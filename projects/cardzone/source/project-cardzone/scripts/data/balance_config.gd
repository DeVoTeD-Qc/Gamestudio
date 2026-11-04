# balance_config.gd
# Pattern adapted from CallingCard scripts/data/balance_config.gd (one Resource, id `balance`,
#   validate(v)); the fields are new: every tunable of spec §16.8 / prototype-scope.md §4.
# Purpose: Every CardZone tunable in one file, res://data/balance.tres (id `balance`).
#   TUNABLES lists each key with its default and allowed values, so validation, the hidden
#   dev panel (cz13) and the tests all read the same table. The rules engine (cz07) reads
#   values straight from the fields (CardDB.get_balance().hand_size).
# Dependencies: DataEnums, DataValidator.
# Author: Mechanics Developer Agent
class_name BalanceConfig
extends Resource

## The id the game looks up (CardDB.get_balance()).
const DEFAULT_ID: StringName = &"balance"

## Spec §16.8, one entry per key, in table order. Each entry has `default` and either
## `allowed` (the full list of allowed values) or `min`/`max` (inclusive). `list` entries
## (final_circle_hits) give the allowed size and the allowed range of each element.
## `rules` names the spec rules the key drives. Keep in step with the @export fields below.
const TUNABLES: Dictionary = {
	&"hand_size": {"default": 5, "allowed": [4, 5], "rules": "D4, R1-R3, §16.4"},
	&"health": {"default": 5, "min": 4, "max": 6, "rules": "D3, S4, R15"},
	&"packing_rule": {"default": DataEnums.PackingRule.HOLD_AND_STOW,
		"allowed": [DataEnums.PackingRule.HOLD_AND_STOW, DataEnums.PackingRule.RACK_SWAP], "rules": "R50, R51"},
	&"hold_limit": {"default": 2, "allowed": [1, 2], "rules": "R50, P3"},
	&"hold_looted": {"default": false, "allowed": [false, true], "rules": "R50"},
	&"adrenaline_mode": {"default": DataEnums.AdrenalineMode.MOVE_OR_SEARCH,
		"allowed": [DataEnums.AdrenalineMode.MOVE_OR_SEARCH, DataEnums.AdrenalineMode.MOVE_ONLY], "rules": "R6"},
	&"adrenaline_cap_per_turn": {"default": 0, "allowed": [0, 2], "rules": "R6 (0 = no cap)"},
	&"down_enabled": {"default": true, "allowed": [false, true], "rules": "D6, R23"},
	&"down_value": {"default": 1, "allowed": [1], "rules": "R23"},
	&"bounty_heal": {"default": 1, "allowed": [0, 1], "rules": "R37"},
	&"bounty_final_circle_extra": {"default": 1, "allowed": [0, 1], "rules": "R38"},
	&"bounty_holder_loses_cover": {"default": false, "allowed": [false, true], "rules": "R22"},
	&"final_circle_hits": {"default": [1, 2, 3], "list": true, "min_size": 1, "max_size": 14,
		"min": 0, "max": 9, "rules": "R43 (the last value repeats)"},
	&"zone_hard_end_card": {"default": 14, "min": 12, "max": 14, "rules": "S3, R44"},
	&"standard_pack": {"default": true, "allowed": [true], "rules": "S4, §16.4 (custom start is out of scope)"},
	&"held_cards_public": {"default": false, "allowed": [false, true], "rules": "P2, P15, P19"},
	&"hits_on_top_public": {"default": true, "allowed": [false, true], "rules": "P4, P9, P16"},
	&"loadout_count_public": {"default": true, "allowed": [false, true], "rules": "P6, P17"},
	&"supply_drop_cost": {"default": 4, "min": 3, "max": 4, "rules": "R10, §16.4a"},
	&"crate_cost": {"default": 1, "min": 0, "max": 1, "rules": "R10, R46"},
	&"crate_free_picks": {"default": 1, "min": 0, "max": 1, "rules": "R46"},
	&"supply_drop_ready_delay": {"default": 0, "allowed": [0, 1], "rules": "R10a"},
	&"ditch_per_turn": {"default": 1, "min": 0, "max": 10, "rules": "R19 (0 = unlimited)"},
	&"min_loadout": {"default": 6, "allowed": [6], "rules": "R19"},
	&"pile_size_outer": {"default": 3, "min": 2, "max": 4, "rules": "S3"},
	&"pile_size_core": {"default": 2, "min": 2, "max": 4, "rules": "S3"},
	&"ai_think_budget_ms": {"default": 300, "min": 100, "max": 1000, "rules": "AI only"},
}

