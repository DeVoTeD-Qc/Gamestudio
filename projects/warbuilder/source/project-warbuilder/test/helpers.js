// Shared helpers for the Warbuilder rules tests (node:test, no dependencies).
'use strict';
const path = require('path');
const crypto = require('crypto');

const SRC = path.join(__dirname, '..', 'src');
const WD = require(path.join(SRC, 'engine.js'));

// ---------- building a scenario by hand ----------
// newGame({seed}) and then hand-edit the plain state object. The engine keeps everything in `s`,
// so a test can set hands, decks, guns, positions and resources directly before calling one action.
function scenario(seed = 1) {
  const s = WD.newGame({ seed });
  const p = s.turn; const o = 1 - p;
  return { s, p, o, me: s.players[p], them: s.players[o] };
}
// a new card instance of `def`; not placed anywhere (put it in a zone yourself)
function card(s, def) {
  if (!WD.CARDS[def]) throw new Error(`unknown card ${def}`);
  const iid = 'c' + (s.nid++); s.cards[iid] = { iid, def }; return iid;
}
const cards = (s, defs) => defs.map(d => card(s, d));
// replace a player's whole card pool. deck is listed bottom → top (the engine draws with pop()).
function setCards(s, pl, { deck = [], hand = [], discard = [] } = {}) {
  pl.deck = cards(s, deck); pl.hand = cards(s, hand); pl.discard = cards(s, discard); pl.play = []; pl.loadout = []; pl.fuelled = []; pl.removed = [];
}
// give player `pl` gun `def` in slot 0, unfired this turn
function setGun(s, pl, def) {
  if (!WD.WEAPONS[def]) throw new Error(`unknown gun ${def}`);
  const iid = 'w' + (s.nid++); s.weapons[iid] = { iid, def, shots: 0, used: false, att: null }; pl.guns[0] = iid; return iid;
}
// put both operators on the map. Locations get the given types (ENVS ids) where asked.
function place(s, posMe, posThem, p, types = {}) {
  s.players[p].pos = posMe; s.players[1 - p].pos = posThem;
  for (const w in types) { const e = WD.envAt(s, +w); e.def = types[w]; e.state = 'safe'; }
}
const zero = pl => { pl.res = { move: 0, prec: 0, intel: 0 }; pl.def = 0; pl.shot = 0; pl.freeCycles = 0; pl.revealPlus = 0; pl.dmgTurn = 0; pl.ignoreCover = false; pl.buys = 0; pl.buyBonus = 0; pl.scrapAvail = 0; pl.squadN = {}; pl.rallyDone = []; pl.nextFire = { reqMod: 0, bonusPrec: 0 }; pl.moved = false; };

// ---------- playing whole matches ----------
// AI vs AI. `onTurn(s)` runs after every turn (for invariant checks). Returns the final state.
function aiMatch(seed, { maxTurns = 400, onTurn } = {}) {
  const s = WD.newGame({ seed }); let n = 0;
  while (!s.over) {
    if (n++ >= maxTurns) throw new Error(`seed ${seed}: no result after ${maxTurns} turns`);
    const r = WD.aiTurn(s, s.turn); if (!r.ok) throw new Error(`seed ${seed}: aiTurn failed: ${r.err}`);
    if (onTurn) onTurn(s);
  }
  return s;
}
// A fixed, AI-free policy (rules-only replays): play every card, fire gun 0 while the rules allow (each shot commits all Precision), end the turn,
// take the first Spoils card when offered.
function scriptedMatch(seed, { maxTurns = 400 } = {}) {
  const s = WD.newGame({ seed }); const actions = []; let n = 0;
  while (!s.over) {
    if (n++ >= maxTurns) throw new Error(`seed ${seed}: no result after ${maxTurns} turns`);
    const p = s.turn;
    WD.playAll(s, p); actions.push('playAll');
    for (let k = 0; k < 6 && !s.over && WD.shootCheck(s, p, 0).ok; k++) { WD.fire(s, p, 0); actions.push('fire'); }
    if (s.over) break;
    const r = WD.endTurn(s, p); if (!r.ok) throw new Error(`seed ${seed}: endTurn failed: ${r.err}`); actions.push('end');
    if (s.spoils) { const t = WD.takeSpoils(s, p, s.spoils.offer[0]); if (!t.ok) throw new Error(`seed ${seed}: takeSpoils failed: ${t.err}`); actions.push('spoils'); } // Spoils: always the first card
  }
  return { s, actions };
}
// stable fingerprint of a state; the log text is left out so wording changes don't break replays
function stateHash(s) {
  const copy = Object.assign({}, s, { log: undefined, _rec: undefined });
  return crypto.createHash('sha256').update(JSON.stringify(copy)).digest('hex').slice(0, 16);
}

// ---------- card bookkeeping ----------
// every card instance must be in at most one place; returns the number of placed cards
function cardPlaces(s) {
  const seen = new Map();
  const note = (iid, where) => { if (seen.has(iid)) throw new Error(`card ${iid} is in ${seen.get(iid)} and ${where}`); seen.set(iid, where); };
  s.players.forEach((pl, i) => ['deck', 'discard', 'hand', 'play', 'loadout', 'fuelled', 'removed', 'drop'].forEach(z => (pl[z] || []).forEach(c => note(c, `p${i}.${z}`))));
  s.gone.forEach(it => note(it.iid, 'gone'));
  s.envs.forEach(e => e.loot.forEach(it => note(it.iid, `loc${e.w}`)));
  [1, 2, 3].forEach(t => s.loot[t].forEach(it => note(it.iid, `loot${t}`)));
  s.players.forEach((pl, i) => pl.guns.filter(Boolean).forEach(w => note(w, `p${i}.gun`)));
  return seen.size;
}

module.exports = { WD, SRC, scenario, card, cards, setCards, setGun, place, zero, aiMatch, scriptedMatch, stateHash, cardPlaces };
