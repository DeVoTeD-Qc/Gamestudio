# pause_menu.gd
# Purpose: Match pause sheet (f03), opened by MENU. A modal over the board with RESUME, a
#   FAST ANIMATIONS toggle (Settings.fast_animations), MIRROR LAYOUT (Settings.mirror_layout,
#   kc-board2: hand tray on the left for left-handed players; applied at once), FORFEIT MATCH (asks first: it counts as
#   a loss) and QUIT TO TITLE (a run stays saved; the match restarts with the same seed next
#   time). It only collects the choice and emits a signal; MatchController acts on it.
#   kc-ui3: CODEX (beside RESUME) opens the card codex over the sheet (codex_view.gd); closing it
#   returns here.
#   kc-juice: SOUND (beside RESET TIPS) opens SOUND · MOTION over the sheet (sound_motion_panel.gd:
#   MASTER / SFX volume, SCREEN SHAKE, REDUCE MOTION); BACK returns here.
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
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
var _codex_button: Button = null
var _codex: Control = null
var _glossary_button: Button = null
var _reset_tips_button: Button = null
var _glossary: Control = null
## kc-cards-impl: Settings > Cards > "Always show all card info" (beside FAST ANIMATIONS).
var _card_info_button: Button = null
## kc-juice: SOUND · MOTION (volumes, screen shake, reduce motion).
var _sound_button: Button = null
var _sound_panel: Control = null
## The width MIRROR LAYOUT gives up so the row with SOUND is no wider than the others.
const SOUND_ROOM: float = 140.0
const SoundMotionPanel: GDScript = preload("res://scripts/ui/sound_motion_panel.gd")

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
	# kc-ui-wire2: the kit's modal plate and red danger plates (code look without the kit).
	KitTheme.style_panel(get_node_or_null(^"Center/Box") as Control, &"pnl_modal")
	for b: Button in [_forfeit, _quit, _forfeit_yes]:
		KitTheme.style_button(b, &"btn_danger")
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_fast.toggled.connect(_on_fast_toggled)
	_mirror.toggled.connect(_on_mirror_toggled)
	_forfeit.pressed.connect(_ask_forfeit)
	_forfeit_no.pressed.connect(_show_main)
	_forfeit_yes.pressed.connect(func() -> void: forfeit_confirmed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())
	# kc-ui3: RESUME and CODEX share the first row (the phone sheet has no room for a 6th row).
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ResumeRow"
	row.add_theme_constant_override(&"separation", 8)
	_main.add_child(row)
	_main.move_child(row, _resume.get_index())
	_main.remove_child(_resume)
	row.add_child(_resume)
	_resume.owner = self  # keeps %ResumeButton resolvable after the move
	_resume.unique_name_in_owner = true
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_button = Button.new()
	_codex_button.name = "CodexButton"
	_codex_button.text = "CODEX"
	_codex_button.theme_type_variation = &"HudButton"
	_codex_button.tooltip_text = "Browse every card and killstreak"
	_codex_button.custom_minimum_size = Vector2(140, 64)
	_codex_button.focus_mode = Control.FOCUS_ALL
	_codex_button.add_to_group(&"tap_target")
	_codex_button.pressed.connect(open_codex)
	row.add_child(_codex_button)
	# kc-ui4: GLOSSARY (every keyword, synergy icon and stat mark) beside CODEX.
	_glossary_button = Button.new()
	_glossary_button.name = "GlossaryButton"
	_glossary_button.text = "GLOSSARY"
	_glossary_button.theme_type_variation = &"HudButton"
	_glossary_button.tooltip_text = "Every keyword and icon"
	_glossary_button.custom_minimum_size = Vector2(150, 64)
	_glossary_button.focus_mode = Control.FOCUS_ALL
	_glossary_button.add_to_group(&"tap_target")
	_glossary_button.pressed.connect(open_glossary)
	row.add_child(_glossary_button)
	# kc-onboard-ui (§5.1): RESET TIPS beside MIRROR LAYOUT: every "New: X" explainer shows again and
	# the systems hide until met (Settings.reset_tips).
	var row2: HBoxContainer = HBoxContainer.new()
	row2.name = "MirrorRow"
	row2.add_theme_constant_override(&"separation", 8)
	_main.add_child(row2)
	_main.move_child(row2, _mirror.get_index())
	_main.remove_child(_mirror)
	row2.add_child(_mirror)
	_mirror.owner = self
	_mirror.unique_name_in_owner = true
	_reset_tips_button = Button.new()
	_reset_tips_button.name = "ResetTipsButton"
	_reset_tips_button.text = "RESET TIPS"
	_reset_tips_button.theme_type_variation = &"HudButton"
	_reset_tips_button.tooltip_text = "Show the one-time \"New:\" tips again"
	_reset_tips_button.custom_minimum_size = Vector2(150, 64)
	_reset_tips_button.focus_mode = Control.FOCUS_ALL
	_reset_tips_button.add_to_group(&"tap_target")
	_reset_tips_button.pressed.connect(reset_tips)
	row2.add_child(_reset_tips_button)
	# kc-juice: SOUND · MOTION beside RESET TIPS (the phone sheet has no room for another row).
	_sound_button = Button.new()
	_sound_button.name = "SoundButton"
	_sound_button.text = "SOUND"
	_sound_button.theme_type_variation = &"HudButton"
	_sound_button.tooltip_text = "Volume, screen shake, reduce motion"
	_sound_button.custom_minimum_size = Vector2(120, 64)
	_sound_button.focus_mode = Control.FOCUS_ALL
	_sound_button.add_to_group(&"tap_target")
	_sound_button.pressed.connect(open_sound)
	row2.add_child(_sound_button)
	_mirror.custom_minimum_size.x = _mirror.custom_minimum_size.x - SOUND_ROOM
	# kc-cards-impl: CARDS · ALL INFO beside FAST ANIMATIONS (Settings.show_all_card_info).
	var row3: HBoxContainer = HBoxContainer.new()
	row3.name = "FastRow"
	row3.add_theme_constant_override(&"separation", 8)
	_main.add_child(row3)
	_main.move_child(row3, _fast.get_index())
	_main.remove_child(_fast)
	row3.add_child(_fast)
	_fast.owner = self
	_fast.unique_name_in_owner = true
	_fast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_info_button = Button.new()
	_card_info_button.name = "CardInfoButton"
	_card_info_button.toggle_mode = true
	_card_info_button.theme_type_variation = &"HudButton"
	_card_info_button.tooltip_text = "Show cost and stats on every board card"
	_card_info_button.custom_minimum_size = Vector2(150, 64)
	_card_info_button.focus_mode = Control.FOCUS_ALL
	_card_info_button.add_to_group(&"tap_target")
	_card_info_button.toggled.connect(_on_card_info_toggled)
	row3.add_child(_card_info_button)
	_update_card_info_text()


