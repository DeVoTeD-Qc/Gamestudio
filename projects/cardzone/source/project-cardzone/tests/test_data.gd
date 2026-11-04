# test_data.gd
# Adapted from CallingCard tests/test_data.gd (user:// case folders, fresh CardDB per case).
# Purpose: cz05 data format tests. The shipped samples are valid and match the spec; a complete
#   valid data set (built in code from spec §3, §8, §10, §11, §16.8 and saved as .tres under
#   user://) loads with no errors and no warnings; each kind of bad data is rejected with the
#   right issue code in CardDB's validation report. Uses a fresh CardDB instance per case, so
#   the live autoload is never disturbed.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const CardDBScript: GDScript = preload("res://autoload/card_db.gd")
const TEST_ROOT: String = "user://test_data"
## Save order: referenced files before the files that reference them.
const SAVE_ORDER: Array[String] = ["cards/", "areas/", "zone/", "packs/", "balance"]
const T: Dictionary = DataEnums.CardType
const R: Dictionary = DataEnums.Rarity
const RING: Array[StringName] = [&"docks", &"farmstead", &"quarry", &"radio_hill", &"motel", &"rail_yard"]

## Spec §16.8 defaults, typed out independently of BalanceConfig.TUNABLES.
const SPEC_DEFAULTS: Dictionary = {
	"hand_size": 5, "health": 5, "packing_rule": 0, "hold_limit": 2, "hold_looted": false,
	"adrenaline_mode": 0, "adrenaline_cap_per_turn": 0, "down_enabled": true, "down_value": 1,
	"bounty_heal": 1, "bounty_final_circle_extra": 1, "bounty_holder_loses_cover": false,
	"final_circle_hits": [1, 2, 3], "zone_hard_end_card": 14, "standard_pack": true,
	"held_cards_public": false, "hits_on_top_public": true, "loadout_count_public": true,
	"supply_drop_cost": 4, "crate_cost": 1, "crate_free_picks": 1, "supply_drop_ready_delay": 0,
	"ditch_per_turn": 1, "min_loadout": 6, "pile_size_outer": 3, "pile_size_core": 2,
	"ai_think_budget_ms": 300,
}

var _case_counter: int = 0

# --- Live project data -----------------------------------------------------------

func test_project_data_is_valid() -> void:
	var db: Node = tree.root.get_node_or_null("CardDB")
	assert_not_null(db, "CardDB autoload")
	if db == null:
		return
	assert_true(db.get_index() > tree.root.get_node("Settings").get_index(), "CardDB after Settings")
	assert_true(db.get_index() < tree.root.get_node("SceneRouter").get_index(), "CardDB before SceneRouter")
	assert_true(db.is_valid(), "res://data has errors:\n" + "\n".join(db.get_errors()))
	var report: Dictionary = db.get_report()
	assert_eq(report["counts"]["balance"], 1, "one balance config")
	assert_eq(report["counts"]["areas"], 7, "the whole map")
	assert_true(report["counts"]["cards"] >= 6, "sample cards loaded")
	assert_true(report["counts"]["zone_cards"] >= 3, "sample Zone cards loaded")
	assert_eq(report["counts"]["packs"], 1, "one Standard pack")


func test_sample_cards_match_spec() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var p9: CardData = db.get_card(&"p9_sidearm")
	assert_true(p9 != null and p9.is_weapon() and p9.is_starter(), "P-9 is a starter weapon")
	if p9 != null:
		assert_eq([p9.code, p9.dmg, p9.rng, p9.cost], ["CZ-001", 1, 0, 0], "P-9 DMG 1 RNG 0")
	var duck: CardData = db.get_card(&"duck")
	assert_true(duck != null and duck.brace == 1 and duck.search == 1, "Duck: Search 1, Brace 1")
	var shotgun: CardData = db.get_card(&"pump_shotgun")
	assert_not_null(shotgun, "pump_shotgun sample")
	if shotgun != null:
		assert_eq([shotgun.dmg, shotgun.rng, shotgun.cost, shotgun.rarity_letter()], [3, 0, 4, "U"], "Pump Shotgun 3/0, U4")
	var frag: CardData = db.get_card(&"frag_grenade")
	assert_true(frag != null and frag.blast_dmg == 2 and frag.blast_rng == 1 and frag.ignores_cover
			and frag.spent == DataEnums.SpentMode.ON_PLAY, "Frag: 2-damage blast, range 1, Spent")
	var smoke: CardData = db.get_card(&"smoke_grenade")
	assert_true(smoke != null and smoke.spent == DataEnums.SpentMode.ON_BRACE and smoke.brace == 2, "Smoke: Spent on Brace")
	var dot: CardData = db.get_card(&"red_dot_sight")
	assert_true(dot != null and dot.is_attachment() and dot.attach_dmg == 1, "Red-dot +1 DMG")
	var lmg: CardData = db.get_card(&"twin_drum_lmg")
	assert_true(lmg != null and lmg.supply_drop and lmg.fires_per_turn == 2 and lmg.cost == 0, "LMG is a drop that fires twice")
	assert_eq(db.hit_card(), db.get_card(&"hit"), "Hit card lookup")
	assert_eq(db.bounty_card(), db.get_card(&"bounty"), "Bounty lookup")
	assert_eq(db.all_cards()[0].id, &"p9_sidearm", "printed order starts at CZ-001")
	assert_eq(db.supply_drop_cards().map(func(c: CardData) -> StringName: return c.id), [&"twin_drum_lmg"], "drop cards")
	if shotgun != null:
		var d: Dictionary = shotgun.to_dict()
		assert_eq([d["type"], d["rarity"], d["dmg"], d["art_key"]], [&"weapon", "U", 3, &"pump_shotgun"], "card dict")


