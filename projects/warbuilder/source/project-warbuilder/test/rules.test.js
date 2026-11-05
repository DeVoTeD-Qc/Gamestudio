// Layer 1: rule unit tests. Each test builds a hand-made state, calls one action and checks the result.
// These pin the CURRENT live rules (TUNE as shipped: the Engine & Synergy package, wb-rules). If a rule changes on purpose, change its test.
'use strict';
const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { WD, scenario, card, cards, setCards, setGun, place, zero } = require('./helpers');

const T = WD.TUNE;
const defs = (s, z) => z.map(i => s.cards[i].def);

// One operator `me` (whose turn it is) with a known gun and deck, shooting at `them`.
function duel({ seed = 1, gun = 'pistol-0', posMe = 2, posThem = 3, types = { 3: 'E01' }, deck = [], prec = 0, themHand = [] } = {}) {
  const sc = scenario(seed); const { s, p, me, them } = sc;
  place(s, posMe, posThem, p, types);
  zero(me); zero(them); setGun(s, me, gun);
  setCards(s, me, { deck }); setCards(s, them, { hand: themHand, deck: Array(6).fill('T001') });
  me.res.prec = prec;
  return sc;
}
// end turns until round `r` has started (the AI is not involved)
function toRound(s, r) { while (!s.over && s.round < r) WD.endTurn(s, s.turn); }

