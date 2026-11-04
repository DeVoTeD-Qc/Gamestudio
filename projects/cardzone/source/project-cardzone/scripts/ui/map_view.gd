# map_view.gd
# Purpose: Container that lays out the 7 Ridge Hollow area tiles as the spec §3 diagram:
#        [1 Docks]   [2 Farmstead]
#   [6 Rail Yard] [C Old Town] [3 Quarry]
#        [5 Motel]   [4 Radio Hill]
#   Rows 1 and 3 sit half a tile in, so ring neighbours touch and the Core touches all six.
#   Tiles are equal size and fill the container (3 columns x 3 rows minus gaps).
# Dependencies: none (children are AreaTile nodes named by area id).
# Author: UI/UX Agent (cz10)
extends Container

## area id -> (column, row); columns in tile units.
const SLOTS: Dictionary = {
	&"docks": Vector2(0.5, 0), &"farmstead": Vector2(1.5, 0),
	&"rail_yard": Vector2(0, 1), &"old_town": Vector2(1, 1), &"quarry": Vector2(2, 1),
	&"motel": Vector2(0.5, 2), &"radio_hill": Vector2(1.5, 2),
}
const MIN_TILE: Vector2 = Vector2(96, 96)

var gap: float = 8.0:
	set(v):
		gap = v
		update_minimum_size()
		queue_sort()


func _get_minimum_size() -> Vector2:
	return MIN_TILE * 3.0 + Vector2(gap, gap) * 2.0


func tile_size() -> Vector2:
	return ((size - Vector2(gap, gap) * 2.0) / 3.0).floor()


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var t: Vector2 = tile_size()
	for c: Node in get_children():
		if c is Control and SLOTS.has(StringName(c.name)):
			var slot: Vector2 = SLOTS[StringName(c.name)]
			var pos: Vector2 = Vector2(slot.x * (t.x + gap), slot.y * (t.y + gap))
			fit_child_in_rect(c, Rect2(pos.floor(), t))
