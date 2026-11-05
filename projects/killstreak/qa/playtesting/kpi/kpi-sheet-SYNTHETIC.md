# Killstreak internal playtest: KPI sheet (SYNTHETIC)

> **SYNTHETIC TEST DATA.** Made by tools/synthetic_playtest_sessions.gd to test this tool. Not player data; never quote these numbers.

**Logs read:** 3 file(s), 4 session(s), 1 tester(s)/device(s) · **Schema:** source/project-killstreak/autoload/playtest_log.gd · **Duplicate lines dropped:** 609

> Expect 1–5 testers internally: every number is directional. One match moves a win rate by 10–30 points.

## KPI sheet

| KPI | Target | Result | n | Status | Note |
|---|---|---|---|---|---|
| Tutorial completion | ≥ 90% of tutorials started | 100% (1/1) | 1 | **PASS** |  |
| Time to first win (Shooter segment) | ≤ 10:00 of play | 10:35 | 1 | **MISS** | includes tutorial; 'both' counted as Shooter |
| Session length | (no bar) | median 22:02, total 85:36 | 4 | **INFO** |  |
| Matches per finished run | (no bar; a full run is 5) | median 5.0 (runs: 5, 4, 5) | 3 | **INFO** | runs started 4, finished 3 |
| Turn (round) time | (no bar) | median 0:57, slowest 1:30 | 61 | **INFO** | round_end to round_end; round 1 includes the mulligan |
| Median match duration | 3:00–5:00 | 3:50 | 16 | **PASS** |  |
| Matches with ≥ 1 killstreak used | ≥ 80% | 81% (13/16) | 16 | **PASS** |  |
| Matches with the Operator down ≥ once | 40–70% | 56% (9/16) | 16 | **PASS** |  |
| Win rate vs AI, bracket 1 | ~75% (±15) | 75% (6W 1L 1D) | 8 | **ON TARGET** |  |
| Win rate vs AI, bracket 2 | ~55% (±15) | 33% (2W 4L 0D) | 6 | **TOO HARD** |  |
| Win rate vs AI, rival | ~40% (±15) | 100% (2W 0L 0D) | 2 | **TOO EASY** |  |
| One more match (next within 60 s) | ≥ 60% | 69% (9/13) | 13 | **PASS** | clock starts at match_end, so it includes the After-Action and reward screens |
| Supply Drop pick-rate spread | no card > 60% or < 5% | 1 of 2 cards outside: point_man 0% | 24 offers | **MISS** | only cards offered ≥ 3 times are judged; 0 offers skipped |
| Median unspent Supply per round | ≤ 1 | 0 | 61 | **PASS** |  |
| Survey Q1 (Shooter segment) | average ≥ 4 | 4.0 | 3 | **PASS** | It felt like a modern shooter match. |
| Survey Q2 (Shooter segment) | average ≥ 4 | 3.3 | 3 | **MISS** | I understood why I won or lost firefights. |
| Survey Q3 (Card segment) | average ≥ 4 | 4.0 | 3 | **PASS** | I had interesting choices each round. |
| Survey Q5 (all segment) | average ≥ 4 | 4.0 | 3 | **PASS** | I want to play another run. |
| Survey Q4 (all) | (no bar) | 5.0 | 2 | **INFO** | Killstreaks felt exciting. |

## Sessions

| Tester | Session | Date | Device | Load | Segment | Length | Tutorial | Matches (W-L-D) | Runs | Survey | Exported | Ended with |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | `86fe8f5f3985` | 2026-11-05 | phone / ios / safari (embedded) | 9.2 s | both | 32:10 | done | 5 (4-1-0) | win (5) | 4/4/4/5/4 | yes | log_exported  |
| T1 | `84c85c661b4b` | 2026-11-05 | phone / ios / safari (embedded) | 4.1 s | both | 24:27 | — | 4 (1-3-0) | loss (4) | 3/2/4/–/3 | yes | log_exported  |
| T1 | `2e24ad70db38` | 2026-11-05 | phone / ios / safari (embedded) | 3.8 s | both | 9:22 | — | 2 (1-0-1) | unfinished | — | no | app_hidden match |
| T1 | `75df7422891b` | 2026-11-05 | phone / ios / safari (embedded) | 3.9 s | both | 19:37 | — | 5 (4-1-0) | win (5) | 5/4/4/5/5 | yes | log_exported  |

## Matches

