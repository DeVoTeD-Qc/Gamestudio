# unit_slot.gd
# Purpose: One position in a lane's line (up to 4 per side). Shows a unit token,
#   the Operator, an incoming red-dot contact, or an empty spot. Display only: the Lane handles
#   taps / long-press for its slots (p09) and asks slot_uid / kind which unit was hit.
#   p09: a queued arrival (this Deploy) is tagged PLAN (SlotPending); set_target(true) frames
#   a unit that can be picked as a card's target (SlotTarget).
#   Layout: [class icon | POINT] / name (<= 2 lines) / class word / FP and AR.
#   f04: FP and Armor carry CardView's stat icons (not "FP" / "AR" words), and the unit's keyword
#   icons (amber, as on CardView, with Cover / Patch values) sit between FP and AR, or just above
#   the Armor number when that gap is too narrow. They float on KeywordLayer, so they never grow
#   the slot (the phone board has no spare height).
#   Compact (phone) profile hides the class word (the icon stays) and drops the
#   desktop minimum height so the board fits a 540 px tall canvas.
#   v01: a unit shows a faint class silhouette (card_art.gd token) behind its text, tinted with its
#   side colour; enemy figures face the other way.
# Dependencies: hud_theme.tres variations (SlotFriendly, SlotEnemy, UnitName...), icon_sheet.gd, card_art.gd.
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
## Rules uid of the unit shown (-1 when empty / incoming). Queued arrivals carry their card uid.
var slot_uid: int = -1
var pending: bool = false
var is_target: bool = false
## INCOMING slot: name of the revealed card behind the red dot ("" = not revealed, f03).
var revealed: String = ""
var _base_variation: StringName = &"SlotEmpty"

## Token silhouette tint (alpha keeps it behind the text).
const FIGURE_FRIEND: Color = Color(0.18, 0.77, 0.71, 0.26)
const FIGURE_ENEMY: Color = Color(0.9, 0.22, 0.23, 0.26)
const FIGURE_OPERATOR: Color = Color(0.79, 0.64, 0.15, 0.36)
const FIGURE_PENDING: Color = Color(1.0, 0.69, 0.13, 0.24)

var _figure_key: StringName = &""
var _figure_scale: float = 0.0

@onready var _figure: TextureRect = %Figure
@onready var _icon: TextureRect = %ClassIcon
@onready var _tag: Label = %TagLabel
@onready var _name: Label = %NameLabel
@onready var _class: Label = %ClassLabel
@onready var _dot: Panel = %RedDot
@onready var _fp_box: Control = %Fp
@onready var _ar_box: Control = %Ar
@onready var _fp: Label = %FpValue
@onready var _ar: Label = %ArValue
@onready var _fp_icon: TextureRect = %FpIcon
@onready var _ar_icon: TextureRect = %ArIcon
@onready var _keywords: HBoxContainer = %KeywordIcons

const MiniIcons: GDScript = preload("res://scripts/ui/mini_icons.gd")
const KEYWORD_PX: float = 18.0
const KEYWORD_PX_COMPACT: float = 16.0


func _ready() -> void:
	var tint: Color = get_theme_color(&"text", &"Hud")
	_fp_icon.texture = IconSheet.get_icon(&"stat_firepower")
	_ar_icon.texture = IconSheet.get_icon(&"stat_armor")
	_fp_icon.modulate = tint
	_ar_icon.modulate = tint
	_fp_icon.tooltip_text = "Firepower"
	_ar_icon.tooltip_text = "Armor"
	%Stats.resized.connect(_place_keywords)


## Phone layout: no class word, no tall minimum (see screen_profile.gd).
func set_compact(value: bool) -> void:
	compact = value
	custom_minimum_size = COMPACT_MIN if compact else DESKTOP_MIN
	_class.visible = not compact and kind == Kind.UNIT


## unit: {name, cls, fp, armor, armor_max, operator?: bool}. is_point: first in line.
func show_unit(unit: Dictionary, unit_side: StringName, is_point: bool) -> void:
	side = unit_side
	kind = Kind.UNIT
	revealed = ""
	var is_operator: bool = unit.get("operator", false)
	slot_uid = int(unit.get("uid", -1))
	pending = bool(unit.get("pending", false))
	if pending:
		_set_variation(&"SlotPending")
	elif is_operator:
		_set_variation(&"SlotOperator")
	else:
		_set_variation(&"SlotFriendly" if side == &"player" else &"SlotEnemy")
	_tag.text = "PLAN" if pending else ("POINT" if is_point else " ")
	# Title case keeps names on 1-2 lines in a narrow slot ("Marksman", "Kestrel AR-7").
	_name.text = String(unit.get("name", "?"))
	var cls: String = "OPERATOR" if is_operator else String(unit.get("cls", "")).to_upper()
	_class.text = cls
	_icon.texture = IconSheet.get_icon(CLASS_ICONS[cls]) if CLASS_ICONS.has(cls) else null
	_icon.tooltip_text = cls
	_show_figure(CardArt.TOKEN_FOR_CLASS.get(cls, &"shield"), is_operator)
	if String(unit.get("name", "")).to_lower().begins_with("sentry"):
		_show_figure(&"sentry", false)
	_fp.text = str(unit.get("fp", 0))
	var armor: int = unit.get("armor", 0)
	var armor_max: int = unit.get("armor_max", armor)
	_ar.text = str(armor) if armor == armor_max else "%d/%d" % [armor, armor_max]
	_set_parts(true, false)
	_set_keywords(unit.get("keywords", []))


