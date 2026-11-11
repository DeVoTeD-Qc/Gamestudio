# dd_art_rect.gd
# Purpose: dd-art-fit. A cover-fit art rect that knows where the subject of a painting is. The art
#   fills its rect (cover) around a focus point, but never crops the subject's must-see box (the
#   whole gun, a zombie's head and chest...): when the rect is too wide or too tall for that, the
#   art zooms out just enough to show the box, and the bars that leaves are filled with the
#   painting's own edge stretched out (slightly darker), so the tile never shows an empty edge.
#   Made by DDArt.cover_rect() from the manifest's "focus" entries; anything without one keeps the
#   plain TextureRect cover look. It is a TextureRect (art_rect slots, self_modulate dimming), but
#   draws the art itself: `texture` stays null, the painting is in `art`.
#   Performance: low. Three draw_texture_rect_region calls at most, redrawn on resize only.
# Dependencies: none.
# Author: Technical Artist Agent (dd-art-fit)
extends TextureRect

## The tint of the bars beside a zoomed-out painting (1 = as bright as the art).
const BACKDROP: Color = Color(0.8, 0.8, 0.82)

var art: Texture2D = null
## The subject's must-see box, in 0..1 of the image (Rect2() = none: plain cover).
var box: Rect2 = Rect2()
## Where the crop centres, in 0..1 of the image (the box's centre by default).
var focus: Vector2 = Vector2(0.5, 0.5)


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	custom_minimum_size = Vector2.ZERO
	resized.connect(queue_redraw)


## The image rect drawn and where it lands, for a rect of `area` (for tests and the bars).
## Returns [src: Rect2 (image px), dst: Rect2 (local px), letterboxed: bool].
func layout(area: Vector2) -> Array:
	if art == null or area.x < 1.0 or area.y < 1.0:
		return [Rect2(), Rect2(), false]
	var isz: Vector2 = art.get_size()
	var s_cover: float = maxf(area.x / isz.x, area.y / isz.y)
	var s_contain: float = minf(area.x / isz.x, area.y / isz.y)
	var s: float = s_cover
	var has_box: bool = box.size.x > 0.0 and box.size.y > 0.0
	var bpx: Rect2 = Rect2(box.position * isz, box.size * isz)
	if has_box:
		s = clampf(minf(area.x / bpx.size.x, area.y / bpx.size.y), s_contain, s_cover)
	var vis: Vector2 = area / s
	var origin: Vector2 = focus * isz - vis * 0.5
	for ax: int in 2:
		if vis[ax] >= isz[ax]:
			origin[ax] = (isz[ax] - vis[ax]) * 0.5
			continue
		if has_box and vis[ax] >= bpx.size[ax]:
			origin[ax] = clampf(origin[ax], bpx.end[ax] - vis[ax], bpx.position[ax])
		origin[ax] = clampf(origin[ax], 0.0, isz[ax] - vis[ax])
	var src: Rect2 = Rect2(origin, vis).intersection(Rect2(Vector2.ZERO, isz))
	var dst: Rect2 = Rect2((src.position - origin) * s, src.size * s)
	return [src, dst, s < s_cover - 0.0001]


func _draw() -> void:
	var l: Array = layout(size)
	var src: Rect2 = l[0]
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	if bool(l[2]):
		# the bars: the painting's own edge (a 2 px strip of its backdrop) stretched out, a touch
		# darker, so the wall or sky just carries on behind the subject
		var dst: Rect2 = l[1]
		if dst.position.x > 0.5 or dst.end.x < size.x - 0.5:
			draw_texture_rect_region(art, Rect2(0.0, dst.position.y, dst.position.x + 1.0, dst.size.y), Rect2(src.position.x, src.position.y, 2.0, src.size.y), BACKDROP)
			draw_texture_rect_region(art, Rect2(dst.end.x - 1.0, dst.position.y, size.x - dst.end.x + 1.0, dst.size.y), Rect2(src.end.x - 2.0, src.position.y, 2.0, src.size.y), BACKDROP)
		else:
			draw_texture_rect_region(art, Rect2(dst.position.x, 0.0, dst.size.x, dst.position.y + 1.0), Rect2(src.position.x, src.position.y, src.size.x, 2.0), BACKDROP)
			draw_texture_rect_region(art, Rect2(dst.position.x, dst.end.y - 1.0, dst.size.x, size.y - dst.end.y + 1.0), Rect2(src.position.x, src.end.y - 2.0, src.size.x, 2.0), BACKDROP)
	draw_texture_rect_region(art, l[1], src)
