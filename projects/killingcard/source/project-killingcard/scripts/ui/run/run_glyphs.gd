# run_glyphs.gd
# Purpose: Run v2 pictograms (kc-v2-ui): the 6 map node icons (run-v2.md §2.2: crossed rifles, rifles +
#   star, radio, crate, tent, target mark) and the 10 Terrain icons. The UI kit's image wins when it
#   ships (UiKit ids node_<type> and terrain_<id>, white with alpha, tinted); until the Sr Game Artist's
#   set lands (§11.2 "Art") these are code-drawn line glyphs, so every screen works without art.
#   Also each Terrain's band colour (a muted tint for its chip on the objective tile).
#   Shape and word always carry the meaning; colour only groups.
#   kc-da-ui2 (art direction §5.5, #8): the boss is a target mark (rings + centre dot + four ticks),
#   never a skull; the code mark wins over any kit node_boss image.
# Dependencies: UiKit.
# Author: UI/UX Agent (kc-v2-ui)
extends RefCounted

const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
## Terrain band tints (chips, map pills). Muted so the side colours (teal / red) stay the loudest.
const TERRAIN_TINT: Dictionary = {
	&"rooftops": Color("#8C7A5B"), &"smoke": Color("#7D8790"), &"dust_storm": Color("#A88A55"),
	&"breach_point": Color("#9A5A3C"), &"floodlights": Color("#C9B458"), &"comms_tower": Color("#4F7FA0"),
	&"supply_cache": Color("#6E8B4A"), &"hot_zone": Color("#B5523B"), &"minefield": Color("#8A6A3A"),
	&"field_hospital": Color("#5E9A86"),
}
const NODE_TINT: Dictionary = {
	&"fight": Color("#D8DEE3"), &"elite": Color("#C9A227"), &"event": Color("#5BC0EB"),
	&"shop": Color("#C2A878"), &"rest": Color("#7CC48A"), &"boss": Color("#E5383B"),
}


static func terrain_tint(id: StringName) -> Color:
	return TERRAIN_TINT.get(id, Color("#7E8890"))


static func node_tint(t: StringName) -> Color:
	return NODE_TINT.get(t, Color("#D8DEE3"))


## Draws a map node pictogram in rect (square-ish). Kit image first.
static func draw_node(ci: CanvasItem, rect: Rect2, t: StringName, c: Color) -> void:
	if t != &"boss" and UiKit.draw_icon(ci, StringName("node_%s" % t), rect, c):
		return
	var r: Rect2 = _square(rect)
	var w: float = maxf(1.5, r.size.x * 0.085)
	var p: Callable = func(x: float, y: float) -> Vector2: return r.position + Vector2(x, y) * r.size.x
	match t:
		&"fight", &"elite":
			# Two rifles crossed: long barrels, stocks at the bottom corners.
			ci.draw_line(p.call(0.18, 0.86), p.call(0.82, 0.16), c, w)
			ci.draw_line(p.call(0.82, 0.86), p.call(0.18, 0.16), c, w)
			ci.draw_line(p.call(0.12, 0.78), p.call(0.26, 0.92), c, w * 1.6)
			ci.draw_line(p.call(0.88, 0.78), p.call(0.74, 0.92), c, w * 1.6)
			if t == &"elite":
				_star(ci, p.call(0.5, 0.24), r.size.x * 0.17, c)
		&"event":
			# A field radio: box, dial, antenna.
			ci.draw_rect(Rect2(p.call(0.16, 0.38), Vector2(0.68, 0.46) * r.size.x), c, false, w)
			ci.draw_arc(p.call(0.36, 0.61), r.size.x * 0.1, 0, TAU, 16, c, w)
			ci.draw_line(p.call(0.58, 0.54), p.call(0.74, 0.54), c, w)
			ci.draw_line(p.call(0.58, 0.68), p.call(0.74, 0.68), c, w)
			ci.draw_line(p.call(0.7, 0.38), p.call(0.84, 0.1), c, w)
		&"shop":
			# A supply crate: box with cross-bracing.
			var b: Rect2 = Rect2(p.call(0.14, 0.26), Vector2(0.72, 0.6) * r.size.x)
			ci.draw_rect(b, c, false, w)
			ci.draw_line(b.position, b.end, c, w * 0.8)
			ci.draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), c, w * 0.8)
			ci.draw_line(p.call(0.14, 0.4), p.call(0.86, 0.4), c, w * 0.8)
		&"rest":
			# A tent: triangle, door flap, ground line.
			ci.draw_polyline(PackedVector2Array([p.call(0.1, 0.84), p.call(0.5, 0.2), p.call(0.9, 0.84), p.call(0.1, 0.84)]), c, w)
			ci.draw_line(p.call(0.5, 0.2), p.call(0.5, 0.84), c, w * 0.8)
			ci.draw_line(p.call(0.5, 0.5), p.call(0.38, 0.84), c, w * 0.8)
		&"boss":
			# A target mark: outer ring, inner ring, centre dot, four ticks outside the ring.
			var ctr: Vector2 = r.get_center()
			ci.draw_arc(ctr, r.size.x * 0.36, 0, TAU, 32, c, w)
			ci.draw_arc(ctr, r.size.x * 0.2, 0, TAU, 24, c, w)
			ci.draw_circle(ctr, r.size.x * 0.07, c)
			for a2: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				var d: Vector2 = Vector2.from_angle(a2)
				ci.draw_line(ctr + d * r.size.x * 0.4, ctr + d * r.size.x * 0.5, c, w)
		_:
			ci.draw_arc(r.get_center(), r.size.x * 0.3, 0, TAU, 20, c, w)


