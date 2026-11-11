// Warbuilder "deckbuilding satisfaction and progression" simulator (studio QA tool, board task wb-fix2, 2026-11-11).
// Design: projects/warbuilder/documentation/design/wb-improve-v2.md
//
// Runs the SHIPPED engine (source/project-warbuilder/src/engine.js) in Node and measures how much the deck you build matters,
// how fast it changes, and how power grows over a match. It never changes the game source: the improvement options below are
// sim-only patches applied between engine calls (symmetrically, to both players), so they are quick checks, not final tuning.
//
//   node projects/warbuilder/qa/tools/ai_sim_v2.js [games=1000] [--a=aware] [--b=blind] [--opt=name,...]
//     --a / --b   policy of the test seat (A) and the other seat (B):
//                 aware   the shipped combo-aware AI (WD.aiTurn's steps)
//                 blind   the shipped combo-blind AI (ignores Squad lines when buying)
//                 noloot  plays like aware but never takes a card (guns only): "what if I don't build a deck at all?"
//                 random  takes random affordable loot (cards and guns) instead of the AI's pick
//     --opt       sim-only rule patches (see OPTIONS below), comma-separated
//     --all       print the standard comparison table for the baseline and every option (slow: about 1 minute per 1,000 games)
'use strict';
const path = require('path');
const WD = require(path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));

const argv = process.argv.slice(2);
const opt = k => { const a = argv.find(x => x.startsWith('--' + k)); return a ? (a.includes('=') ? a.split('=')[1] : true) : null; };
const N = +(argv.find(a => /^\d+$/.test(a)) || 1000);

const STARTERS = ['T001', 'T002', 'T004', 'T005'];
const PROMO_ORDER = ['T001', 'T002', 'T005', 'T004']; // Sprint first, Steady Aim last
const BASIC = { assault: 'K02', recon: 'K04', support: 'K05', engineer: 'K03' };
const isStarterDef = id => STARTERS.includes(id);
const defOf = (s, iid) => s.cards[iid].def;

