# pre_survey.gd
# Purpose: Pre-survey (p16, metrics plan): three yes / no taps that put the tester in a
#   segment (Shooter, Card, Both, Neither). Answers go to PlaytestLog.record_pre_survey.
# Dependencies: survey_screen.gd, PlaytestLog.
# Author: Data Scientist Agent
extends "res://scripts/survey/survey_screen.gd"

const KEYS: Array[String] = ["shooter_weekly", "card_weekly", "deckbuilder"]

## Current answers: key -> bool (missing = not answered yet).
var answers: Dictionary = {}

@onready var _continue_button: Button = %ContinueButton
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	announce(&"pre_survey")
	for i: int in KEYS.size():
		var row: Node = _rows.get_child(i)
		var group: ButtonGroup = ButtonGroup.new()
		var yes: Button = row.get_node("Yes")
		var no: Button = row.get_node("No")
		yes.button_group = group
		no.button_group = group
		yes.pressed.connect(answer.bind(KEYS[i], true))
		no.pressed.connect(answer.bind(KEYS[i], false))
	_continue_button.pressed.connect(submit)
	_refresh()


## Sets one answer (also what a tap does).
func answer(key: String, value: bool) -> void:
	answers[key] = value
	var row: Node = _rows.get_child(KEYS.find(key))
	mark_selected(row.get_node("Yes"), value)
	mark_selected(row.get_node("No"), not value)
	_refresh()


func is_complete() -> bool:
	return answers.size() == KEYS.size()


func submit() -> void:
	if not is_complete():
		return
	var plog: Node = playtest_log()
	if plog != null:
		plog.record_pre_survey(answers["shooter_weekly"], answers["card_weekly"], answers["deckbuilder"])
	finish()


func _refresh() -> void:
	_continue_button.disabled = not is_complete()
	if is_complete():
		_continue_button.grab_focus()
