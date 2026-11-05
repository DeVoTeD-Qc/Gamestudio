// Layer 3: seeded determinism and golden replays.
// A golden replay is a seed played to the end (by the AI, or by a fixed AI-free policy) and the
// hash of its final state (log text excluded). Any rules or AI change that alters a match shows up here.
// After an intended change, regenerate on purpose:  npm run test:update-golden
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { WD, SRC, aiMatch, scriptedMatch, stateHash } = require('./helpers');

const GOLDEN = path.join(__dirname, 'golden', 'replays.json');
const SEEDS = [1, 2, 3, 7, 42, 99, 1234, 20261104];

test('the engine uses only its seeded RNG (no Math.random, no clock in the rules)', () => {
  const src = fs.readFileSync(path.join(SRC, 'engine.js'), 'utf8');
  assert.equal((src.match(/Math\.random/g) || []).length, 0);
  assert.equal((src.match(/Date\.now/g) || []).length, 1, 'only as the default seed of newGame');
  assert.match(src, /opts\.seed \?\? \(Date\.now\(\)/);
});

test('the same seed plays the same match; different seeds play different ones', () => {
  const hashes = new Set();
  for (const seed of SEEDS) {
    const a = aiMatch(seed), b = aiMatch(seed);
    assert.equal(JSON.stringify(a), JSON.stringify(b), `seed ${seed}`);
    hashes.add(stateHash(a));
  }
  assert.equal(hashes.size, SEEDS.length);
});

test('save and resume: a match continued from a JSON copy ends exactly the same', () => {
  for (const seed of SEEDS) {
    const a = WD.newGame({ seed });
    for (let i = 0; i < 9 && !a.over; i++) WD.aiTurn(a, a.turn);
    const b = JSON.parse(JSON.stringify(a));
    for (const s of [a, b]) { let n = 0; while (!s.over && n++ < 400) WD.aiTurn(s, s.turn); }
    assert.equal(JSON.stringify(b), JSON.stringify(a), `seed ${seed}`);
  }
});

test('golden replays match test/golden/replays.json', () => {
  const now = {};
  for (const seed of SEEDS) {
    const a = aiMatch(seed);
    const { s, actions } = scriptedMatch(seed);
    now[seed] = {
      ai: { hash: stateHash(a), winner: a.winner, rounds: a.round, hp: a.players.map(p => p.hp) },
      scripted: { hash: stateHash(s), winner: s.winner, rounds: s.round, hp: s.players.map(p => p.hp), actions: actions.length },
    };
  }
  if (process.env.UPDATE_GOLDEN) {
    const lines = SEEDS.map(seed => `  ${JSON.stringify(String(seed))}: ${JSON.stringify(now[seed])}`);
    fs.mkdirSync(path.dirname(GOLDEN), { recursive: true });
    fs.writeFileSync(GOLDEN, `{\n "note": "Regenerate with \`npm run test:update-golden\` after an intended rules or AI change.",\n "seeds": {\n${lines.join(',\n')}\n }\n}\n`);
    return;
  }
  assert.ok(fs.existsSync(GOLDEN), 'test/golden/replays.json is missing: run npm run test:update-golden');
  const want = JSON.parse(fs.readFileSync(GOLDEN, 'utf8')).seeds;
  for (const seed of SEEDS) assert.deepEqual(now[seed], want[seed], `seed ${seed} replays differently (intended? run npm run test:update-golden)`);
});
