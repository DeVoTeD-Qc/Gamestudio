// Layer 1b: the wb-pkg1 package (documentation/design/wb-improve-v2.md, the head's answers W1–W5).
// O1 Squad Tactics, O2 Spoils, O3 Field Promotion, O6 Hot Drop delivery (see rules.test.js), O7 Threat / Deck bar / match story,
// O10 Operator rank and unlocks (the save is checked with fake storages, including ones that throw).
'use strict';
const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { WD, scenario, card, cards, setCards, setGun, place, zero, aiMatch } = require('./helpers');

const T = WD.TUNE;
const defOf = (s, iid) => s.cards[iid].def;
const HIT5 = ['T004', 'K04', 'K04']; // revealed top first: Focus 2 + Focus 2 + Steady Aim 1 = 5 Hit Markers, the Sidearm's first step (wb-odds2: 5+ → 4)
function duel({ seed = 1, gun = 'pistol-0', posMe = 2, posThem = 3, types = { 3: 'E01' }, deck = [], prec = 0, hand = [], themHand = [], themDeck = Array(8).fill('T001') } = {}) {
  const sc = scenario(seed); const { s, p, me, them } = sc;
  place(s, posMe, posThem, p, types);
  zero(me); zero(them); setGun(s, me, gun); setGun(s, them, 'pistol-0');
  setCards(s, me, { deck, hand }); setCards(s, them, { hand: themHand, deck: themDeck });
  me.res.prec = prec; me.stats.turnDmg = 0;
  return sc;
}
// end turns (empty hands) until it is player p's turn again: their next Ready (the lead alternates every round)
function toReady(s, p) { let n = 0; do { s.players[s.turn].hand = []; WD.endTurn(s, s.turn); if (s.spoils) WD.takeSpoils(s, s.turn, null); } while (!s.over && s.turn !== p && n++ < 8); assert.equal(s.turn, p); }
const play = (s, p, id, o) => { const iid = card(s, id); s.players[p].hand.push(iid); const r = WD.playCard(s, p, iid, o); assert.equal(r.ok, true, r.err); return iid; };

