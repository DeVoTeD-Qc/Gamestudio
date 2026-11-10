# KillingCard: Run v2 (a run map with paths and bosses, Terrain on the columns, Operators with an ability)

*Author: Sr Game Designer Agent · 2026-11-07 · Board task kc-v2-design · Status: **design for the head's review**. No rules, UI, scene or data file was changed. The sim is the new `source/project-killingcard/tests/tools/run_v2_check.gd`: it plays the real engine (MatchState, FirefightResolver, RunProgress offers, AiPlanner), and everything new (Terrain, bosses, Operator kits, map nodes) lives inside that file as subclasses and hooks.*
*Inputs: `onboarding-progression.md` and `synergy-system.md` with their "Removed" sections (kc-no-training: no Recruit / Trained / Promotion; kc-pos-cut: no neighbour links, no row bonuses, no range bonuses; columns are plain A / B / C), `field-cards.md` (Model B, one Field per side per column, Overrun), `firefight-order.md` (beats, First Shot wins its exchange, Pierce), `card-system.md`, `scripts/run/run_progress.gd`, `reward_offers.gd`, `scripts/data/run_config.gd`, `data/run_config.tres`, the squads in `data/squads/`, the Operators in `data/loadout/`.*
*The head picked three ideas (verbatim): "**3. Run variety:** path choice on the run map (events, shop, elite fight, rest), 2–3 bosses with one unique rule each, and unlockable modifiers such as 'Hardcore'." "**4. Make Fields matter:** now that columns are just A/B/C, give each match 1–2 column Fields that change rules (e.g. 'Rooftops: First Shot here', 'Smoke: no Pick here'), so where you fight is a choice." "**5. Deeper Operator choice:** 3–4 Operators, each with one passive and one once-per-match ability. A different strategy per run without per-card complexity."*

## 0. Summary in seven lines
1. **A run is a map**: one act, 9 steps, 3 lanes. Five fights you must play (F1–F4 and the boss), up to two optional **elites**, and four forks with **Events** (9 written), **Shops** (one currency, **REQ**) and **Rests** (+1 ticket, send 2 cards home, or a weapon level). The match ladder, rungs, 2-of-4 picks, Muster out and Salvage map onto F1–F4 unchanged (§2–3).
2. **Three bosses**, each a crew plus one rule that uses a system the player already knows: **Meridian_Six** (from round 5, +1 Supply every round; kc-v2-tune, was round 4), **Bulwark Prime** (starts with a Mortar Pit in every column), **The Hollow Choir** (a Shambler joins it every round from round 2). The run's boss is on the map from step 1 (§4).
3. **Five unlockable modifiers** with a Threat number (Hardcore, Austerity, Veteran Crews, Fog of War, Hot Ground); they unlock cosmetics, never power (§5, §8).
4. **Terrain (map Fields)**: each fight deals 1–2 of 10 one-line column rules (Rooftops, Smoke, Dust Storm, Breach Point, Floodlights, Comms Tower, Supply Cache, Hot Zone, Minefield, Field Hospital). Both sides get it, it's shown on the map and before the mulligan, and it's never replaced in a match. None of them changes a unit's FP or Cover by where it stands (§6).
5. **Four Operators** (Kestrel AR-7, Longreach .338, Wasp-9 and the new **Bastion-60** LMG), each with one passive and one free once-per-match ability on a button on the Operator card (§7).
6. **Sim on the real engine (over 60,000 matches):** new player M1 **71.2%** (unchanged); competent run **40.5%** with the ramp 97 / 89 / 84 / 60 / **42** (boss); every Terrain within **±2.5** points for the player and **±5.4** in the mirror; Operators **37.5–42.1%** run win each (47.5–53.9% against the others); aware vs blind **62.8%**; seat 0 **47.9 / 50.5%**. One miss: traits on v2 decks read **35–68%** (Heavy low, Vanguard high), with or without Terrain, so they need a trait pass (§10).
7. **Implementation** splits into rules, data, AI and the run layer (Mechanics Developer) and seven screens or screen changes (UI/UX agent), with file ownership in §11. There are five head questions in §13.

---

## 1. Goals and what stays
| Goal | Measure (target) | How the design meets it |
|---|---|---|
| Runs differ | Path choices per run, bosses, Operators, Terrain | 4 forks on a 9-step map, 3 bosses, 4 Operators, 10 Terrains, 9 events |
| Where you fight is a choice | A Terrain never swings a match more than ±8 points | Terrains change a rule in one column only, and both sides get it (§6) |
| A different strategy per run, no per-card complexity | Each Operator 45–55% vs the others | One passive, one ability, both on the Operator card; no card text changes (§7) |
| The first run stays simple | New player M1 65–75% | The first run uses a fixed short map, one boss, no Terrain before F3, and the Operator kit switches on after F1 (§2.5) |
| A real run | Competent run 38–43%, the ramp climbs to the boss | §10 |
| Skill still matters | Aware vs blind ≥ 55%; traits 40–60%; seat 0 45–55% | §10 |
| Unlocks are variety, never power | Every unlock is a sidegrade, a challenge or a cosmetic | §8 |

**What stays exactly as it is:** the Standard Issue starter (20 cards; **10 since kc-econ, §15**), traits from the art (one per copy), Doctrine from the first calling card, the reward ladder by card type (units → tactics → Fields → full pool), pick 2 of 4 from F2, Muster out (one Standard Issue card home per card taken, plus one), Salvage after a loss, the green M1 squad (−1 Armor; **since kc-econ a slow, heavy 10-card crew at 0 Armor**), 3 tickets, the 15-card floor (**8 since kc-econ**), Field cards (Model B, one per side per column, Overrun), the beat order, the Operator's 1 Supply cost (**free in round 1 since kc-econ**) and the progressive reveal ("New: …" cards).

Design pillars for v2:
1. **Every choice shows its price.** A map node shows what it gives and what it risks before you step on it; a Terrain shows its rule on the column before you deploy.
2. **One line per rule.** A Terrain, a boss rule, an Operator passive and an ability each read in one sentence. No Terrain changes a unit's FP or Cover; column-wide buffs come only from cards and abilities you choose to play, as the head's position cut intends ("we'll keep that for tactics").
3. **Unlocks widen, they don't raise.** A veteran has more ways to play, not stronger cards.

## 2. The run map

### 2.1 Shape: one act, 9 steps, 3 lanes
```
 step   1        2          3          4               5          6               7          8          9
 lane L          [Event]    [Fight b]  [Elite]                    [Shop]                     [Rest]
 lane M [Fight] ─[ · ]  ─── [Fight a]  [Event]  ─────  [Fight]    [Elite]  ─────  [Fight]               [BOSS]
 lane R          [Shop]                [Rest]                     [Event]                    [Shop]
```
- **9 steps, 5 fights you must play** (F1–F4 and the boss), plus up to **2 optional elites** (steps 4 and 6). A run is 5–7 fights, about the length of today's 5-match run plus one or two.
- **3 lanes.** From a node you may move to the node in your lane or a neighbouring lane at the next step. Fight steps have 1 or 2 fight nodes: the same crew, but **different Terrain** (step 3 has two, steps 5 and 7 have two in run 2+). That is "where you fight is a choice" on the map.
- **Everything ahead is visible** from the start: node types, each fight's crew and its Terrain, and the boss with its rule. Nothing on the map is hidden behind a "?" (an event node shows its title; its options show when you arrive).
- **Map generation (seeded per run):** step 2 = Event + Shop; step 4 = Elite + Event + Rest (30%: the Event is a Shop); step 6 = Shop + Elite + Event (30%: the Event is a Rest); step 8 = Rest + Shop. Events are drawn without repeats.

### 2.2 Nodes: what each gives
| Node | Icon | What happens | Gives | Risk |
|---|---|---|---|---|
| **Fight** | crossed rifles | A match against the step's crew, with its Terrain | Win: Supply Drop (rung of the fight), 3 REQ, weapon level / Perk as today. Loss: Salvage, 1 REQ, −1 ticket | a ticket |
| **Elite** | rifles + star | A harder crew (+1 Armor, 2 Terrains) | Win: an **Elite Cache** = a Supply Drop one rung ahead (pick 2 of 4) + Muster out + **5 REQ**. Loss: Salvage, 1 REQ, −1 ticket | a ticket, and a tougher fight |
| **Event** | radio | A short scene with 2–3 choices (§3) | REQ, a card, a ticket, card removal, intel | some options cost a ticket or REQ (shown) |
| **Shop** | crate | Spend REQ (§2.3) | cards, removals, a Perk | none |
| **Rest** | tent | Pick one: **+1 ticket** (max 3), **Drill**: send 2 cards of your choice home (floor 15), or **Field-strip**: a weapon level now | — | none |
| **Boss** | skull plate | The run's boss (§4) | Win the run | the run |

