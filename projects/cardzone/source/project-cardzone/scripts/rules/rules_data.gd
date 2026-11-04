# rules_data.gd
# Purpose: The content one CardZone match is played with, as plain references the node-free
#   rules engine can read: card definitions, the 7 areas (Cover, piles, adjacency, distances),
#   the Zone deck, the Standard pack and the BalanceConfig (every §16.8 tunable). Built from the
#   CardDB autoload for the game (from_card_db) or in memory by tests (from_parts), so the engine
#   never touches a Node or the SceneTree.
# Dependencies: CardData, AreaData, ZoneCardData, StartPackData, BalanceConfig, DataEnums.
# Author: Mechanics Developer Agent
class_name RulesData
extends RefCounted

## Every tunable. A match owns its own copy (MatchState.new_match duplicates it), so the dev
## panel can change the live config without changing a match in progress.
var balance: BalanceConfig = null
## StringName id -> CardData.
var cards: Dictionary = {}
## StringName id -> AreaData.
var areas: Dictionary = {}
## Outer areas 1..6 in ring order, then the Core.
var area_order: Array[StringName] = []
## Every Zone card by number (1..N), including any past the hard end.
var zone_cards: Array[ZoneCardData] = []
## Starting loadout, top first, per hand size: int -> Array[StringName].
var start_packs: Dictionary = {}
## The Hit card's id (health stacks are copies of it).
var hit_id: StringName = &"hit"

var _dist: Dictionary = {}  # StringName -> {StringName: int}


## Builds the match content from the CardDB autoload (or any node with its lookup API).
static func from_card_db(db: Object) -> RulesData:
	var cards_list: Array[CardData] = []
	cards_list.assign(db.call("all_cards"))
	var areas_list: Array[AreaData] = []
	areas_list.assign(db.call("all_areas"))
	var zone_list: Array[ZoneCardData] = []
	zone_list.assign(db.call("all_zone_cards"))
	var balance_cfg: BalanceConfig = db.call("get_balance")
	var packs: Dictionary = {}
	for size: Variant in BalanceConfig.allowed_values(&"hand_size"):
		var pack: StartPackData = db.call("get_start_pack", int(size))
		if pack != null:
			packs[int(size)] = pack.card_ids()
	return from_parts(cards_list, areas_list, zone_list, packs, balance_cfg)


## Builds the content from loose parts (tests build the spec set in memory).
## packs: hand size (int) -> Array of card ids, top first.
static func from_parts(cards_list: Array[CardData], areas_list: Array[AreaData],
		zone_list: Array[ZoneCardData], packs: Dictionary, balance_cfg: BalanceConfig) -> RulesData:
	var d: RulesData = RulesData.new()
	d.balance = balance_cfg if balance_cfg != null else BalanceConfig.new()
	for c: CardData in cards_list:
		if c == null:
			continue
		d.cards[c.id] = c
		if c.is_hit():
			d.hit_id = c.id
	var outer: Array[AreaData] = []
	var core: Array[AreaData] = []
	for a: AreaData in areas_list:
		if a == null:
			continue
		d.areas[a.id] = a
		if a.is_core():
			core.append(a)
		else:
			outer.append(a)
	outer.sort_custom(func(x: AreaData, y: AreaData) -> bool: return x.number < y.number)
	for a: AreaData in outer + core:
		d.area_order.append(a.id)
	d.zone_cards.assign(zone_list.filter(func(z: ZoneCardData) -> bool: return z != null))
	d.zone_cards.sort_custom(func(x: ZoneCardData, y: ZoneCardData) -> bool: return x.number < y.number)
	for size: Variant in packs.keys():
		var ids: Array[StringName] = []
		for id: Variant in packs[size]:
			ids.append(StringName(id))
		d.start_packs[int(size)] = ids
	d._build_distances()
	return d


## A copy that shares the content but owns a duplicate BalanceConfig with overrides applied
## ({key: value}, values typed as BalanceConfig expects). Unknown keys or values outside the
## allowed set are reported in `errors` (and skipped).
func with_balance(overrides: Dictionary = {}, errors: Array = []) -> RulesData:
	var d: RulesData = RulesData.new()
	d.balance = balance.duplicate() as BalanceConfig
	d.cards = cards
	d.areas = areas
	d.area_order = area_order
	d.zone_cards = zone_cards
	d.start_packs = start_packs
	d.hit_id = hit_id
	d._dist = _dist
	for key: Variant in overrides.keys():
		if not d.balance.set_tunable(StringName(key), overrides[key]):
			errors.append("balance %s = %s is not allowed" % [key, overrides[key]])
	return d


func card(id: StringName) -> CardData:
	return cards.get(id)


func area(id: StringName) -> AreaData:
	return areas.get(id)


func has_area(id: StringName) -> bool:
	return areas.has(id)


## Fewest steps between two areas (0 = same); 99 when unknown.
func distance(a: StringName, b: StringName) -> int:
	return int((_dist.get(a, {}) as Dictionary).get(b, 99))


func is_adjacent(a: StringName, b: StringName) -> bool:
	return distance(a, b) == 1


func cover_of(area_id: StringName) -> int:
	var a: AreaData = area(area_id)
	return a.cover if a != null else 0


func is_outer(area_id: StringName) -> bool:
	var a: AreaData = area(area_id)
	return a != null and not a.is_core()


## The Zone card with this number, or null (also null past the hard end).
func zone_card(number: int) -> ZoneCardData:
	if number > balance.zone_hard_end_card:
		return null
	for z: ZoneCardData in zone_cards:
		if z.number == number:
			return z
	return null


## The starting loadout (top first) for the current hand size.
func start_pack() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(start_packs.get(balance.hand_size, start_packs.get(5, [])))
	return ids


func _build_distances() -> void:
	_dist.clear()
	for start: StringName in area_order:
		var dist: Dictionary = {start: 0}
		var queue: Array[StringName] = [start]
		while not queue.is_empty():
			var cur: StringName = queue.pop_front()
			var a: AreaData = area(cur)
			for next: StringName in a.adjacent:
				if areas.has(next) and not dist.has(next):
					dist[next] = int(dist[cur]) + 1
					queue.append(next)
		_dist[start] = dist
