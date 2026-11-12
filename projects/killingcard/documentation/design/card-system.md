# KillingCard: Card System (banners, chassis + art, vertical columns)

*Author: Sr Game Designer Agent · 2026-11-05 · Board task kc-sys · Status: **draft for the head's review** · DESIGN ONLY (no code was changed)*
*Base: Killstreak's approved rules (`projects/killstreak/documentation/design/core-rules.md` + Rulings 1–2, `balance-log.md`, `content-log.md`) and the code copied into `source/project-killingcard/`. Head's brief: `../reference/README.md`. The board mock-up `../reference/head-board-reference.webp` is a UX reference only; none of its art is used or described as ours.*
*Aligned with the Sr Game Artist's `../art/banner-art-direction.md` and `../art/banner-tags-v1.csv` (kc-art). **This doc adopts the artist's tag fields and names.** It adds the values listed in §2.2 and decides the open points in that doc's §2.4 (see §2.6).*

## 0. Summary in five lines
1. **Every card is a wide calling-card banner.** If the banner's main subject is a character, a weapon or an armed vehicle, it's a **Unit**. Anything else is a **Tactic**. A curator decides in under 10 seconds (§1).
2. **Gameplay lives on a small set of "chassis"**: the 20 Killstreak cards with their balance unchanged, plus 4 new chassis that need no new code. **Any number of banner arts** map to one chassis through the artist's tag sheet and a fixed priority table (§2). New art never needs new design work.
3. **Prototype launch: 24 chassis and about 64 deck arts** (6 animated), plus 8 killstreak arts. The artist's first 24 banners are all mapped (§2.5). The starter deck, enemy squads and every number are Killstreak's (§3).
4. **The board becomes 3 vertical columns.** The objective sits in the middle, and each side's line grows outward from it. Killstreak's engine already works this way: a zone is a column and a line is a stack of rows. **The rules engine needs no rule change.** The work is data (one new resource), a uid→art map, and the UI (§4).
5. **Owning a banner matters** because your equipped calling card *is* your Operator on the board. You also pick which art each copy in your deck wears, and arts unlock through play. **There is no gameplay difference between arts or finishes** (§5). All art is original (§6).

---

## 1. Classification: Unit or Tactic

### 1.1 The test (this is the artist's kind rule; apply in order, stop at the first "yes")
Judge only the **dominant subject**: the biggest, sharpest, most central thing in the banner. Background figures, crowds as scenery, patterns and scenery don't count.

| # | Question | Yes → | `subject` values |
|---|---|---|---|
| Q1 | Is the main subject a **character**? That means a soldier or fighter, a creature, an animal or a robot, shown as a combatant with a body or a readable face. | **UNIT** | `soldier`, `creature`, `animal`, `robot` |
| Q2 | Is the main subject a **weapon**, either a showcase weapon alone or an **armed vehicle or drone** (gun mount, missiles)? | **UNIT** | `weapon_only`, `vehicle` (armed) |
| Q3 | Anything else: landscapes, objects and events, emblems, abstract art, unarmed vehicles. | **TACTIC** | `landscape`, `object`, `emblem`, `abstract`, `vehicle` (unarmed) |

**Can't decide within 10 seconds?** Classify it as a **TACTIC**, set `review = yes`, and move on. A lead curator clears reviews weekly. Calling-card libraries lean heavily toward characters, so defaulting doubtful art to Tactic keeps the tactic pool fed.

### 1.2 Edge cases (the artist's rules, plus a few more)
| Case | Ruling |
|---|---|
| **Armed vehicle or drone** as the subject | **UNIT** (it counts as a weapon). It maps to Gunner or Demolitions Expert (§2.3), or to a killstreak skin. |
| **Unarmed vehicle** (transport, boat, scout car) | **TACTIC**, mapped to Flank Route or a killstreak skin. |
| Vehicle **with a visible, readable crew member** as the focus (pilot leaning out, a rider on a horse) | **UNIT**: the character wins (Q1). |
| **Animals** shown as combatants | **UNIT**, `subject = animal` (real species) or `creature` (fantastical). |
| **Emblem of an animal or weapon** (a flat geometric wolf head, a stylised rifle mark) | **TACTIC**, `subject = emblem`: it's a symbol, not a combatant. |
| **Skulls** as an icon or object | **TACTIC** (`emblem` or `object`). A skull-masked soldier with a body is a character, so it's a **UNIT**. |
| **Text-only** banners | **TACTIC** (`emblem`). Our own prompts never produce text (artist §1.5). This rule exists only for licensed or imported art. |
| **Partial or tiny figures** (a hand on a radio, close-up eyes, distant silhouettes, a crowd as scenery) | **TACTIC**, `subject = object` (or `landscape`). |
| A hand **gripping a weapon** that dominates the frame | **UNIT** (`weapon_only`). |
| **Multiple characters** | **One UNIT**, with `count` set to `duo` / `squad` / `horde`. Map it by weapon and verb like any unit. A group can never be an Elite. |
| **Character plus an emblem** of equal size | **UNIT**. The tie-break is character > weapon > everything else. |
| **Equipment** chassis (Tripwire Charge, Comms Relay) | Their art is **tactic** art. Equipment stays a rules type (§3.2). |

### 1.3 Calibration set (used to train curators)
The reference board shows typical calling-card subjects. **They are third-party images, so they're described here only as test cases and never used.**
- A stalking spider on a red web pattern → UNIT `animal` · `natural` · mood `stealthy` → **Flanker**
- A flat gold horse emblem on red → TACTIC `emblem` · verb `charging` → **Flank Route**
- An extreme close-up of eyes → TACTIC `object` · verb `revealing` → **Callout**
- A hand throwing dice → TACTIC `object` → **Ammo Resupply** (fallback)
- A knight charging on horseback with a lance → UNIT `soldier` · `melee` · `charging` → **Brawler**
- A gold sniper rifle on its own → UNIT `weapon_only` · `sniper` → **Marksman**
- A horde of zombies → UNIT `creature` · `natural` · count `horde` → **Brawler**
- A sea god with a trident → UNIT `creature` · `exotic` · `water` → **Brawler** (or **Commander ★** with `hero = yes`)
- A rifleman in neon synthwave colours → UNIT `soldier` · `ar` · `neon` → **Rifleman**
- A robot standing head-on, no gun → UNIT `robot` · `none` → **Gunner**

