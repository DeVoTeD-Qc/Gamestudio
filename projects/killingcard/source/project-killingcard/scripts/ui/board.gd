# board.gd
# Purpose: The match board: three zones side by side in map order (Left, Mid, Right),
#   each a Lane with both sides' lines. Layout + display of a snapshot; forwards the lanes'
#   taps / long-presses with the zone index (0 = left, 1 = mid, 2 = right, RulesIntent order).
# Dependencies: lane.gd.
# Author: UI/UX Agent
extends HBoxContainer

## slot_side / uid: the unit slot that was hit (&"" / -1 for empty space or an empty slot).
signal lane_tapped(zone: int, slot_side: StringName, uid: int)
signal lane_long_pressed(zone: int, slot_side: StringName, uid: int)

@onready var _lanes: Array[Node] = [%LaneLeft, %LaneMid, %LaneRight]


func _ready() -> void:
	for i: int in _lanes.size():
		var zone: int = i
		_lanes[i].tapped.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			lane_tapped.emit(zone, slot_side, uid))
		_lanes[i].long_pressed.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			lane_long_pressed.emit(zone, slot_side, uid))


## Index of the lane under a canvas position (drag drops), or -1.
func lane_index_at(global_pos: Vector2) -> int:
	for i: int in _lanes.size():
		if (_lanes[i] as Control).get_global_rect().has_point(global_pos):
			return i
	return -1


## targets: one {state, text} per lane (lane.gd TARGET_*); empty Array clears every lane.
func show_targets(targets: Array) -> void:
	for i: int in _lanes.size():
		var t: Dictionary = targets[i] if i < targets.size() else {}
		_lanes[i].set_target(t.get("state", &"none"), String(t.get("text", "")))


func set_unit_targets(uids: Array) -> void:
	for lane: Node in _lanes:
		lane.set_unit_targets(uids)


## lanes: Array of lane Dictionaries in map order (see mock_match_data.gd).
func set_lanes(lanes: Array) -> void:
	for i: int in mini(lanes.size(), _lanes.size()):
		_lanes[i].set_lane(lanes[i])


func get_lanes() -> Array[Node]:
	return _lanes


func set_compact(compact: bool) -> void:
	add_theme_constant_override(&"separation", 6 if compact else 8)
	for lane: Node in _lanes:
		lane.set_compact(compact)


## Returns the Lane for a zone id (&"left", &"mid", &"right"), or null.
func get_lane(zone_id: StringName) -> Node:
	for lane: Node in _lanes:
		if lane.zone_id == zone_id:
			return lane
	return null