func test_sample_map_matches_spec() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var ids: Array = db.all_areas().map(func(a: AreaData) -> StringName: return a.id)
	assert_eq(ids, [&"docks", &"farmstead", &"quarry", &"radio_hill", &"motel", &"rail_yard", &"old_town"], "ring order, Core last")
	var covers: Array = db.all_areas().map(func(a: AreaData) -> int: return a.cover)
	assert_eq(covers, [0, 1, 1, 0, 1, 0, 1], "Cover per area (spec §3)")
	assert_eq(db.core_area().id, &"old_town", "Old Town is the Core")
	assert_eq(db.area_by_number(4).id, &"radio_hill", "area 4")
	assert_eq(db.neighbours(&"old_town").size(), 6, "Core touches every outer area")
	assert_eq(db.neighbours(&"docks").map(func(a: AreaData) -> StringName: return a.id), [&"farmstead", &"rail_yard", &"old_town"], "Docks neighbours")
	assert_eq([db.distance(&"docks", &"docks"), db.distance(&"docks", &"farmstead"), db.distance(&"docks", &"old_town"),
			db.distance(&"docks", &"quarry"), db.distance(&"docks", &"nowhere")], [0, 1, 1, 2, -1], "distances")
	assert_eq(db.area_with_pile(&"pump_shotgun").id, &"quarry", "Pump Shotgun pile in the Quarry")
	var b: BalanceConfig = db.get_balance()
	assert_eq([db.get_area(&"quarry").pile_size(b), db.core_area().pile_size(b)], [3, 2], "2-player pile sizes")
	assert_eq(db.core_area().label(), "C", "Core label")


func test_sample_zone_and_pack() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var z3: ZoneCardData = db.get_zone_card(3)
	assert_true(z3 != null and z3.kind() == DataEnums.ZoneKind.DROP, "card 3 is a drop")
	if z3 != null:
		assert_eq([z3.route_text(DataEnums.Route.A), z3.route_text(DataEnums.Route.B), z3.route_text(DataEnums.Route.C)],
				["drop Quarry", "drop Docks", "drop Motel"], "card 3 routes")
	var z4: ZoneCardData = db.get_zone_card(4)
	assert_true(z4 != null and z4.kind() == DataEnums.ZoneKind.GAS, "card 4 is gas")
	if z4 != null:
		assert_eq([z4.close_a.id, z4.close_b.id, z4.close_c.id], [&"docks", &"radio_hill", &"farmstead"], "card 4 routes")
	assert_eq(db.get_zone_card(1).kind(), DataEnums.ZoneKind.CALM, "card 1 calm")
	var pack: StartPackData = db.get_start_pack(5)
	assert_not_null(pack, "hand-5 pack")
	assert_eq(db.get_start_pack(4), pack, "the same pack serves hand 4 (spec §16.4)")
	assert_eq(db.get_start_pack(), pack, "pack for the balance hand size")
	if pack != null:
		assert_eq(pack.card_ids(), [&"scavenge", &"scavenge", &"scavenge", &"duck", &"dash", &"dash", &"p9_sidearm",
				&"scavenge", &"duck", &"dash"] as Array[StringName], "Standard pack order, top first")
		assert_eq([pack.copies_of(&"scavenge"), pack.copies_of(&"dash"), pack.copies_of(&"duck"), pack.copies_of(&"p9_sidearm")],
				[4, 3, 2, 1], "copies (spec §10)")
		assert_eq(pack.opening_hand(4).map(func(c: CardData) -> StringName: return c.id),
				[&"scavenge", &"scavenge", &"scavenge", &"duck"], "hand-4 turn 1")


func test_balance_defaults_match_spec() -> void:
	var live: BalanceConfig = tree.root.get_node("CardDB").get_balance()
	var fresh: BalanceConfig = BalanceConfig.new()
	assert_eq(BalanceConfig.tunable_keys().size(), SPEC_DEFAULTS.size(), "one TUNABLES entry per §16.8 key")
	var props: Array = fresh.get_property_list().map(func(p: Dictionary) -> String: return p["name"])
	for key: String in SPEC_DEFAULTS.keys():
		assert_true(BalanceConfig.TUNABLES.has(StringName(key)), "TUNABLES has %s" % key)
		assert_true(props.has(key), "exported field %s" % key)
		var expected: Variant = SPEC_DEFAULTS[key]
		for b: BalanceConfig in [live, fresh]:
			var value: Variant = b.get(key)
			if value is PackedInt32Array:
				value = Array(value)
			assert_eq(value, expected, "%s default (%s)" % [key, "balance.tres" if b == live else "new()"])
		var table_default: Variant = BalanceConfig.default_value(StringName(key))
		assert_eq(table_default, expected, "%s default in TUNABLES" % key)
		assert_true(BalanceConfig.is_allowed(StringName(key), fresh.get(key)), "%s default is allowed" % key)