describe('setup', () => {
  test('both operators start with 40 Health, a Common pistol, an empty Loadout row and a 10-card starter deck', () => {
    const { s } = scenario(7);
    assert.equal(T.hp, 40);
    for (const pl of s.players) {
      assert.equal(pl.hp, 40);
      assert.equal(s.weapons[pl.guns[0]].def, 'pistol-0');
      assert.deepEqual(pl.loadout, []);
      assert.deepEqual(defs(s, pl.deck.concat(pl.hand, pl.discard)).sort(), ['T001', 'T001', 'T001', 'T002', 'T002', 'T002', 'T004', 'T004', 'T005', 'T005']);
      assert.equal(pl.hand.length, 5);
    }
  });
  test('a fixed row of 7 different locations; every stack is 3 deep, face up, a Common gun on top while they last', () => {
    for (let seed = 1; seed <= 20; seed++) {
      const s = WD.newGame({ seed });
      assert.equal(s.envs.length, 7);
      assert.equal(new Set(s.envs.map(e => e.def)).size, 7);
      assert.deepEqual(s.players.map(p => p.pos).sort(), [T.startA, T.startB]);
      for (const e of s.envs) { assert.equal(e.loot.length, 3); assert.equal(e.state, 'safe'); assert.ok(e.cache.searched); }
      const topGuns = s.envs.filter(e => e.loot[0].kind === 'weapon').map(e => s.weapons[e.loot[0].iid].def);
      assert.equal(topGuns.length, 6); assert.ok(topGuns.every(g => WD.GUNSET[1].includes(g)));
      for (const e of s.envs) assert.ok(e.loot.slice(1).every(it => it.kind === 'card'));
    }
  });
  test('acting out of turn, or after the match is over, is refused', () => {
    const { s, o, p } = scenario(3);
    assert.match(WD.endTurn(s, o).err, /isn't your turn/);
    s.over = true;
    assert.match(WD.endTurn(s, p).err, /over/);
  });
});

describe('firing (Precision is spent: commit + Recoil)', () => {
  test('a shot reveals one card per Precision committed; without a number it commits all your Precision', () => {
    let d = duel({ prec: 5, deck: Array(8).fill('T001') });
    let r = WD.fire(d.s, d.p, 0, 2);
    assert.equal(r.result.revealed.length, 2); assert.equal(r.result.commit, 2);
    assert.equal(d.me.discard.length, 2, 'revealed cards go to the discard pile');
    d = duel({ prec: 3, deck: Array(8).fill('T001') });
    assert.equal(WD.fire(d.s, d.p, 0).result.revealed.length, 3);
  });
  test('the shot spends what you committed, then Recoil costs more Precision (never below 0)', () => {
    const { s, p, me } = duel({ prec: 9, deck: Array(20).fill('T001') });
    assert.equal(WD.WEAPONS['pistol-0'].recoil, 2);
    WD.fire(s, p, 0, 3); assert.equal(me.res.prec, 4, '9 − 3 committed − 2 Recoil');
    WD.fire(s, p, 0, 3); assert.equal(me.res.prec, 0, '4 − 3 − 2, floored at 0');
  });
  test('Steady: each shot this turn reveals 1 extra card for free', () => {
    const { s, p, me } = duel({ prec: 4, deck: Array(20).fill('T001') });
    me.revealPlus = 1;
    const r = WD.fire(s, p, 0, 2).result;
    assert.equal(r.revealed.length, 3); assert.equal(r.free, 1); assert.equal(me.res.prec, 0, '4 − 2 − 2');
    assert.equal(WD.shotPreview(s, p, 0, 0).reveal, 1, 'with Steady a shot can commit nothing');
  });
  test('Hit Markers against the gun\'s ladder: miss, first step, second step', () => {
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
      assert.equal(them.hp, 40 - c.dealt);
    }
  });
  test('Mark: the next shot needs 1 fewer Hit Marker on every step (then it is used up)', () => {
    const { s, p, me } = duel({ prec: 9, deck: Array(20).fill('T004') });
    me.nextFire.reqMod = 1;
    assert.deepEqual(WD.shotPreview(s, p, 0, 1).steps.map(x => x[0]), [1, 3]);
    WD.fire(s, p, 0, 1);
    assert.deepEqual(WD.shotPreview(s, p, 0, 1).steps.map(x => x[0]), [2, 4]);
  });
  test('"Your hits deal +1 damage this turn" adds to every step', () => {
    const { s, p, me } = duel({ prec: 2, deck: ['T004', 'T004'] }); me.dmgTurn = 2;
    assert.equal(WD.fire(s, p, 0).result.dealt, 4);
  });
  test('cover takes 1 damage off; close quarters (distance 0) and Pierce ignore it', () => {
    const hit = (o) => { const { s, p } = duel(Object.assign({ prec: 2, deck: ['T004', 'T004'] }, o)); if (o.pierce) s.players[p].ignoreCover = true; return WD.fire(s, p, 0).result.dealt; };
    assert.equal(WD.ENVS.E05.cover, 1); assert.equal(WD.ENVS.E01.cover, 0);
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' } }), 1, 'distance 1, target in cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E01' } }), 2, 'distance 1, open ground');
    assert.equal(hit({ posThem: 2, types: { 2: 'E05' } }), 2, 'same location: no cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' }, pierce: true }), 2, 'Pierce');
  });
  test('the best Reaction card in hand is used first, then Armor; close quarters ignores Armor; a hit deals at least 1', () => {
    const big = { prec: 4, deck: ['T004', 'T004', 'T004', 'T004'] }; // Sidearm second step: 3 damage
    let d = duel(Object.assign({ themHand: ['E12'] }, big)); // Deployable Cover, Reaction 3
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1);
    assert.equal(d.them.hand.length, 0); assert.equal(d.them.discard.length, 1, 'the reaction card is discarded');
    d = duel(big); d.them.def = 1;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 2); assert.equal(d.them.def, 0, 'Armor is used up');
    d = duel(big); d.them.def = 5;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 1); assert.equal(d.them.def, 3, 'only the Armor needed is used');
    d = duel(Object.assign({ posThem: 2, types: { 2: 'E01' } }, big)); d.them.def = 5;
    assert.equal(WD.fire(d.s, d.p, 0).result.dealt, 3, 'close quarters: Armor ignored'); assert.equal(d.them.def, 5);
  });
  test('a gun fires up to its shots per turn; extra shots add to it', () => {
    const { s, p, me } = duel({ prec: 30, deck: Array(40).fill('T001') });
    assert.equal(WD.fire(s, p, 0, 1).ok, true); assert.equal(WD.fire(s, p, 0, 1).ok, true);
    const r = WD.fire(s, p, 0, 1); assert.equal(r.ok, false); assert.match(r.err, /fired its shots/);
    me.shot = 1; assert.equal(WD.fire(s, p, 0, 1).ok, true); assert.equal(me.shot, 0);
  });
  test('no Precision, nothing to reveal: the shot is refused', () => {
    const { s, p } = duel({ prec: 0, deck: ['T004'] });
    const r = WD.fire(s, p, 0); assert.equal(r.ok, false); assert.match(r.err, /Precision/);
  });
  test('point blank: every gun fires from distance 0 up to its range', () => {
    let d = duel({ prec: 2, deck: ['T004', 'T004'], posMe: 1, posThem: 4, types: { 4: 'E01' } }); // Sidearm 0–2, distance 3
    const r = WD.fire(d.s, d.p, 0);
    assert.equal(r.ok, false); assert.match(r.err, /fires at distance 0–2/);
    assert.equal(d.me.deck.length, 2, 'a refused shot reveals nothing');
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['T004', 'T004', 'T004'], posThem: 2, types: { 2: 'E01' } });
    assert.equal(WD.fire(d.s, d.p, 0).ok, true, 'Longbow at distance 0');
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['T004', 'T004', 'T004'], posMe: 0, posThem: 5, types: { 5: 'E01' } });
    assert.equal(WD.fire(d.s, d.p, 0).ok, true);
  });
  test('a knife hits at distance 0 without Precision, for 3', () => {
    const { s, p, them } = duel({ gun: 'knife-0', prec: 0, posThem: 2, types: { 2: 'E05' } });
    const r = WD.fire(s, p, 0);
    assert.equal(r.ok, true); assert.equal(r.result.hit, true); assert.equal(them.hp, 37);
  });
  test('a lethal hit ends the match', () => {
    const { s, p, them } = duel({ prec: 2, deck: ['T004', 'T004'] });
    them.hp = 2; WD.fire(s, p, 0);
    assert.equal(s.over, true); assert.equal(s.winner, p); assert.equal(s.endBy, 'ko');
  });
  test('suggestCommit plans the turn: it never commits more Precision than you have', () => {
    const { s, p, me } = duel({ prec: 8, deck: ['T004', 'T001', 'T004', 'K04', 'T001', 'T004', 'K04', 'T001', 'T004'] });
    const sg = WD.suggestCommit(s, p, 0);
    assert.ok(sg.commit >= 1 && sg.commit <= me.res.prec); assert.ok(sg.p > 0 && sg.p <= 1);
  });
});

