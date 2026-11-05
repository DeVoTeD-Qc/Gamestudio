// Layer 1: rule unit tests. Each test builds a hand-made state, calls one action and checks the result.
// These pin the CURRENT live rules (TUNE as shipped). If a rule changes on purpose, change its test.
'use strict';
const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { WD, scenario, card, setCards, setGun, place, zero } = require('./helpers');

const T = WD.TUNE;

// One operator `me` (whose turn it is) with a known gun and deck, shooting at `them`.
function duel({ seed = 1, gun = 'pistol-0', posMe = 2, posThem = 2, types = {}, deck = [], prec = 0, themHand = [] } = {}) {
  const sc = scenario(seed); const { s, p, me, them } = sc;
  place(s, posMe, posThem, p, types);
  zero(me); zero(them); setGun(s, me, gun);
  setCards(s, me, { deck }); setCards(s, them, { hand: themHand, deck: ['T001', 'T001', 'T001', 'T001', 'T001', 'T001'] });
  me.res.prec = prec; me.nextFire = { reqMod: 0, bonusPrec: 0 }; me.ignoreCover = false; me.revealPlus = 0; me.suppressed = 0;
  return sc;
}

describe('setup', () => {
  test('both operators start with 30 health, a Common pistol and a 10-card starter deck', () => {
    const { s } = scenario(7);
    for (const pl of s.players) {
      assert.equal(pl.hp, T.hp);
      assert.equal(pl.hp, 30);
      assert.equal(s.weapons[pl.guns[0]].def, 'pistol-0');
      const all = pl.deck.concat(pl.hand, pl.discard).map(i => s.cards[i].def).sort();
      assert.deepEqual(all, ['T001', 'T001', 'T001', 'T002', 'T002', 'T002', 'T004', 'T004', 'T005', 'T005']);
      assert.equal(pl.hand.length, 5);
    }
  });
  test('operators drop in at locations 1 and 4; the second player\'s side of the map closes first', () => {
    for (let seed = 1; seed <= 20; seed++) {
      const s = WD.newGame({ seed });
      assert.deepEqual(s.players.map(p => p.pos).sort(), [T.startA, T.startB]);
      assert.equal(s.closeSide, s.players[s.first].pos === T.startB ? 'left' : 'right');
      assert.equal(s.envs.length, 6);
      assert.equal(s.envDeck.length, T.phaseDeck.reduce((a, b) => a + b, 0));
    }
  });
  test('acting out of turn, or after the match is over, is refused', () => {
    const { s, o, p } = scenario(3);
    assert.equal(WD.endTurn(s, o).ok, false);
    assert.match(WD.endTurn(s, o).err, /isn't your turn/);
    s.over = true;
    assert.match(WD.endTurn(s, p).err, /over/);
  });
});

describe('firing', () => {
  test('a shot reveals exactly as many cards as you have Precision', () => {
    const { s, p, me } = duel({ prec: 3, deck: ['T001', 'T001', 'T001', 'T001', 'T001'] });
    const r = WD.fire(s, p, 0);
    assert.equal(r.ok, true);
    assert.equal(r.result.revealed.length, 3);
    assert.equal(me.deck.length, 2);
    assert.equal(me.discard.length, 3, 'revealed cards go to the discard pile');
  });
  test('Hit Markers against the gun\'s ladder: miss, first step, second step', () => {
    // Sidearm ladder: 2 Hit Markers → 2 damage, 4 → 3 damage. Steady Aim has 1 Hit Marker, Sprint 0.
    assert.deepEqual(WD.WEAPONS['pistol-0'].ladder, [[2, 2], [4, 3]]);
    const cases = [
      { deck: ['T004', 'T001', 'T001'], hit: false, dealt: 0, total: 1 },
      { deck: ['T001', 'T004', 'T004'], hit: true, dealt: 2, total: 2 },
      { deck: ['T004', 'T004', 'T004', 'T004'], prec: 4, hit: true, dealt: 3, total: 4 },
    ];
    for (const c of cases) {
      const { s, p, them } = duel({ prec: c.prec || 3, deck: c.deck });
      const r = WD.fire(s, p, 0).result;
      assert.equal(r.total, c.total); assert.equal(r.hit, c.hit); assert.equal(r.dealt, c.dealt);
      assert.equal(them.hp, 30 - c.dealt);
    }
  });
  test('cover takes 1 damage off, except at distance 0 or when the shot ignores cover', () => {
    const hit = (o) => { const { s, p } = duel(Object.assign({ prec: 2, deck: ['T004', 'T004'] }, o)); if (o.ignore) s.players[p].ignoreCover = true; return WD.fire(s, p, 0).result.dealt; };
    assert.equal(WD.ENVS.E05.cover, 1); assert.equal(WD.ENVS.E01.cover, 0);
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' } }), 1, 'distance 1, target in cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E01' } }), 2, 'distance 1, open ground');
    assert.equal(hit({ posThem: 2, types: { 2: 'E05' } }), 2, 'same location: no cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' }, ignore: true }), 2, 'ignore cover');
  });
  test('damage never drops below 1 (cover)', () => {
    const { s, p } = duel({ gun: 'smg-0', prec: 3, deck: ['T004', 'T004', 'T004'], posThem: 3, types: { 3: 'E05' } });
    // Viper: 3 Hit Markers → 2 damage; minus 1 cover = 1
    assert.equal(WD.fire(s, p, 0).result.dealt, 1);
  });
  test('the best Reaction card in hand is used first, then Armor; at least 1 damage gets through', () => {
    const big = { prec: 4, deck: ['T004', 'T004', 'T004', 'T004'] }; // Sidearm second step: 3 damage
    let d = duel(Object.assign({ themHand: ['T006'] }, big)); // Take Cover, reaction 2
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1);
    assert.equal(d.them.hand.length, 0); assert.equal(d.them.discard.length, 1, 'the reaction card is discarded');
    d = duel(Object.assign({ themHand: ['T006', 'K01'] }, big)); // Armor Plates, reaction 3, is better
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1);
    assert.deepEqual(d.them.hand.map(i => d.s.cards[i].def), ['T006']);
    d = duel(big); d.them.def = 1;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 2); assert.equal(d.them.def, 0, 'Armor is used up');
    d = duel(big); d.them.def = 5;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1); assert.equal(d.them.def, 3, 'only the Armor needed is used');
    d = duel(Object.assign({ themHand: ['T006'] }, big)); d.them.def = 2;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1); assert.equal(d.them.def, 2, 'reaction first, Armor untouched');
  });
  test('Recoil lowers Precision after each shot', () => {
    const { s, p, me } = duel({ prec: 3, deck: ['T001', 'T001', 'T001', 'T001'] });
    assert.equal(WD.WEAPONS['pistol-0'].recoil, 2);
    WD.fire(s, p, 0); assert.equal(me.res.prec, 1);
    WD.fire(s, p, 0); assert.equal(me.res.prec, 0);
  });
  test('a gun fires up to its magazine per turn; extra shots add to it', () => {
    const deck = Array(30).fill('T001');
    const { s, p, me } = duel({ prec: 9, deck });
    assert.equal(WD.fire(s, p, 0).ok, true); assert.equal(WD.fire(s, p, 0).ok, true);
    const r = WD.fire(s, p, 0); assert.equal(r.ok, false); assert.match(r.err, /magazine/);
    me.shot = 1; assert.equal(WD.fire(s, p, 0).ok, true); assert.equal(me.shot, 0);
  });
  test('no Precision, nothing to reveal: the shot is refused', () => {
    const { s, p } = duel({ prec: 0, deck: ['T004'] });
    const r = WD.fire(s, p, 0); assert.equal(r.ok, false); assert.match(r.err, /Precision/);
  });
  test('a gun only fires inside its distance band', () => {
    let d = duel({ prec: 2, deck: ['T004', 'T004'], posMe: 1, posThem: 4 }); // Sidearm band 0–2, distance 3
    const r = WD.fire(d.s, d.p, 0);
    assert.equal(r.ok, false); assert.match(r.err, /fires at distance 0–2/);
    assert.equal(d.me.deck.length, 2, 'a refused shot reveals nothing');
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['T004', 'T004', 'T004'] }); // Longbow band 1–5, distance 0
    assert.equal(WD.fire(d.s, d.p, 0).ok, false);
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['T004', 'T004', 'T004'], posMe: 0, posThem: 5 });
    assert.equal(WD.fire(d.s, d.p, 0).ok, true);
  });
  test('a knife hits at distance 0 without Precision', () => {
    const { s, p, them } = duel({ gun: 'knife-0', prec: 0 });
    const r = WD.fire(s, p, 0);
    assert.equal(r.ok, true); assert.equal(r.result.hit, true); assert.equal(them.hp, 28);
  });
  test('a lethal hit ends the match', () => {
    const { s, p, them } = duel({ prec: 2, deck: ['T004', 'T004'] });
    them.hp = 2;
    WD.fire(s, p, 0);
    assert.equal(s.over, true); assert.equal(s.winner, p);
  });
});

