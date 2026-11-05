// Warbuilder BUST VARIANTS for push-your-luck FIRE (studio QA tool, board task wb-bust, 2026-11-05).
// Design: projects/warbuilder/documentation/design/bust-variants.md   (base rule: push-your-luck-shooting.md, sim: ai_sim_pyl.js)
//
// Same harness as ai_sim_pyl.js: the engine runs play, Squad, Rally, Loadout, move, loot, scrap, gas, final circle and its own AI;
// only the shooting part of the turn is replaced. By default it loads a FROZEN copy of the pre-PYL engine
// (qa/tools/fixtures/engine_pre_pyl.js, copied from source/ on 2026-11-05 before the PYL build started), so results do not move
// while mechanics-developer edits source/. --engine=<path> loads another engine file. Nothing in source/ is written.
//
// Modes (--mode=). In the three bust variants the Jam limit is 2 (1 in the final circle), +1 for each Rally you made this turn.
//   hotzone   today's approved rule (V2): Jams count per shot; 2nd Jam in a shot misses (1st in the final circle); hits deal at once.
//   firefight A: one flip stream for the whole turn. Each banked shot goes into your POT (not dealt yet). Jams count for the turn;
//             at the Jam limit you BUST: the pot is lost. STOP (or run out of shots/Precision) = cash out the pot.
//   heat      B: hits deal at once, but Jams count for the turn as Heat; at the limit you OVERHEAT: this shot misses, your shooting
//             ends, and you pay a penalty (--pen=hp|shot|mark|loadout; default hp = lose penHp Health).
//   hothand   C: firefight, and every Jam you flip and survive adds +jamBonus damage to that shot.
//   Knobs: --set=scope:shot (Jams count per shot, the pot stays: "pot" variant), rallyPlus:0 (no Rally hook), carry:N (Heat stays
//   on the gun between turns and cools N per turn), streak:N (+N per extra shot in a cashed pot).
//   node projects/warbuilder/qa/tools/ai_sim_bust.js [games=2000] [options]
//     --mode=hotzone|firefight|heat|hothand
//     --match=aware-blind | aware-aware | blind-blind
//     --policy=timid|cautious|normal|bold|reckless|ev   both AIs. Push inside a shot when the chance the push does not reach the next
//                                           step is <= 0/20/35/50/100 % (as ai_sim_pyl.js); fire another shot into a pot / into Heat
//                                           when the chance it busts first is <= the same %. ev = maximise expected damage (pot at stake).
//     --pa=<policy> --pb=<policy>           per-AI policy (first / second name in --match); use with --match=aware-aware
//     --pen=hp|shot|mark|loadout            heat: overheat penalty (hp: lose penHp Health; shot: next turn 1 fewer shot;
//                                           mark: the rival's next shot gets a free Mark; loadout: your Loadout skips its next Ready)
//     --hot=none|t3|t23                     Hot cards: tier III (t3) or tier II+III (t23) squad cards carry a Jam AND +hotDmg damage
//     --set=key:value,...                   override CFG (limit, finalLimit, jamBonus, penHp, hotDmg, dmgPlus, ...)
//     --flat  --curve  --engine=<path>
'use strict';
const path = require('path');
const argv = process.argv.slice(2);
const N = +(argv.find(a => /^\d+$/.test(a)) || 2000);
const opt = k => { const a = argv.find(x => x.startsWith('--' + k + '=') || x === '--' + k); return a ? (a.includes('=') ? a.slice(a.indexOf('=') + 1) : true) : null; };
const WD = require(opt('engine') ? path.resolve(String(opt('engine'))) : path.join(__dirname, 'fixtures', 'engine_pre_pyl.js'));

