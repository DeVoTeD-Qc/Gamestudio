# tutorial_script.gd
# Purpose: The scripted first match (p15, content-log format gap 1). A short Zone Control match
#   on a fixed map against a fixed squad, with a stacked (unshuffled) player draw order, the
#   enemy's plays per round, and the coach steps (TutorialStep) that the TutorialDirector
#   walks through. One file: res://data/tutorial/tutorial_script.tres (CardDB data class).
# Dependencies: DataEnums, CardData, LoadoutItem, SquadData, MapData, TutorialStep,
#   TutorialEnemyPlay, DataValidator.
# Author: UI/UX Agent (p15)
class_name TutorialScript
extends Resource

const MIN_DECK: int = 8
const MAX_DECK: int = 40

@export_group("Identity")
## Unique id, lowercase snake_case (tutorial_basic).
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Match")
@export var squad: SquadData = null
@export var map: MapData = null
@export var mode: DataEnums.GameMode = DataEnums.GameMode.ZONE_CONTROL
## The match always ends at the end of this round (no overtime: a tie is a draw).
@export_range(1, 8) var round_cap: int = 4
## Points that win early. Set high so the match runs to round_cap.
@export_range(1, 99) var score_target: int = 20
## Match seed. Draws are stacked, so it only feeds tie-breaks and reshuffles.
@export var seed_value: int = 15

@export_group("Player")
## Drawn in this order (deck[0] first): Round 1 draws the opening hand + 1, then 2 per round.
@export var player_deck: Array[CardData] = []
## Empty = the run config's starter killstreaks.
@export var player_killstreaks: Array[LoadoutItem] = []

@export_group("Enemy")
## Drawn in this order. Empty = the squad's deck in list order.
@export var enemy_deck: Array[CardData] = []
@export var enemy_plays: Array[TutorialEnemyPlay] = []

@export_group("Coach")
@export var steps: Array[TutorialStep] = []


## Scripted enemy plays of one round, in list order.
func plays_for_round(round_number: int) -> Array[TutorialEnemyPlay]:
	var out: Array[TutorialEnemyPlay] = []
	for p: TutorialEnemyPlay in enemy_plays:
		if p != null and p.round_number == round_number:
			out.append(p)
	return out


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_ref("squad", squad, SquadData, true)
	v.check_ref("map", map, MapData, true)
	v.check_enum("mode", mode, DataEnums.GameMode)
	v.check_range("round_cap", round_cap, 1, 8)
	v.check_range("score_target", score_target, 1, 99)
	if v.check_ref_array("player_deck", player_deck, CardData, MIN_DECK, MAX_DECK):
		for i: int in player_deck.size():
			if not player_deck[i].collectible:
				v.invalid("player_deck[%d]" % i, "'%s' is a token and can't be in a deck" % player_deck[i].id)
	if not enemy_deck.is_empty():
		v.check_ref_array("enemy_deck", enemy_deck, CardData, MIN_DECK, MAX_DECK)
	v.check_slot_array("player_killstreaks", player_killstreaks, DataEnums.LoadoutSlot.KILLSTREAK, 0, 3)
	for i: int in enemy_plays.size():
		if enemy_plays[i] == null:
			v.broken_reference("enemy_plays[%d]" % i, "empty slot")
		else:
			enemy_plays[i].validate(v, "enemy_plays[%d]" % i, round_cap)
	if steps.is_empty():
		v.missing("steps", "a tutorial needs at least one step")
	for i: int in steps.size():
		var s: TutorialStep = steps[i]
		if s == null:
			v.broken_reference("steps[%d]" % i, "empty slot")
			continue
		if s.index != i + 1:
			v.invalid("steps[%d].index" % i, "is %d, expected %d (1-based, in order)" % [s.index, i + 1])
		if s.round_number > round_cap:
			v.out_of_range("steps[%d].round_number" % i, "%d is after round_cap %d" % [s.round_number, round_cap])
		if i > 0 and steps[i - 1] != null and s.round_number < steps[i - 1].round_number:
			v.invalid("steps[%d].round_number" % i, "steps must be in round order")
		s.validate(v, "steps[%d]" % i)
	if not steps.is_empty() and steps.back() != null and steps.back().advance_on != &"match_end":
		v.invalid("steps[%d].advance_on" % (steps.size() - 1), "the last step must advance on match_end")
