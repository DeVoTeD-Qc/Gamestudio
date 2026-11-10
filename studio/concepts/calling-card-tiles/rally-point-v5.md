# Rally Point v5: The Rulebook

*Board task `cct-rally-v5` · project `cctiles` · Sr Game Designer · 2026-11-10*
*This file is the single source of truth for Rally Point's rules. It replaces the rules in [v2](rally-point-v2.md) §2, [v3](rally-point-v3.md) §2 and [v4](rally-point-v4.md) §6; those files stay as the record of how we got here. Simulator: [`tools/rally_v5.py`](tools/rally_v5.py), copied from `rally_v4.py` (unchanged). All names are original. Call of Duty is named only as the inspiration.*

**Decided by the head and built in here:** Basic first, then four layers over the first ~15 games, and ranked play uses all of them (H1). Orders fire on their own (H2). No geometric cover: a Strike can only remove a tile next to an open objective, and protection comes from cards and Armor (H3). The head's answer to "what confused you most?" was *"All of it: too many rules at once."* So every layer below adds **one idea**, and where a layer used to add several, v5 cuts them (section 3).

**TL;DR**
- **Basic is 5 lines and a whole game.** After the Field Kit bug fix, a planning AI still beats a greedy one **97%** of the time (+14 points), and a game lasts **19.6 placements**.
- **Each layer is one idea:** Cards (tiles have text), Classes (each class fills its own meter), Front Line (a tug-of-war you can win outright), Streaks (rewards for a hot run). Every layer passes the same checks in the sim (section 2): the skill gap holds (96–98%), the seats are within a few points of even, and games last 19–20 placements.
- **Six rules are cut** to keep each layer to one idea: Engineer cover, the objective owner's bonus materiel, the Front pushes on Spot and Resupply, Fortify winning back ground, and seeing the opponent's hand. The Front is shortened from 6 to 5 steps each way so it still decides about **⟨BT5⟩** of games.
- **Starter stacks: 46.4–53.6%** (inside the 45–55 target) with the v4 fixes (Bunker Command 2, Shock Line Breach +2) and two common swaps. Without the swaps, the full rules minus cover give 44.9–56.6.
- **The AI's military weights are retuned.** The new weights beat the old ones **52.7%** over 4,000 games. They still don't beat the military-blind AI (48.8%), and section 6 explains why that is expected.

---

## 1. Basic: the whole game in 5 lines

> 1. **On your turn, place one tile from your hand of 3 on empty squares:** a banner (1×4), an objective (2×2) or an insignia (1×1). An objective may also cover a closed-in gap of 1–4 squares, but then it never rallies.
> 2. **An objective rallies the moment all 8 squares around it are filled.** The board edge counts as filled.
> 3. **When it rallies, every square of a tile touching it scores 1 for that tile's owner, or 2 if the tile's colour matches the objective.** Whoever closed it scores 1 more.
> 4. **Each rally also gives you 1 Ammo for every one of your tiles touching it. At 5 Ammo you Strike:** remove an enemy tile that touches an open objective. If there is none, score 1.
> 5. **When the board is full or no one can place, the most points wins.** The second player starts with 1 point.

If nothing in your hand fits, put one tile from your hand at the bottom of your stack, draw one, and pass. "Open" means "has not rallied yet".

**Example.** Your red objective sits in a corner, so only 4 squares around it are on the board. Your red banner covers 2 of them and your opponent's blue banner 1. You put a red insignia in the last square, and the objective rallies. Your banner scores 2 × 2 = 4 (red matches red), your insignia 2, their banner 1, and you get 1 for closing: **you +7, them +1**. Your two tiles give you 2 Ammo, which takes you from 3 to 5, so you Strike. Their green banner touches the open objective in the middle of the board, so it is removed and its 4 squares are empty again.

**The tutorial (Layer 0, "Tiles")** teaches lines 1, 2, 3 and 5 first, without Ammo; line 4 arrives as Layer 1 right after. Both are complete games in the sim (section 2).

---

## 2. The layers

Each layer keeps every rule before it and adds one idea. Layers unlock by games played (Settings has a skip toggle). Casual hosts may pick any layer; **ranked uses Layer 5.** The screen shows only what the unlocked layers use.

