# CardZone: Balance Log

*Mid Game Designer · 2026-11-04 · Board task `cz02` (project cardzone) · Phase: plan (P0 rules lock)*
*Rules: Loadout Loop spec v0.2 (`mechanics/loadout-loop-spec.md`, §1–§15 as of commit 26a0897; §16 was being written in parallel and is not used here). Tool: `../../tools/loadout_sim.py`. Plan: `../production/prototype-milestone-plan.md` §1 DoD 6 and §2.*

This log records every balance run and every proposed change to a default. cz06 takes its values from spec v0.2 + §16 **or** from a change logged here. cz09 adds its Veteran-vs-Veteran numbers to this file later.

---

## Entry 1: hand 4 vs 5 and hold 2 vs 1, routes A/B/C, 1v1 (cz02)

### What was run
- **Tool changes** (`tools/loadout_sim.py`): Zone routes B and C from spec §8, a `--route A|B|C` flag, a `--hold N` flag (the hold limit at Pack, default 2), and a `--sweep` mode that plays v0.2 1v1 on **all 36 drop pairs** (Ana, the first player, drops on each of the 6 outer areas × Ben on each of the 6, hot drops included).
- **Default output unchanged:** the scenario tables, `--hand 5`, `--ablation` and every `--log` scenario were saved before the change and diffed after it. All 10 outputs are byte-identical.
- **What the sweep adds on top of the old tables:** the spec's **hard end after round 14** (most health wins, then more non-Hit loadout cards) and the **simultaneous-elimination tiebreak** (§9: more non-Hit loadout cards wins). So every sweep game has a winner. The old scenario tables still run to round 20 without tiebreaks, as before.
- **Cross-check:** hand 4 / hold 2 / route A and hand 5 / hold 2 / route A reproduce the numbers in plan §2 exactly (decided-by-play 14–8 and 19–16, both out together 14 and 1, medians 12 and 10, earliest rounds 7 and 6, ambushed player wins 13 of 36 by play).
- 12 settings × 36 games = **432 even-start games**, plus the same 432 with Ben ambushed for 2 Hits in round 2. Runtime under 1 s.

```
python3 tools/loadout_sim.py --sweep --summary            # table below
python3 tools/loadout_sim.py --sweep --summary --ambush   # ambush table
python3 tools/loadout_sim.py --sweep --hand 5 --hold 2 --route C   # one row per game
```

### Measures
- **First-player win rate:** Ana's wins out of 36, tiebreaks applied. The next column counts only games decided by play (one player eliminated by a shot, gas or the final circle), as plan §2 did.
- **Both out in final circle:** both players eliminated by the same final-circle card. Nobody wins by play; the card-count tiebreak decides.
- **Median last round** (range) and **earliest elimination** (the first round anyone was eliminated in any of the 36 games).
- Plan targets (DoD 6): first player 45–55%, both out < 10%, median last round 9–12. Spec goal: no elimination before round 6.

### Result: even start, 36 drop pairs per row

| Hand | Hold | Route | First-player wins | 1st wins / decided by play | Both out in final circle | Median last round (range) | Earliest elim. |
|---|---|---|---|---|---|---|---|
| 4 | 2 | A | 20/36 (56%) | 14/22 | **14/36 (39%)** | 12 (7–14) | 7 |
| 4 | 2 | B | 21/36 (58%) | 17/28 | 7/36 (19%) | 12 (4–14) | **4** |
| 4 | 2 | C | 18/36 (50%) | 14/29 | 7/36 (19%) | 12 (7–14) | 7 |
| 4 | 1 | A | 18/36 (50%) | 14/26 | 10/36 (28%) | 12 (7–14) | 7 |
| 4 | 1 | B | **24/36 (67%)** | 21/31 | 4/36 (11%) | 10.5 (4–14) | **4** |
| 4 | 1 | C | 19/36 (53%) | 14/27 | 8/36 (22%) | 12 (7–14) | 7 |
| 5 | 2 | A | 19/36 (53%) | 19/35 | 1/36 (3%) | 10 (6–14) | 6 |
| 5 | 2 | B | **30/36 (83%)** | 24/30 | 6/36 (17%) | 9 (6–13) | 6 |
| 5 | 2 | C | **32/36 (89%)** | 32/36 | 0/36 (0%) | 9 (6–13) | 6 |
| 5 | 1 | A | 17/36 (47%) | 17/35 | 1/36 (3%) | 9.5 (6–14) | 6 |
| 5 | 1 | B | 22/36 (61%) | 22/36 | 0/36 (0%) | 9 (6–12) | 6 |
| 5 | 1 | C | **28/36 (78%)** | 28/32 | 4/36 (11%) | 9 (6–13) | 6 |

