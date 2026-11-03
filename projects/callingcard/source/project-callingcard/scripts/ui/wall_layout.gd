# wall_layout.gd
# Purpose: Container that lays out the 10 bricks of the wall in the 3-4-3 offset pattern
#   (spec §4.1): row B has 4 bricks; rows A and C have 3, shifted by half a brick.
#        [ a1 ][ a2 ][ a3 ]
#     [ b1 ][ b2 ][ b3 ][ b4 ]
#        [ c1 ][ c2 ][ c3 ]
#   Children are placed by their `slot_id` property (WallSlot). brick_size is set by the duel
#   screen from the room it has (DuelScreen.brick_size_for); the container's minimum size is
#   exactly the wall, and the wall is centered in whatever rect the parent gives it.
# Dependencies: none.
# Author: UI/UX Agent (cc07)
@tool
extends Container

const ROWS: Array = [[&"a1", &"a2", &"a3"], [&"b1", &"b2", &"b3", &"b4"], [&"c1", &"c2", &"c3"]]

@export var brick_size: Vector2 = Vector2(256, 64):
	set(v):
		brick_size = v
		update_minimum_size()
		queue_sort()
@export var gap: Vector2 = Vector2(10, 10):
	set(v):
		gap = v
		update_minimum_size()
		queue_sort()


static func wall_size(brick: Vector2, g: Vector2) -> Vector2:
	return Vector2(brick.x * 4.0 + g.x * 3.0, brick.y * 3.0 + g.y * 2.0)


func _get_minimum_size() -> Vector2:
	return wall_size(brick_size, gap)


## Top-left of a brick inside the wall (before centering).
func brick_position(slot_id: StringName) -> Vector2:
	for r: int in ROWS.size():
		var row: Array = ROWS[r]
		var i: int = row.find(slot_id)
		if i >= 0:
			var x0: float = 0.0 if row.size() == 4 else (brick_size.x + gap.x) * 0.5
			return Vector2(x0 + i * (brick_size.x + gap.x), r * (brick_size.y + gap.y))
	return Vector2(-1, -1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var origin: Vector2 = ((size - _get_minimum_size()) * 0.5).floor()
		for child: Node in get_children():
			if not child is Control:
				continue
			# slot_id from WallSlot; the node name (a1..c3) in the editor, where WallSlot is not a tool script.
			var id: StringName = child.slot_id if "slot_id" in child else StringName(String(child.name).to_lower())
			var p: Vector2 = brick_position(id)
			if p.x < 0.0:
				continue
			fit_child_in_rect(child, Rect2(origin + p, brick_size))
