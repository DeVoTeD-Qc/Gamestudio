/* WARZONE DECKBUILDER v7 "Squad Tactics" — rules engine (board tasks wb-rules, wb-pkg1).
   Rules (single source of truth): documentation/design/rules.md. v7 adds Squad Tactics, Spoils, Field Promotion, the Hot Drop delivery,
   Threat / deck readouts and the Operator rank (wb-improve-v2.md, the head's answers W1–W5) on top of engine-synergy-spec.md.
   Squads + Loadout build the engine; a fixed 7-location row closes on a public schedule into an escalating final circle and a hard end.
   Shooting: commit Precision to a shot (1 card revealed per Precision committed, up to 3; each Precision beyond that is +1 damage); the shot
   spends it, and Recoil costs more Precision on top. Cover and long range raise the Hit Markers needed (wb-odds2).
   Resources: Movement, Precision, Intel (+ Armor, which lasts until your next turn). */
(function (root) {
'use strict';

const RES = ['move', 'prec', 'intel'];
const TUNE = {
  hp: 60, hand: 5, firstHand: 5, lowHp: 10, digIn: 2, minDeck: 7,
  zones: 7, startA: 1, startB: 5, stackSize: 3, affinityShare: 2 / 3, adjCost: 1, cycleCost: 1,
  closeAfter: [2, 4, 5, 6, 7, 8], gasDmg: 3, finalStorm: [3, 4, 5, 6], hardEnd: 11, crateRounds: [2, 4], crate: [3, 1],
  buyCap: 2, hotDrop: 3, supplyCost: 2, station: ['K02', 'K04', 'K05', 'K03'], stationCopies: 6, stationScrapCost: 0,
  loadoutSlots: 2, squadCap: 3, rally: [3, 5],
  needPlus: 0, closeQuarters: true, pointBlank: true, aim: 'spend',
  stSprint: 3, stScout: 3, stAim: 2, alternateFirst: true,
  // wb-pkg1: Spoils (O2), Field Promotion (O3), Hot Drop delivery (O6), Squad Tactics (O1)
  spoils: 3, spoilsSquad: 1, promoteCost: 1, promoteBuy: 0, aiSpoilsFocus: 1.5, overwatchCap: 3, fortifyCap: 6, turretRange: 3,
  // wb-odds2: fewer turns deal damage now, so fewer Spoils. Three rules keep building on pace: Spoils also come after a turn in which you were
  // hit since your last turn (spoilsHurt), Field Promotion no longer uses a buy (promoteBuy 0) and the Buy Station's Scrap service is free.
  // wb-odds2 (head's wb-odds answer a: shots hit about 65%): a shot reveals at most aimCap cards; each Precision committed beyond that adds
  // aimPower damage (Power). Cover (+coverNeed per level) and long range (distance longFrom+: +longNeed) raise every step's Hit Markers.
  spoilsHurt: 1, aimCap: 3, aimPower: 1, coverNeed: 1, longFrom: 2, longNeed: 1,
  // wb-first-shot: the Sidearm has a rookie step in rounds 1..rookieRounds (the Hot Drop rounds), so a starter deck can land its first shot.
  // The loot sheet warns "Your deck can't fire this yet" when a full aim reaches a gun's first step less often than this
  fireWarn: 0.1, rookieRounds: 3,
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
// Squad Tactics (wb-pkg1, O1): rule-changing verbs, one small op each
const CH = n => ({ op: 'charge', n }), FT = n => ({ op: 'onHit', n }), SW = n => ({ op: 'sweep', n }), HL = n => ({ op: 'heal', n }), TU = n => ({ op: 'turret', n });
const EX = { op: 'expose' }, OW = { op: 'overwatch' }, FO = { op: 'fortify' }, RP = { op: 'repeat' }, AS = { op: 'anyStack' }, SP = (move, prec) => ({ op: 'suppress', move, prec });
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
    else if (e.op === 'dmgTurn') out.push(`Hits +${e.n} damage`);
    else if (e.op === 'buy') out.push(`+${e.n} Buy`);
    else if (e.op === 'charge') out.push(`Hits at distance 0: +${e.n} damage this turn`);
    else if (e.op === 'onHit') out.push(`next hit this turn: draw ${e.n}`);
    else if (e.op === 'sweep') out.push(`reorder your top ${e.n} cards`);
    else if (e.op === 'expose') out.push('this turn ignore cover, Armor and Reactions');
    else if (e.op === 'overwatch') out.push(`End turn: hold up to ${TUNE.overwatchCap} Precision; fire it if the rival ends in range`);
    else if (e.op === 'fortify') out.push(`keep your Armor at your next Ready (max ${TUNE.fortifyCap})`);
    else if (e.op === 'heal') out.push(`Heal ${e.n}`);
    else if (e.op === 'suppress') out.push(`Suppress: rival's next turn −${e.move} Movement, −${e.prec} Precision`);
    else if (e.op === 'repeat') out.push('repeat the play line of your previous card');
    else if (e.op === 'turret') out.push(`if the rival is 0–${TUNE.turretRange} away, reveal 1: 1 Hit Marker hits for ${e.n}`);
    else if (e.op === 'anyStack') out.push('buy from any stack this turn (printed cost)');
  }
  return out;
}
const effText = effs => effParts(effs).join(', ');
// a card's play line, short: "+1 Movement, +2 Precision. Pierce. Draw 1." (wb-ux-text: same words as Squad lines and Rally)
function playText(effs) {
  const g = effs.filter(e => e.op === 'gain'); const rest = effs.filter(e => e.op !== 'gain');
  const gs = g.map(e => `+${e.n} ${RES_LABEL[e.res]}${e.res === 'shot' && e.n > 1 ? 's' : ''}`);
  const s = [];
  if (gs.length) s.push(`${gs.join(', ')}.`);
  for (const p of effParts(rest)) s.push(p.charAt(0).toUpperCase() + p.slice(1) + '.');
  return s.join(' ');
}

// ---------- TACTICAL CARDS ----------
// TC(id, name, squad, tier, Hit Markers, cost, copies, play effects, extra: { squad: [...] (Squad line), loadout: [...] (Ready effect), reaction })
const CARDS = {};
function TC(id, name, archetype, tier, hm, cost, copies, effects, extra) {
  const d = Object.assign({ id, name, archetype, tier, hit_markers: hm, intel_cost: cost, copies, effects, tags: [ARCH_TAG[archetype]] }, extra || {});
  d.text = d.loadout ? `Loadout. Ready: ${effText(d.loadout)}.` : playText(effects);
  if (d.adrenaline) d.text += ' When you are hit, it returns from discard to hand.';
  if (d.squad) d.squadText = effText(d.squad);
  CARDS[id] = d;
}
// Starter deck (10): no squad
TC('T001', 'Sprint', 'starter', 0, 0, 0, 3, [M(1)]);
TC('T002', 'Scout', 'starter', 0, 0, 0, 3, [I(1)]);
TC('T004', 'Steady Aim', 'starter', 0, 1, 0, 2, [Pr(1)]);
TC('T005', 'Recon Run', 'starter', 0, 1, 0, 2, [M(1), I(1)]);
// Buy Station: one basic per squad, 2 Intel, 6 copies each
TC('K02', 'Tac Sprint', 'assault', 1, 1, 2, 0, [M(1), Pr(2)], { squad: [Pr(1)] });
TC('K04', 'Focus', 'recon', 1, 2, 2, 0, [Pr(2)], { squad: [Pr(1)] });
TC('K05', 'Spare Rounds', 'support', 1, 1, 2, 0, [Pr(2), Sh(1)], { squad: [Pr(1)] });
TC('K03', 'Dead Drop', 'engineer', 1, 1, 2, 0, [I(2)], { squad: [BY(1)] }); // wb-pkg1: +1 Buy per Engineer (promotions use a buy)
// ASSAULT: hits hit harder (wb-odds2: six cards 2 → 3 Hit Markers, so the squad still lands its shots under the 3-card aim limit)
TC('A11', 'Breach', 'assault', 1, 3, 1, 2, [M(1), Pr(2)], { squad: [DM(1), Pr(1)] });
TC('A12', 'Slide Cancel', 'assault', 1, 3, 1, 2, [M(2), Pr(1), SC(1)], { squad: [D(1), Pr(2)] });
TC('A13', 'Hip Fire', 'assault', 1, 3, 2, 2, [M(1), Pr(2)], { squad: [Pr(2), ST(1)] }); // wb-odds2: Squad line Steady (was +3 Precision)
TC('A21', 'Rush the Door', 'assault', 2, 3, 3, 2, [M(1), Pr(3), PI], { squad: [DM(1), Pr(2)] });
TC('AT1', 'Charge', 'assault', 2, 3, 3, 2, [M(2), Pr(1), CH(1)], { squad: [Pr(1)], tactic: true });
TC('AT2', 'Follow Through', 'assault', 2, 3, 3, 2, [M(1), Pr(2), FT(2)], { squad: [Pr(1)], tactic: true });
TC('AT3', 'Adrenaline', 'assault', 3, 3, 4, 2, [M(1), Pr(3)], { squad: [Pr(1)], tactic: true, adrenaline: true });
TC('A32', 'Breaching Charge', 'assault', 3, 3, 4, 2, [M(1), Pr(3), PI, DM(1)], { squad: [DM(1), Sh(1), ST(1)] });
TC('L1A', 'Tac Vest', 'assault', 2, 1, 3, 3, [], { loadout: [Pr(2), DM(1)], tiers: [1, 2, 2] });
// RECON: aim
TC('R11', 'Mark Target', 'recon', 1, 2, 1, 2, [Pr(2)], { squad: [MK(1), Pr(1)] });
TC('R12', 'Steady Breath', 'recon', 1, 3, 1, 2, [Pr(2)], { squad: [Pr(2)] });
TC('R13', 'Snapshot', 'recon', 1, 2, 2, 2, [Pr(2), I(1)], { squad: [I(2), Pr(1)] });
TC('RT1', 'Intel Sweep', 'recon', 2, 2, 3, 2, [Pr(2), SW(4)], { squad: [DM(1)], tactic: true });
TC('R22', 'Spotter Scope', 'recon', 2, 3, 3, 2, [Pr(3)], { squad: [MK(1), DM(1)] });
TC('RT2', 'Expose', 'recon', 2, 2, 3, 2, [Pr(2), MK(1), EX], { squad: [MK(1), DM(1)], tactic: true });
TC('R31', 'UAV', 'recon', 3, 3, 4, 2, [Pr(3), I(1), PI], { squad: [D(1), MK(1), Pr(1)] });
TC('RT3', 'Hold the Angle', 'recon', 3, 3, 4, 2, [Pr(3), OW], { squad: [DM(1)], tactic: true });
TC('L1R', 'Recon Post', 'recon', 2, 1, 3, 3, [], { loadout: [Pr(2)], tiers: [1, 2, 2] });
// SUPPORT: sustained fire (extra shots, Steady = +1 Hit Marker on every shot this turn, Armor)
TC('S11', 'Ammo Box', 'support', 1, 2, 2, 2, [Pr(2), ST(1), SC(1)], { squad: [Pr(3)] }); // wb-pkg1 trim: Steady instead of an extra shot
TC('S12', 'Suppressing Fire', 'support', 1, 2, 2, 2, [Pr(2), Ar(1)], { squad: [Pr(2), ST(1)] }); // wb-odds2: Squad line Steady (was +1 Armor)
TC('S13', 'Bandolier', 'support', 1, 2, 2, 2, [Pr(2), Ar(1), ST(1)], { squad: [Pr(3)] }); // wb-pkg1 trim: no extra shot
TC('ST1', 'Fortify', 'support', 2, 2, 3, 2, [Pr(2), Ar(2), FO], { squad: [Ar(1)], tactic: true });
TC('S22', 'Resupply', 'support', 2, 2, 3, 2, [Pr(1), I(1), D(1)], { squad: [ST(1), Pr(2)] }); // wb-pkg1 trim: no extra shot
TC('ST2', 'Field Medic', 'support', 2, 2, 3, 2, [Pr(1), HL(3)], { squad: [Pr(1)], tactic: true });
TC('S31', 'Overwatch', 'support', 3, 3, 5, 2, [Pr(4), Sh(1), Ar(2)], { squad: [Pr(2), Ar(1)] });
TC('ST3', 'Suppressing Barrage', 'support', 3, 3, 4, 2, [Pr(3), Sh(1), SP(1, 2)], { squad: [Pr(1)], tactic: true });
TC('L1S', 'Field Pack', 'support', 2, 1, 3, 3, [], { loadout: [Pr(1), ST(1)], tiers: [1, 2, 2] }); // wb-pkg1 trim: no extra shot
// ENGINEER: cash and contracts (Intel, +1 Buy, draw, Scrap)
TC('E11', 'Scrounge', 'engineer', 1, 1, 2, 2, [Pr(1), I(2), SC(1)], { squad: [I(2)] });
TC('E12', 'Deployable Cover', 'engineer', 1, 1, 2, 2, [Pr(1), I(2)], { squad: [I(2)], reaction: 3 });
TC('E13', 'Ping', 'engineer', 1, 1, 1, 2, [Pr(1), I(1), CY(1)], { squad: [D(1), I(1)] });
TC('ET1', 'Jury-Rig', 'engineer', 2, 2, 3, 2, [I(1), RP], { squad: [I(1)], tactic: true });
TC('ET2', 'Sentry Turret', 'engineer', 2, 1, 3, 2, [], { loadout: [TU(2)], tiers: [2, 3], tactic: true });
TC('E23', 'Salvage', 'engineer', 2, 2, 3, 2, [Pr(1), I(2), SC(1), CY(2)], { squad: [I(2), BY(1)] });
TC('E31', 'Field Workshop', 'engineer', 3, 2, 4, 2, [Pr(2), I(2), D(1), SC(2)], { squad: [Pr(2), D(1)] });
TC('ET3', 'Contraband Run', 'engineer', 3, 2, 4, 2, [Pr(1), I(3), AS], { squad: [I(1)], tactic: true });
TC('L1E', 'Bounty Contract', 'engineer', 2, 1, 3, 3, [], { loadout: [I(1), Pr(1)], tiers: [1, 2, 2] });

// Rally (head's S4): 3+ / 5+ cards of one squad in play this turn (Loadout counts) give that squad's bonus, once per turn each.
const RALLY = {
  assault: { 3: [DM(1), Pr(2), PI], 5: [DM(1), Pr(2)] },
  recon: { 3: [MK(1)], 5: [MK(1), DM(1), Pr(2)] }, // wb-pkg1: Recon hits harder (headshots); wb-odds2: Rally 3 lost its +1 damage (Mark is worth more now)
  support: { 3: [Pr(2), Sh(1), ST(1)], 5: [Pr(3), Sh(1), ST(2)] },
  engineer: { 3: [I(1), Pr(1)], 5: [D(1), BY(1)] }, // wb-odds2: +1 Precision and +1 Buy (Intel is worth less now that Field Promotion is free of Intel)
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
// wb-pkg1 trim: every gun's Hit Marker steps +1 (the package adds cards and Spoils; Health 60 alone left matches too short).
// wb-odds2: every step +2 Hit Markers and +2 damage over v7 (shots hit about 65% instead of 93%; the damage keeps the match pace).
// wb-rules retune for the Precision-spend rule: Recoil is now a Precision cost per shot, so multi-shot guns lost Recoil; the big single shots lost 1 damage.
const GUNCLASS = {
  // wb-first-shot: the Sidearm's rookie step (rounds 1–TUNE.rookieRounds): 1 Hit Marker hits for 1, whatever the cover or range
  pistol: { name: 'Sidearm', cls: 'Pistol', arch: 'engineer', damage: 4, range: 1, band: [0, 2], ladder: [[5, 4], [7, 5]], rookie: [1, 1], shots: 2, recoil: 2, cost: 1, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Gold Rush' },
  revolver: { name: 'Magnum', cls: 'Revolver', arch: 'engineer', damage: 5, range: 2, band: [0, 3], ladder: [[6, 6], [9, 9]], shots: 1, recoil: 3, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Judge' },
  knife: { name: 'Combat Knife', cls: 'Melee', arch: 'assault', damage: 5, range: 0, band: [0, 0], ladder: [[0, 5]], shots: 1, recoil: 0, melee: true, cost: 1, mods: ['hollow', 'none', 'hollow', 'none'], skin: 'Obsidian' },
  smg: { name: 'Viper', cls: 'SMG', arch: 'assault', damage: 4, range: 0, band: [0, 1], ladder: [[5, 4], [8, 6]], shots: 2, recoil: 0, cost: 2, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Gold Fang' },
  shotgun: { name: 'Breacher', cls: 'Shotgun', arch: 'engineer', damage: 5, range: 0, band: [0, 1], ladder: [[5, 5], [9, 8]], shots: 1, recoil: 3, cost: 2, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Dragon’s Breath' },
  burst: { name: 'Raider', cls: 'Burst Rifle', arch: 'assault', damage: 4, range: 1, band: [0, 2], ladder: [[5, 4], [9, 6]], shots: 2, recoil: 0, cost: 2, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Night Raid' },
  launcher: { name: 'Sapper', cls: 'Launcher', arch: 'engineer', damage: 5, range: 2, band: [0, 3], ladder: [[6, 6], [9, 9]], shots: 1, recoil: 3, cost: 3, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Demolition' },
  ar: { name: 'Sentinel', cls: 'Assault Rifle', arch: 'support', damage: 4, range: 2, band: [0, 3], ladder: [[6, 5], [8, 7]], shots: 2, recoil: 1, cost: 3, mods: ['hollow', 'reddot', 'comp', 'hollow'], skin: 'Crown Jewel' },
  lmg: { name: 'Bastion', cls: 'LMG', arch: 'support', damage: 5, range: 2, band: [0, 3], ladder: [[6, 5], [9, 7]], shots: 3, recoil: 0, cost: 3, mods: ['comp', 'hollow', 'reddot', 'hollow'], skin: 'Iron Monarch' },
  dmr: { name: 'Ranger', cls: 'Marksman Rifle', arch: 'recon', damage: 5, range: 3, band: [0, 4], ladder: [[6, 5], [10, 8]], shots: 2, recoil: 1, cost: 3, mods: ['reddot', 'hollow', 'comp', 'hollow'], skin: 'Golden Hour' },
  sniper: { name: 'Longbow', cls: 'Sniper', arch: 'recon', damage: 5, range: 4, band: [0, 5], ladder: [[6, 6], [11, 10]], shots: 1, recoil: 2, cost: 4, mods: ['hollow', 'reddot', 'extmag', 'hollow'], skin: 'Sun God' },
};
const WEAPONS = {};
for (const k in GUNCLASS) for (let r = 0; r < RARITY.length; r++) {
  const g = GUNCLASS[k]; const mods = g.mods.slice(0, r);
  const st = { damage: g.damage, max_range: g.range, magazine_capacity: g.shots, recoil: g.recoil, hit_need: g.ladder[0][0], reveal: 0 };
  for (const m of mods) for (const f in MODS[m].mod) st[f] = Math.max(f === 'hit_need' ? 1 : 0, st[f] + MODS[m].mod[f]);
  const id = `${k}-${r}`;
  WEAPONS[id] = { id, gunClass: k, name: r === 4 ? `${g.name} “${g.skin}”` : g.name, baseName: g.name, skin: r === 4 ? g.skin : null, archetype: g.arch, cls: g.cls, tier: r, rarity: RARITY[r].key, rarityName: RARITY[r].name,
    ladder: g.ladder.map(([h, dm]) => [g.melee ? 0 : Math.max(1, h + st.hit_need - g.ladder[0][0]), dm + st.damage - g.damage]), rookie: g.rookie ? [g.rookie[0], g.rookie[1] + st.damage - g.damage] : null, band: g.band.slice(), melee: !!g.melee,
    damage: st.damage, max_range: st.max_range, magazine_capacity: st.magazine_capacity, recoil: st.recoil, hit_need: st.hit_need, reveal: 0, intel_cost: 1 + r,
    mods: mods.filter(m => MODS[m].name).map(m => MODS[m].name), modText: mods.filter(m => MODS[m].name).map(m => `${MODS[m].name} (${MODS[m].text})`),
    tactical_main_effects: [], main_text: '', slot: 0, gcombo: null, tactical_boost_effects: [], boost_text: '', tags: [ARCH_TAG[g.arch]] };
}
const WEAPON_COPIES = {};
const ATTS = {};

// ---------- LOCATIONS (8 types, 7 dealt in a fixed row). Each has a squad: 2 in 3 refills of its stack are that squad's cards. ----------
const ENVS = {
  E01: { affinity: 'assault', id: 'E01', name: 'Open Road', cover: 0, bonus: { move: 1 }, bonusText: '+1 Movement', text: 'No cover. Here: +1 Movement.' },
  E02: { affinity: 'assault', id: 'E02', name: 'Small Shed', cover: 1, bonus: { cycle: 1 }, bonusText: '1 free cycle', text: 'Cover: +1 Hit Marker needed. Here: 1 free cycle.' },
  E03: { affinity: 'engineer', id: 'E03', name: 'House', cover: 1, bonus: { draw: 1 }, bonusText: 'Draw 1', text: 'Cover: +1 Hit Marker needed. Here: draw 1.' },
  E04: { affinity: 'engineer', id: 'E04', name: 'Supply Depot', cover: 0, bonus: { intel: 1 }, bonusText: '+1 Intel', text: 'No cover. Here: +1 Intel.' },
  E05: { affinity: 'support', id: 'E05', name: 'Concrete Barrier', cover: 1, bonus: { def: 1 }, bonusText: '+1 Armor', text: 'Cover: +1 Hit Marker needed. Here: +1 Armor.' },
  E06: { affinity: 'support', id: 'E06', name: 'Military Bunker', cover: 1, bonus: { shot: 1 }, bonusText: '+1 extra shot', text: 'Cover: +1 Hit Marker needed. Here: +1 extra shot.' },
  E07: { affinity: 'recon', id: 'E07', name: 'Recon Tower', cover: 1, bonus: { prec: 1 }, bonusText: '+1 Precision', text: 'Cover: +1 Hit Marker needed. Here: +1 Precision.' },
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
function log(s, msg, cls) { s.log.push({ r: s.round, msg, cls: cls || '' }); if (s.log.length > 500) s.log.shift(); if (s._rec) { const r = s._rec; s._rec = null; r.push({ msg, cls: cls || '', state: JSON.stringify(s) }); s._rec = r; } }
const cardDef = (s, iid) => CARDS[s.cards[iid].def];
const hmOf = (s, iid) => cardDef(s, iid).hit_markers;
const isStarter = (s, iid) => cardDef(s, iid).archetype === 'starter';
function itemDef(s, item) { return item.kind === 'card' ? CARDS[s.cards[item.iid].def] : item.kind === 'weapon' ? WEAPONS[s.weapons[item.iid].def] : ATTS[s.atts[item.iid].def]; }
function eff(s, wiid) {
  const W = s.weapons[wiid]; const d = WEAPONS[W.def];
  const e = { damage: d.damage, max_range: d.max_range, magazine_capacity: d.magazine_capacity, hit_need: d.hit_need, recoil: d.recoil, reveal: 0 };
  e.hit_need = d.melee ? 0 : Math.max(1, e.hit_need); e.ladder = ladderOf(s, W.def); e.band = TUNE.pointBlank ? [0, d.band[1]] : d.band;
  return e;
}
// wb-first-shot: a gun with a rookie step (the Sidearm) has an extra, easy first step in rounds 1..TUNE.rookieRounds
function ladderOf(s, wdef) { const d = WEAPONS[wdef]; return d.rookie && s.round <= TUNE.rookieRounds ? [d.rookie].concat(d.ladder) : d.ladder; }
const guns = pl => pl.guns.filter(Boolean);
const allCards = pl => pl.deck.concat(pl.discard, pl.hand, pl.play, pl.loadout || [], pl.drop || []);
const owned = pl => allCards(pl).length;
const isSquad = a => SQUADS.includes(a);
const phaseTier = s => s.round <= 3 ? 1 : s.round <= 7 ? 2 : 3;

function mkPlayer(idx, name) {
  return { idx, name, hp: TUNE.hp, pos: 0, res: { move: 0, prec: 0, intel: 0 }, def: 0, shot: 0,
    deck: [], discard: [], hand: [], play: [], loadout: [], fuelled: [], removed: [], guns: [null, null],
    bonusTaken: [], moved: false, movedToward: false, nextFire: { reqMod: 0, bonusPrec: 0 }, revealPlus: 0, dmgTurn: 0, ignoreCover: false,
    buys: 0, buyBonus: 0, scrapAvail: 0, freeCycles: 0, stationScrapped: false, squadN: {}, rallyDone: [], fp: 0, fpHist: [], perks: [], perkOffer: null,
    dmgHist: [], drop: [], ow: null, supp: null, suppNext: null, fortify: false, peek: null, lastPlayed: null, promoted: false, spoilsDone: false,
    chargeDmg: 0, onHitDraw: 0, expose: false, overwatch: false, anyStack: false, hurt: false,
    stats: { shots: 0, hits: 0, jams: 0, damageDealt: 0, cardsAcquired: 0, weaponAcq: 0, burned: 0, searches: 0, reactions: 0, hitsBy: {}, maxTurnDmg: 0, turnDmg: 0, squads: 0, rallies: 0, big: 0, buys: 0,
      spoils: 0, promoted: 0, healed: 0, owShots: 0, turretShots: 0, dmgRounds: {}, bestRound: 0, mvp: {}, added: [] } };
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
  const s = { v: '7.0', seed: (opts.seed ?? (Date.now() & 0x7fffffff)) | 0, round: 1, turnNo: 1, first: 0, turn: 0, over: false, winner: null, endBy: null,
    log: [], nid: 1, cards: {}, weapons: {}, atts: {}, envs: [], players: [], lastFire: null, finalN: 0, finalDmg: 0, gone: [], aiMode: ['aware', 'aware'],
    ops: (opts.ops || []).filter(k => OPS[k]), spoils: null };
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
  const [sA, sB] = hasOp(s, 'closedrop') ? [2, 4] : [TUNE.startA, TUNE.startB];
  const a = rng(s) < 0.5; s.players[0].pos = a ? sA : sB; s.players[1].pos = a ? sB : sA;
  s.first = rng(s) < 0.5 ? 0 : 1; s.turn = s.first;
  s.closeSide = rng(s) < 0.5 ? 'left' : 'right';
  for (const pl of s.players) pl.guns[0] = newWeapon(s, 'pistol-0');
  drawCards(s, s.first, TUNE.firstHand); drawCards(s, 1 - s.first, TUNE.hand);
  log(s, `Round 1. ${s.players[s.first].name} goes first.`, 'round');
  startTurn(s, s.turn);
  return s;
}
// Operations (O10 unlocks): match variants that change the drop for BOTH operators, never one side's power
const OPS = {
  closedrop: { name: 'Close Drop', text: 'Both operators start 2 locations apart (3rd and 5th).' },
  supplyrun: { name: 'Supply Run', text: 'A third supply crate lands after round 6.' },
  scorched: { name: 'Scorched Earth', text: 'Caught in the gas: +1 damage.' },
};
const hasOp = (s, k) => !!(s.ops && s.ops.includes(k));
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
    case 'gain': { let n = e.n; const sup = pl.supp && pl.supp[e.res] > 0 ? Math.min(n, pl.supp[e.res]) : 0; // Suppress eats the first Movement / Precision you gain
      if (sup) { pl.supp[e.res] -= sup; n -= sup; }
      if (e.res === 'def') pl.def += n; else if (e.res === 'shot') pl.shot += n; else pl.res[e.res] += n; ctx.out.push(`+${n} ${RES_LABEL[e.res]}${sup ? ` (${sup} suppressed)` : ''}`); fp = FPW[e.res] * n; break; }
    case 'charge': pl.chargeDmg += e.n; ctx.out.push(`Charge: hits at distance 0 +${e.n} damage`); fp = e.n; break;
    case 'onHit': pl.onHitDraw += e.n; ctx.out.push(`next hit draws ${e.n}`); fp = 1.5 * e.n; break;
    case 'sweep': { const k = Math.min(e.n, pl.deck.length); pl.peek = pl.deck.slice(pl.deck.length - k).reverse(); ctx.out.push(`Sweep: your top ${k} card${k === 1 ? '' : 's'}`); fp = 1; break; }
    case 'expose': pl.expose = true; ctx.out.push('Expose: shots ignore cover, hits ignore Armor and Reaction cards'); fp = 1; break;
    case 'overwatch': pl.overwatch = true; ctx.out.push('angle held at End'); fp = 2; break;
    case 'fortify': pl.fortify = true; ctx.out.push('Fortify: Armor holds through your next Ready'); fp = 1; break;
    case 'heal': { const h = Math.max(0, Math.min(e.n, TUNE.hp - pl.hp)); pl.hp += h; pl.stats.healed += h; ctx.out.push(`Heal ${h}`); fp = h; break; }
    case 'suppress': { const o = P(s, 1 - p); const q = o.suppNext || { move: 0, prec: 0 }; o.suppNext = { move: q.move + e.move, prec: q.prec + e.prec }; ctx.out.push(`Suppress: rival −${e.move} Movement, −${e.prec} Precision next turn`); fp = 2; break; }
    case 'repeat': { const d = ctx.prev && s.cards[ctx.prev] ? cardDef(s, ctx.prev) : null;
      if (!d || d.loadout || d.effects.some(x => x.op === 'repeat')) { ctx.out.push('nothing to repeat'); break; }
      const c2 = { out: [] }; runEffects(s, p, d.effects, c2); ctx.out.push(`repeats ${d.name} (${c2.out.join(', ')})`); break; }
    case 'turret': autoShot(s, p, { reveal: 1, steps: [[1, e.n]], label: 'Sentry Turret', kind: 'turret', range: TUNE.turretRange }); ctx.out.push('Sentry Turret fires'); fp = e.n; break;
    case 'anyStack': pl.anyStack = true; ctx.out.push('buy from any stack'); fp = 1; break;
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
function check(s, p) { if (s.over) return fail('The match is over.'); if (s.turn !== p) return fail("It isn't your turn."); if (s.spoils) return fail('Choose your Spoils first (or skip them).'); return null; }

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
  const ctx = { out: [], prev: pl.lastPlayed };
  if (def.loadout) {
    const full = pl.loadout.length >= TUNE.loadoutSlots;
    if (o.once || (full && o.slot == null)) { pl.play.push(iid); ctx.out.push('used once'); }
    else { if (full) { const old = pl.loadout.splice(o.slot, 1)[0]; pl.discard.push(old); ctx.out.push(`replaces ${cardDef(s, old).name}`); } pl.loadout.push(iid); ctx.out.push('deployed to the Loadout row'); }
    runEffects(s, p, def.loadout, ctx);
  } else { pl.play.push(iid); runEffects(s, p, def.effects, ctx); }
  pl.lastPlayed = iid;
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
// Hot Drop (O6): in rounds 1–3 a gained card is delivered into your next hand (on top of the 5 you draw); later it goes to the discard pile
function gainCard(s, p, iid) { const pl = P(s, p); if (s.round <= TUNE.hotDrop) (pl.drop = pl.drop || []).push(iid); else pl.discard.push(iid); pl.stats.cardsAcquired++; pl.stats.added.push(s.cards[iid].def); }
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
  const ws = pl.anyStack ? [pl.pos].concat(s.envs.map(e => e.w).filter(w => w !== pl.pos)) : [pl.pos, pl.pos - 1, pl.pos + 1]; // Contraband Run: any stack, no next-door cost
  for (const w of ws) { const e = envAt(s, w); if (!e || e.state !== 'safe') continue; const it = e.loot[0] && e.loot[0].iid === id ? e.loot[0] : null; if (it) return { it, env: e, adj: !pl.anyStack && w !== pl.pos, far: w !== pl.pos }; }
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
  if (item.kind === 'card') { gainCard(s, p, item.iid); if (s.round <= TUNE.hotDrop) extra += ' (Hot Drop: delivered to your next hand)'; }
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
  log(s, `${pl.name} buys ${CARDS[id].name} at the Buy Station${s.round <= TUNE.hotDrop ? ' (Hot Drop: next hand)' : ''}.`, 'act'); return { ok: true };
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
  log(s, `${pl.name} scraps a Sprint (Buy Station${TUNE.stationScrapCost ? `, −${TUNE.stationScrapCost} Intel` : ''}).`, 'fx'); return { ok: true };
}
// ---------- Spoils (O2), Field Promotion (O3), Sweep ----------
// 3 different loot cards from the current tier (topped up from the other tiers); they stay in the loot deck until one is taken
function spoilsOffer(s, p) {
  const t = phaseTier(s); const out = [];
  // the first card is from your main squad (the squad you have most cards of), if this tier still has one: looting rewards a focused squad
  const mf = p != null && TUNE.spoilsSquad ? mainSquad(s, p) : null;
  if (mf) { const pool = (s.loot[t] || []).filter(it => it.kind === 'card' && CARDS[s.cards[it.iid].def].archetype === mf).map(it => it.iid); while (out.length < TUNE.spoilsSquad && pool.length) out.push(pool.splice(Math.floor(rng(s) * pool.length), 1)[0]); }
  for (const k of [t, t + 1, t - 1, 3, 2, 1]) { const pool = (s.loot[k] || []).filter(it => it.kind === 'card' && !out.includes(it.iid)).map(it => it.iid);
    while (out.length < TUNE.spoils && pool.length) out.push(pool.splice(Math.floor(rng(s) * pool.length), 1)[0]); if (out.length >= TUNE.spoils) break; }
  return out;
}
// iid: one card of the offer (to your discard pile), or null to skip. Then the turn ends as usual.
function takeSpoils(s, p, iid) {
  const pl = P(s, p); if (s.over) return fail('The match is over.'); if (!s.spoils || s.spoils.p !== p) return fail('No Spoils to choose.');
  if (iid != null && !s.spoils.offer.includes(iid)) return fail('Choose one of the 3 Spoils cards.');
  s.spoils = null;
  if (iid != null) { const t = [1, 2, 3].find(k => s.loot[k].some(it => it.iid === iid)); s.loot[t].splice(s.loot[t].findIndex(it => it.iid === iid), 1);
    pl.discard.push(iid); pl.stats.cardsAcquired++; pl.stats.spoils++; pl.stats.added.push(s.cards[iid].def); log(s, `${pl.name} takes ${cardDef(s, iid).name} (Spoils).`, 'act'); }
  else log(s, `${pl.name} skips the Spoils.`, 'act');
  return endTurn(s, p);
}
const BASIC = { assault: 'K02', recon: 'K04', support: 'K05', engineer: 'K03' };
// Field Promotion: once per turn, 1 Intel: a starter in your hand, play area or discard pile is swapped for a Buy Station basic of the squad you choose
// (from the Buy Station's stock; not a buy). The starter leaves the game; the new card goes to your hand if the starter was there, else to your discard pile.
function promote(s, p, iid, squad) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (pl.promoted) return fail('Field Promotion is once per turn.');
  if (!SQUADS.includes(squad)) return fail('Choose a squad: Assault, Recon, Support or Engineer.');
  const id = BASIC[squad]; if (!(s.stationLeft[id] > 0)) return fail(`${CARDS[id].name} is sold out at the Buy Station.`);
  if (pl.res.intel < TUNE.promoteCost) return fail(`Field Promotion costs ${TUNE.promoteCost} Intel.`);
  const from = [pl.hand, pl.play, pl.discard].find(z => z.includes(iid)); if (!from) return fail('Choose a starter in your hand, play area or discard pile.');
  if (!isStarter(s, iid)) return fail('Only starter cards (Sprint, Scout, Steady Aim, Recon Run) can be promoted.');
  if (TUNE.promoteBuy && buysLeft(s, p) < 1) return fail(`Field Promotion uses one of your buys, and you have none left (${TUNE.buyCap}${pl.buyBonus ? ` + ${pl.buyBonus}` : ''} per turn).`);
  pl.res.intel -= TUNE.promoteCost; pl.promoted = true; s.stationLeft[id]--; if (TUNE.promoteBuy) pl.buys++;
  const old = cardDef(s, iid).name; from.splice(from.indexOf(iid), 1); pl.removed.push(iid);
  const n = newCard(s, id); (from === pl.hand ? pl.hand : pl.discard).push(n); pl.stats.promoted++; pl.stats.added.push(id);
  log(s, `${pl.name} promotes ${old} → ${CARDS[id].name} (${ARCH_TAG[squad]}${TUNE.promoteCost ? `, −${TUNE.promoteCost} Intel` : ''}).`, 'act');
  return { ok: true, iid: n };
}
// Sweep: order = the swept cards, new top first. Until you arrange them they stay as they were.
function arrange(s, p, order) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const pk = pl.peek; if (!pk || !pk.length) return fail('Nothing to arrange: play a Sweep card first.');
  const k = pk.length; const top = pl.deck.slice(pl.deck.length - k);
  if (top.length !== k || !top.every(i => pk.includes(i))) { pl.peek = null; return fail('Your deck has changed since the Sweep.'); }
  if (!Array.isArray(order) || order.length !== k || new Set(order).size !== k || !order.every(i => pk.includes(i))) return fail(`Put back all ${k} swept cards, each once.`);
  pl.deck.splice(pl.deck.length - k, k, ...order.slice().reverse()); pl.peek = null;
  log(s, `${pl.name} arranges the top ${k} card${k === 1 ? '' : 's'} of the deck.`, 'act'); return { ok: true };
}
function scrap(s, p, iid) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  if (!(pl.scrapAvail > 0)) return fail('No Scrap available. Play a card with Scrap first.');
  const from = [pl.hand, pl.play, pl.discard].find(z => z.includes(iid));
  if (!from) return fail('Scrap takes a card from your hand, play area or discard pile.');
  if (owned(pl) <= TUNE.minDeck) return fail(`Your deck is at the ${TUNE.minDeck}-card minimum.`);
  from.splice(from.indexOf(iid), 1); pl.removed.push(iid); pl.scrapAvail--; pl.stats.burned++;
  log(s, `${pl.name} scraps ${cardDef(s, iid).name}.`, 'fx'); return { ok: true };
}

// ---------- fire ----------
// Aim (head's S1 "Recoil decreases Precision"): you commit Precision to a shot; it reveals 1 card per Precision committed, up to TUNE.aimCap
// cards (wb-odds2). Each Precision committed beyond that is Power: +TUNE.aimPower damage on every step if the shot hits. The shot spends what
// you committed, and then the gun's Recoil costs that much more Precision (down to 0).
// To hit (wb-odds2), the Hit Markers each step needs = printed + Cover + Long range − Mark − Steady (never below 1):
//   Cover: +coverNeed per cover level of the rival's location (also at distance 0; Pierce and Expose ignore it);
//   Long range: +longNeed at distance longFrom or more (not the knife); Steady: −1 per Steady this turn (pl.revealPlus counts them).
function aimMods(s, p, o = {}) {
  const pl = P(s, p), t = P(s, 1 - p); const Dd = dist(s);
  const tEnv = envAt(s, t.pos); const lv = tEnv && tEnv.state === 'safe' ? ENVS[tEnv.def].cover : 0;
  const by = o.auto ? null : pl.expose ? 'Expose' : pl.ignoreCover ? 'Pierce' : null; // held-angle and turret shots: no Pierce / Expose
  const cover = by ? 0 : lv * TUNE.coverNeed; const long = !o.melee && Dd >= TUNE.longFrom ? TUNE.longNeed : 0;
  return { coverLv: lv, coverBy: lv && by ? by : null, cover, long, distance: Dd, cq: TUNE.closeQuarters && Dd === 0 };
}
function shotsLeft(s, p, gi) { const pl = P(s, p); const wid = pl.guns[gi]; if (!wid) return 0; return Math.max(0, eff(s, wid).magazine_capacity - s.weapons[wid].shots) + pl.shot; }
function shotPreview(s, p, gi, commit) {
  const pl = P(s, p), o = P(s, 1 - p); const wid = pl.guns[gi]; if (!wid) return null;
  const W = s.weapons[wid]; const E = eff(s, wid); const d = WEAPONS[W.def];
  const Dd = dist(s); const inBand = Dd >= E.band[0] && Dd <= E.band[1];
  const c = d.melee ? 0 : Math.max(0, Math.min(pl.res.prec, commit == null ? pl.res.prec : commit | 0));
  const free = 0; const reveal = Math.min(c, TUNE.aimCap); const power = c - reveal;
  const am = aimMods(s, p, { melee: d.melee }); const steady = d.melee ? 0 : pl.revealPlus;
  const shift = TUNE.needPlus - pl.nextFire.reqMod + am.cover + am.long - steady;
  const rk = !d.melee && E.ladder !== d.ladder; // the rookie step (wb-first-shot): its need is fixed, cover and range don't raise it
  const steps = E.ladder.map(([h, dm], i) => [d.melee ? 0 : rk && i === 0 ? h : Math.max(1, h + shift), dm + pl.dmgTurn + power * TUNE.aimPower + (Dd === 0 ? pl.chargeDmg || 0 : 0)]); const need = steps[0][0];
  return { gi, commit: c, free, prec: pl.res.prec, reveal, power, powerDmg: power * TUNE.aimPower, need, base: E.hit_need, printed: E.ladder[0][0], accuracy: pl.nextFire.reqMod, steady, coverNeed: am.cover, coverLv: am.coverLv, coverBy: am.coverBy, long: am.long,
    recoil: E.recoil, recoilDrop: E.recoil, cost: Math.min(pl.res.prec, c + E.recoil), cover: am.cover, cq: am.cq, damage: E.damage, dmg: steps[0][1],
    steps, rawSteps: steps, rookie: rk, band: E.band, range: E.max_range, rawDistance: Dd, distance: 0, inRange: inBand, left: shotsLeft(s, p, gi), melee: d.melee, pre: 0, bonusPrec: 0, suppression: 0, fall: 0 };
}
function shootCheck(s, p, gi, commit) {
  const pl = P(s, p); const wid = pl.guns[gi];
  if (!wid) return fail('No gun in that slot.');
  if (shotsLeft(s, p, gi) < 1) return fail(`${WEAPONS[s.weapons[wid].def].name} has fired its shots this turn.`);
  const E = eff(s, wid);
  if (dist(s) < E.band[0] || dist(s) > E.band[1]) return fail(`Out of range: the ${WEAPONS[s.weapons[wid].def].name} fires at distance ${E.band[0]}–${E.band[1]}; you are at ${dist(s)}.`);
  if (!WEAPONS[s.weapons[wid].def].melee && shotPreview(s, p, gi, commit).reveal < 1) return fail('No Precision: play Precision cards first.');
  return { ok: true };
}
// expose (Expose tactic): the target's Reaction cards and Armor don't work against this hit
function applyHit(s, ti, dmg, cq, expose) {
  const t = P(s, ti); const notes = [];
  // reaction cards in hand: the best one is used automatically
  const rx = expose ? null : t.hand.filter(i => cardDef(s, i).reaction).sort((a, b) => cardDef(s, b).reaction - cardDef(s, a).reaction)[0];
  if (rx && dmg > 1) { const r = Math.min(cardDef(s, rx).reaction, dmg - 1); dmg -= r; t.hand.splice(t.hand.indexOf(rx), 1); t.discard.push(rx); t.stats.reactions++; notes.push(`${cardDef(s, rx).name} reaction −${r}`); }
  if (expose) { if (t.def) notes.push('Exposed: Armor ignored'); }
  else if (!cq) { const ab = Math.min(t.def, dmg - 1); if (ab > 0) { t.def -= ab; dmg -= ab; notes.push(`Armor −${ab}`); } }
  else if (t.def) notes.push('close quarters: Armor ignored');
  t.hp -= dmg; t.hurt = true;
  // Adrenaline: one Adrenaline card in the target's discard pile comes back to their hand
  const ad = t.discard.find(i => cardDef(s, i).adrenaline); if (ad) { t.discard.splice(t.discard.indexOf(ad), 1); t.hand.push(ad); notes.push(`${cardDef(s, ad).name} returns to ${poss(t.name).toLowerCase() === 'your' ? 'your' : poss(t.name)} hand`); }
  return { dealt: dmg, notes };
}
// a shot that is not fired from your gun on your turn: Overwatch (rival's turn, your saved Precision) and Sentry Turret (your Ready).
// o: { reveal, steps: [[Hit Markers, damage], ...], label, kind: 'overwatch' | 'turret', range }
function autoShot(s, p, o) {
  const pl = P(s, p), t = P(s, 1 - p); const Dd = dist(s);
  if (s.over || Dd > o.range) return null;
  const revealed = [];
  for (let i = 0; i < Math.min(o.reveal, TUNE.aimCap); i++) { if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s, pl.discard); pl.discard = []; } revealed.push(pl.deck.pop()); }
  const total = revealed.reduce((a, i) => a + hmOf(s, i), 0);
  const am = aimMods(s, p, { auto: true }); const cq = am.cq; const shift = am.cover + am.long;
  o = Object.assign({}, o, { steps: o.steps.map(([h, dm], i) => [h > 0 && !(o.rookie && i === 0) ? h + shift : h, dm]) }); // the rookie step stays fixed // cover and long range raise the need here too
  const lvl = o.steps.filter(([h]) => total >= h).length - 1; const hit = lvl >= 0;
  let dealt = 0, notes = [];
  pl.stats.shots++; pl.stats[o.kind === 'turret' ? 'turretShots' : 'owShots']++;
  if (hit) { const r = applyHit(s, 1 - p, o.steps[lvl][1], cq); dealt = r.dealt; notes = r.notes;
    pl.stats.hits++; pl.stats.damageDealt += dealt; if (s.turn === p) pl.stats.turnDmg += dealt; pl.stats.dmgRounds[s.round] = (pl.stats.dmgRounds[s.round] || 0) + dealt; }
  pl.discard.push(...revealed);
  s.lastFire = { p, weapon: o.label, kind: o.kind, bullet: null, req: o.steps[0][0], steps: o.steps, level: lvl, revealed: revealed.map(i => ({ name: cardDef(s, i).name, hm: hmOf(s, i), jam: false })), total, jam: false, hit, dealt, notes, short: revealed.length < o.reveal, recoil: 0, commit: o.reveal, free: 0 };
  log(s, `${poss(pl.name)} ${o.label} fires: ${revealed.length} card${revealed.length === 1 ? '' : 's'}, needs ${o.steps[0][0]}, got ${total} → ${hit ? `HIT for ${dealt}${notes.length ? ` (${notes.join(', ')})` : ''}` : 'MISS'}.`, hit ? 'hit' : 'miss');
  checkDeath(s, 'ko');
  return s.lastFire;
}
function checkDeath(s, by) {
  const d0 = s.players[0].hp <= 0, d1 = s.players[1].hp <= 0;
  if (!d0 && !d1) return;
  s.over = true; s.endBy = by || 'ko'; const [a, b] = s.players;
  s.winner = d0 && d1 ? (a.hp !== b.hp ? (a.hp > b.hp ? 0 : 1) : 'draw') : d0 ? 1 : 0;
  log(s, s.winner === 'draw' ? 'Both operators fall. Draw.' : `${s.players[s.winner].name} is the last operator standing.`, 'win');
}
// o: a number (Precision to commit) or { commit }. Without one, the shot commits all your Precision.
function fire(s, p, gi, o) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  const commit = typeof o === 'number' ? o : o && typeof o === 'object' && o.commit != null ? o.commit : null;
  const sc = shootCheck(s, p, gi, commit); if (!sc.ok) return sc;
  const W = s.weapons[pl.guns[gi]]; const d = WEAPONS[W.def]; const sp = shotPreview(s, p, gi, commit);
  if (W.shots >= eff(s, pl.guns[gi]).magazine_capacity) pl.shot--; else W.shots++; W.shotTurn = s.turnNo;
  const revealed = [];
  for (let i = 0; i < sp.reveal; i++) { if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s, pl.discard); pl.discard = []; } revealed.push(pl.deck.pop()); }
  const total = revealed.reduce((a, i) => a + hmOf(s, i), 0);
  const hit = d.melee || total >= sp.need;
  const before = pl.res.prec; pl.res.prec = d.melee ? pl.res.prec : Math.max(0, pl.res.prec - sp.commit - sp.recoil);
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  pl.stats.shots++;
  let dealt = 0, notes = [], lvl = -1;
  if (hit) { pl.stats.hits++; pl.stats.hitsBy[W.def] = (pl.stats.hitsBy[W.def] || 0) + 1; lvl = d.melee ? 0 : sp.steps.filter(([h]) => total >= h).length - 1; if (lvl > 0) pl.stats.big++;
    // applyHit's notes may already say 'close quarters: Armor ignored': the bare 'close quarters' tag is added only if not
    const r = applyHit(s, 1 - p, sp.steps[lvl][1], sp.cq, pl.expose); if (lvl > 0) notes.push(lvl === 1 && d.gunClass === 'sniper' ? 'HEADSHOT' : `step ${lvl + 1}`); dealt = r.dealt; notes = notes.concat(r.notes);
    if (sp.powerDmg) notes.unshift(`Power +${sp.powerDmg}`); if (sp.cq && !notes.some(n => n.startsWith('close quarters'))) notes.unshift('close quarters'); pl.stats.damageDealt += dealt; pl.stats.turnDmg += dealt;
    pl.stats.dmgRounds[s.round] = (pl.stats.dmgRounds[s.round] || 0) + dealt;
    for (const i of revealed) { const h = hmOf(s, i); if (h) pl.stats.mvp[cardDef(s, i).id] = (pl.stats.mvp[cardDef(s, i).id] || 0) + h; }
    if (pl.onHitDraw > 0 && !s.over) { const n = drawCards(s, p, pl.onHitDraw); pl.onHitDraw = 0; notes.push(`Follow Through: draw ${n}`); } }
  pl.discard.push(...revealed);
  s.lastFire = { p, weapon: d.name, bullet: null, req: sp.need, steps: sp.steps, level: lvl, revealed: revealed.map(i => ({ name: cardDef(s, i).name, hm: hmOf(s, i), jam: false })), total, jam: false, hit, dealt, notes, short: revealed.length < sp.reveal, recoil: before - pl.res.prec, commit: sp.commit, free: sp.free };
  log(s, `${pl.name} fires ${d.name}: ${d.melee ? 'stabs' : `aims ${sp.commit}${sp.power ? ` (${sp.power} Power)` : ''}, ${revealed.length} card${revealed.length === 1 ? '' : 's'}, needs ${sp.need}, got ${total}`} → ${hit ? `HIT for ${dealt}${notes.length ? ` (${notes.join(', ')})` : ''}` : 'MISS'}.${before !== pl.res.prec ? ` Precision ${before}→${pl.res.prec}.` : ''}`, hit ? 'hit' : 'miss');
  checkDeath(s, 'ko');
  return { ok: true, result: s.lastFire };
}

