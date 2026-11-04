# dev_panel_overrides.gd
# Purpose: The hidden dev panel's balance overrides (cz13, spec §16.8). A dev panel change is
#   stored here (SetupPrefs [dev]) and applied only when a NEW match is built
#   (SetupLaunch: RulesData.with_balance(overrides())). A saved match keeps the balance it was
#   started with (MatchStore saves the snapshot), so Continue is never affected.
#   Only values BalanceConfig allows are accepted (BalanceConfig.is_allowed / allowed_values).
#   Coupling (spec §16.4a): hand_size 4 also sets supply_drop_cost 3; going back to hand_size 5
#   puts a coupled supply_drop_cost 3 back to the shipped value.
#   An override equal to the shipped value (data/balance.tres via CardDB) is dropped, so
#   is_active() is true exactly when a new match would differ from the shipped rules.
# Dependencies: BalanceConfig, DataEnums, setup_prefs.gd, CardDB (optional, for the shipped values).
# Author: UI/UX Agent (cz13)
extends RefCounted

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const SECTION: String = "dev"

## Panel rows in order: [group label, [keys]]. hand_size and F1-F8, the visibility switches,
## the two supply-drop switches (§16.4a couples supply_drop_cost to hand_size), and the two
## cz07b balance switches (BalanceConfig.SWITCHES).
const GROUPS: Array = [
	["HAND", [&"hand_size"]],
	["F1 PACKING", [&"packing_rule", &"hold_limit"]],
	["F2 ADRENALINE", [&"adrenaline_mode", &"adrenaline_cap_per_turn"]],
	["F3 DOWN", [&"down_enabled"]],
	["F4 BOUNTY", [&"bounty_heal", &"bounty_final_circle_extra"]],
	["F5 BOUNTY COVER", [&"bounty_holder_loses_cover"]],
	["F6 ZONE", [&"final_circle_hits", &"zone_hard_end_card"]],
	["F7 START", [&"standard_pack"]],
	["F8 HOLD LOOTED", [&"hold_looted"]],
	["VISIBILITY", [&"held_cards_public", &"hits_on_top_public", &"loadout_count_public"]],
	["SUPPLY DROPS", [&"supply_drop_cost", &"supply_drop_ready_delay"]],
	# cz19b BUG-03: the cz07b first-player balance switches (BalanceConfig.SWITCHES, off by default),
	# so the playtest can try them without a rebuild (decision cz-q2).
	["FIRST-PLAYER SWITCHES (CZ07B)", [&"no_shooting_round1", &"p2_start_health_bonus"]],
]

## Row labels that read better than the key ("no_shooting_round1" -> "No shooting in round 1").
const KEY_TEXT: Dictionary = {
	&"no_shooting_round1": "No shooting in round 1",
	&"p2_start_health_bonus": "P2 extra start health",
}

## final_circle_hits is a list tunable (any list): the panel offers these presets, all allowed.
const FINAL_CIRCLE_PRESETS: Array = [[1, 2, 3], [1, 1, 1], [2, 2, 2], [1, 2]]


## Every key the panel shows, in order.
static func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: Array in GROUPS:
		for k: StringName in g[1]:
			out.append(k)
	return out


## The value a new match uses with no override (data/balance.tres, else the spec default).
static func shipped(key: StringName) -> Variant:
	var db: Node = _card_db()
	if db != null:
		var v: Variant = (db.call("get_balance") as BalanceConfig).get(key)
		return Array(v) if v is PackedInt32Array else v
	return BalanceConfig.default_value(key)


## The value the next new match will use.
static func value(key: StringName) -> Variant:
	var o: Dictionary = overrides()
	return o[key] if o.has(key) else shipped(key)


