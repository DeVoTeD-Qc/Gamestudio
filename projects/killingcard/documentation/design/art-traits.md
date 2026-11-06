# KillingCard: Art Traits (the chassis gives the numbers, the art gives the trait)

*Author: Sr Game Designer Agent · 2026-11-06 · Board task kc-art-traits · Status: **approved (T1-T4 all (a)); implemented in rules / AI / data / run state by kc-art-traits-impl, see §11** · The trait-choice / Re-issue screens are a later UI task. The sim is `source/project-killingcard/tests/tools/art_traits_sim.gd`, on the real engine and the real AI.*
*Inputs: `synergy-system.md` (traits, set bonuses, Doctrine, Recruit / Trained, §11 implementation, §12 paused tuning), `firefight-order.md`, `card-system.md` (§2 chassis + art, §5.6 fairness rule, the head's decisions), `../art/mw3-calling-cards-manifest.csv`, `../art/mw3-calling-cards.md`, `../art/mw3-pitch-set.md` / `.csv`, the squads in `data/squads/`.*
*The head (verbatim): "Alternate art could provide different trait. Which makes alt art have a little bit of strategy and deck building. Also the card name in game should be the one the card represents and the calling card name is the art/alt art, so it should be a subname. That way same card has same name." (The naming part is the UI agent's task. This doc assumes it: the name is the chassis, "Marksman", and the art title is the subname, "KVD Enforcer Mastery".)*

## 0. Summary in six lines
1. **New rule:** a card's cost, FP, Armor, keywords and effects come from its **chassis**. Its **trait** comes from the **art it wears**: the calling-card family decides the trait (Prestige & challenges → Vanguard, operator bundles → Spec Ops, weapon mastery → Heavy, Zombies → Undead, default / campaign → no trait) (§1).
2. **Limited options:** each unit chassis can carry its **home trait and one alternate** (the Rifleman: no trait, Spec Ops or Undead). Elites and Fields keep one printed trait. No chassis reaches all four, so a Marksman is still a sniper first and every trait keeps its own core cards (§4).
3. **The fairness rule changes** from "no art changes anything" to **"art can change the trait, never the numbers, and every trait option is free to every player"**. Owning more arts gives you more looks for an option, never a new option (§1.3).
4. **Per-copy choice, made when the copy trains.** Codex EQUIP (global per card name) sets the default art. In a run, a copy's trait is chosen when it becomes Trained: at the reward pick, at Promotion and at twin training. A new **Re-issue** option (next to Retire) changes one copy's trait later. Art swaps that keep the trait are free at any time (§2).
5. **Sim (about 45,000 matches, current engine incl. the new firefight order):** art-chosen traits mostly fix Vanguard. Vanguard was strong because the starter's Recruits could only train into Vanguard. With the art options: **Vanguard 63.5% → 48.8%**, Spec Ops 44.6, Undead 43.1, but **Heavy 63.1%** (Pierce plus a set that is too easy to start). With two set-bonus changes (**Heavy's bonus needs 3, Undead 3 also gives Cover +1**), the four traits land at **49.4 / 47.7 / 52.7 / 50.2%**. Free drafting doesn't converge on one trait (each main trait wins 48.9–51.0%). Aware vs blind is **55.9%** and seat 0 **52.9%** (§6).
6. **Enemy squads get a fixed art identity** (Rusher = Vanguard crew, Anchor = Heavy crew, Rival = Spec Ops crew). The campaign stays at today's difficulty (35.8%; today 35.2%). The UI needs a trait icon on every art (Codex, EQUIP, offers), trait counts in the deck view and "Marksman · Heavy" offers with the art as subname (§7–8).

---

## 1. The rule

### 1.1 What comes from where
| Comes from the **chassis** (the card name) | Comes from the **art** (the subname) |
|---|---|
| Cost, FP, Armor, class / weapon, printed keywords (First Shot, Pick, Pierce, Patch, Flank, Suppress, Cover), the neighbor keyword (Guard / Spotter / Fireteam / Overwatch), effects, Recruit / Trained / Veteran / Elite stats | The picture, the title (shown as the subname), the animation, **and the trait** (via the art's family), but only if that trait is on the chassis' option list (§4) |

- **Recruits wear an art but have no trait** (unchanged, synergy-system §5.1). The trait switches on when the copy is Trained. Until then the card shows no trait icon. The inspector says "Trains as: Vanguard or Undead".
- **An art whose family isn't on the chassis' list carries no trait** ("plain"). Example: the pitch's Snow Snipers is a Prestige card on a Marksman, and Vanguard isn't a Marksman option, so it plays as a plain Marksman. Curators avoid this, but the rule makes every art legal.
- **Single-option cards print their trait** and their art is cosmetic: the Elites (Ace ★ Spec Ops, Commander ★ Heavy) and the five traited Fields (Bulwark Vanguard, Sniper Perch Spec Ops, Mortar Pit Heavy, War Standard and Aid Station Undead). This is deliberate. Each trait keeps one Field that always counts for it, so a set can always be started, and the Elites stay fixed hero cards. A traited Field that any deck could re-trait would be an automatic +1 to everyone's best set.
- **Tactics, the Operator, the Sentry token and killstreaks have no trait**, whatever art they wear. The Operator keeps its weapon-mastery ladder (head S4). Mastery cards on the Operator never give it Heavy.

### 1.2 Family → trait
Family = the MW3 manifest's `section` (how the card is earned in MW3). For the public build, our own art carries the same family in a new `family` field (§1.4).

| Family | Manifest sections | Trait | Why |
|---|---|---|---|
| **Honors** (prestige & challenges) | Prestige Mastery / Multiplayer, Challenges / Multiplayer, Challenges / General, Ranked Play / Multiplayer | **Vanguard** | Earned in combat, the front-line grind |
| **Operators** (operator bundles) | Standard / Store, Battle Pass, Armory Unlocks, Events; **Warzone** (General, World Series, Ranked Play / Warzone, Challenges / Warzone) | **Spec Ops** | Operator portraits, infil / exfil. Warzone joins it: drop in, scout, extract. |
| **Mastery** (weapon mastery) | Weapon Mastery, every ladder (Multiplayer, Zombies MW3, Zombies MWII) | **Heavy** | One weapon in a camo: the gear trait. One rule, "a gun card is Heavy", even for the Zombies camo ladders. |
| **Horde** (Zombies) | Challenges / Zombies, Prestige Mastery / Zombies, Zombies | **Undead** | Literal |
| **Standard** | Standard / Default, Standard / Miscellaneous, Campaign | **none** | The plain "operator with a rifle" look. Every player owns these. |

The family is shown in the pitch's trait tooltip ("Undead · Zombies card"). The public build names the families Honors / Operators / Mastery / Horde / Standard, because we can't use MW3's mode names (card-system §6).

### 1.3 The fairness rule (replaces card-system §5.6)
> **Fairness rule v2 (binding):** an art may set a card's **trait**, chosen from that chassis' short option list. No art, finish, series, mastery level or collection ever changes **cost, FP, Armor, keywords, effects, draw odds or matchmaking**. **Every trait option is free to every player from the first run:** each (chassis, trait) option has a default art that everyone owns. Earning or buying arts adds looks within an option, never a new option. The trait is always shown on the card as an icon, so no one has to know the art's family.

- **What it protects:** a new player and a collector field the same strategic choices. Cosmetic sales stay possible (card-system §5 monetisation note), because a sold art never unlocks power.
- **What it gives up:** "this art is rare, so it's strong" never exists. The collect hook is identity ("my Undead Marksman wears Glint") and the album, not power.
- **Rewritten lines elsewhere:** card-system §0.5 ("no gameplay difference between arts") and §5.6, and synergy-system §4.1 (decision A, "traits come from the chassis") are superseded by this rule once it's approved. The Promotion band stays the copy's level and is never an art (synergy-system §5.2).

### 1.4 Pitch build vs public build
| | Private pitch (MW3 cards, never committed) | Public build (our own art) |
|---|---|---|
| Where the family comes from | Manifest `section` → family table §1.2 (one lookup in BannerArtDB's licensed rows) | A `family` field on `BannerArt` (new tag column `family` in the art CSV), set by the curator |
| Default art per option | Today each traited chassis has only home-family arts in the pitch set (31 were re-picked for that in kc-syn-impl). **About 16 alternates must be added** (§3.2) | 13 placeholder variants: the chassis' sprite with a family corner emblem and backdrop tint (Honors laurel, Operators tape, Mastery camo swatch, Horde rot-green), from BannerArtDB's generated path. They must not reuse the level camo band (Gilded / Forged / Priceless), which shows the copy's level |
| Names | Subname = MW3 title ("Glint") | Subname = our title ("Grave Watch"). No MW3 names, no "Zombies" mode name |
| Risk | Shows a rule we **can** ship (unlike kc-syn option B, which broke the old fairness rule) | Needs original art in four families before a public demo: about 13 extra arts at minimum |

## 2. Choice and acquisition

### 2.1 Codex EQUIP: the default, global per card name (head's ask, kept)
- In the Codex, each card name has one **equipped art**. It's what the starter's Recruits wear, what the quick match and tutorial decks wear, and the **pre-selected** art whenever a copy of that card trains in a run.
- The Codex groups a card's arts by trait: "Marksman: **Spec Ops** (5 arts) · **Heavy** (10 arts)", with the trait icon on every tile. Plain arts sit in a third group, "No trait". The EQUIP button names the result: "EQUIP · Heavy".

### 2.2 Per copy, decided when it trains (recommended)
Strategy needs two copies of one card to be able to differ: two Marksmen, one Spec Ops (with Flanker / Recon) and one Heavy (with the Gunners), or a Point Man trained Undead to start a Brawler set. A global-per-name trait would make every Promotion re-trait the copies you already have, and the starter's 4 Point Men could only ever be one trait. So:

| Moment | What the player chooses | Why it's a decision |
|---|---|---|
| **Supply Drop pick** | Offers are concrete copies with a concrete art: "**Marksman · Heavy**", subname "KVD Enforcer Mastery", "Heavy 3 → 4". Slot 1 is a card that **can** carry your main trait, shown in that trait's art (the existing on-trait slot). Slots 2–3: a random card in its home art (60%) or its alternate (40%). | You pick the card *and* its trait together. Taking it unlocks the art, as today (card-system §5.3). |
| **Promotion** (Recruit → Trained) and **twin training** | Pick the copy, then one of its options (2–3 tiles, each with the trait icon and the count change). The EQUIPped art is pre-selected. | The starter's Recruits now feed **any** of a chassis' traits, not only Vanguard. This is the main balance fix (§6.1). |
| **Re-issue** (new, the 4th Supply Drop option next to Retire, and also allowed as the Regroup reward after a loss) | Change one Trained copy to another of its options. | A pivot costs a card, like Retire. Without a cost, traits would be re-tuned before every match and nothing would be committed. |
| **Any time, in the deck view** | Swap a copy's art to another art **with the same trait**. | Cosmetic, free, never a balance question. |

- **Rejected: free re-equip of the trait between matches.** It turns deckbuilding into a menu (the sim's "all options" table shows what happens: the choice stops mattering, §6.3). It also lets the player re-tune against the next squad's known trait.
- **Rejected: alternate arts as separate collectible card versions** ("Undead Marksman" as its own card in the pool). It doubles the reward pool, the reward odds and the Codex. The same strategy comes from per-copy art with one pool of chassis.
- Doctrine, the main trait and the on-trait slot are unchanged. They now read the copies' traits (`RunProgress.trait_counts()` counts per copy).

### 2.3 What a run looks like now
Start: 20 Recruits wearing your EQUIPped arts, no traits shown. M1: Doctrine (pick Undead). M2: Promotion. Your Recruit Point Man trains as **Undead** ("Point Man · Undead, Violent Vortex"), so it no longer has to be a Vanguard you don't want. Supply Drop: "Brawler · Undead" in slot 1. M3: Re-issue your Gunner to Spec Ops to back your Marksmen. The deck view shows "Undead 4 · Spec Ops 2 · Vanguard 1".

## 3. Coverage: which traits each chassis can reach

### 3.1 Recommended option table (v3) and the arts that exist
Counts are `review = no` cards in `mw3-calling-cards-manifest.csv` whose suggested chassis is that one, by family (§1.2). Mastery counts include every tier, and the pitch uses tier 1 (Gilded / Golden Ivory / Golden Enigma). "Pitch today" counts the 96-card pitch set by the family of each art.

| Chassis | Home (default art) | Alternate | Manifest arts: home / alternate | Pitch set today | Flag |
|---|---|---|---|---|---|
| Rifleman (1) | none (Standard) | **Spec Ops** or **Undead** | 12 / 78 / 43 | V 4, SO 3, U 1, plain 1 | The 4 Honors Riflemen play as plain (Vanguard isn't a Rifleman option): re-label or keep as plain looks |
| Point Man (2) | Vanguard | Undead | 21 / 23 | V 7 | |
| Breacher (3) | Vanguard | Heavy (shotgun mastery) | 8 (4 usable, 4 rejected for gore) / 56 | V 4 | |
| Protector (4) | Vanguard | Undead | 9 / 5 | V 3 | |
| Flanker (3) | Spec Ops | Undead | 15 / **1** (Quiet Kill) | SO 5 | **Thin**: 1 Undead art. The curator can move a stealthy Zombies Rifleman or Brawler card |
| Recon Specialist (2) | Spec Ops | Undead | 7 / **2** (Seal Time, Clean Kill... Kind Of) | SO 4 | Thin |
| Marksman (3) | Spec Ops | Heavy (sniper mastery) | 6 / 148 | SO 5, V 1 (Snow Snipers = plain) | |
| Gunner (4) | Heavy (LMG mastery) | Spec Ops | 80 / 6 | H 5 | |
| Demolitions Expert (4) | Heavy (launcher mastery) | Undead | 32 / 6 | H 4 | |
| Brawler (2) | Undead | Spec Ops (bundle melee) | 38 / 41 | U 7 | Bundle melee cards include licensed crossovers: eye-check every pick |
| Combat Medic (2) | Undead | Spec Ops | 5 / **0** | U 3 | **Can't reach Spec Ops with MW3 art today.** Re-tag a Store operator with a med kit, or keep the Medic single-option in the pitch |
| Ace ★ (5) | Spec Ops, **printed** | — | **0** (no hero sniper art) | Big Game Hunter (Honors family, cosmetic here) | Single option, so the family doesn't matter |
| Commander ★ (5) | Heavy, **printed** | — | Heavy **0**, SO 7, U 2 | SO 1, U 1 | Single option. Its throne arts aren't mastery cards, which is why it is printed and not art-driven |
| Fields | printed (Bulwark V, Sniper Perch SO, Mortar Pit H, War Standard U, Aid Station U) | — | Bulwark 0 Honors, Sniper Perch 0, Aid Station 0, Mortar Pit 0 Mastery | as today | Art is cosmetic on Fields |

**Reach per trait (unit chassis that can carry it):** Vanguard 3 (Point Man, Breacher, Protector), Spec Ops 6 (+ Rifleman, Gunner, Brawler, Medic, Ace), Heavy 5 (+ Breacher, Marksman, Commander), Undead 8 (+ Rifleman, Point Man, Protector, Flanker, Recon, Demolitions). The weak traits get the widest reach on purpose. Vanguard gets no new carriers, because it was the strongest.

### 3.2 Pitch set: alternates to add (one or two per option, `review = no`, eye-check before use)
| Option | Candidates from the manifest (titles) |
|---|---|
| Rifleman · Undead | Helo Exfil, In Trouble, Random Rewards |
| Rifleman · Spec Ops | Loot At Me, Solid Tactics, Swamp Guys (Warzone; avoid the Store ones with crossovers such as Cadia Stands! or Char's Laugh, which the classifier missed) |
| Point Man · Undead | Violent Vortex, Wolves Wasted, Mayhem On Wheels |
| Breacher · Heavy | Lockwood 680 Mastery: Gilded, Haymaker Mastery: Gilded, Riveter Mastery: Gilded |
| Protector · Undead | Still Standing, Surrounded |
| Flanker · Undead | Quiet Kill |
| Recon Specialist · Undead | Seal Time |
| Marksman · Heavy | KVD Enforcer Mastery: Gilded, MCW 6.8 Mastery: Gilded, Longbow Mastery: Gilded |
| Gunner · Spec Ops | Lead Rain, Download Complete |
| Demolitions Expert · Undead | Objective Destroyed, Boom And Gloom |
| Brawler · Spec Ops | Big Sword, Charging... (eye-check: several Store melee cards are crossovers) |
| Combat Medic · Spec Ops | none (see the §3.1 flag) |

That's about **16 arts** (the pitch set grows from 96 to about 112 card arts). The same eye check as kc-cod2 applies: no gore (Smoke And Blood, Cut And Gutted and others stay rejected), no third-party IP and no side text over the icon columns. Note that `review = no` still lets crossovers through: Cadia Stands! (Warhammer), Char's Laugh (Gundam) and Here Comes The A-Train (The Boys) are tagged `no` in the manifest. The Technical Artist should flag them.

### 3.3 Why not "every chassis, every trait"?
- **Identity:** players learn "Gunner = Heavy, maybe Spec Ops", not 52 combinations. A trait still has core cards (Vanguard owns the front, Spec Ops owns Pick and Flank), so a trait's set bonus keeps pointing at a formation.
- **Balance:** with every option open, the deckbuilder trains its best Recruits (Gunner, Breacher) into whatever its main trait is, so the trait choice stops mattering. The sim's "all" table compresses the traits to 45–55%, but the draft shows the choice is arbitrary: the drafter "picks" Vanguard 75% of the time only because every trait ties (§6.3).
- **Art supply:** 10 of the 52 pairs have no MW3 art at all (§3.1 flags). A full grid would need about 30 more arts in the public build.
- **Recommendation: two options per unit chassis** (three for the Rifleman, which has no home trait), and one printed trait for Elites and Fields.

## 4. Exact option data (for the mechanics developer, after approval)
`CardData.trait_options: Array[StringName]`. The first entry is the default (today's `card_trait`, or `&""` for the Rifleman). Empty means "no trait, ever" (tactics, Operator, Sentry).
| id | trait_options |
|---|---|
| `rifleman` | `["", "specops", "undead"]` |
| `point_man` | `["vanguard", "undead"]` |
| `breacher` | `["vanguard", "heavy"]` |
| `shieldman` | `["vanguard", "undead"]` |
| `flanker` | `["specops", "undead"]` |
| `recon_specialist` | `["specops", "undead"]` |
| `marksman` | `["specops", "heavy"]` |
| `gunner` | `["heavy", "specops"]` |
| `demolitions_expert` | `["heavy", "undead"]` |
| `brawler` | `["undead", "specops"]` |
| `combat_medic` | `["undead", "specops"]` |
| `halek_wren`, `okafor_anvil`, Fields | one entry = their printed trait |

(The sim's v3 table also gave the Commander a Spec Ops option. It's rarely drafted, so the difference is negligible. The recommendation is printed Heavy, §3.1.)

## 5. Set bonus numbers (v1.2 proposal, replaces synergy-system §4.4 for Heavy and Undead)
| Trait | 2 in play | 3 in play |
|---|---|---|
| Vanguard | Vanguard in row 1 get +1 FP (unchanged) | Vanguard get Cover +1 (unchanged) |
| Spec Ops | Spec Ops get +1 FP (unchanged) | Spec Ops have First Shot (unchanged) |
| **Heavy** | **— (no bonus at 2)** | **Heavy get Cover +1 and +1 FP** (was: 2 = Cover +1, 3 = +1 FP) |
| **Undead** | End of round: each damaged Undead heals 1 (unchanged) | **Undead get +1 FP and Cover +1** (was: +1 FP) |

- **Heavy is now a "full crew" trait:** nothing at 2, everything at 3. Heavy reaches 2 too easily: two Gunners, or a Gunner and Mortar Pit. Since the new firefight order gave the Gunner and the Demolitions Expert Pierce, a cheap tier-2 Cover makes Heavy the best trait in every pairing (§6.2). The trait rail shows "Heavy 2/3" with the bonus text greyed until 3.
- **Undead tier 3 gains Cover +1.** Undead is the most-reached trait under art options (8 chassis), but its bodies are the cheapest. The extra Cover lets a full horde survive the front exchange.
- These are data changes in `SynergyRules.TRAIT_BONUS` and `TIER_TEXT` only. They belong to the paused kc-syn-tune v1.2 and should be applied together with the art-trait change, because they were tuned against it.

## 6. Sim results
**Harness:** `tests/tools/art_traits_sim.gd`, built on `synergy_check.gd` (the shipped engine: MatchState + SynergyRules + `AiPlanner.synergy_aware`). A re-traited copy is a sim-only duplicate of its CardData with `card_trait` changed and the id `"<chassis>~<trait>"`, so the planner, which de-duplicates hand cards by design and level, keeps two Marksmen with different traits apart. Seats and modes alternate on Port Vasel. Both sides use the "competent" settings.
**Engine state:** a snapshot of the working tree on 2026-11-06 (HEAD 46df8f7 plus the uncommitted kc-fight-impl work: front-to-back beats, First Shot exchange, **Pierce on the Gunner and the Demolitions Expert**, Protector cost 4 without Guard, slot 3 Armor bonus 0). Baselines were re-measured on it, so they differ from earlier docs.
**Decks** (synergy-system §7): late = the Recruit starter + 4 reward cards of a trait − 3 Riflemen + 2 Promotions. *Fixed* = today's chassis traits. In the old measurement, Promotions follow `PROMOTE_ORDER` (Point Man, Breacher first, which always feeds Vanguard). *Fixed OT* = fixed, but Promotions go to on-trait Recruits (a fairer control). *Art* = the deckbuilder gives every Trained copy that can carry the deck's trait that trait, promotes on-trait Recruits (most expensive first, one per design first) and puts the rest on the best second trait.
Run: `godot --headless --path . -s res://tests/tools/art_traits_sim.gd -- exp=traits|dominance|draft|duel|mirror|campaign n=N opts=fixed|v1|v2|v3|all [ontrait=1] [opt=chassis:t1/t2] [tune=trait.tier.key=value] [pkg=…] [set=…] [squadtraits=native|identity|undead3]`.
**Statistics:** round robin n = 160 per pairing, 480 per trait: ±2.3 points SE per trait. Duel n = 800: ±1.8. Mirror n = 1000: ±1.6. Campaign n = 400: ±2.4.

### 6.1 Trait round robin, late decks, aware vs aware (target 40–60% each)
| Setup | Vanguard | Spec Ops | Heavy | Undead | Spread |
|---|---|---|---|---|---|
| **Baseline**: fixed, `PROMOTE_ORDER` (= `synergy_check exp=traits`) | **63.5** | 40.0 | 56.5 | 40.0 | 23.5 |
| Fixed OT (on-trait Promotions, today's chassis traits) | 53.1 | 42.7 | **63.5** | 40.2 | 23.3 |
| **Art, v1 / v2 / v3 options** (the trait decks are identical under all three) | 48.8 | 44.6 | **63.1** | 43.1 | 20.0 |
| Art, every chassis every trait ("all") | 52.1 | 46.9 | 55.2 | 45.4 | 9.8 |
| Art v3, synergy off (the card packages alone) | 60.0 | 39.6 | 51.9 | 47.7 | 20.4 |

- **Vanguard's lead was the starter, not the trait.** 8 of the 20 Recruits are Vanguard chassis, and under chassis traits every Promotion and twin training of them adds Vanguard to every deck (the fixed late Spec Ops, Heavy and Undead decks each carried 2 Vanguard). When the art decides, a Point Man trains Undead and a Breacher trains Heavy. Vanguard drops 15 points, and nothing about Vanguard itself changed.
- **Heavy is the new problem, and it isn't caused by the art options:** fixed OT shows the same 63.5%. Its synergy is worth +11 points (51.9% without synergy). The source is the cheap tier 2 together with the new Pierce on Gunner and Demolitions.

### 6.2 Set-bonus levers on the art decks (v3; n = 480 per trait)
| What-if | Vanguard | Spec Ops | Heavy | Undead |
|---|---|---|---|---|
| v3, current numbers | 48.8 | 44.6 | 63.1 | 43.1 |
| Heavy tier 2 Cover only in row 1 | 49.0 | 45.8 | 61.9 | 42.9 |
| Undead tier 2 heal 2 | 48.8 | 43.5 | 62.3 | 44.8 |
| Heavy tiers swapped (2 = +1 FP, 3 = Cover +1) | 48.3 | 45.0 | 65.4 | 40.8 |
| Breacher without its Heavy option | 54.6 | 44.8 | 62.3 | 38.1 |
| Heavy package with 1 Demolitions (a Brawler instead) | 49.4 | 45.4 | 59.2 | 45.2 |
| Demolitions without Pierce | 48.5 | 45.2 | 62.5 | 43.3 |
| Heavy tier 2 removed | 52.3 | 50.0 | 51.0 | 46.0 |
| Undead tier 3 + Cover +1 | 46.7 | 43.3 | 60.6 | 49.2 |
| Heavy tier 2 removed + Undead tier 3 Cover | 50.2 | 48.8 | 48.8 | 51.7 |
| Heavy only at 3 (Cover +1 and +1 FP) | 51.5 | 49.0 | 54.8 | 44.6 |
| **Recommended: Heavy only at 3 (Cover +1, +1 FP) + Undead tier 3 Cover +1** | **49.4** | **47.7** | **52.7** | **50.2** |
| Same numbers on fixed OT (chassis traits, fair Promotions) | 50.4 | 44.2 | 54.4 | 50.8 |
| Same numbers on fixed, `PROMOTE_ORDER` | 63.5 | 42.1 | 49.8 | 44.6 |

- The Heavy problem is the **tier-2 bonus** (whether Cover or FP). Its Cover, Pierce and the package are each only a few points. With nothing at 2, Heavy falls back into the pack.
- "Heavy tier 2 removed + Undead tier 3 Cover" (50.2 / 48.8 / 48.8 / 51.7) is just as good within the noise. The recommendation keeps Cover in Heavy's identity ("outlast") by putting it on the 3-set.
- With the same numbers, chassis traits with fair Promotions reach 44–54%. Art traits reach 48–53%, so the art layer is not needed for balance. Its value is the deckbuilding choice, and it removes the "Recruits feed Vanguard" trap without any starter change.

### 6.3 Does free choice make everyone stack the best trait? (drafts and dominance)
**Greedy drafts:** 240 decks per row. Each deck takes 4 Supply Drops of 3 random reward-pool cards and keeps the card that grows its best set, then gets 2 Promotions (on-trait) and 3 Retires. The art rows assign traits with the deckbuilder. Decks are paired at random, 1,200 matches per row.
| Row | Main trait chosen: V / SO / H / U | Win rate by main: V / SO / H / U |
|---|---|---|
| Fixed OT, current numbers | 49.6 / 27.9 / 12.1 / 10.4% | 52.0 / 45.3 / **57.3** / 43.5 |
| Art v1, current numbers | 32.5 / 11.7 / 17.9 / 37.9% | 48.5 / 56.1 / 53.2 / 47.2 |
| Art "all", current numbers | 74.6 / 6.7 / 7.1 / 11.7% (ties → Vanguard: the choice is arbitrary) | 50.6 / 50.0 / 49.1 / 45.8 |
| **Art v3 + recommended numbers** | 15.4 / 28.8 / 10.8 / 45.0% | **48.9 / 51.0 / 50.2 / 48.9** |
| Fixed OT + recommended numbers | 49.6 / 27.9 / 12.1 / 10.4% | 51.2 / 45.6 / 55.2 / 49.0 |

**Dominance:** for each reward package, the deckbuilder is forced to stack each of the four traits, and each result plays 160 matches against the fixed-trait field (4 decks).
| Package (4 reward cards) | Stack Vanguard | Stack Spec Ops | Stack Heavy | Stack Undead | Best |
|---|---|---|---|---|---|
| Vanguard (Point Man, Breacher, Protector, Bulwark) | 55.6 (V 6) | **60.0** (V 4 + SO 2: both Marksmen trained Spec Ops) | 48.8 (V 3 + H 3) | 53.8 (U 4 + V 2) | a 4 + 2 split |
| Spec Ops (Flanker, Recon, Marksman, Sniper Perch) | 40.6 | **56.9** (SO 6) | 46.2 | 45.0 | own trait |
| Heavy (Gunner, Demolitions ×2, Mortar Pit) | **50.6** (H 4 + V 2) | 48.1 | **50.6** (H 6) | 43.8 | own trait or a split |
| Undead (Brawler ×2, Medic, War Standard) | 44.4 | 46.9 | **50.6** (U 4 + H 2) | 48.8 (U 6) | own trait or a split |
| Mixed (Flanker, Demolitions, Brawler, Mortar Pit) | 40.6 | 43.1 | **46.2** | 41.9 | — |
| **Pooled by stacked trait** | 46.4 | 51.0 | 48.5 | 46.6 | |

(Art v3 + recommended numbers; n = 160 per cell, ±4 points; the opponents are the four fixed-trait late decks.) The best main trait follows the package, often as a two-trait split, and no trait is the best stack for every package. With current numbers and v1 options the pooled rows were V 46.1 / SO 53.2 / H 51.2 / U 44.1, with Heavy the best main for the Undead package (53.1%). Moving the Brawler's alternate from Heavy to Spec Ops (v3) and the §5 numbers narrowed that escape route: stacking Heavy on the Undead package went from 53.1% to 50.6%, now level with stacking Undead (48.8%).

- **No single trait wins the draft:** with v3 and the recommended numbers, every main trait wins 48.9–51.0%. With fixed traits, the drafter is pushed toward Vanguard (half the decks) by the starter, and a Heavy main is the one that wins (57%).
- **Undead is chosen most (45%)**, because 8 chassis can reach it and the greedy drafter counts carriers. It doesn't win more (48.9%). Watch it in playtests. If every run turns Undead, the first cut is the Recon Specialist's Undead option (to Vanguard, the v1 table).

### 6.4 Aware vs blind and seats (recommended package)
| Check (target) | Baseline (fixed, current numbers) | **Art v3 + recommended numbers** |
|---|---|---|
| Aware vs blind, same late deck (≥ 55%), n = 800 | 56.4% (V 59.5 / SO 55.0 / H 59.0 / U 52.0) | **55.9%** (50.0 / 58.5 / 57.5 / 57.5) |
| Seat 0, aware mirror (45–55%), n = 1000 | 51.9% (starter 43.0, V 54.0, SO 58.0, H 51.0, U 53.5) | **52.9%** (43.0 / 53.0 / 61.5 / 52.5 / 54.5) |
| Rounds per match (mirror) | 6.57 | 6.55 |

- **Synergy planning still pays (55.9%).** Planning now helps Spec Ops, Heavy and Undead most. The Vanguard deck's planning edge drops to 50%: its links (Guard on the Breacher) are what it plays anyway, and a Heavy 2-set no longer gives cheap value to anyone.
- **Seats stay fair (52.9%).** The Spec Ops mirror's seat 0 is high in both runs (58.0 and 61.5; n = 200, ±3.5). Seat 0 sees the red dots and wins initiative ties, which First Shot (Spec Ops 3) makes count. That's a firefight-order item, not an art item.

### 6.5 Campaign: aware player with the Recruit starter vs the real squads (n = 80 per slot)
| Setup | Slot 1 Rusher (Recruits) | Slot 2 Anchor (Recruits) | Slot 3 Rusher+ | Slot 4 Anchor+ | Slot 5 Rival | **All** |
|---|---|---|---|---|---|---|
| Baseline (current engine and numbers, chassis traits) | 51.2 | 62.5 | 36.2 | 22.5 | 3.8 | **35.2%** |
| §5 numbers, squads on chassis-default traits | 51.2 | 62.5 | 36.2 | 33.8 | 3.8 | **37.5%** |
| **§5 numbers + squad identity** (§7) | 51.2 | 62.5 | 36.2 (V 7, SO 5) | 27.5 (H 6, U 7) | 1.2 (SO 10) | **35.8%** |
| Same, with Rusher+ as an Undead horde | 51.2 | 62.5 | 37.5 (U 9, V 3) | 27.5 | 1.2 | **36.0%** |

- The campaign stays at today's difficulty (35–38%, ±2.4). The Recruit squads in slots 1–2 have no traits, so they don't change.
- The new Heavy numbers make Anchor+ (slot 4) easier (22.5 → 33.8%). An all-Heavy identity takes some of that back (27.5%), because its leftover Riflemen, Protectors and Medics go Undead and form a second set.
- **An Undead Rusher+ plays the same as the Vanguard one (37.5 vs 36.2%),** so the Undead horde is a free variety option (question 4b).
- The Rival as an all-Spec Ops crew is a little harder (1.2 vs 3.8%, 1 win vs 3 in 80). It's the wall either way. The Rival's difficulty is a separate item (synergy-system §7.5).

### 6.6 What the sim doesn't cover
The offer rolls (60/40 home/alternate), Re-issue, Doctrine and Promotion levels 2–3 aren't played. The late decks approximate a run with 2 Promotions. The deckbuilder is a greedy counter, not a human: a human mixes two traits more often. Port Vasel is the only map. The full-run sim (`balance_sim.gd`) needs the engine change first.

## 7. Enemy squads: a fixed art identity
Squads don't choose. Each squad's deck is authored with arts from one family, so it reads as a crew on its banner and in the killfeed, and its trait never changes between runs (the player can scout it from the run map).
| Slot | Squad | Identity (every copy that can carry it) | Calling-card look |
|---|---|---|---|
| 1, 3 | SandViper_07 (Rusher) | **Vanguard**, "Honors crew" | Prestige / ranked cards |
| 2, 4 | Bulwark_Nine (Anchor) | **Heavy**, "Mastery crew" | LMG / launcher mastery cards |
| 5 | Meridian_Six (Rival) | **Spec Ops**, "Operator crew" (Ace, Marksman, Gunner and Medic as Spec Ops; the Commander stays Heavy) | Operator bundle portraits |
| Option | Rusher+ (slot 3) as an **Undead horde** | **Undead**: Point Man, Protector, Flanker and Medic | Zombies cards: a visible "different enemy" moment mid-run |

- Bracket-1 squads stay Recruits (no traits) as today. The identity shows from slot 3 on.
- Data: `SquadData.identity_trait` (the sim's `assign(deck, trait)`: every Trained copy whose options include it, and the rest on the second trait most of them can share), or authored `deck_arts`. The squad's Operator wears a card of its family.

## 8. UI needs (for the UI/UX agent)
- **Name and subname** (the head's naming ask): name = chassis ("Marksman"), subname = art title ("KVD Enforcer Mastery"), with the **trait icon in front of the subname**. Example: "Marksman" / "⚙ KVD Enforcer Mastery". A plain art shows no icon.
- **Codex:** a trait icon on every art tile (corner, shape and colour). On a card's page, the arts grouped by trait with headers ("Spec Ops · 5", "Heavy · 10", "No trait · 1"). The page also lists the options: "Can be: Spec Ops · Heavy". Printed-trait cards (Elites, Fields) show "Trait: printed". A filter chip by trait.
- **EQUIP:** the button names the trait it sets ("EQUIP · Heavy"). A one-line note explains that it sets the default for Recruits and new copies, and that copies in a run keep theirs.
- **Deck view (run):** per copy, the art strip with its trait icon (Recruits: none, "Trains as: V / U"). The Engine panel counts copies per trait (synergy-system §5.2). An art picker per copy shows **same-trait arts only**, with other traits greyed: "change trait with Re-issue".
- **Reward offers:** "**Marksman · Heavy**" with the subname art, the art as the tile, and "Heavy 3 → 4". The on-trait slot is marked. Re-issue appears as the 4th option next to Retire: pick a copy, then a trait tile.
- **Promotion / twin training picker:** the copy, then its 2–3 option tiles (art, trait icon, count change). The EQUIPped one is pre-selected.
- **Board and hand:** unchanged. The trait icon already comes from the copy (`RulesCard.card_trait()`). Two copies of one card can show different icons, and the inspector explains why: "Trait: Heavy (from the art: Mastery family)".
- **Enemy:** the squad's identity trait icon is on its run-map node and its intro banner ("Meridian_Six · Operator crew").
- **Trait rail:** Heavy shows "2/3" with the bonus text greyed until 3 (§5).
- **Accessibility:** trait icons differ by shape (chevron, mask, gear, hand), and the subname line has text, not only the icon.

## 9. Engine and data cost (for the mechanics developer, after approval)
| Item | Where | Size |
|---|---|---|
| `CardData.trait_options` (validator: units only; entries in `SynergyRules.TRAITS` or `&""`; Elites and Fields exactly 1). `card_trait` becomes "default trait" = `trait_options[0]` | `card_data.gd`, 18 `.tres`, `gen_content.gd` | data + ~15 lines |
| `SideSetup.deck_traits: Array[StringName]` parallel to `deck` (missing = default). Rules still never read arts: the UI and run layer resolve art → trait | `side_setup.gd` | ~5 lines |
| `RulesCard.art_trait`; `SynergyRules.trait_at(card, level, art_trait)` returns `art_trait` if it is in the options, else `&""` (plain), and nothing for Recruits | `rules_card.gd`, `synergy_rules.gd`, `match_state.create_unit` | ~15 lines |
| AI: the planner's per-design dedup key gets the trait (`id@level@trait`); records already carry `trait` | `ai_planner.gd` | 1 line + test |
| Art family: `BannerArt.family`, and for the licensed rows section → family (§1.2 table); `BannerArtDB.trait_of(art_id, chassis)` | `banner_art.gd`, `banner_art_db.gd` | ~30 lines |
| Run: `RunProgress.deck_arts` + `deck_traits` per copy (save version 3; v2 saves load with default traits); offers carry `art` + `trait`; the Promotion / twin training choice; a **Re-issue** offer kind; `trait_counts()` per copy; the on-trait slot picks cards whose options include the main trait; the 60/40 art roll | `run_progress.gd`, `reward_offers.gd`, `run_config.gd` | ~80 lines |
| Squads: `SquadData.identity_trait` applied in `SideSetup.from_squad` | `squad_data.gd`, `side_setup.gd`, 3 `.tres` | ~15 lines |
| Set bonus numbers §5 | `synergy_rules.gd` (`TRAIT_BONUS`, `TIER_TEXT`) | data |
| Tests: an art trait outside the options → plain; Recruit with an art trait → none; two copies with different traits count separately; Fields and Elites printed; AI dedup; save v2 → v3; Re-issue; squad identity | `tests/test_rules_synergy.gd`, `test_run_synergy.gd` | ~15 tests |
| Re-run `art_traits_sim.gd` (traits, duel, mirror, campaign) and `balance_sim.gd` after implementation | | |

## 10. Questions for the head (recommended option first)
1. **How many traits per card?** (a) **Two options per unit (home + one alternate; the Rifleman: none / Spec Ops / Undead), with Elites and Fields printed** (recommended: keeps card identity; with the numbers in §5 every trait wins 48–53% and every draft main 49–51%), (b) every unit can carry every trait (most freedom, but the choice stops mattering and about 30 more arts are needed), or (c) three options per unit.
2. **When can a copy's trait be chosen?** (a) **When it trains (reward pick, Promotion, twin training), plus a Re-issue option that costs a Supply Drop pick; same-trait art swaps are always free** (recommended: a run commits to a plan), (b) freely in the deck view between matches (simplest, but no commitment, and you can re-tune for each squad), or (c) only at the reward pick (no Re-issue).
3. **Set-bonus change that goes with it:** (a) **Heavy's bonus only at 3 (Cover +1 and +1 FP) and Undead 3 also gives Cover +1** (recommended: 49 / 48 / 53 / 50%), (b) drop Heavy's tier 2 and keep the rest (50 / 49 / 49 / 52%, same quality, but Heavy loses its Cover), or (c) no number change (Heavy 63%).
4. **Enemy squads:** (a) **a fixed art identity per squad (Rusher Vanguard, Anchor Heavy, Rival Spec Ops)** (recommended), (b) the same plus Rusher+ in slot 3 as an Undead horde (more variety mid-run, same difficulty: 37.5% vs 36.2% in that slot, §6.5), or (c) squads keep chassis-default traits.

## 11. Implementation notes (kc-art-traits-impl, Mechanics Developer)
*Approved answers: T1 (a), T2 (a), T3 (a), T4 (a); fairness rule v2. Tuning answers from kc-fight-impl: F1 (fix the campaign through the Anchor squad), F2 (every LMG has Pierce, the Operator's LMG primary too). Rules, AI, data and run state only; no `scripts/ui` or scene file was touched.*

### 11.1 What was built
| Item | Where |
|---|---|
| `CardData.trait_options` (default first; `&""` = the plain option) on the 11 unit chassis of §4, `trait_choices()`, `has_trait_choice()`, `can_carry(t)`; validator: known traits, no duplicates, `[0] == card_trait`, more than one option only on non-Elite units, never on tactics. Elites and Fields keep one printed trait (no list). | `scripts/data/card_data.gd`, 11 `data/cards/*.tres` |
| `SynergyRules.trait_at(card, level, chosen = TRAIT_DEFAULT)`: Recruits none; printed cards their trait; `TRAIT_DEFAULT` = the default; a chosen trait off the list = plain. | `scripts/rules/synergy_rules.gd` |
| Per-copy trait in a match: `SideSetup.deck_traits` (parallel to `deck`, missing = default) -> `RulesCard.chosen_trait` -> `MatchState.create_unit(..., chosen_trait)` -> `RulesUnit.chosen_trait` / `synergy_trait` -> back to the discard pile. The rules never read arts. | `side_setup.gd`, `rules_card.gd`, `rules_unit.gd`, `match_state.gd` |
| Set bonuses v1.2 (§5): Heavy `[{}, {cover 1, fp 1}]`, Undead tier 3 `{fp 1, cover 1}`; an empty tier gives nothing and shows no set. `tiers` now reports the **active** tier (`active_tier`: Heavy at 2 = 0) and the rail's `next` uses `next_tier` (Heavy 2 -> 3). `TIER_TEXT` Heavy = ["No bonus yet: Heavy needs 3", "Heavy units get Cover +1 and +1 FP"], Undead 3 = "Undead get +1 FP and Cover +1". | `synergy_rules.gd`, `match_state.synergy_view` |
| AI: hand records carry `trait`; the per-design de-dup key is `id@level@trait` (two Marksmen with different traits are two candidates); `record_for_card(..., chosen_trait)`. | `ai_planner.gd`, `ai_view.gd` |
| F2: `pierce = card.pierce or weapon_class == LMG` for units; the Operator gets Pierce when its primary is an LMG (no LMG primary ships yet). | `match_state.gd` (`create_unit`, `_build_operator`), `ai_view.gd` |
| Squad identity (§7): `SquadData.identity_trait` (Rusher `vanguard`, Anchor `heavy`, Rival `specops`); `SideSetup.from_squad` fills `deck_traits` with `SideSetup.identity_traits()` (identity where it is an option, the rest on the trait most of them share, else the default). Bracket-1 squads are Recruits, so no trait shows. | `squad_data.gd`, `side_setup.gd`, 3 `data/squads/*.tres` |
| Art -> family -> trait: `ArtTraits` (data layer, no textures). Art ids: `<chassis>` (default art = home option), `<chassis>~night/dust/flip` (public looks of the home option), `<chassis>~honors/operators/mastery/horde` (our placeholder art of an alternate option: `OPTION_VARIANTS` = subname, tint, emblem), `kc_mw3_*` (licensed; family from the pitch manifest's `family` column, a row without it = the home family, an unknown art = the home family). `SECTION_FAMILY` = §1.2. | `scripts/data/art_traits.gd` |
| Run state: `deck_traits` + `deck_arts` per copy, `equipped_arts` (Codex EQUIP from Settings; dresses the starter's Recruits and pre-selects new copies' arts). Supply Drop offers carry `traits` + `arts` (slot 1 on the main trait when it can carry it; slots 2-3 home 60% / alternate 40%, `ALT_OFFER_CHANCE`, its own RNG stream `supply_art` so card picks are unchanged). Promotion of a Recruit and twin training take a trait (default = the copy's pre-selected art). **Re-issue** is an option flag (`reissue: true`) on the Supply Drop (next to Retire) and on Regroup. Free same-trait art swaps. `trait_counts()` / `main_trait()` / the on-trait slot read per-copy traits. Save **version 3** (`deck_traits`, `deck_arts`, offer `traits` / `arts` / `reissue`); version 1 and 2 saves load with every copy on its default trait and art (a pending v2 Supply Drop is dressed on load). A stored art that is not available (licensed folder absent) shows the option's default art; the trait never changes with it. | `scripts/run/run_progress.gd`, `reward_offers.gd`, `autoload/run_state.gd` |
| Pitch set: `family` column in `mw3-pitch-set.csv`, the builder writes `family` + `trait` into the private manifest; 17 alternate arts added (129 arts), see `../art/mw3-pitch-set.md` §1.2. Flanker · Undead (Quiet Kill shows blood) and Combat Medic · Spec Ops have no MW3 art and use our option placeholders. | `tools/build_mw3_pitch_set.py`, `documentation/art/mw3-pitch-set.*` |
| F1 Anchor fix | see §11.3 |
| Sim: `art_traits_sim.gd` default `opts=game` plays the shipped option lists through the real path (`deck_traits`, no duplicates) and the shipped squad identities; new `swap=` / `armor=` / `slots=` campaign tuning options. | `tests/tools/art_traits_sim.gd` |
| Tests: `tests/test_art_traits.gd` (22) + updated Heavy / Undead / preview tests in `test_rules_synergy.gd` and the save-version / on-trait-slot tests in `test_run_synergy.gd`. | `tests/` |

### 11.2 UI hooks (for the UI agent; nothing in `scripts/ui` was changed)
**Per copy (run deck view):** `RunState.run.deck_view()` rows now add `trait` (what the copy carries in a match: none on Recruits), `trait_choice` (its art's trait; a Recruit trains into it by default), `art`, `subname`, `trait_options` (default first: "Trains as: V / U" on Recruits) and `can_reissue`. Also `run.copy_trait(i)`, `run.trait_choice(i)`, `run.art_of(i)`.
- **Art picker per copy:** `run.art_choices(i)` -> `{same: [...], other: [...]}` (`other` greyed: "change trait with Re-issue"); `RunState.set_copy_art(i, art)` ("" or the reason).
- **Trait options of a card (Codex, offers):** `ArtTraits.options(card, equipped)` / `run.trait_options_of(id)` -> `[{trait, name, family, family_name, default_art, arts}]` (printed cards: one row). `ArtTraits.trait_of(art, card)`, `ArtTraits.family_of(art, card)`, `ArtTraits.subname(art)`, `ArtTraits.arts_for(card)`, `ArtTraits.arts_with_trait(card, t)`, `ArtTraits.default_art(card, t, equipped)`, `ArtTraits.trait_name(t)`, `FAMILY_NAMES`.
- **Supply Drop:** `current_offer()["traits"][k]` / `["arts"][k]` per card ("Marksman · Heavy", subname = `ArtTraits.subname(art)`), `on_trait` marks slot 1, `retire` and `reissue` flags. Count change: `run.trait_counts()`.
- **Promotion / twin training picker:** the offer's options are copies (`options`, `levels`, `traits`); for the chosen copy `run.train_choices(i)` -> `[{trait, name, art, subname, preselected, count_from, count_to}]`, then `RunState.choose_offer(option, trait)` (Promotion) or `RunState.retire_card(option, twin_trait)` (twin). Omitting the trait uses the pre-selected one, so today's screens keep working.
- **Re-issue:** `run.reissue_options()` -> `[{index, id, level, trait, art, subname, options: [{trait, name, art}]}]`, then `RunState.reissue_card(row, new_trait)`; available while `current_offer()["reissue"]` (Supply Drop, Regroup).
- **Codex EQUIP:** RunState passes `Settings.equipped_arts` to the run at start (`run.set_equipped_arts`) and on continue. The Codex's "EQUIP · GIVES X" should read `ArtTraits.trait_of(art, card)` (BannerArtDB.art_trait only knows the licensed manifest's `trait` column).
- **Match view:** `RulesCard.card_trait()` / `RulesUnit.synergy_trait` are per copy already. Callers that still use `SynergyRules.trait_at(card, level)` without the copy's trait (`match_controller.gd` around the inspector, `banner_card.gd`) show the default trait: pass `rc.chosen_trait`.
- **Needed in `scripts/ui` (later UI task):** (1) `MatchController._assign_copy_arts` should take the player's arts from `RunProgress.player_setup().deck_arts` (and dress enemy copies with `ArtTraits.default_art(card, setup.trait_of(i))`), not cycle the licensed pool, or the pitch may show an Undead art on a Vanguard copy; (2) `BannerArtDB._variant` / `subname` / `alt_arts` should know the `<chassis>~<family>` option ids (`ArtTraits.OPTION_VARIANTS`: tint + emblem; today they fall back to the generated gradient placeholder) and list `ArtTraits.arts_for(card)`; (3) the Heavy rail chip "2/3" uses `next` (now 3 for Heavy at 2).

### 11.3 Sims after implementation (real path, shipped data)
