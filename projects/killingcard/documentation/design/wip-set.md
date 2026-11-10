# KillingCard: the "Wip" set (19 cards from the Card Editor), made playable and tested

*Author: Sr Game Designer Agent · 2026-11-10 · Board task kc-wip-design · Status: **design for the head's review**. No rules, UI, scene or data file was changed. The sims are three new sim-only files in `source/project-killingcard/tests/tools/` (`wip_cards.gd`, `wip_match.gd`, `wip_duel_sim.gd`, plus the campaign wrapper `wip_run_check.gd`), on the real engine and AI.*
*Inputs: the export `documentation/design/wip-set.json` (set "Wip", still "building" in the editor), `run-v2.md` (§15 economy), `duel-mode.md` (§2 deck rules, §5 presets, §12 decisions), `firefight-order.md` (the beat order, §2.5 table = the glossary of when each keyword acts), `card-system.md` (§3.2 chassis list, §8 position cut, §9 economy), `art-traits.md`, `scripts/rules/` (`effect_resolver.gd`, `firefight_resolver.gd`, `match_state.gd`, `synergy_rules.gd`), `scripts/data/` (`card_data.gd`, `effect_data.gd`, `data_enums.gd`), the 36 cards in `data/cards/`, and the Card Editor's keyword picker (`tools/card-editor/card-editor.html`: KW_FLAGS, KW_NUM, TRIGGERS).*
*The head: "introduce them" into the game. Earlier: build a new set and "swap sets once it's ready". The set is still "building", so this doc **adds** the cards (playable, tested) and does **not** replace the current set. Q1 asks about the swap.*
*Not touched: the killstreak code (another agent is moving damage killstreaks to fight start).*

@@SUMMARY@@

---

## 1. Rules, card by card

Engine column: **ready** = the shipped engine plays it from data alone (existing keywords, triggers and effect kinds); **NEW** = needs engine work (§2). FP = Firepower, AR = Armor. "Here" = this column. Rules text is written the way the card would print it (≤ 100 characters, one line).

| # | Card | Type | Cost | FP/AR | Head's text / keywords | Precise rule (card text) | Engine |
|---|---|---|---|---|---|---|---|
| 1 | Private I (×2) | Unit | 1 | 1/1 | — | — (plain) | ready |
| 2 | Private II | Unit | 2 | 2/2 | — | — | ready |
| 3 | Private III | Unit | 3 | 3/3 | — | — | ready |
| 4 | Private IV | Unit | 4 | 4/4 | — | — | ready |
| 5 | Scout | Unit | 1 | 0/3 | Arrives Front | **Arrives Front.** (Slides to the front of its column on arrival, like the Protector.) | ready (`arrives_front`) |
| 6 | Medic | Unit | 2 | 2/3 | Patch 1 | **Patch 1.** (After the firefight here, restores 1 Armor to your most damaged other unit here.) | ready (`patch = 1`) |
| 7 | Sharpshooter | Unit | 3 | 3/2 | First Shot | **First Shot.** | ready |
| 8 | Flag Bearer | Unit | 4 | 2/2 | "On Deploy: Give +1/+1 to everyone here." | **On Deploy: your units here get +1/+1 (itself included).** | ready (ON_DEPLOY · MODIFY_FIREPOWER +1 and MODIFY_ARMOR +1 · ALL_FRIENDLIES · THIS_ZONE · permanent) |
| 9 | Hacker | Unit | 2 | 1/1 | "On Deploy: Gain one temporary Supply next turn." | **On Deploy: +1 Supply next round.** | **NEW** effect kind (§2.3) |
| 10 | Kamikaze | Unit | 3 | 1/1 | "On Down: Deal 1 damage to every enemy here" | **On Down: 1 damage to each enemy unit here.** | ready (ON_DOWN · DAMAGE 1 · ALL_ENEMIES · THIS_ZONE) |
| 11 | Runner | Unit | 3 | 2/4 | "Agile: Can move to a different location each round" | **Agile.** (Once per round, in Deploy, you may order it to an adjacent column; it moves at Reveal, to the back of that line.) | **NEW** keyword (§2.2) |
| 12 | Sniper | Unit | 4 | 5/2 | Pick | **Pick.** | ready |
| 13 | Juggernaut | Unit | 5 | 4/5 | Pierce | **Pierce.** | ready |
| 14 | Riot Shield | Unit | 4 | 1/3 | Suppress, Cover 1; "Suppress should allow for a number … Here it's Suppress 1." | **Suppress 1. Cover 1.** | **NEW**: Suppress takes a number (§2.1) |
| 15 | Fast Learner | Unit | 5 | 3/4 | "At end of round: Gain +1/+1" | **At end of round: this unit gets +1/+1.** | ready (END_OF_ROUND · MODIFY_FIREPOWER +1 and MODIFY_ARMOR +1 · SELF · permanent) |
| 16 | Laser Gunner | Unit | 5 | 2/2 | "Does damage to everyone in front of him here, including ally and enemy" | **Beam.** (Its shot hits every unit in front of it here: your units ahead of it and every enemy here.) | **NEW** keyword (§2.4) |
| 17 | War Shout | Tactic | 2 | — | "Give +2 attack to everyone this turn." | **Your units get +2 FP this round.** | ready (ON_PLAY · MODIFY_FIREPOWER +2 · ALL_FRIENDLIES · ALL_ZONES · 1 round) |
| 18 | Barrage | Tactic | 3 | — | "Deal 1 damage to every opponent Unit on the frontlines." | **1 damage to each enemy frontline unit.** | ready (ON_PLAY · DAMAGE 1 · ENEMY_POINT_MAN · ALL_ZONES) |
| 19 | Premium Loadout | Tactic | 1 | — | "Give +1/+1 to target unit." | **A unit of yours gets +1/+1.** | ready in the rules (ON_PLAY · CHOSEN_FRIENDLY · permanent); **the AI can't play it yet** (§2.6) |