describe('Squad lines and Rally', () => {
  const play = (s, p, ids) => { const pl = s.players[p]; pl.hand = cards(s, ids); for (const i of pl.hand.slice()) assert.equal(WD.playCard(s, p, i).ok, true); };
  test('a Squad line pays once for each OTHER card of its squad in play, in any order', () => {
    const { s, p, me } = scenario(31); zero(me);
    play(s, p, ['R12', 'T004']); assert.equal(me.res.prec, 3, 'Steady Breath alone: no Squad');
    zero(me); me.play = [];
    play(s, p, ['R12', 'K04']); // Steady Breath +2, Squad +2 · Focus +2, Squad +1
    assert.equal(me.res.prec, 7);
    zero(me); me.play = [];
    play(s, p, ['K04', 'R12']); assert.equal(me.res.prec, 7, 'order does not matter');
  });
  test('Squad caps at ×3; Loadout cards count as squad cards', () => {
    const { s, p, me } = scenario(33); zero(me);
    me.loadout = cards(s, ['L1R']);
    play(s, p, ['R12', 'K04', 'K04', 'K04']); // 5 Recon cards: each line ×3 (cap)
    assert.equal(me.squadN[me.play[0]], 3);
    // R12: 2 + 3×2; three Focus: 2 + 3×1 each; plus Recon Rally 3 (+1) and 5 (+3)
    assert.equal(me.res.prec, 8 + 3 * 5 + 1 + 3);
    assert.equal(me.nextFire.reqMod, 2, 'Recon Rally 3 and 5 each Mark');
  });
  test('Rally fires once per turn at 3 and at 5 cards of one squad', () => {
    const { s, p, me } = scenario(35); zero(me);
    play(s, p, ['K02', 'K02']); assert.equal(me.rallyDone.length, 0);
    play(s, p, ['K02']); assert.deepEqual(me.rallyDone, ['assault3']); assert.equal(me.dmgTurn, 1); assert.equal(me.ignoreCover, true);
    play(s, p, ['K02', 'K02']); assert.deepEqual(me.rallyDone, ['assault3', 'assault5']); assert.equal(me.dmgTurn, 2);
  });
  test('starter cards have no squad and never count', () => {
    const { s, p, me } = scenario(37); zero(me);
    play(s, p, ['T001', 'T004', 'K04']); assert.equal(me.res.prec, 3); assert.equal(me.stats.squads, 0);
  });
});

