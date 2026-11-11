# title_wordmark.gd
# Purpose: kc-da-ui2 (art direction #7): the KILLINGCARD title lockup, an original stencil wordmark
#   drawn in code: "KILLING" in Stardos Stencil fog white, then "CARD" knocked out in slate ink on a
#   fog-white tag plate cut like a card (45-degree chamfers top-left and bottom-right, art direction
#   §4), a steel rule under the word with four steel hazard ticks. No amber (amber is the one
#   button), no reticle (the reticle means FP). It sits over the title's TitleLabel, whose text stays
#   "KILLINGCARD" for screen readers and tests; the label's own glyphs are hidden.
# Usage: TitleWordmark.attach(label)   # adds the lockup as the label's child and sizes the label
# Author: UI/UX Agent (kc-da-ui2)
extends Control

const FONT_PATH: String = "res://assets/fonts/StardosStencil-Bold.ttf"
const FOG: Color = Color("#D8DEE3")
const INK: Color = Color("#12161A")
const STEEL: Color = Color("#4A535B")
const MUTED: Color = Color("#7D8790")

var font_size: int = 84
var _font: Font = null


static func attach(label: Label) -> Control:
	var w: Control = (load("res://scripts/ui/title_wordmark.gd") as GDScript).new()
	w.name = "Wordmark"
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_child(w)
	label.add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0))
	w.call(&"set_size_from", label)
	label.resized.connect(func() -> void: w.call(&"set_size_from", label))
	return w


func _init() -> void:
	_font = load(FONT_PATH) as Font


## Follows the label's font size; the label's minimum size becomes the lockup's.
func set_size_from(label: Label) -> void:
	font_size = label.get_theme_font_size(&"font_size")
	var need: Vector2 = lockup_size()
	label.custom_minimum_size = need
	position = Vector2.ZERO
	size = Vector2(maxf(need.x, label.size.x), need.y)
	queue_redraw()


func _parts() -> Dictionary:
	var f: float = float(font_size)
	var w1: float = _font.get_string_size("KILLING", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var cs: int = int(round(f * 0.86))
	var w2: float = _font.get_string_size("CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var pad: Vector2 = Vector2(f * 0.16, f * 0.06)
	var gap: float = f * 0.12
	var asc: float = _font.get_ascent(font_size)
	var desc: float = _font.get_descent(font_size)
	var line_h: float = asc + desc
	var plate: Rect2 = Rect2(w1 + gap, f * 0.04, w2 + pad.x * 2.0, line_h - f * 0.08)
	return {"w1": w1, "cs": cs, "w2": w2, "pad": pad, "asc": asc, "desc": desc, "line_h": line_h, "plate": plate,
			"rule_y": line_h + f * 0.1}


func lockup_size() -> Vector2:
	var p: Dictionary = _parts()
	var plate: Rect2 = p["plate"]
	return Vector2(ceilf(plate.end.x + 2.0), ceilf(float(p["rule_y"]) + 4.0))


func _draw() -> void:
	var p: Dictionary = _parts()
	var f: float = float(font_size)
	var asc: float = p["asc"]
	# KILLING: fog white stencil with a soft dark drop (no glow).
	var base_y: float = asc
	draw_string(_font, Vector2(2, base_y + 2), "KILLING", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.45))
	draw_string(_font, Vector2(0, base_y), "KILLING", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, FOG)
	# CARD: slate ink knocked out of a card-cut fog-white plate.
	var plate: Rect2 = p["plate"]
	var cut: float = f * 0.16
	var poly: PackedVector2Array = [
		plate.position + Vector2(cut, 0), Vector2(plate.end.x, plate.position.y), Vector2(plate.end.x, plate.end.y - cut),
		Vector2(plate.end.x - cut, plate.end.y), Vector2(plate.position.x, plate.end.y), plate.position + Vector2(0, cut)]
	var shadow: PackedVector2Array = []
	for v: Vector2 in poly:
		shadow.append(v + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(poly, FOG)
	var inner: PackedVector2Array = poly.duplicate()
	inner.append(poly[0])
	draw_polyline(inner, STEEL, 1.5, true)
	var cs: int = p["cs"]
	var c_asc: float = _font.get_ascent(cs)
	var c_desc: float = _font.get_descent(cs)
	var cy: float = plate.position.y + (plate.size.y + c_asc - c_desc) * 0.5
	draw_string(_font, Vector2(plate.position.x + (p["pad"] as Vector2).x, cy), "CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, cs, INK)
	# The steel rule with four hazard ticks at its left end.
	var ry: float = p["rule_y"]
	var tick_w: float = maxf(4.0, f * 0.07)
	for i: int in 4:
		var x: float = i * tick_w * 1.7
		draw_colored_polygon(PackedVector2Array([Vector2(x + tick_w * 0.6, ry - 2.0), Vector2(x + tick_w * 1.4, ry - 2.0),
				Vector2(x + tick_w * 0.8, ry + 2.0), Vector2(x, ry + 2.0)]), MUTED)
	draw_line(Vector2(tick_w * 7.4, ry), Vector2(plate.end.x, ry), STEEL, 2.0)
