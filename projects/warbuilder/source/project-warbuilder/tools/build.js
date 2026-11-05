#!/usr/bin/env node
// tools/build.js: one-command build of the single-file HTML5 game.
//
//   npm run build                 → build/index.html
//   node tools/build.js --out FILE → another output path (the tests use this)
//
// Steps (all in memory, nothing is written into src/):
//   1. src/pnp/gen.js renders the print-and-play asset sheet; facesFromAssetSheet() turns it into
//      the FACES table (scoped CSS, icon sprite, one HTML string per card face). This replaces
//      `ASSETS=1 node gen.js` + faces_export.py + the faces.json file.
//   2. inlineImages() turns each art folder into { name: dataURI }.
//   3. src/shell.html (doctype, viewport, fonts, body skeleton) gets the CSS, sprite, data, engine
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
function build({ out = DEFAULT_OUT, write = true } = {}) {
  const read = f => fs.readFileSync(path.join(SRC, f), 'utf8');
  const faces = generateFaces();
  const data = [
    `const ART=${js(inlineImages(path.join(SRC, 'webart')))};`,
    `const GUNART=${js(inlineImages(path.join(SRC, 'webart', 'guns')))};`,
    `const FACES=${js(faces.faces)};`,
    `const LOCART=${js(inlineImages(path.join(SRC, 'webart', 'locs')))};`,
    `const FACECSS=${js(faces.css)};`,
    `const FACESPRITE=${js(faces.sprite)};`,
  ].join('\n');
  const parts = { css: read('style.css'), symbols: read('symbols.html'), data, engine: engineForBrowser(read('engine.js')), ui: read('ui.js') };
  const html = read('shell.html').replace(/<!-- @inline:(\w+) -->/g, (m, k) => {
    if (!(k in parts)) throw new Error(`shell.html: unknown marker ${m}`);
    const v = parts[k]; delete parts[k]; return v;
  });
  const missing = Object.keys(parts);
  if (missing.length) throw new Error(`shell.html is missing markers for: ${missing.join(', ')}`);
  if (write) { fs.mkdirSync(path.dirname(out), { recursive: true }); fs.writeFileSync(out, html); }
  return { html, out, bytes: Buffer.byteLength(html), faces: Object.keys(faces.faces).length };
}

module.exports = { build, inlineImages, facesFromAssetSheet, generateFaces, engineForBrowser };

if (require.main === module) {
  const i = process.argv.indexOf('--out');
  const out = i > 0 ? path.resolve(process.argv[i + 1]) : DEFAULT_OUT;
  const r = build({ out });
  console.log(`${path.relative(process.cwd(), r.out) || r.out}: ${r.bytes.toLocaleString('en-US')} bytes, ${r.faces} card faces`);
}
