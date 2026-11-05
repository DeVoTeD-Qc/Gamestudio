// Layer 1: rule unit tests. Each test builds a hand-made state, calls one action and checks the result.
// These pin the CURRENT live rules (TUNE as shipped: the Engine & Synergy package, wb-rules, with push-your-luck FIRE, wb-pyl-impl). If a rule changes on purpose, change its test.
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

describe('firing: push your luck, Firefight (flip, bank, pot, Jam limit, cash out)', () => {
  // decks are listed bottom → top: the LAST card is flipped first
  const finalCircle = (s, w) => { for (const e of s.envs) e.state = e.w === w ? 'safe' : 'gas'; };
  test('FIRE starts a shot without flipping; each flip costs 1 Precision; flipped cards go to the discard pile when the shot ends', () => {
    const { s, p, me } = duel({ prec: 5, deck: ['T004', 'T004', 'K04'] });
    const r = WD.fireStart(s, p, 0);
    assert.equal(r.ok, true); assert.equal(me.res.prec, 5); assert.equal(me.deck.length, 3); assert.ok(s.shot);
    assert.equal(WD.flip(s, p).ok, true); assert.equal(me.res.prec, 4); assert.equal(s.shot.sum, 2); assert.equal(s.shot.level, 0);
    assert.equal(me.discard.length, 0, 'the flipped card stays in the shot until it ends');
    WD.stop(s, p); assert.equal(s.shot, null); assert.equal(me.discard.length, 1);
  });
  test('the ladder: STOP banks the step you are on into the pot; flip on for the next; the top step banks by itself; cashing out deals the pot', () => {
    assert.deepEqual(WD.WEAPONS['pistol-0'].ladder, [[2, 2], [4, 4], [6, 5]]);
    let d = duel({ prec: 9, deck: ['K04', 'K04', 'K04'] });
    WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p);
    let r = WD.stop(d.s, d.p); assert.equal(r.result.hit, true); assert.equal(r.result.level, 0); assert.equal(r.result.banked, 2);
    assert.equal(d.them.hp, 40, 'a banked shot deals nothing yet'); assert.equal(WD.potValue(d.me), 2);
    const c = WD.cashOut(d.s, d.p); assert.equal(c.total, 2); assert.equal(d.them.hp, 38); assert.equal(d.me.pot.length, 0);
    assert.match(WD.cashOut(d.s, d.p).err, /pot is empty/);
    d = duel({ prec: 9, deck: ['K04', 'K04', 'K04'] });
    WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p); WD.flip(d.s, d.p);
    r = WD.stop(d.s, d.p); assert.equal(r.result.banked, 4); assert.equal(r.result.level, 1);
    d = duel({ prec: 9, deck: ['K04', 'K04', 'K04'] });
    WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p); WD.flip(d.s, d.p); r = WD.flip(d.s, d.p);
    assert.equal(r.done, true); assert.equal(r.result.banked, 5); assert.equal(d.s.shot, null, 'the top step ends the shot');
  });
  test('the pot grows over several shots; each banked shot hits on its own when you cash out; End turn cashes out too', () => {
    const { s, p, me, them } = duel({ prec: 9, deck: Array(6).fill('K04') }); them.def = 2;
    assert.equal(WD.fire(s, p, 0, { cash: false }).ok, true); assert.equal(WD.fire(s, p, 0, { cash: false }).ok, true);
    assert.deepEqual(me.pot.map(x => x.dmg), [2, 2]); assert.equal(them.hp, 40);
    const c = WD.cashOut(s, p); assert.deepEqual(c.result.hits.map(h => h.dealt), [1, 1], 'Armor soaks each shot: 2 − 1, then 2 − 1'); assert.equal(them.def, 0);
    const d = duel({ prec: 9, deck: Array(6).fill('K04') });
    WD.fire(d.s, d.p, 0, { cash: false }); assert.equal(d.them.hp, 40);
    WD.endTurn(d.s, d.p); assert.equal(d.them.hp, 38); assert.match(d.s.log.map(l => l.msg).join('\n'), /cashes out Sidearm → HIT for 2/);
  });
  test('you cannot STOP before the first step', () => {
    const { s, p } = duel({ prec: 5, deck: ['K04', 'T004'] });
    WD.fireStart(s, p, 0); WD.flip(s, p);
    assert.match(WD.stop(s, p).err, /Reach the first step/); assert.ok(s.shot);
  });
  test('a Jam (Sprint, Scout) costs the gun\'s Recoil in Precision; Jams count for the whole turn; at the limit (2) you bust', () => {
    assert.equal(WD.CARDS.T001.jam, true); assert.equal(WD.CARDS.T002.jam, true); assert.ok(!WD.CARDS.T004.jam && !WD.CARDS.T005.jam);
    const { s, p, me, them } = duel({ prec: 8, deck: ['T002', 'T004', 'T001'] }); // Sidearm Recoil 2
    WD.fireStart(s, p, 0);
    let r = WD.flip(s, p); assert.equal(r.event, 'jam'); assert.equal(me.res.prec, 8 - 1 - 2); assert.equal(me.heat, 1); assert.equal(WD.jamLimit(s, p), 2);
    WD.flip(s, p); r = WD.flip(s, p);
    assert.equal(r.done, true); assert.equal(r.result.hit, false); assert.equal(r.result.how, 'bust'); assert.equal(them.hp, 40);
    assert.equal(me.stats.busts, 1); assert.equal(me.discard.length, 3);
  });
  test('BUST: the pot is lost and your shooting ends this turn; Jams from earlier shots count', () => {
    const { s, p, me, them } = duel({ prec: 12, deck: ['T001', 'K04', 'K04', 'T002'] }); me.shot = 1;
    WD.fireStart(s, p, 0); WD.flip(s, p); assert.equal(me.heat, 1); WD.flip(s, p); WD.stop(s, p); // Jam, then 2 Hit Markers: bank 2
    WD.fireStart(s, p, 0); WD.flip(s, p); WD.stop(s, p); assert.equal(WD.potValue(me), 4);
    WD.fireStart(s, p, 0); const r = WD.flip(s, p); // the turn's second Jam
    assert.equal(r.result.how, 'bust'); assert.equal(r.result.lost, 4); assert.equal(me.pot.length, 0); assert.equal(them.hp, 40);
    assert.equal(me.busted, true); assert.match(WD.fireStart(s, p, 0).err, /busted/); assert.equal(me.stats.wipes, 1);
    WD.endTurn(s, p); assert.equal(them.hp, 40, 'nothing to cash out');
  });
  test('the Jam limit is 2, +1 for each Rally you made this turn (a Rally between shots raises it); the final circle does not change it', () => {
    const { s, p, me } = duel({ prec: 12, deck: Array(6).fill('K04'), posThem: 2, types: { 2: 'E01' } });
    assert.equal(WD.jamLimit(s, p), 2);
    me.rallyDone = ['support3']; assert.equal(WD.jamLimit(s, p), 3);
    me.rallyDone = ['support3', 'support5', 'recon3']; assert.equal(WD.jamLimit(s, p), 5);
    me.rallyDone = []; for (const e of s.envs) e.state = e.w === me.pos ? 'safe' : 'gas'; assert.equal(WD.jamLimit(s, p), 2, 'no Hot Zone');
    // between shots you may play cards: three Support cards make a Rally and lift the limit
    const d = duel({ prec: 9, deck: Array(6).fill('K04') }); WD.fire(d.s, d.p, 0, { cash: false });
    d.me.hand = cards(d.s, ['K05', 'K05', 'K05']); for (const i of d.me.hand.slice()) assert.equal(WD.playCard(d.s, d.p, i).ok, true);
    assert.equal(WD.jamLimit(d.s, d.p), 3); assert.equal(WD.potValue(d.me), 2, 'the pot stays while you play cards');
  });
  test('Steady cancels a Jam: no Recoil, it does not count, and it is used up (it lasts across the turn\'s shots)', () => {
    const { s, p, me } = duel({ prec: 8, deck: ['T001', 'T001', 'T001'] }); me.revealPlus = 1;
    WD.fireStart(s, p, 0);
    let r = WD.flip(s, p); assert.equal(r.event, 'steady'); assert.equal(me.res.prec, 7); assert.equal(s.shot.jams, 0); assert.equal(me.revealPlus, 0);
    r = WD.flip(s, p); assert.equal(r.event, 'jam'); assert.equal(s.shot.jams, 1);
    r = WD.flip(s, p); assert.equal(r.result.how, 'bust');
  });
  test('out of Precision before the first step: that shot misses (the pot stays); out of Precision on a step: that step banks', () => {
    let d = duel({ prec: 1, deck: ['K04', 'T004'] });
    WD.fireStart(d.s, d.p, 0); let r = WD.flip(d.s, d.p);
    assert.equal(r.done, true); assert.equal(r.result.how, 'out'); assert.equal(r.result.hit, false); assert.equal(d.me.stats.outs, 1);
    d = duel({ prec: 3, deck: ['T004', 'T001', 'K04'] }); // 2 → step 1, then a Jam: 3 − 1 − 1 − 2 = 0 Precision
    WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p); r = WD.flip(d.s, d.p);
    assert.equal(r.done, true); assert.equal(r.result.hit, true); assert.equal(r.result.banked, 2); assert.equal(d.me.res.prec, 0);
    d = duel({ prec: 2, deck: ['T004', 'K04'] }); d.me.shot = 1; WD.fire(d.s, d.p, 0, { cash: false }); WD.fireStart(d.s, d.p, 0); r = WD.flip(d.s, d.p);
    assert.equal(r.result.how, 'out'); assert.equal(WD.potValue(d.me), 2, 'a miss keeps the pot');
  });
  test('no Precision: FIRE is refused', () => {
    const { s, p } = duel({ prec: 0, deck: ['T004'] });
    const r = WD.fireStart(s, p, 0); assert.equal(r.ok, false); assert.match(r.err, /Precision/);
  });
  test('Mark: the next shot needs 1 fewer Hit Marker on every step (then it is used up)', () => {
    const { s, p, me } = duel({ prec: 9, deck: Array(20).fill('T004') });
    me.nextFire.reqMod = 1;
    assert.deepEqual(WD.shotPreview(s, p, 0).steps.map(x => x[0]), [1, 3, 5]);
    WD.fire(s, p, 0);
    assert.deepEqual(WD.shotPreview(s, p, 0).steps.map(x => x[0]), [2, 4, 6]);
  });
  test('if the deck runs out mid-shot the discard pile is shuffled in; the cards of this shot stay out', () => {
    const { s, p, me } = duel({ prec: 9, deck: ['T004'] }); me.discard = cards(s, ['T004', 'T004']);
    WD.fireStart(s, p, 0); WD.flip(s, p); WD.flip(s, p);
    assert.equal(s.shot.flipped.length, 2); assert.equal(me.deck.length + me.discard.length, 1);
    WD.stop(s, p); assert.equal(me.discard.length + me.deck.length, 3);
  });
  test('the knife flips like any gun (2 → 4, 4 → 7) at distance 0, and needs Precision', () => {
    assert.deepEqual(WD.WEAPONS['knife-0'].ladder, [[2, 4], [4, 7]]);
    let d = duel({ gun: 'knife-0', prec: 3, deck: ['K04', 'K04'], posThem: 2, types: { 2: 'E05' } });
    let r = WD.fire(d.s, d.p, 0, { stopAt: 1 }); assert.equal(r.result.dealt, 7); assert.equal(d.me.res.prec, 1);
    d = duel({ gun: 'knife-0', prec: 0, deck: ['K04'], posThem: 2, types: { 2: 'E05' } });
    assert.match(WD.fireStart(d.s, d.p, 0).err, /Precision/);
  });
  test('during a shot nothing else can be done: play, move, buy and End turn wait for FLIP or STOP', () => {
    const { s, p, me } = duel({ prec: 5, deck: ['T004', 'T004'] }); me.hand = cards(s, ['T004']);
    WD.fireStart(s, p, 0);
    assert.match(WD.playCard(s, p, me.hand[0]).err, /Finish the shot/);
    assert.match(WD.endTurn(s, p).err, /Finish the shot/);
    assert.match(WD.fireStart(s, p, 0).err, /Finish the shot/);
    assert.match(WD.cashOut(s, p).err, /Finish the shot/);
  });
  test('"Your hits deal +1 damage this turn" adds to every step', () => {
    const { s, p, me } = duel({ prec: 2, deck: ['K04'] }); me.dmgTurn = 2;
    assert.equal(WD.fire(s, p, 0).result.dealt, 4);
  });
  test('cover takes 1 damage off; close quarters (distance 0) and Pierce ignore it', () => {
    const hit = (o) => { const { s, p } = duel(Object.assign({ prec: 2, deck: ['K04'] }, o)); if (o.pierce) s.players[p].ignoreCover = true; return WD.fire(s, p, 0).result.dealt; };
    assert.equal(WD.ENVS.E05.cover, 1); assert.equal(WD.ENVS.E01.cover, 0);
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' } }), 1, 'distance 1, target in cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E01' } }), 2, 'distance 1, open ground');
    assert.equal(hit({ posThem: 2, types: { 2: 'E05' } }), 2, 'same location: no cover');
    assert.equal(hit({ posThem: 3, types: { 3: 'E05' }, pierce: true }), 2, 'Pierce');
  });
  test('the best Reaction card in hand is used first, then Armor; close quarters ignores Armor; a hit deals at least 1', () => {
    const big = { prec: 2, deck: ['K04', 'K04'] }; // Sidearm second step: 4 damage
    const f = d => WD.fire(d.s, d.p, 0, { stopAt: 1 }).result.dealt;
    let d = duel(Object.assign({ themHand: ['E12'] }, big)); // Deployable Cover, Reaction 3
    assert.equal(f(d), 1);
    assert.equal(d.them.hand.length, 0); assert.equal(d.them.discard.length, 1, 'the reaction card is discarded');
    d = duel(big); d.them.def = 1; assert.equal(f(d), 3); assert.equal(d.them.def, 0, 'Armor is used up');
    d = duel(big); d.them.def = 5; assert.equal(f(d), 1); assert.equal(d.them.def, 2, 'only the Armor needed is used');
    d = duel(Object.assign({ posThem: 2, types: { 2: 'E01' } }, big)); d.them.def = 5;
    assert.equal(f(d), 4, 'close quarters: Armor ignored'); assert.equal(d.them.def, 5);
  });
  test('a gun fires up to its shots per turn; extra shots add to it', () => {
    const { s, p, me } = duel({ prec: 30, deck: Array(40).fill('K04') });
    assert.equal(WD.fire(s, p, 0).ok, true); assert.equal(WD.fire(s, p, 0).ok, true);
    const r = WD.fire(s, p, 0); assert.equal(r.ok, false); assert.match(r.err, /fired its shots/);
    me.shot = 1; assert.equal(WD.fire(s, p, 0).ok, true); assert.equal(me.shot, 0);
  });
  test('point blank: every gun fires from distance 0 up to its range', () => {
    let d = duel({ prec: 2, deck: ['T004', 'T004'], posMe: 1, posThem: 4, types: { 4: 'E01' } }); // Sidearm 0–2, distance 3
    const r = WD.fire(d.s, d.p, 0);
    assert.equal(r.ok, false); assert.match(r.err, /fires at distance 0–2/);
    assert.equal(d.me.deck.length, 2, 'a refused shot flips nothing');
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['K04', 'K04'], posThem: 2, types: { 2: 'E01' } });
    assert.equal(WD.fire(d.s, d.p, 0).ok, true, 'Longbow at distance 0');
    d = duel({ gun: 'sniper-1', prec: 3, deck: ['K04', 'K04'], posMe: 0, posThem: 5, types: { 5: 'E01' } });
    assert.equal(WD.fire(d.s, d.p, 0).ok, true);
  });
  test('a lethal hit ends the match', () => {
    const { s, p, them } = duel({ prec: 2, deck: ['K04'] });
    them.hp = 2; WD.fire(s, p, 0);
    assert.equal(s.over, true); assert.equal(s.winner, p); assert.equal(s.endBy, 'ko');
  });
  test('the fire report says "close quarters" once and the log keeps the flip sequence', () => {
    const big = { prec: 2, deck: ['K04'], posThem: 2, types: { 2: 'E01' } };
    let d = duel(big); d.them.def = 5;
    let notes = WD.fire(d.s, d.p, 0).result.notes;
    assert.equal(notes.filter(n => /close quarters/.test(n)).length, 1, notes.join(' · ')); assert.ok(notes.includes('close quarters: Armor ignored'));
    d = duel(big);
    notes = WD.fire(d.s, d.p, 0).result.notes;
    assert.equal(notes.filter(n => /close quarters/.test(n)).length, 1, notes.join(' · ')); assert.ok(notes.includes('close quarters'));
    assert.ok(d.s.log.some(l => /fires Sidearm: 2 → BANKED 2 \(step 1, banked; pot 2\)/.test(l.msg)), d.s.log.map(l => l.msg).join('\n'));
  });
  test('shotOdds: sure decks and hopeless decks give exact odds; the next-flip Jam and bust chances count the deck and the turn\'s Jams', () => {
    let d = duel({ prec: 9, deck: Array(8).fill('K04') });
    let o = WD.shotOdds(d.s, d.p, 0); assert.deepEqual(o.reach, [1, 1, 1]); assert.deepEqual(o.bust, [0, 0, 0]); assert.equal(o.pJam, 0);
    d = duel({ prec: 9, deck: Array(8).fill('T001') });
    o = WD.shotOdds(d.s, d.p, 0); assert.equal(o.reach[0], 0); assert.equal(o.bust[0], 1); assert.equal(o.pJam, 1); assert.equal(o.jamsLeft, 8);
    d = duel({ prec: 9, deck: ['K04', 'K04', 'T001', 'K04'] }); WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p);
    o = WD.shotOdds(d.s, d.p, 0); assert.equal(o.level, 0); assert.ok(Math.abs(o.pJam - 1 / 3) < 1e-9); assert.equal(o.pBust, 0, 'one Jam is not a bust yet');
    d.me.heat = 1; o = WD.shotOdds(d.s, d.p, 0); assert.ok(Math.abs(o.pBust - 1 / 3) < 1e-9, 'a Jam earlier this turn counts');
  });
  test('AI stop policy counts the pot: it banks when pushing is a bad bet, pushes when it is safe, and cashes out', () => {
    // two sure Focus cards then a deck of Jams: pushing past step 1 is hopeless, so the AI stops at step 1 and cashes out
    let d = duel({ prec: 9, deck: [...Array(6).fill('T001'), 'K04'] });
    WD.aiFireLoop(d.s, d.p); assert.equal(d.s.shot, null); assert.equal(d.s.lastFire.level, 0); assert.equal(d.s.lastFire.stopped, true);
    assert.equal(d.them.hp, 38); assert.equal(d.me.pot.length, 0);
    d = duel({ prec: 9, deck: Array(8).fill('K04') });
    WD.aiFireLoop(d.s, d.p); assert.equal(d.s.lastFire.level, 2, 'a sure push goes to the top step'); assert.equal(d.them.hp, 30, 'two top steps (5 + 5), cashed out');
  });
  test('the bust rule is swappable: Firefight ships; the earlier Hot Zone rule still runs; unbuilt values refuse to run', () => {
    assert.deepEqual(T.pyl, { flipCost: 1, jamRecoil: true, jamLimit: 2, rallyPlus: 1, finalMinus: 0, jamScope: 'turn', bustCost: 'pot', bank: 'pot' });
    const keep = Object.assign({}, T.pyl);
    try {
      Object.assign(T.pyl, { jamScope: 'shot', bustCost: 'shot', bank: 'shot', rallyPlus: 0, finalMinus: 1 }); // Hot Zone
      let d = duel({ prec: 8, deck: ['K04', 'T001'], posThem: 2, types: { 2: 'E01' } });
      for (const e of d.s.envs) e.state = e.w === d.me.pos ? 'safe' : 'gas';
      WD.fireStart(d.s, d.p, 0); assert.equal(WD.flip(d.s, d.p).result.how, 'bust', 'final circle: the first Jam misses');
      d = duel({ prec: 8, deck: ['K04'] }); WD.fireStart(d.s, d.p, 0); WD.flip(d.s, d.p); WD.stop(d.s, d.p); assert.equal(d.them.hp, 38, 'bank "shot": the hit lands at once');
      T.pyl.bank = 'turn'; d = duel({ prec: 9, deck: Array(4).fill('K04') });
      assert.throws(() => WD.fireStart(d.s, d.p, 0), /not built yet/);
    } finally { Object.assign(T.pyl, keep); }
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
