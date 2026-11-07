# KillingCard Run v2: public API for the screens (kc-v2-impl -> kc-v2-ui)

*Owner: Mechanics Developer Agent (kc-v2-impl). Readers: UI/UX agent (kc-v2-ui). Spec: `documentation/design/run-v2.md`.*
*Status: **live**. This file is kept accurate while the rules land; a section marked (planned) is not wired yet.*

Rules of the road:
- The screens call **`RunState`** (autoload) and read **`RunState.run`** (a `RunProgress`) and the **`MatchState`** they are handed. They never write fields directly.
- Every action returns `""` (ok) or a short English reason (show it, or dim the button with it). Views are plain Dictionaries (JSON-safe values, `StringName` ids).
- **Player-facing word is "Terrain"** (head V1). Code says `terrain` everywhere; no player-facing string from these views says "Field" for Terrain. (Field still means the Field *card type*.)
- Every view below carries the text a tooltip / right-click / long-press zoom needs (`name`, `text`, `detail`). Studio rule: everything is inspectable.

---

## 1. Run lifecycle (RunState)

| Call | Returns | Notes |
|---|---|---|
| `RunState.start_run(seed := -1) -> RunProgress` | the run, phase `loadout` | Builds the **map** (first-run fixed map if the profile has never finished a run), draws the **boss** (V3: from unlocked bosses, never the same as last run's). `RunState.run_map_enabled` (default true) = false gives the old 5-match ladder (old tests / tools only). |
| `RunState.operator_choices() -> Array[Dictionary]` | `[{id, name, weapon, fp, armor, keywords: [String], passive_name, passive_text, ability_id, ability_name, ability_text, unlocked: bool, unlock_text, selected: bool}]` | Kestrel, Longreach, Wasp-9, Bastion-60 in that order. Locked ones: `unlocked = false`, `unlock_text` = "Finish a run" / "Reach the boss once" / "Win a run". |
| `RunState.set_primary(id) -> String` | | Refuses a locked Operator. Loadout phase only. |
| `RunState.modifier_choices() -> Array[Dictionary]` | `[{id, name, threat, text, unlocked, unlock_text, on}]` | hardcore, austerity, veterans, fog, hot_ground. |
| `RunState.set_modifiers(ids: Array) -> String` | | Loadout phase only; refuses locked ones; rebuilds the map (Hot Ground adds Terrain). |
| `RunState.begin_run() -> String` | | Ends the loadout; phase becomes `map` (step 1 = F1 is the only reachable node). |
| `RunState.continue_run() -> bool` | | v7 saves load as they were; **v1-v6 saves load as a first-run-shaped map** at the fight they were on (head: no run lost). |
| `RunState.profile_view() -> Dictionary` | `{runs_finished, run_wins, boss_reached, boss_wins: {boss_id: n}, best_threat, terrains_seen: [ids], events_seen: [ids], bosses_seen: [ids], last_boss}` | For the Dossier / After-Action. |

Signals on `RunState` (all after `run_changed`, which still fires on every change):
- `map_changed()`: a move, a node resolved, the map rebuilt (modifiers).
- `node_entered(node: Dictionary)`: the player stepped on a node (the node row of `map_view()`, below). Open the Event / Shop / Rest screen, or the match, from it.
- `req_changed(req: int, delta: int)`: REQ went up or down.
- `unlocked(items: Array[Dictionary])`: after a run ended, what it unlocked: `[{kind: &"operator"|&"boss"|&"modifier", id, name, text}]` (show "New: ..." cards).
- (existing) `system_met(flag)`: new RevealFlags ids for v2 are in §8.

## 2. Phases (`RunState.run.phase`)
`loadout` -> `map` -> one of `match` (fight / elite / boss node), `event`, `shop`, `rest` -> (after a match or some node choices) `rewards` -> back to `map` ... -> `ended`.
- `rewards` is the existing offer queue (Supply Drop, Elite Cache, Salvage, Muster out, weapon level, Perk). After the last offer the phase is `map` again (not `match`).
- `RunProgress.PHASE_MAP`, `PHASE_EVENT`, `PHASE_SHOP`, `PHASE_REST` are the new constants.

## 3. The run map

### `RunState.map_view() -> Dictionary`
```
{
  steps: 9, lanes: 3,
  step: int,                 # index of the step you are on (-1 before F1), 0-based
  current: StringName,       # node id you are on (&"" before F1)
  first_run: bool,           # the fixed first-run map (one fork)
  req: int, tickets: int, max_tickets: int,
  threat: int, modifiers: [StringName],
  boss: <boss_view()>,       # §6, shown from step 1
  nodes: [NODE, ...],        # every node, step then lane order
}
NODE = {
  id: StringName (e.g. &"s3_l0"), step: int (0..8), lane: int (0 = L, 1 = M, 2 = R),
  type: &"fight" | &"elite" | &"event" | &"shop" | &"rest" | &"boss",
  name: String ("Fight", "Elite", "Event", "Shop", "Rest", "Boss"),
  links: [StringName],       # node ids on the next step you may move to from here
  reachable: bool,           # you may move_to() it now
  visited: bool, current: bool, done: bool,
  gives: String, risk: String,   # one line each, for the node inspect ("Win: Supply Drop, +3 REQ" / "Lose: -1 ticket")
  fight: {                   # fight / elite / boss nodes only, else {}
    label: String ("F1".."F4", "Elite I", "Elite II", "Boss"),
    crew: String (squad name), crew_label: String ("Standard Issue crew" ...),
    mode: StringName (&"zone_control" | &"firefight"), mode_name: String,
    armor_bonus: int, green: bool, elite: bool, boss: bool, challenge: bool (Old Rival's Message),
    deck: [StringName],      # the crew's deck list (card ids) for the inspect view
    terrain: [TERRAIN, ...]  # 3 entries, one per column A/B/C; id &"" = no Terrain there
  },
  event: {id, title} ,       # event nodes only (the options show when you arrive)
}
TERRAIN = {zone: int, zone_name: StringName (&"left"|&"mid"|&"right"), id: StringName, name: String, text: String}
```
### Actions
- `RunState.move_to(node_id: StringName) -> String`: phase `map`, node reachable. Fight / elite / boss -> phase `match` (then `RunState.create_match()` as today). Event -> `event`, Shop -> `shop`, Rest -> `rest`. Emits `node_entered`.
- `RunState.current_node() -> Dictionary`: the NODE you are on ({} before F1).

## 4. Event / Shop / Rest

### Event: `RunState.event_view() -> Dictionary`
```
{id, title, scene: String (two lines), options: [OPTION...]}
OPTION = {index, id, label (button text), detail (exact result, odds printed: "50%: an Elite card; 50%: lose 1 ticket"),
          available: bool, reason: String (why not), needs: &"" | &"deck_card" | &"calling_card" | &"terrain",
          choices: [ ... ]}   # for needs: deck rows {index, id, name, trait, art} or Terrain rows TERRAIN-like {id, name, text}
```
`RunState.choose_event(index: int, args := {}) -> Dictionary` -> `{ok, reason, text: String (what happened, for a result line), changes: {req, tickets, added: [card ids], removed: [card ids]}}`.
- args: `{"deck_index": int}` (needs deck_card / calling_card), `{"terrain": StringName}` (needs terrain).
- Some options queue an offer (Range Day "Zero the rifle" = a weapon level; Quartermaster's Audit "Hand in kit" = a Muster out of 2): the phase becomes `rewards` and the normal offer screens show it. Otherwise the phase is `map` again.
- The 9 events: supply_truck, audit (fixed in run 1), wounded_scout, fixer, radio_chatter, memorial, rival_message, range_day, night_drop (spec §3).

### Shop: `RunState.shop_view() -> Dictionary`
```
{req, rung,
 cards: [{slot, id, name, kind: &"unit"|&"tactic"|&"field", elite: bool, trait, art, price, sold: bool, can_buy: bool, reason}],
 perks: [{index, id, name, text, price, can_buy, reason}],     # [] when every Perk slot is full
 muster_out: {price: 2, rows: [{index, id, name, serial, art}], can: bool, reason},   # Standard Issue copies
 discharge:  {price: 3, rows: [{index, id, name, trait, art}],  can: bool, reason},   # any other copy
 restock:    {price: 1, can: bool, reason},
 deck_size, floor}
```
Actions (each `-> String`): `shop_buy(slot)`, `shop_buy_perk(index)`, `shop_muster_out(deck_index)`, `shop_discharge(deck_index)`, `shop_restock()`, `leave_node()` (back to `map`). Prices (V5): unit 4, tactic 3, Field 3, Elite card 7, Muster out 2, Discharge 3, Perk 6, restock 1. Floor 15 for removals.

### Rest: `RunState.rest_view() -> Dictionary`
```
{options: [{id: &"ticket"|&"drill"|&"field_strip", label, detail, available, reason}],
 drill: {count: 2, rows: [{index, id, name, trait, art, standard_issue}]}}
```
`RunState.rest_choose(id: StringName, args := {}) -> String`; drill takes `{"deck_indices": [a, b]}` (up to 2, floor 15). Field-strip queues a weapon-level offer (phase `rewards`).

## 5. Matches in a v2 run
`RunState.create_match(hooks)` is unchanged; the returned `MatchState` already carries the node's Terrain, the boss rule and the Operator kit. Rules-side views on `MatchState`:

### Terrain
- `m.terrain_view(viewer := 0) -> Array[Dictionary]`: 3 rows `{zone: int, zone_name, id, name, text, active_for: [&"player", &"enemy"], held_by: &"player"|&"enemy"|&"" (Rooftops: who holds it at the start of the round)}`; `id == &""` = no Terrain in that column.
- `m.terrain_at(zone) -> StringName`.
- Event `RulesEvent.TERRAIN_TRIGGERED {terrain, zone, side?, uid?, amount?, what: String}` (Minefield damage, Field Hospital heal, Comms Tower streak, Supply Cache Supply, Hot Zone point). Log it ("Minefield: Grunt takes 1").
- Terrain ids: rooftops, smoke, dust_storm, breach_point, floodlights, comms_tower, supply_cache, hot_zone (Zone Control only), minefield, field_hospital. Data: `res://data/terrain/<id>.tres` (`TerrainData`: id, display_name, text, zone_control_only). `TerrainRules.data(id)` / `TerrainRules.all()`.

### Operator kit (passive + once-per-match ability)
- `m.ability_view(side := 0) -> Dictionary` (`{}` when the side has no ability: enemies, the first run's F1, quick matches):
  `{id, name, text, operator_name, passive_name, passive_text, ready: bool, used: bool, needs_operator: bool, operator_on_board: bool, target: &"zone"|&"enemy"|&"none", targets: [{zone, target_uid}], code, reason}`.
  `reason` when not ready: "Deploy your Operator first" (code `operator_not_placed`), "Used this match" (`no_uses_left`), "Not in Deploy" ...
- Use it like a killstreak: `m.submit(side, RulesIntent.use_item(ability_id, zone, target_uid))`; `m.legal_targets(side, ability_id)`, `m.check_use(side, ability_id)`, `m.needs_unit_target(side, ability_id)` and `m.undo_last(side)` all work. It costs 0 Supply.
- `m.operator_kit_view(side := 0) -> Dictionary`: `{operator_id, operator_name, passive_name, passive_text, ability_name, ability_text, kit_on: bool}` (for the Operator card's "P" line even when the ability is used).
- `ITEM_USED` / `ITEM_REVEALED` events of an ability carry `ability: true` (log: "Kestrel: Dig In, column B").

### Boss
- `m.boss_view() -> Dictionary` (`{}` outside boss fights): `{id, rule, name, rule_name, text, active: bool (in effect this round), note: String ("From round 4")}`.
- Event `RulesEvent.BOSS_RULE_TRIGGERED {rule, side, amount?, uid?, zone?, what}` (Reinforcements Supply, Horde Shambler, Dug In pits at the start).
- Shamblers are ordinary units (`card_id = &"shambler"`, a token: no control, Pick / Flank ignore it). Prime's Mortar Pits are ordinary enemy Fields.

## 6. Boss (run level): `RunState.run.boss_view() -> Dictionary`
`{id: &"meridian"|&"prime"|&"choir", name, rule_id: &"reinforcements"|&"dug_in"|&"horde", rule_name, rule_text, crew, mode, mode_name, armor_bonus, deck: [card ids]}`. Shown on the map from step 1 and on the Loadout screen.

## 7. After a match / run end
- `RunProgress.record_result` summary gains `req_gained: int` and `elite: bool`; an elite win's Supply Drop has `elite_cache: true` on the offer (header "Elite Cache").
- `RunState.run.req`, `RunState.run.threat()`, `RunState.run.modifiers`.
- `RunState.unlocked(items)` after the run ends (profile updated in Settings.run_profile).

## 8. New RevealFlags ids
`run_map`, `requisition`, `elite_fight`, `operator_ability`, `terrain`, `boss_rule`, `event`, `rest`, `modifiers`, and one tip per Terrain `terrain_<id>`. Texts via `RevealFlags.text_of(flag)` (Terrain tips: title "New: Rooftops", text = its rule line). `RevealFlags.match_triggers(m)` now also returns `terrain`, `terrain_<id>`, `boss_rule`, `operator_ability`; `run_triggers(run)` returns `run_map`, `event`, `requisition` (shop), `rest`, `elite_fight`.

## 9. Card text changes (AB1)
- Breach and Clear: "2 damage to every enemy unit in a column." (no Close bonus). `scripts/ui/card_samples.gd` still has the old line (UI-owned file).