describe('moving and looting', () => {
  test('moving costs 1 Movement per location, once per turn', () => {
    const { s, p, me } = scenario(5); place(s, 1, 4, p, { 3: 'E05', 4: 'E05' }); zero(me);
    me.moved = false; me.res.move = 1;
    assert.equal(WD.moveCost(s, p, 3), 2);
    assert.match(WD.move(s, p, 3).err, /Needs 2 Movement/);
    me.res.move = 2;
    assert.equal(WD.move(s, p, 3).ok, true);
    assert.equal(me.pos, 3); assert.equal(me.res.move, 0); assert.equal(me.def, 1, 'Concrete Barrier: +1 Armor on arrival');
    me.res.move = 5;
    assert.match(WD.move(s, p, 4).err, /already moved/);
    assert.equal(WD.moveCost(s, p, 3), null, 'no move to where you stand');
  });
  test('buying the top card costs its Intel; next door costs +1', () => {
    const setup = (where) => {
      const { s, p, me } = scenario(9); place(s, 2, 5, p); zero(me);
      const e = WD.envAt(s, where); e.cache.searched = true; e.state = 'safe';
      const top = card(s, 'A11'); const under = card(s, 'A12');
      e.loot = [{ kind: 'card', iid: top }, { kind: 'card', iid: under }];
      return { s, p, me, top, under };
    };
    assert.equal(WD.CARDS.A11.intel_cost, 1);
    let c = setup(2); c.me.res.intel = 1;
    assert.equal(WD.buy(c.s, c.p, c.top).ok, true); assert.equal(c.me.res.intel, 0); assert.ok(c.me.discard.includes(c.top));
    c = setup(3); c.me.res.intel = 1;
    assert.match(WD.buy(c.s, c.p, c.top).err, /Needs 2 Intel/);
    c.me.res.intel = 2;
    assert.equal(WD.buy(c.s, c.p, c.top).ok, true); assert.equal(c.me.res.intel, 0);
    c = setup(2); c.me.res.intel = 9;
    assert.equal(WD.buy(c.s, c.p, c.under).ok, false, 'only the top card can be bought');
    c = setup(4); c.me.res.intel = 9;
    assert.equal(WD.buy(c.s, c.p, c.top).ok, false, 'two locations away is out of reach');
  });
  test('cycling the top card to the bottom costs 1 Intel or 1 Movement (free cycles first)', () => {
    const { s, p, me } = scenario(11); place(s, 2, 5, p); zero(me);
    const e = WD.envAt(s, 2); e.cache.searched = true;
    const [a, b, c] = ['A11', 'A12', 'A13'].map(d => card(s, d)); e.loot = [a, b, c].map(iid => ({ kind: 'card', iid }));
    assert.match(WD.cycle(s, p).err, /costs 1 Intel/);
    me.res.intel = 1; assert.equal(WD.cycle(s, p).ok, true); assert.equal(me.res.intel, 0);
    assert.deepEqual(e.loot.map(x => x.iid), [b, c, a]);
    me.res.move = 1; assert.equal(WD.cycle(s, p, 'move').ok, true); assert.equal(me.res.move, 0);
    me.freeCycles = 1; me.res.intel = 1; assert.equal(WD.cycle(s, p).ok, true);
    assert.equal(me.freeCycles, 0); assert.equal(me.res.intel, 1, 'the free cycle is used before Intel');
    e.loot = e.loot.slice(0, 1); assert.match(WD.cycle(s, p).err, /Only one card/);
  });
  test('the Buy Station sells 8 copies of each card for 2 Intel', () => {
    const { s, p, me } = scenario(13); zero(me);
    assert.deepEqual(T.station, ['K02', 'K04', 'K05', 'K03']);
    me.res.intel = 1; assert.match(WD.buySupply(s, p, 'K04').err, /cost 2 Intel/);
    me.res.intel = 2; assert.equal(WD.buySupply(s, p, 'K04').ok, true);
    assert.equal(me.res.intel, 0); assert.equal(s.stationLeft.K04, 7);
    assert.equal(s.cards[me.discard[me.discard.length - 1]].def, 'K04');
    s.stationLeft.K04 = 0; me.res.intel = 2; assert.match(WD.buySupply(s, p, 'K04').err, /sold out/);
    assert.equal(WD.buySupply(s, p, 'A11').ok, false);
  });
  test('Scrap removes a card from the game but never takes the deck below 6 cards', () => {
    const { s, p, me } = scenario(15);
    setCards(s, me, { hand: ['T001', 'T001', 'T001'], discard: ['T002', 'T002', 'T002', 'T002'] }); // 7 cards
    assert.match(WD.scrap(s, p, me.hand[0]).err, /No Scrap available/);
    me.scrapAvail = 2;
    const x = me.hand[0];
    assert.equal(WD.scrap(s, p, x).ok, true); assert.ok(me.removed.includes(x)); assert.equal(me.scrapAvail, 1);
    assert.match(WD.scrap(s, p, me.hand[0]).err, /6-card minimum/);
  });
});

