# CardZone: Prototype Content Log

*Mid Game Designer · 2026-11-04 · Board task `cz06` (project cardzone) · Phase: plan*
*Data: `source/project-cardzone/data/` (format: cz05, commit 03b763f, `data/README.md`). Sources: `../mechanics/loadout-loop-spec.md` v0.2 §3, §4, §8, §10, §11 and §16 (§16 wins in the prototype), `../balance-log.md` entry 1 (supply-drop cost 4).*

**Status:** `CardDB` loads **28 cards, 7 areas, 14 Zone cards, 1 pack and 1 balance config with 0 errors and 0 warnings**. Every value below matches spec v0.2 / §16 or one of the logged changes at the end.

## 1. Cards (27 player cards plus the Bounty)

One `.tres` per card in `data/cards/`, named after the id. Copies are made by the rules (4 Scavenge in the pack, pile copies, 5 Hits per health stack). Brace is a separate field (the shield on the card's left edge, spec §6), so it isn't repeated in the rules text.

| Code | id | Name | Type | Rarity | Cost | Brace | Values | Where | Rules text (as printed) |
|---|---|---|---|---|---|---|---|---|---|
| CZ-001 | `p9_sidearm` | P-9 Sidearm | Weapon | Starter | – | – | DMG 1 · RNG 0 | Starter ×1 | Shoot. DMG 1 · RNG 0 |
| CZ-002 | `scavenge` | Scavenge | Item | Starter | – | – | Search 1 | Starter ×4 | Search 1 |
| CZ-003 | `dash` | Dash | Item | Starter | – | – | Move 1 | Starter ×3 | Move 1 |
| CZ-004 | `duck` | Duck | Item | Starter | – | 1 | Search 1 | Starter ×2 | Search 1 |
| CZ-005 | `hit` | Hit | Hit | – | – | – | (rules: free draw, Adrenaline, Down) | Health stack ×`health` | Free draw. Adrenaline: play for Move 1 or Search 1. Down: +1 Brace while in your next draw. |
| CZ-006 | `bounty` | Bounty | Marker | – | – | – | (rules: R36–R38) | Shared ×1 | Round start: to the player with strictly the most health. Hit the holder: heal 1. Final circle: holder takes +1 Hit. |
| CZ-010 | `scrap_smg` | Scrap SMG | Weapon | C | 3 | – | DMG 2 · RNG 0 | Docks | Shoot. DMG 2 · RNG 0 |
| CZ-011 | `trail_boots` | Trail Boots | Item | C | 2 | – | Move 2 | Docks | Move 2 |
| CZ-012 | `bandage` | Bandage | Item | C | 2 | – | Heal 1, Move 1, Spent on play | Farmstead | Heal 1. Move 1. Spent. |
| CZ-013 | `smoke_grenade` | Smoke Grenade | Item | C | 2 | 2 | Move 2, Spent on Brace | Farmstead | Move 2. If you use its Brace, it is Spent. |
| CZ-014 | `pump_shotgun` | Pump Shotgun | Weapon | U | 4 | – | DMG 3 · RNG 0 | Quarry | Shoot. DMG 3 · RNG 0 |
| CZ-015 | `frag_grenade` | Frag Grenade | Item | U | 3 | – | Blast 2 dmg, range 1, ignores Cover, Spent on play | Quarry | Spent. One area within Range 1: a 2-damage shot at each player there (you too). Ignores Cover. Brace, Down apply. |
| CZ-016 | `hunting_rifle` | Hunting Rifle | Weapon | U | 4 | – | DMG 2 · RNG 1 | Radio Hill | Shoot. DMG 2 · RNG 1 |
| CZ-017 | `long_scope` | Long Scope | Attachment | U | 3 | – | +1 RNG (cap 2, R13) | Radio Hill | Attach: +1 RNG (max RNG 2) |
| CZ-018 | `medkit` | Medkit | Item | U | 4 | – | Heal 2 | Motel | Heal 2 |
| CZ-019 | `plate_vest` | Plate Vest | Item | U | 4 | 2 | Move 1 | Motel | Move 1 |
| CZ-020 | `crowbar` | Crowbar | Item | C | 2 | – | Search 2 | Rail Yard | Search 2 |
| CZ-021 | `backpack` | Backpack | Item | U | 3 | – | Search 1, Pull 1 | Rail Yard | Search 1. Pull 1. |
| CZ-022 | `red_dot_sight` | Red-dot Sight | Attachment | C | 2 | – | +1 DMG | Rail Yard | Attach: +1 DMG |
| CZ-023 | `assault_rifle` | Assault Rifle | Weapon | R | 6 | – | DMG 3 · RNG 1 | Old Town (Core) | Shoot. DMG 3 · RNG 1 |
| CZ-024 | `marksman_rifle` | Marksman Rifle | Weapon | R | 6 | – | DMG 2 · RNG 2, ignores Cover | Old Town (Core) | Shoot. DMG 2 · RNG 2. Ignores Cover. |
| CZ-025 | `extended_mag` | Extended Mag | Attachment | R | 5 | – | +1 shot per turn | Old Town (Core) | Attach: this weapon may fire one extra time each turn |
| CZ-026 | `suppressor` | Suppressor | Attachment | R | 5 | – | No card Brace (Down still applies) | Old Town (Core) | Attach: targets can't Brace with cards against this weapon (Down still applies) |
| CZ-027 | `recon_drone` | Recon Drone | Item | R | 5 | – | Search 2, Pull 1 | Old Town (Core) | Search 2. Pull 1. |
| CZ-030 | `twin_drum_lmg` | Twin-Drum LMG | Weapon | E | drop (4) | – | DMG 2 · RNG 1, fires 2 | Zone card 3 | Shoot. DMG 2 · RNG 1. Fires twice each turn. |
| CZ-031 | `heavy_plate` | Heavy Plate | Item | E | drop (4) | 3 | Heal 1, Move 1 | Zone card 6 | Heal 1. Move 1. |
| CZ-032 | `longshot_50` | Longshot .50 | Weapon | L | drop (4) | – | DMG 4 · RNG 2, ignores Cover | Zone card 8 | Shoot. DMG 4 · RNG 2. Ignores Cover. |
| CZ-033 | `phantom_suit` | Phantom Suit | Item | L | drop (4) | 4 | Move 2, Search 1 | Zone card 10 | Move 2. Search 1. |

*Supply drops store `cost` 0 and `supply_drop` on; the rules charge `balance.supply_drop_cost` (4).*

## 2. Areas of Ridge Hollow (spec §3)

Adjacency is the ring 1–2–3–4–5–6–1 plus the Core, which touches all six (largest distance 2). Pile sizes come from `balance.tres`: **2 players: outer piles 3 cards, Core piles 2** (`pile_size_outer` 3, `pile_size_core` 2; 3–4 players would be 4 / 3, within the allowed 2–4).

| # | id | Area | Tier | Cover | Neighbours | Loot piles (printed order) | Cards on the map (2 players) |
|---|---|---|---|---|---|---|---|
| 1 | `docks` | Docks | Outer | 0 | Rail Yard, Farmstead, Core | Scrap SMG (C3) · Trail Boots (C2) | 6 |
| 2 | `farmstead` | Farmstead | Outer | 1 | Docks, Quarry, Core | Bandage (C2) · Smoke Grenade (C2) | 6 |
| 3 | `quarry` | Quarry | Outer | 1 | Farmstead, Radio Hill, Core | Pump Shotgun (U4) · Frag Grenade (U3) | 6 |
| 4 | `radio_hill` | Radio Hill | Outer | 0 | Quarry, Motel, Core | Hunting Rifle (U4) · Long Scope (U3) | 6 |
| 5 | `motel` | Motel | Outer | 1 | Radio Hill, Rail Yard, Core | Medkit (U4) · Plate Vest (U4) | 6 |
| 6 | `rail_yard` | Rail Yard | Outer | 0 | Motel, Docks, Core | Crowbar (C2) · Backpack (U3) · Red-dot Sight (C2) | 9 |
| C | `old_town` | Old Town | Core | 1 | all six | Assault Rifle (R6) · Marksman Rifle (R6) · Extended Mag (R5) · Suppressor (R5) · Recon Drone (R5) | 10 |

Total loot on the map at setup (2 players): 13 outer piles × 3 + 5 Core piles × 2 = **49 cards**, plus the 4 supply drops.

## 3. Zone deck, routes A / B / C (spec §8, R39–R44)

`data/zone/zone_01.tres` … `zone_14.tres`. On a card that both closes and drops, gas closes first (R39), and no drop lands in gas on any route (checked by `CardDB`). Each route closes all six outer areas exactly once, and the Core never closes.

| # | Title | Route A | Route B | Route C | Final circle |
|---|---|---|---|---|---|
| 1 | Calm | – | – | – | – |
| 2 | Calm | – | – | – | – |
| 3 | Supply drop (Twin-Drum LMG) | drop Quarry | drop Docks | drop Motel | – |
| 4 | Gas closes | close Docks | close Radio Hill | close Farmstead | – |
| 5 | Calm | – | – | – | – |
| 6 | Gas closes + drop (Heavy Plate) | close Farmstead · drop Motel | close Quarry · drop Rail Yard | close Rail Yard · drop Radio Hill | – |
| 7 | Gas closes | close Rail Yard | close Motel | close Docks | – |
| 8 | Supply drop (Longshot .50) | drop Old Town | drop Old Town | drop Old Town | – |
| 9 | Gas closes | close Radio Hill | close Farmstead | close Quarry | – |
| 10 | Gas closes + drop (Phantom Suit) | close Quarry · drop Motel | close Docks · drop Rail Yard | close Radio Hill · drop Motel | – |
| 11 | Gas closes | close Motel | close Rail Yard | close Motel | – |
| 12 | Final circle I | – | – | – | step 1: `final_circle_hits[0]` = 1 Hit each |
| 13 | Final circle II | – | – | – | step 2: 2 Hits each |
| 14 | Final circle III | – | – | – | step 3: 3 Hits each; hard end after this round |

The Bounty holder takes `bounty_final_circle_extra` (1) more on each final-circle card (R38). With `zone_hard_end_card` 12 or 13, `CardDB.zone_deck()` stops early and the later cards stay in `data/`.

## 4. Standard pack (spec §4, §16.4)

One `StartPackData`, `packs/standard_pack.tres`, with `hand_sizes` 4 and 5 (§16.4: the same order for both).

| Position (top → bottom) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Card | Scavenge | Scavenge | Scavenge | Duck | Dash | Dash | P-9 Sidearm | Scavenge | Duck | Dash |
| Hand 4 turn | 1 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 3 | 3 |
| Hand 5 turn | 1 | 1 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 2 |

Copies: Scavenge 4, Dash 3, Duck 2, P-9 1 (§10). Turn 1 at hand 5: Search 4 and Move 1. Turn 2 (nothing held): Move 2, a gun, Search 2.

## 5. Tunables (`balance.tres`, spec §16.8)

All 27 keys are at the §16.8 defaults. `balance.tres` was already correct from cz05; I checked it value by value against §16.8 and changed nothing.

| Key | Value | Key | Value |
|---|---|---|---|
| `hand_size` | 5 | `zone_hard_end_card` | 14 |
| `health` | 5 | `standard_pack` | true |
| `packing_rule` | hold_and_stow (0) | `held_cards_public` | false |
| `hold_limit` | 2 | `hits_on_top_public` | true |
| `hold_looted` | false | `loadout_count_public` | true |
| `adrenaline_mode` | move_or_search (0) | `supply_drop_cost` | **4** (balance log entry 1, §16.4a) |
| `adrenaline_cap_per_turn` | 0 (no cap) | `crate_cost` / `crate_free_picks` | 1 / 1 |
| `down_enabled` / `down_value` | true / 1 | `supply_drop_ready_delay` | 0 |
| `bounty_heal` | 1 | `ditch_per_turn` / `min_loadout` | 1 / 6 |
| `bounty_final_circle_extra` | 1 | `pile_size_outer` / `pile_size_core` | 3 / 2 |
| `bounty_holder_loses_cover` | false | `ai_think_budget_ms` | 300 |
| `final_circle_hits` | [1, 2, 3] | | |

## 6. Sim cross-check (`tools/loadout_sim.py`)

I compared the data with the sim's built-in tables (`CARDS`, `PILES`, `COVER`, `ZONE_A/B/C`, `START`) using a scratch script. Every stat, cost, pile, Cover value, Zone line and the pack order match, except these:

| # | Data | Sim | Effect on the numbers |
|---|---|---|---|
| S1 | Supply drops cost **4** (`supply_drop_cost`) | Drop cards carry `cost=3` and the tool has no flag for it | **The default sweep still runs at cost 3.** The cost-4 numbers need the scratch patch from balance-log entry 1 (below). |
| S2 | Smoke Grenade is Spent when it braces (R20) | Never removed; it goes to the bottom like any brace card | Small. Scratch run (hand 5, hold 2, cost 4): first player 21 / 19 / 19 = 59/108 (55%), both out 5/108, medians 9 / 9 / 8, earliest round 6. Within noise of the row below. |
| S3 | Frag Grenade: 2-damage blast, range 1, ignores Cover, Spent | `cost=3` only, "not used by bots" | The bots never loot or throw it, so its strength is untested. |
| S4 | Bounty is a card (`CZ-006`) | Rules-only (no card) | None. |
| S5 | P-9 Sidearm | Named "Sidearm" | None (name only). |

**Re-run of the summary sweep.** `python3 tools/loadout_sim.py --sweep --summary` (sim defaults, drop cost 3) reproduces balance-log entry 1 exactly: at hand 5 / hold 2 the first player wins 19 / 30 / 32 of 36. With the data's drop cost 4 (scratch patch), the full table is:

| Hand | Hold | Route | First-player wins | Both out in final circle | Median last round (range) | Earliest elimination |
|---|---|---|---|---|---|---|
| 4 | 2 | A / B / C | 17 / 17 / 16 of 36 | 18 / 12 / 11 | 13.5 / 13 / 13 | 8 / 7 / 8 |
| 4 | 1 | A / B / C | 18 / 18 / 17 | 13 / 11 / 11 | 13 / 12 / 13 | 8 / 7 / 8 |
| **5** | **2** | **A / B / C** | **19 / 19 / 18 (56/108, 52%)** | **2 / 3 / 1 (6/108)** | **9 / 9 / 8** | **6 / 6 / 7** |
| 5 | 1 | A / B / C | 19 / 21 / 19 (59/108, 55%) | 0 / 0 / 1 | 9 / 8 / 8 | 6 / 6 / 6 |

The **defaults row (hand 5, hold 2, cost 4)** matches §16.4 / §16.4a: 19 / 19 / 18, both out 6/108, medians 9 / 9 / 8, earliest round 6. At hand 4 with cost 4, 41/108 duels (38%) end in a double knockout, as §16.4a warns (`CardDB` warns on that combination too).

## 7. Changes from spec

| # | What | Spec says | Data has | Why / source |
|---|---|---|---|---|
| C1 | Supply-drop cost | §11 "drop (3)", §2/§5 "Search 3" | `cost` 0 on the card, `supply_drop_cost` **4** in balance | Logged decision: balance-log entry 1 → §16.4a, §16.8. |
| C2 | Bounty printed text | "Round start: goes to the player with strictly the most health (tie: set aside). Land a Hit on the holder: heal 1. Final circle: the holder takes 1 extra Hit." | "Round start: to the player with strictly the most health. Hit the holder: heal 1. Final circle: holder takes +1 Hit." | The format allows 120 characters. The tie clause is left off the face; the rule is unchanged (R36). |
| C3 | Hit printed text | §11: "…Remove with Patch up or Heal." | The §6 face text: Adrenaline line plus the "Free draw · Down" reminder | 120-character limit. The cz05 sample text is kept. |
| C4 | Frag Grenade printed text | "Choose one area within Range 1: resolve a 2-damage shot against each player there (including you)… Brace and Down apply." | "Spent. One area within Range 1: a 2-damage shot at each player there (you too). Ignores Cover. Brace, Down apply." | 120-character limit. The meaning is the same. |
| C5 | Zone cards 6 and 10 title | "Gas closes + drop" (two bold heads) | `display_name` "Gas closes + drop" | One title per card. The kind is derived (`GAS_AND_DROP`). |

No number differs from spec v0.2 / §16 apart from C1. Changes to the cz05 samples: Rail Yard, Docks, Motel, Radio Hill and Old Town got their piles. The Bounty text gained the final-circle clause. The Frag text gained "Brace, Down apply". Zone cards 6–14 are new. Field order in `bandage.tres` was normalised (no value change).

## 8. Open questions

1. **Test to update (cz05 owner):** `tests/test_data.gd::test_sample_cards_match_spec` expects `supply_drop_cards()` to be only `[twin_drum_lmg]`. With the full set it is `[twin_drum_lmg, heavy_plate, longshot_50, phantom_suit]`, so that one assertion now fails. The data is correct; the test hard-codes the sample. I did not edit the test.
2. **Hit text vs `adrenaline_mode`:** the printed text says "Move 1 or Search 1". With `move_only` (or the cap of 2) the face is wrong. Should the card face (cz10/cz16) build the Adrenaline line from the tunables?
3. **Art default drop cost:** `scripts/art/card_art.gd` has `DROP_COST_DEFAULT = 3` ("3 in spec v0.2"). The prototype default is 4, so the art should read `CardDB.get_balance().supply_drop_cost` (cz16).
4. **UI mock text:** `scripts/ui/mock_match_data.gd` has its own card table (ids `cz_0xx`, slightly different text, e.g. Plate Vest "Move 1. Brace 2."). It should switch to CardDB when cz10 wires the data.
5. **Sim drift:** `tools/loadout_sim.py` should get a `--drop-cost` flag (default 4 to match the data) and model Smoke-on-Brace and the Frag, so cz09's sweep runs on the shipped values without a scratch patch.
6. **Rounding:** §16.4 / §16.4a quote 51% for 56/108; that is 51.9% (the balance log says 52%). The numbers themselves agree.
