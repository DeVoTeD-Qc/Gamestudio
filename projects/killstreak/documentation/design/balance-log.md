# Killstreak: Balance Log (p19)

*Author: Mid Game Designer Agent · 2026-11-03 · Data-only pass. No rules code changed.*

## How it was measured
Harness: `source/project-killstreak/tests/tools/balance_sim.gd` (headless, real rules engine, real data, real enemy AI per squad).
```
godot --headless --path . -s res://tests/tools/balance_sim.gd -- seeds=30 runs=150 proxies=competent,casual,greedy
```
- **Match block:** every run slot played in **both** modes with the starter kit, 30 seeds per slot × mode (600 matches per proxy).
- **Run block:** 150 full 5-match runs per proxy through `RunProgress`, with rewards. Offer rule: the Supply Drop takes the most expensive unit offered; weapon level and Perk take option 0.
- What-if overrides (`set=`, `swap=`, `proxy=`) let you try values in memory without editing files. The header of the script documents them.

**Player proxies** (the greedy policy from `mode_sim.gd` is far too weak to be the reference: it wins 7% of matches and never uses a killstreak):
| Proxy | Definition |
|---|---|
| **competent** | `AiPlanner` on the player side. Weights: dealt 2.0, taken 0.5, zone 2, deny 3; push 0.6; always plays the best plan; takes its mulligan. I picked these settings after a sweep of about 20 planner settings. Neutral weights 1/1/2/3 won only 16% of starter-kit matches, and valuing its own damage over caution won 36%. |
| **casual** | The same planner but less sharp: dealt 1.5, taken 0.8, deny 1, push 0.3. It plays its **second-best** plan 60% of the time and holds cards, grenades and killstreaks longer (keep costs 0.6 / 1.0 / 1.2). |

**Real-time model (an assumption, not measured):** a round takes 12 s to read the board and press READY, plus 5 s per player play, plus 10 s of Reveal/Firefight animation. Round 1 adds 10 s for the mulligan. Each match adds 45 s for the RunMap, the result banner, the After-Action screen and offers. A run adds 60 s for the Title and Loadout. Replace these with `match_end.duration_s` from playtests when they exist.

**Noise:** a slot × mode cell with 30 seeds is ±9 points (1 SE). An in-run slot with 110–150 samples is ±4–5. Every change was chosen from 150-seed or 150-run tests. One-card swaps often moved results by less than the noise, and they sometimes moved them the "wrong" way (see Rejected).

## Targets
From the playtest metrics plan and milestone p19: player win rate **~75% / ~55% / ~40%** in Bracket 1 / Bracket 2 / Rival; **median** unspent Supply ≤ 1 per round; ≥ 80% of matches with a killstreak used; Operator down at least once in 40–70% of matches; median match 3–5 min. From the brief: matches last 5–8 rounds; the competent proxy wins ~55–65% of matches and ~35–50% of runs; the casual proxy wins ~35–45% of matches; a 5-match run takes 20–30 min.
Bracket targets are judged on the **mean of the two proxies, in-run** (with rewards), because that is what a playtester meets.

