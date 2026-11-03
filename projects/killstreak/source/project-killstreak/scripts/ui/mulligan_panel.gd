# mulligan_panel.gd
# Purpose: Round 1 mulligan step (f02, core-rules Ruling 3). A modal panel over the board:
#   one toggle per card in the opening hand (tap = put it back), KEEP HAND, and REDRAW n.
#   It only collects the choice and emits `confirmed(put_back_uids)`; MatchController calls
#   MatchState.mulligan(). Phone sizes: every text >= 16 px and every tap target >= 64 px tall
#   (11.6 pt / 46 pt at the iPhone's 0.722 pt per px, README "Phone readability").
# Scene: res://scenes/match/MulliganPanel.tscn (full-rect, hidden until open()).
# Dependencies: hud_theme.tres variations (Scrim, HudPanelDark, HudHeader, HudSubtle, HudButton,
#   KillstreakButton).
# Author: Mechanics Developer Agent (f02)
extends Control

## The player decided: card uids to put back (empty = keep the hand).
signal confirmed(put_back: Array[int])

const CARD_SIZE: Vector2 = Vector2(150, 88)
const CARD_SIZE_COMPACT: Vector2 = Vector2(150, 72)

var compact: bool = false
var _picked: Array[int] = []

@onready var _cards: GridContainer = %Cards
@onready var _keep: Button = %KeepButton
@onready var _confirm: Button = %ConfirmButton
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_keep.pressed.connect(func() -> void:
		var none: Array[int] = []
		_finish(none))
	_confirm.pressed.connect(func() -> void: _finish(_picked.duplicate()))


## Shows the hand: entries {uid, name, cost, type} (type: "UNIT", "TACTIC", "EQUIP").
func open(hand: Array) -> void:
	_picked.clear()
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_cards.columns = clampi(hand.size(), 1, 4 if compact else 7)
	for entry: Dictionary in hand:
		var b: Button = Button.new()
		var uid: int = int(entry.get("uid", -1))
		b.toggle_mode = true
		b.theme_type_variation = &"HudButton"
		b.custom_minimum_size = CARD_SIZE_COMPACT if compact else CARD_SIZE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.set_meta(&"uid", uid)
		b.set_meta(&"label", "%s\n%d SUP · %s" % [entry.get("name", "?"), int(entry.get("cost", 0)), entry.get("type", "")])
		b.set_meta(&"back_label", "%s\nPUT BACK" % entry.get("name", "?"))
		b.text = b.get_meta(&"label")
		b.add_to_group(&"tap_target")
		b.toggled.connect(func(on: bool) -> void: _toggle(b, uid, on))
		_cards.add_child(b)
	_update_confirm()
	show()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func set_compact(value: bool) -> void:
	compact = value
	_keep.custom_minimum_size = Vector2(200, 64)
	_confirm.custom_minimum_size = Vector2(200, 64)


func get_card_buttons() -> Array[Node]:
	return _cards.get_children()


func get_keep_button() -> Button:
	return _keep


func get_confirm_button() -> Button:
	return _confirm


## Uids currently marked to put back.
func get_picked() -> Array[int]:
	return _picked.duplicate()


## Labels whose whole text must stay visible (tests / QA).
func get_important_labels() -> Array[Label]:
	return [%TitleLabel, _hint]


func _toggle(b: Button, uid: int, on: bool) -> void:
	if on and uid not in _picked:
		_picked.append(uid)
	elif not on:
		_picked.erase(uid)
	# Marked cards switch to the cyan KillstreakButton look and say BACK on their second line.
	b.theme_type_variation = &"KillstreakButton" if on else &"HudButton"
	b.text = String(b.get_meta(&"back_label") if on else b.get_meta(&"label"))
	_update_confirm()


func _update_confirm() -> void:
	_confirm.disabled = _picked.is_empty()
	_confirm.text = "REDRAW %d" % _picked.size()


func _finish(put_back: Array[int]) -> void:
	hide()
	confirmed.emit(put_back)
