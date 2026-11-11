// Warbuilder wb-pkg1 browser smoke test (studio QA tool): plays full matches in the BUILT single-file game with headless
// Chromium through the real UI (taps, not engine calls), on a phone and a desktop viewport, and saves screenshots.
// It also stages the new screens (Spoils, Sweep, Field Promotion, tactical chips, after-action, rank) and checks
// that each new element can be inspected (long press on touch, right click on desktop). Fails on any page error.
//
//   node projects/warbuilder/qa/tools/smoke_pkg.js [outDir=projects/warbuilder/qa/screenshots/pkg1] [matches=1 per viewport]
'use strict';
const path = require('path');
const fs = require('fs');
let chromium; try { ({ chromium } = require('playwright')); } catch (e) { ({ chromium } = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright'))); }

const ROOT = path.join(__dirname, '..', '..');
const PAGE = 'file://' + path.join(ROOT, 'source', 'project-warbuilder', 'build', 'index.html');
const OUT = path.resolve(process.argv[2] || path.join(ROOT, 'qa', 'screenshots', 'pkg1'));
const MATCHES = +(process.argv[3] || 1);
fs.mkdirSync(OUT, { recursive: true });

const VIEWS = [
  { name: 'phone', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  { name: 'desktop', viewport: { width: 1440, height: 900 }, isMobile: false, hasTouch: false, deviceScaleFactor: 1 },
];
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function shot(page, view, name, keepPop) {
  if (!keepPop) { await page.mouse.move(1, 1); await page.evaluate(() => { for (const id of ['tipPop', 'prevPop']) { const e = document.getElementById(id); if (e) e.hidden = true; } }); }
  const f = path.join(OUT, `${view.name}-${name}.png`); await page.screenshot({ path: f }); return f; }
// inspect: long press on touch, right click on desktop; returns the text/preview that appeared
async function inspect(page, view, sel, shotName) {
  const el = await page.$(sel + ' >> visible=true'); if (!el) return null; const b = await el.boundingBox(); if (!b) return null;
  const x = b.x + b.width / 2, y = b.y + Math.min(b.height / 2, 30);
  if (view.hasTouch) {
    await page.evaluate(([x, y]) => { const t = document.elementFromPoint(x, y); const o = { bubbles: true, cancelable: true, pointerType: 'touch', clientX: x, clientY: y, isPrimary: true, pointerId: 7 }; t.dispatchEvent(new PointerEvent('pointerdown', o)); }, [x, y]);
    await sleep(650);
    const r = await page.evaluate(() => { const t = document.getElementById('tipPop'), p = document.getElementById('prevPop'); return (t && !t.hidden && t.textContent) || (p && !p.hidden && 'preview') || null; });
    if (shotName) await shot(page, view, shotName, true);
    await page.evaluate(([x, y]) => { const t = document.elementFromPoint(x, y); t.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, pointerType: 'touch', clientX: x, clientY: y, pointerId: 7 })); }, [x, y]);
    return r;
  }
  await page.mouse.click(x, y, { button: 'right' }); await sleep(250);
  if (shotName) await shot(page, view, shotName, true);
  return page.evaluate(() => { const t = document.getElementById('tipPop'), p = document.getElementById('prevPop'); return (t && !t.hidden && t.textContent) || (p && !p.hidden && 'preview') || null; });
}
const state = page => page.evaluate(() => { const G = window.WZ.G; const ui = window.WZ.ui; if (!G) return { screen: ui.screen }; const me = G.players[ui.me];
  return { screen: ui.screen, over: G.over, turn: G.turn, me: ui.me, busy: ui.busy, play: !!ui.play, sheet: ui.sheet && ui.sheet.type, round: G.round, spoils: !!G.spoils, peek: !!me.peek, hand: me.hand.length, winner: G.winner }; });
async function clickIf(page, sel) { const el = await page.$(sel); if (!el) return false; if (await el.isDisabled() || !(await el.isVisible())) return false; await el.click(); await sleep(120); return true; }

