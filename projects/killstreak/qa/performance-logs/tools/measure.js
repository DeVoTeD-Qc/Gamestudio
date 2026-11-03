const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const URL = 'http://127.0.0.1:8060/index.html';
const SHOTS = '/home/user/Gamestudio/projects/killstreak/qa/screenshots/';
const RUNS = parseInt(process.env.RUNS || '3');
const GL = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];

async function throttle(page) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 40,
    downloadThroughput: process.env.NOTHROTTLE ? -1 : 20e6 / 8, uploadThroughput: process.env.NOTHROTTLE ? -1 : 5e6 / 8,
  });
  let bytes = 0;
  cdp.on('Network.dataReceived', e => { bytes += e.encodedDataLength; });
  return () => bytes;
}

async function coldLoad(i, shot) {
  const browser = await chromium.launch({ args: GL });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const getBytes = await throttle(page);
  const errors = [];
  let titleAt = null, t0;
  page.on('console', m => {
    if (m.text().includes('Title: ready') && titleAt === null) titleAt = Date.now() - t0;
    if (m.type() === 'error') errors.push(m.text());
  });
  page.on('pageerror', e => errors.push(String(e)));
  t0 = Date.now();
  await page.goto(URL, { waitUntil: 'commit' });
  if (shot) {
    await page.waitForFunction(() => {
      const p = parseInt(document.getElementById('ks-pct')?.textContent || '0');
      return p >= 40;
    }, null, { timeout: 60000 });
    await page.screenshot({ path: SHOTS + 'p17-loading-desktop.png' });
  }
  const deadline = Date.now() + 60000;
  while (titleAt === null && Date.now() < deadline) await page.waitForTimeout(50);
  const times = await page.evaluate(() => window.ksLoadTimes);
  if (shot) { await page.waitForTimeout(600); await page.screenshot({ path: SHOTS + 'p17-title-after-load.png' }); }
  const res = { run: i, titleMs: titleAt, shell: times, transferredBytes: getBytes(), errors };
  await browser.close();
  return res;
}

async function portrait() {
  const browser = await chromium.launch({ args: GL });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();
  await page.goto(URL);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: SHOTS + 'p17-portrait-rotate.png' });
  // Landscape phone (844x390): rotate prompt should be hidden, loader or game visible.
  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(300);
  const hidden = await page.evaluate(() => getComputedStyle(document.getElementById('ks-rotate')).display);
  await page.screenshot({ path: SHOTS + 'p17-landscape-phone.png' });
  await browser.close();
  return { rotateDisplayInLandscape: hidden };
}

async function noWebGL() {
  const browser = await chromium.launch({ args: ['--disable-webgl', '--disable-webgl2', '--disable-gpu'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.goto(URL);
  await page.waitForTimeout(1000);
  const txt = await page.evaluate(() => document.getElementById('ks-error').innerText);
  await page.screenshot({ path: SHOTS + 'p17-error-no-webgl.png' });
  await browser.close();
  return txt;
}

(async () => {
  const out = { runs: [] };
  for (let i = 0; i < RUNS; i++) out.runs.push(await coldLoad(i, i === 0));
  out.portrait = await portrait();
  out.noWebGL = await noWebGL();
  console.log(JSON.stringify(out, null, 2));
})();
