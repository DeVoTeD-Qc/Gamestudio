// Warbuilder package simulator (studio QA tool, board task wb-pkg1, 2026-11-11).
// Measures the shipped engine against the acceptance gates of documentation/design/wb-improve-v2.md §3:
//   build edge (aware vs random buyer) >= 85%, synergy edge (aware vs combo-blind) >= 55%, 8–9 rounds, final circle >= 50%,
//   own cards in hand >= 0.45 by round 6 (and the round-8 share), every squad 45–60% in the aware mirror.
// Unlike ai_sim_v2.js (sim-only rule patches), this tool plays the real rules with the engine's own AI (WD.aiTurn), so Squad
// Tactics, Spoils, Field Promotion and the Hot Drop delivery are all in.
//
//   node projects/warbuilder/qa/tools/ai_sim_pkg.js [games=1000] [--gates] [--a=aware --b=blind] [--set=hp:55,...] [--engine=path/to/engine.js]
//     --gates     run the three gate matchups (aware-random, aware-blind, aware-aware) and print the gate table (default)
//     --a / --b   one matchup: aware | blind | random (random = the engine's random-buyer control)
//     --set       TUNE overrides for tuning runs (numbers or true/false)
//     --engine    another engine file (e.g. an older copy, for a before/after table); it must have WD.aiTurn
'use strict';
const path = require('path');

const argv = process.argv.slice(2);
const opt = k => { const a = argv.find(x => x.startsWith('--' + k)); return a ? (a.includes('=') ? a.slice(a.indexOf('=') + 1) : true) : null; };
const N = +(argv.find(a => /^\d+$/.test(a)) || 1000);
const WD = require(opt('engine') ? path.resolve(String(opt('engine'))) : path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));
if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); WD.TUNE[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }

const isStarter = id => WD.CARDS[id] && WD.CARDS[id].archetype === 'starter';
const TACTICS = Object.values(WD.CARDS).filter(d => d.tactic).map(d => d.name);

function run(n, polA, polB) {
  const R = { n: 0, aWins: 0, draws: 0, rounds: 0, final: 0, acq: 0, starters: 0, spoils: 0, promoted: 0, errors: 0, hand: {}, dmg: {}, squad: {}, shots: 0, hits: 0, tactic: {}, owShots: 0, turretShots: 0, healed: 0 };
  for (let i = 0; i < n; i++) {
    const aSeat = i % 2; const s = WD.newGame({ seed: i + 1 });
    s.aiMode = aSeat === 0 ? [polA, polB] : [polB, polA];
    const push = s.log.push; s.log.push = function (e) { const m = / plays (.+?)(:|\.$)/.exec(e.msg); if (m && TACTICS.includes(m[1])) R.tactic[m[1]] = (R.tactic[m[1]] || 0) + 1; return push.call(this, e); };
    try {
      let g = 0;
      while (!s.over && g++ < 400) {
        const p = s.turn; const pl = s.players[p];
        if (p === aSeat) { const h = R.hand[s.round] = R.hand[s.round] || [0, 0]; h[0] += pl.hand.filter(x => !isStarter(s.cards[x].def)).length; h[1] += pl.hand.length; }
        const d0 = pl.stats.damageDealt, r0 = s.round;
        const r = WD.aiTurn(s, p); if (!r.ok) throw new Error(r.err);
        if (p === aSeat) { const d = R.dmg[r0] = R.dmg[r0] || [0, 0]; d[0] += pl.stats.damageDealt - d0; d[1]++; }
      }
      if (!s.over) throw new Error('stuck');
    } catch (e) { R.errors++; if (R.errors < 3) console.error(`seed ${i + 1}:`, e.message); continue; }
    R.n++; if (s.winner === aSeat) R.aWins++; else if (s.winner === 'draw') R.draws++;
    R.rounds += s.round; R.final += s.finalReached ? 1 : 0;
    const pl = s.players[aSeat]; const all = pl.deck.concat(pl.discard, pl.hand, pl.play, pl.loadout, pl.drop || []);
    R.acq += pl.stats.cardsAcquired; R.starters += all.filter(x => isStarter(s.cards[x].def)).length;
    R.spoils += pl.stats.spoils || 0; R.promoted += pl.stats.promoted || 0; R.owShots += pl.stats.owShots || 0; R.turretShots += pl.stats.turretShots || 0; R.healed += pl.stats.healed || 0;
    for (const q of s.players) { R.shots += q.stats.shots; R.hits += q.stats.hits;
      const m = WD.mainSquad(s, q.idx) || '-'; const k = R.squad[m] = R.squad[m] || [0, 0]; k[1]++; if (s.winner === q.idx) k[0]++; }
  }
  const k = R.n || 1; const f = (x, d = 2) => +x.toFixed(d);
  return { a: polA, b: polB, games: R.n, errors: R.errors, aWin: f(R.aWins / k, 3), draws: R.draws, rounds: f(R.rounds / k), finalCircle: f(R.final / k),
    cardsAcquired: f(R.acq / k, 1), startersAtEnd: f(R.starters / k, 1), spoils: f(R.spoils / k, 1), promoted: f(R.promoted / k, 1), hitRate: f(R.hits / Math.max(1, R.shots), 3),
    overwatchShots: f(R.owShots / k), turretShots: f(R.turretShots / k), healed: f(R.healed / k, 1),
    ownHand: Object.fromEntries(Object.entries(R.hand).map(([r, v]) => [r, f(v[0] / v[1])])),
    dmgPerTurn: Object.fromEntries(Object.entries(R.dmg).map(([r, v]) => [r, f(v[0] / v[1], 1)])),
    squadWin: Object.fromEntries(Object.entries(R.squad).sort().map(([q, v]) => [q, `${f(v[0] / v[1], 3)} (n=${v[1]})`])),
    tacticPlays: Object.fromEntries(Object.entries(R.tactic).sort((a, b) => b[1] - a[1]).map(([t, v]) => [t, f(v / k)])) };
}

