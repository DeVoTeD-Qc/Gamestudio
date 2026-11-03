# unit_slot.gd
# Purpose: One position in a lane's line (up to 4 per side). Shows a unit token,
#   the Operator, an incoming red-dot contact, or an empty spot. Display only:
#   tapping/inspecting arrives with p09 (the slot already stops mouse/touch input).
#   Layout: [class icon | POINT] / name (<= 2 lines) / class word / FP and AR.
#   Compact (phone) profile hides the class word (the icon stays) and drops the
#   desktop minimum height so the board fits a 540 px tall canvas.
# Dependencies: hud_theme.tres variations (SlotFriendly, SlotEnemy, UnitName...), icon_sheet.gd.
# Author: UI/UX Agent
extends PanelContainer

enum Kind { EMPTY, UNIT, INCOMING }

const DESKTOP_MIN: Vector2 = Vector2(80, 128)
const COMPACT_MIN: Vector2 = Vector2(64, 64)
## Class text (as in the snapshot) -> icon sheet name.
const CLASS_ICONS: Dictionary = {
	"SMG": &"class_smg", "SHOTGUN": &"class_shotgun", "AR": &"class_ar", "SNIPER": &"class_sniper",
	"LMG": &"class_lmg", "OPERATOR": &"type_operator",
}

## &"player" or &"enemy" (EventBus convention).
var side: StringName = &"player"
var kind: Kind = Kind.EMPTY
var compact: bool = false

@onready var _icon: TextureRect = %ClassIcon
@onready var _tag: Label = %TagLabel
@onready var _name: Label = %NameLabel
@onready var _class: Label = %ClassLabel
@onready var _dot: Panel = %RedDot
@onready var _fp_box: Control = %Fp
@onready var _ar_box: Control = %Ar
@onready var _fp: Label = %FpValue
@onready var _ar: Label = %ArValue


## Phone layout: no class word, no tall minimum (see screen_profile.gd).
func set_compact(value: bool) -> void:
	compact = value
	custom_minimum_size = COMPACT_MIN if compact else DESKTOP_MIN
	_class.visible = not compact and kind == Kind.UNIT


## unit: {name, cls, fp, armor, armor_max, operator?: bool}. is_point: first in line.
func show_unit(unit: Dictionary, unit_side: StringName, is_point: bool) -> void:
	side = unit_side
	kind = Kind.UNIT
	var is_operator: bool = unit.get("operator", false)
	if is_operator:
		theme_type_variation = &"SlotOperator"
	else:
		theme_type_variation = &"SlotFriendly" if side == &"player" else &"SlotEnemy"
	_tag.text = "POINT" if is_point else " "
	# Title case keeps names on 1-2 lines in a narrow slot ("Marksman", "Kestrel AR-7").
	_name.text = String(unit.get("name", "?"))
	var cls: String = "OPERATOR" if is_operator else String(unit.get("cls", "")).to_upper()
	_class.text = cls
	_icon.texture = IconSheet.get_icon(CLASS_ICONS[cls]) if CLASS_ICONS.has(cls) else null
	_icon.tooltip_text = cls
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
	_icon.texture = null
	_set_parts(false, true)


func show_empty(slot_side: StringName) -> void:
	side = slot_side
	kind = Kind.EMPTY
	theme_type_variation = &"SlotEmpty"
	_tag.text = " "
	_name.text = ""
	_class.text = ""
	_icon.texture = null
	_set_parts(false, false)


## Labels whose whole text must stay visible (checked by tests/test_board_layout.gd).
func get_important_labels() -> Array[Label]:
	return [_tag, _name, _fp, _ar]


func _set_parts(stats_visible: bool, dot_visible: bool) -> void:
	# Stats keep their space when hidden so every slot in a row has the same height.
	_fp_box.modulate.a = 1.0 if stats_visible else 0.0
	_ar_box.modulate.a = 1.0 if stats_visible else 0.0
	_dot.visible = dot_visible
	_icon.visible = _icon.texture != null
	_class.visible = not compact and kind == Kind.UNIT
