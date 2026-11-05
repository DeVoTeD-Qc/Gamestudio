// Warbuilder PUSH-YOUR-LUCK FIRE prototype (studio QA tool, board task wb-pyl, 2026-11-05).
// Design: projects/warbuilder/documentation/design/push-your-luck-shooting.md
//
// Runs the SHIPPED engine (source/project-warbuilder/src/engine.js) for everything except FIRE: play, Squad, Rally, Loadout, move, loot,
// scrap, gas, final circle and hard end are the engine's own code and the engine's own AI. Only the shot is replaced by the proposed
// flip-and-stop rule, which this file implements. Card Jam icons and gun ladders are changed in THIS PROCESS'S in-memory copy of the
// card and gun tables only. Nothing in source/ is written; ai_sim.js and ai_sim_syn.js are untouched.
//
// The rule (variant "jam2", the recommendation):
//   FIRE: flip the top card of your deck, one at a time; each flip costs 1 Precision. Add up the Hit Markers.
//   When the total reaches a step of your gun's ladder, you may STOP and deal that step's damage, or flip on for the next step.
//   A card with a Jam icon is a Jam: your gun's Recoil costs that much more Precision, and a 2nd Jam in one shot means you miss.
//   Steady cancels a Jam. Mark: the next shot needs 1 fewer Hit Marker on every step. Out of Precision before step 1: you miss.
//
//   node projects/warbuilder/qa/tools/ai_sim_pyl.js [games=2000] [options]
//     --match=aware-blind | aware-aware | blind-blind   who plays (default aware-blind; seats alternate every game)
//     --variant=jam2 | hotzone | onejam | blank | free   jam2 (V1): Jam icons on Sprint and Scout, 2nd Jam misses, 1 Precision per flip (default)
//                                                        hotzone (V2, recommended): jam2, but in the final circle the 1st Jam misses
//                                                        onejam (V3): the 1st Jam always misses
//                                                        blank: no new icon, any 0-Hit-Marker card is a Jam (= jam2 with today's cards)
//                                                        free (rejected): flips cost no Precision; each Jam costs Recoil+1 Precision and
//                                                              a shot misses when it can't pay (Precision is the bust buffer)
//     --policy=cautious | normal | bold | ev              AI stop rule (push when the risk of the push failing is <= 20 / 35 / 50 %;
//                                                        ev = push when it raises expected damage). Both AIs use it.
//     --set=key:value,...                                 override CFG (e.g. --set=bustAt:3,peek:true,jamSet:starters)
//     --flat                                              Squad and Rally off (the "no synergy" control)
//     --force=assault|recon|support|engineer              the aware AI buys only that squad
//     --curve                                             print the per-round table
//     --shipped                                           control: the shipped commit-Precision FIRE (engine's own aiTurn), same harness
'use strict';
const path = require('path');
const WD = require(path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));

const argv = process.argv.slice(2);
const N = +(argv.find(a => /^\d+$/.test(a)) || 2000);
const opt = k => { const a = argv.find(x => x.startsWith('--' + k)); return a ? (a.includes('=') ? a.split('=')[1] : true) : null; };

const CFG = {
  variant: opt('variant') || 'jam2', policy: opt('policy') || 'normal', shipped: !!opt('shipped'),
  bustAt: 2,            // Jams in one shot that make it miss
  flipCost: 1,          // Precision per flip (jam2, blank)
  jamRecoil: true,      // a Jam also costs the gun's Recoil in Precision
  jamSet: 'starters',   // which cards carry a Jam icon (see JAMSETS)
  steady: 'cancel',     // 'cancel': each Steady cancels one Jam this turn; 'flip': each Steady is one free flip
  peek: true,           // Recon Rally 3 adds "Scope: once this turn, look at the top card before you flip" (AI: stop if it would bust)
  ladders: 'final',     // 'shipped' or a LADDERS key (pyl2, pyl, long, steep, final)
  dmgPlus: 0, dmgPlusStep1: false, // +N damage on steps 2+ (and step 1 if dmgPlusStep1)
  shotsPlus: 0,         // +N shots per turn for every gun
  finalBust: 0, finalSafe: 1, // >0: with finalSafe or fewer safe locations left, a shot misses at this many Jams
  rising: 0,           // >0: flip cost rises by 1 every `rising` flips within a shot (Recoil climbs)
  startMin: 0.05,       // AI fires only if P(reach step 1) >= this (a miss costs nothing but the flips, so fire almost always)
  trials: 150,          // Monte Carlo trials per AI decision
};
if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); CFG[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }
if (CFG.variant === 'hotzone' && !/finalBust/.test(String(opt('set') || ''))) CFG.finalBust = 1;
if (CFG.variant === 'onejam' && !/bustAt/.test(String(opt('set') || ''))) CFG.bustAt = 1;
const POLICY = { cautious: 0.20, normal: 0.35, bold: 0.50, ev: null };
const T = POLICY[CFG.policy];
const match = opt('match') || 'aware-blind';
const force = opt('force');
if (opt('flat')) { WD.TUNE.squadCap = 0; WD.TUNE.rally = []; }
const [aiA, aiB] = match.split('-');

