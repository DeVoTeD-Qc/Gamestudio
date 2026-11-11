// Replays rally_v5.py traces through the rules engine and AI inside rally-point-game.html.
//   python3 -I -B rally_v5_trace.py 10 7 > traces.json
//   node rally_game_replay.mjs traces.json [../rally-point-game.html]
// For every placement: the legal-move count and the AI's best value must match the sim, and the
// sim's chosen move must be one of the engine's best moves (the sim breaks ties at random).  The
// sim's move is then applied, and after every placement, end-of-turn orders and pass the engine's
// state must equal the sim's: scores, rallies, the four meters, Front, Armor, streaks, Spot, the
// winner, every square's tile and owner, Charges on objectives, both hands and both stacks.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const traces = JSON.parse(fs.readFileSync(process.argv[2] || "traces.json", "utf8"));
const html = fs.readFileSync(process.argv[3] || path.join(here, "..", "rally-point-game.html"), "utf8");
const a = html.indexOf("/*ENGINE-START*/"), b = html.indexOf("/*ENGINE-END*/");
if (a < 0 || b < 0) throw new Error("engine markers not found");
const E = new Function(html.slice(a, b) + "\nreturn {newState,setLayer,setPolicies,movesFor,evalMoves,doPlace,doOrders,doPass,refill,gameOver,endScore,outcome,STACKS,CH,get CURW(){return CURW;},setW:w=>{CURW=w;},WSETS,FLAGS,CFG:()=>CFG};")();