const MODE = opt('mode') || 'hotzone';
const DEF = {
  hotzone: { scope: 'shot', pot: false, limit: 2, finalLimit: 1, jamBonus: 0, rallyPlus: 0 },
  firefight: { scope: 'turn', pot: true, limit: 2, finalLimit: 1, jamBonus: 0, rallyPlus: 1 },
  heat: { scope: 'turn', pot: false, limit: 2, finalLimit: 1, jamBonus: 0, rallyPlus: 1 },
  hothand: { scope: 'turn', pot: true, limit: 2, finalLimit: 1, jamBonus: 1, rallyPlus: 1 },
}[MODE];
if (!DEF) throw new Error('unknown --mode ' + MODE);
const CFG = Object.assign({
  pen: opt('pen') || 'hp', penHp: 3, hot: opt('hot') || 'none', hotDmg: 1,
  tune: '', rallyMax: 9, carry: 0, streak: 0, risk: 'fail', flipCost: 1, startMin: 0.05, trials: 150, dmgPlus: 0, peek: true, finalSafe: 1,
}, DEF);
if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); CFG[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }
const POLICY = { timid: 0, cautious: 0.20, normal: 0.35, bold: 0.50, reckless: 1, ev: null }; // timid: never risks a bust; reckless: always pushes and continues
const match = opt('match') || 'aware-blind';
const [aiA, aiB] = match.split('-');
const polA = opt('pa') || opt('policy') || 'normal', polB = opt('pb') || opt('policy') || 'normal';
if (!(polA in POLICY) || !(polB in POLICY)) throw new Error('unknown policy');
if (opt('flat')) { WD.TUNE.squadCap = 0; WD.TUNE.rally = []; }

// ---------- Jam icons (Sprint, Scout) and Hot cards ----------
const JAM = new Set(['T001', 'T002']);
const HOT = new Set();
if (CFG.hot !== 'none') for (const id in WD.CARDS) { const d = WD.CARDS[id]; if (d.loadout || !['assault', 'recon', 'support', 'engineer'].includes(d.archetype)) continue; if (d.tier === 3 || (CFG.hot === 't23' && d.tier === 2)) { JAM.add(id); HOT.add(id); } }