describe('end of turn and round', () => {
  test('unused Movement digs in as Armor, up to 2; Intel and Precision are lost', () => {
    for (const [move, armor] of [[0, 0], [1, 1], [2, 2], [5, 2]]) {
      const { s, p, me } = scenario(17); zero(me); me.res.move = move; me.res.intel = 3; me.res.prec = 2;
      assert.equal(WD.endTurn(s, p).ok, true);
      assert.equal(me.def, armor, `${move} Movement left`);
      assert.deepEqual(me.res, { move: 0, prec: 0, intel: 0 });
    }
  });
  test('you draw 5 cards at the end of your turn, 6 at 10 health or less', () => {
    for (const [hp, n] of [[30, 5], [11, 5], [10, 6], [1, 6]]) {
      const { s, p, me } = scenario(19); setCards(s, me, { deck: Array(8).fill('T001') }); me.hp = hp;
      WD.endTurn(s, p);
      assert.equal(me.hand.length, n, `${hp} health`);
    }
  });
  test('turn order: the lead alternates every round', () => {
    const s = WD.newGame({ seed: 21 }); const first = s.first;
    WD.endTurn(s, s.turn); assert.equal(s.turn, 1 - first); assert.equal(s.round, 1);
    WD.endTurn(s, s.turn); assert.equal(s.round, 2); assert.equal(s.first, 1 - first); assert.equal(s.turn, 1 - first);
  });
  test('the gas takes 1 location per round in phase 1 and new ground arrives on the other side', () => {
    const s = WD.newGame({ seed: 23 }); const before = WD.safeBounds(s);
    WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
    const after = WD.safeBounds(s);
    assert.equal(after.hi, before.hi - 1); assert.equal(after.lo, before.lo - 1); assert.equal(after.n, before.n);
    assert.equal(s.envDeck.length, T.phaseDeck.reduce((a, b) => a + b, 0) - 1);
  });
  test('caught in the gas: 3 damage + 1 per extra location deep, then pushed back to the safe edge', () => {
    const { s, p, o, them } = scenario(25);
    const lo = WD.safeBounds(s).lo; them.pos = lo - 3; // the second player stands 3 locations outside the left edge
    WD.endTurn(s, p); WD.endTurn(s, o); // round ends: new ground arrives at lo - 1, so they are 2 deep
    const B = WD.safeBounds(s);
    assert.equal(B.lo, lo - 1);
    assert.equal(them.hp, 30 - (T.gasDmg + 2 - 1));
    assert.equal(them.hp, 26);
    assert.equal(them.pos, B.lo);
    assert.equal(s.players[p].hp, 30);
  });
  test('final circle: once one location is left the storm hits both for 3, then 4, 5 …', () => {
    const { s, me, them } = scenario(27);
    s.envDeck = []; s.envPh = []; s.newGround = [];
    const w = me.pos; them.pos = w;
    for (const e of s.envs) if (e.w !== w) e.state = 'gas';
    WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
    assert.deepEqual([me.hp, them.hp], [27, 27]);
    WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
    assert.deepEqual([me.hp, them.hp], [23, 23]);
    WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
    assert.deepEqual([me.hp, them.hp], [18, 18]);
    assert.equal(s.over, false);
  });
  test('if both operators fall at once, the one with more health left wins; equal is a draw', () => {
    const run = (hpMe, hpThem) => {
      const { s, p, me, them } = scenario(29);
      s.envDeck = []; s.envPh = []; s.newGround = []; them.pos = me.pos;
      for (const e of s.envs) if (e.w !== me.pos) e.state = 'gas';
      me.hp = hpMe; them.hp = hpThem;
      WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
      assert.equal(s.over, true);
      return s.winner === 'draw' ? 'draw' : s.winner === p ? 'me' : 'them';
    };
    assert.equal(run(2, 3), 'them');
    assert.equal(run(3, 2), 'me');
    assert.equal(run(3, 3), 'draw');
  });
});