func test_balance_allowed_values() -> void:
	assert_eq(BalanceConfig.allowed_values(&"hand_size"), [4, 5], "hand 4, 5")
	assert_eq(BalanceConfig.allowed_values(&"health"), [4, 5, 6], "health 4-6")
	assert_eq(BalanceConfig.allowed_values(&"standard_pack"), [true], "standard pack only")
	assert_eq(BalanceConfig.allowed_text(&"supply_drop_cost"), "3..4", "drop cost text")
	assert_false(BalanceConfig.is_allowed(&"hand_size", 6), "hand 6")
	assert_false(BalanceConfig.is_allowed(&"hold_looted", 1), "int for a bool key")
	assert_false(BalanceConfig.is_allowed(&"final_circle_hits", PackedInt32Array()), "empty final circle")
	assert_true(BalanceConfig.is_allowed(&"final_circle_hits", [2, 2]), "any list")
	assert_false(BalanceConfig.is_allowed(&"no_such_key", 1), "unknown key")
	var b: BalanceConfig = BalanceConfig.new()
	var hash_before: String = b.tunables_hash()
	assert_false(b.set_tunable(&"supply_drop_cost", 5), "dev panel refuses 5")
	assert_eq(b.supply_drop_cost, 4, "value unchanged")
	assert_true(b.set_tunable(&"supply_drop_cost", 3), "dev panel sets 3")
	assert_true(b.set_tunable(&"final_circle_hits", [1, 1]), "dev panel sets a list")
	assert_eq(b.final_circle_hits, PackedInt32Array([1, 1]), "list stored packed")
	assert_true(b.tunables_hash() != hash_before, "hash follows the tunables")
	b.final_circle_hits = PackedInt32Array([1, 2, 3])
	assert_eq([b.final_circle_hits_for(0), b.final_circle_hits_for(1), b.final_circle_hits_for(3), b.final_circle_hits_for(5)],
			[0, 1, 3, 3], "final circle hits, last value repeats (R43)")
	assert_eq(b.ditch_limit(), 1, "ditch 1")
	b.ditch_per_turn = 0
	assert_eq(b.ditch_limit(), -1, "0 = unlimited")
	assert_eq([b.pile_size_for(DataEnums.AreaTier.OUTER), b.pile_size_for(DataEnums.AreaTier.CORE)], [3, 2], "pile sizes")
	assert_eq(b.snapshot().size(), SPEC_DEFAULTS.size(), "snapshot has every key")

# --- Valid set -----------------------------------------------------------------------

func test_valid_set_loads_and_indexes() -> void:
	var db: Node = _load_case(_valid_set())
	assert_true(db.is_valid(), "valid set has errors:\n" + "\n".join(db.get_errors()))
	assert_eq(db.get_warnings().size(), 0, "valid set has no warnings:\n" + "\n".join(db.get_warnings()))
	assert_eq(db.get_report()["counts"], {"cards": 24, "areas": 7, "zone_cards": 14, "packs": 1, "balance": 1}, "counts")
	assert_eq(db.zone_deck().size(), 14, "14-card deck")
	assert_eq(db.get_zone_card(14).final_circle_step, 3, "final circle III")
	assert_eq(db.get_zone_card(6).kind(), DataEnums.ZoneKind.GAS_AND_DROP, "card 6 gas + drop")
	assert_eq(db.get_zone_card(6).route_text(DataEnums.Route.B), "close Quarry · drop Rail Yard", "card 6 route B")
	assert_eq(db.get_card(&"longshot_50"), db.get_zone_card(8).drop_card, "drop reference resolves")
	assert_eq(db.distance(&"farmstead", &"motel"), 2, "across the Core")
	assert_eq(db.get_resource(&"standard_pack"), db.get_start_pack(5), "lookup by id")
	db.free()


func test_hard_end_shortens_the_deck() -> void:
	var data: Dictionary = _valid_set()
	data["balance"].zone_hard_end_card = 12
	var db: Node = _load_case(data)
	assert_true(db.is_valid(), "hard end 12 is legal:\n" + "\n".join(db.get_errors()))
	assert_eq(db.zone_deck().size(), 12, "deck stops at card 12")
	assert_eq(db.all_zone_cards().size(), 14, "the cards past the end still load")
	db.free()

# --- Bad data: each kind must be rejected ----------------------------------------------

func test_rejects_weapon_without_dmg_or_rng() -> void:
	var data: Dictionary = _valid_set()
	data["cards/pump_shotgun"].dmg = 0
	data["cards/hunting_rifle"].rng = CardData.NO_RANGE
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "weapon without DMG / RNG accepted")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "pump_shotgun", "dmg"), "no DMG")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "hunting_rifle", "rng"), "no RNG")
	assert_eq(db.get_errors().size(), 2, "only those two:\n" + "\n".join(db.get_errors()))
	db.free()


