# CallingCard: Balance Log

*Mechanics Developer · cc06 · 2026-11-04. Data: `data/balance.tres`, `data/rivals/*.tres` (cc03).
Tool: `tests/tools/sim_duels.gd` (seeded, headless; the real `WallRules` engine and the cc06 rival AIs).*

```
godot --headless --path . -s res://tests/tools/sim_duels.gd -- --duels=1000 [--seed=N] [--tie=first|draw]
      [--first_bonus=N] [--second_bonus=N] [--first_sig_bonus=N] [--knobs=first_player_bonus:0,chain_captures:1,...]
```

## Change log
| Date | Change | Why |
|---|---|---|
| 2026-11-04 | **Tempo:** `first_player_bonus` 0 → **2** (new `BalanceConfig` field), `tie_winner` FIRST_PLAYER → **DRAW** | Proposal A below, chosen by the studio head. Moves first-player wins from 41.5% to 47.3% of decided duels |
| 2026-11-04 | Collection: a draw is not a win for any goal and does not break the win streak (only a loss resets it) | Studio head decision that came with Tempo |

## Tempo adopted: before / after (3 × 1,000 duels, seeds 1 / 5001 / 9001)
"After" is the shipped data, played by AIs that know the bonus. It is part of `WallRules.score`, so
the evaluation and the end result both include it.

| Rules | First-player wins (of all) | First-player wins (of decided) | Draws counted as half | Draws | Level scores (ties) | Avg score per duel | Avg first / second |
|---|---|---|---|---|---|---|---|
| Before: no bonus, ties to the first player | 44.1 / 41.0 / 39.4% (mean 41.5%) | same (no draws) | 41.5% | 0% | 20.5 / 19.1 / 17.4% (19.0%) | 12.00 | 5.13 / 6.88 |
| Estimate: +2 applied after scoring, AIs unaware | 44.1 / 41.0 / 39.4% | 55.0 / 52.9 / 50.1% (52.7%) | 52.1% | 21.2% | – | 14.00 | 7.13 / 6.88 |
| **After: Tempo +2, ties are draws (shipped)** | 39.7 / 37.4 / 37.2% (mean 38.1%) | **49.2 / 46.4 / 46.4% (mean 47.3%)** | **47.8%** | **19.3 / 19.4 / 19.8% (19.5%)** | = draws | 14.00 | 6.99 / 7.02 |

- **Inside the 45–55% band** for decided duels and for the half-credit count. It sits lower than the
  estimate because the AIs now play for the bonus, and because Clutch's behind-check includes it.
- **Clutch:** the second player is "behind" at 0–2 from the start, so its first Clutch card always
  gets +2. In the Warden mirror this brings the first player down from 54.8% (no Tempo) to
  30–32% of all duels (draws 27–34%).
- If a little more first-player share is wanted later, the next knob to test is leaving Tempo out of
  `is_behind`. It would be one `RulesOptions` flag. Not built.
- Averages: first player 6.98 including the +2, second player 7.02; one duel in five ends level.

### After, full table (seed 1)

| Pairing (A vs B) | Duels | A wins | B wins | Draws | First-player wins | Ties | Avg score (A+B) | Avg first / second |
|---|---|---|---|---|---|---|---|---|
| quartermaster vs quartermaster | 167 | 34.1% | 41.9% | 24.0% | 42.5% | 24.0% | 14.00 | 7.16 / 6.84 |
| quartermaster vs archivist | 167 | 3.0% | 92.2% | 4.8% | 49.7% | 4.8% | 14.00 | 7.37 / 6.63 |
| quartermaster vs warden | 167 | 4.8% | 86.8% | 8.4% | 44.9% | 8.4% | 14.00 | 6.81 / 7.19 |
| archivist vs archivist | 167 | 39.5% | 31.7% | 28.7% | 27.5% | 28.7% | 14.00 | 6.84 / 7.16 |
| archivist vs warden | 166 | 16.3% | 68.1% | 15.7% | 41.6% | 15.7% | 14.02 | 7.00 / 7.02 |
| warden vs warden | 166 | 31.9% | 33.7% | 34.3% | 31.9% | 34.3% | 14.00 | 6.93 / 7.07 |
| **All** | 1000 | 21.6% | 59.1% | 19.3% | 39.7% (49.2% of decided) | 19.3% | 14.00 | 7.02 / 6.99 |