**Pooled over the three routes (108 games each):**

| Hand | Hold | First-player wins | Both out in final circle | Medians by route | Earliest elim. |
|---|---|---|---|---|---|
| 4 | 2 | 59/108 (55%) | 28/108 (26%) | 12 / 12 / 12 | 4 |
| 4 | 1 | 61/108 (56%) | 22/108 (20%) | 12 / 10.5 / 12 | 4 |
| 5 | 2 | 81/108 (75%) | 7/108 (6%) | 10 / 9 / 9 | 6 |
| 5 | 1 | 67/108 (62%) | 5/108 (5%) | 9.5 / 9 / 9 | 6 |

How games ended (shot / final circle alone / both out together / hard end; no game was decided by the gas check): hand 4 is 16–26 shot kills per 36, with 4–14 double knockouts; hand 5 is 30–36 shot kills per 36.

### Result: ambush start (Ben, the second player, takes 2 Hits in round 2)

| Hand | Hold | Route A: Ben wins / both out / median | Route B | Route C |
|---|---|---|---|---|
| 4 | 2 | 19 / 8 / 12 | 10 / 4 / 8 | 14 / 4 / 9 |
| 4 | 1 | 20 / 6 / 12 | 10 / 4 / 8 | 13 / 4 / 9 |
| 5 | 2 | 19 / 0 / 8 | 9 / 2 / 8 | 14 / 2 / 7 |
| 5 | 1 | 16 / 0 / 7.5 | 9 / 0 / 8 | 16 / 2 / 7 |

*(Ben wins out of 36, tiebreak wins included; the only ties were 2 games at hand 5 / hold 1 / route C. Earliest elimination is round 3–4 in every ambush row. The scripted ambush is 2 free Hits, so that is expected and is not a rules signal.)* The comeback the v0.2 spec promised holds on route A (the ambushed player wins 16–20 of 36). On routes B and C it falls to 9–16 of 36, because the round-3 drop race below decides more games than the ambush does.

### What the numbers say

**1. Hand 5 fixes the zone-decided duel; hand 4 does not.** At hand 4, 11–39% of even duels (20–26% pooled) end with **both players knocked out by the final circle** (target < 10%) on every route and hold setting. At hand 5 it is 0–17% per route and 6% pooled. Hand 5 games also land inside the 9–12 median band (9–10) and nobody is eliminated before round 6 on any route. Hand 4 medians sit at the top of the band (12), and route B produced a round-4 elimination: a Quarry/Quarry hot drop where both bots loot a Pump Shotgun on turn 1 and trade shots from round 1 (on route A the same drop lasts to round 8).

**2. Routes B and C have a first-player problem, and it is one card: the round-3 Twin-Drum LMG drop.** I traced who loots the LMG in every game:

| Hand | Route (LMG lands at) | Ana (first) takes it | LMG taker wins by play |
|---|---|---|---|
| 4 | A (Quarry) | 16 of 36 | 11 of 33 |
| 4 | B (Docks) | 23 of 36 | 13 of 36 |
| 4 | C (Motel) | 25 of 36 | 15 of 36 |
| 5 | A (Quarry) | 10 of 36 | 17 of 36 |
| 5 | B (Docks) | **31 of 36** | 23 of 36 |
| 5 | C (Motel) | **30 of 36** | 26 of 36 |

*(hold 2 shown; hold 1 is within 2 games of it.)* With 5 cards, almost every hand has Move 1 + Search 3 by round 3, so whoever moves first in round 3 reaches the drop first. On B and C the drop lands where the first player can usually get it, so the first player wins 78–89%. On route A the Quarry happens to suit Ben's drops, so it evens out by luck of the map, not by design. Hand 4 hides the problem because many hands can't afford the drop at all.