func test_rejects_bad_card_fields() -> void:
	var data: Dictionary = _valid_set()
	var c: Callable = func(id: String) -> CardData: return data["cards/" + id]
	c.call("long_scope").attach_rng = 0                  # attachment with no bonus
	c.call("crowbar").dmg = 2                            # item with DMG
	c.call("dash").rng = 1                               # RNG on a non-weapon
	c.call("scavenge").cost = 2                          # starter with a cost
	c.call("bandage").cost = 0                           # loot pile card with no cost
	c.call("hit").rarity = DataEnums.Rarity.COMMON       # Hit with a rarity chip
	c.call("plate_vest").brace = 0                       # Spent on Brace (set below) with no Brace
	c.call("plate_vest").spent = DataEnums.SpentMode.ON_BRACE
	c.call("frag_grenade").blast_rng = CardData.NO_RANGE # blast with no range
	c.call("duck").code = "CZ-4"                         # bad printed code
	c.call("medkit").attach_dmg = 1                      # attach bonus on an item
	c.call("suppressor").move = 1                        # attachment with a play effect
	c.call("scrap_smg").type = 9 as DataEnums.CardType   # not an enum value
	c.call("heavy_plate").cost = 3                       # supply drop with a pile cost
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "bad card fields accepted")
	var M: String = DataValidator.MISSING_FIELD
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(M, "long_scope", "attach_dmg"), "attachment without a bonus")
	assert_true(db.has_issue(V, "crowbar", "dmg"), "item with DMG")
	assert_true(db.has_issue(V, "dash", "rng"), "RNG on an item")
	assert_true(db.has_issue(V, "scavenge", "cost"), "starter cost")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "bandage", "cost"), "loot cost 0")
	assert_true(db.has_issue(V, "hit", "rarity"), "Hit rarity")
	assert_true(db.has_issue(V, "plate_vest", "spent"), "ON_BRACE without Brace")
	assert_true(db.has_issue(M, "frag_grenade", "blast_rng"), "blast without range")
	assert_true(db.has_issue(V, "duck", "code"), "bad code")
	assert_true(db.has_issue(V, "medkit", "attach_dmg"), "attach bonus on an item")
	assert_true(db.has_issue(V, "suppressor", "move"), "attachment with a play effect")
	assert_true(db.has_issue(V, "scrap_smg", "type"), "bad enum")
	assert_true(db.has_issue(V, "heavy_plate", "cost"), "drop with a cost")
	db.free()


func test_rejects_route_closing_an_area_twice() -> void:
	var data: Dictionary = _valid_set()
	data["zone/zone_09"].close_b = data["areas/quarry"]   # route B already closed the Quarry on card 6
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "double close accepted")
	assert_true(db.has_issue(DataValidator.ROUTE_RULE, "zone_09", "close_b"), "route B closes the Quarry twice")
	assert_eq(db.get_errors().size(), 1, "only that error:\n" + "\n".join(db.get_errors()))
	assert_true(db.get_errors()[0].contains("zone_06"), "message names the first close")
	db.free()


func test_rejects_other_route_errors() -> void:
	var data: Dictionary = _valid_set()
	var z: Callable = func(n: int) -> ZoneCardData: return data["zone/zone_%02d" % n]
	z.call(10).drop_a = data["areas/docks"]            # route A closed the Docks on card 4
	z.call(5).close_a = data["areas/motel"]            # gas on route A only
	z.call(7).close_c = data["areas/old_town"]         # the Core never closes
	z.call(3).drop_c = null                            # a drop with no landing area on route C
	z.call(8).drop_card = data["cards/assault_rifle"]  # not a supply-drop card
	z.call(13).final_circle_step = 3                   # steps 1, 3, 3
	z.call(2).drop_a = data["areas/docks"]             # landing area with no drop card
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "route errors accepted")
	var RR: String = DataValidator.ROUTE_RULE
	assert_true(db.has_issue(RR, "zone_10", "drop_a"), "drop into gas")
	assert_true(db.has_issue(RR, "zone_05", "close_b"), "gas on one route only")
	assert_true(db.has_issue(RR, "zone_07", "close_c"), "Core closes")
	assert_true(db.has_issue(RR, "zone_03", "drop_c"), "drop without a landing area")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "zone_08", "drop_card"), "drop card that isn't a drop")
	assert_true(db.has_issue(RR, "zone_13", "final_circle_step"), "final circle out of order")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "zone_02", "drop_card"), "landing area without a drop card")
	db.free()


func test_rejects_zone_deck_order() -> void:
	var data: Dictionary = _valid_set()
	data["zone/zone_05"].number = 4                    # two card 4s
	data["zone/zone_14"].number = 16                   # gap after 13
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "deck order errors accepted")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "zone_05", "number"), "duplicate number")
	assert_true(db.has_issue(DataValidator.ROUTE_RULE, "zone_14", "number"), "gap in numbers")
	db.free()
	# Final circle must end the deck.
	data = _valid_set()
	data["zone/zone_14"].final_circle_step = 0
	data["zone/zone_14"].display_name = "Calm"
	db = _load_case(data)
	assert_true(db.has_issue(DataValidator.ROUTE_RULE, "zone_14", "number"), "card after the final circle")
	db.free()


func test_rejects_tunables_out_of_range() -> void:
	var data: Dictionary = _valid_set()
	var b: BalanceConfig = data["balance"]
	var bad: Dictionary = {
		"hand_size": 6, "health": 7, "hold_limit": 3, "adrenaline_cap_per_turn": 1, "down_value": 2,
		"bounty_heal": 2, "zone_hard_end_card": 15, "standard_pack": false, "supply_drop_cost": 2,
		"crate_cost": 2, "crate_free_picks": 2, "supply_drop_ready_delay": 2, "ditch_per_turn": 11,
		"min_loadout": 5, "pile_size_outer": 5, "pile_size_core": 1, "ai_think_budget_ms": 50,
		"final_circle_hits": PackedInt32Array(), "packing_rule": 7, "adrenaline_mode": 3,
		"bounty_final_circle_extra": 2,
	}
	for key: String in bad.keys():
		b.set(key, bad[key])
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "tunables out of range accepted")
	for key: String in bad.keys():
		assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "balance", key), "%s out of range" % key)
	var balance_errors: int = db.get_issues().filter(func(i: Dictionary) -> bool:
		return i["id"] == "balance" and i["severity"] == "error").size()
	assert_eq(balance_errors, bad.size(), "one error per bad tunable")
	db.free()
	# A list element out of range.
	data = _valid_set()
	data["balance"].final_circle_hits = PackedInt32Array([1, 12])
	db = _load_case(data)
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "balance", "final_circle_hits"), "final circle 12 Hits")
	db.free()