### 2.3 Currency and shop: Requisition (REQ)
One currency, **Requisition (REQ)**, shown as a stencil "REQ 7" chip next to the tickets on the map and the reward screens. It's earned, never bought.

| Earn | REQ |
|---|---|
| Win a fight | +3 |
| Win an elite | +5 |
| Lose a fight (with the Salvage) | +1 |
| Events | +1 to +3 (some cost REQ) |
| Run start | 0 |

| Shop item (3 cards offered, slot 1 on your main trait, from the rung you are on) | Price |
|---|---|
| Unit card | 4 |
| Tactic | 3 |
| Field | 3 |
| Elite ★ card (rung 4 only) | 7 |
| **Muster out** a Standard Issue card (any number, floor 15; 8 since kc-econ) | 2 each |
| **Discharge** any other card (floor 15) | 3 |
| Perk (if a slot is free; 1 of 2) | 6 |
| Restock the 3 cards | 1 |

- **Muster out stays free after a drop** (one per card taken, plus one). The shop just lets you buy more of it. The price of 2 is the main lever on how fast the starter disappears (§10.3).
- **No tickets in the shop.** Tickets come only from Rest and two events, so the shop can't buy the run back.
- A typical solid run earns about 16 REQ and spends about 10 in one shop: one or two cards and a Standard Issue card or two home (§10.3).

### 2.4 How the match ladder maps onto the map
| Today | Run v2 | Crew (unchanged decks) | Terrain (run 2+) | Reward after a win | "New:" in the first run |
|---|---|---|---|---|---|
| M1 Bracket 1, ZC | **F1** step 1 | SandViper_07 · Standard Issue crew, −1 Armor (green squad) | 1 | rung 1, pick 1 of 3; weapon level | Calling cards & Traits (unchanged) |
| M2 Bracket 1, ZC | **F2** step 3 | Bulwark_Nine · Standard Issue crew | 1 | rung 2, pick 2 of 4, Muster out; Perk | Keywords, Muster out (unchanged); **New: Operator ability** at the start of F2 |
| — | **Elite I** step 4 (optional) | the F3 crew (Rusher Honors, FF) at +1 Armor | 2 | Elite Cache rung 3 (pick 2 of 4), +5 REQ | **New: Elite fights** (on the map, when first reachable) |
| M3 Bracket 2, FF | **F3** step 5 | SandViper_07 · Honors crew | 1 or 2 | rung 3 (+ Fields), pick 2 of 4; weapon level | **New: Terrain** (first Terrain on the board), Fields (unchanged) |
| — | **Elite II** step 6 (optional) | the F4 crew at +1 Armor | 2 | Elite Cache rung 4 (pick 2 of 4), +5 REQ | — |
| M4 Bracket 2, FF | **F4** step 7 | Bulwark_Nine · Mastery crew, **+1 Armor** (today 0) | 2 | rung 4 (full pool), pick 2 of 4; weapon level, Perk | Elites (unchanged) |
| M5 Rival | **Boss** step 9 | one of three bosses (§4) | none (the boss rule is the twist) | run won | **New: Boss rule** (on the map from step 1) |

- **Rungs, picks and Muster out don't change**: they follow the fight number (F1–F4), and an elite's cache is one rung ahead. The order of discovery from `onboarding-progression.md` §4.1 holds.
- **F4 gets +1 Armor** (today 0). The v2 deck is stronger by F4 (shops, elites, rests), and without it F4 would be easier than F3.
- **Tickets:** 3, a loss costs 1, the run ends at 0 (as today). Rests and two events give tickets back (max 3).

### 2.5 The first run (progressive reveal; the new-player target)
The first run uses a **fixed short map** with one fork:
```
 [F1] → [Event: Quartermaster's Audit] → [F2] → [Rest | Elite I] → [F3] → [Shop] → [F4] → [Rest] → [Boss: Meridian_Six]
```
- **F1 is exactly today's M1**: no Terrain, and the **Operator's passive and ability switch on at F2** ("New: Operator ability" opens on the F2 board). Measured: new player M1 **71.2%**, exactly today's number (with the kit on from F1 it would be 79%).
- **No Terrain until F3**, then 1 Terrain in F3, F4 and Elite I. The boss never has Terrain.
- **The only fork is step 4** (Rest or Elite). The Shop at step 6 is the first shop ("New: Requisition" there; REQ is shown from F1 but explained here).
- **Always Meridian_Six**, today's Rival with its rule. Kestrel AR-7 is the only Operator, no modifiers.
- From run 2 the full map, Terrain from F1, Operator choice (once unlocked) and the boss rotation apply.

### 2.6 Path choice in the sim
The sim's competent path rule: with full tickets go Elite, else Shop when it can buy a unit, else Event; with one ticket left go Rest. The casual rule picks at random. Both rules are crude on purpose: a real player who reads the map should do a little better than the competent proxy.

## 3. Events (9, original flavour; each fits on one card)
Each event is a title, two lines of scene and 2–3 buttons. Every button says exactly what it does ("+3 REQ", "Lose 1 ticket: 50%"). Odds are always printed. An event never costs a ticket without saying so.

| # | Event | Scene | Choices |
|---|---|---|---|
| 1 | **Abandoned Supply Truck** | A truck on its rims in a ditch, the tarp still lashed down. | **Crack the crates:** +3 REQ. · **Strip the radio:** add a Comms Relay (Field) to your deck. · Drive on. |
| 2 | **Quartermaster's Audit** (fixed in the first run) | "Sign here, and here. Kit you don't use goes back on the truck." | **Hand in kit:** Muster out 2 Standard Issue cards. · **Fill in the forms:** +2 REQ. |
| 3 | **Wounded Scout** | A scout from another unit, leg splinted with a rifle sling. | **Escort him back:** pay 2 REQ, +1 ticket (max 3). · **Take his kit:** add a Recon Specialist. |
| 4 | **Black Market Fixer** | A man in a borrowed uniform sells things that fell off trucks. | **Swap:** remove a card, gain a random unit of the full pool (shown after). · **Sell:** remove a card, +2 REQ. · Walk away. |
| 5 | **Radio Chatter** | You catch the next crew's channel. | **Jam it:** your next fight has no Terrain. · **Pick the ground:** choose your next fight's Terrain from 3. · **Sell the frequency:** +2 REQ. |
| 6 | **Memorial Wall** | Names in marker on a blast wall, someone's tags hung on a nail. | **Pay respects:** +1 ticket (max 3). · **Carry their tags:** copy one calling card in your deck (same trait). |
| 7 | **Old Rival's Message** | "Heard you're good. Prove it." A grid reference. | **Accept:** your next fight is played at +1 enemy Armor and pays like an elite (+5 REQ). · **Ignore:** +1 REQ. |
| 8 | **Range Day** | A quiet afternoon and a crate of ammo nobody counted. | **Zero the rifle:** a weapon level now (pick 1 of 2). · **Drills:** your next Supply Drop shows 1 more card. |
| 9 | **Night Drop** | A pallet drifts down into the treeline, off target. | **Go get it:** 50%: an Elite ★ card; 50%: lose 1 ticket. · Leave it. |

## 4. Bosses (3)
A boss is a crew plus **one rule**, shown on the boss node from the start of the run ("BOSS RULE" plate), on the match intro and as a plate on the board (right click / long press: the full text). The boss never gets Terrain.

