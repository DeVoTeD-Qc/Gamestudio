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


## kc-ui-wire2: the painted menu backdrop (bg_menu) over the scene's Background when shipped. Runs
## from the READY notification, so the subclasses' own _ready() need no super() call.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY and get_node_or_null(^"BackdropArt") == null:
		var bg: Node = get_node_or_null(^"Background")
		CardArt.add_backdrop(self, &"menu", bg.get_index() + 1 if bg != null else 0)
	if what == NOTIFICATION_READY:
		resized.connect(_fit_panel)
		_fit_panel.call_deferred()


## kc-ui-pass: the 880 px sheet was cut off in phone portrait (390 pt wide). It now fits the screen
## width (12 px margin each side), and each row of buttons shrinks to share it.
func _fit_panel() -> void:
	var panel: Control = get_node_or_null(^"Center/Panel") as Control
	if panel == null or size.x <= 0.0:
		return
	if not panel.has_meta(&"base_w"):
		panel.set_meta(&"base_w", panel.custom_minimum_size.x)
	var w: float = minf(float(panel.get_meta(&"base_w")), size.x - 24.0)
	panel.custom_minimum_size.x = w
	for row: Node in panel.find_children("*", "HBoxContainer", true, false):
		var buttons: Array[Button] = []
		for c: Node in row.get_children():
			if c is Button:
				buttons.append(c)
		if buttons.is_empty():
			continue
		var gap: float = float((row as HBoxContainer).get_theme_constant(&"separation"))
		var room: float = (w - 64.0 - gap * (buttons.size() - 1)) / buttons.size()
		for b: Button in buttons:
			if not b.has_meta(&"base_w"):
				b.set_meta(&"base_w", b.custom_minimum_size.x)
			b.custom_minimum_size.x = minf(float(b.get_meta(&"base_w")), maxf(64.0, room))
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if b.custom_minimum_size.x < float(b.get_meta(&"base_w")) else TextServer.AUTOWRAP_OFF


func playtest_log() -> Node:
	return get_node_or_null("/root/PlaytestLog")


## Tells PlaytestLog which screen or step is showing (for quit(screen)).
func announce(screen: StringName) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("screen_shown"):
		bus.screen_shown.emit(screen)


## Marks a choice button as picked. The HudButton pressed style is too close to normal to read
## on a phone, so a picked answer switches to the filled ReadyButton look (theme variations only).
static func mark_selected(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	button.theme_type_variation = &"ReadyButton" if selected else &"HudButton"


func finish(scene: String = next_scene) -> void:
	finished.emit()
	if scene == "" or not is_inside_tree():
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(scene)
