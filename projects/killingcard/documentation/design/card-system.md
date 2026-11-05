# KillingCard: Card System (banners, chassis + art, vertical columns)

*Author: Sr Game Designer Agent · 2026-11-05 · Board task kc-sys · Status: **draft for the head's review** · DESIGN ONLY (no code was changed)*
*Base: Killstreak's approved rules (`projects/killstreak/documentation/design/core-rules.md` + Rulings 1–2, `balance-log.md`, `content-log.md`) and the code copied into `source/project-killingcard/`. Head's brief: `../reference/README.md`. The board mock-up `../reference/head-board-reference.webp` is a UX reference only; none of its art is used or described as ours.*

## 0. Summary in five lines
1. **Every card is a wide calling-card banner.** If the banner's main subject is a character or a weapon, it's a **Unit**. Anything else is a **Tactic**. A curator decides in under 10 seconds with three questions (§1).
2. **Gameplay lives on a small set of "chassis"**: the 20 Killstreak cards with their balance unchanged, plus 4 new chassis that need no new code. **Any number of banner arts** map to one chassis through a closed list of tags and a fixed priority table (§2). New art never needs new design work.
3. **Prototype launch: 24 chassis and about 64 arts** (6 of them animated), plus 8 killstreak arts. The starter deck, enemy squads and every number are Killstreak's (§3).
4. **The board becomes 3 vertical columns.** The objective sits in the middle, and each side's line grows outward from it. Killstreak's engine already works this way: a zone is a column and a line is a stack of rows. **The rules engine needs no rule change.** The work is data (one new resource), a uid→art map, and the UI (§4).
5. **Owning a banner matters** because your equipped calling card *is* your Operator on the board. You also pick which art each copy in your deck wears, and arts unlock through play. **There is no gameplay difference between arts or finishes** (§5). All art is original (§6).

---

## 1. Classification: Unit or Tactic

### 1.1 The three-question test (apply in this order, stop at the first "yes")
Judge only the **dominant subject**: the biggest, sharpest, most central thing in the banner. Background figures, patterns, text overlays and scenery don't count.

| # | Question | Yes → |
|---|---|---|
| Q1 | Is the main subject a **character**? A character is a being with a body or a readable face: a human, a humanoid robot or mech, a creature or monster, a **rendered** animal, or a mythic figure. | **UNIT** |
| Q2 | Is the main subject a **weapon**, either hand-held, crew-served, melee or a bow? (The weapon *is* the unit: its crew is implied.) | **UNIT** |
| Q3 | Anything else: emblems, skulls, text, places, vehicles, objects, body fragments, abstract art. | **TACTIC** |

**Can't decide within 10 seconds?** Classify it as a **TACTIC**, add the `review` tag, and move on. A lead curator clears `review` tags weekly. Calling-card libraries lean heavily toward characters, so defaulting doubtful art to Tactic keeps the tactic pool fed.

### 1.2 Edge cases
| Case | Ruling | Why / example |
|---|---|---|
| **Vehicles** (tank, jet, helicopter, drone, boat, turret), with **no visible crew** | **TACTIC**, tag `vehicle`. Preferred home: the **killstreak** skins (§3.4) and Flank Route. | Our killstreaks *are* vehicles (Recon Drone, Attack Helo, Sentry Turret). A tank's cannon doesn't make it a "weapon" in the Q2 sense. |
| Vehicle **with a visible, readable crew member** (pilot leaning out, soldier on a quad, rider on a horse) | **UNIT**: the character wins (Q1). | A knight on a charging horse is a unit (`human` + `charging`). |
| **Animals** rendered as beings (volume, lighting, a pose) | **UNIT**, tag `beast`. | A spider stalking across the frame, a roaring dinosaur, a wolf. |
| Animal drawn as a **flat logo or emblem** | **TACTIC**, tag `emblem`. | A gold horse silhouette on a red pattern. |
| **Emblems**, insignia, patches, crests, faction marks | **TACTIC**, tag `emblem`. | |
| **Skulls** shown as an icon or object | **TACTIC**, tag `skull`. | A skull-masked soldier with a body is a character, so it's a **UNIT**. |
| **Text only** (numbers, words, ranks, codes) | **TACTIC**, tag `text`. | Text drawn over a character doesn't matter: the character wins. |
| **Abstract** (patterns, colour fields, energy, glitch) | **TACTIC**, tag `abstract`. | |
| **Places** (landscape, city, map, sky) with no dominant figure | **TACTIC**, tag `place`. | |
| **Body fragments**: eyes, a hand, a mouth, with no full head and no weapon | **TACTIC**, tag `fragment`. | Close-up eyes become an intel tactic. A hand rolling dice becomes a gamble tactic. |
| A hand **gripping a weapon** | **UNIT** (Q2: the weapon is the subject). | |
| **Multiple characters** | **One UNIT**, tag `group`. Map it by its weapon or gear like any other unit. A group can never be an Elite. | A squad photo, a zombie horde. |
| **Weapon alone** (a gold rifle on display) | **UNIT** (Q2), mapped by weapon type. | |
| **Silhouette** of a person, if readable as a figure | **UNIT**. | |
| **Character plus a giant emblem** of equal size | **UNIT**: character beats anything else. | This is the tie-break rule: character > weapon > everything else. |

