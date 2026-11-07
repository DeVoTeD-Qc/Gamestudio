# KillingCard: Run v2 (a run map with paths and bosses, Terrain on the columns, Operators with an ability)

*Author: Sr Game Designer Agent · 2026-11-07 · Board task kc-v2-design · Status: **design for the head's review**. No rules, UI, scene or data file was changed. The sim is the new `source/project-killingcard/tests/tools/run_v2_check.gd`: it plays the real engine (MatchState, FirefightResolver, RunProgress offers, AiPlanner), and everything new (Terrain, bosses, Operator kits, map nodes) lives inside that file as subclasses and hooks.*
*Inputs: `onboarding-progression.md` and `synergy-system.md` with their "Removed" sections (kc-no-training: no Recruit / Trained / Promotion; kc-pos-cut: no neighbour links, no row bonuses, no range bonuses; columns are plain A / B / C), `field-cards.md` (Model B, one Field per side per column, Overrun), `firefight-order.md` (beats, First Shot wins its exchange, Pierce), `card-system.md`, `scripts/run/run_progress.gd`, `reward_offers.gd`, `scripts/data/run_config.gd`, `data/run_config.tres`, the squads in `data/squads/`, the Operators in `data/loadout/`.*
*The head picked three ideas (verbatim): "**3. Run variety:** path choice on the run map (events, shop, elite fight, rest), 2–3 bosses with one unique rule each, and unlockable modifiers such as 'Hardcore'." "**4. Make Fields matter:** now that columns are just A/B/C, give each match 1–2 column Fields that change rules (e.g. 'Rooftops: First Shot here', 'Smoke: no Pick here'), so where you fight is a choice." "**5. Deeper Operator choice:** 3–4 Operators, each with one passive and one once-per-match ability. A different strategy per run without per-card complexity."*

## 0. Summary in seven lines
{{SUMMARY}}

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

**What stays exactly as it is:** the Standard Issue starter (20 cards), traits from the art (one per copy), Doctrine from the first calling card, the reward ladder by card type (units → tactics → Fields → full pool), pick 2 of 4 from F2, Muster out (one Standard Issue card home per card taken, plus one), Salvage after a loss, the green M1 squad (−1 Armor), 3 tickets, the 15-card floor, Field cards (Model B, one per side per column, Overrun), the beat order, the Operator's 1 Supply cost and the progressive reveal ("New: …" cards).

Design pillars for v2:
1. **Every choice shows its price.** A map node shows what it gives and what it risks before you step on it; a Terrain shows its rule on the column before you deploy.
2. **One line per rule.** A Terrain, a boss rule, an Operator passive and an ability each read in one sentence. Nothing changes a unit's printed numbers by where it stands.
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
| **Muster out** a Standard Issue card (any number, floor 15) | 2 each |
| **Discharge** any other card (floor 15) | 3 |
| Perk (if a slot is free; 1 of 2) | 6 |
| Restock the 3 cards | 1 |

- **Muster out stays free after a drop** (one per card taken, plus one). The shop just lets you buy more of it. The price of 2 is the main lever on how fast the starter disappears (§10.3).
- **No tickets in the shop.** Tickets come only from Rest and two events, so the shop can't buy the run back.
- A typical solid run earns about 18–22 REQ and spends 10 in one or two shops: one or two cards and two Standard Issue cards home.

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
- **F1 is exactly today's M1**: no Terrain, and the **Operator's passive and ability switch on at F2** ("New: Operator ability" opens on the F2 board). Measured: new player M1 **{{M1_FIRST}}**.
- **No Terrain until F3**, then 1 Terrain in F3, F4 and Elite I. The boss never has Terrain.
- **The only fork is step 4** (Rest or Elite). The Shop at step 6 is the first shop ("New: Requisition" there; REQ is shown from F1 but explained here).
- **Always Meridian_Six**, the boss the tutorial and the M5 work already point at. Kestrel AR-7 is the only Operator, no modifiers.
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
| **Meridian_Six** (Black Meridian, Spec Ops) | the shipped Rival `enemy_deck` (4 Gunners, 2 Shieldmen, 2 Riflemen, 2 Medics, Anvil, Wren, …) | Zone Control | Armor +1 (as today) | **Reinforcements:** draws 1 extra card every round. | Step 9. Always in the first run; one of three after that |
| **Bulwark Prime** (Anchor, Heavy) | the shipped Bulwark_Nine squad deck (Trained Anchor: Gunners, Protectors, Medics, Hold the Line, Suppressing Fire) | Firefight | Armor +1 | **Dug In:** starts the match with a Mortar Pit in every column. (Overrun tears one down, as for any Field.) | Unlocked after your first run |
| **The Hollow Choir** (Undead) | a new authored deck: Brawler ×4, Point Man ×3, Combat Medic ×2, Flanker ×2, Shieldman ×2, Demolitions Expert ×2, Recon Specialist, Aid Station, War Standard, Hold the Line, Ammo Resupply (20; Undead identity) | Zone Control | Armor +2 | **Horde:** from round 2, a 1/2 Shambler joins the back of its emptiest column every round. Shamblers don't hold ground. | Unlocked after your first boss win |

