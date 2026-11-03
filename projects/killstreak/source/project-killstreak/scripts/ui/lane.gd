# lane.gd
# Purpose: One board zone (lane): header with zone name, range badge and control
#   state, the enemy line on top and the player's line below (4 slots each,
#   core-rules.md section 1 zone capacity). Line order runs left to right; the
#   first unit is the point man. Display only; deploying into it arrives with p09
#   (FriendlyRow is the tap/drop target and is already >= 64 px).
# Dependencies: unit_slot.gd.
# Author: UI/UX Agent
extends PanelContainer

const CONTROL_TEXT: Dictionary = {
	&"player": "YOURS",
	&"enemy": "ENEMY",
	&"contested": "CONTESTED",
	&"empty": "OPEN",
}
const HEADER_VARIATION: Dictionary = {
	&"player": &"ZoneFriend",
	&"enemy": &"ZoneEnemy",
	&"contested": &"ZoneContested",
	&"empty": &"ZoneNeutral",
}

## &"left", &"mid" or &"right" (EventBus convention).
var zone_id: StringName = &""

@onready var _column: VBoxContainer = %Column
@onready var _header: PanelContainer = %Header
@onready var _name: Label = %NameLabel
@onready var _range: Label = %RangeLabel
@onready var _control: Label = %ControlLabel
@onready var _enemy_slots: HBoxContainer = %EnemyRow.get_node("Slots")
@onready var _friendly_slots: HBoxContainer = %FriendlyRow.get_node("Slots")


## lane: see mock_match_data.gd for the shape.
func set_lane(lane: Dictionary) -> void:
	zone_id = lane.get("id", &"")
	_name.text = String(lane.get("name", "")).to_upper()
	_range.text = String(lane.get("range", "")).to_upper()
	var control: StringName = lane.get("control", &"empty")
	_control.text = CONTROL_TEXT.get(control, "OPEN")
	_header.theme_type_variation = HEADER_VARIATION.get(control, &"ZoneNeutral")
	_fill_line(_enemy_slots, lane.get("enemy", []), &"enemy", int(lane.get("incoming", 0)))
	_fill_line(_friendly_slots, lane.get("friendly", []), &"player", 0)


## Phone layout: tighter spacing, compact slots (see screen_profile.gd).
func set_compact(compact: bool) -> void:
	_column.add_theme_constant_override(&"separation", 2 if compact else 4)
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		slot.set_compact(compact)


## Labels whose whole text must stay visible (zone name, range, control, unit names and stats).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_name, _range, _control]
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		out.append_array(slot.get_important_labels())
	return out


func get_enemy_slots() -> Array[Node]:
	return _enemy_slots.get_children()


func get_friendly_slots() -> Array[Node]:
	return _friendly_slots.get_children()


func _fill_line(row: HBoxContainer, units: Array, side: StringName, incoming: int) -> void:
	var slots: Array[Node] = row.get_children()
	for i: int in slots.size():
		var slot: Node = slots[i]
		if i < units.size():
			slot.show_unit(units[i], side, i == 0)
		elif i < units.size() + incoming:
			slot.show_incoming()
		else:
			slot.show_empty(side)
