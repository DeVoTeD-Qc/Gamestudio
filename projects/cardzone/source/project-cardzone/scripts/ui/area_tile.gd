# area_tile.gd
# Purpose: One Ridge Hollow area on the match map (cz10 placeholder look from art-direction.md §4).
#   Open: dune plate, zone_edge border. Gassed: darkened plate, gas_lime overlay with a 45° hatch
#   (the hatch carries "gas" in greyscale), dashed gas_glow border, a GAS tag. The name tag,
#   Cover and loot count are text. Pawns differ by SHAPE, not colour: you = light disc with a
#   chevron, rival = dark disc with a square (plus a ring on a pawn standing in gas).
#   Tap = select (cz11: move here / loot); long-press / right-click = inspector (piles, Cover, gas).
# Dependencies: tap_hold_button.gd, match_theme.gd.
# Author: UI/UX Agent (cz10)
extends "res://scripts/ui/tap_hold_button.gd"

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")

var area_id: StringName = &""
var area: Dictionary = {}
var gas: bool = false
var loot_count: int = 0
var drop: StringName = &""
var you_here: bool = false
var rival_here: bool = false
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
## Pawn diameter in logical px (MatchScreen: 28 pt converted to px, min 28).
var pawn_d: float = 32.0:
	set(v):
		pawn_d = v
		_pawn_space.custom_minimum_size.y = v
		queue_redraw()

var _name: Label
var _info: Label
var _tags: HBoxContainer
var _gas_tag: Label
var _cover_tag: Label
var _drop_tag: Label
var _pawn_space: Control