---

## 2. The chassis + art model

### 2.1 Definitions
- **Chassis** = one gameplay card: cost, class, Firepower, Armor, keywords and effects. It's Killstreak's existing `CardData` resource, unchanged. Players learn about 24 of them.
- **Banner art** (new resource `BannerArt`) = one calling-card image plus its tag-sheet row. **Each art belongs to exactly one chassis.** A chassis can have any number of arts.
- A **card in a deck** = a chassis plus the art that copy wears. Three Riflemen in a deck can wear three different banners.
- **Display names:** the board and the rules always show the **chassis name** ("Marksman"), so players learn 24 names, not 300. The art's title (derived from the file name, e.g. "Marksman Neon", or a curated title) appears in the inspector, the collection and the killfeed tooltip.

`BannerArt` fields (proposal for the mechanics developer). The tag fields mirror the CSV columns one-to-one, so the CSV can be imported directly:
| Field | Type | Notes |
|---|---|---|
| `id` | StringName | The CSV `file` name without `.png` (`kc_b_marksman_neon`). |
| `title` | String | ≤ 24 characters. |
| `chassis` | CardData | The CSV `card` column, resolved to a card id. Art points to chassis, never the other way, so there are no `.tres` cycles. |
| `kind` | UNIT / TACTIC / KILLSTREAK | CSV `kind`, plus `killstreak` (§2.2). Must match the chassis type: Equipment takes tactic art. |
| `banner_texture`, `portrait_texture` | Texture2D | The 4:1 board crop and the 2:3 hand crop, made from one image by the artist's §3 spec. The Technical Artist sets the sizes (artist §3.2). |
| `banner_y`, `portrait_x` | float 0–1 | CSV columns, kept so crops can be re-cut. |
| `animated` | `no` / `yes` / `later` | CSV column. The animation asset follows the artist's tiers (§4). It plays only when the card is focused or placed. |
| tag fields | StringName each | `style`, `subject`, `weapon_class`, `element`, `mood`, `violence`, `setting`, `palette`, `verb`, `count`, plus the new `hero`, `review` and `series` (§2.2). The validator rejects values not in the vocabulary. |
| `is_default` | bool | The art every player owns from the start for that chassis (exactly one per chassis). |
| `artist`, `licence`, `source_note` | String | Required. See §6. |

### 2.2 Tag vocabulary: the artist's sheet, adopted
**The curator uses `banner-tags-v1.csv` exactly as the artist defined it** (artist §2.2: `style`, `kind`, `subject`, `weapon_class`, `element`, `mood`, `violence`, `setting`, `palette`, `verb`, `count`, `card`, `alt_group`, `animated`, `banner_y`, `portrait_x`, `status`, `effect_hint`). Only these fields drive gameplay mapping: **`kind`, `subject`, `weapon_class`, `element`, `verb`, `count`, `hero`**. The rest are style, audio, rating and search data.

Additions and decisions from design (append-only; existing CSV rows stay valid):
| Field | Change | Why |
|---|---|---|
| `kind` | **+ `killstreak`** | Banners that skin a killstreak (Recon Drone, Mortar Barrage, Sentry Turret, Attack Helo). Vehicles, drones, turrets and walkers live here. |
| `element` | **+ `smoke`** | It's the Smoke Screen hook. Before this, it had to be faked with `shadow`. |
| `verb` | **+ `trapping`, `signalling`** | They're the hooks for the two Equipment chassis (Tripwire Charge, Comms Relay). |
| `hero` (new column) | `no` (default) / `yes` | Curator-only. One dominant character in an iconic, front-facing, premium composition. It's the only way into an Elite chassis, and it's never set when `count` isn't `solo`. |
| `review` (new column) | `no` / `yes` | Classification unsure (§1.1). |
| `series` (new column) | empty or `ser_<name>` | Album set of 3–5 arts (§5). |
| `card` | Holds the **chassis id** (`shieldman`, `brawler`, …), not the display name | So the importer resolves it without guessing. Today's display names in the CSV (e.g. "Shieldman") map one-to-one to ids. |
| `alt_group` | Optional, redundant | All arts with the same `card` are alternates of each other. The column can stay for the artist's batching. |

