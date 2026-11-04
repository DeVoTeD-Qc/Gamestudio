# area_tile.gd
# Purpose: CzAreaTile (cz16), one Ridge Hollow area on the map, in its open or gassed state
#   (art-direction.md section 4). Clipped-corner plate, 120x64 pt (ring) or 136x76 pt (Core).
#   Open: dune ground, top-down glyph in basalt + rust, 2 pt zone_edge border, name tag, Cover badge,
#   one loot pip per pile with the top card's rarity letter.
#   Gassed: base darkened 40 % and desaturated, gas_lime at 55 % with a 45 deg gas_shade hatch (6 pt pitch;
#   the hatch carries "gas" in greyscale), 3 pt dashed gas_glow border (10/5), a GAS tag with the gas icon
#   and the "-1 HIT AT END" hint, loot pips greyed out with a padlock.
#   Pawns: 28 pt discs, player = paper disc + ink chevron, AI = ink disc + paper square (shape, not
#   colour); a pawn in gas gets a pulsing gas_glow ring (static with reduced motion).
#   The whole tile is a tap target. Measures are in pt and scale with the tile width.
# Usage:
#   var tile := CzAreaTile.new()
#   tile.configure({"id": "radio_hill", "name": "Radio Hill", "cover": 0, "piles": [{"rarity": "U"}, {"rarity": "U"}]})
#   tile.size = CzArtKit.TILE_PT / pt_per_px     # CORE_TILE_PT for the Core
#   tile.gassed = true; tile.pawns = [&"player", &"ai"]; tile.selected = true
#   signal pressed(area_id)
#   tile.layout_report() -> {k, boxes {name: Rect2}, texts {name: px}}
# Dependencies: CzArtKit, CzIcons, Settings (optional)
# Author: Technical Artist Agent (cz16)
class_name CzAreaTile
extends Control

signal pressed(area_id: StringName)

const CUT_PT: float = 8.0
const PAWN_PT: float = 28.0
const PIP_PT := Vector2(13, 15)
const GAS_PULSE_S: float = 1.2

var area_id: StringName = &""
var area_name: String = "AREA"
var cover: int = 0
var core: bool = false
## One entry per loot pile: {rarity: "U", drop: false, crate: false, count: 3}.
var piles: Array = []
@export var gassed: bool = false : set = _set_gassed
@export var selected: bool = false : set = _set_selected
var pawns: Array = [] : set = _set_pawns

var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CzArtKit.TILE_PT


func configure(area: Variant) -> void:
	var d: Dictionary = CzCardArt.as_dict(area)
	area_id = StringName(str(CzCardArt.field(d, ["id", "area_id"], "")).to_lower().replace(" ", "_"))
	area_name = str(CzCardArt.field(d, ["name", "display_name"], String(area_id).capitalize()))
	cover = int(CzCardArt.field(d, ["cover"], 0))
	# cz05 AreaData: tier 1 = CORE.
	core = bool(CzCardArt.field(d, ["core", "is_core"], false)) or int(CzCardArt.field(d, ["tier"], 0)) == 1 or area_id == &"old_town"
	piles = []
	for p: Variant in CzCardArt.field(d, ["piles", "loot"], []):
		if p is Dictionary:
			piles.append(p)
		elif p is Object:
			var info: Dictionary = CzCardArt.read(p)
			piles.append({"rarity": String(info["rarity"]), "drop": info["drop"]})
		else:
			piles.append({"rarity": str(p)})
	if d.has("gassed"):
		gassed = bool(d["gassed"])
	custom_minimum_size = design_pt()
	queue_redraw()


func design_pt() -> Vector2:
	return CzArtKit.CORE_TILE_PT if core else CzArtKit.TILE_PT


func px_per_pt() -> float:
	var d: Vector2 = design_pt()
	return minf(size.x / d.x, size.y / d.y)


func _set_gassed(v: bool) -> void:
	gassed = v
	_update_process()
	queue_redraw()


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _set_pawns(v: Array) -> void:
	pawns = v
	_update_process()
	queue_redraw()


func _ready() -> void:
	_update_process()


func _update_process() -> void:
	set_process(gassed and not pawns.is_empty() and not _reduced_motion())


func _process(delta: float) -> void:
	_t = fmod(_t + delta, GAS_PULSE_S)
	queue_redraw()


