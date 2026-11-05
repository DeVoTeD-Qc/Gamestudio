// Warbuilder "Engine & Synergy" rules prototype + AI-vs-AI simulator (studio QA tool, board task wb-syn, 2026-11-05).
// Spec: projects/warbuilder/documentation/design/engine-synergy-spec.md
//
// A standalone, seeded model of the PROPOSED rules (Squad / Loadout / Steady / Mark / Pierce / Scrap / Reaction, Hot Drop, a fixed 7-location
// map that closes from both ends, escalating final circle, hard end, close quarters, +1 on every ladder step). It only READS the shipped
// engine for gun, location and gun-set data; it never changes the game source, and ai_sim.js is untouched.
//
//   node projects/warbuilder/qa/tools/ai_sim_syn.js [games=2000] [options]
//     --match=aware-blind | aware-aware | blind-blind      who plays (default aware-blind; seats alternate every game)
//     --flat                                                 switch Squad off (the "no synergy" control)
//     --spec                                                 also switch on Specialist ranks (optional rule, see spec)
//     --set=force:A                                          make the aware AI play one family only (A, R, S or E)
//     --set=key:value,key:value                              override any CFG value, e.g. --set=hp:28,needPlus:1
//     --curve                                                print the per-round curves as a table as well as JSON
'use strict';
const path = require('path');
const WD = require(path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));

// ---------------- configuration (every number the spec names) ----------------
const CFG = {
  // ---- proposed rules (spec defaults) ----
  hp: 40, hand: 5, lowHp: 10, lowHpDraw: 1,
  buyCap: 2,                 // buys per turn (loot stacks + Buy Station together); Engineer "+1 Buy" raises it
  loadoutSlots: 2,           // Loadout row size
  needPlus: 1,               // +1 Hit Marker on every ladder step (M2)
  closeQuarters: true,       // distance 0: ignore cover and Armor (M3)
  pointBlank: true,          // every gun may fire at distance 0 (long guns no longer locked out of the final circle)
  gunTweaks: true,           // SMG first step -1 Hit Marker and Recoil -1, Knife 2 stabs, Breacher first step -1 and +1 damage
  digIn: 2,                  // unused Movement -> Armor, max 2
  gasDmg: 3,                 // caught outside: 3 (+1 per extra space), pushed back in
  closeAfter: { 2: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1 }, // end of these rounds one edge location closes: 7 -> 1 safe after round 8
  finalStorm: [2, 3, 4, 5],  // end of rounds 8, 9, 10, 11 (1 safe location): storm hits both (escalates)
  hardEnd: 11,               // end of round 11: most Health wins
  stationCost: 2, stationCopies: 6, stationScrap: 1, // Buy Station: family basics for 2 Intel; Scrap a Sprint for 1 Intel
  stackSize: 3, affinityShare: 2 / 3,                // location stacks: 3 deep, 2 in 3 refills match the location's family
  squad: true, squadCap: 3, squadAllEach: true, gunSquad: false, // Squad: its line once per OTHER card of the family in play or in the Loadout row
  streak: false, loadout: true, specialist: false, specRanks: [4, 7], // Streak (2nd+ hits hit harder): tested and cut, 2.4% of damage
  minDeck: 7, hotDrop: 3,             // Hot Drop: in rounds 1-3, cards you gain go on top of your deck
  // ---- tested alternatives (off by default; see spec §8-9) ----
  aim: 'recoil', aiCommitP: 0.65,            // 'commit': Precision is spent per shot instead of Recoil
  dodge: false, dodgeCQ: false, dodgeArmor: false, // target flips 1 (or 1 + Armor) card(s); their Hit Markers raise the need
  evasion: false, coverNeed: false, revealCap: 99, supplyRow: false, rowExtra: 0, squadMult: 1, sched: null,
  // ---- AI ----
  famBias: 0, force: null, aiSpendEV: 0.3, steadyFree: false, rally: false, gunSet: 'spec', cardEdits: null, aiFireP: 0.40, aiFireEV: 1.6, mcTrials: 80,
};

// gun tweaks proposed by the spec (applied to this process's in-memory copy of the engine's gun table only)
let GUN_TWEAKS = { smg: { need0: -1, recoil: -1 }, knife: { shots: 1 }, shotgun: { need0: -1, dmg: 1 } };
// wb-rules retune for the 'spend' aim rule (Recoil is a Precision cost per shot)
const GUN_TWEAKS_SPEND = { smg: { need0: -1, recoil: -2 }, shotgun: { need0: -1 }, lmg: { recoil: -1, dmg: 1 }, ar: { recoil: -1 }, dmr: { recoil: -1, need0: -1 }, burst: { recoil: -1 }, knife: { dmg: 1 }, revolver: { dmg: -1 }, launcher: { dmg: -1 }, sniper: { dmg: -1 } };
function applyGunTweaks() {
  if (!CFG.gunTweaks) return;
  if (CFG.gunSet === 'spend') GUN_TWEAKS = GUN_TWEAKS_SPEND;
  for (const id in WD.WEAPONS) { const g = WD.WEAPONS[id]; const t = GUN_TWEAKS[g.gunClass]; if (!t || g._tw) continue; g._tw = true;
    if (t.need0) g.ladder = g.ladder.map(([h, d], i) => [i === 0 ? Math.max(1, h + t.need0) : h, d]);
    if (t.recoil) g.recoil = Math.max(0, g.recoil + t.recoil); if (t.shots) g.magazine_capacity += t.shots; if (t.dmg) g.ladder = g.ladder.map(([h, d]) => [h, d + t.dmg]); }
}

