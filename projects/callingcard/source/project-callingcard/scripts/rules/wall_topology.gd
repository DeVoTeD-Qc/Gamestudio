# wall_topology.gd
# Purpose: The brick-wall board (spec §4.1): slot ids, who touches whom and in which direction,
#   which printed value faces each direction (spec §4.3), and the row runs Triptychs score on (§4.5).
#   Built from BalanceConfig.wall_rows (default 3/4/3 -> a1..a3, b1..b4, c1..c3, 19 edges).
#   Pure data, no nodes. Topologies are cached per row layout, so get_for() is cheap.
# Dependencies: BalanceConfig (row letters only).
# Author: Mechanics Developer Agent
class_name WallTopology
extends RefCounted

## Direction of a neighbour as seen from a slot.
enum Dir { ABOVE, BELOW, LEFT, RIGHT }

## Printed value names, used by effective_values dictionaries.
const TOP: StringName = &"top"
const SIDE: StringName = &"side"
const BOTTOM: StringName = &"bottom"
const DIR_NAMES: Array[StringName] = [&"above", &"below", &"left", &"right"]

static var _cache: Dictionary = {}

## Every slot id, row by row.
var slots: Array[StringName] = []
## Bricks per row, top to bottom.
var rows: PackedInt32Array = PackedInt32Array()
## slot -> Array[Dictionary] of {slot: StringName, dir: Dir}, in order above, left, right, below.
var _neighbours: Dictionary = {}
## slot -> row index.
var _row_of: Dictionary = {}
## Every run of 3 consecutive slots in one row (Triptych positions).
var runs_of_three: Array = []


## The topology for a row layout (cached). Default: the spec's 3/4/3 wall.
static func get_for(wall_rows: PackedInt32Array = PackedInt32Array([3, 4, 3])) -> WallTopology:
	var key: String = str(wall_rows)
	if not _cache.has(key):
		var t: WallTopology = WallTopology.new()
		t._build(wall_rows)
		_cache[key] = t
	return _cache[key]


## The value a card attacks with towards a neighbour in direction `dir`.
static func attack_value_name(dir: Dir) -> StringName:
	match dir:
		Dir.ABOVE:
			return TOP
		Dir.BELOW:
			return BOTTOM
	return SIDE


## The value the neighbour defends with (the face pointing back at the attacker).
static func defend_value_name(dir: Dir) -> StringName:
	match dir:
		Dir.ABOVE:
			return BOTTOM
		Dir.BELOW:
			return TOP
	return SIDE


func is_slot(slot: StringName) -> bool:
	return _neighbours.has(slot)


func slot_count() -> int:
	return slots.size()


## [{slot, dir}] for every neighbour of `slot` (empty for an unknown slot).
func neighbours(slot: StringName) -> Array:
	return _neighbours.get(slot, [])


## Just the neighbour slot ids.
func neighbour_slots(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Dictionary in neighbours(slot):
		out.append(n["slot"])
	return out


## Neighbours of `slot` in one direction, e.g. neighbours_in(&"b2", Dir.ABOVE) == [a1, a2].
func neighbours_in(slot: StringName, dir: Dir) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Dictionary in neighbours(slot):
		if n["dir"] == dir:
			out.append(n["slot"])
	return out


func are_adjacent(a: StringName, b: StringName) -> bool:
	return neighbour_slots(a).has(b)


func row_of(slot: StringName) -> int:
	return _row_of.get(slot, -1)


func edge_count() -> int:
	var total: int = 0
	for s: StringName in slots:
		total += neighbours(s).size()
	return total / 2


func _build(wall_rows: PackedInt32Array) -> void:
	rows = wall_rows
	var grid: Array = []  # grid[row][col] -> slot id
	for r: int in mini(wall_rows.size(), BalanceConfig.ROW_LETTERS.length()):
		var row: Array[StringName] = []
		for c: int in wall_rows[r]:
			var id: StringName = StringName("%s%d" % [BalanceConfig.ROW_LETTERS[r], c + 1])
			row.append(id)
			slots.append(id)
			_row_of[id] = r
			_neighbours[id] = []
		grid.append(row)
	for r: int in grid.size():
		var row: Array = grid[r]
		for c: int in row.size():
			var id: StringName = row[c]
			var list: Array = _neighbours[id]
			if r > 0:
				for s: StringName in _touching(grid[r - 1], row.size(), c):
					list.append({"slot": s, "dir": Dir.ABOVE})
			if c > 0:
				list.append({"slot": row[c - 1], "dir": Dir.LEFT})
			if c < row.size() - 1:
				list.append({"slot": row[c + 1], "dir": Dir.RIGHT})
			if r < grid.size() - 1:
				for s: StringName in _touching(grid[r + 1], row.size(), c):
					list.append({"slot": s, "dir": Dir.BELOW})
		for c: int in row.size() - 2:
			runs_of_three.append([row[c], row[c + 1], row[c + 2]] as Array[StringName])


## Bricks of an adjacent row touching column `c` of a row with `own_len` bricks. Rows are offset by
## half a brick: a short row's brick i sits on the long row's bricks i and i+1; a long row's
## brick j touches the short row's bricks j-1 and j.
func _touching(other: Array, own_len: int, c: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var cols: Array = [c, c + 1] if other.size() > own_len else [c - 1, c]
	for oc: int in cols:
		if oc >= 0 and oc < other.size():
			out.append(other[oc])
	return out
