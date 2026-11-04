# map_view.gd
# Purpose: CzMap (cz16), the Ridge Hollow map: 7 CzAreaTile plates in the spec's layout (loadout-loop
#   spec section 3: Docks and Farmstead on top, Rail Yard / Old Town (Core) / Quarry in the middle,
#   Motel and Radio Hill below) on a shoal sea with a muted island, plus the adjacency links (ring
#   1-2-3-4-5-6-1, every outer area to the Core) drawn as basalt stencil dashes under the tiles.
#   The map scales to fit its rect (design 416 x 248 pt) and stays centred.
# Usage:
#   var map := CzMap.new()
#   map.configure(areas)              # Array of area Dictionaries/Resources (id, name, cover, piles, core)
#   map.set_state({"gassed": [&"docks"], "pawns": {&"radio_hill": [&"player"], &"old_town": [&"ai"]},
#       "selected": &"quarry"})
#   map.tile(&"docks") -> CzAreaTile;  signal area_pressed(area_id)
# Dependencies: CzArtKit, CzAreaTile
# Author: Technical Artist Agent (cz16)
class_name CzMap
extends Control

signal area_pressed(area_id: StringName)

const DESIGN_PT := Vector2(416, 248)
## Tile centres in design pt.
const CENTRES: Dictionary = {
	&"docks": Vector2(138, 52), &"farmstead": Vector2(278, 52),
	&"rail_yard": Vector2(68, 124), &"old_town": Vector2(208, 124), &"quarry": Vector2(348, 124),
	&"motel": Vector2(138, 196), &"radio_hill": Vector2(278, 196),
}
const RING: Array[StringName] = [&"docks", &"farmstead", &"quarry", &"radio_hill", &"motel", &"rail_yard"]
const CORE_ID: StringName = &"old_town"

var _tiles: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = DESIGN_PT * 0.5


func _ready() -> void:
	resized.connect(_relayout)
	_relayout()


func configure(areas: Array) -> void:
	for t: CzAreaTile in _tiles.values():
		t.queue_free()
	_tiles.clear()
	for a: Variant in areas:
		var tile := CzAreaTile.new()
		tile.configure(a)
		tile.pressed.connect(func(id: StringName) -> void: area_pressed.emit(id))
		add_child(tile)
		_tiles[tile.area_id] = tile
	_relayout()


func tile(area_id: StringName) -> CzAreaTile:
	return _tiles.get(area_id)


func tiles() -> Array:
	return _tiles.values()


## {gassed: Array of ids, pawns: {id: [kinds]}, selected: id}. Missing keys leave that part as is.
func set_state(state: Dictionary) -> void:
	if state.has("gassed"):
		var g: Array = state["gassed"]
		for id: StringName in _tiles:
			_tiles[id].gassed = g.has(id) or g.has(String(id))
	if state.has("pawns"):
		var p: Dictionary = state["pawns"]
		for id: StringName in _tiles:
			_tiles[id].pawns = p.get(id, p.get(String(id), []))
	if state.has("selected"):
		for id: StringName in _tiles:
			_tiles[id].selected = StringName(str(state["selected"])) == id
	queue_redraw()


func px_per_pt() -> float:
	return minf(size.x / DESIGN_PT.x, size.y / DESIGN_PT.y)


func _origin() -> Vector2:
	return (size - DESIGN_PT * px_per_pt()) * 0.5


func _relayout() -> void:
	var k: float = px_per_pt()
	var o: Vector2 = _origin()
	for id: StringName in _tiles:
		var t: CzAreaTile = _tiles[id]
		var c: Vector2 = CENTRES.get(id, DESIGN_PT * 0.5)
		var d: Vector2 = t.design_pt()
		t.position = o + (c - d * 0.5) * k
		t.size = d * k
	queue_redraw()


func _draw() -> void:
	var k: float = px_per_pt()
	var o: Vector2 = _origin()
	var r := Rect2(o, DESIGN_PT * k)
	draw_rect(r, CzArtKit.SHOAL.darkened(0.25))
	# Island: a muted ring of land under the tiles.
	var pts := PackedVector2Array()
	var c: Vector2 = o + CENTRES[CORE_ID] * k
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		var wob: float = 1.0 + 0.04 * sin(a * 5.0) + 0.03 * cos(a * 3.0)
		pts.append(c + Vector2(cos(a) * 196.0, sin(a) * 112.0) * k * wob)
	draw_colored_polygon(pts, CzArtKit.SCRUB.darkened(0.35))
	# Adjacency links.
	var col := Color(CzArtKit.BASALT, 0.9)
	for i: int in RING.size():
		_link(RING[i], RING[(i + 1) % RING.size()], o, k, col)
		_link(RING[i], CORE_ID, o, k, col)


func _link(a: StringName, b: StringName, o: Vector2, k: float, col: Color) -> void:
	if not _tiles.has(a) or not _tiles.has(b):
		return
	draw_dashed_line(o + CENTRES[a] * k, o + CENTRES[b] * k, col, maxf(1.0, 3.0 * k), 6.0 * k, false)
