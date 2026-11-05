// Layer 2: full-match invariants (property tests) over many seeded AI-vs-AI matches.
// WB_MATCHES=2000 npm test runs more; the default keeps `npm test` to a few seconds.
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { WD, aiMatch, cardPlaces } = require('./helpers');

const N = +process.env.WB_MATCHES || 400;

// New log lines since the last check (the engine keeps the last 500 lines only).
function since(s, mark) { const i = mark ? s.log.lastIndexOf(mark) : -1; return s.log.slice(i + 1); }

// Damage each log line says a player took. Health may only change through these.
function loggedDamage(s, lines) {
  const dmg = [0, 0]; const who = name => s.players.findIndex(pl => pl.name === name);
  for (const { msg } of lines) {
    let m = msg.match(/^(.+?) fires .*→ HIT for (\d+)/); if (m) { dmg[1 - who(m[1])] += +m[2]; continue; }
    m = msg.match(/^(.+?) is caught \d+ spaces? deep in the gas: −(\d+)/); if (m) { dmg[who(m[1])] += +m[2]; continue; }
    m = msg.match(/storm hits both operators for (\d+)/); if (m) { dmg[0] += +m[1]; dmg[1] += +m[1]; }
  }
  return dmg;
}

test(`${N} seeded AI-vs-AI matches keep every invariant`, () => {
  const rounds = [];
  for (let seed = 1; seed <= N; seed++) {
    let mark = null; let hp = [WD.TUNE.hp, WD.TUNE.hp];
    const check = s => {
      const ctx = `seed ${seed}, round ${s.round}`;
      for (const pl of s.players) {
        for (const r of ['move', 'prec', 'intel']) assert.ok(pl.res[r] >= 0, `${ctx}: negative ${r}`);
        assert.ok(pl.def >= 0, `${ctx}: negative Armor`);
        assert.ok(pl.hp <= WD.TUNE.hp, `${ctx}: health above the maximum`);
        assert.ok(pl.guns[0], `${ctx}: ${pl.name} has no gun`);
      }
      cardPlaces(s); // throws if a card or gun is in two places
      const lines = since(s, mark); const dmg = loggedDamage(s, lines);
      s.players.forEach((pl, i) => assert.equal(hp[i] - pl.hp, dmg[i], `${ctx}: ${pl.name}'s health changed without a hit, gas or storm`));
      hp = s.players.map(pl => pl.hp); mark = s.log[s.log.length - 1];
      if (!s.over) {
        assert.ok(s.turn === 0 || s.turn === 1, `${ctx}: bad turn`);
        assert.ok(WD.safeBounds(s).n >= 1, `${ctx}: no safe location left`);
        const B = WD.safeBounds(s); for (const pl of s.players) assert.ok(pl.pos >= B.lo && pl.pos <= B.hi || s.turn !== s.players.indexOf(pl), `${ctx}: ${pl.name} starts the turn in the gas`);
      }
    };
    const s = aiMatch(seed, { onTurn: check, maxTurns: 400 });
    assert.equal(s.over, true);
    if (s.winner === 'draw') assert.ok(s.players.every(pl => pl.hp <= 0) && s.players[0].hp === s.players[1].hp, `seed ${seed}: bad draw`);
    else { assert.ok(s.winner === 0 || s.winner === 1, `seed ${seed}: bad winner`); const w = s.players[s.winner], l = s.players[1 - s.winner]; assert.ok(l.hp <= 0, `seed ${seed}: loser still alive`); assert.ok(w.hp > 0 || w.hp > l.hp, `seed ${seed}: winner has less health`); }
    assert.deepEqual(JSON.parse(JSON.stringify(s)), s, `seed ${seed}: state is not plain JSON`);
    rounds.push(s.round);
  }
  assert.equal(rounds.length, N);
  assert.ok(Math.max(...rounds) <= 40, `a match lasted ${Math.max(...rounds)} rounds`);
});

test('loot decks never hold the same item twice, and every match deals the full component set', () => {
  for (let seed = 1; seed <= 50; seed++) {
    const s = WD.newGame({ seed });
    const items = [1, 2, 3].flatMap(t => s.loot[t]).concat(s.envs.flatMap(e => e.loot));
    assert.equal(new Set(items.map(it => it.iid)).size, items.length);
    const guns = items.filter(it => it.kind === 'weapon').map(it => s.weapons[it.iid].def).sort();
    assert.deepEqual(guns, [1, 2, 3].flatMap(t => WD.GUNSET[t]).sort(), `seed ${seed}: loot guns`);
    const cards = items.filter(it => it.kind === 'card').length;
    assert.equal(cards, Object.values(WD.CARDS).reduce((a, d) => a + (d.tier ? d.copies : 0), 0));
  }
});
