# dd_layered_texture.gd
# Purpose: dd-art-import45 (art pack 5). A weapon card's art as two layers: the backdrop (dd_bg_gun /
#   dd_bg_melee) and the weapon's transparent cut-out, both painted on one 768x512 canvas. It is a Texture2D,
#   so every place that drew the pack 1 painting (TextureRect, cover_rect, inspect, Codex) draws the two
#   layers instead with no change: drawn into a rect (or a region of it), the backdrop goes first, then the
#   cut-out over the same region of the shared canvas. DDArtRect knows this texture and does better:
#   backdrop cover-fit, cut-out at the set's one shared scale (art-direction.md "Layered weapon cards").
#   Made by DDArt._texture() from the manifest's "layers" group; with a layer missing DDArt keeps the
#   pack 1 painting.
#   Performance: low. Two textured quads per draw, no extra memory (the two layers are shared by every card).
# Dependencies: none.
# Author: Technical Artist Agent (dd-art-import45)
extends Texture2D

var back: Texture2D = null
var cut: Texture2D = null
## The union of the whole set's cut-out boxes, in 0..1 of the canvas (one box for all = one scale).
var box: Rect2 = Rect2(0.05, 0.19, 0.9, 0.66)
## Where the cut-out's canvas centre lands in the art rect, in 0..1 of the rect.
var anchor: Vector2 = Vector2(0.5, 0.52)


func _init(p_back: Texture2D = null, p_cut: Texture2D = null) -> void:
	back = p_back
	cut = p_cut


func _get_width() -> int:
	return cut.get_width() if cut != null else 1


func _get_height() -> int:
	return cut.get_height() if cut != null else 1


func _has_alpha() -> bool:
	return false


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return true


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(to_canvas_item, Rect2(pos, get_size()), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if back != null:
		back.draw_rect(to_canvas_item, rect, tile, modulate, transpose)
	if cut != null:
		cut.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	var sz: Vector2 = get_size()
	for t: Texture2D in [back, cut]:
		if t == null:
			continue
		var k: Vector2 = t.get_size() / sz
		t.draw_rect_region(to_canvas_item, rect, Rect2(src_rect.position * k, src_rect.size * k), modulate, transpose, clip_uv)