// ---------- gun ladders: identical to ai_sim_pyl.js LADDERS.final (the approved PYL ladders) ----------
const LAD = {
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
// --set=tune:pot : per-class retune for the pot variants (a bust loses several small shots, so the multi-shot guns need more per shot)
const TUNES = { pot: { smg: [[2, 3], [4, 5], [6, 7]], lmg: [[3, 4], [5, 6], [7, 9]], revolver: [[2, 3], [5, 7], [7, 10]], shotgun: [[2, 4], [4, 6], [6, 8]] } };
if (CFG.tune && TUNES[CFG.tune]) for (const k in TUNES[CFG.tune]) LAD[k].ladder = TUNES[CFG.tune][k];
for (const id in WD.WEAPONS) {
  const w = WD.WEAPONS[id]; const g = LAD[w.gunClass]; if (!g) continue;
  const base = WD.GUNCLASS[w.gunClass].ladder; const dn = w.ladder[0][0] - base[0][0], dd = w.ladder[0][1] - base[0][1];
  w.ladder = g.ladder.map(([h, d], i) => [w.melee ? 0 : Math.max(1, h + dn), d + dd + (i ? CFG.dmgPlus : 0)]);
  w._pyl = g.ladder.map(([h, d], i) => [Math.max(1, h + dn), d + dd + (i ? CFG.dmgPlus : 0)]);
  if (g.recoil != null) w.recoil = g.recoil;
}

const P = (s, i) => s.players[i];
const def = (s, iid) => WD.CARDS[s.cards[iid].def];
const card = (s, iid) => { const d = WD.CARDS[s.cards[iid].def]; return [d.hit_markers, JAM.has(d.id), HOT.has(d.id)]; };
function lcg(seed) { let x = seed | 0; return () => { x = (x * 1103515245 + 12345) & 0x7fffffff; return x / 0x7fffffff; }; }
const mc = lcg(4242);
const shuf = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(mc() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// st = { sum, jams, prec, steady, recoil, limit, bonus } ; returns 'bust' or null
function applyFlip(st, c) {
  const [hm, jam, hot] = c;
  st.prec -= CFG.flipCost; st.sum += hm;
  if (hot) st.bonus += CFG.hotDmg;
  if (jam) {
    if (st.steady > 0) { st.steady--; return null; }
    st.jams++; st.prec = Math.max(0, st.prec - st.recoil);
    if (st.jams >= st.limit) return 'bust';
    st.bonus += CFG.jamBonus;
  }
  return null;
}
const canFlip = st => st.prec >= CFG.flipCost;
const levelOf = (steps, sum) => { let l = -1; for (const [h] of steps) if (sum >= h) l++; return l; };
// Monte Carlo from state st: chance to reach step `goal`, chance to bust first (the rest: run out of Precision/cards)
function odds(st, steps, goal, dk, dc) {
  let ok = 0, bust = 0;
  for (let t = 0; t < CFG.trials; t++) {
    const seq = shuf(dk.slice()).concat(shuf(dc.slice())); const x = Object.assign({}, st); let i = 0;
    while (i < seq.length && canFlip(x)) { if (applyFlip(x, seq[i++])) { bust++; break; } if (levelOf(steps, x.sum) >= goal) { ok++; break; } }
  }
  return { reach: ok / CFG.trials, bust: bust / CFG.trials };
}

const R = { errors: 0, stuck: 0, inv: 0, decided: 0, draws: 0, aWins: 0, firstWins: 0, rounds: [], endBy: {}, final: 0, shotDmg: 0, gasDmg: 0, selfDmg: 0, gun: {}, fam: {},
  shots: 0, banked: 0, delivered: 0, busts: 0, outs: 0, flips: 0, decisions: 0, pushes: 0, pushWins: 0, conts: 0, cashes: 0, turns: 0, shotTurns: 0,
  bustTurns: 0, lostDmg: 0, cashN: 0, cashShots: 0, wipeTurns: 0, zeroTurns: 0, potLost: 0, turnDmg: [], byRound: {}, comebacks: 0, comebackChances: 0, leadChanges: 0, bigTurns: 0, side: {} };

function applyHit(s, ti, dmg, cq) { // engine applyHit: best Reaction in hand, then Armor (not at close quarters)
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

// the whole shooting part of one turn
function shootTurn(s, p, T) {
  const pl = P(s, p); const wd = WD.WEAPONS[s.weapons[pl.guns[0]].def];
  const final = WD.safeBounds(s).n <= CFG.finalSafe; const limit = (final ? CFG.finalLimit : CFG.limit) + (CFG.rallyPlus ? CFG.rallyPlus * Math.min(CFG.rallyMax, pl.rallyDone.length) : 0); // rallyPlus: each Rally this turn raises the Jam limit
  const known = () => [pl.deck.map(i => card(s, i)), pl.discard.map(i => card(s, i))];
  const draw = () => { if (!pl.deck.length) { if (!pl.discard.length) return null; pl.deck = shuf(pl.discard); pl.discard = []; } return pl.deck.pop(); };
  if (CFG.carry) pl.heat = Math.max(0, (pl.heat || 0) - CFG.carry);
  const pot = []; let tj = CFG.carry ? pl.heat : 0, potBonus = 0, shots = 0, busted = false, reached = false, dealt = 0, peek = CFG.peek && pl.rallyDone.includes('recon3');
  const potValue = () => pot.reduce((a, x) => a + x.dmg, 0) + potBonus + CFG.streak * Math.max(0, pot.length - 1);
  const deal = (dmg, cq) => { const d = applyHit(s, 1 - p, dmg, cq); pl.stats.damageDealt += d; pl.stats.turnDmg += d; dealt += d; R.delivered++; checkDeath(s); };
  for (let g = 0; g < 10 && !s.over; g++) {
    if (WD.shotsLeft(s, p, 0) < 1) break;
    const sp = WD.shotPreview(s, p, 0, 0); if (!sp.inRange) break;
    const steps = wd.melee ? wd._pyl.map(([h, d]) => [Math.max(1, h - pl.nextFire.reqMod), d + pl.dmgTurn]) : sp.steps;
    const st = { sum: 0, jams: CFG.scope === 'turn' ? tj : 0, prec: pl.res.prec, steady: pl.revealPlus, recoil: sp.recoil, limit, bonus: 0 };
    if (!canFlip(st)) break;
    const [dk0, dc0] = known(); const o0 = odds(st, steps, 0, dk0, dc0);
    if (o0.reach < CFG.startMin) break;
    // between shots: is the next shot worth the risk to what you already have?
    if (shots > 0 && (CFG.pot || CFG.scope === 'turn')) {
      const stake = CFG.pot ? potValue() : (CFG.pen === 'hp' ? CFG.penHp : 3);
      R.decisions++;
      const go = T == null ? o0.reach * steps[0][1] > o0.bust * stake : o0.bust <= T;
      if (!go) { R.cashes++; break; }
      R.conts++;
    }
    const W = s.weapons[pl.guns[0]]; if (W.shots >= WD.eff(s, pl.guns[0]).magazine_capacity) pl.shot--; else W.shots++;
    shots++; R.shots++; pl.stats.shots++;
    const flipped = []; let res = null, lvl = -1, decided = -1, pushedFrom = null;
    for (let k = 0; k < 60; k++) {
      if (!canFlip(st)) { res = lvl >= 0 ? 'bank' : 'out'; break; }
      if (lvl >= 0 && lvl > decided) { // stop-or-push
        decided = lvl; R.decisions++;
        const [dk, dc] = known(); let push;
        const cur = steps[lvl][1] + st.bonus, nxt = steps[lvl + 1][1] + st.bonus;
        if (peek) { // Recon Rally 3 Scope: look at the top card before choosing (once per turn)
          peek = false; if (!pl.deck.length && pl.discard.length) { pl.deck = shuf(pl.discard); pl.discard = []; }
          const top = pl.deck[pl.deck.length - 1]; push = !!top && !applyFlip(Object.assign({}, st), card(s, top)); // push unless the top card busts you
        } else {
          const o = odds(st, steps, lvl + 1, dk, dc);
          if (T == null) {
            const lose = CFG.pot ? potValue() + cur : CFG.scope === 'turn' ? cur + (CFG.pen === 'hp' ? CFG.penHp : 3) : cur;
            push = o.reach * (nxt - cur) > o.bust * lose;
          } else push = (CFG.risk === 'bust' ? o.bust : 1 - o.reach) <= T; // 'fail' (default, as ai_sim_pyl.js): the push may not reach the next step
        }
        if (!push) { res = 'bank'; break; }
        R.pushes++; pushedFrom = lvl;
      }
      const c = draw(); if (c == null) { res = lvl >= 0 ? 'bank' : 'out'; break; }
      flipped.push(c); R.flips++;
      if (applyFlip(st, card(s, c))) { res = 'bust'; break; }
      lvl = levelOf(steps, st.sum); if (lvl >= 0) reached = true;
      if (lvl >= steps.length - 1) { res = 'bank'; break; }
    }
    pl.res.prec = Math.max(0, st.prec); pl.revealPlus = st.steady; pl.nextFire = { reqMod: 0, bonusPrec: 0 };
    pl.discard.push(...flipped);
    if (CFG.scope === 'turn') tj = st.jams;
    if (pushedFrom != null && res === 'bank' && lvl > pushedFrom) R.pushWins++;
    if (res === 'bank') {
      R.banked++; pl.stats.hits++;
      if (CFG.pot) { pot.push({ dmg: steps[lvl][1] + st.bonus, cq: sp.cq }); }
      else deal(steps[lvl][1] + st.bonus, sp.cq);
    } else if (res === 'bust') { R.busts++; busted = true; if (lvl >= 0) R.lostDmg += steps[lvl][1] + st.bonus; if (CFG.scope === 'turn' || CFG.pot) break; } // hotzone: only this shot misses
    else { R.outs++; if (!canFlip(st)) break; }
  }
  if (CFG.carry) pl.heat = busted ? 0 : tj;
  // cash out (pot modes) or pay the overheat penalty
  if (CFG.pot) {
    if (busted) { R.potLost += potValue(); R.lostDmg += potValue(); pl.stats.hits -= pot.length; }
    else { if (pot.length) { R.cashN++; R.cashShots += pot.length; } if (pot.length > 1) pot[pot.length - 1].dmg += CFG.streak * (pot.length - 1); for (const x of pot) { if (s.over) break; deal(x.dmg, x.cq); } }
  } else if (busted && CFG.scope === 'turn') {
    if (CFG.pen === 'hp') { pl.hp -= CFG.penHp; pl.stats.selfDmg = (pl.stats.selfDmg || 0) + CFG.penHp; checkDeath(s); }
    else pl._overheat = CFG.pen;
  }
  return { shots, busted, reached, dealt };
}

function pylTurn(s, p, T) {
  const pl = P(s, p), o = P(s, 1 - p);
  // pending penalties from an overheat
  if (pl._overheat === 'shot') { s.weapons[pl.guns[0]].shots += 1; pl._overheat = null; }
  if (o._overheat === 'mark') { pl.nextFire.reqMod += 1; o._overheat = null; }
  WD.aiPlay(s, p); WD.aiMove(s, p); WD.aiBuy(s, p); WD.aiCycle(s, p);
  const r = shootTurn(s, p, T);
  if (!s.over) { WD.aiScrap(s, p); WD.aiBuy(s, p); }
  if (s.over) return { ok: true, r };
  // loadout penalty: hide the Loadout through my next Ready (it runs inside the rival's endTurn), restore after
  return Object.assign(WD.endTurn(s, p), { r });
}

function cardCount(s) {
  const seen = new Map(); const note = (iid, w) => { if (seen.has(iid)) throw new Error(`card ${iid} in ${seen.get(iid)} and ${w}`); seen.set(iid, w); };
  s.players.forEach((pl, i) => ['deck', 'discard', 'hand', 'play', 'loadout', 'fuelled', 'removed'].forEach(z => pl[z].forEach(c => note(c, `p${i}.${z}`))));
  s.envs.forEach(e => e.loot.forEach(it => note(it.iid, 'env'))); [1, 2, 3].forEach(t => s.loot[t].forEach(it => note(it.iid, 'loot'))); s.gone.forEach(it => note(it.iid, 'gone'));
  s.players.forEach(pl => pl.guns.filter(Boolean).forEach(w => note(w, 'gun')));
}
const jamShareOf = (s, pl) => { const all = pl.deck.concat(pl.discard, pl.hand, pl.play); return all.length ? all.filter(i => JAM.has(def(s, i).id)).length / all.length : 0; };

for (let i = 0; i < N; i++) {
  const aSeat = i % 2; const s = WD.newGame({ seed: i + 1 }); const first = s.first;
  s.aiMode = aSeat === 0 ? [aiA, aiB] : [aiB, aiA];
  const side = q => (q === aSeat ? 'A' : 'B');
  const pol = q => POLICY[side(q) === 'A' ? polA : polB];
  let guard = 0, lastSign = 0, maxDef = [0, 0], prevRound = s.round;
  try {
    while (!s.over && guard++ < 400) {
      const p = s.turn, round = s.round, pl = P(s, p), o = P(s, 1 - p);
      const js = jamShareOf(s, pl); const hp0 = o.hp;
      // loadout penalty: if I overheated with pen=loadout, my Loadout must skip my next Ready (inside the rival's endTurn)
      let stash = null;
      if (o._overheat === 'loadout') { stash = o.loadout; o.loadout = []; o._overheat = null; }
      const res = pylTurn(s, p, pol(p)); if (!res.ok) throw new Error(res.err);
      if (stash) o.loadout = stash;
      if (s.players.some(q => q.res.prec < 0 || q.res.intel < 0)) throw new Error('negative resource');
      R.turns++;
      const r = res.r; const sd = R.side[side(p)] = R.side[side(p)] || { turns: 0, dmg: 0, busts: 0, shotTurns: 0 };
      sd.turns++;
      if (r && r.shots) {
        R.shotTurns++; sd.shotTurns++; R.turnDmg.push(r.dealt); sd.dmg += r.dealt;
        if (r.busted) { R.bustTurns++; sd.busts++; }
        if (r.reached && r.dealt === 0) R.wipeTurns++;
        if (r.dealt === 0) R.zeroTurns++;
        if (r.dealt >= 12) R.bigTurns++;
      }
      const b = R.byRound[round] = R.byRound[round] || {}; const k = aiA === aiB ? side(p) : (side(p) === 'A' ? aiA : aiB); const x = b[k] = b[k] || { n: 0, st: 0, dmg: 0, bust: 0, jam: 0 };
      x.n++; x.jam += js; if (r && r.shots) { x.st++; x.dmg += r.dealt; if (r.busted) x.bust++; }
      // lead tracking at each turn end (HP difference from seat A's view)
      const A = P(s, aSeat), B = P(s, 1 - aSeat); const diff = A.hp - B.hp; const sg = Math.sign(diff);
      if (sg && lastSign && sg !== lastSign) R.leadChanges++; if (sg) lastSign = sg;
      if (s.round !== prevRound || s.over) { maxDef[0] = Math.max(maxDef[0], B.hp - A.hp); maxDef[1] = Math.max(maxDef[1], A.hp - B.hp); prevRound = s.round; }
    }
    cardCount(s);
  } catch (e) { if (/card c|negative/.test(e.message)) R.inv++; else R.errors++; if (R.errors + R.inv <= 3) console.error(`seed ${i + 1}:`, e.stack); continue; }
  if (!s.over) { R.stuck++; continue; }
  R.rounds.push(s.round); R.endBy[s.endBy] = (R.endBy[s.endBy] || 0) + 1; if (s.finalReached) R.final++;
  if (s.winner === 'draw') R.draws++; else {
    R.decided++; if (s.winner === aSeat) R.aWins++; if (s.winner === first) R.firstWins++;
    const wDef = s.winner === aSeat ? maxDef[0] : maxDef[1]; // the winner's largest deficit at a round end
    if (Math.max(maxDef[0], maxDef[1]) >= 8) { R.comebackChances++; if (wDef >= 8) R.comebacks++; }
  }
  for (const pl of s.players) {
    R.shotDmg += pl.stats.damageDealt; R.gasDmg += pl.stats.gasTaken || 0; R.selfDmg += pl.stats.selfDmg || 0;
    const g = WD.WEAPONS[s.weapons[pl.guns[0]].def].gunClass; R.gun[g] = R.gun[g] || [0, 0]; R.gun[g][1]++; if (s.winner === pl.idx) R.gun[g][0]++;
    const main = WD.mainSquad(s, pl.idx) || '-'; const kk = `${main}:${side(pl.idx)}`; R.fam[kk] = R.fam[kk] || [0, 0]; R.fam[kk][1]++; if (s.winner === pl.idx) R.fam[kk][0]++;
  }
}
const done = R.rounds.length; const pc = (a, b) => b ? +(a / b).toFixed(3) : null; const avg = a => a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : null;
const td = R.turnDmg; const m = td.reduce((a, b) => a + b, 0) / (td.length || 1); const sdv = Math.sqrt(td.reduce((a, b) => a + (b - m) ** 2, 0) / (td.length || 1));
const gunRates = Object.values(R.gun).filter(v => v[1] >= 40).map(v => v[0] / v[1]);
const out = {
  games: N, match, mode: MODE, policy: polA === polB ? polA : `${polA} vs ${polB}`, cfg: { limit: CFG.limit, finalLimit: CFG.finalLimit, pot: CFG.pot, scope: CFG.scope, jamBonus: CFG.jamBonus, streak: CFG.streak, carry: CFG.carry, rallyPlus: CFG.rallyPlus, pen: MODE === 'heat' ? CFG.pen + (CFG.pen === 'hp' ? CFG.penHp : '') : null, hot: CFG.hot, tune: CFG.tune || null, dmgPlus: CFG.dmgPlus },
  completed: done, errors: R.errors, stuck: R.stuck, invariantFailures: R.inv,
  [`A(${aiA}${polA !== polB ? ',' + polA : ''})WinRate`]: pc(R.aWins, R.decided), firstPlayerWinRate: pc(R.firstWins, R.decided), draws: R.draws,
  avgRounds: avg(R.rounds), maxRound: done ? Math.max(...R.rounds) : null, endBy: R.endBy, finalCircleReached: pc(R.final, done),
  bankRate: pc(R.banked, R.shots), hitRate: pc(R.delivered, R.shots), bustShareOfShots: pc(R.busts, R.shots), outShareOfShots: pc(R.outs, R.shots),
  bustPerShootingTurn: pc(R.bustTurns, R.shotTurns), wipePerShootingTurn: pc(R.wipeTurns, R.shotTurns), zeroDmgShootingTurn: pc(R.zeroTurns, R.shotTurns),
  dmgPerShootingTurn: +m.toFixed(2), dmgSD: +sdv.toFixed(2), dmgCV: +(sdv / (m || 1)).toFixed(2), bigTurns12plus: pc(R.bigTurns, R.shotTurns), lostShareOfShotDmg: pc(R.lostDmg, R.lostDmg + R.shotDmg), potLostPerBust: R.bustTurns && MODE !== 'heat' && MODE !== 'hotzone' ? +(R.potLost / R.bustTurns).toFixed(2) : null,
  shotsPerShootingTurn: pc(R.shots, R.shotTurns), potShotsPerCash: R.cashN ? +(R.cashShots / R.cashN).toFixed(2) : null, flipsPerTurn: pc(R.flips, R.turns), flipsPerShootingTurn: pc(R.flips, R.shotTurns), decisionsPerShootingTurn: pc(R.decisions, R.shotTurns),
  pushRate: pc(R.pushes, R.pushes + R.decisions - R.pushes - R.conts - R.cashes), pushSuccess: pc(R.pushWins, R.pushes), continueRate: pc(R.conts, R.conts + R.cashes),
  gasShareOfDamage: pc(R.gasDmg, R.gasDmg + R.shotDmg), selfDmgPerGame: done ? +(R.selfDmg / done).toFixed(2) : null,
  gunSpread: gunRates.length ? [+Math.min(...gunRates).toFixed(2), +Math.max(...gunRates).toFixed(2)] : null,
  comebackRate: pc(R.comebacks, R.comebackChances), leadChangesPerGame: done ? +(R.leadChanges / done).toFixed(2) : null,
  sides: Object.fromEntries(Object.entries(R.side).map(([k, v]) => [k, { dmgPerShootingTurn: +(v.dmg / v.shotTurns).toFixed(2), bustPerShootingTurn: +(v.busts / v.shotTurns).toFixed(3) }])),
  winRateByGunHeldAtEnd: Object.fromEntries(Object.entries(R.gun).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`])),
};
console.log(JSON.stringify(out, null, 1));
if (opt('curve')) {
  const ks = Object.keys(Object.values(R.byRound)[0] || {}).sort();
  console.log('round | ' + ks.map(k => `${k}: dmg/shooting turn · bust% · jam share`).join(' | '));
  for (const r of Object.keys(R.byRound).map(Number).sort((a, b) => a - b)) console.log(String(r).padStart(5) + ' | ' + ks.map(k => { const x = R.byRound[r][k]; if (!x) return ''; return [x.st ? x.dmg / x.st : 0, x.st ? 100 * x.bust / x.st : 0, 100 * x.jam / x.n].map(v => v.toFixed(1).padStart(5)).join(' ') + ` (n=${x.n})`; }).join(' | '));
}
