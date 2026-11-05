// AI-vs-AI smoke test through the studio's QA simulator (qa/tools/ai_sim.js), run as a separate process
// exactly as `npm run sim` does. Balance numbers are not checked here (that is `npm run sim`'s report);
// this only asserts the simulator runs and every match completes cleanly.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const { execFileSync } = require('child_process');
const { SIM } = require('../tools/balance.js');

test('ai_sim.js: 200 matches, no errors, no stuck matches, no invariant failures', { skip: !fs.existsSync(SIM) && 'qa/tools/ai_sim.js not found' }, () => {
  const out = execFileSync(process.execPath, [SIM, '200'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  const r = JSON.parse(out.slice(out.indexOf('{')));
  assert.equal(r.games, 200);
  assert.equal(r.errors, 0);
  assert.equal(r.stuck, 0);
  assert.equal(r.invariantFailures, 0);
  assert.equal(r.completed, 200);
});
