// Frame-accurate capture of replay.html: sets the timeline clock per frame and screenshots it.
// Usage: NODE_PATH=$(npm root -g) node record.js <outDir> [fromSec] [toSec] [gameDir]
//   gameDir: a recording made by record_game.js (frames.json + frames/); its frames are shown in the game scene.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = process.argv[2]; const FROM = +(process.argv[3] || 0); const TO = process.argv[4] ? +process.argv[4] : null;
const GAME = process.argv[5] ? path.resolve(process.argv[5]) : null;
const HERE = __dirname;
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const TL = JSON.parse(fs.readFileSync(path.join(HERE, 'timeline.json'), 'utf8'));
  if (GAME) TL.gameDir = 'file://' + GAME;
  const frames = GAME && fs.existsSync(path.join(GAME, 'frames.json')) ? JSON.parse(fs.readFileSync(path.join(GAME, 'frames.json'))) : [];
  const fps = TL.fps, end = TO ?? TL.duration;
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.addInitScript(([tl, fr]) => { window.TIMELINE = tl; window.GAME_FRAMES = fr; }, [TL, frames]);
  page.on('pageerror', e => console.error('pageerror', e.message));
  await page.goto('file://' + path.join(HERE, 'replay.html'));
  await page.evaluate(() => window.__ready);
  const n0 = Math.round(FROM * fps), n1 = Math.round(end * fps);
  const t0 = Date.now();
  for (let n = n0; n < n1; n++) {
    await page.evaluate(async t => {
      window.render(t);
      const imgs = [...document.images].filter(i => i.getAttribute('src') && !i.complete);
      await Promise.all(imgs.map(i => i.decode().catch(() => {})));
    }, n / fps);
    await page.screenshot({ path: path.join(OUT, String(n).padStart(6, '0') + '.jpg'), type: 'jpeg', quality: 93 });
    if (n % 300 === 0) console.log('frame', n, '/', n1, ((Date.now() - t0) / 1000).toFixed(0) + 's');
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
