# Game data format (for the designer)

All game content is Godot `.tres` Resources under `res://data/`. `CardDB` loads every `.tres` in
this folder and its subfolders at start-up, indexes it by `id` and checks it. Any problem is printed
as an error (`CardDB: ERROR [code] file (id) field: message`) and the tests fail, so broken data
never reaches a playtest unnoticed.

| Folder | Class (script) | One file per |
|---|---|---|
| `cards/` | `CardData` (`scripts/data/card_data.gd`) | card design (units, tactics, equipment, tokens) |
| `loadout/` | `LoadoutItem` (`loadout_item.gd`) | Primary, attachment, Secondary, Lethal, Tactical, Perk, Killstreak |
| `squads/` | `SquadData` (`squad_data.gd`) | enemy squad |
| `maps/` | `MapData` (`map_data.gd`) | map |
| `run_config.tres` | `RunConfig` (`run_config.gd`), id `run_default` | the run and all tunable numbers |
| `tutorial/` | `TutorialScript` (`tutorial_script.gd`), id `tutorial_basic` | the scripted first match (p15) |

Samples: `cards/rifleman.tres` (unit), `cards/breach_and_clear.tres` (tactic with a Close bonus),
`loadout/mortar_barrage.tres` (killstreak). Copy them as a starting point.

## How to add a card (or any item)
1. In the Godot editor: FileSystem → right-click `data/cards/` → **New Resource…** → `CardData`
   (or duplicate a sample with Ctrl+D). Name the file after the id: `point_man.tres`.
2. Fill the fields in the Inspector (groups below). Add effects with **effects → Add Element →
   New EffectData**. Effects live inside the card file.
3. To use it in a deck or pool, drag the `.tres` into the array slot. Repeat an entry for copies.
4. Run the tests (`godot --headless --path . -s res://tests/run_tests.gd`). `test_project_data_is_valid`
   lists every problem.

Editing the text of a `.tres` by hand works too, but enums are stored as numbers there (see the
tables below for the order). Never reorder enum values in `data_enums.gd`, only append.

## Common rules
- `id`: unique across **all** data, lowercase `snake_case` (`a-z 0-9 _`, starts with a letter). Saves, logs and decks use it.
- `display_name`: required. `text`: one line, max 100 characters.
- References must point at `.tres` files **inside `data/`**. A reference to a file elsewhere, an empty array slot or a file that doesn't load is an error.

## CardData (deck cards)
| Field | Meaning / allowed values |
|---|---|
| `card_type` | `UNIT`(0), `TACTIC`(1), `EQUIPMENT`(2) = **Field** to players (`DataEnums.CARD_TYPE_FIELD`, `type_label()`). One visible Field per side per column (a new one replaces the old at Reveal; two in one Deploy are refused); visible Fields are torn down by **Overrun** (enemy controls the column after END_OF_ROUND effects). Hidden Fields (traps) are exempt from both. Field PASSIVE / END_OF_ROUND effects must use `THIS_ZONE`. |
| `is_elite` | ★ elite unit (units only) |
| `cost` | Supply, 0–10 |
| `weapon_class` | `NONE`(0, "—"), `SMG`(1), `SHOTGUN`(2), `AR`(3), `SNIPER`(4), `LMG`(5). Units only. |
| `firepower` / `armor` | Units: FP 0–10, Armor 1–20. Tactics and equipment: both 0. |
| keywords | `first_shot`, `pick`, `flank`, `suppress`, `holder` (on/off); `cover` N 0–5, `patch` N 0–5. Units only. |
| `arrives_front` | Always arrives at the front of the line (Shieldman). |
| `hidden`, `consumed_on_trigger` | Equipment only: stays hidden after Reveal; discarded after it fires (Tripwire). |
| `counts_for_control`, `grants_elimination_credit`, `collectible` | Leave on for normal cards. Tokens (the Sentry) set all three off. A non-collectible card can't be in a deck or a reward pool. |
| `effects` | List of EffectData (below). Tactics and equipment need at least one. |