// ---------- improvement options (sim-only patches; each one is a rule in wb-improve-v2.md) ----------
// FIELD UPGRADES (milestones): at the start of your first turn in rounds 3, 5 and 7, choose 1 of 3 permanent upgrades.
const UPGRADES = [
  { id: 'aim', v: 1.0, ready: pl => { pl.res.prec += 2; } },          // +2 Precision at Ready
  { id: 'intel', v: 1.0, ready: pl => { pl.res.intel += 1; } },       // +1 Intel at Ready
  { id: 'mag', v: 1.0, ready: pl => { pl.shot += 1; } },              // +1 extra shot at Ready
  { id: 'buy', v: 0.8, ready: pl => { pl.buyBonus += 1; } },          // +1 Buy each turn
  { id: 'hollow', v: 1.3, ready: pl => { pl.dmgTurn += 1; } },        // your hits deal +1 damage
  { id: 'steady', v: 0.9, ready: pl => { pl.revealPlus += 1; } },     // Steady every turn
];
const OPTIONS = {
  // PROMOTE: once per turn, pay 1 Intel: a starter in your hand, play area or discard becomes your main squad's Buy Station basic.
  promote: { afterFire(s, p) { const pl = s.players[p]; if (pl.res.intel < 1 || pl._promoted) return; const mf = WD.mainSquad(s, p); if (!mf) return;
    for (const id of PROMO_ORDER) { const iid = pl.discard.concat(pl.play, pl.hand).find(i => defOf(s, i) === id); if (iid) { s.cards[iid].def = BASIC[mf]; pl.res.intel -= 1; pl._promoted = true; pl._promos = (pl._promos || 0) + 1; return; } } } },
  // THIN: once per turn, free: scrap any starter (hand, play area or discard), down to the 7-card minimum.
  thin: { afterFire(s, p) { const pl = s.players[p]; if (pl._thinned || WD.owned(pl) <= WD.TUNE.minDeck) return;
    const intelSrc = WD.archCounts(s, p).engineer; const order = intelSrc >= 2 ? PROMO_ORDER : ['T001', 'T005', 'T004'];
    for (const id of order) { const iid = pl.discard.concat(pl.play).find(i => defOf(s, i) === id); if (iid) { pl.scrapAvail++; if (WD.scrap(s, p, iid).ok) { pl._thinned = true; return; } pl.scrapAvail--; } } } },
  // SPOILS: if you dealt damage this turn, choose 1 of 3 cards from the current loot tier for free (to your discard pile).
  spoils: { endTurn(s, p, dealt) { if (!dealt) return; offerCards(s, p, 3); } },
  // SPOILS (every turn): the control for SPOILS, a free 1-of-3 card every turn whether you hit or not.
  freecard: { endTurn(s, p) { offerCards(s, p, 3); } },
  // UPGRADES: Field Upgrades at rounds 3, 5 and 7 (1 of 3, permanent, applied at Ready).
  upgrades: { ready(s, p) { const pl = s.players[p];
      if ([3, 5, 7].includes(s.round) && !(pl._upR || []).includes(s.round)) { (pl._upR = pl._upR || []).push(s.round);
        const pool = UPGRADES.slice(); const offer = []; for (let k = 0; k < 3; k++) offer.push(pool.splice(Math.floor(rnd(s) * pool.length), 1)[0]);
        const pick = offer.sort((a, b) => b.v - a.v)[0]; (pl._ups = pl._ups || []).push(pick.id); }
      for (const id of pl._ups || []) UPGRADES.find(u => u.id === id).ready(pl); } },
  // INCOME: Ready: +1 Intel, and 3 buys per turn (a bigger engine budget, the "more buys" control).
  income: { ready(s, p) { s.players[p].res.intel += 1; }, tune: { buyCap: 3 } },
  // KIT (drop draft): before round 1 each player picks a squad kit; 2 of the 3 Sprints become that squad's Buy Station basic.
  kit: { setup(s, p) { const pl = s.players[p]; const sq = WD.SQUADS[Math.floor(rnd(s) * 4)]; let k = 0;
    for (const i of pl.deck.concat(pl.hand)) if (k < 2 && defOf(s, i) === 'T001') { s.cards[i].def = BASIC[sq]; k++; } } },
  // HP50: Health 50 instead of 40 (the pacing control for packages that add power).
  hp50: { tune: { hp: 50 } },
};
// a side RNG for sim-only choices, so the engine's own seed stream is not disturbed
function rnd(s) { s._r = ((s._r || s.seed * 7 + 3) * 1103515245 + 12345) & 0x7fffffff; return s._r / 0x7fffffff; }
function offerCards(s, p, k) {
  const t = s.round <= 3 ? 1 : s.round <= 7 ? 2 : 3; const pool = s.loot[t].filter(x => x.kind === 'card'); if (!pool.length) return;
  const offer = []; for (let i = 0; i < k && pool.length; i++) offer.push(pool.splice(Math.floor(rnd(s) * pool.length), 1)[0]);
  const pl = s.players[p]; const pol = s.pol[p];
  let pick = offer[0];
  if (pol === 'noloot') return; if (pol !== 'random') pick = offer.map(it => ({ it, sc: WD.aiItemScore(s, p, it) })).sort((a, b) => b.sc - a.sc)[0].it;
  s.loot[t].splice(s.loot[t].indexOf(pick), 1); pl.discard.push(pick.iid); pl.stats.cardsAcquired++; pl.stats.spoils = (pl.stats.spoils || 0) + 1;
}