### 1.3 Calibration set (used to train curators)
The reference board shows typical calling-card subjects. **They are third-party images, so they're described here only as test cases and never used.**
- A stalking spider on a red web pattern → UNIT `beast` `sneaking` → **Flanker**
- A flat gold horse emblem on red → TACTIC `emblem` `charging-motion` → **Flank Route**
- An extreme close-up of eyes → TACTIC `fragment` → **Callout**
- A hand throwing dice → TACTIC `fragment` + `object` → **Ammo Resupply**
- A knight charging on horseback → UNIT `human` `charging` → **Point Man**
- A gold sniper rifle on its own → UNIT `weapon` `sniper` `gold` → **Marksman**
- A horde of zombies → UNIT `group` `monster` → **Rifleman**
- A sea god with a trident → UNIT `myth` `melee` `water` → **Brawler** (or **Commander ★** if the curator gives it `hero`)
- A rifleman in neon synthwave colours → UNIT `human` `rifle` `neon` → **Rifleman**
- A robot head-on, no gun → UNIT `machine` → **Gunner**

---

## 2. The chassis + art model

### 2.1 Definitions
- **Chassis** = one gameplay card: cost, class, Firepower, Armor, keywords and effects. It's Killstreak's existing `CardData` resource, unchanged. Players learn about 24 of them.
- **Banner art** (new resource `BannerArt`) = one calling-card image plus its metadata. **Each art belongs to exactly one chassis.** A chassis can have any number of arts.
- A **card in a deck** = a chassis plus the art that copy wears. Three Riflemen in a deck can wear three different banners.
- **Display names:** the board and the rules always show the **chassis name** ("Marksman"), so players learn 24 names, not 300. The art's own title ("Neon Drift") appears in the inspector, the collection and the killfeed tooltip.

