# wall_slot.gd
# Purpose: One brick of the wall. Empty: a faint chalk outline with its slot id; occupied: the
#   card (CardView) with its owner tab. Tap -> `tapped` (cc08: place the picked card here, or
#   inspect an occupied slot); hold 400 ms / right-click / "inspect" key -> `inspect_requested`.
#   target_state: &"none" or &"valid" (amber glow on legal drop slots, cc08 sets it).
# Dependencies: tap_hold_button.gd, scenes/duel/CardView.tscn.
# Author: UI/UX Agent (cc07)
extends "res://scripts/ui/tap_hold_button.gd"

@export var slot_id: StringName = &"a1"

var target_state: StringName = &"none":
	set(v):
		target_state = v
		_refresh_style()
## {card_id, owner, face_down, card (Dictionary), signature} or {} when empty.
var content: Dictionary = {}

@onready var _id_label: Label = %SlotIdLabel
@onready var _card_view: Control = %CardView


func _ready() -> void:
	super._ready()
	_id_label.text = String(slot_id).to_upper()
	_refresh()


func is_empty() -> bool:
	return content.is_empty()


## entry: {} to empty the slot, or {card: Dictionary, owner, face_down, signature}.
func set_content(entry: Dictionary) -> void:
	content = entry
	if is_node_ready():
		_refresh()


func get_card_view() -> Control:
	return _card_view


func set_compact(v: bool) -> void:
	_card_view.compact = v


func _refresh() -> void:
	_id_label.visible = content.is_empty()
	_card_view.visible = not content.is_empty()
	if not content.is_empty():
		_card_view.show_card(content.get("card", {}), content.get("owner", &""),
				content.get("signature", false), content.get("face_down", false))
	_refresh_style()


func _refresh_style() -> void:
	theme_type_variation = &"WallSlotValid" if target_state == &"valid" else &"WallSlot"