## LoadoutItem
`slot`: `PRIMARY`(0), `ATTACHMENT`(1), `SECONDARY`(2), `LETHAL`(3), `TACTICAL`(4), `PERK`(5), `KILLSTREAK`(6).
Fill only the group for that slot; anything else set is an error.

| Slot | Fields |
|---|---|
| PRIMARY | `weapon_class` (not NONE), `operator_firepower` 0–10, `operator_armor` 1–20, `rotations_per_round` 1–3 (Wasp-9: 2), keywords (Wasp-9 First Shot, Longreach Pick), `attachments` = the level-up pool (ATTACHMENT items) |
| ATTACHMENT | `firepower_bonus` −5..5, `armor_bonus` −5..10, keywords (Foregrip: `cover` 1), and/or effects. Must change something. |
| SECONDARY / LETHAL / TACTICAL | `supply_cost` 0–10, `cooldown_rounds` 0–10 (Lethal/Tactical: 3), `uses_per_round` / `uses_per_match` (0 = unlimited; Sidearm 1 per round), effects (≥ 1) |
| PERK | effects (≥ 1), `uses_per_round` / `uses_per_match` (Field Salvage 1 per round, Grit 1 per match) |
| KILLSTREAK | `streak_threshold` 1–15, `supply_cost` must be 0, effects (≥ 1) |

## EffectData (inside cards and loadout items)
An effect = **when** (`trigger`) + **what** (`kind`, `amount`) + **who** (`target`, `target_class`) +
**where** (`zone_scope`) + optional `condition`, `bonus_amount`/`bonus_condition`, `duration_rounds`, `delay_rounds`.
All effects of one play share the player's choices (the chosen zone / unit) and resolve in list order.

