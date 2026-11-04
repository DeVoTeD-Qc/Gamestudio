# title.gd
# Purpose: CardZone Title screen (cz13; replaces the cz03 placeholder).
#   - CONTINUE only when MatchStore has a saved match that replays; it continues that match
#     (SetupLaunch.request_resume -> the match screen -> MatchController.start_resumed). Under it:
#     round, opponent and how long ago it was saved.
#   - NEW MATCH -> Match setup. With no saved match it is the main (light) button.
#   - A save that is damaged, from another version or no longer replayable shows
#     MatchStore.status_text() in a warning plate, and the player starts a new match.
#   - SETTINGS (bottom right; the top-right corner is cz18's PLAYTEST button): reduced motion, event speed, show tips again (pause_menu.gd, settings
#     page only).
#   - Hidden dev panel: press and hold the CardZone logo for 2 s (dev_panel.gd). While any dev
#     override is active a "DEV SETTINGS ACTIVE" tag shows (top left).
#   Prints "Title: ready", the marker web load checks wait for.
# Dependencies: EventBus, MatchStore, SceneRouter, setup_launch.gd, setup_ui.gd, pause_menu.gd,
#   pause_settings.gd, dev_panel.gd, dev_panel_overrides.gd.
# Author: UI/UX Agent (cz13; cz03 placeholder by the Mechanics Developer Agent)
extends Control

const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const PauseMenu: GDScript = preload("res://scripts/ui/pause_menu.gd")
const PauseSettings: GDScript = preload("res://scripts/ui/pause_settings.gd")
const DevPanel: GDScript = preload("res://scripts/ui/dev_panel.gd")
const DevOverrides: GDScript = preload("res://scripts/ui/dev_panel_overrides.gd")

const GAME_TITLE: String = "CardZone"
const SUBTITLE: String = "Prototype build"
## Seconds the logo must be held to open the dev panel.
const LONG_PRESS_S: float = 2.0

## Tests / screenshots: the safe rect in logical px (empty = from the display).
var safe_area_override: Rect2 = Rect2()

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _continue: Button = %ContinueButton
@onready var _continue_info: Label = %ContinueInfo
@onready var _new_match: Button = %NewMatchButton
@onready var _status: Label = %StatusLabel
@onready var _dev_tag: Label = %DevTag
@onready var _settings_button: Button = %SettingsButton
@onready var _version: Label = %VersionLabel
@onready var _safe: MarginContainer = %SafeArea

var _press_started_ms: int = -1
var _dev_panel: Control = null
var _settings: Control = null


func _ready() -> void:
	theme = SetupUI.build_theme()
	_title.text = GAME_TITLE
	_subtitle.text = SUBTITLE
	_version.text = "Prototype · Godot %s" % Engine.get_version_info().get("string", "4")
	PauseSettings.apply_to_settings()
	SetupLaunch.clear_pending()
	_continue.pressed.connect(_on_continue)
	_new_match.pressed.connect(_on_new_match)
	_settings_button.pressed.connect(_on_settings)
	_settings_button.custom_minimum_size = Vector2(160, SetupUI.TAP_PX)
	_title.gui_input.connect(_on_logo_input)
	_title.tooltip_text = ""
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	refresh()
	EventBus.screen_shown.emit(&"title")
	print("Title: ready")


## Re-reads the saved match and the dev overrides.
func refresh() -> void:
	var info: Dictionary = MatchStore.saved_info()
	var has: bool = bool(info.get("has_match", false))
	_continue.visible = has
	_continue_info.visible = has
	_continue_info.text = continue_text(info) if has else ""
	_new_match.theme_type_variation = &"Button" if has else &"DockButton"
	var status: StringName = info.get("status", &"none")
	var bad: bool = not has and status != &"none" and status != &"ok"
	_status.visible = bad
	_status.text = String(info.get("text", "")) if bad else ""
	_dev_tag.visible = DevOverrides.is_active()
	_dev_tag.text = "DEV SETTINGS ACTIVE"
	_dev_tag.tooltip_text = ""
	(_continue if has else _new_match).grab_focus.call_deferred()


## "Round 4 · vs Rookie AI · saved 3 min ago" for the CONTINUE line.
static func continue_text(info: Dictionary) -> String:
	var parts: PackedStringArray = []
	var round_n: Variant = info.get("round")
	parts.append("Drop" if round_n == null or int(round_n) <= 0 else "Round %d" % int(round_n))
	var level: String = String(info.get("ai_level", "")).strip_edges()
	if level == "" and info.get("meta") is Dictionary:
		level = String((info["meta"] as Dictionary).get("ai_level", ""))
	if level != "":
		parts.append("vs %s" % ("placeholder rival" if level == "placeholder" else level.capitalize() + " AI"))
	var saved_at: int = int(info.get("saved_at", 0))
	if saved_at > 0:
		var ago: int = maxi(0, int(Time.get_unix_time_from_system()) - saved_at)
		parts.append("saved " + _ago(ago))
	return " · ".join(parts)


static func _ago(s: int) -> String:
	if s < 60:
		return "just now"
	if s < 3600:
		return "%d min ago" % (s / 60)
	if s < 86400:
		return "%d h ago" % (s / 3600)
	return "%d days ago" % (s / 86400)


func get_dev_panel() -> Control:
	return _dev_panel


func get_settings_menu() -> Control:
	return _settings


func get_buttons() -> Dictionary:
	return {&"continue": _continue, &"new_match": _new_match, &"settings": _settings_button}


func _on_continue() -> void:
	if not MatchStore.has_saved_match():
		refresh()
		return
	SetupLaunch.request_resume()
	SceneRouter.goto_route(&"match")


func _on_new_match() -> void:
	SetupLaunch.clear_pending()
	SceneRouter.goto_route(&"match_setup")


func _on_settings() -> void:
	if _settings == null:
		_settings = PauseMenu.new()
		_settings.name = "TitleSettings"
		_settings.settings_only = true
		add_child(_settings)
	_settings.open()


# --- Hidden dev panel: hold the logo for LONG_PRESS_S ---------------------------------------

func _on_logo_input(event: InputEvent) -> void:
	var pressed: Variant = null
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed == null:
		return
	_press_started_ms = Time.get_ticks_msec() if pressed else -1
	set_process(bool(pressed))


func _process(_delta: float) -> void:
	if _press_started_ms < 0:
		set_process(false)
		return
	if Time.get_ticks_msec() - _press_started_ms >= int(LONG_PRESS_S * 1000.0):
		_press_started_ms = -1
		set_process(false)
		open_dev_panel()


func open_dev_panel() -> void:
	if _dev_panel == null:
		_dev_panel = DevPanel.new()
		_dev_panel.name = "DevPanel"
		add_child(_dev_panel)
		_dev_panel.closed.connect(refresh)
		_dev_panel.changed.connect(func() -> void: _dev_tag.visible = DevOverrides.is_active())
	_dev_panel.open()


func _relayout() -> void:
	SetupUI.apply_margins(_safe, get_viewport_rect().size, safe_area_override)
	var compact: bool = get_viewport_rect().size.y < 640.0
	_title.add_theme_font_size_override(&"font_size", 72 if compact else 96)