function gates(n) {
  const hasRandom = (() => { try { const s = WD.newGame({ seed: 1 }); s.aiMode = ['random', 'random']; for (let g = 0; g < 6; g++) WD.aiTurn(s, s.turn); return s.players.some(p => p.stats.cardsAcquired > 0) && WD.aiBuy.toString().includes('random'); } catch (e) { return false; } })();
  const ar = hasRandom ? run(n, 'aware', 'random') : null, ab = run(n, 'aware', 'blind'), aa = run(n, 'aware', 'aware');
  const sq = Object.entries(aa.squadWin).filter(([q]) => q !== '-').map(([q, v]) => [q, parseFloat(v)]);
  const G = [
    ['Build edge (aware vs random buyer)', ar ? ar.aWin : null, x => x >= 0.85, '>= 85%'],
    ['Synergy edge (aware vs combo-blind)', ab.aWin, x => x >= 0.55, '>= 55%'],
    ['Rounds (aware mirror)', aa.rounds, x => x >= 8 && x <= 9, '8–9'],
    ['Final circle reached', aa.finalCircle, x => x >= 0.5, '>= 50%'],
    ['Own cards in hand, round 6', aa.ownHand[6], x => x >= 0.45, '>= 0.45'],
    ['Own cards in hand, round 8', aa.ownHand[8], x => x >= 0.5, '(report; >= 0.50 wanted)'],
    ['Squads in the mirror (win rate by main squad)', sq.map(([q, v]) => `${q} ${v}`).join(', '), () => sq.every(([, v]) => v >= 0.45 && v <= 0.6), 'each 45–60%'],
    ['Hit rate of shots taken', aa.hitRate, x => x >= 0.6 && x <= 0.7, '60–70% (head\'s target)'],
  ];
  return { games: n, tune: { hp: WD.TUNE.hp }, gates: G.map(([label, v, ok, target]) => ({ label, value: v, target, pass: v == null ? null : ok(v) })), runs: { awareVsRandom: ar, awareVsBlind: ab, mirror: aa } };
}

if (require.main === module) {
  const out = opt('a') ? run(N, opt('a'), opt('b') || 'blind') : gates(N);
  console.log(JSON.stringify(out, null, 1));
  if (out.gates) for (const g of out.gates) console.error(`${g.pass == null ? ' n/a' : g.pass ? '  ok' : 'MISS'}  ${g.label.padEnd(46)} ${String(g.value).padEnd(48)} ${g.target}`);
}
module.exports = { run, gates };
