// DeadDraw web smoke test: loads the packaged export in headless Chromium at phone landscape and
// portrait viewports, plays real taps (touch) through title -> map -> street, resolves a card,
// retreats, long-presses (touch) and right-clicks to inspect, and saves screenshots.
// Usage: node smoke_web.js <url-of-index.html> <screenshot-dir>
// The game publishes window.ddState (screen, hp, tappable rects in CSS px) on the Web build.
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
  if (!it) throw new Error('not on screen: ' + what + ' items=' + JSON.stringify(s.items.map((i) => i.text || i.title)).slice(0, 600));
  return it;
}

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const results = [];
  for (const vp of VIEWPORTS) {
    const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const page = await ctx.newPage();
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', (e) => errors.push(String(e)));
    const shot = async (n) => { const f = path.join(OUT, `dd_${vp.name}_${n}.png`); await page.screenshot({ path: f }); results.push(f); };
    const cdp = await ctx.newCDPSession(page);
    const log = (m) => console.log(`[${vp.name}] ${m}`);
    try {
      await page.goto(URL, { waitUntil: 'load' });
      let s = await waitFor(page, (x) => x.screen === 'TITLE', 'title', 90000);
      log(`title up, portrait=${s.portrait}`); await sleep(400); await shot('1_title');
      // long-press a survivor card (touch) -> zoom
      await touchHold(cdp, center(find(s, (i) => i.type === 'card' && i.kind === 'S', 'survivor card')));
      s = await waitFor(page, (x) => x.inspect, 'survivor inspect'); await shot('2_inspect_survivor');
      await touchTap(cdp, { x: vp.width / 2, y: 20 });
      s = await waitFor(page, (x) => !x.inspect, 'inspect closed');
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Start run'), 'start button')));
      s = await waitFor(page, (x) => x.screen === 'MAP', 'map'); log('map'); await shot('3_map');
      await touchTap(cdp, center(find(s, (i) => i.type === 'button' && i.text.startsWith('Enter'), 'enter button')));
      s = await waitFor(page, (x) => x.screen === 'STREET', 'street'); log(`street hp=${s.hp} cards=${s.street}`); await shot('4_street');
      // retreat first (real button), then the deck counter shows the bottom cards
      const rb = s.items.find((i) => i.type === 'button' && i.text.startsWith('Retreat (') && !i.disabled);
      if (rb) {
        await touchTap(cdp, center(rb));
        s = await waitFor(page, (x) => x.log && x.log.includes('bottom'), 'retreat feedback'); log('retreated: ' + s.log);
        await touchHold(cdp, center(find(s, (i) => i.type === 'card' && i.kind === 'D', 'deck counter')));
        s = await waitFor(page, (x) => x.inspect, 'deck inspect'); await shot('5_inspect_deck_bottom');
        await touchTap(cdp, { x: vp.width / 2, y: 20 });
        s = await waitFor(page, (x) => !x.inspect, 'closed');
        const rb2 = s.items.find((i) => i.type === 'button' && i.text.startsWith('Retreat'));
        log('retreat button now: ' + (rb2 ? rb2.text + ' disabled=' + rb2.disabled : 'none'));
      }
      // select a street card and resolve it with the first option
      const card = find(s, (i) => i.type === 'card' && i.index === 0, 'street card 0');
      await touchTap(cdp, center(card));
      s = await waitFor(page, (x) => x.items.some((i) => i.type === 'button' && !i.text.startsWith('Retreat') && i.text !== 'Log' && i.text !== 'Settings' && !i.disabled), 'options');
      await shot('6_card_selected');
      const before = s.resolved;
      const opt = find(s, (i) => i.type === 'button' && !i.text.startsWith('Retreat') && !i.text.startsWith('Slip') && i.text !== 'Log' && i.text !== 'Settings' && !i.disabled, 'option');
      log('option: ' + opt.text.replace(/\n/g, ' '));
      await touchTap(cdp, center(opt));
      s = await waitFor(page, (x) => x.resolved !== before || x.phase !== 'STREET', 'resolved');
      log(`resolved -> log: ${s.log} hp=${s.hp}`); await sleep(150); await shot('7_after_resolve');
      // right click the weapon slot (desktop path)
      const w = find(s, (i) => i.type === 'card' && i.kind === 'W' && i.index === -1, 'weapon slot');
      await page.mouse.click(center(w).x, center(w).y, { button: 'right' });
      s = await waitFor(page, (x) => x.inspect, 'weapon inspect'); await shot('8_inspect_weapon_rightclick');
      await page.mouse.click(vp.width / 2, 20);
      // other screens via the smoke query
      for (const q of ['screen=safehouse', 'screen=end', 'screen=street&survivor=imani&select=0&seed=3', 'screen=street&seed=7&notch=3', 'screen=map']) {
        await page.goto(URL + '?' + q, { waitUntil: 'load' });
        s = await waitFor(page, (x) => x.screen !== 'TITLE', q, 90000);
        await sleep(500);
        await shot('9_' + q.split('&')[0].replace('screen=', '') + (q.includes('imani') ? '_imani' : '') + (q.includes('notch') ? '_notched' : ''));
        log(`${q} -> ${s.screen}`);
      }
    } catch (e) {
      errors.push('SMOKE FAILURE: ' + e.message);
      await shot('error');
    }
    log('errors: ' + (errors.length ? errors.join(' | ') : 'none'));
    await ctx.close();
  }
  await browser.close();
  console.log('SCREENSHOTS\n' + results.join('\n'));
})();