Seeds 5001 / 9001: Warden beats the Quartermaster 88.6% / 86.2% and the Archivist 62.7% / 67.5%
(draws 20.5% / 18.1%). The Archivist beats the Quartermaster 88.6% / 92.2%. The difficulty ladder holds.

Warden timings with Tempo, same code: mean 12.2 ms, p95 29.3 ms, p99 37.6 ms, nodes max 227–231.
Single maxima of 85–95 ms appeared while other studio agents were loading the machine (load average 1.6–2.1).
They are scheduler stalls, not search size. See Timings below.

---

*Everything below is the original cc06 analysis (pre-Tempo data) that led to the decision.*

## Summary
- **First-player win rate: 39.4–44.1% across three 1,000-duel runs (mean 41.5%).** That is below the
  45–55% target. The second player wins more often because it makes the last placement, and the
  tie-to-first-player rule does not make up for it.
- Ties are common (17–21%) because every duel scores exactly **12 points in total** (10 cards + 2
  Signatures, unless a Triptych scores). Score differences are therefore always even, so only a
  bonus of **2** changes results. A +1 bonus does the same thing as the tie rule.
- No existing `BalanceConfig` knob brings the rate into the band without removing part of a
  trait (below). **Proposal A** (first player +2, ties are draws) lands at 50–55% of decided
  duels. It needs one new engine/data field. `data/balance.tres` was **not** edited.
- Warden: at most 231 search nodes per move. The p99 move time is 31–35 ms on this machine
  (mean 12 ms), well under the 50 ms target (200 ms phone ÷ 4). See Timings.

## Setup
- 1,000 duels per run, split evenly over six pairings: the three mirrors and the three mixed pairs.
  Each rival plays its own lineup and tuning. Coin flip per duel: `WallState.coin_flip(seed + i)`.
  Brains are seeded per duel, so a run replays exactly.
- Rules: `RulesOptions` defaults (RQ-08 yes, RQ-09 full score, RQ-02 printed, RQ-04 cancel); the three
  Triptychs from `data/triptychs/`; balance from `data/balance.tres` (ties to the first player, chain captures off).
- The AIs never see hidden information. Face-down Ambush cards they don't control are sampled from the
  opponent's unseen lineup cards (RQ-19).
- "A wins" / "B wins" are the left / right rival of the pairing. "Ties" are level final scores; under the
  current rule a tie counts as a first-player win.

## Baseline (current data), seed 1

| Pairing (A vs B) | Duels | A wins | B wins | Draws | First-player wins | Ties | Avg score (A+B) | Avg first / second |
|---|---|---|---|---|---|---|---|---|
| quartermaster vs quartermaster | 167 | 46.1% | 53.9% | 0.0% | 43.7% | 19.8% | 12.00 | 5.22 / 6.78 |
| quartermaster vs archivist | 167 | 5.4% | 94.6% | 0.0% | 48.5% | 6.6% | 12.00 | 5.40 / 6.60 |
| quartermaster vs warden | 167 | 9.0% | 91.0% | 0.0% | 46.1% | 16.8% | 12.00 | 4.89 / 7.11 |
| archivist vs archivist | 167 | 54.5% | 45.5% | 0.0% | 27.5% | 18.0% | 12.00 | 4.84 / 7.16 |
| archivist vs warden | 166 | 19.3% | 80.7% | 0.0% | 44.0% | 13.9% | 12.02 | 5.21 / 6.81 |
| warden vs warden | 166 | 45.2% | 54.8% | 0.0% | 54.8% | 48.2% | 12.00 | 5.49 / 6.51 |
| **All** | 1000 | 29.9% | 70.1% | 0.0% | **44.1%** | **20.5%** | **12.00** | 5.18 / 6.83 |

### Seed check (same data)

