# triptych_data.gd
# Purpose: A hidden 3-card combination (spec §4.5, §5, §5.1). Scores triptych_bonus when its three
#   cards, all controlled by one player, sit in three consecutive slots of one row; the first time
#   it reveals a panorama strip and grants a cosmetic title (and optionally a frame).
#   One Triptych = one .tres in res://data/triptychs/.
# Dependencies: CardData, DataValidator.
# Author: Mechanics Developer Agent
class_name TriptychData
extends Resource

const CARD_COUNT: int = 3

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. midnight_run).
@export var id: StringName = &""
@export var display_name: String = ""
## Exactly 3 distinct cards.
@export var cards: Array[CardData] = []
## Cryptic hint on the album's "???" slot.
@export var hint: String = ""

@export_group("Reward (cosmetic only)")
## Title granted on the first score (e.g. "Night Owl+").
@export var reward_title: String = ""
## Optional frame id granted on the first score (e.g. gold_cipher). Empty = none.
@export var reward_frame: StringName = &""
## Key of the panorama strip the art kit draws for the reveal.
@export var panorama_key: StringName = &""


func has_card(card: CardData) -> bool:
	return cards.has(card)


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_ref_array("cards", cards, CardData, CARD_COUNT, CARD_COUNT)
	v.require_text("hint", hint)
	v.check_line("hint", hint, 80)
	v.require_text("reward_title", reward_title)
	v.check_line("reward_title", reward_title, 32)
	if String(panorama_key).is_empty():
		v.missing("panorama_key", "panorama_key is empty (the reveal needs a panorama strip)")
