# CardZone: Loadout Loop sims (v0.1 vs v0.2)

*Sr Game Designer · 2026-11-04 · Board task `cz-spec2` · Supports `loadout-loop-spec.md` v0.2*
*Script: `projects/cardzone/tools/loadout_sim.py` (Python 3, no dependencies, no RNG). Re-run with `python3 tools/loadout_sim.py` (tables), `--ablation` (lever test) or `--log <scenario>` (full turn log).*

## Why a script and not only a hand trace
The head asked whether a player who is shot early still has a real game. A single hand-written example is easy to bend. So we wrote simple **deterministic bots** that play both rule sets on the same map, drops and Zone route, and we read their turn logs like a hand trace. The bots are greedy and fairly dumb (see "Limits"), so treat the numbers as **direction, not balance**. Paper tests decide the final values.

**Bot policy (the same in both rule sets):** loot the most valuable affordable card in reach, and don't buy duplicate weapons or attachments. Leave an area that is gas or closes next round, preferring the Core. From round 4, with a real gun, move into range of a target and fire every weapon. Always Brace to block as much damage as possible. Patch up with spare Search 2. In v0.2, hold up to 2 unplayed Brace cards, and spend Adrenaline on Move first when fleeing, otherwise on Search. In v0.1, use Quick pack. **Target choice:** "weakest" (focus the lowest health, a stress test for snowballing) or "bounty-aware" (shoot the Bounty holder when possible, the way real players would).

**Scenarios** (route A, Standard pack, Ana always moves first):
| Scenario | Players and drops | Scripted ambush |
|---|---|---|
| `2p-even` | Ana Quarry, Ben Radio Hill | – |
| `2p-ben-hit-twice` | Same | Round 2: Ben takes 2 Hits |
| `3p-cid-hit-twice` | Ana Quarry, Ben Rail Yard, Cid Radio Hill | Round 2: Cid takes 2 Hits |
| `3p-focus-cid` | Same | Round 2: Cid takes 2, round 3: Cid takes 1 more (focus-fire) |
| `3p-focus-cid-bounty-aware` | Same, bots target the Bounty first | Same as above |

**Table columns:** `hp` = health stack at the end of the round. `gun` = best weapon owned (DMG × shots per turn). `usable` = cards that player could use on their turn that round, with the number of Hits drawn in brackets (in v0.1 a Hit is dead, and in v0.2 it is Adrenaline and comes on top of the 4 cards).

## Headline results
| Measure | v0.1 | v0.2 |
|---|---|---|
| Fewest usable cards in a turn (any player, all scenarios) | **0** (4 Hits, empty turn) | **4** (never below a full hand) |
| Victim's usable cards on the turn after the ambush | 2 | 6 (2 Adrenaline + 4) |
| Round the ambushed player was eliminated | 6, 6, 3, 3 | **12, 8, 7, 12** |
| Earliest elimination in any game | Round 3 | Round 7 |
| Ambushed player led on health later, or outlived an un-ambushed player | 0 of 4 games | 2 of 4 games |
| Game length (last round) | 6–9 | 8–12 |

**Reading:** v0.1 matches the head's fear exactly. A player shot twice gets a 1–2 card turn, can't flee or patch up, is shot again, and is effectively out from that point (Ben and Cid sat at 0 health for three rounds with nothing to do). In v0.2 the same ambush costs health but never the turn, and the victim stays in the game to the late stages.

## Worked example 1: 2 players, Ben hit twice early (`2p-ben-hit-twice`)

**v0.1 (rules as written in v0.1)**
| Rd | Ana hp / gun / usable | Ben hp / gun / usable |
|---|---|---|
| 1 | 4 / 3 / 4 | 5 / 2 / 4 |
| 2 | 4 / 3 / 3 (1H) | 3 / 2 / **2 (2H)** |
| 3 | 4 / 4 / 4 | 0 / 2 / **1 (3H)** |
| 4 | 4 / 4 / 4 | 0 / 2 / 4 |
| 5 | 4 / 4 / 3 (1H) | 0 / 2 / 4 |
| 6 | 4 / 4 / 4 | **out** |

Round 3: Ana loots the Twin-Drum LMG and hits Ben for 3. Ben's next hand is *Hit, Hit, Hit, Dash*, so he can't run, loot or shoot. He spends rounds 4–5 at 0 health with no way to patch up, and dies in round 6. **Snowball confirmed.**

