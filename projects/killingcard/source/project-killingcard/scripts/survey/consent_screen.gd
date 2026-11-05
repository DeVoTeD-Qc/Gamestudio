# consent_screen.gd
# Purpose: Playtest consent (p16). Explains in plain words what the anonymous log holds and
#   asks yes / no. Yes turns PlaytestLog on and goes to the pre-survey (once per device);
#   no keeps logging off and goes on. Show it when PlaytestLog.needs_consent() is true.
# Dependencies: survey_screen.gd, PlaytestLog.
# Author: Data Scientist Agent
extends "res://scripts/survey/survey_screen.gd"

## Opened after "yes" while the pre-survey is still unanswered ("" = skip it).
@export_file("*.tscn") var pre_survey_scene: String = SCENE_PRE_SURVEY

@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton
@onready var _session_label: Label = %SessionLabel


func _ready() -> void:
	# Marker line for the web load-time check on a first launch, where Boot opens this screen
	# instead of the Title (qa/performance-logs/web-load.md, p18 bug 002).
	print("Consent: ready")
	_yes_button.pressed.connect(_on_answer.bind(true))
	_no_button.pressed.connect(_on_answer.bind(false))
	var plog: Node = playtest_log()
	if plog != null:
		_session_label.text = "Anonymous session %s  ·  log format v%d" % [plog.session_id, plog.SCHEMA_VERSION]
	_yes_button.grab_focus()


func _on_answer(given: bool) -> void:
	var plog: Node = playtest_log()
	if plog != null:
		plog.set_consent(given)
	if given and plog != null and plog.needs_pre_survey() and pre_survey_scene != "":
		finish(pre_survey_scene)
	else:
		finish()