## Valid overrides only: {StringName key: value}, nothing equal to the shipped value.
static func overrides() -> Dictionary:
	var out: Dictionary = {}
	for k: String in SetupPrefs.section(SECTION).keys():
		var key: StringName = StringName(k)
		var v: Variant = SetupPrefs.get_value(SECTION, k)
		if BalanceConfig.is_allowed(key, v) and not _same(v, shipped(key)):
			out[key] = v
	return out


static func is_active() -> bool:
	return not overrides().is_empty()


## The values the panel offers for a key (BalanceConfig's allowed values; presets for the list).
static func options(key: StringName) -> Array:
	if key == &"final_circle_hits":
		return FINAL_CIRCLE_PRESETS.filter(func(p: Array) -> bool: return BalanceConfig.is_allowed(key, p))
	return BalanceConfig.allowed_values(key)


## Sets a tunable for new matches. False (nothing stored) when BalanceConfig does not allow it.
static func set_value(key: StringName, v: Variant) -> bool:
	if not BalanceConfig.is_allowed(key, v):
		return false
	_store(key, v)
	if key == &"hand_size":
		if int(v) == 4:
			_store(&"supply_drop_cost", 3)  # spec §16.4a: hand 4 plays with drop cost 3
		elif int(value(&"supply_drop_cost")) == 3:
			_store(&"supply_drop_cost", shipped(&"supply_drop_cost"))
	return true


static func reset() -> void:
	SetupPrefs.clear_section(SECTION)


## Short text for a value ("4", "ON", "HOLD & STOW", "1·2·3").
static func value_text(key: StringName, v: Variant) -> String:
	match key:
		&"packing_rule":
			return "RACK SWAP" if int(v) == DataEnums.PackingRule.RACK_SWAP else "HOLD & STOW"
		&"adrenaline_mode":
			return "MOVE ONLY" if int(v) == DataEnums.AdrenalineMode.MOVE_ONLY else "MOVE OR SEARCH"
		&"adrenaline_cap_per_turn":
			return "NO CAP" if int(v) == 0 else str(v)
		&"p2_start_health_bonus":
			return "OFF" if int(v) == 0 else "+%d" % int(v)
		&"final_circle_hits":
			return "·".join((v as Array).map(func(n: Variant) -> String: return str(n)))
	if v is bool:
		return "ON" if v else "OFF"
	return str(v)


## Row label for a key ("hand_size" -> "Hand size").
static func key_text(key: StringName) -> String:
	if KEY_TEXT.has(key):
		return KEY_TEXT[key]
	return String(key).replace("_", " ").capitalize()


## One line for the Title / Setup tag: "DEV SETTINGS ACTIVE · hand size 4, supply drop cost 3".
static func summary() -> String:
	var parts: PackedStringArray = []
	var o: Dictionary = overrides()
	for k: StringName in keys():
		if o.has(k):
			parts.append("%s %s" % [key_text(k).to_lower(), value_text(k, o[k])])
	return "DEV SETTINGS ACTIVE" + (" · " + ", ".join(parts) if not parts.is_empty() else "")


static func _store(key: StringName, v: Variant) -> void:
	var cfg_key: String = String(key)
	if _same(v, shipped(key)):
		if SetupPrefs.get_value(SECTION, cfg_key) != null:
			var all: Dictionary = SetupPrefs.section(SECTION)
			all.erase(cfg_key)
			SetupPrefs.clear_section(SECTION)
			for k: String in all.keys():
				SetupPrefs.set_value(SECTION, k, all[k])
		return
	SetupPrefs.set_value(SECTION, cfg_key, (v as Array).duplicate() if v is Array else v)


static func _same(a: Variant, b: Variant) -> bool:
	if a is Array or a is PackedInt32Array or b is Array or b is PackedInt32Array:
		return (a is Array or a is PackedInt32Array) and (b is Array or b is PackedInt32Array) and Array(a) == Array(b)
	return typeof(a) == typeof(b) and a == b


static func _card_db() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var db: Node = loop.root.get_node_or_null("CardDB")
	return db if db != null and db.has_method("get_balance") else null
