// Warbuilder headless AI-vs-AI simulator for the SHIPPED engine (studio QA tool; rewritten for wb-rules, 2026-11-05).
// Runs src/engine.js in Node (no browser) and reports balance and pacing numbers against the engine-synergy targets.
// It only reads the engine; it never changes the game source.
//
//   node projects/warbuilder/qa/tools/ai_sim.js [games=2000] [options]
//     --match=aware-blind | aware-aware | blind-blind   who plays (default aware-aware; seats alternate every game)
//     --flat                                            Squad and Rally switched off (the "no synergy" control)
//     --force=assault|recon|support|engineer            the aware AI buys only that squad
//     --set=key:value,...                               override TUNE values (numbers or true/false)
//     --curve                                           also print the per-round Firepower table
// Back-compat: a bare second argument "nosyn" means --flat.
'use strict';
const path = require('path');
const WD = require(path.join(__dirname, '..', '..', 'source', 'project-warbuilder', 'src', 'engine.js'));

const argv = process.argv.slice(2);
const N = +(argv.find(a => /^\d+$/.test(a)) || 2000);
const opt = k => { const a = argv.find(x => x.startsWith('--' + k)); return a ? (a.includes('=') ? a.split('=')[1] : true) : null; };
const match = opt('match') || 'aware-aware';
const force = opt('force');
if (opt('flat') || argv.includes('nosyn')) { WD.TUNE.squadCap = 0; WD.TUNE.rally = []; }
if (opt('set')) for (const kv of String(opt('set')).split(',')) { const [k, v] = kv.split(':'); WD.TUNE[k] = isNaN(+v) ? (v === 'true' ? true : v === 'false' ? false : v) : +v; }
const [aiA, aiB] = match.split('-');

const avg = a => a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : null;
const pct = (w, n) => n ? +(w / n).toFixed(3) : null;
const R = { errors: 0, stuck: 0, invariantFailures: 0, decided: 0, draws: 0, aWins: 0, firstWins: 0, seat0: 0, rounds: [], endBy: {}, final: 0,
  shots: 0, hits: 0, rangedShots: 0, rangedHits: 0, big: 0, shotDmg: 0, gasDmg: 0, gun: {}, fam: {}, share: {}, byRound: {}, squads: 0, rallies: 0, turns: 0 };

function cardCount(s) { // every card instance must be in exactly one place
  const seen = new Map();
  const note = (iid, where) => { if (seen.has(iid)) throw new Error(`card ${iid} in ${seen.get(iid)} and ${where}`); seen.set(iid, where); };
  s.players.forEach((pl, i) => ['deck', 'discard', 'hand', 'play', 'loadout', 'fuelled', 'removed', 'drop'].forEach(z => (pl[z] || []).forEach(c => note(c, `p${i}.${z}`))));
  s.envs.forEach(e => e.loot.forEach(it => note(it.iid, `env${e.w}`)));
  [1, 2, 3].forEach(t => s.loot[t].forEach(it => note(it.iid, `loot${t}`)));
  s.gone.forEach(it => note(it.iid, 'gone'));
  s.players.forEach((pl, i) => pl.guns.filter(Boolean).forEach(w => note(w, `p${i}.gun`)));
}

