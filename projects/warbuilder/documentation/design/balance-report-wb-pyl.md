# Warbuilder: Balance report for push-your-luck FIRE with the Firefight bust (as built)

> **NOT SHIPPED (2026-11-11, wb-fix2).** The push-your-luck FIRE build was reverted at the head's request; the game is back to the wb-art-import rules (b8f83e1). Kept as design history. See `wb-improve-v2.md` for the current direction.

*Mechanics developer · 2026-11-05 · Board task `wb-pyl-impl`*
*Design: `push-your-luck-shooting.md` (flip and stop, Jam icons, 3-step ladders; head's answers P2 and P3), with the bust rule from `bust-variants.md` A "Firefight" (head's choice: Rally hook, no final-circle change, the 4-gun retune).*
*Simulator: `qa/tools/ai_sim.js` on the **shipped engine** (`source/project-warbuilder/src/engine.js`). The engine's own AI plays both sides: the combo-aware AI (now Jam-aware) against the combo-blind one. Unless a row says otherwise, each row is 4,000 seeded games. Every run had 0 errors, 0 stuck games and 0 card-count failures.*

## 1. Summary
The flip-by-flip Firefight shot is in the game. It **meets every target except the hit rate**, which sits at **71.9%**, about 2 points over the 60–70% band.
- Combo-aware AI: **60.4%** (target ≥ 55%).
- First player: **50.3%**, or **49.7%** in the mirror (target 45–55%).
- Gun classes: **45–56%**, or **43–54%** in the mirror (target 42–58%).
- Gas and storm share of damage: **14.0%** (target 10–20%).
- Rounds: **8.98**, max 11.
- Whole turns wiped by a bust: **4.3%** (doc 4.9%; band 3–7%).
- Firepower still rises from 8.2 to 21 by round 9.

The stop decision matters in both directions:
- An AI that never risks its pot wins **47.2%** of mirror games (doc 46.7%).
- An AI that always pushes wins **38.0%** (doc 34.9%).

These numbers match the designer's simulator on the same rule set. `ai_sim_bust.js --mode=firefight --set=finalLimit:2,tune:pot --policy=ev` gives an edge of 59.0%, a hit rate of 71.8%, 9.05 rounds, gas 14.5%, 4.5% wiped turns and 14.3% busts per shooting turn.

**Why the hit rate is high:** two of the head's choices make shots safer. The first is no Hot Zone (B3). The second is the AI policy that counts the pot, which is careful by design. The doc's 67.8% used the Normal policy and the final-circle limit −1. If playtests also show people hitting too often, there are two knobs. One is a Jam on Recon Run (`push-your-luck-shooting.md` §3.2). The other is `TUNE.pyl.finalMinus: 1`, which brings back the final-circle squeeze (Q1).

