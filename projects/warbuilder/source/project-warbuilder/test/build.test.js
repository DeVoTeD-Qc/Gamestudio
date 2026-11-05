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
  assert.ok(html.includes(fs.readFileSync(path.join(SRC, 'style.css'), 'utf8')));
  assert.ok(html.includes(fs.readFileSync(path.join(SRC, 'ui.js'), 'utf8')));
  assert.ok(html.includes('<symbol id="i-move"'));
  const art = dataLine('ART'), gunArt = dataLine('GUNART'), locArt = dataLine('LOCART'), faces = dataLine('FACES');
  assert.equal(Object.keys(art).length, fs.readdirSync(path.join(SRC, 'webart')).filter(f => f.endsWith('.webp')).length);
  assert.ok(Object.keys(gunArt).includes('pistol-0'));
  assert.deepEqual(Object.keys(locArt).sort(), ['E01', 'E02', 'E03', 'E04', 'E05', 'E06', 'E07', 'E08']);
  for (const v of [...Object.values(art), ...Object.values(gunArt), ...Object.values(locArt)]) assert.match(v, /^data:image\/[a-z+]+;base64,/);
  assert.equal(Object.keys(faces).length, 116);
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
