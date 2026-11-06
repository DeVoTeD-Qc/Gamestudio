# initiative_chip.gd
# Purpose: kc-onboard-ui (lead brief item 8): the player can always see who holds initiative this
#   round, and why. A small chip in the icon strip (above the trait rail): "1ST" over YOU (teal, an
#   up-chevron flag) or RIVAL (red, a hazard-striped flag; shape, not only colour), and a one-word
#   reason under it: BEHIND (that side trails on score) or TIE (the tie rule decided). It follows
#   match_snapshot.initiative_info(): during Deploy the side the rules will pick at Reveal, then the
#   side that has it. Tap or long-press / right-click opens the full reason and what initiative does
#   (the match controller's inspector, key &"initiative"). The initiative rule itself is untouched.
# Dependencies: press_gesture.gd, hud_theme.tres (HudPanelDark, Hud colours, HudNumber / HudHeader).
# Author: UI/UX Agent (kc-onboard-ui)
class_name InitiativeChip
extends Control

signal tapped
signal inspected

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

## match_snapshot.initiative_info() ({} = hidden).
var info: Dictionary = {}
var _gesture: RefCounted = null


func _ready() -> void:
	name = "InitiativeChip"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"tap_target")
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: tapped.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspected.emit())


func _gui_input(event: InputEvent) -> void:
	if _gesture != null and _gesture.handle(event):
		accept_event()


func set_info(d: Dictionary) -> void:
	info = d
	tooltip_text = "%s %s" % [String(d.get("reason", "")), String(d.get("effect", ""))] if not d.is_empty() else ""
	queue_redraw()


## Plain text (tests, QA): "1ST YOU BEHIND".
func get_text() -> String:
	if info.is_empty():
		return ""
	return "1ST %s %s" % [String(info.get("short", "")), "TIE" if info.get("why", &"") == &"tie" else "BEHIND"]


func _draw() -> void:
	if info.is_empty():
		return
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var sb: StyleBox = get_theme_stylebox(&"panel", &"HudPanelDark")
	if sb != null:
		draw_style_box(sb, r)
	var mine: bool = bool(info.get("mine", true))
	var c: Color = get_theme_color(&"friend", &"Hud") if mine else get_theme_color(&"enemy", &"Hud")
	var muted: Color = Color("#9AA5AE")
	var head: Font = get_theme_font(&"font", &"HudHeader")
	var num: Font = get_theme_font(&"font", &"HudNumber")
	var fs_small: int = 15 if size.y < 62.0 else 16
	var fs_big: int = 18 if size.x < 66.0 else 20
	# Flag glyph (shape per side) + "1ST" on the top line.
	var fy: float = 5.0
	var flag: Rect2 = Rect2(6.0, fy, 12.0, 14.0)
	draw_line(Vector2(flag.position.x, flag.position.y), Vector2(flag.position.x, flag.end.y), c, 2.0)
	var cloth: PackedVector2Array = [flag.position + Vector2(1, 0), flag.position + Vector2(12, 3), flag.position + Vector2(1, 8)]
	draw_colored_polygon(cloth, c)
	if not mine:
		draw_line(flag.position + Vector2(3, 6), flag.position + Vector2(7, 1), Color(0.05, 0.06, 0.07), 1.5)
	var t1: String = "1ST"
	var w1: float = num.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small).x
	draw_string(num, Vector2(maxf(flag.end.x + 3.0, (size.x - w1) * 0.5 + 6.0), fy + num.get_ascent(fs_small) - 1.0), t1,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small, muted)
	# Holder.
	var t2: String = String(info.get("short", ""))
	var big: int = fs_big
	while big > 12 and head.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x > size.x - 6.0:
		big -= 1
	var w2: float = head.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var y2: float = size.y * 0.5 + head.get_ascent(big) * 0.5 - (1.0 if size.y >= 56.0 else -1.0)
	draw_string(head, Vector2((size.x - w2) * 0.5, y2), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, big, c)
	# Why, when there is room.
	if size.y >= 56.0:
		var t3: String = "TIE" if info.get("why", &"") == &"tie" else "BEHIND"
		var fs3: int = fs_small
		var w3: float = num.get_string_size(t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
		draw_string(num, Vector2((size.x - w3) * 0.5, size.y - 4.0), t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, muted)