| Layer | Name | The one new idea | Unlocks |
|---|---|---|---|
| 0 | Tiles | Place, rally, score (lines 1, 2, 3, 5) | Start (tutorial) |
| 1 | Basic | Ammo and the Strike (line 4) | After the tutorial |
| 2 | Cards | Your tiles have text, and you bring your own stack | After 3 games |
| 3 | Classes | Each class fills its own meter, and each meter has its own order | After 6 games |
| 4 | Front Line | A tug-of-war track: push it to the end and you win | After 10 games |
| 5 | Streaks | A hot run earns rewards | After 15 games |

**How to read the sim checks.** Each layer ends with a small table from `rally_v5.py` (1,000 games a row, random starter pairs, both seats). *Skill* is a planning AI against a greedy one; above 90% means a better player almost always wins. *Luck floor* is greedy against random; it should stay well above 50%. *Seats* is the first player's win rate in a mirror match, with the 1-point start and without it. *Length* is placements a game; Basic is about 20, which is 5–7 minutes.

### Layer 1: Basic

The 5 lines above.

| Skill | Luck floor | Seats (start 1 / none) | Length | Military a game |
|---|---|---|---|---|
| 96.8% (+14.1) | 72.9% | ⟨S1⟩ | 19.6 | 1.7 Strikes, 1.0 tile removed |

### Layer 2: Cards

**New idea: your tiles have text.** Each tile has a name and one keyword, printed with its reminder text. Long-press or right-click shows it.
- **Objectives** print **Command N**: when one rallies, its owner scores N (2 on a standard objective).
- **Insignia** print **"2 Ammo"**: they give 2 instead of 1 when they touch a rally. Cards that say "Rally: +1 Ammo" add 1. (Until Layer 3, any materiel a card gives is Ammo.)
- **Protection is card text:** *Bunker* (objective): "Your tiles touching this can't be Struck." *Smoke* (insignia): "Your tiles touching this can't be Struck until your next turn."
- **You bring your own 12-tile stack:** 6–7 banners, 3–4 objectives, up to 2 insignia; at most 2 classes (colours); at most 2 copies of a tile, 1 of a legendary. Four starter stacks come free.
- **One end rule comes with it:** an objective that never rallied scores its touching squares at 1 each when the game ends. Some cards change this, so it arrives with the cards (section 3 says why it stays).

**Example.** Point Man (Assault banner, *Breach +3: if this closes a rally, +3*) fills the last square beside your Assault Post (Command 2). Point Man's 2 squares score 4 (matched), closing +1, Breach +3, Command +2: **10 points from one tile.**

| Skill | Luck floor | Seats (start 1 / none) | Length | Military a game |
|---|---|---|---|---|
| 97.8% (+18.8) | 64.0% | ⟨S2⟩ | 20.3 | 2.9 Strikes, 1.6 tiles removed |

### Layer 3: Classes

**New idea: each class fills its own meter.** The one Ammo meter becomes four, one per class. A tile touching a rally gives 1 of its class's materiel (an insignia 2). A meter that reaches **3** fires its order at the end of your turn, by itself, in this order:

| Class | Meter | Order at 3 |
|---|---|---|
| Engineer ▲ | Works | **Fortify:** +2 Armor (up to 4). Each Armor scores 1 at the end. |
| Recon ● | Intel | **Spot:** +1 Charge on every open objective you touch (the closer scores +1 per Charge), and your next Strike ignores protection. |
| Assault ◆ | Ammo | **Strike:** as in Basic. |
| Support ✚ | Supply | **Resupply:** draw 1 tile and score 1. |

The Strike now costs 3, not 5, because only Assault tiles fill the Ammo meter.

**Example.** A Recon objective rallies. Your Assault banner touches it (1 Ammo), and so do your Recon banner (1 Intel) and your Flare insignia (2 Intel). Intel goes from 0 to 3, so at the end of your turn **Spot** fires: the two open objectives your tiles touch get a Charge each, and your next Strike can hit the tile your opponent hid next to their Bunker.

| Skill | Luck floor | Seats (start 1 / none) | Length | Military a game |
|---|---|---|---|---|
| ⟨K3⟩ | ⟨G3⟩ | ⟨S3⟩ | ⟨P3⟩ | ⟨M3⟩ |

### Layer 4: Front Line

**New idea: the Front.** A track runs between the players, **5 steps each way** from the centre.
- A **Strike** may now **push the Front 2** toward the enemy instead of removing a tile. With no tile to hit, it pushes.
- Enemy **Armor** soaks pushes 1 for 1. A **spotted** Strike pushes 3 and ignores Armor.
- **Push the Front to the enemy's end and you win at once** (a Breakthrough). Otherwise the Front scores nothing.