// ---------------- cards ----------------
// effect keys: m Movement, p Precision, i Intel, a Armor, s extra shot, d draw, k Mark (next shot needs 1 fewer Hit Marker),
//              x Pierce (shots ignore cover this turn), sc Scrap, cy free cycle, g your hits deal +1 damage this turn,
//              st Steady (your shots ignore 1 Recoil this turn), b +1 Buy this turn. Squad lines repeat once per OTHER family card in play.
const FAM = { A: 'Assault', R: 'Recon', S: 'Support', E: 'Engineer' };
const CARDS = {};
function C(id, name, fam, tier, h, c, base, o = {}) { CARDS[id] = Object.assign({ id, name, fam, tier, h, c, base, squad: null, ready: null, reaction: 0, copies: 2 }, o); }
// starter (10): unchanged
C('T001', 'Sprint', null, 0, 0, 0, { m: 1 }, { copies: 3 });
C('T002', 'Scout', null, 0, 0, 0, { i: 1 }, { copies: 3 });
C('T004', 'Steady Aim', null, 0, 1, 0, { p: 1 }, { copies: 2 });
C('T005', 'Recon Run', null, 0, 1, 0, { m: 1, i: 1 }, { copies: 2 });
// Buy Station (family basics; always available, 6 copies each)
C('K02', 'Tac Sprint', 'A', 1, 1, 2, { m: 1, p: 2 }, { copies: 0 });
C('K04', 'Focus', 'R', 1, 2, 2, { p: 2 }, { copies: 0 });
C('K05', 'Spare Rounds', 'S', 1, 2, 2, { p: 1, s: 1 }, { copies: 0 });
C('K03', 'Dead Drop', 'E', 1, 1, 2, { i: 2 }, { copies: 0 });
// Every family card helps you shoot (Precision); its family decides what else it does and what its Squad line pays.
// ASSAULT: hits hit harder. Movement, "your hits deal +1 damage this turn" (g), Pierce.
C('A11', 'Breach', 'A', 1, 2, 1, { m: 1, p: 2 }, { squad: { g: 1, p: 1 } });
C('A12', 'Slide Cancel', 'A', 1, 2, 1, { m: 2, p: 1, sc: 1 }, { squad: { d: 1, p: 1 } });
C('A13', 'Hip Fire', 'A', 1, 2, 2, { m: 1, p: 2 }, { squad: { p: 3 } });
C('A21', 'Rush the Door', 'A', 2, 2, 3, { m: 1, p: 3, x: 1 }, { squad: { g: 1, p: 2 } });
C('A22', 'Flank', 'A', 2, 2, 3, { m: 2, p: 2, d: 1 }, { squad: { d: 1, p: 2 } });
C('A23', 'Run and Gun', 'A', 2, 2, 3, { m: 1, p: 2, s: 1 }, { squad: { st: 1, p: 2 } });
C('A31', 'Blitz', 'A', 3, 3, 5, { m: 2, p: 3, g: 1 }, { squad: { p: 2 }, squadEach: true });
C('A32', 'Breaching Charge', 'A', 3, 3, 4, { m: 1, p: 3, x: 1, g: 1 }, { squad: { s: 1, st: 1 } });
C('L1A', 'Tac Vest', 'A', 2, 1, 3, {}, { ready: { p: 1, g: 1 }, tiers: [1, 2, 2] });
// RECON: aim. Precision, the most Hit Markers, Mark.
C('R11', 'Mark Target', 'R', 1, 2, 1, { p: 2 }, { squad: { k: 1, p: 1 } });
C('R12', 'Steady Breath', 'R', 1, 3, 1, { p: 2 }, { squad: { p: 2 } });
C('R13', 'Snapshot', 'R', 1, 2, 2, { p: 2, i: 1 }, { squad: { i: 2, p: 1 } });
C('R21', 'Heartbeat Sensor', 'R', 2, 2, 3, { p: 2, d: 1 }, { squad: { p: 4 } });
C('R22', 'Spotter Scope', 'R', 2, 3, 3, { p: 3 }, { squad: { k: 1, p: 2 } });
C('R23', 'Thermal Optic', 'R', 2, 2, 3, { p: 3, x: 1 }, { squad: { i: 2, p: 2 } });
C('R31', 'UAV', 'R', 3, 3, 4, { p: 3, i: 1, x: 1 }, { squad: { d: 1, k: 1, p: 1 } });
C('R32', 'Headhunter', 'R', 3, 3, 5, { p: 4, k: 1 }, { squad: { p: 2 }, squadEach: true });
C('L1R', 'Recon Post', 'R', 2, 1, 3, {}, { ready: { p: 2 }, tiers: [1, 2, 2] });
// SUPPORT: sustained fire. Extra shots, Steady (shots ignore 1 Recoil), Armor.
C('S11', 'Ammo Box', 'S', 1, 2, 2, { p: 2, s: 1, sc: 1 }, { squad: { st: 1, p: 2 } });
C('S12', 'Suppressing Fire', 'S', 1, 2, 2, { p: 2, a: 1 }, { squad: { s: 1, a: 1 } });
C('S13', 'Bandolier', 'S', 1, 2, 2, { p: 1, s: 1, a: 1, st: 1 }, { squad: { p: 3 } });
C('S21', 'Steady Grip', 'S', 2, 2, 3, { p: 2, s: 1, st: 1 }, { squad: { p: 3 } });
C('S22', 'Resupply', 'S', 2, 2, 3, { p: 1, i: 1, s: 1, d: 1 }, { squad: { st: 1, i: 2 } });
C('S23', 'Covering Fire', 'S', 2, 2, 3, { p: 3, a: 2 }, { squad: { s: 1, st: 1, a: 1 } });
C('S31', 'Overwatch', 'S', 3, 3, 5, { p: 4, s: 1, a: 2 }, { squad: { p: 2, a: 1 }, squadEach: true });
C('S32', 'Munitions Drop', 'S', 3, 3, 4, { p: 3, s: 2, st: 1 }, { squad: { s: 1, p: 1 } });
C('L1S', 'Field Pack', 'S', 2, 1, 3, {}, { ready: { p: 1, s: 1 }, tiers: [1, 2, 2] });
// ENGINEER: economy. Intel, extra Buys (b), draw, Scrap (thinning), cycles.
C('E11', 'Scrounge', 'E', 1, 1, 2, { p: 1, i: 2, sc: 1 }, { squad: { i: 3 } });
C('E12', 'Deployable Cover', 'E', 1, 1, 2, { p: 1, i: 2 }, { squad: { b: 1, i: 1 }, reaction: 3 });
C('E13', 'Ping', 'E', 1, 1, 1, { p: 1, i: 1, cy: 1 }, { squad: { d: 1, i: 1 } });
C('E21', 'Munitions Box', 'E', 2, 2, 3, { p: 2, i: 2 }, { squad: { s: 1, p: 2 } });
C('E22', 'Field Kit', 'E', 2, 2, 3, { p: 1, i: 2, d: 1 }, { squad: { p: 3 } });
C('E23', 'Salvage', 'E', 2, 2, 3, { p: 1, i: 2, sc: 1, cy: 2 }, { squad: { i: 3, b: 1 } });
C('E31', 'Field Workshop', 'E', 3, 2, 4, { p: 2, i: 2, d: 1, sc: 2 }, { squad: { p: 3, d: 1 } });
C('E32', 'Black Market', 'E', 3, 2, 5, { p: 2, i: 4, d: 1, b: 1 }, { squad: { i: 1, p: 2 }, squadEach: true });
C('L1E', 'Bounty Contract', 'E', 2, 1, 3, {}, { ready: { i: 2 }, tiers: [1, 2, 2] });
const STATION = ['K02', 'K04', 'K05', 'K03'];