| Session | # | Bracket | Mode | Result | Rounds | Duration | Killstreaks used | Operator downs | Best streak |
|---|---|---|---|---|---|---|---|---|---|
| `86fe8f` | 1 | bracket 1 | zone_control | win | 4 | 3:30 | 1 | 1 | 2 |
| `86fe8f` | 2 | bracket 1 | zone_control | win | 4 | 3:36 | 1 | 0 | 4 |
| `86fe8f` | 3 | bracket 2 | firefight | loss | 4 | 4:08 | 0 | 2 | 1 |
| `86fe8f` | 4 | bracket 2 | firefight | win | 3 | 2:56 | 1 | 0 | 4 |
| `86fe8f` | 5 | rival | zone_control | win | 5 | 4:38 | 1 | 1 | 3 |
| `84c85c` | 1 | bracket 1 | zone_control | loss | 4 | 5:19 | 0 | 2 | 1 |
| `84c85c` | 2 | bracket 1 | zone_control | win | 4 | 3:57 | 1 | 0 | 4 |
| `84c85c` | 3 | bracket 2 | firefight | loss | 4 | 4:27 | 0 | 1 | 2 |
| `84c85c` | 4 | bracket 2 | firefight | loss | 4 | 4:07 | 1 | 2 | 1 |
| `2e24ad` | 1 | bracket 1 | zone_control | win | 3 | 2:27 | 1 | 0 | 4 |
| `2e24ad` | 2 | bracket 1 | zone_control | draw | 5 | 4:15 | 1 | 1 | 3 |
| `2e24ad` | 3 | bracket 2 | zone_control | *unfinished* | 0 logged | | | | |
| `75df74` | 1 | bracket 1 | zone_control | win | 3 | 2:12 | 1 | 0 | 4 |
| `75df74` | 2 | bracket 1 | zone_control | win | 3 | 2:27 | 1 | 0 | 4 |
| `75df74` | 3 | bracket 2 | firefight | win | 3 | 2:07 | 1 | 1 | 3 |
| `75df74` | 4 | bracket 2 | firefight | loss | 4 | 4:08 | 1 | 1 | 3 |
| `75df74` | 5 | rival | zone_control | win | 4 | 3:42 | 1 | 0 | 5 |

## Card usage

**Cards the player deployed** (all sessions):

| Card | Plays | Share |
|---|---|---|
| sentry | 17 | 12% |
| rifleman | 14 | 10% |
| breacher | 13 | 9% |
| flanker | 13 | 9% |
| point_man | 11 | 8% |
| combat_medic | 10 | 7% |
| gunner | 10 | 7% |
| shieldman | 10 | 7% |
| marksman | 10 | 7% |
| recon_specialist | 8 | 6% |
| comms_relay | 7 | 5% |
| breach_and_clear | 4 | 3% |
| tripwire_charge | 4 | 3% |
| ammo_resupply | 4 | 3% |
| flank_route | 3 | 2% |
| hold_the_line | 3 | 2% |
| callout | 2 | 1% |
| suppressing_fire | 1 | 1% |

**Supply Drop offers** (pick rate = chosen / offered):

| Card | Offered | Chosen | Pick rate |
|---|---|---|---|
| callout | 3 | 1 | 33% |
| point_man | 3 | 0 | 0% |
| ammo_resupply | 2 | 1 | 50% |
| comms_relay | 2 | 0 | 0% |
| flanker | 2 | 1 | 50% |
| halek_wren | 2 | 1 | 50% |
| breach_and_clear | 1 | 1 | 100% |
| breacher | 1 | 0 | 0% |
| demolitions_expert | 1 | 1 | 100% |
| flank_route | 1 | 0 | 0% |
| gunner | 1 | 1 | 100% |
| hold_the_line | 1 | 0 | 0% |
| marksman | 1 | 0 | 0% |
| recon_specialist | 1 | 0 | 0% |
| shieldman | 1 | 1 | 100% |
| suppressing_fire | 1 | 0 | 0% |

**Attachment / perk picks:** attachment (skipped) ×1, attachment ceramic_lining ×1, attachment extended_mag ×1, attachment foregrip ×2, attachment holo_sight ×4, perk field_salvage ×1, perk grit ×2, perk objective_focus ×2, perk streak_discipline ×1

**Killstreaks used:** recon_drone ×5, attack_helo ×4, mortar_barrage ×3, sentry_turret ×1

## Confusion signals

Thresholds: tutorial step open > 60 s, round > 120 s, ≥ 2 Supply unspent. Signals point at moments to ask the tester about; they are not failures on their own.

| Where | Signal | Detail |
|---|---|---|
| T1/86fe8f | tutorial stall | step 9: 78 s |
| T1/86fe8f | rounds ending with ≥ 2 Supply unspent | 2 of 20 |
| T1/84c85c | rounds with no card played | 2 of 16 |
| T1/84c85c | rounds ending with ≥ 2 Supply unspent | 5 of 16 |
| T1/84c85c | outcome preview turned on | 2× |
| T1/84c85c | pause menu opened in a match | 1× |
| T1/84c85c | survey statements skipped | q4 |
| T1/2e24ad | match left unfinished | 1 |
| T1/2e24ad | app hidden during a match | 1× |
| T1/2e24ad | run started but not finished | 1 |
| T1/75df74 | rounds ending with ≥ 2 Supply unspent | 1 of 17 |

## Survey answers

| Segment | Q1 | Q2 | Q3 | Q4 | Q5 | Open answer |
|---|---|---|---|---|---|---|
| both | 4 | 4 | 4 | 5 | 4 | Would like a kill-cam replay of the last firefight. |
| both | 3 | 2 | 4 | – | 3 | I did not see why my rifleman lost the mid lane. |
| both | 5 | 4 | 4 | 5 | 5 |  |

Statements: **Q1** It felt like a modern shooter match. **Q2** I understood why I won or lost firefights. **Q3** I had interesting choices each round. **Q4** Killstreaks felt exciting. **Q5** I want to play another run.

## Data quality

- `qa/playtesting/synthetic/SYNTHETIC-1-iphone-first-session.jsonl`: 228 lines
- `qa/playtesting/synthetic/SYNTHETIC-2-iphone-renamed-to-json.json`: 381 lines
- `qa/playtesting/synthetic/SYNTHETIC-3-iphone-sessions-1-to-4.jsonl`: 666 lines

Every line matches the logger schema.
