# placed_card.gd
# Purpose: One card instance on the wall. Tracks the instance, not the card id (RQ-15: both
#   players may bring the same card): whose lineup it came from (fixed), who controls it now,
#   face-down state, Signature flag, its active trait (a Cipher's copied trait, RQ-01) and a
#   pending Ambush spring.
# Dependencies: CardData, DataEnums.
# Author: Mechanics Developer Agent
class_name PlacedCard
extends RefCounted

var card: CardData
## Player whose lineup the card came from (WallState.P1 / P2). Never changes.
var lineup: int = 0
## Player who controls it now.
var controller: int = 0
## Face-down Ambush (can't be captured, captures nothing until it springs).
var face_down: bool = false
var signature: bool = false
## Printed trait, or for a placed Cipher card the copied trait (NONE when nothing was copied).
var active_trait: DataEnums.CardTrait = DataEnums.CardTrait.NONE
## Ambush spring still to resolve (face-down Ambush, or a face-up Cipher holding a copied Ambush).
var spring_pending: bool = false
## Player who placed it; a pending spring is theirs (RQ-04).
var placed_by: int = 0
## Placement order on this wall (springs resolve in this order when the wall fills).
var order: int = 0


static func create(p_card: CardData, p_lineup: int, p_controller: int) -> PlacedCard:
	var pc: PlacedCard = PlacedCard.new()
	pc.card = p_card
	pc.lineup = p_lineup
	pc.controller = p_controller
	pc.placed_by = p_controller
	pc.active_trait = p_card.card_trait()
	return pc


func copy() -> PlacedCard:
	var pc: PlacedCard = PlacedCard.new()
	pc.card = card
	pc.lineup = lineup
	pc.controller = controller
	pc.face_down = face_down
	pc.signature = signature
	pc.active_trait = active_trait
	pc.spring_pending = spring_pending
	pc.placed_by = placed_by
	pc.order = order
	return pc


func printed_trait() -> DataEnums.CardTrait:
	return card.card_trait()


func clearance() -> int:
	return card.clearance


## Printed values as {top, side, bottom}.
func printed_values() -> Dictionary:
	return {WallTopology.TOP: card.top, WallTopology.SIDE: card.side, WallTopology.BOTTOM: card.bottom}


## Printed value by name (&"top", &"side", &"bottom").
func value(name: StringName) -> int:
	match name:
		WallTopology.TOP:
			return card.top
		WallTopology.BOTTOM:
			return card.bottom
	return card.side


func trait_name() -> StringName:
	return StringName(DataEnums.key_of(DataEnums.CardTrait, active_trait).to_lower())


## Plain snapshot for the UI, tests and saves. With `viewer` >= 0, a face-down card the viewer
## doesn't control hides its identity (RQ-19: everyone knows it is an Ambush, not which one).
func to_dict(viewer: int = -1) -> Dictionary:
	var hidden: bool = face_down and viewer >= 0 and viewer != controller
	return {
		"card": &"?" if hidden else card.id,
		"lineup": lineup, "controller": controller, "face_down": face_down,
		"signature": false if hidden else signature,
		"active_trait": &"ambush" if hidden else trait_name(),
		"spring_pending": spring_pending, "order": order,
	}
