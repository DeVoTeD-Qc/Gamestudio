// DeadDraw v2 web smoke test: loads the packaged export in headless Chromium at phone landscape and
// portrait viewports, plays real taps (touch) through title -> map -> street, fights a zombie with
// a weapon slot, reloads, skips (Skipped pile), opens a door and uses its machine, long-presses
// (touch) and right-clicks to inspect, and saves screenshots of the v2 screens (wave track, deck
// counter, doors, slots with magazine pips, last-street banner, boss street, safehouse, end).
// dd-save: reloads the page mid-run and continues from the title (the state must match), and taps
// the "run resumed" banner away.
// Usage: node smoke_web.js <url-of-index.html> <screenshot-dir>
// The game publishes window.ddState (screen, hp, wave, deck, points, tappable rects in CSS px).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const URL = process.argv[2];
const OUT = process.argv[3];
fs.mkdirSync(OUT, { recursive: true });

const VIEWPORTS = [
  { name: 'landscape', width: 844, height: 390 },
  { name: 'portrait', width: 390, height: 844 },
];

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function state(page) { return page.evaluate(() => window.ddState || null); }

async function waitFor(page, pred, what, ms = 60000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' state=' + JSON.stringify(await state(page)).slice(0, 400));
}

function center(it) { return { x: it.x + it.w / 2, y: it.y + it.h / 2 }; }

async function touchTap(cdp, p) {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y }] });
  await sleep(60);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(250);
}

async function touchHold(cdp, p, ms = 750) {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y }] });
  await sleep(ms);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(300);
}

function find(s, pred, what) {
  const it = s.items.find(pred);
  if (!it) throw new Error('not on screen: ' + what + ' items=' + JSON.stringify(s.items.map((i) => i.text || i.tag || i.title)).slice(0, 900));
  return it;
}

// every tappable thing must be inside the viewport (no clipped HUD on a phone)
function offscreen(s, vp) {
  return s.items.filter((i) => i.x < -1 || i.y < -1 || i.x + i.w > vp.width + 1 || i.y + i.h > vp.height + 1)
    .map((i) => (i.text || i.tag || i.title || i.type) + '@' + Math.round(i.x) + ',' + Math.round(i.y));
}