func test_rejects_broken_adjacency() -> void:
	var data: Dictionary = _valid_set()
	var a: Callable = func(id: String) -> AreaData: return data["areas/" + id]
	a.call("farmstead").adjacent.erase(&"docks")              # Docks lists Farmstead, not back
	a.call("motel").adjacent.append(&"no_such_area")          # unknown id
	a.call("quarry").adjacent.append(&"quarry")               # itself
	a.call("radio_hill").adjacent.append(&"pump_shotgun")     # a card, not an area
	a.call("rail_yard").adjacent.append(&"docks")             # listed twice
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "broken adjacency accepted")
	assert_true(db.has_issue(DataValidator.MAP_RULE, "docks", "adjacent"), "not mutual")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "motel", "adjacent"), "unknown area")
	assert_true(db.has_issue(DataValidator.MAP_RULE, "quarry", "adjacent"), "self")
	assert_true(db.has_issue(DataValidator.WRONG_TYPE, "radio_hill", "adjacent"), "card id as a neighbour")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "rail_yard", "adjacent"), "repeat")
	db.free()


func test_rejects_disconnected_or_too_wide_map() -> void:
	# Too wide: only the Docks touch the Core, so the Core -> Radio Hill is 4 steps.
	var data: Dictionary = _valid_set()
	for id: StringName in RING:
		if id != &"docks":
			data["areas/" + String(id)].adjacent.erase(&"old_town")
	data["areas/old_town"].adjacent.assign([&"docks"])
	var db: Node = _load_case(data)
	assert_true(db.has_issue(DataValidator.MAP_RULE, "", "adjacent"), "4 steps > RNG 2")
	assert_true("\n".join(db.get_errors()).contains("4 steps apart"), "message names the distance:\n" + "\n".join(db.get_errors()))
	db.free()
	# Disconnected: the Core has no neighbours at all.
	data = _valid_set()
	for id: StringName in RING:
		data["areas/" + String(id)].adjacent.erase(&"old_town")
	data["areas/old_town"].adjacent.clear()
	db = _load_case(data)
	assert_true(db.has_issue(DataValidator.MAP_RULE, "old_town", "adjacent"), "Core unreachable")
	assert_eq(db.distance(&"docks", &"old_town"), -1, "no path")
	db.free()


func test_rejects_bad_map_shape() -> void:
	var data: Dictionary = _valid_set()
	data["areas/motel"].tier = DataEnums.AreaTier.CORE       # a second Core (number 5, not 0)
	data["areas/quarry"].number = 2                          # same as Farmstead
	data["areas/radio_hill"].cover = 3                       # Cover above 2
	var extra: AreaData = _area(&"bunker", 7, DataEnums.AreaTier.OUTER, 0, [&"old_town"])
	data["areas/bunker"] = extra                             # an 8th area
	data["areas/old_town"].adjacent.append(&"bunker")
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "bad map accepted")
	assert_true(db.has_issue(DataValidator.MAP_RULE, "", "tier"), "two Cores")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "motel", "number"), "Core numbered 5")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "", "number"), "map number used twice")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "radio_hill", "cover"), "Cover 3")
	assert_true(db.has_issue(DataValidator.MAP_RULE, "", "areas"), "8 areas")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "bunker", "number"), "area number 7")
	db.free()


func test_rejects_bad_piles() -> void:
	var data: Dictionary = _valid_set()
	data["areas/docks"].piles.append(data["cards/scavenge"])        # a starter in a pile
	data["areas/motel"].piles.append(data["cards/twin_drum_lmg"])   # a drop in a pile
	data["areas/farmstead"].piles.append(data["cards/crowbar"])     # already in the Rail Yard
	data["areas/quarry"].piles.append(data["cards/pump_shotgun"])   # twice in one area
	data["areas/radio_hill"].piles.append(data["cards/suppressor"]) # a Rare outside the Core: warning
	data["areas/old_town"].piles.erase(data["cards/suppressor"])
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "bad piles accepted")
	var V: String = DataValidator.INVALID_VALUE
	assert_true(db.has_issue(V, "docks", "piles[1]"), "starter in a pile")
	assert_true(db.has_issue(V, "motel", "piles[2]"), "drop in a pile")
	assert_true(db.has_issue(V, "rail_yard", "piles[0]"), "card in two areas (reported on the later area)")
	assert_true(db.has_issue(V, "quarry", "piles"), "same pile twice")
	assert_false(db.has_issue(V, "radio_hill"), "a Rare outside the Core is not an error")
	assert_true(db.has_issue(V, "radio_hill", "piles[2]", true), "but it is a warning")
	db.free()