// ---------- policies ----------
function randomBuy(s, p) {
  const pl = s.players[p];
  for (let g = 0; g < 6 && WD.buysLeft(s, p) > 0; g++) {
    const opts = [];
    for (const w of [pl.pos - 1, pl.pos, pl.pos + 1]) { const e = WD.envAt(s, w); if (e && e.state === 'safe' && e.loot.length) { const it = e.loot[0]; if (WD.lootCost(s, p, it) <= pl.res.intel) opts.push(() => WD.buy(s, p, [it.iid])); } }
    for (const id of WD.TUNE.station) if (s.stationLeft[id] > 0 && WD.TUNE.supplyCost <= pl.res.intel) opts.push(() => WD.buySupply(s, p, id));
    if (!opts.length) return; if (!opts[Math.floor(rnd(s) * opts.length)]().ok) return;
  }
}
function gunOnlyBuy(s, p) {
  const pl = s.players[p];
  for (const w of [pl.pos - 1, pl.pos, pl.pos + 1]) { const e = WD.envAt(s, w); if (!e || e.state !== 'safe' || !e.loot.length) continue; const it = e.loot[0];
    if (it.kind === 'weapon' && WD.aiItemScore(s, p, it) > 0 && WD.lootCost(s, p, it) <= pl.res.intel && WD.buysLeft(s, p) > 0) WD.buy(s, p, [it.iid]); }
}
function turn(s, p, opts) {
  const pl = s.players[p]; const pol = s.pol[p]; pl._promoted = false; pl._thinned = false;
  for (const o of opts) if (o.ready) o.ready(s, p);
  const hand = pl.hand.map(i => defOf(s, i)); const r = s.round; const T = s.T[p];
  (T.handBuilt[r] = T.handBuilt[r] || [0, 0]); T.handBuilt[r][0] += hand.filter(id => !isStarterDef(id)).length; T.handBuilt[r][1] += hand.length;
  const dmg0 = pl.stats.damageDealt;
  WD.aiPlay(s, p); WD.aiMove(s, p);
  const buy = () => pol === 'random' ? randomBuy(s, p) : pol === 'noloot' ? gunOnlyBuy(s, p) : (WD.aiBuy(s, p), WD.aiCycle(s, p));
  buy(); WD.aiFireLoop(s, p);
  if (s.over) return;
  if (pol !== 'noloot') WD.aiScrap(s, p);
  for (const o of opts) if (o.afterFire) o.afterFire(s, p);
  buy();
  const dealt = pl.stats.damageDealt - dmg0;
  (T.dmg[r] = T.dmg[r] || []).push(dealt); T.turnDmg.push(dealt); T.prec.push(pl.res.prec);
  for (const o of opts) if (o.endTurn) o.endTurn(s, p, dealt);
  const res = WD.endTurn(s, p); if (!res.ok) throw new Error(res.err);
}

