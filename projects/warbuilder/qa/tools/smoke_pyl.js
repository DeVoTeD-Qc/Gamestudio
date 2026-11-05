// Playwright smoke + screenshot pass for wb-pyl-impl (push-your-luck FIRE: one tap per flip).
// Plays several of my turns at 844x390 (phone landscape, touch) and 1440x900 by tapping: Play all, then FIRE and FLIP / STOP
// (stop when pushing would fail more than 35% of the time, as the AI does), Continue or Fire again, End turn. Move and buy
// use the engine's AI helpers so the board reaches real mid-game states. It also watches one of the rival's shots replay
// flip by flip, and stages one final-circle shot (Hot Zone: the first Jam misses) by editing the state, so every moment is shot.
//   NODE_PATH=$(npm root -g) node projects/warbuilder/qa/tools/smoke_pyl.js [turns=7]
// Writes WebP files (deviceScaleFactor 1) to projects/warbuilder/qa/screenshots/pyl/<viewport>-<n>-<name>.webp. Exit code 1 on any console error.
'use strict';
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', '..');
const BUILD = path.join(ROOT, 'source', 'project-warbuilder', 'build', 'index.html');
const OUT = path.join(ROOT, 'qa', 'screenshots', 'pyl');
const TURNS = +process.argv[2] || 7;
const SEED_NOW = +process.env.PYL_SEED || 140;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  for (const f of fs.readdirSync(OUT)) if (f.endsWith('.webp')) fs.rmSync(path.join(OUT, f));
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pyl-'));
  const pngs = []; const errors = []; const facts = [];
  const browser = await chromium.launch();
  for (const [w, h, vp] of [[844, 390, 'phone'], [1440, 900, 'desktop']]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, hasTouch: vp === 'phone' });
    await ctx.addInitScript(`Date.now = () => ${SEED_NOW};`);
    const page = await ctx.newPage();
    page.on('console', m => { if (m.type() === 'error') errors.push(`${vp} console: ${m.text()}`); });
    page.on('pageerror', e => errors.push(`${vp} pageerror: ${e.message}`));
    await page.goto('file://' + BUILD);
    let n = 0; const seen = new Set();
    const shot = async (name, once) => { if (once && seen.has(name)) return; seen.add(name); const f = path.join(tmp, `${vp}-${String(++n).padStart(2, '0')}-${name}.png`); await page.screenshot({ path: f }); pngs.push(f); };
    const tap = async sel => { const el = await page.$(sel); if (!el) return false; await el.click(); return true; };
    const closeSheets = () => page.evaluate(() => { if (WZ.ui.sheet && WZ.ui.sheet.type !== 'over') { WZ.ui.sheet = null; WZ.render(); } });
    const waitMine = async () => {
      for (let g = 0; g < 400; g++) {
        const st = await page.evaluate(() => { const G = WZ.G; return { over: G.over, mine: G.turn === WZ.ui.me && !WZ.ui.busy && !WZ.ui.play, sheet: WZ.ui.sheet && WZ.ui.sheet.type }; });
        if (st.over) return false;
        if (st.sheet && st.sheet !== 'over') await closeSheets();
        if (st.mine) return true;
        await page.waitForTimeout(100);
      }
      return false;
    };
    const stats = { shots: 0, flips: 0, stops: 0, jams: 0, hits: 0, misses: 0, rivalFlipFrames: 0 };
    // one shot by taps; returns false if FIRE was not available
    const fireByTaps = async (tag) => {
      if (!(await tap('.hb-fire:not([disabled])'))) return false;
      stats.shots++; await page.waitForTimeout(260); await shot(`${tag}-fire-start`, true);
      for (let k = 0; k < 40; k++) {
        const s = await page.evaluate(() => { const G = WZ.G; if (!G.shot) return null; const o = WD.shotOdds(G, WZ.ui.me, G.shot.gi, 300); return { lvl: G.shot.level, next: o.next }; });
        if (!s) break;
        if (s.lvl >= 0 && (s.next == null || 1 - s.next > 0.35)) { await tap('[data-act="stop"]'); stats.stops++; await page.waitForTimeout(520); await shot('stop-bank', true); break; }
        await tap('[data-act="flip"]'); stats.flips++; await page.waitForTimeout(470);
        const ev = await page.evaluate(() => (WZ.ui.shotFx || {}).ev);
        if (ev === 'jam') { stats.jams++; await shot('flip-jam', true); }
        else if (ev === 'step') await shot('flip-step-reached', true);
        else if (ev === 'bust') { stats.jams++; await page.waitForTimeout(300); await shot('bust-jammed', true); }
        else if (ev === 'bank') { await page.waitForTimeout(300); await shot('bank-top-or-out', true); }
        else if (ev === 'miss') { await page.waitForTimeout(300); await shot('miss-out-of-precision', true); }
        else await shot(`flip-${Math.min(k + 1, 3)}`, true);
      }
      const r = await page.evaluate(() => WZ.ui.shotEnd && { hit: WZ.ui.shotEnd.hit, how: WZ.ui.shotEnd.how });
      if (r) { r.hit ? stats.hits++ : stats.misses++; await shot(r.hit ? 'result-hit' : 'result-miss', true); }
      if (!(await tap('[data-act="fireagain"]'))) await tap('[data-act="shotok"]'); else { stats.shots++; await page.waitForTimeout(260); await shot('fire-again', true); await finishOpenShot(); }
      return true;
    };
    const finishOpenShot = async () => { // a shot opened with Fire again: flip to the end, stopping at step 1
      for (let k = 0; k < 40; k++) { const lvl = await page.evaluate(() => WZ.G.shot ? WZ.G.shot.level : null); if (lvl == null) break; await tap(lvl >= 0 ? '[data-act="stop"]' : '[data-act="flip"]'); stats.flips++; await page.waitForTimeout(380); }
      await tap('[data-act="shotok"]'); await page.waitForTimeout(200);
    };
    await page.click('[data-act="new"][data-id="ai"]');
    await page.waitForTimeout(600);
    let rivalShot = false;
    for (let t = 0; t < TURNS; t++) {
      if (!(await waitMine())) break;
      await page.waitForTimeout(1700); await closeSheets();
      await tap('[data-act="playall"]:not([disabled])'); await page.waitForTimeout(500); await closeSheets();
      await page.evaluate(() => { const G = WZ.G, p = WZ.ui.me; WD.aiMove(G, p); WD.aiBuy(G, p); WZ.render(); });
      await page.waitForTimeout(300);
      if (t === 2) await shot('turn-fire-button', true);
      for (let g = 0; g < 4; g++) { const ok = await fireByTaps('t' + t); if (!ok) break; if (await page.evaluate(() => WZ.G.over)) break; }
      if (await page.evaluate(() => WZ.G.over)) break;
      await tap('[data-act="endturn"]:not([disabled])');
      // watch the rival replay; catch one of its shots mid-flip
      for (let g = 0; g < 400; g++) {
        const st = await page.evaluate(() => ({ play: !!WZ.ui.play, shot: !!(WZ.G.shot && WZ.G.shot.p !== WZ.ui.me), n: WZ.G.shot ? WZ.G.shot.flipped.length : 0, end: !!(WZ.ui.shotEnd && WZ.ui.play) }));
        if (!st.play && g > 5) break;
        if (st.shot) stats.rivalFlipFrames++;
        if (!rivalShot && st.shot && st.n >= 2) { await shot('rival-shot-flipping'); rivalShot = true; }
        if (rivalShot && st.end && !seen.has('rival-shot-result')) await shot('rival-shot-result');
        await page.waitForTimeout(90);
      }
    }
    // staged: the final circle (Hot Zone). Both operators on the last location, a fresh turn with Precision.
    if (await waitMine()) {
      await page.evaluate(() => { const G = WZ.G, me = G.players[WZ.ui.me], op = G.players[1 - WZ.ui.me];
        for (const e of G.envs) e.state = e.w === me.pos ? 'safe' : 'gas'; op.pos = me.pos; me.res.prec = Math.max(me.res.prec, 6); WZ.render(); });
      await page.waitForTimeout(300); await shot('hotzone-fire-button');
      if (await tap('.hb-fire:not([disabled])')) { await page.waitForTimeout(300); await shot('hotzone-shot');
        for (let k = 0; k < 20; k++) { const lvl = await page.evaluate(() => WZ.G.shot ? WZ.G.shot.level : null); if (lvl == null) break; await tap('[data-act="flip"]'); await page.waitForTimeout(420); }
        await shot('hotzone-result'); await tap('[data-act="shotok"]'); }
    }
    await page.evaluate(() => { WZ.ui.sheet = { type: 'rules' }; WZ.renderLayer(); }); await page.waitForTimeout(300);
    await page.evaluate(() => { const el = [...document.querySelectorAll('.rules h4')].find(h => /Firing/.test(h.textContent)); if (el) el.scrollIntoView(); });
    await page.waitForTimeout(200); await shot('rules-firing');
    const st = await page.evaluate(() => ({ round: WZ.G.round, over: WZ.G.over }));
    facts.push({ vp, ...st, ...stats });
    await ctx.close();
  }
  await browser.close();
  const py = `import sys\nfrom PIL import Image\nfor src in sys.argv[2:]:\n    dst = sys.argv[1] + '/' + src.rsplit('/', 1)[1][:-4] + '.webp'\n    Image.open(src).convert('RGB').save(dst, 'WEBP', quality=86, method=6)\n`;
  if (pngs.length) execFileSync('python3', ['-I', '-c', py, OUT, ...pngs]);
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(JSON.stringify({ errors, facts, files: pngs.map(f => path.basename(f, '.png') + '.webp') }, null, 1));
  if (errors.length) process.exitCode = 1;
})();
