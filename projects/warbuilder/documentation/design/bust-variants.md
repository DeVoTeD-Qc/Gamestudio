# Warbuilder: Bust variants for push-your-luck FIRE (design + simulator proof)

> **NOT SHIPPED (2026-11-11, wb-fix2).** The push-your-luck FIRE build was reverted at the head's request; the game is back to the wb-art-import rules (b8f83e1). Kept as design history. See `wb-improve-v2.md` for the current direction.

*Sr Game Designer · 2026-11-05 · Board task `wb-bust` · Status: **proposal, proven in the simulator, not in the game***
*Inputs: the head's note ("we need a busting mechanic, otherwise the stakes are too low"; inspiration: the push-your-luck party-builder where a bust loses the whole night). The approved base rule is `push-your-luck-shooting.md` (V2 Hot Zone).*
*Simulator: `qa/tools/ai_sim_bust.js` (new). It runs a **frozen copy of the pre-PYL engine** (`qa/tools/fixtures/engine_pre_pyl.js`), so the numbers don't move while `source/` is being rebuilt. `ai_sim.js`, `ai_sim_syn.js`, `ai_sim_pyl.js` and `source/` are unchanged.*
*Only the mechanics are borrowed (a shared pot, a bust that wipes it, cash out any time, and thinning trouble out of your pool). No names, art or content come from that game.*

## 1. Answer
**Recommended: A "Firefight".** Your hits wait in a pot until you STOP. Jams count for the whole turn, and **every Rally you made this turn raises your Jam limit by 1**. Reaching the limit loses the pot.

Compared with today's Hot Zone, in the same harness:
- A whole turn's damage is wiped **3.8× as often** (4.9% of shooting turns vs 1.3%).
- **2.5× as much damage** is lost to busts (7.2% of damage dealt vs 2.9%).
- The stop decision now matters both ways. A timid player loses **46.7%** of mirror games (today **51.2%**, so timid play is free today). A reckless player loses **34.9%**.
- Combo edge **58.6%** (59.0% with the gun retune), first player 49%, gas 18%.

**The Rally hook is not optional.** Without it, any bust that ends the turn caps how far a big engine can push. The combo edge then falls to **53.2%** (fails), and gas rises to 20.5%. "Your squad covers you" is also the synergy hook the head asked for.

**What these stakes don't do:** comebacks barely move (17% → 18%), and the pot holds only **1.25 shots** on average. That is because most turns fire only one shot. Q2 covers the knob that would raise the stakes further.

## 2. Rules (as the player reads them)
The base stays as approved: flip one card per tap, 1 Precision per flip, add Hit Markers, stop or push at each ladder step, Jam = Sprint and Scout (costs Recoil), Steady cancels a Jam, Mark lowers every step.

**A. Firefight (recommended)**
> Your whole turn is one **firefight**. Each shot you bank goes into your **pot**. It deals nothing yet.
> Jams count for the whole turn. Your Jam limit is **2, +1 for each Rally you made this turn** (1 fewer in the final circle).
> Reach the limit and you **BUST**: the pot is lost. **STOP** whenever you like to deal the whole pot. You also stop when your shots or Precision run out.

**B. Heat**
> Your hits deal damage at once. But every Jam this turn adds 1 **Heat**. The limit is 2, +1 per Rally (1 fewer in the final circle).
> At the limit your gun **OVERHEATS**: this shot misses, your shooting ends, and you take **3 damage**.

**C. Hot Hand (my add-on to A)**
> Firefight, and **every Jam you survive adds +1 damage** to that shot.

Only one new decision appears: after a banked shot, **fire again (and risk the pot) or STOP**. Pushing inside a shot works as today. Each player-facing rule set is 3–5 sentences.

## 3. Numbers (combo-aware vs combo-blind, 4,000 seeded games per row; policies 2,000 mirror games; 0 errors and 0 card-count failures in every run)
| Measure | Hot Zone (today) | **A Firefight** | A + gun retune | B Heat (3 dmg) | C Hot Hand |
|---|---|---|---|---|---|
| Combo-aware vs blind, ≥ 55% | 56.0% | **58.6%** | 59.0% | 59.1% | 60.0% |
| Same, Squad and Rally off (control) | 44.0% | 41.2% | — | 44.3% | 44.2% |
| First player, 45–55% (mirror) | 49.1% | **48.8%** | 49.2% | 48.8% | 48.5% |
| Gun classes, 42–58% (aware vs blind / mirror) | 43–58 / 41–56 | 40–57 / 39–58 | **43–57 / 44–56** | 38–59 / 40–57 | 41–56 / 40–57 |
| Hit rate (shots that deal damage) | 68.4% | 67.8% | 67.8% | 71.8% | 67.7% |
| Bust in a shooting turn | 21.3% | 16.8% | 16.8% | 15.6% | 16.7% |
| **Whole turn wiped** (reached a step, dealt 0) | 1.3% | **4.9%** | 4.7% | 2.3% | 4.8% |
| Shooting turns with 0 damage | 21.5% | 28.4% | — | 25.9% | 28.2% |
| **Damage lost to busts** (as a share of damage dealt) | 2.9% | **7.2%** | 6.9% | 2.8% (+6.2 self-damage a game) | 7.5% |
| Damage per shooting turn (SD, CV) | 4.49 (4.50, 1.00) | 4.02 (4.48, **1.11**) | (1.12) | 4.03 (4.29, 1.06) | 4.19 (4.58, 1.09) |
| Gas + storm share, 10–20% | 12.9% | 17.8% | 18.1% | 13.8% | 16.3% |
| Rounds, ≤ ~9 (max) | 8.84 (11) | 9.18 (11) | 9.22 (11) | 8.82 (11) | 9.07 (11) |
| Flips per turn / per shooting turn | 2.84 / 3.72 | 2.65 / 3.44 | — | 2.48 / 3.25 | 2.61 / 3.40 |
| Decisions per shooting turn | 1.03 | 1.39 | — | 1.26 | 1.36 |
| "Fire again" taken (when there is a pot) | — | 67% | — | 66% | 68% |
| Comebacks (winner trailed by 8+ HP at a round end) | 16.9% | 18.1% | 16.5% | 18.9% | 17.3% |
| Lead changes per game | 2.04 | 1.92 | — | 1.91 | 1.98 |