## Balance switches under test (cz07b, first-player balance; not §16.8 keys). Same entry format
## as TUNABLES and the same API (is_allowed, set_tunable, allowed_values, default_value), but
## every switch is OFF by default and snapshot() lists a switch only when it is on, so the
## defaults keep the exact snapshot and tunables_hash they had before the switches existed
## (saves and playtest logs stay valid). The studio head picks which (if any) to turn on (cz-q2).
const SWITCHES: Dictionary = {
	## The second player (P2) starts with this many extra health (S4); healing (R15) may refill
	## P2 up to that larger stack. 0 = off.
	&"p2_start_health_bonus": {"default": 0, "allowed": [0, 1], "rules": "S4, R15 (P2 only)"},
	## Shots and Frags are illegal in round 1 (LoadoutRules.ERR_NO_SHOOTING_ROUND1). false = off.
	&"no_shooting_round1": {"default": false, "allowed": [false, true], "rules": "R21, R31 (round 1)"},
}

@export_group("Identity")
@export var id: StringName = DEFAULT_ID

@export_group("Hand and health")
## Non-Hit cards per draw (D4). 4 or 5. With 4, set supply_drop_cost to 3 (§16.4a).
@export_range(4, 5) var hand_size: int = 5
## Hit cards in each health stack at setup. 4-6.
@export_range(4, 6) var health: int = 5

@export_group("Pack (F1, F8)")
@export var packing_rule: DataEnums.PackingRule = DataEnums.PackingRule.HOLD_AND_STOW
## Cards you may hold on top at Pack. 1 or 2.
@export_range(1, 2) var hold_limit: int = 2
## May unused cards looted this turn be held (R50).
@export var hold_looted: bool = false

@export_group("Adrenaline and Down (F2, F3)")
@export var adrenaline_mode: DataEnums.AdrenalineMode = DataEnums.AdrenalineMode.MOVE_OR_SEARCH
## Adrenaline plays per turn: 0 = no cap, or 2.
@export_range(0, 2) var adrenaline_cap_per_turn: int = 0
@export var down_enabled: bool = true
## Damage subtracted per shot at a Down target. Only 1 is allowed.
@export_range(1, 1) var down_value: int = 1

@export_group("Bounty (F4, F5)")
@export_range(0, 1) var bounty_heal: int = 1
@export_range(0, 1) var bounty_final_circle_extra: int = 1
@export var bounty_holder_loses_cover: bool = false

@export_group("Zone (F6)")
## Hits per player on final circle I, II, III... (the last value repeats).
@export var final_circle_hits: PackedInt32Array = PackedInt32Array([1, 2, 3])
## The last Zone card (12-14). The match ends after the round it is flipped in.
@export_range(12, 14) var zone_hard_end_card: int = 14

@export_group("Start (F7)")
## Loadouts start in the Standard pack order. Only true is allowed.
@export var standard_pack: bool = true

@export_group("Information (Q3)")
@export var held_cards_public: bool = false
@export var hits_on_top_public: bool = true
@export var loadout_count_public: bool = true

@export_group("Loot")
## Search to loot a supply drop. 3-4 (default 4, §16.4a).
@export_range(3, 4) var supply_drop_cost: int = 4
## Search per crate card. 0-1.
@export_range(0, 1) var crate_cost: int = 1
## Free crate picks for the shooter who eliminated the owner. 0-1.
@export_range(0, 1) var crate_free_picks: int = 1
## 1 = a drop can't be looted in the round it lands (R10a). 0 or 1.
@export_range(0, 1) var supply_drop_ready_delay: int = 0
## Ditches per turn; 0 = unlimited.
@export_range(0, 10) var ditch_per_turn: int = 1
## Ditch never takes your non-Hit cards below this. Only 6 is allowed.
@export_range(6, 6) var min_loadout: int = 6
## Cards per loot pile in an outer area / in the Core (2-4).
@export_range(2, 4) var pile_size_outer: int = 3
@export_range(2, 4) var pile_size_core: int = 2

@export_group("AI")
## Veteran's search budget per decision, ms (100-1000).
@export_range(100, 1000) var ai_think_budget_ms: int = 300

@export_group("First-player switches (cz07b, off by default)")
## Extra starting health for P2 (0 or 1). See SWITCHES.
@export_range(0, 1) var p2_start_health_bonus: int = 0
## No shots or Frags in round 1. See SWITCHES.
@export var no_shooting_round1: bool = false


## Every tunable key in spec table order.
static func tunable_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(TUNABLES.keys())
	return keys


## Every balance switch key (SWITCHES), in table order.
static func switch_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(SWITCHES.keys())
	return keys


static func default_value(key: StringName) -> Variant:
	var spec: Dictionary = _spec(key)
	return spec["default"] if not spec.is_empty() else null


