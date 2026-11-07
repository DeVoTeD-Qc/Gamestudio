# run_glyph.gd
# Purpose: A small Control that draws one Run v2 pictogram (a map node or a Terrain) from run_glyphs.gd,
#   on a dark backing plate unless backing = false. Display only (mouse ignored).
# Dependencies: run_glyphs.gd.
# Author: UI/UX Agent (kc-v2-ui)
extends Control

const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")

var kind: StringName = &"node"
var id: StringName = &"fight"
var color: Color = Color.WHITE
var backing: bool = true


func _init(p_kind: StringName = &"node", p_id: StringName = &"fight", p_color: Color = Color.WHITE, px: float = 28.0) -> void:
	kind = p_kind
	id = p_id
	color = p_color
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if backing:
		draw_rect(r, Color(0.05, 0.06, 0.07, 0.85))
	var inner: Rect2 = r.grow(-size.x * 0.12)
	if kind == &"terrain":
		RunGlyphs.draw_terrain(self, inner, id, color)
	else:
		RunGlyphs.draw_node(self, inner, id, color)
