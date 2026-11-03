# cost_hex.gd
# Purpose: Small cost badge for hand chips (f04): the same amber hexagon the full CardView draws
#   (card_view.gd _hex, pointy top), with the cost number centred on it. Size it with
#   custom_minimum_size; the number label is a child (HudNumber, dark ink), so tests see it as
#   a key number. Not a container: the label may be a few px taller than the hex without
#   growing the chip.
# Dependencies: hud_theme.tres (Hud/colors/accent, HudNumber).
# Author: UI/UX Agent (f04)
extends Control

const INK: Color = Color("#12161A")

var label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.theme_type_variation = &"HudNumber"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", INK)
	add_child(label)
	resized.connect(_center_label)


func set_text(text: String) -> void:
	label.text = text
	_center_label()


func _center_label() -> void:
	var need: Vector2 = label.get_combined_minimum_size()
	label.size = Vector2(maxf(size.x, need.x), need.y)
	label.position = Vector2((size.x - label.size.x) * 0.5, (size.y - need.y) * 0.5 + 1.0)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var rad: float = minf(size.y * 0.5, size.x / sqrt(3.0))
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	var fill: Color = get_theme_color(&"accent", &"Hud")
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, fill.darkened(0.35), 1.5, true)