**3. Hold 2 vs 1 is not a strong lever for these bots.** The bots hold only cards with a Brace value, and the limit of 2 binds in just **5–9% of packs** (they hold 0 cards in 64–75% of packs and 1 card in 20–34%). The row-to-row swings between hold 2 and hold 1 (for example 83% vs 61% on route B at hand 5) come from small changes in a 5-card loop that change who reaches the LMG first, not from Hold itself. The sim cannot judge the hold limit. The playtest's pack telemetry (holds 0/1/2, what was held) and the "Hold used ≥ 60%" KPI must.

**4. Proposed fix, tested in a scratch run (not applied):** raise **`supply_drop_cost` from 3 to 4** (already an allowed tunable, 3–4, in scope §4). A 4-Search drop needs a strong hand or a Crowbar, so being first in turn order stops being enough:

| Supply drop cost 4 | First-player wins (route A / B / C) | Pooled | Both out | Medians | Earliest elim. |
|---|---|---|---|---|---|
| Hand 5, hold 2 | 19 / 19 / 18 of 36 | **56/108 (52%)** | 6/108 (6%) | 9 / 9 / 8 | 6 |
| Hand 5, hold 1 | 19 / 21 / 19 of 36 | 59/108 (55%) | 1/108 (1%) | 9 / 8 / 8 | 6 |
| Hand 4, hold 2 | 17 / 17 / 16 of 36 | 50/108 (46%) | **41/108 (38%)** | 13.5 / 13 / 13 | 7 |

At hand 5, cost 4 brings every route into the 45–55% band (50–58% per route), keeps double knockouts at 1–3 per route and keeps the earliest elimination at round 6. The cost: medians drop to 8–9, so route C (8) sits just under the band. At hand 4, cost 4 makes zone-decided games worse (38%). Reproduce (scratch patch, no tool flag):

```
cd tools && python3 -c "
import loadout_sim as L
o = L.Game.loot_options
L.Game.loot_options = lambda s, p, a: [(k, n, 4 if k[0] == 'drop' else c) for k, n, c in o(s, p, a)]
L.HAND = 5
for r in 'ABC':
    L.ROUTE = r; print(r, L.sweep_stats(L.sweep()))"
```

### Confidence limits (read before using these numbers)
- **The bots are simple and greedy** (`loadout-loop-sims.md`, "Limits"): they loot the most valuable card in reach, rush into range from round 4, always shoot, always brace as much as possible, and hold only Brace cards. They never hold against a specific threat, never use Frag, Ditch or Heal items well, never pick a spot by Cover, and **never race for or deny a supply drop on purpose**. Real players will fight over the LMG, which could make finding 2 stronger or weaker.
- **Same deterministic bot on both seats.** Each row is 36 fixed games, not a random sample. If you treat the 36 drop pairs as a sample anyway, a 95% interval on one row is about **±16 points** around 50% (19/36 = 37–68%). So one row **cannot** confirm the 45–55% target. It can only flag large gaps: 30/36 (68–92%) and 32/36 (75–96%) are real problems for these bots; 21/36 vs 18/36 is noise. Pooled 108-game rows are about ±9 points.
- **Setup is not the spec's.** The sweep plays every drop pair, but in a real game the **second player picks the route and drops first** (§4). A second player who knows finding 2 would never pick B or C at hand 5. That would hide the edge, but it would also make two of the three routes dead choices. The sim also has no drop strategy (cz09's AI drop rule is still to come).
- **Hand 5 uses the hand-4 Standard pack order.** With hand 5 the 10-card loadout loops in exactly 2 turns. cz01 may change the order for hand 5; rerun this sweep if it does.
- **1v1 only, Bounty and Down on, health 5, both players on the Standard pack, public information** (the bots see everything; the prototype hides held cards, scope §4 `held_cards_public` false).
- **Direction, not tuning.** cz09's Veteran-vs-Veteran sweep (216 games per setting) and the playtest decide. Rerun this table when cz09 lands and compare.

