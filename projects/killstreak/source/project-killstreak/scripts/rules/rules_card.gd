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


func _init(p_uid: int = 0, p_card: CardData = null) -> void:
	uid = p_uid
	card = p_card


func id() -> StringName:
	return card.id if card != null else &""
