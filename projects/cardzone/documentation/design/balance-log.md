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
