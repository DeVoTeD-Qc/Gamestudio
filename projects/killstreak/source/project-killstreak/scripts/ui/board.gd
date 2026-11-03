# board.gd
# Purpose: The match board: three zones side by side in map order (Left, Mid, Right),
#   each a Lane with both sides' lines. Pure layout + display of a snapshot.
# Dependencies: lane.gd.
# Author: UI/UX Agent
extends HBoxContainer

@onready var _lanes: Array[Node] = [%LaneLeft, %LaneMid, %LaneRight]


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