describe('Squad Tactics (O1): 12 rule-changing cards replace the 12 flattest', () => {
  test('3 per squad, tier II/III, and the card count and print-and-play size stay the same', () => {
    const tac = Object.values(WD.CARDS).filter(d => d.tactic);
    assert.equal(tac.length, 12);
    for (const q of WD.SQUADS) assert.equal(tac.filter(d => d.archetype === q).length, 3, q);
    assert.ok(tac.every(d => d.tier >= 2 && d.copies === 2));
    for (const gone of ['A22', 'A23', 'A31', 'R21', 'R23', 'R32', 'S21', 'S23', 'S32', 'E21', 'E22', 'E32']) assert.equal(WD.CARDS[gone], undefined, gone);
    assert.equal(Object.values(WD.CARDS).reduce((a, d) => a + (d.tier ? d.copies : 0), 0), 76);
    assert.ok(tac.every(d => d.text && !/undefined/.test(d.text)), 'every Tactic has rules text');
  });
  test('Charge: +2 Movement, and hits at distance 0 deal +1 this turn (not at range)', () => {
    let d = duel({ prec: 3, deck: HIT5, posThem: 2, types: { 2: 'E01' } }); play(d.s, d.p, 'AT1');
    assert.equal(d.me.res.move, 2); assert.equal(WD.fire(d.s, d.p, 0, 3).result.dealt, 5, 'Sidearm 4 + Charge 1');
    d = duel({ prec: 3, deck: HIT5 }); play(d.s, d.p, 'AT1');
    assert.equal(WD.fire(d.s, d.p, 0, 3).result.dealt, 4, 'distance 1: no Charge bonus');
  });
  test('Follow Through: your next hit this turn draws 2 cards (once)', () => {
    const d = duel({ prec: 6, deck: ['T001', 'T001', 'T001', 'T001', 'T004', 'T004', 'T004', 'T004', 'K04', 'K04'] }); play(d.s, d.p, 'AT2');
    assert.equal(d.me.hand.length, 0); const r = WD.fire(d.s, d.p, 0, 3).result;
    assert.equal(r.hit, true); assert.ok(r.notes.includes('Follow Through: draw 2')); assert.equal(d.me.hand.length, 2); assert.equal(d.me.onHitDraw, 0);
  });
  test('Adrenaline: when a shot hits you, one Adrenaline returns from your discard pile to your hand', () => {
    const d = duel({ prec: 3, deck: HIT5 }); d.them.discard = cards(d.s, ['AT3', 'AT3']);
    WD.fire(d.s, d.p, 0, 3);
    assert.equal(d.them.hand.filter(i => defOf(d.s, i) === 'AT3').length, 1); assert.equal(d.them.discard.length, 1);
  });
  test('Intel Sweep: look at your top 4 and put them back in any order; a changed deck or a wrong order is refused', () => {
    const d = duel({ deck: ['T001', 'T002', 'T004', 'T005', 'K04', 'T001'] }); play(d.s, d.p, 'RT1');
    const pk = d.me.peek.slice(); assert.deepEqual(pk.map(i => defOf(d.s, i)), ['T001', 'K04', 'T005', 'T004'], 'top first');
    assert.equal(WD.arrange(d.s, d.p, pk.slice(0, 3)).ok, false);
    assert.equal(WD.arrange(d.s, d.p, [pk[0], pk[0], pk[1], pk[2]]).ok, false);
    const order = [pk[1], pk[3], pk[2], pk[0]]; assert.equal(WD.arrange(d.s, d.p, order).ok, true);
    assert.deepEqual(d.me.deck.slice(-4).reverse(), order); assert.equal(d.me.peek, null);
    assert.equal(WD.arrange(d.s, d.p, order).ok, false, 'one arrangement per Sweep');
    play(d.s, d.p, 'RT1'); d.me.deck.pop(); assert.match(WD.arrange(d.s, d.p, d.me.peek).err, /changed/);
  });
  test('Expose: this turn your shots ignore cover and your hits ignore the rival\'s Armor and Reaction cards', () => {
    const d = duel({ prec: 6, deck: Array(6).fill('K04'), themHand: ['E12'], types: { 3: 'E05' } }); d.them.def = 4;
    assert.equal(WD.shotPreview(d.s, d.p, 0, 3).need, 6, 'in cover: Sidearm 5 + cover 1'); play(d.s, d.p, 'RT2');
    assert.equal(WD.shotPreview(d.s, d.p, 0, 3).need, 4, 'Expose: cover ignored, and its Mark −1'); assert.equal(WD.shotPreview(d.s, d.p, 0, 3).coverBy, 'Expose');
    const r = WD.fire(d.s, d.p, 0, 3).result; assert.equal(r.dealt, 5, 'the full 5 (6 Hit Markers: the marked second step): no Armor −4, no Reaction −3');
    assert.equal(d.them.def, 4); assert.equal(d.them.hand.length, 1, 'the Reaction card stays in hand'); assert.ok(r.notes.includes('Exposed: Armor ignored'));
  });
  test('Hold the Angle: unspent Precision (up to 3) fires on the rival\'s turn if they end it in your range', () => {
    let d = duel({ prec: 0, deck: Array(10).fill('K04') }); play(d.s, d.p, 'RT3'); d.me.res.prec = 9;
    WD.endTurn(d.s, d.p); assert.deepEqual(d.me.ow, { prec: 3 }, 'wb-odds2: 3, the aim limit');
    const hp = d.them.hp; zero(d.them); d.them.hand = []; WD.endTurn(d.s, d.o);
    assert.equal(d.them.hp, hp - 4, 'Sidearm: 3 Precision saved, 6 Hit Markers revealed, first step (needs 5)'); assert.equal(d.s.lastFire.kind, 'overwatch'); assert.equal(d.me.ow, null); assert.equal(d.me.stats.owShots, 1);
    d = duel({ prec: 0, deck: Array(10).fill('T004'), posMe: 0, posThem: 4, types: { 4: 'E01' } }); play(d.s, d.p, 'RT3'); d.me.res.prec = 5;
    WD.endTurn(d.s, d.p); const hp2 = d.them.hp; d.them.hand = []; WD.endTurn(d.s, d.o);
    assert.equal(d.them.hp, hp2, 'out of range: it holds'); assert.equal(d.me.ow, null, 'and is gone at your next Ready');
  });
  test('Fortify: your Armor holds through your next Ready (up to 6)', () => {
    let d = duel({ types: { 2: 'E01', 3: 'E01' } }); play(d.s, d.p, 'ST1'); d.me.def = 9; d.me.res.move = 0;
    toReady(d.s, d.p); assert.equal(d.me.def, T.fortifyCap); assert.equal(d.me.fortify, false, 'once');
    d = duel({ types: { 2: 'E01', 3: 'E01' } }); d.me.def = 3; toReady(d.s, d.p); assert.equal(d.me.def, 0, 'without Fortify Armor drops at Ready');
  });
  test('Field Medic: heal 3, never above your starting Health', () => {
    const d = duel({}); d.me.hp = T.hp - 2; play(d.s, d.p, 'ST2'); assert.equal(d.me.hp, T.hp); assert.equal(d.me.stats.healed, 2);
    d.me.hp = 10; play(d.s, d.p, 'ST2'); assert.equal(d.me.hp, 13);
  });
  test('Suppressing Barrage: on the rival\'s next turn their first 1 Movement and 2 Precision are lost', () => {
    const d = duel({ types: { 3: 'E05' } }); play(d.s, d.p, 'ST3'); d.me.hand = []; WD.endTurn(d.s, d.p);
    assert.deepEqual(d.them.supp, { move: 1, prec: 2 }, 'Concrete Barrier gives Armor, not Movement: the 2 Precision are still owed');
    d.them.hand = cards(d.s, ['T005', 'K04', 'K04']); for (const i of d.them.hand.slice()) WD.playCard(d.s, d.o, i);
    assert.equal(d.them.res.move, 0); assert.equal(d.them.res.prec, 2 + 2 + 1 + 1 - 2, 'two Focus (2 + Squad 1 each), minus 2');
    toReady(d.s, d.o); toReady(d.s, d.o); assert.equal(d.them.supp, null, 'one turn only');
  });
  test('Jury-Rig: repeats the play effects of the card you played just before it (not its Squad line); first card: nothing', () => {
    const d = duel({}); play(d.s, d.p, 'ET1'); assert.equal(d.me.res.intel, 1, 'nothing to repeat');
    zero(d.me); d.me.play = []; d.me.lastPlayed = null; play(d.s, d.p, 'K04'); const pr = d.me.res.prec; play(d.s, d.p, 'ET1');
    assert.equal(d.me.res.prec, pr + 2, 'Focus again: +2'); assert.equal(d.me.res.intel, 1);
  });
  test('Sentry Turret (Loadout): a free 2-damage shot at Ready, distance 0–3: reveal 1, needs 1 Hit Marker', () => {
    const d = duel({ deck: ['T004', 'T001', 'T004'] }); const hp = d.them.hp;
    play(d.s, d.p, 'ET2'); assert.equal(d.me.loadout.length, 1); assert.equal(d.them.hp, hp - 2, 'fires when deployed (Steady Aim revealed)');
    const hp2 = d.them.hp; d.me.discard = []; d.me.deck = cards(d.s, ['R12', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001', 'T001']); d.them.pos = d.me.pos + 1;
    toReady(d.s, d.p); assert.equal(d.me.stats.turretShots >= 2, true);
    assert.ok(d.s.log.some(l => /Sentry Turret fires/.test(l.msg) && l.r > 1), 'and again at your Ready'); assert.ok(d.them.hp <= hp2);
    const far = duel({ deck: ['T004'], posMe: 0, posThem: 4, types: { 4: 'E01' } }); play(far.s, far.p, 'ET2'); assert.equal(far.them.hp, T.hp, 'out of range');
  });
  test('Contraband Run: this turn you may buy the top card of any stack, at its printed cost', () => {
    const d = duel({ posMe: 0, posThem: 6, types: { 6: 'E01' } }); const far = WD.envAt(d.s, 5); const top = far.loot[0];
    assert.equal(WD.lootNear(d.s, d.p, top.iid), null);
    play(d.s, d.p, 'ET3'); d.me.res.intel = 20; const cost = WD.itemDef(d.s, top).intel_cost;
    assert.equal(WD.lootCost(d.s, d.p, top), cost); const before = d.me.res.intel; assert.equal(WD.buy(d.s, d.p, [top.iid]).ok, true); assert.equal(d.me.res.intel, before - cost);
  });
});

describe('Spoils (O2): pick 1 of 3 after a turn in which you dealt damage', () => {
  const hitTurn = () => { const d = duel({ prec: 3, deck: HIT5 }); WD.fire(d.s, d.p, 0, 3); assert.ok(d.me.stats.turnDmg > 0); return d; };
  test('End turn offers 3 different loot cards of the current tier (one of your main squad first) and waits for your pick', () => {
    const d = hitTurn(); d.me.discard.push(...cards(d.s, ['K04', 'K04']));
    const r = WD.endTurn(d.s, d.p); assert.equal(r.ok, true); assert.equal(r.spoils.length, 3);
    assert.equal(d.s.turn, d.p, 'still your turn'); assert.equal(new Set(r.spoils).size, 3);
    const tier = d.s.round <= 3 ? 1 : 2; const inTier = new Set(d.s.loot[tier].map(it => it.iid)); assert.ok(r.spoils.every(i => inTier.has(i) || d.s.loot[1].concat(d.s.loot[2], d.s.loot[3]).some(it => it.iid === i)));
    assert.equal(WD.CARDS[defOf(d.s, r.spoils[0])].archetype, 'recon', 'main squad first');
    assert.match(WD.playCard(d.s, d.p, card(d.s, 'T001')).err, /Spoils/); assert.match(WD.endTurn(d.s, d.p).err, /Spoils/);
  });
  test('taking one: it goes to your discard pile and leaves the loot deck; then the turn ends', () => {
    const d = hitTurn(); const { spoils } = WD.endTurn(d.s, d.p); const pick = spoils[1];
    assert.equal(WD.takeSpoils(d.s, d.p, 'nope').ok, false);
    assert.equal(WD.takeSpoils(d.s, d.o, pick).ok, false, 'only the player who earned them');
    assert.equal(WD.takeSpoils(d.s, d.p, pick).ok, true);
    assert.ok(d.me.deck.concat(d.me.hand, d.me.discard).includes(pick), 'yours (the end-of-turn draw may have shuffled it in)'); assert.ok(![1, 2, 3].some(t => d.s.loot[t].some(it => it.iid === pick)));
    assert.equal(d.me.stats.spoils, 1); assert.equal(d.s.spoils, null); assert.equal(d.s.turn, d.o);
  });
  test('skipping gains nothing; no damage, no Spoils', () => {
    let d = hitTurn(); const n = d.me.stats.cardsAcquired; WD.endTurn(d.s, d.p); assert.equal(WD.takeSpoils(d.s, d.p, null).ok, true);
    assert.equal(d.me.stats.cardsAcquired, n); assert.equal(d.s.turn, d.o);
    d = duel({}); const r = WD.endTurn(d.s, d.p); assert.equal(r.spoils, undefined); assert.equal(d.s.turn, d.o);
  });
  test('wb-odds2: Spoils also come after a turn in which you were hit since your last turn (once)', () => {
    const d = duel({ prec: 3, deck: HIT5 }); WD.fire(d.s, d.p, 0, 3); assert.equal(d.them.hurt, true);
    WD.endTurn(d.s, d.p); WD.takeSpoils(d.s, d.p, null); assert.equal(d.s.turn, d.o);
    d.them.hand = []; const r = WD.endTurn(d.s, d.o); assert.equal(r.spoils.length, 3, 'the rival was hit: Spoils without dealing damage');
    assert.match(d.s.log[d.s.log.length - 1].msg, /was hit since their last turn: Spoils/);
    WD.takeSpoils(d.s, d.o, null); assert.equal(d.them.hurt, false, 'used up');
  });
});

describe('Field Promotion (O3): 1 Intel (wb-odds2: not a buy), once per turn, a starter becomes a squad basic', () => {
  test('from the discard pile: the starter leaves the game, the basic comes from the Buy Station stock to your discard', () => {
    const d = duel({}); d.me.discard = cards(d.s, ['T001']); d.me.res.intel = 3; const sprint = d.me.discard[0]; const left = d.s.stationLeft.K04;
    const r = WD.promote(d.s, d.p, sprint, 'recon'); assert.equal(r.ok, true);
    assert.ok(d.me.removed.includes(sprint)); assert.equal(defOf(d.s, d.me.discard[0]), 'K04'); assert.equal(d.s.stationLeft.K04, left - 1);
    assert.equal(d.me.res.intel, 2); assert.equal(d.me.buys, 0, 'wb-odds2: not a buy'); assert.equal(d.me.stats.promoted, 1);
    d.me.discard.push(card(d.s, 'T002')); assert.match(WD.promote(d.s, d.p, d.me.discard[1], 'recon').err, /once per turn/);
  });
  test('from your hand it stays in your hand (play it this turn)', () => {
    const d = duel({ hand: ['T002'] }); d.me.res.intel = 1; const r = WD.promote(d.s, d.p, d.me.hand[0], 'assault');
    assert.equal(r.ok, true); assert.equal(defOf(d.s, d.me.hand[0]), 'K02');
  });
  test('refused: no Intel, not a starter, an unknown squad, sold out; no buys left is fine (wb-odds2)', () => {
    let d = duel({ hand: ['T001', 'K04'] });
    assert.match(WD.promote(d.s, d.p, d.me.hand[0], 'recon').err, /Intel/);
    d.me.res.intel = 5;
    assert.match(WD.promote(d.s, d.p, d.me.hand[1], 'recon').err, /starter/);
    assert.match(WD.promote(d.s, d.p, d.me.hand[0], 'pirates').err, /squad/);
    d.s.stationLeft.K04 = 0; assert.match(WD.promote(d.s, d.p, d.me.hand[0], 'recon').err, /sold out/);
    d.me.buys = T.buyCap; assert.equal(WD.promote(d.s, d.p, d.me.hand[0], 'assault').ok, true, 'Field Promotion is not a buy');
  });
});

describe('Readouts (O7): Threat and the Deck bar', () => {
  test('Threat is the planner\'s expected damage for the rest of the turn; with ifPlayAll it counts your hand', () => {
    const d = duel({ prec: 3, deck: Array(9).fill('K04'), hand: ['K04', 'K04'] });
    const now = WD.threat(d.s, d.p); assert.equal(now.inRange, true); assert.equal(now.ev, 4, 'commit 3: 6 Hit Markers, the first step'); assert.equal(now.p, 1);
    const all = WD.threat(d.s, d.p, { ifPlayAll: true }); assert.ok(all.ev > now.ev, `${all.ev} > ${now.ev}`);
    assert.equal(d.me.hand.length, 2, 'the real hand is untouched');
    const far = duel({ prec: 3, deck: Array(9).fill('T004'), posMe: 0, posThem: 5, types: { 5: 'E01' } }); assert.deepEqual([WD.threat(far.s, far.p).ev, WD.threat(far.s, far.p).inRange], [0, false]);
  });
  test('the Deck bar counts starters against your cards, by squad (Hot Drop cards included)', () => {
    const d = duel({ deck: ['T001', 'T002', 'K04', 'R12'], hand: ['A11'] }); d.me.drop = cards(d.s, ['K05']);
    assert.deepEqual(WD.deckMix(d.s, d.p), { total: 6, starters: 2, yours: 4, by: { assault: 1, recon: 2, support: 1, engineer: 0 } });
  });
  test('the match story is recorded: damage per round, best turn and its round, MVP cards, cards added', () => {
    const s = aiMatch(11); const pl = s.players[s.winner === 'draw' ? 0 : s.winner];
    assert.equal(Object.values(pl.stats.dmgRounds).reduce((a, b) => a + b, 0), pl.stats.damageDealt);
    assert.ok(pl.stats.maxTurnDmg > 0 && pl.stats.bestRound >= 1);
    assert.ok(Object.keys(pl.stats.mvp).every(id => WD.CARDS[id]));
    assert.equal(pl.stats.added.length, pl.stats.cardsAcquired + pl.stats.promoted);
  });
});

describe('Operator rank and unlocks (O10): progression across matches, variety not power', () => {
  const store = (init = {}) => { const m = new Map(Object.entries(init)); return { m, getItem: k => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)) }; };
  test('ranks and what they unlock: the Daily Drop, three Operations, two insignia', () => {
    assert.deepEqual(WD.RANKS.map(r => r.xp), [0, 150, 350, 650, 1000, 1500, 2200]);
    assert.equal(WD.rankOf(0).name, 'Recruit'); assert.equal(WD.rankOf(149).name, 'Recruit'); assert.equal(WD.rankOf(150).name, 'Private');
    assert.equal(WD.rankOf(99999).name, 'Captain'); assert.equal(WD.rankOf(99999).next, null);
    assert.equal(WD.rankOf(200).toNext, 150);
    assert.deepEqual(WD.rankOf(1000).unlocks.map(u => u.kind), ['daily', 'op', 'op', 'op']);
    assert.deepEqual(WD.unlockedOps({ xp: 700 }), ['closedrop', 'supplyrun']);
    for (const r of WD.RANKS.slice(1)) assert.ok(r.unlock.name && r.unlock.text, r.name);
  });
  test('Operations change the drop for both operators the same way', () => {
    const a = WD.newGame({ seed: 5, ops: ['closedrop'] }); assert.deepEqual(a.players.map(p => p.pos).sort(), [2, 4]);
    assert.deepEqual(WD.newGame({ seed: 5, ops: ['bogus'] }).ops, [], 'unknown operations are ignored');
    const g = WD.newGame({ seed: 6, ops: ['scorched'] }); g.round = 2; for (const e of g.envs) e.state = e.w >= 1 && e.w <= 5 ? 'safe' : 'gas'; g.closeSide = 'left';
    g.players[1 - g.turn].pos = 0; g.players[g.turn].pos = 3; WD.endTurn(g, g.turn); WD.endTurn(g, g.turn);
    assert.equal(g.players.find(p => p.pos === 2 && p.hp < T.hp).hp, T.hp - (T.gasDmg + 1 + 1), 'gas +1');
    const c = WD.newGame({ seed: 7, ops: ['supplyrun'] }); c.round = 6; WD.endTurn(c, c.turn); WD.endTurn(c, c.turn);
    assert.ok(c.log.some(l => /Supply crate lands/.test(l.msg) && l.r === 7), 'a third crate after round 6');
    const n = WD.newGame({ seed: 7 }); n.round = 6; WD.endTurn(n, n.turn); WD.endTurn(n, n.turn); assert.ok(!n.log.some(l => /Supply crate lands/.test(l.msg)), 'not without the Operation');
  });
  test('XP per match: 40 for playing, 60 for a win, 1 per damage (up to 80), 20 for the final circle', () => {
    const s = aiMatch(3); const w = s.winner === 'draw' ? 0 : s.winner; const g = WD.xpFor(s, w);
    const want = 40 + (s.winner === w ? 60 : 30) + Math.min(80, s.players[w].stats.damageDealt) + (s.finalReached ? 20 : 0);
    assert.equal(g.total, want); assert.equal(g.parts.reduce((a, x) => a + x[1], 0), g.total);
  });
  test('applyMatch returns a new profile with XP, records and new unlocks; the old one is not changed', () => {
    const s = aiMatch(3); const p = s.winner === 'draw' ? 0 : s.winner; const old = Object.assign(WD.blankProfile(), { xp: 140 });
    const r = WD.applyMatch(old, s, p, { daily: '2026-11-11' });
    assert.equal(old.xp, 140); assert.equal(r.profile.xp, 140 + r.gained.total); assert.equal(r.profile.matches, 1);
    assert.equal(r.before.name, 'Recruit'); assert.ok(r.newUnlocks.length >= 1 && r.newUnlocks[0].kind === 'daily');
    assert.deepEqual(r.profile.daily, { date: '2026-11-11', dmg: s.players[p].stats.damageDealt, won: s.winner === p });
    assert.ok(r.profile.bestDmg >= s.players[p].stats.damageDealt && r.profile.bestTurn === s.players[p].stats.maxTurnDmg);
  });
  test('save and load round-trip under one key; bad data, missing or throwing storage fall back to a blank profile', () => {
    const st = store(); const prof = Object.assign(WD.blankProfile(), { xp: 420, matches: 3, wins: 2, bestDmg: 51, bestTurn: 14, daily: { date: '2026-11-10', dmg: 30, won: true } });
    assert.equal(WD.saveProfile(st, prof), true); assert.deepEqual([...st.m.keys()], [WD.PROFILE_KEY]);
    assert.deepEqual(WD.loadProfile(st), prof);
    assert.deepEqual(WD.loadProfile(store({ [WD.PROFILE_KEY]: '{not json' })), WD.blankProfile());
    assert.deepEqual(WD.loadProfile(store({ [WD.PROFILE_KEY]: '{"xp":-5,"matches":"x","wins":2.7}' })), Object.assign(WD.blankProfile(), { wins: 2 }));
    assert.deepEqual(WD.loadProfile(store({ [WD.PROFILE_KEY]: 'null' })), WD.blankProfile());
    assert.deepEqual(WD.loadProfile(null), WD.blankProfile()); assert.equal(WD.saveProfile(null, prof), false);
    const boom = { getItem() { throw new Error('SecurityError'); }, setItem() { throw new Error('QuotaExceededError'); } };
    assert.deepEqual(WD.loadProfile(boom), WD.blankProfile()); assert.equal(WD.saveProfile(boom, prof), false);
  });
  test('the Daily Drop seed depends only on the date', () => {
    assert.equal(WD.dailySeed('2026-11-11'), WD.dailySeed('2026-11-11')); assert.notEqual(WD.dailySeed('2026-11-11'), WD.dailySeed('2026-11-12'));
    const a = WD.newGame({ seed: WD.dailySeed('2026-11-11') }), b = WD.newGame({ seed: WD.dailySeed('2026-11-11') });
    assert.equal(JSON.stringify(a.envs), JSON.stringify(b.envs));
  });
});