// ---------- Jam icons ----------
// pyl: Sprint x3 and Scout x3 (the 0-Hit-Marker starters) + the 4 Buy Station basics (cheap gear jams) + the 6 tier III "heavy" cards.
const JAMSETS = {
  starters: ['T001', 'T002'],
  pyl: ['T001', 'T002', 'K02', 'K04', 'K05', 'K03', 'A31', 'A32', 'R31', 'R32', 'S31', 'S32', 'E31', 'E32'],
  station: ['T001', 'T002', 'K02', 'K04', 'K05', 'K03'],
  heavy: ['T001', 'T002', 'A31', 'A32', 'R31', 'R32', 'S31', 'S32', 'E31', 'E32'],
};
const JAM = new Set(CFG.variant === 'blank' ? Object.keys(WD.CARDS).filter(id => WD.CARDS[id].hit_markers === 0) : (JAMSETS[CFG.jamSet] || String(CFG.jamSet).split('+')));

// ---------- gun ladders for flip-and-stop ----------
// [Hit Markers, damage] per step. Step 1 is the safe bank, the top step is the prize worth pushing for. Knife: needs 1 Hit Marker.
const LADDERS = {};
LADDERS.pyl2 = {
  pistol: { ladder: [[2, 2], [4, 4]] },
  revolver: { ladder: [[3, 3], [6, 7]] },
  knife: { ladder: [[1, 3]] },
  smg: { ladder: [[2, 2], [4, 4]] },
  shotgun: { ladder: [[2, 3], [5, 6]] },
  burst: { ladder: [[2, 2], [5, 4]] },
  launcher: { ladder: [[3, 3], [6, 7]] },
  ar: { ladder: [[3, 3], [5, 5]] },
  lmg: { ladder: [[3, 2], [5, 4]] },
  dmr: { ladder: [[3, 3], [6, 6]] },
  sniper: { ladder: [[3, 3], [7, 8]] },
};
// three steps: two stop-or-push decisions at most
LADDERS.pyl = {
  pistol: { ladder: [[2, 2], [4, 3], [6, 5]] },
  revolver: { ladder: [[3, 3], [6, 6], [8, 9]] },
  knife: { ladder: [[1, 3]] },
  smg: { ladder: [[2, 2], [4, 3], [6, 5]] },
  shotgun: { ladder: [[2, 3], [4, 5], [6, 7]] },
  burst: { ladder: [[2, 2], [4, 3], [6, 5]] },
  launcher: { ladder: [[3, 3], [6, 6], [8, 9]] },
  ar: { ladder: [[3, 3], [5, 4], [7, 6]] },
  lmg: { ladder: [[3, 2], [5, 4], [7, 5]] },
  dmr: { ladder: [[3, 3], [6, 5], [8, 7]] },
  sniper: { ladder: [[3, 3], [7, 7], [9, 10]] },
};
// longer ladders: a shot takes 3-7 flips, so Precision (flips) is the engine's budget and Jam risk builds with every flip
LADDERS.long = {
  pistol: { ladder: [[3, 2], [5, 4], [7, 6]] },
  revolver: { ladder: [[4, 3], [7, 6], [10, 10]] },
  knife: { ladder: [[2, 3], [4, 5]] },
  smg: { ladder: [[3, 2], [5, 3], [7, 5]] },
  shotgun: { ladder: [[3, 3], [5, 5], [7, 8]] },
  burst: { ladder: [[3, 2], [6, 4], [8, 6]] },
  launcher: { ladder: [[4, 3], [7, 6], [10, 10]] },
  ar: { ladder: [[4, 3], [6, 5], [9, 8]] },
  lmg: { ladder: [[4, 2], [6, 4], [8, 6]] },
  dmr: { ladder: [[4, 3], [7, 6], [10, 9]] },
  sniper: { ladder: [[4, 3], [8, 8], [11, 12]] },
};
// steep: step 3 is worth about 3x step 1, so pushing pays (the push-your-luck prize)
LADDERS.steep = {
  pistol: { ladder: [[2, 2], [4, 4], [6, 6]] },
  revolver: { ladder: [[3, 3], [6, 7], [8, 10]] },
  knife: { ladder: [[2, 3], [4, 6]] },
  smg: { ladder: [[2, 2], [4, 3], [6, 5]] },
  shotgun: { ladder: [[2, 3], [4, 5], [6, 8]] },
  burst: { ladder: [[2, 2], [5, 4], [7, 6]] },
  launcher: { ladder: [[3, 3], [6, 7], [8, 10]] },
  ar: { ladder: [[3, 3], [5, 5], [7, 7]] },
  lmg: { ladder: [[3, 2], [5, 4], [7, 6]] },
  dmr: { ladder: [[3, 3], [6, 6], [8, 9]] },
  sniper: { ladder: [[3, 3], [7, 8], [9, 12]] },
};
// final (the recommendation): 'steep' with +1 damage on every step, then per-class tuning from the mirror match
LADDERS.final = {
  pistol: { ladder: [[2, 2], [4, 4], [6, 5]] },
  revolver: { ladder: [[2, 4], [5, 7], [7, 10]], recoil: 1 },
  knife: { ladder: [[2, 4], [4, 7]] },
  smg: { ladder: [[2, 3], [4, 4], [6, 6]] },
  shotgun: { ladder: [[2, 4], [4, 6], [6, 9]], recoil: 2 },
  burst: { ladder: [[2, 3], [5, 4], [8, 6]] },
  launcher: { ladder: [[3, 4], [5, 8], [7, 11]], recoil: 2 },
  ar: { ladder: [[3, 4], [5, 6], [7, 8]] },
  lmg: { ladder: [[3, 3], [5, 6], [7, 9]] },
  dmr: { ladder: [[3, 4], [5, 7], [7, 10]] },
  sniper: { ladder: [[3, 4], [6, 9], [9, 13]], recoil: 1 },
};
const GUN_PYL = LADDERS[CFG.ladders];
if (GUN_PYL && !CFG.shipped) for (const id in WD.WEAPONS) {
  const w = WD.WEAPONS[id]; const g = GUN_PYL[w.gunClass]; if (!g) continue;
  const base = WD.GUNCLASS[w.gunClass].ladder; // rarity mods: keep their offsets (Red Dot -1 need, Hollow Points +1 damage)
  const dn = w.ladder[0][0] - base[0][0], dd = w.ladder[0][1] - base[0][1];
  const dp = CFG.dmgPlus || 0;
  w.ladder = g.ladder.map(([h, d], i) => [w.melee ? 0 : Math.max(1, h + dn), d + dd + (i ? dp * (CFG.dmgPlusStep1 ? 1 : 1) : (CFG.dmgPlusStep1 ? dp : 0))]);
  w._pyl = g.ladder.map(([h, d], i) => [Math.max(1, h + dn), d + dd + (i || CFG.dmgPlusStep1 ? dp : 0)]); // the knife flips too (the engine's ladder keeps 0 for its melee code)
  if (g.recoil != null) w.recoil = g.recoil; if (g.shots != null) w.magazine_capacity = g.shots;
  if (CFG.shotsPlus) w.magazine_capacity += CFG.shotsPlus;
}

