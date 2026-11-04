# card_inspector.gd
# Purpose: Card inspector (plan §7: no hover-only information). Opens from a tap on a wall card,
#   a long-press / right-click / "inspect" key on any card, or the INFO button. Shows the card
#   big, its name, set and origin, Clearance, the three values with what they face, the trait
#   and its rule text, "how it's earned", and whose card it is (with the Signature rule).
#   A rival's face-down Ambush card shows only what the rules reveal.
#   Closes with CLOSE, a tap on the dimmed backdrop, Esc / right-click ("cancel").
# Dependencies: card_text.gd, scenes/card/BannerCard.tscn (cc14; full detail at >= 112 px tall).
# Author: UI/UX Agent (cc07)
extends Control

signal closed

const CardText: GDScript = preload("res://scripts/ui/card_text.gd")
const CARD_WIDE: Vector2 = Vector2(720, 180)
const CARD_COMPACT: Vector2 = Vector2(520, 130)

var compact: bool = false
var card: Dictionary = {}

@onready var _scrim: ColorRect = %Scrim
@onready var _margin: MarginContainer = %SafeMargin
@onready var _card_view: BannerCard = %InspectorCard
@onready var _name: Label = %InspectorNameLabel
@onready var _set_origin: Label = %SetOriginLabel
@onready var _clearance: Label = %ClearanceLabel
@onready var _owner: Label = %OwnerLabel
@onready var _top: Label = %TopValue
@onready var _side: Label = %SideValue
@onready var _bottom: Label = %BottomValue
@onready var _trait_heading: Label = %TraitHeading
@onready var _trait_rule: Label = %TraitRule
@onready var _earned: Label = %EarnedLabel
@onready var _close: Button = %CloseButton
@onready var _right: VBoxContainer = %RightColumn


func _ready() -> void:
	hide()
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close.pressed.connect(close)
	_scrim.gui_input.connect(_on_scrim_input)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		close()
		get_viewport().set_input_as_handled()


## context: {owner: &"player"|&"rival"|&"", signature: bool, face_down: bool, where: "hand"|"wall"}
func open_card(c: Dictionary, context: Dictionary = {}) -> void:
	card = c
	var owner: StringName = context.get("owner", &"")
	var hidden: bool = context.get("face_down", false) and owner == &"rival"
	var size_px: Vector2 = CARD_COMPACT if compact else CARD_WIDE
	_card_view.custom_minimum_size = size_px
	_card_view.configure(c)
	_card_view.side = owner
	_card_view.signature = context.get("signature", false)
	_card_view.face_down = hidden
	_right.custom_minimum_size.x = 380 if compact else 360
	%Column.add_theme_constant_override(&"separation", 8 if compact else 12)
	if hidden:
		_name.text = "Face-down card"
		_set_origin.text = "Event card (Ambush), placed face-down"
		_clearance.text = "Clearance hidden"
		_top.text = "?"
		_side.text = "?"
		_bottom.text = "?"
		_trait_heading.text = "TRAIT · AMBUSH"
		_trait_rule.text = CardText.TRAIT_RULES[&"ambush"]
		_earned.text = "Revealed when it flips."
	else:
		_name.text = String(c.get("name", ""))
		_set_origin.text = CardText.set_origin_line(c)
		_clearance.text = CardText.clearance_line(c)
		_top.text = str(c.get("top", ""))
		_side.text = str(c.get("side", ""))
		_bottom.text = str(c.get("bottom", ""))
		_trait_heading.text = "TRAIT · %s" % CardText.trait_name(c).to_upper()
		_trait_rule.text = CardText.trait_rule(c)
		_earned.text = CardText.earned_line(c)
	_owner.text = _owner_line(owner, context)
	show()
	_close.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


## Keeps the panel clear of notches (DuelScreen passes its safe margins, logical px).
func set_safe_margins(lt: Vector2, rb: Vector2) -> void:
	_margin.add_theme_constant_override(&"margin_left", int(lt.x))
	_margin.add_theme_constant_override(&"margin_top", int(lt.y))
	_margin.add_theme_constant_override(&"margin_right", int(rb.x))
	_margin.add_theme_constant_override(&"margin_bottom", int(rb.y))


func get_card_view() -> BannerCard:
	return _card_view


func get_panel() -> Control:
	return %InspectorPanel


func get_important_labels() -> Array[Label]:
	return [_name, _set_origin, _clearance, _owner, _top, _side, _bottom, _trait_heading, _trait_rule, _earned]


func _owner_line(owner: StringName, context: Dictionary) -> String:
	var where: String = context.get("where", "")
	var line: String = ""
	match owner:
		&"player":
			line = "In your hand" if where == "hand" else "Yours (solid tab)"
		&"rival":
			line = "Rival's (notched tab)"
	if context.get("signature", false):
		line += (" · " if line != "" else "") + "Signature: counts double"
	return line


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
