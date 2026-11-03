# boot.gd
# Purpose: Boot scene. Shows a loading label for one frame, then routes to Title, or first to the
#   playtest consent screen while PlaytestLog still needs an answer (p16 wiring, see
#   documentation/production/p16-playtest-wiring.md; Consent -> PreSurvey once -> Title).
#   Headless runs (tests, exports) never ask, like PlaytestLog never loads a stored consent there.
# Dependencies: SceneRouter, PlaytestLog.
# Author: Mechanics Developer Agent (consent routing: UI/UX Agent, p11)
extends Control

const SCENE_CONSENT: String = "res://scenes/survey/Consent.tscn"

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_status.text = "Loading..."
	# Wait one frame so the label is drawn before the next scene loads.
	await get_tree().process_frame
	SceneRouter.goto_scene(first_scene(get_node_or_null("/root/PlaytestLog"), DisplayServer.get_name() == "headless"))


## Consent screen while the tester hasn't answered yet (not in headless runs), else Title.
static func first_scene(playtest_log: Node, headless: bool) -> String:
	if not headless and playtest_log != null and playtest_log.needs_consent() and ResourceLoader.exists(SCENE_CONSENT):
		return SCENE_CONSENT
	return SceneRouter.SCENE_TITLE
