# pitch_decks.gd
# Purpose: Private pitch build only (kc-cod2, head: "include several of each kind (units, tactics,
#   Fields) so the pitch shows all three"). In the "Web (private pitch)" export (feature tag
#   licensed_pitch) every match deck gets a few swaps so the board shows Units, Tactics and Fields and
#   the 4 chassis added for the MW3 art (Brawler, Smoke Screen, Blackout, Sabotage). The public build,
#   the tests and the saved run deck are untouched: apply() returns a new array for this match only.
#   Swap rule (deterministic, kc-cod3 head answers): about half units, 3 Fields, the rest tactics
#   (20 cards: 10 / 7 / 3; 18 cards: 9 / 6 / 3). Sniper Perch and Aid Station never appear (no art fits).
#   1. Brawler replaces one copy of the most duplicated non-Elite unit.
#   2. Fields up to FIELDS from FIELD_ADDS, each replacing a duplicated unit while units > target.
#   3. The new tactics (TACTIC_ADDS) each replace a duplicated unit while units > target, else a
#      duplicated older tactic, else the last older tactic. Decks under MIN_DECK cards are left alone.
# Dependencies: CardDB (autoload), CardData, DataEnums.
# Author: Mechanics Developer Agent (kc-cod2)
class_name PitchDecks
extends RefCounted

const FIELD_ADDS: Array[StringName] = [&"war_standard", &"listening_post", &"bulwark"]
const TACTIC_ADDS: Array[StringName] = [&"smoke_screen", &"blackout", &"sabotage"]
const LEFT_OUT: Array[StringName] = [&"sniper_perch", &"aid_station"]
const FIELDS: int = 3
const MIN_DECK: int = 10
## Tests / a local preview can force it on.
static var forced: bool = false


static func active() -> bool:
	return forced or OS.has_feature("licensed_pitch")


## Units the pitch deck aims for (half the deck, rounded down).
static func unit_target(size: int) -> int:
	return size / 2


## The pitch version of a deck (a new array; `deck` is not modified). Unchanged when inactive.
static func apply(deck: Array[CardData], card_lookup: Callable = Callable()) -> Array[CardData]:
	var out: Array[CardData] = deck.duplicate()
	if not active() or out.size() < MIN_DECK:
		return out
	var lookup: Callable = card_lookup
	if not lookup.is_valid():
		var db: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/CardDB") if Engine.get_main_loop() is SceneTree else null
		if db == null:
			return out
		lookup = db.get_card
	var target: int = unit_target(out.size())
	var UNIT: int = DataEnums.CardType.UNIT
	# Left-out Fields become the first missing pitch Field.
	for i: int in out.size():
		if out[i] != null and out[i].id in LEFT_OUT:
			var sub: CardData = _first_missing(out, FIELD_ADDS, lookup)
			if sub != null:
				out[i] = sub
	var brawler: CardData = lookup.call(&"brawler")
	if brawler != null and not _has(out, brawler.id):
		var v: int = _dup_victim(out, UNIT, [] as Array[StringName])
		if v >= 0:
			out[v] = brawler
	for id: StringName in FIELD_ADDS:
		if _count_type(out, DataEnums.CARD_TYPE_FIELD) >= FIELDS or _count_type(out, UNIT) <= target:
			break
		var card: CardData = lookup.call(id)
		var v: int = _dup_victim(out, UNIT, [] as Array[StringName])
		if card != null and not _has(out, id) and v >= 0:
			out[v] = card
	for id: StringName in TACTIC_ADDS:
		var card: CardData = lookup.call(id)
		if card == null or _has(out, id):
			continue
		var v: int = _dup_victim(out, UNIT, [] as Array[StringName]) if _count_type(out, UNIT) > target else -1
		if v < 0:
			v = _dup_victim(out, DataEnums.CardType.TACTIC, TACTIC_ADDS)
		if v < 0:
			v = _last_of(out, DataEnums.CardType.TACTIC, TACTIC_ADDS)
		if v >= 0:
			out[v] = card
	return out


static func _first_missing(deck: Array[CardData], ids: Array[StringName], lookup: Callable) -> CardData:
	for id: StringName in ids:
		if not _has(deck, id):
			return lookup.call(id)
	return null


static func _has(deck: Array[CardData], id: StringName) -> bool:
	for c: CardData in deck:
		if c != null and c.id == id:
			return true
	return false


static func _count_type(deck: Array[CardData], type: int) -> int:
	var n: int = 0
	for c: CardData in deck:
		if c != null and c.card_type == type:
			n += 1
	return n


## Index of the last copy of the most duplicated non-Elite card of `type` (not in `keep`), -1 if none.
static func _dup_victim(deck: Array[CardData], type: int, keep: Array[StringName]) -> int:
	var counts: Dictionary = {}
	for c: CardData in deck:
		if c != null and c.card_type == type and not c.is_elite and not c.id in keep:
			counts[c.id] = int(counts.get(c.id, 0)) + 1
	var best: StringName = &""
	for id: StringName in counts:
		if int(counts[id]) >= 2 and (best == &"" or int(counts[id]) > int(counts[best])):
			best = id
	return _last_index(deck, best) if best != &"" else -1


## Index of the last card of `type` not in `keep` (-1 if none).
static func _last_of(deck: Array[CardData], type: int, keep: Array[StringName]) -> int:
	for i: int in range(deck.size() - 1, -1, -1):
		if deck[i] != null and deck[i].card_type == type and not deck[i].id in keep:
			return i
	return -1


static func _last_index(deck: Array[CardData], id: StringName) -> int:
	for i: int in range(deck.size() - 1, -1, -1):
		if deck[i] != null and deck[i].id == id:
			return i
	return -1