## Changes (before → after)
| # | Data | Before → After | Reason | Evidence (150-seed / 150-run tests) |
|---|---|---|---|---|
| B1 | `run_config.tres` `starter_deck` | Recon Specialist ×1 → **Breacher ×2** (was 1). Recon Specialist stays in the reward pool. | Bracket 1 was too hard: in-run B1 averaged 49% against a target of 75%. The starter deck is the only lever that is player-only and applies from match 1. Recon Specialist (2 Supply, 1/2) adds next-round intel that neither proxy uses, and a typical human wouldn't use it much either. A body is what wins early firefights. | Slots 1–4, starter kit, 150 seeds: Recon→Breacher plus Callout→Point Man moved the competent proxy from 42% to 50% and the casual proxy from 36% to 47%. Full runs: the Breacher swap alone (V2) gave about the same in-run B1 as both swaps (V1): competent 69 vs 77 in M1, casual 49 vs 48. So I kept the single swap. |
| B2 | `squad_rusher.tres` `killstreaks` | Recon Drone + **Mortar Barrage** → Recon Drone + **Sentry Turret** | Rusher Firefight (M3, B2 +1 Armor) was the hardest slot. Mortar (2 damage to every enemy unit in a zone) stacked on Breach and Clear and the Breachers to wipe the player's 2-Armor units, and in Firefight every one of those kills scores. The Sentry fits a squad that pushes and holds Close. | Slots 1 and 3, 150 seeds: M1 69→73 / 64→68, M3 30→34 / 36→37 (competent / casual). Full runs (V2 vs V6, without B2): M3 29→37 / 44→54, M1 64→69 / 47→49. It is the only Rusher lever that moved M3 up for both proxies. |
| B3 | `run_config.tres` match 2 / match 4 `mode` | M2 B1 Anchor **Firefight → Zone Control**; M4 B2 Anchor **Zone Control → Firefight** | The Anchor is the strongest squad in Firefight (sturdy units, healing, kills scored) and the weakest in Zone Control, because it contests only the centre. It played FF in Bracket 1, where it was too hard (in-run 44% / 62%), and ZC in Bracket 2, where it was too easy (76% / 47%). Three deck and weight changes (Demolitions→Shieldman, Gunner→Shieldman, zone weight 2.5) could not split the two modes; they moved both slots the same way or made the Anchor stronger. | In-run, 150 runs: M2 44→93 / 62→69; M4 76→50 / 47→54. Bracket 2 still has both modes (M3 FF, M4 FF, Rival ZC). Bracket 1 is now Zone Control only. That is a trade-off to sign off (see Approval). |
| B4 | `squad_black_meridian.tres` `attachments` | Foregrip + Ceramic Lining → **+ Extended Mag** | B1 and B3 made the player stronger going into match 5. By then the player has 3 weapon levels (Ruling 1, after matches 1, 3, 4). The Rival had 2 attachments, so this keeps it at parity: Operator FP 3→4. It affects only the Rival. | Full runs (sw vs swmag): Rival in-run 68→53 / 40→30; Rival-perk alternative (+ Streak Discipline) 69 / 34 did almost nothing. |

No other values changed. The squads' AI weights, the cards, the tunables (§10) and the bracket bonuses (Ruling 11) are untouched.

### Results: before → after (150 full runs per proxy, run seeds 900000–900149; in-run match win %)
| Slot | Competent before | Competent after | Casual before | Casual after | Mean before → after | Target |
|---|---|---|---|---|---|---|
| M1 B1 Rusher ZC | 55% | 66% | 35% | 49% | 45 → **58** | 75 |
| M2 B1 Anchor (FF → **ZC**) | 44% | 93% | 62% | 69% | 53 → **81** | 75 |
| **Bracket 1** | 50% | 80% | 49% | 59% | 49 → **69** | ~75 |
| M3 B2 Rusher FF | 33% | 41% | 44% | 51% | 39 → **46** | 55 |
| M4 B2 Anchor (ZC → **FF**) | 76% | 50% | 47% | 54% | 62 → **52** | 55 |
| **Bracket 2** | 55% | 46% | 46% | 53% | 50 → **49** | ~55 |
| **Rival** (M5 ZC) | 59% | 62% | 41% | 28% | 50 → **45** | ~40 |
| All in-run matches | 52% | 62% | 46% | 51% | | comp 55–65, casual 35–45 |
| **Run win** | 45% | **54%** | 26% | **21%** | | comp 35–50 |
| Rounds per match (in-run) | 5.99 | 5.82 | 6.25 | 6.20 | | 5–8 |
| Unspent Supply / round, in-run mean (median from the starter-kit block) | 0.58 (0) | 0.52 (0) | 1.56 (1) | 1.40 (1) | | median ≤ 1 |
| Matches with ≥ 1 killstreak used | 96% | 96% | 89% | 89% | | ≥ 80% |
| Operator down ≥ 1 per match | 77% | 76% | 82% | 81% | | 40–70% |
| Est. 5-match run | 25.4 min | 24.7 min | 24.6 min | 24.7 min | | 20–30 min |

Starter-kit matches (600 per proxy, both modes in every slot), after: competent wins 35% overall, casual 33%, greedy 7%. Per mode, after: ZC rounds 4.6–6.3, FF rounds 5.5–8.1. The longest is the casual proxy in Anchor FF, at 8.1 rounds with 3 of 30 going to an overtime draw.

**Reading:** the difficulty curve now has the intended shape: B1 69% (easy), B2 49% (a challenge), Rival 45% (the hardest per proxy for casual players). Before, the curve was flat at ~50% everywhere, with Bracket 1 the hardest part for the casual proxy. The competent run win (54%) sits 4 points over the 35–50% band, inside noise of the top. The casual in-run match rate (51%) is above its 35–45% band because B1 is now easy, but casual still wins only 21% of runs. The proxies disagree by slot: casual beats competent at Rusher FF and Anchor FF, and loses far more at the Rival. So treat them as two bounds, not as a skill ladder.

