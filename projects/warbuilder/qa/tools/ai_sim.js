// Warbuilder headless AI-vs-AI simulator (studio QA tool, wb-assess, 2026-11-04).
// Runs the shipped rules engine in Node with no browser and reports balance and pacing numbers.
// It only reads the engine; it does not change the game source.
//
//   node projects/warbuilder/qa/tools/ai_sim.js [games=2000] [ablate]
//   ablate (optional, applies to player 1): nocards | mono | assault | recon | support | engineer | nosyn
//
// Prototype for the rules test harness proposed in documentation/technical/tech-review.md.
'use strict';
const path = require('path');
const WD = require(path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));

const N = +process.argv[2] || 2000;
const ablate = process.argv[3] || null;
WD.TUNE.ablate = ablate ? { 1: ablate } : null;

const avg = a => a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : null;
const out = { games: N, ablate, errors: 0, stuck: 0, invariantFailures: 0, p1Wins: 0, firstPlayerWins: 0, draws: 0,
  rounds: [], shots: 0, hits: 0, shotDmg: 0, gasDmg: 0, gamesWithGasDamage: 0, safeAtEnd: [], newGroundLeft: [], gunWin: {} };

function cardCount(s) { // every card instance must be in exactly one place
  const seen = new Map();
  const note = (iid, where) => { if (seen.has(iid)) throw new Error(`card ${iid} in ${seen.get(iid)} and ${where}`); seen.set(iid, where); };
  s.players.forEach((pl, i) => ['deck', 'discard', 'hand', 'play', 'fuelled', 'removed'].forEach(z => pl[z].forEach(c => note(c, `p${i}.${z}`))));
  s.envs.forEach(e => e.loot.forEach(it => it.kind === 'card' && note(it.iid, `env${e.w}`)));
  [1, 2, 3].forEach(t => s.loot[t].forEach(it => it.kind === 'card' && note(it.iid, `loot${t}`)));
}

for (let i = 0; i < N; i++) {
  const s = WD.newGame({ seed: i + 1 }); const first = s.first;
  let guard = 0;
  try {
    while (!s.over && guard++ < 400) {
      const r = WD.aiTurn(s, s.turn); if (!r.ok) throw new Error(r.err);
      if (s.players.some(p => p.res.intel < 0 || p.res.move < 0 || p.res.prec < 0)) throw new Error('negative resource');
    }
    cardCount(s);
  } catch (e) { if (/card c/.test(e.message) || /negative/.test(e.message)) out.invariantFailures++; else out.errors++; if (out.errors + out.invariantFailures <= 3) console.error(`seed ${i + 1}:`, e.message); continue; }
  if (!s.over) { out.stuck++; continue; }
  if (s.winner === 'draw') out.draws++; else { if (s.winner === 1) out.p1Wins++; if (s.winner === first) out.firstPlayerWins++; }
  out.rounds.push(s.round);
  for (const pl of s.players) {
    out.shots += pl.stats.shots; out.hits += pl.stats.hits; out.shotDmg += pl.stats.damageDealt;
    const g = WD.WEAPONS[s.weapons[pl.guns[0]].def].gunClass; out.gunWin[g] = out.gunWin[g] || [0, 0]; out.gunWin[g][1]++; if (s.winner === pl.idx) out.gunWin[g][0]++;
  }
  let gas = 0; for (const l of s.log) { const m = l.msg.match(/gas: −(\d+)/); if (m) gas += +m[1]; const f = l.msg.match(/storm hits both operators for (\d+)/); if (f) gas += 2 * f[1]; }
  out.gasDmg += gas; if (gas) out.gamesWithGasDamage++;
  out.safeAtEnd.push(WD.safeBounds(s).n); out.newGroundLeft.push(s.envDeck.length);
}
const done = out.rounds.length; const decided = done - out.draws;
console.log(JSON.stringify({
  games: N, ablate, completed: done, errors: out.errors, stuck: out.stuck, invariantFailures: out.invariantFailures,
  p1WinRate: +(out.p1Wins / decided).toFixed(3), firstPlayerWinRate: +(out.firstPlayerWins / decided).toFixed(3), draws: out.draws,
  avgRounds: avg(out.rounds), hitRate: +(out.hits / out.shots).toFixed(3), shotsPerGame: +(out.shots / done).toFixed(1),
  gasShareOfDamage: +(out.gasDmg / (out.gasDmg + out.shotDmg)).toFixed(3), gamesWithGasDamage: +(out.gamesWithGasDamage / done).toFixed(3),
  avgSafeLocationsAtEnd: avg(out.safeAtEnd), avgNewGroundLeftAtEnd: avg(out.newGroundLeft),
  winRateByGunHeldAtEnd: Object.fromEntries(Object.entries(out.gunWin).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`])),
}, null, 1));
