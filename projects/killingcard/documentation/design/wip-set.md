# KillingCard: the "Wip" set (19 cards from the Card Editor), made playable and tested

*Author: Sr Game Designer Agent · 2026-11-10 · Board task kc-wip-design · Status: **design for the head's review**. No rules, UI, scene or data file was changed. The sims are four new sim-only files in `source/project-killingcard/tests/tools/` (`wip_cards.gd`, `wip_match.gd`, `wip_duel_sim.gd` and the campaign wrapper `wip_run_check.gd`), on the real engine and AI.*
*Inputs: the export `documentation/design/wip-set.json` (set "Wip", still "building" in the editor), `run-v2.md` (§15 economy), `duel-mode.md` (§2 deck rules, §5 presets, §12 decisions), `firefight-order.md` (the beat order, §2.5 table = the glossary of when each keyword acts), `card-system.md` (§3.2 chassis list, §8 position cut, §9 economy), `art-traits.md`, `scripts/rules/` (`effect_resolver.gd`, `firefight_resolver.gd`, `match_state.gd`, `synergy_rules.gd`), `scripts/data/` (`card_data.gd`, `effect_data.gd`, `data_enums.gd`), the 36 cards in `data/cards/`, and the Card Editor's keyword picker (`tools/card-editor/card-editor.html`: KW_FLAGS, KW_NUM, TRIGGERS).*
*The head: "introduce them" into the game. Earlier: build a new set and "swap sets once it's ready". The set is still "building", so this doc **adds** the cards (playable, tested) and does **not** replace the current set. Q1 asks about the swap.*
*Not touched: the killstreak code (another agent is moving damage killstreaks to fight start).*

