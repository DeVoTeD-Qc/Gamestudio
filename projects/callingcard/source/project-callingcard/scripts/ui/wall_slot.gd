# wall_slot.gd
# Purpose: One brick of the wall. Empty: cc14's WallSlot outline with the slot id; occupied: a
#   BannerCard (cc14 art kit; owner ring + solid/notched tab, Signature ribbon, Ambush back).
#   This Button is the tap target and owns input (the card ignores the mouse), so taps, focus and
#   keys work the same on empty and occupied slots:
#   tap -> `tapped` (cc08: place the picked card here; occupied: inspect);
#   hold 400 ms / right-click / "inspect" key -> `inspect_requested`.
#   target_state: &"none" or &"valid" (amber glow on legal drop slots, cc08 sets it).
# Dependencies: tap_hold_button.gd, scenes/card/BannerCard.tscn.
# Author: UI/UX Agent (cc07)
extends "res://scripts/ui/tap_hold_button.gd"

@export var slot_id: StringName = &"a1"

var target_state: StringName = &"none":
	set(v):
		target_state = v
		_refresh_style()
## {card: Dictionary, owner, face_down, signature, pending, preview, preview_dir, target, boost} or {}.
var content: Dictionary = {}

@onready var _id_label: Label = %SlotIdLabel
@onready var _card: BannerCard = %Card


func _ready() -> void:
	super._ready()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_id_label.text = String(slot_id).to_upper()
	_refresh()


func is_empty() -> bool:
	return content.is_empty()


## entry: {} to empty the slot, or {card: Dictionary, owner, face_down, signature, pending}.
func set_content(entry: Dictionary) -> void:
	content = entry
	if is_node_ready():
		_refresh()


func get_card() -> BannerCard:
	return _card


func _refresh() -> void:
	_id_label.visible = content.is_empty()
	_card.visible = not content.is_empty()
	if not content.is_empty():
		_card.configure(content.get("card", {}))
		_card.side = content.get("owner", &"")
		_card.signature = content.get("signature", false)
		_card.face_down = content.get("face_down", false)
		_card.highlighted = content.get("pending", false) or content.get("target", false)
		_card.preview_flip = content.get("preview", false)
		_card.preview_dir = content.get("preview_dir", Vector2.RIGHT)
		_card.boost = content.get("boost", Vector3i.ZERO)
	_refresh_style()


func _refresh_style() -> void:
	theme_type_variation = &"SlotButtonValid" if target_state == &"valid" else &"SlotButton"
