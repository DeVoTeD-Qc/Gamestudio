# test_rules_fixtures.gd
# Pattern adapted from CallingCard tests/test_rules_fixtures.gd (JSON loading, content built in
#   memory so the rules tests never depend on res://data, which cz06 is still authoring).
# Purpose: Shared helpers for the rules tests (no test_ methods of its own). Loads QA's
#   rules-test-cases.json (cz04), builds the spec content (27 cards + the Hit, the 7 areas,
#   Zone cards 1-14, the Standard pack) as RulesData, and maps QA's card codes (SCV, HRF+RDS) to
#   CardDB ids and back.
# Dependencies: RulesData, CardData, AreaData, ZoneCardData, BalanceConfig, DataEnums, MatchState.
# Author: Mechanics Developer Agent
extends RefCounted

## QA's machine-readable cases, relative to the Godot project folder.
const JSON_REL_PATH: String = "../../documentation/qa/rules-test-cases.json"
const RING: Array[String] = ["docks", "farmstead", "quarry", "radio_hill", "motel", "rail_yard"]
const TYPES: Dictionary = {"weapon": DataEnums.CardType.WEAPON, "attachment": DataEnums.CardType.ATTACHMENT,
		"item": DataEnums.CardType.ITEM, "hit": DataEnums.CardType.HIT}
const RARITIES: Dictionary = {"starter": DataEnums.Rarity.STARTER, "C": DataEnums.Rarity.COMMON,
		"U": DataEnums.Rarity.UNCOMMON, "R": DataEnums.Rarity.RARE, "E": DataEnums.Rarity.EPIC,
		"L": DataEnums.Rarity.LEGENDARY}

static var _json_cache: Dictionary = {}
static var _content_cache: RulesData = null


static func json_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(JSON_REL_PATH).simplify_path()


## The parsed JSON ({} with push_error when missing).
static func load_cases() -> Dictionary:
	if _json_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path()))
		if parsed is Dictionary:
			_json_cache = parsed
		else:
			push_error("rules fixtures: can't read %s" % json_path())
	return _json_cache


## QA code -> CardDB id (SCV -> scavenge).
static func code_map(doc: Dictionary = {}) -> Dictionary:
	if doc.is_empty():
		doc = load_cases()
	var out: Dictionary = {}
	for code: String in doc.get("cards", {}).keys():
		out[code] = doc["cards"][code]["data_id"]
	return out


## CardDB id -> QA code.
static func id_map(doc: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var cm: Dictionary = code_map(doc)
	for code: String in cm.keys():
		out[StringName(cm[code])] = code
	return out


## The spec content as RulesData, with BalanceConfig defaults (§16.8).
static func content(doc: Dictionary = {}) -> RulesData:
	if _content_cache != null:
		return _content_cache
	if doc.is_empty():
		doc = load_cases()
	var cards: Dictionary = {}  # code -> CardData
	var list: Array[CardData] = []
	for code: String in doc["cards"].keys():
		var j: Dictionary = doc["cards"][code]
		var c: CardData = CardData.new()
		c.id = StringName(j["data_id"])
		c.code = String(j["cz_id"])
		c.display_name = String(j["name"])
		c.type = TYPES[j["type"]]
		c.rarity = RARITIES.get(j["rarity"], DataEnums.Rarity.NONE) if j["rarity"] != null else DataEnums.Rarity.NONE
		c.cost = int(j["cost"]) if j["cost"] != null else 0
		c.supply_drop = j["cost"] == null and c.rarity in [DataEnums.Rarity.EPIC, DataEnums.Rarity.LEGENDARY]
		c.brace = int(j.get("brace", 0))
		c.move = int(j.get("move", 0))
		c.search = int(j.get("search", 0))
		c.heal = int(j.get("heal", 0))
		c.pull = int(j.get("pull", 0))
		match String(j.get("spent", "")):
			"play", "resolve":
				c.spent = DataEnums.SpentMode.ON_PLAY
			"brace":
				c.spent = DataEnums.SpentMode.ON_BRACE
		if c.type == DataEnums.CardType.WEAPON:
			c.dmg = int(j["dmg"])
			c.rng = int(j["rng"])
			c.fires_per_turn = int(j.get("fires", 1))
		c.ignores_cover = bool(j.get("ignore_cover", false))
		if j.has("frag"):
			c.blast_dmg = int(j["frag"])
			c.blast_rng = 1
			c.ignores_cover = true  # R32 (data/cards/frag_grenade.tres sets it too)
		c.attach_dmg = int(j.get("attach_dmg", 0))
		c.attach_rng = int(j.get("attach_rng", 0))
		c.attach_extra_fire = int(j.get("attach_extra_fire", 0))
		c.attach_no_brace = bool(j.get("attach_suppress", false))
		cards[code] = c
		list.append(c)
	var areas: Dictionary = {}
	var area_list: Array[AreaData] = []
	for id: String in doc["map"]["areas"].keys():
		var j: Dictionary = doc["map"]["areas"][id]
		var a: AreaData = AreaData.new()
		a.id = StringName(id)
		a.display_name = String(j["name"])
		a.number = RING.find(id) + 1
		a.tier = DataEnums.AreaTier.CORE if id == "old_town" else DataEnums.AreaTier.OUTER
		a.cover = int(j["cover"])
		for n: Variant in j["adjacent"]:
			a.adjacent.append(StringName(n))
		for code: Variant in j["piles"]:
			a.piles.append(cards[code])
		areas[id] = a
		area_list.append(a)
	var zone: Array[ZoneCardData] = []
	for j: Dictionary in doc["zone_deck"]:
		var z: ZoneCardData = ZoneCardData.new()
		z.number = int(j["card"])
		z.id = StringName("zone_%02d" % z.number)
		z.display_name = String(j["kind"])
		if j.has("final_circle_index"):
			z.final_circle_step = int(j["final_circle_index"]) + 1
		if j.has("A"):
			var routes: Array = [j["A"], j["B"], j["C"]]
			if routes[0]["gas"] != null:
				z.close_a = areas[routes[0]["gas"]]
				z.close_b = areas[routes[1]["gas"]]
				z.close_c = areas[routes[2]["gas"]]
			if j.get("drop") != null:
				z.drop_card = cards[j["drop"]]
				z.drop_a = areas[routes[0]["drop_area"]]
				z.drop_b = areas[routes[1]["drop_area"]]
				z.drop_c = areas[routes[2]["drop_area"]]
		zone.append(z)
	var pack: Array = []
	for code: Variant in doc["standard_pack"]:
		pack.append(cards[code].id)
	_content_cache = RulesData.from_parts(list, area_list, zone, {4: pack, 5: pack}, BalanceConfig.new())
	return _content_cache


## A card instance as a QA token: "HRF+RDS".
static func token(state: MatchState, inst: int, ids: Dictionary) -> String:
	var parts: PackedStringArray = [String(ids.get(state.card_id(inst), String(state.card_id(inst))))]
	for a: int in state.attachments_of(inst):
		parts.append(String(ids.get(state.card_id(a), String(state.card_id(a)))))
	return "+".join(parts)


static func tokens(state: MatchState, list: Array, ids: Dictionary) -> Array:
	var out: Array = []
	for inst: Variant in list:
		out.append(token(state, int(inst), ids))
	return out
