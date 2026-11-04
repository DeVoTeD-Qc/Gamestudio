# test_rules_fixtures.gd
# Purpose: Shared helpers for the rules tests (no test_ methods of its own). Loads QA's
#   rules-test-cases.json (cc04) and builds the 20 spec cards, their sets, the Triptychs and
#   balance configs in memory, so the rules tests never depend on res://data (RQ-18).
# Dependencies: CardData, SetData, TriptychData, BalanceConfig, DataEnums, WallState.
# Author: Mechanics Developer Agent
extends RefCounted

## QA's machine-readable cases, relative to the Godot project folder.
const JSON_REL_PATH: String = "../../documentation/qa/rules-test-cases.json"

const ORIGINS: Dictionary = {
	"challenge": DataEnums.Origin.CHALLENGE, "mastery": DataEnums.Origin.MASTERY,
	"event": DataEnums.Origin.EVENT, "prestige": DataEnums.Origin.PRESTIGE,
	"ranked": DataEnums.Origin.RANKED, "secret": DataEnums.Origin.SECRET,
	"store": DataEnums.Origin.SHOWCASE, "showcase": DataEnums.Origin.SHOWCASE,
}

static var _json_cache: Dictionary = {}


static func json_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(JSON_REL_PATH).simplify_path()


## The parsed JSON ({} with push_error when missing).
static func load_cases() -> Dictionary:
	if _json_cache.is_empty():
		var text: String = FileAccess.get_file_as_string(json_path())
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_json_cache = parsed
		else:
			push_error("rules fixtures: can't read %s" % json_path())
	return _json_cache


## card id (StringName) -> CardData for every card in the JSON (or in `doc`).
static func build_cards(doc: Dictionary = {}) -> Dictionary:
	if doc.is_empty():
		doc = load_cases()
	var sets: Dictionary = {}
	var out: Dictionary = {}
	var order: Dictionary = {}
	for id: String in doc.get("cards", {}).keys():
		var j: Dictionary = doc["cards"][id]
		var set_id: String = j["set"]
		if not sets.has(set_id):
			var s: SetData = SetData.new()
			s.id = StringName(set_id)
			s.display_name = set_id.capitalize()
			s.kind = DataEnums.SetKind.SHOWCASE if set_id == "showcase" else (
					DataEnums.SetKind.CIPHER if set_id == "cipher" else DataEnums.SetKind.STANDARD)
			s.number = sets.size() + 1
			s.palette_key = StringName(set_id)
			s.completion_title = set_id.capitalize()
			sets[set_id] = s
		order[set_id] = int(order.get(set_id, 0)) + 1
		var c: CardData = CardData.new()
		c.id = StringName(id)
		c.display_name = j["name"]
		c.card_set = sets[set_id]
		c.album_order = order[set_id]
		c.top = int(j["top"])
		c.side = int(j["side"])
		c.bottom = int(j["bottom"])
		c.clearance = int(j["clearance"])
		c.origin = ORIGINS[j["origin"]]
		c.is_store = j["origin"] == "store"
		c.how_earned = "Test card"
		c.art_key = StringName(id)
		c.starts_owned = true
		out[StringName(id)] = c
	return out


static func build_triptychs(cards: Dictionary, doc: Dictionary = {}) -> Array[TriptychData]:
	if doc.is_empty():
		doc = load_cases()
	var out: Array[TriptychData] = []
	for id: String in doc.get("triptychs", {}).keys():
		var t: TriptychData = TriptychData.new()
		t.id = StringName(id)
		t.display_name = id.capitalize()
		for cid: String in doc["triptychs"][id]:
			t.cards.append(cards[StringName(cid)])
		out.append(t)
	return out


## Spec §9 defaults plus a case's balance_overrides.
static func build_balance(overrides: Dictionary = {}) -> BalanceConfig:
	var b: BalanceConfig = BalanceConfig.new()
	for key: String in overrides.keys():
		var v: Variant = overrides[key]
		match key:
			"tie_winner":
				b.tie_winner = DataEnums.TieWinner.DRAW if str(v) == "draw" else DataEnums.TieWinner.FIRST_PLAYER
			"chain_captures":
				b.chain_captures = bool(v)
			_:
				b.set(key, int(v))
	return b


static func cards_from_ids(cards: Dictionary, ids: Variant) -> Array:
	var out: Array = []
	if ids == null:
		return out
	for id: Variant in ids:
		out.append(cards.get(StringName(str(id)), null))
	return out


## JSON-comparable copy: StringName -> String, integral floats -> int, player ints stay ints.
static func norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(v) == floor(float(v)) else v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_ARRAY:
			var a: Array = []
			for x: Variant in v:
				a.append(norm(x))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in v.keys():
				d[str(k)] = norm(v[k])
			return d
	if v is PackedStringArray or v is PackedInt32Array:
		return norm(Array(v))
	return v


static func sorted_strings(v: Variant) -> Array:
	var a: Array = []
	if v != null:
		for x: Variant in v:
			a.append(str(x))
	a.sort()
	return a


static func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(norm(a), "", true) == JSON.stringify(norm(b), "", true)


static func show(v: Variant) -> String:
	return JSON.stringify(norm(v), "", true)
