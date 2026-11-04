# match_card_button.gd
# Purpose: One card on the match screen (hand, line, loadout strip). A TapHoldButton that hosts
#   the card face (placeholder card_face.gd until cz16's card scene) and the state marks the
#   art direction asks for: HOLD tag + outline on held cards, NEXT outline on the next hand
#   (armour), the selected outline, and an attachment tag. Tap = select (cz11 turns it into
#   play / hold); long-press, right-click or the "inspect" key = inspector.
# Swap the face: set FACE_SCRIPT to cz16's script (see card_face.gd for the 3 members it needs).
# Dependencies: tap_hold_button.gd, card_face.gd, match_theme.gd.
# Author: UI/UX Agent (cz10)
extends "res://scripts/ui/tap_hold_button.gd"

const FACE_SCRIPT: GDScript = preload("res://scripts/ui/card_face.gd")
const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")

## Where the card sits: &"hand", &"line", &"next" (loadout strip).
var zone: StringName = &"hand"
var index: int = 0
var card_id: StringName = &""
var card: Dictionary = {}
var held: bool = false
var armour: bool = false
var selected: bool = false: set = set_selected

var _face: Control
var _outline: Panel
var _tag: Label


func _init() -> void:
	super._init()
	theme_type_variation = &"CardButton"
	clip_contents = false
	add_to_group(&"tap_target")
	_face = FACE_SCRIPT.new()
	_face.name = "Card"
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_face)
	_outline = Panel.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_outline)
	_tag = Label.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	add_child(_tag)


## c: a card Dictionary (mock_match_data.card() or CardDB later). size_class: &"hand" | &"mini".
func setup(c: Dictionary, where: StringName, i: int, size_class: StringName, is_held: bool = false, is_armour: bool = false) -> void:
	card = c
	card_id = c.get("id", &"")
	zone = where
	index = i
	held = is_held
	armour = is_armour
	_face.configure(c, size_class)
	_tag.visible = false
	if held:
		_show_tag("HOLD", &"TagHold")
	elif c.get("type", &"") == &"hit" and where == &"next":
		_show_tag("DOWN +1", &"TagDown")
	_refresh_outline()


func set_selected(v: bool) -> void:
	selected = v
	if is_inside_tree() or _outline != null:
		_refresh_outline()


func get_face() -> Control:
	return _face


func get_tag() -> Label:
	return _tag


func _show_tag(text: String, variation: StringName) -> void:
	_tag.text = text
	_tag.theme_type_variation = variation
	_tag.visible = true
	# Sits above the bottom row (Brace / stat), centred.
	_tag.offset_bottom = -35.0
	_tag.offset_top = -35.0 - 24.0
	_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _refresh_outline() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(6)
	if selected:
		box.border_color = MatchTheme.PAPER
		box.set_border_width_all(4)
		box.expand_margin_left = 3
		box.expand_margin_right = 3
		box.expand_margin_top = 3
		box.expand_margin_bottom = 3
	elif held or armour:
		box.border_color = MatchTheme.ZONE_EDGE
		box.set_border_width_all(3)
		box.expand_margin_left = 2
		box.expand_margin_right = 2
		box.expand_margin_top = 2
		box.expand_margin_bottom = 2
	else:
		box.set_border_width_all(0)
	_outline.add_theme_stylebox_override(&"panel", box)
