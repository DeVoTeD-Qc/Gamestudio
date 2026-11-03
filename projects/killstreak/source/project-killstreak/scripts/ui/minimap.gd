# minimap.gd
# Purpose: Minimap intel strip (top-center). One cell per zone in map order showing
#   the enemy's committed deployments as red dots (count only, core-rules.md 2.1).
#   The count is also printed, so the dots never rely on color alone.
#   Recon "flip to silhouettes" and the sweep animation are p14.
#   Compact (phone) profile: narrower cells, smaller dots.
# Dependencies: hud_theme.tres variations (MinimapCell, RedDot).
# Author: UI/UX Agent
extends PanelContainer

const CELL_WIDTH: float = 92.0
const CELL_WIDTH_COMPACT: float = 78.0
const DOT_SIZE: float = 20.0
const DOT_SIZE_COMPACT: float = 16.0

var compact: bool = false
var _lanes: Array = []

@onready var _cells: HBoxContainer = %Cells


func set_compact(value: bool) -> void:
	if value == compact:
		return
	compact = value
	set_intel(_lanes)


## Labels whose whole text must stay visible (zone labels and red-dot counts).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	for label: Node in _cells.find_children("*", "Label", true, false):
		out.append(label)
	return out


## lanes: lane Dictionaries in map order; reads label and incoming.
func set_intel(lanes: Array) -> void:
	_lanes = lanes
	for child: Node in _cells.get_children():
		_cells.remove_child(child)
		child.queue_free()
	for lane: Dictionary in lanes:
		_cells.add_child(_make_cell(String(lane.get("label", "?")), int(lane.get("incoming", 0))))


func _make_cell(label_text: String, count: int) -> Control:
	var cell: PanelContainer = PanelContainer.new()
	cell.theme_type_variation = &"MinimapCell"
	cell.custom_minimum_size = Vector2(CELL_WIDTH_COMPACT if compact else CELL_WIDTH, 0)
	cell.name = "Cell%s" % label_text.capitalize()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	cell.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var label: Label = Label.new()
	label.theme_type_variation = &"HudSubtle"
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var number: Label = Label.new()
	number.theme_type_variation = &"HudNumber" if count == 0 else &"EnemyLabel"
	number.add_to_group(&"key_number")
	if count == 0:
		number.self_modulate = Color(1, 1, 1, 0.6)  # "nothing seen" reads quieter
	number.text = str(count)
	top.add_child(number)
	var dots: HBoxContainer = HBoxContainer.new()
	dots.add_theme_constant_override(&"separation", 4)
	var dot_size: float = DOT_SIZE_COMPACT if compact else DOT_SIZE
	dots.custom_minimum_size = Vector2(0, dot_size)
	column.add_child(dots)
	for i: int in mini(count, 4):
		var dot: Panel = Panel.new()
		dot.theme_type_variation = &"RedDot"
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dots.add_child(dot)
	return cell