- **Each rule uses an existing system**, so the player already knows how to answer it: draws (Meridian), Fields and Overrun (Prime), and units that don't count for control (Choir; the Sentry token works the same way). Killing a Shambler counts for your streak.
- **Rotation:** from run 2, the run's boss is drawn from the unlocked bosses, never the same one twice in a row, and it is shown on the map from step 1, so the whole path can be planned against it (e.g. Fields and Pick against the Choir, Overrun pressure against Prime).
- Tuning note: the three bosses differ in how the solid proxy fares ({{BOSS_SPREAD}}). The levers are the boss Armor bonus and the rule's numbers (Prime: pits in 2 or 3 columns; Choir: the Shambler from round 1 or 2).

## 5. Modifiers (5, unlockable, opt-in)
Picked on the Loadout screen before a run, any combination. Each shows its effect in one line and a **Threat** number; the run's Threat total is printed on the map and on the After-Action screen. Winning at a Threat level unlocks cosmetics (§8), never power.

| Modifier | Threat | Effect (one line) | Unlocks after |
|---|---|---|---|
| **Hardcore** | 2 | Start with 2 tickets instead of 3. | Your first run win |
| **Austerity** | 1 | Supply Drops show 3 cards instead of 4 (you still take 2). | Win a run with any 2 Operators |
| **Hot Ground** | 1 | Every fight has one more Terrain (max 2); the boss gets 1. | See all 10 Terrains (Dossier complete) |
| **Veteran Crews** | 2 | F3, F4, elites and the boss get +1 Armor. | Beat all three bosses |
| **Fog of War** | 1 | No red dots for either side. | Win a run with Hardcore |

Measured effects on the competent run are in §10.6.

## 6. Terrain (map Fields on the columns)
**Player-facing name: Terrain** (internally `map_field`). "Field" is already the card type the player places, and two things called Field on one column would be confusing (head question 1). A Terrain is part of the **column itself**, not a card: it belongs to neither side, applies to both, can't be shot, Sabotaged, Overrun or replaced in the match, and never counts for traits.

### 6.1 The pool (10)
| Terrain | Rule (one line, as printed) | What it makes you decide | Sim |
|---|---|---|---|
| **Rooftops** | Whoever holds this column at the start of the round has First Shot here. | Take it early and keep it; arriving into a held Rooftops is expensive | {{T_rooftops}} |
| **Smoke** | No Pick or Flank here: every shot hits the front unit. | Put your Marksman elsewhere; a wall in front is safe here | {{T_smoke}} |
| **Dust Storm** | No First Shot here. | Breachers and Point Men lose their edge; plain bodies trade evenly | {{T_dust_storm}} |
| **Breach Point** | Every unit here has Pierce. | Stack damage here; don't park a stack of fragile cards behind one wall | {{T_breach_point}} |
| **Floodlights** | Red dots here are shown face-up to both sides. | No surprises here: commit where you have the better card | {{T_floodlights}} |
| **Comms Tower** | Hold this column at the end of the round: +1 streak. | A streak race: holding it brings killstreaks sooner | {{T_comms_tower}} |
| **Supply Cache** | Hold this column at the end of the round: +1 Supply next round. | Tempo: hold it early, spend it late | {{T_supply_cache}} |
| **Hot Zone** (Zone Control only) | Holding this column scores 1 extra point. | The match is decided here; the AI fights for it too | {{T_hot_zone}} |
| **Minefield** | Each round, the first unit each side brings here takes 1 damage. | Lead with a cheap or sturdy card; never drop a 2-Armor Marksman in first | {{T_minefield}} |
| **Field Hospital** | End of round: each side's most damaged unit here heals 1. | Long fights favour the side with the bigger Armor pool | {{T_field_hospital}} |

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
| **Kestrel AR-7** | AR · 3 / 7 | **Quartermaster:** your opening hand has 1 more card. | **Dig In:** your units in a column have Cover 1 this round. | the steady all-rounder: more options, one big defensive turn |
| **Longreach .338** | Sniper · 3 / 5 · Pick | **Overpenetration:** the Operator has Pierce. | **Marked Shot:** 3 damage to an enemy unit in the Operator's column. | picks off backliners; one guaranteed removal |
| **Wasp-9** | SMG · 2 / 6 · First Shot | **Run and Gun:** may Rotate twice per round (as today). | **Flashbang:** enemies in the Operator's column lose First Shot and get {{WASP_FLASH}} this round. | moves to where the fight is and wins the one exchange that matters |
| **Bastion-60** (new) | LMG · 2 / {{BASTION_AR}} · Pierce (every LMG) | **Suppressor:** Suppress (the enemy front unit in its column gets −2 FP). | **Covering Fire:** your units in the Operator's column get +1 FP this round. | holds one column; the anchor for Heavy decks |

- **Why these abilities:** each is a one-round version of a tactic the player already knows (Hold the Line, a removal, Suppressing Fire + Blackout, Callout for a column), so it reads at once and the AI already values it. The passives use existing keywords (Pierce, Suppress) or an existing number (opening hand, Rotations).
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
| **Operator camo** | win a run with that Operator (Gilded), then at Threat 2 (Forged), Threat 4 (Priceless), Threat 6 (Interstellar) | the mastery-tier camos the pitch set already has (card-system §2.7); cosmetic only |
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
{{RESULTS}}

## 11. Implementation split (after approval)
{{IMPL}}

## 12. Risks and levers
{{RISKS}}

## 13. Questions for the head (recommended option first)
{{QUESTIONS}}
