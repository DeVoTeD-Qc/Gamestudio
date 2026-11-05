// Layer 6: print-and-play consistency. The paper components (src/pnp/gen.js) and the web build's card
// faces come from the same engine data; these checks stop the two from drifting apart.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { WD, SRC } = require('./helpers');

const gen = require(path.join(SRC, 'pnp', 'gen.js'));
const T = WD.TUNE;
// card types a match can deal: the 4 starters, the Buy Station cards and every loot card
const IN_PLAY = ['T001', 'T002', 'T004', 'T005', ...T.station, ...Object.values(WD.CARDS).filter(d => d.tier && d.copies).map(d => d.id)];

test('requiring gen.js writes nothing', () => {
  const dir = path.join(SRC, 'pnp');
  const snap = () => fs.readdirSync(dir).map(f => `${f}:${fs.statSync(path.join(dir, f)).mtimeMs}`).sort().join('|');
  const before = snap();
  require('child_process').execFileSync(process.execPath, ['-e', `require(${JSON.stringify(path.join(dir, 'gen.js'))})`], { stdio: 'pipe' });
  assert.equal(snap(), before);
  assert.equal(typeof gen.html, 'string');
});

test('component counts: 157 cards, 30 guns, 8 locations', () => {
  assert.equal(gen.counts.total, 157);
  assert.equal(gen.components.guns, 30);
  assert.equal(gen.components.locations, 8);
});

test('the paper set matches the engine data', () => {
  const starters = 2 * (T.stSprint + T.stScout + T.stAim + WD.CARDS.T005.copies);
  const station = T.station.length * T.stationCopies;
  const role = Object.values(WD.CARDS).filter(d => ['assault', 'recon', 'support', 'engineer'].includes(d.archetype)).reduce((a, d) => a + d.copies, 0);
  const extras = 2 /* turn reference */ + 2 /* squad & rally reference */ + 2 /* health trackers */ + 1 /* tokens */;
  assert.equal(gen.components.cards, starters + station + role + extras);
  assert.equal(gen.components.guns, 2 + [1, 2, 3].reduce((a, t) => a + WD.GUNSET[t].length, 0));
  assert.equal(gen.components.locations, WD.LOCSET.length);
  // a digital match deals the same loot: every loot card copy and every loot gun
  const s = WD.newGame({ seed: 1 });
  const items = [1, 2, 3].flatMap(t => s.loot[t]).concat(s.envs.flatMap(e => e.loot));
  assert.equal(items.filter(i => i.kind === 'card').length, role);
  assert.equal(items.filter(i => i.kind === 'weapon').length, gen.components.guns - 2);
  assert.equal(s.envs.length + s.envDeck.length, WD.LOCSET.length);
});

test('every component a match can deal has a card face for the web build', () => {
  const names = new Set(gen.assetList().map(([n]) => n));
  assert.equal(names.size, gen.assetList().length, 'face names are unique');
  for (const id of IN_PLAY) assert.ok(names.has('card_' + id), `card_${id}`);
  for (const id of ['pistol-0', ...[1, 2, 3].flatMap(t => WD.GUNSET[t])]) assert.ok(names.has('gun_' + id), `gun_${id}`);
  WD.LOCSET.forEach((L, i) => assert.ok(names.has('loc_L' + String(i + 1).padStart(2, '0'))));
});

// The 4 Loadout cards (new in wb-rules) have no art yet: they show their squad's sample art until the art pass (ui.js artURL fallback).
const SQUAD_ART = { assault: 'Breach', recon: 'Mark_Target', support: 'Ammo_Box', engineer: 'Deployable_Cover' };
test('every card, gun and location in play has web art', () => {
  const list = dir => new Set(fs.readdirSync(path.join(SRC, 'webart', dir)).filter(f => /\.(webp|png|jpe?g|avif)$/i.test(f)).map(f => f.replace(/\.[^.]+$/, '')));
  const art = list(''), gunArt = list('guns'), locArt = list('locs');
  for (const id of IN_PLAY) assert.ok(art.has(WD.CARDS[id].name.replace(/ /g, '_')) || (WD.CARDS[id].loadout && art.has(SQUAD_ART[WD.CARDS[id].archetype])), WD.CARDS[id].name);
  for (const id of ['pistol-0', ...[1, 2, 3].flatMap(t => WD.GUNSET[t])]) assert.ok(gunArt.has(id), id);
  for (const id in WD.ENVS) assert.ok(locArt.has(id), id);
});