### Recommendation (for cz06 and the Sr Game Designer)
1. **Hand size: 5** (keep the scope default). It is the only setting that meets the "both out < 10%" and "median 9–12" targets, and it never eliminates anyone before round 6. Hand 4 leaves 20–26% of even duels (pooled) to the zone. Keep 4 as a dev-panel switch.
2. **Hold limit: 2** (keep the spec default). The sim can't separate 2 from 1: the limit binds in under 10% of bot packs, and the differences between rows are cascade effects. Hold 2 is what the spec's "hold a Plate Vest, keep your guard up" decision is built on. Keep 1 as a switch, and decide from playtest pack telemetry.
3. **Proposed change, needs Sr Game Designer approval before cz06 uses it: `supply_drop_cost` 3 → 4.** At hand 5 with the current cost, routes B and C give the first player 83–89% (78–89% with hold 1) because of the round-3 LMG drop. With cost 4 every route is 50–58%. If the Sr Designer prefers to keep cost 3, the alternatives to test next are: make drops lootable only from the round after they land, or move the B/C round-3 drop to an area neither player can reach first by turn order alone. Until one is approved, **route A is the only fair route at hand 5** in these sims; the cut-order note "keep A" (plan §3) already covers that case.
4. **Rerun** this entry after cz01 (hand-5 Standard pack) and cz09 (Veteran sweep), and log any change here.

### Decision (Sr Game Designer, cz01, 2026-11-04)
- **Approved: `supply_drop_cost` 3 → 4** as the prototype default (spec §16.4a, scope §4). cz06 uses 4.
- **Alternative kept as a switch:** `supply_drop_ready_delay` (0/1, default 0) means a drop can't be looted in the round it lands. In a scratch run (hand 5, hold 2, cost 3, 36 pairs × A/B/C), the first player won 20 / 19 / 21 (55%), with both out 6/108, medians 9.5 / 9 / 9, and **earliest elimination round 4**. That breaks the round-6 gate, so it stays off.
- **Rejected:** moving the B/C round-3 drop. It treats one card, not the turn-order race.
- **Hand-5 Standard pack:** confirmed as the hand-4 order (spec §16.4), so the numbers in this entry stand. A scratch re-run of three other splits at cost 4 gave 47%/8 both-out, 67%/17 both-out with a round-5 elimination, and 40%/18 both-out. None beat the Standard order.
- **Hand 4 caveat:** at hand 4 keep cost 3 (cost 4 gives 38% double knockouts). The dev panel (cz13) should switch both together.

---

## Entry 2: Veteran vs Veteran on the real rules engine, 216 games (cz09)