| Run | First-player wins | Ties | Avg first / second | Warden vs Quartermaster | Warden vs Archivist | Archivist vs Quartermaster |
|---|---|---|---|---|---|---|
| seed 1 | 44.1% | 20.5% | 5.18 / 6.83 | 91.0% | 80.7% | 94.6% |
| seed 5001 | 41.0% | 19.1% | 5.13 / 6.87 | 95.2% | 72.9% | 93.4% |
| seed 9001 | 39.4% | 17.4% | 5.08 / 6.93 | 89.2% | 74.1% | 95.2% |
| **mean** | **41.5%** | **19.0%** | 5.13 / 6.88 | 91.8% | 75.9% | 94.4% |

Reading:
- **Difficulty ladder holds:** Quartermaster < Archivist < Warden. Warden beats the Archivist about 76% of the time.
- **First-player gap by skill:** greedy-vs-greedy (Archivist mirror) is the worst case for the first
  player at 25–28%. The greedy player always answers the last open slot. The Warden mirror is
  42–55%: looking ahead takes away much of the last-move edge. Human play is probably somewhere in
  between, so this should be checked again against playtest data.
- **Tie rate** is highest in the Warden mirror (38–48%): two careful players often split the wall 6–6.

## Knob tests (1,000 duels each, seed 1 unless noted)

| # | Change | How tested | First-player wins | Draws | Notes |
|---|---|---|---|---|---|
| 0 | none (baseline) | data | 44.1% (3 seeds: 39.4–44.1) | 0% | |
| 1 | `tie_winner` = DRAW | data knob | 23.6% (29.7% of decided) | 20.5% | wrong direction |
| 2 | first player +1 | sim bonus | = baseline | 0% | identical to "ties to first player" (even score gaps) |
| 3 | first player +2 | sim bonus | 63.9% | 0% | overshoots |
| 4 | `chain_captures` = on | data knob | 35.5% | 0% | helps the last mover more |
| 5 | `clutch_bonus` 0 | data knob | 45.1% (seed 5001: 41.4%) | 0% | edge of the band, and Clutch becomes a blank trait: rejected |
| 5b | `clutch_bonus` 1 | data knob | 43.8% | 0% | |
| 6 | `set_link_bonus` 0 / 2 | data knob | 43.3% / 40.6% | 0% | |
| 7 | `signature_value` 1 / 3 | data knob | 40.4% / 39.1% | 0% | |
| 8 | `ambush_spring_bonus` 0 / 2 | data knob | 42.1% / 42.1% | 0% | |
| 9 | first player +2 if they hold their own Signature at the end | sim bonus | 58.1% / 57.2% / 54.2% (3 seeds) | 0% | Proposal B: slightly high |
| 10 | first player +2, a tie goes to whoever holds more Signatures | sim bonus | 56.9–60.1% | 0% | overshoots |
| **11** | **first player +2, ties are draws** | sim bonus + data knob | **55.0% / 52.9% / 50.1% of decided** (3 seeds) | 19.8–22.5% | **Proposal A** |

Rows 0, 1, 3, 4, 5, 9 and 11 were run with the final Warden cap (200 nodes). Rows 5b, 6, 7, 8 and 10
come from an earlier run at 250 nodes, where the baseline was 42.6%.
Rows 9–11 apply the bonus to the final score in the sim tool only. The AIs don't know about it, so
those numbers are estimates. An AI that knows the bonus would play for it.

### Proposal A, full table (seed 1): first player +2 "Tempo", ties are draws

| Pairing (A vs B) | Duels | A wins | B wins | Draws | First-player wins | Ties | Avg score (A+B) | Avg first / second |
|---|---|---|---|---|---|---|---|---|
| quartermaster vs quartermaster | 167 | 34.1% | 43.7% | 22.2% | 43.7% | 22.2% | 14.00 | 7.22 / 6.78 |
| quartermaster vs archivist | 167 | 2.4% | 90.4% | 7.2% | 48.5% | 7.2% | 14.00 | 7.40 / 6.60 |
| quartermaster vs warden | 167 | 5.4% | 85.0% | 9.6% | 46.1% | 9.6% | 14.00 | 6.89 / 7.11 |
| archivist vs archivist | 167 | 39.5% | 31.7% | 28.7% | 27.5% | 28.7% | 14.00 | 6.84 / 7.16 |
| archivist vs warden | 166 | 13.9% | 68.7% | 17.5% | 44.0% | 17.5% | 14.02 | 7.21 / 6.81 |
| warden vs warden | 166 | 30.1% | 36.1% | 33.7% | 54.8% | 33.7% | 14.00 | 7.49 / 6.51 |
| **All** | 1000 | 20.9% | 59.3% | 19.8% | 44.1% of all · **55.0% of decided** | 19.8% | 14.00 | 7.18 / 6.83 |

