# title.gd
# Purpose: Title screen (p11). CONTINUE RUN (only when a save exists) loads it and opens the screen
#   for its phase; if the save can't be loaded, RunState moves it aside and the notice shows
#   RunState.last_load_warning. START NEW RUN starts a fresh run and opens the Loadout; with a
#   save on disk it first asks to replace it (REPLACE / KEEP IT), so one stray tap never loses a run.
#   TUTORIAL opens the p15 drill (scenes/tutorial/Tutorial.tscn). First launch (the drill was
#   never completed or skipped, and no run is saved) also shows "New here? Play the 3-minute
#   drill." with PLAY DRILL / NOT NOW; NOT NOW records a skip so it is not offered again.
# Dependencies: run_screen.gd, RunState, SceneRouter (via RunFlow), tutorial_progress.gd.
# Author: Mechanics Developer Agent (placeholder); run flow: UI/UX Agent (p11)
extends "res://scripts/ui/run/run_screen.gd"

const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const SCENE_TUTORIAL: String = "res://scenes/tutorial/Tutorial.tscn"

@onready var _column: VBoxContainer = %Column
@onready var _continue_button: Button = %ContinueButton
@onready var _start_button: Button = %StartButton
@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _replace_button: Button = %ReplaceButton
@onready var _keep_button: Button = %KeepButton
@onready var _warning_panel: PanelContainer = %WarningPanel
@onready var _warning_label: Label = %WarningLabel
@onready var _tutorial_button: Button = %TutorialButton
@onready var _offer_panel: PanelContainer = %OfferPanel
@onready var _play_drill_button: Button = %PlayDrillButton
@onready var _not_now_button: Button = %NotNowButton


func screen_id() -> StringName:
	return &"title"


func _build() -> void:
	# Marker line for the web load-time check (qa/performance-logs/web-load.md).
	print("Title: ready")
	_continue_button.pressed.connect(_on_continue_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_replace_button.pressed.connect(_start_new_run)
	_keep_button.pressed.connect(_hide_confirm)
	_tutorial_button.pressed.connect(open_tutorial)
	_play_drill_button.pressed.connect(open_tutorial)
	_not_now_button.pressed.connect(_on_not_now_pressed)
	refresh()


## Re-reads the save state (tests call it after changing the save).
func refresh() -> void:
	var rs: Node = RunFlow.run_state()
	_continue_button.visible = rs != null and rs.has_save()
	_confirm_panel.hide()
	_show_warning(rs.last_load_warning if rs != null else "")
	_offer_panel.visible = TutorialProgress.should_offer() and not (rs != null and rs.has_save())
	if _offer_panel.visible:
		_play_drill_button.grab_focus.call_deferred()
	elif _continue_button.visible:
		_continue_button.grab_focus.call_deferred()
	else:
		_start_button.grab_focus.call_deferred()


func _apply_compact() -> void:
	var h: float = button_height()
	_continue_button.custom_minimum_size.y = h
	_start_button.custom_minimum_size.y = h
	_tutorial_button.custom_minimum_size.y = h
	_column.add_theme_constant_override(&"separation", 10 if compact else 14)


func _on_continue_pressed() -> void:
	var rs: Node = RunFlow.run_state()
	if rs.continue_run():
		goto(RunFlow.scene_for(rs.run))
		return
	_continue_button.hide()
	_show_warning(rs.last_load_warning if rs.last_load_warning != "" else "No saved run was found.")
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	var rs: Node = RunFlow.run_state()
	if rs.has_save() and not _confirm_panel.visible:
		_confirm_panel.show()
		_keep_button.grab_focus()
		return
	_start_new_run()


func _start_new_run() -> void:
	var rs: Node = RunFlow.run_state()
	rs.start_run()
	goto(RunFlow.SCENE_LOADOUT)


func _hide_confirm() -> void:
	_confirm_panel.hide()
	_start_button.grab_focus()


func _show_warning(text: String) -> void:
	_warning_label.text = text
	_warning_panel.visible = text != ""


## TUTORIAL / PLAY DRILL: opens the p15 drill.
func open_tutorial() -> void:
	goto(SCENE_TUTORIAL)


## True while the first-launch drill offer is on screen.
func is_offering_tutorial() -> bool:
	return _offer_panel.visible


func _on_not_now_pressed() -> void:
	TutorialProgress.record(false, 0)
	_offer_panel.hide()
	_start_button.grab_focus()
