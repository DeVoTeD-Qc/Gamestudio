// Playwright smoke test of the built game for wb-rules: start a match vs the AI, play several turns, no console errors.
// Screenshots go to projects/warbuilder/qa/screenshots/rules/.
//   NODE_PATH=$(npm root -g) node projects/warbuilder/qa/tools/smoke_rules.js [turns=6]
'use strict';
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..', '..');
const BUILD = path.join(ROOT, 'source', 'project-warbuilder', 'build', 'index.html');
const OUT = path.join(ROOT, 'qa', 'screenshots', 'rules');
const TURNS = +process.argv[2] || 6;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const errors = [];
  const results = [];
  for (const [w, h, tag] of [[844, 390, 'phone'], [1440, 900, 'desktop']]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, hasTouch: tag === 'phone', isMobile: false });
    const page = await ctx.newPage();
    page.on('console', m => { if (m.type() === 'error') errors.push(`${tag} console: ${m.text()}`); });
    page.on('pageerror', e => errors.push(`${tag} pageerror: ${e.message}`));
    await page.goto('file://' + BUILD);
    await page.screenshot({ path: path.join(OUT, `${tag}-0-start.png`) });
    await page.click('[data-act="new"][data-id="ai"]');
    await page.waitForTimeout(600);
    const shot = async name => page.screenshot({ path: path.join(OUT, `${tag}-${name}.png`) });
    let turns = 0;
    for (let guard = 0; guard < 400 && turns < TURNS; guard++) {
      const st = await page.evaluate(() => { const G = WZ.G; return G ? { over: G.over, mine: G.turn === WZ.ui.me && !WZ.ui.busy && !WZ.ui.play && !WZ.ui.handoff, sheet: WZ.ui.sheet && WZ.ui.sheet.type, round: G.round } : null; });
      if (!st || st.over) break;
      if (st.sheet && st.sheet !== 'over') { await page.evaluate(() => { WZ.ui.sheet = null; WZ.render(); }); continue; }
      if (!st.mine) { await page.waitForTimeout(150); const sk = await page.$('[data-act="skipplay"]'); if (sk) await sk.click().catch(() => {}); continue; }
      // my turn: play all, try to move, buy at the station, aim, fire, end
      const btn = async sel => { const el = await page.$(sel); if (el && await el.isEnabled()) { await el.click(); await page.waitForTimeout(250); await page.evaluate(() => { if (WZ.ui.sheet && WZ.ui.sheet.type !== 'over') { WZ.ui.sheet = null; WZ.render(); } }); return true; } return false; };
      await btn('[data-act="playall"]');
      if (turns === 1) await shot('2-played');
      // a buy at the Buy Station if Intel allows
      await page.evaluate(() => { const G = WZ.G, me = G.players[WZ.ui.me]; if (me.res.intel >= 2 && window.WD.buysLeft(G, WZ.ui.me)) { const r = window.WD.buySupply(G, WZ.ui.me, 'K04'); if (r.ok) WZ.render(); } });
      // open the Aim sheet once and screenshot it
      const aim = await page.$('[data-act="aim"]');
      if (aim && !results.some(r => r === tag + ':aim')) { await aim.click(); await page.waitForTimeout(300); await shot('3-aim'); results.push(tag + ':aim'); await page.evaluate(() => { WZ.ui.sheet = null; WZ.render(); }); }
      for (let k = 0; k < 3; k++) { if (!(await btn('.hb-fire:not([disabled])'))) break; }
      if (turns === 2) await shot('4-after-fire');
      await btn('[data-act="endturn"]');
      turns++;
      await page.waitForTimeout(300);
    }
    // finish the rival's turn and capture the board mid-match
    for (let g = 0; g < 60; g++) { const busy = await page.evaluate(() => !!(WZ.ui.busy || WZ.ui.play)); if (!busy) break; const sk = await page.$('[data-act="skipplay"]'); if (sk) await sk.click().catch(() => {}); await page.waitForTimeout(150); }
    await page.evaluate(() => { if (WZ.ui.sheet && WZ.ui.sheet.type !== 'over') { WZ.ui.sheet = null; WZ.render(); } });
    await shot('5-board');
    // rules sheet with the new text
    await page.evaluate(() => { WZ.ui.sheet = { type: 'rules' }; WZ.renderLayer(); });
    await page.waitForTimeout(250); await shot('6-rules');
    const state = await page.evaluate(() => { const G = WZ.G, me = G.players[WZ.ui.me]; return { round: G.round, over: G.over, fpHist: me.fpHist, loadout: me.loadout.length, hasFirepower: !!document.querySelector('.h-fp'), squadCounters: document.querySelectorAll('.h-squad .sqc').length, loadoutSlots: document.querySelectorAll('.h-lo .lo-slot').length }; });
    results.push({ tag, turns, ...state });
    await ctx.close();
  }
  await browser.close();
  console.log(JSON.stringify({ errors, results }, null, 1));
  if (errors.length) process.exitCode = 1;
})();