func _reduced_motion() -> bool:
	if not is_inside_tree():
		return false
	var s: Node = get_node_or_null("/root/Settings")
	return s != null and bool(s.get("reduced_motion"))


func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var xf: Transform2D = get_viewport().get_screen_transform() * get_global_transform_with_canvas()
	return maxf(1.0, maxf(absf(xf.get_scale().x), absf(xf.get_scale().y)))


static func _fpx(pt: float, k: float) -> int:
	return maxi(1, int(ceilf(pt * k - 0.001)))


## Boxes (local px) and text sizes for the current state.
func layout_report() -> Dictionary:
	var k: float = px_per_pt()
	var dpt: Vector2 = design_pt()
	var font: Font = CzArtKit.font_display()
	var boxes: Dictionary = {}
	var texts: Dictionary = {}
	var np: int = _fpx(12.0, k)
	texts["name"] = np
	var nw: float = font.get_string_size(area_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, np).x
	boxes["name_tag"] = Rect2(Vector2(6.0, 4.0) * k, Vector2(nw + 8.0 * k, 15.0 * k))
	if cover > 0:
		boxes["cover"] = Rect2(Vector2(boxes["name_tag"].end.x + 3.0 * k, 4.0 * k), Vector2(13.0, 15.0) * k)
		texts["cover"] = _fpx(10.0, k)
	if gassed:
		var gp: int = _fpx(10.0, k)
		texts["gas_tag"] = gp
		texts["hint"] = gp
		var gw: float = font.get_string_size("GAS", HORIZONTAL_ALIGNMENT_LEFT, -1, gp).x + 6.0 * k
		boxes["gas_tag"] = Rect2(Vector2(6.0, 20.0) * k, Vector2(gw, 12.0 * k))
		boxes["gas_icon"] = Rect2(Vector2(boxes["gas_tag"].end.x + 2.0 * k, 20.0 * k), Vector2(12.0, 12.0) * k)
		var hw: float = font.get_string_size("-1 HIT AT END", HORIZONTAL_ALIGNMENT_LEFT, -1, gp).x
		boxes["hint"] = Rect2(Vector2(boxes["gas_icon"].end.x + 2.0 * k, 20.0 * k + (12.0 * k - gp * 0.72) * 0.5), Vector2(hw, gp * 0.72))
	# Loot pips: up to 3 per row; ring row at y 44, Core rows at y 38 and 56.
	var row_y: Array = [38.0, 56.0] if core else [44.0, 26.0]
	texts["pip_letter"] = _fpx(10.0, k)
	var n: int = piles.size() + (1 if gassed and not piles.is_empty() else 0)
	for i: int in n:
		var row: int = i / 3
		var col: int = i % 3
		var y: float = row_y[mini(row, row_y.size() - 1)]
		var key: String = "pip%d" % i if i < piles.size() else "padlock"
		# Gassed rows add a padlock, so pips pack tighter (4 x 12 pt) to stay clear of the pawns.
		var step: float = 12.0 if gassed else PIP_PT.x + 2.0
		var pw: float = 11.0 if gassed else PIP_PT.x
		var cols: int = 4 if gassed else 3
		row = i / cols
		col = i % cols
		y = row_y[mini(row, row_y.size() - 1)]
		boxes[key] = Rect2(Vector2(6.0 + float(col) * step, y) * k, Vector2(pw, PIP_PT.y) * k)
	# Pawns: bottom-right, right-aligned row of 28 pt discs.
	var pr: float = PAWN_PT * 0.5
	for i: int in pawns.size():
		var cx: float = dpt.x - 4.0 - pr - float(i) * (PAWN_PT + 2.0)
		var cy: float = dpt.y - 4.0 - pr  # clear of the bottom-right corner cut
		boxes["pawn%d" % i] = Rect2(Vector2(cx - pr, cy - pr) * k, Vector2(PAWN_PT, PAWN_PT) * k)
	boxes["glyph"] = Rect2(Vector2(dpt.x - 4.0 - (dpt.y - 10.0), 5.0) * k, Vector2(dpt.y - 10.0, dpt.y - 10.0) * k)
	return {"k": k, "boxes": boxes, "texts": texts, "gassed": gassed}