func test_rejects_duplicates() -> void:
	var data: Dictionary = _valid_set()
	data["cards/pump_shotgun_copy"] = data["cards/pump_shotgun"].duplicate()  # same id
	data["cards/crowbar"].code = "CZ-014"                                    # same code as the shotgun
	var second_hit: CardData = data["cards/hit"].duplicate()
	second_hit.id = &"hit_two"
	second_hit.code = "CZ-099"
	data["cards/hit_two"] = second_hit                                       # two Hit cards
	data["zone/zone_02"].number = 1                                          # two card 1s
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "duplicates accepted")
	assert_true(db.has_issue(DataValidator.DUPLICATE_ID, "pump_shotgun"), "duplicate id")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "", "code"), "duplicate code")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "hit_two", "type"), "second Hit card")
	assert_true(db.has_issue(DataValidator.INVALID_VALUE, "", "number"), "duplicate Zone number")
	db.free()


func test_rejects_bad_start_packs() -> void:
	var data: Dictionary = _valid_set()
	var pack: StartPackData = data["packs/standard_pack"]
	pack.cards.pop_back()                              # 9 cards
	pack.cards[0] = data["cards/crowbar"]              # not a starter
	pack.hand_sizes = PackedInt32Array([5, 6])         # hand 6 isn't allowed; nothing serves hand 4
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "bad pack accepted")
	var P: String = DataValidator.PACK_RULE
	assert_true(db.has_issue(P, "standard_pack", "cards"), "9 cards")
	assert_true(db.has_issue(P, "standard_pack", "cards[0]"), "Crowbar is not a starter")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "standard_pack", "hand_sizes[1]"), "hand 6")
	assert_true(db.has_issue(P, "", "hand_sizes"), "no pack for hand 4")
	db.free()
	# Two packs for the same hand size.
	data = _valid_set()
	var second: StartPackData = data["packs/standard_pack"].duplicate()
	second.id = &"second_pack"
	data["packs/second_pack"] = second
	db = _load_case(data)
	assert_true(db.has_issue(DataValidator.PACK_RULE, "", "hand_sizes"), "hand size served twice")
	db.free()


func test_rejects_broken_references_and_files() -> void:
	var data: Dictionary = _valid_set()
	# An area saved outside the data folder: it loads, but isn't registered data.
	var stray: AreaData = data["areas/docks"].duplicate()
	stray.id = &"stray_area"
	_ensure_dir(TEST_ROOT.path_join("outside"))
	_save(stray, TEST_ROOT.path_join("outside/stray_area.tres"))
	data["zone/zone_09"].close_a = stray
	data["areas/docks"].piles.append(null)             # empty pile slot
	data["cards/not_a_card"] = Gradient.new()
	var db: Node = _load_case(data, {"cards/broken_dep.tres": _tres_with_missing_dependency()})
	assert_false(db.is_valid(), "broken refs accepted")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "zone_09", "close_a"), "area outside data/")
	assert_true(db.has_issue(DataValidator.BROKEN_REFERENCE, "docks", "piles[1]"), "empty pile slot")
	assert_true(db.has_issue(DataValidator.UNKNOWN_TYPE), "foreign resource")
	assert_true(db.has_issue(DataValidator.LOAD_FAILED), "file with a missing dependency")
	db.free()


func test_rejects_missing_balance_file() -> void:
	var data: Dictionary = _valid_set()
	data.erase("balance")
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "missing balance.tres accepted")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "balance", "balance"), "balance missing reported")
	assert_eq(db.get_balance().hand_size, 5, "defaults still usable")
	db.free()


func test_rejects_missing_required_fields() -> void:
	var data: Dictionary = _valid_set()
	data["cards/medkit"].display_name = ""
	data["cards/medkit"].rules_text = ""
	data["cards/medkit"].heal = 0                     # an item with no effect at all
	data["areas/motel"].display_name = ""
	data["zone/zone_01"].display_name = ""
	var blank: CardData = CardData.new()               # nothing set at all
	blank.id = &"blank_card"
	data["cards/blank_card"] = blank
	var db: Node = _load_case(data)
	assert_false(db.is_valid(), "missing fields accepted")
	var M: String = DataValidator.MISSING_FIELD
	assert_true(db.has_issue(M, "medkit", "display_name"), "empty name")
	assert_true(db.has_issue(M, "medkit", "rules_text"), "empty text")
	assert_true(db.has_issue(M, "medkit", "move"), "item without an effect")
	assert_true(db.has_issue(M, "motel", "display_name"), "area without a name")
	assert_true(db.has_issue(M, "zone_01", "display_name"), "Zone card without a title")
	assert_true(db.has_issue(M, "blank_card", "code"), "blank card: no code")
	db.free()


func test_warnings_do_not_fail_the_load() -> void:
	var data: Dictionary = _valid_set()
	for n: int in [12, 13, 14]:
		data.erase("zone/zone_%d" % n)                # deck ends at 11 (< hard end 14)
	data["areas/docks"].piles.clear()                  # no piles yet
	data["balance"].hand_size = 4                      # with drop cost 4: the §16.4a caveat
	var db: Node = _load_case(data)
	assert_true(db.is_valid(), "warnings only:\n" + "\n".join(db.get_errors()))
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "", "zone", true), "short deck warned")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "docks", "piles", true), "no piles warned")
	assert_true(db.has_issue(DataValidator.MISSING_FIELD, "scrap_smg", "rarity", true), "card never on the map warned")
	assert_true(db.has_issue(DataValidator.OUT_OF_RANGE, "balance", "supply_drop_cost", true), "hand 4 + drop 4 warned")
	assert_eq(db.get_report()["warnings"], 4, "four warnings:\n" + "\n".join(db.get_warnings()))
	db.free()