**Glossary words kept as they are:** "+1/+1" = +1 FP and +1 Armor (the Armor point raises the maximum and the current Armor, so it also heals 1). "This round" = until the Score step ends (the engine's `duration_rounds = 1`). "Turn" in the head's text = round (the game has no other turn). "Everyone" = your units (the Operator counts while it's on the board), never the enemy's, unless the card says enemy. "Here" = this column. Damage from cards applies Cover, as Breach and Clear and Sabotage do.

### 1.1 Assumptions (the simplest reading where the text is open)
| # | Card | Text | Reading chosen | Other reading |
|---|---|---|---|---|
| A1 | Flag Bearer | "everyone here" | your units in its column **when it arrives, itself included**; units that arrive later don't get it; it stays for good | "other units" (then it is a 2/2 for 4: weak) |
| A2 | Hacker | "temporary Supply next turn" | +1 Supply in the next round only; unspent Supply is lost at the end of a round anyway, so "temporary" needs no extra rule. Two Hackers stack. It can take you over the 7 cap for that round (like the Supply Cache Terrain) | a Supply that persists |
| A3 | Kamikaze | "every enemy here" | every enemy unit in the column where it went down, at the moment it goes down (in the beat, like the Demolitions Expert) | — |
| A4 | Runner | "a different location each round" | an **adjacent** column, once per round, as an order in Deploy (exactly the Operator's Rotate, which players already know). A→C takes two rounds | any column (A↔C in one move): the sim's greedy mover was tried both ways, see §4.2 |
| A5 | Riot Shield | "Suppress 1" | Suppress N: the enemy front unit here gets −N FP this round (the shipped Suppress is −2, so the Gunner becomes "Suppress 2", unchanged) | — |
| A6 | Fast Learner | "At end of round" | the Score step, with the other END_OF_ROUND effects; it grows every round it's on the board, the round it arrives included | from the round after it arrives |
| A7 | Laser Gunner | "everyone in front of him here, including ally and enemy" | its shot is a Beam: FP to **each** of your units ahead of it in its line and to **every** enemy unit in the column (each one's Cover applies). It fires in its own beat (front to back, as every unit). If it's your front unit, it hits only enemies. Friendly downs give nobody a streak | "the whole column, both sides" (it would hit units behind it too) |
| A8 | War Shout | "everyone this turn" | all your units in **every** column, this round, including units that arrive this Reveal (tactics resolve after arrivals) | your units in a chosen column (the shape every other buff tactic has; see §4 for why this may be the better number) |
| A9 | Barrage | "every opponent Unit on the frontlines" | each enemy front unit (row 1), in all three columns | — |
| A10 | Premium Loadout | "target unit" | one of **your** units on the board (chosen in Deploy), for good | any unit (it would never be played on an enemy) |

## 2. New mechanics (exact rules)

What the head's list asked about, and what the engine already has:
| Mechanic | Already in the engine? | What's needed |
|---|---|---|
| On Deploy | **Yes** (`Trigger.ON_DEPLOY`; the Recon Specialist uses it) | nothing for Flag Bearer; the Hacker needs a new effect kind (§2.3) |
| On Down | **Yes** (`Trigger.ON_DOWN`; the Demolitions Expert uses it) | nothing (Kamikaze is data only) |
| End-of-round growth | **Yes** (`Trigger.END_OF_ROUND`; Fields use it) + permanent MODIFY_FIREPOWER / MODIFY_ARMOR | nothing for the rules; a "grew" pop in the Score step for clarity (§5) |
| Suppress with a number | No (fixed −2) | §2.1 |
| Agile | No | §2.2 |
| Temporary Supply next turn | No (only the Supply Cache Terrain does it) | §2.3 |
| Laser Gunner's friendly fire | No | §2.4 |
| War Shout, Barrage | **Yes** (existing kinds and targets) | data only |
| Premium Loadout | Rules **yes**; the AI has no CHOSEN_FRIENDLY buff candidate | §2.6 |

### 2.1 Suppress N
**Suppress N:** *at the start of the firefight in its column, the enemy front unit here gets −N FP this round.* Everything else as today's Suppress (it pins the unit, not the slot; several Suppress units stack; firefight-order §2.5).
- The Gunner and every shipped Suppress source become **Suppress 2** (no balance change). The Riot Shield is **Suppress 1**.
- Card face and editor: a numbered keyword like Cover N and Patch N ("Suppress 2").

### 2.2 Agile
**Agile:** *once per round, in Deploy, you may order this unit to move to an adjacent column. It moves at Reveal, after arrivals, and joins the back of that line.*
- It's an order with no Supply cost, made like the Operator's Rotate (drag the unit to the next column, or the inspector's "Move" button; touch: long press → Move). The order shows as a ghost arrow and can be undone in Deploy.
- If the destination is full at Reveal, the move fizzles and the unit stays (the Flank Route rule).
- Tripwire Charge in the destination triggers on it (it "arrives"), as with Flank Route.
- The enemy sees the move as a red dot leaving and arriving (intel as for a Rotate).

### 2.3 Supply next round (the Hacker)
New effect kind **GAIN_SUPPLY_NEXT_ROUND** (amount N): *the owner gets +N Supply in the next round only.* It adds to the same per-side slot the Supply Cache Terrain uses (`MatchState.terrain_supply_next`), so the Briefing line already shows it as "extra". It may exceed the round's cap (cap 7) for that round. The Hacker's text: "On Deploy: +1 Supply next round."

### 2.4 Beam (the Laser Gunner)
**Beam:** *instead of a normal shot, this unit's shot hits every unit in front of it in its column: each of your units ahead of it in your line, and every enemy unit in the column. Each hit is this unit's FP, minus that unit's Cover.*
- It fires in its own beat, like every unit (firefight-order §2.2), so the units ahead of it have already traded.
- A friendly unit it downs gives **nobody** elimination credit or streak (the engine already does this: the killer's side equals the victim's).
- First Shot, Pick, Flank and Pierce don't change a Beam (it already reaches everyone). Suppress and FP buffs change its FP.
- Board: the beam draws as one line through the column, friendly hits flashing amber. The card's inspector says "Hits your units in front of it too."

### 2.5 End-of-round growth and On Deploy buffs: what to show
No new rule, but two clarity needs (studio UX rule: "the player must always be able to tell what just happened"):
- Fast Learner: in the Score step, a "+1/+1" pop on the card and an FP/AR plate that shows its current numbers in a different shade from the printed ones (the existing ▲ marker on a modified stat).
- Flag Bearer: an arrival pulse along its column and "+1/+1" on each unit it hit; the killfeed line "Flag Bearer: +1/+1 to 3 units in B".

### 2.6 Premium Loadout and the AI
The rules play CHOSEN_FRIENDLY buffs already (`MatchState` checks the target, `EffectResolver` applies MODIFY_FIREPOWER / MODIFY_ARMOR to it). The AI's candidate list (`AiPlanner._effect_candidates`) offers chosen *enemy* targets and chosen friendly *moves*, but no chosen friendly buff, so an AI would never play Premium Loadout. It needs one more candidate branch: each of its living units, valued with the existing `_apply_effect` CHOSEN_FRIENDLY code (which already handles MODIFY_FIREPOWER; MODIFY_ARMOR needs adding there). The sim used a stand-in the AI can value (§4.1).

@@BALANCE@@

@@IMPL@@

@@QUESTIONS@@