func _draw() -> void:
	var lay: Dictionary = layout_report()
	var k: float = lay["k"]
	var boxes: Dictionary = lay["boxes"]
	var texts: Dictionary = lay["texts"]
	var rect := Rect2(Vector2.ZERO, size)
	var cut: float = CUT_PT * k
	var poly: PackedVector2Array = CzArtKit.tag_points(rect, cut)
	var font: Font = CzArtKit.font_display()
	var num: Font = CzArtKit.font_numeral()
	var ss: float = _screen_scale()
	if selected:
		CzArtKit.draw_tag(self, rect.grow(4.0 * k), cut + 2.0 * k, Color(0, 0, 0, 0), CzArtKit.PAPER, 2.0 * k)
	# Ground and glyph.
	draw_colored_polygon(poly, CzArtKit.gas_tone(CzArtKit.DUNE) if gassed else CzArtKit.DUNE)
	var gr: Rect2 = boxes["glyph"]
	var glyph: Texture2D = CzIcons.area_glyph(area_id, gr.size.x * ss, gassed)
	if glyph != null:
		draw_texture_rect(glyph, gr, false)
	if gassed:
		draw_colored_polygon(poly, Color(CzArtKit.GAS_LIME, 0.55))
		_draw_hatch(poly, k)
		CzArtKit.draw_tag(self, rect, cut, Color(0, 0, 0, 0), CzArtKit.GAS_GLOW, 3.0 * k, true, 10.0 * k)
	else:
		CzArtKit.draw_tag(self, rect, cut, Color(0, 0, 0, 0), CzArtKit.ZONE_EDGE, 2.0 * k)
	# Name tag + Cover badge.
	var nt: Rect2 = boxes["name_tag"]
	draw_rect(nt, CzArtKit.PAPER)
	draw_string(font, Vector2(nt.position.x + 4.0 * k, nt.get_center().y + texts["name"] * 0.36), area_name.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, texts["name"], CzArtKit.INK)
	if boxes.has("cover"):
		var cb: Rect2 = boxes["cover"]
		var sp: PackedVector2Array = CzArtKit.shield_points(cb)
		draw_colored_polygon(sp, CzArtKit.BRACE_STEEL)
		var closed: PackedVector2Array = sp.duplicate()
		closed.append(sp[0])
		draw_polyline(closed, CzArtKit.INK, maxf(1.0, 1.2 * k), true)
		var cs: String = str(cover)
		var cw: float = num.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, texts["cover"]).x
		draw_string(num, Vector2(cb.get_center().x - cw * 0.5, cb.get_center().y - 1.0 * k + texts["cover"] * 0.36), cs,
				HORIZONTAL_ALIGNMENT_LEFT, -1, texts["cover"], CzArtKit.INK)
	if gassed:
		var gt: Rect2 = boxes["gas_tag"]
		draw_rect(gt, CzArtKit.GAS_GLOW)
		draw_string(font, Vector2(gt.position.x + 3.0 * k, gt.get_center().y + texts["gas_tag"] * 0.36), "GAS",
				HORIZONTAL_ALIGNMENT_LEFT, -1, texts["gas_tag"], CzArtKit.INK)
		var gi: Rect2 = boxes["gas_icon"]
		draw_rect(gi.grow(1.0 * k), CzArtKit.INK)
		var gtex: Texture2D = CzIcons.get_icon(&"gas", gi.size.x * ss)
		if gtex != null:
			draw_texture_rect(gtex, gi, false, CzArtKit.GAS_GLOW)
		var hb: Rect2 = boxes["hint"]
		draw_rect(hb.grow(1.5 * k), Color(CzArtKit.INK, 0.85))
		draw_string(font, Vector2(hb.position.x, hb.end.y), "-1 HIT AT END", HORIZONTAL_ALIGNMENT_LEFT, -1, texts["hint"], CzArtKit.GAS_GLOW)
	_draw_pips(boxes, texts, k, ss)
	_draw_pawns(boxes, k)