func test_issue_report_shape() -> void:
	var data: Dictionary = _valid_set()
	data["cards/pump_shotgun"].dmg = 0
	var db: Node = _load_case(data)
	var report: Dictionary = db.get_report()
	assert_false(report["ok"], "report ok flag")
	assert_eq(report["errors"], 1, "exactly one error")
	var issue: Dictionary = report["issues"][0]
	for key: String in ["severity", "code", "file", "id", "field", "message"]:
		assert_true(issue.has(key), "issue has %s" % key)
	assert_true(String(issue["file"]).ends_with("pump_shotgun.tres"), "issue names the file")
	assert_true(db.get_errors()[0].begins_with("ERROR [missing_field]"), "formatted line")
	db.free()

# --- Fixture builders ------------------------------------------------------------------

## A complete, valid data set (spec §3, §8, §10, §11 values). Keys are "<folder>/<file>".
func _valid_set() -> Dictionary:
	var d: Dictionary = {}
	var cards: Array[CardData] = [
		_card(&"p9_sidearm", "CZ-001", T.WEAPON, R.STARTER, 0, {"dmg": 1, "rng": 0}),
		_card(&"scavenge", "CZ-002", T.ITEM, R.STARTER, 0, {"search": 1}),
		_card(&"dash", "CZ-003", T.ITEM, R.STARTER, 0, {"move": 1}),
		_card(&"duck", "CZ-004", T.ITEM, R.STARTER, 0, {"brace": 1, "search": 1}),
		_card(&"hit", "CZ-005", T.HIT, R.NONE, 0, {}),
		_card(&"bounty", "CZ-006", T.MARKER, R.NONE, 0, {}),
		_card(&"scrap_smg", "CZ-010", T.WEAPON, R.COMMON, 3, {"dmg": 2, "rng": 0}),
		_card(&"bandage", "CZ-012", T.ITEM, R.COMMON, 2, {"heal": 1, "move": 1, "spent": DataEnums.SpentMode.ON_PLAY}),
		_card(&"pump_shotgun", "CZ-014", T.WEAPON, R.UNCOMMON, 4, {"dmg": 3, "rng": 0}),
		_card(&"frag_grenade", "CZ-015", T.ITEM, R.UNCOMMON, 3, {"blast_dmg": 2, "blast_rng": 1, "ignores_cover": true,
				"spent": DataEnums.SpentMode.ON_PLAY}),
		_card(&"hunting_rifle", "CZ-016", T.WEAPON, R.UNCOMMON, 4, {"dmg": 2, "rng": 1}),
		_card(&"long_scope", "CZ-017", T.ATTACHMENT, R.UNCOMMON, 3, {"attach_rng": 1}),
		_card(&"medkit", "CZ-018", T.ITEM, R.UNCOMMON, 4, {"heal": 2}),
		_card(&"plate_vest", "CZ-019", T.ITEM, R.UNCOMMON, 4, {"brace": 2, "move": 1}),
		_card(&"crowbar", "CZ-020", T.ITEM, R.COMMON, 2, {"search": 2}),
		_card(&"assault_rifle", "CZ-023", T.WEAPON, R.RARE, 6, {"dmg": 3, "rng": 1}),
		_card(&"extended_mag", "CZ-025", T.ATTACHMENT, R.RARE, 5, {"attach_extra_fire": 1}),
		_card(&"suppressor", "CZ-026", T.ATTACHMENT, R.RARE, 5, {"attach_no_brace": true}),
		_card(&"twin_drum_lmg", "CZ-030", T.WEAPON, R.EPIC, 0, {"supply_drop": true, "dmg": 2, "rng": 1, "fires_per_turn": 2}),
		_card(&"heavy_plate", "CZ-031", T.ITEM, R.EPIC, 0, {"supply_drop": true, "brace": 3, "heal": 1, "move": 1}),
		_card(&"longshot_50", "CZ-032", T.WEAPON, R.LEGENDARY, 0, {"supply_drop": true, "dmg": 4, "rng": 2, "ignores_cover": true}),
		_card(&"phantom_suit", "CZ-033", T.ITEM, R.LEGENDARY, 0, {"supply_drop": true, "brace": 4, "move": 2, "search": 1}),
		_card(&"red_dot_sight", "CZ-022", T.ATTACHMENT, R.COMMON, 2, {"attach_dmg": 1}),
		_card(&"recon_drone", "CZ-027", T.ITEM, R.RARE, 5, {"search": 2, "pull": 1}),
	]
	for c: CardData in cards:
		d["cards/" + String(c.id)] = c
	var card: Callable = func(id: String) -> CardData: return d["cards/" + id]

	var piles: Dictionary = {
		&"docks": ["scrap_smg"], &"farmstead": ["bandage"], &"quarry": ["pump_shotgun", "frag_grenade"],
		&"radio_hill": ["hunting_rifle", "long_scope"], &"motel": ["medkit", "plate_vest"],
		&"rail_yard": ["crowbar", "red_dot_sight"],
		&"old_town": ["assault_rifle", "extended_mag", "suppressor", "recon_drone"],
	}
	var covers: Array[int] = [0, 1, 1, 0, 1, 0]
	for i: int in RING.size():
		var a: AreaData = _area(RING[i], i + 1, DataEnums.AreaTier.OUTER, covers[i], [RING[(i + 5) % 6], RING[(i + 1) % 6], &"old_town"])
		d["areas/" + String(a.id)] = a
	d["areas/old_town"] = _area(&"old_town", 0, DataEnums.AreaTier.CORE, 1, RING)
	for area_id: StringName in piles.keys():
		for card_id: String in piles[area_id]:
			(d["areas/" + String(area_id)] as AreaData).piles.append(card.call(card_id))

	# Zone deck, spec §8: [number, title, close A/B/C, drop card, drop A/B/C, final circle step].
	var rows: Array = [
		[1, "Calm", [], "", [], 0], [2, "Calm", [], "", [], 0],
		[3, "Supply drop", [], "twin_drum_lmg", ["quarry", "docks", "motel"], 0],
		[4, "Gas closes", ["docks", "radio_hill", "farmstead"], "", [], 0],
		[5, "Calm", [], "", [], 0],
		[6, "Gas closes", ["farmstead", "quarry", "rail_yard"], "heavy_plate", ["motel", "rail_yard", "radio_hill"], 0],
		[7, "Gas closes", ["rail_yard", "motel", "docks"], "", [], 0],
		[8, "Supply drop", [], "longshot_50", ["old_town", "old_town", "old_town"], 0],
		[9, "Gas closes", ["radio_hill", "farmstead", "quarry"], "", [], 0],
		[10, "Gas closes", ["quarry", "docks", "radio_hill"], "phantom_suit", ["motel", "rail_yard", "motel"], 0],
		[11, "Gas closes", ["motel", "rail_yard", "motel"], "", [], 0],
		[12, "Final circle I", [], "", [], 1], [13, "Final circle II", [], "", [], 2], [14, "Final circle III", [], "", [], 3],
	]
	for row: Array in rows:
		var z: ZoneCardData = ZoneCardData.new()
		z.id = StringName("zone_%02d" % row[0])
		z.number = row[0]
		z.display_name = row[1]
		if not (row[2] as Array).is_empty():
			z.close_a = d["areas/" + row[2][0]]
			z.close_b = d["areas/" + row[2][1]]
			z.close_c = d["areas/" + row[2][2]]
		if not String(row[3]).is_empty():
			z.drop_card = card.call(row[3])
			z.drop_a = d["areas/" + row[4][0]]
			z.drop_b = d["areas/" + row[4][1]]
			z.drop_c = d["areas/" + row[4][2]]
		z.final_circle_step = row[5]
		d["zone/" + String(z.id)] = z

	var pack: StartPackData = StartPackData.new()
	pack.id = &"standard_pack"
	pack.display_name = "Standard pack"
	for id: String in ["scavenge", "scavenge", "scavenge", "duck", "dash", "dash", "p9_sidearm", "scavenge", "duck", "dash"]:
		pack.cards.append(card.call(id))
	d["packs/standard_pack"] = pack
	d["balance"] = BalanceConfig.new()
	return d


