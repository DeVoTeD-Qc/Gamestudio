# KillingCard: Onboarding and Progression (a plain Standard Issue starter, then traits, then keywords)

*Author: Sr Game Designer Agent · 2026-11-06 · Board task kc-onboard · Status: **proposal, waiting for the head's answers (§9)** · No rules, UI, scene or data file was changed. The sim is `source/project-killingcard/tests/tools/onboarding_sim.gd` (real engine, real AI, sim-only cards), run on a snapshot of the working tree that includes the kc-art-traits-impl work in progress.*
*Inputs: `synergy-system.md` (Recruit starter, Retire, Promotion, Doctrine, §11–12), `art-traits.md` (the trait comes from the art; approved), `firefight-order.md` (beats, Pierce on LMG units), `card-system.md`, `scripts/run/*`, `data/run_config.tres`, the squads in `data/squads/`, the tutorial in `data/tutorial/`, and `balance_sim.gd` for today's baseline.*
*The head (verbatim): "The game also feels too complex in first user experience. I think the starter deck should be mostly vanilla cards, which means units with no ability and no trait. Maybe we should use our own generated art for the starter deck, and then as we progress in the roguelite campaign we find the MW3 calling cards that come with a trait. Then we find more cards or upgrades and discover keywords. The goal is that our first deck is simple and somewhat bad, so we can improve it by adding more cards and at some point by removing the starting cards."*

## 0. Summary in six lines
1. **The starter is 20 Standard Issue cards**: 4 vanilla unit designs (cost, FP and Armor only: no keyword, no trait, no weapon class) plus 2 Ammo Resupply. They wear **our own art** in a plain "Standard Issue" look, so they read as basic kit you are meant to replace (§2).
2. **Every copy climbs one ladder**: Standard Issue (plain, never trains) → **calling card · Recruit** (an MW3 card: its trait is on, its keywords are shown but still locked) → **Trained** (keywords on) → Veteran → Elite. "Recruit" changes meaning: today it means "keywords but no trait"; now it means "trait but no keywords" (§3).
3. **One new idea per match.** M1 is vanilla against a vanilla squad. The first Supply Drop brings calling cards (**traits**). M2 brings **keywords** (Trained cards, Promotion) and **Replace** (send a Standard Issue card home). M3 brings **Fields**, and M4 brings the Elites. The enemy climbs one step behind you (§4).
4. **The UI shows a system only when it first matters**: the trait rail, keyword pips, link ticks, the Field strip and the Engine panel stay hidden until their first use, and each one opens with a one-time "New: …" card. The tutorial switches to Standard Issue cards and stops teaching First Shot (§5).
5. **Sim (about 14,000 matches):** the new-player proxy wins **M1 70.5%** (today 64%), and the run climbs 70 / 70 / 56 / 32 / 34. For the competent proxy the **full run is 40.5%** (today 35%; target 38–40). Aware vs blind on the end-of-run decks is **60.4%** and the first player wins **52.1%** (n = 1000). An end-of-run deck beats the starter **79%** of the time with the same loadout. Four number changes get there: M1 squad −1 Armor, Supply Drops from M2 give **2 picks**, Anchor+ and Rival Armor bonus 1 → 0, and the Rival swaps 2 Riflemen for 2 Gunners (§6).
6. **Implementation in 6 steps** after kc-art-traits-impl: Standard Issue data and art, the new Recruit meaning in the rules, Standard Issue squads, the run ladder (rung pools, 2 picks, Replace, Salvage), progressive reveal flags with "New:" cards, and the tutorial (§8).

---

## 1. Goals
| Goal | Measure | How this design meets it |
|---|---|---|
| The first match is simple | Rules a player must read in M1 | Cost, FP, Armor, Supply, the columns, the firefight order, the Operator, streaks and the Recon Drone (all taught in the tutorial). **No keyword, no trait, no Field, no link.** |
| The first deck is "somewhat bad" | End-of-run deck vs the starter | The end-of-run deck wins **79%** against the starter with the same loadout (§6.4). Every reward is visibly better than the card it replaces. |
| It still wins the first match | M1 win rate, new-player proxy | **70.5%** (target 65–75%), competent proxy 95% |
| Growth is felt | Standard Issue cards left at M5 | 20 → about **13** of 21 cards, with 5–6 calling cards, all Trained by M5 (§6.3) |
| Discovery has an order | One new system per match | Traits (after M1) → keywords and Replace (after M2) → Fields (after M3) → Elites (after M4) (§4) |
| The run is still a run | Full-run win (competent proxy) | **40.5%** (today 35%, target 38–40) |
| Skill still matters late | Aware vs blind, same end-of-run deck | **60.4%** (target ≥ 55%) |
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
- **Never a trait and never a keyword.** Standard Issue cards can't train, can't be Promoted and can't be Re-issued. Their only exit is Replace or Retire (§4.3). `trait_options` is empty, and they are `collectible = false`, so they're never in the reward pool and never in the Codex album.
- **The same starter every run** (the roguelite norm). Only the first-time explainers are per profile (§5).
- Tested alternatives, M1 vs the Standard Issue Rusher (n = 160, new-player / competent proxy): this list 69 / 91% (with the M1 squad at −1 Armor); a stronger list (Trooper 2/4, Sergeant 3/4) 47 / 79% (squad at 0 Armor); and the same list with the squad at 0 Armor 34 / 79% (n = 120). The M1 lever is the squad, not the starter (§6.1).