`BannerArt` fields (proposal for the mechanics developer):
| Field | Type | Notes |
|---|---|---|
| `id` | StringName | snake_case, unique (`neon_drift`). |
| `title` | String | The banner's name, ≤ 24 characters. |
| `chassis` | CardData | The gameplay card. Art points to chassis, never the other way, so there are no `.tres` cycles. |
| `kind` | UNIT / TACTIC / KILLSTREAK | Must match the chassis type. Equipment counts as TACTIC. |
| `texture` | Texture2D | 1024×256 master (4:1), PNG/WebP. |
| `animation` | SpriteFrames (optional) | For animated finishes: ≤ 16 frames at 512×128, looped. Plays only when the card is focused or being placed (head's rule). |
| `focus_x` | float 0–1 | Horizontal centre of the subject, used for crops (hand on phones, killfeed thumbnails). |
| `tags` | Array[StringName] | From the closed vocabulary in §2.2. The validator rejects unknown tags. |
| `is_default` | bool | The art every player owns from the start for that chassis (exactly one per chassis). |
| `series` | StringName (optional) | Album set, 3–5 arts (§5). |
| `artist`, `licence`, `source_note` | String | Required. See §6. |

### 2.2 Tag vocabulary (closed list, 61 tags)
A curator tags each art in under a minute. **Bold** groups are required.

| Group | Rule | Tags |
|---|---|---|
| **Subject** (exactly 1; it decides the kind) | Unit subjects | `human`, `beast`, `monster` (undead, demon, alien), `machine` (humanoid robot, mech, cyborg), `myth` (gods, knights, samurai, legends), `weapon` (weapon alone), `group` (2+ characters) |
| | Tactic subjects | `emblem`, `skull`, `text`, `place`, `vehicle`, `object` (dice, coins, cards, crates, gadgets), `fragment` (eyes, hands), `abstract` |
| Weapon (0–1) | The most prominent weapon | `smg`, `shotgun`, `rifle`, `sniper`, `lmg`, `pistol`, `melee` (blades, axes, tridents, fists), `bow`, `explosive` (grenade, rocket, C4), `shield` |
| Gear (0–1) | Non-weapon kit that defines a role | `medkit`, `optics` (binoculars, scope, visor, radar), `radio` (antenna, flag, satellite dish), `trap` (wire, mine, web, snare) |
| Pose (0–1, units) | What the character is doing | `aiming`, `charging`, `guarding`, `healing`, `watching`, `sneaking`, `commanding` |
| Mood / element (0–2) | Dominant colour or energy | `fire`, `ice`, `water`, `electric`, `toxic`, `smoke`, `light` (flash, glare), `shadow`, `neon`, `retro`, `gold`, `comic`, `chaos`, `calm` |
| Setting (0–1) | | `urban`, `desert`, `jungle`, `snow`, `sea`, `sky`, `space`, `ruins`, `night` |
| Vehicle type (only with `vehicle`) | | `drone`, `aircraft`, `turret`, `artillery`, `ground` |
| Curator flags | | `hero` (one dominant character in an iconic, front-facing, premium composition; the only way into Elite chassis), `review` (classification unsure) |
| **Finish** (exactly 1; set by the pipeline) | | `static`, `animated` |

### 2.3 Mapping rules: which tags let an art join which chassis
**How to use the table:** go down the list for the art's kind. The **first chassis whose "Joins if" the art meets is the auto-suggestion**. A curator may instead pick **any** other chassis whose "Joins if" the art meets, for example to fill a thin chassis, but never one it doesn't meet. The last row of each list is the **fallback**, which accepts every art of that kind, so no art is ever left without a home.
"Never" lists tags that block a chassis even when "Joins if" matches.

**Units** (order matters)
| # | Chassis | Joins if (any of) | Never | Reads as |
|---|---|---|---|---|
| U1 | **Ace ★** (Wren's stats) | `hero` + (`sniper` or `bow`) | `group` | A legendary marksman |
| U2 | **Commander ★** (Anvil's stats) | `hero` + (`commanding` or `gold` or `myth`) | `group` | A leader others rally around |
| U3 | Combat Medic | `medkit` or `healing` | | |
| U4 | Recon Specialist | `optics` or `radio` or `watching` | | |
| U5 | **Protector** (was Shieldman) | `shield` or `guarding` | | |
| U6 | Demolitions Expert | `explosive` | | |
| U7 | Marksman | `sniper` or `bow` or `aiming` + `night` | | |
| U8 | Gunner | `lmg`, or `machine` with no weapon tag | | Heavy, armoured |
| U9 | Breacher | `shotgun` | | |
| U10 | Flanker | `sneaking`, or `shadow` + (`smg`/`pistol`/`melee`/`beast`) | | |
| U11 | Point Man | `smg` or `pistol` or `charging` | | |
| U12 | **Brawler** (new) | `melee`, or `beast`/`monster`/`myth` with no firearm tag | | Close-quarters, claws and blades |
| U13 | Rifleman (**fallback**) | any unit art | | |

**Tactics** (order matters; Equipment chassis are tactics for art purposes)
| # | Chassis | Joins if (any of) | Reads as |
|---|---|---|---|
| T1 | Tripwire Charge *(equipment)* | `trap` | A web, a wire, a mine |
| T2 | Comms Relay *(equipment)* | `radio` | An antenna, a flag, a dish |
| T3 | Breach and Clear | `explosive` or `fire` or `chaos` | Blast, burning |
| T4 | **Sabotage** (new) | `electric` or `toxic` | Short-circuit, corrosion |
| T5 | Suppressing Fire | `skull` or `ice` | Fear, frozen: the enemy hits weaker |
| T6 | **Smoke Screen** (new) | `smoke` or `shadow` or `night` | Hiding from snipers |
| T7 | **Flashblind** (new) | `light` or `neon` | Blinding: the enemy loses its quick shot |
| T8 | Hold the Line | `emblem` or `shield` or `calm` | Crest, unity, fortification |
| T9 | Callout | `fragment` or `optics` or `text` or `place` | Eyes, maps, codes: intel |
| T10 | Flank Route | `vehicle` (`ground`/`aircraft`) or `sky` or `charging` | Movement and transport |
| T11 | Ammo Resupply (**fallback**) | any tactic art | Dice, coins, crates, abstract |

**Killstreaks** (art kind KILLSTREAK; vehicle arts only)
| Killstreak | Joins if |
|---|---|
| Recon Drone | `vehicle` + (`drone` or `optics`) |
| Mortar Barrage | `vehicle` + `artillery`, or `explosive` + `sky` |
| Sentry Turret (also skins the Sentry token) | `vehicle` + `turret` |
| Attack Helo | `vehicle` + `aircraft` |

A vehicle art can go either to a killstreak or to Flank Route, at the curator's choice. Killstreaks are the better home because they're on screen in every match.

### 2.4 Curator guard rails
- **Elites are scarce by design:** at most 3 arts each at launch, `hero` required, never `group`.
- **Keep the pool spread even:** no chassis should hold more than 12% of all arts. Use the "any eligible chassis" freedom to fill thin chassis.
- **One art, one chassis, forever.** Re-mapping an art someone owns changes their deck, so it needs a design sign-off.
- **The art inspires the effect, but the effect never changes for the art.** A fire Breacher and an ice Breacher play the same.
- **A tool can do the first pass:** the validator can auto-suggest the chassis from tags (§4.6). The curator only confirms.

### 2.5 Rarity and finish (recommendation)
- **There's no rarity on arts and no gameplay difference between arts.** Power lives on the chassis only, and the chassis are balanced by cost.
- The only gameplay rarity is Killstreak's **Elite ★** (reward pool only, 1 copy per deck in practice). It's a chassis property, not an art property.
- **Finishes are cosmetic tiers:**
  - **Standard**: static banner.
  - **Animated**: the premium, foil-like tier. Its loop plays only when the card is focused or placed. Otherwise it shows a still frame plus a thin moving sheen on the frame, so the board stays calm.
  - **Mastery border** (earned): a bronze → silver → gold frame, earned through eliminations made by units wearing that art (§5).
- Recommendation: **animated = premium look, never more power.** This keeps the "earned, not bought" fairness CallingCard established.

---

## 3. Starter set (prototype)

### 3.1 Sizes
| | Count | Notes |
|---|---|---|
| Deck chassis | **24**: 13 units (2 Elite) and 11 tactics (2 of them Equipment) | 20 from Killstreak with **unchanged balance**, plus 4 new ones built only from effect kinds the engine already implements |
| Token chassis | 1 (Sentry) | Not collectible |
| Killstreak chassis | 4 (Recon Drone, Mortar Barrage, Sentry Turret, Attack Helo) | Loadout items, also shown as banners |
| **Banner arts at prototype launch** | **64 deck arts + 8 killstreak arts = 72**, of which **6 are animated** | Minimum viable: 48 (2 per chassis). §3.3 has the allocation. |
| Enemy squad calling cards | 3 (one Operator banner each for Rusher, Anchor, Black Meridian), taken from the 72 | |
| Starter deck | 20 cards, **the same list as Killstreak** (after p19) | Each copy wears that chassis' default art |
| Reward pool | Killstreak's 23 entries + Brawler ×2, Smoke Screen ×1, Flashblind ×1, Sabotage ×1 = **28** | The new chassis enter only through rewards, so starter balance stays untouched |

### 3.2 Chassis list (exact numbers)
FP = Firepower, AR = Armor. "KS" means the value comes straight from Killstreak's data in `source/project-killingcard/data/cards/`. Ids stay the same, so saves, tests and squads keep working; only the display name and text change where marked.

| # | Chassis (display) | id | Type | Class | Cost | FP/AR | Text (≤ 100 chars) | Source | Board icons |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Rifleman | `rifleman` | Unit | AR | 1 | 2/2 | — | KS | — |
| 2 | Point Man | `point_man` | Unit | SMG | 2 | 2/3 | First Shot | KS | First Shot |
| 3 | Combat Medic | `combat_medic` | Unit | AR | 2 | 1/3 | Patch 2 | KS | Patch |
| 4 | Recon Specialist | `recon_specialist` | Unit | AR | 2 | 1/2 | On Deploy: next round, enemy red dots in this zone are revealed. | KS | ⚡ |
| 5 | **Brawler** | `brawler` | Unit | Shotgun | 2 | 2/3 | — | **NEW** | — |
| 6 | Breacher | `breacher` | Unit | Shotgun | 3 | 3/4 | First Shot | KS | First Shot |
| 7 | Marksman | `marksman` | Unit | Sniper | 3 | 2/2 | Pick | KS | Pick |
| 8 | Flanker | `flanker` | Unit | SMG | 3 | 2/3 | Flank | KS | Flank |
| 9 | **Protector** | `shieldman` | Unit | — | 3 | 1/5 | Cover 1. Slides to the front of its column on arrival. | KS stats, **renamed + reworded** | Cover, Protector |
| 10 | Gunner | `gunner` | Unit | LMG | 4 | 2/6 | Suppress | KS | Suppress |
| 11 | Demolitions Expert | `demolitions_expert` | Unit | LMG | 4 | 2/4 | On Down: 3 damage to the enemy point man here. | KS | ⚡ |
| 12 | **Commander ★** | `okafor_anvil` | Unit (Elite) | AR | 5 | 3/6 | Holder. Your other units here get +1 FP. | KS stats, **renamed** (was Sgt. Okafor "Anvil") | Holder, ⚡ |
| 13 | **Ace ★** | `halek_wren` | Unit (Elite) | Sniper | 5 | 4/3 | Pick. Its eliminations give +1 extra streak. | KS stats, **renamed + reworded** (was Lt. Halek "Wren") | Pick, ⚡ |
| 14 | Callout | `callout` | Tactic | — | 0 | — | Resolves immediately: reveal red dots in a zone; your first unit to arrive there gets +1 FP. | KS | — |
| 15 | Ammo Resupply | `ammo_resupply` | Tactic | — | 1 | — | Resolves immediately: draw 2. | KS | — |
| 16 | Flank Route | `flank_route` | Tactic | — | 1 | — | Move a friendly unit to an adjacent zone; it gains First Shot this round. | KS | — |
| 17 | **Smoke Screen** | `smoke_screen` | Tactic | — | 1 | — | Your units in a zone can't be targeted by Pick or Flank this round. | **NEW** | — |
| 18 | **Flashblind** | `flashblind` | Tactic | — | 1 | — | Enemy units in a zone lose First Shot this round. | **NEW** | — |
| 19 | Suppressing Fire | `suppressing_fire` | Tactic | — | 2 | — | Enemy units in a zone get -1 FP this round. | KS | — |
| 20 | Hold the Line | `hold_the_line` | Tactic | — | 2 | — | Your units in a zone gain Cover 1 this round. | KS | — |
| 21 | **Sabotage** | `sabotage` | Tactic | — | 2 | — | Destroy an enemy Equipment in a zone; 1 damage to each enemy unit there. | **NEW** | — |
| 22 | Breach and Clear | `breach_and_clear` | Tactic | — | 3 | — | 2 damage to each enemy unit in a zone (3 if Close). | KS | — |
| 23 | Tripwire Charge | `tripwire_charge` | Equipment (tactic art) | — | 2 | — | Hidden in a zone: the next enemy unit to arrive there takes 3 damage. | KS | — |
| 24 | Comms Relay | `comms_relay` | Equipment (tactic art) | — | 2 | — | While you control this zone: streak +1 at end of round. | KS | — |
| T | Sentry *(token)* | `sentry` | Unit | — | 0 | 2/4 | Cover 1. Ignored for control; no elimination credit for destroying it. | KS | Cover |

**The 4 new chassis use only existing effect kinds** (checked against `scripts/rules/effect_resolver.gd`):
| Chassis | Effects (EffectData) | Design intent | Balance note |
|---|---|---|---|
| Brawler | No effects. Shotgun class gives +2 FP at Close and −1 at Long. | A home for melee, beasts, monsters and myth, which are very common in calling cards. It's a sidegrade of Point Man: more damage at Close (4 vs 3), no First Shot, weak at Long. | Unit-only stat line; compare with Point Man in the harness. |
| Smoke Screen | ON_PLAY · UNTARGETABLE_BY_PICK_FLANK · ALL_FRIENDLIES · CHOSEN_ZONE · duration 1 | The deck-card version of the post-prototype Smoke Canister. It counters Marksman, Ace and Flanker. | Narrow, so cost 1. |
| Flashblind | ON_PLAY · REMOVE_FIRST_SHOT · ALL_ENEMIES · CHOSEN_ZONE · duration 1 | A deck-card version of half the Flashbang. It counters Point Man and Breacher rushes, the Rusher squad's plan. | Narrow, so cost 1. |
| Sabotage | ON_PLAY · DESTROY_EQUIPMENT amount 1 · CHOSEN_ZONE, then ON_PLAY · DAMAGE 1 · ALL_ENEMIES · CHOSEN_ZONE | The deck-card version of the post-prototype Breaching Charge. It answers Tripwire and Comms Relay and chips the backline. | Cheaper and weaker than Breach and Clear (2 dmg for 3). |

All four are **provisional**: the mechanics developer runs `tests/tools/balance_sim.gd` with them added to the reward pool before the prototype ships. Nothing in the starter kit changes, so Killstreak's p19 balance numbers still describe the starter experience.

### 3.3 Art allocation for the prototype (72 arts)
More arts go to the most-played chassis, so alternate art shows up within a single match.

| Chassis | Arts | Animated | Chassis | Arts | Animated |
|---|---|---|---|---|---|
| Rifleman | 5 | 1 | Callout | 3 | 1 |
| Point Man | 4 | 1 | Ammo Resupply | 3 | |
| Marksman | 4 | 1 | Flank Route | 2 | |
| Combat Medic | 3 | | Smoke Screen | 2 | |
| Breacher | 3 | | Flashblind | 2 | |
| Gunner | 3 | | Suppressing Fire | 2 | |
| Brawler | 3 | 1 | Hold the Line | 2 | |
| Flanker | 2 | | Sabotage | 2 | |
| Protector | 2 | | Breach and Clear | 2 | |
| Recon Specialist | 2 | | Tripwire Charge | 2 | |
| Demolitions Expert | 2 | | Comms Relay | 2 | |
| Commander ★ | 2 | 1 | **Deck subtotal** | **64** | **6** |
| Ace ★ | 2 | | Killstreaks (4 × 2) | **8** | 0 |

The art team can work in two passes: pass 1 is the 24 default arts (one per chassis, enough to play), and pass 2 adds the other 48. Generated-art prompts follow the existing pipeline in `projects/killstreak/documentation/art/image-prompt-pack.md`, with the banner format from §2.1.

### 3.4 Stats on the banner: icon slots
Each banner keeps its art clean. Icons sit on the **inner edge**, the edge that faces the objective. That's the top edge for your cards and the bottom edge for enemy cards. Across each objective, the two front cards' numbers face each other, so the fight reads at a glance: "my 3 vs their 2".

```
 Your card (objective is ABOVE it)
 ┌[FP 3]───────[⚡ / keyword]───────[AR 4]┐   ← inner edge (facing the objective)
 │                                         │
 │        art safe zone (centre 64%)       │
 │                                         │
 └[class]──────────────────────────────[★]┘   ← outer edge
```

| Slot | Shows | Look |
|---|---|---|
| Inner-left | **Firepower**, *effective in this column* (range bonus and modifiers included) | Crosshair glyph + number. Friend: teal circle; enemy: red notched diamond (a shape cue for colourblind players, per Killstreak's art direction). A small ▲/▼ marker when modified. |
| Inner-right | **Armor**, current | Shield glyph + number. Turns amber when damaged. Max Armor shows in the inspector. |
| Inner-centre | **Effect strip**: up to 2 keyword glyphs (First Shot, Pick, Flank, Cover, Suppress, Patch, Holder, Protector), or **⚡** for any triggered or aura text (On Deploy, On Down, auras) | More than 2 → ⚡ plus a dot. A tap or long-press opens the inspector (no hover-only info). |
| Outer-left | Weapon-class pip (SMG / Shotgun / AR / Sniper / LMG) | Small. It matters for range bonuses. |
| Outer-right | ★ for Elite, a callsign plate for the Operator, a gear mark for the Sentry token | |
| **In hand** | A **cost hex** at outer-left replaces the class pip. Tactics show cost + ⚡ + a target hint (zone / friendly / enemy). | |
| **Skull** | Not a card stat. It's reserved for eliminations: the killfeed, the streak arc and elimination stamps. | This deliberately departs from the reference, where a skull number sits on the card. |

**Rules for artists:** keep the subject inside the centre 64% of the width. The four corners (18% wide, 30% tall) get covered by badges, and the top and bottom strips may be covered too, because cards sit on either side of the objective. `focus_x` sets the crop for the phone hand and the killfeed.

---

## 4. Rules for vertical columns

### 4.1 The key finding: Killstreak's engine already is a column board
In `scripts/rules/`, each side has `lines[zone]`: an array ordered **front first** (index 0 = point man). New units are appended at the back (`MatchState.put_in_line`), and a unit with `arrives_front` (Shieldman) is inserted at index 0. Eliminated units are removed from the array, so everyone behind them moves up one. The firefight targets index 0 unless Pick (lowest remaining Armor) or Flank (back-most) say otherwise. **That's exactly "enter from the outside, move toward the objective, frontline obvious".** Turning it vertical is a presentation change, not a rules change.

### 4.2 Board layout
```
            Column A            Column B            Column C
 enemy  ┌ staging (face-down) ┐ ┌ staging ┐        ┌ staging ┐   ← enemy deploys enter here (red dots)
        │ row 4  (back)       │ │         │        │         │
        │ row 3               │ │         │        │         │
        │ row 2               │ │         │        │         │
        │ row 1  FRONTLINE    │ │         │        │         │
        ╞═ OBJECTIVE A ═══════╡ ╞═ OBJ B ═╡        ╞═ OBJ C ═╡   ← zone: name, range tag, control, equipment chips
 you    │ row 1  FRONTLINE    │ │         │        │         │
        │ row 2               │ │         │        │         │
        │ row 3               │ │         │        │         │
        │ row 4  (back)       │ │         │        │         │
        └ staging (your plays)┘ └         ┘        └         ┘
 [ hand: banners along the bottom ]
```

| Element | Rule | Killstreak equivalent | Engine change |
|---|---|---|---|
| **Columns** | 3 columns, **A / B / C**. A and C are adjacent to B only. | Zones Left / Mid / Right, same adjacency | None (`ZONE_COUNT = 3`) |
| **Objectives** | One per column, in the middle row. It shows the zone's name, **range tag** (Close / Mid / Long) and control state. Control works as in Killstreak: ≥1 unit of yours and none of theirs (or Holder). | Zone header | None |
| **Rows per side** | **4** (recommended; Killstreak's zone capacity). Row 1 touches the objective. | `zone_capacity = 4` | None. 3 rows is an option (data only; see Question 2). |
| **Staging strip** | The outer edge of each column. Your face-down plays wait here during Deploy. The enemy's planned unit deployments show here as **face-down banner backs (count only)**: these are the red dots, now on the board itself. | Deploy queue + minimap red dots | None (UI reads the same intel). The minimap becomes optional. |
| **Equipment** | A small face-down or face-up chip on your side of the objective tile, not a row. It never uses a row. | Equipment list per zone | None |

### 4.3 How cards enter and advance
1. **Deploy:** you drop a unit banner on a column, and it goes face-down into your staging strip (the order of your plays is kept).
2. **Reveal, arrival:** each unit flips and **slides in from the outer edge toward the objective**, stopping behind the last friendly card in that column. Into an empty column, it slides all the way to row 1 and is your frontline. This is Killstreak's "units go to the back of the line".
3. **Protector:** it slides in **past every friendly card** and takes row 1. The cards it passed shift back one row. This is the head's "Protector slides to the top on spawn"; *top* now means *toward the objective*, on both sides. With two Protectors in the same Reveal, the later one ends up in front (Ruling 6, unchanged).
4. **Advance:** when a card is eliminated, every friendly card behind it slides one row toward the objective at the end of that firefight step. Nothing else moves units forward. The frontline is always the card touching the objective.
5. **Full column:** a column with 4 friendly cards greys out (Killstreak's zone-full rules, Ruling 9).
6. **Flank Route / Rotate:** the unit leaves its column, and the rows behind it close up. It enters the adjacent column **from the outer edge**, at the back (a Protector still slides to the front, Ruling 10).
7. **Sentry token:** enters from the outer edge at the back and never slides to the front (`allow_front = false`, unchanged).
8. **Operator:** a banner unit wearing **your equipped calling card**, with a callsign plate. It enters at the back like any unit, also on respawn and Rotate.

### 4.4 Frontline and backline
| Position | What reaches it |
|---|---|
| **Frontline** (row 1) | Every normal shot (until enough damage is assigned to kill it, then shots go to the next row), **Suppress** (−2 FP), Attack Helo, Frag (2), Demolitions Expert's On Down. |
| **Second row** | Overflow shots, Frag's 1 damage to the "second in line". |
| **Backline** (rows 2–4) | Only **Pick** (the lowest remaining Armor anywhere in the column; ties go to the card nearest the objective), **Flank** (the outermost card), and column-wide effects (Breach and Clear, Mortar Barrage, Sabotage's 1 damage, Suppressing Fire). Smoke Screen shuts out Pick and Flank. |

So the vertical board makes Killstreak's best decisions visible: put a sturdy card in front, keep the medic and sniper behind, and use Pick or Flank to reach past the wall. Shots draw as tracers from the shooter's row to the target's row. A Pick shot visibly skips the frontline.

### 4.5 Unchanged
The round structure (Briefing, Deploy, Reveal, Firefight, Score & Streak), Supply, hand, mulligan, initiative, the First Shot and Main steps, simultaneous damage, damage that persists across rounds, Cover, Patch, Holder, streaks, the Streak Tray, Operator down and respawn, game modes, and every Ruling in Killstreak's `core-rules.md` all stay as they are. The AI (`scripts/ai/`) reads the same state and needs no change.

### 4.6 Exact change list
**Rules engine (`scripts/rules/`): no rule logic changes.** Two optional, display-only touches:
| File | Change | Why |
|---|---|---|
| `match_state.gd` | Add `art_by_uid: Dictionary` (card uid → BannerArt). Fill it where the deck becomes RulesCards (`RulesCard.new(new_uid(), card)`, ~line 108). The rules never read it. | A unit keeps its card's uid, so the killfeed, discard and board can show the right banner for each copy. That's why the map works, while a field on RulesCard would be lost when a unit returns to the discard as a new RulesCard (~line 905). |
| `match_clone.gd` | Copy the `art_by_uid` reference into clones. | AI simulations and the outcome forecast keep working (they ignore it). |

**Setup (`scripts/rules/side_setup.gd`):** add `deck_arts: Array[BannerArt]`, parallel to `deck` (empty = default arts), and `calling_card: BannerArt` (the Operator's banner). `from_squad()` fills them from the squad.

**Data (`scripts/data/`, `data/`):**
| Item | Change |
|---|---|
| `banner_art.gd` (new) | The `BannerArt` resource of §2.1, with `validate()`: tags from the closed list, exactly one subject and one finish, kind matches the chassis' card type, the chassis' "Joins if" is met (§2.3), licence fields not empty. |
| `card_db.gd` (autoload) | Load `data/banners/*.tres`, build the chassis → arts index, check that every collectible chassis has exactly one `is_default` art. Optional: `suggest_chassis(tags)` implementing §2.3 for the curator tool. |
| `squad_data.gd` | Add `calling_card: BannerArt` and `art_tags: Array[StringName]`. Enemy copies pick arts matching those tags, seeded so they're deterministic. Proposal: Rusher `fire`/`chaos`/`charging`, Anchor `guarding`/`emblem`/`calm`, Black Meridian `shadow`/`gold`. |
| `data/cards/shieldman.tres` | `display_name` "Protector", text "Cover 1. Slides to the front of its column on arrival." The id stays. |
| `data/cards/okafor_anvil.tres`, `halek_wren.tres` | Display names "Commander ★" / "Ace ★". Wren's text becomes "Pick. Its eliminations give +1 extra streak." Ids stay. |
| `data/cards/` (new) | `brawler.tres`, `smoke_screen.tres`, `flashblind.tres`, `sabotage.tres` (§3.2). |
| `run_config.tres` | `reward_pool` +5 entries (§3.1). `zone_capacity` stays 4, unless Question 2 picks 3. |
| `data_enums.gd` | No change needed. If a `BannerKind` enum is added, append it only, never reorder. |
| `tests/tools/gen_content.gd` | Generate the 4 new chassis and the renames. |

**UI (`scripts/ui/`, owned by UI/UX):** `lane.gd` becomes a vertical column (staging, rows 4→1, objective tile, mirrored for the enemy). `unit_slot.gd` becomes a banner slot with the §3.4 icon slots. `hand_area.gd` shows banners: full banners on desktop; on phone landscape, a `focus_x` crop at about 2:1 with the same badges (the head's "centred crop" option). `card_info.gd` uses the terms "frontline", "backline" and "Protector". Arrival, Protector and advance get slide animations from the `UNIT_ARRIVED` event's `index` (already emitted). Animated banners play only on focus or placement. The minimap is optional.

**Tests:** no rules-test changes (capacity stays 4). Add data tests for `BannerArt` validation and chassis → default-art coverage. Re-run `balance_sim.gd` with the new reward pool.

---

## 5. Collection value: why owning a banner matters in play
Gameplay power comes only from **chassis**, which you earn through run rewards just like in Killstreak. **Arts** give identity, flex and goals, never power.

1. **Your calling card is your Operator.** The banner you equip as your calling card is the card your Operator wears on the board, in the killfeed ("NEON DRIFT ▸ [FRAG] ▸ Marksman"), on the title screen and in run results. Enemy squads show theirs too. When your Operator eliminates the enemy Operator, your banner gets a full-screen takeover (the existing `call_in_takeover.gd` FX), CallingCard's "You got carded" moment.
2. **Art per copy.** In the deck view, each copy wears an art you choose from the ones you own for that chassis, or you can let the game shuffle your owned arts. Opponents learn to read a deck by chassis, while players flex with their art.
3. **Arts unlock through play, the way calling cards do.** Prototype sources: (a) a Supply Drop offer is shown as a specific banner, and taking it also unlocks that art permanently; (b) challenges like "10 Pick eliminations with Marksmen" unlock a themed Marksman art; (c) winning a run unlocks the Rival squad's calling card.
4. **Mastery borders:** eliminations made by a unit wearing an art upgrade that art's frame (bronze → silver → gold). Your favourite banner shows that you've played it.
5. **Album series:** arts belong to series of 3–5 (`series`). Completing one grants a title and frame. This is CallingCard's Album, kept light.
6. **Fairness rule (binding):** no art, finish, series or mastery level ever changes stats, cost, effects, draw odds or matchmaking.

*Monetisation note (no design here):* animated finishes and series are the natural candidates if the game ever sells cosmetics. The fairness rule above has to hold. A proper design is out of scope.

---

## 6. IP note (binding)
- **We use only original banner art**, made or generated by our team and recorded with `artist`, `licence` and `source_note` on every `BannerArt`. The validator rejects an art without them.
- **We never use real games' calling cards**, logos, emblems, characters, operator likenesses, maps or mode names without a written licence. That includes the third-party banners in `../reference/head-board-reference.webp`, which is a layout reference only and never a source for art, compositions or titles.
- **No real people's likenesses, no real brand marks, no franchise-recognisable characters.** Generated-art prompts must not name a franchise, a studio or a living artist. Keep the prompt with the art for audit.
- Myth figures (sea gods, knights) and generic animals are fine. Recognisable modern depictions owned by someone else are not.
- Project names ("KillingCard", "calling card" as a generic term) still need a trademark check before any public build, the same caveat Killstreak's title carries.

---

## 7. Open questions for the head (recommended option first)
1. **Elite naming:** (a) **role names, Commander ★ / Ace ★, so any `hero` art can wear them** (recommended), or (b) keep the named characters (Anvil, Wren), which allows exactly one art each and no alternates.
2. **Rows per side:** (a) **4, Killstreak's capacity: zero balance risk, smaller banners** (recommended for the prototype), or (b) 3, like the reference: about 25% bigger banners, but it needs a balance re-run and changes some test expectations.
3. **The 4 new chassis** (Brawler, Smoke Screen, Flashblind, Sabotage): (a) **add them through the reward pool only, after a sim pass** (recommended), (b) ship with Killstreak's 20 only and squeeze beasts, myth and smoke arts into the existing chassis, or (c) also put one Brawler into the starter deck.
4. **Calling card = Operator:** (a) **any owned art can be your Operator banner, unit or tactic** (recommended: it's your profile), or (b) unit arts only, so the Operator always shows a character.
