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
## kc-art-traits: the trait this copy's art gives it (SideSetup.deck_traits; TRAIT_DEFAULT = the
## chassis' default). Read through card_trait(), which applies the option list. kc-no-training: one
## trait at most, and every copy has its keywords and effects (there are no copy levels).
var chosen_trait: StringName = SynergyRules.TRAIT_DEFAULT


func _init(p_uid: int = 0, p_card: CardData = null, p_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> void:
	uid = p_uid
	card = p_card
	chosen_trait = p_trait


## Neighbor keyword of this copy (retired: always &"").
func neighbor_keyword() -> StringName:
	return SynergyRules.keyword_at(card)


func card_trait() -> StringName:
	return SynergyRules.trait_at(card, chosen_trait)


## Arrives at the front of the line (Shieldman).
func arrives_front() -> bool:
	return card != null and card.arrives_front


func id() -> StringName:
	return card.id if card != null else &""
