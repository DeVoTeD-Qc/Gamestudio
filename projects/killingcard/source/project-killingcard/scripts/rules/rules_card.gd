# rules_card.gd
# Purpose: One physical card instance in a match (deck, hand, discard, board).
#   Copies of the same CardData get different uids. A unit on the board keeps its
#   card's uid, so killfeed, discard pile and intents all speak the same id.
# Dependencies: CardData.
# Author: Mechanics Developer Agent
class_name RulesCard
extends RefCounted

var uid: int = 0
var card: CardData = null
## Per-copy level (kc-syn §5.2, SynergyRules.LEVEL_*): 0 Recruit (no neighbor keyword, no trait),
## 1 Trained (the full chassis), 2 Veteran (+1 Armor), 3 Elite (+1 Armor, +1 FP).
var level: int = SynergyRules.LEVEL_TRAINED


func _init(p_uid: int = 0, p_card: CardData = null, p_level: int = SynergyRules.LEVEL_TRAINED) -> void:
	uid = p_uid
	card = p_card
	level = p_level


## Neighbor keyword / trait of this copy (none on a Recruit).
func neighbor_keyword() -> StringName:
	return SynergyRules.keyword_at(card, level)


func card_trait() -> StringName:
	return SynergyRules.trait_at(card, level)


func id() -> StringName:
	return card.id if card != null else &""