describe('Loadout row', () => {
  test('a Loadout card goes to the row (2 slots), fires now and again at every Ready, and is never discarded or revealed', () => {
    const { s, p, me } = scenario(41); zero(me);
    const lo = card(s, 'L1R'); me.hand = [lo];
    assert.equal(WD.playCard(s, p, lo).ok, true);
    assert.deepEqual(me.loadout, [lo]); assert.equal(me.res.prec, 2);
    WD.endTurn(s, p); assert.ok(!me.discard.includes(lo) && !me.deck.includes(lo) && !me.hand.includes(lo));
    while (s.turn !== p) WD.endTurn(s, s.turn); // until my next Ready
    assert.ok(me.res.prec >= 2, 'Recon Post fired at Ready');
    assert.match(s.log.map(l => l.msg).join('\n'), /Loadout \(Recon Post\): \+2 Precision/);
  });
  test('with the row full you replace a slot (the old card goes to the discard) or use the new card once', () => {
    const { s, p, me } = scenario(43); zero(me);
    me.loadout = cards(s, ['L1R', 'L1E']);
    let c = card(s, 'L1S'); me.hand = [c];
    WD.playCard(s, p, c, { slot: 0 });
    assert.deepEqual(defs(s, me.loadout), ['L1E', 'L1S']); assert.deepEqual(defs(s, me.discard), ['L1R']);
    c = card(s, 'L1A'); me.hand = [c];
    WD.playCard(s, p, c, { once: true });
    assert.deepEqual(defs(s, me.loadout), ['L1E', 'L1S']); assert.ok(me.play.includes(c), 'used once, discarded at the end of the turn');
  });
});