### 2.2 Look: "Standard Issue" (our own art)
| Element | Standard Issue | Calling card (reward) |
|---|---|---|
| Art | Our generated art (public build and pitch build alike): one flat two-tone soldier silhouette per role, olive drab and khaki, on a canvas / supply-crate background | MW3 calling card (pitch) or our own family art (public), per art-traits §1.4 |
| Frame | Matte grey-green frame, stencil lettering, a serial plate "SI-01" … "SI-04", no foil, no camo band | The banner frame with the trait icon in front of the subname, and the camo band for the level |
| Name / subname | "Grunt" / "Standard Issue" | "Breacher" / "⚙ Lockwood 680 Mastery" |
| Animation | None | Animated arts keep their loop |
| Family | `standard_issue` (a new family: no trait, not an album family) | Honors / Operators / Mastery / Horde / Standard |

- The Sr Game Artist makes **5 arts** (4 units and the Standard Issue Ammo Resupply) with `tools/gen_card_art.py` and the existing banner pipeline. They must read as "basic" at phone size: low contrast and no glow, so the first calling card visibly pops next to them.
- The **Standard Issue squads** (§4.4) wear the same arts with a red serial plate, so the enemy in M1 is plainly as basic as you are.
- IP: all original, safe for the public build (card-system §6).

## 3. The card ladder (per copy)
| Level | Name on the card | Comes from | Trait | Keywords (printed, neighbor, effects, LMG Pierce) | Frame / band | Next step |
|---|---|---|---|---|---|---|
| — | **Standard Issue** | The starter | never | never | Standard Issue frame | Replace / Retire only |
| 0 | **Recruit** (calling card) | The M1 Supply Drop, Salvage after an M1 loss, enemy squads in M2–M3 | **on** (from the art, art-traits §1) | **shown greyed, locked**: "Trains: First Shot · Guard" | banner frame, no band | Promotion, or Replace's kit hand-over (option, §4.3) |
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
| **M1** Bracket 1, Zone Control | **SandViper_07 · Standard Issue crew**: Standard Issue cards, **−1 Armor** ("green squad" tag on the run map) | Nothing new: the tutorial's rules with your 20 Standard Issue cards | Win: **Supply Drop · Calling cards**: 3 Recruit calling cards (units only, no Elites), pick 1. Your first calling card sets your **Doctrine** (no separate screen). Loss: **Salvage**: the same, with 2 cards. Then weapon level (as today). | **New: Calling cards & Traits**, **New: Doctrine** (one card) |
| **M2** Bracket 1, Zone Control | **Bulwark_Nine · Standard Issue crew** with **3 Heavy Recruits** (Gunners): the enemy's trait rail appears | Your first trait in play: the trait rail, set counter "Heavy 1/3" | Win: **Supply Drop**: **Trained** cards (keywords) and simple tactics, **pick 2 of 4**, each pick can **Replace** a Standard Issue card. Loss: Salvage (2 cards, pick 1). Then **Promotion** (your Recruit trains), then a Perk. | **New: Keywords** (at the first Trained card or Promotion), **New: Replace** |
| **M3** Bracket 2, Firefight | **SandViper_07 · Honors crew**: the real Rusher deck as **Recruit calling cards** (Vanguard traits, no keywords) | Keywords on your side; Vanguard sets on theirs | Supply Drop **+ Fields** in the pool (pick 2 of 4, Replace), or Salvage. Weapon level. | **New: Fields** (at the first Field offered), keyword cards at first play |
| **M4** Bracket 2, Firefight | **Bulwark_Nine · Mastery crew**: the real Anchor, **Trained** (keywords, links, Pierce, Heavy identity), Armor bonus **0** (today 1) | Enemy links and Pierce | Supply Drop **+ Elites**: the full pool (pick 2 of 4, Replace), or Salvage. Promotion, weapon level, Perk. | **New: Links** (the first time a neighbor keyword links, on either side) |
| **M5** Rival, Zone Control | **Meridian_Six · Operator crew**: Trained, Spec Ops identity, Armor bonus **0** (today 1), **2 Riflemen → 2 Gunners** | Everything | Run end | — |