### 3.1 Does the stop decision matter? (AI policy vs the Normal AI, combo-aware mirror; 50% means it doesn't matter)
| Policy | Hot Zone | **A Firefight** | B Heat | C Hot Hand |
|---|---|---|---|---|
| Timid (never risks a bust) | **51.2%** (free) | **46.7%** | 48.4% | 46.8% |
| Cautious (≤ 20%) | 51.7% | 49.9% | 50.7% | 49.8% |
| Bold (≤ 50%) | 47.8% | 48.8% | 48.8% | 48.7% |
| Reckless (always pushes) | 36.2% | **34.9%** | 37.2% | 34.5% |
| Expected value (counts the pot) | 51.6% | 51.8% | 53.1% | 53.1% |

Today only recklessness is punished, and never pushing costs nothing. Under Firefight both extremes lose, and the best player is the one who **counts what is in the pot** (EV 51.8–53.1%). That is the "nerve" decision the head wants. Between Cautious and Bold the curve stays flat (±2), so the decision is a judgement call, not a solved one.

### 3.2 Other things tested (2,000–4,000 games)
| Test | Result | Verdict |
|---|---|---|
| A with **no Rally hook** (limit 2 flat) | Edge 53.2%, gas 20.5%, 9.37 rounds | Fails: a bust that ends the turn caps the engine |
| A with a Jam limit of 3 (no hook) | Edge 55.3%, but busts only 6% and wipes 2.9% | Too safe; the hook is better |
| A, final circle keeps limit 2 (no Hot Zone) | 9.04 rounds, gas 14.7%, edge 58.2%, wipes 4.2% | Knob if matches run long (Q3) |
| "Pot" variant: Jams count per shot (as today), the pot stays | Edge 51.9% without the hook, 59.6% with it | Same stakes as A, but two Jam counters to explain |
| B penalties (limit 2 + hook): rival gets a free Mark / 1 fewer shot next turn / Loadout skips next Ready / 5 damage | Edge 58.0 / 56.1 / 59.7 / 56.4%; rounds 9.01 / 9.15 / 9.13 / 8.61; wipes 2.3–2.6% | All playable. Health damage is the clearest and shortest match |
| B, limit 3, Heat carries over (cools 1 a turn) | Bust 8%, edge 55.2%, timid 49% | More bookkeeping for little stake |
| A, limit 3, + streak (+2 per extra shot in a cashed pot) | Edge 56.8%, timid 45.9% | Works, but helps only multi-shot guns |
| C with +2 per survived Jam | Edge 61.8%, 8.88 rounds | Edge creeps high; +1 is enough |
| **Hot cards**: tier III (or II+III) squad cards carry a Jam and +1 damage | A: edge 59.6 / 60.7%, but 9.25 / 9.38 rounds, gas 18–20.5% | Not now: more Jams in the late deck lengthen matches. Retest after humans play A |

## 4. Recommendation
1. **Adopt A Firefight with the Rally hook and the Hot Zone** (final circle: limit −1). It has the most stakes per sentence of rules. Thinning still shows: the Jam share of the deck falls from 60% to 25% by round 9, and turn busts fall from 19–20% in rounds 4–5 to 13% in round 8 (combo-aware, with the retune). The final circle brings the nerve back (27–33% busts).
2. **Retune four guns with it** (A + gun retune column). A bust loses several small shots, so the multi-shot guns need a little more per shot, and the big single shots a little less:

| Gun | Ladder now (PYL) | With Firefight |
|---|---|---|
| Viper (SMG) | 2→3 · 4→4 · 6→6 | 2→3 · 4→**5** · 6→**7** |
| Bastion (LMG) | 3→3 · 5→6 · 7→9 | 3→**4** · 5→6 · 7→9 |
| Magnum | 2→4 · 5→7 · 7→10 | 2→**3** · 5→7 · 7→10 |
| Breacher | 2→4 · 4→6 · 6→9 | 2→4 · 4→6 · 6→**8** |

