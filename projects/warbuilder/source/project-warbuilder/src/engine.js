/* WARZONE DECKBUILDER v5 "Engine & Synergy" — rules engine (board task wb-rules).
   Spec: documentation/design/engine-synergy-spec.md (approved), with the head's answers S1–S4.
   Squads + Loadout build the engine; a fixed 7-location row closes on a public schedule into an escalating final circle and a hard end.
   Shooting (wb-pyl-impl): push your luck. Flip cards one at a time (1 Precision each), stop on a ladder step or flip on; Jams (Sprint, Scout) cost Recoil and the 2nd Jam in a shot misses (the 1st in the final circle).
   Resources: Movement, Precision, Intel (+ Armor, which lasts until your next turn). */
(function (root) {
'use strict';

const RES = ['move', 'prec', 'intel'];
const TUNE = {
  hp: 40, hand: 5, firstHand: 5, lowHp: 10, digIn: 2, minDeck: 7,
  zones: 7, startA: 1, startB: 5, stackSize: 3, affinityShare: 2 / 3, adjCost: 1, cycleCost: 1,
  closeAfter: [2, 4, 5, 6, 7, 8], gasDmg: 3, finalStorm: [3, 4, 5, 6], hardEnd: 11, crateRounds: [2, 4], crate: [3, 1],
  buyCap: 2, hotDrop: 3, supplyCost: 2, station: ['K02', 'K04', 'K05', 'K03'], stationCopies: 6, stationScrapCost: 1,
  loadoutSlots: 2, squadCap: 3, rally: [3, 5],
  needPlus: 0, closeQuarters: true, pointBlank: true,
  // push-your-luck FIRE (see the fire section): the bust rule's swappable pieces. Only these values are built.
  pyl: { flipCost: 1, jamRecoil: true, bustAt: 2, finalBustAt: 1, jamScope: 'shot', bustCost: 'shot', bank: 'shot' },
  stSprint: 3, stScout: 3, stAim: 2, alternateFirst: true,
  // kept for the UI and print-and-play (old systems switched off)
  lite: true, perks: false, ammo: false, phases: false, stacks: true, physical: true, tradeIn: 0, combos: false, locEveryTurn: true,
};
const TIER_NAME = ['Common', 'Uncommon', 'Rare', 'Epic'];
const RES_LABEL = { move: 'Movement', prec: 'Precision', intel: 'Intel', def: 'Armor', shot: 'extra shot' };
const ARCH_TAG = { supply: 'Supply', starter: 'Starter', assault: 'Assault', support: 'Support', recon: 'Recon', engineer: 'Engineer' };
const SQUADS = ['assault', 'recon', 'support', 'engineer'];
const NEIGHBOURS = { assault: [], recon: [], support: [], engineer: [] }; // old combo pairs: cut
const COND_LABEL = {};

// ---------- effects (one small language for cards, Loadouts, Squad lines, Rally and locations) ----------
const gain = (res, n) => ({ op: 'gain', res, n });
const M = n => gain('move', n), Pr = n => gain('prec', n), I = n => gain('intel', n), Ar = n => gain('def', n), Sh = n => gain('shot', n);
const D = n => ({ op: 'draw', n }), SC = n => ({ op: 'scrap', n }), CY = n => ({ op: 'cycleFree', n });
const MK = (n = 1) => ({ op: 'mark', n }), PI = { op: 'pierce' }, ST = (n = 1) => ({ op: 'steady', n }), DM = (n = 1) => ({ op: 'dmgTurn', n }), BY = (n = 1) => ({ op: 'buy', n });
const times = (n, w) => n > 1 ? `${w} ×${n}` : w;
// short text: "+1 Movement, +2 Precision, Draw 1, Pierce"
function effParts(effs) {
  const out = [];
  for (const e of effs) {
    if (e.op === 'gain') out.push(`+${e.n} ${RES_LABEL[e.res]}${e.res === 'shot' && e.n > 1 ? 's' : ''}`);
    else if (e.op === 'draw') out.push(`Draw ${e.n}`);
    else if (e.op === 'scrap') out.push(`Scrap ${e.n}`);
    else if (e.op === 'cycleFree') out.push(`${e.n} free cycle${e.n > 1 ? 's' : ''}`);
    else if (e.op === 'mark') out.push(times(e.n, 'Mark'));
    else if (e.op === 'pierce') out.push('Pierce');
    else if (e.op === 'steady') out.push(times(e.n, 'Steady'));
    else if (e.op === 'dmgTurn') out.push(`hits +${e.n} damage`);
    else if (e.op === 'buy') out.push(`+${e.n} Buy`);
  }
  return out;
}
const effText = effs => effParts(effs).join(', ');
// full sentence for a card's play line: "Gain 1 Movement and 2 Precision. Pierce. Draw 1."
function playText(effs) {
  const g = effs.filter(e => e.op === 'gain'); const rest = effs.filter(e => e.op !== 'gain');
  const gs = g.map(e => `${e.n} ${RES_LABEL[e.res]}${e.res === 'shot' && e.n > 1 ? 's' : ''}`);
  const s = [];
  if (gs.length) s.push(`Gain ${gs.length > 1 ? gs.slice(0, -1).join(', ') + ' and ' + gs[gs.length - 1] : gs[0]}.`);
  for (const p of effParts(rest)) s.push(p.charAt(0).toUpperCase() + p.slice(1) + '.');
  return s.join(' ');
}

// ---------- TACTICAL CARDS ----------
// TC(id, name, squad, tier, Hit Markers, cost, copies, play effects, extra: { squad: [...] (Squad line), loadout: [...] (Ready effect), reaction })
const CARDS = {};
function TC(id, name, archetype, tier, hm, cost, copies, effects, extra) {
  const d = Object.assign({ id, name, archetype, tier, hit_markers: hm, intel_cost: cost, copies, effects, tags: [ARCH_TAG[archetype]] }, extra || {});
  d.text = d.loadout ? `Loadout. Ready: ${effText(d.loadout)}.` : playText(effects);
  if (d.squad) d.squadText = effText(d.squad);
  CARDS[id] = d;
}
// Starter deck (10): no squad
TC('T001', 'Sprint', 'starter', 0, 0, 0, 3, [M(1)], { jam: true });
TC('T002', 'Scout', 'starter', 0, 0, 0, 3, [I(1)], { jam: true });
TC('T004', 'Steady Aim', 'starter', 0, 1, 0, 2, [Pr(1)]);
TC('T005', 'Recon Run', 'starter', 0, 1, 0, 2, [M(1), I(1)]);
// Buy Station: one basic per squad, 2 Intel, 6 copies each
TC('K02', 'Tac Sprint', 'assault', 1, 1, 2, 0, [M(1), Pr(2)], { squad: [Pr(1)] });
TC('K04', 'Focus', 'recon', 1, 2, 2, 0, [Pr(2)], { squad: [Pr(1)] });
TC('K05', 'Spare Rounds', 'support', 1, 1, 2, 0, [Pr(2), Sh(1)], { squad: [Pr(1)] });
TC('K03', 'Dead Drop', 'engineer', 1, 1, 2, 0, [I(2)], { squad: [I(1)] });
// ASSAULT: hits hit harder
TC('A11', 'Breach', 'assault', 1, 2, 1, 2, [M(1), Pr(2)], { squad: [DM(1), Pr(1)] });
TC('A12', 'Slide Cancel', 'assault', 1, 2, 1, 2, [M(2), Pr(1), SC(1)], { squad: [D(1), Pr(2)] });
TC('A13', 'Hip Fire', 'assault', 1, 2, 2, 2, [M(1), Pr(2)], { squad: [Pr(3)] });
TC('A21', 'Rush the Door', 'assault', 2, 2, 3, 2, [M(1), Pr(3), PI], { squad: [DM(1), Pr(2)] });
TC('A22', 'Flank', 'assault', 2, 2, 3, 2, [M(2), Pr(2), D(1)], { squad: [D(1), Pr(2)] });
TC('A23', 'Run and Gun', 'assault', 2, 2, 3, 2, [M(1), Pr(2), Sh(1)], { squad: [ST(1), Pr(2)] });
TC('A31', 'Blitz', 'assault', 3, 3, 5, 2, [M(2), Pr(3), DM(1)], { squad: [Pr(2)] });
TC('A32', 'Breaching Charge', 'assault', 3, 3, 4, 2, [M(1), Pr(3), PI, DM(1)], { squad: [DM(1), Sh(1), ST(1)] });
TC('L1A', 'Tac Vest', 'assault', 2, 1, 3, 3, [], { loadout: [Pr(2), DM(1)], tiers: [1, 2, 2] });
// RECON: aim
TC('R11', 'Mark Target', 'recon', 1, 2, 1, 2, [Pr(2)], { squad: [MK(1), Pr(1)] });
TC('R12', 'Steady Breath', 'recon', 1, 3, 1, 2, [Pr(2)], { squad: [Pr(2)] });
TC('R13', 'Snapshot', 'recon', 1, 2, 2, 2, [Pr(2), I(1)], { squad: [I(2), Pr(1)] });
TC('R21', 'Heartbeat Sensor', 'recon', 2, 2, 3, 2, [Pr(2), D(1)], { squad: [Pr(4)] });
TC('R22', 'Spotter Scope', 'recon', 2, 3, 3, 2, [Pr(3)], { squad: [MK(1), Pr(2)] });
TC('R23', 'Thermal Optic', 'recon', 2, 2, 3, 2, [Pr(3), PI], { squad: [I(2), Pr(2)] });
TC('R31', 'UAV', 'recon', 3, 3, 4, 2, [Pr(3), I(1), PI], { squad: [D(1), MK(1), Pr(1)] });
TC('R32', 'Headhunter', 'recon', 3, 3, 5, 2, [Pr(4), MK(1)], { squad: [Pr(2)] });
TC('L1R', 'Recon Post', 'recon', 2, 1, 3, 3, [], { loadout: [Pr(2)], tiers: [1, 2, 2] });
// SUPPORT: sustained fire (extra shots, Steady = free reveals, Armor)
TC('S11', 'Ammo Box', 'support', 1, 2, 2, 2, [Pr(2), Sh(1), SC(1)], { squad: [Pr(3)] });
TC('S12', 'Suppressing Fire', 'support', 1, 2, 2, 2, [Pr(2), Ar(1)], { squad: [Pr(2), Ar(1)] });
TC('S13', 'Bandolier', 'support', 1, 2, 2, 2, [Pr(2), Sh(1), Ar(1), ST(1)], { squad: [Pr(3)] });
TC('S21', 'Steady Grip', 'support', 2, 2, 3, 2, [Pr(3), Sh(1), ST(1)], { squad: [Pr(3)] });
TC('S22', 'Resupply', 'support', 2, 2, 3, 2, [Pr(1), I(1), Sh(1), D(1)], { squad: [ST(1), Pr(2)] });
TC('S23', 'Covering Fire', 'support', 2, 2, 3, 2, [Pr(3), Ar(2)], { squad: [Pr(2), ST(1), Ar(1)] });
TC('S31', 'Overwatch', 'support', 3, 3, 5, 2, [Pr(4), Sh(1), Ar(2)], { squad: [Pr(2), Ar(1)] });
TC('S32', 'Munitions Drop', 'support', 3, 3, 4, 2, [Pr(4), Sh(2), ST(1)], { squad: [Pr(2)] });
TC('L1S', 'Field Pack', 'support', 2, 1, 3, 3, [], { loadout: [Pr(1), Sh(1), ST(1)], tiers: [1, 2, 2] });
// ENGINEER: cash and contracts (Intel, +1 Buy, draw, Scrap)
TC('E11', 'Scrounge', 'engineer', 1, 1, 2, 2, [Pr(1), I(2), SC(1)], { squad: [I(2)] });
TC('E12', 'Deployable Cover', 'engineer', 1, 1, 2, 2, [Pr(1), I(2)], { squad: [I(2)], reaction: 3 });
TC('E13', 'Ping', 'engineer', 1, 1, 1, 2, [Pr(1), I(1), CY(1)], { squad: [D(1), I(1)] });
TC('E21', 'Munitions Box', 'engineer', 2, 2, 3, 2, [Pr(2), I(2)], { squad: [Pr(2)] });
TC('E22', 'Field Kit', 'engineer', 2, 2, 3, 2, [Pr(1), I(2), D(1)], { squad: [Pr(2)] });
TC('E23', 'Salvage', 'engineer', 2, 2, 3, 2, [Pr(1), I(2), SC(1), CY(2)], { squad: [I(2), BY(1)] });
TC('E31', 'Field Workshop', 'engineer', 3, 2, 4, 2, [Pr(2), I(2), D(1), SC(2)], { squad: [Pr(2), D(1)] });
TC('E32', 'Black Market', 'engineer', 3, 2, 5, 2, [Pr(2), I(3), D(1)], { squad: [I(1), Pr(2)] });
TC('L1E', 'Bounty Contract', 'engineer', 2, 1, 3, 3, [], { loadout: [I(1), Pr(1)], tiers: [1, 2, 2] });

// Rally (head's S4): 3+ / 5+ cards of one squad in play this turn (Loadout counts) give that squad's bonus, once per turn each.
const RALLY = {
  assault: { 3: [DM(1), Pr(2), PI], 5: [DM(1), Pr(2)] },
  recon: { 3: [MK(1), Pr(1)], 5: [MK(1), Pr(3)] },
  support: { 3: [Pr(2), Sh(1), ST(1)], 5: [Pr(3), Sh(1), ST(2)] },
  engineer: { 3: [I(1)], 5: [D(1)] },
};
const RALLY_TEXT = {}; for (const a in RALLY) RALLY_TEXT[a] = { 3: effText(RALLY[a][3]), 5: effText(RALLY[a][5]) };
const SQUAD_TEXT = { 3: 'Rally at 3 cards of one squad in play', 4: '' };

// ---------- GUNS: one model per class, five rarities. Every class may fire at distance 0 (point blank). ----------
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
// wb-pyl-impl: 3-step ladders [Hit Markers, damage] for push-your-luck FIRE (step 1 is the safe bank, the top step the prize; steps 2–3 ≈ 2–3× step 1).
// Recoil is what a Jam costs in Precision; single-shot guns got lower Recoil so one Jam does not end the turn's damage. The knife flips like any gun.
const GUNCLASS = {
  pistol: { name: 'Sidearm', cls: 'Pistol', arch: 'engineer', damage: 2, range: 1, band: [0, 2], ladder: [[2, 2], [4, 4], [6, 5]], shots: 2, recoil: 2, cost: 1, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Gold Rush' },
  revolver: { name: 'Magnum', cls: 'Revolver', arch: 'engineer', damage: 3, range: 2, band: [0, 3], ladder: [[2, 4], [5, 7], [7, 10]], shots: 1, recoil: 1, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Judge' },
  knife: { name: 'Combat Knife', cls: 'Melee', arch: 'assault', damage: 3, range: 0, band: [0, 0], ladder: [[2, 4], [4, 7]], shots: 1, recoil: 0, melee: true, cost: 1, mods: ['hollow', 'none', 'hollow', 'none'], skin: 'Obsidian' },
  smg: { name: 'Viper', cls: 'SMG', arch: 'assault', damage: 2, range: 0, band: [0, 1], ladder: [[2, 3], [4, 4], [6, 6]], shots: 2, recoil: 0, cost: 2, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Gold Fang' },
  shotgun: { name: 'Breacher', cls: 'Shotgun', arch: 'engineer', damage: 3, range: 0, band: [0, 1], ladder: [[2, 4], [4, 6], [6, 9]], shots: 1, recoil: 2, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Dragon’s Breath' },
  burst: { name: 'Raider', cls: 'Burst Rifle', arch: 'assault', damage: 2, range: 1, band: [0, 2], ladder: [[2, 3], [5, 4], [8, 6]], shots: 2, recoil: 0, cost: 2, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Night Raid' },
  launcher: { name: 'Sapper', cls: 'Launcher', arch: 'engineer', damage: 3, range: 2, band: [0, 3], ladder: [[3, 4], [5, 8], [7, 11]], shots: 1, recoil: 2, cost: 3, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Demolition' },
  ar: { name: 'Sentinel', cls: 'Assault Rifle', arch: 'support', damage: 2, range: 2, band: [0, 3], ladder: [[3, 4], [5, 6], [7, 8]], shots: 2, recoil: 1, cost: 3, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Crown Jewel' },
  lmg: { name: 'Bastion', cls: 'LMG', arch: 'support', damage: 3, range: 2, band: [0, 3], ladder: [[3, 3], [5, 6], [7, 9]], shots: 3, recoil: 0, cost: 3, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Iron Monarch' },
  dmr: { name: 'Ranger', cls: 'Marksman Rifle', arch: 'recon', damage: 3, range: 3, band: [0, 4], ladder: [[3, 4], [5, 7], [7, 10]], shots: 2, recoil: 1, cost: 3, mods: ['reddot', 'hollow', 'comp', 'hollow'], skin: 'Golden Hour' },
  sniper: { name: 'Longbow', cls: 'Sniper', arch: 'recon', damage: 3, range: 4, band: [0, 5], ladder: [[3, 4], [6, 9], [9, 13]], shots: 1, recoil: 1, cost: 4, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Sun God' },
};
const WEAPONS = {};
for (const k in GUNCLASS) for (let r = 0; r < RARITY.length; r++) {
  const g = GUNCLASS[k]; const mods = g.mods.slice(0, r);
  const st = { damage: g.damage, max_range: g.range, magazine_capacity: g.shots, recoil: g.recoil, hit_need: g.ladder[0][0], reveal: 0 };
  for (const m of mods) for (const f in MODS[m].mod) st[f] = Math.max(f === 'hit_need' ? 1 : 0, st[f] + MODS[m].mod[f]);
  const id = `${k}-${r}`;
  WEAPONS[id] = { id, gunClass: k, name: r === 4 ? `${g.name} “${g.skin}”` : g.name, baseName: g.name, skin: r === 4 ? g.skin : null, archetype: g.arch, cls: g.cls, tier: r, rarity: RARITY[r].key, rarityName: RARITY[r].name,
    ladder: g.ladder.map(([h, dm]) => [Math.max(1, h + st.hit_need - g.ladder[0][0]), dm + st.damage - g.damage]), band: g.band.slice(), melee: !!g.melee,
    damage: st.damage, max_range: st.max_range, magazine_capacity: st.magazine_capacity, recoil: st.recoil, hit_need: st.hit_need, reveal: 0, intel_cost: 1 + r,
    mods: mods.filter(m => MODS[m].name).map(m => MODS[m].name), modText: mods.filter(m => MODS[m].name).map(m => `${MODS[m].name} (${MODS[m].text})`),
    tactical_main_effects: [], main_text: '', slot: 0, gcombo: null, tactical_boost_effects: [], boost_text: '', tags: [ARCH_TAG[g.arch]] };
}
const WEAPON_COPIES = {};
const ATTS = {};

// ---------- LOCATIONS (8 types, 7 dealt in a fixed row). Each has a squad: 2 in 3 refills of its stack are that squad's cards. ----------
const ENVS = {
  E01: { affinity: 'assault', id: 'E01', name: 'Open Road', cover: 0, bonus: { move: 1 }, bonusText: '+1 Movement', text: 'No cover. Here: +1 Movement.' },
  E02: { affinity: 'assault', id: 'E02', name: 'Small Shed', cover: 1, bonus: { cycle: 1 }, bonusText: '1 free cycle', text: 'Cover −1. Here: 1 free cycle.' },
  E03: { affinity: 'engineer', id: 'E03', name: 'House', cover: 1, bonus: { draw: 1 }, bonusText: 'Draw 1', text: 'Cover −1. Here: draw 1 card.' },
  E04: { affinity: 'engineer', id: 'E04', name: 'Supply Depot', cover: 0, bonus: { intel: 1 }, bonusText: '+1 Intel', text: 'No cover. Here: +1 Intel.' },
  E05: { affinity: 'support', id: 'E05', name: 'Concrete Barrier', cover: 1, bonus: { def: 1 }, bonusText: '+1 Armor', text: 'Cover −1. Here: +1 Armor.' },
  E06: { affinity: 'support', id: 'E06', name: 'Military Bunker', cover: 1, bonus: { shot: 1 }, bonusText: '+1 extra shot', text: 'Cover −1. Here: +1 extra shot.' },
  E07: { affinity: 'recon', id: 'E07', name: 'Recon Tower', cover: 1, bonus: { prec: 1 }, bonusText: '+1 Precision', text: 'Cover −1. Here: +1 Precision.' },
  E08: { affinity: 'recon', id: 'E08', name: 'Workbench', cover: 0, bonus: { scrap: 1 }, bonusText: 'Scrap 1', text: 'No cover. Here: Scrap 1.' },
};
for (const k in ENVS) ENVS[k].cache = TUNE.stackSize;

// ---------- helpers ----------
function rng(s) { s.seed = (s.seed + 0x6D2B79F5) | 0; let t = s.seed; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
function shuffle(s, a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng(s) * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
const fail = err => ({ ok: false, err });
const P = (s, i) => s.players[i];
const envAt = (s, w) => s.envs.find(e => e.w === w);
const dist = s => Math.abs(s.players[0].pos - s.players[1].pos);
// rec: a replay frame only (no log line), e.g. one flip of a shot; the UI replays the AI's turn frame by frame
function rec(s, msg, cls) { if (s._rec) { const r = s._rec; s._rec = null; r.push({ msg, cls: cls || '', state: JSON.stringify(s), quiet: true }); s._rec = r; } }
function log(s, msg, cls) { s.log.push({ r: s.round, msg, cls: cls || '' }); if (s.log.length > 500) s.log.shift(); if (s._rec) { const r = s._rec; s._rec = null; r.push({ msg, cls: cls || '', state: JSON.stringify(s) }); s._rec = r; } }
const cardDef = (s, iid) => CARDS[s.cards[iid].def];
const hmOf = (s, iid) => cardDef(s, iid).hit_markers;
const isStarter = (s, iid) => cardDef(s, iid).archetype === 'starter';
function itemDef(s, item) { return item.kind === 'card' ? CARDS[s.cards[item.iid].def] : item.kind === 'weapon' ? WEAPONS[s.weapons[item.iid].def] : ATTS[s.atts[item.iid].def]; }
function eff(s, wiid) {
  const W = s.weapons[wiid]; const d = WEAPONS[W.def];
  const e = { damage: d.damage, max_range: d.max_range, magazine_capacity: d.magazine_capacity, hit_need: d.hit_need, recoil: d.recoil, reveal: 0 };
  e.hit_need = Math.max(1, e.hit_need); e.ladder = d.ladder; e.band = TUNE.pointBlank ? [0, d.band[1]] : d.band;
  return e;
}
const guns = pl => pl.guns.filter(Boolean);
const allCards = pl => pl.deck.concat(pl.discard, pl.hand, pl.play, pl.loadout || []);
const owned = pl => allCards(pl).length;
const isSquad = a => SQUADS.includes(a);
const phaseTier = s => s.round <= 3 ? 1 : s.round <= 7 ? 2 : 3;

function mkPlayer(idx, name) {
  return { idx, name, hp: TUNE.hp, pos: 0, res: { move: 0, prec: 0, intel: 0 }, def: 0, shot: 0,
    deck: [], discard: [], hand: [], play: [], loadout: [], fuelled: [], removed: [], guns: [null, null],
    bonusTaken: [], moved: false, movedToward: false, nextFire: { reqMod: 0, bonusPrec: 0 }, revealPlus: 0, dmgTurn: 0, ignoreCover: false,
    buys: 0, buyBonus: 0, scrapAvail: 0, freeCycles: 0, stationScrapped: false, squadN: {}, rallyDone: [], fp: 0, fpHist: [], perks: [], perkOffer: null,
    heat: 0, stats: { shots: 0, hits: 0, jams: 0, flips: 0, busts: 0, outs: 0, damageDealt: 0, cardsAcquired: 0, weaponAcq: 0, burned: 0, searches: 0, reactions: 0, hitsBy: {}, maxTurnDmg: 0, turnDmg: 0, squads: 0, rallies: 0, big: 0, buys: 0 } };
}
function newCard(s, def) { const iid = 'c' + (s.nid++); s.cards[iid] = { iid, def }; return iid; }
function newWeapon(s, def) { const iid = 'w' + (s.nid++); s.weapons[iid] = { iid, def, shots: 0, used: false, att: null }; return iid; }

function drawCards(s, p, n) {
  const pl = P(s, p); let d = 0;
  for (let i = 0; i < n; i++) {
    if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s, pl.discard); pl.discard = []; }
    pl.hand.push(pl.deck.pop()); d++;
  }
  return d;
}

// ---------- physical component sets (the print-and-play uses exactly these) ----------
const GUNSET = { 1: ['smg-0', 'shotgun-0', 'lmg-0', 'dmr-0', 'knife-0', 'revolver-0'], 2: ['burst-1', 'launcher-1', 'ar-1', 'sniper-1', 'smg-2', 'shotgun-2', 'lmg-2', 'dmr-2', 'pistol-2', 'knife-2', 'revolver-1'], 3: ['burst-3', 'launcher-3', 'ar-3', 'sniper-3', 'smg-4', 'shotgun-4', 'lmg-4', 'dmr-4', 'pistol-4', 'knife-4', 'revolver-3'] };
// location cards: one of each type; 7 are dealt into the row each match
const LOCSET = Object.keys(ENVS).map(def => ({ ph: 'start', def, gun: 0 }));
function locTier() { return 1; }
function locSize() { return TUNE.stackSize; }

// ---------- setup ----------
function newGame(opts = {}) {
  const s = { v: '6.0', seed: (opts.seed ?? (Date.now() & 0x7fffffff)) | 0, round: 1, turnNo: 1, first: 0, turn: 0, over: false, winner: null, endBy: null,
    log: [], nid: 1, cards: {}, weapons: {}, atts: {}, envs: [], players: [], lastFire: null, shot: null, finalN: 0, finalDmg: 0, gone: [], aiMode: ['aware', 'aware'] };
  s.players = [mkPlayer(0, (opts.names && opts.names[0]) || 'You'), mkPlayer(1, (opts.names && opts.names[1]) || 'Rival')];
  for (const pl of s.players) { for (const id of ['T001', 'T002', 'T004', 'T005']) for (let c = 0; c < CARDS[id].copies; c++) pl.deck.push(newCard(s, id)); shuffle(s, pl.deck); }
  s.loot = { 1: [], 2: [], 3: [] };
  for (const id in CARDS) { const d = CARDS[id]; if (!d.tier || !d.copies) continue; const tiers = d.tiers || Array(d.copies).fill(d.tier); for (const t of tiers) s.loot[t].push({ kind: 'card', iid: newCard(s, id) }); }
  for (const t of [1, 2, 3]) for (const id of GUNSET[t]) s.loot[t].push({ kind: 'weapon', iid: newWeapon(s, id) });
  for (const t of [1, 2, 3]) shuffle(s, s.loot[t]);
  // the fixed row: 7 of the 8 location types; the leftover card stays in the box (s.envDeck)
  const types = shuffle(s, Object.keys(ENVS));
  types.slice(0, TUNE.zones).forEach((def, w) => s.envs.push(mkEnv(def, w)));
  s.envDeck = types.slice(TUNE.zones); s.envPh = s.envDeck.map(() => 'start'); s.phase = 1;
  // every stack: a Common gun on top (while they last) and 2 cards, biased to the location's squad; all stacks are face up
  const g1 = s.loot[1].filter(x => x.kind === 'weapon'); s.loot[1] = s.loot[1].filter(x => x.kind !== 'weapon');
  for (const e of s.envs) { const g = g1.shift(); if (g) e.loot.push(g); while (e.loot.length < TUNE.stackSize) { const it = pull(s, e, 1, true); if (!it) break; e.loot.push(it); } markTop(e); }
  s.loot[1].push(...g1); shuffle(s, s.loot[1]);
  s.stationLeft = {}; for (const id of TUNE.station) s.stationLeft[id] = TUNE.stationCopies;
  const a = rng(s) < 0.5; s.players[0].pos = a ? TUNE.startA : TUNE.startB; s.players[1].pos = a ? TUNE.startB : TUNE.startA;
  s.first = rng(s) < 0.5 ? 0 : 1; s.turn = s.first;
  s.closeSide = rng(s) < 0.5 ? 'left' : 'right';
  for (const pl of s.players) pl.guns[0] = newWeapon(s, 'pistol-0');
  drawCards(s, s.first, TUNE.firstHand); drawCards(s, 1 - s.first, TUNE.hand);
  log(s, `Round 1. ${s.players[s.first].name} goes first.`, 'round');
  startTurn(s, s.turn);
  return s;
}
function mkEnv(def, w) { return { w, def, tier: 1, state: 'safe', hot: false, fresh: false, loot: [], cache: { reveal: TUNE.stackSize, searched: true }, crate: null }; }
function markTop(e) { if (e.loot[0]) e.loot[0].seen = true; }
// one loot item for a location's stack: 2 in 3 are a card of the location's squad (if the tier has one)
function pull(s, env, t, noGun) {
  const aff = ENVS[env.def].affinity; const wantAff = rng(s) < TUNE.affinityShare;
  for (const k of [t, t + 1, t - 1, 3, 2, 1]) {
    const Dk = s.loot[k]; if (!Dk || !Dk.length) continue;
    let j = -1;
    if (wantAff) j = Dk.findIndex(x => x.kind === 'card' && CARDS[s.cards[x.iid].def].archetype === aff);
    if (j < 0) j = Dk.findIndex(x => !noGun || x.kind === 'card');
    if (j >= 0) return Dk.splice(j, 1)[0];
  }
  return null;
}
function safeBounds(s) { const w = s.envs.filter(e => e.state === 'safe').map(e => e.w); return { lo: Math.min(...w), hi: Math.max(...w), n: w.length }; }
function nextEdge(s) { const b = safeBounds(s); if (b.n <= 1) return null; return s.closeSide === 'right' ? b.hi : b.lo; }
function inSafe(s, w) { const e = envAt(s, w); return !!e && e.state === 'safe'; }
// the public schedule: which round each safe location closes at the end of (null = final circle)
function closeSchedule(s) {
  const out = {}; const safe = s.envs.filter(e => e.state === 'safe').map(e => e.w).sort((a, b) => a - b); let lo = 0, hi = safe.length - 1; let side = s.closeSide;
  for (const r of TUNE.closeAfter) { if (r < s.round || hi <= lo) continue; if (side === 'right') { out[safe[hi]] = r; hi--; } else { out[safe[lo]] = r; lo++; } side = side === 'right' ? 'left' : 'right'; }
  return out;
}

// ---------- effects ----------
const FPW = { move: 1, prec: 1, intel: 1, def: 1, shot: 2, draw: 2, mark: 2, pierce: 1, steady: 1, dmgTurn: 2, buy: 1, scrap: 1, cycleFree: 0.5 };
function runEffects(s, p, effs, ctx) { for (const e of effs) runEffect(s, p, e, ctx); }
function runEffect(s, p, e, ctx) {
  const pl = P(s, p); let fp = 0;
  switch (e.op) {
    case 'gain': if (e.res === 'def') pl.def += e.n; else if (e.res === 'shot') pl.shot += e.n; else pl.res[e.res] += e.n; ctx.out.push(`+${e.n} ${RES_LABEL[e.res]}`); fp = FPW[e.res] * e.n; break;
    case 'draw': { const n = drawCards(s, p, e.n); ctx.out.push(`Draw ${n}`); fp = FPW.draw * n; break; }
    case 'nextFire': if (e.reqMod) { pl.nextFire.reqMod += e.reqMod; ctx.out.push(`Mark ${e.reqMod}`); } break;
    case 'mark': pl.nextFire.reqMod += e.n; ctx.out.push(times(e.n, 'Mark')); fp = FPW.mark * e.n; break;
    case 'pierce': case 'ignoreCover': if (!pl.ignoreCover) fp = FPW.pierce; pl.ignoreCover = true; ctx.out.push('Pierce'); break;
    case 'steady': case 'revealPlus': pl.revealPlus += e.n; ctx.out.push(times(e.n, 'Steady')); fp = FPW.steady * e.n; break;
    case 'dmgTurn': pl.dmgTurn += e.n; ctx.out.push(`hits +${e.n} damage`); fp = FPW.dmgTurn * e.n; break;
    case 'buy': pl.buyBonus += e.n; ctx.out.push(`+${e.n} Buy`); fp = FPW.buy * e.n; break;
    case 'scrap': pl.scrapAvail += e.n; ctx.out.push(`Scrap ${e.n}`); fp = FPW.scrap * e.n; break;
    case 'cycleFree': pl.freeCycles += e.n; ctx.out.push(`${e.n} free cycle${e.n > 1 ? 's' : ''}`); fp = FPW.cycleFree * e.n; break;
  }
  if (s.turn === p) pl.fp += fp;
}

// ---------- turn checks ----------
function check(s, p) { if (s.over) return fail('The match is over.'); if (s.turn !== p) return fail("It isn't your turn."); if (s.shot) return fail('Finish the shot in progress first (FLIP or STOP).'); return null; }

// Squad: a card's Squad line pays once for each OTHER card of its squad in play (Loadout counts), up to ×3.
// Order never matters: whenever a new squad card arrives, every line already in play is topped up to its new count.
function squadCounts(s, p) { const pl = P(s, p); const c = { assault: 0, recon: 0, support: 0, engineer: 0 }; for (const i of pl.play.concat(pl.loadout)) { const a = cardDef(s, i).archetype; if (a in c) c[a]++; } return c; }
function checkSquads(s, p, ctx) {
  const pl = P(s, p); const cnt = squadCounts(s, p);
  for (const i of pl.play) { const d = cardDef(s, i); if (!d.squad) continue;
    const want = Math.min(TUNE.squadCap, cnt[d.archetype] - 1); const have = pl.squadN[i] || 0; if (want <= have) continue;
    const c2 = { out: [] }; for (let k = have; k < want; k++) runEffects(s, p, d.squad, c2);
    pl.squadN[i] = want; pl.stats.squads += want - have; pl.turnSquads = (pl.turnSquads || 0) + want - have; ctx.out.push(`Squad ×${want} (${d.name}): ${effText(d.squad)}${want - have > 1 ? ` ×${want - have}` : ''}`); }
  for (const a of SQUADS) for (const n of TUNE.rally) { const key = a + n; if (cnt[a] >= n && !pl.rallyDone.includes(key)) {
    pl.rallyDone.push(key); const c2 = { out: [] }; runEffects(s, p, RALLY[a][n], c2); pl.stats.rallies++; ctx.out.push(`${ARCH_TAG[a].toUpperCase()} RALLY ${n}: ${c2.out.join(', ')}`); } }
}
// o.slot: Loadout slot (0/1) to replace when the row is full; o.once: use a Loadout card once instead of deploying it
function playCard(s, p, iid, o = {}) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!pl.hand.includes(iid)) return fail('That card is not in your hand.');
  const def = cardDef(s, iid);
  pl.hand.splice(pl.hand.indexOf(iid), 1);
  const ctx = { out: [] };
  if (def.loadout) {
    const full = pl.loadout.length >= TUNE.loadoutSlots;
    if (o.once || (full && o.slot == null)) { pl.play.push(iid); ctx.out.push('used once'); }
    else { if (full) { const old = pl.loadout.splice(o.slot, 1)[0]; pl.discard.push(old); ctx.out.push(`replaces ${cardDef(s, old).name}`); } pl.loadout.push(iid); ctx.out.push('deployed to the Loadout row'); }
    runEffects(s, p, def.loadout, ctx);
  } else { pl.play.push(iid); runEffects(s, p, def.effects, ctx); }
  checkSquads(s, p, ctx);
  log(s, `${pl.name} plays ${def.name}${ctx.out.length ? ': ' + ctx.out.join(', ') : ''}.`, 'play');
  return { ok: true, out: ctx.out };
}
function playAll(s, p) { const pl = P(s, p); const e = check(s, p); if (e) return e; for (const iid of pl.hand.slice()) playCard(s, p, iid); return { ok: true }; }
function rolesPlayed(s, p) { const pl = P(s, p); return new Set(pl.play.concat(pl.loadout).map(i => cardDef(s, i).archetype).filter(isSquad)); }
function archCounts(s, p) { const c = { assault: 0, support: 0, recon: 0, engineer: 0 }; allCards(P(s, p)).forEach(i => { const a = cardDef(s, i).archetype; if (a in c) c[a]++; }); return c; }
function mainSquad(s, p) { const c = archCounts(s, p); const a = SQUADS.slice().sort((x, y) => c[y] - c[x])[0]; return c[a] ? a : null; }

// ---------- movement ----------
function moveCost(s, p, tw) { const pl = P(s, p); if (!envAt(s, tw) || tw === pl.pos) return null; return Math.abs(tw - pl.pos); }
function reachable(s, p) { const pl = P(s, p); return s.envs.map(e => ({ w: e.w, cost: moveCost(s, p, e.w) })).filter(r => r.cost != null && r.cost <= pl.res.move); }
function arriveBonus(s, p, env) {
  const pl = P(s, p); const d = ENVS[env.def]; if (env.state !== 'safe' || !d.bonus || pl.bonusTaken.includes(env.w)) return '';
  pl.bonusTaken.push(env.w); const b = d.bonus; const ctx = { out: [] };
  const fx = []; if (b.draw) fx.push(D(b.draw)); if (b.intel) fx.push(I(b.intel)); if (b.def) fx.push(Ar(b.def)); if (b.prec) fx.push(Pr(b.prec)); if (b.move) fx.push(M(b.move)); if (b.shot) fx.push(Sh(b.shot)); if (b.scrap) fx.push(SC(b.scrap)); if (b.cycle) fx.push(CY(b.cycle));
  runEffects(s, p, fx, ctx);
  return ctx.out.length ? ` ${d.name}: ${ctx.out.join(', ')}.` : '';
}
function move(s, p, tw) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const cost = moveCost(s, p, tw); if (cost == null) return fail('Choose a different location.');
  if (!inSafe(s, tw)) return fail('That location is in the gas.');
  if (cost > pl.res.move) return fail(`Needs ${cost} Movement (you have ${pl.res.move}).`);
  if (pl.moved) return fail('You already moved this turn (one Move per turn).');
  const before = dist(s); pl.res.move -= cost; pl.pos = tw; pl.moved = true;
  let extra = arriveBonus(s, p, envAt(s, tw));
  if (pl.pos === P(s, 1 - p).pos) extra += ' Close quarters: shots ignore cover and Armor.';
  if (dist(s) < before) pl.movedToward = true;
  log(s, `${pl.name} moves to ${ENVS[envAt(s, tw).def].name} (−${cost}).${extra}`, 'act');
  return { ok: true };
}

// ---------- market ----------
const buysLeft = (s, p) => Math.max(0, TUNE.buyCap + P(s, p).buyBonus - P(s, p).buys);
function gainCard(s, p, iid) { const pl = P(s, p); if (s.round <= TUNE.hotDrop) pl.deck.push(iid); else pl.discard.push(iid); pl.stats.cardsAcquired++; }
function cycle(s, p, pay) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const env = envAt(s, pl.pos); if (!env || env.state !== 'safe') return fail('Nothing to cycle here.');
  if (env.loot.length < 2) return fail('Only one card in this stack.');
  let how;
  if (pl.freeCycles > 0) { pl.freeCycles--; how = 'free'; }
  else if (pay === 'move') { if (pl.res.move < TUNE.cycleCost) return fail('Cycling costs 1 Movement or 1 Intel.'); pl.res.move -= TUNE.cycleCost; how = `−${TUNE.cycleCost} Movement`; }
  else { if (pl.res.intel < TUNE.cycleCost) return fail('Cycling costs 1 Intel or 1 Movement.'); pl.res.intel -= TUNE.cycleCost; how = `−${TUNE.cycleCost} Intel`; }
  const top = env.loot.shift(); env.loot.push(top); markTop(env); pl.stats.cycles = (pl.stats.cycles || 0) + 1;
  log(s, `${pl.name} cycles ${itemDef(s, top).name} to the bottom (${how}): ${itemDef(s, env.loot[0]).name} on top.`, 'act');
  return { ok: true };
}
function lootNear(s, p, id) {
  const pl = P(s, p);
  for (const w of [pl.pos, pl.pos - 1, pl.pos + 1]) { const e = envAt(s, w); if (!e || e.state !== 'safe') continue; const it = e.loot[0] && e.loot[0].iid === id ? e.loot[0] : null; if (it) return { it, env: e, adj: w !== pl.pos }; }
  return null;
}
function lootCost(s, p, item) { const near = lootNear(s, p, item.iid); return Math.max(0, itemDef(s, item).intel_cost + (near && near.adj ? TUNE.adjCost : 0)); }
function buyTotal(s, p, iids) { let t = 0; for (const id of iids) { const n = lootNear(s, p, id); if (n) t += lootCost(s, p, n.it); } return t; }
function buy(s, p, iids, o = {}) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const list = (Array.isArray(iids) ? iids : [iids]).filter((x, i, a) => a.indexOf(x) === i);
  if (!list.length) return fail('Pick something.');
  if (list.length > 1) return fail('Buy one item at a time.');
  const near = lootNear(s, p, list[0]); if (!near) return fail('You can only buy the top card of a stack where you stand or next door (+1 Intel).');
  if (buysLeft(s, p) < 1) return fail(`No buys left this turn (${TUNE.buyCap}${pl.buyBonus ? ` + ${pl.buyBonus}` : ''} per turn).`);
  const item = near.it; const total = lootCost(s, p, item);
  if (pl.res.intel < total) return fail(`Needs ${total} Intel (you have ${pl.res.intel}).`);
  pl.res.intel -= total; pl.buys++; pl.stats.buys++;
  const src = near.env; src.loot.splice(src.loot.indexOf(item), 1); markTop(src); let extra = near.adj ? ' (from next door)' : '';
  if (item.kind === 'card') { gainCard(s, p, item.iid); if (s.round <= TUNE.hotDrop) extra += ' (Hot Drop: on top of the deck)'; }
  else {
    const old = pl.guns[0];
    if (old) { src.loot.push({ kind: 'weapon', iid: old }); extra += `, dropping ${WEAPONS[s.weapons[old].def].name}`; }
    pl.guns[0] = item.iid; pl.stats.weaponAcq++; s.weapons[item.iid].shots = 0; extra = ' (loaded)' + extra;
  }
  log(s, `${pl.name} takes ${itemDef(s, item).name}${extra} for ${total} Intel.`, 'act');
  return { ok: true };
}
function plateCost() { return TUNE.supplyCost; }
function buySupply(s, p, id) {
  const pl = P(s, p); const e = check(s, p); if (e) return e; id = id || TUNE.station[0];
  if (!TUNE.station.includes(id)) return fail('Not sold at the Buy Station.');
  if (!(s.stationLeft[id] > 0)) return fail(`${CARDS[id].name} is sold out.`);
  if (buysLeft(s, p) < 1) return fail(`No buys left this turn (${TUNE.buyCap}${pl.buyBonus ? ` + ${pl.buyBonus}` : ''} per turn).`);
  const cost = plateCost(); if (pl.res.intel < cost) return fail(`Buy Station cards cost ${cost} Intel.`);
  pl.res.intel -= cost; pl.buys++; pl.stats.buys++; s.stationLeft[id]--; const iid = newCard(s, id); gainCard(s, p, iid); pl.stats.supply = (pl.stats.supply || 0) + 1;
  log(s, `${pl.name} buys ${CARDS[id].name} at the Buy Station.`, 'act'); return { ok: true };
}
// Buy Station service: pay 1 Intel to Scrap a Sprint (hand, play area or discard), once per turn. Not a buy.
function stationScrap(s, p, iid) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (pl.stationScrapped) return fail('The Scrap service is once per turn.');
  if (pl.res.intel < TUNE.stationScrapCost) return fail(`The Scrap service costs ${TUNE.stationScrapCost} Intel.`);
  const from = [pl.hand, pl.play, pl.discard].find(z => z.includes(iid)); if (!from) return fail('Choose a Sprint in your hand, play area or discard pile.');
  if (cardDef(s, iid).id !== 'T001') return fail('The Scrap service only takes a Sprint.');
  if (owned(pl) <= TUNE.minDeck) return fail(`Your deck is at the ${TUNE.minDeck}-card minimum.`);
  pl.res.intel -= TUNE.stationScrapCost; pl.stationScrapped = true; from.splice(from.indexOf(iid), 1); pl.removed.push(iid); pl.stats.burned++;
  log(s, `${pl.name} pays ${TUNE.stationScrapCost} Intel at the Buy Station to scrap a Sprint (out of the game).`, 'fx'); return { ok: true };
}
function scrap(s, p, iid) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!(pl.scrapAvail > 0)) return fail('No Scrap available. Play a card with Scrap first.');
  const from = [pl.hand, pl.play, pl.discard].find(z => z.includes(iid));
  if (!from) return fail('Scrap takes a card from your hand, play area or discard pile.');
  if (owned(pl) <= TUNE.minDeck) return fail(`Your deck is at the ${TUNE.minDeck}-card minimum.`);
  from.splice(from.indexOf(iid), 1); pl.removed.push(iid); pl.scrapAvail--; pl.stats.burned++;
  log(s, `${pl.name} scraps ${cardDef(s, iid).name} (out of the game).`, 'fx'); return { ok: true };
}

// ---------- fire: push your luck (board task wb-pyl-impl; design push-your-luck-shooting.md, head's answers P1–P3) ----------
// FIRE. Flip cards off the top of your deck one at a time. Each flip costs 1 Precision. Add up the Hit Markers.
// When your total reaches a step on your gun's ladder, you may STOP and deal that step's damage, or flip on for the next step.
// A card with the Jam icon (Sprint, Scout) is a Jam. It costs your gun's Recoil in Precision, and your second Jam in one shot is a miss.
// In the final circle, your first Jam is a miss (Hot Zone). If you run out of Precision before the first step, you miss.
// Steady: cancel a Jam. Mark: your next shot needs 1 fewer Hit Marker on every step.
// A shot is three actions: fireStart → flip (one per tap) → stop. The top step banks by itself; running out of Precision (or cards)
// on a step banks that step. Flipped cards sit in s.shot until the shot ends, then go to the discard pile.
//
// The bust rule is built from small seams so variants can be swapped in through TUNE.pyl (only the shipped values are built):
//   jamScope 'shot' (Jams count per shot) | 'turn' ("Heat": pl.heat counts every Jam this turn)  → jamsCounted()
//   bustAt / finalBustAt: Jams that make it a miss, normally / in the final circle               → bustLine()
//   bustCost 'shot' (this shot misses)  | later: 'turn' (lose all unbanked damage), 'penalty'     → onBust()
//   bank 'shot' (damage lands when the shot ends) | later: 'turn' (damage lands at End turn)     → bankShot()
const PYL_BUILT = { jamScope: ['shot', 'turn'], bustCost: ['shot'], bank: ['shot'] };
function pylCheck() { const c = TUNE.pyl; for (const k in PYL_BUILT) if (!PYL_BUILT[k].includes(c[k])) throw new Error(`TUNE.pyl.${k} "${c[k]}" is not built yet (built: ${PYL_BUILT[k].join(', ')})`); }
const isJamDef = d => !!d.jam;
function bustLine(s) { return safeBounds(s).n <= 1 ? TUNE.pyl.finalBustAt : TUNE.pyl.bustAt; }
const jamsCounted = (pl, sh) => TUNE.pyl.jamScope === 'turn' ? pl.heat : sh.jams;
function onBust(s, p, sh) { /* bustCost 'shot': the shot deals nothing; nothing else is lost */ }
function bankShot(s, p, sh) { // bank 'shot': the banked step hits now. Returns { dealt, notes }.
  const lvl = sh.level; const r = applyHit(s, 1 - p, sh.steps[lvl][1], sh.cq); const notes = [];
  if (sh.cover) notes.push(`cover −${sh.cover}`); if (sh.cq && !r.notes.some(n => n.startsWith('close quarters'))) notes.push('close quarters');
  return { dealt: r.dealt, notes: notes.concat(r.notes) };
}
const levelOf = (steps, sum) => steps.filter(([h]) => sum >= h).length - 1;

function shotsLeft(s, p, gi) { const pl = P(s, p); const wid = pl.guns[gi]; if (!wid) return 0; return Math.max(0, eff(s, wid).magazine_capacity - s.weapons[wid].shots) + pl.shot; }
// What a shot with gun slot gi would look like right now (or the open shot's numbers, if one is in progress).
function shotPreview(s, p, gi = 0) {
  const pl = P(s, p), o = P(s, 1 - p); const wid = pl.guns[gi]; if (!wid) return null;
  const W = s.weapons[wid]; const E = eff(s, wid); const d = WEAPONS[W.def];
  const Dd = dist(s); const inBand = Dd >= E.band[0] && Dd <= E.band[1];
  const steps = E.ladder.map(([h, dm]) => [Math.max(1, h - pl.nextFire.reqMod), dm + pl.dmgTurn]);
  const cq = TUNE.closeQuarters && Dd === 0;
  const tEnv = envAt(s, o.pos); const cover = !cq && tEnv && tEnv.state === 'safe' && !pl.ignoreCover ? ENVS[tEnv.def].cover : 0;
  const net = dm => Math.max(1, dm - cover);
  const pool = pl.deck.length ? pl.deck : pl.discard;
  return { gi, prec: pl.res.prec, need: steps[0][0], mark: pl.nextFire.reqMod, recoil: E.recoil, cover, cq, steady: pl.revealPlus,
    steps: steps.map(([h, dm]) => [h, net(dm)]), rawSteps: steps, band: E.band, range: E.max_range, rawDistance: Dd, inRange: inBand, left: shotsLeft(s, p, gi), melee: d.melee,
    bustAt: bustLine(s), hotZone: bustLine(s) < TUNE.pyl.bustAt, flipCost: TUNE.pyl.flipCost,
    jamsInDeck: pool.filter(i => isJamDef(cardDef(s, i))).length, cardsInDeck: pool.length };
}
function shootCheck(s, p, gi = 0) {
  const pl = P(s, p); const wid = pl.guns[gi];
  if (s.shot) return fail('Finish the shot in progress first (FLIP or STOP).');
  if (!wid) return fail('No gun in that slot.');
  if (shotsLeft(s, p, gi) < 1) return fail(`${WEAPONS[s.weapons[wid].def].name} has fired its shots this turn.`);
  const E = eff(s, wid);
  if (dist(s) < E.band[0] || dist(s) > E.band[1]) return fail(`${WEAPONS[s.weapons[wid].def].name} fires at distance ${E.band[0]}–${E.band[1]}. You are at ${dist(s)}.`);
  if (pl.res.prec < TUNE.pyl.flipCost) return fail('No Precision: every flip costs 1 Precision. Play Precision cards first.');
  if (!pl.deck.length && !pl.discard.length) return fail('No cards to flip.');
  return { ok: true };
}
function applyHit(s, ti, dmg, cq) {
  const t = P(s, ti); const notes = [];
  // reaction cards in hand: the best one is used automatically
  const rx = t.hand.filter(i => cardDef(s, i).reaction).sort((a, b) => cardDef(s, b).reaction - cardDef(s, a).reaction)[0];
  if (rx && dmg > 1) { const r = Math.min(cardDef(s, rx).reaction, dmg - 1); dmg -= r; t.hand.splice(t.hand.indexOf(rx), 1); t.discard.push(rx); t.stats.reactions++; notes.push(`${cardDef(s, rx).name} reaction −${r}`); }
  if (!cq) { const ab = Math.min(t.def, dmg - 1); if (ab > 0) { t.def -= ab; dmg -= ab; notes.push(`Armor −${ab}`); } }
  else if (t.def) notes.push('close quarters: Armor ignored');
  t.hp -= dmg; return { dealt: dmg, notes };
}
function checkDeath(s, by) {
  const d0 = s.players[0].hp <= 0, d1 = s.players[1].hp <= 0;
  if (!d0 && !d1) return;
  s.over = true; s.endBy = by || 'ko'; const [a, b] = s.players;
  s.winner = d0 && d1 ? (a.hp !== b.hp ? (a.hp > b.hp ? 0 : 1) : 'draw') : d0 ? 1 : 0;
  log(s, s.winner === 'draw' ? 'Both operators fall. Draw.' : `${s.players[s.winner].name} is the last operator standing.`, 'win');
}
const flipTxt = c => c.jam ? (c.cancelled ? 'JAM (Steady)' : 'JAM') : String(c.hm);
// Start a shot with gun slot gi: uses one of its shots (or an extra shot) and the Mark. Nothing is flipped yet.
function fireStart(s, p, gi = 0) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const sc = shootCheck(s, p, gi); if (!sc.ok) return sc;
  pylCheck();
  const wid = pl.guns[gi]; const W = s.weapons[wid]; const d = WEAPONS[W.def]; const sp = shotPreview(s, p, gi);
  if (W.shots >= eff(s, wid).magazine_capacity) pl.shot--; else W.shots++; W.shotTurn = s.turnNo;
  s.shot = { p, gi, weapon: d.name, gunClass: d.gunClass, steps: sp.steps, need: sp.need, mark: sp.mark, recoil: sp.recoil, cover: sp.cover, cq: sp.cq, bustAt: sp.bustAt, hotZone: sp.hotZone,
    flipped: [], sum: 0, jams: 0, cancelled: 0, level: -1, prec0: pl.res.prec, stopped: false };
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  pl.stats.shots++;
  rec(s, `${pl.name} opens fire with the ${d.name}: steps ${sp.steps.map(([h, dm]) => `${h}→${dm}`).join(' · ')}${sp.hotZone ? ' (final circle: the first Jam misses)' : ''}.`, 'flip');
  return { ok: true, shot: s.shot };
}
// Flip the top card of your deck into the open shot.
function flip(s, p) {
  const pl = P(s, p); const sh = s.shot;
  if (s.over) return fail('The match is over.');
  if (!sh || sh.p !== p) return fail('No shot in progress: tap FIRE first.');
  if (pl.res.prec < TUNE.pyl.flipCost) return resolveShot(s, sh.level >= 0 ? 'bank' : 'out', null);
  if (!pl.deck.length) { if (!pl.discard.length) return resolveShot(s, sh.level >= 0 ? 'bank' : 'out', null); pl.deck = shuffle(s, pl.discard); pl.discard = []; }
  const iid = pl.deck.pop(); pl.res.prec -= TUNE.pyl.flipCost; pl.stats.flips++;
  const def = cardDef(s, iid); const c = { iid, name: def.name, hm: def.hit_markers, jam: isJamDef(def), cancelled: false, recoil: 0 };
  sh.flipped.push(c); sh.sum += c.hm;
  let ev = 'flip';
  if (c.jam) {
    if (pl.revealPlus > 0) { pl.revealPlus--; c.cancelled = true; sh.cancelled++; ev = 'steady'; }
    else {
      sh.jams++; pl.heat++; pl.stats.jams++; ev = 'jam';
      if (TUNE.pyl.jamRecoil) { const b = pl.res.prec; pl.res.prec = Math.max(0, pl.res.prec - sh.recoil); c.recoil = b - pl.res.prec; }
      if (jamsCounted(pl, sh) >= sh.bustAt) return resolveShot(s, 'bust', c);
    }
  }
  const was = sh.level; sh.level = levelOf(sh.steps, sh.sum);
  if (sh.level >= sh.steps.length - 1) return resolveShot(s, 'bank', c);
  if (pl.res.prec < TUNE.pyl.flipCost || (!pl.deck.length && !pl.discard.length)) return resolveShot(s, sh.level >= 0 ? 'bank' : 'out', c);
  if (sh.level > was) ev = ev === 'flip' ? 'step' : ev;
  rec(s, `${pl.name} flips ${def.name}: ${flipTxt(c)}${c.recoil ? ` (−${c.recoil} Precision)` : ''} · ${sh.sum}/${sh.steps[Math.min(sh.steps.length - 1, sh.level + 1)][0]} Hit Markers.`, ev === 'jam' ? 'jamf' : 'flip');
  return { ok: true, card: c, event: ev, shot: sh, stepUp: sh.level > was };
}
// Bank the step you are on.
function stop(s, p) {
  const sh = s.shot;
  if (s.over) return fail('The match is over.');
  if (!sh || sh.p !== p) return fail('No shot in progress.');
  if (sh.level < 0) return fail(`Reach the first step (${sh.steps[0][0]} Hit Markers) before you stop.`);
  sh.stopped = true; return resolveShot(s, 'bank', null);
}
function resolveShot(s, how, last) {
  const sh = s.shot; const p = sh.p; const pl = P(s, p); s.shot = null;
  pl.discard.push(...sh.flipped.map(c => c.iid));
  let dealt = 0, notes = []; const hit = how === 'bank'; const lvl = hit ? sh.level : -1;
  if (hit) { pl.stats.hits++; pl.stats.hitsBy[s.weapons[pl.guns[sh.gi]].def] = (pl.stats.hitsBy[s.weapons[pl.guns[sh.gi]].def] || 0) + 1; if (lvl > 0) pl.stats.big++;
    const r = bankShot(s, p, sh); dealt = r.dealt; notes = r.notes; if (lvl === sh.steps.length - 1 && sh.steps.length > 2 && sh.gunClass === 'sniper') notes.unshift('HEADSHOT');
    pl.stats.damageDealt += dealt; pl.stats.turnDmg += dealt; }
  else if (how === 'bust') { pl.stats.busts++; onBust(s, p, sh); }
  else pl.stats.outs++;
  const seq = sh.flipped.map(flipTxt).join(' · ') || 'no cards';
  s.lastFire = { p, gi: sh.gi, weapon: sh.weapon, revealed: sh.flipped.map(c => ({ name: c.name, hm: c.hm, jam: c.jam, cancelled: c.cancelled, recoil: c.recoil })), total: sh.sum, req: sh.steps[0][0], steps: sh.steps,
    level: lvl, reached: sh.level, hit, dealt, notes, how, jam: how === 'bust', stopped: sh.stopped, jams: sh.jams, cancelled: sh.cancelled, bustAt: sh.bustAt, hotZone: sh.hotZone, recoil: sh.prec0 - pl.res.prec, flips: sh.flipped.length };
  const tail = hit ? `→ HIT for ${dealt} (step ${lvl + 1}${sh.stopped ? ', stopped' : lvl === sh.steps.length - 1 ? ', top step' : ', banked'}${notes.length ? `, ${notes.join(', ')}` : ''})` : how === 'bust' ? `→ MISS (JAMMED${sh.hotZone ? ' in the final circle' : ''})` : `→ MISS (out of ${pl.res.prec < TUNE.pyl.flipCost ? 'Precision' : 'cards'} before step 1)`;
  log(s, `${pl.name} fires ${sh.weapon}: ${seq} ${tail}. Precision ${sh.prec0}→${pl.res.prec}.`, hit ? 'hit' : 'miss');
  checkDeath(s, 'ko');
  return { ok: true, card: last, event: how, done: true, result: s.lastFire };
}
// Fire a whole shot in one call (tests, scripted replays): flip until the shot ends or reaches step o.stopAt (default: the first step), then stop.
function fire(s, p, gi = 0, o = {}) {
  const r = fireStart(s, p, gi); if (!r.ok) return r; const stopAt = o.stopAt == null ? 0 : o.stopAt;
  for (let g = 0; g < 200; g++) { const sh = s.shot; if (!sh) break; const x = sh.level >= stopAt ? stop(s, p) : flip(s, p); if (!x.ok) return x; if (x.done) return { ok: true, result: x.result }; }
  return { ok: true, result: s.lastFire };
}

// ---------- turn flow ----------
// Ready: reset, Loadout cards fire, then the location's bonus.
function startTurn(s, p) {
  const pl = P(s, p);
  Object.assign(pl, { res: { move: 0, prec: 0, intel: 0 }, def: 0, shot: 0, revealPlus: 0, dmgTurn: 0, ignoreCover: false, buys: 0, buyBonus: 0, scrapAvail: 0, freeCycles: 0,
    stationScrapped: false, squadN: {}, rallyDone: [], turnSquads: 0, heat: 0, moved: false, movedToward: false, bonusTaken: [], fp: 0 });
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  for (const wid of guns(pl)) { s.weapons[wid].shots = 0; s.weapons[wid].used = false; }
  pl.stats.turnDmg = 0;
  if (pl.loadout.length) { const ctx = { out: [] }; for (const i of pl.loadout) runEffects(s, p, cardDef(s, i).loadout, ctx); checkSquads(s, p, ctx); log(s, `${poss(pl.name)} Loadout (${pl.loadout.map(i => cardDef(s, i).name).join(', ')}): ${ctx.out.join(', ')}.`, 'play'); }
  const env = envAt(s, pl.pos); if (env) { const t = arriveBonus(s, p, env); if (t) log(s, `${pl.name} holds${t}`, 'fx'); }
}
function endTurn(s, p) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  pl.stats.maxTurnDmg = Math.max(pl.stats.maxTurnDmg, pl.stats.turnDmg);
  pl.fpHist.push(Math.round(pl.fp * 10) / 10);
  pl.discard.push(...pl.hand, ...pl.play); pl.hand = []; pl.play = [];
  pl.scrapAvail = 0;
  if (TUNE.digIn && pl.res.move > 0) { const a = Math.min(TUNE.digIn, pl.res.move); pl.def += a; pl.stats.dugIn = (pl.stats.dugIn || 0) + a; log(s, `${pl.name} digs in: +${a} Armor from unused Movement.`, 'fx'); }
  pl.res = { move: 0, prec: 0, intel: 0 }; pl.shot = 0; // Armor stays up through the rival's turn
  drawCards(s, p, TUNE.hand + (TUNE.lowHp && pl.hp > 0 && pl.hp <= TUNE.lowHp ? 1 : 0));
  const fpN = pl.fpHist[pl.fpHist.length - 1], fpP = pl.fpHist[pl.fpHist.length - 2]; const dd = fpP == null ? '' : ` (${fpN >= fpP ? '▲' : '▼'}${Math.round(Math.abs(fpN - fpP))})`;
  log(s, `${pl.name} ends the turn. Turn ${pl.fpHist.length}: Firepower ${Math.round(fpN)}${dd} · Squad ×${pl.turnSquads || 0} · ${pl.stats.turnDmg} damage.`, 'act');
  s.turnNo++;
  let next = 1 - p;
  if (p !== s.first) { endRound(s); if (TUNE.alternateFirst && !s.over) { s.first = 1 - s.first; log(s, `${s.players[s.first].name} takes the lead this round.`, 'round'); } next = s.first; }
  if (s.over) return { ok: true };
  s.turn = next; startTurn(s, s.turn); // Armor lasts until your next turn: it drops at Ready
  return { ok: true };
}
function nextPhase() { return null; }
function gasRate(s) { return TUNE.closeAfter.includes(s.round) ? 1 : 0; }
// the edge that closes at the end of this round (public schedule), or []
function closing(s) { const B = safeBounds(s); if (B.n <= 1 || !TUNE.closeAfter.includes(s.round)) return []; return [s.closeSide === 'right' ? B.hi : B.lo]; }
function endRound(s) {
  const list = closing(s);
  if (list.length) {
    for (const w of list) { const ge = envAt(s, w); ge.state = 'gas'; s.gone.push(...ge.loot.filter(it => it.kind === 'card' || it.kind === 'weapon')); ge.loot = []; ge.crate = null; log(s, `Round ${s.round} ends. Gas swallows ${ENVS[ge.def].name}.`, 'gas'); }
    s.closeSide = s.closeSide === 'right' ? 'left' : 'right';
  } else log(s, `Round ${s.round} ends.`, 'round');
  // caught outside: 3 damage +1 per extra space, then pushed back to the nearest safe location
  const B = safeBounds(s);
  for (const pl of s.players) {
    if (pl.pos >= B.lo && pl.pos <= B.hi) continue;
    const depth = pl.pos < B.lo ? B.lo - pl.pos : pl.pos - B.hi; const dmg = TUNE.gasDmg + depth - 1;
    pl.hp -= dmg; const back = pl.pos < B.lo ? B.lo : B.hi; pl.pos = back; pl.stats.gasTaken = (pl.stats.gasTaken || 0) + dmg;
    log(s, `${pl.name} is caught ${depth} space${depth > 1 ? 's' : ''} deep in the gas: −${dmg}, pushed back to ${ENVS[envAt(s, back).def].name}.`, 'gas');
  }
  if (B.n <= 1) { s.finalReached = true; const dmg = TUNE.finalStorm[Math.min(s.finalN, TUNE.finalStorm.length - 1)]; s.finalN++; s.finalDmg = dmg; for (const pl of s.players) { pl.hp -= dmg; pl.stats.gasTaken = (pl.stats.gasTaken || 0) + dmg; } log(s, `Final circle: the storm hits both operators for ${dmg}.`, 'gas'); }
  checkDeath(s, s.finalN ? 'storm' : 'gas'); if (s.over) return;
  if (s.round >= TUNE.hardEnd) {
    const [a, b] = s.players; s.over = true; s.endBy = 'hardEnd'; s.winner = a.hp === b.hp ? 'draw' : a.hp > b.hp ? 0 : 1;
    log(s, `Hard end after round ${s.round}: ${s.winner === 'draw' ? 'equal Health, a draw' : `${s.players[s.winner].name} wins on Health (${a.hp}–${b.hp})`}.`, 'win'); return;
  }
  s.round++;
  // fresh loot lands on top of every safe stack (2 in 3 of the location's squad, tier by phase); a stack over 3 loses its bottom item
  for (const e of s.envs) { if (e.state !== 'safe') continue; const it = pull(s, e, phaseTier(s), false); if (it) e.loot.unshift(it); while (e.loot.length > TUNE.stackSize) s.gone.push(e.loot.pop()); markTop(e); }
  if (TUNE.crateRounds.includes(s.round - 1)) {
    const B2 = safeBounds(s); const mid = (B2.lo + B2.hi) / 2;
    const t = s.envs.filter(e => e.state === 'safe').sort((a, b) => Math.abs(a.w - mid) - Math.abs(b.w - mid) || a.w - b.w)[0];
    if (t) { const items = []; const g = (s.loot[3].findIndex(it => it.kind === 'weapon')); if (g >= 0) items.push(s.loot[3].splice(g, 1)[0]);
      while (items.length < TUNE.crate[0]) { const j = s.loot[3].findIndex(it => it.kind !== 'weapon'); if (j < 0) break; items.push(s.loot[3].splice(j, 1)[0]); }
      t.loot.unshift(...items); markTop(t); t.dropRound = s.round; if (items.length) log(s, `Supply crate lands on ${ENVS[t.def].name}: ${items.length} tier III items on top of its stack, ${itemDef(s, items[0]).name} face up.`, 'fx'); }
  }
  log(s, `Round ${s.round}.${TUNE.closeAfter.includes(s.round) && safeBounds(s).n > 1 ? ` ${ENVS[envAt(s, closing(s)[0]).def].name} closes at the end of this round.` : ''}`, 'round');
}

// ---------- estimates ----------
function lcg(seed) { let x = seed | 0; return () => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x / 0x7fffffff; }; }
// Odds for the open shot (or a fresh shot with gun slot gi): reach[k] = chance to reach step k if you keep flipping,
// plus the next flip's chance to be a Jam that counts and to end the shot. The unknown cards are the rest of the deck
// (any order), then the discard pile reshuffled. Seeded from the state, so the AI stays deterministic.
function shotOdds(s, p, gi = 0, trials = 150) {
  const pl = P(s, p); const sh = s.shot && s.shot.p === p ? s.shot : null;
  const sp = sh ? null : shotPreview(s, p, gi); if (!sh && !sp) return null;
  const steps = sh ? sh.steps : sp.steps; const recoil = sh ? sh.recoil : sp.recoil; const bustAt = sh ? sh.bustAt : sp.bustAt;
  const card = i => { const d = cardDef(s, i); return [d.hit_markers, isJamDef(d)]; };
  const dk = pl.deck.map(card), dc = pl.discard.map(card); const fc = TUNE.pyl.flipCost;
  const st0 = { sum: sh ? sh.sum : 0, jams: sh ? jamsCounted(pl, sh) : (TUNE.pyl.jamScope === 'turn' ? pl.heat : 0), prec: pl.res.prec, steady: pl.revealPlus };
  const lvl0 = levelOf(steps, st0.sum);
  const r = lcg((s.seed ^ Math.imul(pl.deck.length + 1, 7919) ^ Math.imul(pl.discard.length + 1, 104729) ^ Math.imul(st0.sum + 3, 31) ^ Math.imul(st0.prec + 5, 2654435)) | 0);
  const sh2 = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const cnt = steps.map(() => 0);
  for (let t = 0; t < trials; t++) {
    const seq = sh2(dk.slice()).concat(sh2(dc.slice())); const x = Object.assign({}, st0); let best = lvl0;
    for (let i = 0; i < seq.length && x.prec >= fc && best < steps.length - 1; i++) {
      const [hm, jam] = seq[i]; x.prec -= fc; x.sum += hm;
      if (jam) { if (x.steady > 0) x.steady--; else { x.jams++; if (TUNE.pyl.jamRecoil) x.prec = Math.max(0, x.prec - recoil); if (x.jams >= bustAt) break; } }
      best = Math.max(best, levelOf(steps, x.sum));
    }
    for (let k = 0; k <= best; k++) cnt[k]++;
  }
  const reach = cnt.map(v => v / trials);
  const pool = dk.length ? dk : dc; const jamN = pool.filter(c => c[1]).length;
  const pJam = pool.length && st0.steady < 1 ? jamN / pool.length : 0;
  return { reach, steps, level: lvl0, next: lvl0 + 1 < steps.length ? reach[lvl0 + 1] : null, pJam, pBust: st0.jams + 1 >= bustAt ? pJam : 0, jamsLeft: jamN, cardsLeft: pool.length, bustAt, jams: st0.jams, steady: st0.steady };
}