// ---------- turn flow ----------
// Ready: reset, Loadout cards fire, then the location's bonus.
function startTurn(s, p) {
  const pl = P(s, p);
  const keepDef = pl.fortify ? Math.min(pl.def, TUNE.fortifyCap) : 0; // Fortify: your Armor holds through this Ready
  if (pl.fortify && keepDef) log(s, `${poss(pl.name)} Fortify holds ${keepDef} Armor.`, 'fx');
  Object.assign(pl, { res: { move: 0, prec: 0, intel: 0 }, def: keepDef, shot: 0, revealPlus: 0, dmgTurn: 0, ignoreCover: false, buys: 0, buyBonus: 0, scrapAvail: 0, freeCycles: 0,
    stationScrapped: false, squadN: {}, rallyDone: [], turnSquads: 0, moved: false, movedToward: false, bonusTaken: [], fp: 0,
    chargeDmg: 0, onHitDraw: 0, expose: false, overwatch: false, anyStack: false, fortify: false, peek: null, lastPlayed: null, promoted: false, spoilsDone: false, ow: null,
    supp: pl.suppNext || null, suppNext: null });
  if (pl.supp) log(s, `${pl.name} is suppressed: −${pl.supp.move} Movement, −${pl.supp.prec} Precision this turn.`, 'fx');
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  for (const wid of guns(pl)) { s.weapons[wid].shots = 0; s.weapons[wid].used = false; }
  pl.stats.turnDmg = 0;
  if (pl.loadout.length) { const ctx = { out: [] }; for (const i of pl.loadout) runEffects(s, p, cardDef(s, i).loadout, ctx); checkSquads(s, p, ctx); log(s, `${poss(pl.name)} Loadout (${pl.loadout.map(i => cardDef(s, i).name).join(', ')}): ${ctx.out.join(', ')}.`, 'play'); }
  const env = envAt(s, pl.pos); if (env) { const t = arriveBonus(s, p, env); if (t) log(s, `${pl.name} holds${t}`, 'fx'); }
}
function endTurn(s, p) {
  const pl = P(s, p); const e = check(s, p); if (e) return e;
  // Spoils (O2): after a turn in which you dealt damage (wb-odds2: or were hit since your last End turn), look at 3 loot cards and take 1
  // (or skip). takeSpoils() then ends the turn.
  const hurt = !pl.spoilsDone && pl.hurt; if (!pl.spoilsDone) pl.hurt = false;
  if (TUNE.spoils && !pl.spoilsDone && (pl.stats.turnDmg > 0 || (TUNE.spoilsHurt && hurt))) {
    pl.spoilsDone = true; const offer = spoilsOffer(s, p);
    if (offer.length) { s.spoils = { p, offer, round: s.round }; log(s, `${pl.name} ${pl.stats.turnDmg ? `dealt ${pl.stats.turnDmg} damage` : 'was hit since their last turn'}: Spoils! ${offer.map(i => CARDS[s.cards[i].def].name).join(', ')}.`, 'fx'); return { ok: true, spoils: offer }; }
  }
  // Overwatch: the rival ends this turn inside your saved shot's range, so it fires now
  const o = P(s, 1 - p);
  if (o.ow) { const ow = o.ow; o.ow = null; const E = eff(s, o.guns[0]); const W = WEAPONS[s.weapons[o.guns[0]].def];
    if (dist(s) >= E.band[0] && dist(s) <= E.band[1]) { autoShot(s, 1 - p, { reveal: W.melee ? 0 : ow.prec, steps: E.ladder.map(([h, dm]) => [W.melee ? 0 : h, dm]), rookie: E.ladder !== W.ladder, label: 'held angle', kind: 'overwatch', range: E.band[1] }); if (s.over) return { ok: true }; }
    else log(s, `${poss(o.name)} held angle stays quiet: ${pl.name} ends out of range.`, 'fx'); }
  if (pl.stats.turnDmg > pl.stats.maxTurnDmg) pl.stats.bestRound = s.round;
  pl.stats.maxTurnDmg = Math.max(pl.stats.maxTurnDmg, pl.stats.turnDmg);
  if (pl.overwatch && pl.res.prec > 0) { pl.ow = { prec: Math.min(TUNE.overwatchCap, pl.res.prec) }; log(s, `${pl.name} holds the angle with ${pl.ow.prec} Precision.`, 'fx'); }
  pl.fpHist.push(Math.round(pl.fp * 10) / 10); (pl.dmgHist = pl.dmgHist || []).push(pl.stats.turnDmg);
  pl.discard.push(...pl.hand, ...pl.play); pl.hand = []; pl.play = [];
  pl.scrapAvail = 0;
  if (TUNE.digIn && pl.res.move > 0) { const a = Math.min(TUNE.digIn, pl.res.move); pl.def += a; pl.stats.dugIn = (pl.stats.dugIn || 0) + a; log(s, `${pl.name} digs in: +${a} Armor (unused Movement).`, 'fx'); }
  pl.res = { move: 0, prec: 0, intel: 0 }; pl.shot = 0; // Armor stays up through the rival's turn
  drawCards(s, p, TUNE.hand + (TUNE.lowHp && pl.hp > 0 && pl.hp <= TUNE.lowHp ? 1 : 0));
  if (pl.drop && pl.drop.length) { log(s, `Hot Drop: ${pl.drop.map(i => cardDef(s, i).name).join(', ')} delivered to ${poss(pl.name).toLowerCase() === 'your' ? 'your' : poss(pl.name)} hand.`, 'fx'); pl.hand.push(...pl.drop); pl.drop = []; }
    log(s, `${pl.name} ends the turn: ${pl.stats.turnDmg} damage dealt.`, 'act');
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
    const depth = pl.pos < B.lo ? B.lo - pl.pos : pl.pos - B.hi; const dmg = TUNE.gasDmg + (hasOp(s, 'scorched') ? 1 : 0) + depth - 1;
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
  if (TUNE.crateRounds.includes(s.round - 1) || (hasOp(s, 'supplyrun') && s.round - 1 === 6)) {
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
function hitChance(s, p, n, req, trials = 300) {
  const pl = P(s, p); if (n <= 0) return 0; if (req <= 0) return 1;
  const dk = pl.deck.map(i => hmOf(s, i)), dc = pl.discard.map(i => hmOf(s, i));
  const r = lcg(12345); let ok = 0; const sh = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  for (let t = 0; t < trials; t++) { const seq = sh(dk.slice()).concat(sh(dc.slice())); let sum = 0; for (let i = 0; i < Math.min(n, seq.length); i++) sum += seq[i]; if (sum >= req) ok++; }
  return ok / trials;
}
// probability of reaching each ladder step when revealing 0..max cards (one Monte Carlo pass, prefix sums)
function stepOdds(s, p, steps, max, trials = 120) {
  const pl = P(s, p); const dk = pl.deck.map(i => hmOf(s, i)), dc = pl.discard.map(i => hmOf(s, i));
  const cnt = Array.from({ length: max + 1 }, () => steps.map(() => 0)); const r = lcg(777 + dk.length * 31 + max);
  const sh = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  for (let t = 0; t < trials; t++) { const a = sh(dk.slice()).concat(sh(dc.slice())); let sum = 0;
    for (let c = 1; c <= max; c++) { sum += c <= a.length ? a[c - 1] : 0; steps.forEach(([h], i) => { if (sum >= h) cnt[c][i]++; }); } }
  return cnt.map(x => x.map(v => v / trials));
}
function expDmg(s, p, sp) { if (sp.melee) return sp.steps[0][1]; const o = stepOdds(s, p, sp.steps, sp.reveal)[sp.reveal] || sp.steps.map(() => 0); let ev = 0; sp.steps.forEach(([, dm], i) => { ev += (o[i] - (o[i + 1] || 0)) * dm; }); return ev; }
// Best Precision to commit to the next shot: a small dynamic programme over the shots left this turn (expected damage, Armor ignored).
// V(q, l, first): best expected damage with q Precision and l shots still allowed. The model behind it:
// - every shot is optional: a shot that cannot add damage is simply not fired, so the plan never burns Precision on a dud shot
//   just to reach a later one (it used to: with spare shots it suggested a 0% commit-1 shot first);
// - Mark (nextFire.reqMod) helps only the next shot; Steady (−1 Hit Marker needed) and +damage last the whole turn;
// - a shot reveals at most TUNE.aimCap cards; Precision committed beyond that adds TUNE.aimPower damage per point (Power);
// - ties go to the larger commit: the surer shot now, and Precision left at End turn is worth nothing.
// The planner re-runs after every shot, so later shots are re-planned with the cards actually left.
function suggestCommit(s, p, gi) {
  const pl = P(s, p); const sp = shotPreview(s, p, gi, 0); if (!sp || sp.melee) return { commit: 0, ev: sp ? sp.steps[0][1] : 0, p: 1, total: sp ? sp.steps[0][1] * sp.left : 0 };
  const pool = pl.res.prec, rc = sp.recoil, cap = TUNE.aimCap; if (pool < 1) return { commit: 0, ev: 0, p: 0, total: 0 };
  const nS = sp.steps.length; const E = eff(s, pl.guns[gi]);
  const later = pl.nextFire.reqMod ? E.ladder.map(([h], i) => [sp.rookie && i === 0 ? h : Math.max(1, h + TUNE.needPlus + sp.coverNeed + sp.long - sp.steady), sp.steps[i][1]]) : sp.steps;
  const odds = stepOdds(s, p, sp.steps.concat(later), Math.min(pool, cap), 300); // one pass, same samples for both ladders
  const pw = c => Math.max(0, c - cap) * TUNE.aimPower;
  const evOf = (c, k) => { if (c <= 0) return 0; const o = odds[Math.min(c, cap)].slice(k * nS, k * nS + nS); const st = k ? later : sp.steps; let e = 0; st.forEach(([, dm], i) => { e += (o[i] - (o[i + 1] || 0)) * (dm + pw(c)); }); return e; };
  const EV = [0, 1].map(k => Array.from({ length: pool + 1 }, (_, c) => evOf(c, k))); const memo = {};
  const V = (q, l, first) => { if (l <= 0) return [0, -1]; const key = (q * 16 + l) * 2 + (first ? 1 : 0); if (memo[key]) return memo[key];
    let best = V(q, l - 1, first); // leave one shot unfired
    for (let c = q; c >= 1; c--) { const v = EV[first ? 0 : 1][c] + V(Math.max(0, q - c - rc), l - 1, false)[0]; if (v > best[0] + 1e-9) best = [v, c]; }
    return (memo[key] = best); };
  const [total, c] = V(pool, Math.min(sp.left, 6), true);
  if (c < 0) return { commit: 0, ev: 0, p: 0, total: 0 };
  return { commit: c, ev: EV[0][c], p: odds[Math.min(c, cap)][0], total };
}

// Threat (O7): the damage you can expect from the rest of this turn with the Precision you have now (the planner's plan, all shots left),
// and the first shot's odds. With { ifPlayAll: true } it is measured on a copy after playing every card in your hand.
function threat(s, p, o = {}) {
  let st = s; if (o.ifPlayAll && P(s, p).hand.length && s.turn === p && !s.spoils) { st = JSON.parse(JSON.stringify(Object.assign({}, s, { _rec: null, log: [] }))); playAll(st, p); }
  const pl = P(st, p); if (st.over || !pl.guns[0]) return { ev: 0, p: 0, inRange: false, shots: 0 };
  const sp = shotPreview(st, p, 0, null); const shots = shotsLeft(st, p, 0);
  if (!sp.inRange || shots < 1) return { ev: 0, p: 0, inRange: sp.inRange, shots, steps: sp.steps };
  const sg = suggestCommit(st, p, 0);
  return { ev: Math.round(sg.total * 10) / 10, p: Math.round(sg.p * 100) / 100, commit: sg.commit, inRange: true, shots, steps: sp.steps };
}
// wb-first-shot: what a gun would do with your deck. The chance that a full aim (TUNE.aimCap cards, drawn from all the cards you own,
// shuffled) reaches each step of its printed ladder: no cover, close range, no Mark or Steady. The loot sheet shows it for every gun,
// and below TUNE.fireWarn it warns "Your deck can't fire this yet". deckHM: your deck's Hit Markers (total, per card).
function deckHM(s, p) {
  const all = allCards(P(s, p)).map(i => hmOf(s, i)); const tot = all.reduce((a, b) => a + b, 0);
  return { total: tot, cards: all.length, avg: all.length ? tot / all.length : 0 };
}
function gunOdds(s, p, wdef) {
  const W = WEAPONS[wdef]; if (!W) return null; if (W.melee) return { steps: [1], first: 1, need: 0, warn: false, melee: true };
  const L = ladderOf(s, wdef); const hm = allCards(P(s, p)).map(i => hmOf(s, i)); const r = lcg(4242 + hm.length * 7); const n = 400; const hit = L.map(() => 0);
  for (let t = 0; t < n; t++) { const a = hm.slice(); let sum = 0; for (let k = 0; k < Math.min(TUNE.aimCap, a.length); k++) { const j = k + Math.floor(r() * (a.length - k)); [a[k], a[j]] = [a[j], a[k]]; sum += a[k]; } L.forEach(([h], i) => { if (sum >= h) hit[i]++; }); }
  const steps = hit.map(x => x / n); return { steps, ladder: L, first: steps[0], need: L[0][0], warn: steps[0] < TUNE.fireWarn, melee: false };
}
// Deck bar (O7): starters vs cards you added, by squad
function deckMix(s, p) {
  const pl = P(s, p); const all = allCards(pl); const by = { assault: 0, recon: 0, support: 0, engineer: 0 }; let starters = 0;
  for (const i of all) { const a = cardDef(s, i).archetype; if (a === 'starter') starters++; else if (a in by) by[a]++; }
  return { total: all.length, starters, yours: all.length - starters, by };
}

// ---------- Operator rank (O10): a light meta saved on this device. Pure functions; the UI passes its storage in. ----------
// Unlocks add variety, never power: the Daily Drop, Operations (match variants for both operators) and insignia.
const RANKS = [
  { name: 'Recruit', xp: 0 },
  { name: 'Private', xp: 150, unlock: { kind: 'daily', name: 'Daily Drop', text: 'One match a day, the same for everyone.' } },
  { name: 'Corporal', xp: 350, unlock: { kind: 'op', id: 'closedrop' } },
  { name: 'Sergeant', xp: 650, unlock: { kind: 'op', id: 'supplyrun' } },
  { name: 'Staff Sergeant', xp: 1000, unlock: { kind: 'op', id: 'scorched' } },
  { name: 'Lieutenant', xp: 1500, unlock: { kind: 'badge', name: 'Silver insignia', text: 'Silver insignia on your start screen and report.' } },
  { name: 'Captain', xp: 2200, unlock: { kind: 'badge', name: 'Gold insignia', text: 'Gold insignia on your start screen and report.' } },
];
for (const r of RANKS) if (r.unlock && r.unlock.kind === 'op') Object.assign(r.unlock, { name: OPS[r.unlock.id].name, text: OPS[r.unlock.id].text });
const PROFILE_KEY = 'wb-operator-v1';
const blankProfile = () => ({ v: 1, xp: 0, matches: 0, wins: 0, bestDmg: 0, bestTurn: 0, daily: null });
function rankOf(xp) {
  let i = 0; while (i + 1 < RANKS.length && xp >= RANKS[i + 1].xp) i++;
  const next = RANKS[i + 1] || null;
  return { i, name: RANKS[i].name, xp, next: next ? next.name : null, nextXp: next ? next.xp : null, toNext: next ? next.xp - xp : 0, floor: RANKS[i].xp, unlocks: RANKS.slice(1, i + 1).map(r => r.unlock) };
}
const unlockedOps = prof => rankOf((prof && prof.xp) || 0).unlocks.filter(u => u.kind === 'op').map(u => u.id);
// XP for one finished match, from player p's side
function xpFor(s, p) {
  const pl = P(s, p); const parts = [['Match played', 40]];
  if (s.winner === p) parts.push(['Win', 60]); else if (s.winner === 'draw') parts.push(['Draw', 30]);
  const d = Math.min(80, pl.stats.damageDealt); if (d) parts.push([`Damage dealt (${pl.stats.damageDealt})`, d]);
  if (s.finalReached) parts.push(['Reached the final circle', 20]);
  return { total: parts.reduce((a, x) => a + x[1], 0), parts };
}
// returns { profile (a new object; the old one is not changed), gained, before, after, newUnlocks }
function applyMatch(prof, s, p, o = {}) {
  const base = Object.assign(blankProfile(), prof || {}); const g = xpFor(s, p); const before = rankOf(base.xp);
  const pl = P(s, p); const next = Object.assign({}, base, { xp: base.xp + g.total, matches: base.matches + 1, wins: base.wins + (s.winner === p ? 1 : 0),
    bestDmg: Math.max(base.bestDmg, pl.stats.damageDealt), bestTurn: Math.max(base.bestTurn, pl.stats.maxTurnDmg) });
  if (o.daily) next.daily = { date: o.daily, dmg: pl.stats.damageDealt, won: s.winner === p };
  const after = rankOf(next.xp);
  return { profile: next, gained: g, before, after, newUnlocks: after.unlocks.slice(before.unlocks.length) };
}
// storage: anything with getItem/setItem (window.localStorage). Every failure (no storage, blocked, full, bad JSON) falls back quietly.
function loadProfile(storage) {
  try { const raw = storage && storage.getItem(PROFILE_KEY); const b = blankProfile(); if (!raw) return b; const o = JSON.parse(raw);
    if (!o || typeof o !== 'object') return b;
    for (const k of ['xp', 'matches', 'wins', 'bestDmg', 'bestTurn']) b[k] = Number.isFinite(o[k]) && o[k] >= 0 ? Math.floor(o[k]) : 0;
    if (o.daily && typeof o.daily.date === 'string') b.daily = { date: o.daily.date, dmg: +o.daily.dmg || 0, won: !!o.daily.won };
    return b; } catch (e) { return blankProfile(); }
}
function saveProfile(storage, prof) { try { if (!storage) return false; storage.setItem(PROFILE_KEY, JSON.stringify(prof)); return true; } catch (e) { return false; } }
// the Daily Drop's seed for a date string ('2026-11-11'): the same for every player
function dailySeed(date) { let h = 2166136261; for (const ch of String(date)) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); } return (h >>> 0) & 0x7fffffff; }