// ---------- the flip-and-stop shot ----------
const P = (s, i) => s.players[i];
const def = (s, iid) => WD.CARDS[s.cards[iid].def];
const isJam = (s, iid) => JAM.has(s.cards[iid].def);
function lcg(seed) { let x = seed | 0; return () => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x / 0x7fffffff; }; }
const mc = lcg(4242);
const shuf = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(mc() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// One step of the rule, shared by the real shot and the AI's Monte Carlo: apply a flipped card to the shot state.
// st = { sum, jams, prec, steady, recoil, melee } ; returns 'bust' or null
function applyFlip(st, hm, jam) {
  if (!st.melee) { if (CFG.variant === 'free') { /* flips free */ } else if (CFG.steady === 'flip' && st.steady > 0) st.steady--; else { st.prec -= CFG.flipCost + (CFG.rising ? Math.floor(st.flips / CFG.rising) : 0); } st.flips = (st.flips || 0) + 1; }
  st.sum += hm;
  if (jam) {
    if (CFG.steady === 'cancel' && st.steady > 0) { st.steady--; return null; }
    st.jams++;
    if (CFG.variant === 'free') { const c = st.recoil + 1; if (st.prec < c) return 'bust'; st.prec -= c; }
    else if (CFG.jamRecoil) st.prec = Math.max(0, st.prec - st.recoil);
    if (st.jams >= (st.bustAt || CFG.bustAt)) return 'bust';
  }
  return null;
}
const canFlip = st => st.melee || CFG.variant === 'free' || (CFG.steady === 'flip' && st.steady > 0) || st.prec >= CFG.flipCost + (CFG.rising ? Math.floor((st.flips || 0) / CFG.rising) : 0);
const levelOf = (steps, sum) => steps.filter(([h]) => sum >= h).length - 1;

// P(reaching step `goal` from state st), with the unknown cards: the rest of the deck (unknown order), then the discard pile reshuffled
function pReach(st, steps, goal, deckCards, discCards) {
  let ok = 0;
  for (let t = 0; t < CFG.trials; t++) {
    const seq = shuf(deckCards.slice()).concat(shuf(discCards.slice())); const x = Object.assign({}, st); let i = 0, r = false;
    while (i < seq.length && canFlip(x)) { const c = seq[i++]; if (applyFlip(x, c[0], c[1])) break; if (levelOf(steps, x.sum) >= goal) { r = true; break; } }
    if (r) ok++;
  }
  return ok / CFG.trials;
}
function evPush(st, steps, lvl, deckCards, discCards) { // expected damage if you push from level lvl (stop at the next step, AI-style)
  return pReach(st, steps, lvl + 1, deckCards, discCards) * steps[lvl + 1][1];
}

const R0 = () => ({ shots: 0, hits: 0, busts: 0, outs: 0, top: 0, flips: 0, decisions: 0, pushes: 0, pushWins: 0, turns: 0, shotTurns: 0, meleeShots: 0, meleeHits: 0,
  byRound: {}, jamShare: {}, hitByJam: {}, why: {} });
const R = Object.assign(R0(), { errors: 0, stuck: 0, inv: 0, decided: 0, draws: 0, aWins: 0, firstWins: 0, rounds: [], endBy: {}, final: 0, shotDmg: 0, gasDmg: 0, gun: {}, fam: {}, curve: {} });

function applyHit(s, ti, dmg, cq) { // as engine.js applyHit: best Reaction in hand, then Armor (not at close quarters)
  const t = P(s, ti);
  const rx = t.hand.filter(i => def(s, i).reaction).sort((a, b) => def(s, b).reaction - def(s, a).reaction)[0];
  if (rx && dmg > 1) { const r = Math.min(def(s, rx).reaction, dmg - 1); dmg -= r; t.hand.splice(t.hand.indexOf(rx), 1); t.discard.push(rx); t.stats.reactions++; }
  if (!cq) { const ab = Math.min(t.def, dmg - 1); if (ab > 0) { t.def -= ab; dmg -= ab; } }
  t.hp -= dmg; return dmg;
}
function checkDeath(s) {
  const d0 = s.players[0].hp <= 0, d1 = s.players[1].hp <= 0; if (!d0 && !d1) return;
  s.over = true; s.endBy = 'ko'; const [a, b] = s.players; s.winner = d0 && d1 ? (a.hp !== b.hp ? (a.hp > b.hp ? 0 : 1) : 'draw') : d0 ? 1 : 0;
}

// one shot; returns { fired, hit, flips }
function pylShot(s, p, acc) {
  const pl = P(s, p), wid = pl.guns[0], W = s.weapons[wid], wd = WD.WEAPONS[W.def];
  if (WD.shotsLeft(s, p, 0) < 1) { acc.why.noShots = (acc.why.noShots || 0) + 1; return null; }
  const sp = WD.shotPreview(s, p, 0, 0); if (!sp.inRange) { acc.why.range = (acc.why.range || 0) + 1; return null; }
  const steps = wd.melee ? (wd._pyl || [[1, 3]]).map(([h, d]) => [Math.max(1, h - pl.nextFire.reqMod), d + pl.dmgTurn]) : sp.steps;
  const st = { sum: 0, jams: 0, prec: pl.res.prec, steady: pl.revealPlus, recoil: sp.recoil, melee: false, flips: 0,
    bustAt: CFG.finalBust && WD.safeBounds(s).n <= CFG.finalSafe ? CFG.finalBust : CFG.bustAt }; // optional: the circle's pressure lowers the bust line
  if (!canFlip(st)) { acc.why.noPrec = (acc.why.noPrec || 0) + 1; return null; }
  const known = () => [pl.deck.map(i => [def(s, i).hit_markers, isJam(s, i)]), pl.discard.map(i => [def(s, i).hit_markers, isJam(s, i)])];
  const [dk0, dc0] = known(); const p1 = pReach(st, steps, 0, dk0, dc0);
  if (p1 < CFG.startMin) { acc.why.lowOdds = (acc.why.lowOdds || 0) + 1; return null; }
  // fire
  if (W.shots >= WD.eff(s, wid).magazine_capacity) pl.shot--; else W.shots++;
  const flipped = []; let res = null, lvl = -1, decided = -1, peek = CFG.peek && pl.rallyDone.includes('recon3') && !pl._peeked;
  const draw = () => { if (!pl.deck.length) { if (!pl.discard.length) return null; pl.deck = shuf(pl.discard); pl.discard = []; } return pl.deck.pop(); };
  for (let g = 0; g < 60; g++) {
    if (!canFlip(st)) { res = lvl >= 0 ? 'bank' : 'out'; break; }
    if (lvl >= 0 && lvl > decided) { // decision point: stop and bank, or push
      decided = lvl; acc.decisions++;
      let push;
      if (peek) { // Scope: look at the top card first
        pl._peeked = true; peek = false;
        if (!pl.deck.length && pl.discard.length) { pl.deck = shuf(pl.discard); pl.discard = []; }
        const top = pl.deck[pl.deck.length - 1];
        if (!top) push = false; else { const x = Object.assign({}, st); const b = applyFlip(x, def(s, top).hit_markers, isJam(s, top)); push = !b && (levelOf(steps, x.sum) > lvl || pReach(x, steps, lvl + 1, ...known().map((a, k) => k === 0 ? a.slice(0, -1) : a)) >= 1 - (T == null ? 0.4 : T)); }
      } else {
        const [dk, dc] = known();
        if (T == null) push = evPush(st, steps, lvl, dk, dc) > steps[lvl][1] + 0.05;
        else push = 1 - pReach(st, steps, lvl + 1, dk, dc) <= T;
      }
      if (!push) { res = 'bank'; break; }
      acc.pushes++; st.pushedFrom = lvl;
    }
    const c = draw(); if (c == null) { res = lvl >= 0 ? 'bank' : 'out'; break; }
    flipped.push(c); acc.flips++;
    const b = applyFlip(st, def(s, c).hit_markers, isJam(s, c));
    if (b) { res = 'bust'; break; }
    lvl = levelOf(steps, st.sum);
    if (lvl >= steps.length - 1) { res = 'bank'; break; }
  }
  if (!res) res = lvl >= 0 ? 'bank' : 'out';
  pl.res.prec = Math.max(0, st.prec); pl.revealPlus = st.steady;
  pl.nextFire = { reqMod: 0, bonusPrec: 0 };
  pl.discard.push(...flipped);
  pl.stats.shots++; acc.shots++; if (wd.melee) acc.meleeShots++;
  const hit = res === 'bank';
  if (st.pushedFrom != null) { if (hit && lvl > st.pushedFrom) acc.pushWins++; }
  if (hit) { pl.stats.hits++; acc.hits++; if (wd.melee) acc.meleeHits++; if (lvl === steps.length - 1 && steps.length > 1) acc.top++;
    const dealt = applyHit(s, 1 - p, steps[lvl][1], sp.cq); pl.stats.damageDealt += dealt; pl.stats.turnDmg += dealt; checkDeath(s); }
  else if (res === 'bust') acc.busts++; else acc.outs++;
  return { hit, flips: flipped.length };
}

function pylTurn(s, p, acc) {
  const pl = P(s, p); pl._peeked = false;
  WD.aiPlay(s, p); WD.aiMove(s, p); WD.aiBuy(s, p); WD.aiCycle(s, p);
  let shots = 0; for (let g = 0; g < 10 && !s.over; g++) { const r = pylShot(s, p, acc); if (!r) break; shots++; }
  if (shots) acc.shotTurns++;
  if (!s.over) { WD.aiScrap(s, p); WD.aiBuy(s, p); }
  if (s.over) return { ok: true };
  return WD.endTurn(s, p);
}

function cardCount(s) {
  const seen = new Map(); const note = (iid, w) => { if (seen.has(iid)) throw new Error(`card ${iid} in ${seen.get(iid)} and ${w}`); seen.set(iid, w); };
  s.players.forEach((pl, i) => ['deck', 'discard', 'hand', 'play', 'loadout', 'fuelled', 'removed'].forEach(z => pl[z].forEach(c => note(c, `p${i}.${z}`))));
  s.envs.forEach(e => e.loot.forEach(it => note(it.iid, 'env'))); [1, 2, 3].forEach(t => s.loot[t].forEach(it => note(it.iid, 'loot'))); s.gone.forEach(it => note(it.iid, 'gone'));
  s.players.forEach((pl, i) => pl.guns.filter(Boolean).forEach(w => note(w, 'gun')));
}
const jamShareOf = (s, pl) => { const all = pl.deck.concat(pl.discard, pl.hand, pl.play); return all.length ? all.filter(i => isJam(s, i)).length / all.length : 0; };

for (let i = 0; i < N; i++) {
  const aSeat = i % 2; const s = WD.newGame({ seed: i + 1 }); const first = s.first;
  const mode = k => k === 'aware' && force ? 'force:' + force : k;
  s.aiMode = aSeat === 0 ? [mode(aiA), mode(aiB)] : [mode(aiB), mode(aiA)];
  const ai = q => (q === aSeat ? aiA : aiB);
  let guard = 0;
  try {
    while (!s.over && guard++ < 400) {
      const p = s.turn, round = s.round, pl = P(s, p);
      const a0 = { shots: R.shots, hits: R.hits, flips: R.flips, dmg: pl.stats.damageDealt };
      const js = jamShareOf(s, pl);
      if (CFG.shipped) s.log.length = 0; // the log is UI-only; cleared so this turn's reveals can be counted
      const r = CFG.shipped ? WD.aiTurn(s, p) : pylTurn(s, p, R); if (!r.ok) throw new Error(r.err);
      if (CFG.shipped) { let fl = 0; for (const e of s.log) { const m = / reveals (\d+)/.exec(e.msg); if (m) fl += +m[1]; } R.flips += fl; if (fl) R.shotTurns++; }
      if (s.players.some(q => q.res.prec < 0 || q.res.intel < 0)) throw new Error('negative resource');
      R.turns++;
      const b = R.byRound[round] = R.byRound[round] || {}; const k = ai(p); const x = b[k] = b[k] || { fp: 0, n: 0, shots: 0, hits: 0, flips: 0, dmg: 0, jam: 0 };
      x.n++; x.fp += pl.fpHist[pl.fpHist.length - 1] || 0; x.shots += R.shots - a0.shots; x.hits += R.hits - a0.hits; x.flips += R.flips - a0.flips; x.dmg += pl.stats.damageDealt - a0.dmg; x.jam += js;
    }
    cardCount(s);
  } catch (e) { if (/card c|negative/.test(e.message)) R.inv++; else R.errors++; if (R.errors + R.inv <= 3) console.error(`seed ${i + 1}:`, e.stack); continue; }
  if (!s.over) { R.stuck++; continue; }
  R.rounds.push(s.round); R.endBy[s.endBy] = (R.endBy[s.endBy] || 0) + 1; if (s.finalReached) R.final++;
  if (s.winner === 'draw') R.draws++; else { R.decided++; if (s.winner === aSeat) R.aWins++; if (s.winner === first) R.firstWins++; }
  for (const pl of s.players) {
    if (CFG.shipped) { R.shots += pl.stats.shots; R.hits += pl.stats.hits; }
    R.shotDmg += pl.stats.damageDealt; R.gasDmg += pl.stats.gasTaken || 0;
    const g = WD.WEAPONS[s.weapons[pl.guns[0]].def].gunClass; R.gun[g] = R.gun[g] || [0, 0]; R.gun[g][1]++; if (s.winner === pl.idx) R.gun[g][0]++;
    const main = WD.mainSquad(s, pl.idx) || '-'; const k = `${main}:${ai(pl.idx)}`; R.fam[k] = R.fam[k] || [0, 0]; R.fam[k][1]++; if (s.winner === pl.idx) R.fam[k][0]++;
  }
}
const done = R.rounds.length; const pc = (a, b) => b ? +(a / b).toFixed(3) : null; const avg = a => a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : null;
const fmt = o => Object.fromEntries(Object.entries(o).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`]));
const gunRates = Object.values(R.gun).filter(v => v[1] >= 40).map(v => v[0] / v[1]);
const out = {
  games: N, match, variant: CFG.shipped ? 'shipped' : CFG.variant, policy: CFG.shipped ? 'planner' : CFG.policy, cfg: CFG.shipped ? null : { bustAt: CFG.bustAt, finalBust: CFG.finalBust, jamSet: CFG.variant === 'blank' ? '0-HM cards' : CFG.jamSet, steady: CFG.steady, peek: CFG.peek, ladders: CFG.ladders, startMin: CFG.startMin },
  completed: done, errors: R.errors, stuck: R.stuck, invariantFailures: R.inv,
  [`${aiA}WinRate`]: pc(R.aWins, R.decided), firstPlayerWinRate: pc(R.firstWins, R.decided), draws: R.draws,
  avgRounds: avg(R.rounds), maxRound: done ? Math.max(...R.rounds) : null, endBy: R.endBy, finalCircleReached: pc(R.final, done),
  hitRate: pc(R.hits, R.shots), hitRateExclMelee: pc(R.hits - R.meleeHits, R.shots - R.meleeShots),
  bustShare: pc(R.busts, R.shots), outOfPrecShare: pc(R.outs, R.shots), topStepShareOfHits: pc(R.top, R.hits),
  shotsPerGame: done ? +(R.shots / done).toFixed(1) : null, flipsPerShot: pc(R.flips, R.shots), flipsPerTurn: pc(R.flips, R.turns), flipsPerShootingTurn: pc(R.flips, R.shotTurns),
  decisionsPerShot: pc(R.decisions, R.shots), pushRate: pc(R.pushes, R.decisions), pushSuccess: pc(R.pushWins, R.pushes),
  gasShareOfDamage: pc(R.gasDmg, R.gasDmg + R.shotDmg), gunSpread: gunRates.length ? [+Math.min(...gunRates).toFixed(2), +Math.max(...gunRates).toFixed(2)] : null,
  whyStopped: Object.fromEntries(Object.entries(R.why).map(([k, v]) => [k, +(v / R.turns).toFixed(2)])), // per turn: why the AI fired no (more) shots
  winRateByGunHeldAtEnd: fmt(R.gun), winRateByMainSquad: fmt(R.fam),
};
console.log(JSON.stringify(out, null, 1));
if (opt('curve')) {
  const ks = [aiA, aiB].filter((x, i, a) => a.indexOf(x) === i);
  console.log('round | ' + ks.map(k => `${k}: Firepower / shots / hit% / flips / dmg / jam share of deck`).join(' | '));
  for (const r of Object.keys(R.byRound).map(Number).sort((a, b) => a - b)) console.log(String(r).padStart(5) + ' | ' + ks.map(k => { const x = R.byRound[r][k]; if (!x) return ''; return [x.fp / x.n, x.shots / x.n, x.shots ? 100 * x.hits / x.shots : 0, x.flips / x.n, x.dmg / x.n, 100 * x.jam / x.n].map(v => v.toFixed(1).padStart(5)).join(' ') + ` (n=${x.n})`; }).join(' | '));
}
