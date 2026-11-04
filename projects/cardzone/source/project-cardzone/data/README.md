# CardZone data format (for the Mid Game Designer, cz06)

All game content is Godot `.tres` Resources under `res://data/`. `CardDB` (autoload) loads every
`.tres` in this folder and its subfolders at start-up, indexes it by `id` and checks it. Every
problem is printed as `CardDB: ERROR [code] file (id) field: message` and the data tests fail, so
broken data never reaches a playtest unnoticed.

**Warnings** (`WARNING [...]`) mark content that is still incomplete: an area with no piles, a
Zone deck shorter than `zone_hard_end_card`, a loot card that is on no pile and dropped by no Zone
card, no Hit or Bounty card yet. They don't fail the load, but **cz06 should finish with none**.
The cz05 samples leave five of them on purpose (four areas without piles, a deck that stops at card 5).

| Folder / file | Class (script in `scripts/data/`) | One file per |
|---|---|---|
| `cards/` | `CardData` (`card_data.gd`) | card definition (copies are made by the rules) |
| `areas/` | `AreaData` (`area_data.gd`) | area of Ridge Hollow (exactly 7) |
| `zone/` | `ZoneCardData` (`zone_card_data.gd`) | Zone card, `zone_01` .. `zone_14` |
| `packs/` | `StartPackData` (`start_pack_data.gd`) | starting loadout order (one: `standard_pack`) |
| `balance.tres` | `BalanceConfig` (`balance_config.gd`), id `balance` | every §16.8 tunable (exactly one file) |

**Samples to copy** (cz05): cards `p9_sidearm`, `scavenge`, `dash`, `duck` (starters), `hit`, `bounty`,
`pump_shotgun` (weapon), `red_dot_sight` (attachment), `bandage` (Spent on play), `smoke_grenade`
(Spent on Brace), `frag_grenade` (blast), `twin_drum_lmg` (supply drop); all 7 areas (adjacency and
Cover final, piles partly filled); Zone cards 1–5 (Calm, drop, gas); `packs/standard_pack.tres`;
`balance.tres` at the spec defaults. `tests/test_data.gd` (`_valid_set()`) builds the whole spec
data set in code (24 cards, the full map, all 14 Zone cards on routes A/B/C), which is a good
cross-check for what you author.

## How to add a card (or anything else)
1. In the Godot editor: FileSystem → right-click `data/cards/` → **New Resource…** → `CardData`
   (or duplicate a sample with Ctrl+D). Name the file after the id: `hunting_rifle.tres`.
2. Fill the fields in the Inspector. Drag `.tres` files into reference slots (`piles`, `close_a`,
   `drop_card`, pack `cards`).
3. Run the tests: `godot --headless --path . -s res://tests/run_tests.gd -- --only=data`.
   `test_project_data_is_valid` lists every error. Warnings print in the log above the results.

Editing a `.tres` as text works too, but enums are stored as numbers (tables below). Enum values
are only ever appended in `data_enums.gd`, never reordered.

## Common rules
- `id`: unique across **all** data, lowercase `snake_case` (`a-z 0-9 _`, starts with a letter).
  The rules, saves and the playtest log use it. Error `duplicate_id` if two files share one.
- `display_name` is required everywhere (cards and areas max 24 characters, packs 32).
- References must point at `.tres` files **inside `data/`**. A file elsewhere, an empty slot, or a
  file that doesn't load is an error (`broken_reference`, `load_failed`).
- Areas name their neighbours by **id** (`adjacent`), not by dragging, so two areas never
  reference each other in a loop.

