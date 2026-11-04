# test_tempo_ui.gd
# Purpose: cc06 Tempo on the duel screen: the first player's counter shows a "TEMPO +N" tag
#   (the score already includes the bonus, WallRules.score), the other counter doesn't, and the
#   tag follows first_player and the bonus (0 = hidden). Default bonus comes from balance.tres.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"


func _tags(duel: Control) -> Array:
	var out: Array = []
	for c: Control in duel.get_counters():
		var l: Label = c.get_tempo_label()
		out.append(l.text if l.visible else "")
	return out


func test_tempo_tag_on_first_player_counter() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	DuelControllerScript.set_autostart(false)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	viewport.add_child(duel)
	DuelControllerScript.set_autostart(true)
	await tree.process_frame
	var state: Dictionary = MockDuelData.start_state()
	state["first_player"] = &"player"
	duel.show_state(state)
	var data_bonus: int = tree.root.get_node("CardDB").get_balance().first_player_bonus
	assert_eq(data_bonus, 2, "balance.tres Tempo")
	assert_eq(_tags(duel), ["TEMPO +2", ""], "player first: tag on the player counter (from balance data)")
	state = state.duplicate(true)
	state["first_player"] = &"rival"
	duel.show_state(state)
	assert_eq(_tags(duel), ["", "TEMPO +2"], "rival first: tag on the rival counter")
	state["first_player_bonus"] = 0
	duel.show_state(state)
	assert_eq(_tags(duel), ["", ""], "bonus 0: no tag")
	viewport.queue_free()
	await tree.process_frame
