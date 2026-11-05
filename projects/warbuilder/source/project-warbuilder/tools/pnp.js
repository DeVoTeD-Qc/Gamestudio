#!/usr/bin/env node
// tools/pnp.js: print-and-play sheets (replaces pnp/topdf.py; all paths are relative to this repo).
//
//   npm run pnp            → src/pnp/pnp.html (open it in a browser and print, or …)
//   npm run pnp -- --pdf   → … also src/pnp/Warzone-Deckbuilder-Print-and-Play.pdf (needs Playwright + Chromium)
//
// pnp.html stays next to src/pnp/art/ because it links the card art with relative paths.
// Generated files (pnp.html, *.pdf) are git-ignored. Playwright is resolved from this project or
// from the global npm root (NODE_PATH=$(npm root -g)); it is not a dependency of the game.
'use strict';
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const PNP = path.join(__dirname, '..', 'src', 'pnp');
const HTML = path.join(PNP, 'pnp.html');
const PDF = path.join(PNP, 'Warzone-Deckbuilder-Print-and-Play.pdf');

function loadPlaywright() {
  try { return require('playwright'); } catch (e) { /* fall through */ }
  const { execSync } = require('child_process');
  const root = execSync('npm root -g', { encoding: 'utf8' }).trim();
  return require(path.join(root, 'playwright'));
}

async function main() {
  const gen = require(path.join(PNP, 'gen.js'));
  fs.writeFileSync(HTML, gen.html);
  console.log(`${path.relative(process.cwd(), HTML)}: ${gen.counts.total} cards, ${gen.components.guns} guns, ${gen.components.locations} locations`);
  if (!process.argv.includes('--pdf')) return;
  const { chromium } = loadPlaywright();
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(pathToFileURL(HTML).href);
    await page.waitForTimeout(500);
    await page.pdf({ path: PDF, format: 'Letter', printBackground: true, margin: { top: '0', bottom: '0', left: '0', right: '0' } });
  } finally { await browser.close(); }
  console.log(`${path.relative(process.cwd(), PDF)}: ${fs.statSync(PDF).size.toLocaleString('en-US')} bytes`);
}

main().catch(e => { console.error(e); process.exit(1); });