// ---------- AI ----------
const W8 = { move: 0.7, prec: 1, intel: 1, def: 0.6, shot: 2, draw: 1.8, mark: 1.5, pierce: 0.6, scrap: 1, cycleFree: 0.3, dmgTurn: 2.5, steady: 1.5, buy: 1.5 };
const val = effs => (effs || []).reduce((t, e) => t + (e.op === 'gain' ? W8[e.res] : W8[e.op] || 0) * (e.n || 1), 0);
const aiAware = (s, p) => !(s.aiMode && s.aiMode[p] === 'blind');
const poss = name => name === 'You' ? 'Your' : `${name}’s`;
function cardScore(s, p, d) {
  const pl = P(s, p); const aware = aiAware(s, p);
  let v = val(d.effects) + d.hit_markers * 1.1;
  if (d.loadout) v = val(d.loadout) * Math.min(4, Math.max(1, TUNE.hardEnd - s.round) / 2) + d.hit_markers * 0.3;
  if (d.reaction) v += 1;
  if (aware && isSquad(d.archetype)) {
    const fc = archCounts(s, p); const n = owned(pl) + 1; const f = (fc[d.archetype] + 1) / n;
    const lo = pl.loadout.some(i => cardDef(s, i).archetype === d.archetype) ? 1 : 0;
    const pSquad = lo ? 1 : 1 - Math.pow(1 - f, TUNE.hand - 1);
    if (d.squad) v += pSquad * val(d.squad) * Math.max(1, Math.min(TUNE.squadCap, (fc[d.archetype] + 1) * TUNE.hand / n));
    const force = s.aiMode && /^force:/.test(s.aiMode[p] || '') ? s.aiMode[p].slice(6) : null; // sim only: a one-squad deck
    const mf = force || mainSquad(s, p); if (mf && d.archetype === mf) v += 1.8; else if (force) v -= 4; else if (mf && fc[mf] >= 3) v -= 1.5;
    let partners = 0; for (const i of allCards(pl)) { const dx = cardDef(s, i); if (dx.archetype === d.archetype && dx.squad) partners += val(dx.squad); } v += Math.min(3, partners * 0.12);
  }
  return v;
}
function gunScore(s, p, wd) {
  const cur = WEAPONS[s.weapons[P(s, p).guns[0]].def];
  if (wd.gunClass === cur.gunClass && wd.tier <= cur.tier) return -1;
  if (cur.gunClass === 'pistol') return 12 + wd.tier * 3;
  const dd = wd.tier - cur.tier; return dd > 0 ? 10 + dd * 3 : -1;
}
function aiItemScore(s, p, it) { const d = itemDef(s, it); return it.kind === 'weapon' ? gunScore(s, p, d) : cardScore(s, p, d); }
function stationScore(s, p, id) {
  const d = CARDS[id];
  if (aiAware(s, p)) return cardScore(s, p, d) - 0.5;
  // combo-blind: buy whatever resource the deck has least of
  const tot = { move: 0, prec: 0, intel: 0, shot: 0 }; for (const i of allCards(P(s, p))) for (const e of cardDef(s, i).effects) if (e.op === 'gain' && e.res in tot) tot[e.res] += e.n;
  const want = { K02: tot.move / 1.0, K04: tot.prec / 1.4, K03: tot.intel / 1.2, K05: (tot.shot + 3) / 0.8 };
  const best = TUNE.station.slice().sort((a, b) => want[a] - want[b])[0];
  return id === best ? val(d.effects) + d.hit_markers * 1.1 : 0;
}
const MIN_SCORE = 3.0;
function aiBuy(s, p) {
  const pl = P(s, p);
  for (let guard = 0; guard < 6 && buysLeft(s, p) > 0; guard++) {
    const opts = [];
    for (const w of [pl.pos - 1, pl.pos, pl.pos + 1]) { const e = envAt(s, w); if (!e || e.state !== 'safe' || !e.loot.length) continue; const it = e.loot[0]; opts.push({ it, cost: lootCost(s, p, it), sc: aiItemScore(s, p, it) }); }
    for (const id of TUNE.station) if (s.stationLeft[id] > 0) opts.push({ station: id, cost: TUNE.supplyCost, sc: stationScore(s, p, id) });
    const ok = opts.filter(o => o.cost <= pl.res.intel && o.sc >= (o.it && o.it.kind === 'weapon' ? 0 : MIN_SCORE)).sort((a, b) => (b.sc - 0.35 * b.cost) - (a.sc - 0.35 * a.cost));
    const o = ok[0]; if (!o) break;
    const r = o.station ? buySupply(s, p, o.station) : buy(s, p, [o.it.iid]); if (!r.ok) break;
  }
}
function aiCycle(s, p) {
  const pl = P(s, p); const env = envAt(s, pl.pos);
  for (let k = 0; k < 2; k++) {
    if (!env || env.loot.length < 2 || buysLeft(s, p) < 1) return;
    const top = env.loot[0]; if (aiItemScore(s, p, top) >= MIN_SCORE && lootCost(s, p, top) <= pl.res.intel) return;
    const pay = pl.freeCycles > 0 ? 'intel' : pl.res.move >= 1 ? 'move' : null; if (!pay) return;
    if (!cycle(s, p, pay).ok) return; aiBuy(s, p);
  }
}
function aiScrap(s, p) {
  const pl = P(s, p); const mf = mainSquad(s, p);
  if (pl.res.intel >= TUNE.stationScrapCost && owned(pl) > TUNE.minDeck && mf && archCounts(s, p)[mf] >= 2) { const t = pl.discard.concat(pl.play).find(i => cardDef(s, i).id === 'T001'); if (t) stationScrap(s, p, t); }
  // Jam-aware (combo-aware AI only): Scouts are Jams, so they go once the deck has a little other Intel
  const scoutAt = aiAware(s, p) ? AI_PYL.scoutIntel : 6;
  while (pl.scrapAvail > 0 && owned(pl) > TUNE.minDeck) {
    const intelSrc = allCards(pl).filter(i => cardDef(s, i).id !== 'T002').reduce((t, i) => t + cardDef(s, i).effects.concat(cardDef(s, i).loadout || []).reduce((a, e) => a + (e.op === 'gain' && e.res === 'intel' ? e.n : 0), 0), 0);
    const pool = pl.discard.concat(pl.play).filter(i => { const id = cardDef(s, i).id; return id === 'T001' || (id === 'T002' && intelSrc >= scoutAt) || (id === 'T005' && s.round >= 5 && intelSrc >= 6); });
    const t = pool.sort((a, b) => (cardDef(s, a).id === 'T005') - (cardDef(s, b).id === 'T005'))[0]; if (!t || !scrap(s, p, t).ok) break;
  }
}
function aiScoreLoc(s, p, w) {
  const pl = P(s, p), o = P(s, 1 - p); const env = envAt(s, w); if (!env || env.state !== 'safe') return -99;
  let sc = 0; if (closing(s).includes(w)) sc -= 12;
  const E = eff(s, pl.guns[0]); const dd = Math.abs(w - o.pos);
  const off = dd < E.band[0] ? E.band[0] - dd : dd > E.band[1] ? dd - E.band[1] : 0; sc += 6 - 2.5 * off;
  if (off === 0 && E.band[1] <= 1 && dd === 0) sc += 1.5;
  const oE = eff(s, o.guns[0]); if (dd >= oE.band[0] && dd <= oE.band[1]) sc -= 1.5;
  if (dd !== 0) sc += ENVS[env.def].cover * 1.5;
  if (env.loot.length) { const it = env.loot[0]; const v = aiItemScore(s, p, it); if (v > MIN_SCORE || (it.kind === 'weapon' && v > 0)) sc += Math.min(3, v * 0.35); }
  if (aiAware(s, p)) { const mf = mainSquad(s, p); if (mf && ENVS[env.def].affinity === mf) sc += 1.2; }
  return sc;
}
function aiMove(s, p) {
  const pl = P(s, p); const here = aiScoreLoc(s, p, pl.pos);
  const opts = reachable(s, p).filter(r => inSafe(s, r.w)).map(r => ({ w: r.w, sc: aiScoreLoc(s, p, r.w) - 0.3 * r.cost })).sort((a, b) => b.sc - a.sc);
  if (opts.length && opts[0].sc > here + 0.5) move(s, p, opts[0].w);
}
function aiPlay(s, p) {
  const pl = P(s, p);
  for (const iid of pl.hand.slice()) {
    const d = cardDef(s, iid); if (!pl.hand.includes(iid)) continue;
    if (d.loadout && pl.loadout.length >= TUNE.loadoutSlots) { // replace the weakest slot if the new card is better, else use it once
      const mf = mainSquad(s, p); const sc = i => val(cardDef(s, i).loadout) + (aiAware(s, p) && cardDef(s, i).archetype === mf ? 1 : 0);
      const worst = pl.loadout.map((i, k) => [sc(i), k]).sort((a, b) => a[0] - b[0])[0];
      playCard(s, p, iid, sc(iid) > worst[0] ? { slot: worst[1] } : { once: true });
    } else playCard(s, p, iid);
  }
}
// Stop policy "Normal" (push-your-luck-shooting.md §3.1): fire when step 1 is at least 5% likely (a miss costs only the flips);
// on a step, push on only if the push fails at most 35% of the time.
const AI_PYL = { startMin: 0.05, pushRisk: 0.35, trials: 150, scoutIntel: 3 };
function aiFireLoop(s, p) {
  for (let g = 0; g < 12 && !s.over; g++) {
    if (!shootCheck(s, p, 0).ok) break;
    const o = shotOdds(s, p, 0, AI_PYL.trials); if (!o || o.reach[0] < AI_PYL.startMin) break;
    if (!fireStart(s, p, 0).ok) break;
    let decided = -1;
    for (let k = 0; k < 200 && s.shot && !s.over; k++) {
      const sh = s.shot;
      if (sh.level >= 0 && sh.level > decided) { decided = sh.level; const q = shotOdds(s, p, 0, AI_PYL.trials); if (1 - q.next > AI_PYL.pushRisk) { stop(s, p); break; } }
      if (!flip(s, p).ok) break;
    }
  }
}
function aiTurn(s, p) {
  if (s.over || s.turn !== p) return fail('not AI turn');
  aiPlay(s, p);
  aiMove(s, p);
  aiBuy(s, p); aiCycle(s, p);
  aiFireLoop(s, p);
  if (!s.over) { aiScrap(s, p); aiBuy(s, p); }
  if (s.over) return { ok: true };
  return endTurn(s, p);
}

