# area_data.gd
# Purpose: One area card of Ridge Hollow (spec §3, §8): number, tier (outer / Core), Cover,
#   neighbours and loot piles. One area = one .tres in res://data/areas/.
#   Neighbours are listed by id (not by reference) so two areas never reference each other in
#   a loop. CardDB checks the whole map in its cross checks: 7 areas, one Core, adjacency
#   mutual, map connected, every distance within RNG 2, each pile card in one area only.
# Dependencies: DataEnums, CardData, DataValidator.
# Author: Mechanics Developer Agent
class_name AreaData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. radio_hill).
@export var id: StringName = &""
@export var display_name: String = ""
## Map number: outer areas 1-6 (ring order), the Core 0.
@export_range(0, 9) var number: int = 0
## OUTER or CORE. Sets the pile size (BalanceConfig.pile_size_outer / _core) and the rarity tier
## of its piles (outer: Common, Uncommon; Core: Rare).
@export var tier: DataEnums.AreaTier = DataEnums.AreaTier.OUTER

@export_group("Map (spec §3)")
## Cover: shots from another area at a target here deal this much less (0-2; spec uses 0 and 1).
@export_range(0, 2) var cover: int = 0
## Ids of the adjacent areas. Adjacency must be mutual (if A lists B, B lists A).
@export var adjacent: Array[StringName] = []

@export_group("Loot (spec §3)")
## One entry per loot pile, in printed order. Each pile holds pile_size copies of that card.
@export var piles: Array[CardData] = []

@export_group("Art")
## Key the map art uses. Defaults to the id when empty.
@export var art_key: StringName = &""


func is_core() -> bool:
	return tier == DataEnums.AreaTier.CORE


## Cards per pile here under the given balance.
func pile_size(balance: BalanceConfig) -> int:
	return balance.pile_size_for(tier)


func is_adjacent_to(area_id: StringName) -> bool:
	return adjacent.has(area_id)


## "1".."6", or "C" for the Core (map labels).
func label() -> String:
	return "C" if is_core() else str(number)


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_line("display_name", display_name, 24)
	if v.check_enum("tier", tier, DataEnums.AreaTier):
		if is_core():
			if number != 0:
				v.invalid("number", "the Core is number 0 (got %d)" % number)
		else:
			v.check_range("number", number, 1, DataEnums.MAP_AREA_COUNT - 1)
	v.check_range("cover", cover, 0, DataEnums.MAX_COVER)
	# Adjacency: known areas, not itself, no repeats. Mutual and connected: CardDB cross check.
	if adjacent.is_empty():
		v.add(DataValidator.MAP_RULE, "adjacent", "an area needs at least one neighbour")
	var seen: Dictionary = {}
	for i: int in adjacent.size():
		var field: String = "adjacent[%d]" % i
		var other: StringName = adjacent[i]
		if other == id:
			v.add(DataValidator.MAP_RULE, field, "an area can't be adjacent to itself")
			continue
		if seen.has(other):
			v.invalid(field, "'%s' is listed twice" % other)
			continue
		seen[other] = true
		v.check_id_ref(field, other, AreaData)
	# Piles: loaded loot cards, at most one pile per card here.
	if piles.is_empty():
		v.warn(DataValidator.MISSING_FIELD, "piles", "no loot piles yet (cz06 adds them)")
	elif v.check_ref_array("piles", piles, CardData, 0, 8):
		var allowed: Array = DataEnums.PILE_RARITIES.get(tier, [])
		for i: int in piles.size():
			var card: CardData = piles[i]
			var field: String = "piles[%d]" % i
			if card.supply_drop:
				v.invalid(field, "'%s' is a supply drop; drops land from Zone cards, not piles" % card.id)
			elif not card.is_loot():
				v.invalid(field, "'%s' (%s) can't be looted; piles hold Common to Legendary cards"
						% [card.id, DataEnums.key_of(DataEnums.Rarity, card.rarity)])
			elif not allowed.has(card.rarity):
				v.warn(DataValidator.INVALID_VALUE, field, "'%s' is %s; %s areas usually hold %s" % [
						card.id, DataEnums.key_of(DataEnums.Rarity, card.rarity),
						DataEnums.key_of(DataEnums.AreaTier, tier),
						", ".join(allowed.map(func(r: int) -> String: return DataEnums.key_of(DataEnums.Rarity, r)))])