## Draws a Terrain pictogram in rect. Kit image first.
static func draw_terrain(ci: CanvasItem, rect: Rect2, id: StringName, c: Color) -> void:
	if UiKit.draw_icon(ci, StringName("terrain_%s" % id), rect, c):
		return
	var r: Rect2 = _square(rect)
	var w: float = maxf(1.5, r.size.x * 0.09)
	var p: Callable = func(x: float, y: float) -> Vector2: return r.position + Vector2(x, y) * r.size.x
	match id:
		&"rooftops":
			ci.draw_polyline(PackedVector2Array([p.call(0.08, 0.86), p.call(0.08, 0.46), p.call(0.36, 0.46), p.call(0.36, 0.26),
					p.call(0.64, 0.26), p.call(0.64, 0.56), p.call(0.92, 0.56), p.call(0.92, 0.86)]), c, w)
			ci.draw_line(p.call(0.04, 0.86), p.call(0.96, 0.86), c, w)
		&"smoke":
			for i: int in 3:
				var y: float = 0.3 + 0.2 * i
				ci.draw_arc(p.call(0.32 + 0.1 * (i % 2), y), r.size.x * 0.13, PI * 0.9, TAU * 1.05, 10, c, w)
				ci.draw_arc(p.call(0.62 + 0.06 * (i % 2), y), r.size.x * 0.13, PI * 0.9, TAU * 1.05, 10, c, w)
		&"dust_storm":
			for i: int in 3:
				var y: float = 0.28 + 0.22 * i
				ci.draw_line(p.call(0.1 + 0.08 * i, y), p.call(0.78, y), c, w)
				ci.draw_arc(p.call(0.78, y + 0.07), r.size.x * 0.07, -PI * 0.5, PI * 0.5, 8, c, w)
		&"breach_point":
			ci.draw_polyline(PackedVector2Array([p.call(0.12, 0.5), p.call(0.88, 0.5)]), c, w)
			ci.draw_polyline(PackedVector2Array([p.call(0.66, 0.3), p.call(0.88, 0.5), p.call(0.66, 0.7)]), c, w)
			ci.draw_line(p.call(0.42, 0.18), p.call(0.42, 0.82), c, w * 1.3)
			ci.draw_line(p.call(0.3, 0.3), p.call(0.54, 0.7), c, w * 0.7)
		&"floodlights":
			ci.draw_circle(p.call(0.5, 0.36), r.size.x * 0.12, c)
			for a: float in [-0.9, -0.45, 0.0, 0.45, 0.9]:
				var d: Vector2 = Vector2(sin(a), cos(a))
				ci.draw_line(p.call(0.5, 0.36) + d * r.size.x * 0.2, p.call(0.5, 0.36) + d * r.size.x * 0.48, c, w * 0.8)
		&"comms_tower":
			ci.draw_polyline(PackedVector2Array([p.call(0.3, 0.9), p.call(0.5, 0.3), p.call(0.7, 0.9)]), c, w)
			ci.draw_line(p.call(0.4, 0.62), p.call(0.6, 0.62), c, w * 0.8)
			ci.draw_arc(p.call(0.5, 0.3), r.size.x * 0.18, -PI * 0.85, -PI * 0.15, 10, c, w * 0.8)
			ci.draw_arc(p.call(0.5, 0.3), r.size.x * 0.32, -PI * 0.85, -PI * 0.15, 12, c, w * 0.8)
		&"supply_cache":
			var b: Rect2 = Rect2(p.call(0.16, 0.4), Vector2(0.68, 0.46) * r.size.x)
			ci.draw_rect(b, c, false, w)
			ci.draw_line(p.call(0.5, 0.4), p.call(0.5, 0.86), c, w * 0.8)
			ci.draw_polyline(PackedVector2Array([p.call(0.36, 0.26), p.call(0.5, 0.12), p.call(0.64, 0.26)]), c, w)
		&"hot_zone":
			ci.draw_arc(r.get_center(), r.size.x * 0.36, 0, TAU, 24, c, w)
			ci.draw_arc(r.get_center(), r.size.x * 0.18, 0, TAU, 16, c, w)
			ci.draw_circle(r.get_center(), r.size.x * 0.06, c)
		&"minefield":
			ci.draw_arc(p.call(0.5, 0.62), r.size.x * 0.24, PI, TAU, 14, c, w)
			ci.draw_line(p.call(0.2, 0.62), p.call(0.8, 0.62), c, w)
			ci.draw_line(p.call(0.5, 0.38), p.call(0.5, 0.22), c, w)
			ci.draw_line(p.call(0.36, 0.28), p.call(0.3, 0.16), c, w * 0.7)
			ci.draw_line(p.call(0.64, 0.28), p.call(0.7, 0.16), c, w * 0.7)
		&"field_hospital":
			ci.draw_rect(Rect2(p.call(0.4, 0.14), Vector2(0.2, 0.72) * r.size.x), c)
			ci.draw_rect(Rect2(p.call(0.14, 0.4), Vector2(0.72, 0.2) * r.size.x), c)
		_:
			ci.draw_rect(Rect2(p.call(0.2, 0.2), Vector2(0.6, 0.6) * r.size.x), c, false, w)


static func _star(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i: int in 10:
		var a: float = -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (rad if i % 2 == 0 else rad * 0.45))
	ci.draw_colored_polygon(pts, col)


static func _square(rect: Rect2) -> Rect2:
	var s: float = minf(rect.size.x, rect.size.y)
	return Rect2(rect.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))


## A small Control that draws one glyph (node or terrain), for containers (run_glyph.gd).
static func make(kind: StringName, id: StringName, color: Color, px: float = 28.0) -> Control:
	return (load("res://scripts/ui/run/run_glyph.gd") as GDScript).new(kind, id, color, px)
