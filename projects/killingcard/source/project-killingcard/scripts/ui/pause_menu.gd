# pause_menu.gd
# Purpose: Match pause sheet (f03), opened by MENU. A modal over the board with RESUME, a
#   FAST ANIMATIONS toggle (Settings.fast_animations), MIRROR LAYOUT (Settings.mirror_layout,
#   kc-board2: hand tray on the left for left-handed players; applied at once), FORFEIT MATCH (asks first: it counts as
#   a loss) and QUIT TO TITLE (a run stays saved; the match restarts with the same seed next
#   time). It only collects the choice and emits a signal; MatchController acts on it.
#   The match is not paused underneath (no get_tree().paused): the sheet blocks taps, and a
#   round that is already playing finishes behind it.
#   Phone sizes: every text >= 16 px and every tap target >= 64 px tall.
# Scene: res://scenes/match/PauseMenu.tscn (full-rect, hidden until open()).
# Dependencies: Settings (fast_animations), hud_theme.tres variations (Scrim, HudPanelDark,
#   HudHeader, HudSubtle, ReadyButton, HudButton, KillstreakButton).
# Author: Mechanics Developer Agent (f03)
extends Control

signal resume_pressed
signal fast_animations_toggled(enabled: bool)
## FORFEIT MATCH, then FORFEIT in the confirmation.
signal forfeit_confirmed
signal quit_pressed

var compact: bool = false

@onready var _title: Label = %PauseTitle
@onready var _hint: Label = %PauseHint
@onready var _main: VBoxContainer = %MainButtons
@onready var _confirm: VBoxContainer = %ConfirmBox
@onready var _confirm_hint: Label = %ConfirmHint
@onready var _resume: Button = %ResumeButton
@onready var _fast: Button = %FastButton
@onready var _mirror: Button = %MirrorButton
@onready var _forfeit: Button = %ForfeitButton
@onready var _quit: Button = %QuitButton
@onready var _forfeit_yes: Button = %ForfeitYesButton
@onready var _forfeit_no: Button = %ForfeitNoButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_fast.toggled.connect(_on_fast_toggled)
	_mirror.toggled.connect(_on_mirror_toggled)
	_forfeit.pressed.connect(_ask_forfeit)
	_forfeit_no.pressed.connect(_show_main)
	_forfeit_yes.pressed.connect(func() -> void: forfeit_confirmed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())


## info: {context ("MATCH 1 OF 5 · ROUND 3"), hint (what QUIT does), can_forfeit,
## forfeit_hint (what a forfeit costs), fast_animations (bool)}.
func open(info: Dictionary = {}) -> void:
	_title.text = "PAUSED"
	var ctx: String = String(info.get("context", ""))
	if ctx != "":
		_title.text = "PAUSED  ·  %s" % ctx
	_hint.text = String(info.get("hint", ""))
	_hint.visible = _hint.text != ""
	_confirm_hint.text = String(info.get("forfeit_hint", "Forfeit? It counts as a loss."))
	_forfeit.visible = bool(info.get("can_forfeit", true))
	_fast.set_pressed_no_signal(bool(info.get("fast_animations", false)))
	_update_fast_text()
	var settings: Node = get_node_or_null(^"/root/Settings")
	_mirror.set_pressed_no_signal(settings != null and bool(settings.get(&"mirror_layout")))
	_update_mirror_text()
	_show_main()
	show()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func is_confirming() -> bool:
	return visible and _confirm.visible


func set_compact(value: bool) -> void:
	compact = value
	var w: float = 360.0 if compact else 400.0
	for b: Button in [_resume, _fast, _mirror, _forfeit, _quit]:
		b.custom_minimum_size = Vector2(w, 64)
	for b: Button in [_forfeit_yes, _forfeit_no]:
		b.custom_minimum_size = Vector2(176 if compact else 196, 64)


## Esc: back out of the confirmation, else resume.
func back() -> void:
	if _confirm.visible:
		_show_main()
	else:
		resume_pressed.emit()


func get_resume_button() -> Button:
	return _resume


func get_fast_button() -> Button:
	return _fast


func get_mirror_button() -> Button:
	return _mirror


func get_forfeit_button() -> Button:
	return _forfeit


func get_forfeit_confirm_button() -> Button:
	return _forfeit_yes


func get_forfeit_cancel_button() -> Button:
	return _forfeit_no


func get_quit_button() -> Button:
	return _quit


func _ask_forfeit() -> void:
	_main.hide()
	_confirm.show()


func _show_main() -> void:
	_confirm.hide()
	_main.show()


func _on_fast_toggled(on: bool) -> void:
	_update_fast_text()
	fast_animations_toggled.emit(on)


func _update_fast_text() -> void:
	_fast.text = "FAST ANIMATIONS: %s" % ("ON" if _fast.button_pressed else "OFF")


func _on_mirror_toggled(on: bool) -> void:
	_update_mirror_text()
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.set_value(&"mirror_layout", on)


func _update_mirror_text() -> void:
	_mirror.text = "MIRROR LAYOUT: %s" % ("ON" if _mirror.button_pressed else "OFF")
