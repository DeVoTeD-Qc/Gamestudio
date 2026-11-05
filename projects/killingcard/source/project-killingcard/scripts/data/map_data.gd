# map_data.gd
# Purpose: A match map (core-rules §1): three zones Left Flank - Mid - Right Flank,
#   each with a name and a range tag. One map = one .tres in res://data/maps/.
# Dependencies: DataEnums, DataValidator.
# Author: Mechanics Developer Agent
class_name MapData
extends Resource

const ZONE_COUNT: int = 3
## Zone ids in board order, matching EventBus (&"left", &"mid", &"right").
const ZONE_IDS: Array[StringName] = [&"left", &"mid", &"right"]

## Unique id, lowercase snake_case (e.g. port_vasel).
@export var id: StringName = &""
@export var display_name: String = ""
## Zone names in order Left, Mid, Right (e.g. "Container Stacks").
@export var zone_names: PackedStringArray = PackedStringArray(["", "", ""])
## Zone range tags in order Left, Mid, Right.
@export var zone_ranges: Array[DataEnums.RangeTag] = [
	DataEnums.RangeTag.CLOSE, DataEnums.RangeTag.MID, DataEnums.RangeTag.LONG,
]


## Range tag of a zone by id (&"left"/&"mid"/&"right").
func range_of(zone_id: StringName) -> DataEnums.RangeTag:
	return zone_ranges[ZONE_IDS.find(zone_id)]


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	if zone_names.size() != ZONE_COUNT:
		v.out_of_range("zone_names", "needs exactly %d zone names (got %d)" % [ZONE_COUNT, zone_names.size()])
	else:
		for i: int in ZONE_COUNT:
			v.require_text("zone_names[%d]" % i, zone_names[i])
	if zone_ranges.size() != ZONE_COUNT:
		v.out_of_range("zone_ranges", "needs exactly %d zone ranges (got %d)" % [ZONE_COUNT, zone_ranges.size()])
	for i: int in zone_ranges.size():
		v.check_enum("zone_ranges[%d]" % i, zone_ranges[i], DataEnums.RangeTag)