| Field | Values |
|---|---|
| `trigger` | `ON_PLAY` resolves at Reveal · `IMMEDIATE` "Resolves immediately" in Deploy · `ON_DEPLOY` · `ON_DOWN` (units) · `ON_ELIMINATE` (this unit's kills on a unit card; any of yours on a perk) · `PASSIVE` · `START_OF_FIREFIGHT` · `END_OF_ROUND` · `ON_ENEMY_ARRIVE` (equipment traps) |
| `kind` | `DAMAGE`, `MODIFY_FIREPOWER` (± amount), `MODIFY_ARMOR`, `GRANT_COVER`, `REMOVE_COVER`, `GRANT_FIRST_SHOT`, `REMOVE_FIRST_SHOT`, `UNTARGETABLE_BY_PICK_FLANK`, `DRAW`, `REVEAL_RED_DOTS`, `REVEAL_DEPLOYMENTS`, `HIDE_FROM_INTEL`, `MOVE_UNIT`, `STREAK_BONUS`, `STREAK_THRESHOLD_MOD`, `COOLDOWN_MOD`, `DESTROY_EQUIPMENT`, `SUMMON_UNIT` (needs `summon_card`, a UNIT), `SURVIVE_LETHAL`, `HEAL` (each target regains up to amount lost Armor) |
| `target` | `SELF`, `OPERATOR`, `OWNER` (your side: draw, streak, cooldowns), `CHOSEN_ENEMY`, `CHOSEN_FRIENDLY`, `ENEMY_POINT_MAN`, `ENEMY_SECOND_IN_LINE`, `ALL_ENEMIES`, `ALL_FRIENDLIES`, `OTHER_FRIENDLIES`, `NEXT_FRIENDLY_ARRIVING`, `ARRIVING_ENEMY`, `ENEMY_EQUIPMENT`, `FRIENDLY_POINT_MAN` (your frontline unit; as a PASSIVE it follows the line), `MOST_DAMAGED_FRIENDLY` (Patch's rule: most lost Armor, ties front-most) |
| `target_class` | Only units of this weapon class (`NONE` = any). Overwatch Training: `SNIPER`. |
| `zone_scope` | `THIS_ZONE`, `CHOSEN_ZONE`, `OPERATOR_ZONE`, `OPERATOR_OR_ADJACENT`, `ADJACENT_ZONE`, `ALL_ZONES`, `ANY` (not zone-bound) |
| `condition`, `bonus_condition` | `ALWAYS`, `ZONE_IS_CLOSE`, `ZONE_IS_MID`, `ZONE_IS_LONG`, `YOU_CONTROL_ZONE`, `YOU_CONTROL_2_PLUS_ZONES` |
| `amount`, `bonus_amount` | −10..10. DAMAGE, GRANT_COVER, DRAW, STREAK_BONUS, DESTROY_EQUIPMENT, SURVIVE_LETHAL, HEAL need ≥ 1; the MODIFY / MOD kinds need ≠ 0. A bonus needs a bonus_condition. |
| `duration_rounds` | 0 = instant/permanent, 1 = this round, 2 = this and next round (or the next 2 firefights) |
| `delay_rounds` | 0 = now, 1 = next round (Recon Specialist) |

Examples: *Breach and Clear* = ON_PLAY DAMAGE 2, ALL_ENEMIES, CHOSEN_ZONE, bonus 1 if ZONE_IS_CLOSE.
*Frag Grenade* = two effects in OPERATOR_OR_ADJACENT: DAMAGE 2 ENEMY_POINT_MAN, DAMAGE 1 ENEMY_SECOND_IN_LINE.
*Comms Relay* = END_OF_ROUND STREAK_BONUS 1, OWNER, THIS_ZONE, condition YOU_CONTROL_ZONE.
*Sentry Turret* = SUMMON_UNIT with `summon_card` = a non-collectible Sentry unit card (FP 2 / AR 4, Cover 1).

## SquadData (enemy squads)
`display_name` (gamertag), `clan_tag` (≤ 5 chars), `personality` `RUSHER`(0) / `ANCHOR`(1) / `SNIPER_NEST`(2),
`deck` 15–20 card references, `primary`, `secondary`, `lethal`, `tactical` (required, right slot),
`attachments` (from the primary's pool), `perks` ≤ 3, `killstreaks` ≤ 3,
AI weights `weight_damage_dealt` / `weight_damage_taken` / `weight_zone_control` / `weight_deny_streak` (0–10; defaults 1/1/2/3),
`second_best_chance` 0–1, `preferred_ranges` (CLOSE/MID/LONG).

## MapData
`zone_names` and `zone_ranges`, exactly 3 each, in order Left, Mid, Right. Port Vasel: Container Stacks CLOSE, Crane Yard LONG, Loading Offices MID.

## RunConfig (`run_config.tres`)
- **Run:** `matches` (in order; each a RunMatchData: `bracket`, `is_rival`, `squad`, `mode` ZONE_CONTROL/FIREFIGHT/DETONATOR, `map`, `enemy_firepower_bonus`, `enemy_armor_bonus`), `tickets` (3), `supply_drop_choices` (3), `weapon_level_after_matches` ([1, 3, 4] per core-rules Ruling 1; the script default is also [1, 3, 4]), `attachment_choices` (2), `perk_offer_after_matches` ([2, 4]), `perk_choices` (2).
- **Starter kit:** `starter_deck` (exactly `deck_size` = 20 entries), `starter_primary/secondary/lethal/tactical`, `starter_killstreaks` (exactly `killstreak_slots`, all in `killstreak_pool`).
- **Pools:** `reward_pool`, `killstreak_pool`, `perk_pool`.
- **Match rules (core-rules §10):** `deck_size`, `opening_hand` 4, `round1_extra_draw` 1, `free_mulligans` 1, `draws_per_round` 2, `hand_cap` 7, `supply_round_offset` 1 + `supply_cap` 7 (Round N gives N+1, max 7), `zone_capacity` 4, `default_cooldown` 3, `zone_control_target` 6, `firefight_target` 7, `round_cap` 8, `overtime_draw_round` 10, `detonator_arm_rounds` 2, `perk_slots` 3, `killstreak_slots` 3.
- **Range bonuses:** `range_bonus_smg/shotgun/ar/sniper/lmg`, 3 numbers each (Close, Mid, Long), −5..5.

## Error codes
`load_failed` (file broken or points at a missing file) · `unknown_type` (not one of the classes above) ·
`duplicate_id` · `missing_field` · `out_of_range` · `invalid_value` (field doesn't fit the type/slot, bad id format, bad enum) ·
`broken_reference` (points outside `data/` or empty slot) · `wrong_type` (wrong kind of resource or slot).

## TutorialScript (the tutorial match, p15)
`tutorial/tutorial_script.tres` scripts the first match that `scenes/tutorial/Tutorial.tscn` plays.
The steps and enemy plays are sub-resources inside the file (`TutorialStep`, `TutorialEnemyPlay`).

| Field | Meaning |
|---|---|
| `squad`, `map`, `mode` | The opponent (`squad_tutorial`), the map and the mode. |
| `round_cap` | The match always ends at the end of this round (no overtime; a tie is a draw). |
| `score_target` | Early-win score. Keep it high (20) so the drill runs to `round_cap`. |
| `seed_value` | Match seed (draws are stacked, so it only matters for reshuffles). |
| `player_deck` | 8-40 cards, **drawn in list order** (no shuffle): Round 1 draws the first 5, then 2 per round. |
| `player_killstreaks` | Empty = the run config's starter killstreaks. Primary, Secondary, Lethal, Tactical are always the starter ones. |
| `enemy_deck` | Stacked enemy draws (empty = the squad's deck in list order). |
| `enemy_plays` | `TutorialEnemyPlay`: `round_number`, `card` (a unit; empty = place the enemy Operator), `zone` 0 Left / 1 Mid / 2 Right. Committed at the start of that round's Deploy, before the player acts. A card not drawn yet is pulled from the deck. |
| `steps` | `TutorialStep` list, in order (below). The last step must advance on `match_end`. |

**TutorialStep**
| Field | Meaning |
|---|---|
| `index` | 1, 2, 3... in list order. Sent as `EventBus.tutorial_step(index)` when the step starts (playtest log). |
| `round_number` | The round it belongs to (steps must be in round order). |
| `title` | Caption in capitals, max 16 characters. |
| `text` | Max 120 characters: it has to read at a glance on a phone. `{intel}` is replaced by the enemy cards the Recon Drone revealed ("Combat Medic and Rifleman to Mid"). |
| `advance_on` | `next` (NEXT button), `place_operator` (in `zone`), `play_card` (`card_id` to `zone`), `use_item` (`item_id`), `ready`, `round_end` (the round has finished playing), `match_end`. |
| `highlight` | What gets the amber frame: `auto` (from `advance_on`: Operator or hand card, then the lane; the item button; READY), `none`, `operator`, `hand_card`, `lane`, `enemy_row`, `ready`, `streak`, `killstreak`, `minimap`, `score`. `lane` / `enemy_row` use `zone`, `killstreak` uses `item_id`. |
| `lock_input` | On: the screen around the highlight is dimmed, taps elsewhere are blocked and any other play, READY or UNDO is refused. Off: free play, the frame is only a hint. |
| `grant_killstreak` | Forced earn: puts this killstreak in the Streak Tray when the step starts, if the scripted firefight hasn't already earned it. |

Changing the script: keep the enemy plays and the player's stacked draws in step with the steps (the
`test_tutorial.gd` engine test checks that Round 1 and 2 each give an elimination and that the Recon Drone
is earned by Round 2). Run the tests after any change.
