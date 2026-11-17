// DeadDraw v3 ("Kill Stacks") web smoke test: loads the packaged export in headless Chromium at
// phone landscape and portrait viewports and plays real taps (touch) through title -> map -> street:
// the first-run hint, the active-weapon toggle (melee / gun), a zombie attack that lands on the
// gun's kill stack, Run, long-press (touch) and right-click inspects (gun, wave stack, pile, room),
// opening a room (cards fly into the pile) and its machine. dd-save: reloads the page mid-run and
// continues from the title (the state must match), then taps the "run resumed" banner away.
// Then smoke-query screens: open rooms, stacks, rule lock, gun sheet, Bench / Wall Rack / Patch
// Press sheets, the three bosses (Patient Zero: NO ESCAPE), a finishing kill (collect + challenge
// stamp, captured mid-animation), a wave shuffle-in, Patch chips + Lookout, zooms, safehouse, end.
// dd-ux-v4 (Door row): the WAVE banner (tap skips it), the ? Glossary (long press a row), the
// Codex from the title (a filter chip), long press on the Run button (its tooltip, not a Run).
// ui-pass-3 (explain once): on the played path (title -> map -> street) each concept the player
// meets is explained once in a callout beside its thing; the smoke checks the first ones (inspect on the
// title, district on the map, the street first), that each callout is on screen and that dismissing it
// (Got it, or a tap anywhere) never changes the game; a seen concept doesn't come back after the reload.
// Every tappable thing must be inside the viewport; console errors fail the run.
// Usage: node smoke_web.js <url-of-index.html> <screenshot-dir>
// The game publishes window.ddState (screen, hp, wave, pile, points, stacks, tappable rects in CSS px).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const URL = process.argv[2];
// dd-ui-clean: DD_SKIN=a|b|c runs the whole smoke in that UI skin (&skin= on every page load)
const SKIN_Q = process.env.DD_SKIN ? 'skin=' + process.env.DD_SKIN : '';
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
    await sleep(120);
  }
  throw new Error('timeout waiting for ' + what + ' state=' + JSON.stringify(await state(page)).slice(0, 400));
}

function center(it) { return { x: it.x + it.w / 2, y: it.y + it.h / 2 }; }

// A tap queues its start and end together (the end is sent without waiting for the start's ack):
// on a loaded machine an awaited touchStart can be acked late, and the page would then see a
// 60 ms tap as a long press (a zoom).
async function touchTap(cdp, p) {
  const a = cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y }] });
  await sleep(60);
  const b = cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await Promise.all([a, b]);
  await sleep(250);
}