**Example.** Your Ammo reaches 3. Their banner on the open objective is next to their Bunker, so you push the Front instead. They have 1 Armor, which soaks 1: the Front moves 1, to 4 steps from their end. Next turn you Spot first, and your Strike pushes 3 through their Armor: **Breakthrough**.

| Skill | Luck floor | Seats (start 1 / none) | Length | Military a game |
|---|---|---|---|---|
| ⟨K4⟩ | ⟨G4⟩ | ⟨S4⟩ | ⟨P4⟩ | ⟨M4⟩ |

### Layer 5: Streaks (the ranked rules)

**New idea: a hot run earns rewards.** Your **streak** goes up 1 for each rally you close and each order you fire. An enemy Strike that lands on you (removes your tile or moves the Front) resets it to 0.
- **3 · Spotter Drone:** +1 Intel.
- **5 · Supply Drop:** draw 1 and place one more tile now.
- **7 · Fire Mission:** push the Front 2, ignoring Armor, and remove one enemy tile that touches an open objective, ignoring protection.

**Example.** You close a rally (streak 1), and your Strike and Resupply fire (2, 3): **Spotter Drone**, +1 Intel. Next turn their Strike removes your banner, and your streak drops to 0.

| Skill | Luck floor | Seats (start 1 / none) | Length | Military a game |
|---|---|---|---|---|
| ⟨K5⟩ | ⟨G5⟩ | ⟨S5⟩ | ⟨P5⟩ | ⟨M5⟩ |

---

## 3. What v5 cut, and why

The head's note was "too many rules at once". Before v5, Classes and Front Line each added four or five rules in one step. These are gone from every layer:

| Cut | Was | Why it can go |
|---|---|---|
| **Engineer cover** | A tile touching its owner's Engineer tile could not be Struck (v3) | The head chose (a) on H3. The sim measured nothing it added (v4 §6.2). Bunker and Smoke keep protection as card text. |
| **Objective owner's materiel** | The objective's owner also got 1 materiel of its class (v3) | Now Classes reads like Basic line 4: "1 for every tile touching it". It costs about 1.3 orders a game; skill stays at 96–98%. |
| **Spot and Resupply push the Front** | +1 step each (v3) | Each order is now one line, and only the Strike moves the Front. |
| **Fortify wins back ground** | +1 step back toward the centre (v3) | Same reason. Fortify is "+2 Armor", and Armor does the defending. |
| **Seeing the opponent's hand** | On Spot and Spotter Drone (v3) | It adds a screen and reading time on the opponent's turn. The sim never modelled it, so no balance number depends on it. |
| **Front 6 steps each way** | 13-step track (v3) | With only Strikes pushing, 6 steps gave Breakthroughs in 1–4% of games. 5 steps, with a spotted Strike pushing 3, gives ⟨BT5⟩ (v3 aimed for 8–9%). 4 steps gave 12–15%, too swingy. |

**What stays although it is a second rule:** the end rule in Layer 2 (unrallied objectives score at 1 a square). Without it, the Cards layer measured worse on both counts: seats 45.8 / 54.5 instead of 50.3 / 53.0, and the skill margin +16.9 instead of +18.7. Cards such as Dig-In also need it. It is one line on the end-of-game screen.

**Why Classes is one layer, not two.** Splitting it (Ammo and Supply first, Intel and Works later) would leave two of the four starter stacks without working meters for a whole layer: T3 has no Assault or Support, and T2 no Assault. "Your tile's class picks the meter" is one idea, and the four orders are one line each, printed on the meters. Question 2 offers the split anyway.

**Not changed:** orders fire by themselves (H2); points win, with the Front as a sudden-death threat; streaks are fixed at 3 / 5 / 7; objectives and scored points are never removed.

---

## 4. Simulator fix: Field Kit in Basic

The UI agent found it: in `rally_v4.py`, `moves_for` read Field Kit's patch ability from the raw card data instead of through `AB()`, the function that hides card text when a ruleset turns text off. So under Basic, Field Kit (in starters T2 and T4) could still be pinned as a patch. `rally_v5.py` fixes this. It also applies Basic's target rule (a tile touching an open objective; if there is one, the Strike must take it) the same way for every AI. v4's planning AI could aim at any unprotected tile.