| Boss | Squad (deck) | Mode | Scaling | Rule (one line) | Where |
|---|---|---|---|---|---|
| **Meridian_Six** (Black Meridian, Spec Ops) | the shipped Rival `enemy_deck` (4 Gunners, 2 Shieldmen, 2 Riflemen, 2 Medics, Anvil, Wren, …) | Zone Control | Armor +1 (as today) | **Reinforcements:** from round 5, gains 1 extra Supply every round (kc-v2-tune; was round 4). | Step 9. Always in the first run; one of three after that |
| **Bulwark Prime** (Anchor, Heavy) | the shipped Bulwark_Nine squad deck (Trained Anchor: Gunners, Protectors, Medics, Hold the Line, Suppressing Fire) | Firefight | Armor +1 | **Dug In:** starts the match with a Mortar Pit in every column. (Overrun tears one down, as for any Field.) | Unlocked after your first run |
| **The Hollow Choir** (Undead) | a new authored deck: Brawler ×4, Point Man ×3, Combat Medic ×2, Flanker ×2, Shieldman ×2, Demolitions Expert ×2, Recon Specialist, Aid Station, War Standard, Hold the Line, Ammo Resupply (20; Undead identity) | Zone Control | Armor +2 | **Horde:** from round 2, a 1/2 Shambler joins the back of its emptiest column every round. Shamblers don't hold ground, and Pick and Flank ignore them. | Unlocked after your first boss win |

- **Each rule uses an existing system**, so the player already knows how to answer it: Supply (Meridian: win it before round 5 or hold out), Fields and Overrun (Prime: take a column to tear its pit down), and units that don't count for control (Choir; the Sentry token works the same way). Killing a Shambler counts for your streak. Shamblers ignore Pick and Flank so they don't soak every Marksman shot (without that line Longreach won 15% of its Choir fights).
- **Rotation:** from run 2, the run's boss is drawn from the unlocked bosses, never the same one twice in a row, and it is shown on the map from step 1, so the whole path can be planned against it (e.g. Fields and Pick against the Choir, Overrun pressure against Prime).
- Boss fights for the solid proxy: Meridian 40.3%, Prime 40.3%, Choir 45.7% (§10.2). The levers are the rule's numbers (Meridian: the round the Supply starts; Prime: pits in 2 or 3 columns; Choir: the Shambler from round 1 or 2, 1/2 or 2/2) and the boss Armor bonus.

## 5. Modifiers (5, unlockable, opt-in)
Picked on the Loadout screen before a run, any combination. Each shows its effect in one line and a **Threat** number; the run's Threat total is printed on the map and on the After-Action screen. Winning at a Threat level unlocks cosmetics (§8), never power.

| Modifier | Threat | Effect (one line) | Unlocks after | Competent run (base 40.5%) |
|---|---|---|---|---|
| **Hardcore** | 3 | Start with 2 tickets; you can never have more than 2. | Your first run win | 28.2% (−12.3) |
| **Austerity** | 1 | Supply Drops: take 1 card instead of 2. | Win a run with any 2 Operators | 38.0% (−2.5) |
| **Veteran Crews** | 1 | F4 and the elites get +1 Armor. | Beat all three bosses | 38.2% (−2.3; F4 60 → 37%) |
| **Fog of War** | 1 | No red dots for either side. | Win a run with Hardcore | not measurable in the sim (the AI plans without red dots); playtest |
| **Hot Ground** | 0 (variety) | Every fight has one more Terrain (max 2); the boss gets 1. | Play on all 10 Terrains (Dossier complete) | 39.5% (−1.0) |

- Tested and changed: "Supply Drops show 3 cards instead of 4" (−0.3, no challenge), "F3, F4, elites and the boss +1 Armor" (17.9%, far too hard; boss + elites only: 25.0%), Hardcore without the cap of 2 (the Rest refilled the third ticket: −0 points).
- Hot Ground is variety rather than challenge (Terrain doesn't move the run, §10.5), so it carries no Threat.
400 runs per row, same seeds as the base (§10.6).

## 6. Terrain (map Fields on the columns)
**Player-facing name: Terrain** (internally `map_field`). "Field" is already the card type the player places, and two things called Field on one column would be confusing (head question 1). A Terrain is part of the **column itself**, not a card: it belongs to neither side, applies to both, can't be shot, Sabotaged, Overrun or replaced in the match, and never counts for traits.

### 6.1 The pool (10)
| Terrain | Rule (one line, as printed) | What it makes you decide | Swing: vs crews / mirror seat 0 (points, §10.5) |
|---|---|---|---|
| **Rooftops** | Whoever holds this column at the start of the round has First Shot here. | Take it early and keep it; arriving into a held Rooftops is expensive | +0.4 / −0.4 |
| **Smoke** | No Pick or Flank here: every shot hits the front unit. | Put your Marksman elsewhere; a wall in front is safe here | +1.7 / −2.5 |
| **Dust Storm** | No First Shot here. | Breachers and Point Men lose their edge; plain bodies trade evenly | +0.8 / 0.0 |
| **Breach Point** | Every unit here has Pierce. | Stack damage here; don't park a stack of fragile cards behind one wall | +1.2 / −2.1 |
| **Floodlights** | Red dots here are shown face-up to both sides. | No surprises here: commit where you have the better card | 0.0 / 0.0 |
| **Comms Tower** | Hold this column at the end of the round: +1 streak. | A streak race: holding it brings killstreaks sooner | +1.7 / −3.3 |
| **Supply Cache** | Hold this column at the end of the round: +1 Supply next round. | Tempo: hold it early, spend it late | +2.1 / −2.5 |
| **Hot Zone** (Zone Control only) | Holding this column scores 1 extra point. | The match is decided here; the AI fights for it too | +2.5 / −5.4 |
| **Minefield** | Each round, the first unit each side brings here takes 1 damage. | Lead with a cheap or sturdy card; never drop a 2-Armor Marksman in first | +0.8 / +2.1 |
| **Field Hospital** | End of round: each side's most damaged unit here heals 1. | Long fights favour the side with the bigger Armor pool | 0.0 / −1.7 |

**What is not in the pool, on purpose (the head's cut):** no Terrain adds FP or Cover to units, by class, row, neighbour or range. Every rule above is a keyword switched on or off for the column (First Shot, Pick / Flank, Pierce), a scoring or economy rule (streak, Supply, points), intel (red dots), or a column-wide event (damage on arrival, a heal). Tested and left out: "Cover +1 here" and "+1 FP here" (they are the old range bonus under a new name) and "Max 2 units here" (it fights the zone-full rule and the AI's capacity model).

### 6.2 Dealing, reveal and replacement
- **How many:** F1 and F2: 1; F3: 1 or 2 (50%); F4: 2; elites: 2; boss: 0 (first run: none before F3, then 1). Hot Ground adds 1 (max 2, the boss gets 1).
- **Where:** distinct Terrains on distinct random columns (seeded per run, so a reload deals the same). Hot Zone only in Zone Control matches.
- **Revealed:** on the map, at the fight node (inspect shows the columns and their Terrain), and again on the match intro and the board **before the mulligan**. Never hidden. "Where you fight is a choice" starts on the map (pick the fight whose ground suits your deck) and continues on the board (where you send each card).
- **Replaced:** never during a match. Only the Radio Chatter event changes a fight's Terrain (before it starts). No card can remove Terrain in v2 (a later "Engineer" card or Operator is a lever, not a v1 need).

### 6.3 Terrain and Field cards
| Case | Rule |
|---|---|
| Slots | Terrain is a band across the whole objective tile; each side's Field slot is unchanged (one visible Field per side per column). A Field never replaces a Terrain and a Terrain never blocks a Field. |
| Stacking | Both apply. Floodlights + Listening Post: the Listening Post adds nothing new (its text is greyed with "Floodlights already shows these" on the placement preview). Field Hospital + Aid Station: both heal. Breach Point + a Gunner: the Gunner already has Pierce. |
| Overrun | Unchanged. Terrain is never torn down. Comms Tower, Supply Cache and Hot Zone use the same "hold" test as Overrun (control after the firefight). |
| Fields that want a Terrain | Sniper Perch in Smoke is weaker (no Pick); War Standard on Rooftops is stronger. The placement preview shows the combined effect, so the player sees it before committing. |
| AI | The AI reads the Terrain the same way the player does (the sim's AI is Terrain-aware; §10.5 has aware vs blind). |

## 7. Operators (4)
The Operator is still a unit card with its Primary's stats, its keyword and its 1 Supply cost. v2 adds **one passive** (always on, printed on the card) and **one ability** (once per match, free, played from a button on the Operator card during Deploy like a killstreak). Card text on deck cards doesn't change.

| Operator | Weapon · FP / Armor · keyword | Passive (one line) | Ability: once per match, 0 Supply (one line) | Plays like |
|---|---|---|---|---|
| **Kestrel AR-7** | AR · 3 / 7 | **Quartermaster:** your opening hand has 1 more card (on the map from F2; kc-v2-tune). | **Dig In:** your units in a column have Cover 1 this round. | the steady all-rounder: more options, one big defensive turn |
| **Longreach .338** | Sniper · 3 / **6** (today 5) · Pick | **Overpenetration:** the Operator has Pierce. | **Marked Shot:** 3 damage to an enemy unit in the Operator's column. | picks off backliners; one guaranteed removal |
| **Wasp-9** | SMG · 2 / **7** (today 6) · First Shot | **Run and Gun:** may Rotate twice per round (as today). | **Flashbang:** enemies in the Operator's column lose First Shot and get −2 FP this round. | moves to where the fight is and wins the one exchange that matters |
| **Bastion-60** (new) | LMG · 2 / 8 · Pierce (every LMG) | **Sandbagged:** the Operator has Cover 1. | **Covering Fire:** your units in the Operator's column get +1 FP this round. | holds one column; the anchor for Heavy decks |

- **Why these abilities:** each is a one-round version of a tactic the player already knows (Hold the Line, a removal, Suppressing Fire + Blackout, Callout for a column), so it reads at once and the AI already values it. The passives use existing keywords (Pierce, Cover) or an existing number (opening hand, Rotations).
- **Why not Suppress on Bastion:** it was the first idea, and it won F1 100% and the run 48–53%: −2 FP on the enemy front unit decides the early fights by itself.
- **The ability is a free, once-per-match play.** It's always available from round 1 (from F2 in the first run), costs no Supply, and is shown as a charge pip on the Operator card. It is not a killstreak (it never needs a streak and isn't lost on an Operator down).
- **Unlocks:** Kestrel from the start; **Longreach** after your first run ends (win or lose); **Wasp-9** after you reach the boss once; **Bastion-60** after your first run win. Each Operator unlock has a "New: Operator" card on the Loadout screen with the passive and the ability.
- **Enemy Operators** keep today's Primary and get no ability (the boss rule is the enemy's twist). The rules allow an enemy ability later (the data is per Operator).
- **Bastion-60** is a new Primary (`data/loadout/bastion_60.tres`), our own name and art; the pitch art set has an LMG mastery line that can dress it (art-traits rules apply).