## RESET TIPS: Settings.reset_tips() (every explainer again; systems hide until met).
func reset_tips() -> void:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null and st.has_method(&"reset_tips"):
		st.reset_tips()
	_reset_tips_button.text = "TIPS RESET"


func get_reset_tips_button() -> Button:
	return _reset_tips_button


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
	if _reset_tips_button != null:
		_reset_tips_button.text = "RESET TIPS"
	_update_mirror_text()
	_card_info_button.set_pressed_no_signal(settings != null and bool(settings.get(&"show_all_card_info")))
	_update_card_info_text()
	_show_main()
	show()


func close() -> void:
	if get_sound_panel() != null:
		_sound_panel.close()
	if get_codex() != null:
		_codex.close()
	if get_glossary() != null:
		_glossary.close()
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
	_resume.custom_minimum_size.x = w - 148.0
	_mirror.custom_minimum_size.x = w - SOUND_ROOM
	for b: Button in [_forfeit_yes, _forfeit_no]:
		b.custom_minimum_size = Vector2(176 if compact else 196, 64)


## Esc: back out of the confirmation, else resume.
func back() -> void:
	if get_codex() != null or get_glossary() != null or get_sound_panel() != null:
		return  # the codex / glossary / sound panel handles Esc itself
	if _confirm.visible:
		_show_main()
	else:
		resume_pressed.emit()


## kc-ui3: opens the codex over the sheet (and the match).
func open_codex() -> Control:
	if _codex != null and is_instance_valid(_codex):
		return _codex
	_codex = CodexView.open_over(self)
	_codex.closed.connect(func() -> void:
		_codex = null
		if visible:
			_resume.grab_focus())
	return _codex


## kc-juice: SOUND · MOTION over the sheet.
func open_sound() -> Control:
	if get_sound_panel() != null:
		return _sound_panel
	_sound_panel = SoundMotionPanel.open_over(self)
	_sound_panel.closed.connect(func() -> void:
		_sound_panel = null
		if visible and _sound_button != null:
			_sound_button.grab_focus())
	return _sound_panel


func get_sound_panel() -> Control:
	return _sound_panel if _sound_panel != null and is_instance_valid(_sound_panel) and not _sound_panel.is_queued_for_deletion() else null


func get_sound_button() -> Button:
	return _sound_button


func get_codex() -> Control:
	return _codex if _codex != null and is_instance_valid(_codex) else null


## kc-ui4: the glossary over the sheet (and the match).
func open_glossary() -> Control:
	if _glossary != null and is_instance_valid(_glossary):
		return _glossary
	_glossary = (load("res://scripts/ui/codex/glossary.gd") as GDScript).call(&"open_over", self, &"")
	_glossary.closed.connect(func() -> void:
		_glossary = null
		_glossary_button.grab_focus())
	return _glossary


func get_glossary() -> Control:
	return _glossary if _glossary != null and is_instance_valid(_glossary) else null


func get_glossary_button() -> Button:
	return _glossary_button


func get_codex_button() -> Button:
	return _codex_button


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


func _on_card_info_toggled(on: bool) -> void:
	_update_card_info_text()
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.set_value(&"show_all_card_info", on)


func _update_card_info_text() -> void:
	_card_info_button.text = "ALL CARD INFO: %s" % ("ON" if _card_info_button.button_pressed else "OFF")


func get_card_info_button() -> Button:
	return _card_info_button


func _update_mirror_text() -> void:
	_mirror.text = "MIRROR LAYOUT: %s" % ("ON" if _mirror.button_pressed else "OFF")