const isOption = (i) => i.type === 'button' && !i.disabled && /^(Service Pistol|Revolver|Compact SMG|Pump Shotgun|Hunting Rifle|Carbine|Belt-fed MG|Static Lance|Retrofit|Kitchen Knife|Crowbar|Cricket Bat|Machete|Fire Axe|Sledgehammer|BARE|INTO SLOT|SCRAP|Use|Take)/.test(i.text);

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const results = [];
  let failures = 0;
  for (const vp of VIEWPORTS) {
    const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const page = await ctx.newPage();
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', (e) => errors.push(String(e)));
    const shot = async (n) => { const f = path.join(OUT, `dd_${vp.name}_${n}.png`); await page.screenshot({ path: f }); results.push(f); };
    const cdp = await ctx.newCDPSession(page);
    const log = (m) => console.log(`[${vp.name}] ${m}`);
    const closeInspect = async () => { await touchTap(cdp, { x: vp.width / 2, y: 12 }); return waitFor(page, (x) => !x.inspect, 'inspect closed'); };
    try {
      await page.goto(URL, { waitUntil: 'load' });
      let s = await waitFor(page, (x) => x.screen === 'TITLE', 'title', 90000);
      log(`title up, portrait=${s.portrait}`); await sleep(400); await shot('01_title');
      await touchHold(cdp, center(find(s, (i) => i.type === 'card' && i.kind === 'S', 'survivor card')));
      s = await waitFor(page, (x) => x.inspect, 'survivor inspect'); await shot('02_inspect_survivor');
      s = await closeInspect();
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Start run'), 'start button')));
      s = await waitFor(page, (x) => x.screen === 'MAP', 'map'); log('map'); await shot('03_map');
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Enter'), 'enter button')));
      s = await waitFor(page, (x) => x.screen === 'STREET', 'street'); log(`street hp=${s.hp} wave=${s.wave} deck=${s.deck} pts=${s.points}`);
      await sleep(300); await shot('04_street_wave_banner');
      await sleep(1800); s = await state(page); await shot('05_street');
      const off = offscreen(s, vp);
      if (off.length) { errors.push('OFFSCREEN: ' + off.join(' ')); }
      // fight: tap a zombie, take the first weapon/bare option (previews show HP, ammo, points)
      let z = s.items.find((i) => i.type === 'card' && i.kind === 'Z' && i.index >= 0 && i.index < 100);
      if (z) {
        await touchTap(cdp, center(z));
        s = await waitFor(page, (x) => x.items.some(isOption), 'fight options');
        await shot('06_fight_options');
        const opt = s.items.find((i) => isOption(i) && !i.text.startsWith('BARE')) || find(s, isOption, 'option');
        log('fight: ' + opt.text.replace(/\n/g, ' '));
        const before = s.resolved;
        await touchTap(cdp, center(opt));
        s = await waitFor(page, (x) => x.resolved !== before || x.phase !== 'STREET', 'resolved');
        log(`-> ${s.log} ammo=${JSON.stringify(s.ammo)}`); await sleep(200); await shot('07_after_fight');
      }
      // reload (real button) when it is offered
      const rl = s.items.find((i) => i.type === 'button' && i.text.startsWith('RELOAD') && !i.disabled);
      if (rl) {
        log('reload: ' + rl.text.replace(/\n/g, ' '));
        await touchTap(cdp, center(rl));
        s = await waitFor(page, (x) => x.log && x.log.startsWith('Reloaded'), 'reload feedback');
        log('-> ' + s.log); await shot('08_after_reload');
      }
      // finish the street with any options, then skip the next one
      for (let k = 0; k < 4 && s.actions > 0; k++) {
        const c = s.items.find((i) => i.type === 'card' && i.index >= 0 && i.index < 100);
        if (!c) break;
        await touchTap(cdp, center(c));
        s = await state(page);
        const o = s.items.find((i) => isOption(i) && i.text.startsWith('BARE')) || s.items.find(isOption);
        if (!o) break;
        await touchTap(cdp, center(o));
        await sleep(300); s = await state(page);
      }
      const sk = s.items.find((i) => i.type === 'button' && i.text.startsWith('SKIP STREET') && !i.disabled);
      if (sk) {
        await touchTap(cdp, center(sk));
        s = await waitFor(page, (x) => x.skipped > 0, 'skip'); log(`skipped -> pile ${s.skipped}: ${s.log}`);
        await sleep(400); await shot('09_after_skip');
        await touchHold(cdp, center(find(s, (i) => i.type === 'card' && i.tag === 'SKIPPED PILE', 'skipped pile')));
        s = await waitFor(page, (x) => x.inspect, 'skipped inspect'); await shot('10_inspect_skipped_longpress');
        s = await closeInspect();
      }
      // right click the weapon slot (desktop path)
      const w = find(s, (i) => i.type === 'card' && i.index === 200, 'weapon slot 1');
      await page.mouse.click(center(w).x, center(w).y, { button: 'right' });
      s = await waitFor(page, (x) => x.inspect, 'slot inspect'); await shot('11_inspect_slot_rightclick');
      await page.mouse.click(vp.width / 2, 12);
      s = await waitFor(page, (x) => !x.inspect, 'closed');
      // door: long press shows price + unlocks; tap selects; the button shows the price
      const door = find(s, (i) => i.type === 'card' && i.index === 100, 'first door');
      await touchHold(cdp, center(door));
      s = await waitFor(page, (x) => x.inspect, 'door inspect'); await shot('12_inspect_door');
      s = await closeInspect();
      await touchTap(cdp, center(find(s, (i) => i.type === 'card' && i.index === 100, 'first door')));
      s = await state(page); await shot('13_door_selected');
      const ob = s.items.find((i) => i.type === 'button' && (i.text.startsWith('OPEN for') || i.text.startsWith('Open ')));
      log('door button: ' + (ob ? ob.text.replace(/\n/g, ' ') + ' disabled=' + ob.disabled : 'none'));
      // dd-save: reload the page mid-run, then Continue from the title: same run, same state
      s = await state(page);
      const before = { hp: s.hp, wave: s.wave, deck: s.deck, skipped: s.skipped, points: s.points, actions: s.actions, street: s.street };
      await sleep(1500);   // let user:// reach IndexedDB
      await page.reload({ waitUntil: 'load' });
      s = await waitFor(page, (x) => x.screen === 'TITLE', 'title after reload', 90000);
      await sleep(300); await shot('13b_title_continue');
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('CONTINUE RUN'), 'continue button')));
      s = await waitFor(page, (x) => x.screen === 'STREET', 'resumed street');
      const after = { hp: s.hp, wave: s.wave, deck: s.deck, skipped: s.skipped, points: s.points, actions: s.actions, street: s.street };
      log('resumed: ' + JSON.stringify(after));
      if (JSON.stringify(before) !== JSON.stringify(after)) errors.push('RESUME MISMATCH ' + JSON.stringify(before) + ' vs ' + JSON.stringify(after));
      s = await waitFor(page, (x) => x.banner_open, 'resume banner');
      await shot('13c_resumed_banner');
      await touchTap(cdp, center(s.banner_rect));
      s = await waitFor(page, (x) => !x.banner_open, 'banner dismissed by a tap', 3000);
      log('banner dismissed by tap');
      await shot('13d_resumed_street');
      // other screens via the smoke query
      const queries = [
        'screen=street&seed=11&open=2&points=40&room=0',
        'screen=street&seed=11&open=1&offer=1',
        'screen=street&seed=5&slot2=machete&notch=4&ammo=1&buff=steady_aim&laststreet=1',
        'screen=street&seed=5&skip=1&inspect=deck',
        'screen=street&seed=9&boss=1',
        'screen=street&survivor=imani&select=0&seed=3',
        'screen=safehouse',
        'screen=end',
        'screen=map',
      ];
      let n = 14;
      for (const q of queries) {
        await page.goto(URL + '?' + q, { waitUntil: 'load' });
        s = await waitFor(page, (x) => x.screen !== 'TITLE', q, 90000);
        await sleep(700);
        const name = q.replace(/screen=|seed=\d+&?|&/g, (m) => (m === '&' ? '_' : '')).replace(/=/g, '').replace(/_+$/, '');
        await shot(String(n++) + '_' + name);
        const off2 = offscreen(s, vp);
        if (off2.length && !s.inspect && s.screen === 'STREET') errors.push(`OFFSCREEN ${q}: ` + off2.join(' '));
        log(`${q} -> ${s.screen} wave=${s.wave} deck=${s.deck} pts=${s.points} pending=${s.pending}`);
      }
    } catch (e) {
      errors.push('SMOKE FAILURE: ' + e.message);
      await shot('error');
    }
    failures += errors.length;
    log('errors: ' + (errors.length ? errors.join(' | ') : 'none'));
    await ctx.close();
  }
  await browser.close();
  console.log('SCREENSHOTS\n' + results.join('\n'));
  process.exitCode = failures ? 1 : 0;
})();