**`weapon_class` on art ≠ gameplay class (decision on the artist's §2.4 (b)).** The artist's 6 proposed classes (`sidearm`, `melee`, `launcher`, `bow`, `natural`, `exotic`) are **adopted as art tags only**. They are **not** appended to `DataEnums.WeaponClass`. A gameplay class drives Killstreak's range table, and adding 6 classes would mean 6 new range rows to balance. Instead, each art class maps to an existing chassis, and that chassis carries a gameplay class:
| Art `weapon_class` | Goes to (first match in §2.3) | Gameplay class of that chassis |
|---|---|---|
| `ar` | Rifleman (or Medic, Recon, Commander by verb) | AR |
| `smg`, `sidearm` | Point Man (or Flanker, Protector by verb or mood) | SMG / none |
| `shotgun` | Breacher | Shotgun |
| `sniper`, `bow` | Marksman / Ace ★ | Sniper |
| `lmg` | Gunner | LMG |
| `launcher` | Demolitions Expert | LMG |
| `melee`, `natural`, `exotic` | **Brawler** (new) | Shotgun (a close-range bonus that reads right for claws, blades and tridents) |
| `none` | by subject and verb (robot → Gunner, otherwise Rifleman) | — |

### 2.3 Mapping rules: which tags let an art join which chassis
**How to use the tables:** go down the list for the art's `kind`. The **first chassis whose "Joins if" the art meets is the auto-suggestion**, written into `card`. A curator may instead pick **any** other chassis whose "Joins if" the art meets, for example to fill a thin chassis, but never one it doesn't meet. The last row is the **fallback**, which accepts every art of that kind. Verb rules come before element rules, because what the subject *does* is the clearest hint.

**Units** (order matters)
| # | Chassis | Joins if (any of) | Reads as |
|---|---|---|---|
| U1 | **Ace ★** (Wren's stats) | `hero = yes` and weapon `sniper`/`bow` | A legendary marksman |
| U2 | **Commander ★** (Anvil's stats) | `hero = yes` (any other weapon) | A leader others rally around |
| U3 | Combat Medic | verb `healing` | |
| U4 | Recon Specialist | verb `scouting` or `revealing` | |
| U5 | **Protector** (was Shieldman) | verb `guarding` or `holding` | Steps in front of everyone |
| U6 | Demolitions Expert | weapon `launcher`, or element `explosive` with weapon `none`/`natural` | Blows up when it falls |
| U7 | Marksman | weapon `sniper` or `bow` | |
| U8 | Breacher | weapon `shotgun`, or verb `breaching` | |
| U9 | Gunner | weapon `lmg`, or subject `robot`, or an armed `vehicle`, or a `creature` larger than a person (curator's call) | Heavy, pins the enemy down |
| U10 | Flanker | verb `flanking`, or mood `stealthy` with weapon `smg`/`sidearm`/`natural`/`melee` | Goes for the back row |
| U11 | **Brawler** (new) | weapon `melee`, `natural` or `exotic` | Claws, blades, myth |
| U12 | Point Man | weapon `smg` or `sidearm`, or verb `rushing`/`charging` | Shoots first |
| U13 | Rifleman (**fallback**) | any unit art | |

**Tactics** (order matters; the Equipment chassis take tactic art)
| # | Chassis | Joins if (any of) | Reads as |
|---|---|---|---|
| T1 | Tripwire Charge *(equipment)* | verb `trapping` | A wire, a mine, a web |
| T2 | Comms Relay *(equipment)* | verb `signalling` | An antenna, a flag, a dish |
| T3 | Callout | verb `revealing` or `scouting` | Eyes, pings, maps: intel |
| T4 | Ammo Resupply | verb `resupplying` | Crates, dice, coins |
| T5 | Flank Route | verb `flanking`, `rushing` or `charging`, or an unarmed `vehicle` | Movement, transport |
| T6 | Hold the Line | verb `guarding` or `holding`, or subject `emblem` | Crest, unity, fortification |
| T7 | **Blackout** (new; was "Flashblind" in the first draft, renamed to the artist's name) | verb `disabling`, or element `light`/`neon` | Power cut, glare: the enemy loses its quick shot |
| T8 | **Smoke Screen** (new) | element `smoke` or `shadow` | Hiding from snipers |
| T9 | Suppressing Fire | verb `suppressing` or `poisoning`, or element `ice`/`toxic` | Fear, cold, gas: the enemy hits weaker |
| T10 | **Sabotage** (new) | element `electric` or `wind` or `earth` | Machines fail, cover breaks |
| T11 | Breach and Clear | verb `breaching` or `burning`, or element `fire`/`explosive` | A blast through a whole column |
| T12 | Ammo Resupply (**fallback**) | any tactic art | |

**Killstreaks** (`kind = killstreak`)
| Killstreak | Joins if |
|---|---|
| Recon Drone | a drone or satellite, or verb `scouting`/`revealing` |
| Mortar Barrage | artillery, or element `explosive` with setting `sky` |
| Sentry Turret (also skins the Sentry token on the board) | a turret, or a `robot` with verb `guarding` |
| Attack Helo | an aircraft |

### 2.4 Curator guard rails
- **Elites are scarce by design:** at most 3 arts each at launch, `hero = yes`, `count = solo`.
- **Keep the pool spread even:** no chassis should hold more than 12% of all arts. Use the "any eligible chassis" freedom to fill thin chassis.
- **One art, one chassis, forever.** Re-mapping an art someone owns changes their deck, so it needs a design sign-off.
- **The art inspires the effect, but the effect never changes for the art.** An ice Marksman and a neon Marksman play the same. The artist's `effect_hint` is input for *future* chassis, never a per-art rule.
- **A tool can do the first pass:** `CardDB.suggest_chassis(row)` implements §2.3 (§4.6). The curator only confirms.

### 2.5 The artist's 24 banners, mapped (prompt pack v1)
**The 6 "(designer)" banners:**
| Banner | Tags that decide | Chassis | Why |
|---|---|---|---|
| `kc_b_frost_wolf` | unit · animal · `natural` · ice · `charging` | **Brawler** (U11) | A beast with natural weapons. It's the Brawler's signature art: close-range and fierce. |
| `kc_b_leviathan_lighthouse` | unit · creature · `natural` · water · `emerging` | **Gunner** (U9: a creature larger than a person) | A huge body that pins the enemy down (Suppress) and soaks hits (Armor 6). The artist's "hidden until revealed" hint is noted for a future chassis. |
| `kc_b_storm_ronin` | unit · soldier · `melee` · wind · `dueling` | **Brawler** (U11) | A melee duelist. The artist's "strike the frontline only" is exactly what a Brawler does. |
| `kc_b_firestorm_city` | tactic · landscape · fire · `burning` | **Breach and Clear** (T11) | "Damage every unit in a column" is Breach and Clear's text. |
| `kc_b_blackout_street` | tactic · landscape · electric · `disabling` | **Blackout** (T7, new) | The new chassis takes this banner's name: enemy units in a zone lose First Shot. |
| `kc_b_toxic_bog` | tactic · landscape · toxic · `poisoning` | **Suppressing Fire** (T9) | "Weaken power" = −1 FP to every enemy in the zone. One round instead of over time, so no new code. |

**The other 18 (confirming or correcting the CSV's `card` column):**
| Banner | Chassis | Note |
|---|---|---|
| `kc_b_rifleman_dusk`, `kc_b_rifleman_comic` | Rifleman | Confirmed (alternates) |
| `kc_b_marksman_snow`, `kc_b_marksman_neon` | Marksman | Confirmed (alternates) |
| `kc_b_point_man_bazaar` | Point Man | Confirmed |
| `kc_b_breacher_doorkick` | Breacher | Confirmed. Its `explosive` element doesn't send it to Demolitions, because U6 needs weapon `launcher` or `none`/`natural`. |
| `kc_b_gunner_inferno` | Gunner | Confirmed |
| `kc_b_shieldman_sparks` | Protector (id `shieldman`) | Confirmed. Its `sidearm` is fine; the verb `guarding` decides. |
| `kc_b_medic_goldengrass` | Combat Medic | Confirmed |
| `kc_b_gilded_launcher` | **Demolitions Expert** | Decided (the CSV said "or new launcher card"). No new launcher card. |
| `kc_b_sentry_walker` | **Sentry Turret killstreak** (`kind = killstreak`) | **Correction:** the Sentry is a non-collectible token, so a deck card can't wear it. The walker skins the Sentry Turret killstreak and the Sentry token it places. If we'd rather have it in decks, Gunner is the alternative (robot · `lmg`). |
| `kc_b_callout_ping` | Callout | Confirmed (verb `revealing`) |
| `kc_b_suppress_tracers` | Suppressing Fire | Confirmed |
| `kc_b_flank_route_alley`, `kc_b_flank_route_emblem` | Flank Route | Confirmed (alternates) |
| `kc_b_hold_seawall` | Hold the Line | Confirmed |
| `kc_b_breach_burst` | Breach and Clear | Confirmed |
| `kc_b_supply_drop` | Ammo Resupply | Confirmed |

**Gaps for the next prompt batch** (chassis with no art yet): Flanker, Recon Specialist, Commander ★, Ace ★, Smoke Screen, Sabotage, Tripwire Charge, Comms Relay, and the Recon Drone, Mortar Barrage and Attack Helo killstreaks. Suggested hooks: a stealthy SMG operator (`flanking`); a spotter with binoculars (`scouting`); one `hero` leader and one `hero` sniper; a smoke-filled street (`smoke`); sparking machinery (`electric`); a wire trap (`trapping`); an antenna mast (`signalling`); a drone, mortar tubes and a gunship.

### 2.6 Answers to the artist's sync list (artist §2.4)
- (a) `kind`: `unit` and `tactic`, plus `killstreak` for loadout banners.
- (b) `weapon_class`: all 12 values are kept as art tags. `DataEnums.WeaponClass` stays unchanged (§2.2 table).
- (c) `element` and `verb` **don't become gameplay keywords**. They only route art to a chassis (§2.3). Gameplay keywords stay Killstreak's 7 (First Shot, Pick, Flank, Cover, Suppress, Patch, Holder), plus "Protector" as the display name of `arrives_front`.
- The artist's question on emblem animals: confirmed, **tactic**.

### 2.7 Rarity and finish (recommendation)
- **There's no rarity on arts and no gameplay difference between arts.** Power lives on the chassis only, and the chassis are balanced by cost.
- The only gameplay rarity is Killstreak's **Elite ★** (reward pool only, 1 copy per deck in practice). It's a chassis property, not an art property.
- **Finishes are cosmetic tiers:**
  - **Standard**: static.
  - **Animated**: the premium, foil-like tier, built with the artist's motion tiers. It loops only when the card is focused or placed; otherwise it shows a still frame plus a subtle frame sheen.
  - **Mastery border** (earned): a bronze → silver → gold frame, earned through eliminations made by units wearing that art (§5).
- Recommendation: **animated = premium look, never more power.**

---

## 3. Starter set (prototype)

### 3.1 Sizes
| | Count | Notes |
|---|---|---|
| Deck chassis | **24**: 13 units (2 Elite) and 11 tactics (2 of them Equipment) | 20 from Killstreak with **unchanged balance**, plus 4 new ones built only from effect kinds the engine already implements |
| Token chassis | 1 (Sentry) | Not collectible; skinned by the Sentry Turret banner |
| Killstreak chassis | 4 (Recon Drone, Mortar Barrage, Sentry Turret, Attack Helo) | Loadout items, also shown as banners |
| **Banner arts at prototype launch** | **64 deck arts + 8 killstreak arts = 72**, of which **6 are animated** | Minimum viable: 48 (2 per chassis). The artist's pack v1 already covers 23 deck arts across 16 chassis, plus 1 killstreak art (§2.5). |
| Enemy squad calling cards | 3 (one Operator banner each for Rusher, Anchor, Black Meridian), taken from the 72 | |
| Starter deck | 20 cards, **the same list as Killstreak** (after p19). **kc-econ (2026-11-08): 10 Standard Issue cards**, see §9 | Each copy wears that chassis' default art |
| Reward pool | Killstreak's 23 entries + Brawler ×2, Smoke Screen ×1, Blackout ×1, Sabotage ×1 = **28** | The new chassis enter only through rewards, so starter balance stays untouched |

### 3.2 Chassis list (exact numbers)
FP = Firepower, AR = Armor. "KS" means the value comes straight from Killstreak's data in `source/project-killingcard/data/cards/`. Ids stay the same, so saves, tests and squads keep working; only the display name and text change where marked.

| # | Chassis (display) | id | Type | Class | Cost | FP/AR | Text (≤ 100 chars) | Source | Board effect glyph |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Rifleman | `rifleman` | Unit | AR | 1 | 2/2 | — | KS | — |
| 2 | Point Man | `point_man` | Unit | SMG | 2 | 2/3 | First Shot | KS | First Shot |
| 3 | Combat Medic | `combat_medic` | Unit | AR | 2 | 1/3 | Patch 2 | KS | Patch |
| 4 | Recon Specialist | `recon_specialist` | Unit | AR | 2 | 1/2 | On Deploy: next round, enemy red dots in this zone are revealed. | KS | ⚡ |
| 5 | **Brawler** | `brawler` | Unit | Shotgun | 2 | 3/3 (was 2/3 before kc-pos-cut, §8) | — | **NEW** | — |
| 6 | Breacher | `breacher` | Unit | Shotgun | 3 | 3/4 | First Shot | KS | First Shot |
| 7 | Marksman | `marksman` | Unit | Sniper | 3 | 2/2 | Pick | KS | Pick |
| 8 | Flanker | `flanker` | Unit | SMG | 3 | 2/3 | Flank | KS | Flank |
| 9 | **Protector** | `shieldman` | Unit | — | 3 | 1/5 | Cover 1. Slides to the front of its column on arrival. | KS stats, **renamed + reworded** | Protector + Cover |
| 10 | Gunner | `gunner` | Unit | LMG | 4 | 2/6 | Suppress | KS | Suppress |
| 11 | Demolitions Expert | `demolitions_expert` | Unit | LMG | 4 | 2/4 | On Down: 3 damage to the enemy point man here. | KS | ⚡ |
| 12 | **Commander ★** | `okafor_anvil` | Unit (Elite) | AR | 5 | 3/6 | Holder. Your other units here get +1 FP. | KS stats, **renamed** (was Sgt. Okafor "Anvil") | Holder + ⚡ |
| 13 | **Ace ★** | `halek_wren` | Unit (Elite) | Sniper | 5 | 4/3 | Pick. Its eliminations give +1 extra streak. | KS stats, **renamed + reworded** (was Lt. Halek "Wren") | Pick + ⚡ |
| 14 | Callout | `callout` | Tactic | — | 0 | — | Instant: reveal red dots in a zone; your first unit to arrive there gets +1 FP. | KS | |
| 15 | Ammo Resupply | `ammo_resupply` | Tactic | — | 1 | — | Instant: draw 2. | KS | |
| 16 | Flank Route | `flank_route` | Tactic | — | 1 | — | Move a friendly unit to an adjacent zone; it gains First Shot this round. | KS | |
| 17 | **Smoke Screen** | `smoke_screen` | Tactic | — | 1 | — | Your units in a zone can't be targeted by Pick or Flank this round. | **NEW** | |
| 18 | **Blackout** | `blackout` | Tactic | — | 1 | — | Enemy units in a zone lose First Shot this round. | **NEW** | |
| 19 | Suppressing Fire | `suppressing_fire` | Tactic | — | 2 | — | Enemy units in a zone get -1 FP this round. | KS | |
| 20 | Hold the Line | `hold_the_line` | Tactic | — | 2 | — | Your units in a zone gain Cover 1 this round. | KS | |
| 21 | **Sabotage** | `sabotage` | Tactic | — | 2 | — | Destroy an enemy Equipment in a zone; 1 damage to each enemy unit there. | **NEW** | |
| 22 | Breach and Clear | `breach_and_clear` | Tactic | — | 3 | — | 2 damage to each enemy unit in a zone (3 if Close). | KS | |
| 23 | Tripwire Charge | `tripwire_charge` | Equipment (tactic art) | — | 2 | — | Hidden in a zone: the next enemy unit to arrive there takes 3 damage. | KS | |
| 24 | Comms Relay | `comms_relay` | Equipment (tactic art) | — | 2 | — | While you control this zone: streak +1 at end of round. | KS | |
| T | Sentry *(token)* | `sentry` | Unit | — | 0 | 2/4 | Cover 1. Ignored for control; no elimination credit for destroying it. | KS | Cover |

**The 4 new chassis use only existing effect kinds** (checked against `scripts/rules/effect_resolver.gd`):
| Chassis | Effects (EffectData) | Design intent | Balance note |
|---|---|---|---|
| Brawler | No effects. Shotgun class gives +2 FP at Close and −1 at Long. | A home for melee, beasts, creatures and myth (`melee`/`natural`/`exotic` art), which are very common in calling cards. It's a sidegrade of Point Man: more damage at Close (4 vs 3), no First Shot, weak at Long. | Compare with Point Man in the harness. |
| Smoke Screen | ON_PLAY · UNTARGETABLE_BY_PICK_FLANK · ALL_FRIENDLIES · CHOSEN_ZONE · duration 1 | The deck-card version of the post-prototype Smoke Canister. It counters Marksman, Ace and Flanker. | Narrow, so cost 1. |
| Blackout | ON_PLAY · REMOVE_FIRST_SHOT · ALL_ENEMIES · CHOSEN_ZONE · duration 1 | Half of the (since removed, kc-loadout-cut) Flashbang as a deck card. It counters Point Man and Breacher rushes, the Rusher squad's plan. | Narrow, so cost 1. |
| Sabotage | ON_PLAY · DESTROY_EQUIPMENT amount 1 · CHOSEN_ZONE, then ON_PLAY · DAMAGE 1 · ALL_ENEMIES · CHOSEN_ZONE | The deck-card version of the post-prototype Breaching Charge. It answers Tripwire and Comms Relay and chips the backline. | Cheaper and weaker than Breach and Clear (2 dmg for 3). |

All four are **provisional**: the mechanics developer runs `tests/tools/balance_sim.gd` with them added to the reward pool before the prototype ships. Nothing in the starter kit changes, so Killstreak's p19 balance numbers still describe the starter experience.

### 3.3 Art allocation for the prototype (72 arts)
More arts go to the most-played chassis, so alternate art shows up within a single match. "Have" = mapped from the artist's pack v1 (§2.5).

| Chassis | Target | Have | Animated | Chassis | Target | Have | Animated |
|---|---|---|---|---|---|---|---|
| Rifleman | 5 | 2 | 1 | Callout | 3 | 1 | 1 (ping) |
| Point Man | 4 | 1 | 1 | Ammo Resupply | 3 | 1 | |
| Marksman | 4 | 2 | 1 (neon) | Flank Route | 2 | 2 | |
| Combat Medic | 3 | 1 | | Smoke Screen | 2 | 0 | |
| Breacher | 3 | 1 | | Blackout | 2 | 1 | 1 (street) |
| Gunner | 3 | 2 | (inferno) | Suppressing Fire | 2 | 2 | |
| Brawler | 3 | 2 | | Hold the Line | 2 | 1 | |
| Flanker | 2 | 0 | | Sabotage | 2 | 0 | |
| Protector | 2 | 1 | | Breach and Clear | 2 | 2 | |
| Recon Specialist | 2 | 0 | | Tripwire Charge | 2 | 0 | |
| Demolitions Expert | 2 | 1 | | Comms Relay | 2 | 0 | |
| Commander ★ | 2 | 0 | 1 | **Deck subtotal** | **64** | **23** | **6** |
| Ace ★ | 2 | 0 | | Killstreaks (4 × 2) | **8** | **1** | 0 |

The 6 animated are the artist's 4 "yes" (marksman_neon, gunner_inferno, callout_ping, blackout_street) plus 2 from later batches (a Rifleman and the Commander). Two passes still work: first one art for every chassis (8 missing, see §2.5), then the remaining alternates.

### 3.4 Stats on the banner: icon slots
> **kc-ui4 (head, 2026-11-06): superseded placement.** "Attack and health icons must be in the same place for my cards and the opponent's." Every card form, both sides, now uses ONE anatomy (the head's): **cost top-left, trait top-right, abilities bottom-left, FP and Armor side by side bottom-right, each a plate with its number inside**; the name (always the chassis) top-centre and the art's subname in the middle band or bottom-centre; the camo / level band on the top edge. Side identity stays in the spine pattern, the FP badge shape (teal circle / red diamond) and the colours. Hand cards and Codex tiles are this same banner (with a cost hex); see `ux/board-layout-v2.md`, kc-ui4 notes. The text below is the original proposal.
This follows the artist's safe zones: **the art's left and right ~15% stay calm for icons**, and the subject stays in the middle 70%. Icons sit on the **inner edge**, the edge that faces the objective. That's the top edge for your cards and the bottom edge for enemy cards. Across each objective, the two front cards' numbers face each other, so the fight reads at a glance: "my 3 vs their 2".

```
 Your card on the board (objective is ABOVE it), 4:1 banner
 ┌[FP 3]│                                      │[AR 4]┐  ← inner edge (facing the objective)
 │      │          art: middle 70%             │      │
 └[cls] │                                      │ [⚡] ┘  ← outer edge
   left 15%                                     right 15%
```

| Slot | Shows | Look |
|---|---|---|
| Left column, inner corner | **Firepower**, *effective in this column* (range bonus and modifiers included) | Crosshair glyph + number. Friend: teal circle; enemy: red notched diamond (a shape cue for colourblind players). A ▲/▼ marker when modified. |
| Right column, inner corner | **Armor**, current | Shield glyph + number. Turns amber when damaged. |
| Right column, outer corner | **Effect**: one keyword glyph (First Shot, Pick, Flank, Cover, Suppress, Patch, Holder, Protector), or **⚡** for triggered or aura text, with a dot if there's more | Right click or long press opens the inspector (studio UX rule). |
| Left column, outer corner | Weapon-class pip (SMG / Shotgun / AR / Sniper / LMG) of the chassis | Small. It matters for range bonuses. |
| Frame | Gold frame + ★ for Elites, a callsign plate for the Operator, a gear mark for the Sentry token | |
| **In hand** | The artist's **2:3 portrait crop** (`portrait_x`), with the cost hex top-left, FP/AR along the bottom, the effect glyph top-right, and the chassis name. Tactics show cost + ⚡ + a target hint (zone / friendly / enemy). | This is the head's "vertical card" option: the portrait crop comes from the same image as the banner, so the card stays recognisable. |
| **Skull** | Not a card stat. It's reserved for eliminations: the killfeed, the streak arc and elimination stamps. | This deliberately departs from the reference, where a skull number sits on the card. |

---

## 4. Rules for vertical columns

### 4.1 The key finding: Killstreak's engine already is a column board
In `scripts/rules/`, each side has `lines[zone]`: an array ordered **front first** (index 0 = point man). New units are appended at the back (`MatchState.put_in_line`), and a unit with `arrives_front` (Shieldman / Protector) is inserted at index 0. Eliminated units are removed from the array, so everyone behind them moves up one. The firefight targets index 0 unless Pick (lowest remaining Armor) or Flank (back-most) say otherwise. **That's exactly "enter from the outside, move toward the objective, frontline obvious".** Turning it vertical is a presentation change, not a rules change.

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
 [ hand: portrait cards along the bottom ]
```

| Element | Rule | Killstreak equivalent | Engine change |
|---|---|---|---|
| **Columns** | 3 columns, **A / B / C**. A and C are adjacent to B only. | Zones Left / Mid / Right, same adjacency | None (`ZONE_COUNT = 3`) |
| **Objectives** | One per column, in the middle row. It shows the zone's name, **range tag** (Close / Mid / Long) and control state. Control works as in Killstreak: ≥1 unit of yours and none of theirs (or Holder). | Zone header | None |
| **Rows per side** | **4** (recommended; Killstreak's zone capacity). Row 1 touches the objective. | `zone_capacity = 4` | None. 3 rows is an option (data only; see Question 2). |
| **Staging strip** | The outer edge of each column. Your face-down plays wait here during Deploy. The enemy's planned unit deployments show here as **face-down banner backs (count only)**: these are the red dots, now on the board itself. | Deploy queue + minimap red dots | None (UI reads the same intel). The minimap becomes optional. |
| **Equipment** | A small chip on your side of the objective tile, not a row. It never uses a row. | Equipment list per zone | None |

### 4.3 How cards enter and advance
1. **Deploy:** you drop a unit on a column, and it goes face-down into your staging strip (the order of your plays is kept).
2. **Reveal, arrival:** each unit flips and **slides in from the outer edge toward the objective**, stopping behind the last friendly card in that column. Into an empty column, it slides all the way to row 1 and is your frontline. This is Killstreak's "units go to the back of the line".
3. **Protector:** it slides in **past every friendly card** and takes row 1. The cards it passed shift back one row. This is the head's "Protector slides to the top on spawn"; *top* now means *toward the objective*, on both sides. With two Protectors in the same Reveal, the later one ends up in front (Ruling 6, unchanged).
4. **Advance:** when a card is eliminated, every friendly card behind it slides one row toward the objective at the end of that firefight step. Nothing else moves units forward. The frontline is always the card touching the objective.
5. **Full column:** a column with 4 friendly cards greys out (Killstreak's zone-full rules, Ruling 9).
6. **Flank Route / Rotate:** the unit leaves its column, and the rows behind it close up. It enters the adjacent column **from the outer edge**, at the back (a Protector still slides to the front, Ruling 10).
7. **Sentry token:** enters from the outer edge at the back and never slides to the front (`allow_front = false`, unchanged).
8. **Operator:** a banner unit wearing **your equipped calling card**, with a callsign plate. It enters at the back like any unit, also on respawn and Rotate.
   **Removed (kc-loadout-cut):** the Operator's Lethal (Frag Grenade), Tactical (Flashbang) and secondary weapon (P-12 Sidearm) are gone, so Frag no longer reaches the frontline / second row (§4.4). The Operator is a unit card with its Primary weapon and its Supply cost (1 Supply in the shipped run), and its card shows that cost in the same cost hex as every deck card (no brass "1 SUPPLY" plate). The full Operator card redesign comes later.

### 4.4 Frontline and backline
| Position | What reaches it |
|---|---|
| **Frontline** (row 1) | Every normal shot (until enough damage is assigned to kill it, then shots go to the next row), **Suppress** (−2 FP), Attack Helo, Demolitions Expert's On Down. |
| **Second row** | Overflow shots. |
| **Backline** (rows 2–4) | Only **Pick** (the lowest remaining Armor anywhere in the column; ties go to the card nearest the objective), **Flank** (the outermost card), and column-wide effects (Breach and Clear, Mortar Barrage, Sabotage's 1 damage, Suppressing Fire). Smoke Screen shuts out Pick and Flank. |

So the vertical board makes Killstreak's best decisions visible: put a sturdy card in front, keep the medic and sniper behind, and use Pick or Flank to reach past the wall. Shots draw as tracers from the shooter's row to the target's row. A Pick shot visibly skips the frontline.

### 4.5 Unchanged
The round structure (Briefing, Deploy, Reveal, Firefight, Score & Streak), Supply, hand, mulligan, initiative, the First Shot and Main steps, simultaneous damage, damage that persists across rounds, Cover, Patch, Holder, streaks, the Streak Tray, Operator down and respawn, game modes, and every Ruling in Killstreak's `core-rules.md` all stay as they are. The AI (`scripts/ai/`) reads the same state and needs no change.

### 4.6 Exact change list
**Rules engine (`scripts/rules/`): no rule logic changes.** Two display-only touches:
| File | Change | Why |
|---|---|---|
| `match_state.gd` | Add `art_by_uid: Dictionary` (card uid → BannerArt). Fill it where the deck becomes RulesCards (`RulesCard.new(new_uid(), card)`, ~line 108). The rules never read it. | A unit keeps its card's uid, so the killfeed, discard and board can show the right banner for each copy. That's why the map works, while a field on RulesCard would be lost when a unit returns to the discard as a new RulesCard (~line 905). |
| `match_clone.gd` | Copy the `art_by_uid` reference into clones. | AI simulations and the outcome forecast keep working (they ignore it). |

**Setup (`scripts/rules/side_setup.gd`):** add `deck_arts: Array[BannerArt]`, parallel to `deck` (empty = default arts), and `calling_card: BannerArt` (the Operator's banner). `from_squad()` fills them from the squad.

**Data (`scripts/data/`, `data/`):**
| Item | Change |
|---|---|
| `banner_art.gd` (new) | The `BannerArt` resource of §2.1, with `validate()`: each tag field holds a value from the vocabulary (artist §2.2 + §2.2 additions here), kind matches the chassis' card type, the chassis' "Joins if" is met (§2.3), the elite rules hold (`hero`, `count = solo`), and the licence fields aren't empty. |
| `tools/import_banner_csv` (new, editor or headless script) | Turns `banner-tags-v1.csv` rows into `data/banners/*.tres`. It fills an empty `card` with `suggest_chassis()`. |
| `card_db.gd` (autoload) | Load `data/banners/*.tres`, build the chassis → arts index, check that every collectible chassis has exactly one `is_default` art. `suggest_chassis(row)` implements §2.3. |
| `squad_data.gd` | Add `calling_card: BannerArt` and `art_prefs: Dictionary` (tag field → values). Enemy copies pick arts matching those tags, seeded so they're deterministic. Proposal: Rusher element `fire`/`explosive`, mood `aggressive`; Anchor verb `guarding`/`holding`, mood `defiant`; Black Meridian palette `gold`, element `shadow`. |
| `data_enums.gd` | **No change.** `WeaponClass` stays at 6 values (§2.2 decision). |
| `data/cards/shieldman.tres` | `display_name` "Protector", text "Cover 1. Slides to the front of its column on arrival." The id stays. |
| `data/cards/okafor_anvil.tres`, `halek_wren.tres` | Display names "Commander ★" / "Ace ★". Wren's text becomes "Pick. Its eliminations give +1 extra streak." Ids stay. |
| `data/cards/` (new) | `brawler.tres`, `smoke_screen.tres`, `blackout.tres`, `sabotage.tres` (§3.2). |
| `run_config.tres` | `reward_pool` +5 entries (§3.1). `zone_capacity` stays 4, unless Question 2 picks 3. |
| `tests/tools/gen_content.gd` | Generate the 4 new chassis and the renames. |

**UI (`scripts/ui/`, owned by UI/UX):** `lane.gd` becomes a vertical column (staging, rows 4→1, objective tile, mirrored for the enemy). `unit_slot.gd` becomes a banner slot with the §3.4 icon slots. `hand_area.gd` shows portrait-crop cards. `card_info.gd` uses the terms "frontline", "backline" and "Protector". Every banner, badge, objective and chip opens an inspector on right click or long press (studio UX rule). Arrival, Protector and advance get slide animations from the `UNIT_ARRIVED` event's `index` (already emitted). Animated banners play only on focus or placement. The minimap is optional.

**Tests:** no rules-test changes (capacity stays 4). Add data tests for `BannerArt` validation, chassis → default-art coverage and `suggest_chassis` on the 24 rows of §2.5 (their expected chassis are listed there). Re-run `balance_sim.gd` with the new reward pool.

---

## 5. Collection value: why owning a banner matters in play
Gameplay power comes only from **chassis**, which you earn through run rewards just like in Killstreak. **Arts** give identity, flex and goals, never power.

1. **Your calling card is your Operator.** The banner you equip as your calling card is the card your Operator wears on the board, in the killfeed, on the title screen and in run results. Enemy squads show theirs too. When your Operator eliminates the enemy Operator, your banner gets a full-screen takeover (the existing `call_in_takeover.gd` FX), CallingCard's "You got carded" moment.
2. **Art per copy.** In the deck view, each copy wears an art you choose from the ones you own for that chassis, or you can let the game shuffle your owned arts. Opponents learn to read a deck by chassis, while players flex with their art.
3. **Arts unlock through play, the way calling cards do.** Prototype sources: (a) a Supply Drop offer is shown as a specific banner, and taking it also unlocks that art permanently; (b) challenges like "10 Pick eliminations with Marksmen" unlock a themed Marksman art; (c) winning a run unlocks the Rival squad's calling card.
4. **Mastery borders:** eliminations made by a unit wearing an art upgrade that art's frame (bronze → silver → gold). Your favourite banner shows that you've played it.
5. **Album series:** arts belong to series of 3–5 (`series`). Completing one grants a title and frame. This is CallingCard's Album, kept light.
6. **Fairness rule (binding):** no art, finish, series or mastery level ever changes stats, cost, effects, draw odds or matchmaking.

*Monetisation note (no design here):* animated finishes and series are the natural candidates if the game ever sells cosmetics. The fairness rule above has to hold. A proper design is out of scope.

---

## 6. IP note (binding)
- **We use only original banner art**, made or generated by our team (the artist's pipeline) and recorded with `artist`, `licence` and `source_note` on every `BannerArt`. The validator rejects an art without them.
- **We never use real games' calling cards**, logos, emblems, characters, operator likenesses, maps or mode names without a written licence. That includes the third-party banners in `../reference/head-board-reference.webp`, which is a layout reference only and never a source for art, compositions or titles.
- **No real people's likenesses, no real brand marks, no real weapon or vehicle models, no franchise-recognisable characters.** Generated-art prompts must not name a franchise, a studio or a living artist (the artist's §1.5 hard rules and reject checklist apply). Keep the prompt with the art for audit.
- Myth figures (sea gods, ronin) and generic animals are fine. Recognisable modern depictions owned by someone else are not.
- Project names ("KillingCard", "calling card" as a generic term) still need a trademark check before any public build, the same caveat Killstreak's title carries.

---

## 7. Open questions for the head (recommended option first)
1. **Elite naming:** (a) **role names, Commander ★ / Ace ★, so any `hero` art can wear them** (recommended), or (b) keep the named characters (Anvil, Wren), which allows exactly one art each and no alternates.
2. **Rows per side:** (a) **4, Killstreak's capacity: zero balance risk, smaller banners** (recommended for the prototype), or (b) 3, like the reference: about 25% bigger banners, but it needs a balance re-run and changes some test expectations.
3. **The 4 new chassis** (Brawler, Smoke Screen, Blackout, Sabotage): (a) **add them through the reward pool only, after a sim pass** (recommended), (b) ship with Killstreak's 20 only and squeeze beast, myth and smoke art into the existing chassis, or (c) also put one Brawler into the starter deck.
4. **Calling card = Operator:** (a) **any owned art can be your Operator banner, unit or tactic** (recommended: it's your profile), or (b) unit arts only, so the Operator always shows a character.

---

## Head's decisions (2026-11-05, task kc-sys)
- **S1 Elites:** role names **Commander ★ / Ace ★**, so any hero art can wear them.
- **S2 Rows:** **4 rows per side**, like Killstreak (no balance change).
- **S3 New chassis** (Brawler, Smoke Screen, Blackout, Sabotage): **reward pool only, after a balance sim**.
- **S4 Operator:** **unit art only** for now. The Operator is a deployable unit with stronger stats. Idea to explore next: Operators use **weapon-mastery style banners** that the player grinds for **camo variants** (alt-art tiers of the same Operator), because the Operator is the card you see every game.
- From kc-art: invented faces OK in stylised styles; flat emblems are tactics (a third "field card" type is being explored in `field-cards.md`, task kc-field); new weapon types map onto the existing 6 classes.
- From kc-field: a third card type, **Field** (model B, full model in the first prototype). Curator rule: "Fighter or gun → Unit. Symbol or building → Field. A moment → Tactic." See `field-cards.md`.
- **Private pitch build (2026-11-05, task kc-cod):** for a prototype shown only to Activision, the head chose to use the real Modern Warfare III calling cards. They are downloaded by `tools/fetch_mw3_calling_cards.py` into a **git-ignored** folder and are never committed (this repository is public) or published anywhere public. A clean checkout falls back to placeholder/original art. Any public or commercial use still needs original art or a licence.


## 8. Position cut (kc-pos-cut, 2026-11-06)
*The head: "Remove the position based effect. It's too much. We'll keep that for tactics." Full spec and numbers: `synergy-system.md` §13.*
- **A unit's stats no longer depend on its row or column.** Gone from units: the neighbour keywords (Guard, Spotter, Fireteam, Overwatch), the row-1 condition on trait bonuses, and the **range bonus by column** (the weapon-class table of §3.4 and §2.2: SMG +1 Close, Shotgun +2 Close / −1 Long, AR +1 Mid, Sniper −1 Close / +2 Long).
- **Weapon class stays** on every chassis as a tag: the art mapping of §2.2, Sniper Perch ("your Sniper units"), and LMG Pierce still read it. The banner's weapon-class pip (§3.4) is flavour now; the Firepower number in the corner is the same in every column.
- **Kept:** Pick, Flank, Pierce, First Shot, Suppress, Cover, Patch, Holder, the Protector's slide to the front, the Anvil's "your other units here" aura, column Fields, and every Tactic's position words (Hold the Line, Callout, Breach and Clear "3 if Close", Flank Route, Smoke Screen…).
- **Card changes:** Breacher, Point Man, Gunner, Marksman, Recon Specialist and Rifleman lose their neighbour keyword and nothing else. **Brawler 2/3 → 3/3** (it lost both Fireteam and Shotgun +2 at Close, and would otherwise equal the Standard Issue Trooper).

## Removed (kc-no-training, 2026-11-07)

*The head, after an iPad playtest: "Remove all the training thing." / "Make sure cards only have 1 trait at most."* The card level system is gone: no Recruit / Trained / Veteran / Elite levels, no Promotion, no level coin or camo band, no "Trains:" line or locked keywords. Every card has its printed keywords and effects from the start. Standard Issue cards stay vanilla. A card copy carries at most one trait (see `art-traits.md`, "Removed (kc-no-training)"). "Elite" now only means the named Elite cards (★, rung 4 of the reward ladder).


## 9. Classic deckbuilder economy (kc-econ, 2026-11-08)
*The head: "start at 1 supply and also draw only one card per turn. Maybe the starting deck should be 10 cards so we see our newly earned cards faster. Shuffle discard if we run out of cards, like classic deckbuilder." Numbers and sims: `run-v2.md` §15.*
- **Starter: 10 Standard Issue cards**, the 20-card list halved with its shape kept (mostly units, one kind of Tactic): **Grunt ×3, Trooper ×3, Sergeant ×2, Armored Trooper ×1, Ammo Resupply ×1**. The starter panel shows exactly this list and match 1 draws exactly it (`tests/test_deck_match.gd`).
- **Supply: round N gives N** (round 1 = 1, cap 7). **Draw 1 card per round** (round 1 still draws the opening hand of 4 + 1, with the free mulligan). Hand cap 7.
- **The Operator is free to place in round 1** and costs 1 Supply on every respawn (`RunConfig.operator_free_round1`), so round 1 is "Operator + a 1-drop".
- **Reshuffle:** when you must draw and the deck is empty, the discard pile (played Tactics, downed units, torn-down Fields, burned cards) is shuffled into a new deck. The match log says it ("Discard shuffled into a new deck (6 cards)"), and the DECK badge's inspector explains the rule.
- **Crews play 10 cards too** (every squad and run-slot deck scaled from 18-20 to 10 with its composition kept); the Supply and draw rules are the same on both sides. Deck floor 15 → **8**.