Over the three seeds: **52.7% of decided duels** (50.1–55.0). Counting draws as half a win it is **52.1%**
(50.1–54.0). The rate over all duels is 39.4–44.1%, because about 21% of duels are draws.

## Proposal (for the producer / sr game designer, not applied)
**A (recommended): "Tempo": the first player starts at +2 points, and ties are draws.**
- Same as saying "the second player must finish 4+ ahead to win; finishing exactly 2 ahead is a draw."
- First player: 50–55% of decided duels. This is the only tested change inside the band that leaves
  every trait whole.
- Cost: about 1 in 5 duels is a draw. Unlock goals (win streaks, "beat the Warden") would need a rule
  for draws, e.g. a draw doesn't break a streak.
- Needs: `tie_winner = DRAW` (existing knob, `data/balance.tres`) plus a new `first_player_bonus: int` in
  `BalanceConfig`, read by `WallRules.score`/`final_result` and shown on the score bar from turn 1.
  That is an engine change (cc05 owner) and a data change (balance owner). Neither is made here.
  The AIs pick up a real engine bonus on their own, because they evaluate with `WallRules`.

**B (if draws are unwanted): "Home guard": +2 to the first player if they hold their own Signature at the end; ties stay with the first player.**
54–58%, slightly above the band in two of three seeds. With an AI that knows the rule it would be
higher still. A +1 version has no effect, because score gaps are even. Not recommended without
another round of tuning.

**Not recommended:** `clutch_bonus` 0 (45% only at one seed, and the trait goes blank), chain captures
(35.5%), a flat +2 with ties to the first player (64%).

## Warden timings (target: under 200 ms on a phone; budget 4x headroom = 50 ms here)
Warden runs a 2-ply minimax with alpha-beta. Root moves are searched in greedy order and the
opponent's replies in exposure order. A **deterministic node cap** stops the search at
`WardenAI.max_nodes = 200` simulated placements, or 100 when a Triptych can score in this duel.
The cap only bites in the first two or three moves. Triptychs whose cards aren't in either
lineup are dropped from the search world; this is exact and halves the cost per node.

| Measure (3,325 Warden moves, one sim run, nothing else in the process) | Value |
|---|---|
| mean / p50 | 11.9 ms / 10.0 ms |
| p95 / p99 | 28.2 ms / 35.5 ms |
| max | 49.5 ms (another run: 54.7 ms) |
| nodes p95 / max | 206 / 231 |
| opening move, test suite (`test_warden_node_cap_and_time`) | 31 ms worst of 6 |

- The rare maxima of 50–77 ms are scheduler stalls. The machine is shared (load average 2–2.6 on 4
  cores), and two sims in parallel raise them. They are not search size. A 30 ms wall-clock cap does
  not remove them (max 52 ms with `--warden_ms=30`), and the node count is the same in those moves.
- Engine cost per search node is about 45 µs (copy + `WallRules.place` + evaluate) with no
  Triptych and about 110 µs with one. `WallRules.score` checks every Triptych on each call;
  `legal_moves` costs about 68 µs on an empty wall.
- Optional `WardenAI.max_ms` (off by default) adds a wall-clock stop between root moves for release
  builds (suggested 150). It is off in the sim and the tests, because a clock-cut move is not
  reproducible from the seed.
- Search depth vs node cap: 1,500 / 400 / 250 / 200 nodes gave the same results within noise
  (Warden vs Archivist 75–81%), so 200 costs nothing measurable in strength.

## Open items
1. Re-check the first-player rate with human-vs-Warden playtest data (cc QA). AI mirrors bracket it
   at 25–55%.
2. If Proposal A is taken, decide how a draw counts for unlock goals and the Rivals screen.