## 0. Summary in seven lines
1. **Every card has an exact rule (§1).** 15 of the 19 are playable from data today (Premium Loadout also needs an AI fix): the engine already has On Deploy, On Down, end-of-round effects, permanent +1/+1, every keyword the cards print, and the shapes of War Shout, Barrage and Premium Loadout.
2. **Four things are new (§2):** **Suppress N** (Riot Shield's Suppress 1; the Gunner becomes Suppress 2), **Agile** (the Runner: a free move order to an adjacent column, like the Operator's Rotate), **+1 Supply next round** (the Hacker, through the Supply Cache's slot) and **Beam** (the Laser Gunner hits every unit in front of it, friends included). One AI gap: it never plays a "buff your unit" tactic (Premium Loadout).
3. **Balance (§4, ~19,000 Duel games and 4,000 campaign runs on the real engine and AI):** 16 of the 19 sit inside the shipped cards' range at their cost. **None is over the curve.** The head's numbers stay for all of them except three under-curve suggestions: **Private I 1/1 → 2/1, Private II 2/2 → 2/3, Kamikaze cost 3 → 2.**
4. **The Privates as the starter (§3.1, §4.3):** with the exported numbers the first fight of a run drops to 51% (competent) and **25% (casual)**; with the two tweaks the ladder plays like today's starter (41.0% run win, first fight 92%).
5. **The other 15 cards join the current pool (§3):** campaign rewards (one copy each) and the Duel Basic pool, one trait each (Vanguard 3, Spec Ops 4, Heavy 3, Undead 2), no Elites, presets unchanged. They cost the campaign 3 points of run win; the implementation re-measures that (§4.4).
6. **No set swap yet:** as one 20-card deck the Wip set wins 13–21% against the Duel presets (§4.5). It's a pool of good single cards, not a finished set.
7. **Work (§5):** 7 engine items, 19 card files plus the reward pool and the editor's keyword list, banner arts left to the technical artist, and the tests. Four questions for the head (§6).

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

## 3. Where the cards fit

### 3.1 The starter: the Private ladder
Private I–IV are plain units with no keyword or effect, at FP = AR = cost. That is a Standard Issue ladder, the same job as today's starter (Grunt 2/2 for 1, Trooper 2/3 for 2, Sergeant 3/3 for 3, Armored Trooper 2/5 for 4, card-system §9). **Recommendation: the Privates become the Standard Issue starter, under their names, with two number tweaks (§4.3): Private I 2/1 and Private II 2/3.** The starter list keeps today's shape: **Private I ×3, Private II ×3, Private III ×2, Private IV ×1, Ammo Resupply ×1.** Private III is today's Sergeant; Private IV (4/4) replaces the Armored Trooper (2/5).
- They keep every Standard Issue rule: not collectible, never offered, never in the Duel pool, no trait, sent home by Muster out / Drill.
- With the head's numbers as exported (1/1, 2/2), the first fight drops from 96% to 51% for a competent player and from 82% to **25% for a casual one** (§4.3). That breaks the first-run promise (run-v2 §2.5), so the tweak is the one change this doc pushes for.

### 3.2 Campaign: rewards
The other 15 cards (12 units, 3 tactics) join `run_config.reward_pool`, **one copy each**, on the existing reward rungs (units → tactics → Fields → Elites): the units on rung 1, the three tactics on rung 2. None is an Elite ★.
- Shop and event card offers draw from the same pool, so nothing else changes.
- The pool grows from 35 to 50 entries, so each offer is a little less likely to be a card you already build around. §4.4 measures it.

### 3.3 Traits (one per card; the art-traits rule: home trait + one alternate art later)
| Card | Trait | Why | Weapon class (art tag; Sniper Perch reads it) |
|---|---|---|---|
| Private I–IV | none | Standard Issue is plain by rule | none |
| Scout | Vanguard | front-line blocker, the Protector's job | SMG |
| Medic | Undead | the Combat Medic's trait; the Undead heal plan | AR |
| Sharpshooter | Spec Ops | marksman family (First Shot is Vanguard's word, but the art is a sniper) | Sniper |
| Flag Bearer | Vanguard | "take the column": a column buff on arrival | AR |
| Hacker | Spec Ops | intel / tech, the Recon Specialist's family | SMG |
| Kamikaze | Heavy | explosives, the Demolitions Expert's family | none (not LMG: LMG gives Pierce) |
| Runner | Spec Ops | mobility, the Flanker's family | SMG |
| Sniper | Spec Ops | Pick sniper, with the Marksman and the Ace | Sniper (Sniper Perch: +1 FP) |
| Juggernaut | Heavy | armour + Pierce, the Gunner's family | LMG (its Pierce is printed anyway) |
| Riot Shield | Vanguard | Cover + front pinning, the Protector's family | none |
| Fast Learner | Undead | "comes back stronger", Undead's growth theme | AR |
| Laser Gunner | Heavy | the big gun | none (**not** LMG: that would add Pierce to a Beam) |
| War Shout, Barrage, Premium Loadout | — | tactics never have a trait | — |

Spread: Vanguard 3, Spec Ops 4, Heavy 3, Undead 2. The alternate art traits (the second option per unit) are left to the art-traits pass when the arts exist.

### 3.4 Duel
The 12 Wip units and 3 tactics join the **Basic pool** (duel-mode §7: non-Elite units and tactics are open from the start; `DuelRules.pool_eligible` picks them up from `data/cards/` with no list to edit). The Privates stay out (Standard Issue). **The four presets don't change.** A preset swap is a later tuning task once the head has played them.

### 3.5 Rarity
The game has one gameplay rarity, Elite ★ (card-system §2.7). **None of the 19 is an Elite**: the strongest Wip unit measures below the Gunner (§4.2). The editor's "copies" (Private I ×2, the rest ×1) become: the starter count for the Privates (§3.1), one reward-pool entry for the others, and the usual 2 copies per pick in Duel.

### 3.6 Names that sit close to existing cards
"Medic" (Patch 1, 2/3) beside "Combat Medic" (Patch 2, 1/3), and "Sniper" beside the "Sniper Perch" Field. Both are fine (the Perch's "your Sniper units" now has a card literally called Sniper), but the inspector should show both medics' Patch numbers big enough to tell them apart.

## 4. Balance (sims on the real engine and AI)

### 4.1 The tools
| File (all in `tests/tools/`, sim-only) | What it does |
|---|---|
| `wip_cards.gd` | The 19 cards in memory as `CardData` (real effects where the engine has them), cached at `res://data/cards/<id>.tres` so the existing harnesses load them by id. `WIP_SET="card.prop=value;..."` for what-ifs; `WIP_TRAITS=1` prints §3.3's traits. |
| `wip_match.gd` | A sim-only `MatchState` playing Suppress N, Agile (greedy: an Agile unit in a column with no enemy, if a friend stays to hold it, moves to the adjacent column with the most enemies), the Hacker's Supply and the Beam (fired at the start of its column). Premium Loadout uses a stand-in the AI can value (+1 FP to a chosen column this round), resolved as +1/+1 for good on the front unit there. |
| `wip_duel_sim.gd` | `duel_sim.gd` on `wip_match.gd`. `WIP_EXPS=swap`: each card replaces the closest-cost pick of the same kind (non-Elite) in each of the 4 presets and wears that pick's trait; the changed preset plays the other 3, 40 games per pair, seats alternate, same seeds as the unchanged baseline. `WIP_REF=` sends shipped cards through the same test as yardsticks. `WIP_EXPS=deck`: the export's 20-card list as one deck vs each preset. |
| `wip_run_check.gd` | `run_v2_check.gd` with the Wip ids loadable (`starter=private_1*3,...`), and `WIP_POOL=1` to add one copy of each engine-ready non-Private card to the reward pool (10 cards: Hacker, Runner, Riot Shield and Laser Gunner need `wip_match.gd`, and Premium Loadout's sim card is a stand-in, so those 5 stay out of this test). |

Run: `WIP_EXPS=swap godot --headless --path . -s res://tests/tools/wip_duel_sim.gd -- exps=none n=40` and `godot --headless --path . -s res://tests/tools/wip_run_check.gd -- exps=runs runs=400 starter=...`.

**What the sims don't cover:** the AI doesn't know Agile, Beam, Suppress N or the Hacker's Supply when it plans (its look-ahead is a plain `MatchState`), so it places the Laser Gunner without care (74 friendly downs in ~480 games) and never orders a Runner move (the sim's greedy mover does). Read those four as "played by a careless player". Repeat runs move a number by about ±2 points (the AI has some unseeded randomness); one swap row has a standard error of about ±2.5 points.

### 4.2 Card value: the swap test (Duel, n = 480 games per card)
Baseline preset win rates: Spearhead 42%, Overwatch 55%, Iron Wall 54%, Hollow Ranks 45%. **Δ** = change of the changed preset's win rate, averaged over the 4 presets. Every card at a cost replaces the same picks, so compare a row with the **yardsticks of the same cost** (shipped cards through the same test), not with zero. Cost 4–5 cards always replace Iron Wall's Gunner (−12 to −19 there), which pulls every 4–5 row down by about 3 points.

| Cost | Replaces (Spearhead / Overwatch / Iron Wall / Hollow Ranks) | Yardsticks (shipped) | Wip cards: Δ (AI plays per game) |
|---|---|---|---|
| 1 | Rifleman ×4 | Grunt 2/2 **−6.4** | **Private I 1/1 −11.9** (1.07) · Scout −2.6 (1.09) · *2/1: −6.2 · 1/2: −12.4* |
| 2 | Point Man / Recon / Rifleman / Brawler | Brawler **+6.9** · Trooper 2/3 **−9.6** | Medic −0.5 (1.09) · Hacker −5.5 (0.96) · Private II 2/2 −11.5 (0.80) · *2/3: −9.6* |
| 3 | Breacher / Marksman / Breacher / Flanker | Flanker **−8.5** · Sergeant 3/3 **−8.6** | Runner −2.3 (0.90; adjacent-only −2.5) · Sharpshooter −4.8 (1.00) · Private III −8.5 (0.62) · **Kamikaze −12.1** (0.72) · *Kamikaze 2/2: −8.1 · Kamikaze cost 2: −6.7* |
| 4 | Shieldman / Marksman / Gunner / Shieldman | Gunner **+5.0** · Protector **−4.6** · Armored Trooper 2/5 **−5.6** | Flag Bearer −2.7 (0.50) · Private IV −3.0 (0.49) · Riot Shield −4.4 (0.51) · Sniper −5.4 (0.62) |
| 5 | (same as 4) | (same) | Juggernaut **+1.6** (0.61) · Fast Learner −1.7 (0.54) · Laser Gunner −4.5 (0.41) |
| Tactics | Hold the Line / Ammo Resupply / Suppressing Fire or Breach and Clear / Breach and Clear | — | Barrage +0.5 (0.27) · Premium Loadout +0.5 (0.59) · War Shout −1.8 (0.51) |

Laser Gunner's Beam over all its games: 923 damage to enemies, 395 to friends, 74 friendly downs. The Hacker gave about 1 Supply per game it was in.

**Read-out:**
- **On the curve (keep the head's numbers):** Scout, Medic, Hacker, Runner, Sharpshooter, Flag Bearer, Riot Shield, Sniper, Juggernaut, Fast Learner, Laser Gunner, War Shout, Barrage, Premium Loadout, Private III, Private IV. Every one of them lands between the shipped yardsticks of its cost. Nothing is over the curve: the best Wip unit (Juggernaut) is below the Gunner, and the 5/2 Sniper with Pick (above the Ace's 4/3 on paper) dies to anything, so it measures like the Protector.
- **Under the curve:**
  - **Kamikaze (1/1, cost 3): the weakest card in the set**, 3.5 points under the 3-cost yardsticks. A 1/1 dies in the first beat, and its On Down 1 damage is stopped by any Cover. Suggest **cost 2** (Δ −6.7, inside the 2-cost band); 2/2 at cost 3 (−8.1) also works.
  - **Private I (1/1)**: 5.5 points under the Grunt. It's the Firepower that matters: 1/2 doesn't help (−12.4), **2/1 does (−6.2, equal to the Grunt)**.
  - **Private II (2/2)**: 2 points under the Trooper (within noise in Duel, but it compounds in the starter, §4.3). Suggest **2/3** (= the Trooper).
- **Watch (no change now):** the Laser Gunner is on the curve even when the AI shoots its own line; a player who keeps it at the front of its column gets a 2-FP shot at every enemy there each round, which is Breach and Clear every round. If playtests show "Laser at the front" as the only way to play it, the lever is FP 2 → 1 against enemies behind the first, not its cost. War Shout's "all columns" reading measures on the curve (−1.8), so the simplest reading stays.

### 4.3 The Private ladder as the campaign starter (run_v2_check, 400 runs per proxy, Operators and bosses rotating, Terrain on)
| Starter | Competent: run win | Competent: F1 | Casual: run win | Casual: F1 |
|---|---|---|---|---|
| Today (Grunt ×3, Trooper ×3, Sergeant ×2, Armored ×1, Ammo Resupply) | **39.0%** | 95.8% | **30.5%** | 82.2% |
| Privates, head's numbers (I ×3, II ×3, III ×2, IV ×1, Ammo Resupply) | 37.5% | **51.2%** | 23.5% | **24.8%** |
| Privates with **I 2/1, II 2/3** (recommended) | **41.0%** | 92.2% | **28.0%** | 78.5% |

The run win barely moves with the head's numbers because the starter is sent home within a few fights (8–9 Standard Issue cards sent home per run). But the **first fight** goes from a near-certain win to a coin flip, and to 1 in 4 for a casual player: the first match of the first run would be lost by most new players. With the two tweaks the ladder plays like today's starter (inside run-v2's 38–43% competent target, F1 back above 90%). Private IV 4/4 instead of the Armored Trooper's 2/5 is the small gain.

### 4.4 The cards in the reward pool (run_v2_check, 400 runs per proxy, today's starter)
| Reward pool | Competent run win | Casual run win |
|---|---|---|
| Today (35 entries) | 39.0% | 30.5% |
| + 10 engine-ready Wip cards, **no traits** | 34.8% | 23.2% |
| + 10 engine-ready Wip cards, **§3.3 traits** | 36.2% | 25.5% |

- Adding the cards costs the run **3 points (competent) and 5 (casual)** with traits, 4 and 7 without. Two causes, and the sim can't split them: most Wip units sit in the lower half of their cost band (§4.2), and a bigger pool makes a trait set harder to complete. The F1–F3 ramp is untouched; the loss is at F4 and the boss.
- 36.2% is just under run-v2's competent target (38–43%). **Not a reason to hold the cards back**, but the implementation task should re-measure on the real engine (with Hacker, Runner, Riot Shield, Laser Gunner and Premium Loadout in, and the AI knowing them) and, if it stays under 38%, use the existing run levers (offer weighting toward the trait you hold, the F4 / boss Armor bonus) rather than the card numbers.

### 4.5 The whole set as one deck (the "swap" question)
The export's 20-card list (Private I ×2 and one of each other card), played as a Duel deck with Kestrel and no Doctrine, against the four presets (40 games each):
| Wip deck | vs Spearhead | vs Overwatch | vs Iron Wall | vs Hollow Ranks | Overall |
|---|---|---|---|---|---|
| no traits (as exported) | 20.0% | 5.0% | 17.5% | 10.0% | **13.1%** |
| §3.3 traits | 15.0% | 7.5% | 22.5% | 12.5% | **14.4%** |
| §3.3 traits + the tweaks (Private I 2/1, Private II 2/3, Kamikaze cost 2) | 27.5% | 17.5% | 22.5% | 15.0% | **20.6%** |

As one deck the set loses 4 games in 5 to the presets, even with traits and the tweaks. That isn't a flaw of the single cards (they are on the curve, §4.2); it's the list: 6 Privates (plain, a starter's job), single copies, a 4–5-cost top end of 7 cards, and no Field. **A whole-set swap would need its own deck-building pass** (presets, squads, the reward pool), which is why Q1 recommends joining the pool now and swapping later.


## 5. Implementation list (Mechanics Developer, after the head's answers)
Order: data-only cards first (they work today), then the four mechanics. Don't touch the killstreak timing (another task owns it).

### 5.1 Engine (`scripts/rules/`, `scripts/data/`)
| # | Item | Where | Exact change |
|---|---|---|---|
| E1 | **Suppress N** | `card_data.gd`, `loadout_item.gd`, `rules_unit.gd`, `match_state.gd` (create_unit, _build_operator), `firefight_resolver.gd` `_suppress`, `ai/ai_view.gd` + the AI estimator | Add `@export_range(1, 5) var suppress_amount: int = 2` next to `suppress` (old saves and the Gunner keep −2). `RulesUnit.suppress_amount` (Operator: the largest of its parts). `_suppress` uses `u.suppress_amount` instead of `SUPPRESS_AMOUNT` (keep the const as the default). `keyword_names()` → "Suppress %d". Gunner text "Suppress 2. Pierce". The AI view carries the amount. |
| E2 | **Agile** | `card_data.gd` (`agile: bool`), `rules_unit.gd`, `match_state.gd`, `rules_intent.gd`, `ai/ai_planner.gd` | A new play kind `&"agile_move"` (intent `RulesIntent.move_unit(uid, zone)`), modelled on `rotate`: legal if the unit is on the board, has Agile, has no move order this round, and the zone is adjacent with room (projected); Supply 0; undoable in Deploy. Resolves in the Reveal arrival step like `rotate` (fizzles if full; `UNIT_MOVED`; `trigger_traps`). Intel: shown like a Rotate. AI: offer the move as a candidate, valued with the existing MOVE_UNIT code (no First Shot). |
| E3 | **GAIN_SUPPLY_NEXT_ROUND** | `data_enums.gd` (append to `EffectKind`, never reorder), `effect_resolver.gd`, `effect_data.gd` (`_NEEDS_POSITIVE_AMOUNT`), AI | `_apply`: `state.terrain_supply_next[side] += amount` and `EFFECT_APPLIED` (consider renaming the slot `supply_next`). The Briefing's `SUPPLY_GAINED.extra` already reports it. AI: a flat value (+0.5 per Supply) so it plays the Hacker as more than a 1/1. |
| E4 | **Beam** | `card_data.gd` (`beam: bool`), `rules_unit.gd`, `firefight_resolver.gd` `_beat`, `rules_event.gd`, AI estimator | In `_beat`, a Beam shooter's hits are: each living friendly unit with a lower index in its own line, then every living enemy unit in the column, each `firepower_of(u)` (Cover applied by `deal_damage`). No Pick / Flank / Pierce on a Beam. Event `BEAM_FIRED {side, shooter_uid, zone, beat, hits: [{uid, side, damage}]}` (plus the usual `DAMAGE_DEALT`). Friendly downs: no change needed (no credit when the killer's side is the victim's). |
| E5 | **AI: chosen-friendly buffs** | `ai/ai_planner.gd` `_effect_candidates`, `_apply_effect` | A candidate per living friendly unit for a tactic whose effects target CHOSEN_FRIENDLY with MODIFY_FIREPOWER / MODIFY_ARMOR / GRANT_COVER; add MODIFY_ARMOR to `_apply_effect`'s CHOSEN_FRIENDLY branch. Without it the AI never plays Premium Loadout. |
| E6 | **Operator and permanent Armor buffs** | `match_state.gd` `_record_elimination` (Operator branch) | A permanent MODIFY_ARMOR raises `base_max_armor`, which the Operator keeps through respawns (Flag Bearer can hit it). Reset the Operator's `base_max_armor` to its kit value when it goes down (as `mods.clear()` already does for FP). |
| E7 | Keyword names | `card_data.gd` `keyword_names()`, `card_info.gd` | "Agile", "Beam", "Suppress N". The editor says "Arrives Front", the game says "Front line": pick one ("Arrives Front" reads better on a card; one-line change). |

### 5.2 Data (`data/`)
| Item | Change |
|---|---|
| `data/cards/` (19 new `.tres`) | ids `private_1`, `private_2`, `private_3`, `private_4`, `scout`, `medic`, `sharpshooter`, `flag_bearer`, `hacker`, `kamikaze`, `runner`, `sniper`, `juggernaut`, `riot_shield`, `fast_learner`, `laser_gunner`, `war_shout`, `barrage`, `premium_loadout`. Stats, keywords and effects exactly as §1 (`tests/tools/wip_cards.gd` `build()` is the reference, except Premium Loadout's real effects: ON_PLAY · MODIFY_FIREPOWER +1 and MODIFY_ARMOR +1 · CHOSEN_FRIENDLY · ANY · permanent). Privates: `standard_issue = true`, `collectible = false`, no trait. Others: `card_trait` from §3.3 (`trait_options` = [home] until the alternate arts exist), `weapon_class` from §3.3. Text as §1's "Precise rule" column (≤ 100 characters). Number tweaks only if the head says yes (Q2, Q3). |
| `run_config.tres` | `reward_pool` + the 15 non-Private cards, one each. If Q2 = (a): `starter_deck` = Private I ×3, Private II ×3, Private III ×2, Private IV ×1, Ammo Resupply ×1; the `si_*` cards move to `legacy_cards` (old saves still load). |
| Banner arts | Each new collectible chassis needs one `is_default` art per trait option (CardDB's check), and the Privates need a default art each: **art ids and arts are the technical artist's** (`data/banners/`). Until then the card needs a placeholder default art or the CardDB check fails. The art's trait tag = §3.3's trait (the "trait for art lookup"). |
| Card Editor | Move Suppress from `KW_FLAGS` to `KW_NUM` ("Suppress N: at the start of the firefight, the enemy front unit here gets −N FP"), add "Agile" and "Beam" to `KW_FLAGS` with §2's one-line rules, add "gain {n} Supply next round" to `EFFECTS`. |
| `tests/tools/gen_content.gd` | If the card `.tres` are generated there, add the 19 there instead of by hand. |

### 5.3 Tests (`tests/`)
- **Rules:** Suppress 1 vs Suppress 2 and stacking (Riot Shield + Gunner = −3); Suppress pins the unit, not the slot. Agile: adjacent only, once per round, undo, fizzle when full, Tripwire triggers, red-dot intel. GAIN_SUPPLY_NEXT_ROUND: next round only, two Hackers stack, can exceed the cap, a Hacker that doesn't arrive (column full) gives nothing. Beam: friendlies ahead hit and behind not, a front Beam hits only enemies, Cover per target, no streak for friendly downs, First Shot partner order unchanged. Flag Bearer: itself and the units already there, not later arrivals; the Operator's Armor resets on down (E6). Kamikaze: 1 to each enemy in its column at the moment it goes down (Cover applies). Fast Learner: +1/+1 every Score step (incl. the arrival round), heals 1. War Shout: every column, includes this Reveal's arrivals, ends with the round. Barrage: only front units, all columns. Premium Loadout: permanent; the AI plays it (E5).
- **Data:** the 19 cards validate (`CardData.validate`), text ≤ 100 characters, Privates are Standard Issue, every collectible chassis has a default art, the reward pool has no token or Standard Issue card.
- **Sims after the build:** re-run `wip_duel_sim.gd` (swap) and `wip_run_check.gd` / `run_v2_check.gd` on the real engine; the numbers should match §4 within ±3 points, and the AI's use of Agile and Beam is the new part to check.


## 6. Questions for the head (recommended option first)
1. **The "swap": what do the Wip cards become now?** (a) **Join the current pool**: the 15 non-Private cards go into campaign rewards and the Duel Basic pool, next to today's cards; the set stays "building" and can be swapped later (recommended: every card is on the curve, §4.2). (b) Make Wip the whole card set now (not recommended: as one deck it wins 14–21% against the presets, and Duel presets and squads would all need rebuilding). (c) Keep them editor-only until the set is finished.
2. **The Private ladder: the new starter?** (a) **Yes, as the Standard Issue starter, with Private I 2/1 and Private II 2/3** (plays like today: competent 41.0%, first fight 92%; casual first fight 79%) (recommended). (b) Yes, with the exported 1/1 and 2/2 (first fight 51% competent, **25% casual**). (c) No, keep Grunt / Trooper / Sergeant / Armored; the Privates wait for the swap.
3. **Kamikaze (1/1 for 3, the one card clearly under the curve):** (a) **cost 2** (recommended; measured into its band). (b) 2/2 at cost 3. (c) Keep it as is.
4. **Traits:** (a) **one home trait per card as in §3.3** (recommended: without traits the new cards dilute the reward pool, §4.4). (b) Leave them neutral for now.

