#!/usr/bin/env node
// tools/build.js: one-command build of the single-file HTML5 game.
//
//   npm run build                 → build/index.html
//   node tools/build.js --out FILE → another output path (the tests use this)
//   node tools/build.js --no-minify → keep CSS and card-face HTML as written (for debugging)
//
// Steps (all in memory, nothing is written into src/):
//   1. src/pnp/gen.js renders the print-and-play asset sheet; facesFromAssetSheet() turns it into
//      the FACES table (scoped CSS, icon sprite, one HTML string per card face). This replaces
//      `ASSETS=1 node gen.js` + faces_export.py + the faces.json file.
//   2. inlineImages() turns each art folder into { name: dataURI }.
//   3. The CSS and the card-face HTML are minified (minifyCss / collapseHtml; JS is left as written).
//   4. src/shell.html (doctype, viewport, fonts, body skeleton) gets the CSS, sprite, data, engine
//      and UI pasted into its `<!-- @inline:NAME -->` markers.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const DEFAULT_OUT = path.join(ROOT, 'build', 'index.html');

// ---------- art ----------
const MIME = { '.webp': 'image/webp', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.avif': 'image/avif', '.svg': 'image/svg+xml' };

// The only place images are encoded. Returns { baseName: 'data:<mime>;base64,...' } for every image
// directly in `dir` (not sub-folders), sorted by file name. A later art re-encode step only has to
// change the files in src/webart (any format in MIME works) or swap this function's body.
function inlineImages(dir) {
  const out = {};
  for (const f of fs.readdirSync(dir).sort()) {
    const ext = path.extname(f).toLowerCase();
    if (!MIME[ext] || !fs.statSync(path.join(dir, f)).isFile()) continue;
    const name = f.slice(0, -ext.length);
    if (name in out) throw new Error(`Two images named "${name}" in ${dir}`);
    out[name] = `data:${MIME[ext]};base64,` + fs.readFileSync(path.join(dir, f)).toString('base64');
  }
  return out;
}

// ---------- minify (build output only; src/ stays readable) ----------
// A small, conservative CSS minifier: strips comments and collapses whitespace, never touching the
// inside of strings or url(...). It only removes spaces next to { } ; , > and after a colon, which
// never changes meaning (it keeps spaces around + - * / for calc() and before ":" for selectors
// such as `.a :hover`). Saves ~15% of style.css; the tests check strings, calc() and selectors.
function minifyCss(css) {
  const keep = [];
  const stash = s => `\u0000${keep.push(s) - 1}\u0000`;
  // 1. pull out strings and url(...) bodies, drop comments (one left-to-right pass, so a "/*" inside
  //    a string or a quote inside a comment is handled correctly)
  let out = '';
  for (let i = 0; i < css.length;) {
    const c = css[i];
    if (c === '/' && css[i + 1] === '*') {
      const end = css.indexOf('*/', i + 2); if (end < 0) throw new Error('minifyCss: unclosed comment');
      i = end + 2; out += ' ';
    } else if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < css.length && css[j] !== c) { if (css[j] === '\n') throw new Error('minifyCss: unclosed string'); j += css[j] === '\\' ? 2 : 1; }
      if (j >= css.length) throw new Error('minifyCss: unclosed string');
      out += stash(css.slice(i, j + 1)); i = j + 1;
    } else if (/^url\(\s*[^"'\s)]/i.test(css.slice(i, i + 6))) {
      const end = css.indexOf(')', i); if (end < 0) throw new Error('minifyCss: unclosed url(');
      out += stash(css.slice(i, end + 1)); i = end + 1;
    } else { out += c; i++; }
  }
  // 2. whitespace
  out = out.replace(/\s+/g, ' ')
    .replace(/ ?([{};,>]) ?/g, '$1')
    .replace(/: /g, ':')
    .replace(/;}/g, '}')
    .trim();
  return out.replace(/\u0000(\d+)\u0000/g, (m, n) => keep[+n]);
}

// Card-face HTML from the print-and-play generator: collapse whitespace runs to one space, which is
// what the browser renders anyway (the faces contain no <pre>, <textarea> or white-space:pre text;
// the build test checks that).
const collapseHtml = h => h.replace(/\s+/g, ' ').trim();

