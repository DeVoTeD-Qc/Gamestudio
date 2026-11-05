# KillingCard: Synergy System (neighbor links, calling-card traits, a deck that grows into an engine)

*Author: Sr Game Designer Agent · 2026-11-05 · Board task kc-syn · Status: **proposal for the head's review** · DESIGN + SIM ONLY. No rules, UI, scene or data file was changed. The sim lives in `source/project-killingcard/tests/tools/synergy_rules.gd` and `synergy_sim.gd`.*
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