### Other KPIs (after)
- **Card play / win-when-played (in-run, competent):** every starter card wins 58–67% when played (no outlier). The planner rarely plays Hold the Line (12%) or Suppressing Fire (22%). Watch them in playtests: they may be weak or just undervalued by the AI. Reward cards appear in under 10% of matches because the sim takes 1 card per won match. The "pick-rate spread" KPI needs human picks; the sim's offer rule can't measure it.
- **Streaks:** competent average best streak per match is 3.1, with 2.7 killstreaks earned and 1.9 used per match (starter kit). By use: Recon Drone 336, Mortar 178, Attack Helo 52 (of 100 earned).
- **Run length:** a full 5-match run is **~25 min** for every proxy, a losing run (3–4 matches) 16–21 min, and a match ~4.0 min (inside the 3–5 min KPI). This assumes the time model above. At 20 s per round more than assumed, the run would take ~34 min.

## Rejected (tested, not kept)
| Try | Result |
|---|---|
| Rusher / Anchor `second_best_chance` 0.15/0.10 → 0.3 or 0.5 | The AI got **stronger** vs the competent proxy (B1–B2 −4 to −16). Its "second-best" plan is often as good. Don't use it as a difficulty knob. |
| Rusher deck: Breacher→Rifleman (×1, ×2), Point Man→Rifleman, Flank Route→Rifleman, B&C→Rifleman | Within noise, mixed by proxy. |
| Rusher without Extended Mag; Rusher Primary Wasp-9 → Kestrel | No help; with the Kestrel the Rusher got **much** stronger (−20). The Wasp-9 is the weaker Primary. |
| Rusher weights 1/1 or deny 1.5; Anchor zone 2.0 / 2.5, taken 1.0 | Within noise or worse. |
| Anchor deck: Demolitions / Gunner → Shieldman or Rifleman | Shieldman made the Anchor stronger in FF. Rifleman eased both Anchor slots together (no split). |
| Starter Callout → Point Man (on top of B1) | B1 +3–8 for the competent proxy only; not needed. |
| Recon Specialist 1/2 → 2/3 | Within noise. |
| Attack Helo threshold 5 → 4 | +3 / +4 overall; killstreak use was already ≥ 80%, so I didn't spend a change on it. |
| `firefight_target` 7 → 6 | FF matches 0.3–0.6 rounds shorter, no win-rate effect. I kept 7 (core-rules number); see Recommendations. |
| Rival + Streak Discipline perk | No effect. |

## Recommendations (need a rules / ruling decision, not made here)
1. **Operator down rate is high (76–81% of matches vs 40–70%).** Both AIs hunt the Operator (deny-streak weight 3). Options: Operator Armor +1 for both Primaries, or a lower `weight_deny_streak` (2) on the base squads. Verify with the harness first. This is a feel question for the Sr Designer: the KPI says the risk is "too punishing".
2. **Firefight runs long for careful players.** Casual Anchor FF averages 8.0 rounds with 7% overtime draws. `firefight_target` 6 would trim that with no win-rate cost. It is a §10 tunable, but core-rules states 7, so I left it.
3. **Bracket 2 armor bonus (Ruling 11) is a big step.** +1 Armor on every enemy unit cost the starter-kit player 25–40 points in the same matchup. That is fine with rewards, but if B2 playtests read as a wall, a +1 Firepower variant or bonus on the Rival only are the levers. Changing either is a Ruling change.
4. **Bracket 1 is now Zone Control only** (B3). If the Sr Designer wants Firefight introduced in B1, the alternative is to keep the old order and accept B1 at ~50% (the Anchor-FF problem has no data fix found).
5. **Measure for real:** the proxies disagree per slot. Re-run this harness against the first 8–15 playtest logs (win rate per slot, `match_end.duration_s`, unspent Supply) before a second pass.

## Approval
- B3 (mode order) changes the run's structure and the content-log rationale ("both modes in each bracket"). It **needs Sr Game Designer sign-off**.
- B1, B2 and B4 are content parameters within the approved systems.

## Test impact
- `tests/test_ai_player.gd::test_killstreak_from_tray_hits_the_crowded_zone` granted Mortar Barrage to the Rusher, which no longer carries it. The test now uses the Rival (Black Meridian), which does. A comment in `test_personalities_keep_their_positions` was updated for the new slot modes. No assertion values changed.
- `tests/tools/gen_content.gd` is in sync with all four changes.
