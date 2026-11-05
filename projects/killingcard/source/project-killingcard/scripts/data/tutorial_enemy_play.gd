# tutorial_enemy_play.gd
# Purpose: One scripted enemy play of the tutorial match (p15), embedded in
#   TutorialScript.enemy_plays. The enemy commits it at the start of `round_number`'s Deploy
#   (before the player acts), like the AI would. card = null places the enemy Operator.
# Dependencies: CardData, DataValidator.
# Author: UI/UX Agent (p15)
class_name TutorialEnemyPlay
extends Resource

@export_range(1, 8) var round_number: int = 1
## Unit card to deploy (taken from the enemy hand, or pulled from its deck if not drawn yet).
## Null = place the enemy Operator.
@export var card: CardData = null
## Zone 0 = Left, 1 = Mid, 2 = Right.
@export_range(0, 2) var zone: int = 0


func validate(v: DataValidator, prefix: String, round_cap: int) -> void:
	v.check_range(prefix + ".round_number", round_number, 1, round_cap)
	v.check_range(prefix + ".zone", zone, 0, 2)
	if card != null:
		v.check_unit_ref(prefix + ".card", card)
