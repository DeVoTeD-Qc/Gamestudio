// Records real Killstreak gameplay (probe build) at 1280x720 CSS / 1920x1080 px via CDP screencast.
// Usage: node play.js <outdir> [port]
// Writes <outdir>/frames/<n>.jpg + <outdir>/frames.json [{file, t}] + <outdir>/marks.json [{t, label, ...}]
const { chromium } = require('playwright');
const fs = require('fs');
const OUT = process.argv[2]; const PORT = process.argv[3] || 8761; const TS = +(process.env.TS || 0.15);
fs.mkdirSync(OUT + '/frames', { recursive: true });
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1.5 });
  const page = await ctx.newPage();
  let P = null; const logs = [];
  page.on('console', m => { const t = m.text(); if (t.startsWith('PROBE ')) P = JSON.parse(t.slice(6)); else logs.push(m.type() + ': ' + t); });
  const rsleep = ms => page.waitForTimeout(ms); const sleep = ms => page.waitForTimeout(ms / TS);
  const T0 = Date.now(); const now = () => (Date.now() - T0) / 1000;
  const marks = []; const mark = (label, extra = {}) => { marks.push({ t: now() * TS, label, ...extra }); console.log((now() * TS).toFixed(1), label, JSON.stringify(extra)); };
  // screencast
  const cdp = await ctx.newCDPSession(page); const frames = []; let fi = 0;
  cdp.on('Page.screencastFrame', async f => {
    const file = `frames/${String(fi++).padStart(6, '0')}.jpg`;
    fs.writeFileSync(`${OUT}/${file}`, Buffer.from(f.data, 'base64'));
    frames.push({ file, t: now() * TS });
    try { await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }); } catch (e) {}
  });
  const fresh = async () => { P = null; for (let i = 0; i < 50 && !P; i++) await rsleep(100); return P; };
  const until = async (pred, what, ms = 90000) => { ms = ms / TS; const t0 = Date.now(); while (Date.now() - t0 < ms) { if (P && pred(P)) return P; await rsleep(150); } throw new Error('timeout: ' + what + ' ' + JSON.stringify(P).slice(0, 800) + '\n' + logs.slice(-15).join('\n')); };
  const key = (re) => Object.keys((P && P.buttons) || {}).find(k => re.test(k));
  const btn = (re) => { const k = key(re); return k ? P.buttons[k] : null; };
  // Visible tap indicator (DOM overlay above the canvas; the game never sees it).
  const ring = async (x, y, long = false) => page.evaluate(([x, y, long, TS]) => {
    let st = document.getElementById('tapcss');
    if (!st) { st = document.createElement('style'); st.id = 'tapcss'; st.textContent = '@keyframes tapr{0%{transform:translate(-50%,-50%) scale(.4);opacity:1}100%{transform:translate(-50%,-50%) scale(1.6);opacity:0}}.tapr{position:fixed;width:46px;height:46px;border-radius:50%;border:4px solid #fff;background:rgba(255,255,255,.25);box-shadow:0 0 12px rgba(0,0,0,.6);pointer-events:none;z-index:99999;animation:tapr '+(.55/TS)+'s ease-out forwards}.tapr.long{animation-duration:'+(1.1/TS)+'s;border-color:#ffb020}'; document.head.appendChild(st); }
    const d = document.createElement('div'); d.className = 'tapr' + (long ? ' long' : ''); d.style.left = x + 'px'; d.style.top = y + 'px'; document.body.appendChild(d); setTimeout(() => d.remove(), 1300 / TS);
  }, [x, y, long, TS]);
  const click = async (xy, wait = 600) => { await ring(xy[0], xy[1]); await page.mouse.click(xy[0], xy[1]); await sleep(wait); };
  const longPress = async (xy, hold = 800) => { await ring(xy[0], xy[1], true); await page.mouse.move(xy[0], xy[1]); await page.mouse.down(); await sleep(hold); await page.mouse.up(); await sleep(500); };
  const tapBtn = async (re, wait = 900) => { const b = btn(re); if (!b) throw new Error('no button ' + re + ' in ' + JSON.stringify(P && P.buttons)); await click(b, wait); await fresh(); };

  await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 88, maxWidth: 1920, maxHeight: 1080, everyNthFrame: 1 });
  mark('goto');
  await page.goto(`http://localhost:${PORT}/index.html?ts=${TS}`);
  await until(p => p.scene === 'Consent', 'consent'); mark('consent'); await sleep(1200); await fresh();
  await tapBtn(/^YesButton/, 1000); mark('presurvey'); await sleep(600);
  for (const [x, y] of [[831, 268], [831, 345], [973, 421]]) await click([x, y], 450);
  await click([917, 504], 1500); await fresh(); mark('title');
  await sleep(1800);
  if (btn(/^NotNowButton/)) await tapBtn(/^NotNowButton/, 900);
  await tapBtn(/^StartButton/, 1500); mark('loadout'); await sleep(2200); await fresh();
  await tapBtn(/BEGIN RUN/, 2200); mark('runmap'); await sleep(1800); await fresh();
  await tapBtn(/DEPLOY/, 2500);
  await until(p => p.scene === 'Match', 'match'); mark('match');

  let inspected = false, matches = 0, ksUsed = 0, fragUsed = 0;
  const MAXM = +(process.env.MAXM || 2);
  while (true) {
    await fresh();
    if (P.scene !== 'Match') {
      mark('scene', { scene: P.scene });
      if (matches >= MAXM || (ksUsed > 0 && matches >= 1)) break;
      // after-action / rewards: tap the main continue button until we are back on RunMap, then DEPLOY
      const k = key(/DEPLOY/) || key(/CONTINUE|NEXT|SKIP|TAKE|DONE|OK/i);
      if (k) { await click(P.buttons[k], 1800); continue; }
      const any = Object.keys(P.buttons).find(k => !/QUIT|MENU|BACK/i.test(k));
      if (any) { await click(P.buttons[any], 1800); continue; }
      await sleep(500); continue;
    }
    if (P.banner) {
      mark('banner', { round: P.round }); matches++;
      await sleep(3500); await fresh();
      if (matches >= MAXM || ksUsed > 0) break;
      const k = key(/CONTINUE/i); if (k) await click(P.buttons[k], 2500);
      continue;
    }
    if (P.busy || P.phase !== 'deploy') { await rsleep(250); continue; }
    if (P.mulligan) { await sleep(1500); mark('mulligan'); await tapBtn(/^KeepButton/, 1200); continue; }
    if (P.ready) { await rsleep(300); continue; }
    const round = P.round; mark('deploy', { round, supply: P.supply, streak: P.streak, tray: P.tray });
    // 1) operator
    if (P.op_deploy) {
      await click(P.op, 700); await fresh();
      await click(P.rows[1], 900); await fresh(); mark('operator');
    }
    // 2) killstreak call-in
    const ksk = Object.keys(P.buttons).find(k => /\|(RECON|MORTAR|ATTACK|SENTRY)/i.test(k) && !/ AT \d|WAIT/i.test(k));
    if (ksk) {
      const before = P.plays; const name = ksk.split('|')[1];
      await click(P.buttons[ksk], 900); await fresh();
      if (P.plays === before) {
        // needs a zone: the lane with most enemies
        let best = 0; P.lanes.forEach((l, i) => { if (l.enemies.length > P.lanes[best].enemies.length) best = i; });
        const tgt = P.lanes[best].enemies.length ? P.lanes[best].enemies[0].pos : P.rows[best];
        await click(tgt, 900); await fresh();
        if (P.plays === before) { await click(P.rows[best], 900); await fresh(); }
      }
      if (P.plays > before) { ksUsed++; mark('killstreak', { name }); } else { mark('ks-failed', { name, buttons: Object.keys(P.buttons) }); }
    }
    // 3) inspector (long press a hand card) once, round 2+
    if (!inspected && round >= 2 && P.hand.length) {
      mark('inspector'); await longPress(P.hand[0].pos, 900); await sleep(2600);
      await fresh(); const c = key(/CLOSE|BACK|DONE/i); if (c) await click(P.buttons[c], 800); else await click([640, 60], 800);
      inspected = true; await fresh();
    }
    // 4) frag on an enemy unit
    const fk = key(/\|FRAG READY/i);
    if (fk && fragUsed < 2) {
      const lane = P.lanes.findIndex(l => l.enemies.length > 0);
      if (lane >= 0) {
        const before = P.plays; await click(P.buttons[fk], 800); await fresh();
        await click(P.lanes[lane].enemies[0].pos, 900); await fresh();
        if (P.plays > before) { fragUsed++; mark('frag', { lane }); } else { mark('frag-failed'); const c = key(/\|FRAG/i); if (c) await click(P.buttons[c], 500); await fresh(); }
      }
    }
    // 5) units
    for (let guard = 0; guard < 6; guard++) {
      await fresh();
      const cards = P.hand.filter(h => h.unit && h.cost <= P.supply).sort((a, b) => b.cost - a.cost);
      if (!cards.length) break;
      const c = cards[0]; const before = P.plays;
      const order = [1, 0, 2].filter(z => P.lanes[z].mine < 4);
      await click(c.pos, 650);
      let ok = false;
      for (const z of order) { await click(P.rows[z], 750); await fresh(); if (P.plays > before) { ok = true; mark('unit', { z }); break; } }
      if (!ok) { await click(c.pos, 400); break; }
    }
    await sleep(500); await fresh();
    mark('ready', { round }); await tapBtn(/^ReadyButton/, 600);
    await until(p => p.busy || p.banner || p.round !== round || p.scene !== 'Match', 'round start', 20000).catch(() => {});
    mark('fight', { round });
    await until(p => p.scene !== 'Match' || p.banner || (!p.busy && p.round !== round && p.phase === 'deploy'), 'round end', 120000);
    mark('fight-end', { round });
  }
  await sleep(1500);
  await cdp.send('Page.stopScreencast');
  mark('end');
  fs.writeFileSync(OUT + '/frames.json', JSON.stringify(frames));
  fs.writeFileSync(OUT + '/marks.json', JSON.stringify(marks, null, 1));
  fs.writeFileSync(OUT + '/logs.txt', logs.join('\n'));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