3. **Keep C (Hot Hand) as the next lever.** If playtests say "busting feels bad but pushing doesn't pay", +1 per survived Jam makes the Jam itself a reward. It shortens matches by 0.1 round, and the head's "strong cards that carry Jams" idea plugs straight into it.
4. **B Heat is the fallback** if the head wants damage to land immediately ("my hits count") while keeping a real cost: about 6 self-damage a game. It wipes fewer turns (2.3%), so the stakes come from the penalty, not from the pot.

## 5. Engine and UI changes (for mechanics-developer and ui-ux-agent, after approval)
| Item | Work |
|---|---|
| `s.shot` grows a turn-level `s.fight = {pot: [{dmg, cq}], jams, limit}`. `flip` adds Jams to `fight.jams`. A banked shot pushes onto `pot` instead of calling `applyHit`. A new `cashOut(s,p)` applies each pot entry with `applyHit` (Reactions and Armor per shot, as today). A bust clears the pot. `endTurn` auto-cashes an open pot. | M |
| `limit = 2 + pl.rallyDone.length − (safeBounds(s).n <= 1 ? 1 : 0)`. It is recomputed when a card is played mid-turn (a Rally after the first shot raises it). Steady still cancels a Jam. | S |
| AI: port the "fire again" choice from `ai_sim_bust.js` (Normal: fire again when the chance of busting before step 1 is ≤ 35%; better: EV with the pot at stake). The stop or push inside a shot is unchanged. | S |
| Gun retune per §4 (four `GUNCLASS` ladders). | S |
| UI: a **POT** tray beside the flip row (the banked shots stack up, with the total in big numbers). A Jam bar that shows the turn's slots (2 + Rally, a gold slot per Rally). After a bank, two buttons: **[FIRE AGAIN · risk 9]** and **[STOP · deal 9]**. A bust shows "JAMMED. POT LOST −9", the pot tray shatters, and a log line follows. Show the bust chance on FIRE AGAIN, as on today's FIRE button. | M |
| Tests: bands as in §3 (edge ≥ 55%, first player 45–55%, guns 42–58%, gas 10–20%) plus "turn wiped" at 3–7%. | S |

Print-and-play: one "Pot" strip beside the gun card (park the banked shots' damage as tokens). Add a Jam track with 2 boxes plus 2 gold "Rally" boxes. The storm card reads "Final circle: Jam limit −1".

## 6. Reproduce
From the repo root (4,000 games ≈ 30 s):
```bash
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=hotzone                       # today (baseline, same harness)
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=firefight --curve             # A (recommended); add --set=tune:pot for the gun retune
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=heat                          # B; --pen=mark|shot|loadout, --set=penHp:5
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=hothand                       # C; --set=jamBonus:2
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=firefight --match=aware-aware # first player, guns
node projects/warbuilder/qa/tools/ai_sim_bust.js 2000 --mode=firefight --match=aware-aware --pa=timid --pb=normal  # stop-policy test
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=firefight --set=rallyPlus:0   # control: no Rally hook (fails)
node projects/warbuilder/qa/tools/ai_sim_bust.js 4000 --mode=firefight --flat              # control: Squad and Rally off
```
The Hot Zone baseline reproduces `push-your-luck-shooting.md` §3: hit rate 68.4% (doc 68.2%), edge 56.0% (doc 57.1%, within noise), 8.84 rounds (doc 8.85), gas 12.9% (doc 13.0%).

**Limits:**
- These are the engine's AIs, not people. The buy and scrap AI doesn't know about Jams; a human would scrap Sprints and Scouts sooner and chase Rallies harder, which would widen the edge.
- Mirror gun spreads in this harness run about 4 points wider than in the PYL doc (Bastion is the low end in every variant, today included).
- "Comeback" means the winner trailed by 8+ Health at the end of some round.

## 7. Questions for the head
1. **Q1. Which bust?** (a) **A Firefight + Rally hook** (pot lost; recommended). (b) C Hot Hand: A plus +1 per survived Jam (more reward for pushing). (c) B Heat: hits land at once, an overheat costs 3 Health. (d) Keep today's Hot Zone.
2. **Q2. Do you want bigger stakes than this?** The pot averages 1.25 shots because most turns fire once. (a) **No: ship A and playtest first** (recommended). (b) +1 shot for every gun under Firefight, so pots of 2–3 shots are normal (needs a ladder pass). (c) A bust also costs your Loadout's next Ready (the stake reaches into the next turn; tested in B: edge 59.7%, 9.1 rounds).
3. **Q3. Final circle under Firefight?** (a) **Limit −1** (consistent with Hot Zone: 27–33% busts in the showdown, 9.2 rounds; recommended). (b) No final-circle change (9.04 rounds, gas 14.7%, a calmer climax). (c) Limit −1, but the storm only starts after the first final-circle round.
