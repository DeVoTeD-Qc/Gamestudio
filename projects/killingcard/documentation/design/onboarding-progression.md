# KillingCard: Onboarding and Progression (a plain Standard Issue starter, then traits, then keywords)

*Author: Sr Game Designer Agent · 2026-11-06 · Board task kc-onboard · Status: **approved (N1–N4 all (a)); §8 steps 1–4 and 8 implemented by kc-onboard-impl, see "Implementation notes" at the end; steps 5–7 (UI, tutorial, art) are kc-onboard-ui / art tasks** · No rules, UI, scene or data file was changed. The sim is `source/project-killingcard/tests/tools/onboarding_sim.gd` (real engine, real AI, sim-only cards), run on a snapshot of the working tree that includes the kc-art-traits-impl work in progress.*
*Inputs: `synergy-system.md` (Recruit starter, Retire, Promotion, Doctrine, §11–12), `art-traits.md` (the trait comes from the art; approved), `firefight-order.md` (beats, Pierce on LMG units), `card-system.md`, `scripts/run/*`, `data/run_config.tres`, the squads in `data/squads/`, the tutorial in `data/tutorial/`, and `balance_sim.gd` for today's baseline.*
*The head (verbatim): "The game also feels too complex in first user experience. I think the starter deck should be mostly vanilla cards, which means units with no ability and no trait. Maybe we should use our own generated art for the starter deck, and then as we progress in the roguelite campaign we find the MW3 calling cards that come with a trait. Then we find more cards or upgrades and discover keywords. The goal is that our first deck is simple and somewhat bad, so we can improve it by adding more cards and at some point by removing the starting cards."*

## 0. Summary in six lines
1. **The starter is 20 Standard Issue cards**: 4 vanilla unit designs (cost, FP and Armor only: no keyword, no trait, no weapon class) plus 2 Ammo Resupply. They wear **our own art** in a plain "Standard Issue" look, so they read as basic kit you are meant to replace (§2).
2. **Every copy climbs one ladder**: Standard Issue (plain, never trains) → **calling card · Recruit** (an MW3 card: its trait is on, its keywords are shown but still locked) → **Trained** (keywords on) → Veteran → Elite. "Recruit" changes meaning: today it means "keywords but no trait"; now it means "trait but no keywords" (§3).
3. **One new idea per match.** M1 is vanilla against a vanilla squad. The first Supply Drop brings calling cards (**traits**). M2 brings **keywords** (Trained cards, Promotion) and **Muster out** (each new card sends a Standard Issue card home, plus one extra). M3 brings **Fields**, and M4 brings the Elites. The enemy climbs one step behind you (§4).
4. **The UI shows a system only when it first matters**: the trait rail, keyword pips, link ticks, the Field strip and the Engine panel stay hidden until their first use, and each one opens with a one-time "New: …" card. The tutorial switches to Standard Issue cards and stops teaching First Shot (§5).
5. **Sim (about 100,000 matches):** the new-player proxy wins **M1 70.2%** (today 64%), and its run climbs 70 / 70 / 56 / 30 / 32. For the competent proxy the **full run is 42.8%** (400 runs, ±2.5; today 35%; target 38–40). Aware vs blind on the end-of-run decks is **58.4%** and the first player wins **52.1%** (n = 1000). An end-of-run deck beats the starter **76%** of the time with the same loadout. It takes four changes: the M1 squad gets −1 Armor, Supply Drops from M2 give **2 picks of 4**, each drop sends **one extra** Standard Issue card home, and Anchor+'s Armor bonus goes 1 → 0. The Rival is unchanged (§6).
6. **Implementation in 8 steps** after kc-art-traits-impl: Standard Issue data, the new Recruit meaning in the rules, the squads along the ladder, the run ladder (rung pools, 2 picks, Muster out, Salvage), progressive reveal flags with "New:" cards, the tutorial, the art and a re-measure (§8).

---

## 1. Goals
| Goal | Measure | How this design meets it |
|---|---|---|
| The first match is simple | Rules a player must read in M1 | Cost, FP, Armor, Supply, the columns, the firefight order, the Operator, streaks and the Recon Drone (all taught in the tutorial). **No keyword, no trait, no Field, no link.** |
| The first deck is "somewhat bad" | End-of-run deck vs the starter | The end-of-run deck wins **76%** against the starter with the same loadout (§6.4). Every reward is visibly better than the card it replaces. |
| It still wins the first match | M1 win rate, new-player proxy | **70.2%** (target 65–75%), competent proxy 95% |
| Growth is felt | Standard Issue units left at M5 | 18 → about **10** in an 18-card deck, next to 5–6 calling cards, all Trained by M5 (§6.3) |
| Discovery has an order | One new system per match | Traits (after M1) → keywords and Muster out (after M2) → Fields (after M3) → Elites (after M4) (§4) |
| The run is still a run | Full-run win (competent proxy) | **42.8%** ±2.5 (today 35%, target 38–40; the lever back down is in §7) |
| Skill still matters late | Aware vs blind, same end-of-run deck | **58.4%** (target ≥ 55%) |
| Seats stay fair | Seat 0 win, starter mirror | **52.1%** (n = 1000) |

Design pillars for onboarding:
1. **Learn one thing at a time.** A new system appears only when you can use it, together with one sentence about it.
2. **The starter is a crutch you outgrow.** Standard Issue cards never get better. They exist to be replaced, and replacing them is the visible progress.
3. **Calling cards are the reward.** The MW3 art and its trait are what you earn, and they never appear in the starter.

## 2. The Standard Issue starter

### 2.1 Cards (exact numbers)
| Card | id | Cost | FP / AR | Copies | Text | Compare with (reward chassis at the same cost) |
|---|---|---|---|---|---|---|
| **Grunt** | `si_grunt` | 1 | 2 / 2 | 5 | — | Rifleman 2/2, AR class (+1 at Mid) |
| **Trooper** | `si_trooper` | 2 | 2 / 3 | 6 | — | Point Man 2/3 First Shot, Brawler 2/3 Shotgun |
| **Sergeant** | `si_sergeant` | 3 | 3 / 3 | 4 | — | Breacher 3/4 First Shot, Shotgun |
| **Armored Trooper** | `si_armored` | 4 | 2 / 5 | 3 | — | Gunner 2/6 Suppress, Pierce |
| Ammo Resupply | `ammo_resupply` (existing) | 1 | — | 2 | Draw 2. | (the existing card, in a Standard Issue art) |