### 7.1 UI for the Operator card (desktop and touch)
| Element | Rule |
|---|---|
| Passive | One line under the stat strip with a small "P" chip. Right click / long press: the full text and an example. |
| Ability button | A round button on the Operator card's top edge (the "charge pip"), in the hand area and on the board. Lit while usable, empty once spent ("USED"). Tap: target picking as for a tactic (column, or an enemy unit for Marked Shot), with the same preview and Undo. Right click / long press: the text, the targets, "Once per match". |
| Off the board | Marked Shot, Flashbang and Covering Fire need the Operator on the board (or arriving this Deploy). While it's off, the button shows "Deploy your Operator first". |
| Enemy | Enemy Operators show no button. The boss rule plate sits where the enemy Operator plate is. |
| Log | The killfeed / event log names the ability ("Kestrel: Dig In, column B") so the player always knows what just happened. |

## 8. Collection: what unlocks between runs
| Unlock | How | What it is |
|---|---|---|
| Operators | §7 | sidegrades (§10.4: each 45–55% vs the others) |
| Bosses | after run 1, after the first boss win | variety, not difficulty (§10.2 has each boss's numbers) |
| Modifiers | §5 | opt-in challenge |
| **Dossier** (Codex tab) | a Terrain's page fills in the first time you play on it; an event's page when you first see it; a boss's when you first fight it | knowledge: each page has the rule, the flavour and your record on it |
| **Operator camo** | win a run with that Operator (Gold Leaf), then at Threat 2 (Machined), Threat 4 (Prism), Threat 6 (Starfield) | original level finishes drawn in code (`mastery_bands.gd`, kc-ui-bands; the old camo-ladder names are retired); cosmetic only |
| **Banner frames / map stamps** | beat each boss; win at each Threat level | a frame for calling cards in the Codex, a stamp on the map's boss node |
| Calling cards | found in runs (unchanged) | the Codex album (unchanged) |

**Never unlocked:** stronger cards, a bigger starter, extra tickets, extra REQ, a permanent stat. A veteran's first fight is exactly as hard as a newcomer's second run.

## 9. Clarity (studio UX rule: inspect everything, show what the decision needs)
| Screen | Shown for the decision | Behind right click / long press |
|---|---|---|
| **Run map** | node icons, the fight's crew name and Terrain icons, the boss and its rule plate, tickets, REQ | node: what it gives / risks; fight: crew deck list, mode, Terrain rules; boss: full rule and deck |
| **Event** | title, two lines, buttons with exact results and odds | each card a button would add (full card view) |
| **Shop** | 3 cards with prices, removal buttons, REQ | every card (zoom), the deck list for removals |
| **Rest** | three buttons with exact results | the cards for Drill |
| **Board** | a Terrain band on the objective tile: icon + name + the one-line rule, both sides lit | the full rule, an example, "applies to both sides" |
| **Operator card** | passive line, ability button with its charge | full texts, targets |
| **Boss** | the rule plate next to the enemy Operator plate | full rule; Shamblers and Prime's Mortar Pits are normal inspectable cards |
| **After a round** | the event log names each Terrain trigger ("Minefield: Grunt takes 1"), ability and boss rule | — |

**New "New:" cards (RevealFlags ids):** `run_map` (first map), `requisition` (first shop), `elite` (first elite node reachable), `operator_ability` (F2 of run 1), `terrain` (first Terrain on a board), `boss_rule` (first boss node), `event` (first event), `rest` (first rest), `modifiers` (first unlock), plus one tip per Terrain (`terrain_<id>`, the first time each is in play). One per screen, at the moment of use, as today.

## 10. Sim results
**Harness:** `tests/tools/run_v2_check.gd` (new). It plays the v2 map with the **real** `RunProgress` (offers, rungs, 2 of 4, Muster out, Salvage, weapon levels, Perks, Doctrine), the real `MatchState` / `FirefightResolver` and the real `AiPlanner` on both sides. What v2 adds is prototyped in the same file: `V2Match` (a `MatchState` subclass: Terrain, boss rules, Operator passives), `V2Hooks` (Comms Tower, Supply Cache, Hot Zone), `V2View` / `V2Ai` (the AI reads the Terrain in its plan), the abilities as free once-per-match items the planner already knows how to value, and the map, shop, rest and events as a run loop around `RunProgress`. **Nothing in `scripts/` or `data/` was changed.**
**Proxies:** tune_check's *competent* and *casual* (the new-player proxy), unchanged. Path rule as §2.6, shop rule "on-trait unit, else the most expensive unit; spare REQ on Muster out". Seeds are fixed; 400 runs give about ±2.5 points SE on a run win rate, 240 runs ±3.2.
**Run:** `godot --headless --path . -s res://tests/tools/run_v2_check.gd -- exps=runs runs=400` (add `first=1`, `op=…`, `boss=…`, `mods=…`, `terrain=0`, `exps=ops,swing,late`; every number below is a tool default, and `k=name=value` changes one).

### 10.1 The first run (fixed map, Kestrel, Meridian_Six; target: new player M1 65–75%)
| 400 runs | F1 | F2 | Elite I (taken) | F3 | F4 | Boss | Run win | today (5-match run) |
|---|---|---|---|---|---|---|---|---|
| **New player (casual)** | **71.2%** | 79.5 | 19.1 (taken 50%) | 65.5 | 38.7 | 34.2 | 27.2% | M1 71.2%, run 20.8% |
| Competent | 94.8 | 96.8 | 42.1 (92%) | 79.2 | 54.2 | 43.5 | 40.2% | M1 94.8%, run 40.0% |

- **M1 is unchanged (71.2%)** because F1 is today's M1: no Terrain, and the Operator kit switches on at F2. With the kit on from F1 the new player wins 79% (measured; it's the +1 card and Dig In), which is why it waits.
- The first run is a little kinder than today's run for a new player (27% instead of 21%: a Rest before the boss and a Shop), and the same for a solid player (40.2% vs 40.0%). The levers are in §12.