*Mechanics Developer · 2026-11-04 · Board task `cz09` (project cardzone) · Phase: prototype*
*Rules: the cz07 engine (`scripts/rules/`, commit 1cf8514), spec v0.2 + §16, content from `res://data` (cz06), `balance.tres` defaults unless a row says otherwise. Tool: `tests/tools/ai_sweep.gd`. AI: `scripts/ai/` (Veteran = whole-turn plan search on a belief world; Rookie = the sim bots' policy from `tools/loadout_sim.py`).*

### What was run
- **216 games, Veteran vs Veteran:** 36 drop pairs (P1 on each outer area × P2 on each, hot drops included) × routes A/B/C × hand 4 and 5. Hand 5 uses the defaults (supply drop cost 4); hand 4 uses cost 3, the pairing §16.4a asks the dev panel to switch together.
- **Ladder:** Rookie vs Veteran from both seats on the same 216 settings each way, plus Rookie vs Rookie as the baseline.
- **What-if:** hand 5 with `supply_drop_ready_delay` = 1 (the switch kept from Entry 1).
- **Difference from Entry 1:** this is the real engine, not the paper sim. Loadouts, held cards and hands are private: each AI sees only `view(state, seat)` plus its own cards and plays its opponent from a belief world (it never reads the other side's hidden cards). Down, Brace, Bounty, the hard end, gas and crates are all the engine's. Every game is deterministic, so the same command prints the same tables.

```
godot --headless --path . -s res://tests/tools/ai_sweep.gd -- --retime=10                    # this entry (V vs V)
godot --headless --path . -s res://tests/tools/ai_sweep.gd -- --p1=veteran --p2=rookie        # ladder, Veteran first
godot --headless --path . -s res://tests/tools/ai_sweep.gd -- --p1=rookie --p2=veteran        # ladder, Rookie first
godot --headless --path . -s res://tests/tools/ai_sweep.gd -- --p1=rookie --p2=rookie         # baseline
godot --headless --path . -s res://tests/tools/ai_sweep.gd -- --hands=5 --set=supply_drop_ready_delay:1
```

### Result: Veteran vs Veteran, 36 drop pairs per row

| Hand (drop cost) | Route | First-player wins | P2 wins | Draws | Shot / gas / final circle / both out / hard end | Median last round (range) | Earliest elim. |
|---|---|---|---|---|---|---|---|
| 4 (3) | A | 23/36 (64%) | 13 | 0 | 22 / 0 / 3 / 3 / 8 | 13 (6–14) | 6 |
| 4 (3) | B | 20/36 (56%) | 15 | 1 | 21 / 0 / 7 / 4 / 4 | 13.5 (10–14) | 10 |
| 4 (3) | C | 23/36 (64%) | 12 | 1 | 24 / 0 / 3 / 5 / 4 | 13 (8–14) | 8 |
| 5 (4) | A | 19/36 (53%) | 17 | 0 | 35 / 0 / 1 / 0 / 0 | 11 (3–13) | **3** |
| 5 (4) | B | 22/36 (61%) | 14 | 0 | 22 / 0 / 8 / 3 / 3 | 13 (9–14) | 9 |
| 5 (4) | C | **26/36 (72%)** | 10 | 0 | 30 / 0 / 2 / 4 / 0 | 11 (5–14) | **5** |
| **4, pooled** | | **66/108 (61%)** | 40 | 2 | 67 / 0 / 13 / 12 / 16 | 13 (6–14) | 6 |
| **5, pooled (defaults)** | | **67/108 (62%)** | 41 | 0 | 87 / 0 / 11 / 7 / 3 | 12 (3–14) | **3** |

*"Final circle" = one player knocked out by a final-circle card; "both out" = both at once (R47 tiebreak decides).*

**Who took the round-3 Twin-Drum LMG** (the card behind Entry 1's first-player problem):

| Hand | Route | P1 takes it | P2 takes it | Nobody | Taker wins |
|---|---|---|---|---|---|
| 4 (cost 3) | A / B / C | 32 / 33 / 32 | 4 / 3 / 4 | 0 / 0 / 0 | 21 / 21 / 21 of 36 |
| 5 (cost 4) | A / B / C | 19 / 21 / 15 | 17 / 15 / 16 | 0 / 0 / 5 | 22 of 36 / 23 of 36 / 22 of 31 |

### Ladder: Veteran vs Rookie (same 216 settings each way)

| Hand | Veteran as P1 | Veteran as P2 | Veteran overall | Baseline: Rookie vs Rookie, P1 wins |
|---|---|---|---|---|
| 5 (defaults) | 89 won, 15 lost, 4 drawn (82%) | 65 won, 43 lost (60%) | **154/216 (71%)** | 66/108 (61%) |
| 4 (cost 3) | 80 won, 27 lost, 1 drawn (74%) | 62 won, 45 lost, 1 drawn (57%) | **142/216 (66%)** | 69/108 (64%) |

From either seat the Veteran does about 21 points better than a Rookie in the same seat (a Rookie P1 wins 61% at hand 5, a Veteran P1 82%; a Rookie P2 wins 39%, a Veteran P2 60%). **The Veteran is clearly the stronger level.** (Tuning note: the evaluation's loot-value weight was raised from 2 to 6 on this ladder; it took the Veteran from 67% to 71–76% in the tuning runs. No other weight moved it by more than noise.)

### What-if: drops lootable only from the round after they land (hand 5, Veteran vs Veteran)
`supply_drop_ready_delay` = 1: first player **78/108 (72%)** (A 20, B 25, C 33 of 36), earliest elimination round 5. Worse than the default; it stays off.

### AI speed (the cz09 "under 300 ms on an iPhone 12-class phone" gate)
- Dev machine (shared 4-core Xeon VM, 2.1 GHz). Budget: 4× headroom, so **≤ 75 ms per whole AI turn** here.
- Over the 4,898 Veteran turns of the sweep: median **9 ms**, p95 31 ms, p99 42 ms, slowest single timing 71 ms.
- The 10 slowest turns re-timed 5 times each from a replayed state (one timing on a shared machine can catch another process): **worst median 63 ms** (a 4-shot LMG turn in round 9). All 10 are under 75 ms. The Rookie's slowest turn is 17 ms.
- The bound is deterministic: the Veteran searches once per turn segment (the turn start and after each shot), with a node cap (120 actions, then 120 / (1 + shots)², at least 30), not a clock. `ai_think_budget_ms` (300) is only a safety stop.

### What the numbers say
**1. At the defaults the first player wins 62% (hand 5) when both sides play the Veteran, outside the 45–55% target.** The Rookie baseline on the same engine is 61%, so this is not an AI quirk. It is also **no longer the LMG**: with cost 4 the drop splits 55/48 between the seats at hand 5, and its taker wins only 61–71% of the games in which it is taken. The edge comes from **first strike**: P1 acts first in every round, and 87 of 108 hand-5 games end with a shot, so whoever reaches range first usually lands the first big hit (the Rookie games show the same, 106 of 108 by shot). By route, A is fair (53%), B leans to P1 (61%), C strongly (72%).
**2. Early eliminations are back at hand 5: 6 of 108 games end before round 6** (round 3 on route A, round 5 on route C). All six have P2 dropping at the **Quarry** with P1 on the Quarry or next to it: hand 5's first turn (Search 4 + Move 1) buys a Pump Shotgun (cost 4) and shoots in round 1, and the second Pump answers. Entry 1's bots never shot before round 4, so the paper sim could not see this.
**3. Hand 4 stays worse**, as in Entry 1: both out 12/108 (11%, target < 10%), 16 hard ends, medians 13–13.5 (target 9–12), first player 61%.
**4. The AI-vs-AI rate is sensitive to the AI build.** An earlier Veteran build that differed only in its search cap (200 instead of 120) gave the first player **57/108 (53%)** at hand 5 on the same 108 games. Treat about ±9 points as AI noise on top of Entry 1's ±9-point sampling limit for a 108-game row.

### Proposals (for the Sr Game Designer; **not applied**, `balance.tres` unchanged)
- **P-1 First-player edge (62%).** Options to test, in order of cost:
  1. **Use the setup rule that already exists:** the second player (or the human vs the AI) picks the route (§16.3 S2). A second player who picks route A gets 53%, but then B and C become dead choices. Not a fix on its own.
  2. **A second-player compensation switch** for the dev panel, swept with this tool: for example P2 starts with 6 health (or the Bounty-style +1), or **no shooting in round 1** (blunts first strike and finding 2 together). Either needs a small engine change in `scripts/rules` (cz07 owner), then `--set=<key>:<value>` reruns this entry in 2 minutes.
  3. Confirm with the playtest's first-player KPI before changing any default from AI data alone.
- **P-2 Turn-1 Pump Shotgun at the Quarry (eliminations in round 3).** Options: Pump Shotgun cost 4 → 5 (out of a hand-5 first turn's reach), or the same "no shooting in round 1" switch as P-1. Rerun this entry after either.
- **Keep** `supply_drop_cost` 4 and `supply_drop_ready_delay` 0 (the delay makes the first-player edge worse here, 72%).

### Confidence limits
- **Two copies of one AI.** The Veteran plans one turn ahead against a guessed opponent hand; it does not model the opponent's next turn beyond a threat estimate, and it never bluffs a hold. Real players will differ, most of all in drop choice (here every drop pair is forced; in play P2 drops first and P1 answers).
- **Each row is 36 fixed, deterministic games** (±16 points on one row, ±9 on a pooled 108-game row, Entry 1), plus the AI-build sensitivity in point 4.
- **Timing** is from a shared VM; the iPhone 12 figure is an estimate by the 4× rule, not a device measurement. The web build (cz12/cz17) should log real turn times on a phone.
