// Playwright screenshot pass for wb-hud (HUD: Firepower, squads, Rally, Loadout, Aim, circle chips).
// Fixed seed (Date.now is pinned), so "before" and "after" runs show the same match.
// My turns are played by the engine's AI helpers until the engine has formed, then each HUD moment is captured.
//   NODE_PATH=$(npm root -g) node projects/warbuilder/qa/tools/smoke_hud.js <tag: before|after> [warmTurns=6]
// Writes WebP files (deviceScaleFactor 1) to projects/warbuilder/qa/screenshots/hud/<tag>-<viewport>-<n>-<name>.webp
'use strict';
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', '..');
const BUILD = path.join(ROOT, 'source', 'project-warbuilder', 'build', 'index.html');
const OUT = path.join(ROOT, 'qa', 'screenshots', 'hud');
const TAG = process.argv[2] || 'after';
const WARM = +process.argv[3] || 7;
const SEED_NOW = +process.env.HUD_SEED || 140; // seed 140: an Engineer deck with 2 Loadout cards and a rising Firepower curve

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hud-'));
  const pngs = [];
  const browser = await chromium.launch();
  const errors = [];
  const facts = [];
  for (const [w, h, vp] of [[844, 390, 'phone'], [1440, 900, 'desktop']]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, hasTouch: vp === 'phone', isMobile: false });
    await ctx.addInitScript(`Date.now = () => ${SEED_NOW};`);
    const page = await ctx.newPage();
    page.on('console', m => { if (m.type() === 'error') errors.push(`${vp} console: ${m.text()}`); });
    page.on('pageerror', e => errors.push(`${vp} pageerror: ${e.message}`));
    await page.goto('file://' + BUILD);
    let n = 0;
    const shot = async name => { const f = path.join(tmp, `${TAG}-${vp}-${++n}-${name}.png`); await page.screenshot({ path: f }); pngs.push(f); };
    const closeSheets = () => page.evaluate(() => { if (WZ.ui.sheet && WZ.ui.sheet.type !== 'over') { WZ.ui.sheet = null; WZ.render(); } });
    const waitMine = async (skip = true) => {
      for (let g = 0; g < 200; g++) {
        const st = await page.evaluate(() => { const G = WZ.G; return { over: G.over, mine: G.turn === WZ.ui.me && !WZ.ui.busy && !WZ.ui.play && !WZ.ui.handoff, sheet: WZ.ui.sheet && WZ.ui.sheet.type }; });
        if (st.over) return false;
        if (st.sheet && st.sheet !== 'over') await closeSheets();
        if (st.mine) return true;
        if (skip) { const sk = await page.$('[data-act="skipplay"]'); if (sk) await sk.click().catch(() => {}); }
        await page.waitForTimeout(120);
      }
      return false;
    };
    await page.click('[data-act="new"][data-id="ai"]');
    await page.waitForTimeout(500);
    // warm-up: the engine's AI plays my turns, so the deck forms (Loadout, squads)
    for (let t = 0; t < WARM; t++) {
      if (!(await waitMine())) break;
      await page.evaluate(() => { const G = WZ.G, p = WZ.ui.me; WD.aiPlay(G, p); WD.aiMove(G, p); WD.aiBuy(G, p); WD.aiCycle(G, p); WD.aiFireLoop(G, p); if (!G.over) { WD.aiScrap(G, p); WD.aiBuy(G, p); } WZ.render(); });
      await closeSheets();
      const end = await page.$('[data-act="endturn"]:not([disabled])'); if (end) await end.click();
      await page.waitForTimeout(200);
    }
    // the rival's turn as it plays out (the rival overlay on the map)
    for (let g = 0; g < 40; g++) { const p = await page.evaluate(() => !!WZ.ui.play); if (p) break; await page.waitForTimeout(100); }
    await page.waitForTimeout(1600);
    if (await page.evaluate(() => !!WZ.ui.play)) await shot('rival-turn');
    if (!(await waitMine())) { await shot('over'); await ctx.close(); continue; }
    await page.waitForTimeout(250); await shot('turn-start');
    await page.waitForTimeout(1600); await closeSheets(); await shot('ready');
    // play one card by tapping it (phone: tap lifts, second tap plays), then Play all
    const card = await page.$('.h-hand .hslot:not(.pl) [data-act="card"]');
    if (card) { await card.click(); await page.waitForTimeout(150); const c2 = await page.$('.h-hand .hslot.lifted [data-act="card"]'); if (c2) await c2.click(); await page.waitForTimeout(450); await shot('one-card'); }
    const all = await page.$('[data-act="playall"]:not([disabled])'); if (all) { await all.click(); await page.waitForTimeout(500); await shot('played'); await page.waitForTimeout(1600); await shot('played-settled'); }
    // move toward the rival if the AI would, and buy, so the board looks like a real mid-game
    await page.evaluate(() => { const G = WZ.G, p = WZ.ui.me; WD.aiMove(G, p); WD.aiBuy(G, p); WZ.render(); });
    await page.waitForTimeout(300);
    const aim = await page.$('[data-act="aim"]');
    if (aim) { await aim.click(); await page.waitForTimeout(350); await shot('aim'); await closeSheets(); }
    const fire = await page.$('.hb-fire:not([disabled])');
    if (fire) { await fire.click(); await page.waitForTimeout(1800); await shot('fire-report'); await closeSheets(); }
    const end = await page.$('[data-act="endturn"]:not([disabled])');
    if (end) { await end.click(); await page.waitForTimeout(350); await shot('turn-end'); }
    await waitMine();
    await page.waitForTimeout(1800); await closeSheets(); await shot('next-turn');
    await page.evaluate(() => { WZ.ui.sheet = { type: 'rules' }; WZ.renderLayer(); });
    await page.waitForTimeout(300); await shot('rules');
    const st = await page.evaluate(() => { const G = WZ.G, me = G.players[WZ.ui.me]; return { round: G.round, over: G.over, fpHist: me.fpHist, loadout: me.loadout.length }; });
    facts.push({ vp, ...st });
    await ctx.close();
  }
  await browser.close();
  // PNG -> WebP (Pillow), then drop the PNGs
  const py = `import sys\nfrom PIL import Image\nfor src in sys.argv[2:]:\n    dst = sys.argv[1] + '/' + src.rsplit('/', 1)[1][:-4] + '.webp'\n    Image.open(src).convert('RGB').save(dst, 'WEBP', quality=86, method=6)\n`;
  if (pngs.length) execFileSync('python3', ['-I', '-c', py, OUT, ...pngs]);
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(JSON.stringify({ errors, facts, files: pngs.map(f => path.basename(f, '.png') + '.webp') }, null, 1));
  if (errors.length) process.exitCode = 1;
})();
