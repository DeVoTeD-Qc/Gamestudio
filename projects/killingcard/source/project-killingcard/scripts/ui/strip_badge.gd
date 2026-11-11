# strip_badge.gd
# Purpose: One badge of the icon strip (kc-board2, board-layout-v2.md §3): SCORE, OPERATOR, STREAK,
#   RIVAL or DECK. A dark panel with a glyph on top and the badge's key value under it (20 px number,
#   side colours where it helps), so nothing hides behind a badge without a visible value.
#   Tap opens the badge's flyout (match_screen.gd), long-press / right-click opens its rules.
#   `hot` draws the amber glow (a killstreak is ready, or the Operator can deploy).
#   The OPERATOR badge also carries the Operator handle while it can deploy: match_screen enables
#   drag_enabled and forwards the gesture to the Operator panel's signals.
# Dependencies: press_gesture.gd, hud_theme.tres (HudPanelDark, Hud colours, HudNumber / HudHeader fonts).
# Author: Mechanics Developer Agent (kc-board2)
extends Control

signal tapped
signal inspected
signal drag_started(pos: Vector2)
signal drag_moved(pos: Vector2)
signal drag_ended(pos: Vector2)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const AMBER: Color = Color(0.961, 0.722, 0.239)
const CAMO: Array[Color] = [Color("#6b5a2a"), Color("#c9a548"), Color("#3d3a1c"), Color("#e7c56a")]

## &"score", &"operator", &"streak", &"rival", &"deck"
@export var key: StringName = &""
## Glyph drawn on top: &"camo", &"streak", &"cards", &"cards_rival", &"none".
@export var glyph: StringName = &"none"
## kc-ui-bands: the level band the &"camo" glyph shows (MasteryBands id; old ids migrate on set).
var band: StringName = &"base":
	set(value):
		band = MasteryBands.migrate_id(value) if value != &"" else &"base"
		queue_redraw()
## Value rows under the glyph (or alone): each row is an Array of [text, Color] segments.
var lines: Array = []
var hot: bool = false
var font_size: int = 20
var _gesture: RefCounted = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"tap_target")
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: tapped.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspected.emit())
	_gesture.drag_started.connect(func(p: Vector2) -> void: drag_started.emit(p))
	_gesture.drag_moved.connect(func(p: Vector2) -> void: drag_moved.emit(p))
	_gesture.drag_ended.connect(func(p: Vector2) -> void: drag_ended.emit(p))


func _gui_input(event: InputEvent) -> void:
	if _gesture.handle(event):
		accept_event()


func set_drag_enabled(on: bool) -> void:
	if _gesture != null:
		_gesture.drag_enabled = on


## rows: [[[text, Color], ...], ...]; one Array of coloured segments per row, top to bottom.
## kc-fight-ui: a segment [text, Color, &"cards_rival"] draws that small glyph before its text.
func set_value(rows: Array, is_hot: bool = false) -> void:
	var parts: Array = rows
	lines = parts
	hot = is_hot
	queue_redraw()


