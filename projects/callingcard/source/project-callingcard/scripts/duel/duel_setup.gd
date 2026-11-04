# duel_setup.gd
# Purpose: Where a duel's cards come from (cc08). Reads CardDB (cc02/cc03 data) and falls back
#   to the cc07 mock table when the data is missing or incomplete, so the duel always starts.
#   - cards:   CardDB.get_card(id), else a CardData built from mock_duel_data.gd.
#   - player:  DuelController.next_player_lineup (cc10/cc13 set it), else balance.loaner_lineup,
#              else the mock lineup. (cc09's saved lineup plugs in through next_player_lineup.)
#   - Signature: cc13: when the requested lineup is the one saved in Collection (same cards, any
#              order), the Signature saved with it (cc10 builder); else the loaner's, else the
#              highest-Clearance eligible card.
#   - rivals:  CardDB.all_rivals() with a 5-card lineup and a Signature, else one mock rival.
# Dependencies: CardDB and Collection autoloads, CardData, RivalData, BalanceConfig, DataEnums, mock_duel_data.gd.
# Author: UI/UX Agent (cc08)
extends RefCounted

const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")

static var _mock_cards: Dictionary = {}


static func card_db() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("CardDB") if loop != null else null


static func get_card(id: StringName) -> CardData:
	var db: Node = card_db()
	if db != null and db.has_card(id):
		return db.get_card(id)
	return mock_card(id)


static func balance() -> BalanceConfig:
	var db: Node = card_db()
	var b: BalanceConfig = db.get_balance() if db != null else null
	return b if b != null else BalanceConfig.new()


static func triptychs() -> Array[TriptychData]:
	var db: Node = card_db()
	var out: Array[TriptychData] = []
	if db != null:
		out.assign(db.all_triptychs())
	return out


## [{id, name, difficulty (0-2), lineup: Array[CardData], signature: CardData, data: RivalData|null}]
static func rivals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var db: Node = card_db()
	if db != null:
		var list: Array = db.all_rivals()
		list.sort_custom(func(a: RivalData, b: RivalData) -> bool: return a.difficulty < b.difficulty)
		for r: RivalData in list:
			if r.lineup.size() == balance().lineup_size and r.signature != null and r.lineup.has(r.signature):
				var lineup: Array[CardData] = []
				lineup.assign(r.lineup)
				out.append({"id": r.id, "name": r.display_name, "difficulty": int(r.difficulty),
						"lineup": lineup, "signature": r.signature, "data": r})
	if out.is_empty():
		var lineup: Array[CardData] = []
		for id: StringName in MockDuelData.RIVAL_LINEUP:
			lineup.append(get_card(id))
		out.append({"id": &"archivist", "name": "Archivist", "difficulty": 1, "lineup": lineup,
				"signature": get_card(&"brass_tacks"), "data": null})
	return out


## The player's lineup: {lineup: Array[CardData], signature: CardData}.
static func player_lineup(requested: Array = []) -> Dictionary:
	var lineup: Array[CardData] = []
	for c: Variant in requested:
		var card: CardData = c if c is CardData else get_card(StringName(str(c)))
		if card != null:
			lineup.append(card)
	var b: BalanceConfig = balance()
	var sig: CardData = saved_signature_for(lineup) if lineup.size() == b.lineup_size else null
	if lineup.size() != b.lineup_size and b.loaner_lineup.size() == b.lineup_size:
		lineup.assign(b.loaner_lineup)
		sig = b.loaner_signature
	if lineup.size() != b.lineup_size:
		lineup.clear()
		for id: StringName in MockDuelData.PLAYER_LINEUP:
			lineup.append(get_card(id))
		sig = get_card(&"snow_blind")
	if sig == null or not lineup.has(sig) or not sig.signature_eligible:
		sig = default_signature(lineup)
	return {"lineup": lineup, "signature": sig}


## cc13: the Signature saved with this lineup in Collection (cc10 builder), or null when the lineup
## is not the saved one (compared as a set of ids) or nothing is saved.
static func saved_signature_for(lineup: Array[CardData]) -> CardData:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var col: Node = loop.root.get_node_or_null("Collection") if loop != null else null
	if col == null or not col.has_method(&"get_saved_lineup_ids"):
		return null
	var saved: Dictionary = col.get_saved_lineup_ids()
	if saved.is_empty():
		return null
	var want: Array = (saved.get("cards", []) as Array).map(func(id: Variant) -> String: return str(id))
	var have: Array = lineup.map(func(c: CardData) -> String: return String(c.id))
	want.sort()
	have.sort()
	if want != have:
		return null
	var sig_id: StringName = StringName(str(saved.get("signature", "")))
	for c: CardData in lineup:
		if c.id == sig_id:
			return c
	return null


## Highest-Clearance card that may be a Signature.
static func default_signature(lineup: Array[CardData]) -> CardData:
	var best: CardData = null
	for c: CardData in lineup:
		if c.signature_eligible and (best == null or c.clearance > best.clearance):
			best = c
	return best if best != null else (lineup[0] if not lineup.is_empty() else null)


## CardData from the cc07 mock table (no set resource: art falls back to its default palette).
static func mock_card(id: StringName) -> CardData:
	if _mock_cards.has(id):
		return _mock_cards[id]
	var d: Dictionary = MockDuelData.card(id)
	if d.is_empty():
		return null
	var c: CardData = CardData.new()
	c.id = id
	c.display_name = d["name"]
	c.top = d["top"]
	c.side = d["side"]
	c.bottom = d["bottom"]
	c.clearance = d["clearance"]
	c.origin = DataEnums.Origin[String(d["origin"]).to_upper()]
	c.is_store = d["origin"] == &"showcase"
	c.signature_eligible = true
	c.how_earned = d["earned"]
	c.art_seed = d["art_seed"]
	_mock_cards[id] = c
	return c