- **The enemy is one step behind you.** You get traits after M1, and the squads show traits in M2–M3. You get keywords after M2, and the squads show them in M4. So when something new appears on the enemy side, you've already met it on your own cards.
- **Rungs are pools, not scripts.** Each Supply Drop draws from `reward_pool` filtered by rung (§4.2) with the existing on-trait slot (slot 1 is on your main trait) and the art-traits dressing (home art 60%, alternate 40%). Repeat runs feel different, but the order of discovery is always the same.
- **The camo band, Re-issue and the Engine panel** come with Promotion (M2), with nothing before then.

### 4.2 Reward pools by rung (filters on today's `reward_pool`, no new cards)
| Rung | Offered after | Pool | Level |
|---|---|---|---|
| 1 · Calling cards | M1 (win or Salvage) | Units except Elites: Point Man, Breacher, Protector, Flanker ×2, Recon Specialist, Marksman, Gunner, Demolitions Expert ×2, Brawler ×2, Combat Medic | **Recruit** |
| 2 · Keywords | M2 | Rung 1 units + tactics (Callout ×2, Ammo Resupply, Flank Route ×2, Suppressing Fire ×2, Hold the Line, Breach and Clear ×2) | Trained |
| 3 · Fields | M3 | + Fields (Tripwire ×2, Comms Relay ×2, Listening Post, Mortar Pit, Bulwark, War Standard, Sniper Perch, Aid Station) | Trained |
| 4 · Full | M4 | + Elites (Commander ★, Ace ★) | Trained |