## 2. Numbers vs targets
| Target | Result | Verdict |
|---|---|---|
| Hit rate (shots that deal damage), 60–70% | **71.9%** (71.5% without the knife); mirror 72.7% | 2 points over (see §1) |
| Combo-aware vs blind, ≥ 55% | **60.4%** | ok (doc's Firefight + retune: 59.0%) |
| Same, Squad and Rally off (control) | 44.2% | ok: synergy is what wins (doc 41.2%) |
| First player, 45–55% | **50.3%** (mirror 49.7%) | ok |
| Gun classes, 42–58% (aware vs blind / mirror) | **45–56% / 43–54%** | ok (lowest: Bastion 45% / Viper 43%) |
| Gas + storm share of damage, 10–20% | **14.0%** (mirror 12.2%) | ok |
| Match length, ≤ ~9 rounds | **8.98** (mirror 8.80), max 11; hard ends 0.35% | ok |
| Whole turns wiped (reached a step, dealt 0), 3–7% | **4.3%** (mirror 4.5%) | ok (doc 4.9%) |
| Busts per shooting turn | 14.3% | doc 16.8% (that run had the Hot Zone) |
| Timid AI vs normal (mirror, 2,000) | **47.2%** | ok: timid play is punished (doc 46.7%) |
| Reckless AI vs normal (mirror, 2,000) | **38.0%** | ok (doc 34.9%) |
| Flips per turn / per shooting turn | **2.84 / 3.69** | doc 2.65 / 3.44 |
| Shots per shooting turn / per cash-out | 1.20 / 1.24 | doc: the pot holds 1.25 shots |
| Shooting turns with 0 damage | 26.3% | doc 28.4% |
| Damage lost to busts (pot only, share of damage dealt) | 2.1% | The doc's 7.2% also counts the bust shot's own step |
| Shots that miss on Precision (before step 1) | 11.9% | — |

### 2.1 Firepower and hit rate per round (combo-aware, per player turn; blind in brackets)
| Round | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Firepower | 8.2 (8.3) | 9.4 (9.3) | 11.2 (10.4) | 12.2 (11.1) | 15.0 (12.8) | 16.5 (14.0) | 19.4 (15.3) | 20.7 (16.6) | 21.1 (16.9) | 21.2 (17.0) | 20.2 (16.6) |
| Damage dealt | 0.31 | 1.24 | 1.63 | 1.49 | 2.74 | 3.91 | 5.82 | 7.44 | 8.66 | 8.67 | 7.34 |
| Hit rate (both AIs) | 76% | 76% | 71% | 56% | 66% | 73% | 77% | 78% | 76% | 69% | 61% |

The dip in round 4 comes from first fights with thick starter decks (60% Jams) and few Rallies. Late rounds fall back to 61–69%, because the deck still holds Jams and the pot is bigger, so the AI cashes out sooner.

### 2.2 Gun classes (win rate holding the gun at the end; aware vs blind / mirror)
| Sidearm | Magnum | Knife | Viper | Breacher | Raider | Sapper | Sentinel | Bastion | Ranger | Longbow |
|---|---|---|---|---|---|---|---|---|---|---|
| 49 / 52 | 48 / 49 | 56 / 54 | 48 / 43 | 55 / 53 | 46 / 47 | 50 / 52 | 48 / 52 | 45 / 47 | 51 / 51 | 48 / 50 |

## 3. What was built (engine)
- **Shot as three actions:** `fireStart(s, p, gi)`, then `flip(s, p)` (one per tap) and `stop(s, p)` (bank the step). The state is `s.shot = {gi, flipped, sum, jams, level, steps, …}`. The top step banks by itself, and so does running out of Precision or cards on a step. Flipped cards stay out of the deck until the shot ends; if the deck runs out mid-shot, the discard pile is reshuffled in.
- **Firefight:**
  - Banked steps go to `pl.pot`. `cashOut(s, p)` (STOP) deals each banked shot on its own, so Reactions and Armor apply per shot. `endTurn` cashes out automatically.
  - Jams count in `pl.heat` for the whole turn. `jamLimit(s, p)` = 2 + 1 per Rally this turn, recomputed live, so a Rally played between shots raises it.
  - At the limit the shot busts: the pot is lost, `pl.busted` is set, and FIRE is refused for the rest of the turn.
  - A shot that runs out of Precision before step 1 misses, and the pot stays.
- **Jam:** `jam: true` on Sprint and Scout. A Jam costs the gun's Recoil in Precision. Steady (`revealPlus`) cancels one Jam. Mark lowers every step of the next shot. The knife flips like any gun.
- **Bust-rule seams (`TUNE.pyl`):**
  - Shipped values: `jamScope: 'turn'`, `jamLimit: 2`, `rallyPlus: 1`, `finalMinus: 0`, `bustCost: 'pot'`, `bank: 'pot'`.
  - The earlier Hot Zone rule still runs from the same code (`jamScope: 'shot'`, `bustCost: 'shot'`, `bank: 'shot'`, `rallyPlus: 0`, `finalMinus: 1`). A test covers it.
  - A value that is not built refuses to fire (`pylCheck`), so a new variant has a clear place to land.
- **Guns:** 3-step ladders and the Recoil changes from `push-your-luck-shooting.md` §4, plus the Firefight retune: Viper 2→3 · 4→5 · 6→7, Bastion 3→4 · 5→6 · 7→9, Magnum 2→3 · 5→7 · 7→10, Breacher 2→4 · 4→6 · 6→8.
- **AI:**
  - Stop policy that counts the pot (`bust-variants.md` §3.1, the best policy there). Fire when step 1 is at least 5% likely. Fire again into a pot only when P(step 1) × step-1 damage beats P(bust first) × pot. Inside a shot, push only when P(next) × (gain) beats P(bust first) × (pot + this step).
  - `shotOdds()` is a Monte Carlo seeded from the state, so replays stay deterministic.
  - Jam-aware scrapping (cheap): the combo-aware AI scraps Scouts once its other Intel sources give 3 Intel (before, 6). This moved the edge by about +2 points at no cost to the other targets (tested at 6 / 4 / 3 / 2: 3 keeps the mirror hit rate lowest).
- **Removed:** the commit planner (`suggestCommit`, `stepOdds`, `hitChance`, `expDmg`), the AIM sheet, the Fire and Load sheets, and the old Precision-commit fire. `fire(s, p, gi, {stopAt, cash})` stays as a one-call helper for tests and scripted replays.

## 4. Reproduce
From the repo root:
```bash
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-blind --curve          # §2 main row and the per-round table
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-aware                  # first player, mirror gun spread
node projects/warbuilder/qa/tools/ai_sim.js 4000 --match=aware-blind --flat           # control: Squad and Rally off
node projects/warbuilder/qa/tools/ai_sim.js 2000 --match=aware-aware --pa=timid       # stop policy: timid vs the shipped AI (also --pa=reckless)
cd projects/warbuilder/source/project-warbuilder && npm run sim                       # the band report (warns, never fails)
```

## 5. Limits
- These are the engine's AIs, not people. Hit rate and push behaviour will move with human nerve. The flip UI shows the odds of reaching the next step and of busting first, so humans should play near the AI's line.
- `npm run sim` defaults to 2,000 games, so single gun classes can drift a few points from the 4,000-game numbers above.
- Damage "lost to busts" counts only the pot, not the step the busted shot had reached.