// one of my turns through the UI: play all, maybe promote, fire while it is worth it, handle Sweep and Spoils, end the turn
async function myTurn(page, view, log, shots) {
  await clickIf(page, '[data-act=playall]'); await sleep(200);
  let st = await state(page);
  // one Buy Station card when there is Intel for it (through the sheet, like a player)
  if (await clickIf(page, '.hb-bs')) { await sleep(150); if (await clickIf(page, '.bscard:not([disabled])')) log.buys++; await clickIf(page, '[data-act=close]'); await sleep(100); st = await state(page); }
  if (st.sheet === 'sweep') { if (!shots.sweep) shots.sweep = await shot(page, view, '04-sweep'); await clickIf(page, '[data-act=sweeppick]'); await clickIf(page, '[data-act=sweepok][data-id=set]'); }
  if (await page.$('[data-act=promosheet].tchip')) {
    await clickIf(page, '[data-act=promosheet].tchip'); await sleep(150); await clickIf(page, '[data-act=promopick]');
    if (!shots.promote) shots.promote = await shot(page, view, '05-promote');
    await clickIf(page, '[data-act=dopromote]') || await clickIf(page, '[data-act=close]'); log.promotions++;
  }
  for (let k = 0; k < 6; k++) {
    st = await state(page); if (st.over || st.sheet === 'spoils') break;
    if (st.sheet === 'sweep') { await clickIf(page, '[data-act=sweepok][data-id=keep]'); continue; }
    if (st.sheet) { await clickIf(page, '[data-act=close]'); await sleep(100); }
    const fire = await page.$('.hb-fire:not([disabled])'); if (!fire) break;
    try { await fire.click({ timeout: 4000 }); } catch (e) { log.skipped = (log.skipped || 0) + 1; break; } await sleep(250); log.shots++;
    if (!shots.report) shots.report = await shot(page, view, '03-fire-report');
    await clickIf(page, '[data-act=close]'); await sleep(100);
    st = await state(page); if (st.sheet === 'sweep') await clickIf(page, '[data-act=sweepok][data-id=keep]');
    if (st.hand) await clickIf(page, '[data-act=playall]');
  }
  st = await state(page); if (st.over) return;
  if (st.sheet && st.sheet !== 'spoils') await clickIf(page, '[data-act=close]');
  if (!st.spoils) await clickIf(page, '[data-act=endturn]');
  await sleep(250); st = await state(page);
  if (st.sheet === 'spoils') {
    log.spoils++;
    if (!shots.spoils) { shots.spoils = await shot(page, view, '06-spoils'); log.inspect.spoils = await inspect(page, view, '.sp-pick'); await page.mouse.click(5, 5); await sleep(100); await page.keyboard.press('Escape'); }
    await clickIf(page, '.sp-pick');
  }
}

async function playMatch(browser, view, idx, log) {
  const ctx = await browser.newContext({ viewport: view.viewport, isMobile: view.isMobile, hasTouch: view.hasTouch, deviceScaleFactor: view.deviceScaleFactor });
  const page = await ctx.newPage(); const errors = [];
  page.on('pageerror', e => errors.push(e.message)); page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(PAGE); await sleep(400);
  const shots = {};
  if (idx === 0) shots.start = await shot(page, view, '00-start');
  await page.click('[data-act=new][data-id=ai]'); await sleep(300);
  let guard = 0, rounds = 0;
  while (guard++ < 400) {
    let st = await state(page); if (st.over) break;
    if (st.play) { await clickIf(page, '[data-act=skipplay]'); await sleep(150); continue; }
    if (st.busy || st.turn !== st.me) { await sleep(200); continue; }
    if (st.sheet && !['spoils', 'sweep'].includes(st.sheet)) { await clickIf(page, '[data-act=close]'); await sleep(100); }
    if (st.sheet === 'spoils') { await clickIf(page, '.sp-pick'); continue; }
    if (idx === 0 && st.round === 4 && !shots.r4) { await sleep(500); shots.r4 = await shot(page, view, '01-round4'); log.inspect.threat = await inspect(page, view, '.h-fp'); log.inspect.deck = await inspect(page, view, '.h-deck'); }
    if (idx === 0 && st.round === 7 && !shots.r7) { await sleep(500); shots.r7 = await shot(page, view, '02-round7'); log.inspect.tchip = await inspect(page, view, '.tchip'); }
    rounds = st.round; await myTurn(page, view, log, shots);
  }
  await sleep(900); const st = await state(page);
  if (!st.over) errors.push('match did not finish');
  if (idx === 0) { shots.over = await shot(page, view, '07-after-action'); await page.evaluate(() => { const s = document.querySelector('.layer-ui .sheet'); if (s) s.scrollTop = 9999; }); await sleep(200); shots.over2 = await shot(page, view, '08-after-action-xp'); }
  const meta = await page.evaluate(() => ({ prof: window.WZ.ui.prof, saved: localStorage.getItem('wb-operator-v1') }));
  log.matches.push({ view: view.name, rounds: st.round, winner: st.winner === st.me ? 'player' : st.winner === 'draw' ? 'draw' : 'AI', errors: errors.slice(), xp: meta.prof.xp, saved: !!meta.saved });
  await ctx.close();
  return errors;
}

