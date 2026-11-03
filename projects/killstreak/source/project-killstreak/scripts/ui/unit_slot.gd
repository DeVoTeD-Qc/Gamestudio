# unit_slot.gd
# Purpose: One position in a lane's line (up to 4 per side). Shows a unit token,
#   the Operator, an incoming red-dot contact, or an empty spot. Display only:
#   tapping/inspecting arrives with p09 (the slot already stops mouse/touch input).
# Dependencies: hud_placeholder_style.gd variation names (SlotFriendly, SlotEnemy...).
# Author: UI/UX Agent
extends PanelContainer

enum Kind { EMPTY, UNIT, INCOMING }

## &"player" or &"enemy" (EventBus convention).
var side: StringName = &"player"
var kind: Kind = Kind.EMPTY

@onready var _tag: Label = %TagLabel
@onready var _name: Label = %NameLabel
@onready var _class: Label = %ClassLabel
@onready var _dot: Panel = %RedDot
@onready var _fp_box: Control = %Fp
@onready var _ar_box: Control = %Ar
@onready var _fp: Label = %FpValue
@onready var _ar: Label = %ArValue


## unit: {name, cls, fp, armor, armor_max, operator?}. is_point: first in line.
func show_unit(unit: Dictionary, unit_side: StringName, is_point: bool) -> void:
	side = unit_side
	kind = Kind.UNIT
	var is_operator: bool = unit.get("operator", false)
	if is_operator:
		theme_type_variation = &"SlotOperator"
	else:
		theme_type_variation = &"SlotFriendly" if side == &"player" else &"SlotEnemy"
	_tag.text = "POINT" if is_point else " "
	# Title case keeps names on 1-2 lines in a ~90 px slot ("Marksman", "Kestrel AR-7").
	_name.text = String(unit.get("name", "?"))
	_class.text = "OPERATOR" if is_operator else String(unit.get("cls", ""))
	_fp.text = str(unit.get("fp", 0))
	var armor: int = unit.get("armor", 0)
	var armor_max: int = unit.get("armor_max", armor)
	_ar.text = str(armor) if armor == armor_max else "%d/%d" % [armor, armor_max]
	_set_parts(true, false)


## A committed but hidden enemy unit (red-dot intel, core-rules.md section 2.1).
func show_incoming() -> void:
	side = &"enemy"
	kind = Kind.INCOMING
	theme_type_variation = &"SlotIncoming"
	_tag.text = "INCOMING"
	_name.text = ""
	_class.text = ""
	_set_parts(false, true)


func show_empty(slot_side: StringName) -> void:
	side = slot_side
	kind = Kind.EMPTY
	theme_type_variation = &"SlotEmpty"
	_tag.text = " "
	_name.text = ""
	_class.text = ""
	_set_parts(false, false)


func _set_parts(stats_visible: bool, dot_visible: bool) -> void:
	# Stats keep their space when hidden so every slot in a row has the same height.
	_fp_box.modulate.a = 1.0 if stats_visible else 0.0
	_ar_box.modulate.a = 1.0 if stats_visible else 0.0
	_dot.visible = dot_visible
