# lineup_row.gd
# Purpose: One of the five lineup slots in the lineup builder (cc10): the card (a TapHoldButton
#   holding a cc14 BannerCard, or an "EMPTY SLOT" button) and its SIGNATURE toggle.
#   - tap the card            -> card_tapped (the builder takes the card out: one tap)
#   - hold / right-click card -> inspect_requested (the release does not take it out)
#   - tap SIGNATURE           -> signature_tapped (mark / unmark: one tap)
#   The toggle shows its state three ways, never by colour alone: pressed (filled) style, the
#   Signature ribbon on the card, and the builder's status line naming the Signature.
# Dependencies: tap_hold_button.gd, scenes/card/BannerCard.tscn (cc14).
# Author: UI/UX Agent (cc10)
extends HBoxContainer

signal card_tapped(index: int)
signal inspect_requested(index: int)
signal signature_tapped(index: int)

var index: int = 0
var card: CardData = null
var is_signature: bool = false

@onready var _button: Button = %CardButton
@onready var _card: BannerCard = %Card
@onready var _empty: Label = %EmptyLabel
@onready var _sig: Button = %SigToggle


func _ready() -> void:
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.tapped.connect(func() -> void: card_tapped.emit(index))
	_button.inspect_requested.connect(func() -> void:
		if card != null:
			inspect_requested.emit(index))
	_sig.pressed.connect(func() -> void:
		_sig.set_pressed_no_signal(is_signature)  # the builder decides; show() re-syncs
		signature_tapped.emit(index))
	_render()


## c: the card in this slot (null = empty). sig: it is the Signature.
func show_card(c: CardData, sig: bool) -> void:
	card = c
	is_signature = sig and c != null
	_render()


func set_sizes(card_size: Vector2, toggle_w: float, font_px: int) -> void:
	_button.custom_minimum_size = card_size
	_sig.custom_minimum_size = Vector2(toggle_w, card_size.y)
	_sig.add_theme_font_size_override(&"font_size", font_px)


func get_card_button() -> Button:
	return _button


func get_signature_toggle() -> Button:
	return _sig


func get_card_view() -> BannerCard:
	return _card


func _render() -> void:
	if not is_node_ready():
		return
	var filled: bool = card != null
	_card.visible = filled
	_empty.visible = not filled
	_button.theme_type_variation = &"HandCard" if filled else &"SlotButton"
	if filled:
		_card.configure(card)
		_card.side = &"player"
		_card.signature = is_signature
	_sig.disabled = not filled
	_sig.set_pressed_no_signal(is_signature)
	_sig.text = "SIGNATURE"
