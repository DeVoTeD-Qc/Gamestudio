# minimap.gd
# Purpose: Minimap intel strip (top-center). One cell per zone in map order showing
#   the enemy's committed deployments as red dots (count only, core-rules.md 2.1).
#   The count is also printed, so the dots never rely on color alone.
#   Recon "flip to silhouettes" and the sweep animation are p14.
# Dependencies: hud_placeholder_style.gd variation names (MinimapCell, RedDot).
# Author: UI/UX Agent
extends PanelContainer

const CELL_WIDTH: float = 92.0
const DOT_SIZE: float = 20.0

@onready var _cells: HBoxContainer = %Cells


## lanes: lane Dictionaries in map order; reads label and incoming.
func set_intel(lanes: Array) -> void:
	for child: Node in _cells.get_children():
		_cells.remove_child(child)
		child.queue_free()
	for lane: Dictionary in lanes:
		_cells.add_child(_make_cell(String(lane.get("label", "?")), int(lane.get("incoming", 0))))


func _make_cell(label_text: String, count: int) -> Control:
	var cell: PanelContainer = PanelContainer.new()
	cell.theme_type_variation = &"MinimapCell"
	cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
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
	number.theme_type_variation = &"HudSubtle" if count == 0 else &"EnemyLabel"
	number.add_theme_font_size_override(&"font_size", 16)
	number.text = str(count)
	top.add_child(number)
	var dots: HBoxContainer = HBoxContainer.new()
	dots.add_theme_constant_override(&"separation", 4)
	dots.custom_minimum_size = Vector2(0, DOT_SIZE)
	column.add_child(dots)
	for i: int in mini(count, 4):
		var dot: Panel = Panel.new()
		dot.theme_type_variation = &"RedDot"
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dots.add_child(dot)
	return cell