## 45 deg hatch of gas_shade stripes (6 pt pitch, 3 pt stripes), clipped to the plate.
func _draw_hatch(poly: PackedVector2Array, k: float) -> void:
	var pitch: float = 6.0 * k
	var w: float = 3.0 * k
	var x: float = -size.y
	while x < size.x:
		var stripe := PackedVector2Array([Vector2(x, size.y), Vector2(x + w, size.y), Vector2(x + w + size.y, 0), Vector2(x + size.y, 0)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(stripe, poly):
			draw_colored_polygon(part, Color(CzArtKit.GAS_SHADE, 0.7))
		x += pitch


func _draw_pips(boxes: Dictionary, texts: Dictionary, k: float, ss: float) -> void:
	var font: Font = CzArtKit.font_display()
	for i: int in piles.size():
		var r: Rect2 = boxes["pip%d" % i]
		var p: Dictionary = piles[i]
		var rar: Dictionary = CzArtKit.rarity(p.get("rarity", ""))
		var col: Color = rar.get("color", CzArtKit.STARTER_STRIPE)
		var txt: Color = rar.get("text", CzArtKit.PAPER)
		if gassed:
			col = CzArtKit.gas_tone(col).lerp(Color(0.5, 0.5, 0.5), 0.3)
			txt = Color(CzArtKit.PAPER, 0.6)
		CzArtKit.draw_tag(self, r, 3.0 * k, col, CzArtKit.INK, maxf(1.0, 1.0 * k))
		if bool(p.get("drop", false)) or bool(p.get("crate", false)):
			var icon: StringName = &"supply_drop" if bool(p.get("drop", false)) else &"crate_open"
			var tex: Texture2D = CzIcons.get_icon(icon, r.size.x * ss)
			if tex != null:
				var ir := Rect2(r.position + Vector2(1.5, 2.0) * k, Vector2(r.size.x - 3.0 * k, r.size.x - 3.0 * k))
				draw_texture_rect(tex, ir, false, txt)
		else:
			var letter: String = rar.get("letter", "S")
			var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, texts["pip_letter"]).x
			draw_string(font, Vector2(r.get_center().x - w * 0.5, r.get_center().y + texts["pip_letter"] * 0.36), letter,
					HORIZONTAL_ALIGNMENT_LEFT, -1, texts["pip_letter"], txt)
	if boxes.has("padlock"):
		var lr: Rect2 = boxes["padlock"]
		var lt: Texture2D = CzIcons.get_icon(&"padlock", lr.size.y * ss)
		if lt != null:
			draw_texture_rect(lt, Rect2(lr.position, Vector2(lr.size.y, lr.size.y)).grow(-1.0 * k), false, CzArtKit.INK)


func _draw_pawns(boxes: Dictionary, k: float) -> void:
	for i: int in pawns.size():
		var r: Rect2 = boxes["pawn%d" % i]
		var c: Vector2 = r.get_center()
		var rad: float = r.size.x * 0.5
		var kind: String = str(pawns[i] if not (pawns[i] is Dictionary) else (pawns[i] as Dictionary).get("kind", "player"))
		if gassed:
			var pulse: float = 0.5 if _reduced_motion() else 0.5 + 0.5 * sin(_t / GAS_PULSE_S * TAU)
			draw_arc(c, rad + 2.5 * k, 0.0, TAU, 40, Color(CzArtKit.GAS_GLOW, 0.45 + 0.55 * pulse), (1.5 + 1.5 * pulse) * k, true)
		draw_circle(c + Vector2(0, 1.5 * k), rad, Color(0, 0, 0, 0.35))
		if kind == "ai":
			draw_circle(c, rad, CzArtKit.INK)
			draw_arc(c, rad - 0.75 * k, 0.0, TAU, 40, CzArtKit.PAPER, 1.5 * k, true)
			var s: float = rad * 0.75
			draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), CzArtKit.PAPER)
		else:
			draw_circle(c, rad, CzArtKit.PAPER)
			draw_arc(c, rad - 0.75 * k, 0.0, TAU, 40, CzArtKit.INK, 1.5 * k, true)
			var h: float = rad * 0.5
			draw_colored_polygon(PackedVector2Array([c + Vector2(-h, h * 0.55), c + Vector2(0, -h * 0.7), c + Vector2(h, h * 0.55),
					c + Vector2(h * 0.55, h * 0.75), c + Vector2(0, -h * 0.05), c + Vector2(-h * 0.55, h * 0.75)]), CzArtKit.INK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			pressed.emit(area_id)
			accept_event()