- **18 vanilla units and 2 copies of one tactic.** Ammo Resupply is the simplest tactic and fixes floods. Hold the Line, Callout, Flank Route and the rest move to the reward pool (most are already there).
- **Each design is one stat point worse** than the reward chassis at its cost, or it lacks the keyword and weapon class. So **every calling card is an upgrade on the card it replaces**, even before its keywords train.
- **No weapon class** means no hidden range bonus (SMG +1 at Close, Shotgun +2 / −1, AR +1 at Mid). The first board has no invisible math. Weapon classes arrive with the calling cards, where the art shows the weapon.
- **Never a trait and never a keyword.** Standard Issue cards can't train, can't be Promoted and can't be Re-issued. Their only exit is Muster out or Retire (§4.3). `trait_options` is empty, and they are `collectible = false`, so they're never in the reward pool and never in the Codex album.
- **The same starter every run** (the roguelite norm). Only the first-time explainers are per profile (§5).
- **The Armored Trooper is the deliberate weak spot**: a clunky 4-drop, and the obvious first card to send home. The Grunt is the best Standard Issue card (a cheap body for the curve). The sim shows the difference: sending Armored Troopers (or Troopers) home first wins 11–13 points more runs than sending Grunts home first (§6.3). The reward screen suggests the right one by default.
- Tested alternatives, M1 vs the Standard Issue Rusher (new-player / competent proxy): this list 69 / 91% with the M1 squad at −1 Armor (n = 160), 34 / 79% with the squad at 0 Armor (n = 80), and a stronger list (Trooper 2/4, Sergeant 3/4) 47 / 79% at 0 Armor (n = 160). The M1 lever is the squad, not the starter (§6.1).

### 2.2 Look: "Standard Issue" (our own art)
| Element | Standard Issue | Calling card (reward) |
|---|---|---|
| Art | Our generated art (public build and pitch build alike): one flat two-tone soldier silhouette per role, olive drab and khaki, on a canvas / supply-crate background | MW3 calling card (pitch) or our own family art (public), per art-traits §1.4 |
| Frame | Matte grey-green frame, stencil lettering, a serial plate "SI-01" … "SI-04", no foil, no camo band; the trait and weapon slot (bottom left in card layout v3, kc-trait-ui) stays empty | The banner frame with the trait icon and weapon in the bottom-left slot, and the camo band for the level |
| Name / subname (details) | "Grunt" / "Standard Issue" | "Breacher" / "Lockwood 680 Mastery" |
| Animation | None | Animated arts keep their loop |
| Family | `standard_issue` (a new family: no trait, not an album family) | Honors / Operators / Mastery / Horde / Standard |

- The Sr Game Artist makes **5 arts** (4 units and the Standard Issue Ammo Resupply) with `tools/gen_card_art.py` and the existing banner pipeline. They must read as "basic" at phone size: low contrast and no glow, so the first calling card visibly pops next to them.
- The **Standard Issue squads** (§4.4) wear the same arts with a red serial plate, so the enemy in M1 is plainly as basic as you are.
- IP: all original, safe for the public build (card-system §6).

## 3. The card ladder (per copy)
| Level | Name on the card | Comes from | Trait | Keywords (printed, neighbor, effects, LMG Pierce) | Frame / band | Next step |
|---|---|---|---|---|---|---|
| — | **Standard Issue** | The starter | never | never | Standard Issue frame | Muster out / Retire only |
| 0 | **Recruit** (calling card) | The M1 Supply Drop, Salvage after an M1 loss, enemy squads in M2–M3 | **on** (from the art, art-traits §1) | **shown greyed, locked**: "Trains: First Shot · Guard" | banner frame, no band | Promotion (or the kit hand-over option, §4.3) |
| 1 | **Trained** | Supply Drops from M2 on, Promotion | on | **on** | Gilded | Promotion |
| 2 | Veteran | Promotion | on | on, +1 Armor | Forged | Promotion |
| 3 | Elite | Promotion | on | on, +1 Armor +1 FP | Priceless | — |

- **"Recruit" changes meaning.** Today (kc-syn) a Recruit has its printed keywords but no neighbor keyword and no trait. In this design, a Recruit has its **trait** but **none** of its rules text: no First Shot, Pick, Flank, Cover, Suppress, Patch, Holder, arrive-front, On Deploy / On Down effect, neighbor keyword or LMG Pierce. It keeps the chassis' cost, FP, Armor and weapon class. That's exactly the head's order: the art brings the trait first, and the keywords are discovered next.
- The greyed "Trains: …" line is the **discovery hook**. A Recruit Breacher in hand shows "Trains: First Shot · Guard". The first Promotion lights it up with the "New: Keywords" card (§5).
- **Why no 2-tier Recruit (trait-only and keyword-only)?** Today's Recruit level only existed because the starter needed plain copies of real chassis. Standard Issue cards now do that job, so the level can take the new meaning without adding a state.
- Rules impact: `SynergyRules.trait_at` returns the trait for level 0 too, and `match_state.create_unit` clears the keywords at level 0. Details in §8.

## 4. The discovery ladder through the run

### 4.1 Match by match
| | Enemy (what you face) | New for you in the match | After the match (offers in order) | "New:" card |
|---|---|---|---|---|
| **Tutorial** (optional, before run 1) | TrainingBot_01, Standard Issue | Deploy, Supply, red dots, columns, the beat order, the Operator, streak → Recon Drone | — | (the tutorial itself) |
| **M1** Bracket 1, Zone Control | **SandViper_07 · Standard Issue crew**: Standard Issue cards, **−1 Armor** ("green squad" tag on the run map) | Nothing new: the tutorial's rules with your 20 Standard Issue cards | Win: **Supply Drop · Calling cards**: 3 Recruit calling cards (units only, no Elites), pick 1. Your first calling card sets your **Doctrine** (no separate screen). Loss: **Salvage**: the same with 2 cards. Then the weapon level (as today). | **New: Calling cards & Traits**, which also covers Doctrine |
| **M2** Bracket 1, Zone Control | **Bulwark_Nine · Standard Issue crew** with **3 Heavy Recruits** (Gunners), so the enemy's trait rail appears | Your first trait in play: the trait rail and the set counter ("Heavy 1/3") | Win: **Supply Drop**: **Trained** cards (keywords) and simple tactics, **pick 2 of 4**, then **Muster out**. Loss: Salvage (2 cards, pick 1, Muster out). Then **Promotion** (your Recruit trains), then a Perk. | **New: Keywords** (at the first Trained card or the Promotion), **New: Muster out** |
| **M3** Bracket 2, Firefight | **SandViper_07 · Honors crew**: the real Rusher deck as **Recruit calling cards** (Vanguard traits, no keywords) | Keywords on your side, Vanguard sets on theirs | Supply Drop **+ Fields** in the pool (pick 2 of 4, Muster out), or Salvage. Weapon level. | **New: Fields** (at the first Field offered); keyword tips at first play |
| **M4** Bracket 2, Firefight | **Bulwark_Nine · Mastery crew**: the real Anchor, **Trained** (keywords, links, Pierce, Heavy identity), Armor bonus **0** (today 1) | Enemy links and Pierce | Supply Drop **+ Elites**, the full pool (pick 2 of 4, Muster out), or Salvage. Promotion, weapon level, Perk. | **New: Links** (the first time a neighbor keyword links, on either side) |
| **M5** Rival, Zone Control | **Meridian_Six · Operator crew**: as shipped (Trained, Spec Ops identity, Armor +1) | Everything | Run end | — |

- **The enemy is one step behind you.** You get traits after M1, and the squads show traits in M2–M3. You get keywords after M2, and the squads show them in M4. So when something new appears on the enemy side, you've already met it on your own cards.
- **Rungs are pools, not scripts.** Each Supply Drop draws from `reward_pool` filtered by rung (§4.2), with the existing on-trait slot (slot 1 is on your main trait) and the art-traits dressing (home art 60%, alternate 40%). Repeat runs feel different, but the order of discovery is always the same.
- **The camo band, Re-issue and the Engine panel** arrive with the first Promotion (after M2). Before that, none of them is shown.

