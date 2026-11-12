// DeadDraw dd-ux-equip touch smoke: the studio head's equip / drag / scroll / Patch notes, played
// with real touch events (CDP Input.dispatchTouchEvent) in headless Chromium at phone portrait:
//   1. auto-equip: a tap on a street gun with slot 2 empty puts it straight in (no sheet);
//   2. both slots full: the tap opens the sheet (into slot 1 / slot 2 / scrap / cancel);
//   3. drag: a gun card lifted with one finger shows the glowing targets (captured mid-drag),
//      dropped on slot 2 it replaces that gun; a melee button dragged onto a zombie attacks it;
//   4. the Patch icon row in the HUD (a long press on an icon opens that Patch);
//   5. the Codex scrolls with a one-finger drag and with two fingers, without opening a tile.
// Console errors fail the run. Prints "errors: none" when everything passed.
// Usage: node smoke_touch.js <url-of-index.html> <screenshot-dir>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const URL = process.argv[2];
const OUT = process.argv[3];
fs.mkdirSync(OUT, { recursive: true });
const VP = { width: 390, height: 844 };

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
async function state(page) { return page.evaluate(() => window.ddState || null); }
async function waitFor(page, pred, what, ms = 60000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const s = await state(page);
    if (s && pred(s)) return s;
    await sleep(120);
  }
  throw new Error('timeout waiting for ' + what + ' state=' + JSON.stringify(await state(page)).slice(0, 400));
}
const center = (it) => ({ x: it.x + it.w / 2, y: it.y + it.h / 2 });
const card = (idx) => (i) => i.type === 'card' && i.index === idx;
function find(s, pred, what) {
  const it = s.items.find(pred);
  if (!it) throw new Error('not on screen: ' + what);
  return it;
}
async function touch(cdp, type, pts) {
  await cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, k) => (pts.length > 1 ? { x: p.x, y: p.y, id: k } : { x: p.x, y: p.y })) });
}
// start and end are queued together (a late ack on a loaded machine would turn a tap into a zoom)
async function tap(cdp, p) { const a = touch(cdp, 'touchStart', [p]); await sleep(60); await Promise.all([a, touch(cdp, 'touchEnd', [])]); await sleep(300); }
async function hold(cdp, p, ms = 1000) { await touch(cdp, 'touchStart', [p]); await sleep(ms); await touch(cdp, 'touchEnd', []); await sleep(300); }
// tap until pred holds (the board ignores taps while the deal animation runs on a slow machine)
async function tapUntil(page, cdp, p, pred, what, tries = 4) {
  for (let k = 0; k < tries; k++) {
    await tap(cdp, p);
    const s = await waitFor(page, pred, what, 2500).catch(() => null);
    if (s) return s;
    const t = await state(page);
    console.log(`  (retry ${what}: sheet=${t.sheet} inspect=${t.inspect} block=${t.block} drag=${t.drag} guns=${t.guns})`);
    // a busy machine can deliver the release late (a zoom opens): close it and tap again
    if (t.inspect) { await tap(cdp, { x: 195, y: 6 }); await sleep(400); }
  }
  return state(page);
}
// one finger from a to b in steps; end=false leaves the finger down (mid-drag screenshot)
async function drag(cdp, a, b, end = true, steps = 12) {
  // the start and the first moves are queued together: on a loaded machine an awaited start can be
  // acked so late that the long press fires before the finger has moved
  const pt = (k) => ({ x: a.x + (b.x - a.x) * k / steps, y: a.y + (b.y - a.y) * k / steps });
  const first = [touch(cdp, 'touchStart', [a])];
  for (let k = 1; k <= 3; k++) first.push(touch(cdp, 'touchMove', [pt(k)]));
  await Promise.all(first);
  for (let k = 4; k <= steps; k++) {
    await touch(cdp, 'touchMove', [pt(k)]);
    await sleep(25);
  }
  if (end) { await sleep(80); await touch(cdp, 'touchEnd', []); await sleep(400); }
}

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await browser.newContext({ viewport: VP, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));
  const cdp = await ctx.newCDPSession(page);
  const shot = async (n) => { await page.screenshot({ path: path.join(OUT, `equip_${n}.png`) }); };
  const go = async (q, what) => {
    await page.goto(URL + '?' + q, { waitUntil: 'load' });
    const s = await waitFor(page, (x) => x.screen === what, what, 90000);
    await sleep(3000);
    return state(page);
  };
  const check = (cond, msg) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg); if (!cond) errors.push('FAIL ' + msg); };
  try {
    // 1. auto-equip into the empty slot 2
    let s = await go('screen=street&seed=4&gun1=rifle&stack1=6,4&gun2=none&street=W:carbine,Z5,Z3,M4&patches=bounty,brawler,lookout', 'STREET');
    await shot('00_before');
    s = await tapUntil(page, cdp, center(find(s, card(0), 'street gun')), (x) => x.guns && x.guns[1] === 'carbine', 'carbine in slot 2');
    await sleep(120); await shot('01_auto_equip_flight');
    check(s.guns[1] === 'carbine' && s.sheet === '', 'tap with a free slot: auto-equipped into slot 2, no sheet');
    await sleep(900); await shot('01b_auto_equip_done');
    // 4. the Patch row: long press an icon -> that Patch's tooltip
    s = await state(page);
    const icon = s.items.find((i) => i.type === 'card' && i.kind === 'P' && i.tag === 'PATCH' && i.h <= 60);
    check(!!icon, 'a Patch icon in the HUD');
    if (icon) {
      await hold(cdp, center(icon));
      s = await waitFor(page, (x) => x.inspect, 'patch tooltip', 4000).catch(() => state(page));
      check(s.inspect && JSON.stringify(s.tip).includes('Patch'), 'long press on a Patch icon: its name and rule ' + JSON.stringify(s.tip));
      await shot('04_patch_tooltip');
      await tap(cdp, { x: VP.width / 2, y: 8 });
    }
    // 2. both slots full: the sheet
    s = await go('screen=street&seed=4&gun1=rifle&stack1=6,4,3&gun2=crossbow&stack2=4&street=W:carbine,Z5,Z3,M4&patches=bounty,brawler', 'STREET');
    s = await tapUntil(page, cdp, center(find(s, card(0), 'street gun')), (x) => x.sheet === 'gun', 'full-slots sheet');
    check(s.sheet === 'gun', 'both slots full: the sheet opens');
    const texts = s.items.filter((i) => i.type === 'button').map((i) => i.text).join(' | ');
    check(texts.includes('INTO SLOT 1') && texts.includes('INTO SLOT 2') && texts.includes('SCRAP') && texts.includes('Cancel'), 'slot 1 / slot 2 / scrap / cancel: ' + texts.replace(/\n/g, ' '));
    await sleep(300); await shot('02_full_slots_sheet');
    await tap(cdp, center(find(s, (i) => i.type === 'button' && i.text === 'Cancel', 'cancel')));
    s = await waitFor(page, (x) => x.sheet === '', 'sheet closed', 4000);
    // 3. drag the gun card onto slot 2 (mid-drag screenshot with the glows)
    const from = center(find(s, card(0), 'street gun'));
    const to = center(find(s, card(201), 'gun slot 2'));
    await drag(cdp, from, to, false);
    await sleep(250);
    s = await state(page);
    check(s.drag === true, 'one finger lifts the card (drag on)');
    await shot('03_drag_in_progress');
    await touch(cdp, 'touchEnd', []);
    s = await waitFor(page, (x) => x.guns && x.guns[1] === 'carbine', 'dropped on slot 2', 5000).catch(() => state(page));
    check(s.guns[1] === 'carbine' && !s.drag, 'dropped on slot 2: the carbine replaced the crossbow');
    await sleep(900);
    // a drop on empty space snaps back
    s = await go('screen=street&seed=4&gun1=rifle&gun2=crossbow&street=W:carbine,Z5,Z3,M4', 'STREET');
    await drag(cdp, center(find(s, card(0), 'street gun')), { x: VP.width / 2, y: 6 });
    s = await state(page);
    check(s.guns[1] === 'crossbow' && s.guns[0] === 'rifle' && s.street === 4 && !s.drag, 'a drop on empty space snaps back (nothing changes)');
    // melee dragged onto a zombie attacks it
    s = await go('screen=street&seed=4&gun1=rifle&gun2=none&street=Z2,Z7,M4,C2', 'STREET');
    const r0 = s.resolved;
    await drag(cdp, center(find(s, card(202), 'melee')), center(find(s, card(0), 'zombie')));
    s = await waitFor(page, (x) => x.resolved > r0, 'melee drag attack', 5000).catch(() => state(page));
    check(s.resolved > r0 && s.active === 2, 'melee dragged onto a zombie: killed, melee active');
    // 5. the Codex: one finger on a tile, then two fingers
    s = await go('screen=street&seed=4&overlay=codex', 'STREET');
    s = await waitFor(page, (x) => x.overlay === 'codex', 'codex open', 5000);
    await sleep(500);
    const tile = s.items.find((i) => i.type === 'card' && i.y > 380 && i.y < 600);
    const p0 = tile ? center(tile) : { x: VP.width / 2, y: 560 };
    await drag(cdp, p0, { x: p0.x, y: p0.y - 260 });
    await sleep(500);
    s = await state(page);
    check(s.codex_scroll > 120 && !s.inspect, `one-finger drag on a tile scrolls the Codex (${s.codex_scroll}px), no tile opened ${JSON.stringify(s.tip)} from ${JSON.stringify(tile)}`);
    await shot('05_codex_scrolled');
    const before = s.codex_scroll;
    // two fingers, upward again (scroll further)
    const a = { x: VP.width / 2 - 50, y: 640 }, b = { x: VP.width / 2 + 50, y: 640 };
    await touch(cdp, 'touchStart', [a, b]);
    await sleep(60);
    for (let k = 1; k <= 10; k++) {
      await touch(cdp, 'touchMove', [{ x: a.x, y: a.y - 22 * k }, { x: b.x, y: b.y - 22 * k }]);
      await sleep(30);
    }
    await touch(cdp, 'touchEnd', []);
    await sleep(700);
    s = await state(page);
    check(s.codex_scroll > before + 60 && !s.inspect, `two fingers scroll the Codex (${before} -> ${s.codex_scroll}px)`);
    await shot('05b_codex_two_fingers');
  } catch (e) {
    errors.push('EXCEPTION ' + e.message);
  }
  await browser.close();
  console.log('errors: ' + (errors.length ? errors.join(' || ') : 'none'));
  process.exit(errors.length ? 1 : 0);
})();