// ---------- removed systems (kept as stubs so older callers fail politely) ----------
const LOADOUT = {}; const PERKS = {};
const no = () => fail('Not in these rules.');
const API = { RES, RES_LABEL, TIER_NAME, RARITY, MODS, GUNCLASS, CARDS, WEAPONS, ATTS, ENVS, WEAPON_COPIES, TUNE, ARCH_TAG, SQUADS, RALLY, RALLY_TEXT, FPW,
  newGame, playCard, playAll, move, buy, fire, endTurn, aiTurn, aiPlay, aiMove, aiBuy, aiCycle, aiFireLoop, aiScrap, AI_PYL, fireStart, flip, stop, shotOdds, bustLine, levelOf, stationScrap, squadCounts, mainSquad, buysLeft, closeSchedule, effText, playText,
  reachable, closing, GUNSET, LOCSET, locTier, locSize, SQUAD_TEXT, rolesPlayed, NEIGHBOURS, cycle, LOADOUT, plateCost, nextPhase, buySupply, scrap, lootNear, PERKS, archCounts, gasRate, moveCost,
  shotPreview, shootCheck, shotsLeft, lootCost, buyTotal, eff, envAt, dist, itemDef, cardDef, nextEdge, safeBounds, inSafe, isStarter, guns, owned, aiItemScore,
  activateGun: no, eligibleFuel: () => [], boostOk: () => 'Not in these rules.', search: no, searchable: () => null, burnAtBench: no, canBench: () => false, punch: no, pickPerk: no, perksOf: () => [], hasPerk: () => false, stackPlan: () => [], ammoLeft: () => 0 };
if (typeof module !== 'undefined' && module.exports) module.exports = API; else root.WD = API;
})(typeof window !== 'undefined' ? window : globalThis);
