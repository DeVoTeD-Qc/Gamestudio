# cover_screen.gd
# Purpose: CardZone hot-seat pass-the-device cover (cz14, spec §16.2 / §16.3). A full-screen,
#   opaque layer over the match screen, raised by MatchController.cover_changed(true) at every
#   seat change (a turn, the drop, the defender's Brace prompt) and at the start / resume of a
#   hot-seat match:
#       HOT-SEAT · ROUND 3
#       PASS TO PLAYER 2
#       Player 1: look away. Player 2: incoming shot, choose your Brace.
#       [ TAP WHEN READY ]
#   The whole screen is the tap target (>= 64 px everywhere). A tap in the first arm_ms after the
#   cover went up is ignored, so a last tap of the previous player can't pass through. The tap
#   calls MatchController.reveal(); the cover hides on cover_changed(false).
#   As it goes up it asks the screen to drop everything seat-private (hotseat_cover_reset) and it
#   draws only public words: seat numbers, the round and the reason. No card is ever on it.
# Usage: CoverScreen.attach(match_screen, controller) (match_screen.gd does it in _ready).
# Dependencies: setup_ui.gd (theme, labels), match_controller.gd (cover_changed, reveal, cover_info).
# Author: Mechanics Developer Agent (cz14)
extends Control

const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const SCENE_PATH: String = "res://scenes/match/CoverScreen.tscn"
const BG: Color = Color("#1B1026")

## Taps this soon after the cover went up are ignored (ms). Tests set 0.
@export var arm_ms: int = 350

var _screen: Control
var _ctrl: Node
var _shown_ms: int = 0
var _info: Dictionary = {}
var _tap: Button
var _tag: Label
var _heading: Label
var _body: Label
var _plate: Button


## Adds the cover (hidden) as the screen's last child and binds it to the controller.
static func attach(screen: Control, ctrl: Node) -> Control:
	var cover: Control = (load(SCENE_PATH) as PackedScene).instantiate()
	screen.add_child(cover)
	cover.call("bind", screen, ctrl)
	return cover


func _init() -> void:
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SetupUI.build_theme()
	var bg: ColorRect = ColorRect.new()
	bg.name = "CoverBackground"
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_tap = Button.new()
	_tap.name = "CoverTap"
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_ALL
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for st: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		_tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_tap.pressed.connect(_on_tap)
	add_child(_tap)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "CoverColumn"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	_tag = _label("", &"ShellTag", "CoverTag")
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_tag)
	_heading = _label("", &"ShellTitle", "CoverHeading")
	col.add_child(_heading)
	_body = _label("", &"ShellBody", "CoverBody")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)
	_plate = SetupUI.button("TAP WHEN READY", &"DockButton")
	_plate.name = "CoverPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the whole screen is the tap target
	_plate.focus_mode = Control.FOCUS_NONE
	_plate.custom_minimum_size = Vector2(320, SetupUI.TAP_PX)
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_plate)
	resized.connect(_fit)
	_fit()


func bind(screen: Control, ctrl: Node) -> void:
	_screen = screen
	_ctrl = ctrl
	if ctrl != null and ctrl.has_signal(&"cover_changed") and not ctrl.is_connected(&"cover_changed", _on_cover_changed):
		ctrl.connect(&"cover_changed", _on_cover_changed)


## True while the cover is up.
func is_up() -> bool:
	return visible


func get_tap_button() -> Button:
	return _tap


func get_info() -> Dictionary:
	return _info.duplicate()


## {tag, heading, body, plate}: the words on the cover.
func get_texts() -> Dictionary:
	return {"tag": _tag.text, "heading": _heading.text, "body": _body.text, "plate": _plate.text}


## The words for a cover (static: tests and screenshots).
static func texts_for(info: Dictionary) -> Dictionary:
	var p: int = int(info.get("player", 1))
	var other: int = int(info.get("from_player", 3 - p))
	var lead: String = "Player %d: look away. " % other
	var body: String = ""
	match StringName(info.get("reason", &"turn")):
		&"drop":
			body = "Player %d: choose where to drop." % p
			if p == 2:
				body = "Player %d drops first: choose where to land." % p
		&"brace":
			body = "Player %d: incoming shot. Choose your Brace." % p
		&"start":
			body = "Player %d: your turn." % p
		_:
			body = "Player %d: your turn." % p
	var round_n: int = int(info.get("round", 0))
	return {"tag": "HOT-SEAT · DROP" if round_n <= 0 else "HOT-SEAT · ROUND %d" % round_n,
			"heading": "PASS TO PLAYER %d" % p, "body": lead + body, "plate": "TAP WHEN READY"}


func _on_cover_changed(up: bool, info: Dictionary) -> void:
	_info = info.duplicate()
	if not up:
		visible = false
		return
	if _screen != null and _screen.has_method(&"hotseat_cover_reset"):
		_screen.call("hotseat_cover_reset")
	var t: Dictionary = texts_for(info)
	_tag.text = t["tag"]
	_heading.text = t["heading"]
	_body.text = t["body"]
	_plate.text = t["plate"]
	_shown_ms = Time.get_ticks_msec()
	visible = true
	if get_parent() != null:
		get_parent().move_child(self, -1)  # above the shell, coach and every overlay
	if is_inside_tree():
		_tap.grab_focus.call_deferred()


func _on_tap() -> void:
	if not visible or _ctrl == null:
		return
	if Time.get_ticks_msec() - _shown_ms < arm_ms:
		return
	_ctrl.call("reveal")


func _label(text: String, variation: StringName, node_name: String) -> Label:
	var l: Label = SetupUI.label(text, variation)
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _fit() -> void:
	if _body != null:
		_body.custom_minimum_size.x = clampf(size.x - 96.0, 240.0, 640.0)
