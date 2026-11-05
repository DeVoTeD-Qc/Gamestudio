#!/usr/bin/env node
// tools/balance.js: balance report (test layer 4, non-blocking). Runs the studio's QA simulator
// qa/tools/ai_sim.js and compares its numbers with the target bands from the tech review and
// DESIGN_REVIEW.md. Out-of-band numbers print a WARN line; the exit code is 0 unless the sim breaks.
//
//   npm run sim                 → 2000 seeded AI-vs-AI matches
//   npm run sim -- 500 --match=aware-blind   → 500 matches, combo-aware vs combo-blind (see ai_sim.js for the options)
//   npm run sim -- --json       → the raw ai_sim.js JSON only
'use strict';
const path = require('path');
const { execFileSync } = require('child_process');

const SIM = path.join(__dirname, '..', '..', '..', 'qa', 'tools', 'ai_sim.js');

// [label, read(report) → number | null, low, high]
const BANDS = [
  ['first-player win rate', r => r.firstPlayerWinRate, 0.45, 0.55],
  ['average rounds', r => r.avgRounds, 8, 12],
  ['gas share of damage', r => r.gasShareOfDamage, 0.10, 0.20],
  ['hit rate (shots that deal)', r => r.hitRate, 0.60, 0.70],
  ['whole turns wiped by a bust', r => r.pyl && r.pyl.wipedTurns, 0.03, 0.07], // bust-variants.md §5
];
const GUN_BAND = [0.42, 0.58];

function run(args) {
  const out = execFileSync(process.execPath, [SIM, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'], maxBuffer: 64 << 20 });
  return JSON.parse(out.slice(out.indexOf('{')));
}

function report(r) {
  const lines = []; let warn = 0;
  const row = (label, v, lo, hi) => {
    if (v == null || Number.isNaN(v)) return;
    const ok = v >= lo && v <= hi; if (!ok) warn++;
    lines.push(`${ok ? '  ok ' : 'WARN '} ${label.padEnd(28)} ${String(v).padStart(6)}   target ${lo}–${hi}`);
  };
  lines.push(`Balance report: ${r.games} matches, ${r.match}${r.force ? `, forced ${r.force}` : ''} (qa/tools/ai_sim.js)`);
  if (r.errors || r.stuck || r.invariantFailures) { lines.push(`FAIL  errors ${r.errors}, stuck ${r.stuck}, invariant failures ${r.invariantFailures}`); warn++; }
  for (const [label, get, lo, hi] of BANDS) row(label, get(r), lo, hi);
  for (const [gun, txt] of Object.entries(r.winRateByGunHeldAtEnd || {})) row(`win rate holding ${gun}`, parseFloat(txt), GUN_BAND[0], GUN_BAND[1]);
  if (r.pyl) lines.push(`      Firefight: busts in ${r.pyl.bustPerShootingTurn} of shooting turns, ${r.pyl.wipedTurns} wiped, ${r.pyl.lostShareOfDamage} of damage lost to busts, ${r.pyl.flipsPerTurn} flips per turn (${r.pyl.flipsPerShootingTurn} per shooting turn), ${r.pyl.shotsPerCash} shots per cash-out`);
  lines.push(`      hit rate ${r.hitRate} (${r.hitRateExclMelee} without the knife), final circle ${r.finalCircleReached}, shots per match ${r.shotsPerGame}, draws ${r.draws}, P1 win rate ${r.p1WinRate}${r.awareWinRate != null && /blind/.test(r.match) ? `, combo-aware ${r.awareWinRate} (target ≥ 0.55)` : ''}`);
  lines.push(warn ? `${warn} number(s) outside the target bands (report only, not a failure).` : 'All numbers inside the target bands.');
  return { text: lines.join('\n'), warn };
}

module.exports = { SIM, BANDS, report };

if (require.main === module) {
  const args = process.argv.slice(2).filter(a => a !== '--json');
  const r = run(args.length ? args : ['2000']);
  if (process.argv.includes('--json')) console.log(JSON.stringify(r, null, 1));
  else console.log(report(r).text);
  if (r.errors || r.stuck || r.invariantFailures) process.exitCode = 1;
}