**v4 §6.3 Basic row, re-run** (800 games a row, same seed 71; a second seed for v5):

| Basic | Skill (margin) | Luck floor | Options / distinct / best − median | Length | Empty squares | Full boards | Seats (start 1 / none) | Tiles removed |
|---|---|---|---|---|---|---|---|---|
| v4 (with the bug) | 97.4% (+14.3) | 72.9% | 65.8 / 5.8 / 2.00 | 20.0 | 3.5 | 23.5% | 47.0 / 52.5 | 0.98 |
| **v5, seed 71** | **96.6% (+13.8)** | 73.8% | 66.6 / 5.9 / 2.06 | 19.6 | 4.2 | 19.0% | 48.0 / 52.8 | 0.96 |
| v5, seed 72 | 95.1% (+13.8) | 68.8% | 66.7 / 5.9 / 2.01 | 19.7 | 4.2 | 19.5% | 50.0 / 49.5 | 0.92 |

The bug flattered the board, not the skill: full boards fall from 23.5% to about 19%, and empty squares rise from 3.5 to 4.2. The skill gap, decision density and length are unchanged within noise. v4's conclusions about Basic stand.

---

## 5. Starter stacks

Round robin, ranked rules (Layer 5), the second player starts with 1, 600 games a pairing.

| Rules and stacks | T1 | T2 | T3 | T4 | Range |
|---|---|---|---|---|---|
| v3 launch rules with cover, no fixes (v4, `rally_v3.py`) | 51.3 | 46.5 | 40.8 | 61.4 | 40.8–61.4 |
| v3 launch rules with cover + v4 fixes (v4) | 45.7 | 52.3 | 47.6 | 54.4 | 45.7–54.4 |
| **Full rules minus cover + v4 fixes** (the brief) | 47.4 | 51.1 | **44.9** | **56.6** | 44.9–56.6 |
| v5 rules, v4 fixes, v4 starters | 45.6 | 55.9 | 44.8 | 53.7 | 44.8–55.9 |
| **v5 rules + v4 fixes + two swaps** (seed 151) | 46.4 | 51.2 | 48.9 | 53.6 | **46.4–53.6** |
| same, second seed (152) | 47.4 | 50.8 | 48.6 | 53.2 | **47.4–53.2** |

- **The v4 fixes alone miss the target without cover.** T3 Relay Net leaned on Engineer cover, and T4 Shock and Supply on Point Man.
- **The two swaps (commons only):** T3 swaps **Dug-In → Sandbag Line** (Rally: +1 Works). T4 swaps **one Point Man → Rifle Team** (Rally: +1 Ammo) and **Field Kit → Medic Line** (Rally: +1 Supply). The other swap sets we tried (`STACK_FIXES` c, d, e and g) left T4 at 55.1–57.8.
- **The v4 fixes apply:** Bunker is Command 2 and Shock Line is "Breach +2".

| Stack | Classes | Banners (7) | Objectives (3) | Insignia (2) |
|---|---|---|---|---|
| T1 Spearhead | ◆ ● | Point Man ×2, Shock Line, Liaison A>R, Wireman, Spotter ×2 | Assault Post ×2, Recon Post | Ammo Cache, Flare |
| T2 Hold the Line | ▲ ✚ | Dug-In ×2, Long Watch ×2, Sandbag Line, Field Kit, Quartermaster | Engineer Post, Bunker, Supply Depot | Sandbags, Supply Crate |
| T3 Relay Net | ● ▲ | Wireman, Liaison R>E ×2, Long Watch ×2, **Sandbag Line**, Spotter | Recon Post, Engineer Post ×2 | Flare, Sandbags |
| T4 Shock and Supply | ◆ ✚ | Point Man, **Rifle Team**, Shock Line, Liaison A>S, Medic Line ×2, Quartermaster | Assault Post ×2, Supply Depot | Ammo Cache, Supply Crate |

---

## 6. The AI's military weights

v4 found that the AI that ignores the military layer (`milblind`) beat the one that values it (`smart`). Under v5 it still does, at 44.6–47.1% across the layers.