**v0.2**
| Rd | Ana hp / gun / usable | Ben hp / gun / usable |
|---|---|---|
| 1 | 4 / 3 / 4 | 5 / 2 / 4 |
| 2 | 4 / 3 / 5 (1H) | 3 / 2 / **6 (2H)** |
| 3 | 4 / 3 / 4 | 3 / 2 / 4 |
| 4 | 4 / 3 / 4 | 2 / 2 / 5 (1H) |
| 5 | 3 / 3 / 5 (1H) | 3 / 2 / 6 (2H) |
| 6 | 4 / 3 / 5 (1H) | 3 / 2 / 4 |
| 7 | 4 / 3 / 4 | 3 / 2 / 4 |
| 8 | 1 / 4 / 4 | 2 / 3 / **8 (4H)** |
| 9 | 1 / 4 / 8 (4H) | **3** / 3 / 4 |
| 10 | 1 / 4 / 4 | **3** / 3 / 4 |
| 11 | 1 / 4 / 4 | **3** / 3 / 5 (1H) |
| 12 | 1 / 8 / 5 (1H) | out (final circle + Longshot) |

Key beats (from the turn log):
- **R2:** Ben draws *Hit, Hit* **plus** a full hand (*Dash, Dash, Sidearm, Scavenge*). Adrenaline lets him move to Rail Yard, take a shot at Ana (she braces with the Duck in her next hand) and loot a Red-dot. That's a full turn right after the ambush.
- **R4–5:** Ana's shotgun hits Ben once (he braces with two Ducks, one held from last turn). Ben is now **Down**, so Ana's Sidearm follow-up next round deals 0. Ben is the trailing player, Ana holds the **Bounty**, and Ben's Sidearm hit on her **heals him 1**.
- **R8:** Ana loots the Longshot .50 and hits Ben for 3, leaving him at 0 health. In v0.1 that would be a dead turn. In v0.2 Ben draws **4 Hits + 4 cards**: he fires the Hunting Rifle (Bounty claim, heal 1), uses Adrenaline as Search to loot an **Assault Rifle (Search 6)**, fires it (Bounty claim, heal 1) and takes Ana from 4 to 1. **Ben leads on health for rounds 9–11.**
- **R12:** Final circle I. Ben holds the Bounty (more health), so he takes 2 and Ana takes 1. Ana's Longshot finishes him. Ana wins **at 1 health**. It is a close game decided by the last supply drop, not by round 2.

## Worked example 2: 3 players, Cid focus-fired early (`3p-focus-cid-bounty-aware`)
Cid takes 2 Hits in round 2 and 1 more in round 3 (from two different players), and Ben avoids early fights.

| Rd | Ana hp / gun / usable | Ben hp / gun / usable | Cid hp / gun / usable |
|---|---|---|---|
| 1 | 4 / 3 / 4 | 5 / 1 / 4 | 5 / 2 / 4 |
| 2 | 3 / 3 / 5 (1H) | 4 / 1 / 5 (1H) | 3 / 2 / 6 (2H) |
| 3 | 3 / 4 / 5 (1H) | 4 / 1 / 4 | **2** / 2 / 5 (1H) |
| 4 | 3 / 4 / 4 | 2 / 3 / 5 (1H) | 2 / 2 / 5 (1H) |
| 5 | 3 / 4 / 4 | 3 / 3 / 5 (1H) | 2 / 2 / 6 (2H) |
| 6 | 4 / 4 / 5 (1H) | 3 / 3 / 5 (1H) | 2 / 2 / 4 |
| 7 | 4 / 4 / 4 | 3 / 3 / 4 | 3 / 2 / 5 (1H) |
| 8 | 2 / 4 / 5 (1H) | **out** | 3 / 4 / 4 |
| 9 | 3 / 4 / 6 (2H) | out | 2 / 4 / 8 (4H) |
| 10 | 3 / 4 / 4 | out | 2 / 4 / 4 |
| 11 | 2 / 4 / 4 | out | 2 / 4 / 6 (2H) |
| 12 | 1 / 4 / 7 (3H) | out | **out (2nd place)** |

- **R3–4:** Cid, at 2 health, uses Adrenaline to reach the Motel and loot a Medkit. Ben has the most health and holds the Bounty, so Cid's Hunting Rifle hit on him **heals Cid 1**.
- **R4:** Ben's Assault Rifle shot at Cid deals only 1, because Cid braces with a held Duck. Focus-fire is now slower: Cid is **Down** for the rest of the round.
- **R8:** Cid outlives Ben, who was never ambushed. Cid fires on Ana after the Longshot kill, loots the Extended Mag from Ben's crate for Search 1, and reaches the final circle in **2nd place**.
- **v0.1, same start:** Cid draws *Hit, Hit, Hit + 1 card* in round 3 and is eliminated that round (out **r3**, last place).