### 4.2 Reward pools by rung (filters on today's `reward_pool`, no new cards)
| Rung | Offered after | Pool (copies as in `run_config.tres`) | Level |
|---|---|---|---|
| 1 · Calling cards | M1 (win, or Salvage) | Units except Elites: Point Man, Breacher, Protector, Flanker ×2, Recon Specialist, Marksman, Gunner, Demolitions Expert ×2, Brawler ×2, Combat Medic | **Recruit** |
| 2 · Keywords | M2 | Rung 1 + tactics: Callout ×2, Ammo Resupply, Flank Route ×2, Suppressing Fire ×2, Hold the Line, Breach and Clear ×2 | Trained |
| 3 · Fields | M3 | + Fields: Tripwire ×2, Comms Relay ×2, Listening Post, Mortar Pit, Bulwark, War Standard, Sniper Perch, Aid Station | Trained |
| 4 · Full | M4 | + Elites: Commander ★, Ace ★ | Trained |

Smoke Screen, Blackout and Sabotage (card-system §3.1) are not in the shipped pool and stay out.

### 4.3 Removing the starting cards: Muster out, Retire, Salvage
| Action | When | What it does | Why it's attractive |
|---|---|---|---|
| **Muster out** (new, recommended) | After every Supply Drop or Salvage **from M2 on** | Each card you take sends one Standard Issue card home, **plus one more**, for free (2 picks → up to 3 Standard Issue cards out). The screen pre-selects the most expensive Standard Issue units (Armored Troopers first) and shows "Grunt SI-01 → home"; the player can change the selection or keep a card. The deck shrinks by one per drop, never below 15. | No opportunity cost: you get the new cards **and** lose weak ones. It's the head's "remove the starting cards" as one screen, and it touches only Standard Issue cards, so the framing is clear: the quartermaster takes back the basic kit. |
| **Retire** (exists, kc-syn) | The 4th Supply Drop option, any card, as today (under "More") | Removes a card instead of taking one (15-card floor) | Still there for thinning calling cards you no longer want |
| **Salvage** (replaces Regroup) | After a loss (M1–M4) | A 2-card Supply Drop of the current rung, pick 1 (Muster out from M2 on) | A loss still moves the deck forward. Today's Regroup (a free Retire) does little for a Standard Issue deck: Salvage instead of Regroup is worth about +10 points of run win (§6.3). |
| Twin training (kc-syn) | — | **Retired**: the starter has no Recruit twins any more | — |
| Kit hand-over (option, not for v1) | Retire of a Standard Issue card | One of your Recruit calling cards trains for free | Kept as a lever in case Recruits stay untrained (they don't in the sim: the M2 Promotion trains them) |

- **2 picks per Supply Drop from M2 on** (4 shown, pick 2, slot 1 on-trait). With 1 pick (and one card out per pick), the end-of-run deck still has 15 Standard Issue cards and the run drops to 30% (§6.3). Five matches is a short run, so each drop has to move the deck more than one fight does in a 15-fight roguelite.
- **The "+1" matters**: without it the run is 34.5%, and with it 42.8% (400 runs each). Thinning out Standard Issue cards is real progress, and the sim confirms it.
- **What you send home is a decision.** Sending Grunts home first (the cheap, efficient body) costs 11–13 points of run win against sending Armored Troopers or Troopers first. That's a small, readable skill lesson, so the default pre-selection is the Armored Trooper.

### 4.4 Enemy squads along the ladder
| Slot | Squad | Deck | Levels / traits | Scaling | Change vs today |
|---|---|---|---|---|---|
| 1 | SandViper_07 (Rusher) | **Standard Issue**: Grunt 5, Trooper 7, Sergeant 3, Armored Trooper 1, Ammo Resupply 2 (18) | no traits | **Armor −1** | new deck (today: the Rusher deck as Recruits) |
| 2 | Bulwark_Nine (Anchor) | **Standard Issue + 3 calling cards**: Grunt 1, Trooper 4, Sergeant 3, Armored Trooper 4, Ammo Resupply 1, Hold the Line 2, **Gunner ×3 as Heavy Recruits** (18) | Heavy on the 3 Gunners | 0 | new deck |
| 3 | SandViper_07 (Rusher+) | the shipped Rusher deck | **Recruit calling cards** (new meaning): Vanguard identity, no keywords | 0 (as today) | today: Trained |
| 4 | Bulwark_Nine (Anchor+) | the shipped Anchor deck | Trained, Heavy identity | **0** (today 1) | −1 Armor |
| 5 | Meridian_Six (Rival) | shipped | Trained, Spec Ops identity | 1 (as today) | none |

- Squad AI personalities stay as shipped. A sloppier M1 AI (second-best chance 0.35) did nothing measurable (§6.1).
- Tested and not needed: Rival Armor 0 (too easy: M5 50–53%; with 2 Riflemen → 2 Gunners on top, 41–53% depending on the Muster out rule), M3 at −1 Armor (M3 63% competent but 92% casual, a bump rather than a ramp), and M2 as pure Standard Issue (the new player does worse there, 60% vs 70%, and the first enemy trait comes later).

## 5. Progressive reveal (UI and rules appear when first relevant)

### 5.1 Rules
- **Profile flags, not per run.** `ProfileFlags.seen` (in the settings save) stores each "New:" card the player has seen. The starter, the ladder and the squads are the same every run. Only the explainers are one-time. A "Reset tips" switch in Settings clears the flags.
- **One "New:" card at a time**: a half-screen card with the icon, one sentence, a mini example and "Got it". It shows **at the moment of use** (the reward screen, or the first board where the thing is in play), never in a menu. Several triggers at once queue up, at most one per screen.
- **Hidden doesn't mean off.** An element is hidden only while nothing on the board uses it. The enemy can never use something that's hidden from you: the trait rail appears when the first traited unit of **either** side is in play.

### 5.2 What appears when
| UI / rule | Hidden until | "New:" card text (one sentence) |
|---|---|---|
| Hand, Supply, columns, red dots, Operator, streak arc, Recon Drone | always on (tutorial) | — |
| Lethal / Tactical buttons | always on; a coach mark the first time each is ready in M1 | "New: Frag Grenade. Your Operator's grenade: 2 damage at the front. It recharges." |
| Killstreak choice on the Loadout screen | run 2 (run 1 uses the defaults: Recon Drone, Mortar Barrage, Attack Helo, and skips the Loadout screen) | "New: Loadout. Pick your three killstreaks before a run." |
| Trait icon on cards, the subname with the art title | the first calling card offered | **New: Calling cards.** "Calling cards bring a trait. 2 or 3 of a trait in play give a bonus. Your first one's trait is your Doctrine: it counts +1." |
| Doctrine emblem on the Operator plate | the first calling card picked | (in the same card) |
| Trait rail and set callouts | the first traited unit in play (either side) | **New: Traits.** The rail's own tier text ("Heavy 1/3: …") |
| Locked keyword line ("Trains: …") | shown on Recruits from the start (it's the teaser) | — |
| Keyword pips and stat deltas (▲) | the first Trained card offered, or the first Promotion | **New: Keywords.** "Trained cards have keywords. Your Breacher now has First Shot." |
| Per-keyword tip (First Shot, Pick, Flank, Pierce, Suppress, Patch, Cover, Protector slide, On Deploy / On Down, Holder) | the first time that keyword is in play on either side | One line each (the card text / `SynergyRules.KEYWORD_TEXT`) |
| Link ticks and placement preview | the first time a neighbor keyword links (either side) | **New: Links.** "Guard: the card behind this one has Cover +1." (with the mini-grid) |
| Camo band, Promotion screen | the first Promotion (after M2) | **New: Promotion.** "Promotion trains a card. Gilded → Forged → Priceless." |
| Muster out step | the first Supply Drop from M2 on | **New: Muster out.** "The quartermaster takes back Standard Issue kit: one card per new card, plus one." |
| Retire (4th option), Re-issue | the first Supply Drop from M2 on (under "More") | — |
| Field strip on the objective | the first Field offered or in play (either side) | **New: Fields.** "Fields sit on the objective and change the whole column." |
| Engine panel in the deck view | the first Promotion | — |
| Elite frame | the first Elite offered | "New: Elites. One of a kind, with a printed trait." |

### 5.3 The tutorial, aligned
- **Decks:** the player gets Grunt / Trooper / Sergeant (Standard Issue). TrainingBot_01 becomes Standard Issue too: 8 Grunts, 3 Troopers, 2 Sergeants and 2 Armored Troopers, instead of Rifleman / Point Man / Marksman / Combat Medic.
- **Steps 1–6 stay** (Operator, red dots, "Tap Grunt, then Left", READY, the fight, streak 1).
- **Steps 7–9 change** from "Point Man has First Shot" to the beat order: "Sergeant hits for 3. In each column the front cards trade shots, and when one falls, the card behind steps up." (card `si_sergeant`; the scripted board shows a line advance.)
- **Steps 10–17 stay** (Recon Drone, scoring, the final fight).
- First Shot is no longer taught in the tutorial. Its own keyword tip teaches it the first time it's in play (§5.2), which in a normal run is M2–M3.

## 6. Sim results
**Harness:** `tests/tools/onboarding_sim.gd`, built like `synergy_check.gd` / `art_traits_sim.gd` on the shipped engine (MatchState + SynergyRules + AiPlanner, synergy-aware on both sides; squads use `AiPlayer.for_squad`). Standard Issue cards and Recruit calling cards (the new meaning) are sim-only CardData objects, and traits go through `SideSetup.deck_traits`.
**Full runs** are the sim's own 5-match loop: 3 tickets, a loss costs one, and the run ends at 0 tickets or after M5. Offers follow §4: rung pools, the on-trait slot, the 60/40 art roll, Doctrine = the first pick's trait. Promotion after M2 and M4 trains the best Recruit, otherwise it levels the best on-trait unit. The weapon level after M1/M3/M4 and the Perk after M2/M4 take option 0. Picks follow balance_sim's rule: the on-trait unit, else the most expensive unit. Muster out removes Standard Issue units in a set order while the deck has ≥ 18 cards, plus the extra one (floor 15).
**Proxies:** balance_sim's *competent* (a solid player) and *casual* (second-best plan 60% of the time, holds cards: the new-player proxy). Today's baseline is `balance_sim.gd` (the real `RunProgress`, synergy offers on), on the same snapshot.
Run: `godot --headless --path . -s res://tests/tools/onboarding_sim.gd -- exp=slots|runs|mirror|all n=N runs=N [options]`. The recommended package:
`exp=runs runs=400 n=80 slotset=1.enemy_armor_bonus=-1 slotset=4.enemy_armor_bonus=0 picks=2 thin=1 enemy=si,si+cc,cc,shipped,shipped replace_order=armored,sergeant,trooper,grunt`
**Statistics:** 400 runs give ±2.5 points SE on the run win rate, and 200 runs give ±3.5. Slot rows with n = 120–160 give ±4. Seeds are fixed, so rows that share their first 200 seeds share their first 200 runs (the 200-run rows read about 4 points higher than the 400-run rows of the same setting). Raw outputs are in the session scratchpad (not committed).

### 6.1 Match 1 (target: new-player proxy 65–75%)
| Setup (vs SandViper_07 in M1) | New player (casual) | Competent | n |
|---|---|---|---|
| **Today**: Recruit starter vs the Recruit Rusher (balance_sim, in-run M1) | 64% | 78% | 200 runs |
| Today's starter kit, fixed slot | 72.5% | 71.2% | 80 |
| Standard Issue starter vs a Standard Issue Rusher, Armor 0 | 33.8% | 78.8% | 80 |
| … with a cheaper squad deck (Grunt 8, Trooper 6, Sergeant 2) | 34.2% | 68.3% | 120 |
| … with that deck and a sloppier squad AI (second-best chance 0.35) | 30.8% | 70.0% | 120 |
| … with a thin squad deck (6 Grunts, 4 Troopers, 6 tactics) | 56.2% | 83.8% | 160 |
| … with a stronger starter (Trooper 2/4, Sergeant 3/4) | 46.9% | 79.4% | 160 |
| … without Lethal / Tactical, Recon Drone only, both sides (M1–M2 "lite") | 15.8% | 40.0% | 120 |
| **Recommended: the squad at Armor −1** | **68.8%** (in-run 70.2%) | 90.6% (in-run 94.8%) | 160 / 400 runs |

- **A vanilla mirror is a skill test.** With equal decks, the squad AI (close to competent) beats the casual proxy two games out of three, and a vanilla board has no swingy card for a weaker player to lean on. So M1 needs a real handicap on the squad, not a weaker player deck. **−1 Armor** is the cleanest one: it uses the existing `enemy_armor_bonus` (Ruling 11 already scales squads that way), and the run map can show it as "green squad".
- **Keep the Operator kit in M1.** Removing Lethal, Tactical and two killstreaks from both sides hurts the player badly, because the player proxy uses its kit better than the squads do. Teach the kit with coach marks instead (§5.2).
- M1 rounds: 5.0–5.2 per match with the −1 Armor squad (today 5.6–5.7). The first match is slightly shorter.

### 6.2 The run: per-match win rates (target: competent run 38–40%, a smooth ramp)
| Setup | Runs | Competent: run | M1 / M2 / M3 / M4 / M5 | Casual: run | M1 / M2 / M3 / M4 / M5 |
|---|---|---|---|---|---|
| **Today** (balance_sim, Recruit starter, real RunProgress) | 200 | **35%** | 78 / 98 / 36 / 27 / 38 | 36% | 64 / 84 / 54 / 27 / 44 |
| Standard Issue, 1 pick, Regroup = free Retire, squads as shipped from M3 | 200 | 14.5% | 95 / 98 / 16 / 6 / 15 | 5.0% | 70 / 66 / 49 / 7 / 7 |
| + M3 squad as Recruit calling cards | 200 | 14.0% | 95 / 98 / 28 / 5 / 15 | 8.0% | 70 / 66 / 52 / 6 / 11 |
| + Salvage after a loss + each pick sends a Standard Issue card home (Grunts first) | 200 | 24.5% | 95 / 98 / 32 / 11 / 26 | 19.5% | 70 / 70 / 58 / 7 / 26 |
| + 2 picks from M2 | 200 | 25.5% | 95 / 98 / 38 / 14 / 27 | 16.0% | 70 / 70 / 56 / 11 / 22 |
| + send Armored Troopers home first, Anchor+ Armor 0 | 400 | 34.5% | 95 / 98 / 28 / 39 / 36 | 20.0% | 70 / 70 / 56 / 33 / 25 |
| … + Salvage with 3 cards | 400 | 35.8% | 95 / 98 / 29 / 40 / 37 | 17.0% | 70 / 70 / 54 / 35 / 22 |
| … + the extra Standard Issue card out only from M4's drop | 400 | 35.8% | 95 / 98 / 28 / 39 / 37 | 20.5% | 70 / 70 / 56 / 33 / 26 |
| … + the extra one from M3's drop | 400 | 36.2% | 95 / 98 / 28 / 36 / 38 | 22.0% | 70 / 70 / 56 / 28 / 28 |
| **Recommended: … + the extra one from M2's drop (Muster out)** | 400 | **42.8%** | **95 / 98 / 33 / 38 / 44** | **25.2%** | **70 / 70 / 56 / 30 / 32** |
| Recommended + M3 squad at Armor −1 | 400 | 42.5% | 95 / 98 / 68 / 40 / 43 | 28.5% | 70 / 70 / 90 / 33 / 32 |
| Without the extra one, M3 at Armor −1 | 400 | 37.8% | 95 / 98 / 63 / 39 / 39 | 22.5% | 70 / 70 / 92 / 31 / 25 |
| 2 picks, Grunts home first, Anchor+ and Rival Armor 0, Rival 2 Riflemen → 2 Gunners | 200 | 40.5% | 95 / 98 / 38 / 35 / 41 | 26.0% | 70 / 70 / 56 / 32 / 34 |
| Same, Rival Armor 0 without the swap | 200 | 49.0% | 95 / 98 / 38 / 35 / 50 | 31.5% | 70 / 70 / 56 / 32 / 41 |

- **The run lands at 42.8%** (competent, ±2.5), at the top of the target band. M3–M5 run 33 / 38 / 44%, a rising slope instead of today's 36 / 27 / 38 with its M4 dip. The cliff after M2 (98 → 33%) has the same shape as today's (98 → 36%): it marks the step from Bracket 1 to Bracket 2, and the competent proxy is known to play Firefight (the mode of M3–M4) worse than Zone Control. The new-player proxy sees a gentler 70 / 70 / 56 / 30 / 32.
- **The extra card out after M2 is the swing** (34.5% → 42.8%): a Standard Issue deck is held back by its Standard Issue cards. Starting the extra from M3 instead lands at 36%, the lever if playtests find runs too easy.
- **The new player wins a full run 25% of the time** (today 36%). That's lower, and expected: today's casual proxy is carried by its starter's keywords, while a Standard Issue run is won by what you add, and a sloppy player adds less well. Watch first-run churn in playtests. Levers: a first-run extra ticket, or the pre-selected Muster out (§7).
- **The ladder itself costs nothing:** giving M1's rewards as Trained cards (keywords on at once) instead of Recruits leaves the competent run unchanged (40.5% vs 40.5%, 200 runs, older package). The Recruit step is a teaching step, not a balance step.

### 6.3 How much rewards and Muster out move the deck
| Package | Runs | Cards added / run | Standard Issue cards sent home / run | Deck at M5: size · Standard Issue · calling-card units | Aware vs blind, end decks | Competent run |
|---|---|---|---|---|---|---|
| 1 pick, Regroup = free Retire (kc-syn rules) | 200 | 1.2 | 2.7 | 18.5 · 15.2 · 1.2 | 52.1% | 14.5% |
| 1 pick, Salvage, one out per pick (Grunts first) | 200 | 3.9 | 2.9 | 21.0 · 15.0 · 4.0 | 57.5% | 24.5% |
| 1 pick, Regroup, one out per pick | 200 | 2.3 | 3.0 | 19.4 · 15.0 · 2.4 | 53.3% | 15.0% |
| 2 picks, Salvage, nothing sent home | 200 | 5.5 | 0 | 25.6 · 18.0 · 5.4 | 55.4% | 48.0% † |
| 2 picks, one out per pick, Grunts first | 200 | 5.7 | 4.7 | 21.0 · 13.3 · 5.5 | 60.4% | 40.5% † |
| 2 picks, one out per pick, Armored Troopers first | 200 | 5.6 | 4.6 | 21.0 · 13.3 · 5.5 | 57.9% | 52.0% † |
| 2 picks, one out per pick, Troopers first | 200 | 5.6 | 4.6 | 21.0 · 13.3 · 5.5 | 60.0% | 54.0% † |
| 1 pick, one out per pick, Armored first, Anchor+ Armor 0 | 200 | 4.0 | 3.0 | 21.0 · 15.0 · 4.0 | 57.5% | 30.0% |
| **Recommended: 2 picks + Muster out (one per pick + 1), Armored first, Anchor+ Armor 0** | 400 | **5.7** | **7.6** | **18.0 · 10.3 · 5.5** | **58.4%** | **42.8%** |

(† with the Rival at Armor 0 and 2 Riflemen → 2 Gunners, so these rows compare with each other, not with the recommended row.)

- **The deck grows into calling cards.** With the recommended package, the M5 deck has 5–6 calling cards (all Trained: the M1 Recruit trains at the M2 Promotion), 10 Standard Issue units and the 2 Ammo Resupply. It beats the starter **76.2%** with the same loadout (n = 320). Synergy-system §7.4 measured 53–76% for its late decks vs its Recruit starter.
- **Salvage is the biggest growth lever** (1.2 → 3.9 cards a run), because a run that loses M3 still gets a card instead of only a removal.
- **Sending cards home pays only if you send the right ones.** Keeping every Standard Issue card (25-card decks) beats sending Grunts home (48 vs 40.5%), and sending Armored Troopers or Troopers home beats both (52–54%). Hence the pre-selection in §4.3.

### 6.4 Seats, planning and growth (recommended package)
| Check (target) | Result | n |
|---|---|---|
| Seat 0, Standard Issue mirror (≈ 50%) | **52.1%** | 1000 |
| Seat 0, end-of-run deck mirror | 53.1% | 160 |
| Aware vs blind, same end-of-run deck (≥ 55%) | **58.4%** | 320 |
| End-of-run deck vs the starter, same loadout | **76.2%** | 320 |

- A Standard Issue mirror has no keywords and no traits, so the only seat edge is that seat 0 sees the red dots and wins initiative ties. It stays inside the band.
- The planning edge on end-of-run decks (58.4%) is above today's art-traits package (55.9%). The decks hold fewer engine cards, but each link and set the planner forms counts for more.

### 6.5 What the sim doesn't cover
The real `RunProgress` (this loop reimplements the offers with balance_sim's pick rule), Re-issue, Retire as a separate option, Veteran / Elite beyond the M4 Promotion, a chosen Doctrine (the sim takes the first pick's trait), maps other than Port Vasel, and human learning (M1 is the first match only for the first run). `balance_sim.gd` must be re-run once §8 lands.

## 7. Risks and levers
| Risk | Sign in playtests | Lever (in order) |
|---|---|---|
| Runs too easy for good players (42.8%, top of the band) | Competent run win > 42% on the real build | The extra Muster out card only from M3 (36%); Anchor+ Armor back to 1 |
| M1 too easy for veterans (95% competent) | Experienced players click through M1 | Fine for M1. If needed, give "green squad" (−1 Armor) only to the first run |
| New players quit after a lost first run (25% run win) | Run-1 completion | A first-run extra ticket; Salvage with 3 cards; a hint on the Muster out screen |
| Players keep their Standard Issue cards | Standard Issue units at M5 > 12 | Pre-selection on by default; a Standard Issue counter in the deck view |
| Recruits stay untrained | Recruits at M5 > 1 | The kit hand-over on Retire (§4.3), or a third Promotion after M3 |
| Standard Issue art reads as "unfinished" | Survey | The serial plate and crate frame have to look deliberate (military issue), not placeholder |

## 8. Implementation list (ordered to follow kc-art-traits-impl)
| # | Task (owner) | What | Where | Size |
|---|---|---|---|---|
| 1 | **Standard Issue data** (Mechanics Developer) | 4 new `CardData` (`si_grunt` 1 · 2/2, `si_trooper` 2 · 2/3, `si_sergeant` 3 · 3/3, `si_armored` 4 · 2/5; `weapon_class = NONE`, empty `trait_options`, `collectible = false`); `CardData.standard_issue: bool` (frame, Muster out target, never trains / promotes / re-issues; validator); the starter list in `run_config.tres` (§2.1); `starter_recruits` removed (or false); the art family `standard_issue` | `card_data.gd`, `data/cards/si_*.tres`, `run_config.tres`, `gen_content.gd`, `data_validator.gd` | data + ~20 lines |
| 2 | **Recruit = trait without keywords** (Mechanics Developer) | `SynergyRules.trait_at` gives level 0 its trait; `keyword_at` stays Trained+; `create_unit` at level 0 clears first_shot / pick / flank / cover / suppress / pierce (incl. the LMG rule) / patch / holder / arrives_front / effects; AI records read the unit, so the planner follows; `RulesCard` text "Trains: …" for the inspector; tests (today's Recruit tests flip) | `synergy_rules.gd`, `match_state.gd`, `rules_card.gd`, `tests/test_rules_synergy.gd` | ~30 lines, ~10 tests |
| 3 | **Squads along the ladder** (Mechanics Developer) | `RunMatchData.enemy_deck` (an authored deck override per slot) and `enemy_recruits` (units at level 0, now trait without keywords); slot 1 Standard Issue Rusher at Armor −1; slot 2 Standard Issue Anchor + 3 Gunners at level 0; slot 3 the Rusher at level 0; slot 4 Armor 0; TrainingBot Standard Issue | `run_match_data.gd`, `side_setup.from_squad`, `run_config.tres`, `squad_tutorial.tres` | ~25 lines + data |
| 4 | **Run ladder** (Mechanics Developer) | `RunConfig.reward_rungs` (per match: a filter on `reward_pool` (units / + tactics / + Fields / all) and the level (Recruit or Trained)), read by `RewardOffers.supply_drop_on_trait`; `supply_drop_picks_from = 2` (4 shown, pick 2: one offer with `picks: 2`); **Muster out** (`KIND_MUSTER_OUT`, queued after a Supply Drop or Salvage from M2: picks + 1 Standard Issue copies, pre-selected most expensive first, floor 15; `muster_out(indices)`); **Salvage** (`KIND_SALVAGE`, 2 cards) replaces Regroup; Doctrine = the first calling card's trait (`doctrine_after_matches` empty, set on the first pick); twin training off; save version 4 | `run_config.gd`, `reward_offers.gd`, `run_progress.gd`, `tests/test_run_*.gd` | ~100 lines, ~15 tests |
| 5 | **Progressive reveal** (UI/UX agent) | `ProfileFlags` (`seen: {flag: true}` in the settings save) and `RevealRules.visible(flag, match_view)`; a "New:" card component (queue, one per screen); hide / show for the trait rail, keyword pips, link ticks, placement preview, Field strip, Engine panel, camo band, Retire / Re-issue options and the Loadout screen in run 1; per-keyword first-play tips; the Standard Issue frame and serial plate; reward screen "pick 2 of 4", the Muster out screen and the Salvage view | `scripts/ui/*`, `scripts/ui/run/reward_screen.gd`, `engine_panel.gd`, `trait_rail.gd`, `banner_card.gd`, new `scripts/ui/new_card.gd`, the settings autoload | UI task |
| 6 | **Tutorial** (UI/UX agent + Mid Game Designer) | Standard Issue decks; steps 7–9 rewritten for the beat order with `si_sergeant`; the First Shot text moves to the keyword tip | `data/tutorial/tutorial_script.tres`, `squad_tutorial.tres`, `tutorial_director.gd` | data + small |
| 7 | **Art** (Sr Game Artist) | 5 Standard Issue arts (4 units + Ammo Resupply) and the red-plate enemy variant; the Standard Issue frame | `tools/gen_card_art.py`, `BannerArtDB` | art |
| 8 | **Re-measure** (Mid Game Designer) | `balance_sim.gd` (runs, both proxies; its offer rule needs a Muster out rule: most expensive Standard Issue first) and `art_traits_sim.gd` (duel, mirror) on the real build; compare with §6 | `tests/tools/` | sim |

Order notes: steps 1–3 can start the moment kc-art-traits-impl lands. They touch `synergy_rules.gd`, `match_state.gd`, `run_progress.gd` and `run_config.tres`, which that task is editing now. Step 4 builds on its `deck_traits` / `deck_arts` save (version 3 → 4). Steps 5–7 can run in parallel with step 4, and step 8 closes the work.

## 9. Questions for the head (recommended option first)
1. **What a Recruit calling card is:** (a) **trait on, keywords locked until it trains (shown greyed as "Trains: …")** (recommended: exactly "traits first, then keywords", and the locked line is the discovery hook; it costs nothing in balance), (b) trait and keywords both on from the first pick (simpler rules, but M2 has nothing new to discover), or (c) today's Recruit (keywords, no trait) for rewards too (the opposite of your order).
2. **Removing the starting cards:** (a) **Muster out after each Supply Drop from M2 on: one Standard Issue card per new card plus one, pre-selected most expensive first; Salvage (2 cards) after a loss; Retire stays as an option** (recommended: run 42.8%, M5 deck = 10 Standard Issue units of 18), (b) the same without the "+1" (34.5%, a harder run with a slower clean-out), or (c) keep today's Retire / Regroup only (14–15% runs: too hard with a vanilla starter).
3. **Reward size:** (a) **2 picks of 4 from M2 on** (recommended: the deck visibly turns into calling cards), or (b) 1 pick of 3 as today (fewer choices per screen; with one card out per pick the run drops to about 30%, and the end deck keeps 15 Standard Issue cards).
4. **Difficulty fixes that come with it:** (a) **M1 squad at −1 Armor ("green squad") and Anchor+ Armor bonus 1 → 0; the Rival unchanged** (recommended: new player 70% in M1, run 42.8%), (b) the same, plus the extra Muster out card only from M3 (36%: harder, closer to today's 35%), or (c) Standard Issue squads in M1–M2 with no Armor change (new player 34% in M1: too hard).

---

## Implementation notes (kc-onboard-impl, Mechanics Developer, 2026-11-06)
§8 steps 1–4 and 8, plus the head's kc-trait-ui answers Z1 ("No choice at all: the trait comes only from the art you find") and Z2 (one standard Standard Issue art for starters). Nothing in `scripts/ui` or `scenes` was changed. Not committed.

### What was built
| Step | What | Where |
|---|---|---|
| 1 · Standard Issue data | `CardData.standard_issue` (+ `is_token()`, `trained_keyword_names()`); 4 cards `si_grunt` 1 · 2/2, `si_trooper` 2 · 2/3, `si_sergeant` 3 · 3/3, `si_armored` 4 · 2/5 (no class, trait, keyword or effect; `collectible = false`, but deck cards: control, credit, discard). Validator: a Standard Issue card with a trait / keyword / effect / class is an error; token checks for decks now use `is_token()`. Starter = Grunt 5, Trooper 6, Sergeant 4, Armored Trooper 3, Ammo Resupply 2; `starter_recruits = false`; SI copies are level 0 and never train / promote. | `scripts/data/card_data.gd`, `data/cards/si_*.tres`, `data/run_config.tres`, `run_config.gd`, `squad_data.gd`, `tutorial_script.gd`, `match_state.gd` (discard) |
| 1 · Art (Z2) | Every starter copy wears one fixed art (`ArtTraits.starter_art`): SI units their own id, the starter's Ammo Resupply `si_ammo_resupply` (`ArtTraits.STANDARD_ISSUE_ARTS`); no random draw, never licensed MW3 art (an SI art id resolves at BannerArtDB step 1). **PLACEHOLDERS:** `data/banners/si_grunt / si_trooper / si_sergeant / si_armored / si_ammo_resupply.tres` (`placeholder = true`, source_note "PLACEHOLDER") point at our Killstreak card art (rifleman / point_man / breacher / shieldman / ammo_resupply) until the Sr Game Artist's 5 arts land (drop them in by replacing `image_path`). Subname "Standard Issue". CardDB skips `data/banners` (display-only). | `scripts/data/art_traits.gd`, `data/banners/`, `autoload/card_db.gd` |
| 2 · Recruit (N1) | Level 0 = trait ON, rules text locked: `SynergyRules.trait_at` ignores the level (none on SI cards); `keywords_on(card, level)`, `effects_at`, `locked_keywords`, `trains_text`. `create_unit` gives a Recruit unit no First Shot / Pick / Flank / Cover / Suppress / Pierce (incl. LMG) / Patch / Holder / arrive-front / effects; play-time effects and targets use `effects_at`; the AI's `record_for_card` mirrors it; preview uses `RulesCard.arrives_front()`. Fields / tactics are never locked. | `synergy_rules.gd`, `match_state.gd`, `rules_card.gd`, `ai_view.gd`, `ai_planner.gd` |
| 3 · Squads | `RunMatchData.enemy_deck` (authored slot deck), `crew_label`, `is_green_squad()`, `enemy_armor_bonus` range −1..5. M1 SandViper_07 Standard Issue crew (Grunt 5, Trooper 7, Sergeant 3, Armored 1, Ammo 2) at **−1 Armor**; M2 Bulwark_Nine SI crew + 3 Heavy Recruit Gunners (Grunt 1, Trooper 4, Sergeant 3, Armored 4, Ammo 1, Hold the Line 2, Gunner 3); M3 the shipped Rusher as Recruit calling cards (Vanguard identity); M4 Anchor+ Armor **0**; M5 unchanged. TrainingBot_01 is **not** changed (the tutorial script plays fixed cards: step 6 owner). | `run_match_data.gd`, `side_setup.gd`, `run_config.tres` |
| 4 · Ladder | `RunConfig.reward_rungs` [1,2,3,4] + `in_rung()` / `rung_after(n)`; `reward_levels` [0,1,1,1] (Recruits after M1); `multi_pick_from_match = 2` (4 shown, `multi_picks` 2); `muster_out_from_match = 2`, `muster_out_extra = 1`; `salvage_after_loss` (2 cards, pick 1, replaces Regroup); `doctrine_from_first_pick` (`doctrine_after_matches` empty); `legacy_cards` [Rifleman] so old saves load. `RewardOffers.KIND_SALVAGE`, `KIND_MUSTER_OUT`, `CARD_DROPS`; `supply_drop(_on_trait)` take `rung` and `count`. Twin training retired (`twin_index` always −1). Save **v4**; v1–v3 saves load, their Recruit copies migrate to Trained (the old Recruit had its keywords), Re-issue flags are dropped. | `run_config.gd`, `reward_offers.gd`, `run_progress.gd`, `autoload/run_state.gd` |
| Z1 | No trait choice: `choose_offer(i, trait)` / `retire_card(i, twin_trait)` ignore the trait; `train_choices(i)` returns one row (the copy's trait, `random: false`); `reissue_options()` = []; `reissue_card()` always refuses; `set_copy_art` never changes a copy's trait; drops / Regroup never carry `reissue`; `deck_view().can_reissue` false. | `run_progress.gd`, `art-traits.md` §2 note |
| Reveal | `RevealFlags` (pure): flag ids, `TEXTS` ("New: X"), `run_triggers(run)`, `match_triggers(state)`, `pending_explainers`, `visible`. Profile store in Settings: `met_flags`, `seen_flags` (persisted), `meet()`, `has_met()`, `mark_seen()`, `is_seen()`, `reset_tips()`. RunState: `system_met(flag)` signal, `note_systems(flags)`, `has_met`, `pending_explainers()`, `ack_explainer(flag)`; it feeds `run_triggers` itself after every run change. | `scripts/run/reveal_flags.gd`, `autoload/settings.gd`, `autoload/run_state.gd` |
| Tests | New `tests/test_onboarding.gd` (18 tests: data, starter + art, Recruit rule, AI record, Trains line, squads, rungs, M1 / M2 drops, 2 of 4, Muster out count / pre-selection / floor / errors, Salvage, Promotion keeps trait + art, Retire uses a pick, save v4, v3 migration with the Rifleman, reveal flags + profile store). `tests/legacy_starter.gd` = the kc-syn Recruit starter with the ladder off; the kc-syn / kc-art-traits run tests, the pitch-deck tests and **`test_run_screens.gd` (UI) run on it** until kc-onboard-ui re-points the screen suite at the shipped config (the 4-card drop + Retire tile overflows the phone canvas today: 1316 > 1168 px). Updated for the new rules: `test_art_traits`, `test_run_synergy`, `test_rules_synergy`, `test_run_flow`, `test_trait_ui`, `test_syn_ui`, `test_board_columns`, `test_rules_soak`. | `tests/` |

### UI hooks for kc-onboard-ui (nothing in `scripts/ui` was changed)
| Need | Hook |
|---|---|
| Standard Issue frame / serial plate | `CardData.standard_issue`; `RunProgress.standard_issue_serial(card)` ("SI-01" … "SI-04", by cost); `deck_view()` rows: `standard_issue`, `serial`, `level_name` "Standard Issue", `band` "". Arts: `ArtTraits.is_standard_issue_art(art, card)`, subname "Standard Issue". Enemy red plate: `RunMatchData.crew_label` / the squad side. |
| Greyed "Trains:" line | `SynergyRules.trains_text(card, level)` → "Trains: First Shot · Guard" (`RulesCard.trains_text()`, `deck_view().trains`, `locked_keywords`); Promotion rows: `promotion_options()[i].unlocks`. A Recruit's banner already shows its trait (`BannerCard.entry_for_card` reads `trait_at`). Keyword pips must use `SynergyRules.keywords_on(card, level)` (or the unit's own flags), not the CardData's printed booleans. |
| Pick 2 of 4 | Drop / Salvage offers carry `picks` (left), `taken` ([{id, trait, art}]; a taken card **leaves** `options` / `traits` / `arts`), `level` (0 = Recruit calling cards), `rung`. The drop stays current until `picks` is 0 (or SKIP = done). `choose_offer(i)` adds one card; the reward screen must re-render after each pick (it does on `run_changed`). Retire on a drop uses one pick. |
| Muster out screen | Offer `kind` `muster_out`, `count`; `RunProgress.muster_out_count()`, `muster_out_options()` (rows {index, id, name, cost, firepower, armor, art, serial, preselected}, most expensive first); commit with `RunState.muster_out(indices)` (any subset up to the count), `choose_offer(0)` = the pre-selection, SKIP = keep all. Floor 15 is applied (the offer disappears at the floor). `RunProgress.mustered_out` counts them (After-Action). |
| Salvage view | Offer `kind` `salvage`: a 2-card drop (same keys as a Supply Drop), after a loss in M1–M4; Muster out follows from M2. `KIND_REGROUP` stays for old saves / configs. |
| Green squad tag | `RunMatchData.is_green_squad()` (M1), `crew_label` ("Standard Issue crew", "Honors crew", "Mastery crew", "Operator crew"). |
| Doctrine | Set by the first calling card taken (`run.doctrine`; no Doctrine screen in the shipped config). |
| Remove (Z1) | The TRAIN AS picker (`reward_screen.gd` `train_pick`, `_build_train_picker`; `train_choices` now has one row), the RE-ISSUE tile / header button / `_build_reissue` / `reissue()` (`reissue_options` is [] and `reissue_card` refuses), the "random art" line in TRAIN AS, the deck view's Re-issue hints (`can_reissue` false, `art_choices().other` = other-trait arts, never allowed), the twin-training path (`twin_index` −1), `qa_bridge.gd` reissue fields. Keep the Codex "NOT FOUND YET" dimming (Z3). |
| Progressive reveal | `RevealFlags` ids: `calling_cards`, `trait_rail`, `doctrine`, `keywords`, `links`, `promotion`, `engine_panel`, `muster_out`, `salvage`, `retire`, `multi_pick`, `fields`, `elites`, `loadout`, `lethal`, `tactical`, `killstreaks`, `kw_<keyword>` tips. Show an element when `RevealFlags.visible(flag, Settings.met_flags, now)` (now = `RevealFlags.match_triggers(state)` on the board). After each Reveal / Firefight call `RunState.note_systems(RevealFlags.match_triggers(m))`; feed `lethal` / `tactical` / `killstreaks` yourself the first time a button is ready. Run-state triggers are fed by RunState automatically. Listen to `RunState.system_met(flag)`; show one "New:" card per screen from `RunState.pending_explainers()` with `RevealFlags.text_of(flag)` ({title, text}); "Got it" → `RunState.ack_explainer(flag)`; Settings "Reset tips" → `Settings.reset_tips()`. Run 1 skips the Loadout screen while `loadout` is not met (met when a run ends). |
| Tutorial (step 6) | TrainingBot_01 / the tutorial decks are unchanged; `si_grunt` / `si_trooper` / `si_sergeant` exist for the rewrite. |

### Re-measure on the real build (step 8)
New tool `tests/tools/onboarding_check.gd` plays the **real** run (shipped `run_config.tres`, real `RunProgress` offers, balance_sim's proxies and offer rule, Muster out = the pre-selection); `balance_sim.gd` (updated: Salvage is picked like a drop) gives the same run numbers on the same seeds. `art_traits_sim.gd` was re-run as is. Raw outputs in the session scratchpad (not committed).
`godot --headless --path . -s res://tests/tools/onboarding_check.gd -- runs=400 late=160 mirror=1000` · `balance_sim.gd -- seeds=40 modes=run runs=400` · `art_traits_sim.gd -- exp=duel|mirror|campaign n=160`

| Check (target) | Real build | §6 sim | n |
|---|---|---|---|
| New player (casual) M1 in a run (65–75%) | **69.8%** | 70.2% | 400 runs |
| New player, starter kit vs the fixed M1 slot | 68% (competent 92%) | 68.8 / 90.6% | 40 |
| Solid-player (competent) full run (38–43%) | **41.0%** (±2.5) | 42.8% | 400 |
| Competent per match M1–M5 | 95.5 / 97.8 / 37.5 / 38.8 / 42.2 | 95 / 98 / 33 / 38 / 44 | 400 |
| Casual full run · per match | 23.5% · 69.8 / 71.8 / 55.5 / 36.1 / 30.4 | 25.2% · 70 / 70 / 56 / 30 / 32 | 400 |
| Cards added / Standard Issue sent home per run (competent) | 5.71 / 7.67 | 5.7 / 7.6 | 400 |
| Deck at M5: size · SI units · calling-card units · Recruits | 18.0 · 10.2 · 5.1 · 0.00 | 18.0 · 10.3 · 5.5 · — | 389 |
| End-of-run deck vs the starter, same loadout | **74.7%** | 76.2% | 640 |
| Aware vs blind, same end-of-run deck (≥ 55%) | **55.9%** | 58.4% | 640 |
| Seat 0, Standard Issue mirror (≈ 50%) | **53.5%** | 52.1% | 1000 |
| Seat 0, end-of-run deck mirror | 61.6% (watch) | 53.1% | 320 |
| art_traits_sim duel / mirror (its own late decks: starter + 4 rewards, no Muster out) | aware 51.7%, seat 0 46.9% | — | 640 / 800 |
| art_traits_sim campaign (starter vs each slot, aware) | 97.5 / 50.6 / 31.2 / 23.8 / 0.6% | — | 160 per slot |

- **Every target is met on the real build.** The run lands at 41.0% (inside 38–43), M1 for the new player at 69.8%, aware vs blind at 55.9% (just above 55), the end deck beats the starter 74.7%, and seat 0 of the starter mirror is 53.5%.
- **Watch:** seat 0 on the end-of-run deck mirror reads 61.6% (n = 320, ±2.7), above the §6 sim's 53.1%. The starter mirror is fine, so it's the late decks (more First Shot / initiative-tie value for the seat that sees the red dots). Worth a larger run before tuning.
- art_traits_sim's own duel / mirror build late decks the old way (starter + 4 package cards, 3 Riflemen retired, which the Standard Issue starter doesn't have), so they are mostly Standard Issue decks with few sets (tier 2+ in 1–19% of matches). Their 51.7% aware edge is not the end-of-run measure; onboarding_check's 55.9% on real M5 decks is. Updating that tool's deck model to the ladder is a Mid Game Designer follow-up.
- Every Recruit is trained by M5 (0.00 left), as §6.3 expected (the M2 Promotion trains the M1 calling card).