for (let i = 0; i < N; i++) {
  const aSeat = i % 2; const s = WD.newGame({ seed: i + 1 }); const first = s.first;
  const mode = k => k === 'aware' && force ? 'force:' + force : k;
  s.aiMode = aSeat === 0 ? [mode(aiA), mode(aiB)] : [mode(aiB), mode(aiA)];
  const ai = q => (q === aSeat ? aiA : aiB);
  let guard = 0; const turnLog = [];
  try {
    while (!s.over && guard++ < 400) {
      const p = s.turn; const round = s.round; const pl = s.players[p];
      const sh0 = pl.stats.shots, hit0 = pl.stats.hits, sq0 = pl.stats.squads, ra0 = pl.stats.rallies, dmg0 = pl.stats.damageDealt;
      const melee = WD.WEAPONS[s.weapons[pl.guns[0]].def].melee;
      const r = WD.aiTurn(s, p); if (!r.ok) throw new Error(r.err);
      if (s.players.some(q => q.res.intel < 0 || q.res.move < 0 || q.res.prec < 0 || q.def < 0)) throw new Error('negative resource');
      if (!melee) { R.rangedShots += pl.stats.shots - sh0; R.rangedHits += pl.stats.hits - hit0; }
      turnLog.push({ p, round, fp: pl.fpHist.length && s.players[p].fpHist[s.players[p].fpHist.length - 1], squads: pl.stats.squads - sq0, rallies: pl.stats.rallies - ra0, dmg: pl.stats.damageDealt - dmg0, ended: !s.over || pl.fpHist.length });
    }
    cardCount(s);
  } catch (e) { if (/card c|negative/.test(e.message)) R.invariantFailures++; else R.errors++; if (R.errors + R.invariantFailures <= 3) console.error(`seed ${i + 1}:`, e.message); continue; }
  if (!s.over) { R.stuck++; continue; }
  R.rounds.push(s.round); R.endBy[s.endBy] = (R.endBy[s.endBy] || 0) + 1; if (s.finalReached) R.final++;
  if (s.winner === 'draw') R.draws++; else { R.decided++; if (s.winner === aSeat) R.aWins++; if (s.winner === first) R.firstWins++; if (s.winner === 0) R.seat0++; }
  for (const pl of s.players) {
    R.shots += pl.stats.shots; R.hits += pl.stats.hits; R.big += pl.stats.big; R.shotDmg += pl.stats.damageDealt; R.gasDmg += pl.stats.gasTaken || 0;
    R.squads += pl.stats.squads; R.rallies += pl.stats.rallies; R.turns += pl.fpHist.length;
    const g = WD.WEAPONS[s.weapons[pl.guns[0]].def].gunClass; R.gun[g] = R.gun[g] || [0, 0]; R.gun[g][1]++; if (s.winner === pl.idx) R.gun[g][0]++;
    const fc = WD.archCounts(s, pl.idx); const tot = Object.values(fc).reduce((a, b) => a + b, 0); const main = WD.mainSquad(s, pl.idx) || '-';
    const k = `${main}:${ai(pl.idx)}`; R.fam[k] = R.fam[k] || [0, 0]; R.fam[k][1]++; if (s.winner === pl.idx) R.fam[k][0]++;
    if (tot) { const sh = Math.max(...Object.values(fc)) / tot; const b = `${ai(pl.idx)} ${sh >= 0.85 ? 'mono (85%+ one squad)' : sh >= 0.6 ? 'lean (60-85%)' : 'mixed (<60%)'}`; R.share[b] = R.share[b] || [0, 0]; R.share[b][1]++; if (s.winner === pl.idx) R.share[b][0]++; }
  }
  for (const t of turnLog) { if (typeof t.fp !== 'number') continue; const k = ai(t.p); const b = R.byRound[t.round] = R.byRound[t.round] || {}; const x = b[k] = b[k] || [0, 0, 0, 0, 0]; x[0] += t.fp; x[1]++; x[2] += t.squads; x[3] += t.dmg; x[4] += t.rallies; }
}
const done = R.rounds.length;
const curve = Object.keys(R.byRound).map(Number).sort((a, b) => a - b).map(r => ({ round: r, ...Object.fromEntries(Object.entries(R.byRound[r]).map(([k, v]) => [k, { firepower: +(v[0] / v[1]).toFixed(1), turns: v[1], squads: +(v[2] / v[1]).toFixed(2), rallies: +(v[4] / v[1]).toFixed(2), dmg: +(v[3] / v[1]).toFixed(2) }])) }));
const fmt = o => Object.fromEntries(Object.entries(o).sort().map(([k, v]) => [k, `${(v[0] / v[1]).toFixed(2)} (n=${v[1]})`]));
const out = {
  games: N, match, force: force || null, flat: WD.TUNE.squadCap === 0, set: opt('set') || null, completed: done, errors: R.errors, stuck: R.stuck, invariantFailures: R.invariantFailures,
  [`${aiA}WinRate`]: pct(R.aWins, R.decided), p1WinRate: pct(R.decided - R.seat0, R.decided), firstPlayerWinRate: pct(R.firstWins, R.decided), draws: R.draws,
  avgRounds: avg(R.rounds), maxRound: done ? Math.max(...R.rounds) : null, endBy: R.endBy, finalCircleReached: pct(R.final, done),
  hitRate: pct(R.hits, R.shots), hitRateExclMelee: pct(R.rangedHits, R.rangedShots), bigHitShare: pct(R.big, R.hits), shotsPerGame: done ? +(R.shots / done).toFixed(1) : null,
  gasShareOfDamage: pct(R.gasDmg, R.gasDmg + R.shotDmg), squadsPerTurn: +(R.squads / Math.max(1, R.turns)).toFixed(2), ralliesPerTurn: +(R.rallies / Math.max(1, R.turns)).toFixed(2),
  winRateByGunHeldAtEnd: fmt(R.gun), winRateByMainSquad: fmt(R.fam), winRateBySquadShare: fmt(R.share), curve,
};
console.log(JSON.stringify(opt('curve') ? Object.assign({}, out, { curve: undefined }) : out, null, 1));
if (opt('curve')) { console.log('round | ' + [aiA, aiB].filter((x, i, a) => a.indexOf(x) === i).map(k => `${k}: Firepower / squads / rallies / dmg`).join(' | '));
  for (const c of curve) console.log(String(c.round).padStart(5) + ' | ' + [aiA, aiB].filter((x, i, a) => a.indexOf(x) === i).map(k => c[k] ? `${String(c[k].firepower).padStart(5)} ${String(c[k].squads).padStart(5)} ${String(c[k].rallies).padStart(5)} ${String(c[k].dmg).padStart(5)}` : '').join(' | ')); }