// ---------- card faces (port of the old pnp/faces_export.py) ----------
function facesFromAssetSheet(sheet) {
  let css = sheet.slice(sheet.indexOf('<style>') + 7, sheet.indexOf('</style>'));
  css = css.replace(/@page\s*\{[^}]*\}/g, '');
  css = css.replace(/(^|\})\s*body\s*\{/g, '$1 .fw {');
  css += '\n.fw{position:relative;overflow:hidden;background:transparent}.fw>.card,.fw>.bigloc{border:0!important}.fw .pfoot{display:none}\n';
  const b = sheet.includes('<body>') ? sheet.indexOf('<body>') + 6 : sheet.indexOf('<body');
  const body = sheet.slice(b);
  const sp0 = body.indexOf('<svg'); const sp1 = body.indexOf('</svg>', sp0) + 6;
  if (sp0 < 0 || sp1 < 6) throw new Error('Asset sheet has no icon sprite');
  const sprite = body.slice(sp0, sp1);
  const faces = {};
  const OPEN = '<div class="asset" data-name="';
  const re = /<div class="asset" data-name="([^"]+)">/g;
  let m;
  while ((m = re.exec(body))) {
    const start = m.index + m[0].length; const nxt = body.indexOf(OPEN, start);
    let chunk = body.slice(start, nxt > 0 ? nxt : body.lastIndexOf('</body>')).trim();
    if (!chunk.endsWith('</div>')) throw new Error(`Asset ${m[1]} is not closed`);
    faces[m[1]] = chunk.slice(0, -6).trim();
  }
  if (!Object.keys(faces).length) throw new Error('Asset sheet has no faces');
  return { css, sprite, faces };
}

function generateFaces() {
  const gen = require(path.join(SRC, 'pnp', 'gen.js'));
  return facesFromAssetSheet(gen.assetsHtml());
}

// ---------- code ----------
// The engine exports itself for Node and the browser; the build keeps only the browser export.
function engineForBrowser(src) {
  const cut = src.indexOf('if (typeof module');
  if (cut < 0) throw new Error('engine.js: export footer not found');
  return src.slice(0, cut) + "root.WD = API;\n})(typeof window !== 'undefined' ? window : globalThis);\n";
}

// JSON that is safe inside an inline <script>.
const js = v => JSON.stringify(v).replace(/<\/(script)/gi, '<\\/$1');

// ---------- assemble ----------
function build({ out = DEFAULT_OUT, write = true, minify = true } = {}) {
  const read = f => fs.readFileSync(path.join(SRC, f), 'utf8');
  const faces = generateFaces();
  if (minify) {
    faces.css = minifyCss(faces.css);
    for (const k of Object.keys(faces.faces)) faces.faces[k] = collapseHtml(faces.faces[k]);
  }
  const data = [
    `const ART=${js(inlineImages(path.join(SRC, 'webart')))};`,
    `const GUNART=${js(inlineImages(path.join(SRC, 'webart', 'guns')))};`,
    `const FACES=${js(faces.faces)};`,
    `const LOCART=${js(inlineImages(path.join(SRC, 'webart', 'locs')))};`,
    `const FACECSS=${js(faces.css)};`,
    `const FACESPRITE=${js(faces.sprite)};`,
  ].join('\n');
  const parts = { css: minify ? minifyCss(read('style.css')) : read('style.css'), symbols: read('symbols.html'), data, engine: engineForBrowser(read('engine.js')), ui: read('ui.js') };
  const html = read('shell.html').replace(/<!-- @inline:(\w+) -->/g, (m, k) => {
    if (!(k in parts)) throw new Error(`shell.html: unknown marker ${m}`);
    const v = parts[k]; delete parts[k]; return v;
  });
  const missing = Object.keys(parts);
  if (missing.length) throw new Error(`shell.html is missing markers for: ${missing.join(', ')}`);
  if (write) { fs.mkdirSync(path.dirname(out), { recursive: true }); fs.writeFileSync(out, html); }
  return { html, out, bytes: Buffer.byteLength(html), faces: Object.keys(faces.faces).length };
}

module.exports = { build, inlineImages, facesFromAssetSheet, generateFaces, engineForBrowser, minifyCss, collapseHtml };

if (require.main === module) {
  const i = process.argv.indexOf('--out');
  const out = i > 0 ? path.resolve(process.argv[i + 1]) : DEFAULT_OUT;
  const r = build({ out, minify: !process.argv.includes('--no-minify') });
  console.log(`${path.relative(process.cwd(), r.out) || r.out}: ${r.bytes.toLocaleString('en-US')} bytes, ${r.faces} card faces`);
}