// ---------- AI ----------
// wb-odds2: with 3 cards a shot, Hit Markers and need cuts (Mark, Steady, Pierce) decide the odds, so the AI values them more
const HMW = 2;
const W8 = { move: 0.7, prec: 1, intel: 1, def: 0.6, shot: 2, draw: 1.8, mark: 2.5, pierce: 1.2, scrap: 1, cycleFree: 0.3, dmgTurn: 2.5, steady: 3, buy: 1.5,
  // Squad Tactics: what each new verb is worth to the AI on an average turn (tuned with qa/tools/ai_sim_pkg.js)
  charge: 0.6, onHit: 0.9, sweep: 0.35, expose: 1.2, overwatch: 2.2, fortify: 1.2, heal: 0.8, suppress: 2.5, repeat: 2.6, turret: 1.1, anyStack: 1.4 };
const val = effs => (effs || []).reduce((t, e) => t + (e.op === 'gain' ? W8[e.res] : W8[e.op] || 0) * (e.n || 1), 0);
const aiAware = (s, p) => !(s.aiMode && (s.aiMode[p] === 'blind' || /^naive/.test(s.aiMode[p] || '')));
const poss = name => name === 'You' ? 'Your' : `${name}’s`;
function cardScore(s, p, d) {
  const pl = P(s, p); const aware = aiAware(s, p);
  let v = val(d.effects) + d.hit_markers * HMW;
  if (d.loadout) v = val(d.loadout) * Math.min(4, Math.max(1, TUNE.hardEnd - s.round) / 2) + d.hit_markers * 0.3;
  if (d.reaction) v += 1;
  if (d.adrenaline) v += 1.2;
  if (d.effects.some(e => e.op === 'charge') && pl.guns[0] && eff(s, pl.guns[0]).band[1] <= 2) v += 1; // Charge suits short guns
  if (d.effects.some(e => e.op === 'heal')) v += pl.hp < TUNE.hp * 0.6 ? 1 : pl.hp > TUNE.hp - 3 ? -1.5 : 0;
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
  return id === best ? val(d.effects) + d.hit_markers * HMW : 0;
}
const MIN_SCORE = 3.0;
const aiRandom = (s, p) => !!(s.aiMode && s.aiMode[p] === 'random'); // sim only: buys, Spoils and promotions at random
function aiBuy(s, p) {
  const pl = P(s, p);
  if (aiRandom(s, p)) { // the "random buyer" control: any affordable top card or Buy Station card
    for (let guard = 0; guard < 6 && buysLeft(s, p) > 0; guard++) {
      const opts = [];
      for (const e of s.envs) { if (e.state !== 'safe' || !e.loot.length || !lootNear(s, p, e.loot[0].iid)) continue; if (lootCost(s, p, e.loot[0]) <= pl.res.intel) opts.push(() => buy(s, p, [e.loot[0].iid])); }
      for (const id of TUNE.station) if (s.stationLeft[id] > 0 && TUNE.supplyCost <= pl.res.intel) opts.push(() => buySupply(s, p, id));
      if (!opts.length || !opts[Math.floor(rng(s) * opts.length)]().ok) return;
    }
    return;
  }
  for (let guard = 0; guard < 6 && buysLeft(s, p) > 0; guard++) {
    const opts = [];
    for (const w of pl.anyStack ? s.envs.map(e => e.w) : [pl.pos - 1, pl.pos, pl.pos + 1]) { const e = envAt(s, w); if (!e || e.state !== 'safe' || !e.loot.length) continue; const it = e.loot[0]; opts.push({ it, cost: lootCost(s, p, it), sc: aiItemScore(s, p, it) }); }
    for (const id of TUNE.station) if (s.stationLeft[id] > 0) opts.push({ station: id, cost: TUNE.supplyCost, sc: stationScore(s, p, id) });
    const ok = opts.filter(o => o.cost <= pl.res.intel && o.sc >= (o.it && o.it.kind === 'weapon' ? 0 : MIN_SCORE)).sort((a, b) => (b.sc - 0.35 * b.cost) - (a.sc - 0.35 * a.cost));
    const o = ok[0]; if (!o) break;
    const r = o.station ? buySupply(s, p, o.station) : buy(s, p, [o.it.iid]); if (!r.ok) break;
  }
}
function aiCycle(s, p) {
  const pl = P(s, p); const env = envAt(s, pl.pos); if (aiRandom(s, p)) return;
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
  while (pl.scrapAvail > 0 && owned(pl) > TUNE.minDeck) {
    const intelSrc = allCards(pl).filter(i => cardDef(s, i).id !== 'T002').reduce((t, i) => t + cardDef(s, i).effects.concat(cardDef(s, i).loadout || []).reduce((a, e) => a + (e.op === 'gain' && e.res === 'intel' ? e.n : 0), 0), 0);
    const pool = pl.discard.concat(pl.play).filter(i => { const id = cardDef(s, i).id; return id === 'T001' || (id === 'T002' && intelSrc >= 6) || (id === 'T005' && s.round >= 5 && intelSrc >= 6); });
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
  if (o.ow && dd >= oE.band[0] && dd <= oE.band[1]) sc -= 2.5; // the rival holds the angle: don't end the turn in their range
  if (pl.chargeDmg > 0 && dd === 0) sc += 2;
  return sc;
}
function aiMove(s, p) {
  const pl = P(s, p); const here = aiScoreLoc(s, p, pl.pos);
  const opts = reachable(s, p).filter(r => inSafe(s, r.w)).map(r => ({ w: r.w, sc: aiScoreLoc(s, p, r.w) - 0.3 * r.cost })).sort((a, b) => b.sc - a.sc);
  if (opts.length && opts[0].sc > here + 0.5) move(s, p, opts[0].w);
}
function aiPlay(s, p) {
  const pl = P(s, p);
  // order: weakest first, the strongest plain card last so a Jury-Rig (played after it) repeats it; cards drawn on the way are played too
  const rank = i => { const d = cardDef(s, i); return d.effects.some(e => e.op === 'repeat') ? 1e3 : d.loadout ? -1e3 : val(d.effects); };
  for (let guard = 0; guard < 30 && pl.hand.length && !s.over; guard++) {
    const iid = pl.hand.slice().sort((a, b) => rank(a) - rank(b))[0];
    const d = cardDef(s, iid);
    if (d.loadout && pl.loadout.length >= TUNE.loadoutSlots) { // replace the weakest slot if the new card is better, else use it once
      const mf = mainSquad(s, p); const sc = i => val(cardDef(s, i).loadout) + (aiAware(s, p) && cardDef(s, i).archetype === mf ? 1 : 0);
      const worst = pl.loadout.map((i, k) => [sc(i), k]).sort((a, b) => a[0] - b[0])[0];
      playCard(s, p, iid, sc(iid) > worst[0] ? { slot: worst[1] } : { once: true });
    } else playCard(s, p, iid);
    if (pl.peek) aiArrange(s, p);
  }
}
// Sweep: the most Hit Markers on top, for this turn's shots
function aiArrange(s, p) { const pl = P(s, p); const order = pl.peek.slice().sort((a, b) => hmOf(s, b) - hmOf(s, a)); return arrange(s, p, order); }
function aiSpoils(s, p) {
  const offer = s.spoils.offer; if (aiRandom(s, p)) return offer[Math.floor(rng(s) * offer.length)];
  const mf = aiAware(s, p) ? mainSquad(s, p) : null; // the aware AI leans into its main squad (more Squad lines and Rallies)
  const sc = offer.map(iid => { const d = CARDS[s.cards[iid].def]; return { iid, v: cardScore(s, p, d) + (mf && d.archetype === mf ? TUNE.aiSpoilsFocus : 0) }; }).sort((a, b) => b.v - a.v);
  return sc[0].v >= MIN_SCORE - 1 ? sc[0].iid : null;
}
// Field Promotion with the Intel left after buying: Sprint first, Scout only when the deck has other Intel
function aiPromote(s, p) {
  const pl = P(s, p); if (pl.promoted || pl.res.intel < TUNE.promoteCost) return;
  let sq;
  if (aiRandom(s, p)) sq = SQUADS[Math.floor(rng(s) * SQUADS.length)];
  else if (aiAware(s, p)) { const force = s.aiMode && /^force:/.test(s.aiMode[p] || '') ? s.aiMode[p].slice(6) : null;
    // the basic that fits this deck best (its Squad line with the cards you have), not just your biggest squad
    sq = force || SQUADS.filter(q => s.stationLeft[BASIC[q]] > 0).sort((a, b) => cardScore(s, p, CARDS[BASIC[b]]) - cardScore(s, p, CARDS[BASIC[a]]))[0]; if (!sq) return; }
  else { const id = TUNE.station.filter(k => s.stationLeft[k] > 0).sort((a, b) => stationScore(s, p, b) - stationScore(s, p, a))[0]; sq = id && CARDS[id].archetype; }
  if (!sq || !(s.stationLeft[BASIC[sq]] > 0)) return;
  const intelSrc = allCards(pl).filter(i => cardDef(s, i).id !== 'T002').reduce((t, i) => t + cardDef(s, i).effects.concat(cardDef(s, i).loadout || []).reduce((a, e) => a + (e.op === 'gain' && e.res === 'intel' ? e.n : 0), 0), 0);
  const order = ['T001', 'T005'].concat(intelSrc >= 6 ? ['T002'] : [], s.round >= 6 ? ['T004'] : []);
  const pool = pl.discard.concat(pl.play);
  for (const id of order) { const iid = pool.find(i => cardDef(s, i).id === id); if (iid) { promote(s, p, iid, sq); return; } }
}
function aiFireLoop(s, p) {
  const pl = P(s, p);
  for (let g = 0; g < 12 && !s.over; g++) {
    if (!shootCheck(s, p, 0, pl.res.prec).ok) break;
    const sg = suggestCommit(s, p, 0); if (sg.ev < (pl.overwatch ? 0.8 : 0.3)) break; // with Overwatch armed, weak shots keep their Precision for the rival's turn
    if (!fire(s, p, 0, sg.commit).ok) break;
    if (pl.hand.length && !s.over) aiPlay(s, p); // Follow Through drew cards: play them, then keep shooting
  }
}
// ---------- the "new player" bot (wb-first-shot; sim only, aiMode 'naive') ----------
// A plausible first-match policy, not a good one: play every card, walk toward the rival until in range (and out of closing gas),
// buy the biggest gun it can afford, then the priciest cards, take the first Spoils card, never promote, scrap or cycle,
// and fire whenever FIRE shows more than 0% (the commit FIRE uses: the planner's, or all Precision).
const aiNaive = (s, p) => !!(s.aiMode && /^naive/.test(s.aiMode[p] || ''));
const aiHeeds = (s, p) => s.aiMode[p] === 'naive+warn'; // the same new player, but it skips guns the loot sheet warns about
function naiveTurn(s, p) {
  const pl = P(s, p); const o = P(s, 1 - p);
  for (let g = 0; g < 30 && pl.hand.length && !s.over; g++) { playCard(s, p, pl.hand[0], { once: pl.loadout.length >= TUNE.loadoutSlots }); if (pl.peek) arrange(s, p, pl.peek.slice()); }
  // move: away from closing gas first, else toward the rival until in range
  const E = () => eff(s, pl.guns[0]); const inR = w => { const d = Math.abs(w - o.pos); return d >= E().band[0] && d <= E().band[1]; };
  const bad = w => !inSafe(s, w) || closing(s).includes(w);
  const opts = reachable(s, p).filter(r => !bad(r.w));
  let tgt = null;
  if (bad(pl.pos)) tgt = opts.sort((a, b) => (inR(b.w) - inR(a.w)) || a.cost - b.cost)[0];
  else if (!inR(pl.pos)) tgt = opts.filter(r => inR(r.w)).sort((a, b) => a.cost - b.cost)[0] || opts.filter(r => Math.abs(r.w - o.pos) < Math.abs(pl.pos - o.pos)).sort((a, b) => Math.abs(a.w - o.pos) - Math.abs(b.w - o.pos))[0];
  if (tgt) move(s, p, tgt.w);
  // buy: the biggest gun it can afford (higher price than the one it holds), then the priciest cards
  for (let g = 0; g < 6 && buysLeft(s, p) > 0; g++) {
    const items = [pl.pos - 1, pl.pos, pl.pos + 1].map(w => envAt(s, w)).filter(e => e && e.state === 'safe' && e.loot.length).map(e => e.loot[0]).filter(it => lootCost(s, p, it) <= pl.res.intel);
    const cur = WEAPONS[s.weapons[pl.guns[0]].def];
    const gun = items.filter(it => it.kind === 'weapon' && WEAPONS[s.weapons[it.iid].def].intel_cost >= cur.intel_cost && s.weapons[it.iid].def !== cur.id && !(aiHeeds(s, p) && gunOdds(s, p, s.weapons[it.iid].def).warn))
      .sort((a, b) => WEAPONS[s.weapons[b.iid].def].intel_cost - WEAPONS[s.weapons[a.iid].def].intel_cost || WEAPONS[s.weapons[b.iid].def].ladder[0][1] - WEAPONS[s.weapons[a.iid].def].ladder[0][1])[0];
    if (gun) { if (!buy(s, p, [gun.iid]).ok) break; continue; }
    const card = items.filter(it => it.kind === 'card').sort((a, b) => itemDef(s, b).intel_cost - itemDef(s, a).intel_cost)[0];
    if (card && itemDef(s, card).intel_cost >= TUNE.supplyCost) { if (!buy(s, p, [card.iid]).ok) break; continue; }
    const st = TUNE.station.find(id => s.stationLeft[id] > 0);
    if (st && pl.res.intel >= TUNE.supplyCost) { if (!buySupply(s, p, st).ok) break; continue; }
    if (card) { if (!buy(s, p, [card.iid]).ok) break; continue; }
    break;
  }
  // fire whenever FIRE shows more than 0%. pl.stats.fireOpp[round] = [turns FIRE was live, sum of the odds it showed, turns with a hit]
  const h0 = pl.stats.hits;
  for (let g = 0; g < 12 && !s.over; g++) {
    if (!shootCheck(s, p, 0, pl.res.prec).ok) break;
    const d = WEAPONS[s.weapons[pl.guns[0]].def];
    const c = d.melee ? 0 : (suggestCommit(s, p, 0).commit || pl.res.prec); const sp = shotPreview(s, p, 0, c);
    const odds = d.melee ? 1 : sp.reveal >= 1 ? hitChance(s, p, sp.reveal, sp.need, 300) : 0;
    if (g === 0) { const f = (pl.stats.fireOpp = pl.stats.fireOpp || {})[s.round] = pl.stats.fireOpp[s.round] || [0, 0, 0]; f[0]++; f[1] += odds; }
    if (!(odds > 0)) break;
    if (!fire(s, p, 0, c).ok) break;
    if (pl.hand.length && !s.over) for (let k = 0; k < 10 && pl.hand.length; k++) playCard(s, p, pl.hand[0], { once: pl.loadout.length >= TUNE.loadoutSlots });
  }
  if (pl.stats.hits > h0 && pl.stats.fireOpp && pl.stats.fireOpp[s.round]) pl.stats.fireOpp[s.round][2]++;
  if (s.over) return { ok: true };
  const r = endTurn(s, p);
  if (r.ok && s.spoils && s.spoils.p === p) return takeSpoils(s, p, s.spoils.offer[0]);
  return r;
}
function aiTurn(s, p) {
  if (s.over || s.turn !== p) return fail('not AI turn');
  if (aiNaive(s, p)) return naiveTurn(s, p);
  aiPlay(s, p);
  aiMove(s, p);
  aiBuy(s, p); aiCycle(s, p);
  aiFireLoop(s, p);
  if (!s.over) { aiScrap(s, p); aiBuy(s, p); aiPromote(s, p); }
  if (s.over) return { ok: true };
  const r = endTurn(s, p);
  if (r.ok && s.spoils && s.spoils.p === p) return takeSpoils(s, p, aiSpoils(s, p));
  return r;
}

// ---------- removed systems (kept as stubs so older callers fail politely) ----------
const LOADOUT = {}; const PERKS = {};
const no = () => fail('Not in these rules.');
const API = { RES, RES_LABEL, TIER_NAME, RARITY, MODS, GUNCLASS, CARDS, WEAPONS, ATTS, ENVS, WEAPON_COPIES, TUNE, ARCH_TAG, SQUADS, RALLY, RALLY_TEXT, FPW,
  newGame, playCard, playAll, gunOdds, deckHM, move, buy, fire, endTurn, aiTurn, takeSpoils, spoilsOffer, promote, arrange, autoShot, threat, deckMix, BASIC, OPS, hasOp,
  RANKS, PROFILE_KEY, blankProfile, rankOf, unlockedOps, xpFor, applyMatch, loadProfile, saveProfile, dailySeed, aiSpoils, aiPromote, aiArrange, cardScore, aiPlay, aiMove, aiBuy, aiCycle, aiFireLoop, aiScrap, suggestCommit, stepOdds, stationScrap, squadCounts, mainSquad, buysLeft, closeSchedule, effText, playText,
  reachable, closing, GUNSET, LOCSET, locTier, locSize, SQUAD_TEXT, rolesPlayed, NEIGHBOURS, cycle, LOADOUT, plateCost, nextPhase, buySupply, scrap, lootNear, PERKS, archCounts, gasRate, moveCost,
  shotPreview, shootCheck, shotsLeft, hitChance, expDmg, lootCost, buyTotal, eff, envAt, dist, itemDef, cardDef, nextEdge, safeBounds, inSafe, isStarter, guns, owned, aiItemScore,
  activateGun: no, eligibleFuel: () => [], boostOk: () => 'Not in these rules.', search: no, searchable: () => null, burnAtBench: no, canBench: () => false, punch: no, pickPerk: no, perksOf: () => [], hasPerk: () => false, stackPlan: () => [], flip: () => false, ammoLeft: () => 0 };
if (typeof module !== 'undefined' && module.exports) module.exports = API; else root.WD = API;
})(typeof window !== 'undefined' ? window : globalThis);