## A committed but hidden enemy unit (red-dot intel, core-rules.md section 2.1). f03: with
## revealed_name (Recon Drone / Callout showed the card) the slot names it and tags it SPOTTED.
func show_incoming(revealed_name: String = "") -> void:
	side = &"enemy"
	kind = Kind.INCOMING
	slot_uid = -1
	pending = false
	_set_variation(&"SlotIncoming")
	revealed = revealed_name
	_tag.text = "SPOTTED" if revealed_name != "" else "INCOMING"
	_name.text = revealed_name
	_class.text = ""
	_icon.texture = null
	_hide_figure()
	_set_parts(false, true)
	_set_keywords([])


func show_empty(slot_side: StringName) -> void:
	side = slot_side
	kind = Kind.EMPTY
	revealed = ""
	slot_uid = -1
	pending = false
	_set_variation(&"SlotEmpty")
	_tag.text = " "
	_name.text = ""
	_class.text = ""
	_icon.texture = null
	_hide_figure()
	_set_parts(false, false)
	_set_keywords([])


func _show_figure(key: StringName, is_operator: bool) -> void:
	_figure_key = key
	_figure.flip_h = side == &"enemy"
	if pending:
		_figure.modulate = FIGURE_PENDING
	elif is_operator:
		_figure.modulate = FIGURE_OPERATOR
	else:
		_figure.modulate = FIGURE_FRIEND if side == &"player" else FIGURE_ENEMY
	_figure.visible = true
	_figure_scale = 0.0
	_update_figure_texture()


func _hide_figure() -> void:
	_figure_key = &""
	_figure.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_update_figure_texture.call_deferred()


## Rasterises the silhouette at the slot's on-screen scale (bucketed and cached in CardArt).
func _update_figure_texture() -> void:
	if _figure_key == &"" or _figure == null or not is_inside_tree():
		return
	var s: float = CardArt.bucket(CardArt.screen_scale(self) * maxf(size.y, 1.0) / 110.0)
	if is_equal_approx(s, _figure_scale):
		return
	_figure_scale = s
	_figure.texture = CardArt.token_texture(_figure_key, s)


## Frames the slot as a pickable target (Flank Route) while a card is selected.
func set_target(value: bool) -> void:
	is_target = value
	theme_type_variation = &"SlotTarget" if is_target else _base_variation
	queue_redraw()


func _set_variation(variation: StringName) -> void:
	_base_variation = variation
	theme_type_variation = &"SlotTarget" if is_target else variation
	queue_redraw()


## Empty slot: HUD corner brackets (theme colour Hud/slot_bracket) over a see-through fill.
func _draw() -> void:
	if kind != Kind.EMPTY or is_target:
		return
	var c: Color = get_theme_color(&"slot_bracket", &"Hud")
	var r: Rect2 = Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var l: float = minf(12.0, minf(r.size.x, r.size.y) * 0.25)
	var w: float = 2.0
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx: float = 1.0 if corner.x == r.position.x else -1.0
		var sy: float = 1.0 if corner.y == r.position.y else -1.0
		draw_polyline(PackedVector2Array([corner + Vector2(0, sy * l), corner, corner + Vector2(sx * l, 0)]), c, w)
	draw_circle(r.get_center(), 1.5, Color(c, 0.6))


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


## Keyword icons of the unit shown ([{id, value}] from match_snapshot.gd), empty to clear.
func _set_keywords(keywords: Array) -> void:
	for child: Node in _keywords.get_children():
		_keywords.remove_child(child)
		child.queue_free()
	var px: float = KEYWORD_PX_COMPACT if compact else KEYWORD_PX
	var row: HBoxContainer = MiniIcons.keyword_row(keywords, px, get_theme_color(&"accent", &"Hud"), false)
	for child: Node in row.get_children():
		row.remove_child(child)
		_keywords.add_child(child)
	row.free()
	_keywords.visible = _keywords.get_child_count() > 0
	_place_keywords.call_deferred()


## Between the FP and Armor numbers when the gap is wide enough, else just above the Armor number.
func _place_keywords() -> void:
	if _keywords == null or not _keywords.visible or not is_inside_tree():
		return
	var want: Vector2 = _keywords.get_combined_minimum_size()
	_keywords.size = want
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var layer_origin: Vector2 = to_local * _keywords.get_parent().get_global_rect().position
	var fp: Rect2 = Rect2(to_local * _fp_box.global_position, _fp_box.size)
	var ar: Rect2 = Rect2(to_local * _ar_box.global_position, _ar_box.size)
	# Keep 4 px clear on each side, so an icon never touches "3/4" (checked in f04 screenshots).
	var gap: float = ar.position.x - fp.end.x - 8.0
	var pos: Vector2
	if want.x <= gap:
		var value: Rect2 = Rect2(to_local * _ar.global_position, _ar.size)
		pos = Vector2(fp.end.x + 4.0 + (gap - want.x) * 0.5, value.position.y + (value.size.y - want.y) * 0.5)
	else:
		pos = Vector2(ar.end.x - want.x, ar.position.y - want.y)
	_keywords.position = (pos - layer_origin).round()
