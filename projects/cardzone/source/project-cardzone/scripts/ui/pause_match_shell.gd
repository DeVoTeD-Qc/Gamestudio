# pause_match_shell.gd
# Purpose: MatchShell (cz13): the shell's layer over the cz11 match screen when the match was
#   started from the Title or Match setup (a SetupLaunch request is pending when the screen
#   loads). It owns three overlays and the match start:
#     begin(controller)  applies the event speed and starts the requested match
#                        (SetupLaunch.begin: new match from the setup choices, or the saved one);
#                        if it can't (e.g. the save was damaged meanwhile) it says why, with TITLE
#     pause menu         MENU -> RESUME / RULES / SETTINGS / CONCEDE… / LEAVE TO TITLE (pause_menu.gd);
#                        the match loop is held (controller.paused) while it is open
#     end screen         at the match end (end_screen.gd): NEW MATCH = the same setup again,
#                        TITLE; MENU after SEE BOARD shows it again
#     coach              the first-match tips (scenes/coach/CoachTip.tscn)
#   Without a launch request (tests and QA fixtures that load Match.tscn directly) there is no
#   shell and the screen keeps its cz11 MENU / end sheets.
# Dependencies: setup_launch.gd, pause_menu.gd, pause_settings.gd, end_screen.gd, coach overlay,
#   setup_ui.gd, SceneRouter.
# Author: UI/UX Agent (cz13)
extends Control

const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const PauseMenu: GDScript = preload("res://scripts/ui/pause_menu.gd")
const PauseSettings: GDScript = preload("res://scripts/ui/pause_settings.gd")
const END_SCENE: PackedScene = preload("res://scenes/end/EndScreen.tscn")
const COACH_SCENE: PackedScene = preload("res://scenes/coach/CoachTip.tscn")

var pause_menu: Control
var end_screen: Control
var coach: Control
## Why the last begin() could not start a match ("" = it started).
var start_error: String = ""

var _screen: Control
var _ctrl: Node
var _error_panel: Control


## Adds the shell to a match screen (as its last child, above every cz11 overlay).
static func attach(screen: Control) -> Control:
	var shell: Control = (load("res://scripts/ui/pause_match_shell.gd") as GDScript).new()
	shell.name = "MatchShell"
	shell._screen = screen
	screen.add_child(shell)
	return shell


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SetupUI.build_theme()
	coach = COACH_SCENE.instantiate()
	add_child(coach)
	end_screen = END_SCENE.instantiate()
	end_screen.visible = false
	add_child(end_screen)
	end_screen.new_match_pressed.connect(_on_new_match)
	end_screen.title_pressed.connect(_to_title)
	end_screen.board_pressed.connect(func() -> void: coach.enabled = true)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.resumed.connect(_on_pause_closed)
	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.concede_confirmed.connect(_on_concede)
	pause_menu.leave_requested.connect(_to_title)
	pause_menu.settings_changed.connect(func() -> void: PauseSettings.apply_to_controller(_ctrl))


## Starts the pending launch on the controller. "" when a match started, else why not.
func begin(ctrl: Node) -> String:
	if _ctrl == null:
		_ctrl = ctrl
		coach.watch(_screen, ctrl)
	PauseSettings.apply_to_settings()
	PauseSettings.apply_to_controller(ctrl)
	end_screen.visible = false
	coach.enabled = true
	start_error = SetupLaunch.begin(ctrl)
	if start_error != "":
		_show_error(start_error)
	return start_error


func open_pause() -> void:
	if _ctrl != null and _ctrl.get("phase") == &"over":
		show_end()
		return
	coach.enabled = false
	if _ctrl != null:
		_ctrl.set("paused", true)
	pause_menu.open()


func show_end() -> void:
	pause_menu.close()
	coach.enabled = false
	end_screen.show_result(_ctrl.call("view"), _ctrl.call("stats"))


func is_paused() -> bool:
	return pause_menu.visible


func _on_pause_closed() -> void:
	if _ctrl != null and not coach.is_showing():
		_ctrl.set("paused", false)
	coach.enabled = true
	coach.check.call_deferred()


func _on_concede() -> void:
	if _ctrl != null:
		_ctrl.set("paused", false)
		_ctrl.call("request", {"type": "concede"})


func _on_new_match() -> void:
	end_screen.visible = false
	SetupLaunch.request_again()
	_screen.call("start_live")


func _to_title() -> void:
	if _ctrl != null:
		_ctrl.set("paused", false)
	SceneRouter.goto_route(&"title")


func _show_error(text: String) -> void:
	if _error_panel != null:
		_error_panel.queue_free()
	var layer: Control = Control.new()
	layer.name = "StartError"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(SetupUI.dim_layer(0.85))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ShellPanel"
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	panel.add_child(col)
	col.add_child(SetupUI.label("CAN'T START THE MATCH", &"ShellHeading"))
	var l: Label = SetupUI.label(text, &"ShellBody", true)
	l.custom_minimum_size.x = minf(560.0, size.x - 96.0)
	col.add_child(l)
	var b: Button = SetupUI.button("TITLE", &"DockButton")
	b.name = "ErrorTitleButton"
	b.pressed.connect(_to_title)
	col.add_child(b)
	add_child(layer)
	_error_panel = layer
