# wall_view.gd
# Purpose: The duel board: a dark brick-wall panel holding the 10 WallSlots (wall_layout.gd).
#   Re-emits slot taps / inspect requests with the slot id; shows a wall Dictionary
#   {slot_id: {card, owner, face_down, signature}}.
# Dependencies: wall_layout.gd, wall_slot.gd (scenes/duel/Slot.tscn).
# Author: UI/UX Agent (cc07)
extends PanelContainer

signal slot_tapped(slot_id: StringName)
signal slot_inspect_requested(slot_id: StringName)

@onready var _layout: Container = %WallLayout


func _ready() -> void:
	for s: Node in get_slots():
		s.tapped.connect(func() -> void: slot_tapped.emit(s.slot_id))
		s.inspect_requested.connect(func() -> void: slot_inspect_requested.emit(s.slot_id))


func get_slots() -> Array[Node]:
	return _layout.get_children()


func get_slot(slot_id: StringName) -> Node:
	return _layout.get_node_or_null(NodePath(String(slot_id)))


func set_brick_size(brick: Vector2, gap: Vector2) -> void:
	_layout.brick_size = brick
	_layout.gap = gap


func get_brick_size() -> Vector2:
	return _layout.brick_size


func set_compact(v: bool) -> void:
	for s: Node in get_slots():
		s.set_compact(v)


## entries: {slot_id: {card: Dictionary, owner, face_down, signature}}; missing slots are emptied.
func show_wall(entries: Dictionary) -> void:
	for s: Node in get_slots():
		s.set_content(entries.get(s.slot_id, {}))
