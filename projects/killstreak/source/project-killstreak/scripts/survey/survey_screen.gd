# survey_screen.gd
# Purpose: Base for the playtest screens (consent, pre-survey, end survey; p16). Each screen
#   is a full-screen Control that emits `finished` and then, if next_scene is set, routes
#   there through SceneRouter. Embed one as an overlay by clearing next_scene and listening
#   to `finished` instead. Styling comes from the project theme (hud_theme.tres) only.
#   Phone rules (README): text >= 16 px and tap targets >= 64 px tall at the 540 px base,
#   which is >= 11.6 pt and >= 46 pt on an 844x390 iPhone.
# Dependencies: PlaytestLog, SceneRouter, EventBus (autoloads, looked up by path).
# Author: Data Scientist Agent
extends Control

signal finished

const SCENE_CONSENT: String = "res://scenes/survey/Consent.tscn"
const SCENE_PRE_SURVEY: String = "res://scenes/survey/PreSurvey.tscn"
const SCENE_END_SURVEY: String = "res://scenes/survey/EndSurvey.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"

## Scene to open when this screen is done ("" = only emit `finished`).
@export_file("*.tscn") var next_scene: String = SCENE_TITLE


func playtest_log() -> Node:
	return get_node_or_null("/root/PlaytestLog")


## Tells PlaytestLog which screen or step is showing (for quit(screen)).
func announce(screen: StringName) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("screen_shown"):
		bus.screen_shown.emit(screen)


func finish(scene: String = next_scene) -> void:
	finished.emit()
	if scene == "" or not is_inside_tree():
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(scene)