## Worked example 3: 3 players, bots ignore the Bounty (`3p-cid-hit-twice`, stress test)
| Rd | Ana | Ben | Cid |
|---|---|---|---|
| v0.1 | out r8 | **won** (5 hp) | out r6 (0 hp from r3, usable 1 in r3) |
| v0.2 | out r8 | **won** (4 hp) | out r8 (≥ 4 usable every turn) |

Cid lasts 2 rounds longer and never has a dead turn. But when the bots **ignore the Bounty**, the player who avoided fighting (Ben, a Sidearm only until round 7) wins both versions. With bounty-aware bots, the same start is won by Ana and Ben is out in round 11 (see the ablation). **Open question:** is the Bounty enough to flush a camper out, or do we need more (DESIGN_REVIEW follow-up F5)?

## Lever ablation (which v0.2 rule does the work?)
Each row switches **one** v0.2 lever off. Format: winner · last round · round each player was eliminated.

| Scenario | v0.1 | v0.2 all levers | No Adrenaline | No Down | No Bounty heal | No Bounty gas | Bots target Bounty |
|---|---|---|---|---|---|---|---|
| 2p-even | Ana · 6 · Ben r6 | Ana · 12 · Ben r12 | Ana · 7 · Ben r7 | Ana · 8 · Ben r8 | Tie · 12 · both r12 | Ana · 12 | Ana · 12 |
| 2p-ben-hit-twice | Ana · 6 · **Ben r6** | Ana · 12 · **Ben r12** | Ana · 4 · **Ben r4** | Ana · 8 · Ben r8 | Ana · 8 · Ben r8 | Ana · 12 | Ana · 12 |
| 3p-cid-hit-twice | Ben · 8 · **Cid r6** | Ben · 8 · **Cid r8** | Ben · 12 · **Cid r4** | Ana · 11 · Cid r7 | Ben · 8 · Cid r8 | Ben · 8 | Ana · 11 · Cid r8 |
| 3p-focus-cid | Ben · 9 · **Cid r3** | Ana · 11 · **Cid r7** | Ben · 12 · **Cid r4** | Ben · 8 · Cid r7 | Ana · 11 · Cid r7 | Ana · 11 | Ana · 12 · **Cid r12** |

**What we learn:**
1. **Free-draw Hits + Adrenaline are the core fix.** Without Adrenaline (but with Hits still free draws) the victim dies **earlier** than in v0.1 (r4), because the extra health loss isn't offset by tempo.
2. **Down** stretches games by 2–4 rounds and protects the victim of focus-fire (Cid r7 vs r3).
3. **Bounty heal** matters in duels where one player pulls ahead (2p: Ben r12 vs r8 without it). Its effect in 3p depends on players *using* it. Bounty-aware bots let the focus-fire victim reach the final circle.
4. **Bounty gas** (the extra final-circle Hit) **changed no result** in these runs. It's cheap, but a candidate to cut if it confuses players (DESIGN_REVIEW follow-up F4).

## Packing time (estimate, to verify at the table)
| Step | v0.1 | v0.2 |
|---|---|---|
| Orders to consider at Pack | 4–6 cards → 24–720 orders | Hold 0–2 of the 0–4 leftover cards → usually 1–4 options, at most 11 |
| Physical handling | Fan, reorder, square up | Slide the line under the stack, place 0–2 cards face up on top |
| Seconds per Pack (est.) | 15–45 s | **≈ 5 s** (2–4 s choice + 2–3 s handling) |
| Turn (est.) | 50–90 s | **35–60 s** |

Paper-test target: **median Pack ≤ 10 s, 90th percentile ≤ 20 s**, logged with a phone stopwatch in the 3–5 print-and-play sessions.

## Limits of this sim
- The bots don't hold cards on purpose against a specific threat, don't use Frag Grenades, Ditch or Heal items smartly, and don't reason about Cover when they choose where to stand. Human games will be swingier.
- One Zone route (A), one drop pattern per scenario, and 2–3 players only (no 4-player run yet).
- The final-circle cap in the script is "1/2/3 Hits" as in v0.2. No game reached round 14.
- The scripted ambushes are injected as plain damage (no Brace), to make the test harsh.
