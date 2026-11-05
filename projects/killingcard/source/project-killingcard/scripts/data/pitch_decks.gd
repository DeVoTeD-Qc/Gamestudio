# pitch_decks.gd
# Purpose: Private pitch build only (kc-cod2, head: "include several of each kind (units, tactics,
#   Fields) so the pitch shows all three"). In the "Web (private pitch)" export (feature tag
#   licensed_pitch) every match deck gets a few swaps so the board shows Units, Tactics and Fields and
#   the 4 chassis added for the MW3 art (Brawler, Smoke Screen, Blackout, Sabotage). The public build,
#   the tests and the saved run deck are untouched: apply() returns a new array for this match only.
#   Swap rule (deterministic): for each WANTED card not yet in the deck whose kind is under its quota,
#   one copy of the most duplicated non-Elite unit chassis is replaced (never the last copy of a chassis,
#   never below MIN_UNITS units). Decks under MIN_DECK cards (tutorial) are left alone.
# Dependencies: CardDB (autoload), CardData, DataEnums.
# Author: Mechanics Developer Agent (kc-cod2)
class_name PitchDecks
extends RefCounted

## In order of priority: [card id, kind quota (cards of that type wanted in the deck)].
const WANTED: Array = [
	[&"brawler", 0], [&"war_standard", 3], [&"smoke_screen", 7], [&"listening_post", 3],
	[&"blackout", 8], [&"bulwark", 3], [&"sabotage", 9],
]
const MIN_DECK: int = 10
const MIN_UNITS: int = 8
## Tests / a local preview can force it on.
static var forced: bool = false


static func active() -> bool:
	return forced or OS.has_feature("licensed_pitch")


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
	for w: Array in WANTED:
		var card: CardData = lookup.call(w[0])
		if card == null or _has(out, card.id):
			continue
		if card.card_type != DataEnums.CardType.UNIT and _count_type(out, card.card_type) >= int(w[1]):
			continue
		var i: int = _victim(out)
		if i < 0:
			break
		out[i] = card
	return out


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


## Index of a copy of the most duplicated non-Elite unit (the last copy in the list), -1 if none.
static func _victim(deck: Array[CardData]) -> int:
	if _count_type(deck, DataEnums.CardType.UNIT) <= MIN_UNITS:
		return -1
	var counts: Dictionary = {}
	for c: CardData in deck:
		if c != null and c.card_type == DataEnums.CardType.UNIT and not c.is_elite:
			counts[c.id] = int(counts.get(c.id, 0)) + 1
	var best: StringName = &""
	for id: StringName in counts:
		if int(counts[id]) >= 2 and (best == &"" or int(counts[id]) > int(counts[best])):
			best = id
	if best == &"":
		return -1
	for i: int in range(deck.size() - 1, -1, -1):
		if deck[i] != null and deck[i].id == best:
			return i
	return -1