// staged screens: a tactical moment built on top of a live match (the engine state is plain JSON; the UI re-renders it)
async function staged(browser, view, log) {
  const ctx = await browser.newContext({ viewport: view.viewport, isMobile: view.isMobile, hasTouch: view.hasTouch, deviceScaleFactor: view.deviceScaleFactor });
  const page = await ctx.newPage(); const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto(PAGE); await sleep(300);
  await page.evaluate(() => { localStorage.setItem('wb-operator-v1', JSON.stringify({ v: 1, xp: 700, matches: 6, wins: 3, bestDmg: 48, bestTurn: 14 })); });
  await page.reload(); await sleep(300); await shot(page, view, '09-start-ranked');
  log.inspect.opChip = await inspect(page, view, '.st-chip.op');
  await page.click('.st-chip.op'); await sleep(100);
  await page.click('[data-act=sheet][data-id=rank]'); await sleep(250); await shot(page, view, '10-rank'); await clickIf(page, '[data-act=close]');
  await page.click('[data-act=new][data-id=ai]'); await sleep(500);
  for (let g = 0; g < 50; g++) { const st = await state(page); if (st.turn === st.me && !st.busy && !st.play) break; await clickIf(page, '[data-act=skipplay]'); await sleep(200); }
  await page.evaluate(() => { const { G, ui, render } = window.WZ; const me = G.players[ui.me], op = G.players[1 - ui.me];
    const mk = d => { const iid = 'c' + (G.nid++); G.cards[iid] = { iid, def: d }; return iid; };
    me.hand = ['AT2', 'RT2', 'ST3', 'ET1', 'K04'].map(mk); op.ow = { prec: 3 }; me.drop = [mk('RT3')]; me.res.intel = 2; me.discard.push(mk('T001')); me.hp = 41; op.hp = 37;
    render(); });
  await sleep(300); await shot(page, view, '11-tactics-hand');
  log.inspect.handCard = await inspect(page, view, '.hh-row .hslot button', '11b-inspect-tactic');
  await page.evaluate(() => { const { G, ui } = window.WZ; const me = G.players[ui.me]; for (const i of me.hand.slice()) window.WD.playCard(G, ui.me, i); window.WZ.render(); });
  await sleep(300); await shot(page, view, '12-tactics-chips');
  log.inspect.warnChip = await inspect(page, view, '.tchip.warn', '12b-inspect-chip');
  log.inspect.deckBar = await inspect(page, view, '.h-deck', '12c-inspect-deck');
  await page.evaluate(() => { const { G, ui } = window.WZ; const me = G.players[ui.me]; const mk = d => { const iid = 'c' + (G.nid++); G.cards[iid] = { iid, def: d }; return iid; }; me.deck.push(...['T001', 'R12', 'T004', 'K04'].map(mk)); const sw = mk('RT1'); me.hand.push(sw); window.WD.playCard(G, ui.me, sw); ui.sheet = { type: 'sweep', order: [] }; window.WZ.render(); });
  await sleep(250); await page.click('.sw-pick:nth-child(2)'); await sleep(120); await shot(page, view, '13-sweep');
  await clickIf(page, '[data-act=sweepok][data-id=set]');
  await page.evaluate(() => { const { G, ui } = window.WZ; ui.sheet = { type: 'promote', pick: null, sq: 'recon' }; window.WZ.render(); });
  await sleep(200); await clickIf(page, '[data-act=promopick]'); await shot(page, view, '14-promote');
  await clickIf(page, '[data-act=close]');
  await ctx.close(); return errors;
}

(async () => {
  const browser = await chromium.launch(); const log = { matches: [], shots: 0, buys: 0, spoils: 0, promotions: 0, inspect: {}, errors: [] };
  for (const view of VIEWS) {
    for (let i = 0; i < MATCHES; i++) log.errors.push(...(await playMatch(browser, view, i, log)).map(e => `${view.name}: ${e}`));
    log.errors.push(...(await staged(browser, view, log)).map(e => `${view.name} staged: ${e}`));
  }
  await browser.close();
  console.log(JSON.stringify(log, null, 1));
  if (log.errors.length) process.exit(1);
})();