## The allowed values of a key as a list (ranges expanded). Empty for list keys.
static func allowed_values(key: StringName) -> Array:
	var spec: Dictionary = _spec(key)
	if spec.is_empty():
		return []
	if spec.has("allowed"):
		return (spec["allowed"] as Array).duplicate()
	if spec.get("list", false):
		return []
	return range(int(spec["min"]), int(spec["max"]) + 1)


## Allowed values as text for the dev panel and messages ("4, 5", "3..4", "list of 1..14, each 0..9").
static func allowed_text(key: StringName) -> String:
	var spec: Dictionary = _spec(key)
	if spec.is_empty():
		return "?"
	if spec.has("allowed"):
		return ", ".join((spec["allowed"] as Array).map(func(a: Variant) -> String: return str(a)))
	if spec.get("list", false):
		return "list of %d..%d, each %d..%d" % [spec["min_size"], spec["max_size"], spec["min"], spec["max"]]
	return "%d..%d" % [spec["min"], spec["max"]]


## True when value is allowed for key (types must match: ints for ints, bools for bools).
static func is_allowed(key: StringName, value: Variant) -> bool:
	var spec: Dictionary = _spec(key)
	if spec.is_empty():
		return false
	if spec.get("list", false):
		if not (value is PackedInt32Array or value is Array):
			return false
		if value.size() < int(spec["min_size"]) or value.size() > int(spec["max_size"]):
			return false
		for n: Variant in value:
			if typeof(n) != TYPE_INT or n < int(spec["min"]) or n > int(spec["max"]):
				return false
		return true
	if typeof(value) != typeof(spec["default"]):
		return false
	if spec.has("allowed"):
		return (spec["allowed"] as Array).has(value)
	return value >= int(spec["min"]) and value <= int(spec["max"])


## Sets a tunable at runtime (dev panel). Refuses unknown keys and values outside the allowed set.
func set_tunable(key: StringName, value: Variant) -> bool:
	if not is_allowed(key, value):
		return false
	if key == &"final_circle_hits":
		set(key, PackedInt32Array(value))
	else:
		set(key, value)
	emit_changed()
	return true


## Every tunable as {key: value} (for match_start logging and saves).
func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in TUNABLES.keys():
		var value: Variant = get(key)
		result[String(key)] = Array(value) if value is PackedInt32Array else value
	for key: StringName in SWITCHES.keys():
		if get(key) != SWITCHES[key]["default"]:
			result[String(key)] = get(key)
	return result


## The TUNABLES or SWITCHES entry for a key, or {}.
static func _spec(key: StringName) -> Dictionary:
	if TUNABLES.has(key):
		return TUNABLES[key]
	return SWITCHES.get(key, {})


## Starting (and maximum) health of a seat (0 = P1, 1 = P2): `health`, plus
## p2_start_health_bonus for P2 (S4, R15).
func start_health(seat: int) -> int:
	return health + (p2_start_health_bonus if seat == 1 else 0)


## Stable hash of the tunables (match_start.tunables_hash in the playtest log).
func tunables_hash() -> String:
	return JSON.stringify(snapshot(), "", true).md5_text().substr(0, 12)


## Hits each player takes on final circle step 1, 2, 3... (R43: the last value repeats).
func final_circle_hits_for(step: int) -> int:
	if step < 1 or final_circle_hits.is_empty():
		return 0
	return final_circle_hits[mini(step, final_circle_hits.size()) - 1]


## Loot pile size for an area tier (S3).
func pile_size_for(tier: DataEnums.AreaTier) -> int:
	return pile_size_core if tier == DataEnums.AreaTier.CORE else pile_size_outer


## Ditch limit, or -1 for unlimited (stored as 0).
func ditch_limit() -> int:
	return -1 if ditch_per_turn == 0 else ditch_per_turn


func validate(v: DataValidator) -> void:
	v.require_id(id)
	if id != DEFAULT_ID:
		v.invalid("id", "the balance config must have id '%s' (got '%s')" % [DEFAULT_ID, id])
	for key: StringName in TUNABLES.keys() + SWITCHES.keys():
		var value: Variant = get(key)
		if is_allowed(key, value):
			continue
		var shown: String = str(Array(value)) if value is PackedInt32Array else str(value)
		v.out_of_range(String(key), "%s is not allowed (allowed: %s; spec §16.8)" % [shown, allowed_text(key)])
	# Combination the Sr Designer flagged (§16.4a hand-4 caveat): a warning, not an error.
	if hand_size == 4 and supply_drop_cost == 4:
		v.warn(DataValidator.OUT_OF_RANGE, "supply_drop_cost",
				"hand_size 4 with supply_drop_cost 4 makes the zone decide 38% of duels; use 3 with hand 4 (spec §16.4a)")
