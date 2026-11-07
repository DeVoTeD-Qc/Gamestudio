# KillingCard: Synergy System (neighbor links, calling-card traits, a deck that grows into an engine)

*Author: Sr Game Designer Agent · 2026-11-05 · Board task kc-syn · Status: **approved (S1-S4, recommended answers) and implemented in kc-syn-impl, see §11** · this design section was written before the implementation: No rules, UI, scene or data file was changed. The sim lives in `source/project-killingcard/tests/tools/synergy_rules.gd` and `synergy_sim.gd`.*
*Inputs: `card-system.md` (incl. head's decisions S1–S4), `field-cards.md` (incl. F1–F3 and the kc-field-impl notes), `../art/mw3-calling-cards.md`, `mw3-calling-cards-manifest.csv`, `mw3-pitch-set.md`, the Killstreak rules in `scripts/rules/`, the AI in `scripts/ai/` and the run layer in `scripts/run/`.*
*The head's direction (verbatim): "we also need nice improvement to the deck as we progress. Cards that have synergy together. We can also have mechanic based on neighbors, left right. And top down. Calling card of same kind should maybe have a trait and bonus if played together."*
*Follow-up from the head (via the lead), also covered here: **(A)** a simpler starter deck with more duplicates, with complexity arriving through the run (§5.1); **(B)** card removal during a run (§5.4); **(C)** a Supply cost for the Operator (§6.3).*

## 0. Summary in six lines
1. **Four neighbor keywords**, one line each, two vertical and two sideways. **Guard**: the card behind you gets Cover +1. **Spotter**: the card in front of you gets +1 FP. **Fireteam**: +1 FP while a friendly stands beside you. **Overwatch**: cards beside you get Cover +1. "Beside" means the same row in the next column (A–B, B–C). Links are read live, like Field auras (§2–3).
2. **Four traits**, one per chassis (never per art): **Vanguard**, **Spec Ops**, **Heavy**, **Undead**. Count your units and Fields with that trait anywhere on your side. At **2** and **3** in play, that trait's units get a set bonus (§4). The calling-card *family* illustrates the trait (Zombies cards on Undead chassis, weapon-mastery cards on Heavy, and so on). So "same kind played together" is true on screen, and the fairness rule still holds.
3. **The starter is plain** (A): 20 **Recruit** cards in 9 designs, mostly 2–4 copies each, with no neighbor keyword and no trait. Complexity arrives through the run. Reward cards come **Trained** (keyword and trait). **Promotion** trains a Recruit, then adds +1 Armor and +1 FP, shown on the weapon-mastery camo band. **Retire** removes cards (B): a Recruit retired next to a twin trains the twin. **Doctrine** picks a run trait. One Supply Drop slot is always on your main trait (§5).
4. **Sim on the real engine and real AI** (sim-only subclasses), 15,000+ matches. With the end-of-run deck, synergy-aware play beats blind play **60.0%**; the control with synergy off gives 49.9%. The edge grows as the deck grows: 47% with the starter (by design: Recruits have no synergy), 55% mid-run, 60–61% late. Seats stay at 46–54%. With one Spec Ops fix, every trait deck lands at **45–59%** vs the field (§7).
5. **Operator Supply cost** (C): **recommend 1 Supply** to deploy and to respawn. Matches run +0.3 rounds, seat balance is unchanged, and together with the plain starter it brings the campaign back to today's difficulty (37.5% vs 37.8% today). Don't scale it with the mastery tier, because tiers are cosmetic (§6.3).
6. **No new board, card type or row.** Engine cost is a pure synergy helper read by `firepower_of` / `cover_of` / `has_first_shot`, two `CardData` fields, a heal step, Recruit/Promotion per copy, four offer kinds and AI changes (§8). The UI gets link ticks, a trait rail, set callouts and a placement preview (§9).

---

## 1. Goals and constraints
| Goal | How this design meets it |
|---|---|
| Synergy you can read on a phone | Max **4 keywords**, each one line with an arrow glyph that points at the neighbors it uses. A card has **at most one keyword and one trait**. Set bonuses have 2 tiers only. The starter has none of it. |
| Left/right and top/down neighbors | The board already is a grid: 3 columns × 4 rows per side (card-system §4). Neighbors fall out of it, with no new movement rules. |
| "Same kind of calling card" bonus | Traits, illustrated by calling-card families (§4.2). |
| The deck improves through a run | Recruit → Trained, on-trait Supply Drops, Doctrine, Promotion, Retire (§5). Sim: without synergy, adding reward cards barely improves the deck; with synergy it clearly does (§7.4). |
| Fairness rule (card-system §5.6, binding) | Traits and keywords live on the **chassis** (and on a copy's Promotion level, which is earned in the run). Art never changes stats (§4.1). |
| Engine fit | Bonuses are only FP, Cover, First Shot and a heal, read where the engine already reads Field auras. |

## 2. Board geometry: who is a neighbor
```
            Column A        Column B        Column C        (your side; the objective is ABOVE row 1)
 row 1   [ A1 ] ◄──────► [ B1 ] ◄──────► [ C1 ]          ◄► = beside (same row, next column)
           ▲ in front      ▲               ▲
           ▼ behind        ▼               ▼              ▲▼ = in front / behind (same column)
 row 2   [ A2 ] ◄──────► [ B2 ] ◄──────► [ C2 ]
 row 3   [ A3 ]           [ B3 ]           [ C3 ]
 row 4   [ A4 ]           [ B4 ]           [ C4 ]
```
- **In front of** a card means the friendly card one row closer to the objective, in the same column. **Behind** means one row further out. Row 1 has nobody in front of it (the objective is not a card).
- **Beside** means the friendly card in the **same row** of an **adjacent column**. A and C are not adjacent (the engine's `are_adjacent`). So **column B is the hub**: it can have two side neighbors, while A and C can have one. What goes in the middle is a new positional decision.
- **Only your own units are neighbors.** Enemy cards never count. Fields sit on the objective, not in a row, so they are never neighbors (they do count for traits, §4).
- **The Operator and the Sentry token are neighbors** (they are units in a row), but they carry no keyword and no trait.
- **Links are live.** They are recomputed whenever the board changes: an arrival, the Protector slide, a Flank Route move, an elimination and the advance after it. Field frontline auras already work this way (`FRIENDLY_POINT_MAN` follows the line). So a Guard whose front card dies now guards the card that moved up behind it.
- **Rows are your line order** (engine index 0 = row 1). Uneven columns are normal: a card in A3 has no side neighbor if B and C hold only two cards each.

## 3. Neighbor keywords (4)
| Keyword | Glyph | Text on the card (one line) | Uses | Stacking |
|---|---|---|---|---|
| **Guard** | shield + ▼ | **Guard:** the card behind this one has Cover +1. | behind | once (only one card can be behind you) |
| **Spotter** | eye + ▲ | **Spotter:** the card in front of this one gets +1 FP. | in front | once (only one card is in front) |
| **Fireteam** | two chevrons ◄► | **Fireteam:** +1 FP while a friendly card is beside this one. | beside (either side) | self-bonus, max +1 even with two neighbors |
| **Overwatch** | crosshair ◄► | **Overwatch:** cards beside this one have Cover +1. | beside (both sides) | max Cover +1 from Overwatch per card, even with two Overwatch neighbors |

Different keywords stack: a card behind a Guard and beside an Overwatch has Cover +2. Link Cover is removed by the usual answers (Recon Drone, REMOVE_COVER effects), and Blackout still removes First Shot.

**Which chassis get a keyword (Trained copies only; Recruits have none, §5.1).** Each keyword sits where the chassis already wants to stand, so the link teaches the formation the vertical board is built around ("sturdy card in front, sniper behind").
| Chassis | Keyword | Why it fits |
|---|---|---|
| Rifleman (1) | **Fireteam** | Cheap bodies that want a line across all three columns. A Trained Rifleman is a real choice. |
| Point Man (2) | **Fireteam** | Front fighters spread across row 1. |
| Brawler (2, new chassis) | **Fireteam** | Packs, hordes and gangs (its art). |
| Breacher (3) | **Guard** | The front fighter that shields whoever stacks behind it. |
| Protector (3) | **Guard** | Slides to row 1, then covers the card it passed: the "shield wall" combo. |
| Gunner (4) | **Overwatch** | The anchor of column B: one Gunner in B1 covers A1 and C1. |
| Recon Specialist (2) | **Spotter** | Finally a reason to deploy it behind a fighter, not only for its intel. |
| Marksman (3) | **Spotter** | Sits behind the front (where Pick wants it anyway) and calls targets for it. |
| Flanker, Combat Medic, Demolitions Expert, Commander ★, Ace ★, Sentry | — | They already carry Flank / Patch / On Down / auras; one rule each is enough. |

Tactics have no keyword. Formation tools come from existing cards: Flank Route moves a card (and its links) to the next column, and Protector reorders a column.

## 4. Traits: "same kind played together"

### 4.1 Decision: traits come from the CHASSIS, and the art illustrates them (recommended)
| | **A. Trait on the chassis (recommended)** | B. Trait on the art (calling-card family), as a pitch-only exception |
|---|---|---|
| Rule | Each chassis has one trait. The curator gives each chassis arts **from the matching calling-card family**, so a Zombies card is (almost) always on an Undead chassis. | The art's wiki section gives the trait: any Marksman wearing a Zombies card is Undead. |
| Fairness rule | Holds: art never changes power. | **Broken**: a different art means different stats, which card-system §5.6 forbids for the shipping game. |
| Readability | A chassis always plays the same; players learn ~24 cards, not ~300. | Two Marksmen in one deck can play differently, and opponents must know an art's section, which the card doesn't show. |
| Balance | One table to tune (§6). | Every family × chassis pair is its own card: 4 traits × 13 units = 52 variants. |
| Collection | Arts stay cosmetic; a themed deck still looks like a set. | A strong collect hook, but it becomes pay-to-win as soon as arts are sold or earned unevenly. |
| Pitch cost | Re-curate 37 of the 58 traited pitch arts to the matching family (the manifest has the supply, §4.2). | No curation, but the pitch would show a rule we could never ship. |

**Recommendation: A.** It puts the head's "same kind, played together, bonus" on screen (three Zombies calling cards light up the Undead set) without making art a stat. B would demo a rule the public game can't keep.

### 4.2 The four traits and their calling-card families
Family = the MW3 manifest's `section` (how the card is earned). "Available" counts `review = no` cards in `mw3-calling-cards-manifest.csv` from that family whose suggested chassis is that one.

| Trait | Icon (ours) | Units | Field | Identity | Pitch art family | Family arts available |
|---|---|---|---|---|---|---|
| **Vanguard** | chevron | Point Man, Breacher, Protector | Bulwark | Win row 1 | **Prestige & Challenges** (MP Prestige Mastery, Ranked, MP/General challenge cards: earned in combat) | Point Man 23, Breacher 8, Protector 9; Bulwark keeps its Store art |
| **Spec Ops** | mask | Flanker, Recon Specialist, Marksman, Ace ★ | **Sniper Perch** | Win from the back | **Operator bundles** (Store, Battle Pass, Armory, Events: operator portraits) | Flanker 14, Recon 7, Marksman 6; Ace keeps Big Game Hunter; Sniper Perch has no art yet (the pitch set had none) |
| **Heavy** | gear | Gunner, Demolitions Expert, Commander ★ | Mortar Pit | Outlast | **Weapon Mastery** (camo'd weapon showcase cards) | Gunner 28 (LMG), Demolitions 8 (launchers); Commander and Mortar Pit keep their arts |
| **Undead** | hand-from-ground | Brawler, Combat Medic | War Standard, Aid Station | Come back | **Zombies** (Zombies challenges, Zombies Prestige, Zombies section) | Brawler 38, Medic 5, War Standard 8 |
| *(none)* | — | Rifleman, Sentry, Operator; all tactics | Tripwire, Comms Relay, Listening Post | | Default / Store "operator with a rifle" | Rifleman 75 |

- Today **21 of the 58 traited pitch arts already match** their family. **37 need a swap** (Vanguard 8, Spec Ops 12, Heavy 12, Undead 5). The manifest has enough `review = no` cards for every unit chassis. Elites and the Fields with no family art keep their current pick: the rule is the trait icon, not the art.
- **Heavy wears weapon-mastery cards, and so does the Operator** (head, S4). They stay distinct: the Operator has the callsign plate and its own camo ladder, while Heavy units show the gear icon.
- **The public build** uses our own art series with the same names (`series` column, card-system §2.2). The game shows the names Vanguard, Spec Ops, Heavy and Undead. The pitch can label the family in the trait tooltip ("Undead · Zombies cards").
- **Sniper Perch replaces Listening Post as the Spec Ops Field** (sim fix, §7.3). Listening Post becomes untraited.

### 4.3 How a set is counted
- **Count = your Trained units on the board with the trait, plus your visible Fields with the trait** (any column; one Field per column, so up to 3). Recruits, hidden traps, tactics and units still in staging don't count.
- **Tier 2** needs 2 in play; **tier 3** needs 3 in play and includes tier 2. The bonus goes **only to your units with that trait**. Fields count but get nothing (they have no stats).
- Sets are counted live, like links. A set can switch on at Reveal and switch off mid-firefight when a member dies. The trait rail shows it (§9).
- **Board-wide, not per column (decision).** "In the same column" would overlap with Guard and Spotter and would make sets nearly impossible on 4 rows. Board-wide reads as one counter per trait.

### 4.4 Set bonuses (v1.1 numbers, after the sim)
| Trait | 2 in play | 3 in play |
|---|---|---|
| **Vanguard** | Your Vanguard in **row 1** get **+1 FP**. | Your Vanguard get **Cover +1**. |
| **Spec Ops** | Your Spec Ops get **+1 FP**. | Your Spec Ops have **First Shot**. |
| **Heavy** | Your Heavy units have **Cover +1**. | Your Heavy units get **+1 FP**. |
| **Undead** | **End of round:** each damaged Undead heals 1 (never above max Armor). | Your Undead get **+1 FP**. |

Each trait pushes its own formation. Vanguard wants the front. Spec Ops wants the back, and its tier 3 lets Pick fire in the First Shot step. Heavy wants to stand long, and Undead rewards staying in the fight. A trait's Field reaches tier 2 with one unit: e.g. Bulwark + Breacher = Vanguard 2.

## 5. The deck grows into an engine
The run stays Killstreak's 5 matches: Supply Drops after wins (`RewardOffers`), weapon levels after matches 1/3/4 and perk offers after 2/4. The synergy layer adds the Recruit starter and four reward kinds, all on the existing offer queue (`RunProgress._queue_offers`).

### 5.1 The plain starter: Recruits (head's ask A)
**Recruit** = a copy of a chassis with the chassis' stats and printed keyword (First Shot, Pick, Patch…) but **no neighbor keyword and no trait**. It wears the plain frame (no camo band). Every starter card is a Recruit. Reward cards arrive **Trained** (full chassis).

**Recommended starter (sim list "v3"): 20 cards, 9 designs, 4 tactic copies.**
| Card | Copies | Printed rule | | Card | Copies | Printed rule |
|---|---|---|---|---|---|---|
| Rifleman | 3 | — | | Combat Medic | 2 | Patch 2 |
| Point Man | 4 | First Shot | | Gunner | 1 | Suppress |
| Breacher | 3 | First Shot | | Protector | 1 | Cover 1, slides to the front |
| Marksman | 2 | Pick | | Ammo Resupply | 2 | draw 2 |
| | | | | Hold the Line | 2 | Cover 1 to a column |

- **Compared with today's starter** (13 designs, 7 singletons): Callout, Flank Route, Suppressing Fire and Tripwire Charge leave the starter (all are in the reward pool). Point Man +2, Breacher +1, Ammo Resupply +1, Hold the Line +1, Rifleman unchanged. There are 4 tactic designs fewer and **no Field** in the starter: the first Field comes as a reward, which is a good moment to teach the Field strip.
- **Every unit has at most one familiar printed rule**, and the starter shows **no links and no sets**. The tutorial stays as it is.
- **The early squads become Recruits too.** In bracket 1 (slots 1–2), the enemy squads' cards are Recruits. In bracket 2 and the Rival, they are Trained. The sim found that synergy on the squads alone is worth ~14 points of player win rate (today's starter list as Recruits vs Trained squads: 23.8% vs 37.8%, §7.5). A plain player against Trained squads would be the wrong difficulty curve.
- Other lists tested (campaign win rate with bracket-1 squads as Recruits, same seeds): v2 (Rifleman 4, Point Man 4, Breacher 3, Marksman 2, Medic 2, Gunner 1, Ammo 2, Hold 2) 31.2%; **v3 34.2%**; today's list as Recruits 30.2%. Against Trained squads in every slot: v1 (Rifleman 6, no Breacher or Gunner) 13.5% (n = 40 per slot), Callout-heavy lists (v4, v5) 22.8%, v2 24.8%, v3 28.5%.

### 5.2 Rewards
| When | Reward | What it does | Why it feels like progress |
|---|---|---|---|
| After every win (exists) | **Supply Drop**, 3 cards + **Retire** | **New:** slot 1 is always a card of your **main trait** (the trait with most Trained cards in your deck; ties → the trait of your last pick; none yet → the Doctrine trait). Slots 2–3 stay weighted random. Each option shows its trait icon and the count change ("Vanguard 3 → 4"). **4th option: Retire** (§5.4) instead of a card. | You can always push your engine, and still pivot. |
| After match 1 | **Doctrine** (new: pick 1 of 2 trait emblems; the two are your deck's best trait and one random other) | For this run, your sets of that trait count **+1** (one Trained Vanguard on the board already gives tier 2). The emblem sits on your Operator's plate. | An early identity: "this is my Undead run". |
| After matches 2 and 4 (with the perk offer) | **Promotion** (new: pick one copy) | **Recruit → Trained** (it gains the chassis' keyword and trait). **Trained → Veteran:** +1 Armor. **Veteran → Elite:** +1 FP. One level per Promotion; max Elite. | A named card visibly gets better and keeps its art. |
| After a loss (today: nothing, Ruling 12) | **Regroup** (new: a free Retire) | Retire one card. | A loss still moves the deck forward, so no run feels wasted. |
| Always | **Deck view: Engine panel** | Trait counters (Vanguard 4 · Spec Ops 2 · Heavy 1 · Undead 0), keyword counts, the Recruit count, and the next tier the deck can reach. | The engine is visible before it's on the board. |

**The camo band shows the level** (MW3's own progression language, from the weapon-mastery ladder): Recruit = plain frame, Trained = **Gilded**, Veteran = **Forged**, Elite = **Priceless**. **Interstellar** stays the Operator's. The art itself never changes.

### 5.3 Pacing of a typical run
Start: 20 Recruits. After M1: Doctrine, weapon level, Supply Drop (if won). After M2: Promotion, perk, Supply Drop. After M3: weapon level, Supply Drop or Retire. After M4: Promotion, perk, weapon level, Supply Drop. Expected end state for a run with 3–4 wins: **~21 cards, 4 reward cards (Trained), 2–3 Retired, 2 Promoted.** That's the sim's "late" deck (§7). The starter shows no synergy, mid-run decks show some, and the late deck is an engine. This is the curve the head asked for: complexity and combos come as the deck improves.

### 5.4 Card removal: Retire (head's ask B)
| Rule | Value |
|---|---|
| **Where** | (1) As the 4th option of every Supply Drop: take a card **or** Retire a card. (2) **Regroup** after a loss: a free Retire, the only reward after a loss. |
| **How often** | Up to 4 Supply Drops + Regroups per run, so at most ~4 Retires. In practice 1–3, because each Supply Drop Retire costs a new card. |
| **Cost** | Opportunity only: no tickets, no currency. Retiring is a real choice against a new card, and Regroup makes a loss less empty. |
| **Floor** | The deck never goes below **15 cards** (the Retire option greys out). |
| **List order** | Recruits first, then your 1-cost cards, then everything else, with the Supply cost and trait icon shown. |
| **Recruits feel like progress: "two become one"** | Retire a Recruit while a **second Recruit of the same chassis** is in your deck, and that twin is **Trained** for free. Two plain Point Men become one Gilded Point Man: a thinner deck **and** a stronger card. The starter's duplicates (§5.1) exist partly for this. |
| **Show it** | The retired banner flies to the run's **Honor Roll** (an album page in the After-Action; cosmetic). The trained twin gets its Gilded band with a flash. |

Sim proxy: "late" decks = 3 cards Retired + 2 Recruits trained (§7.1, §7.4). They beat the starter 53–76% with synergy, vs 39–58% with synergy off.

## 6. Exact numbers for the first set

### 6.1 Chassis changes (Trained copies; stats unchanged except Recon Specialist)
| Chassis | id | Cost | FP/AR | Existing text | + Keyword | + Trait | Pool |
|---|---|---|---|---|---|---|---|
| Rifleman | `rifleman` | 1 | 2/2 | — | Fireteam | — | starter (Recruit), reward |
| Point Man | `point_man` | 2 | 2/3 | First Shot | Fireteam | Vanguard | starter (Recruit), reward |
| Breacher | `breacher` | 3 | 3/4 | First Shot | Guard | Vanguard | starter (Recruit), reward |
| Protector | `shieldman` | 3 | 1/5 | Cover 1, slides to the front | Guard | Vanguard | starter (Recruit), reward |
| Flanker | `flanker` | 3 | 2/3 | Flank | — | Spec Ops | reward |
| Recon Specialist | `recon_specialist` | 2 | **2/3** (was 1/2) | On Deploy: reveal | Spotter | Spec Ops | reward |
| Marksman | `marksman` | 3 | 2/2 | Pick | Spotter | Spec Ops | starter (Recruit), reward |
| Ace ★ | `halek_wren` | 5 | 4/3 | Pick, +1 streak | — | Spec Ops | reward |
| Gunner | `gunner` | 4 | 2/6 | Suppress | Overwatch | Heavy | starter (Recruit), reward |
| Demolitions Expert | `demolitions_expert` | 4 | 2/4 | On Down: 3 dmg | — | Heavy | reward |
| Commander ★ | `okafor_anvil` | 5 | 3/6 | Holder, +1 FP aura | — | Heavy | reward |
| Brawler | `brawler` | 2 | 2/3 | — | Fireteam | Undead | **reward ×2 (enters the pool now, per S3)** |
| Combat Medic | `combat_medic` | 2 | 1/3 | Patch 2 | — | Undead | starter (Recruit), reward |
| Bulwark *(Field)* | `bulwark` | 3 | — | frontline Cover 1 | — | Vanguard | reward |
| Sniper Perch *(Field)* | `sniper_perch` | 2 | — | Snipers here +1 FP | — | Spec Ops | reward |
| Mortar Pit *(Field)* | `mortar_pit` | 3 | — | 1 dmg to enemy front | — | Heavy | reward |
| War Standard *(Field)* | `war_standard` | 3 | — | frontline +1 FP | — | Undead | reward |
| Aid Station *(Field)* | `aid_station` | 2 | — | heal 1 | — | Undead | reward |

No trait: Rifleman, Sentry, Operator, every tactic, Tripwire Charge, Comms Relay and Listening Post. Smoke Screen, Blackout and Sabotage are unaffected and stay reward-pool candidates (S3).
**Reward pool changes:** + Brawler ×2 (the only Undead unit besides the Medic). Callout, Flank Route, Suppressing Fire and Tripwire Charge each gain +1 copy in the pool, because they left the starter.
**Recon Specialist 1/2 → 2/3** is the one stat change. It was the weakest card in the sim, and Spec Ops was the weakest trait without it (§7.3). At 2/3 for 2 Supply it matches Point Man and Brawler's bodies, and it has no First Shot.

### 6.2 New cards
**None are needed for v1.** Every keyword sits on an existing chassis and every trait has a Field. Two backlog cards, in case playtests show players want more formation control (both need a new effect kind):
- **Regroup Order** (tactic, 1): swap two of your units in the same column or the same row. (new `SWAP` kind, ~20 lines)
- **Rally Banner** (Field, 2): counts as one more card of the trait you choose when you play it. (chosen-trait target, ~15 lines)

### 6.3 Operator Supply cost (head's ask C)
Today the Operator is free to place in round 1 and on every respawn (it respawns each round at full Armor; never in Detonator). Simulated: costs 0 / 1 / 2 Supply for every placement (deploy and respawn), on the recommended plain starter, with the AI paying it too.
| Cost | Rounds per match (aware mirror) | Operator placements per side per round | Seat 0 win | Campaign win (player vs squads, bracket-1 Recruits) |
|---|---|---|---|---|
| 0 (today) | 5.78 | 0.42 | 48.0% | 34.2% |
| **1 (recommended)** | **6.10** | 0.41 | 46.0% | **37.5%** |
| 2 | 6.67 | 0.40 | 50.0% | 38.8% |
(n = 200 mirror matches and 400 campaign matches per cost; ±3.5 / ±2.4 points SE.)

- **Tempo:** the AI still deploys its Operator almost every time it can (placements barely drop), so the cost mainly takes 1–2 Supply from units. That slows the board: +0.3 rounds at cost 1, **+0.9 rounds at cost 2**. At the balance-sim time model (~27 s a round), that's about +8 s vs +24 s per match.
- **Round 1 at cost 2** leaves 0 Supply for cards (round 1 has 2 Supply). The opening becomes "place the Operator, nothing else", which kills the first decision. Cost 1 keeps a 1-drop (a Rifleman or Ammo Resupply) beside the Operator.
- **Seat balance** doesn't move in a way the sim can see (46–50%, inside the noise).
- **Win rate vs squads:** the player gains +3.3 points at cost 1. The squads' AI handles a cost less well than the player proxy, and the Operator down → pay to come back loop rewards the side that kills Operators. Combined with the plain starter, cost 1 puts the campaign at 37.5%, back to today's 37.8%.
- **It makes Operator downs matter** (today a down costs only the streak) and gives Supply a second use late in the match, when it is often unspent.
- **Mastery-tier scaling: not recommended.** The mastery tiers are cosmetic (head S4, card-system §5.6). A cost that scales with the tier would turn a cosmetic grind into a gameplay penalty or perk. If tiers ever add stats, revisit then.
- **Recommendation: 1 Supply per placement, deploy and respawn, both sides, all modes.** It's data plus one check (`_check_place` / `_commit_place`). The card shows a cost hex on the Operator's portrait in the staging tray.

## 7. Sim results (real engine, real AI, sim-only subclasses)
**Harness:** `tests/tools/synergy_sim.gd` + `synergy_rules.gd`. `SynState`, a `MatchState` subclass that exists only in the sim, adds §3–4 where the engine reads FP / Cover / First Shot, adds the Undead heal before the Score step, and adds the Operator cost. The **blind** policy is the stock `AiPlanner` with balance_sim's "competent" settings. It sees bonuses already on the board (its records read `firepower_of`) but never plans for them. The **aware** policy is a planner subclass. It recomputes links and sets for every candidate across all three columns (side links cross columns) and values them for the rounds left: weight 1.5 per point × the share of rounds left, like the stock planner's Field future value. Both use the starter Operator. Seats and modes (Zone Control / Firefight) alternate on Port Vasel. Seat 0 is balance_sim's PLAYER: it commits second (it sees red dots) and wins initiative ties.
Run: `godot --headless --path . -s res://tests/tools/synergy_sim.gd -- exp=duel|mirror|traits|draft|growth|opcost|campaign n=N [base=plain] [retire=N promote=N] [syn=0] …` (options are listed in the file header).
**Statistics:** n = 200 per row gives ±3.5 points SE (±7 at 95%), and n = 160 gives ±4. Use the pooled rows for decisions; single rows wobble. Every number below is a real run. Raw outputs are in the session scratchpad (not committed).

**Decks.** *Starter* = §5.1 v3 (Recruits); "ks" = today's starter. **Trait decks** = starter + 4 Trained cards of one trait: Vanguard: Point Man, Breacher, Protector, Bulwark · Spec Ops: Flanker, Recon Specialist, Marksman, Sniper Perch (v1.0: Listening Post) · Heavy: Gunner, Demolitions ×2, Mortar Pit · Undead: Brawler ×2, Medic, War Standard. *Mid* = those 24 cards. *Late* = mid − 3 Retired (Riflemen first) with 2 Recruits Trained (Point Man / Breacher / Marksman / Medic first). *Mixed* = the same 4 slots filled one per trait (Flanker, Demolitions, Brawler, Mortar Pit), a "blind draft".

### 7.1 Synergy-aware vs blind, same deck (target ≥ 55%)
| Deck stage | Vanguard | Spec Ops | Heavy | Undead | **Pooled** | Control (synergy off) |
|---|---|---|---|---|---|---|
| Starter (Recruits) | — | — | — | — | **47.0%** | 47.0% (identical: Recruits have no synergy, as intended) |
| Mid (+4 Trained) | 54.5 | 48.0 | 57.0 | 61.0 | **55.1%** (n=800) | 52.3% |
| **Late (+4, Retire 3, Promote 2), v1.1 numbers** | 59.5 | 60.0 | 60.0 | 60.5 | **60.0%** (n=800) | — |
| Late, v1.0 numbers | 59.5 | 64.5 | 60.0 | 60.5 | 61.1% | 49.9% |
| Today's starter list with keywords and traits on it (first model, before ask A) | 55.5 | 57.5 | 60.0 | 57.0 | 57.7% (n=1000, incl. starter 58.5) | 52.1% |

- **The target is met where it should be:** late decks reach 60%, about **+10 points over the control**. The aware planner subclass is slightly stronger on its own, because it re-evaluates more (control 50–52%).
- Aware play forms about **twice as many links** (late decks: 0.17–0.26 active links per unit vs 0.09–0.12 blind) and twice as many sets.
- Turn time: aware 7.5–9 ms vs blind 4–5 ms per AI turn (~1.9×), still far below a frame budget.

### 7.2 Seat balance (target: seat 0 within 45–55%, no worse than today)
| Setup | Synergy on | Synergy off |
|---|---|---|
| Late decks (starter / Vanguard / Undead), aware mirror | 48.0 / 53.5 / 46.0 → **49.2%** | 48.0 / 48.0 / 45.0 → 47.0% |
| Same, blind mirror | 47.5 / 55.0 / 46.0 → 49.5% | 47.5 / 47.0 / 44.0 → 46.2% |
| Today's starter-based decks, aware mirror (first model) | 56.5 / 50.5 / 52.0 → 53.0% | 48.5 / 53.5 / 51.5 → 51.2% |
| Plain starter, Operator cost 0 / 1 / 2 | 48.0 / 46.0 / 50.0% | — |

Synergy moves seat 0 by about +2 points (seat 0 sees the red dots and can link around them). That is inside the target and inside the noise of a single row.

### 7.3 Trait balance: round robin, aware vs aware (target: each trait 40–60% overall)
| Version | Vanguard | Spec Ops | Heavy | Undead |
|---|---|---|---|---|
| Synergy off (the 4 card packages alone) | 57.9 | 44.2 | 49.0 | 48.3 |
| v1.0 (Spec Ops tier 2 back rows only, Listening Post, Recon 1/2) | 60.8 | **39.6** | 52.3 | 46.9 |
| v1.0 + Sniper Perch as the Spec Ops Field + tier 2 to all Spec Ops | 60.0 | 39.8 | 51.9 | 47.9 |
| + Recon Specialist 2/2 | 60.4 | 41.2 | 50.4 | 47.5 |
| **v1.1 = + Recon Specialist 2/3 (recommended)** | **58.8** | **46.5** | **49.2** | **45.4** |
| v1.1 with Vanguard tier 2 moved to tier 3 (test) | 60.6 | 47.1 | 48.1 | 44.0 |
(decks: starter + 4 trait cards, Retire 3; n = 160 per pairing, 480 per trait.)

- **Most of the spread is in the card packages, not in the bonuses:** without synergy, Vanguard already leads (57.9) and Spec Ops trails (44.2). The same was true on today's starter (63.8 / 36.2 off, 64.6 / 35.4 on). Synergy v1.0 widened the gap by ~7 points, and v1.1 closes it.
- Vanguard stays the strongest at 58.8%, inside the target. It is the "first trait" most players will find (Point Man and Breacher are in the starter), which is fine for onboarding. Watch it in playtests. The next lever is Vanguard tier 3 → "Cover +1 in row 1 only".

### 7.4 Does the deck grow? End-of-run decks vs the starter (both aware)
| Deck | +4 reward cards | Late (+ Retire 3, Promote 2), synergy on | Late, synergy off |
|---|---|---|---|
| Vanguard | 63.8 | **75.6** | 58.1 |
| Spec Ops (v1.0) | 36.9 | **53.1** | 38.8 |
| Heavy | 55.0 | **67.5** | 49.4 |
| Undead | 47.5 | **65.6** | 49.4 |
| Mixed (blind draft) | 47.5 | **60.0** | 46.2 |

- **Synergy is what makes deck growth pay off.** Without it, a late deck is only 38–58% against the starter. With it, every route beats the starter, and a focused route beats a blind draft.
- Retire + Promotion add 12–18 points on top of the 4 reward cards. That's the "engine forming" the head wants, and it's visible in the counters.
- Draft check (today's starter base): a trait deck played aware vs the mixed draft played blind wins 55.6–74.4%. Against the mixed draft played aware, it wins 47.5–66.9%. Deck choices and board play each add about half of the edge.

### 7.5 Campaign: competent player vs the real squads, starter kit in every slot
Each slot is played with the starting deck, so slots 3–5 understate a real run (the player's deck has grown by then). n = 80 per slot, 400 per row.
| Setup | Slot 1 Rusher | Slot 2 Anchor | Slot 3 Rusher+ | Slot 4 Anchor+ | Slot 5 Rival | **All** |
|---|---|---|---|---|---|---|
| **Today** (today's starter, no synergy) | 53.8 | 57.5 | 30.0 | 38.8 | 8.8 | **37.8%** |
| Today's starter + synergy on everyone (first model) | — | — | — | — | — | 39.0% (blind) / 41.8% (aware) |
| Today's starter list as Recruits vs Trained squads | — | — | — | — | — | 23.8% |
| Plain v3 starter vs Trained squads | — | — | — | — | — | 28.5% |
| Plain v3, bracket-1 squads as Recruits | 57.5 | 60.0 | 20.0 | 27.5 | 6.2 | 34.2% |
| **Recommended: plain v3 + bracket-1 Recruit squads + Operator cost 1** | 61.2 | 68.8 | 20.0 | 32.5 | 5.0 | **37.5%** |
| Same with Operator cost 2 | 62.5 | 72.5 | 22.5 | 30.0 | 6.2 | 38.8% |

The recommended package keeps the campaign at today's overall difficulty, with easier opening matches (61–69%: you learn with a simple deck against simple squads) and the same wall at the Rival. The real run sim (`balance_sim.gd`, with offers taken) must confirm this after implementation, because this harness doesn't play the run's offers.

### 7.6 What the sim does not cover
The Doctrine (+1 set count), Promotion levels 2–3 (+1 Armor / +1 FP), the on-trait Supply Drop slot, Regroup and the twin-training rule are designed but not simulated (the "late" decks approximate their sum). Squads have no Doctrine. Port Vasel is the only map. The aware policy is one strong heuristic, not a human.

## 8. Engine cost (for the mechanics developer, after approval)
| Item | Where | Size |
|---|---|---|
| `CardData.neighbor_keyword: StringName` (`guard` / `spotter` / `fireteam` / `overwatch` / empty) and `CardData.trait: StringName` (`vanguard` / `specops` / `heavy` / `undead` / empty); validator: trait only on units and Fields | `scripts/data/card_data.gd`, `data_validator.gd`, `gen_content.gd`, 18 `.tres` | data |
| Per-copy level: `SideSetup.deck_levels: Array[int]` (0 Recruit, 1 Trained, 2 Veteran, 3 Elite), parallel to `deck` like `deck_arts`; `RulesCard.level`; `create_unit` applies +AR / +FP and drops keyword and trait for Recruits | `side_setup.gd`, `rules_card.gd`, `match_state.create_unit` | ~25 lines |
| `SynergyRules` (static, pure): per side → per unit `{fp, cover, fs, heal, links}`. The sim's `synergy_rules.gd` is the reference implementation | new `scripts/rules/synergy_rules.gd` | ~120 lines |
| Read it in `firepower_of`, `cover_of` (after the REMOVE_COVER check) and `has_first_shot` (after REMOVE_FIRST_SHOT); cache it per board change with a `board_version` bumped by `put_in_line`, removals and moves | `match_state.gd` | ~25 lines |
| Undead heal after the Firefight, before END_OF_ROUND effects; reuse `UNIT_HEALED` with `source_id = &"trait_undead"` | `match_state.score()` | ~12 lines |
| Operator cost: `RunConfig.operator_cost = 1`; check and pay in `_check_place` / `_commit_place` (refund on undo already uses `play.cost`) | `run_config.gd`, `match_state.gd` | ~8 lines |
| Doctrine: `SideSetup.doctrine` (+1 to that trait's count) | `side_setup.gd`, `synergy_rules` | ~6 lines |
| Run: starter as Recruits, `RunProgress.deck_levels` (save version 2), Promotion / Doctrine / Retire / Regroup offers, on-trait Supply Drop slot, twin training, 15-card floor; bracket-1 squads as Recruits (`RunMatchData.enemy_recruits: bool`) | `run_progress.gd`, `reward_offers.gd`, `run_match_data.gd`, `run_config.tres` | ~110 lines |
| Data: the v3 starter list, reward pool + Brawler ×2 and +1 Callout / Flank Route / Suppressing Fire / Tripwire, Recon Specialist 2/3 | `run_config.tres`, `recon_specialist.tres`, `gen_content.gd` | data |
| AI: AiView records carry `keyword` / `trait` / `level`; the planner recomputes bonuses per candidate across columns (unit / place / rotate / Field actions touch all 3 zones), adds the future value and pays the Operator cost. The sim's `SynPlanner` / `OpPlanner` are the reference | `ai_view.gd`, `ai_planner.gd` | ~90 lines; ~1.9× turn time |
| UI view: `MatchState.synergy_view(viewer)` → per unit `{uid, links: [{kind, from_uid}], sets: [[trait, tier]]}` and per side `{trait: count, tier}`; event `SYNERGY_CHANGED` only when a tier or link flips | `match_state.gd` | ~30 lines |
| Tests: geometry (beside / behind / front, A–C not adjacent), live re-link after an advance and a Protector slide, stacking caps, Cover removal, set count incl. Fields and Recruits, Undead heal cap, Doctrine, levels, Operator cost incl. undo, Retire floor and twin training, save/load | `tests/test_rules_synergy.gd`, `test_run_*` | ~50 tests |
| Re-run `balance_sim.gd` (runs with offers) after implementation | | |

## 9. UI needs (for the UI/UX agent)
**Board** (phone landscape, 4:1 banner slots, card-system §3.4):
- **Keyword pip** on the banner's outer edge, next to the effect glyph: the keyword glyph with its arrow (▲, ▼ or ◄►). Grey while the link is idle, lit while it's active.
- **Link ticks**: a short glowing tick between two linked banners. Vertical between rows for Guard / Spotter, horizontal across the column gap for Fireteam / Overwatch. Draw only **active** links, at most one tick per pair, in the owner's colour (teal / red). Ticks slide with the line when it advances.
- **Stat delta**: the FP / Cover icons already show ▲ when modified (card-system §3.4), and link and set bonuses use the same marker. The inspector lists sources: "FP 3 = 2 + Spotter (Marksman, behind) + Vanguard 2".
- **Trait icon** on every Trained banner (small, bottom-left, next to the class pip) and on hand cards (next to the cost hex). **Recruits show no trait icon and no keyword pip**, just the plain frame.
- **Camo band** on the frame for the level: Recruit = none, Trained = Gilded, Veteran = Forged, Elite = Priceless.
- **Trait rail** per side (a thin strip by the Streak arc or along the board's outer edge): only the traits you have in play (max 4), each with a counter like "2/3". The icon lights at tier 2 and gets a ring at tier 3. The Doctrine trait has a small emblem mark.
- **Set callouts**: when a tier switches on, a short banner over the rail ("UNDEAD 2: heal 1 each round") shows for ~1.2 s, then folds into the rail. When a tier switches off (a member died), the icon dims with a crack tick. At most one callout per side per step.
- **Placement preview**: while dragging a unit over a column, show ghost link ticks and chips ("+1 FP", "Cover +1", "Vanguard 2 ▶ 3") before the drop. This is the main teaching tool, and it makes the hub column visible.
- **Field strips** show their trait icon (Fields count for sets).
- **Operator cost**: a cost hex on the Operator's staging card and on the respawn prompt. It's greyed with "1 Supply" when you can't afford it.
- **Hand**: trait icon and keyword pip on Trained cards; a dot on cards that would complete a tier if played this round.
- **Deck view and rewards**: the Engine panel (§5.2), the on-trait Supply Drop slot marked, "Vanguard 3 → 4" on offers, the Retire option (with the twin-training preview "Point Man → Gilded"), the Promotion picker showing the next band, the Doctrine emblems, and the Honor Roll page in the After-Action.
- **Accessibility**: link ticks also differ by shape (vertical bar vs horizontal bar), trait icons are shapes rather than colours, and callouts use text.
- **Inspector** (right click / long press): the full keyword text, which neighbors count (a mini 3×4 grid with the cells highlighted), the trait tier texts with the current count, and the copy's level.

## 10. Questions for the head (recommended option first)
1. **Where traits come from:** (a) **the chassis, with the pitch arts re-curated so each trait wears its calling-card family** (Zombies → Undead, weapon mastery → Heavy, operator bundles → Spec Ops, prestige/challenges → Vanguard; 37 swaps) (recommended), or (b) the art's family as a pitch-only exception (literal, but it breaks the fairness rule and can't ship).
2. **Starter and early squads:** (a) **the plain 9-design Recruit starter (§5.1), with bracket-1 squads as Recruits too** (recommended: same overall difficulty with Operator cost 1, easier first matches), (b) keep today's 13-design starter list as Recruits (more variety, 30% campaign), or (c) keep today's starter with keywords and traits on it (synergy from match 1; 39–42%; more to read early).
3. **Card removal:** (a) **Retire as the 4th Supply Drop option + a free Regroup Retire after a loss, a 15-card floor, and the twin-training rule** (recommended), (b) Retire only after losses, or (c) a paid Retire (a ticket).
4. **Operator Supply cost:** (a) **1 Supply for every placement, deploy and respawn** (recommended: +0.3 rounds, seats unchanged, +3 points vs squads), (b) keep it free (today), or (c) 2 Supply (+0.9 rounds and an empty round 1). Not recommended in any option: scaling the cost with the mastery tier, because tiers are cosmetic.

---

## 11. Implementation (kc-syn-impl, after the head's approval of S1-S4 with the recommended answers)
*Mechanics Developer Agent · 2026-11-05 · rules / data / AI / run state only (no UI or scene file touched). Status: implemented and tested; the UI is a later task (§11.4).*

### 11.1 What shipped where
| Item | Where |
|---|---|
| `SynergyRules` (static, pure): the 4 keywords, the 4 traits with the v1.1 tier table, copy levels (Recruit / Trained / Veteran / Elite), texts for the UI | `scripts/rules/synergy_rules.gd` |
| `CardData.neighbor_keyword`, `CardData.card_trait` (`trait` is a reserved word in GDScript) + validation; 18 chassis per §6.1; Recon Specialist 2/3; Sniper Perch = Spec Ops, Listening Post untraited | `card_data.gd`, `data/cards/*.tres` |
| Copy level: `SideSetup.deck_levels` (parallel to `deck`, missing = Trained), `RulesCard.level`, `RulesUnit.level / neighbor_keyword / synergy_trait`; `create_unit(side, card, uid, level)` drops keyword + trait on Recruits, Veteran +1 Armor, Elite +1 Armor +1 FP; the discard keeps the level | `side_setup.gd`, `rules_card.gd`, `rules_unit.gd`, `match_state.gd` |
| Read live in `firepower_of`, `cover_of` (removed with the rest by REMOVE_COVER) and `has_first_shot` (removed by REMOVE_FIRST_SHOT); cached per board signature (line order + Fields of both sides) | `match_state.gd` |
| Undead heal at the start of the Score step (after the Firefight, before END_OF_ROUND effects), `UNIT_HEALED` with `source_id = &"trait_undead"` | `match_state.gd` |
| Doctrine: `SideSetup.doctrine` (+1 to that set count while the side has a member in play) | `side_setup.gd`, `synergy_rules.gd` |
| Operator cost: `RunConfig.operator_cost` (1 in `run_config.tres`, 0 for `RunConfig.new()`), checked / paid in `_check_place` / `_commit_place`, refunded by undo | `run_config.gd`, `match_state.gd` |
| AI: records carry `kw / trait / level / syn_*`; `AiPlanner.synergy_aware` (default on, squads and player proxies) re-computes links and sets on all three columns per unit / Operator / traited Field / move candidate and values them for the rounds left (`synergy_future_weight` 1.5); the planner pays the Operator cost; a Recruit and a Trained copy of one design are planned separately | `ai_view.gd`, `ai_planner.gd` |
| Run: plain v3 Recruit starter (`starter_recruits`), Trained rewards, Bracket-1 squads as Recruits (`RunMatchData.enemy_recruits`), main trait + on-trait Supply Drop slot (`supply_drop_on_trait`), Doctrine, Promotion, Retire (4th Supply Drop option), Regroup (free Retire after a loss), twin training, 15-card floor, Honor Roll, save version 2 (version 1 saves load as all-Trained) | `run_progress.gd`, `reward_offers.gd`, `run_config.gd`, `run_match_data.gd`, `run_config.tres`, `autoload/run_state.gd` (`retire_card`) |
| Data: §6.1 numbers, reward pool + Brawler x2 and +1 Callout / Flank Route / Suppressing Fire / Tripwire Charge | `run_config.tres`, `recon_specialist.tres`, `gen_content.gd` (notes) |
| Pitch: 31 traited unit arts re-picked to their calling-card family (`../art/mw3-pitch-set.md` §1.1); `PitchDecks.apply_setup(setup)` keeps `deck_levels` parallel and trains the pitch decks | `mw3-pitch-set.csv/.md`, `pitch_decks.gd` |
| Tests: `tests/test_rules_synergy.gd` (25), `tests/test_run_synergy.gd` (10); balance tool `tests/tools/synergy_check.gd` (the shipped engine); `synergy_sim.gd` now switches the engine's synergy off so it still measures the proposal model alone | `tests/` |

**One deviation, waiting on the UI:** `RunConfig.synergy_offers` is **false** in `run_config.tres`. Doctrine, Promotion, Retire and Regroup are implemented and tested, but today's reward screen renders every option as a card or loadout item, and a Doctrine option is a trait id (it would break the screen). Flip it to true when the Doctrine / Promotion / Retire screens land. The Recruit starter, Trained rewards, Recruit squads, the on-trait slot and the Operator cost are live now.

### 11.2 Numbers on the shipped engine (synergy_check.gd, balance_sim.gd; seats and modes alternate, Port Vasel)
| Check (target) | Result | Doc §7 (proposal model) |
|---|---|---|
| Aware vs blind, same **late** deck (>= 55%) | **52.0%** pooled (Vanguard 60.0, Spec Ops 49.0, Heavy 50.5, Undead 48.5; n = 800) | 60.0% |
| Same at Operator cost 0 | 55.0% (61.0 / 52.0 / 54.5 / 52.5) | (cost 0) 60.0% |
| Same, **mid** decks | 49.8% | 55.1% |
| Same, late decks with every copy Trained (no Recruits) | 62.4% | 57.7% (today's starter with synergy) |
| Control: late decks, synergy off (aware search, nothing to find) | 46.0% | 49.9% |
| Seat 0, aware mirror, starter + 4 late decks (45-55%) | **51.8%** (47.5 / 54.5 / 48.0 / 49.5 / 59.5; n = 1000) | 49.2% |
| Trait round robin, late decks, aware (40-60% each) | Vanguard **67.3**, Spec Ops **42.3**, Heavy 47.7, Undead **42.1** (n = 480 per trait) | 58.8 / 46.5 / 49.2 / 45.4 |
| Same, synergy off (the packages alone) | Vanguard 56.9, Spec Ops 41.9, Heavy 49.4, Undead 50.4 | 57.9 / 44.2 / 49.0 / 48.3 |
| Same with Vanguard tier 3 = "Cover +1 in row 1 only" (the doc's next lever) | Vanguard 66.2: no real change | — |
| Campaign: aware player, Recruit starter in every slot vs the real squads (today 37.8%) | **37.5%** with aware squads (63.8 / 70.0 / 17.5 / 30.0 / 6.2), 38.5% with blind squads | 37.5% |
| Full runs, competent proxy, offers taken (balance_sim, 300 runs) | **40%** run win (synergy offers off, as shipped) vs **41%** before kc-syn-impl; per match M1 83 / M2 95 / M3 19 / M4 25 / M5 47 (before: 65 / 90 / 38 / 47 / 47) | — |
| Same with `synergy_offers` on (Doctrine 0, Promotion / Regroup first option, Retire a twin Recruit at 22+ cards) | 34% (M3 16, M4 34, M5 39) | — |
| AI turn time (aware / blind) | 7.4-8.6 ms / 4.0-4.6 ms per turn (~1.9x) | 7.5-9 / 4-5 ms |

- **Aware vs blind misses the 55% target on late decks (52%).** Two reasons in the data: the late decks are still mostly Recruits (15 of 21 cards), so there are few links to plan (all-Trained decks give 62%), and the Operator cost takes the Supply a planner would spend on a linking unit (cost 0: 55%). Against the synergy-off control (46%) the planning edge is +6 points. Vanguard is the only deck far above 55%.
- **Vanguard is too strong (67%, target <= 60%)**, and it is mostly the package (57% with synergy off) plus the starter: 8 of the 20 Recruits are Vanguard chassis, so every Promotion and twin training feeds Vanguard. The doc's tier-3 lever does nothing here. Candidate levers for the designer: fewer Vanguard Recruits in the starter (e.g. Point Man 4 -> 3, Rifleman 3 -> 4), or Vanguard tier 2 at 3 in play.
- **The difficulty curve moved as designed but steeper:** Bracket 1 is easier (83-95%), the first Trained squad (M3, Rusher+ in Firefight) is a wall (38% -> 19%), and the run total is unchanged (40% vs 41%).
- The Doctrine / Promotion / Retire offers with the sim's naive picks did not raise the run win rate (34% vs 40%, about 1.5 standard errors); a player who promotes on-trait cards should do better. Re-measure with the real screens and a smarter offer rule.
- Run: `godot --headless --path . -s res://tests/tools/synergy_check.gd -- exp=duel|mirror|traits|campaign n=N [stage=mid|late] [opcost=N] [trained=1] [syn=0] [squads=aware|blind] [tune=vanguard.1.where=front]`; balance_sim adds `synoffers=1 aware=0|1 squadaware=0|1 syn=0`.

### 11.3 UI hooks
**Match (MatchState, public board information, safe for either viewer):**
- `synergy_view(viewer) -> {player: SIDE, enemy: SIDE, units: {uid: UNIT}}`.
  `SIDE = {counts: {trait: n}, tiers: {trait: 0|2|3}, doctrine: trait, links: [{kind, from_uid, to_uid}], rail: [{trait, name, count, tier, next, doctrine}]}` (rail = traits with count > 0 in `SynergyRules.TRAITS` order; `next` = the next threshold or 0 at tier 3).
  `UNIT = {uid, side, keyword, trait, level, band (&"" / gilded / forged / priceless), fp, cover, fs, heal, links: [{kind, from_uid}], sets: [[trait, tier]]}`. fp / cover / fs / heal are the synergy part only (`firepower_of` / `cover_of` / `has_first_shot` already include it), so the inspector can write "FP 3 = 2 + Spotter + Vanguard 2". Link ticks: one per `links` entry of the side (`from_uid` gives, `to_uid` receives; Fireteam's `from_uid` is the friend beside it).
- `synergy_of(unit)`, `synergy_side(side)`: the same data for one unit / one side.
- `preview_synergy(side, hand_card_uid, zone) -> {ok, links, new_links, card: {fp, cover, fs, links, sets}, tiers_before, tiers_after, counts_before, counts_after}`: the placement preview (ghost ticks, "+1 FP", "Vanguard 2 ▶ 3") for a unit or a Field arriving after this Deploy's queued plays.
- `card_level(uid)` for any copy (hand, deck, discard, plays, Fields, board); `RulesCard.level`, `RulesCard.neighbor_keyword()`, `RulesCard.card_trait()`; `RulesUnit.level / neighbor_keyword / synergy_trait`. Hand cards of a Recruit return `&""` for both: no trait icon, no keyword pip.
- Events: `RulesEvent.SYNERGY_CHANGED {side, links, counts, sets}` after Reveal, the Firefight and the Score step, only when a side's links or tiers changed (set callouts, crack ticks); `UNIT_HEALED` with `source_id = &"trait_undead"` (heal float text).
- Operator cost: `operator_cost()`; `check_use(side, &"operator")` / `can_submit(place_operator)` refuse with `not_enough_supply {cost, supply}` (grey the staging card with "1 Supply").
- Texts: `SynergyRules.KEYWORD_TEXT`, `TIER_TEXT` (per trait: [tier 2, tier 3]), `TRAIT_NAMES`, `LEVEL_NAMES`, `LEVEL_BANDS`, `TIER2` / `TIER3`.

**Run (RunProgress, through RunState.run):**
- `deck_levels` (parallel to `deck`), `level_of(i)`, `deck_view() -> [{index, id, level, level_name, band, keyword, trait}]`.
- `engine_summary() -> {traits: {trait: Trained n}, keywords: {kw: n}, recruits, main_trait, doctrine, deck_size, floor}` (the Engine panel), `trait_counts()`, `main_trait()`.
- Offers (`current_offer()`): `supply_drop` may carry `on_trait: trait` (slot 1 is on it; show "Vanguard 3 ▶ 4") and `retire: true` (show Retire as the 4th option); `doctrine` (options = trait ids; `choose_offer(i)`); `promotion` and `regroup` (options = card ids + parallel `levels`; each option is the first copy of that design at that level; `choose_offer(i)`). Promotion / Regroup options are rebuilt when they become current (an earlier offer may have changed the deck).
- `retire_options() -> [{index, id, level, cost, trait, twin_index}]` (Recruits first, then 1-cost cards, then the rest; `twin_index >= 0` = "Point Man ▶ Gilded" preview), `can_retire()` (false at the 15-card floor: grey the option), `retire_card(i)` / `RunState.retire_card(i)` (resolves the Supply Drop or the Regroup; EventBus `reward_picked(&"retire", id)`).
- `promotion_options() -> [{index, id, level, next_level}]`, `doctrine`, `honor_roll: [{id, level, match, trained_twin}]` (After-Action album page).
- `RunConfig.starter_levels()` gives the starter's levels for setups built outside a run.

### 11.4 Open items for the UI task
1. The reward screen needs the Doctrine / Promotion / Regroup / Retire views; then set `synergy_offers = true` in `run_config.tres`.
2. `MatchController.start_local_match` and the tutorial build their player setup from `config.starter_deck` without levels, so the quick match and the tutorial play a **Trained** starter (`deck_levels` empty = Trained). Use `config.starter_levels()` for the quick match; the tutorial can stay Trained or go plain (its script was written for today's cards).
3. `MatchController.start` should call `PitchDecks.apply_setup(s.setup)` instead of `apply(s.setup.deck)` so the pitch decks show links and sets.
4. The phone inspector of the Protector is 1 px too tall (InfoPanel 135 + 406 = 541 on a 540 canvas): `test_board_layout` (inspector phone ×2) and `test_board_columns::test_inspector_shows_the_512_banner_and_rails_inspect` fail now that the new starter puts a Protector in the first hand of the test seed. Not a rules change; the layout needs a pixel of slack.

---

## 12. Tuning v1.2 (done) and v1.3 (after the loadout cut, §12.5b)
*Sr Game Designer Agent · 2026-11-06 · board task kc-syn-tune · resumed after the firefight order (kc-fight) and the onboarding ladder (6d17ea1) landed · **Status: done, not committed** (the lead commits). Changed: `data/run_config.tres` (the M3 and M4 crews), `scripts/rules/mode_rules.gd` (an initiative tie-rule switch for balance tools; the shipped rule is unchanged), the new tool `tests/tools/tune_check.gd`, and tests `test_rules_modes.gd` (tie rules) and `test_onboarding.gd` (the M3 / M4 decks). No trait bonus, card, squad file, UI or loadout file was changed.*
*§12.7–12.8 below are the paused pass on the old deck model (d154893), kept for the record.*

### 12.1 Tool
`tests/tools/tune_check.gd` plays the **real** run like `onboarding_check.gd` (shipped `run_config.tres`, real `RunProgress` offers, balance_sim's competent / casual proxies and offer rule), keeps the M5 decks, and runs every target on them: trait round robin (end-of-run decks grouped by `main_trait()`), aware vs blind, and the seat-0 mirror with initiative statistics. What-ifs in memory: `tiebreak=` / `mtie=` (tie rule), `set=card.prop=v`, `slot=N.prop=v`, `sdeck=N:card*n,...`, `cfg=prop=v`, `tune=trait.tier.key=v`.
`godot --headless --path . -s res://tests/tools/tune_check.gd -- runs=400 late=160 mirror=1920 tn=160`

### 12.2 What changed (numbers only)
| Slot | Before | After | Why |
|---|---|---|---|
| M3 (SandViper_07, Honors crew, Firefight, Recruits) | the shipped Rusher deck | the Rusher deck with its **Breach and Clear → 1 Standard Issue Sergeant** (`enemy_deck`) | Breach and Clear (2 damage to every enemy unit in a column, 3 at Close) wipes a Standard Issue line, and in Firefight every kill scores. This one card was the M3 cliff: taking it out moves M3 from 37.5% to 54% (also taking out the 2 Flank Routes: 74%) |
| M4 (Bulwark_Nine, Mastery crew, Firefight, Trained) | the shipped Anchor deck | the Anchor deck with **2 Demolitions Experts + the Marksman → 2 Armored Troopers + 1 Sergeant** (`enemy_deck`) | Smaller step than Recruits (which gave 54%, above M3). Lands M4 between M3 and the Rival |
| M1, M2, M5, traits, cards, reward pools | — | unchanged | Already on target (see the table) |

The enemy now "climbs one step behind you" in the deck too: a few Standard Issue cards remain in the M3 / M4 crews, as in the player's own M3 / M4 deck.

### 12.3 Before / after (shipped 6d17ea1 → this pass; 400 real runs per proxy, same seeds)
| Check (target) | Before | After | n | Tool |
|---|---|---|---|---|
| New player (casual) M1 (65–75%) | 69.8% | **69.8%** (M1 untouched) | 400 | tune_check, onboarding_check |
| Competent full run (38–43%) | 41.0% | **39.2%** (±2.4) | 400 | all three tools agree |
| Competent per match M1–M5 (smooth ramp) | 95.5 / 97.8 / **37.5** / 38.8 / 42.2 | 95.5 / 97.8 / **54.0** / 42.8 / 39.8 | 400 | |
| Casual full run · per match | 23.5% · 69.8 / 71.8 / 55.5 / 36.1 / 30.4 | 20.5% · 69.8 / 71.8 / 64.8 / 41.9 / 24.6 | 400 | |
| Traits, end-of-run decks by main trait (40–60% each) | Undead 50.8 · Vanguard 48.8 · Heavy 45.4 · Spec Ops 55.0 | Undead 51.7 · Vanguard 49.6 · Heavy 46.7 · Spec Ops 52.1 | 480 per trait | tune_check |
| Traits, old deck model (synergy_check late) | Vanguard 67.3 (d154893) | Vanguard 53.3 · Spec Ops 44.6 · Heavy 54.6 · Undead 47.3 (no squad in this check) | 480 per trait | synergy_check |
| Aware vs blind, end-of-run decks (≥ 55%) | 55.9% | **57.7%** | 640 | tune_check, onboarding_check |
| End-of-run deck vs the starter | 74.7% | 77.3% | 640 | onboarding_check |
| Seat 0, end-of-run deck mirror (45–55%) | 61.6% (n = 320) · **53.8%** (n = 1860) | **51.0%** | 1920 | tune_check |
| Seat 0, Standard Issue starter mirror (45–55%) | 53.5% (n = 1000) · 52.1% (n = 1920) | 52.1% (unchanged: no data it uses changed) | 1920 | |

- Every target is met. The 61.6% "watch" number of the onboarding notes was a small sample (n = 320, ±2.7): with the same tool at n = 1860 the shipped build reads 53.8%, and 51.0% after this pass.
- The ramp no longer has a 60-point cliff after M2. It now goes easy, easy, then about a coin flip, then a bit harder each match up to the Rival. M2 stays easy on purpose (see §12.6 Q2).
- Rejected levers: M3 / M4 Armor −1 (M3 62.5%, M4 67%: overshoots, and −1 marks a slot as the green squad), M4 Recruits (M4 54% > M3), M3 in Zone Control (competent 64–79% but new player 46%, and Firefight would first appear at M4), M2 Armor +1 or Trained Gunners (competent 85 / 73.5% but new player 47 / 44.5%), a 4th Gunner in M2 (no effect), `firefight_target` 6 or 8 (±3 points, both slots move together).

### 12.4 Initiative ("What do you mean first player? Cards are revealed at the same time.")
Both sides commit face down and their cards are revealed together. There is no first player for committing. But the Reveal still has to resolve one side's plays before the other's, and that side holds **initiative**: the side behind on the mode score, and on a tie the player (`ModeRules.initiative_side`; the board's initiative banner). Initiative orders four things: (1) Reveal (Equipment placed, units arriving, then tactics and loadout items, the initiative side first in each step), (2) removing the dead, (3) the firefight's per-side loops, (4) the Score step (Undead heal, end-of-round effects, Overrun, streaks).
**What it is worth (sim, aware mirror, n ≈ 1900 per row; scratch copy with a per-step order switch):**
| Test | Late decks | Starter |
|---|---|---|
| Shipped: ties → player | 53.8% | 52.1% |
| Ties → enemy (seat 0 holds initiative only 22% of rounds) | 52.8% | 48.5% |
| Ties alternate by round · ties swap (round 1 player) · coin flip in round 1 then swap · coin flip every tie | 56.6 · 53.5 · 53.5 · 56.5% (the 56% values are n = 620) | 53.4 · 51.6 · 50.7 · 51.7% |
| Seat 1 forced first in every step (vs only in Reveal) | 51.5% (identical) | 48.8% (identical) |
| No Frag Grenade / Flashbang / secondary (kc-loadout-cut preview): ties → player · ties → enemy | 52.3 · 52.1% | 49.7 · 49.8% |
- **Only the Reveal order matters.** Forcing seat 1 first in deaths, the firefight and the Score step changed no result at all (the beats are simultaneous and removal is order-free). Ties come up in about 53% of rounds (always in round 1).
- **The tie edge is the loadout items.** Ties → player is worth ~3.6 points in the starter mirror, ~1 point on late decks. Without the grenade, flashbang and secondary it is worth **0** (49.7 vs 49.8%): resolving first matters when your Frag Grenade / Flashbang hits before the other side's plays resolve. Once kc-loadout-cut lands, the tie rule will no longer move the seat numbers.
- The other ~2 points of seat 0 on late decks are the sim's turn order (the player-seat AI commits after the enemy AI; with the player AI first: 50.1%). A human gets this too, by design: the enemy commits first so your red dots are complete (Ruling 13).
- **Recommendation: keep "ties → you".** It is in band (51–54%), it is the shortest sentence for a player ("Behind on score? You resolve first. Tied? You do."), and in a PvE game the edge goes to the player. After the loadout cut it is worth nothing in the mirror anyway. "Ties swap" is ready behind `ModeRules.tiebreak` (`&"other"` / `&"coin"`; tested in `test_rules_modes.gd::test_initiative_tie_rules`) if a PvP mode ever needs it.

### 12.5 Depends on the loadout cut (kc-loadout-cut; landed in 1bf3b22, re-tuned in §12.5b)
The head removed the Frag Grenade, Flashbang and secondary. Every run number above uses the old loadout, so they move when the cut lands. Re-check with the command in §12.1 and `onboarding_check.gd -- runs=400 late=160 mirror=1000`.
- **Initiative tie edge:** comes from those items (above). Expect the starter mirror to go from ~52 to ~50%.
- **Run and per-match win rates:** the player and every squad lose the items. M1 (new player 69.8%) and M5 (the Rival has the most loadout) are the most likely to move. If M1 leaves 65–75%, the lever is the M1 squad's Armor (−1 now) or its deck.
- **Aware vs blind (57.7%) and traits:** the AI's item plays are a small share of these, so they should move only a little; worth a look.

### 12.5b v1.3: retune after the loadout cut (kc-syn-tune2, 2026-11-06, not committed)
The cut (1bf3b22) moved the numbers as §12.5 expected: the new player won M1 too often, the M3 Rusher became a wall again, and Spec Ops (whose Recon / Marksman decks lost nothing) rose to 61.9%. All three fixes are data / balance constants:
| What | v1.2 | v1.3 | Why |
|---|---|---|---|
| M1 crew (`enemy_deck`, still −1 Armor, still the green squad) | Grunt 5 · Trooper 7 · Sergeant 3 · Armored 1 · Ammo 2 | **Grunt 6 · Trooper 7 · Sergeant 2** · Armored 1 · Ammo 2 | Cheap bodies fill the columns and hold zones. Armor −1 → 0 overshoots: new player 23%. Fewer Grunts (more Sergeants) makes M1 easier (87%) |
| M3 crew (`enemy_deck`, Recruits, Firefight) | the Rusher units + 2 Flank Routes, Callout, Tripwire, a Sergeant | the Rusher units (3 Point Man, 3 Breacher, 2 Flanker, 2 Rifleman, Shieldman, Medic) + **3 Troopers, a Grunt, a Sergeant**, Ammo Resupply | Without your grenade, the Rusher's tactics and its Tripwire decided M3. Only swapping the Flank Routes: 42–44% |
| Spec Ops tier 2 (`SynergyRules.TRAIT_BONUS`) | +1 FP to all Spec Ops | **+1 FP to Spec Ops in row 1** (like Vanguard tier 2); tier 3 (First Shot for all) unchanged | Spec Ops 61.9% → 50.6%. Giving Heavy a tier-2 bonus instead brought Heavy up but pushed the run to 43–44% |
| `AiPersonality.cooldown_keep_cost` | retired field, still set by tune_check | **removed** (field and tool use) | Cleanup after the cut |

**Before / after (tune_check, 400 real runs per proxy, late = 160 decks, mirror n = 1920, traits n = 480; onboarding_check agrees on runs and duel)**
| Check (target) | After the cut, v1.2 data | v1.3 |
|---|---|---|
| New player M1 (65–75%) | **77.8%** | **73.0%** |
| Competent run (38–43%) | 41.8% | **40.0%** |
| Competent M1–M5 | 91.5 / 99.0 / **36.8** / 41.2 / 43.0 | 88.2 / 99.0 / **58.8** / 42.5 / 41.1 |
| Casual run · M1–M5 | 23.5% · 77.8 / 80.0 / **29.2** / 34.0 / 29.5 | 26.0% · 73.0 / 81.0 / **44.8** / 35.1 / 31.8 |
| Traits (40–60% each) | Undead 50.0 · Heavy 40.8 · Vanguard 47.3 · **Spec Ops 61.9** | Undead 51.9 · Heavy 45.4 · Vanguard 52.1 · Spec Ops 50.6 |
| Aware vs blind, late decks (≥ 55%) | 55.8% | **58.6%** (n = 640) |
| End-of-run deck vs the starter | — | 80.9% |
| Seat 0, late mirror (45–55%) | 51.8% | 49.3% |
| Seat 0, starter mirror (45–55%) | 49.7% | 49.7% |

**Initiative after the cut (confirms §12.4's preview).** Same 160 late decks, n = 1848–1920 per row. Ties → player: 49.3% late / 49.7% starter. Ties → enemy: 49.2 / 49.8%. Coin flip in round 1, then swap: 49.1 / 49.8%. **The tie rule is now worth nothing**: seat 0 is ~50% under every rule, so "ties → you" stays and costs no fairness. Seat 0 still holds initiative in 78% of rounds (ties happen in 55–57% of rounds), but with the grenade, flashbang and secondary gone, resolving first no longer changes results.

Notes: the competent M3 (58.8%) now sits above M4 (42.5%), and a casual player wins M2 (81%) more often than M1 (73%). Both are small bumps, not cliffs. M2 is the easiest match for everyone (Q2 below).

### 12.6 Questions for the head (recommended option first; updated for v1.3)
1. **Spec Ops tier 2 becomes "Spec Ops in row 1 get +1 FP"** (players see this text; it mirrors Vanguard's tier 2). (a) Approve: Spec Ops 61.9% → 50.6%, aware edge up to 58.6%. (b) Keep the old text and trim a Spec Ops card instead (untested; Recon Specialist / Marksman are the candidates).
2. **M2 is the easiest match** (solid player 99%, new player 81%, above M1's 73%). (a) Keep it: a breather after the first calling cards. (b) M2 squad Armor +1: with the old loadout it gave the solid player 85% and the new player 47%, too harsh.
3. **Initiative ties** (from v1.2; now settled by data). (a) Keep "ties → you": after the cut every tie rule gives seat 0 ~49–50%, so it costs nothing. (b) Ties swap / coin flip: same numbers, one more rule to explain.

### 12.7 Baselines reproduced (paused pass, shipped data, d154893)
| Check (target) | Result | n |
|---|---|---|
| Trait round robin, late decks (40-60% each) | Vanguard **67.3**, Spec Ops 42.3, Heavy 47.7, Undead 42.1 | 480 per trait |
| Aware vs blind, late decks (>= 55%) | **52.0%** (60.0 / 49.0 / 50.5 / 48.5) | 800 |
| Seat 0, aware mirror (45-55%) | 51.8% | 1000 |
| Full runs, competent proxy (balance_sim) | run win **40%**; M1 83 / M2 95 / **M3 19** / M4 25 / M5 47 | 300 runs |

### 12.8 Findings of the paused pass (old deck model; n = 120 per pairing, 360 per trait: about ±2.6 points SE per trait)
**Vanguard's lead is the card package, not its set bonus.**
| What-if | Vanguard | Spec Ops | Heavy | Undead |
|---|---|---|---|---|
| Vanguard tier 2 removed | 68.3 | 44.7 | 46.1 | 39.7 |
| Vanguard tiers 2 and 3 removed | 65.8 | 44.7 | 46.7 | 41.7 |
| Tier 2 = Cover +1 row 1, tier 3 = +1 FP row 1 (swap) | 68.9 | 45.0 | 45.6 | 40.0 |
| Breacher Armor 4 → 3 (all copies) | 71.4 | 39.2 | 49.4 | 39.2 |
| Bulwark cost 3 → 4 | 68.6 | 43.3 | 45.3 | 42.2 |
| Vanguard adds without the Point Man (a Rifleman instead) | 63.6 | 42.2 | 48.1 | 45.3 |
| ... without the **Breacher** | **58.1** | 45.3 | 49.4 | 46.4 |
| ... without the **Protector** | **59.7** | 46.1 | 49.2 | 44.7 |
| ... without Bulwark (a Rifleman is *better*) | 70.6 | 43.1 | 47.2 | 38.9 |
| Guard removed from Breacher and Protector | 63.1 | 45.8 | 47.5 | 43.1 |
| Guard removed from the Protector only | 63.9 | 45.6 | 46.7 | 43.3 |
| Protector cost 3 → 4 (all copies) | 62.2 | 41.1 | 52.2 | 44.2 |
| Breacher Guard → Fireteam | 67.2 | 41.4 | 49.2 | 41.7 |

- Taking the Vanguard bonuses away entirely leaves Vanguard at ~66%. The edge sits in the **Trained Breacher and Protector** (each worth ~8 points) and in **Guard** (Cover is strong in this engine). Breacher stat cuts backfire, because every deck carries Recruit Breachers. **Bulwark is a weak card** (a Rifleman does better in its slot).
- Most promising combination for v1.2 (not yet run): **Protector cost 4 + Guard off the Protector** (it keeps Cover 1 and the slide), possibly with a stronger Bulwark so the Vanguard Field is worth picking.
- **Aware vs blind:** larger Spec Ops / Heavy / Undead tier-2 bonuses (Undead heal 2, Heavy tier 2 + 1 FP, Spec Ops tier 2 + Cover 1) left the duel unchanged (49-50% on those decks; identical seeds give identical results), so sets rarely form in the late decks. A set-activity count confirms it (aware side, n = 100 per deck): a tier 2 is active in only **9-18% of side-rounds** (Vanguard 18, Undead 13, Spec Ops 11, Heavy 9) and a tier 3 in 1-8%. The levers left are the number of Trained cards (all-Trained decks: 62%), keyword counts on chassis that have none (Flanker, Demolitions, Medic), and the Operator cost (cost 0: 55%). The measurement's own late deck promotes Point Man and Breacher in every deck (`PROMOTE_ORDER`), which feeds Vanguard into the other trait decks; an on-trait promotion rule would be a fairer proxy.
- **Difficulty curve (M3 19%):** not tested yet. First levers to try: slot 3 `enemy_armor_bonus` 1 → 0, or slot 3 `enemy_recruits = true`.

---

## 13. Position cut (kc-pos-cut)
*Sr Game Designer Agent · 2026-11-06 · board task kc-pos-cut · **implemented, not committed** · the head, verbatim: "Remove the position based effect. It's too much. We'll keep that for tactics." The head picked three things to remove from **units**: neighbour links, row-based trait bonuses, and range bonuses by column. Kept: Pick, Flank and Pierce (targeting), every position effect on **Tactics**, and the column-scoped Fields (they are cards you place in a column, not unit keywords).*

### 13.1 The rule after the cut
**A unit's numbers don't depend on where it stands.** Its FP and Cover are what is printed, plus its level, plus modifiers from Tactics, Fields and auras, plus its trait set bonus. Where you put a unit still matters for **who it fights** (the column) and **who it shields** (the front unit is shot first; Pick and Flank reach past it). The board doesn't give or take stats by row or column any more.

### 13.2 What each affected thing becomes
| Thing | Before | After | Why |
|---|---|---|---|
| **Guard** (Breacher) | the card behind gets Cover +1 | **removed** | Breacher keeps First Shot. The effect lives on as a Tactic: **Hold the Line** (Cover 1 to your units in a column) |
| **Spotter** (Marksman, Recon Specialist) | the card in front gets +1 FP | **removed** | Marksman keeps Pick, Recon keeps its intel. Tactic version: **Callout** (+1 FP to your next arrival in a column) |
| **Fireteam** (Point Man, Rifleman, Brawler) | +1 FP while a friend is beside it | **removed** | Point Man keeps First Shot. Rifleman is a legacy card. **Brawler 2/3 → 3/3** so it stays better than the Standard Issue Trooper (it also lost Shotgun +2 at Close) |
| **Overwatch** (Gunner) | cards beside it get Cover +1 | **removed** | Gunner keeps Suppress and Pierce |
| **Vanguard tier 2** | +1 FP to Vanguard in row 1 | **+1 FP to every Vanguard** | whole-set |
| **Spec Ops tier 2** | +1 FP to Spec Ops in row 1 | **+1 FP to every Spec Ops** | whole-set |
| **Range bonus by column** (SMG +1 Close, Shotgun +2 Close / −1 Long, AR +1 Mid, Sniper −1 Close / +2 Long) | on every unit and the Operator | **removed** (0 everywhere) | Weapon class stays on the card as flavour and for Sniper Perch / LMG Pierce. Tactics keep their own column words (Breach and Clear: 3 if Close) |
| Link ticks, link preview, "New: Links" explainer, keyword pips | shown | gone (UI/UX agent, in parallel) | nothing to show |
| "Trains:" line | e.g. "First Shot · Guard" | e.g. "First Shot" | only printed keywords train now. Riflemen and Brawlers have nothing to train |

### 13.3 Trait set bonuses (whole set, every unit of the trait, anywhere)
| Trait | 2 in play | 3 in play (includes 2) |
|---|---|---|
| **Vanguard** | +1 FP | Cover +1 |
| **Spec Ops** | +1 FP | First Shot |
| **Heavy** | — | Cover +1 and +1 FP |
| **Undead** | heal 1 at the end of the round | +1 FP and Cover +1 |
Tested and rejected: Vanguard 2 = Cover +1, 3 = +1 FP (the swap: Spec Ops 62%, Undead 41%).

### 13.4 Retune (numbers only)
| What | v1.3 | v2.0 (after the cut) | Why |
|---|---|---|---|
| Brawler (Undead / Spec Ops chassis) | 2/3, Shotgun, Fireteam | **3/3**, Shotgun, no keyword | It lost +2 at Close and Fireteam; 2/3 would equal the Standard Issue Trooper |
| M1 crew (still −1 Armor, the green squad) | Grunt 6 · Trooper 7 · Sergeant 2 · Armored 1 · Ammo 2 | **Grunt 9 · Trooper 6** · Armored 1 · Ammo 2 | Without the Operator's range bonus the M1 crew got weaker (new player 82%). Cheap bodies hold zones |
| M4 crew (Bulwark_Nine, Firefight) | Trained | **Recruits** (keywords locked, trait on) | Without range and links, Trained Gunners / Medics made M4 a wall (31%) |
| M5 Rival crew (`enemy_deck`, new) | the Black Meridian deck | the same deck with **2 Marksmen → 2 Gunners** | The Rival got easier (48%): its Snipers lost +2 at Long, and Gunners are now its best units. Armor +2 or +1 FP overshot (21%) |
| Trait bonuses | row 1 conditions | whole set (§13.3) | the cut |
| M2, M3, reward pools, run config | — | unchanged | |

Rejected on the way: Rival Armor +2 or FP +1 (M5 21%), Rival Breachers for Riflemen (M5 49–54%: Breachers are worse without the Shotgun bonus), M4 deck trims while Trained (M4 36–42%), M3 with its 2 Flank Routes back (new player 37.5%), Marksman 2/2 → 3/2 (Spec Ops 59%).

### 13.5 Before / after (tune_check, 400 real runs per player type, late = 160 decks, mirror n = 1920, traits n = 480; onboarding_check agrees on the runs and the duel)
| Check (target) | v1.3 (HEAD 1c67de4) | Cut only, v1.3 numbers | v2.0 |
|---|---|---|---|
| New player M1 (65–75%) | 73.0% | 82.2% | **71.2%** |
| Competent run (38–43%) | 40.0% | 46.5% | **38.8%** |
| Competent M1–M5 | 88.2 / 99.0 / 58.8 / 42.5 / 41.1 | 97.8 / 99.0 / 74.2 / **31.0** / 47.1 | 94.8 / 99.0 / 74.0 / 54.5 / 39.5 |
| Casual run · M1–M5 | 26.0% · 73.0 / 81.0 / 44.8 / 35.1 / 31.8 | 28.8% · 82.2 / 81.0 / 46.0 / **17.6** / 35.1 | 25.0% · 71.2 / 81.8 / 46.5 / 48.3 / 29.8 |
| Traits (40–60% each) | U 51.9 · H 45.4 · V 52.1 · S 50.6 | U 43.3 · H 48.3 · V 52.5 · S 55.8 | U 45.6 · H 45.2 · V 52.5 · S 56.7 |
| Aware vs blind (≥ 55%) | 58.6% | 56.1% | **59.5%** |
| End-of-run deck vs the starter | 80.9% | — | 75.3% |
| Seat 0, late mirror (45–55%) | 49.3% | 50.9% (n = 640) | 49.9% |
| Seat 0, starter mirror (45–55%) | 49.7% | 46.7% (n = 640) | 49.9% |
| Ties → enemy instead (late · starter) | 49.2 · 49.8% | — | 50.4 · 50.1% (the tie rule still changes nothing) |

- **Every target is met.** The aware edge didn't fall with the links gone: sets are now easy to read and to build, and the aware planner still completes them (59.5%).
- The ramp has no wall: easy, easy, then 74 / 55 / 40 for a solid player and 47 / 48 / 30 for a new one. The steepest step is the Rival, which is meant to be the peak.

### 13.6 Implementation (rules and data; the UI/UX agent removes the link visuals in parallel)
| Where | Change |
|---|---|
| `scripts/rules/synergy_rules.gd` | `TRAIT_BONUS` whole-set (no `where`), `TIER_TEXT` updated; `compute()` makes no links (`links` always `[]`); `keyword_at()` always `&""`. `KEYWORDS` / `KEYWORD_TEXT` kept (marked retired) until the UI drops them |
| `scripts/rules/match_state.gd` | `firepower_of()` no longer adds a range bonus |
| `scripts/data/run_config.gd` | `range_bonus()` returns 0; the `range_bonus_*` fields stay (old `.tres` load) with zero defaults, marked retired |
| `scripts/ai/ai_view.gd`, `ai_planner.gd` | no range bonus in hand records, Operator-by-zone or Flank Route moves |
| `scripts/data/card_data.gd` | the validator rejects any `neighbor_keyword` |
| `data/cards/*` | `neighbor_keyword` removed from Breacher, Point Man, Gunner, Marksman, Recon Specialist, Rifleman, Brawler; Brawler FP 3 |
| `data/run_config.tres` | range rows removed; M1 crew, M4 Recruits, M5 Rival `enemy_deck` |
| `data/README.md` | `neighbor_keyword` marked retired |
| Tests | Rules: the link / range tests are replaced by `test_neighbor_keywords_are_retired`, `test_no_range_bonus_by_column` (×2), `test_set_member_death_in_a_switches_off_the_set_before_b` and `test_aware_planner_completes_a_set`; the tier, First Shot, Callout, Anvil, Mortar Barrage, onboarding, run-synergy and data tests now use the new numbers. The UI tests (`test_syn_ui`, `test_ui4`) are the UI/UX agent's |

### 13.7 Questions for the head (recommended option first)
1. **Brawler 2/3 → 3/3.** (a) Approve: it stays a clear upgrade on the Trooper. (b) Keep 2/3 and give it a non-positional keyword instead (e.g. Cover 1; untested).
2. **M3 is now easier than M4 for a solid player (74 vs 55%).** (a) Keep: it's the new player's hardest early match (47%) and the step after it is gentle. (b) Put the Rusher's 2 Flank Routes back in M3: solid 68.5%, but the new player drops to 37.5%.
3. **Other placement-based unit text that the cut didn't name.** These are the Protector's slide to the front, the Anvil's "your other units here get +1 FP", and the Demolitions Expert's On Down "3 damage to the enemy point man here". (a) Keep them: they decide which column and who gets shot, not stats by row or neighbour. (b) Cut them too, for units with no position words at all (needs one more pass).

## Removed (kc-no-training, 2026-11-07)

*The head, after an iPad playtest: "Remove all the training thing." and "Make sure cards only have 1 trait at most."*

- **Gone:** the per-copy levels of §5.2 (Recruit / Trained / Veteran / Elite), Promotion (`promotion_after_matches`, the Promotion offer), the Veteran / Elite stat bonuses (+1 Armor / +1 FP), the camo bands, Recruit squads (`RunMatchData.enemy_recruits`), the Recruit starter switch (`RunConfig.starter_recruits`) and twin training. Every copy plays its full chassis (keywords, effects, Pierce, arrives-front) from the moment it is in a deck.
- **Kept:** traits and set bonuses (§4, §13), Doctrine, Retire / Regroup and the Honor Roll (entries no longer carry a level), the 15-card floor.
- **One trait per copy:** a copy carries at most one trait (`SynergyRules.trait_at` returns one id; `SynergyRules.is_single_trait`). `CardData.validate` rejects a `card_trait` or trait option that names two traits; `ArtTraits.validate_map()` / `card_problems()` check that each art gives at most one trait; a save whose copy names two traits is refused.
- Numbers after the removal: `onboarding-progression.md`, "Removed (kc-no-training)".