// ---------------- helpers ----------------
function mkRng(seed) { let s = seed | 0; return () => { s = (s + 0x6D2B79F5) | 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const shuffle = (r, a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const W8 = { m: 0.7, p: 1, i: 1, a: 0.6, s: 2, d: 1.8, k: 1.5, x: 0.6, sc: 1, cy: 0.3, g: 2.5, st: 1.5, b: 1.5 }; // AI value of one point
const TPW = { m: 1, p: 1, i: 1, a: 1, s: 2, d: 2, k: 2, x: 1, sc: 1, cy: 0.5, g: 2, st: 1, b: 1 };     // Turn Power readout weights (spec §4)
const val = fx => fx ? Object.entries(fx).reduce((t, [k, n]) => t + (W8[k] || 0) * n, 0) : 0;
const def = c => CARDS[c.id];

// ---------------- setup ----------------
// wb-rules card retune (head's S4: buff Assault and Support, tone down Engineer). Edits: CFG.cardEdits = { id: { base?, squad?, ready?, h? } }
let _cardsTweaked = false;
function applyCardTweaks() { if (_cardsTweaked || !CFG.cardEdits) return; _cardsTweaked = true; for (const id in CFG.cardEdits) Object.assign(CARDS[id], CFG.cardEdits[id]); }
function newGame(seed, ais) {
  applyGunTweaks(); applyCardTweaks();
  const r = mkRng(seed * 7919 + 13);
  const s = { gone: [], r, seed, round: 1, over: false, winner: null, endBy: null, uid: 1, players: [], locs: [], decks: { 1: [], 2: [], 3: [] }, stationLeft: {}, log: [], finalN: 0 };
  const card = id => ({ uid: s.uid++, id });
  for (let p = 0; p < 2; p++) {
    const pl = { idx: p, ai: ais[p], hp: CFG.hp, pos: 0, deck: [], discard: [], hand: [], play: [], loadout: [], removed: [], gun: { def: 'pistol-0' },
      res: { m: 0, p: 0, i: 0 }, armor: 0, shot: 0, mark: 0, pierce: false, sc: 0, cy: 0, hitsTurn: 0, gunShots: 0, squadDone: new Set(), moved: false, buys: 0,
      tp: 0, turnSquads: 0,
      st: { oppP: [], shots: 0, hits: 0, firstShotP: [], dmg: 0, squads: 0, streakDmg: 0, buys: 0, scraps: 0, loadouts: 0, turns: [], famAtEnd: null, big: 0 } };
    for (const id of ['T001', 'T002', 'T004', 'T005']) for (let k = 0; k < CARDS[id].copies; k++) pl.deck.push(card(id));
    shuffle(r, pl.deck); s.players.push(pl);
  }
  for (const id in CARDS) { const d = CARDS[id]; if (!d.fam || STATION.includes(id)) continue; if (d.tiers) { for (const t of d.tiers) s.decks[t].push({ kind: 'card', c: card(id) }); continue; } for (let k = 0; k < d.copies; k++) s.decks[d.tier].push({ kind: 'card', c: card(id) }); }
  for (const t of [1, 2, 3]) for (const g of WD.GUNSET[t]) s.decks[t].push({ kind: 'gun', g });
  for (const t of [1, 2, 3]) shuffle(r, s.decks[t]);
  // Supply Line: one face-up card per family, refilled from that family's own deck (one copy of every family card goes there)
  s.row = {}; s.famDeck = {};
  if (CFG.supplyRow) for (const f of ['A', 'R', 'S', 'E']) {
    s.famDeck[f] = { 1: [], 2: [], 3: [] };
    for (const t of [1, 2, 3]) { const D = s.decks[t]; const seenId = new Set(); for (let j = D.length - 1; j >= 0; j--) { const it = D[j]; if (it.kind === 'card' && def(it.c).fam === f && !seenId.has(it.c.id)) { seenId.add(it.c.id); s.famDeck[f][t].push(D.splice(j, 1)[0]); } } shuffle(r, s.famDeck[f][t]); }
    s.row[f] = null;
  }
  for (const id of STATION) s.stationLeft[id] = CFG.stationCopies;
  // fixed row of 7 locations (7 of the 8 types), each with an affinity family
  const types = shuffle(r, Object.keys(WD.ENVS)).slice(0, 7);
  const AFF = { assault: 'A', recon: 'R', support: 'S', engineer: 'E' };
  types.forEach((t, w) => s.locs.push({ w, def: t, fam: AFF[WD.ENVS[t].affinity], safe: true, stack: [] }));
  // each location: a Common gun on top + 2 cards (biased to its family)
  const guns1 = s.decks[1].filter(x => x.kind === 'gun'); s.decks[1] = s.decks[1].filter(x => x.kind !== 'gun');
  for (const L of s.locs) { const g = guns1.shift(); if (g) L.stack.push(g); while (L.stack.length < CFG.stackSize) { const it = pull(s, L, 1, true); if (!it) break; L.stack.push(it); } }
  s.decks[1].push(...guns1);
  // drop: second player picks first (sim: fixed 1 and 5, seats random)
  const a = r() < 0.5; s.players[0].pos = a ? 1 : 5; s.players[1].pos = a ? 5 : 1;
  s.first = r() < 0.5 ? 0 : 1; s.first0 = s.first;
  s.closeSide = r() < 0.5 ? 'L' : 'R';
  for (const pl of s.players) draw(s, pl, CFG.hand);
  if (CFG.supplyRow) refillRow(s);
  return s;
}
function refillRow(s) {
  for (const f in s.row) { if (s.row[f]) continue; const t = phaseTier(s); for (const k of [t, t - 1, t + 1, 1, 2, 3]) { const D = s.famDeck[f][k]; if (D && D.length) { s.row[f] = D.pop(); break; } } }
}
function phaseTier(s) { return s.round <= 3 ? 1 : s.round <= 7 ? 2 : 3; }
function pull(s, L, t, noGun) {
  for (const k of [t, t + 1, t - 1, 3, 2, 1]) {
    const D = s.decks[k]; if (!D || !D.length) continue;
    let j = -1;
    if (s.r() < CFG.affinityShare) j = D.findIndex(x => x.kind === 'card' && def(x.c).fam === L.fam);
    if (j < 0) j = D.findIndex(x => !noGun || x.kind === 'card');
    if (j >= 0) return D.splice(j, 1)[0];
  }
  return null;
}
function draw(s, pl, n) {
  let d = 0;
  for (let k = 0; k < n; k++) { if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s.r, pl.discard); pl.discard = []; } pl.hand.push(pl.deck.pop()); d++; }
  return d;
}
const safe = s => s.locs.filter(L => L.safe);
const bounds = s => { const w = safe(s).map(L => L.w); return { lo: Math.min(...w), hi: Math.max(...w), n: w.length }; };
const loc = (s, w) => s.locs[w];
const dist = s => Math.abs(s.players[0].pos - s.players[1].pos);
const W = id => WD.WEAPONS[id];
const owned = pl => pl.deck.length + pl.discard.length + pl.hand.length + pl.play.length + pl.loadout.length;
function famCounts(pl) { const c = { A: 0, R: 0, S: 0, E: 0 }; for (const x of [...pl.deck, ...pl.discard, ...pl.hand, ...pl.play, ...pl.loadout]) { const f = def(x).fam; if (f) c[f]++; } return c; }
function mainFam(pl) { if (pl.ai === 'aware' && CFG.force) return CFG.force; const c = famCounts(pl); const f = Object.keys(c).sort((a, b) => c[b] - c[a])[0]; return c[f] ? f : null; }
// which edge closes at the end of this round (public schedule), or null
function closingW(s) { if (!CFG.closeAfter[s.round]) return []; const B = bounds(s); if (B.n <= 1) return []; return [s.closeSide === 'L' ? B.lo : B.hi]; }

// ---------------- effects ----------------
function gain(s, pl, fx, tag) {
  if (!fx) return;
  for (const [k, n] of Object.entries(fx)) {
    if (k === 'm' || k === 'p' || k === 'i') pl.res[k] += n;
    else if (k === 'a') pl.armor += n; else if (k === 's') pl.shot += n; else if (k === 'k') pl.mark += n;
    else if (k === 'x') pl.pierce = true; else if (k === 'g') pl.dmgUp += n; else if (k === 'st') pl.steady += n; else if (k === 'b') pl.buyBonus += n; else if (k === 'sc') pl.sc += n; else if (k === 'cy') pl.cy += n;
    else if (k === 'd') { const got = draw(s, pl, n); pl.tp += TPW.d * got; continue; }
    pl.tp += (TPW[k] || 0) * n;
  }
}
function startTurn(s, pl) {
  Object.assign(pl, { dmgUp: 0, steady: 0, buyBonus: 0, res: { m: 0, p: 0, i: 0 }, armor: 0, shot: 0, mark: 0, pierce: false, sc: 0, cy: 0, hitsTurn: 0, gunShots: 0, moved: false, buys: 0, tp: 0, turnSquads: 0, streakSum: 0 });
  pl.squadDone = new Set();
  if (CFG.loadout) for (const c of pl.loadout) gain(s, pl, def(c).ready);
  if (CFG.specialist) { const fc = famCounts(pl); for (const f in fc) { const rk = fc[f] >= CFG.specRanks[1] ? 2 : fc[f] >= CFG.specRanks[0] ? 1 : 0; if (rk) gain(s, pl, SPEC[f][rk - 1]); } }
  locBonus(s, pl);
}
const SPEC = { A: [{ m: 1 }, { s: 1 }], R: [{ p: 1 }, { k: 1 }], S: [{ a: 1 }, { s: 1 }], E: [{ i: 1 }, { d: 1 }] };
function locBonus(s, pl) { const b = WD.ENVS[loc(s, pl.pos).def].bonus || {}; const fx = {}; if (b.move) fx.m = b.move; if (b.prec) fx.p = b.prec; if (b.intel) fx.i = b.intel; if (b.def) fx.a = b.def; if (b.shot) fx.s = b.shot; if (b.draw) fx.d = b.draw; if (b.scrap) fx.sc = b.scrap; if (b.cycle) fx.cy = b.cycle; gain(s, pl, fx); }
function playCard(s, pl, c) {
  pl.hand.splice(pl.hand.indexOf(c), 1); const d = def(c);
  if (d.ready && CFG.loadout) {
    if (pl.loadout.length >= CFG.loadoutSlots) { // replace the weakest (AI: value + family fit)
      const mf = mainFam(pl); const sc = x => val(def(x).ready) + (pl.ai === 'aware' && def(x).fam === mf ? 1 : 0);
      const worst = pl.loadout.slice().sort((a, b) => sc(a) - sc(b))[0];
      if (sc(worst) >= sc(c)) { pl.play.push(c); gain(s, pl, d.ready); return; } // keep the row, use it once
      pl.loadout.splice(pl.loadout.indexOf(worst), 1); pl.discard.push(worst);
    }
    pl.loadout.push(c); pl.st.loadouts++; gain(s, pl, d.ready); checkSquads(s, pl); return;
  }
  pl.play.push(c); gain(s, pl, d.base);
  if (d.streak && CFG.streak) pl.streakSum += d.streak;
  checkSquads(s, pl);
}
const GUNFAM = { knife: 'A', smg: 'A', shotgun: 'A', burst: 'R', dmr: 'R', sniper: 'R', ar: 'S', lmg: 'S', launcher: 'S', pistol: 'E', revolver: 'E' };
// Rally (wb-rules, head's S4): 3+ / 5+ cards of one squad in play this turn (Loadout counts) give that squad's bonus, once per turn each.
const RALLY = { A: { 3: { g: 1 }, 5: { g: 1, x: 1 } }, R: { 3: { k: 1, p: 1 }, 5: { k: 1, p: 3 } }, S: { 3: { p: 2, s: 1, st: 1 }, 5: { p: 3, s: 1, st: 2 } }, E: { 3: { i: 1, p: 1 }, 5: { d: 1 } } };
function checkSquads(s, pl) {
  if (!CFG.squad) return;
  const present = {}; for (const x of [...pl.play, ...pl.loadout]) { const f = def(x).fam; if (f) present[f] = (present[f] || 0) + 1; }
  if (CFG.rally) for (const f in present) for (const n of [3, 5]) { const key = f + n; if (present[f] >= n && !pl.squadDone.has(key)) { pl.squadDone.add(key); gain(s, pl, RALLY[f][n]); pl.st.rallies = (pl.st.rallies || 0) + 1; } }
  if (CFG.gunSquad) { const gf = GUNFAM[W(pl.gun.def).gunClass]; present[gf] = (present[gf] || 0) + 1; }
  for (const x of pl.play) { const d = def(x); if (!d.squad || pl.squadDone.has(x.uid)) continue;
    if ((present[d.fam] || 0) - 1 >= 1) { pl.squadDone.add(x.uid); const k = Math.min(CFG.squadCap, (d.squadEach || CFG.squadAllEach) ? present[d.fam] - 1 : 1); for (let j = 0; j < k * CFG.squadMult; j++) gain(s, pl, d.squad); pl.st.squads++; pl.turnSquads++; } }
}

// ---------------- shooting ----------------
function shotInfo(s, p) {
  const pl = s.players[p], o = s.players[1 - p]; const G = W(pl.gun.def); const D = dist(s);
  const lo = CFG.pointBlank ? 0 : G.band[0]; const inBand = D >= lo && D <= G.band[1];
  const left = Math.max(0, G.magazine_capacity - pl.gunShots) + pl.shot;
  const cq = CFG.closeQuarters && D === 0;
  const cv = !cq && !pl.pierce ? WD.ENVS[loc(s, o.pos).def].cover : 0;
  const cover = CFG.coverNeed ? 0 : cv; const needUp = (CFG.coverNeed ? cv : 0) + (cq ? 0 : o.evade || 0); // coverNeed: cover makes the shot harder instead of weaker
  const steps = G.ladder.map(([h, dm]) => [G.melee ? 0 : Math.max(1, h + CFG.needPlus + needUp - pl.mark), dm]);
  return { G, D, inBand, left, cq, cover, cv, steps, reveal: G.melee ? 0 : Math.min(pl.res.p, CFG.revealCap) };
}
function hmSeq(pl) { return [pl.deck.map(c => def(c).h), pl.discard.map(c => def(c).h)]; }
function stepProbs(s, p, si) {
  if (si.G.melee) return si.steps.map(() => 1);
  const pl = s.players[p]; const [dk, dc] = hmSeq(pl); const n = si.reveal; if (n <= 0) return si.steps.map(() => 0);
  const cnt = si.steps.map(() => 0); const r = mkRng(pl.res.p * 31 + dk.length * 7 + s.round);
  const o = s.players[1 - p]; const dodgePool = (o.deck.length ? o.deck : o.discard).map(c => def(c).h);
  for (let t = 0; t < CFG.mcTrials; t++) {
    const a = shuffle(r, dk.slice()); let sum = 0, k = 0;
    for (; k < Math.min(n, a.length); k++) sum += a[k];
    if (k < n) { const b = shuffle(r, dc.slice()); for (let j = 0; j < Math.min(n - k, b.length); j++) sum += b[j]; }
    let dg = 0; if (dodgeOn(si)) for (let q = 0; q < dodgeN(o); q++) dg += dodgePool[Math.floor(r() * dodgePool.length)] || 0;
    si.steps.forEach(([h], i) => { if (sum >= h + dg) cnt[i]++; });
  }
  return cnt.map(c => c / CFG.mcTrials);
}
const dodgeOn = si => CFG.dodge && !si.G.melee && (CFG.dodgeCQ || !si.cq);
const dodgeN = o => CFG.dodgeArmor ? 1 + Math.min(2, o.armor) : 1;
function netDmg(s, p, si, dm, streakOn) {
  const o = s.players[1 - p]; let d = Math.max(1, dm + s.players[p].dmgUp + (streakOn ? s.players[p].streakSum : 0) - si.cover);
  if (!si.cq) d -= Math.min(o.armor, d - 1);
  return d;
}
// prefix-sum Monte Carlo: probability of reaching each ladder step when committing c = 0..max cards
function probsByCommit(s, p, si, max) {
  const pl = s.players[p]; const [dk, dc] = hmSeq(pl);
  const cnt = Array.from({ length: max + 1 }, () => si.steps.map(() => 0)); const r = mkRng(pl.res.p * 31 + dk.length * 7 + s.round * 3 + pl.gunShots);
  for (let t = 0; t < CFG.mcTrials; t++) {
    const a = shuffle(r, dk.slice()).concat(shuffle(r, dc.slice())); let sum = 0;
    for (let c = 1; c <= max; c++) { sum += c <= a.length ? a[c - 1] : 0; si.steps.forEach(([h], i) => { if (sum >= h) cnt[c][i]++; }); }
  }
  return cnt.map(x => x.map(v => v / CFG.mcTrials));
}
function fire(s, p, commit) {
  const pl = s.players[p], o = s.players[1 - p]; const si = shotInfo(s, p); if (commit != null && !si.G.melee) si.reveal = commit;
  const freeRev = CFG.aim === 'spend' && CFG.steadyFree && !si.G.melee ? pl.steady : 0; const paid = si.reveal; si.reveal += freeRev;
  if (pl.gunShots >= si.G.magazine_capacity) pl.shot--; else pl.gunShots++;
  const revealed = [];
  for (let k = 0; k < si.reveal; k++) { if (!pl.deck.length) { if (!pl.discard.length) break; pl.deck = shuffle(s.r, pl.discard); pl.discard = []; } revealed.push(pl.deck.pop()); }
  const total = revealed.reduce((t, c) => t + def(c).h, 0);
  pl.discard.push(...revealed);
  pl.st.shots++;
  // Dodge: the target flips the top card of their deck; its Hit Markers raise what this shot needs (not at close quarters)
  let dg = 0; if (dodgeOn(si)) for (let q = dodgeN(o); q > 0; q--) { if (!o.deck.length && o.discard.length) { o.deck = shuffle(s.r, o.discard); o.discard = []; } const dc = o.deck.pop(); if (dc) { dg += def(dc).h; o.discard.push(dc); } }
  const hitStep = si.steps.filter(([h]) => total >= h + dg).length - 1;
  const kind = si.G.melee ? 'melee' : si.cq ? 'cq' : 'ranged'; pl.st.byKind = pl.st.byKind || {}; const bk = pl.st.byKind[kind] = pl.st.byKind[kind] || [0, 0]; bk[0]++; if (hitStep >= 0) bk[1]++;
  if (CFG.aim === 'commit') pl.res.p = Math.max(0, pl.res.p - (si.G.melee ? 0 : si.reveal));
  else if (CFG.aim === 'spend') pl.res.p = Math.max(0, pl.res.p - (si.G.melee ? 0 : paid + (CFG.steadyFree ? si.G.recoil : Math.max(0, si.G.recoil - pl.steady))));
  else pl.res.p = Math.max(0, pl.res.p - Math.max(0, si.G.recoil - pl.steady));
  pl.mark = 0;
  if (hitStep < 0) return false;
  pl.hitsTurn++; pl.st.hits++; if (hitStep > 0) pl.st.big++;
  const streakOn = CFG.streak && pl.hitsTurn >= 2 && pl.streakSum > 0;
  let dmg = Math.max(1, si.steps[hitStep][1] + pl.dmgUp + (streakOn ? pl.streakSum : 0) - si.cover);
  if (streakOn) pl.st.streakDmg += pl.streakSum;
  const rx = o.hand.filter(c => def(c).reaction).sort((a, b) => def(b).reaction - def(a).reaction)[0];
  if (rx && dmg > 1) { dmg -= Math.min(def(rx).reaction, dmg - 1); o.hand.splice(o.hand.indexOf(rx), 1); o.discard.push(rx); }
  if (!si.cq) { const ab = Math.min(o.armor, dmg - 1); o.armor -= ab; dmg -= ab; }
  o.hp -= dmg; pl.st.dmg += dmg; s.turnDmg += dmg;
  if (o.hp <= 0) { s.over = true; s.winner = p; s.endBy = 'ko'; }
  return true;
}
function aiFireCommit(s, p) {
  const pl = s.players[p]; let first = true;
  for (let g = 0; g < 10 && !s.over; g++) {
    const si = shotInfo(s, p); if (!si.inBand || si.left < 1) break;
    const streakOn = CFG.streak && pl.hitsTurn >= 1 && pl.streakSum > 0;
    if (si.G.melee) { if (first) first = false; fire(s, p, 0); continue; }
    const pool = pl.res.p; if (pool < 1) break;
    const P = probsByCommit(s, p, si, pool);
    const evOf = c => { let ev = 0; si.steps.forEach(([, dm], i) => { ev += (P[c][i] - (P[c][i + 1] || 0)) * netDmg(s, p, si, dm, streakOn); }); return ev; };
    if (first) pl.st.oppP.push(P[pool][0]);
    if (dodgeOn(si)) { /* probsByCommit ignores Dodge; commit mode is tested without it */ }
    let c;
    // smallest commit that reaches the target odds; on the last shot, try for the big step first
    const minFor = (st) => { for (let k = 1; k <= pool; k++) if ((P[k][st] || 0) >= CFG.aiCommitP) return k; return 0; };
    c = (si.left === 1 && si.steps.length > 1 && minFor(1)) || minFor(0) || pool;
    if (P[c][0] < CFG.aiFireP && evOf(c) < CFG.aiFireEV) break;
    if (first) { pl.st.firstShotP.push(P[c][0]); first = false; }
    pl.st.commitP = pl.st.commitP || []; pl.st.commitP.push(P[c][0]);
    fire(s, p, c);
  }
}
// 'spend' (head's S1 answer): a shot reveals the cards you commit, and costs those Precision PLUS the gun's Recoil (Steady cancels Recoil).
// The AI allocates its Precision over the shots it has left with a small dynamic programme on expected damage.
function aiFireSpend(s, p) {
  const pl = s.players[p]; let first = true;
  for (let g = 0; g < 10 && !s.over; g++) {
    const si = shotInfo(s, p); if (!si.inBand || si.left < 1) break;
    if (si.G.melee) { fire(s, p, 0); continue; }
    const pool = pl.res.p; if (pool < 1) break;
    const fr = CFG.steadyFree ? pl.steady : 0; const P0 = probsByCommit(s, p, si, pool + fr); const P = P0.slice(fr);
    const ev = c => { let e = 0; si.steps.forEach(([, dm], i) => { e += (P[c][i] - (P[c][i + 1] || 0)) * netDmg(s, p, si, dm, false); }); return e; };
    const EV = Array.from({ length: pool + 1 }, (_, c) => c ? ev(c) : 0);
    const rc = CFG.steadyFree ? si.G.recoil : Math.max(0, si.G.recoil - pl.steady);
    const memo = new Map();
    const V = (q, l) => { if (l <= 0 || q < 1) return [0, 0]; const k = q * 16 + l; if (memo.has(k)) return memo.get(k); let best = [0, 0];
      for (let c = 1; c <= q; c++) { const v = EV[c] + V(Math.max(0, q - c - rc), l - 1)[0]; if (v > best[0] + 1e-9) best = [v, c]; } memo.set(k, best); return best; };
    const c = V(pool, Math.min(si.left, 6))[1]; if (!c) break;
    if (first) pl.st.oppP.push(P[pool][0]);
    if (EV[c] < CFG.aiSpendEV) break; // Precision is worth nothing after the turn, so any real chance is worth taking
    if (first) { pl.st.firstShotP.push(P[c][0]); first = false; }
    fire(s, p, c);
  }
}
function aiFire(s, p) {
  if (CFG.aim === 'commit') return aiFireCommit(s, p);
  if (CFG.aim === 'spend') return aiFireSpend(s, p);
  const pl = s.players[p]; let first = true;
  for (let g = 0; g < 10 && !s.over; g++) {
    const si = shotInfo(s, p); if (!si.inBand || si.left < 1 || (!si.G.melee && si.reveal < 1)) break;
    const ps = stepProbs(s, p, si); if (first && !si.G.melee) pl.st.oppP.push(ps[0]); const streakOn = CFG.streak && pl.hitsTurn >= 1 && pl.streakSum > 0;
    let ev = 0; si.steps.forEach(([, dm], i) => { ev += (ps[i] - (ps[i + 1] || 0)) * netDmg(s, p, si, dm, streakOn); });
    if (ps[0] < CFG.aiFireP && ev < CFG.aiFireEV) break;
    if (first) { pl.st.firstShotP.push(ps[0]); first = false; }
    fire(s, p);
  }
}

// ---------------- AI: buying ----------------
function remainingTurns(s) { return Math.max(1, CFG.hardEnd - s.round); }
function cardScore(s, pl, d) {
  const aware = pl.ai === 'aware';
  let v = val(d.base) + d.h * 1.1;
  if (d.ready) v = val(d.ready) * Math.min(4, remainingTurns(s) / 2) + d.h * 0.3;
  if (d.reaction) v += 1;
  if (aware && d.fam) {
    const fc = famCounts(pl); const n = owned(pl) + 1; const f = (fc[d.fam] + 1) / n;
    const lo = pl.loadout.some(c => def(c).fam === d.fam) || (CFG.gunSquad && GUNFAM[W(pl.gun.def).gunClass] === d.fam) ? 1 : 0;
    const pSquad = lo ? 1 : 1 - Math.pow(1 - f, CFG.hand - 1);
    if (d.squad && CFG.squad) v += pSquad * val(d.squad) * ((d.squadEach || CFG.squadAllEach) ? Math.max(1, (fc[d.fam] + 1) * CFG.hand / n) : 1);
    if (d.streak && CFG.streak) { const G = W(pl.gun.def); v += d.streak * (G.magazine_capacity >= 2 ? 0.8 : 0.35); }
    const mf = mainFam(pl); if (mf && d.fam === mf) v += 1.2 * CFG.famBias; else if (mf && (fc[mf] >= 3 || CFG.force)) v -= CFG.force ? 4 : CFG.famBias;
    // a family card also switches on the Squad text of cards already owned
    if (CFG.squad) { let partners = 0; for (const x of [...pl.deck, ...pl.discard, ...pl.hand, ...pl.play]) { const dx = def(x); if (dx.fam === d.fam && dx.squad) partners += val(dx.squad); } v += Math.min(3, partners * 0.12); }
    if (CFG.specialist) { const c0 = fc[d.fam]; if (CFG.specRanks.includes(c0 + 1)) v += 3; }
  }
  return v;
}
function gunScore(s, pl, gid) {
  const cur = W(pl.gun.def), g = W(gid); let fit = 0;
  if (CFG.gunSquad && pl.ai === 'aware') { const mf = mainFam(pl); if (mf) fit = (GUNFAM[g.gunClass] === mf ? 1 : 0) - (GUNFAM[cur.gunClass] === mf ? 1 : 0); }
  if (g.gunClass === cur.gunClass && g.tier <= cur.tier) return -1;
  if (cur.gunClass === 'pistol') return 12 + g.tier * 3 + fit * 4;
  const d = g.tier - cur.tier + fit * 1.5; return d > 0 ? 10 + d * 3 : -1;
}
function itemScore(s, pl, it) { return it.kind === 'gun' ? gunScore(s, pl, it.g) : cardScore(s, pl, def(it.c)); }
function itemCost(it) { return it.kind === 'gun' ? W(it.g).intel_cost : def(it.c).c; }
const MIN_SCORE = 3.0;
function aiBuy(s, p) {
  const pl = s.players[p];
  for (let guard = 0; guard < 6 && pl.buys < CFG.buyCap + pl.buyBonus; guard++) {
    const opts = [];
    for (const w of [pl.pos - 1, pl.pos, pl.pos + 1]) { const L = s.locs[w]; if (!L || !L.safe || !L.stack.length) continue; const it = L.stack[0]; opts.push({ it, L, cost: itemCost(it) + (w !== pl.pos ? 1 : 0), sc: itemScore(s, pl, it) }); }
    for (const id of STATION) if (s.stationLeft[id] > 0) opts.push({ station: id, cost: CFG.stationCost, sc: stationScore(s, pl, id) });
    if (CFG.supplyRow) for (const f in s.row) { const it = s.row[f]; if (it) opts.push({ it, rowFam: f, cost: def(it.c).c + CFG.rowExtra, sc: itemScore(s, pl, it) }); }
    const ok = opts.filter(o => o.cost <= pl.res.i && o.sc >= (o.it && o.it.kind === 'gun' ? 0 : MIN_SCORE)).sort((a, b) => (b.sc - 0.35 * b.cost) - (a.sc - 0.35 * a.cost));
    const o = ok[0]; if (!o) break;
    pl.res.i -= o.cost; pl.buys++; pl.st.buys++;
    const gain_ = c => { if (CFG.hotDrop && s.round <= CFG.hotDrop) pl.deck.push(c); else pl.discard.push(c); }; // Hot Drop: early buys go on top of your deck
    if (o.station) { s.stationLeft[o.station]--; gain_({ uid: s.uid++, id: o.station }); continue; }
    if (o.rowFam) { s.row[o.rowFam] = null; refillRow(s); gain_(o.it.c); continue; }
    o.L.stack.shift();
    if (o.it.kind === 'gun') { const old = pl.gun.def; pl.gun = { def: o.it.g }; pl.gunShots = 0; o.L.stack.push({ kind: 'gun', g: old }); }
    else gain_(o.it.c);
  }
}
function stationScore(s, pl, id) {
  const d = CARDS[id];
  if (pl.ai === 'aware') return cardScore(s, pl, d) - 0.5;
  // combo-blind: the shipped AI's rule, buy whatever resource the deck has least of
  const tot = { m: 0, p: 0, i: 0, s: 0 }; for (const x of [...pl.deck, ...pl.discard, ...pl.hand, ...pl.play]) for (const [k, n] of Object.entries(def(x).base)) if (k in tot) tot[k] += n;
  const want = { K02: tot.m / 1.0, K04: tot.p / 1.4, K03: tot.i / 1.2, K05: (tot.s + 3) / 0.8 };
  const best = STATION.slice().sort((a, b) => want[a] - want[b])[0];
  return id === best ? val(d.base) + d.h * 1.1 : 0;
}
function aiCycle(s, p) {
  const pl = s.players[p]; const L = loc(s, pl.pos);
  for (let k = 0; k < 2; k++) {
    if (!L.stack.length || L.stack.length < 2 || pl.buys >= CFG.buyCap + pl.buyBonus) return;
    const top = L.stack[0]; if (itemScore(s, pl, top) >= MIN_SCORE && itemCost(top) <= pl.res.i) return;
    if (pl.cy > 0) pl.cy--; else if (pl.res.m >= 1) pl.res.m--; else return;
    L.stack.push(L.stack.shift()); aiBuy(s, p);
  }
}
function aiScrap(s, p) {
  const pl = s.players[p];
  // Buy Station service: pay 1 Intel to Scrap one Starter card (once per turn)
  if (CFG.stationScrap && pl.res.i >= CFG.stationScrap && owned(pl) > CFG.minDeck && famCounts(pl)[mainFam(pl) || 'A'] >= 2 && [...pl.discard, ...pl.play].some(c => c.id === 'T001')) { pl.res.i -= CFG.stationScrap; pl.sc++; }
  while (pl.sc > 0 && owned(pl) > CFG.minDeck) {
    const intelSrc = [...pl.deck, ...pl.discard, ...pl.hand, ...pl.play].filter(c => c.id !== 'T002').reduce((t, c) => t + (def(c).base.i || 0), 0) + pl.loadout.reduce((t, c) => t + ((def(c).ready || {}).i || 0), 0);
    const pool = [...pl.discard, ...pl.play].filter(c => c.id === 'T001' || (c.id === 'T002' && intelSrc >= 6) || (c.id === 'T005' && s.round >= 5 && intelSrc >= 6));
    const t = pool.sort((a, b) => (a.id === 'T005') - (b.id === 'T005'))[0]; if (!t) break;
    const from = pl.discard.includes(t) ? pl.discard : pl.play; from.splice(from.indexOf(t), 1); pl.removed.push(t); pl.sc--; pl.st.scraps++; pl.tp += 0;
  }
}

// ---------------- AI: moving ----------------
function locScore(s, p, w) {
  const pl = s.players[p], o = s.players[1 - p]; const L = s.locs[w]; if (!L.safe) return -99;
  let sc = 0; if (closingW(s).includes(w)) sc -= 12;
  const G = W(pl.gun.def); const dd = Math.abs(w - o.pos);
  const blo = CFG.pointBlank ? 0 : G.band[0]; const off = dd < blo ? blo - dd : dd > G.band[1] ? dd - G.band[1] : 0; sc += 6 - 2.5 * off;
  if (off === 0 && G.band[1] <= 1 && dd === 0) sc += 1.5; // close guns love close quarters
  const oG = W(o.gun.def); if (dd >= (CFG.pointBlank ? 0 : oG.band[0]) && dd <= oG.band[1]) sc -= 1.5; // in the rival's band
  if (dd !== 0) sc += WD.ENVS[L.def].cover * 1.5;
  if (L.stack.length) { const it = L.stack[0]; const v = itemScore(s, pl, it); if (v > MIN_SCORE || (it.kind === 'gun' && v > 0)) sc += Math.min(3, v * 0.35); }
  if (pl.ai === 'aware') { const mf = mainFam(pl); if (mf && L.fam === mf) sc += 1.2; }
  return sc;
}
function aiMove(s, p) {
  const pl = s.players[p]; const here = locScore(s, p, pl.pos);
  const opts = s.locs.filter(L => L.safe && L.w !== pl.pos && Math.abs(L.w - pl.pos) <= pl.res.m).map(L => ({ w: L.w, cost: Math.abs(L.w - pl.pos), sc: locScore(s, p, L.w) - 0.3 * Math.abs(L.w - pl.pos) })).sort((a, b) => b.sc - a.sc);
  if (opts.length && opts[0].sc > here + 0.5) { pl.res.m -= opts[0].cost; pl.pos = opts[0].w; pl.moved = true; locBonus(s, pl); }
}

// ---------------- turn / round ----------------
function aiTurn(s, p) {
  const pl = s.players[p]; s.turnDmg = 0;
  startTurn(s, pl);
  for (let g = 0; g < 20 && pl.hand.length; g++) playCard(s, pl, pl.hand[0]);
  const tpPlay = pl.tp;
  aiMove(s, p);
  aiBuy(s, p); aiCycle(s, p);
  aiFire(s, p);
  if (!s.over) { aiScrap(s, p); aiBuy(s, p); }
  pl.st.turns.push({ round: s.round, tp: pl.tp, tpPlay, waste: pl.res.i, buys: pl.buys, squads: pl.turnSquads, dmg: s.turnDmg, deck: owned(pl), lo: pl.loadout.length });
  // end of turn: dig in, discard, draw
  pl.evade = 0; if (CFG.digIn && pl.res.m > 0) { if (CFG.evasion) pl.evade = Math.min(CFG.digIn, pl.res.m); else pl.armor += Math.min(CFG.digIn, pl.res.m); }
  pl.discard.push(...pl.hand, ...pl.play); pl.hand = []; pl.play = [];
  draw(s, pl, CFG.hand + (pl.hp <= CFG.lowHp ? CFG.lowHpDraw : 0));
}
function endRound(s) {
  const cl = closingW(s);
  for (const w of cl) { const L = s.locs[w]; L.safe = false; L.stack = []; }
  if (cl.length) s.closeSide = s.closeSide === 'L' ? 'R' : 'L';
  const B = bounds(s);
  for (const pl of s.players) { if (pl.pos >= B.lo && pl.pos <= B.hi) continue; const depth = pl.pos < B.lo ? B.lo - pl.pos : pl.pos - B.hi; const d = CFG.gasDmg + depth - 1; pl.hp -= d; s.gas += d; pl.pos = pl.pos < B.lo ? B.lo : B.hi; }
  if (B.n <= 1) { s.finalReached = true; const d = CFG.finalStorm[Math.min(s.finalN, CFG.finalStorm.length - 1)]; s.finalN++; for (const pl of s.players) { pl.hp -= d; s.gas += d; } }
  const [a, b] = s.players;
  if (a.hp <= 0 || b.hp <= 0) { s.over = true; s.endBy = s.finalN ? 'storm' : 'gas'; s.winner = a.hp === b.hp ? 'draw' : a.hp > b.hp ? 0 : 1; return; }
  if (s.round >= CFG.hardEnd) { s.over = true; s.endBy = 'hardEnd'; s.winner = a.hp === b.hp ? 'draw' : a.hp > b.hp ? 0 : 1; return; }
  // loot: every safe stack below 3 gets one item from the phase deck
  s.round++;
  // fresh loot lands on TOP of every safe stack; a stack over 3 loses its bottom item (out of the match)
  for (const L of safe(s)) { const it = pull(s, L, phaseTier(s), false); if (it) L.stack.unshift(it); while (L.stack.length > CFG.stackSize) s.gone.push(L.stack.pop()); }
}
function playGame(seed, ais) {
  const s = newGame(seed, ais); s.gas = 0;
  for (let guard = 0; guard < 60 && !s.over; guard++) {
    const order = [s.first, 1 - s.first];
    for (const p of order) { if (s.over) break; aiTurn(s, p); }
    if (s.over) break;
    endRound(s); s.first = 1 - s.first; // alternate the lead every round
  }
  // invariant: every card instance in exactly one place, nothing negative
  const seen = new Set();
  for (const pl of s.players) for (const z of ['deck', 'discard', 'hand', 'play', 'loadout', 'removed']) for (const c of pl[z]) { if (seen.has(c.uid)) throw new Error('dup card ' + c.uid); seen.add(c.uid); }
  for (const L of s.locs) for (const it of L.stack) if (it.kind === 'card') { if (seen.has(it.c.uid)) throw new Error('dup card ' + it.c.uid); seen.add(it.c.uid); }
  for (const f in s.row) { const extra = [s.row[f], ...s.famDeck[f][1], ...s.famDeck[f][2], ...s.famDeck[f][3]].filter(Boolean); for (const it of extra) { if (seen.has(it.c.uid)) throw new Error('dup card ' + it.c.uid); seen.add(it.c.uid); } }
  for (const it of s.gone) if (it.kind === 'card') { if (seen.has(it.c.uid)) throw new Error('dup card ' + it.c.uid); seen.add(it.c.uid); }
  for (const t of [1, 2, 3]) for (const it of s.decks[t]) if (it.kind === 'card') { if (seen.has(it.c.uid)) throw new Error('dup card ' + it.c.uid); seen.add(it.c.uid); }
  for (const pl of s.players) { pl.st.famAtEnd = famCounts(pl); pl.st.main = mainFam(pl); }
  return s;
}

const RULES_CARDS = {
  K05: { base: { p: 2, s: 1 }, h: 1, squad: { p: 1 } }, K02: { squad: { p: 1 } }, K04: { squad: { p: 1 } }, K03: { squad: { i: 1 } },
  E32: { base: { p: 2, i: 4, d: 1 } },
  L1E: { ready: { i: 1, p: 1 } },
  E12: { squad: { i: 2 } }, E21: { squad: { p: 2 } }, E22: { squad: { p: 2 } }, E31: { squad: { p: 2, d: 1 } },
  S11: { squad: { p: 3 } }, S12: { squad: { p: 2, a: 1 } }, S13: { base: { p: 2, s: 1, a: 1, st: 1 } }, S21: { base: { p: 3, s: 1, st: 1 } },
  S22: { squad: { st: 1, p: 2 } }, S23: { squad: { p: 2, st: 1, a: 1 } }, S32: { base: { p: 4, s: 2, st: 1 }, squad: { p: 2 } }, L1S: { ready: { p: 1, s: 1, st: 1 } },
};
// ---------------- runner ----------------
if (require.main === module) {
  const argv = process.argv.slice(2);
  const N = +(argv.find(a => /^\d+$/.test(a)) || 2000);
  const opt = k => { const a = argv.find(x => x.startsWith('--' + k)); return a ? (a.includes('=') ? a.split('=')[1] : true) : null; };
  const match = opt('match') || 'aware-blind';
  if (opt('flat')) { CFG.squad = false; CFG.streak = false; }
  if (opt('spec')) CFG.specialist = true;
  if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); CFG[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }
  const SCHED = { fast: { 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1 }, mid: { 2: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1 }, slow: { 2: 1, 4: 1, 6: 1, 8: 1, 9: 1, 10: 1 } };
  if (CFG.sched) CFG.closeAfter = SCHED[CFG.sched];
  if (opt('rules')) { // wb-rules: the package implemented in the shipped engine (head's answers S1-S4)
    Object.assign(CFG, { steadyFree: true, aim: 'spend', needPlus: 0, rally: true, gunSet: 'spend', famBias: CFG.famBias || 1.5, cardEdits: RULES_CARDS });
    if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); CFG[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }
  }
  const [aiA, aiB] = match.split('-');
  const R = { games: N, match, flat: !!opt('flat'), specialist: CFG.specialist, errors: 0, seat0: 0, wins: { A: 0, B: 0, draw: 0 }, firstWins: 0, decided: 0, rounds: [], endBy: {}, finalReached: 0,
    shots: 0, hits: 0, big: 0, firstP: [], oppP: [], dmg: 0, gas: 0, streakDmg: 0, squads: 0, turns: 0, gun: {}, byRound: {}, topFamShare: { [aiA]: [], [aiB + '_']: [] }, loadouts: 0, deckEnd: [], winnerHpEnd: [], fam: {}, kind: {} };
  for (let i = 0; i < N; i++) {
    const aSeat = i % 2; const ais = aSeat === 0 ? [aiA, aiB] : [aiB, aiA];
    let s; try { s = playGame(i + 1, ais); } catch (e) { R.errors++; if (R.errors < 4) console.error('seed', i + 1, e.message); continue; }
    R.rounds.push(s.round); R.endBy[s.endBy] = (R.endBy[s.endBy] || 0) + 1; if (s.finalReached) R.finalReached++;
    if (s.winner === 'draw') R.wins.draw++; else { R.decided++; if (s.winner === aSeat) R.wins.A++; else R.wins.B++; if (s.winner === s.first0) R.firstWins++; if (s.winner === 0) R.seat0++; }
    R.gas += s.gas;
    for (const pl of s.players) {
      const st = pl.st; for (const k in st.byKind || {}) { R.kind[k] = R.kind[k] || [0, 0]; R.kind[k][0] += st.byKind[k][0]; R.kind[k][1] += st.byKind[k][1]; } R.shots += st.shots; R.hits += st.hits; R.big += st.big; R.firstP.push(...st.firstShotP); R.oppP.push(...st.oppP); R.dmg += st.dmg; R.streakDmg += st.streakDmg; R.squads += st.squads; R.turns += st.turns.length; R.loadouts += st.loadouts; R.deckEnd.push(owned(pl));
      const g = W(pl.gun.def).gunClass; R.gun[g] = R.gun[g] || [0, 0]; R.gun[g][1]++; if (s.winner === pl.idx) R.gun[g][0]++;
      const fc = st.famAtEnd; const tot = Object.values(fc).reduce((a, b) => a + b, 0); const key = pl.idx === aSeat ? aiA : aiB + '_';
      if (tot) R.topFamShare[key].push(Math.max(...Object.values(fc)) / tot);
      if (tot && pl.ai === 'aware') { const sh = Math.max(...Object.values(fc)) / tot; const b = sh >= 0.85 ? 'mono(85%+)' : sh >= 0.6 ? 'lean(60-85%)' : 'mixed(<60%)'; R.share = R.share || {}; R.share[b] = R.share[b] || [0, 0]; R.share[b][1]++; if (s.winner === pl.idx) R.share[b][0]++; }
      for (const t of st.turns) { const b = R.byRound[t.round] = R.byRound[t.round] || { n: 0, tp: 0, squads: 0, dmg: 0, deck: 0, lo: 0, ai: {} }; b.n++; b.tp += t.tp; b.squads += t.squads; b.dmg += t.dmg; b.deck += t.deck; b.lo += t.lo;
        const k = pl.ai; b.ai[k] = b.ai[k] || [0, 0, 0, 0]; b.ai[k][0] += t.tp; b.ai[k][1]++; b.ai[k][2] += t.squads; b.ai[k][3] += t.dmg; }
      if (s.winner === pl.idx) R.winnerHpEnd.push(pl.hp);
      { const k = (pl.st.main || '-') + ':' + pl.ai; R.fam[k] = R.fam[k] || [0, 0]; R.fam[k][1]++; if (s.winner === pl.idx) R.fam[k][0]++; }
    }
  }
  const avg = a => a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : null;
  const done = R.rounds.length;
  const curve = Object.keys(R.byRound).map(Number).sort((a, b) => a - b).map(r => { const b = R.byRound[r]; return { round: r, turns: b.n, turnPower: +(b.tp / b.n).toFixed(1), squads: +(b.squads / b.n).toFixed(2), dmg: +(b.dmg / b.n).toFixed(2), deck: +(b.deck / b.n).toFixed(1), loadouts: +(b.lo / b.n).toFixed(2), byAI: Object.fromEntries(Object.entries(b.ai).map(([k, v]) => [k, { tp: +(v[0] / v[1]).toFixed(1), squads: +(v[2] / v[1]).toFixed(2), dmg: +(v[3] / v[1]).toFixed(2) }])) }; });
  const out = {
    games: N, match, flat: R.flat, specialist: R.specialist, set: opt('set') || null, completed: done, errors: R.errors,
    [`${aiA}WinRate`]: +(R.wins.A / Math.max(1, R.decided)).toFixed(3), firstPlayerWinRate: +(R.firstWins / Math.max(1, R.decided)).toFixed(3), seat0WinRate: +(R.seat0 / Math.max(1, R.decided)).toFixed(3), draws: R.wins.draw,
    avgRounds: avg(R.rounds), maxRound: Math.max(...R.rounds), endBy: R.endBy, finalCircleReached: +(R.finalReached / done).toFixed(3),
    hitRate: +(R.hits / R.shots).toFixed(3), shotsByKind: Object.fromEntries(Object.entries(R.kind).map(([k, v]) => [k, `${(v[1] / v[0]).toFixed(2)} hit, ${(v[0] / done).toFixed(1)}/game`])), avgFirstShotOdds: avg(R.firstP), avgOddsWhenInRange: avg(R.oppP), shotOddsBands: (() => { const b = [0, 0, 0, 0, 0]; for (const x of R.oppP) b[Math.min(4, Math.floor(x * 5))]++; return b.map(x => +(x / R.oppP.length).toFixed(2)); })(), bigHitShare: +(R.big / R.hits).toFixed(3), shotsPerGame: +(R.shots / done).toFixed(1),
    gasShareOfDamage: +(R.gas / (R.gas + R.dmg)).toFixed(3), streakShareOfDamage: +(R.streakDmg / R.dmg).toFixed(3), squadsPerTurn: +(R.squads / R.turns).toFixed(2), loadoutsPerPlayer: +(R.loadouts / (2 * done)).toFixed(2),
    topFamilyShareAtEnd: Object.fromEntries(Object.entries(R.topFamShare).map(([k, v]) => [k, avg(v)])), deckSizeAtEnd: avg(R.deckEnd), winnerHpAtEnd: avg(R.winnerHpEnd),
    winRateByGunHeldAtEnd: Object.fromEntries(Object.entries(R.gun).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`])),
    awareWinRateBySquadShare: Object.fromEntries(Object.entries(R.share || {}).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`])),
    winRateByMainFamily: Object.fromEntries(Object.entries(R.fam).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`])),
    curve,
  };
  if (opt('curve')) { const o2 = Object.assign({}, out); delete o2.curve; console.log(JSON.stringify(o2, null, 1)); } else console.log(JSON.stringify(out, null, 1));
  if (opt('curve')) { console.log('round turns power squads  dmg  deck loadouts | per AI: power/squads/dmg'); for (const c of curve) console.log(`${String(c.round).padStart(5)} ${String(c.turns).padStart(5)} ${String(c.turnPower).padStart(5)} ${String(c.squads).padStart(6)} ${String(c.dmg).padStart(4)} ${String(c.deck).padStart(5)} ${String(c.loadouts).padStart(8)} | ` + Object.entries(c.byAI).map(([k, v]) => `${k} ${v.tp}/${v.squads}/${v.dmg}`).join('  ')); }
}
module.exports = { CFG, CARDS, playGame, newGame };
