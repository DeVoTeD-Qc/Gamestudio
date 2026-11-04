/* WARZONE DECKBUILDER v4.0 — rules engine.
   Full turns (no action points). 7 locations = the clock. Boost only on guns.
   Each gun fires up to its magazine every turn (refills each turn; a gun you pick up is loaded).
   Resources: Movement, Precision, Intel (+ Armor, which lasts until your next turn). */
(function (root) {
'use strict';

const RES = ['move', 'prec', 'intel'];
const TUNE = { lite: true, multiMove: false, digIn: 2, combos: true, lowHp: 10, locEveryTurn: true, perks: false, zones: 6, startA: 1, startB: 4, hp: 30, gasDmg: 3, finalBase: 3, distDiv: 2, need: 2, cardDisc: 0, bankIntel: false, adjCost: 1, stSprint: 3, stScout: 3, stAim: 2, stHM: 0, supplyCost: 2, station: ['K02', 'K04', 'K05', 'K03'], fuelBurns: false, distMode: 'band', sweetBonus: 0, enterCover: 0, phases: true, physical: true, stationRoles: true, stationCopies: 8, ammo: false, slots: false, squad: false, squadGun: false, comboAnyNeighbour: true, bulletCounts: true, freeBulletHM: 1, stacks: true, cycleCost: 1, plateArmor: 2, gunPos: 'early', phaseDeck: [3, 4, 5], phaseGas: [1, 1, 1], phaseTier: [2, 2, 3], perkDraft: 3, firstShotRecoil: false, needPlus: 0, allies: false, gunAlly: false, mastery: false, affinity: 0, perks: false, recoilStack: true, aiAmmoBias: 3, cardDiscount: 1, crate: [3, 1], crateRounds: [2, 4], hotBonus: 1, tradeIn: 0, firstHand: 5, secondIntel: 0, secondExtraCards: 0, secondArmor: 0, alternateFirst: true, dropRound: 0, hand: 5, minDeck: 6, fuelAnyCard: true, mapMode: 'drift', newZones: 11, tier2Reveals: 3, gasRates: [1, 1, 1, 2, 2, 3], freshBonus: 1 };
const TIER_NAME = ['Common', 'Uncommon', 'Rare', 'Epic'];
const RES_LABEL = { move: 'Movement', prec: 'Precision', intel: 'Intel', def: 'Armor', shot: 'extra shot' };
const ARCH_TAG = { supply: 'Supply', starter: 'Starter', assault: 'Assault', support: 'Support', recon: 'Recon', engineer: 'Engineer' };
const NEIGHBOURS = { assault: ['recon', 'support'], recon: ['assault', 'engineer'], support: ['assault', 'engineer'], engineer: ['recon', 'support'] };
const COND_LABEL = { notMoved: "haven't moved", movedToward: 'moved toward the enemy', shareOrAdjacent: 'same or adjacent location' };

const gain = (res, n) => ({ op: 'gain', res, n });
const draw = n => ({ op: 'draw', n });
const nextFire = o => Object.assign({ op: 'nextFire' }, o);
const cond = (iff, then) => ({ op: 'cond', if: iff, then });

// ---------- TACTICAL CARDS: one effect line; tier 0 = starter, I / II / III = loot quality ----------
const CARDS = {};
function TC(id, name, archetype, tier, hm, cost, copies, effects, text, extra) {
  CARDS[id] = Object.assign({ id, name, archetype, tier, hit_markers: hm, intel_cost: cost, copies, effects, text, tags: [ARCH_TAG[archetype]] }, extra || {});
}
// Starter deck (10) — grey: no role, no combo
TC('T001', 'Sprint', 'starter', 0, TUNE.stHM, 0, TUNE.stSprint, [gain('move', 1)], 'Gain 1 Movement.');
TC('T002', 'Scout', 'starter', 0, TUNE.stHM, 0, TUNE.stScout, [gain('intel', 1)], 'Gain 1 Intel.');
TC('T004', 'Steady Aim', 'starter', 0, 1, 0, TUNE.stAim, [gain('prec', 1)], 'Gain 1 Precision.');
TC('T005', 'Recon Run', 'starter', 0, 1, 0, 2, [gain('move', 1), gain('intel', 1)], 'Gain 1 Movement and 1 Intel.');
TC('T006', 'Take Cover', 'starter', 0, 1, 0, 1, [gain('move', 1)], 'Gain 1 Movement.', { reaction: 2 });
// Buy Station: always for sale anywhere, unlimited (like Dominion's Silver / Star Realms' Explorer)
TC('K02', 'Tac Sprint', TUNE.stationRoles ? 'assault' : 'supply', 1, 1, 2, 0, [gain('move', 2)], 'Gain 2 Movement.');
TC('K03', 'Dead Drop', TUNE.stationRoles ? 'engineer' : 'supply', 1, 1, 2, 0, [gain('intel', 2)], 'Gain 2 Intel.');
TC('K04', 'Focus', TUNE.stationRoles ? 'recon' : 'supply', 1, 2, 2, 0, [gain('prec', 2)], 'Gain 2 Precision.');
TC('K05', 'Spare Rounds', TUNE.stationRoles ? 'support' : 'supply', 1, 1, 2, 0, [gain('shot', 1)], 'Gain 1 extra shot.');
TC('K01', 'Armor Plates', 'supply', 1, 1, 2, 0, [gain('intel', 1)], 'Gain 1 Intel.', { reaction: 3 });
const combo = (role, eff, text) => ({ combo: { role, eff, text } });
const cb = (role, eff, text) => ({ role, eff, text });
const combos = (...c) => ({ combos: c });
const shot = n => gain('shot', n); const armor = n => gain('def', n);
// v7 LITE: no combos. Each role has one job. Tier = more of it.
// ASSAULT — Movement, plus some aim. Rush in, ignore cover.
TC('A11', 'Breach', 'assault', 1, 1, 1, 2, [gain('move', 2), gain('prec', 1)], 'Gain 2 Movement and 1 Precision.', combos(cb('assault', [gain('prec', 1)], 'Gain 1 Precision.')));
TC('A12', 'Slide Cancel', 'assault', 1, 1, 1, 2, [gain('move', 2), { op: 'scrap', n: 1 }], 'Gain 2 Movement. Scrap 1.', combos(cb('assault', [gain('move', 1)], 'Gain 1 Movement.')));
TC('A13', 'Hip Fire', 'assault', 1, 1, 2, 2, [gain('move', 1), gain('prec', 2)], 'Gain 1 Movement and 2 Precision.', combos(cb('assault', [gain('prec', 1)], 'Gain 1 Precision.')));
TC('A21', 'Rush the Door', 'assault', 2, 2, 3, 2, [gain('move', 2), gain('prec', 2), { op: 'ignoreCover' }], 'Gain 2 Movement and 2 Precision. Ignore cover.', combos(cb(['assault', 'recon'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('A22', 'Flank', 'assault', 2, 2, 3, 2, [gain('move', 3), gain('intel', 1), draw(1)], 'Gain 3 Movement and 1 Intel. Draw 1.', combos(cb(['assault', 'support'], [draw(1)], 'Draw 1.')));
TC('A23', 'Run and Gun', 'assault', 2, 2, 3, 2, [gain('move', 2), gain('prec', 2), shot(1)], 'Gain 2 Movement, 2 Precision and 1 extra shot.', combos(cb(['assault', 'support'], [shot(1)], 'Gain 1 extra shot.')));
TC('A31', 'Blitz', 'assault', 3, 3, 5, 2, [gain('move', 3), gain('prec', 3), draw(1)], 'Gain 3 Movement and 3 Precision. Draw 1.', combos(cb(['assault', 'recon'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('A32', 'Breaching Charge', 'assault', 3, 2, 4, 2, [gain('move', 2), gain('prec', 2), { op: 'ignoreCover' }, nextFire({ dmg: 2 })], 'Gain 2 Movement and 2 Precision. Ignore cover. Next hit +2 damage.', combos(cb(['assault', 'support'], [nextFire({ dmg: 1 })], 'Next hit +1 damage.')));
// RECON — Precision and Hit Markers. Aim, mark, see.
TC('R11', 'Mark Target', 'recon', 1, 2, 1, 2, [gain('prec', 2), gain('move', 1)], 'Gain 2 Precision and 1 Movement.', combos(cb('recon', [gain('prec', 1)], 'Gain 1 Precision.')));
TC('R12', 'Steady Breath', 'recon', 1, 3, 1, 2, [gain('prec', 3)], 'Gain 3 Precision.', combos(cb('recon', [gain('prec', 1)], 'Gain 1 Precision.')));
TC('R13', 'Snapshot', 'recon', 1, 2, 2, 2, [gain('prec', 2), gain('intel', 1)], 'Gain 2 Precision and 1 Intel.', combos(cb('recon', [gain('intel', 1)], 'Gain 1 Intel.')));
TC('R21', 'Heartbeat Sensor', 'recon', 2, 2, 3, 2, [gain('prec', 3), gain('move', 1), draw(1)], 'Gain 3 Precision and 1 Movement. Draw 1.', combos(cb(['recon', 'assault'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('R22', 'Spotter Scope', 'recon', 2, 3, 3, 2, [gain('prec', 5)], 'Gain 5 Precision.', combos(cb(['recon', 'engineer'], [nextFire({ reqMod: 1 })], 'Next shot −1 Hit Marker.')));
TC('R23', 'Thermal Optic', 'recon', 2, 2, 3, 2, [gain('prec', 3), gain('intel', 1), { op: 'ignoreCover' }], 'Gain 3 Precision and 1 Intel. Ignore cover.', combos(cb(['recon', 'engineer'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('R31', 'UAV', 'recon', 3, 3, 4, 2, [gain('prec', 4), gain('intel', 2), { op: 'ignoreCover' }], 'Gain 4 Precision and 2 Intel. Ignore cover.', combos(cb(['recon', 'engineer'], [draw(1)], 'Draw 1.')));
TC('R32', 'Headhunter', 'recon', 3, 3, 5, 2, [gain('prec', 5), nextFire({ reqMod: 1 })], 'Gain 5 Precision. Next shot −1 Hit Marker.', combos(cb(['recon', 'assault'], [gain('prec', 2)], 'Gain 2 Precision.')));
// SUPPORT — extra shots and Armor.
TC('S11', 'Ammo Box', 'support', 1, 1, 2, 2, [gain('prec', 2), shot(1), { op: 'scrap', n: 1 }], 'Gain 2 Precision and 1 extra shot. Scrap 1.', combos(cb('support', [gain('prec', 1), armor(1)], 'Gain 1 Precision and 1 Armor.')));
TC('S12', 'Suppressing Fire', 'support', 1, 1, 2, 2, [gain('prec', 2), gain('move', 1), armor(1)], 'Gain 2 Precision, 1 Movement and 1 Armor.', combos(cb('support', [gain('prec', 2)], 'Gain 2 Precision.')));
TC('S13', 'Bandolier', 'support', 1, 1, 2, 2, [gain('prec', 2), shot(1), armor(1)], 'Gain 2 Precision, 1 extra shot and 1 Armor.', combos(cb('support', [shot(1)], 'Gain 1 extra shot.')));
TC('S21', 'Steady Grip', 'support', 2, 2, 3, 2, [gain('prec', 3), shot(1), armor(1)], 'Gain 3 Precision, 1 extra shot and 1 Armor.', combos(cb(['support', 'assault'], [shot(1)], 'Gain 1 extra shot.')));
TC('S22', 'Resupply', 'support', 2, 1, 3, 2, [gain('intel', 2), gain('prec', 1), shot(1), draw(1)], 'Gain 2 Intel, 1 Precision and 1 extra shot. Draw 1.', combos(cb(['support', 'engineer'], [gain('intel', 1)], 'Gain 1 Intel.')));
TC('S23', 'Covering Fire', 'support', 2, 2, 3, 2, [gain('prec', 3), armor(2)], 'Gain 3 Precision and 2 Armor.', combos(cb(['support', 'assault'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('S31', 'Overwatch', 'support', 3, 2, 5, 2, [gain('prec', 5), shot(1), armor(2)], 'Gain 5 Precision, 1 extra shot and 2 Armor.', combos(cb(['support', 'engineer'], [draw(1)], 'Draw 1.')));
TC('S32', 'Munitions Drop', 'support', 3, 2, 4, 2, [gain('prec', 4), shot(2)], 'Gain 4 Precision and 2 extra shots.', combos(cb(['support', 'assault'], [shot(1)], 'Gain 1 extra shot.')));
// ENGINEER — Intel, Scrap and digging through stacks.
TC('E11', 'Scrounge', 'engineer', 1, 1, 2, 2, [gain('intel', 2), { op: 'scrap', n: 1 }], 'Gain 2 Intel. Scrap 1.', combos(cb('engineer', [gain('intel', 1)], 'Gain 1 Intel.')));
TC('E12', 'Deployable Cover', 'engineer', 1, 0, 2, 2, [gain('intel', 3), gain('prec', 1)], 'Gain 3 Intel and 1 Precision.', Object.assign({ reaction: 3 }, combos(cb('engineer', [gain('intel', 1)], 'Gain 1 Intel.'))));
TC('E13', 'Ping', 'engineer', 1, 1, 1, 2, [gain('intel', 2), gain('prec', 1), { op: 'cycleFree', n: 1 }], 'Gain 2 Intel, 1 Precision and 1 free cycle.', combos(cb('engineer', [{ op: 'cycleFree', n: 1 }], 'Gain 1 free cycle.')));
TC('E21', 'Munitions Box', 'engineer', 2, 1, 3, 2, [gain('intel', 2), gain('prec', 1)], 'Gain 2 Intel and 1 Precision.', combos(cb(['engineer', 'support'], [shot(1)], 'Gain 1 extra shot.')));
TC('E22', 'Field Kit', 'engineer', 2, 2, 3, 2, [gain('intel', 3), gain('prec', 1), draw(1)], 'Gain 3 Intel and 1 Precision. Draw 1.', combos(cb(['engineer', 'recon'], [gain('prec', 2)], 'Gain 2 Precision.')));
TC('E23', 'Salvage', 'engineer', 2, 1, 3, 2, [gain('intel', 3), { op: 'scrap', n: 1 }, { op: 'cycleFree', n: 2 }], 'Gain 3 Intel. Scrap 1. 2 free cycles.', combos(cb(['engineer', 'support'], [gain('intel', 1)], 'Gain 1 Intel.')));
TC('E31', 'Field Workshop', 'engineer', 3, 2, 4, 2, [gain('intel', 3), draw(1), { op: 'scrap', n: 2 }], 'Gain 3 Intel. Draw 1. Scrap 2.', combos(cb(['engineer', 'recon'], [draw(1)], 'Draw 1.')));
TC('E32', 'Black Market', 'engineer', 3, 2, 5, 2, [gain('intel', 5), draw(1)], 'Gain 5 Intel. Draw 1.', combos(cb(['engineer', 'support'], [draw(1)], 'Draw 1.')));

// Combo lines always appear in the same role order: Assault, Recon, Support, Engineer.
const ROLE_ORDER = ['assault', 'recon', 'support', 'engineer'];
for (const id in CARDS) { const d = CARDS[id]; if (!d.combos) continue;
  d.combos.forEach(c => { if (Array.isArray(c.role)) c.role.sort((a, b) => ROLE_ORDER.indexOf(a) - ROLE_ORDER.indexOf(b)); });
  d.combos.sort((a, b) => ROLE_ORDER.indexOf([].concat(a.role)[0]) - ROLE_ORDER.indexOf([].concat(b.role)[0])); }

// ---------- GUNS: one model per class, five rarities (Warzone colours). Each rarity step pre-installs one more attachment.
// Stats: Damage · Range (sweet spot) · Shots per turn · Recoil. Every hit needs 2 Hit Markers (Red Dot: 1).
const RARITY = [
  { key: 'common', name: 'Common', color: '#9AA0A6' }, { key: 'uncommon', name: 'Uncommon', color: '#3FA34D' },
  { key: 'rare', name: 'Rare', color: '#2F7FD8' }, { key: 'epic', name: 'Epic', color: '#9B4DCA' }, { key: 'legendary', name: 'Legendary', color: '#E0A800' }];
const MODS = {
  hollow: { name: 'Hollow Points', text: '+1 Damage on every step', mod: { damage: 1 } },
  extmag: { name: 'Extended Mag', text: '+1 shot per turn', mod: { magazine_capacity: 1 } },
  comp: { name: 'Compensator', text: '−1 Recoil', mod: { recoil: -1 } },
  reddot: { name: 'Red Dot', text: 'every Hit Marker step −1', mod: { hit_need: -1 } },
  none: { name: '', text: '', mod: {} },
};
const GUNCLASS = {
  pistol: { name: 'Sidearm', cls: 'Pistol', arch: 'engineer', damage: 2, range: 1, band: [0, 2], ladder: [[2, 2], [4, 3]], reveal: 0, shots: 2, recoil: 2, slot: 0, gcombo: { role: 'engineer', eff: [gain('intel', 1)], text: 'Gain 1 Intel.' }, cost: 1, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Gold Rush', main: [gain('intel', 1)], mainText: 'Gain 1 Intel.', boost: [gain('prec', 1), gain('intel', 1)], boostText: 'Gain 1 Precision and 1 Intel.' },
  revolver: { name: 'Magnum', cls: 'Revolver', arch: 'engineer', damage: 4, range: 2, band: [0, 3], ladder: [[3, 5], [5, 8]], reveal: 0, shots: 1, recoil: 3, slot: 0, gcombo: { role: 'engineer', eff: [gain('prec', 1)], text: 'Gain 1 Precision.' }, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Judge', main: [], mainText: '', boost: [], boostText: '' },
  knife: { name: 'Combat Knife', cls: 'Melee', arch: 'assault', damage: 2, range: 0, band: [0, 0], ladder: [[0, 2]], reveal: 0, shots: 1, recoil: 0, slot: 0, melee: true, gcombo: { role: 'assault', eff: [nextFire({ dmg: 1 })], text: 'Next hit +1 damage.' }, cost: 1, mods: ['hollow', 'none', 'hollow', 'none'], skin: 'Obsidian', main: [], mainText: '', boost: [], boostText: '' },
  smg: { name: 'Viper', cls: 'SMG', arch: 'assault', damage: 2, range: 0, band: [0, 1], ladder: [[3, 2], [5, 4]], reveal: 0, shots: 2, recoil: 2, slot: 0, gcombo: { role: 'assault', eff: [gain('shot', 1)], text: 'Gain 1 extra shot.' }, cost: 2, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Gold Fang', main: [gain('move', 1)], mainText: 'Gain 1 Movement.', boost: [gain('prec', 2)], boostText: 'Gain 2 Precision.' },
  shotgun: { name: 'Breacher', cls: 'Shotgun', arch: 'engineer', damage: 3, range: 0, band: [0, 1], ladder: [[3, 3], [6, 6]], reveal: 0, shots: 1, recoil: 3, slot: 0, gcombo: { role: 'engineer', eff: [gain('prec', 2)], text: 'Gain 2 Precision.' }, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Dragon’s Breath', main: [gain('move', 1), gain('def', 1)], mainText: 'Gain 1 Movement and 1 Armor.', boost: [gain('shot', 1)], boostText: 'Gain 1 extra shot.' },
  burst: { name: 'Raider', cls: 'Burst Rifle', arch: 'assault', damage: 2, range: 1, band: [0, 2], ladder: [[2, 2], [6, 4]], reveal: 0, shots: 2, recoil: 1, slot: 0, gcombo: { role: 'assault', eff: [gain('prec', 1)], text: 'Gain 1 Precision.' }, cost: 2, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Night Raid', main: [gain('move', 1)], mainText: 'Gain 1 Movement.', boost: [gain('shot', 1)], boostText: 'Gain 1 extra shot.' },
  launcher: { name: 'Sapper', cls: 'Launcher', arch: 'engineer', damage: 4, range: 2, band: [1, 3], ladder: [[3, 5], [6, 8]], reveal: 0, shots: 1, recoil: 3, slot: 0, gcombo: { role: 'engineer', eff: [gain('prec', 1), { op: 'ignoreCover' }], text: 'Gain 1 Precision. Ignore cover.' }, cost: 3, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Demolition', main: [gain('intel', 1)], mainText: 'Gain 1 Intel.', boost: [gain('shot', 1)], boostText: 'Gain 1 extra shot.' },
  ar: { name: 'Sentinel', cls: 'Assault Rifle', arch: 'support', damage: 2, range: 2, band: [0, 3], ladder: [[3, 3], [5, 5]], reveal: 0, shots: 2, recoil: 2, slot: 0, gcombo: { role: 'support', eff: [gain('prec', 1)], text: 'Gain 1 Precision.' }, cost: 3, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Crown Jewel', main: [gain('def', 1), gain('move', 1)], mainText: 'Gain 1 Armor and 1 Movement.', boost: [gain('shot', 1)], boostText: 'Gain 1 extra shot.' },
  lmg: { name: 'Bastion', cls: 'LMG', arch: 'support', damage: 2, range: 2, band: [0, 3], ladder: [[3, 2], [7, 4]], reveal: 0, shots: 3, recoil: 1, slot: 0, gcombo: { role: 'support', eff: [gain('def', 1)], text: 'Gain 1 Armor.' }, cost: 3, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Iron Monarch', main: [gain('def', 2)], mainText: 'Gain 2 Armor.', boost: [gain('def', 2), gain('prec', 1)], boostText: 'Gain 2 Armor and 1 Precision.' },
  dmr: { name: 'Ranger', cls: 'Marksman Rifle', arch: 'recon', damage: 3, range: 3, band: [1, 4], ladder: [[3, 3], [7, 6]], reveal: 0, shots: 2, recoil: 2, slot: 0, gcombo: { role: 'recon', eff: [nextFire({ reqMod: 1 })], text: 'Next shot −1 Hit Marker.' }, cost: 3, mods: ['reddot', 'hollow', 'comp', 'hollow'], skin: 'Golden Hour', main: [gain('def', 1), gain('intel', 1)], mainText: 'Gain 1 Armor and 1 Intel.', boost: [nextFire({ reqMod: 1 })], boostText: 'Your next shot needs 1 fewer Hit Marker.' },
  sniper: { name: 'Longbow', cls: 'Sniper', arch: 'recon', damage: 4, range: 4, band: [1, 5], ladder: [[3, 5], [7, 9]], reveal: 0, shots: 1, recoil: 2, slot: 0, gcombo: { role: 'recon', eff: [gain('prec', 1)], text: 'Gain 1 Precision.' }, cost: 4, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Sun God', main: [gain('def', 2), gain('intel', 1)], mainText: 'Gain 2 Armor and 1 Intel.', boost: [cond('notMoved', [nextFire({ bonusPrec: 3 })])], boostText: "If you haven't moved this turn, your next shot gets 3 extra Precision." },
};
const WEAPONS = {};
for (const k in GUNCLASS) for (let r = 0; r < RARITY.length; r++) {
  const g = GUNCLASS[k]; const mods = g.mods.slice(0, r);
  const st = { damage: g.damage, max_range: g.range, magazine_capacity: g.shots, recoil: g.recoil, hit_need: g.ladder[0][0], reveal: Math.max(0, (g.reveal || 0) + (TUNE.revealAdj || 0)) };
  for (const m of mods) for (const f in MODS[m].mod) st[f] = Math.max(f === 'hit_need' ? 1 : 0, st[f] + MODS[m].mod[f]);
  const id = `${k}-${r}`;
  WEAPONS[id] = { id, gunClass: k, name: r === 4 ? `${g.name} “${g.skin}”` : g.name, baseName: g.name, skin: r === 4 ? g.skin : null, archetype: g.arch, cls: g.cls, tier: r, rarity: RARITY[r].key, rarityName: RARITY[r].name,
    ladder: g.ladder.map(([h, dm]) => [g.melee ? 0 : Math.max(1, h + st.hit_need - g.ladder[0][0]), dm + st.damage - g.damage]), band: g.band.slice(), melee: !!g.melee,
    damage: st.damage, max_range: st.max_range, magazine_capacity: st.magazine_capacity, recoil: st.recoil, hit_need: st.hit_need, reveal: st.reveal, intel_cost: 1 + r,
    mods: mods.filter(m => MODS[m].name).map(m => MODS[m].name), modText: mods.filter(m => MODS[m].name).map(m => `${MODS[m].name} (${MODS[m].text})`),
    tactical_main_effects: [], main_text: '', slot: g.slot, gcombo: g.gcombo, tactical_boost_requirement: 'any', tactical_boost_min_hit_markers: 0, tactical_boost_effects: TUNE.lite ? [] : g.boost, boost_text: TUNE.lite ? '' : g.boostText, tags: [ARCH_TAG[g.arch]] };
}
// how many guns of each rarity go into each loot tier (tier I = start, II = centre/new ground, III = late ground/crates)
const GUN_LOOT = { 1: [0, 0, 3, 3], 2: [0, 0, 0, 3, 3], 3: [0, 0, 0, 0, 3, 3] };
const GUN_LOOT_RARITY = { 1: [0, 0, 0, 1, 1, 1], 2: [2, 2, 2, 3, 3], 3: [3, 3, 4, 4] };
const WEAPON_COPIES = {};
const ATTS = {};

// ---------- LOCATIONS (8 types, 7 dealt) ----------
const ENVS = {
  E01: { affinity: 'assault', id: 'E01', name: 'Open Road', cover: 0, cache: 3, bonus: { move: 1 }, bonusText: '+1 Movement', text: 'No cover. Here: +1 Movement.' },
  E02: { affinity: 'assault', id: 'E02', name: 'Small Shed', cover: 1, cache: 2, bonus: { cycle: 1 }, bonusText: '1 free cycle', text: 'Cover −1. Here: 1 free cycle.' },
  E03: { affinity: 'engineer', id: 'E03', name: 'House', cover: 1, cache: 3, bonus: { draw: 1 }, bonusText: 'Draw 1', text: 'Cover −1. Here: draw 1 card.' },
  E04: { affinity: 'engineer', id: 'E04', name: 'Supply Depot', cover: 0, cache: 4, bonus: { intel: 1 }, bonusText: '+1 Intel', text: 'No cover. Big cache. Here: +1 Intel.' },
  E05: { affinity: 'support', id: 'E05', name: 'Concrete Barrier', cover: 1, cache: 2, bonus: { def: 1 }, bonusText: '+1 Armor', text: 'Cover −1. Here: +1 Armor.' },
  E06: { affinity: 'support', id: 'E06', name: 'Military Bunker', cover: 1, cache: 3, bonus: { shot: 1 }, bonusText: '+1 extra shot', text: 'Cover −1. Here: +1 extra shot.' },
  E07: { affinity: 'recon', id: 'E07', name: 'Recon Tower', cover: 1, cache: 2, bonus: { prec: 1 }, bonusText: '+1 Precision', text: 'Cover −1. Here: +1 Precision.' },
  E08: { affinity: 'recon', id: 'E08', name: 'Workbench', cover: 0, cache: 3, special: 'bench', bonus: { scrap: 1 }, bonusText: 'Scrap 1', text: 'No cover. Here: Scrap 1.' },
};

// ---------- helpers ----------
function rng(s) { s.seed = (s.seed + 0x6D2B79F5) | 0; let t = s.seed; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
function shuffle(s, a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng(s) * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
const fail = err => ({ ok: false, err });
const P = (s, i) => s.players[i];
const envAt = (s, w) => s.envs.find(e => e.w === w);
const dist = s => Math.abs(s.players[0].pos - s.players[1].pos);
function log(s, msg, cls) { s.log.push({ r: s.round, msg, cls: cls || '' }); if (s.log.length > 500) s.log.shift(); if (s._rec) { const r = s._rec; s._rec = null; r.push({ msg, cls: cls || '', state: JSON.stringify(s) }); s._rec = r; } }
const cardDef = (s, iid) => CARDS[s.cards[iid].def];
const hmOf = (s, iid) => cardDef(s, iid).hit_markers;
const isStarter = (s, iid) => cardDef(s, iid).archetype === 'starter';
function itemDef(s, item) { return item.kind === 'card' ? CARDS[s.cards[item.iid].def] : item.kind === 'weapon' ? WEAPONS[s.weapons[item.iid].def] : ATTS[s.atts[item.iid].def]; }
function eff(s, wiid) {
  const W = s.weapons[wiid]; const d = WEAPONS[W.def];
  const e = { damage: d.damage, max_range: d.max_range, magazine_capacity: d.magazine_capacity, hit_need: d.hit_need, recoil: d.recoil, reveal: d.reveal || 0 };
  if (W.att) { const a = ATTS[s.atts[W.att].def]; for (const k in a.mod) e[k] = Math.max(0, e[k] + a.mod[k]); }
  e.hit_need = d.melee ? 0 : Math.max(1, e.hit_need); e.ladder = d.ladder; e.band = d.band;
  return e;
}
const guns = pl => pl.guns.filter(Boolean);
const owned = pl => pl.deck.length + pl.discard.length + pl.hand.length + pl.play.length + (pl.fuelled ? pl.fuelled.length : 0);

function mkPlayer(idx, name) {
  return { idx, name, hp: TUNE.hp, pos: 0, res: { move: 0, prec: 0, intel: 0 }, def: 0, shot: 0,
    deck: [], discard: [], hand: [], play: [], fuelled: [], removed: [], allyDone: [], guns: [null, null],
    bonusTaken: [], benchUsed: false, searches: 1, moved: false, movedToward: false, punched: false,
    nextFire: { reqMod: 0, bonusPrec: 0 }, recoilTurn: 0, perks: [], perkOffer: null, perkFired: [], gen: { move: 0, prec: 0, intel: 0, def: 0 }, suppressArm: 0, suppressed: 0, lootDiscount: 0,
    stats: { shots: 0, hits: 0, jams: 0, damageDealt: 0, cardsAcquired: 0, weaponAcq: 0, burned: 0, tradeIns: 0, searches: 0, reactions: 0, hitsBy: {}, maxTurnDmg: 0, turnDmg: 0 } };
}
function newCard(s, def) { const iid = 'c' + (s.nid++); s.cards[iid] = { iid, def }; return iid; }
function newWeapon(s, def) { const iid = 'w' + (s.nid++); s.weapons[iid] = { iid, def, shots: 0, used: false, att: null }; return iid; }
function newAtt(s, def) { const iid = 'a' + (s.nid++); s.atts[iid] = { iid, def }; return iid; }

function drawCards(s, p, n) {
  const pl = P(s, p); let d = 0;
  for (let i = 0; i < n; i++) {
    if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s, pl.discard); pl.discard = []; }
    pl.hand.push(pl.deck.pop()); d++;
  }
  return d;
}

// ---------- physical component sets (the print-and-play uses exactly these) ----------
// one loot gun per role per rarity, alternating two types per role (Assault SMG/Burst · Engineer Shotgun/Launcher · Support LMG/AR · Recon DMR/Sniper); tier 1 = Common, tier 2 = Uncommon + Rare, tier 3 = Epic + Legendary
const GUNSET = { 1: ['smg-0', 'shotgun-0', 'lmg-0', 'dmr-0', 'knife-0', 'revolver-0'], 2: ['burst-1', 'launcher-1', 'ar-1', 'sniper-1', 'smg-2', 'shotgun-2', 'lmg-2', 'dmr-2', 'pistol-2', 'knife-2', 'revolver-1'], 3: ['burst-3', 'launcher-3', 'ar-3', 'sniper-3', 'smg-4', 'shotgun-4', 'lmg-4', 'dmr-4', 'pistol-4', 'knife-4', 'revolver-3'] };
// location cards: phase ('start' | 1 | 2 | 3), type, centre, gun position in its stack (0 = top)
const LOCSET = [
  { ph: 'start', def: 'E01', gun: 0 }, { ph: 'start', def: 'E05', gun: 0 }, { ph: 'start', def: 'E04', gun: 0 }, { ph: 'start', def: 'E06', gun: 0 }, { ph: 'start', def: 'E02', gun: 0 }, { ph: 'start', def: 'E07', gun: 0 },
  { ph: 1, def: 'E03', gun: 0 }, { ph: 1, def: 'E08', gun: 0 }, { ph: 1, def: 'E02', gun: 0 },
  { ph: 2, def: 'E06', gun: 1 }, { ph: 2, def: 'E01', gun: 0 }, { ph: 2, def: 'E07', gun: 2 }, { ph: 2, def: 'E04', gun: 1 },
  { ph: 3, def: 'E05', gun: 2 }, { ph: 3, def: 'E03', gun: 1 }, { ph: 3, def: 'E08', gun: 0 }, { ph: 3, def: 'E01', gun: 2 }, { ph: 3, def: 'E06', gun: 1 },
];
function locTier(L) { return L.ph === 'start' ? (L.centre ? 2 : 1) : TUNE.phaseTier[L.ph - 1]; }
function locSize(L) { return ENVS[L.def].cache + (L.centre ? TUNE.hotBonus : 0) + (L.ph === 'start' ? 0 : TUNE.freshBonus); }
// ---------- setup ----------
function newGame(opts = {}) {
  const s = { v: '5.0', seed: (opts.seed ?? (Date.now() & 0x7fffffff)) | 0, round: 1, turnNo: 1, first: 0, turn: 0, over: false, winner: null,
    log: [], nid: 1, cards: {}, weapons: {}, atts: {}, envs: [], lootDeck: [], players: [], lastFire: null, finalDmg: 0 };
  s.players = [mkPlayer(0, (opts.names && opts.names[0]) || 'You'), mkPlayer(1, (opts.names && opts.names[1]) || 'Rival')];
  for (const pl of s.players) { for (const id of ['T001', 'T002', 'T004', 'T005']) for (let c = 0; c < ({ T001: TUNE.stSprint, T002: TUNE.stScout, T004: TUNE.stAim }[id] ?? CARDS[id].copies); c++) pl.deck.push(newCard(s, id)); shuffle(s, pl.deck); }
  s.loot = { 1: [], 2: [], 3: [] };
  for (const id in CARDS) if (CARDS[id].tier) for (let c = 0; c < CARDS[id].copies; c++) s.loot[CARDS[id].tier].push({ kind: 'card', iid: newCard(s, id) });
  const classes = Object.keys(GUNCLASS).filter(k => k !== 'pistol');
  if (TUNE.physical) { for (const t of [1, 2, 3]) for (const id of GUNSET[t]) s.loot[t].push({ kind: 'weapon', iid: newWeapon(s, id) }); }
  else for (const t of [1, 2, 3]) for (const r of GUN_LOOT_RARITY[t]) { const k = classes[Math.floor(rng(s) * classes.length)]; s.loot[t].push({ kind: 'weapon', iid: newWeapon(s, `${k}-${r}`) }); }
  for (const t of [1, 2, 3]) shuffle(s, s.loot[t]);
  s.lootDeck = s.loot[1];
  const bag = shuffle(s, Object.keys(ENVS).concat(Object.keys(ENVS))); const mid = (TUNE.zones - 1) / 2;
  const types = []; while (types.length < TUNE.zones) { const d = bag.shift(); if (types[types.length - 1] === d) bag.push(d); else types.push(d); }
  types.forEach((def, w) => { const hot = Math.abs(w - mid) < 1; s.envs.push(mkEnv(def, w, hot ? TUNE.hotBonus : 0, hot ? 'hot' : null, hot ? 2 : 1)); });
  s.revealed = 0;
  s.envDeck = bag.slice(0, TUNE.newZones); s.phase = 1;
  if (TUNE.phases) { const pool = shuffle(s, Object.keys(ENVS).concat(Object.keys(ENVS), Object.keys(ENVS))); s.envDeck = []; TUNE.phaseDeck.forEach((n, i) => { for (let k = 0; k < n; k++) s.envDeck.push(pool.shift()); }); s.envPh = []; TUNE.phaseDeck.forEach((n, i) => { for (let k = 0; k < n; k++) s.envPh.push(i + 1); }); }
  if (TUNE.physical) {
    // the 6 Start cards: centre pair in the middle, the other four shuffled around them
    s.envs = [];
    const st = LOCSET.filter(L => L.ph === 'start'); const outer = shuffle(s, st.filter(L => !L.centre)); const cen = shuffle(s, st.filter(L => L.centre));
    const row = cen.length ? [outer[0], outer[1], cen[0], cen[1], outer[2], outer[3]] : outer;
    row.forEach((L, w) => { const e = mkEnv(L.def, w, L.centre ? TUNE.hotBonus : 0, L.centre ? 'hot' : null, locTier(L)); e.gunAt = L.gun; s.envs.push(e); });
    // new-ground deck: phase 1 on top, then 2, then 3 — each phase shuffled
    s.newGround = []; for (const ph of [1, 2, 3]) s.newGround.push(...shuffle(s, LOCSET.filter(L => L.ph === ph)));
    s.envDeck = s.newGround.map(L => L.def); s.envPh = s.newGround.map(L => L.ph);
  }
  s.perkDeck = shuffle(s, Object.keys(LOADOUT));
  if (TUNE.stationCopies) { s.stationLeft = {}; for (const id of TUNE.station) s.stationLeft[id] = TUNE.stationCopies; }
  const a = rng(s) < 0.5; s.players[0].pos = a ? TUNE.startA : TUNE.startB; s.players[1].pos = a ? TUNE.startB : TUNE.startA;
  s.first = rng(s) < 0.5 ? 0 : 1; s.turn = s.first;
  s.closeSide = s.players[s.first].pos === TUNE.startB ? 'left' : 'right'; // the second player's side closes first
  for (const pl of s.players) pl.guns[TUNE.slots && !TUNE.lite ? 1 : 0] = newWeapon(s, 'pistol-0'); // everyone drops in with a Common pistol
  if (TUNE.stacks) for (const q of [0, 1]) flip(s, envAt(s, s.players[q].pos), null);
  if (TUNE.phases) for (const q of [0, 1]) dealPerks(s, q);
  drawCards(s, s.first, TUNE.firstHand); drawCards(s, 1 - s.first, TUNE.hand + TUNE.secondExtraCards);
  s.players[1 - s.first].res.intel += TUNE.secondIntel;
  s.players[1 - s.first].def += TUNE.secondArmor;
  log(s, `Round 1. ${s.players[s.first].name} goes first (with ${TUNE.firstHand} cards).`, 'round');
  return s;
}
function mkEnv(def, w, extra, tag, tier) { return { w, def, tier: tier || 1, state: 'safe', hot: tag === 'hot', fresh: tag === 'fresh', loot: [], cache: { reveal: ENVS[def].cache + (extra || 0), searched: false }, crate: null }; }
function safeBounds(s) { const w = s.envs.filter(e => e.state === 'safe').map(e => e.w); return { lo: Math.min(...w), hi: Math.max(...w), n: w.length }; }
function nextEdge(s) { const b = safeBounds(s); if (b.n <= 1) return null; return s.closeSide === 'right' ? b.hi : b.lo; }
function inSafe(s, w) { const e = envAt(s, w); return !!e && e.state === 'safe'; }

// ---------- effects ----------
function checkCond(s, p, c) { const pl = P(s, p); if (c === 'notMoved') return !pl.moved; if (c === 'movedToward') return pl.movedToward; if (c === 'shareOrAdjacent') return dist(s) <= 1; return false; }
function burnScore(s, iid) { const d = cardDef(s, iid); const b = { T001: 0, T006: 1, T002: 1, T004: 3, T005: 4, K01: 5, K02: 6, K03: 6, K04: 7, T005: 6 }[d.id]; return b != null ? b : 20 + d.intel_cost * 3 + d.hit_markers; }
function runEffects(s, p, effs, ctx) { for (const e of effs) runEffect(s, p, e, ctx); }
function runEffect(s, p, e, ctx) {
  const pl = P(s, p);
  switch (e.op) {
    case 'gain': if (e.res === 'def') pl.def += e.n; else if (e.res === 'shot') pl.shot += e.n; else pl.res[e.res] += e.n; ctx.out.push(`+${e.n} ${RES_LABEL[e.res]}`); if (pl.gen && e.res in pl.gen) { pl.gen[e.res] += e.n; perkTriggers(s, p, ctx); } break;
    case 'draw': ctx.out.push(`Draw ${drawCards(s, p, e.n)}`); break;
    case 'nextFire': if (e.reqMod) { pl.nextFire.reqMod += e.reqMod; ctx.out.push(`Next shot −${e.reqMod} Hit`); } if (e.bonusPrec) { pl.nextFire.bonusPrec += e.bonusPrec; ctx.out.push(`Next shot reveals +${e.bonusPrec}`); } if (e.dmg) { pl.nextFire.dmg = (pl.nextFire.dmg || 0) + e.dmg; ctx.out.push(`Next hit +${e.dmg} damage`); } break;
    case 'recoilTurn': pl.recoilTurn = TUNE.recoilStack ? pl.recoilTurn + e.n : Math.max(pl.recoilTurn, e.n); ctx.out.push(`Shots ignore ${e.n} Recoil this turn`); break;
    case 'cond': if (checkCond(s, p, e.if)) runEffects(s, p, e.then, ctx); else ctx.out.push(`(not ${COND_LABEL[e.if]})`); break;
    case 'suppressArm': pl.suppressArm = e.n; ctx.out.push('Suppression armed'); break;
    case 'burnDiscard': { if (owned(pl) <= TUNE.minDeck) { ctx.out.push(`Deck at ${TUNE.minDeck}-card minimum: no burn`); break; } const c = pl.discard.filter(x => !ctx.exclude.includes(x)); const t = (ctx.pick && c.includes(ctx.pick)) ? ctx.pick : c.sort((a, b) => burnScore(s, a) - burnScore(s, b))[0]; if (t) { pl.discard.splice(pl.discard.indexOf(t), 1); pl.removed.push(t); pl.stats.burned++; ctx.out.push(`Burned ${cardDef(s, t).name}`); } else ctx.out.push('Nothing to burn'); break; }
    case 'burnHand': { if (owned(pl) <= TUNE.minDeck) { ctx.out.push(`Deck at ${TUNE.minDeck}-card minimum: no burn`); break; } const c = pl.hand.filter(x => !ctx.exclude.includes(x)); const t = (ctx.pick && c.includes(ctx.pick)) ? ctx.pick : c.sort((a, b) => burnScore(s, a) - burnScore(s, b))[0]; if (t) { pl.hand.splice(pl.hand.indexOf(t), 1); pl.removed.push(t); pl.stats.burned++; ctx.out.push(`Burned ${cardDef(s, t).name}`); runEffects(s, p, e.then, ctx); } else ctx.out.push('Nothing to burn'); break; }
    case 'lootDiscount': pl.lootDiscount += e.n; ctx.out.push(`Next buy −${e.n}`); break;
    case 'scrap': pl.scrapAvail = (pl.scrapAvail || 0) + e.n; ctx.out.push(`Scrap ${e.n} available`); break;
    case 'searchExtra': pl.searches += e.n; ctx.out.push('+1 Search'); break;
    case 'mag': pl.magBonus = (pl.magBonus || 0) + e.n; ctx.out.push(`+${e.n} magazine`); break;
    case 'ammo': pl.freeAmmo = (pl.freeAmmo || 0) + e.n; ctx.out.push(`${e.n} free bullet${e.n > 1 ? 's' : ''}`); break;
    case 'ignoreCover': pl.ignoreCover = true; ctx.out.push('shots ignore cover'); break;
    case 'revealPlus': pl.revealPlus = (pl.revealPlus || 0) + e.n; ctx.out.push(`every shot reveals +${e.n}`); break;
    case 'cycleFree': pl.freeCycles = (pl.freeCycles || 0) + e.n; ctx.out.push(`${e.n} free cycle`); break;
  }
}

// ---------- turn checks ----------
function check(s, p) { if (s.over) return fail('The match is over.'); if (s.turn !== p) return fail("It isn't your turn."); if (P(s, p).perkOffer) return fail('Draft a perk first.'); return null; }

function playCard(s, p, iid, o = {}) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!pl.hand.includes(iid)) return fail('That card is not in your hand.');
  const def = cardDef(s, iid);
  pl.hand.splice(pl.hand.indexOf(iid), 1); pl.play.push(iid);
  const ctx = { out: [], exclude: [iid], pick: o.pick };
  runEffects(s, p, def.effects, ctx);
  if (TUNE.combos) checkCombos(s, p, ctx);
  if (TUNE.allies && def.ally) checkAllies(s, p, def.archetype, ctx);
  if (TUNE.mastery && def.archetype !== 'starter') checkMastery(s, p, def.archetype, ctx);
  log(s, `${pl.name} plays ${def.name}${ctx.out.length ? ': ' + ctx.out.join(', ') : ''}.`, 'play');
  return { ok: true, out: ctx.out };
}
// Combos are order-free: a combo fires as soon as a card of its partner role has been played this turn (before or after).
const SQUAD = { 3: [gain('prec', 2), { op: 'ammo', n: 1 }], 4: [draw(2), { op: 'ignoreCover' }] };
const SQUAD_TEXT = { 3: '+2 Precision and 1 free bullet', 4: 'draw 2 cards and your shots ignore cover' };
function rolesPlayed(s, p) { const pl = P(s, p); return new Set(pl.play.map(i => cardDef(s, i).archetype).filter(a => NEIGHBOURS[a])); }
function checkCombos(s, p, ctx) {
  const pl = P(s, p); const roles = rolesPlayed(s, p); pl.comboDone = pl.comboDone || [];
  const cnt = {}; for (const i of pl.play) { const a = cardDef(s, i).archetype; cnt[a] = (cnt[a] || 0) + 1; }
  for (const i of pl.play) { const d = cardDef(s, i); (d.combos || []).forEach((c, k) => { const key = i + ':' + k; if (pl.comboDone.includes(key)) return;
    const rs = [].concat(c.role); if (!rs.some(r => ((cnt[r] || 0) - (d.archetype === r ? 1 : 0)) >= 1)) return;
    pl.comboDone.push(key); const c2 = { out: [], exclude: [] }; runEffects(s, p, c.eff, c2); pl.stats.combos = (pl.stats.combos || 0) + 1; ctx.out.push(`${d.name} combo (${[].concat(c.role).map(r => ARCH_TAG[r]).join('/')}): ${c2.out.join(', ')}`); }); }
  const sq = new Set(roles); { const g0 = pl.guns[0] && WEAPONS[s.weapons[pl.guns[0]].def]; if (TUNE.squadGun && g0 && g0.gcombo) sq.add(g0.gcombo.role); }
  if (TUNE.squad && sq.size >= 3 && !pl.squad3) { pl.squad3 = true; const c2 = { out: [], exclude: [] }; runEffects(s, p, SQUAD[3], c2); pl.stats.squads = (pl.stats.squads || 0) + 1; ctx.out.push(`SQUAD (3 roles): ${c2.out.join(', ')}`); }
  if (TUNE.squad && sq.size >= 4 && !pl.squad4) { pl.squad4 = true; const c2 = { out: [], exclude: [] }; runEffects(s, p, SQUAD[4], c2); pl.stats.fullSquads = (pl.stats.fullSquads || 0) + 1; ctx.out.push(`FULL SQUAD (4 roles): ${c2.out.join(', ')}`); }
  const pw = pl.guns[0] && WEAPONS[s.weapons[pl.guns[0]].def];
  if (pw && pw.gcombo && pl.gunCombo !== s.turnNo && roles.has(pw.gcombo.role)) { pl.gunCombo = s.turnNo; const c2 = { out: [], exclude: [] }; runEffects(s, p, pw.gcombo.eff, c2); pl.stats.gunCombos = (pl.stats.gunCombos || 0) + 1; ctx.out.push(`${pw.baseName} combo: ${c2.out.join(', ')}`); }
}
function playAll(s, p) { const pl = P(s, p); const e = check(s, p); if (e) return e; for (const iid of pl.hand.slice()) if (!cardDef(s, iid).jam && !cardDef(s, iid).effects.some(x => x.op === 'burnHand')) playCard(s, p, iid); return { ok: true }; }

// Ally: a card's Ally bonus triggers once you've played another card of the same archetype this turn,
// or you carry a gun of that archetype.
function allyReady(s, p, arch, iid) { const pl = P(s, p); return pl.play.some(i => i !== iid && cardDef(s, i).archetype === arch) || (TUNE.gunAlly && guns(pl).some(w => WEAPONS[s.weapons[w].def].archetype === arch)); }
function checkAllies(s, p, arch, ctx) {
  const pl = P(s, p);
  for (const i of pl.play) { const d = cardDef(s, i); if (d.archetype !== arch || !d.ally || pl.allyDone.includes(i) || !allyReady(s, p, arch, i)) continue;
    pl.allyDone.push(i); const c2 = { out: [], exclude: [i] }; runEffects(s, p, d.ally, c2); pl.stats.allies = (pl.stats.allies || 0) + 1; ctx.out.push(`Ally (${d.name}): ${c2.out.join(', ')}`); }
}
// Perks: owning 3 / 5 bought cards of one archetype unlocks a permanent bonus applied at the start of each turn.
const PERKS = {
  assault: [{ n: 4, name: 'Quick Feet', text: '+1 Movement every turn', eff: [gain('move', 1)] }, { n: 6, name: 'Run and Gun', text: '+1 extra shot every turn', eff: [gain('shot', 1)] }],
  support: [{ n: 4, name: 'Flak Jacket', text: '+2 Armor every turn', eff: [gain('def', 2)] }, { n: 6, name: 'Steady Grip', text: 'your shots ignore 1 Recoil', eff: [{ op: 'recoilTurn', n: 1 }] }],
  recon: [{ n: 4, name: 'Marksman', text: '+1 Precision every turn', eff: [gain('prec', 1)] }, { n: 6, name: 'Dead Aim', text: 'your first shot needs 1 fewer Hit Marker', eff: [nextFire({ reqMod: 1 })] }],
  engineer: [{ n: 4, name: 'Scrounger', text: '+2 Intel and +1 Precision every turn', eff: [gain('intel', 2), gain('prec', 1)] }, { n: 6, name: 'Pack Rat', text: '+1 Search and +1 Precision every turn', eff: [{ op: 'searchExtra', n: 1 }, gain('prec', 1)] }],
};
// Loadout perks: drafted at the start of each phase (deal 3, keep 1). Triggers fire once per turn.
const LOADOUT = {
  doubletime: { name: 'Double Time', arch: 'assault', trig: { res: 'move', n: 3 }, eff: [{ op: 'ammo', n: 1 }], text: 'When you gain 3+ Movement in a turn: 1 free bullet.' },
  ninja: { name: 'Ninja', arch: 'assault', text: 'Getting into cover costs no extra Movement.' },
  tempered: { name: 'Tempered', arch: 'support', trig: { res: 'prec', n: 4 }, eff: [{ op: 'recoilTurn', n: 1 }], text: 'When you gain 4+ Precision in a turn: −1 Recoil.' },
  battle: { name: 'Battle Hardened', arch: 'support', text: 'The first hit against you each rival turn deals 1 less damage.' },
  coldblooded: { name: 'Cold-Blooded', arch: 'recon', trig: { res: 'prec', n: 4 }, eff: [nextFire({ reqMod: 1, dmg: 1 })], text: 'When you gain 4+ Precision in a turn: your next shot needs 1 fewer Hit Marker on every step and deals +1 damage.' },
  amped: { name: 'Overkill', arch: 'support', text: 'Your secondary gun gets +1 shot per turn and its shots cost no ammo.' },
  looter: { name: 'Scavenger', arch: 'engineer', trig: { res: 'intel', n: 3 }, eff: [draw(1)], text: 'When you gain 3+ Intel in a turn: draw 1 card.' },
  spotter: { name: 'Spotter', arch: 'engineer', text: 'Your first loot purchase each turn costs 1 less Intel (min 1).' },
  restock: { name: 'Restock', arch: 'any', text: 'Each time you Scrap a card: +3 Intel.' },
  hardline: { name: 'Hardline', arch: 'any', text: 'Buy Station cards cost 1 Intel.' },
  quickfix: { name: 'Quick Fix', arch: 'any', text: 'Your first Buy Station purchase each turn heals 2 Health.' },
  eod: { name: 'E.O.D.', arch: 'any', text: 'Gas and storm damage against you −2.' },
};
const hasPerk = (pl, k) => (pl.perks || []).includes(k);
function dealPerks(s, p) {
  const pl = P(s, p); if (!TUNE.perks || !s.perkDeck.length) return;
  pl.perkOffer = s.perkDeck.splice(0, Math.min(TUNE.perkDraft, s.perkDeck.length));
}
function pickPerk(s, p, k) {
  const pl = P(s, p); if (s.over) return fail('The match is over.');
  if (!pl.perkOffer || !pl.perkOffer.includes(k)) return fail('That perk is not on offer.');
  pl.perks.push(k); s.perkDeck.push(...pl.perkOffer.filter(x => x !== k)); shuffle(s, s.perkDeck); pl.perkOffer = null;
  log(s, `${pl.name} drafts the ${LOADOUT[k].name} perk.`, 'fx');
  // a trigger perk drafted mid-turn checks right away
  perkTriggers(s, p, { out: [], exclude: [] });
  return { ok: true };
}
function perkTriggers(s, p, ctx) {
  const pl = P(s, p); if (!pl.gen) return;
  for (const k of pl.perks || []) { const L = LOADOUT[k]; if (!L.trig || pl.perkFired.includes(k) || s.turn !== p) continue;
    if (pl.gen[L.trig.res] >= L.trig.n) { pl.perkFired.push(k); const c2 = { out: [], exclude: [] }; runEffects(s, p, L.eff, c2); pl.stats.perkFires = (pl.stats.perkFires || 0) + 1; log(s, `${pl.name}’s ${L.name} triggers: ${c2.out.join(', ')}.`, 'fx'); } }
}
function aiPickPerk(s, p) {
  const pl = P(s, p); if (!pl.perkOffer) return; const c = archCounts(s, p);
  guns(pl).forEach(w => { const a = WEAPONS[s.weapons[w].def].archetype; c[a] = (c[a] || 0) + 2; });
  const base = { doubletime: 1, ninja: 0.8, tempered: 1.4, battle: 2.2, coldblooded: 1.2, amped: 1.4, looter: 1.2, spotter: s.phase === 1 ? 2 : 1, restock: 1.2, hardline: 1.6, quickfix: 1.8, eod: 1.2 };
  const sc = k => base[k] + (LOADOUT[k].arch !== 'any' ? 0.5 * (c[LOADOUT[k].arch] || 0) : 0) + rng(s) * 0.8;
  const best = pl.perkOffer.slice().sort((a, b) => sc(b) - sc(a))[0]; pickPerk(s, p, best);
}
function archCounts(s, p) { const pl = P(s, p); const c = { assault: 0, support: 0, recon: 0, engineer: 0 }; pl.deck.concat(pl.discard, pl.hand, pl.play, pl.fuelled || []).forEach(i => { const a = cardDef(s, i).archetype; if (a in c) c[a]++; }); return c; }
function perksOf(s, p) { const c = archCounts(s, p); const out = []; for (const a in PERKS) for (const k of PERKS[a]) if (c[a] >= k.n) out.push(Object.assign({ arch: a }, k)); return out; }
function applyPerks(s, p) {
  if (!TUNE.perks) return; const ps = perksOf(s, p); if (!ps.length) return; const ctx = { out: [], exclude: [] };
  for (const k of ps) { runEffects(s, p, k.eff, ctx); } P(s, p).stats.perkTurns = (P(s, p).stats.perkTurns || 0) + ps.length;
  log(s, `${P(s, p).name}’s perks: ${ps.map(k => k.name).join(', ')} (${ctx.out.join(', ')}).`, 'play');
}
// Gun Mastery: once per turn, a gun gets +1 Precision and +1 extra shot when you've played 2+ cards of its archetype.
function checkMastery(s, p, arch, ctx) {
  const pl = P(s, p); const n = pl.play.filter(i => cardDef(s, i).archetype === arch).length; if (n < 2) return;
  for (const w of guns(pl)) { const W = s.weapons[w]; const d = WEAPONS[W.def]; if (d.archetype !== arch || W.masteryTurn === s.turnNo) continue;
    W.masteryTurn = s.turnNo; pl.res.prec += 1; pl.shot += 1; pl.stats.mastery = (pl.stats.mastery || 0) + 1; ctx.out.push(`${d.name} Mastery: +1 Precision, +1 extra shot`); }
}
// Gun tactical: free and automatic at the start of your turn (and when you pick the gun up).
function autoTactical(s, p, wid) {
  const W = s.weapons[wid]; if (W.tacTurn === s.turnNo) return;
  W.tacTurn = s.turnNo; const d = WEAPONS[W.def]; const ctx = { out: [], exclude: [] };
  runEffects(s, p, d.tactical_main_effects, ctx);
  if (!ctx.out.length) return;
  log(s, `${P(s, p).name}’s ${d.name}: ${ctx.out.join(', ')}.`, 'play');
}
// Boost: once per turn per gun, burn a card from hand to trigger the gun's Boost.
function boostOk(s, p, gi, fuel) {
  const pl = P(s, p); const W = s.weapons[pl.guns[gi]]; const d = WEAPONS[W.def];
  if (!pl.hand.includes(fuel)) return 'Fuel must come from your hand.';
  if (TUNE.fuelAnyCard) return null;
  if (d.tactical_boost_requirement === 'min' && hmOf(s, fuel) < d.tactical_boost_min_hit_markers) return `Boost needs a card with ${d.tactical_boost_min_hit_markers}+ Hit Markers.`;
  return null;
}
function eligibleFuel(s, p, gi) { return P(s, p).hand.filter(i => !boostOk(s, p, gi, i)); }
function activateGun(s, p, gi, fuel) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const wid = pl.guns[gi]; if (!wid) return fail('No gun in that slot.');
  const W = s.weapons[wid]; const d = WEAPONS[W.def];
  if (W.used) return fail(`${d.name} is already boosted this turn.`);
  if (!fuel) return fail('Choose a card from your hand as fuel.');
  if (fuel) { const b = boostOk(s, p, gi, fuel); if (b) return fail(b); }
  W.used = true; W.usedTurn = s.turnNo; const ctx = { out: [], exclude: [] };
  pl.hand.splice(pl.hand.indexOf(fuel), 1); pl.fuelled.push(fuel);
  runEffects(s, p, d.tactical_boost_effects, ctx);
  if (hasPerk(pl, 'amped') && !pl.ampUsed && guns(pl).length === 2 && guns(pl).every(w => s.weapons[w].used)) { pl.ampUsed = true; pl.res.prec += 1; ctx.out.push('Amped: +1 Precision'); }
  log(s, `${pl.name} boosts ${d.name} (fuel: ${cardDef(s, fuel).name}): ${ctx.out.join(', ')}.`, 'play');
  return { ok: true, out: ctx.out };
}

// ---------- movement ----------
function moveCost(s, p, tw) { const pl = P(s, p); if (!envAt(s, tw) || tw === pl.pos) return null; return Math.abs(tw - pl.pos) + (TUNE.enterCover && !hasPerk(pl, 'ninja') ? ENVS[envAt(s, tw).def].cover : 0); }
function reachable(s, p) { const pl = P(s, p); return s.envs.map(e => ({ w: e.w, cost: moveCost(s, p, e.w) })).filter(r => r.cost != null && r.cost <= pl.res.move); }
function arriveBonus(s, p, env) {
  const pl = P(s, p); const d = ENVS[env.def]; if (env.state !== 'safe' || !d.bonus || pl.bonusTaken.includes(env.w)) return '';
  pl.bonusTaken.push(env.w); const b = d.bonus; const out = [];
  if (b.draw) { drawCards(s, p, b.draw); out.push(`draws ${b.draw}`); }
  if (b.intel) { pl.res.intel += b.intel; out.push(`+${b.intel} Intel`); }
  if (b.def) { pl.def += b.def; out.push(`+${b.def} Armor`); }
  if (b.prec) { pl.res.prec += b.prec; out.push(`+${b.prec} Precision`); }
  if (b.move) { pl.res.move += b.move; out.push(`+${b.move} Movement`); }
  if (b.ammo) { pl.freeAmmo = (pl.freeAmmo || 0) + b.ammo; out.push(`${b.ammo} free bullet`); }
  if (b.shot) { pl.shot += b.shot; out.push(`+${b.shot} extra shot`); }
  if (b.scrap) { pl.scrapAvail = (pl.scrapAvail || 0) + b.scrap; out.push(`Scrap ${b.scrap} available`); }
  if (b.cycle) { pl.freeCycles = (pl.freeCycles || 0) + b.cycle; out.push(`${b.cycle} free cycle`); }
  return out.length ? ` ${d.name}: ${out.join(', ')}.` : '';
}
function move(s, p, tw) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const cost = moveCost(s, p, tw); if (cost == null) return fail('Choose a different location.');
  if (cost > pl.res.move) return fail(`Needs ${cost} Movement (you have ${pl.res.move}).`);
  if (pl.moved && !TUNE.multiMove) return fail('You already moved this turn (one Move per turn).');
  const before = dist(s); pl.res.move -= cost; pl.pos = tw; pl.moved = true;
  if (TUNE.stacks) flip(s, envAt(s, tw), p);
  let extra = arriveBonus(s, p, envAt(s, tw));
  if (pl.pos === P(s, 1 - p).pos) extra += ' Close quarters: no cover for either.';
  if (dist(s) < before) pl.movedToward = true;
  log(s, `${pl.name} moves to ${ENVS[envAt(s, tw).def].name} (−${cost}).${extra}`, 'act');
  return { ok: true };
}

// ---------- market ----------
function deckFor(s, t) { for (const k of [t, t - 1, t + 1, t - 2, t + 2]) if (s.loot[k] && s.loot[k].length) return s.loot[k]; return []; }
// where the gun sits in a location's stack (printed on the location card as icons)
function gunSlot(s, env) {
  if (env.gunAt == null) env.gunAt = TUNE.gunPos === 'top' || (TUNE.gunPos === 'early' && !(env.phase > 1)) ? 0 : TUNE.gunPos === 'second' ? 1 : TUNE.gunPos === 'bottom' ? env.cache.reveal - 1 : Math.floor(rng(s) * env.cache.reveal);
  return env.gunAt;
}
function stackPlan(s, env) { const n = env.cache.reveal; const g = gunSlot(s, env); return Array.from({ length: n }, (_, i) => i === g ? 'weapon' : 'card'); }
function stackFor(s, env) {
  const items = []; const t = env.tier;
  const pickGun = tt => { for (const k of [tt, tt - 1, tt + 1, tt + 2]) { const D = s.loot[k] || []; const j = D.findIndex(it => it.kind === 'weapon'); if (j >= 0) return D.splice(j, 1)[0]; } return null; };
  const g = pickGun(t); if (g) items.push(g);
  const aff = ENVS[env.def].affinity; const want = env.cache.reveal; const nAff = TUNE.affinity ? Math.ceil((want - items.length) * TUNE.affinity) : 0;
  const D = deckFor(s, t);
  for (let i = 0; i < nAff; i++) { const j = D.findIndex(it => it.kind === 'card' && CARDS[s.cards[it.iid].def].archetype === aff); if (j < 0) break; items.push(D.splice(j, 1)[0]); }
  while (items.length < want) { const D2 = deckFor(s, t); const j = D2.findIndex(it => it.kind !== 'weapon'); if (j < 0) break; items.push(D2.splice(j, 1)[0]); }
  if (g && items.length > 1) { const pos = Math.min(gunSlot(s, env), items.length - 1); items.shift(); items.splice(pos, 0, g); }
  const cards = items.filter(x => x.kind === 'card'); // cards in affinity order are shuffled so the top isn't always the archetype card
  return items;
}
// Flip a location's stack face up (first time anyone stands there). Only the top card can be bought.
function flip(s, env, p) {
  if (!env || env.cache.searched || env.state !== 'safe') return false;
  env.cache.searched = true; const items = stackFor(s, env); env.loot.unshift(...items);
  if (env.loot[0]) env.loot[0].seen = true;
  if (p != null) { P(s, p).stats.searches++; log(s, `${P(s, p).name} flips the loot at ${ENVS[env.def].name}: ${env.loot.length} card${env.loot.length === 1 ? '' : 's'}, ${env.loot[0] ? itemDef(s, env.loot[0]).name : 'nothing'} on top.`, 'fx'); }
  return true;
}
function cycle(s, p, pay) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const env = envAt(s, pl.pos); if (!env || !env.cache.searched) return fail('Nothing to cycle here.');
  if (env.loot.length < 2) return fail('Only one card in this stack.');
  let how;
  if (pl.freeCycles > 0) { pl.freeCycles--; how = 'free'; }
  else if (false && hasPerk(pl, 'spotter') && (pl.spotUsed || 0) < 1) { pl.spotUsed = (pl.spotUsed || 0) + 1; how = 'Spotter, free'; }
  else if (pay === 'move') { if (pl.res.move < TUNE.cycleCost) return fail('Cycling costs 1 Movement or 1 Intel.'); pl.res.move -= TUNE.cycleCost; how = `−${TUNE.cycleCost} Movement`; }
  else { if (pl.res.intel < TUNE.cycleCost) return fail('Cycling costs 1 Intel or 1 Movement.'); pl.res.intel -= TUNE.cycleCost; how = `−${TUNE.cycleCost} Intel`; }
  const top = env.loot.shift(); env.loot.push(top); env.loot[0].seen = true; pl.stats.cycles = (pl.stats.cycles || 0) + 1;
  log(s, `${pl.name} cycles ${itemDef(s, top).name} to the bottom (${how}): ${itemDef(s, env.loot[0]).name} on top.`, 'act');
  return { ok: true };
}
function searchable(s, p) {
  if (TUNE.stacks) return null;
  const pl = P(s, p); const env = envAt(s, pl.pos); if (!env || env.state !== 'safe') return null;
  if (env.crate && !env.crate.searched) return 'crate';
  if (!env.cache.searched) return 'cache';
  return null;
}
function search(s, p) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (pl.searches < 1) return fail('You already searched this turn.');
  const which = searchable(s, p); if (!which) return fail('Nothing hidden here.');
  const env = envAt(s, pl.pos); const items = [];
  const deckFor = t => { for (const k of [t, t - 1, t + 1, t - 2, t + 2]) if (s.loot[k] && s.loot[k].length) return s.loot[k]; return []; };
  if (which === 'crate') {
    env.crate.searched = true;
    for (let i = 0; i < TUNE.crate[1]; i++) { const D = deckFor(3); const j = D.findIndex(it => it.kind === 'weapon'); if (j >= 0) items.push(D.splice(j, 1)[0]); else { const D2 = deckFor(2); const j2 = D2.findIndex(it => it.kind === 'weapon'); if (j2 >= 0) items.push(D2.splice(j2, 1)[0]); } }
    while (items.length < TUNE.crate[0]) { const D = deckFor(3); const j = D.findIndex(it => it.kind !== 'weapon'); if (j < 0) break; items.push(D.splice(j, 1)[0]); }
  } else {
    env.cache.searched = true; const aff = ENVS[env.def].affinity; const nAff = TUNE.affinity ? Math.ceil(env.cache.reveal * TUNE.affinity) : 0;
    const D = deckFor(env.tier);
    for (let i = 0; i < nAff; i++) { const j = D.findIndex(it => it.kind === 'card' && CARDS[s.cards[it.iid].def].archetype === aff); if (j < 0) break; items.push(D.splice(j, 1)[0]); }
    const want = env.cache.reveal + (hasPerk(pl, 'spotter') ? 1 : 0);
    while (items.length < want) { const D2 = deckFor(env.tier); if (!D2.length) break; items.push(D2.pop()); }
  }
  pl.searches--; pl.stats.searches++;
  env.loot.push(...items);
  log(s, `${pl.name} searches ${which === 'crate' ? 'the supply crate' : ENVS[env.def].name}: ${items.map(it => itemDef(s, it).name).join(', ') || 'nothing'}.`, 'fx');
  return { ok: true, ids: items.map(it => it.iid) };
}
function lootNear(s, p, id) {
  const pl = P(s, p);
  for (const w of [pl.pos, pl.pos - 1, pl.pos + 1]) { const e = envAt(s, w); if (!e || (w !== pl.pos && e.state !== 'safe')) continue; if (TUNE.stacks && !e.cache.searched) continue; const it = TUNE.stacks ? (e.loot[0] && e.loot[0].iid === id ? e.loot[0] : null) : e.loot.find(x => x.iid === id); if (it) return { it, env: e, adj: w !== pl.pos }; }
  return null;
}
function lootCost(s, p, item, noDiscount) {
  const pl = P(s, p); const here = envAt(s, pl.pos); let c = itemDef(s, item).intel_cost - (noDiscount ? 0 : pl.lootDiscount);
  const near = lootNear(s, p, item.iid); if (near && near.adj) c += TUNE.adjCost;
  if (hasPerk(pl, 'spotter') && !noDiscount && !pl.spotUsed && c > 1) c -= 1;
  if (item.kind === 'card' && itemDef(s, item).tier >= 2) c -= TUNE.cardDisc * (itemDef(s, item).tier - 1);
  if (item.kind === 'att' && ENVS[here.def].special === 'bench') c -= 1;
  return Math.max(0, c);
}
function buyTotal(s, p, iids) { let t = 0; iids.forEach((id, i) => { const n = lootNear(s, p, id); if (n) t += lootCost(s, p, n.it, i > 0); }); return t; }
// o.tradeIn: starter cards from hand (1 Intel each, burned); o.replace: gun slot to drop; o.attachTo: gun slot
function buy(s, p, iids, o = {}) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const list = (Array.isArray(iids) ? iids : [iids]).filter((x, i, a) => a.indexOf(x) === i);
  if (!list.length) return fail('Pick something.');
  const env = envAt(s, pl.pos);
  const near = list.map(id => lootNear(s, p, id)); const items = near.map(n => n && n.it);
  if (items.some(x => !x)) return fail('You can only buy the top card of a stack where you stand or next door (+1 Intel).');
  if (items.filter(x => x.kind === 'weapon').length > 1) return fail('Take one gun at a time.');
  if (items.some(x => x.kind === 'att') && !guns(pl).length) return fail('You need a gun to mount an attachment.');
  const trade = (o.tradeIn || []).filter((x, i, a) => a.indexOf(x) === i && pl.hand.includes(x) && isStarter(s, x));
  const total = buyTotal(s, p, list); const tv = trade.length * TUNE.tradeIn;
  if (pl.res.intel + tv < total) return fail(`Needs ${total} Intel (you have ${pl.res.intel}${tv ? ` + ${tv} trade-in` : ''}).`);
  if (tv > total) return fail('Trade in only what you need.');
  for (const t of trade) { pl.hand.splice(pl.hand.indexOf(t), 1); pl.removed.push(t); pl.stats.tradeIns++; pl.stats.burned++; }
  pl.res.intel -= total - tv; pl.lootDiscount = 0;
  const got = []; const pendingTac = [];
  for (const item of items) {
    const src = near[items.indexOf(item)].env; src.loot.splice(src.loot.indexOf(item), 1); if (src.loot[0]) src.loot[0].seen = true; let extra = src.w !== pl.pos ? ' (from next door)' : '';
    if (item.kind === 'card') { pl.discard.push(item.iid); pl.stats.cardsAcquired++; }
    else if (item.kind === 'att') {
      const gi = o.attachTo != null && pl.guns[o.attachTo] ? o.attachTo : pl.guns[0] ? 0 : 1; const W = s.weapons[pl.guns[gi]];
      if (W.att) { env.loot.push({ kind: 'att', iid: W.att }); extra = `, dropping ${ATTS[s.atts[W.att].def].name}`; }
      W.att = item.iid; extra = ` onto ${WEAPONS[W.def].name}` + extra;
    } else {
      let gi = TUNE.lite ? 0 : TUNE.slots ? WEAPONS[s.weapons[item.iid].def].slot : pl.guns[0] == null ? 0 : pl.guns[1] == null ? 1 : (o.replace != null ? o.replace : 0);
      const old = pl.guns[gi];
      if (old) { env.loot.push({ kind: 'weapon', iid: old }); extra = `, dropping ${WEAPONS[s.weapons[old].def].name}`; }
      pl.guns[gi] = item.iid; pl.stats.weaponAcq++; extra = ' (loaded)' + extra;
      if (s.turn === p) { s.weapons[item.iid].shots = s.weapons[item.iid].shotTurn === s.turnNo ? s.weapons[item.iid].shots : 0; s.weapons[item.iid].used = s.weapons[item.iid].usedTurn === s.turnNo && s.weapons[item.iid].used; pendingTac.push(item.iid); }
    }
    got.push(itemDef(s, item).name + extra);
    if (TUNE.combos && item.kind === 'weapon' && s.turn === p) checkCombos(s, p, { out: [], exclude: [] });
  }
  for (const wid of pendingTac) setTimeout0(s, p, wid);
  log(s, `${pl.name} takes ${got.join(', ')} for ${total} Intel${trade.length ? ` (traded in ${trade.map(t => cardDef(s, t).name).join(', ')})` : ''}.`, 'act');
  if (hasPerk(pl, 'spotter')) pl.spotUsed = 1;
  return { ok: true };
}
function setTimeout0(s, p, wid) { autoTactical(s, p, wid); }
function plateCost(s, p) { return hasPerk(P(s, p), 'hardline') ? 1 : TUNE.supplyCost; }
function buySupply(s, p, id) {
  const pl = P(s, p); const e = check(s, p); if (e) return e; id = id || TUNE.station[0];
  if (!TUNE.station.includes(id)) return fail('Not sold at the Buy Station.');
  if (s.stationLeft && !(s.stationLeft[id] > 0)) return fail(`${CARDS[id].name} is sold out.`);
  const cost = plateCost(s, p); if (pl.res.intel < cost) return fail(`Buy Station cards cost ${cost} Intel.`);
  pl.res.intel -= cost; if (hasPerk(pl, 'quickfix') && !pl.qfUsed && pl.hp < TUNE.hp) { pl.qfUsed = true; const h = Math.min(2, TUNE.hp - pl.hp); pl.hp += h; log(s, `${pl.name}’s Quick Fix heals ${h}.`, 'fx'); } if (s.stationLeft) s.stationLeft[id]--; const iid = newCard(s, id); pl.discard.push(iid); pl.stats.cardsAcquired++; pl.stats.supply = (pl.stats.supply || 0) + 1;
  log(s, `${pl.name} buys ${CARDS[id].name} at the Buy Station.`, 'act'); return { ok: true };
}
function scrap(s, p, iid) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!(pl.scrapAvail > 0)) return fail('No Scrap available. Play a card with the Scrap (trash bin) icon.');
  const from = pl.discard.includes(iid) ? pl.discard : pl.hand.includes(iid) ? pl.hand : null;
  if (!from) return fail('Scrap takes a card from your hand or discard pile.');
  if (owned(pl) <= TUNE.minDeck) return fail(`Your deck is at the ${TUNE.minDeck}-card minimum.`);
  from.splice(from.indexOf(iid), 1); pl.removed.push(iid); pl.scrapAvail--; pl.stats.burned++;
  if (hasPerk(pl, 'restock')) { pl.res.intel += 3; log(s, `${pl.name}’s Restock: +3 Intel.`, 'fx'); }
  log(s, `${pl.name} scraps ${cardDef(s, iid).name} (out of the game).`, 'fx'); return { ok: true };
}
function canBench() { return false; }
function burnAtBench(s, p, iid) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!canBench(s, p)) return fail('Burning needs the Workbench (once per turn).');
  if (!pl.hand.includes(iid)) return fail('Choose a card from your hand.');
  pl.hand.splice(pl.hand.indexOf(iid), 1); pl.removed.push(iid); pl.benchUsed = true; pl.stats.burned++;
  log(s, `${pl.name} burns ${cardDef(s, iid).name} at the Workbench.`, 'fx');
  return { ok: true };
}

// ---------- fire ----------
function shotsLeft(s, p, gi) { const pl = P(s, p); const wid = pl.guns[gi]; if (!wid) return 0; if (TUNE.ammo) return Math.max(0, eff(s, wid).magazine_capacity + (pl.magBonus || 0) + (gi === 1 && hasPerk(pl, 'amped') ? 1 : 0) - s.weapons[wid].shots); return Math.max(0, eff(s, wid).magazine_capacity - s.weapons[wid].shots) + pl.shot; }
function ammoLeft(s, p) { const pl = P(s, p); return (pl.freeAmmo || 0) + pl.hand.length; }
function shotPreview(s, p, gi) {
  const pl = P(s, p), o = P(s, 1 - p); const wid = pl.guns[gi]; if (!wid) return null;
  const W = s.weapons[wid]; const E = eff(s, wid); const d = WEAPONS[W.def];
  const D = dist(s); const inBand = D >= E.band[0] && D <= E.band[1];
  const dpen = TUNE.distMode === 'band' ? (D === E.max_range ? -TUNE.sweetBonus : 0) : TUNE.distMode === 'sweet' ? Math.abs(dist(s) - E.max_range) : TUNE.distMode === 'beyond' ? Math.max(0, dist(s) - E.max_range) : TUNE.distMode === 'linear' ? dist(s) : Math.floor(dist(s) / TUNE.distDiv);
  const pre = TUNE.firstShotRecoil ? Math.max(0, E.recoil - pl.recoilTurn) : 0;
  const reveal = d.melee ? 0 : (TUNE.lite ? (E.reveal || 0) + pl.res.prec : Math.max(0, pl.res.prec - pre - dpen)) + pl.nextFire.bonusPrec + (pl.revealPlus || 0);
  const shift = TUNE.needPlus + pl.suppressed - pl.nextFire.reqMod;
  const steps = d.melee ? E.ladder.map(([h, dm]) => [0, dm + (pl.nextFire.dmg || 0)]) : E.ladder.map(([h, dm]) => [Math.max(1, h + shift), dm + (pl.nextFire.dmg || 0)]); const need = steps[0][0];
  const recoilDrop = Math.max(0, E.recoil - pl.recoilTurn);
  const tEnv = envAt(s, o.pos); const cover = tEnv.state === 'safe' && o.pos !== pl.pos && !pl.ignoreCover ? ENVS[tEnv.def].cover : 0;
  const fall = d.falloff && o.pos !== pl.pos ? d.falloff : 0; const net = dm => Math.max(1, dm - fall - cover);
  return { gi, pre, prec: pl.res.prec, distance: dpen, rawDistance: dist(s), bonusPrec: pl.nextFire.bonusPrec, reveal, need, base: E.hit_need, suppression: pl.suppressed, accuracy: pl.nextFire.reqMod, recoilDrop, cover, fall, damage: E.damage, dmg: net(steps[0][1]), steps: steps.map(([h, dm]) => [h, net(dm)]), rawSteps: steps, sweet: TUNE.distMode === 'band' && D === E.max_range, band: E.band, range: E.max_range, inRange: TUNE.distMode === 'band' ? inBand : TUNE.distMode !== 'linear' || dist(s) <= E.max_range, left: shotsLeft(s, p, gi) };
}
function shootCheck(s, p, gi) {
  const pl = P(s, p); const wid = pl.guns[gi];
  if (!wid) return fail('No gun in that slot.');
  if (TUNE.dropRound && s.round <= TUNE.dropRound) return fail('Round 1 is the drop: nobody can fire yet. Loot up and get in position.');
  if (shotsLeft(s, p, gi) < 1) return fail(`${WEAPONS[s.weapons[wid].def].name} has fired its magazine this turn.`);
  const E = eff(s, wid); if (TUNE.distMode === 'linear' && dist(s) > E.max_range) return fail(`Out of range: Distance ${dist(s)}, Range ${E.max_range}.`);
  if (TUNE.distMode === 'band' && (dist(s) < E.band[0] || dist(s) > E.band[1])) return fail(`${WEAPONS[s.weapons[wid].def].name} fires at distance ${E.band[0]}–${E.band[1]}. You are at ${dist(s)}.`);
  if (TUNE.ammo && !WEAPONS[s.weapons[wid].def].melee && ammoLeft(s, p) < 1 && !(gi === 1 && hasPerk(P(s, p), 'amped'))) return fail('No ammo: you need a card in hand (or a free bullet) to load.');
  if (!TUNE.ammo && !WEAPONS[s.weapons[wid].def].melee && shotPreview(s, p, gi).reveal < 1) return fail('Nothing to reveal: play Precision cards first.');
  return { ok: true };
}
function applyHit(s, ti, dmg) {
  const t = P(s, ti); const notes = [];
  // reaction cards in hand: the best one is used automatically
  const rx = t.hand.filter(i => cardDef(s, i).reaction).sort((a, b) => cardDef(s, b).reaction - cardDef(s, a).reaction)[0];
  if (rx && dmg > 1) { const r = Math.min(cardDef(s, rx).reaction, dmg - 1); dmg -= r; t.hand.splice(t.hand.indexOf(rx), 1); t.discard.push(rx); t.stats.reactions++; notes.push(`${cardDef(s, rx).name} reaction −${r}`); }
  if (hasPerk(t, 'battle') && !t.bhUsed && dmg > 1) { const r = Math.min(1, dmg - 1); dmg -= r; t.bhUsed = true; notes.push(`Battle Hardened −${r}`); }
  const ab = Math.min(t.def, dmg - 1); if (ab > 0) { t.def -= ab; dmg -= ab; notes.push(`Armor −${ab}`); }
  t.hp -= dmg; return { dealt: dmg, notes };
}
function checkDeath(s) {
  const d0 = s.players[0].hp <= 0, d1 = s.players[1].hp <= 0;
  if (!d0 && !d1) return;
  s.over = true; const [a, b] = s.players;
  s.winner = d0 && d1 ? (a.hp !== b.hp ? (a.hp > b.hp ? 0 : 1) : 'draw') : d0 ? 1 : 0;
  log(s, s.winner === 'draw' ? 'Both operators fall. Draw.' : `${s.players[s.winner].name} is the last operator standing.`, 'win');
}
function fire(s, p, gi, ammo) {
  const pl = P(s, p), o = P(s, 1 - p); const e = check(s, p); if (e) return e;
  const sc = shootCheck(s, p, gi); if (!sc.ok) return sc;
  let bullet = null, bulletHM = 0; const isMelee = WEAPONS[s.weapons[pl.guns[gi]].def].melee;
  if (TUNE.ammo && !isMelee) {
    if (gi === 1 && hasPerk(pl, 'amped')) { bullet = 'Overkill, free'; }
    else if (ammo === 'free' || (ammo == null && pl.freeAmmo > 0)) { if (!(pl.freeAmmo > 0)) return fail('No free bullets.'); pl.freeAmmo--; bullet = 'free bullet'; bulletHM = TUNE.freeBulletHM; }
    else { if (!pl.hand.includes(ammo)) return fail('Load a card from your hand as the bullet.'); pl.hand.splice(pl.hand.indexOf(ammo), 1); pl.fuelled.push(ammo); bullet = cardDef(s, ammo).name; bulletHM = TUNE.bulletCounts ? hmOf(s, ammo) : 0; pl.stats.loaded = (pl.stats.loaded || 0) + 1; }
  }
  const W = s.weapons[pl.guns[gi]]; const d = WEAPONS[W.def]; const sp = shotPreview(s, p, gi);
  if (TUNE.ammo) W.shots++; else if (W.shots >= eff(s, pl.guns[gi]).magazine_capacity) pl.shot--; else W.shots++; W.shotTurn = s.turnNo;
  const revealed = [];
  for (let i = 0; i < sp.reveal; i++) { if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s, pl.discard); pl.discard = []; } revealed.push(pl.deck.pop()); }
  const total = revealed.reduce((a, i) => a + hmOf(s, i), 0) + bulletHM;
  const jam = revealed.some(i => cardDef(s, i).jam);
  const hit = !jam && total >= sp.need;
  const before = pl.res.prec; pl.res.prec = Math.max(0, pl.res.prec - sp.recoilDrop);
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  pl.stats.shots++; if (jam) pl.stats.jams++;
  let dealt = 0, notes = [];
  if (hit) { pl.stats.hits++; pl.stats.hitsBy[W.def] = (pl.stats.hitsBy[W.def] || 0) + 1; const step = sp.steps.filter(([h]) => total >= h).pop(); const lvl = sp.steps.indexOf(step); pl.stats.steps = pl.stats.steps || [0, 0, 0]; pl.stats.steps[lvl]++; const r = applyHit(s, 1 - p, step[1]); if (lvl > 0) notes.push(lvl === 2 && WEAPONS[W.def].gunClass === 'sniper' ? 'HEADSHOT' : `step ${lvl + 1}`); dealt = r.dealt; notes = notes.concat(r.notes); if (sp.cover) notes.unshift(`cover −${sp.cover}`); if (sp.fall) notes.unshift(`range −${sp.fall}`); pl.stats.damageDealt += dealt; pl.stats.turnDmg += dealt;
    if (pl.suppressArm) { o.suppressedNext = pl.suppressArm; pl.suppressArm = 0; notes.push('enemy suppressed'); } }
  else pl.suppressArm = 0;
  pl.discard.push(...revealed);
  s.lastFire = { p, weapon: d.name, bullet: bullet ? { name: bullet, hm: bulletHM } : null, req: sp.need, steps: sp.steps, level: hit ? sp.steps.filter(([h]) => total >= h).length - 1 : -1, revealed: revealed.map(i => ({ name: cardDef(s, i).name, hm: hmOf(s, i), jam: !!cardDef(s, i).jam })), total, jam, hit, dealt, notes, short: revealed.length < sp.reveal, recoil: before - pl.res.prec };
  log(s, `${pl.name} fires ${d.name}${bullet ? ` (bullet: ${bullet})` : ''}: reveals ${revealed.length}${bulletHM ? ` + bullet ${bulletHM}` : ''}, needs ${sp.need}, gets ${total}${jam ? ' — JAMMED' : ''} → ${hit ? `HIT for ${dealt}${notes.length ? ` (${notes.join(', ')})` : ''}` : 'MISS'}.${before !== pl.res.prec ? ` Precision ${before}→${pl.res.prec}.` : ''}`, hit ? 'hit' : 'miss');
  checkDeath(s);
  return { ok: true, result: s.lastFire };
}
function punch(s, p) {
  if (!TUNE.punch) return fail('No melee without a knife.');
  const pl = P(s, p), o = P(s, 1 - p); const e = check(s, p); if (e) return e;
  if (pl.pos !== o.pos) return fail('Fists need the same location.');
  if (TUNE.dropRound && s.round <= TUNE.dropRound) return fail('Round 1 is the drop: nobody can fight yet.');
  if (pl.punched) return fail('One punch per turn.');
  pl.punched = true; o.hp -= 1; pl.stats.damageDealt += 1;
  s.lastFire = { p, fists: true, hit: true, dealt: 1 };
  log(s, `${pl.name} punches for 1 (ignores Armor).`, 'hit'); checkDeath(s);
  return { ok: true, result: s.lastFire };
}

// ---------- end of turn ----------
function startTurn(s, p) {
  const pl = P(s, p);
  pl.res.move = 0; pl.res.prec = 0; pl.def = 0; pl.shot = 0; pl.recoilTurn = 0; pl.lootDiscount = 0;
  pl.searches = 1; pl.freeCycles = 0; pl.magBonus = 0; pl.freeAmmo = 0; pl.ignoreCover = false; pl.revealPlus = 0; pl.comboDone = []; pl.squad3 = false; pl.squad4 = false; pl.spotUsed = 0; pl.allyDone = []; pl.benchUsed = false; pl.moved = false; pl.movedToward = false; pl.punched = false; pl.bonusTaken = [];
  pl.nextFire = { reqMod: 0, bonusPrec: 0 }; pl.suppressed = pl.suppressedNext || 0; pl.suppressedNext = 0;
  pl.gen = { move: 0, prec: 0, intel: 0, def: 0 }; pl.perkFired = []; pl.ampUsed = false; pl.restocked = false; pl.qfUsed = false; P(s, 1 - p).bhUsed = false;
  for (const wid of guns(pl)) { s.weapons[wid].shots = 0; s.weapons[wid].used = false; }
  pl.stats.turnDmg = 0;
  if (!TUNE.ammo) for (const wid of guns(pl)) autoTactical(s, p, wid);
  applyPerks(s, p);
  if (TUNE.stacks) flip(s, envAt(s, pl.pos), p);
  if (TUNE.locEveryTurn) { const env = envAt(s, pl.pos); if (env) { const t = arriveBonus(s, p, env); if (t) log(s, `${pl.name} holds${t}`, 'fx'); } }
}
function endTurn(s, p) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  pl.stats.maxTurnDmg = Math.max(pl.stats.maxTurnDmg, pl.stats.turnDmg);
  pl.discard.push(...pl.hand, ...pl.play); pl.hand = []; pl.play = [];
  if (pl.fuelled.length && !TUNE.fuelBurns) { pl.discard.push(...pl.fuelled); pl.fuelled = []; }
  pl.scrapAvail = 0;
  if (pl.fuelled.length) {
    const burn = [], keep = [];
    for (const i of pl.fuelled) { if (owned(pl) - burn.length > TUNE.minDeck) burn.push(i); else keep.push(i); }
    if (burn.length) { pl.removed.push(...burn); pl.stats.burned += burn.length; log(s, `${pl.name} burns the Boost fuel: ${burn.map(i => cardDef(s, i).name).join(', ')} (out of the game).`, 'fx'); }
    if (keep.length) { pl.discard.push(...keep); log(s, `${pl.name}'s deck is at the ${TUNE.minDeck}-card minimum: ${keep.map(i => cardDef(s, i).name).join(', ')} goes to the discard instead of burning.`, 'fx'); }
    pl.fuelled = [];
  }
  if (TUNE.digIn && pl.res.move > 0) { const a = Math.min(TUNE.digIn, pl.res.move); pl.def += a; pl.stats.dugIn = (pl.stats.dugIn || 0) + a; log(s, `${pl.name} digs in: +${a} Armor from unused Movement.`, 'fx'); }
  pl.res.move = 0; pl.res.prec = 0; pl.shot = 0; if (!TUNE.bankIntel) pl.res.intel = 0; // Armor stays up through the rival's turn
  drawCards(s, p, TUNE.hand + (TUNE.lowHp && pl.hp > 0 && pl.hp <= TUNE.lowHp ? 1 : 0));
  log(s, `${pl.name} ends the turn.`, 'act');
  s.turnNo++;
  let next = 1 - p;
  if (p !== s.first) { endRound(s); if (TUNE.alternateFirst && !s.over) { s.first = 1 - s.first; log(s, `${s.players[s.first].name} takes the lead this round.`, 'round'); } next = s.first; }
  if (s.over) return { ok: true };
  s.turn = next; startTurn(s, s.turn);
  return { ok: true };
}
// How many locations the gas takes this round: speeds up while new ground keeps coming; once the deck is empty it shrinks 1 per round.
function gasRate(s) { if (TUNE.phases) return TUNE.phaseGas[s.phase - 1]; const r = TUNE.gasRates; return r[Math.min(s.round - 1, r.length - 1)]; }
function nextPhase(s) { return TUNE.phases && s.envPh && s.envPh.length ? s.envPh[0] : null; }
function closing(s) {
  const B = safeBounds(s); if (B.n <= 1) return [];
  if (s.envDeck && s.envDeck.length) { const n = Math.min(gasRate(s), B.n - 1); return Array.from({ length: n }, (_, i) => B.hi - i); }
  return [s.closeSide === 'right' ? B.hi : B.lo];
}
function endRound(s) {
  const list = closing(s);
  if (list.length) {
    const drifting = s.envDeck && s.envDeck.length;
    const names = [];
    for (const w of list) { const ge = envAt(s, w); names.push(ENVS[ge.def].name + (ge.loot.length || !ge.cache.searched ? ' (with its loot)' : '')); ge.loot = []; ge.state = 'gas'; ge.crate = null; }
    log(s, `Round ${s.round} ends. Gas swallows ${names.join(', ')}.`, 'gas');
    let phaseUp = false;
    if (drifting) {
      const added = [];
      for (let i = 0; i < list.length && s.envDeck.length; i++) {
        const B = safeBounds(s); const w = B.lo - 1;
        let def = s.envDeck.shift(); const ph = TUNE.phases ? s.envPh.shift() : 0; const card = TUNE.physical ? s.newGround.shift() : null; const nb = envAt(s, B.lo); if (!TUNE.physical && nb && nb.def === def && s.envDeck.length) { const j = s.envDeck.findIndex((d, x) => d !== def && (!TUNE.phases || s.envPh[x] === ph)); if (j >= 0) { const t = s.envDeck[j]; s.envDeck[j] = def; def = t; } }
        if (ph > s.phase) { s.phase = ph; phaseUp = true; }
        const old = envAt(s, w); if (old) s.envs.splice(s.envs.indexOf(old), 1);
        s.revealed++; s.envs.push(Object.assign(mkEnv(def, w, TUNE.freshBonus, 'fresh', TUNE.phases ? TUNE.phaseTier[ph - 1] : s.revealed <= TUNE.tier2Reveals ? 2 : 3), { phase: ph })); { const ne = s.envs.find(x => x.w === w); if (card) ne.gunAt = card.gun; gunSlot(s, ne); } s.envs.sort((a, b) => a.w - b.w); added.push(ENVS[def].name);
      }
      log(s, `New ground revealed on the left: ${added.join(', ')}${s.envDeck.length ? ` (${s.envDeck.length} more to come)` : ' — the last new ground. From now on the circle shrinks.'}.`, 'fx');
      if (!s.envDeck.length) s.closeSide = 'right';
      if (phaseUp) { log(s, `PHASE ${s.phase}: the gas speeds up to ${TUNE.phaseGas[s.phase - 1]} location${TUNE.phaseGas[s.phase - 1] > 1 ? 's' : ''} per round. Both operators draft a new perk.`, 'round'); for (const q of [0, 1]) dealPerks(s, q); }
    } else s.closeSide = s.closeSide === 'right' ? 'left' : 'right';
    const B2 = safeBounds(s); s.envs = s.envs.filter(e => e.state === 'safe' || (e.w >= B2.lo - 1 && e.w <= B2.hi + 1) || s.players.some(q => q.pos === e.w));
  }
  // Gas: 3 damage +1 per extra space outside, then you are pushed back to the nearest safe location.
  for (const pl of s.players) {
    const B = safeBounds(s); if (pl.pos >= B.lo && pl.pos <= B.hi) continue;
    const depth = pl.pos < B.lo ? B.lo - pl.pos : pl.pos - B.hi; const dmg = Math.max(0, TUNE.gasDmg + depth - 1 - (hasPerk(pl, 'eod') ? 2 : 0));
    pl.hp -= dmg; const back = pl.pos < B.lo ? B.lo : B.hi; pl.pos = back;
    log(s, `${pl.name} is caught ${depth} space${depth > 1 ? 's' : ''} deep in the gas: −${dmg}, pushed back to ${ENVS[envAt(s, back).def].name}.`, 'gas');
  }
  if (safeBounds(s).n <= 1) { s.finalDmg = s.finalDmg ? s.finalDmg + 1 : TUNE.finalBase; for (const pl of s.players) pl.hp -= Math.max(0, s.finalDmg - (hasPerk(pl, 'eod') ? 2 : 0)); log(s, `Final circle: the storm hits both operators for ${s.finalDmg}.`, 'gas'); }
  if (TUNE.crateRounds.includes(s.round)) {
    const B = safeBounds(s); const mid = (B.lo + B.hi) / 2; const cl = closing(s);
    const pool = s.envs.filter(e => e.state === 'safe' && !cl.includes(e.w)).sort((a, b) => Math.abs(a.w - mid) - Math.abs(b.w - mid) || a.w - b.w).slice(0, TUNE.physical ? 1 : 2);
    if (pool.length) { const t = pool[Math.floor(rng(s) * pool.length)]; if (TUNE.stacks) { flip(s, t, null); const items = []; for (let i = 0; i < TUNE.crate[1]; i++) { const D = deckFor(s, 3); const j = D.findIndex(it => it.kind === 'weapon'); if (j >= 0) items.push(D.splice(j, 1)[0]); } while (items.length < TUNE.crate[0]) { const D = deckFor(s, 3); const j = D.findIndex(it => it.kind !== 'weapon'); if (j < 0) break; items.push(D.splice(j, 1)[0]); } t.loot.unshift(...items); if (t.loot[0]) t.loot[0].seen = true; t.dropRound = s.round; log(s, `Supply crate lands on ${ENVS[t.def].name}: ${items.length} cards on top of its stack, ${itemDef(s, items[0]).name} face up.`, 'fx'); } else t.crate = { searched: false }; if (!TUNE.stacks) log(s, `Supply crate lands at ${ENVS[t.def].name}: ${TUNE.crate[0]} items, ${TUNE.crate[1]} of them guns.`, 'fx'); }
  }
  checkDeath(s);
  s.round++;
  if (!s.over) log(s, `Round ${s.round}.`, 'round');
}

// ---------- estimates ----------
function expDmg(s, p, sp, trials = 200, bhm = 0) {
  let ev = 0, prevP = 0; const ps = sp.steps.map(([h]) => h - bhm <= 0 ? 1 : hitChance(s, p, sp.reveal, h - bhm, trials));
  sp.steps.forEach(([h, dm], i) => { const pThis = ps[i] - (ps[i + 1] || 0); ev += pThis * dm; });
  return ev;
}
function hitChance(s, p, n, req, trials = 300) {
  const pl = P(s, p); if (n <= 0) return 0;
  const enc = i => cardDef(s, i).jam ? -99 : hmOf(s, i);
  const dk = pl.deck.map(enc), dc = pl.discard.map(enc);
  let seed = 12345, ok = 0; const r = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  const sh = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  for (let t = 0; t < trials; t++) { const seq = sh(dk.slice()).concat(sh(dc.slice())); let sum = 0; for (let i = 0; i < Math.min(n, seq.length); i++) sum += seq[i]; if (sum >= req) ok++; }
  return ok / trials;
}

// ---------- AI: plays a whole turn ----------
function aiItemScore(s, p, it) {
  const pl = P(s, p); const d = itemDef(s, it); const ab = TUNE.ablate && TUNE.ablate[p];
  if (it.kind === 'weapon') { const g = guns(pl); if (!g.length) return 40 + d.intel_cost; if (TUNE.lite) { const cur = WEAPONS[s.weapons[g[0]].def]; return d.tier > cur.tier || (d.tier === cur.tier && d.intel_cost > cur.intel_cost && cur.gunClass === 'pistol') || (cur.gunClass === 'pistol' && d.gunClass !== 'pistol') ? 14 + d.intel_cost * 3 : -1; } if (g.length < 2) return 18 + d.intel_cost * 2; return d.tier > Math.min(...g.map(w => WEAPONS[s.weapons[w].def].tier)) ? 12 + d.intel_cost * 2 : -1; }
  if (ab === 'nocards' && it.kind === 'card') return -1;
  if (ab === 'mono' && it.kind === 'card') { const ga = guns(pl).map(w => WEAPONS[s.weapons[w].def].archetype); const own = pl.deck.concat(pl.discard, pl.hand, pl.play).map(i => cardDef(s, i).archetype).filter(x => x !== 'starter'); const focus = ga[0] || own[0]; if (focus && d.archetype !== focus) return -1; }
  if (ab && ['assault', 'support', 'recon', 'engineer'].includes(ab) && it.kind === 'card' && d.archetype !== ab) return -1;
  if (ab && typeof ab === 'string' && ab.startsWith('pair:') && it.kind === 'card' && NEIGHBOURS[d.archetype] && !ab.slice(5).split(',').includes(d.archetype)) return -1;
  if (it.kind === 'att') return guns(pl).length ? 5 + d.intel_cost : -1;
  let syn = 0;
  if (TUNE.allies && d.archetype !== 'starter' && !(TUNE.ablate && TUNE.ablate[p] === 'nosyn')) {
    const own = pl.deck.concat(pl.discard, pl.hand, pl.play).map(i => cardDef(s, i).archetype);
    const k = own.filter(a => a === d.archetype).length; syn = k * 2 + (TUNE.perks && (k === 3 || k === 5) ? 6 : 0) + (guns(pl).some(w => WEAPONS[s.weapons[w].def].archetype === d.archetype) ? 4 : 0);
  }
  if ((TUNE.ammo || TUNE.combos) && d.combos && !(TUNE.ablate && TUNE.ablate[p] === 'nosyn')) {
    const own = pl.deck.concat(pl.discard, pl.hand, pl.play).map(i => cardDef(s, i).archetype);
    for (const c of d.combos) syn += own.filter(a => [].concat(c.role).includes(a)).length * (TUNE.aiSyn || 2);
    const pw = pl.guns[0] && WEAPONS[s.weapons[pl.guns[0]].def]; if (pw && pw.gcombo && pw.gcombo.role === d.archetype) syn += 4; if (pw && pw.gcombo && d.combos.some(c => [].concat(c.role).includes(pw.gcombo.role))) syn += 3;
  }
  return 8 + d.intel_cost * 2 + d.hit_markers * 2 + syn;
}
const fodder = (s, iid) => ['T001', 'T006', 'T002'].includes(cardDef(s, iid).id);
function aiBuy(s, p) {
  const pl = P(s, p); const noTrade = TUNE.ablate && TUNE.ablate[p] === 'notrade';
  for (let guard = 0; guard < 6; guard++) {
    const near = [pl.pos, pl.pos - 1, pl.pos + 1].map(w => envAt(s, w)).filter(e => e && e.state === 'safe' && (!TUNE.stacks || e.cache.searched)).flatMap(e => TUNE.stacks ? e.loot.slice(0, 1) : e.loot);
    const cands = near.filter(it => aiItemScore(s, p, it) > 0).sort((a, b) => (aiItemScore(s, p, b) - lootCost(s, p, b)) - (aiItemScore(s, p, a) - lootCost(s, p, a)));
    const fod = (noTrade || !TUNE.tradeIn) ? [] : pl.hand.filter(i => fodder(s, i)).sort((a, b) => burnScore(s, a) - burnScore(s, b));
    const it = cands.find(c => buyTotal(s, p, [c.iid]) <= pl.res.intel + fod.length); if (!it) return;
    const short = Math.max(0, buyTotal(s, p, [it.iid]) - pl.res.intel);
    const o = { tradeIn: fod.slice(0, short) };
    if (it.kind === 'weapon' && pl.guns[0] && pl.guns[1]) o.replace = WEAPONS[s.weapons[pl.guns[0]].def].tier <= WEAPONS[s.weapons[pl.guns[1]].def].tier ? 0 : 1;
    if (!buy(s, p, [it.iid], o).ok) return;
  }
}
function aiActivate(s, p) {
  const pl = P(s, p); if (TUNE.ammo || TUNE.lite) return;
  pl.guns.forEach((wid, gi) => { if (!wid || s.weapons[wid].used) return;
    const own = pl.deck.length + pl.discard.length + pl.hand.length + pl.play.length;
    const danger = closing(s).includes(pl.pos) && !pl.moved;
    const fuel = own > 0 ? eligibleFuel(s, p, gi).filter(i => (burnScore(s, i) < 10 || TUNE.fuelAny) && !(danger && cardDef(s, i).effects.some(e => e.res === 'move'))).sort((a, b) => burnScore(s, a) - burnScore(s, b))[0] : null;
    if (fuel) activateGun(s, p, gi, fuel); });
}
function aiPickAmmo(s, p, gi) {
  const pl = P(s, p); if (!TUNE.ammo) return { ammo: null, hm: 0 };
  if (pl.guns[gi] && WEAPONS[s.weapons[pl.guns[gi]].def].melee) return { ammo: null, hm: 0 };
  if (gi === 1 && hasPerk(pl, 'amped')) return { ammo: null, hm: 0 };
  if (pl.freeAmmo > 0) return { ammo: 'free', hm: TUNE.freeBulletHM };
  const r = (pl._reserve || []).filter(i => pl.hand.includes(i)); const pool = r.length ? r : pl.hand;
  // best bullet: most Hit Markers among the cheap cards
  const a = pool.slice().sort((x, y) => (burnScore(s, x) - hmOf(s, x) * 3) - (burnScore(s, y) - hmOf(s, y) * 3))[0];
  return a ? { ammo: a, hm: TUNE.bulletCounts ? hmOf(s, a) : 0, reserved: r.length > 0 } : { ammo: null, hm: 0, none: true };
}
function aiEV(s, p) { // best expected damage from here with what we have now
  const pl = P(s, p); let best = 0, bestGi = -1;
  pl.guns.forEach((wid, gi) => { if (!wid || !shootCheck(s, p, gi).ok) return; const sp = shotPreview(s, p, gi); const am = aiPickAmmo(s, p, gi); const ev = expDmg(s, p, sp, 120, am.hm); if (ev > best) { best = ev; bestGi = gi; } });
  return { ev: best, gi: bestGi };
}
function aiFireLoop(s, p) {
  const pl = P(s, p);
  for (let g = 0; g < 12 && !s.over; g++) { const { ev, gi } = aiEV(s, p); if (gi < 0 || ev < (TUNE.aiFireMin || 0.6)) break;
    const am = aiPickAmmo(s, p, gi); if (am.none) break; const ammo = am.ammo;
    if (ammo && ammo !== 'free' && !am.reserved && burnScore(s, ammo) > (TUNE.aiSpendScore || 12) && ev < 2.5) break;
    if (!fire(s, p, gi, ammo).ok) break; }
  if (TUNE.punch && !TUNE.ammo && !s.over && P(s, p).pos === P(s, 1 - p).pos && !P(s, p).punched) punch(s, p);
}
function aiScoreLoc(s, p, w) {
  const pl = P(s, p), o = P(s, 1 - p); const env = envAt(s, w); const d = ENVS[env.def];
  if (env.state !== 'safe') return -50;
  let sc = 0; if (closing(s).includes(w)) sc -= 9;
  const dd = Math.abs(w - o.pos); const gs = guns(pl).map(wid => eff(s, wid));
  if (gs.length) { const off = Math.min(...gs.map(e => TUNE.distMode === 'band' ? (dd === e.max_range ? -1 : dd >= e.band[0] && dd <= e.band[1] ? 0 : 1 + Math.min(Math.abs(dd - e.band[0]), Math.abs(dd - e.band[1]))) : Math.abs(dd - e.max_range))); sc += 6 - 2 * off; }
  sc += d.cover * 1.5;

  const shop = pl.res.intel + pl.hand.filter(i => fodder(s, i)).length >= 2;
  const myArch = (() => { const c = {}; pl.deck.concat(pl.discard, pl.hand, pl.play).forEach(i => { const a = cardDef(s, i).archetype; if (a !== 'starter') c[a] = (c[a] || 0) + 1; }); guns(pl).forEach(w => { const a = WEAPONS[s.weapons[w].def].archetype; c[a] = (c[a] || 0) + 2; }); return Object.keys(c).sort((x, y) => c[y] - c[x])[0]; })();
  const affB = TUNE.affinity && myArch && ENVS[env.def].affinity === myArch && !env.cache.searched ? (TUNE.ablate && TUNE.ablate[p] === 'mono' ? 6 : 2) : 0;
  const loot = affB + (!env.cache.searched && pl.searches > 0 ? 3 : 0) + (env.crate && !env.crate.searched ? 4 : 0) + ((TUNE.stacks ? env.loot.slice(0, 1) : env.loot).some(it => aiItemScore(s, p, it) > 0) ? 2 : 0) + (TUNE.stacks && !env.cache.searched ? 3 : 0) + (env.dropRound && env.loot[0] ? 2 : 0);
  sc += loot * (gs.length ? (shop ? 1 : 0.3) : 4);
  if (d.bonus && !pl.bonusTaken.includes(w)) sc += 0.5;
  return sc;
}
function aiTurn(s, p) {
  if (s.over || s.turn !== p) return fail('not AI turn');
  const pl = P(s, p); aiPickPerk(s, p);
  // keep weak starters as trade-in fodder if shopping here is possible
  const shopHere = () => searchable(s, p) && pl.searches > 0 || envAt(s, pl.pos).loot.slice(0, TUNE.stacks ? 1 : 99).some(it => aiItemScore(s, p, it) > 0);
  // reserve the weakest cards as bullets before playing the rest
  pl._reserve = [];
  if (TUNE.ammo && guns(pl).length) { const g = pl.guns[0] || pl.guns[1]; const mag = eff(s, g).magazine_capacity; const k = Math.max(0, Math.min(mag, pl.hand.length - (TUNE.aiKeepPlay || 3)));
    pl._reserve = pl.hand.slice().sort((a, b) => burnScore(s, a) - burnScore(s, b)).slice(0, k); }
  const playSome = keepFodder => { for (const iid of pl.hand.slice()) { const d = cardDef(s, iid); if (d.jam) continue; if (keepFodder !== 'all' && pl._reserve.includes(iid)) continue; if (keepFodder && fodder(s, iid) && d.id !== 'T002') continue; playCard(s, p, iid); } };
  // escape first: if the gas is coming for us, spend movement on getting out
  const inDanger = () => closing(s).includes(pl.pos) || envAt(s, pl.pos).state === 'gas';
  if (inDanger()) {
    for (const iid of pl.hand.slice()) if (cardDef(s, iid).effects.some(e => e.op === 'gain' && e.res === 'move')) playCard(s, p, iid);
    const cl = closing(s); const B = safeBounds(s);
    const safe = reachable(s, p).filter(r => inSafe(s, r.w) && !cl.includes(r.w)).map(r => ({ ...r, sc: aiScoreLoc(s, p, r.w) })).sort((a, b) => b.sc - a.sc);
    if (safe.length) move(s, p, safe[0].w);
    else { const toward = reachable(s, p).filter(r => r.w < pl.pos && r.w >= B.lo).sort((a, b) => a.w - b.w)[0]; if (toward) move(s, p, toward.w); }
  }
  if (!s.over && searchable(s, p) && pl.searches > 0) search(s, p);
  aiActivate(s, p);
  playSome(shopHere() && TUNE.tradeIn > 0);
  aiBuy(s, p); aiActivate(s, p);
  // shoot from here if good, else reposition first
  const here = aiScoreLoc(s, p, pl.pos);
  const opts = reachable(s, p).map(r => ({ ...r, sc: aiScoreLoc(s, p, r.w) - r.cost * 0.3 })).sort((a, b) => b.sc - a.sc);
  const ev0 = aiEV(s, p).ev;
  if (opts.length && opts[0].sc > here + 1 && !(ev0 >= 2 && opts[0].sc < here + 4)) { move(s, p, opts[0].w); if (searchable(s, p) && pl.searches > 0) search(s, p); playSome(false); aiBuy(s, p); aiActivate(s, p); }
  playSome(false); aiActivate(s, p);
  aiFireLoop(s, p);
  if (s.over) return { ok: true };
  if (TUNE.ammo) playSome('all');
  // shoot-and-scoot: duck into cover if movement remains
  const cv = w => ENVS[envAt(s, w).def].cover;
  if (!cv(pl.pos)) { const c = reachable(s, p).filter(r => inSafe(s, r.w) && !closing(s).includes(r.w) && cv(r.w) && r.w !== P(s, 1 - p).pos).sort((a, b) => cv(b.w) - cv(a.w))[0]; if (c) move(s, p, c.w); }
  if (searchable(s, p) && pl.searches > 0) { search(s, p); }
  aiBuy(s, p);
  if (canBench(s, p)) { const f = pl.hand.slice().sort((a, b) => burnScore(s, a) - burnScore(s, b))[0]; if (f && burnScore(s, f) < 5) burnAtBench(s, p, f); }
  // dig through the loot stack here if the top card is no use
  for (let k = 0; k < 3 && TUNE.stacks; k++) { const env = envAt(s, pl.pos); if (!env || !env.cache.searched || env.loot.length < 2) break; const top = env.loot[0];
    if (aiItemScore(s, p, top) > 0 && lootCost(s, p, top) <= pl.res.intel) break;
    const free = pl.freeCycles > 0 || (false && hasPerk(pl, 'spotter') && (pl.spotUsed || 0) < 1); const pay = free ? 'intel' : pl.res.move >= 1 ? 'move' : pl.res.intel >= 3 ? 'intel' : null; if (!pay) break;
    if (!cycle(s, p, pay).ok) break; aiBuy(s, p); }
  // scrap the weakest starters, then spend leftovers on the supply line
  while (pl.scrapAvail > 0 && owned(pl) > TUNE.minDeck) { const t = pl.discard.slice().sort((a, b) => burnScore(s, a) - burnScore(s, b))[0]; if (!t || burnScore(s, t) > 4 || !scrap(s, p, t).ok) break; }
  aiBuy(s, p);
  while (pl.res.intel >= plateCost(s, p) && !(TUNE.ablate && TUNE.ablate[p] === 'nocards')) {
    const tot = { move: 0, prec: 0, intel: 0, ammo: 0 }; pl.deck.concat(pl.discard, pl.hand, pl.play, pl.fuelled).forEach(i => cardDef(s, i).effects.forEach(e => { if (e.op === 'gain' && e.res in tot) tot[e.res] += e.n; if (e.op === 'ammo') tot.ammo += e.n; }));
    const want = { move: tot.move / 1.0, prec: tot.prec / 1.4, intel: tot.intel / 1.2, ammo: (tot.ammo + TUNE.aiAmmoBias) / 0.8 };
    const map = { K02: 'move', K03: 'intel', K04: 'prec', K05: 'ammo', K01: 'intel' }; if (TUNE.lite) tot.ammo = pl.deck.concat(pl.discard, pl.hand, pl.play).reduce((a, i) => a + cardDef(s, i).effects.filter(e => e.res === 'shot').reduce((x, e) => x + e.n, 0), 0);
    const pick = TUNE.station.filter(x => !s.stationLeft || s.stationLeft[x] > 0).sort((a, b) => want[map[a]] - want[map[b]])[0]; if (!pick) break;
    if (!buySupply(s, p, pick).ok) break; }
  return endTurn(s, p);
}

const API = { RES, RES_LABEL, TIER_NAME, RARITY, MODS, GUNCLASS, CARDS, WEAPONS, ATTS, ENVS, WEAPON_COPIES, TUNE, ARCH_TAG,
  newGame, playCard, playAll, activateGun, eligibleFuel, boostOk, move, search, buy, burnAtBench, canBench, fire, punch, endTurn, aiTurn,
  reachable, closing, GUNSET, LOCSET, locTier, locSize, SQUAD_TEXT, ammoLeft, rolesPlayed, NEIGHBOURS, cycle, flip, stackPlan, LOADOUT, pickPerk, plateCost, nextPhase, hasPerk, buySupply, scrap, lootNear, PERKS, perksOf, archCounts, gasRate, moveCost, shotPreview, shootCheck, shotsLeft, hitChance, expDmg, lootCost, buyTotal, searchable, eff, envAt, dist, itemDef, cardDef, nextEdge, safeBounds, inSafe, isStarter, guns };
if (typeof module !== 'undefined' && module.exports) module.exports = API; else root.WD = API;
})(typeof window !== 'undefined' ? window : globalThis);