## CardData (spec §6, §10, §11)
| Field | Meaning / allowed values |
|---|---|
| `code` | Printed number `CZ-000` (three digits), unique. Required. Cards list in code order. |
| `type` | `WEAPON`(0), `ATTACHMENT`(1), `ITEM`(2), `HIT`(3) (the health card), `MARKER`(4) (the Bounty). One Hit card and one Bounty card only. |
| `rarity` | `NONE`(0) Hit/Bounty only · `STARTER`(1) · `COMMON`(2) · `UNCOMMON`(3) · `RARE`(4) · `EPIC`(5) · `LEGENDARY`(6). |
| `cost` | Search to loot from a pile, 1–9, for Common–Legendary pile cards. **0** for starters, Hit, Bounty and supply drops (a drop costs `supply_drop_cost` from balance). |
| `supply_drop` | On for the 4 drop cards (Twin-Drum LMG, Heavy Plate, Longshot .50, Phantom Suit). A drop is placed by a Zone card and never sits in a pile. |
| `brace` | Brace N while in your next hand (0 = none). |
| `move`, `search`, `heal`, `pull` | Play effects, 0–9. |
| `spent` | `NONE`(0), `ON_PLAY`(1) (Bandage, Frag: gone after it resolves), `ON_BRACE`(2) (Smoke Grenade; needs `brace` > 0). |
| `dmg`, `rng` | **Weapons only, both required:** DMG 1–9, RNG 0 (same area), 1 (adjacent) or 2 (anywhere). `rng` is **-1 = not set**, so RNG 0 is a real value. Error `missing_field` if a weapon has no DMG or no RNG; a non-weapon with DMG or RNG is an error. |
| `fires_per_turn` | Weapons: 1–3 (Twin-Drum LMG 2). |
| `ignores_cover` | Marksman Rifle, Longshot .50, Frag Grenade. Only on weapons and blasts. |
| `blast_dmg`, `blast_rng` | Frag Grenade: a `blast_dmg` shot at each player in an area within `blast_rng` (Frag: 2, 1). `blast_rng` -1 when there is no blast. Items only. |
| `attach_dmg`, `attach_rng`, `attach_extra_fire`, `attach_no_brace` | Attachment bonus: Red-dot +1 DMG, Long Scope +1 RNG (the rules cap RNG at 2), Extended Mag +1 shot, Suppressor no Brace. **An attachment needs at least one**, has no play effect (R14), and only attachments carry them. |
| `rules_text` | The effect line as printed, one line, max 120. Required except on the Hit. |
| `art_key` | Optional; the art kit uses the id when empty. |

Item rule: an `ITEM` needs some effect (Move, Search, Heal, Pull, a blast or Brace).
Hit and Bounty print no values (they work through the rules and the balance tunables).

## AreaData (spec §3)
| Field | Meaning |
|---|---|
| `number` | Outer areas 1–6 in ring order (1 Docks … 6 Rail Yard), unique. The Core is 0. |
| `tier` | `OUTER`(0) or `CORE`(1). Sets the pile size (`pile_size_outer` / `pile_size_core`) and the expected pile rarity: outer Common/Uncommon, Core Rare (anything else is a **warning**). |
| `cover` | 0–2 (spec: 0 or 1). |
| `adjacent` | Neighbour ids. |
| `piles` | One entry per loot pile, in printed order (1–8). Each entry is a Common–Legendary, non-drop card; no card twice in one area, and a card has a pile in **one** area only. |

**Map rules** (error `map_rule`): exactly **7 areas** with **one Core**; adjacency is **mutual**
(if A lists B, B must list A); no area lists itself; the map is connected; and every area is at
most **2 steps** from every other (RNG 2 = anywhere). Unknown neighbour ids are `broken_reference`,
a non-area id is `wrong_type`, a repeat is `invalid_value`.

## ZoneCardData (spec §8, R39–R44)
| Field | Meaning |
|---|---|
| `number` | 1–20, flip order. The deck is numbered **1..N with no gaps**, no repeats. |
| `display_name` | "Calm", "Gas closes", "Supply drop", "Final circle I" … |
| `close_a`, `close_b`, `close_c` | Area gas closes on route A / B / C. **All three or none.** |
| `drop_card` + `drop_a`, `drop_b`, `drop_c` | A `supply_drop` card and where it lands on each route. All three landing areas are required with a drop card; none without. |
| `final_circle_step` | 0, or 1/2/3 for final circle I/II/III (Hits per player = `final_circle_hits[step − 1]`, the last value repeats). A final-circle card closes and drops nothing. |

A card's kind follows from its fields: Calm (nothing), Gas, Drop, Gas + Drop, Final circle.

**Route rules** (error `route_rule`), checked per route in flip order:
- a route **never closes the same area twice**;
- a drop never lands in an area that is already gas, including one closed by the same card (gas closes first, R39);
- **the Core never closes**;
- each drop card drops on one Zone card only;
- final-circle steps run 1, 2, 3 on consecutive cards, and **nothing comes after the final circle**.