async function touchHold(cdp, p, ms = 1000) {
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

function offscreen(s, vp) {
  return s.items.filter((i) => i.x < -1 || i.y < -1 || i.x + i.w > vp.width + 1 || i.y + i.h > vp.height + 1)
    .map((i) => (i.text || i.tag || i.title || i.type) + '@' + Math.round(i.x) + ',' + Math.round(i.y));
}

const card = (idx) => (i) => i.type === 'card' && i.index === idx;
const gameOf = (x) => JSON.stringify({ screen: x.screen, hp: x.hp, wave: x.wave, pile: x.pile, points: x.points, street: x.street, stacks: x.stacks, active: x.active, resolved: x.resolved });
const btn = (name) => (i) => i.type === 'button' && i.name === name;

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
    const shot = async (n) => { const f = path.join(OUT, `dd3_${vp.name}_${n}.png`); await page.screenshot({ path: f }); results.push(f); };
    const cdp = await ctx.newCDPSession(page);
    const log = (m) => console.log(`[${vp.name}] ${m}`);
    const closeInspect = async () => { await touchTap(cdp, { x: vp.width / 2, y: 8 }); return waitFor(page, (x) => !x.inspect, 'inspect closed'); };
    // ui-pass-3: waits for the callouts due now (each concept once), checks each, dismisses it with Got it
    const seenTips = [];
    const tips = async (where, waitMs = 1400) => {
      const ids = [];
      for (let k = 0; k < 10; k++) {
        const t0 = Date.now(); let s = await state(page);
        while (!s.hint && Date.now() - t0 < waitMs) { await sleep(150); s = await state(page); }
        if (!s.hint) break;
        const id = s.hint; const g0 = gameOf(s);
        if (seenTips.includes(id)) errors.push(`callout ${id} came back (${where})`);
        const c = s.callout || {};
        if (!(c.w > 0) || c.x < -1 || c.y < -1 || c.x + c.w > vp.width + 1 || c.y + c.h > vp.height + 1) errors.push(`callout ${id} off screen (${where}) ` + JSON.stringify(c));
        if (ids.length === 0 && shotTips) { await sleep(250); await shot('tip_' + where + '_' + id); }
        const ok = s.items.find((i) => i.type === 'button' && i.name === 'HintOk');
        if (!ok) { errors.push('callout without Got it: ' + id); break; }
        await sleep(450); // a tap in the callout's first 350 ms is eaten without dismissing it
        // alternate: Got it, then a tap on an empty corner (both only dismiss)
        await touchTap(cdp, k % 2 === 0 ? center(ok) : { x: 6, y: vp.height - 6 });
        s = await waitFor(page, (x) => x.hint !== id, 'callout ' + id + ' dismissed', 4000);
        if (gameOf(s) !== g0) errors.push(`dismissing ${id} changed the game: ${g0} -> ${gameOf(s)}`);
        ids.push(id); seenTips.push(id);
        waitMs = 900;
      }
      if (ids.length) log(`tips (${where}): ${ids.join(', ')}`);
      return ids;
    };
    const shotTips = true;
    const checkOff = (s, where) => { const off = offscreen(s, vp); if (off.length && !s.inspect) errors.push(`OFFSCREEN ${where}: ` + off.join(' ')); };
    try {
      await page.goto(URL + (SKIN_Q ? '?' + SKIN_Q : ''), { waitUntil: 'load' });
      let s = await waitFor(page, (x) => x.screen === 'TITLE', 'title', 90000);
      log(`title up, portrait=${s.portrait}`); await sleep(400); await shot('01_title');
      const t0tips = await tips('title', 2500);
      if (t0tips[0] !== 'inspect') errors.push('title: first concept is not hold-to-read: ' + t0tips.join(','));
      s = await state(page);
      // dd-ux-v4: the Codex from the title, a filter chip, close
      await touchTap(cdp, center(find(s, btn('CodexButton'), 'Codex button')));
      s = await waitFor(page, (x) => x.overlay === 'codex', 'codex open'); await sleep(300); await shot('01b_codex');
      checkOff({ items: s.items.filter((i) => i.name === 'CloseOverlay' || (i.name || '').startsWith('Type_')) }, 'codex chips');
      await touchTap(cdp, center(find(s, btn('Type_guns'), 'Guns chip')));
      await sleep(400); await shot('01c_codex_guns');
      s = await state(page);
      await touchTap(cdp, center(find(s, btn('CloseOverlay'), 'close codex')));
      s = await waitFor(page, (x) => x.overlay === '', 'codex closed');
      await touchHold(cdp, center(find(s, (i) => i.type === 'card' && i.kind === 'S', 'survivor card')));
      s = await waitFor(page, (x) => x.inspect, 'survivor inspect');
      s = await closeInspect();
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Start run'), 'start button')));
      s = await waitFor(page, (x) => x.screen === 'MAP', 'map'); log('map'); await shot('02_map');
      const mtips = await tips('map', 2500);
      if (mtips[0] !== 'district') errors.push('map: first concept is not districts: ' + mtips.join(','));
      s = await state(page);
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Enter'), 'enter button')));
      s = await waitFor(page, (x) => x.screen === 'STREET', 'street');
      log(`street hp=${s.hp} wave=${s.wave} pile=${s.pile} pts=${s.points} hint=${s.hint}`);
      await sleep(250); await shot('03_street_enter_shuffle');
      s = await waitFor(page, (x) => x.banner_open, 'WAVE 1 banner'); await sleep(500); await shot('03b_wave1_banner');
      if (s.banner !== 'WAVE 1') errors.push('first banner is not WAVE 1: ' + s.banner);
      // skip it with a tap on the empty top margin (if it already ended, that tap does nothing)
      await touchTap(cdp, { x: vp.width / 2, y: 4 });
      s = await waitFor(page, (x) => !x.banner_open, 'a tap skips the banner', 3000);
      s = await waitFor(page, (x) => !!x.hint, 'the first street concept', 4000); await sleep(300); await shot('04_street_first_concept');
      checkOff(s, 'street');
      // (the tap that skips the WAVE banner may land on the first callout: it only dismisses it)
      if (s.hint !== 'street' && !(s.seen || []).includes('street')) errors.push('first street concept is not the street: ' + s.hint);
      await tips('street');
      s = await state(page);
      for (const id of ['street', 'active_weapon']) if (!(s.seen || []).includes(id)) errors.push('street: concept not explained: ' + id + ' seen=' + JSON.stringify(s.seen));
      s = await state(page); await shot('05_street_after_concepts');
      // active weapon: melee then the pistol
      await touchTap(cdp, center(find(s, card(202), 'melee tile')));
      s = await waitFor(page, (x) => x.active === 2, 'melee active'); await shot('06_melee_active');
      await tips('melee', 1100); s = await state(page);
      await touchTap(cdp, center(find(s, card(200), 'gun 1')));
      s = await waitFor(page, (x) => x.active === 0, 'pistol active');
      await tips('pistol', 1100); s = await state(page);
      // attack a zombie with the pistol: it lands on the stack
      const z = s.items.find((i) => i.type === 'card' && (i.kind === 'Z' || i.kind === 'F') && i.index >= 0 && i.index < 100);
      if (z) {
        const before = s.resolved;
        await touchTap(cdp, center(z));
        await sleep(120); await shot('07_kill_flying_to_stack');
        s = await waitFor(page, (x) => x.resolved !== before || x.phase !== 'STREET', 'attack resolved');
        await sleep(500); s = await state(page);
        log(`-> ${s.log} stacks=${JSON.stringify(s.stacks)} pts=${s.points}`); await shot('08_after_kill_stack');
      }
      await tips('after_kill');
      s = await state(page);
      // inspect: long press the gun, right click a wave deck, long press the pile and a room
      await touchHold(cdp, center(find(s, card(200), 'gun 1')));
      s = await waitFor(page, (x) => x.inspect, 'gun inspect'); await shot('09_inspect_gun_longpress');
      s = await closeInspect();
      const w = find(s, card(300), 'wave stack');
      await page.mouse.click(center(w).x, center(w).y, { button: 'right' });
      s = await waitFor(page, (x) => x.inspect, 'wave inspect'); await shot('10_inspect_wave_rightclick');
      await page.mouse.click(vp.width / 2, 8);
      s = await waitFor(page, (x) => !x.inspect, 'closed');
      await touchHold(cdp, center(find(s, card(400), 'pile')));
      s = await waitFor(page, (x) => x.inspect, 'pile inspect'); await shot('11_inspect_pile');
      s = await closeInspect();
      await touchHold(cdp, center(find(s, card(100), 'room 1')));
      s = await waitFor(page, (x) => x.inspect, 'room inspect'); await shot('12_inspect_room');
      s = await closeInspect();
      // dd-ux-v4: the ? opens the Glossary; long press a row reads it
      await touchTap(cdp, center(find(s, btn('HelpButton'), 'help button')));
      s = await waitFor(page, (x) => x.overlay === 'glossary', 'glossary open'); await sleep(300); await shot('12b_glossary');
      await touchHold(cdp, { x: vp.width / 2, y: Math.min(vp.height - 40, 170) });
      s = await waitFor(page, (x) => x.inspect, 'glossary row tooltip'); await shot('12c_glossary_row_tip');
      s = await closeInspect();
      await touchTap(cdp, center(find(s, btn('CloseOverlay'), 'close glossary')));
      s = await waitFor(page, (x) => x.overlay === '', 'glossary closed');
      // long press Run: its tooltip, and it does NOT run
      const rbl = s.items.find((i) => btn('Run')(i));
      if (rbl) {
        const hp0 = s.hp;
        await touchHold(cdp, center(rbl));
        s = await waitFor(page, (x) => x.inspect, 'run tooltip'); await shot('12d_run_tooltip');
        s = await closeInspect();
        if (s.hp !== hp0) errors.push('a long press on Run ran');
      }
      // Run (if allowed now)
      const rb = s.items.find((i) => btn('Run')(i) && !i.disabled);
      if (rb) {
        await touchTap(cdp, center(rb));
        await sleep(150); await shot('13_run_back_into_pile');
        s = await waitFor(page, (x) => x.items.some((i) => btn('Run')(i) && i.disabled), 'ran');
        log('run: ' + s.log);
        await tips('after_run');
      }
      // dd-save: reload mid-run, Continue from the title: same run, same state
      s = await state(page);
      const pick = (x) => ({ hp: x.hp, wave: x.wave, pile: x.pile, points: x.points, street: x.street, stacks: x.stacks, active: x.active });
      const before = pick(s);
      // dd-save-fix: the run is saved (and mirrored to localStorage) when the Run resolves, so 1 s is plenty
      await sleep(1000);
      await page.reload({ waitUntil: 'load' });
      s = await waitFor(page, (x) => x.screen === 'TITLE', 'title after reload', 90000);
      await sleep(300); await shot('14_title_continue');
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('CONTINUE RUN'), 'continue button')));
      s = await waitFor(page, (x) => x.screen === 'STREET', 'resumed street');
      const after = pick(s);
      log('resumed: ' + JSON.stringify(after));
      if (JSON.stringify(before) !== JSON.stringify(after)) errors.push('RESUME MISMATCH ' + JSON.stringify(before) + ' vs ' + JSON.stringify(after));
      s = await waitFor(page, (x) => x.banner_open, 'resume banner');
      await touchTap(cdp, center(s.banner_rect));
      s = await waitFor(page, (x) => !x.banner_open, 'banner dismissed by a tap', 3000);
      // ui-pass-3: concepts seen before the reload stay seen (the profile mirror)
      await tips('resumed');
      // other screens via the smoke query: [query, name, action?]
      const queries = [
        ['screen=street&seed=11&points=60', 'rooms_affordable', async () => {
          let t = await state(page);
          await touchTap(cdp, center(find(t, btn('Open0'), 'OPEN 1')));
          await sleep(200); await shot('room_open_cards_flying');
          t = await waitFor(page, (x) => x.opened === 1, 'room opened');
          t = await waitFor(page, (x) => x.banner_open, 'room open banner', 4000); await shot('room_open_banner');
          await touchTap(cdp, center(t.banner_rect));
          t = await waitFor(page, (x) => !x.banner_open, 'banner skipped', 3000);
          await touchTap(cdp, center(find(t, btn('Use0'), 'USE')));
          await waitFor(page, (x) => x.sheet === 'machine', 'machine sheet'); await shot('room_wall_rack_sheet');
        }],
        ['screen=street&seed=5&gun2=crossbow&stack1=3,5,6&stack2=4,5,6&open=2', 'stacks_two_guns'],
        ['screen=street&seed=5&survivor=imani&gun1=rifle&stack1=2&active=0', 'rule_lock'],
        ['screen=street&seed=3&sheet=gun', 'gun_card_sheet'],
        ['screen=street&seed=3&sheet=machine2&gun1=rifle&stack1=7,2&gun2=crossbow&stack2=4', 'bench_sheet'],
        ['screen=street&seed=3&sheet=patch', 'patch_press_pick'],
        ['screen=street&seed=2&near=1', 'finish', async () => {
          const t = await state(page);
          await touchTap(cdp, center(find(t, card(0), 'zombie 0')));
          await sleep(350); await shot('finish_collect_midway');
          await sleep(650); await shot('finish_challenge_stamp');
          const u = await state(page); log('finish: ' + u.log + ' finished=' + u.finished + ' fx=' + JSON.stringify(u.fx));
          if (u.finished !== 1) errors.push('near-finish kill did not finish the gun');
        }],
        ['screen=street&seed=4&lastcards=1', 'wave_shuffle', async () => {
          for (let k = 0; k < 3; k++) { const t = await state(page); await touchTap(cdp, center(find(t, card(0), 'card 0'))); await sleep(150); }
          await sleep(200); await shot('wave2_shuffle_in');
          let u = await waitFor(page, (x) => x.wave === 2 && x.banner_open, 'wave 2 banner'); await sleep(500); await shot('wave2_banner');
          log('wave: ' + u.banner);
          if (u.banner !== 'WAVE 2') errors.push('wave banner: ' + u.banner);
          await touchTap(cdp, { x: vp.width / 2, y: 4 });
          u = await waitFor(page, (x) => !x.banner_open, 'a tap skips the WAVE banner', 2500);
        }],
        ['screen=street&seed=9&boss=1', 'boss_groundskeeper'],
        ['screen=street&seed=9&boss=1&district=1', 'boss_horde'],
        ['screen=street&seed=9&boss=1&district=2', 'boss_patient_zero_no_escape'],
        ['screen=street&seed=6&patches=lookout,brawler,thick_jacket,bounty&gun2=lever&stack2=3,7,2', 'patches_lookout'],
        ['screen=street&seed=6&inspect=zombie&gun1=rifle&stack1=5', 'inspect_zombie'],
        ['screen=street&seed=6&inspect=gun1&gun1=rifle&stack1=8,6', 'inspect_gun'],
        ['screen=street&seed=6&inspect=stack&stack1=4,2', 'inspect_stack_card'],
        ['screen=street&seed=6&inspect=boss&district=2', 'inspect_boss'],
        ['screen=safehouse', 'safehouse'],
        ['screen=end', 'end'],
        ['screen=map', 'map'],
      ];
      let n = 20;
      for (const [q, name, act] of queries) {
        await page.goto(URL + '?' + q + (SKIN_Q ? '&' + SKIN_Q : ''), { waitUntil: 'load' });
        s = await waitFor(page, (x) => x.screen !== 'TITLE', q, 90000);
        await sleep(2300);
        s = await state(page);
        await shot(String(n++) + '_' + name);
        if (s.screen === 'STREET') checkOff(s, q);
        log(`${q} -> ${s.screen} wave=${s.wave} pile=${s.pile} pts=${s.points} sheet=${s.sheet} stacks=${JSON.stringify(s.stacks)}`);
        if (act) await act();
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
