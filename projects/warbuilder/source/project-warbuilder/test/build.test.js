// Build smoke test: tools/build.js assembles a complete, self-contained page (in memory, nothing written).
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { SRC } = require('./helpers');
const B = require('../tools/build.js');

const { html } = B.build({ write: false });
const dataLine = name => { const m = html.match(new RegExp(`^const ${name}=(.*);$`, 'm')); assert.ok(m, name); return JSON.parse(m[1]); };

test('the page has a real document wrapper (standards mode, mobile viewport)', () => {
  assert.ok(html.startsWith('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">'));
  assert.match(html, /<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">/);
  assert.match(html, /<\/head>\n<body>\n/);
  assert.ok(html.trimEnd().endsWith('</body>\n</html>'));
  assert.doesNotMatch(html, /@inline:/, 'every shell marker is filled');
});

test('everything is inlined: CSS, sprite, engine, UI, art and card faces', () => {
  assert.ok(html.includes(B.minifyCss(fs.readFileSync(path.join(SRC, 'style.css'), 'utf8'))), 'style.css (minified)');
  assert.ok(html.includes(fs.readFileSync(path.join(SRC, 'ui.js'), 'utf8')));
  assert.ok(html.includes('<symbol id="i-move"'));
  const art = dataLine('ART'), gunArt = dataLine('GUNART'), locArt = dataLine('LOCART'), faces = dataLine('FACES');
  assert.equal(Object.keys(art).length, fs.readdirSync(path.join(SRC, 'webart')).filter(f => f.endsWith('.webp')).length);
  assert.ok(Object.keys(gunArt).includes('pistol-0'));
  assert.deepEqual(Object.keys(locArt).sort(), ['E01', 'E02', 'E03', 'E04', 'E05', 'E06', 'E07', 'E08']);
  for (const v of [...Object.values(art), ...Object.values(gunArt), ...Object.values(locArt)]) assert.match(v, /^data:image\/[a-z+]+;base64,/);
  assert.equal(Object.keys(faces).length, 98);
  assert.match(dataLine('FACESPRITE'), /^<svg[\s\S]*<\/svg>$/);
  assert.match(dataLine('FACECSS'), /\.fw\{position:relative/);
  for (const l of html.split('\n').filter(l => /^const (ART|GUNART|FACES|LOCART|FACECSS|FACESPRITE)=/.test(l))) assert.doesNotMatch(l, /<\/script/i, 'data cannot close its <script>');
  // faces keep the print-and-play's art/*.jpg links; ui.js swaps them for the inlined art at runtime
  assert.ok(fs.readFileSync(path.join(SRC, 'ui.js'), 'utf8').includes('src="art\\/'));
});

test('the inlined engine runs in a browser-like global and exposes window.WD', () => {
  const m = html.match(/<script>\n(\/\* WARZONE DECKBUILDER[\s\S]*?)\n<\/script>/);
  assert.ok(m, 'engine script block');
  const win = {}; vm.runInNewContext(m[1], { window: win, globalThis: win });
  assert.equal(typeof win.WD.newGame, 'function');
  const s = win.WD.newGame({ seed: 1 }); let n = 0;
  while (!s.over && n++ < 400) assert.ok(win.WD.aiTurn(s, s.turn).ok);
  assert.ok(s.over);
});

test('inlineImages() reads one folder, sorted, keyed by file name', () => {
  const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'wb-art-'));
  try {
    fs.writeFileSync(path.join(tmp, 'b.png'), Buffer.from([1, 2])); fs.writeFileSync(path.join(tmp, 'a.webp'), Buffer.from([3]));
    fs.writeFileSync(path.join(tmp, 'notes.txt'), 'x'); fs.mkdirSync(path.join(tmp, 'sub'));
    assert.deepEqual(B.inlineImages(tmp), { a: 'data:image/webp;base64,Aw==', b: 'data:image/png;base64,AQI=' });
    fs.writeFileSync(path.join(tmp, 'a.png'), Buffer.from([4]));
    assert.throws(() => B.inlineImages(tmp), /Two images named "a"/);
  } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
});

// ---------- size (DESIGN_REVIEW Q4: single file <= 1.5 MB, first load < 2 s on 4G) ----------
test('the build stays under the 1.5 MB budget', () => {
  const bytes = Buffer.byteLength(html);
  assert.ok(bytes <= 1500000, `build/index.html is ${bytes.toLocaleString('en-US')} bytes; budget 1,500,000. Re-encode new art with src/webart/reencode_art.py`);
});

test('web art is sized to display (WebP, capped widths)', () => {
  const webpWidth = buf => { // VP8 / VP8L / VP8X headers
    const kind = buf.toString('ascii', 12, 16);
    if (kind === 'VP8 ') return buf.readUInt16LE(26) & 0x3fff;
    if (kind === 'VP8L') return 1 + (buf.readUInt16LE(21) & 0x3fff);
    if (kind === 'VP8X') return 1 + buf.readUIntLE(24, 3);
    throw new Error('not a WebP file');
  };
  for (const [sub, cap] of [['', 280], ['guns', 280], ['locs', 336]]) {
    const dir = path.join(SRC, 'webart', sub);
    const files = fs.readdirSync(dir).filter(f => /\.(webp|png|jpe?g|avif)$/i.test(f));
    assert.ok(files.length > 0, dir);
    for (const f of files) {
      assert.match(f, /\.webp$/, `${sub}/${f} should be WebP`);
      const buf = fs.readFileSync(path.join(dir, f));
      assert.equal(buf.toString('ascii', 0, 4) + buf.toString('ascii', 8, 12), 'RIFFWEBP', f);
      assert.ok(webpWidth(buf) <= cap, `${sub}/${f} is ${webpWidth(buf)} px wide (cap ${cap})`);
    }
  }
});

test('minifyCss() keeps strings, url(), calc() and descendant pseudo-selectors intact', () => {
  const css = `/* c */ .a  :hover , .b > .c {\n  content: " /* not a comment */ ; } ";\n  width: calc(100% - 2px);\n  background: url(data:image/svg+xml,a%20b) , url( "x y.png" );\n}\n@media (max-width: 600px) { .d { grid-template-areas: "a  b" 'c  d'; } }\n`;
  assert.equal(B.minifyCss(css),
    '.a :hover,.b>.c{content:" /* not a comment */ ; } ";width:calc(100% - 2px);background:url(data:image/svg+xml,a%20b),url( "x y.png" )}@media (max-width:600px){.d{grid-template-areas:"a  b" \'c  d\'}}');
  assert.equal(B.minifyCss('a{content:"\\"";b:1}'), 'a{content:"\\"";b:1}', 'escaped quote');
  assert.throws(() => B.minifyCss('a{content:"x}'), /unclosed string/);
  assert.throws(() => B.minifyCss('a{} /* x'), /unclosed comment/);
});

test('--no-minify keeps style.css and the card-face HTML exactly as written', () => {
  const raw = B.build({ write: false, minify: false }).html;
  assert.ok(raw.includes(fs.readFileSync(path.join(SRC, 'style.css'), 'utf8')));
  assert.ok(raw.length > html.length);
  // collapsing whitespace in the faces is only safe while nothing in them preserves whitespace
  const gen = B.generateFaces();
  assert.doesNotMatch(gen.css, /white-space\s*:\s*(pre|break-spaces)/);
  assert.doesNotMatch(Object.values(gen.faces).join(''), /<(pre|textarea)\b/i);
  assert.equal(B.collapseHtml(' <b>1</b>\n   <i>2</i> '), '<b>1</b> <i>2</i>');
});