### 10.2 Run 2+ (target: competent 38–43%, a smooth ramp, the boss as the peak)
| 400 runs, Operators and bosses rotate | F1 | F2 | Elite I | F3 | Elite II | F4 | **Boss** | **Run win** |
|---|---|---|---|---|---|---|---|---|
| **Competent** | 97.2 | 89.0 | 47.9 (taken 82%) | 84.0 | 62.9 (44%) | 59.8 | **42.1** | **40.5%** |
| Casual | 80.0 | 64.8 | 40.2 (32%) | 78.6 | 35.9 (33%) | 47.5 | 31.7 | 26.8% |

| Boss (competent, 400 runs) | Boss fight win | Run win |
|---|---|---|
| Meridian_Six (Reinforcements) | 40.3% | 38.2% |
| Bulwark Prime (Dug In) | 40.3% | 39.4% |
| The Hollow Choir (Horde) | 45.7% | 43.9% |

- **The ramp:** 97 → 89 → 84 → 60 → **42** for the solid player, with the two optional elites at 48% and 63% (a real gamble for a better cache; Elite II is taken mostly by decks that are already doing well). The boss is the peak.
- F3 (84) and F2 (89) are within noise of flat; F3 is the first Firefight match.
- **What was tuned to get here** (each a tool default; 30+ variants at 200–240 runs): F4 crew +1 Armor; the shop's Muster out at 2 REQ (1 REQ thinned the starter to 3 cards and lifted the run by about 5 points); Bulwark Prime with pits in all 3 columns and Armor +1 (2 pits: 55% boss fight; Zone Control instead of Firefight: 68%); the Hollow Choir at Armor +2 with a 1/2 Shambler from round 2 that Pick and Flank ignore (from round 1: 32%; without the "ignore Pick" line Longreach won only 15% of its Choir fights, because every Pick shot hit a Shambler); Meridian's rule went from "draws 1 extra card every round" (52.7% boss fight; +2 cards: 50%, its Supply is the limit) to "**from round 4, +1 Supply every round**" (40.8%; +1 Supply from round 1: 13%; from round 6: 51%; +1 FP: 21%; Armor +2: 27%).
- **Without Terrain** (same seeds, `terrain=0`, n = 160): competent run 42.5%, the same as with Terrain on those seeds (42.5%). Terrain changes where matches are won, not how often (§10.5).

### 10.3 Economy per run (competent, 400 runs)
| | per run |
|---|---|
| Nodes: fights / elites / events / shops / rests | 4 + boss / 1.25 / 1.04 / 1.02 / 0.64 |
| REQ earned (from the win rates), spent | about 16, 9.7 |
| Cards bought in shops | 1.51 |
| Standard Issue cards sent home (of 18) | 13.4 (today 7.7) |
| Deck at the boss | 16.7 cards, about 4 of them Standard Issue |

The starter now leaves faster than in today's run (13.4 vs 7.7 cards home). That is the head's "improve it by adding more cards and at some point by removing the starting cards", and it is the main reason the v2 deck is stronger by F4. The shop's Muster out price (2 REQ) is the lever.