describe('moving and looting', () => {
  test('moving costs 1 Movement per location, once per turn; the location bonus comes on arrival', () => {
    const { s, p, me } = scenario(5); place(s, 1, 5, p, { 3: 'E05', 4: 'E05' }); zero(me);
    me.res.move = 1;
    assert.equal(WD.moveCost(s, p, 3), 2);
    assert.match(WD.move(s, p, 3).err, /Needs 2 Movement/);
    me.res.move = 2;
    assert.equal(WD.move(s, p, 3).ok, true);
    assert.equal(me.pos, 3); assert.equal(me.res.move, 0); assert.equal(me.def, 1, 'Concrete Barrier: +1 Armor on arrival');
    me.res.move = 5;
    assert.match(WD.move(s, p, 4).err, /already moved/);
  });
  const stackAt = (where, seed = 9) => {
    const { s, p, me } = scenario(seed); place(s, 2, 5, p); zero(me); s.round = 4;
    const e = WD.envAt(s, where); const top = card(s, 'A11'); const under = card(s, 'A12');
    e.loot = [{ kind: 'card', iid: top }, { kind: 'card', iid: under }];
    return { s, p, me, top, under, e };
  };
  test('buying the top card costs its Intel; next door costs +1; only the top card, only here or next door', () => {
    assert.equal(WD.CARDS.A11.intel_cost, 1);
    let c = stackAt(2); c.me.res.intel = 1;
    assert.equal(WD.buy(c.s, c.p, c.top).ok, true); assert.equal(c.me.res.intel, 0); assert.ok(c.me.discard.includes(c.top));
    c = stackAt(3); c.me.res.intel = 1;
    assert.match(WD.buy(c.s, c.p, c.top).err, /Needs 2 Intel/);
    c.me.res.intel = 2; assert.equal(WD.buy(c.s, c.p, c.top).ok, true); assert.equal(c.me.res.intel, 0);
    c = stackAt(2); c.me.res.intel = 9;
    assert.equal(WD.buy(c.s, c.p, c.under).ok, false, 'only the top card can be bought');
    c = stackAt(4); c.me.res.intel = 9;
    assert.equal(WD.buy(c.s, c.p, c.top).ok, false, 'two locations away is out of reach');
  });
  test('at most 2 buys per turn (loot and Buy Station together); +1 Buy raises it', () => {
    const c = stackAt(2); c.me.res.intel = 20;
    assert.equal(WD.buySupply(c.s, c.p, 'K04').ok, true);
    assert.equal(WD.buySupply(c.s, c.p, 'K04').ok, true);
    assert.match(WD.buy(c.s, c.p, c.top).err, /No buys left/);
    c.me.buyBonus = 1; assert.equal(WD.buy(c.s, c.p, c.top).ok, true);
    assert.equal(WD.buysLeft(c.s, c.p), 0);
  });
  test('Hot Drop: in rounds 1–3 a gained card goes on top of your deck, later to the discard', () => {
    let c = stackAt(2); c.s.round = 3; c.me.res.intel = 9;
    WD.buy(c.s, c.p, c.top); assert.equal(c.me.deck[c.me.deck.length - 1], c.top);
    c = stackAt(2); c.s.round = 4; c.me.res.intel = 9;
    WD.buy(c.s, c.p, c.top); assert.ok(c.me.discard.includes(c.top));
  });
  test('buying a gun swaps it with yours (yours goes under that stack)', () => {
    const { s, p, me } = scenario(45); place(s, 2, 5, p); zero(me); me.res.intel = 9;
    const e = WD.envAt(s, 2); const g = 'w' + (s.nid++); s.weapons[g] = { iid: g, def: 'smg-0', shots: 0, used: false, att: null };
    const old = me.guns[0]; e.loot = [{ kind: 'weapon', iid: g }];
    assert.equal(WD.buy(s, p, g).ok, true); assert.equal(me.guns[0], g); assert.equal(e.loot[e.loot.length - 1].iid, old);
  });
  test('cycling the top card to the bottom costs 1 Intel or 1 Movement (free cycles first)', () => {
    const { s, p, me } = scenario(11); place(s, 2, 5, p); zero(me);
    const e = WD.envAt(s, 2);
    const [a, b, c] = ['A11', 'A12', 'A13'].map(d => card(s, d)); e.loot = [a, b, c].map(iid => ({ kind: 'card', iid }));
    assert.match(WD.cycle(s, p).err, /costs 1 Intel/);
    me.res.intel = 1; assert.equal(WD.cycle(s, p).ok, true); assert.equal(me.res.intel, 0);
    assert.deepEqual(e.loot.map(x => x.iid), [b, c, a]);
    me.res.move = 1; assert.equal(WD.cycle(s, p, 'move').ok, true); assert.equal(me.res.move, 0);
    me.freeCycles = 1; me.res.intel = 1; assert.equal(WD.cycle(s, p).ok, true);
    assert.equal(me.freeCycles, 0); assert.equal(me.res.intel, 1, 'the free cycle is used before Intel');
    e.loot = e.loot.slice(0, 1); assert.match(WD.cycle(s, p).err, /Only one card/);
  });
  test('the Buy Station sells 6 copies of each squad basic for 2 Intel', () => {
    const { s, p, me } = scenario(13); zero(me); s.round = 5;
    assert.deepEqual(T.station, ['K02', 'K04', 'K05', 'K03']);
    me.res.intel = 1; assert.match(WD.buySupply(s, p, 'K04').err, /cost 2 Intel/);
    me.res.intel = 2; assert.equal(WD.buySupply(s, p, 'K04').ok, true);
    assert.equal(me.res.intel, 0); assert.equal(s.stationLeft.K04, 5);
    assert.equal(s.cards[me.discard[me.discard.length - 1]].def, 'K04');
    s.stationLeft.K04 = 0; me.res.intel = 2; me.buys = 0; assert.match(WD.buySupply(s, p, 'K04').err, /sold out/);
    assert.equal(WD.buySupply(s, p, 'A11').ok, false);
  });
  test('Buy Station Scrap service: 1 Intel scraps a Sprint, once per turn, not a buy', () => {
    const { s, p, me } = scenario(14); zero(me);
    setCards(s, me, { hand: ['T001', 'T001', 'T002'], discard: Array(8).fill('T002') });
    me.res.intel = 3;
    assert.match(WD.stationScrap(s, p, me.hand[2]).err, /only takes a Sprint/);
    const x = me.hand[0];
    assert.equal(WD.stationScrap(s, p, x).ok, true); assert.ok(me.removed.includes(x)); assert.equal(me.res.intel, 2); assert.equal(me.buys, 0);
    assert.match(WD.stationScrap(s, p, me.hand[0]).err, /once per turn/);
  });
  test('Scrap removes a card from the game but never takes the deck below 7 cards', () => {
    const { s, p, me } = scenario(15);
    setCards(s, me, { hand: ['T001', 'T001', 'T001'], discard: ['T002', 'T002', 'T002', 'T002', 'T002'] }); // 8 cards
    assert.match(WD.scrap(s, p, me.hand[0]).err, /No Scrap available/);
    me.scrapAvail = 2;
    const x = me.hand[0];
    assert.equal(WD.scrap(s, p, x).ok, true); assert.ok(me.removed.includes(x)); assert.equal(me.scrapAvail, 1);
    assert.match(WD.scrap(s, p, me.hand[0]).err, /7-card minimum/);
  });
});