## Plain text of the badge (QA bridge, tests).
func get_text() -> String:
	var out: PackedStringArray = []
	for row: Array in lines:
		var t: String = ""
		for seg: Array in row:
			t += String(seg[0])
		out.append(t)
	return " ".join(out)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var sb: StyleBox = get_theme_stylebox(&"panel", &"HudPanelDark")
	if sb != null:
		draw_style_box(sb, r)
	else:
		draw_rect(r, Color(0.08, 0.1, 0.12, 0.95))
	if hot:
		draw_rect(r.grow(-1.0), AMBER, false, 2.5)
		draw_rect(r.grow(1.5), Color(AMBER, 0.35), false, 3.0)
	var text_c: Color = get_theme_color(&"text", &"Hud")
	var has_glyph: bool = glyph != &"none"
	var g: float = 26.0
	var rows: int = lines.size()
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var line_h: float = font_size + 2.0
	var block: float = (g + 4.0 if has_glyph else 0.0) + rows * line_h
	var y: float = (size.y - block) * 0.5
	if has_glyph:
		_draw_glyph(Rect2(Vector2((size.x - g) * 0.5, y), Vector2(g, g)), text_c)
		y += g + 4.0
	for row: Array in lines:
		var fs: int = font_size
		var w: float = _row_width(row, font, fs)
		while fs > 16 and w > size.x - 6.0:
			fs -= 1
			w = _row_width(row, font, fs)
		var x: float = (size.x - w) * 0.5
		for seg: Array in row:
			var text: String = String(seg[0])
			var c: Color = seg[1] if seg.size() > 1 else text_c
			if seg.size() > 2:
				_draw_mini_glyph(Rect2(Vector2(x, y + 1.0), Vector2(fs, fs)), StringName(seg[2]), c)
				x += fs + 2.0
			draw_string(font, Vector2(x, y + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
			x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		y += line_h


func _row_width(row: Array, font: Font, fs: int) -> float:
	var w: float = 0.0
	for seg: Array in row:
		w += font.get_string_size(String(seg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if seg.size() > 2:
			w += fs + 2.0
	return w


## A glyph inside a value row (kc-fight-ui: the rival's hand on the phone SCORE badge).
func _draw_mini_glyph(gr: Rect2, g: StringName, c: Color) -> void:
	var s: float = gr.size.x
	if g == &"flag" or g == &"flag_rival":
		# kc-onboard-ui: the initiative flag on the SCORE badge (the rival's has a hazard notch).
		draw_line(gr.position + Vector2(s * 0.2, s * 0.08), gr.position + Vector2(s * 0.2, s * 0.95), c, 2.0)
		draw_colored_polygon(PackedVector2Array([gr.position + Vector2(s * 0.26, s * 0.08), gr.position + Vector2(s * 0.92, s * 0.3),
				gr.position + Vector2(s * 0.26, s * 0.55)]), c)
		if g == &"flag_rival":
			draw_line(gr.position + Vector2(s * 0.36, s * 0.45), gr.position + Vector2(s * 0.56, s * 0.15), Color(0.05, 0.06, 0.07), 1.5)
		return
	if g == &"cards_rival" or g == &"cards":
		draw_rect(Rect2(gr.position + Vector2(s * 0.08, s * 0.28), Vector2(s * 0.5, s * 0.64)), c, false, 1.8)
		draw_polyline(PackedVector2Array([gr.position + Vector2(s * 0.3, s * 0.12), gr.position + Vector2(s * 0.8, s * 0.12),
				gr.position + Vector2(s * 0.8, s * 0.74)]), c, 1.8)


func _draw_glyph(gr: Rect2, c: Color) -> void:
	# kc-ui-import: the UI kit pictogram when imported (UiKit.STRIP_GLYPHS), else the drawn glyph below.
	var kit_c: Color = ((AMBER if hot else Color("#8fd8f0")) if glyph == &"streak"
			else Color("#ff8a8d") if glyph == &"cards_rival" else c)
	if UiKit.draw_icon(self, UiKit.STRIP_GLYPHS.get(glyph, &""), gr, kit_c):
		return
	var ctr: Vector2 = gr.get_center()
	var s: float = gr.size.x
	match glyph:
		&"camo":
			# The Operator's level band (kc-ui-bands: an original finish, MasteryBands) on a disc in a
			# brass ring; the band's name and how it is earned are in the Operator inspector (long press).
			var rad: float = s * 0.48
			if not MasteryBands.draw(self, Rect2(ctr - Vector2(rad, rad), Vector2(rad, rad) * 2.0), band, MasteryBands.disc(ctr, rad * 0.86)):
				draw_circle(ctr, rad * 0.86, CAMO[0])
			draw_arc(ctr, rad, 0, TAU, 28, Color("#0d1014"), rad * 0.3)
			draw_arc(ctr, rad * 0.86, 0, TAU, 28, CAMO[3], 2.0)
		&"streak":
			var cy: Color = Color("#8fd8f0") if not hot else AMBER
			var pts: PackedVector2Array = [gr.position + Vector2(s * 0.1, s * 0.75), gr.position + Vector2(s * 0.35, s * 0.5),
					gr.position + Vector2(s * 0.52, s * 0.66), gr.position + Vector2(s * 0.86, s * 0.3)]
			draw_polyline(pts, cy, 2.6)
			draw_polyline(PackedVector2Array([gr.position + Vector2(s * 0.62, s * 0.28), gr.position + Vector2(s * 0.88, s * 0.28),
					gr.position + Vector2(s * 0.88, s * 0.54)]), cy, 2.6)
		&"cards", &"cards_rival":
			var col: Color = Color("#ff8a8d") if glyph == &"cards_rival" else c
			draw_rect(Rect2(gr.position + Vector2(s * 0.14, s * 0.26), Vector2(s * 0.46, s * 0.62)), col, false, 2.2)
			draw_polyline(PackedVector2Array([gr.position + Vector2(s * 0.34, s * 0.14), gr.position + Vector2(s * 0.8, s * 0.14),
					gr.position + Vector2(s * 0.8, s * 0.72)]), col, 2.2)


## kc-text: hover tooltips show each concept's icon inline (IconText), like every other text.
func _make_custom_tooltip(for_text: String) -> Object:
	return IconText.tooltip(for_text)
