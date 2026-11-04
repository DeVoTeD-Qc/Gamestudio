# start_pack_data.gd
# Purpose: A starting loadout order (spec §4 step 5, §10, §16.4): 10 starter cards, top to bottom,
#   and the hand sizes it serves. The Standard pack serves both hand 4 and hand 5 (§16.4: the same
#   order), so the prototype ships one file, res://data/packs/standard_pack.tres.
#   CardDB checks that every allowed hand_size (4, 5) has exactly one pack.
# Dependencies: DataEnums, CardData, BalanceConfig, DataValidator.
# Author: Mechanics Developer Agent
class_name StartPackData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (standard_pack).
@export var id: StringName = &""
@export var display_name: String = ""
## Hand sizes this order is printed for (allowed values of BalanceConfig.hand_size: 4, 5).
@export var hand_sizes: PackedInt32Array = PackedInt32Array([4, 5])

@export_group("Loadout (top -> bottom)")
## The 10 starter cards in loadout order, top first. Repeats are copies (4 Scavenge).
@export var cards: Array[CardData] = []


func serves(hand_size: int) -> bool:
	return hand_sizes.has(hand_size)


## How many copies of a card the pack holds.
func copies_of(card_id: StringName) -> int:
	return cards.filter(func(c: CardData) -> bool: return c != null and c.id == card_id).size()


## Card ids, top first (rules setup and tests).
func card_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for c: CardData in cards:
		result.append(c.id if c != null else &"")
	return result


## The hand a player draws on their first turn when nothing is held (the top hand_size cards).
func opening_hand(hand_size: int) -> Array[CardData]:
	var result: Array[CardData] = []
	result.assign(cards.slice(0, hand_size))
	return result


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_line("display_name", display_name, 32)
	var allowed: Array = BalanceConfig.allowed_values(&"hand_size")
	if hand_sizes.is_empty():
		v.missing("hand_sizes", "list the hand sizes this pack serves (4, 5)")
	for i: int in hand_sizes.size():
		v.check_allowed("hand_sizes[%d]" % i, hand_sizes[i], allowed)
	if v.has_duplicates(Array(hand_sizes)):
		v.invalid("hand_sizes", "a hand size is listed twice")
	if cards.size() != DataEnums.LOADOUT_SIZE:
		v.add(DataValidator.PACK_RULE, "cards", "a starting loadout has %d cards (got %d)" % [DataEnums.LOADOUT_SIZE, cards.size()])
	if not v.check_ref_array("cards", cards, CardData, 0, 99, true):
		return
	var non_hits: int = 0
	for i: int in cards.size():
		var card: CardData = cards[i]
		if not card.is_starter():
			v.add(DataValidator.PACK_RULE, "cards[%d]" % i, "'%s' is not a Starter card" % card.id)
		if not card.is_hit():
			non_hits += 1
	if non_hits < v.balance.min_loadout:
		v.add(DataValidator.PACK_RULE, "cards", "%d non-Hit cards; min_loadout is %d" % [non_hits, v.balance.min_loadout])