**The retune.** v3's weights were set for meters that fire at 3. In Basic the meter fires at 5, so each Ammo was overvalued by 5/3, and the AI built toward Strikes worth less than it thought. The new `tuned` set values one materiel at 0.35 × 3 ÷ threshold (it was 0.55 flat) and halves the other military terms: Armor, streak, Spot, the Front, the enemy-threat penalty and the near-Breakthrough bonus. We chose it from a 12-point grid (mat 0.2 / 0.35 / 0.55 × Front 0.65 / 1.3 × threat 0 / 0.2) at 1,000 games a point, after a first pass of 7 sets. Every scaled set landed within 47–51% against `milblind`.

| Layer | tuned v smart (the old weights) | tuned v milblind | smart v milblind |
|---|---|---|---|
| L1 Basic | 51.9 | 48.6 | 46.2 |
| L2 Cards | 53.5 | 49.8 | 46.4 |
| L3 Classes | 52.5 | 51.4 | 44.8 |
| L4 Front Line | 52.1 | 46.8 | 47.1 |
| L5 Streaks | 53.6 | 47.6 | 44.6 |
| **All, 4,000 games** | **52.7** (2 SE ±1.6) | **48.8** | **45.8** |

800 games a cell, 2 SE about ±3.5.

**Ship `tuned`.** It beats the old weights in every layer and closes most of the gap to `milblind`, from −4.2 to −1.2.

**Why no weight set beats `milblind`.** Orders fire by themselves, at the end of the turn that fills the meter, so the AI's one-move lookahead already *sees* every order a placement triggers and counts its points and removed tiles. The only military knowledge left for the weights is a guess about the future: a half-full meter, a threat. Those follow from rallies, and the tiling evaluator already chases rallies. So the military layer rewards good tiling instead of asking for a second plan. That fits the head's "a tiling and puzzle game mostly", and it is why "hold an order" (v4) found no timing skill either. **For AI difficulty tiers, vary the tiling search** (depth and how many options the AI considers), not the military weights.

---

## 7. Godot 4.4.1 notes (delta to v4 §8)

- `RulesetDef` (`ruleset_basic.tres`, `ruleset_cards.tres`, `ruleset_classes.tres`, `ruleset_front.tres`, `ruleset_ranked.tres`): booleans `card_text`, `end_scoring`, `classes`, `front`, `streaks`; ints `strike_threshold` (5 for layers 1–2, 3 from Classes) and `front_steps` (5). **Remove** `cover`, and add no fields for the cut rules. The sim's `LAYERS` table maps 1:1.
- Protection is a card hook: `can_be_struck(tile) -> bool` asks the touching Bunker and Smoke tiles, and the Strike's target outline uses the same call. `is_strike_target(tile)` = enemy tile, touches an open objective, `can_be_struck` (or the Strike is spotted).
- AI: `AIWeights` resource with the `tuned` values; materiel value = `mat * 3.0 / strike_threshold`.

---

## 8. Questions for the studio head (recommended option first)

1. **⟨Q1⟩**
2. **Classes: one layer or two?**
   - **(a) One layer, with the trimmed orders above (recommended).** Each order is one line, printed on its meter. It is one idea, "your tile's class picks the meter".
   - (b) Two layers: Ammo and Supply first, then Intel and Works. Smaller steps, but T2 and T3 play a whole layer with an idle meter, and the unlock path grows to 6 steps.
3. **The trimmed Front (section 3):**
   - **(a) 5 steps each way, only Strikes push, and a spotted Strike pushes 3 through Armor (recommended).** One idea, with Breakthroughs in about ⟨BT5⟩ of games.
   - (b) v3's Front, as approved in v3: 6 steps each way, and Spot, Resupply and Fortify also move it. Breakthroughs in about 8% of games, but four extra rules arrive in Layer 4.

---

*Reproduce (from `tools/`, about 5–15 minutes each on one core):* `python3 -I rally_v5.py 400 rules r=22 seed=71` (Basic re-run; `rally_v4.py` the same for v4) · `500 layers l=0,1,2,20,21,22 stk=f seed=141` (layer tables) · `500 seat5 l=0,1,2 stk=f seed=171` and `l=20,21,22 seed=172` (seats) · `300 stacks5 l=22 stk=f seed=151` (starters; `l=5` for the full rules minus cover) · `400 ai l=1,2,20,21,22 stk=f seed=161 "p=tunedvsmart,tunedvmilblind,smartvmilblind"` (AI) · `500 ai l=1,5 "p=tunedvmilblind" "w=scale:1,mat:0.35,..."` (the weight grid, seeds 311–334) · `300 layers l=3..19 seed=101,111,112` (the trimming variants).