### 10.4 Operators (target: each 45–55% vs the others)
| Operator (final kit) | Run win (240 runs each, bosses rotate) | Run win vs the others (p·(1−q) / (p·(1−q) + q·(1−p)), q = the others' mean) | Boss fight vs Meridian / Prime / Choir | Head to head, late decks (720 games each) |
|---|---|---|---|---|
| Kestrel AR-7 · 3/7 · Quartermaster · Dig In (Cover 1) | 38.3% | **48.6%** | 38 / 25 / 55 | 42.6% |
| Longreach .338 · 3/**6** · Pick, Pierce · Marked Shot 3 | 39.2% | **49.9%** | 42 / 42 / 40 | 56.5% |
| Wasp-9 · 2/**7** · First Shot, 2 Rotations · Flashbang (no First Shot, −2 FP) | 37.5% | **47.5%** | 22 / 28 / 65 | 41.5% |
| Bastion-60 · 2/8 · LMG Pierce, Cover 1 · Covering Fire +1 | 42.1% | **53.9%** | 44 / 47 / 37 | 59.3% |

- **On the run (the target as written), every Operator is inside 45–55% against the others**: the four run win rates are 37.5–42.1% (±3.2 SE each), so no Operator is a clear best pick.
- **The boss changes the best pick**, which is the point of showing the boss before the Operator is chosen: Wasp-9 wins 65% of its Choir fights (it Rotates to wherever the Shamblers pile up and Flashbangs the column) but 22% against Meridian; Kestrel struggles with Prime's pits (25%). A run where the player picks the Operator for the boss does better than the rotation the sim plays.
- **Head to head on the same late deck** (both sides Operator-only different), Bastion and Longreach win more and Kestrel and Wasp less (pairs: Kestrel–Longreach 37.9, Kestrel–Wasp 56.7, Kestrel–Bastion 33.3, Longreach–Wasp 57.5, Longreach–Bastion 50.0, Wasp–Bastion 38.8). In a mirror the bigger Armor pool (Bastion 8, Longreach's Pierce) decides more fights than it does against AI crews. That isn't a run number (no run is Operator vs Operator), so it's a watch item, not a blocker; the levers are in §12.
- Tried and rejected: Dig In Cover 2 + Wasp 3/6 with −1 FP (head to head 56.7 / 53.3 / 31.7 / 58.3, run 46.7 / 48.3 / 47.5 / 43.3: every run too easy); Bastion with Suppress as its passive (run 48–53%, F1 100%: the −2 FP on the enemy front unit wins the early fights alone); Bastion 2/7 Cover 1 (run 35%); Wasp 2/6 (run 33.5%).
- **Stat changes this implies on shipped data:** Longreach .338 Armor 5 → 6, Wasp-9 Armor 6 → 7 (both to pay for their kits being weaker early), Bastion-60 new at 2/8.

### 10.5 Terrain: no single Terrain swings a match by more than ±8 points
| Terrain | Player late deck vs F3 / F4 / Elite II crews (240 paired matches) | Δ vs no Terrain | Seat 0, late-deck mirror (240) | Δ | Player win by column A / B / C |
|---|---|---|---|---|---|
| (none) | 91.2% | — | 55.4% | — | — |
| Rooftops | 91.7 | +0.4 | 55.0 | −0.4 | 91 / 94 / 90 |
| Smoke | 92.9 | +1.7 | 52.9 | −2.5 | 91 / 96 / 91 |
| Dust Storm | 92.1 | +0.8 | 55.4 | 0.0 | 91 / 95 / 90 |
| Breach Point | 92.5 | +1.2 | 53.3 | −2.1 | 90 / 96 / 91 |
| Floodlights | 91.2 | 0.0 | 55.4 | 0.0 | 89 / 94 / 91 |
| Comms Tower | 92.9 | +1.7 | 52.1 | −3.3 | 95 / 94 / 90 |
| Supply Cache | 93.3 | +2.1 | 52.9 | −2.5 | 95 / 93 / 92 |
| Hot Zone (ZC) | 93.8 | +2.5 | 50.0 | −5.4 | 94 / 94 / 94 |
| Minefield | 92.1 | +0.8 | 57.5 | +2.1 | 89 / 94 / 94 |
| Field Hospital | 91.2 | 0.0 | 53.8 | −1.7 | 94 / 90 / 90 |

- **Every Terrain is inside ±8** on both measures. The largest is Hot Zone in the mirror (−5.4, n = 240, about ±4.5 SE on a difference): with a Hot Zone the seat that moves second wins a little more often, because the column is worth contesting late.
- The late decks beat these crews 91% of the time, so the first column has a ceiling; the mirror (55% base) is the sensitive measure, and it shows the same picture.
- **Reading the Terrain is worth little to the AI:** a Terrain-aware AI against a Terrain-blind one on the same deck reads 53.8% and 44.1% in two samples (n = 320 each; 52.2% with no Terrain at all, the noise floor). The AI's awareness is approximate (it sees the rules in its estimate but doesn't plan around them), so this is a floor for what a player gets from reading the ground, not a ceiling. Terrain is a texture you plan around, not a puzzle that decides the match, which is what "±8" asks for.

### 10.6 Modifiers (competent, 240 runs each, same seeds)
| Modifier (§5) | Run win | Δ | Boss fight | Note |
|---|---|---|---|---|
| none (base) | 40.5% | — | 42.1% | |
| Hardcore (2 tickets, max 2) | 28.2% | −12.3 | 39.5% | fewer runs reach the boss (72% vs 96%) |
| Austerity (take 1 of 4) | 38.0% | −2.5 | 39.2% | |
| Veteran Crews (F4, elites +1 Armor) | 38.2% | −2.3 | 40.6% | F4 60 → 37%; the proxy skips more elites |
| Hot Ground (+1 Terrain) | 39.5% | −1.0 | 40.6% | variety, no Threat |
| Fog of War | 40.5% | 0.0 | 42.1% | the AI plans without red dots on both sides, so the sim can't see it; a human loses information |

### 10.7 Skill, seats and traits on v2 end-of-run decks (random Terrain)
| Check (target) | v2 | today (v1.5, tune_check) |
|---|---|---|
| Synergy-aware vs blind, same late deck (≥ 55%) | **62.8%** (n = 320; 60.6% in a second sample) | 57.3% |
| Seat 0, late-deck mirror (45–55%) | **47.9%** (n = 480) | 54.7% |
| Seat 0, Standard Issue mirror (45–55%) | **50.5%** (n = 400) | 46.8% |
| Traits, aware round robin on v2 end-of-run decks, Kestrel on both sides (40–60% each; n = 270 per trait) | **Undead 53.7 · Spec Ops 47.0 · Heavy 31.5 · Vanguard 67.8** | 47.8 · 55.6 · 43.9 · 52.8 |
| Same, without Terrain (`terrain=0`) | Undead 45.6 · Spec Ops 46.7 · Heavy 38.3 · Vanguard 69.4 | |
| What-if: Heavy 2-set = Cover +1 (3-set adds +1 FP) | Undead 50.7 · Spec Ops 50.0 · Heavy 34.8 · Vanguard 64.4 | |

- **Skill and seats meet the targets.** The synergy edge grows (62.8%) because v2 decks hold more calling cards and complete their sets more often.
- **Traits miss the band, and not because of Terrain:** the no-Terrain control shows the same shape. The v2 deck has about 12 calling cards at the boss instead of 6, so whole-set bonuses decide more: Vanguard's 2-set (+1 FP) and 3-set (Cover +1) on cheap bodies is the best set when it is complete, and Heavy (nothing until 3, slow 4-drops) is the worst. The cheapest fix tested, a Heavy 2-set bonus, only moves Heavy +3. **This needs a trait pass on v2 decks** (`run_v2_check.gd exps=late tune=…`, with tune_check's method) before kc-v2-impl closes; it is the main open item of this spec (§12).
- Deck counts by main trait at the boss: Heavy 94, Spec Ops 59, Undead 47, Vanguard 28 (the proxy's "most expensive unit" pick rule favours Gunners).

### 10.8 What the sim does not cover
- **Path reading.** The proxies' path rule is fixed (§2.6); a player who plans the whole map against the boss and the Terrain will do better. Expect real players a few points above the competent proxy.
- **Radio Chatter's Terrain options and Range Day's "+1 card"** are not simulated (the proxy takes the REQ / the weapon level).
- **Shamblers and Mortar Pits** use the real token and Field rules; the AI values the pits through its Field code, and its own Shamblers as ordinary units.
- **Time:** a v2 run is 6.3 fights on average for the competent proxy (4 fights, 1.3 elites, the boss; today 5.0) plus 2.7 non-fight nodes (about 20–40 s each), so roughly +6–8 minutes per run.


## 11. Implementation split (after approval)
Two tasks, as the board already plans: **kc-v2-impl** (Mechanics Developer: rules, data, AI, run layer) and **kc-v2-ui** (UI/UX agent: screens). The rules side exposes view functions; the UI never edits `scripts/rules`, `scripts/run` or `data/`. Port `run_v2_check.gd` onto the shipped code when the rules land (drop its subclasses and keep the experiments) and re-measure §10.

### 11.1 Mechanics Developer (kc-v2-impl)
| # | What | Files (owner: Mechanics Developer) |
|---|---|---|
| 1 | **Terrain data**: `TerrainData` resource (id, name, one-line text, rule id, `zone_control_only`), 10 `.tres` | new `scripts/data/terrain_data.gd`, `data/terrain/*.tres`, `data/README.md` |
| 2 | **Terrain rules** as explicit helpers, not flag flips: `MatchState.terrain[zone]`, `held_at_start[zone]` (set in Briefing), `has_first_shot()` (Rooftops / Dust Storm), new `can_pick(u)` / `can_flank(u)` / `has_pierce(u)` read by `FirefightResolver.pick_target` and `_pierce` (Smoke / Breach Point), Minefield after arrivals in `reveal()` (uncredited damage, source `terrain`), Floodlights in `revealed_red_dots()`, Field Hospital in the score step, Comms Tower via `streak_bonus_this_round`, Supply Cache as next-round Supply, Hot Zone in `ModeRules.points_for_round`. Events: `TERRAIN_TRIGGERED {zone, terrain, side, uid?, amount?}`. `terrain_view()` for the UI. Clone support in `match_clone.gd`. | new `scripts/rules/terrain_rules.gd`; `match_state.gd`, `firefight_resolver.gd`, `mode_rules.gd`, `rules_event.gd`, `match_clone.gd`, `outcome_forecast.gd` |
| 3 | **Bosses**: `RunMatchData.boss_rule` (`reinforcements` / `dug_in` / `horde`) + text; rules at match start (pits as real enemy Fields) and in Briefing (extra draw, Shambler). Token `shambler` (1/2, no control, credit on, PASSIVE untargetable by Pick / Flank). Bulwark Prime and Hollow Choir slots (Choir deck authored, identity Undead). | new `scripts/rules/boss_rules.gd`; `run_match_data.gd`, `match_state.gd`, `data/cards/shambler.tres`, `data/squads/squad_hollow_choir.tres`, `data/run_config.tres` |
| 4 | **Operator kits**: Primary `LoadoutItem` gains `passive_text`, `pierce`, `opening_hand_bonus`, `ability: LoadoutItem`. The ability is its own slot on `RulesSide` (`ability_used`), not a streak-tray entry: `LoadoutRules.check_item` lets it through once per match, free, from round 1; intents reuse `use_item`. Data: `bastion_60.tres` (new, 2/8, LMG, Cover 1), `ab_dig_in / ab_marked_shot / ab_flashbang / ab_covering_fire.tres`; Longreach Armor 6, Wasp-9 Armor 7. | `loadout_item.gd`, `loadout_rules.gd`, `match_state.gd` (`_build_operator`, `start_match`), `rules_side.gd`, `data/loadout/*` |
| 5 | **AI**: `AiView.terrain` / `held` and the Terrain applied in `_unit_record`, `record_for_card`, `_operator_in_zone` (exactly the sim's `V2View.apply`); the ability listed in `items` (the planner already values these effect kinds); Shamblers' "ignore Pick" in records. | `ai_view.gd`, `ai_planner.gd` (only if a value needs tuning) |
| 6 | **Run map**: seeded generation (§2.1), lanes and links, node resolution, elite insertion, rung by fight number (elite = +1), REQ, Rest, the shop (prices §2.3), 9 events as data (`EventData`: title, text, options with effect ids), boss pick and rotation, the first-run fixed map, modifiers. Save **v7** (map, step, lane, REQ, boss, modifiers; v6 saves continue as a first-run-shaped map). | new `scripts/run/run_map.gd`, `run_shop.gd`, `run_events.gd`, `scripts/data/event_data.gd`, `data/events/*.tres`; `run_progress.gd`, `run_config.gd/.tres`, `reward_offers.gd`, `run_save.gd`, `autoload/run_state.gd` |
| 7 | **Profile unlocks**: Operators, bosses, modifiers, Dossier pages, camo / frames / stamps, best Threat. | `autoload/settings.gd` (or a new `autoload/profile.gd`) |
| 8 | **Reveal flags** for §9's new ids and their texts. | `scripts/run/reveal_flags.gd` |
| 9 | **Tests**: `test_terrain.gd` (each rule, both sides, Field stacking, clone), `test_bosses.gd`, `test_operator_kit.gd` (passives, ability once per match, AI uses it, Operator off the board), `test_run_map.gd` (generation, first run, rungs with elites, save v7), `test_shop_events.gd`; re-run `onboarding_check.gd`, `tune_check.gd`, `run_v2_check.gd`. | `tests/` |

**Hooks for the UI:** `RunProgress.map_view()` (steps, lanes, nodes {type, crew, mode, terrain[], boss_rule, reachable, done}), `shop_view()`, `event_view()`, `rest_options()`, `req`; `MatchState.terrain_view()` ({zone, id, name, text, active_for: [sides]}), `ability_view(side)` ({id, name, text, ready, needs_operator, targets}), `boss_view()`; `RunState` signals for Terrain / ability / boss events.

### 11.2 UI/UX agent (kc-v2-ui)
| # | Screen / element | Files (owner: UI/UX agent) |
|---|---|---|
| 1 | **Run map**: 3 lanes × 9 steps, node icons, links, the boss plate, REQ + tickets, node inspect (right click / long press) with crew deck, mode and Terrain rules | `scenes/run/RunMap.tscn`, `scripts/ui/run/run_map.gd` |
| 2 | **Event**, **Shop**, **Rest** screens: one card each on phone, exact results on buttons, every card zoomable | new `scenes/run/Event.tscn`, `Shop.tscn`, `Rest.tscn` + `scripts/ui/run/event_screen.gd`, `shop_screen.gd`, `rest_screen.gd` |
| 3 | **Loadout**: Operator picker (passive + ability lines, locked state with its unlock condition), modifiers with Threat, the run's boss | `scenes/run/Loadout.tscn`, `scripts/ui/run/loadout_screen.gd` |
| 4 | **Board**: the Terrain band on the objective tile (icon, name, one line; inspect for the full rule), Terrain triggers in the log, the Field placement preview with the Terrain's effect | `scripts/ui/objective_tile.gd`, `lane.gd`, `board.gd`, `match_snapshot.gd`, `card_inspector.gd` |
| 5 | **Operator card**: passive line, ability button with charge pip, target picking, Undo, "USED" | `scenes/match/OperatorPanel.tscn`, `scripts/ui/operator_panel.gd`, `hand_area.gd`, `match_controller.gd` |
| 6 | **Boss**: rule plate beside the enemy Operator plate, match intro card | `scripts/ui/score_bar.gd` or `operator_panel.gd`, `match_screen.gd` |
| 7 | **Reward / After-Action / Run End**: Elite Cache header, REQ earned, Threat and unlocks | `scripts/ui/run/reward_screen.gd`, `after_action.gd`, `run_end.gd` |
| 8 | **Codex: Dossier tab** (Terrains, events, bosses) | `scripts/ui/codex/codex_view.gd`, `glossary.gd` |
| 9 | **"New:" cards** for the new reveal flags; screen tests | `scripts/ui/reveal_gate.gd`, `tests/test_run_screens.gd` |

Art (Sr Game Artist, after approval): 10 Terrain icons and band textures, 6 node icons, 3 boss plates, the Bastion-60 Operator art, the Shambler token, the event card frame. Original art only; nothing from `assets/licensed`.

## 12. Risks and levers
| Risk | Sign | Lever (tool knob) |
|---|---|---|
| Traits on v2 decks (Heavy 31.5%, Vanguard 67.8%) | Heavy runs feel hopeless | a trait pass on v2 decks before kc-v2-impl closes (e.g. Heavy 2-set bonus, Vanguard 3-set to +1 FP only), measured with `exps=late tune=…` |
| The first run is kind (27% for a new player, today 21%) | playtests win run 1 without losing a ticket | drop the step-8 Rest in run 1, or Meridian's Supply from round 3 in run 1 (`meridian_supply_from`) |
| Bosses differ (Meridian 40%, Prime 40%, Choir 46% boss fights; by Operator the spread is wider, e.g. Longreach vs Choir) | players pick the Operator by the boss | that is intended (the boss is shown before the Operator is picked); levers: Prime pits in 2 columns (`prime_pits=0,2`: 55%), Choir Shambler from round 1 (`choir_from_round=1`: 32%), Meridian Supply from round 3 / 5 |
| The starter disappears too fast | Standard Issue cards gone by F3 | shop Muster out 3 REQ (`price_remove_si`) |
| Operators in mirror duels (Bastion 59, Wasp 41), Bastion the top run pick (42.1%) | PvP or a future rival Operator | Bastion Cover 0 (`bastion_cover`), Wasp Flashbang −3 (`ab_flash`), Kestrel Dig In Cover 2 (`ab_dig_in`; run +2–3) |
| Terrain feels like noise | players ignore it (the AI's aware edge is 44–54%, i.e. none measurable) | stronger rules within one line (e.g. Smoke also blocks Pierce); keep ±8 |
| Run length (+1–2 fights, +6–8 min) | session data | elites optional already; a 7-step map variant (steps 2 and 8 merged) |
| AI and abilities | the AI spends its ability in round 1 every time | `killstreak_keep_cost` for abilities; the sim uses the planner as is |
| Save format | v6 runs in progress | v6 loads as a first-run map at the matching fight |

## 13. Questions for the head (recommended option first)
1. **The player-facing name of map Fields.** (a) **Terrain** (recommended: never confused with the Field cards you place). (b) "Ground". (c) Keep "Field" ("map Field" vs "your Field").
2. **Operator stat changes and the 4th Operator.** (a) **Approve Bastion-60 (new LMG, 2/8, Cover 1, Covering Fire) and Longreach Armor 5 → 6, Wasp-9 Armor 6 → 7** (recommended: run win 37.5–42.1% each, 47.5–53.9% against the others). (b) Three Operators only (no Bastion). (c) Keep today's stats and accept a wider spread (Longreach 36.7%, Wasp 33.5% in the sim).
3. **How the boss is chosen from run 2.** (a) **Drawn from the unlocked bosses, never twice in a row, shown on the map from step 1** (recommended: plan the run against it, including the Operator). (b) The player picks the boss. (c) A fixed order Meridian → Prime → Choir.
4. **The first run's difficulty.** (a) **Keep it as measured (new player 27% run, M1 71.2%; a solid player 40%)**: the first run teaches the map, with a Rest before the boss (recommended). (b) Remove the Rest before the boss in run 1 (closer to today's 21%; not simulated yet).
5. **The shop's Muster out price.** (a) **2 REQ per Standard Issue card** (recommended: 13.4 of 18 sent home per run, run 40.5%). (b) 1 REQ (the starter is gone by F3; the run gets about 5 points easier). (c) No Muster out in the shop (only after drops, as today).


## 14. Shipped measurements and the kc-v2-tune pass (Mechanics Developer, 2026-11-07)
Measured on the **shipped** code with the ported harness (`tests/tools/run_v2_check.gd`, real RunProgress map runs, 400 runs per row, fixed seeds). Shipped changes beyond §1-§13: enemy crews keep the pre-v2 Wasp-9 (`wasp_9_crew`, Armor 6) so head V2's buff doesn't toughen SandViper / the Choir; the trait pass of head V6 (Vanguard: 2-set +1 FP, no 3-set bonus; Heavy: 2-set Cover +1, 3-set +1 FP).

**Traits on v2 decks (V6, n = 270 each):** Undead 50.4 · Vanguard 51.5 · Heavy 46.3 · Spec Ops 51.9 (before the pass: 51.1 / 63.9 / 37.2 / 47.8).

**kc-v2-tune (head I1 / I2, both answered (a)):** Meridian_Six's Supply from round 5; Kestrel's extra opening card only from F2 on the map (elites and the boss keep it). Bastion-60 stays 2/8 (it measured inside 45-55 against the others).

| Competent, 400 runs per Operator | Run win before | after | vs the others before | after |
|---|---|---|---|---|
| Kestrel AR-7 | 43.0 | 44.8 | 55.2 | 55.1 |
| Longreach .338 | 37.2 | 39.2 | 47.1 | 47.4 |
| Wasp-9 | 40.5 | 42.0 | 51.8 | 51.3 |
| Bastion-60 | 36.2 | 38.2 | 45.7 | 46.1 |

| 400 runs, rotation | before | after |
|---|---|---|
| Run 2+ competent / casual | 40.8 / 22.0 | 42.5 / 22.8 |
| Boss fight Meridian / Prime / Choir (competent) | 30.8 / 44.5 / 50.4 | 35.3 / 45.3 / 50.4 |
| First run competent / casual (new-player F1) | 39.0 / 22.0 (71.2) | 45.0 / 27.0 (71.2) |

Kestrel sits at the edge of the band (55.1, about ±2.5 SE); Meridian is still the hardest boss; the first run got kinder (Meridian is its boss).

## 15. Classic deckbuilder economy (kc-econ, Mechanics Developer, 2026-11-08)
*The head: "start at 1 supply and also draw only one card per turn. Maybe the starting deck should be 10 cards so we see our newly earned cards faster. Shuffle discard if we run out of cards, like classic deckbuilder."*

### 15.1 What changed (shipped)
| | Before | Now |
|---|---|---|
| Supply | round N gives N + 1 (round 1 = 2), cap 7 | **round N gives N** (round 1 = 1), cap 7 (`supply_round_offset` 1 → 0) |
| Draws | opening 4 + 1 in round 1, then **2** per round | opening 4 + 1 in round 1 (free mulligan kept), then **1** per round |
| Operator | 1 Supply to place, round 1 and every respawn | **free in round 1**, 1 Supply per respawn (`RunConfig.operator_free_round1`) |
| Starter | 20 Standard Issue (Grunt 5, Trooper 6, Sergeant 4, Armored 3, Ammo Resupply 2) | **10**: Grunt 3, Trooper 3, Sergeant 2, Armored Trooper 1, Ammo Resupply 1 |
| Deck floor (Muster out, Retire, Drill, Discharge) | 15 | **8** |
| Crews | 18-20 cards | **10 cards each** (every squad and run-slot deck scaled with its composition kept; M2 keeps its one Heavy Gunner; `SquadData.MIN_DECK` 15 → 8) |
| F1 crew (SandViper_07, Standard Issue) | −1 Armor ("green squad"), Grunt-heavy | 0 Armor, a slow heavy deck: Grunt 3, Trooper 2, Armored Trooper 5 |
| Map Armor by fight (`fight_armor_bonus`) | F4 +1 | **F3 +1, F4 +1**; the Mastery crew (slot 4) base Armor 0 → 1 (F4 and Elite II end at +2) |
| Bosses | Meridian +1 Supply from round 5; Prime Armor +1; Choir Armor +2, Shamblers from round 2 | Meridian **from round 4**; Prime **Armor +2**; Choir Armor +2, Shamblers **from round 4** |
| Operators (player) | Kestrel 3/7, Longreach 3/6, Wasp 2/7, Bastion 2/8 | **Kestrel 3/8, Longreach 3/7**, Wasp 2/7, **Bastion 2/6**; the crews keep a crew-only 3/7 Kestrel (`kestrel_ar7_crew`, like `wasp_9_crew`) |
| Sets | v2.1 | v2.2: **Heavy's 2-set = Cover +1 and +1 FP** (3-set +1 FP more); the others unchanged (`synergy-system.md`, kc-econ note) |
| Reshuffle | engine only (DECK_RESHUFFLED event) | unchanged rule (an empty deck takes the shuffled discard pile when you must draw); now **said in the match log** ("Discard shuffled into a new deck (6 cards)", the rival's too) and explained in the DECK badge's inspector |

**The Operator in round 1, measured on the shipped data** (400 runs each; competent run 2+, casual first-run F1): free in round 1 (shipped) **40.5% / 68.8%** · cost 1 always 41.0% / 75.2% · free always 38.0% / 68.0%. The win rates are within noise of each other, so the choice is about the decision: at cost 1, round 1's single Supply buys the Operator and nothing else (§6.3's reason for rejecting cost 2); free in round 1 keeps "Operator + a Grunt or Ammo Resupply", and the respawn cost still makes Operator downs matter.

**Why the crews shrank too:** with 1 draw per round a match draws about 12 cards, so an 18-card crew deck never reshuffles and plays a random 12 of its cards, while the player's 10-card deck cycles its best cards. With the crews at 18-20 cards the mid-run fights fell to the player (F3 97%, F4 87-93%); at 10 cards both sides play the same deckbuilder (F3 85%, F4 67%). Supply and draw rules are the same for both sides.

**Why F1 changed shape:** at 1 Supply in round 1 cheap units decide the opening. The −1 Armor crew (Grunts at 2/1) fell to the new player 79-94% whatever its deck; at 0 Armor a Grunt crew beat them (36-50%). A crew with 5 Armored Troopers (4-drops it can't play early) lands in the band.

### 15.2 Before / after (run_v2_check, 400 runs per row unless noted; fixed seeds)
| Target | Before (shipped kc-v2-tune) | After (kc-econ) |
|---|---|---|
| New player (casual) F1, first run (65–75%) | 71.2% | **68.8%** |
| Competent run 2+, Operators and bosses rotate (38–43%) | 42.5% | **40.5%** |
| Casual run 2+ | 22.8% | 31.2% |
| First run competent / casual | 45.0 / 27.0% | 54.0 / 41.5% |
| Ramp, competent run 2+ (F1 / F2 / Elite I / F3 / Elite II / F4 / Boss) | 96 / 89 / 56 / 89 / 56 / 61 / 44 | 86 / 89 / 79 / 85 / 68 / 67 / 42 |
| Boss fight Meridian / Prime / Choir (competent) | 35.3 / 45.3 / 50.4 | 45.5 / 39.1 / 40.6 |
| Traits, v2 end-of-run decks, n = 270 each (44–56%) | Undead 48.1 · Vanguard 54.1 · Heavy 45.6 · Spec Ops 52.2 | **Undead 50.4 · Vanguard 50.0 · Heavy 51.1 · Spec Ops 48.5** |
| Seat 0, late-deck mirror / Standard Issue mirror (45–55%) | 50.6 / 50.5% | **51.6 / 48.0%** |
| Aware vs blind, same late deck (≥ 55%) | 61.2% | 59.2% |
| Operators, run win (vs the others, 45–55%) | Kestrel 44.8 (55.1) · Longreach 39.2 (47.4) · Wasp 42.0 (51.3) · Bastion 38.2 (46.1) | Kestrel 35.5 (**45.9**) · Longreach 41.8 (**54.7**) · Wasp 36.5 (**47.3**) · Bastion 39.8 (**52.0**) |
| Per run (competent): Standard Issue sent home / deck at the end | 13.8 of 18 / 16.5 | 8.7 of 9 / 11.9 |

"Vs the others" = p·(1−q) / (p·(1−q) + q·(1−p)), q = the other three Operators' mean (§10.4). The Operator, trait and seat rows were measured one step before the last F1 deck tweak (Grunt 3, Trooper 1, Armored 5, Ammo Resupply 1 → Grunt 3, Trooper 2, Armored 5); that tweak only touches F1.

**Read:** the economy is slower and the deck thinner, so the run is front-loaded differently: F1 is a real fight for the competent proxy again (86% instead of 96%), Elite I is easier (79% instead of 56%: the thin deck draws its reward cards), and the boss stays the peak. The first run is much kinder than before (Kestrel 3/8 meets Meridian, whose Supply edge from round 4 is smaller against a 10-card deck). The new player's run doubles from 23% to 31%.

**Tuning path (each a tool default, 200-400 runs):** with only the head's three changes the competent run read 52% and F1 85% (crews at 18-20 cards); shrinking the crews and the F1 deck fixed F1 and the mid-run; the trait pass followed Heavy's collapse (24%); the Choir swung from 15% (Shamblers from round 1 at Armor +2) to 66% (Armor +1), and Shamblers from round 4 at Armor +2 landed at 41%; Bastion read 52-67% vs the others (Cover 1 shrugs off Shamblers) until 2/6.

**New harness options** (`run_v2_check.gd`): `starter=card*n,...` (the run starter, sets deck_size), `edeck=0.5|10` (enemy decks scaled, composition kept), `sdeck=N:card*n,...` (a slot's authored enemy deck), `slot=N.prop=value` (RunMatchData; 6-8 = the bosses), `lset=loadout.prop=value` (an Operator in memory).

### 15.3 Watch items
- **Elite I** (79%) is no longer a gamble; Elite II (68%) is. The lever is `elite_armor_bonus` 1 → 2 (Elite I read 35% there: too steep), or an F3-crew deck change.
- **Kestrel** sits near the bottom of the band (45.9) and is the first-run Operator; **Longreach** near the top (54.7).
- **Prime** (39%) is now the hardest boss and **Wasp** struggles against it (25%).