(Today's copies in `run_config.tres`; the Smoke Screen / Blackout / Sabotage reward-pool entries from card-system §3.1 are not in the shipped pool and stay out.)

### 4.3 Replace, Retire and Salvage (removing the starting cards)
| Action | When | What it does | Why it's attractive |
|---|---|---|---|
| **Replace** (new, recommended) | Every Supply Drop / Salvage pick **from M2 on** | The picked card takes the place of a Standard Issue card you choose ("Send home: Grunt SI-01"). Deck size stays the same. The default suggestion is the cheapest Standard Issue unit. | No opportunity cost: you get the card **and** lose a weak one. It's the head's "remove the starting cards" as one tap, and it only works on Standard Issue cards, so the framing is clear. |
| **Retire** (exists, kc-syn) | The 4th Supply Drop option, any card, as today | Removes a card instead of taking one (15-card floor) | Still there for advanced thinning (calling cards you no longer want) |
| **Salvage** (replaces Regroup) | After a loss (M1–M4) | A 2-card Supply Drop of the current rung, pick 1 (Replace allowed from M2 on) | A loss still moves the deck forward. Today's Regroup (a free Retire) does little for a Standard Issue deck: in the sim, Salvage instead of Regroup is worth about +10 points of run win (§6.3). |
| Twin training (kc-syn) | — | **Retired with this design**: there are no Recruit twins in the starter any more | — |
| **Kit hand-over** (option, not recommended for v1) | Retire of a Standard Issue card | One of your Recruit calling cards trains for free | Simulated early: it made Retire too automatic and shrank decks (§6.3). Keep it as a lever if playtests show Recruits stay untrained. |

- **2 picks per Supply Drop from M2 on** (4 shown, pick 2, slot 1 on-trait). With 1 pick, the end-of-run deck still holds 15 Standard Issue cards and the planning edge falls below target (52.9%). With 2 picks it holds about 13, and aware vs blind is 60.4% (§6.3). Five matches is a short run, so each drop has to move the deck more than in a 15-fight roguelite.
- **Floor**: Replace never changes the deck size. Retire keeps the 15-card floor.

### 4.4 Enemy squads along the ladder
| Slot | Squad | Deck | Levels / traits | Scaling | Change vs today |
|---|---|---|---|---|---|
| 1 | SandViper_07 (Rusher) | **Standard Issue**: Grunt 5, Trooper 7, Sergeant 3, Armored Trooper 1, Ammo Resupply 2 (18) | no traits | **Armor −1** | new deck (today: the Rusher deck as Recruits) |
| 2 | Bulwark_Nine (Anchor) | **Standard Issue + 3 calling cards**: Grunt 1, Trooper 4, Sergeant 3, Armored Trooper 4, Ammo Resupply 1, Hold the Line 2, **Gunner ×3 as Heavy Recruits** (18) | Heavy on the 3 Gunners | 0 | new deck |
| 3 | SandViper_07 (Rusher+) | the shipped Rusher deck | **Recruit calling cards** (new meaning): Vanguard identity, no keywords | 0 (as today) | today: Trained |
| 4 | Bulwark_Nine (Anchor+) | the shipped Anchor deck | Trained, Heavy identity | **0** (today 1) | −1 Armor |
| 5 | Meridian_Six (Rival) | shipped, **2 Riflemen → 2 Gunners** | Trained, Spec Ops identity (the Gunners carry Spec Ops) | **0** (today 1) | −1 Armor, a stronger deck |

- The Rival change trades a flat +1 Armor (which punishes 2-FP Standard Issue bodies more than anything else) for a stronger deck. With the bonus at 0 and no swap, the Rival is too easy (M5 50–53%, run 49–51%). With both, it lands at 41% (§6.2).
- Squad AI personalities stay as shipped. A sloppier M1 AI (second-best chance 0.35) did nothing measurable (§6.1).

## 5. Progressive reveal (UI and rules appear when first relevant)

### 5.1 Rules
- **Profile flags, not per run.** `ProfileFlags.seen` (Settings / save) stores each "New:" card the player has seen. The starter, the ladder and the squads are the same every run. Only the explainers are one-time. A "Reset tips" switch in Settings clears the flags.
- **One "New:" card at a time**: a half-screen card with the icon, one sentence, a mini example and "Got it". It shows **at the moment of use** (the reward screen or the first board where the thing is in play), never in a menu. Several triggers at once queue up, at most one per screen.
- **Hidden ≠ off.** An element is hidden only while nothing on the board uses it. The enemy can never use something that's hidden from you: the trait rail appears when the first traited unit of **either** side is in play.

### 5.2 What appears when
| UI / rule | Hidden until | "New:" card text (one sentence) |
|---|---|---|
| Hand, Supply, columns, red dots, Operator, streak arc, Recon Drone | always on (tutorial) | — |
| Lethal / Tactical buttons | always on; a coach mark the first time each is off cooldown in M1 | "New: Frag Grenade. Your Operator's grenade: 2 damage to a front card. It recharges." |
| Killstreak choice on the Loadout screen | run 2 (run 1 uses the defaults: Recon Drone, Mortar Barrage, Attack Helo, and skips the Loadout screen) | "New: Loadout. Pick your three killstreaks before a run." |
| Trait icon on cards, subname with the art title | the first calling card offered | **New: Calling cards.** "Calling cards bring a trait. 2 or 3 of a trait in play give a bonus." |
| Doctrine emblem on the Operator plate | the first calling card picked | (in the same card) "Your first calling card's trait is your Doctrine: it counts +1." |
| Trait rail and set callouts | the first traited unit in play (either side) | **New: Traits.** "Heavy 1/3: one more and your Heavy cards…" (the rail's own tier text) |
| Locked keyword line ("Trains: …") | shown on Recruits from the start (it's the teaser) | — |
| Keyword pips and stat deltas (▲) | the first Trained card offered, or the first Promotion | **New: Keywords.** "Trained cards have keywords. Your Breacher now has First Shot." |
| Per-keyword tip (First Shot, Pick, Flank, Pierce, Suppress, Patch, Cover, Protector slide, On Deploy / On Down, Holder) | the first time that keyword is in play on either side | One line each (the `SynergyRules.KEYWORD_TEXT` / card text) |
| Link ticks and placement preview | the first time a neighbor keyword links (either side) | **New: Links.** "Guard: the card behind this one has Cover +1." (with the mini-grid) |
| Camo band, Promotion screen | the first Promotion (after M2) | **New: Promotion.** "Promotion trains a card. Gilded → Forged → Priceless." |
| Replace toggle on picks | the first Supply Drop from M2 on | **New: Replace.** "Send a Standard Issue card home and put this one in its place." |
| Retire (4th option), Re-issue | the first Supply Drop from M2 on (grouped under "More") | — |
| Field strip on the objective | the first Field offered or in play (either side) | **New: Fields.** "Fields sit on the objective and change the whole column." |
| Engine panel in the deck view | the first Promotion | — |
| Elite frame | the first Elite offered | "New: Elites. One of a kind, with a printed trait." |

### 5.3 The tutorial, aligned
- **Decks:** the player gets Grunt / Trooper / Sergeant (Standard Issue). TrainingBot_01 becomes Standard Issue too (8 Grunts, 3 Troopers, 2 Sergeants, 2 Armored Troopers instead of Rifleman / Point Man / Marksman / Combat Medic).
- **Steps 1–6 stay** (Operator, red dots, "Tap Grunt, then Left", READY, the fight, streak 1).
- **Steps 7–9 change** from "Point Man has First Shot" to the beat order: "Sergeant hits for 3. In each column the front cards trade shots, and when one falls, the card behind steps up." (card `si_sergeant`; the scripted board shows a line advance).
- **Steps 10–17 stay** (Recon Drone, scoring, the final fight).
- First Shot is no longer taught in the tutorial. It's taught by its own keyword tip the first time it's in play (§5.2), which in a normal run is M2–M3.

## 6. Sim results
**Harness:** `tests/tools/onboarding_sim.gd`, built like `synergy_check.gd` / `art_traits_sim.gd` on the shipped engine (MatchState + SynergyRules + AiPlanner with synergy-aware planning on both sides; the squads use `AiPlayer.for_squad`). Standard Issue cards and Recruit calling cards (the new meaning) are sim-only CardData objects; traits go through `SideSetup.deck_traits`. **Full runs** are the sim's own 5-match loop: 3 tickets, a loss costs one, the run ends at 0 tickets or after M5; offers follow §4 (rung pools, the on-trait slot, the 60/40 art roll, the first trait = Doctrine, Promotion after M2 and M4 trains the best Recruit, otherwise levels the best on-trait unit; weapon level after M1/M3/M4 and a Perk after M2/M4 take option 0; Supply Drop picks take the on-trait unit, else the most expensive unit; Replace removes the cheapest Standard Issue unit while the deck has ≥ 18 cards). **Proxies:** balance_sim's *competent* (a solid player) and *casual* (second-best plan 60% of the time, holds cards; the new-player proxy). Today's baseline is `balance_sim.gd` (the real `RunProgress` with synergy offers on), on the same snapshot.
Run: `godot --headless --path . -s res://tests/tools/onboarding_sim.gd -- exp=slots|runs|mirror|all n=N runs=N [options]`. The recommended package is:
`exp=runs runs=200 n=60 slotset=1.enemy_armor_bonus=-1 slotset=4.enemy_armor_bonus=0 slotset=5.enemy_armor_bonus=0 picks=2 enemy=si,si+cc,cc,shipped,shipped squadswap=squad_black_meridian:rifleman>gunner squadswap=squad_black_meridian:rifleman>gunner`
**Statistics:** 200 runs give ±3.5 points SE on the run win rate. Slot rows with n = 120–160 give ±4. Raw outputs are in the session scratchpad (not committed).

### 6.1 Match 1 (target: new-player proxy 65–75%)
| Setup (vs SandViper_07 in M1) | New player (casual) | Competent | n |
|---|---|---|---|
| **Today**: Recruit starter vs the Recruit Rusher (balance_sim full runs, in-run M1) | 64% | 78% | 200 runs |
| Today's starter kit, fixed slot | 72.5% | 71.2% | 80 |
| Standard Issue starter vs a Standard Issue Rusher, Armor 0 | 33.8% | 78.8% | 80 |
| … with a cheaper squad (Grunt 8, Trooper 6, Sergeant 2) | 34.2% | 68.3% | 120 |
| … with a sloppier squad AI (second-best chance 0.35) | 30.8% | 70.0% | 120 |
| … with a thin squad deck (6 Grunts, 4 Troopers, 6 tactics) | 56.2% | 83.8% | 160 |
| … with a stronger starter (Trooper 2/4, Sergeant 3/4) | 46.9% | 79.4% | 160 |
| … without Lethal / Tactical, Recon Drone only, both sides (M1–M2 "lite") | 15.8% | 40.0% | 120 |
| **Recommended: squad at Armor −1** | **68.8%** (in-run 70.5%) | 90.6% (in-run 95%) | 160 / 200 runs |

- **A vanilla mirror is a skill test.** With equal decks, the squad AI (close to competent) beats the casual proxy two games out of three. Vanilla boards have no swingy card for a weaker player to lean on. So M1 needs a real handicap on the squad, not a weaker player deck. **−1 Armor** is the cleanest one: it uses the existing `enemy_armor_bonus` (Ruling 11 already scales squads that way), so it can be shown on the run map as "green squad".
- **Keep the Operator kit in M1.** Taking away Lethal, Tactical and two killstreaks from both sides hurt the player badly (the player proxy uses its kit better than the squads do). Teach the kit with coach marks instead (§5.2).

### 6.2 The run: per-match win rates (target: competent run 38–40%, a smooth ramp)
| Setup | Competent: run win | Competent: M1 / M2 / M3 / M4 / M5 | Casual: run win | Casual: M1 / M2 / M3 / M4 / M5 |
|---|---|---|---|---|
| **Today** (balance_sim, Recruit starter, real RunProgress) | **35%** | 78 / 98 / 36 / 27 / 38 | 36% | 64 / 84 / 54 / 27 / 44 |
| Standard Issue, 1 pick, Regroup = free Retire, squads as shipped from M3 | 14.5% | 95 / 98 / 16 / 6 / 15 | 5.0% | 70 / 66 / 49 / 7 / 7 |
| + M3 squad as Recruit calling cards | 14.0% | 95 / 98 / 28 / 5 / 15 | 8.0% | 70 / 66 / 52 / 6 / 11 |
| + Salvage (2-card drop after a loss) + Replace from M2 | 24.5% | 95 / 98 / 32 / 11 / 26 | 19.5% | 70 / 70 / 58 / 7 / 26 |
| + 2 picks from M2 | 25.5% | 95 / 98 / 38 / 14 / 27 | 16.0% | 70 / 70 / 56 / 11 / 22 |
| + Anchor+ and Rival Armor 1 → 0 | 49.0% | 95 / 98 / 38 / 35 / 50 | 31.5% | 70 / 70 / 56 / 32 / 41 |
| **Recommended: + Rival 2 Riflemen → 2 Gunners** | **40.5%** | **95 / 98 / 38 / 35 / 41** | **26.0%** | **70 / 70 / 56 / 32 / 34** |
| Same, plus a third swap (Ammo Resupply → Gunner) | 40.0% | 95 / 98 / 38 / 35 / 41 | 22.5% | 70 / 70 / 56 / 32 / 29 |
| Same, plus a free Retire of a Standard Issue card after every drop | 48.0% | 95 / 98 / 47 / 40 / 50 | 38.5% | 70 / 70 / 58 / 34 / 47 |
| Recommended, but Rival in Firefight | 16.5% | … / 17 | 19.0% | … / 25 |
| 1 pick, Anchor+ and Rival Armor 0 | 51.0% | 95 / 98 / 32 / 32 / 53 | 33.5% | 70 / 70 / 58 / 24 / 44 |

- **The run lands at 40.5%** (competent), with M3–M5 at 35–41%. That's flatter than today's 36 / 27 / 38 with its M4 dip. The cliff after M2 (98 → 38%) is the same shape as today (98 → 36%). It marks the step from Bracket 1 to Bracket 2, and the new-player proxy sees a gentler 70 / 70 / 56 / 32 / 34.
- **The Rival's +1 Armor is the biggest single lever** (about 25 points on M5): 2-FP Standard Issue bodies can't hurt 4–7 Armor units. A stronger deck is a fairer kind of hard.
- **The new player wins a full run 26% of the time** (today 36%). That's lower on purpose. Today's casual proxy is carried by its starter's keywords. With Standard Issue, the run is won by what you add, and a sloppy player adds less well. First-run churn should be watched in playtests. The lever is Salvage with 3 cards, or the free Retire per drop (casual 38.5%, competent 48%).

### 6.3 How much the rewards and Replace move the deck
| Package | Cards added / run | Of them Replacing a Standard Issue card | Deck at M5: size · Standard Issue · Trained+ units | Aware vs blind, end decks |
|---|---|---|---|---|
| 1 pick, Regroup = free Retire (kc-syn rules) | 1.2 | — (2.7 retired) | 18.5 · 15.2 · 1.2 | 52.1% |
| 1 pick, Salvage, Replace | 3.9 | 2.9 | 21.0 · 15.0 · 4.0 | 57.5% |
| 1 pick, no Salvage (Regroup), Replace | 2.3 | 1.4 | 19.4 · 15.0 · 2.4 | 53.3% |
| **2 picks, Salvage, Replace (recommended)** | **5.7** | **4.7** | **21.0 · 13.3 · 5.5** | **60.4%** |
| 2 picks + a free Retire per drop | 5.8 | 4.8 (+3.0 retired) | 18.0 · 10.1 · 5.6 | 61.7% |

- **The deck grows into calling cards.** With the recommended package, the M5 deck has 5–6 calling cards (all Trained: the M1 Recruit trains at the M2 Promotion) and 13 Standard Issue cards left, and it beats the starter **79.2%** with the same loadout (n = 240). Today's synergy-system §7.4 measured 53–76% for its late decks vs its Recruit starter.
- **Salvage is the single biggest growth lever** (1.2 → 3.9 cards a run): with Standard Issue, a run that loses M3 still gets a card instead of a removal.
- **Replace is free value**, so the sim always takes it. That's intended: it's the "remove the starting cards" action, and its only cost is a tap. Retire stays for thinning calling cards.

### 6.4 Seats, planning and growth (recommended package)
| Check (target) | Result | n |
|---|---|---|
| Seat 0, Standard Issue mirror (≈ 50%) | **52.1%** | 1000 |
| Seat 0, end-of-run deck mirror | 50.8% | 120 |
| Aware vs blind, same end-of-run deck (≥ 55%) | **60.4%** | 240 |
| End-of-run deck vs the starter, same loadout | **79.2%** | 240 |
| Rounds per match, M1 (Standard Issue mirror-like) | 5.7 (today 5.6–5.7) | 160 |

- A Standard Issue mirror has no keywords and no traits, so the only seat edge is that seat 0 sees the red dots and wins initiative ties. It stays inside the band.
- The planning edge on end decks (60.4%) beats today's art-traits package (55.9%). With fewer engine cards, each link and set the planner forms counts for more.

### 6.5 What the sim doesn't cover
The real `RunProgress` (this loop reimplements the offers; it was calibrated against `balance_sim`'s pick rule), Re-issue, Retire as a separate option, Veteran / Elite beyond the M4 Promotion, the on-trait Doctrine choice (the sim takes the first pick's trait), Salvage after M4 (the run then ends at M5), maps other than Port Vasel, and human learning: M1 is the first match only for the first run. `balance_sim.gd` must be re-run once §8 lands.

## 7. Risks and levers
| Risk | Sign in playtests | Lever (in order) |
|---|---|---|
| M1 is too easy for veterans (95% competent) | Experienced players skip-click through M1 | Fine for M1. If needed, show the green tag and make "−1 Armor" a Bracket 0 rule only in run 1 |
| New players quit after a lost first run (26% run win) | Run-1 completion | Salvage 3 cards; a free Retire per drop (casual 38.5%); a "first run" ticket +1 |
| Players never Replace (they hoard) | Standard Issue count at M5 > 15 | Pre-select Replace on the toggle; show the Standard Issue counter in the deck view |
| Recruits stay untrained | Recruits at M5 > 1 | The kit hand-over on Retire (§4.3), or a third Promotion after M3 |
| The Rival becomes a deck-check | M5 < 30% for decks with ≥ 14 Standard Issue cards | The third Gunner swap is neutral (41%); Rival Armor stays 0 |
| Standard Issue art reads as "unfinished" | Survey | The serial plate and crate frame should look deliberate (military issue), not placeholder |

## 8. Implementation list (ordered to follow kc-art-traits-impl)
| # | Task (owner) | What | Where | Size |
|---|---|---|---|---|
| 1 | **Standard Issue data** (Mechanics Developer) | 4 new `CardData` (`si_grunt` 1·2/2, `si_trooper` 2·2/3, `si_sergeant` 3·3/3, `si_armored` 4·2/5; `weapon_class = NONE`, empty `trait_options`, `collectible = false`), a new `CardData.standard_issue: bool` (frame, Replace target, never trains / promotes / re-issues; validator), starter list in `run_config.tres` (§2.1), `starter_recruits` → removed or false, art family `standard_issue` | `card_data.gd`, `data/cards/si_*.tres`, `run_config.tres`, `gen_content.gd`, `data_validator.gd` | data + ~20 lines |
| 2 | **Recruit = trait without keywords** (Mechanics Developer) | `SynergyRules.trait_at` gives level 0 its trait; `keyword_at` stays Trained+; `create_unit` at level 0 clears first_shot / pick / flank / cover / suppress / pierce (incl. the LMG rule) / patch / holder / arrives_front / effects; AI records read the unit, so the planner follows; `RulesCard`/inspector text "Trains: …"; tests (today's Recruit tests flip) | `synergy_rules.gd`, `match_state.gd`, `rules_card.gd`, `tests/test_rules_synergy.gd` | ~30 lines, ~10 tests |
| 3 | **Squads along the ladder** (Mechanics Developer) | `RunMatchData.enemy_deck` override (an authored Standard Issue list per slot) + `enemy_recruits` keeps meaning "units at level 0" (now trait, no keywords); slot 1 Standard Issue Rusher, Armor −1; slot 2 Standard Issue Anchor + 3 Gunners at level 0; slot 3 the Rusher at level 0; slot 4 and the Rival Armor 0; Rival 2 Riflemen → 2 Gunners; TrainingBot Standard Issue | `run_match_data.gd`, `side_setup.from_squad`, `run_config.tres`, `squad_black_meridian.tres`, `squad_tutorial.tres` | ~25 lines + data |
| 4 | **Run ladder** (Mechanics Developer) | `RunConfig.reward_rungs` (per match: a filter on `reward_pool`: units / + tactics / + Fields / all, and the level: Recruit or Trained), `RewardOffers.supply_drop_on_trait` takes the filter; `supply_drop_picks_after = [2,3,4]` → 4 shown, 2 picks (one offer with `picks: 2`); `replace` on each pick (`choose_offer(i, trait, replace_index)`), Replace only on Standard Issue copies; **Salvage** (`KIND_SALVAGE`, 2 cards) replaces Regroup; Doctrine = the first calling card's trait (`doctrine_after_matches` empty, set on the first pick); twin training off; save version 4 | `run_config.gd`, `reward_offers.gd`, `run_progress.gd`, `tests/test_run_*.gd` | ~90 lines, ~15 tests |
| 5 | **Progressive reveal** (UI/UX agent) | `ProfileFlags` (`seen: {flag: true}` in the settings save) + `RevealRules.visible(flag, match_view)`; "New:" card component (queue, one per screen); hide/show: trait rail, keyword pips, link ticks, placement preview, Field strip, Engine panel, camo band, Replace / Retire / Re-issue options, Loadout screen in run 1; per-keyword first-play tips; the Standard Issue frame and serial plate; reward screen: "pick 2 of 4" and the Replace toggle; Salvage view | `scripts/ui/*`, `scripts/ui/run/reward_screen.gd`, `engine_panel.gd`, `trait_rail.gd`, `banner_card.gd`, new `scripts/ui/new_card.gd`, `autoload/settings` | UI task |
| 6 | **Tutorial** (UI/UX agent + Mid Game Designer) | Standard Issue decks; steps 7–9 rewritten to the beat order with `si_sergeant`; the First Shot text moves to the keyword tip | `data/tutorial/tutorial_script.tres`, `squad_tutorial.tres`, `tutorial_director.gd` | data + small |
| 7 | **Art** (Sr Game Artist) | 5 Standard Issue arts (4 units + Ammo Resupply) and the red-plate enemy variant; the Standard Issue frame | `tools/gen_card_art.py`, `BannerArtDB` | art |
| 8 | **Re-measure** (Mid Game Designer) | `balance_sim.gd` (runs, both proxies) and `art_traits_sim.gd` (duel, mirror) on the real build; compare with §6 | `tests/tools/` | sim |

Order notes: steps 1–3 can start the moment kc-art-traits-impl lands (they touch `synergy_rules.gd`, `match_state.gd` and `run_config.tres`, which that task is editing now). Step 4 builds on its `deck_traits` / `deck_arts` save (version 3 → 4). Steps 5–7 can run in parallel with 4. Step 8 closes it.

## 9. Questions for the head (recommended option first)
1. **What a Recruit calling card is:** (a) **trait on, keywords locked until it trains (shown greyed as "Trains: …")** (recommended: exactly "traits first, then keywords", and the locked line is the discovery hook), (b) trait and keywords both on from the first pick (simpler rules; M2 has nothing new to discover), or (c) keep today's Recruit (keywords, no trait) for rewards too (the art's trait would come later, the opposite of your order).
2. **Removing the starting cards:** (a) **Replace on every pick from M2 on (the new card takes a Standard Issue card's place) + Salvage (2 cards) after a loss; Retire stays as the 4th option** (recommended: 40.5% run, deck at M5 = 13 Standard Issue of 21), (b) the same plus a free Retire of a Standard Issue card after every drop (faster thinning; the run gets easier: 48%, new player 38.5%), or (c) keep today's Retire / Regroup only (14–15% runs: too hard with a vanilla starter).
3. **Reward size:** (a) **2 picks of 4 from M2 on** (recommended: the deck visibly turns into calling cards; planning edge 60.4%), or (b) 1 pick of 3 as today (fewer screens; the end deck stays mostly Standard Issue and the planning edge falls to 57.5%).
4. **Difficulty fixes that come with it:** (a) **M1 squad Armor −1 ("green squad"), Anchor+ and Rival Armor bonus 1 → 0, Rival 2 Riflemen → 2 Gunners** (recommended: new player 70.5% in M1, run 40.5%), (b) the same without the Rival swap (run 49%: too easy), or (c) only the M1 change (run about 25%).