describe('end of turn and round', () => {
  test('unused Movement digs in as Armor, up to 2; Intel and Precision are lost; Firepower is recorded', () => {
    for (const [move, armor] of [[0, 0], [1, 1], [2, 2], [5, 2]]) {
      const { s, p, me } = scenario(17); zero(me); me.res.move = move; me.res.intel = 3; me.res.prec = 2;
      const n = me.fpHist.length;
      assert.equal(WD.endTurn(s, p).ok, true);
      assert.equal(me.def, armor, `${move} Movement left`);
      assert.deepEqual(me.res, { move: 0, prec: 0, intel: 0 });
      assert.equal(me.fpHist.length, n + 1);
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
  test('the circle closes one edge at the end of rounds 2, 4, 5, 6, 7 and 8, alternating sides, down to a final circle', () => {
    const s = WD.newGame({ seed: 23 }); for (const pl of s.players) pl.hp = 999;
    const sched = WD.closeSchedule(s); assert.deepEqual(Object.values(sched).sort((a, b) => a - b), [2, 4, 5, 6, 7, 8]);
    const sizes = [];
    for (let r = 1; r <= 9; r++) { toRound(s, r + 1); sizes.push(WD.safeBounds(s).n); }
    assert.deepEqual(sizes, [7, 6, 6, 5, 4, 3, 2, 1, 1]);
    for (const [w, r] of Object.entries(sched)) assert.equal(WD.envAt(s, +w).state, 'gas', `location ${w} closed after round ${r}`);
  });
  test('fresh loot lands on top of every safe stack each round; a stack never grows past 3', () => {
    const s = WD.newGame({ seed: 24 }); for (const pl of s.players) pl.hp = 999;
    const tops = s.envs.map(e => e.loot[0].iid);
    toRound(s, 2);
    const safe = s.envs.filter(e => e.state === 'safe');
    assert.ok(safe.every(e => e.loot.length <= 3));
    assert.ok(safe.filter(e => e.loot[0].iid !== tops[e.w]).length >= safe.length - 1, 'a new top card almost everywhere');
  });
  test('caught in the gas: 3 damage + 1 per extra location deep, then pushed back to the safe edge', () => {
    const { s, p, o, them } = scenario(25);
    s.round = 2; for (const e of s.envs) e.state = e.w >= 1 && e.w <= 5 ? 'safe' : 'gas'; s.closeSide = 'left'; them.pos = 0;
    // end of round 2: location 1 closes (left side), so the rival at 0 is 2 deep
    WD.endTurn(s, s.turn); if (!s.over && s.round === 2) WD.endTurn(s, s.turn);
    const B = WD.safeBounds(s);
    assert.equal(B.lo, 2);
    assert.equal(them.hp, 40 - (T.gasDmg + 2 - 1));
    assert.equal(them.pos, B.lo);
    assert.ok(s.players[p].hp === 40 || s.players[p].pos < B.lo);
    assert.ok(o === 1 - p);
  });
  test('final circle: once one location is left the storm hits both for 3, then 4, 5, 6', () => {
    const { s, me, them } = scenario(27);
    const w = me.pos; them.pos = w; s.round = 9;
    for (const e of s.envs) if (e.w !== w) e.state = 'gas';
    const hp = () => [me.hp, them.hp];
    toRound(s, 10); assert.deepEqual(hp(), [37, 37]);
    toRound(s, 11); assert.deepEqual(hp(), [33, 33]);
    assert.equal(s.over, false);
  });
  test('hard end after round 11: most Health wins (equal is a draw)', () => {
    for (const [a, b, want] of [[20, 15, 0], [10, 12, 1], [9, 9, 'draw']]) {
      const s = WD.newGame({ seed: 28 }); s.round = 11; s.players[0].hp = a; s.players[1].hp = b;
      WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
      assert.equal(s.over, true); assert.equal(s.endBy, 'hardEnd'); assert.equal(s.winner, want);
    }
  });
  test('if both operators fall at once, the one with more health left wins; equal is a draw', () => {
    const run = (hpMe, hpThem) => {
      const { s, p, me, them } = scenario(29);
      them.pos = me.pos; s.round = 9;
      for (const e of s.envs) if (e.w !== me.pos) e.state = 'gas';
      me.hp = hpMe; them.hp = hpThem;
      WD.endTurn(s, s.turn); WD.endTurn(s, s.turn);
      assert.equal(s.over, true);
      return s.winner === 'draw' ? 'draw' : s.winner === p ? 'me' : 'them';
    };
    assert.equal(run(1, 2), 'them');
    assert.equal(run(2, 1), 'me');
    assert.equal(run(2, 2), 'draw');
  });
});