A deck shorter than `zone_hard_end_card` is a warning. With `zone_hard_end_card` 12 or 13, the
cards past it stay in `data/` but `CardDB.zone_deck()` stops at the end card.

## StartPackData (spec §4, §10, §16.4)
| Field | Meaning |
|---|---|
| `hand_sizes` | Hand sizes this order serves; values from `hand_size`'s allowed list (4, 5). |
| `cards` | **Exactly 10 Starter cards**, top of the loadout first. Repeats are copies (Scavenge ×4). |

Pack rules (error `pack_rule`): 10 cards, all `STARTER`, at least `min_loadout` non-Hit cards, and
**every allowed hand size (4 and 5) is served by exactly one pack**. Spec §16.4 uses the same order
for both, so `standard_pack.tres` has `hand_sizes` 4, 5:
*Scavenge, Scavenge, Scavenge, Duck, Dash · Dash, P-9 Sidearm, Scavenge, Duck, Dash.*

## BalanceConfig (`balance.tres`, spec §16.8 / scope §4)
Every key is checked against its allowed values (error `out_of_range`). The same table
(`BalanceConfig.TUNABLES`) feeds the dev panel (cz13): `allowed_values(key)`, `is_allowed(key, value)`,
`set_tunable(key, value)`.

| Key | Default | Allowed |
|---|---|---|
| `hand_size` | 5 | 4, 5 |
| `health` | 5 | 4–6 |
| `packing_rule` | `HOLD_AND_STOW`(0) | `HOLD_AND_STOW`(0), `RACK_SWAP`(1) |
| `hold_limit` | 2 | 1, 2 |
| `hold_looted` | false | true / false |
| `adrenaline_mode` | `MOVE_OR_SEARCH`(0) | `MOVE_OR_SEARCH`(0), `MOVE_ONLY`(1) |
| `adrenaline_cap_per_turn` | 0 (no cap) | 0, 2 |
| `down_enabled` / `down_value` | true / 1 | on/off, 1 |
| `bounty_heal` | 1 | 0, 1 |
| `bounty_final_circle_extra` | 1 | 0, 1 |
| `bounty_holder_loses_cover` | false | true / false |
| `final_circle_hits` | [1, 2, 3] | any list of 1–14 values, each 0–9 |
| `zone_hard_end_card` | 14 | 12–14 |
| `standard_pack` | true | true |
| `held_cards_public` | false | true / false |
| `hits_on_top_public` | true | true / false |
| `loadout_count_public` | true | true / false |
| `supply_drop_cost` / `crate_cost` / `crate_free_picks` | 4 / 1 / 1 | 3–4 / 0–1 / 0–1 |
| `supply_drop_ready_delay` | 0 | 0, 1 |
| `ditch_per_turn` / `min_loadout` | 1 / 6 | 0–10 (0 = unlimited) / 6 |
| `pile_size_outer` / `pile_size_core` | 3 / 2 | 2–4 |
| `ai_think_budget_ms` | 300 | 100–1000 |

`hand_size` 4 with `supply_drop_cost` 4 is a **warning** (§16.4a: use cost 3 with hand 4).
To change a default, change `balance.tres` **and** the `default` in `BalanceConfig.TUNABLES` and
the field default, and log it in the balance log; `test_balance_defaults_match_spec` holds all three
to the spec table.

## Issue codes
`load_failed`, `unknown_type`, `duplicate_id`, `missing_field`, `out_of_range`, `invalid_value`,
`broken_reference`, `wrong_type`, `map_rule`, `route_rule`, `pack_rule`.

## Lookups (for cz07 rules and the UI)
`CardDB.get_card(id)`, `all_cards()`, `cards_of_type(type)`, `starter_cards()`, `supply_drop_cards()`,
`hit_card()`, `bounty_card()` · `get_area(id)`, `all_areas()` (1–6 then the Core), `outer_areas()`,
`core_area()`, `area_by_number(n)`, `neighbours(id)`, `distance(a, b)` (steps; -1 unknown),
`area_with_pile(card_id)` · `get_zone_card(n)`, `zone_deck()` (1..hard end), `all_zone_cards()` ·
`get_start_pack(hand_size)` · `get_balance()` · `get_resource(id)` · report: `is_valid()`,
`get_errors()`, `get_warnings()`, `has_issue(code, id, field)`, `get_report()`.
