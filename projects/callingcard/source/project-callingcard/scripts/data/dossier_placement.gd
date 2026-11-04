# dossier_placement.gd
# Purpose: One card on a Dossier wall: a pre-placed card, a scripted rival reply, or one step
#   of the known solution (spec §5.2, plan cc12). Lives inside a DossierData file (sub-resource).
# Dependencies: DataEnums, CardData, BalanceConfig (via DataValidator), DataValidator.
# Author: Mechanics Developer Agent
class_name DossierPlacement
extends Resource

## Wall slot id: a1 a2 a3 / b1 b2 b3 b4 / c1 c2 c3 (spec §4.1).
@export var slot: StringName = &""
@export var card: CardData = null
## Who controls the card. Solution steps are always PLAYER.
@export var side: DataEnums.Side = DataEnums.Side.RIVAL
## Pre-placed Ambush card still face-down (Ambush cards only).
@export var face_down: bool = false
## This card is its side's Signature (counts double).
@export var is_signature: bool = false
## Cipher cards only: the adjacent slot whose trait the card copies (spec §4.4 "your pick").
## &"" = no pick (non-Cipher cards, or a Cipher with no neighbour). Used by solution steps (cc12).
@export var copy_from: StringName = &""


func validate(v: DataValidator, field: String) -> void:
	if not v.balance.is_slot(slot):
		v.invalid(field + ".slot", "'%s' is not a wall slot (%s)" % [slot, ", ".join(PackedStringArray(v.balance.slot_ids()))])
	v.check_ref(field + ".card", card, CardData, true)
	v.check_enum(field + ".side", side, DataEnums.Side)
	if face_down and card != null and card is CardData and card.card_trait() != DataEnums.CardTrait.AMBUSH:
		v.invalid(field + ".face_down", "only Ambush cards can be face-down ('%s' isn't)" % card.id)