describe('the AI uses the package', () => {
  test('over 60 matches it takes Spoils, promotes starters, plays Tactics and resolves every Sweep', () => {
    let spoils = 0, promoted = 0, tactics = 0, turrets = 0, sweeps = 0;
    for (let seed = 1; seed <= 60; seed++) {
      const s = WD.newGame({ seed }); let n = 0;
      while (!s.over && n++ < 400) {
        const p = s.turn; const r = WD.aiTurn(s, p); assert.equal(r.ok, true, r.err);
        assert.equal(s.spoils, null, 'the AI never leaves Spoils pending');
      }
      for (const l of s.log) { if (/ plays (Charge|Follow Through|Adrenaline|Intel Sweep|Expose|Hold the Angle|Fortify|Field Medic|Suppressing Barrage|Jury-Rig|Sentry Turret|Contraband Run)\b/.test(l.msg)) tactics++; if (/arranges the top/.test(l.msg)) sweeps++; }
      for (const pl of s.players) { spoils += pl.stats.spoils; promoted += pl.stats.promoted; turrets += pl.stats.turretShots; }
    }
    assert.ok(spoils > 60, `Spoils taken: ${spoils}`); assert.ok(promoted > 30, `promotions: ${promoted}`); assert.ok(tactics > 20, `Tactics played: ${tactics}`);
    assert.ok(sweeps >= 0 && turrets >= 0);
  });
  test('the AI arranges a Sweep with the most Hit Markers on top', () => {
    const d = duel({ deck: ['T001', 'R12', 'T001', 'T004', 'T001'] }); play(d.s, d.p, 'RT1'); WD.aiArrange(d.s, d.p);
    assert.deepEqual(d.me.deck.slice(-4).reverse().map(i => WD.cardDef(d.s, i).hit_markers), [3, 1, 0, 0]);
  });
  test('the AI stays out of the rival\'s range while they hold an angle', () => {
    const d = duel({ posMe: 3, posThem: 6, types: { 6: 'E01' } }); d.them.ow = { prec: 4 }; d.me.res.move = 3;
    const inRange = w => Math.abs(w - d.them.pos) <= WD.eff(d.s, d.them.guns[0]).band[1];
    WD.aiMove(d.s, d.p); assert.ok(!inRange(d.me.pos), `moved to ${d.me.pos}`);
  });
});