func _card(id: StringName, code: String, type: int, rarity: int, cost: int, fields: Dictionary) -> CardData:
	var c: CardData = CardData.new()
	c.id = id
	c.code = code
	c.display_name = String(id).capitalize()
	c.type = type
	c.rarity = rarity
	c.cost = cost
	c.rules_text = "Test card"
	for key: String in fields.keys():
		c.set(key, fields[key])
	return c


func _area(id: StringName, number: int, tier: DataEnums.AreaTier, cover: int, adjacent: Array) -> AreaData:
	var a: AreaData = AreaData.new()
	a.id = id
	a.display_name = String(id).capitalize()
	a.number = number
	a.tier = tier
	a.cover = cover
	a.adjacent.assign(adjacent)
	return a


## Text of a .tres whose ext_resource points at a file that doesn't exist.
func _tres_with_missing_dependency() -> String:
	return "\n".join([
		'[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]', "",
		'[ext_resource type="Script" path="res://scripts/data/card_data_missing.gd" id="1_x"]', "",
		"[resource]", 'script = ExtResource("1_x")', 'id = &"broken_dep"', "",
	])

# --- Saving & loading a case -------------------------------------------------------

## Saves `data` (and raw text files) under a fresh user:// folder and loads it with
## a new CardDB instance (not in the tree). Caller frees the returned node.
func _load_case(data: Dictionary, raw_files: Dictionary = {}) -> Node:
	_case_counter += 1
	var root: String = TEST_ROOT.path_join("case_%d_%d" % [Time.get_ticks_usec(), _case_counter])
	var saved: Dictionary = {}
	for prefix: String in SAVE_ORDER:
		for key: String in data.keys():
			if key.begins_with(prefix) and not saved.has(key):
				saved[key] = true
				var path: String = root.path_join(key + ".tres")
				_ensure_dir(path.get_base_dir())
				_save(data[key], path)
	for rel: String in raw_files.keys():
		var path: String = root.path_join(rel)
		_ensure_dir(path.get_base_dir())
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(raw_files[rel])
		f.close()
	var db: Node = CardDBScript.new()
	db.report_to_console = false
	db.load_all(root)
	_remove_dir(TEST_ROOT)  # files are no longer needed: loaded resources stay cached in memory
	return db


func _remove_dir(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## Saves res and gives it that path, so later files reference it as an ext_resource
## (FLAG_CHANGE_PATH does not set the path for user:// files).
func _save(res: Resource, path: String) -> void:
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		failures.append("could not save %s (%s)" % [path, error_string(err)])
	res.take_over_path(path)


func _ensure_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
