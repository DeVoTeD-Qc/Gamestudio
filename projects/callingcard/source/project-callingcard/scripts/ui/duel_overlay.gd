# duel_overlay.gd
# Purpose: Modal panel for the duel flow (cc08): duel setup (rival + Signature), coin flip and the
#   end screen. Title, body text, a content box the caller fills, and a row of big buttons.
#   open(title, body, buttons) where buttons = [{id, text, primary}] -> button_pressed(id).
#   Sits under the card inspector, so cards shown here can still be held to inspect them.
# Dependencies: none (theme variations InspectorPanel, InspectorName, InspectorBody, ActionButton,
#   PrimaryButton from duel_theme.gd).
# Author: UI/UX Agent (cc08)
extends Control

signal button_pressed(id: StringName)

@onready var _margin: MarginContainer = %OverlayMargin
@onready var _title: Label = %OverlayTitle
@onready var _body: Label = %OverlayBody
@onready var _content: VBoxContainer = %OverlayContent
@onready var _buttons: HBoxContainer = %OverlayButtons

var _open_id: StringName = &""


func _ready() -> void:
	hide()


## buttons: [{id: StringName, text: String, primary: bool}]. kind names the overlay (tests).
func open(kind: StringName, title: String, body: String, buttons: Array) -> void:
	_open_id = kind
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	for c: Node in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	for b: Node in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	for spec: Dictionary in buttons:
		var b: Button = Button.new()
		b.name = "Button_%s" % spec["id"]
		b.text = spec["text"]
		b.custom_minimum_size = Vector2(200, 64)
		b.theme_type_variation = &"PrimaryButton" if spec.get("primary", false) else &"ActionButton"
		var id: StringName = spec["id"]
		b.pressed.connect(func() -> void: button_pressed.emit(id))
		_buttons.add_child(b)
	show()
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(_buttons.get_child_count() - 1) as Button).grab_focus.call_deferred()


func close() -> void:
	_open_id = &""
	hide()


func kind() -> StringName:
	return _open_id if visible else &""


func get_content() -> VBoxContainer:
	return _content


func get_button(id: StringName) -> Button:
	return _buttons.get_node_or_null("Button_%s" % id)


func get_panel() -> Control:
	return %OverlayPanel


func get_important_labels() -> Array[Label]:
	return [_title, _body]


func set_safe_margins(lt: Vector2, rb: Vector2) -> void:
	_margin.add_theme_constant_override(&"margin_left", int(lt.x))
	_margin.add_theme_constant_override(&"margin_top", int(lt.y))
	_margin.add_theme_constant_override(&"margin_right", int(rb.x))
	_margin.add_theme_constant_override(&"margin_bottom", int(rb.y))
