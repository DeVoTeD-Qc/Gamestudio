# boss_plate.gd
# Purpose: The BOSS RULE plate on the match board (run-v2.md §4, §7.1 "the boss rule plate sits where
#   the enemy Operator plate is"; kc-v2-ui). A red plate on an empty rival back-row slot (the
#   screen picks one; a skull tab at the board's corner when all are full), over the rival's side: skull, "BOSS RULE", the rule's name, and a state word: "FROM ROUND N" before
#   it starts, "ACTIVE" once it is in effect (MatchState.boss_view active / note). Hidden outside boss
#   fights. Tap = the rule as a toast, long press / right click = the boss inspector.
# Dependencies: run_glyphs.gd, press_gesture.gd, hud_theme.tres fonts.
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal tapped
signal inspected

const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

var boss: Dictionary = {}
var compact: bool = false
## All rival back rows are full: a 56 px skull tab instead of the plate.
var tab: bool = false
var _gesture: RefCounted = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"tap_target")
	set_meta(&"inspectable", true)
	visible = false


func _ready() -> void:
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: tapped.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspected.emit())


func _gui_input(e: InputEvent) -> void:
	if _gesture != null and _gesture.handle(e):
		accept_event()


func set_boss(b: Dictionary) -> void:
	boss = b
	visible = not b.is_empty()
	tooltip_text = "Boss rule · %s: %s" % [b.get("rule_name", ""), b.get("rule_text", "")] if visible else ""
	queue_redraw()


func plate_width() -> float:
	return 196.0 if compact else 240.0


## 64 px: a 46 pt tap target on the phone.
func plate_height() -> float:
	return 64.0


func state_word() -> String:
	if boss.is_empty():
		return ""
	if bool(boss.get("active", false)):
		return "ACTIVE"
	var note: String = String(boss.get("note", ""))
	return note.to_upper() if note != "" else "BOSS FIGHT"


func _draw() -> void:
	if boss.is_empty():
		return
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var red: Color = Color("#E5383B")
	var active: bool = bool(boss.get("active", false))
	draw_rect(r, Color(0.16, 0.08, 0.09, 0.94))
	draw_rect(r, red, false, 3.0 if active else 2.0)
	var g: float = minf(size.y - 10.0, 44.0)
	RunGlyphs.draw_node(self, Rect2(Vector2(5, (size.y - g) * 0.5), Vector2(g, g)), &"boss", red)
	if tab:
		return
	var f: Font = get_theme_font(&"font", &"HudHeader")
	var x: float = g + 12.0
	var room: float = size.x - x - 6.0
	var top: float = maxf(0.0, (size.y - 54.0) * 0.5)
	draw_string(f, Vector2(x, top + 15), "BOSS RULE", HORIZONTAL_ALIGNMENT_LEFT, room, 13, Color("#FF8A8C"))
	var nm: String = BannerView.fit_text(String(boss.get("rule_name", "")).to_upper(), f, 18, room)
	draw_string(f, Vector2(x, top + 34), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var sw: String = state_word()
	draw_string(f, Vector2(x, top + 51), BannerView.fit_text(sw, f, 14, room), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			red if active else Color("#B9C2C9"))


## kc-text: hover tooltips show each concept's icon inline (IconText), like every other text.
func _make_custom_tooltip(for_text: String) -> Object:
	return IconText.tooltip(for_text)