func _init() -> void:
	super._init()
	theme_type_variation = &"TileButton"
	add_to_group(&"tap_target")
	clip_contents = true
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 4)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)
	margin.add_child(col)
	_name = _label(col, &"TileName")
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Two fixed rows (a flow container's minimum height depends on a width it may not have yet):
	#   [Loot N | GAS] [Cover N]
	#   [DROP]
	_tags = HBoxContainer.new()
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tags.add_theme_constant_override(&"separation", 4)
	col.add_child(_tags)
	_info = _label(_tags, &"TileText")
	_gas_tag = _label(_tags, &"TagGas")
	_gas_tag.text = "GAS"
	# Cover: a shield badge with the number (art-direction.md §4), drawn behind the label.
	_cover_tag = _label(_tags, &"TileText")
	_cover_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover_tag.custom_minimum_size = Vector2(26, 0)
	_cover_tag.item_rect_changed.connect(queue_redraw)
	_drop_tag = _label(col, &"TagDrop")
	_drop_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_drop_tag.text = "DROP"
	var fill: Control = Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	_pawn_space = Control.new()
	_pawn_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn_space.custom_minimum_size.y = pawn_d
	col.add_child(_pawn_space)


## a: mock_match_data AREAS entry; st: state["areas"][id]; you / rival: pawn here.
func setup(a: Dictionary, st: Dictionary, you: bool, rival: bool) -> void:
	area = a
	area_id = a["id"]
	gas = st.get("gas", false)
	drop = st.get("drop", &"")
	loot_count = (st.get("piles", []) as Array).size() + (1 if drop != &"" else 0)
	you_here = you
	rival_here = rival
	_name.text = String(a["name"]) if a["id"] != &"old_town" else "Old Town"
	# Gassed: no loot count (piles are locked; the inspector says so), the GAS tag instead.
	_info.text = "Loot %d" % loot_count
	_info.visible = not gas
	_gas_tag.visible = gas
	_cover_tag.visible = int(a.get("cover", 0)) > 0
	_cover_tag.text = str(int(a.get("cover", 0)))
	_drop_tag.visible = drop != &""
	queue_redraw()


func get_name_label() -> Label:
	return _name


func get_labels() -> Array[Label]:
	return [_name, _info, _gas_tag, _cover_tag, _drop_tag]


## Pawn centres in tile coordinates (tests: both pawns inside the tile, no overlap).
func pawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var y: float = size.y - 4.0 - pawn_d
	var x: float = 5.0
	if you_here:
		out.append(Rect2(x, y, pawn_d, pawn_d))
		x += pawn_d + 6.0
	if rival_here:
		out.append(Rect2(x, y, pawn_d, pawn_d))
	return out


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var core: bool = area_id == &"old_town"
	if gas:
		draw_rect(r, MatchTheme.DUNE.darkened(0.4).lerp(Color(0.45, 0.45, 0.45), 0.4))
		draw_rect(r, Color(MatchTheme.GAS_LIME, 0.55))
		# 45° hatch, 6 pt pitch (~9 px).
		var pitch: float = 10.0
		var t: float = -size.y
		while t < size.x:
			draw_line(Vector2(t, size.y), Vector2(t + size.y, 0), MatchTheme.GAS_SHADE, 2.0)
			t += pitch
		_dashed_rect(r.grow(-1.5), MatchTheme.GAS_GLOW, 3.0)
	else:
		draw_rect(r, MatchTheme.DUNE)
		draw_rect(r.grow(-1.0), MatchTheme.ZONE_EDGE if not core else MatchTheme.PAPER, false, 3.0 if core else 2.0)
	_draw_shield()
	if selected:
		draw_rect(r.grow(-3.0), MatchTheme.INK, false, 3.0)
	var rects: Array[Rect2] = pawn_rects()
	var i: int = 0
	if you_here:
		_draw_you(rects[i])
		i += 1
	if rival_here:
		_draw_rival(rects[i])


func _draw_you(rc: Rect2) -> void:
	var c: Vector2 = rc.get_center()
	var rad: float = rc.size.x * 0.5
	if gas:
		draw_arc(c, rad + 2.0, 0, TAU, 32, MatchTheme.GAS_GLOW, 3.0)
	draw_circle(c, rad, MatchTheme.PAPER)
	draw_arc(c, rad - 1.0, 0, TAU, 32, MatchTheme.INK, 2.0)
	var w: float = rad * 0.55
	draw_polyline(PackedVector2Array([c + Vector2(-w, w * 0.45), c + Vector2(0, -w * 0.55), c + Vector2(w, w * 0.45)]), MatchTheme.INK, 4.0)


func _draw_rival(rc: Rect2) -> void:
	var c: Vector2 = rc.get_center()
	var rad: float = rc.size.x * 0.5
	if gas:
		draw_arc(c, rad + 2.0, 0, TAU, 32, MatchTheme.GAS_GLOW, 3.0)
	draw_circle(c, rad, MatchTheme.INK)
	draw_arc(c, rad - 1.0, 0, TAU, 32, MatchTheme.PAPER, 2.0)
	var s: float = rad * 0.75
	draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), MatchTheme.PAPER)


## Shield behind the Cover number (the tile draws before its children, so the number sits on top).
func _draw_shield() -> void:
	if not _cover_tag.visible or not _cover_tag.is_inside_tree():
		return
	var r: Rect2 = _cover_tag.get_global_rect()
	var o: Vector2 = r.position - get_global_rect().position
	var w: float = r.size.x
	var h: float = r.size.y + 4.0
	o.y -= 1.0
	var pts: PackedVector2Array = [o + Vector2(0, 0), o + Vector2(w, 0), o + Vector2(w, h * 0.55),
			o + Vector2(w * 0.5, h), o + Vector2(0, h * 0.55)]
	draw_colored_polygon(pts, MatchTheme.BRACE_STEEL)
	pts.append(pts[0])
	draw_polyline(pts, MatchTheme.INK, 1.5)


func _dashed_rect(r: Rect2, color: Color, width: float) -> void:
	var pts: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k: int in 4:
		draw_dashed_line(pts[k], pts[k + 1], color, width, 10.0)


func _label(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