const SIM2JS = { "T1 Spearhead (A+R)": "T1", "T2 Hold the Line (E+S)": "T2", "T3 Relay Net (R+E)": "T3", "T4 Shock and Supply (A+S)": "T4" };
for (const [k, v] of Object.entries(traces.stacks)) {
  const mine = E.STACKS[SIM2JS[k]].slice().sort().join(), theirs = v.slice().sort().join();
  if (mine !== theirs) throw new Error(`stack ${k} differs: ${mine} vs ${theirs}`);
}
function snap(s) {
  const charges = {};
  for (const [q, e] of s.pcs) if (e.kind === "hub") charges[String(q)] = e.charges;
  return { score: s.score, rallies: s.rallies, mat: s.mat, front: s.front, armor: s.armor, streak: s.streak, spot: s.spot,
    winner: s.winner, own: s.own.map(q => q ? s.pcs.get(q).cid + ":" + s.pcs.get(q).owner : ""), charges, hands: s.hands, decks: s.decks };
}
function diff(js, py) {
  const out = [];
  for (const k of Object.keys(py)) if (JSON.stringify(js[k]) !== JSON.stringify(py[k])) out.push(`${k}: js ${JSON.stringify(js[k])} sim ${JSON.stringify(py[k])}`);
  return out;
}
const total = { games: 0, placements: 0, orders: 0, passes: 0, bad: 0, aiChecked: 0, rallies: 0, strikes: 0, fronts: 0, breakthroughs: 0, streak3: 0, streak5: 0, streak7: 0, endTies: 0 };
const perLayer = [];
for (const L of traces.layers) {
  E.setLayer(L.layer);
  const cfg = E.CFG();
  for (const k of Object.keys(L.cfg)) if (k in cfg && JSON.stringify(cfg[k]) !== JSON.stringify(L.cfg[k])) throw new Error(`layer ${L.layer} cfg ${k}: js ${JSON.stringify(cfg[k])} sim ${JSON.stringify(L.cfg[k])}`);
  const row = { layer: L.layer, name: L.name, games: 0, placements: 0, orders: 0, passes: 0, bad: 0, aiChecked: 0, ties: 0, rallies: 0, strikes: 0, removed: 0, fronts: 0, breakthroughs: 0, rewards: 0, fm: 0, drops: 0, outcomeOk: 0 };
  for (const [gi, g] of L.games.entries()) {
    const s = E.newState(8, 8);
    s.decks = g.decks0.map(d => d.slice());
    s.hands = [0, 1].map(p => [s.decks[p].pop(), s.decks[p].pop(), s.decks[p].pop()]);
    s.score[1] += 1;
    E.setPolicies(g.policies);
    s.ev = [];
    let ok = true;
    for (const [si, st] of g.steps.entries()) {
      const p = st.p;
      E.setW(E.WSETS[g.policies[p]] || E.FLAGS);
      let errs = [];
      if (st.t === "place") {
        const uniq = [...new Set(s.hands[p])];
        const nm = uniq.reduce((n, c) => n + E.movesFor(s, c).length, 0);
        if (nm !== st.nmoves) errs.push(`move count js ${nm} sim ${st.nmoves}`);
        const opts = E.evalMoves(s, s.hands[p], p, g.policies[p]);
        const best = Math.max(...opts.map(o => o.val));
        if (Math.abs(best - st.val) > 1e-6) errs.push(`best value js ${best} sim ${st.val}`);
        const key = o => o.cid + "|" + o.m[0] + "|" + o.m[1].join(",");
        const want = st.cid + "|" + st.kind + "|" + st.cells.join(",");
        const tops = opts.filter(o => Math.abs(o.val - best) <= 1e-6);
        if (!tops.some(o => key(o) === want)) errs.push(`sim move ${want} not among js best (${tops.map(key).join(" ; ")})`);
        if (tops.length > 1) row.ties++;
        row.aiChecked++;
        if (s.hands[p][st.hi] !== st.cid) errs.push(`hand slot ${st.hi} js ${s.hands[p][st.hi]} sim ${st.cid}`);
        E.doPlace(s, p, st.hi, [st.kind, st.cells]);
        row.placements++;
      } else if (st.t === "orders") {
        E.doOrders(s, p);
        s.passes = 0;
        E.refill(s, p);
        row.orders++;
      } else {
        E.doPass(s, p);
        E.refill(s, p);
        row.passes++;
      }
      // the sim refills at the end of the turn, after the orders/pass snapshot: compare hands before refill
      let js = snap(s);
      if (st.t !== "place") {
        // undo our refill view: the sim snapshot was taken before refilling
        const py = st.after;
        const pyRef = { ...py };
        // compare everything except hands/decks first, then hands/decks after simulating the sim's refill
        const h = py.hands.map(x => x.slice()), d = py.decks.map(x => x.slice());
        while (h[p].length < 3 && d[p].length) h[p].push(d[p].pop());
        pyRef.hands = h; pyRef.decks = d;
        errs = errs.concat(diff(js, pyRef));
      } else errs = errs.concat(diff(js, st.after));
      if (errs.length) {
        row.bad++; ok = false;
        if (row.bad <= 3) console.log(`MISMATCH layer ${L.layer} game ${gi} step ${si} (${st.t}, turn ${st.turn}, p${p}):\n  ` + errs.join("\n  "));
        break;
      }
    }
    for (const e of s.ev) {
      if (e.t === "rally") row.rallies++;
      if (e.t === "strike") { row.strikes++; if (e.tile) row.removed++; }
      if (e.t === "front" && e.moved) row.fronts++;
      if (e.t === "front" && e.breakthrough) row.breakthroughs++;
      if (e.t === "reward") { row.rewards++; if (e.tier === 7) row.fm++; if (e.tier === 5) row.drops++; }
    }
    if (ok) {
      if (s.winner === null) E.endScore(s);
      const fe = diff(snap(s), g.final);
      if (fe.length) { row.bad++; console.log(`FINAL MISMATCH layer ${L.layer} game ${gi}: ${fe.join("; ")}`); }
      else if (E.outcome(s) === g.outcome) row.outcomeOk++;
      else { row.bad++; console.log(`OUTCOME MISMATCH layer ${L.layer} game ${gi}`); }
    }
    row.games++;
  }
  perLayer.push(row);
}
console.log("layer | games | placements | orders | passes | AI decisions checked (ties) | rallies | Strikes (tiles removed) | Front moves | Breakthroughs | streak rewards (Supply Drops, Fire Missions) | final scores and winner match | mismatches");
for (const r of perLayer) console.log(`L${r.layer} ${r.name} | ${r.games} | ${r.placements} | ${r.orders} | ${r.passes} | ${r.aiChecked} (${r.ties}) | ${r.rallies} | ${r.strikes} (${r.removed}) | ${r.fronts} | ${r.breakthroughs} | ${r.rewards} (${r.drops}, ${r.fm}) | ${r.outcomeOk}/${r.games} | ${r.bad}`);
const bad = perLayer.reduce((n, r) => n + r.bad, 0);
console.log(bad ? `FAILED: ${bad} mismatches` : "ALL MATCH");
process.exit(bad ? 1 : 0);