function run(n, polA, polB, optNames) {
  const opts = optNames.map(k => { if (!OPTIONS[k]) throw new Error('unknown option ' + k); return OPTIONS[k]; });
  const saved = Object.assign({}, WD.TUNE); for (const o of opts) if (o.tune) Object.assign(WD.TUNE, o.tune);
  const R = { n: 0, aWins: 0, draws: 0, rounds: 0, acq: 0, starters: 0, size: 0, built: 0, scrapped: 0, promos: 0, swing: 0, prec: 0, zero4: [0, 0], dmg: {}, handBuilt: {}, firstHitRound: 0, errors: 0, final: 0 };
  for (let i = 0; i < n; i++) {
    const aSeat = i % 2; const s = WD.newGame({ seed: i + 1 });
    s.pol = aSeat === 0 ? [polA, polB] : [polB, polA];
    s.aiMode = s.pol.map(x => x === 'blind' ? 'blind' : 'aware');
    s.T = [0, 1].map(() => ({ dmg: {}, turnDmg: [], prec: [], handBuilt: {} }));
    for (const o of opts) if (o.setup) { o.setup(s, 0); o.setup(s, 1); }
    try { let g = 0; while (!s.over && g++ < 400) turn(s, s.turn, opts); } catch (e) { R.errors++; if (R.errors < 3) console.error(e); continue; }
    R.n++; if (s.winner === aSeat) R.aWins++; else if (s.winner === 'draw') R.draws++;
    R.rounds += s.round; R.final += s.finalReached ? 1 : 0;
    const pl = s.players[aSeat]; const T = s.T[aSeat];
    const all = pl.deck.concat(pl.discard, pl.hand, pl.play, pl.loadout);
    R.acq += pl.stats.cardsAcquired; R.size += all.length; R.starters += all.filter(i => isStarterDef(defOf(s, i))).length;
    R.built += all.filter(i => !isStarterDef(defOf(s, i))).length / all.length; R.scrapped += pl.stats.burned || 0; R.promos += pl._promos || 0;
    const tot = T.turnDmg.reduce((a, b) => a + b, 0); R.swing += tot ? Math.max(...T.turnDmg) / tot : 0; R.prec += T.prec.reduce((a, b) => a + b, 0) / Math.max(1, T.prec.length);
    for (const [r, a] of Object.entries(T.dmg)) { (R.dmg[r] = R.dmg[r] || [0, 0]); R.dmg[r][0] += a.reduce((x, y) => x + y, 0); R.dmg[r][1] += a.length; if (+r >= 4) { R.zero4[0] += a.filter(x => !x).length; R.zero4[1] += a.length; } }
    for (const [r, a] of Object.entries(T.handBuilt)) { (R.handBuilt[r] = R.handBuilt[r] || [0, 0]); R.handBuilt[r][0] += a[0]; R.handBuilt[r][1] += a[1]; }
    const fr = Object.keys(T.dmg).map(Number).sort((a, b) => a - b).find(r => T.dmg[r].some(x => x > 0)); R.firstHitRound += fr || s.round;
  }
  Object.assign(WD.TUNE, saved);
  const k = R.n || 1; const f = (x, d = 2) => +x.toFixed(d);
  return { a: polA, b: polB, opt: optNames.join('+') || 'baseline', games: R.n, errors: R.errors, aWin: f(R.aWins / k, 3), draws: R.draws, rounds: f(R.rounds / k), finalCircle: f(R.final / k),
    cardsAcquired: f(R.acq / k, 1), deckAtEnd: f(R.size / k, 1), startersAtEnd: f(R.starters / k, 1), builtShareAtEnd: f(R.built / k), scrapped: f(R.scrapped / k, 1), promoted: f(R.promos / k, 1),
    builtShareOfHand: Object.fromEntries(Object.entries(R.handBuilt).map(([r, v]) => [r, f(v[0] / v[1])])),
    dmgPerTurn: Object.fromEntries(Object.entries(R.dmg).map(([r, v]) => [r, f(v[0] / v[1], 1)])),
    zeroDamageTurnsFromR4: f(R.zero4[0] / Math.max(1, R.zero4[1])), bestTurnShareOfDamage: f(R.swing / k), unusedPrecision: f(R.prec / k, 1), firstDamageRound: f(R.firstHitRound / k, 1) };
}

if (require.main === module) {
  if (opt('all')) {
    const rows = [];
    for (const o of [[], ['promote'], ['thin'], ['spoils'], ['freecard'], ['upgrades'], ['income'], ['kit'], ['promote', 'spoils', 'upgrades'], ['kit', 'promote', 'spoils', 'upgrades', 'hp50'], ['kit', 'spoils', 'upgrades', 'hp50']]) {
      const ab = run(N, 'aware', 'blind', o), an = run(N, 'aware', 'noloot', o), ar = run(N, 'aware', 'random', o), mm = run(N, 'aware', 'aware', o);
      rows.push({ opt: ab.opt, synergyEdge: ab.aWin, buildEdgeVsNoloot: an.aWin, edgeVsRandom: ar.aWin, rounds: mm.rounds, finalCircle: mm.finalCircle, acquired: mm.cardsAcquired, startersAtEnd: mm.startersAtEnd, deckAtEnd: mm.deckAtEnd,
        builtHandR3: mm.builtShareOfHand[3], builtHandR6: mm.builtShareOfHand[6], dmgR2: mm.dmgPerTurn[2], dmgR4: mm.dmgPerTurn[4], dmgR6: mm.dmgPerTurn[6], dmgR8: mm.dmgPerTurn[8], zeroDmgR4plus: mm.zeroDamageTurnsFromR4, bestTurnShare: mm.bestTurnShareOfDamage, firstDamageRound: mm.firstDamageRound, errors: ab.errors + an.errors + ar.errors + mm.errors });
    }
    console.log(JSON.stringify(rows, null, 1));
  } else {
    console.log(JSON.stringify(run(N, opt('a') || 'aware', opt('b') || 'blind', opt('opt') ? String(opt('opt')).split(',') : []), null, 1));
  }
}
module.exports = { run, OPTIONS };
