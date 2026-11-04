# hand_view.gd
# Purpose: The player's hand (up to 5 cards). Cards are the same size as a brick, centered in
#   rows (5 in one row when they fit, else 3 + 2), so every card stays visible and tappable.
#   Strip mode (strip = true): one row in a horizontal ScrollContainer, for screens too short
#   for two rows (DuelScreen decides; at 1280x720 and 844x390 two rows fit, see the cc07 notes).
#   Each card is a TapHoldButton (tap target, focus, input) holding a cc14 BannerCard that ignores
#   the mouse. Tap a card -> pick it (BannerCard amber highlight, `card_picked`); tap again -> unpick.
#   Hold 400 ms / right-click / "inspect" key -> `card_inspect_requested`.
# Dependencies: tap_hold_button.gd, scenes/card/BannerCard.tscn and ArtKit (cc14).
# Author: UI/UX Agent (cc07)
extends VBoxContainer

signal card_picked(card_id: StringName)
signal card_unpicked
signal card_inspect_requested(card_id: StringName)

const TapHoldButton: GDScript = preload("res://scripts/ui/tap_hold_button.gd")
const BannerCardScene: PackedScene = preload("res://scenes/card/BannerCard.tscn")
const CARD_GAP: int = 10

var card_size: Vector2 = Vector2(256, 64)
var strip: bool = false
var compact: bool = false
var picked_id: StringName = &""

var _cards: Array[Dictionary] = []
var _signature_id: StringName = &""
var _status: String = ""

@onready var _title: Label = %HandTitle
@onready var _hint: Label = %HandHint
@onready var _scroll: ScrollContainer = %HandScroll
@onready var _flow: HFlowContainer = %HandCards


func _ready() -> void:
	_flow.add_theme_constant_override(&"h_separation", CARD_GAP)
	_flow.add_theme_constant_override(&"v_separation", CARD_GAP)


## cards: UI card Dictionaries in hand order. signature_id draws the ribbon on that card.
func show_hand(cards: Array, signature_id: StringName = &"") -> void:
	# Same cards as shown: keep the buttons (focus and an in-flight press survive a re-render).
	var same: bool = cards.size() == _cards.size() and signature_id == _signature_id \
			and _flow != null and _flow.get_child_count() == cards.size()
	for i: int in mini(cards.size(), _cards.size()):
		same = same and (cards[i] as Dictionary).get("id") == _cards[i].get("id")
	if same:
		_refresh_picked()
		return
	_cards.clear()
	for c: Dictionary in cards:
		_cards.append(c)
	_signature_id = signature_id
	if picked_id != &"" and not _cards.any(func(c: Dictionary) -> bool: return c.get("id") == picked_id):
		picked_id = &""
	_rebuild()


func set_layout(size_px: Vector2, is_strip: bool, is_compact: bool) -> void:
	card_size = size_px
	strip = is_strip
	compact = is_compact
	_rebuild()


## A short status in the hand header instead of the tap hint (prompts, preview summary,
## refusals). It sits in the player's eye line and never covers the wall.
func show_status(text: String) -> void:
	_status = text
	_hint.text = text
	_hint.add_theme_color_override(&"font_color", ArtKit.AMBER)


func clear_status() -> void:
	_status = ""
	_hint.remove_theme_color_override(&"font_color")
	_hint.text = _hint_text()


func get_status() -> String:
	return _status


func _hint_text() -> String:
	return "Tap to pick · hold for details" if compact else "Tap to pick · hold or right-click for details"


func rows_for(width: float, count: int) -> int:
	if count <= 0:
		return 1
	var per_row: int = maxi(1, int(floor((width + CARD_GAP) / (card_size.x + CARD_GAP))))
	return int(ceil(float(count) / per_row))


func get_card_buttons() -> Array[Node]:
	return _flow.get_children()


func get_scroll() -> ScrollContainer:
	return _scroll


func pick(card_id: StringName) -> void:
	picked_id = card_id
	_refresh_picked()
	card_picked.emit(card_id)


func unpick() -> void:
	picked_id = &""
	_refresh_picked()
	card_unpicked.emit()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child: Node in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	_title.text = "YOUR HAND · %d" % _cards.size()
	if _status == "":
		_hint.text = _hint_text()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if strip else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if strip else ScrollContainer.SCROLL_MODE_AUTO
	var n: int = _cards.size()
	_flow.custom_minimum_size.x = (card_size.x * n + CARD_GAP * maxi(n - 1, 0)) if strip else card_size.x
	for c: Dictionary in _cards:
		var b: Button = TapHoldButton.new()
		b.name = "Card_%s" % c.get("id", "")
		b.custom_minimum_size = card_size
		b.theme_type_variation = &"HandCard"
		b.add_to_group(&"tap_target")
		var card: BannerCard = BannerCardScene.instantiate()
		card.name = "Card"
		card.custom_minimum_size = Vector2.ZERO
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.configure(c)
		card.side = &"player"
		card.signature = c.get("id") == _signature_id
		var id: StringName = c.get("id", &"")
		b.tapped.connect(func() -> void: unpick() if picked_id == id else pick(id))
		b.inspect_requested.connect(func() -> void: card_inspect_requested.emit(id))
		b.set_meta(&"card_id", id)
		_flow.add_child(b)
	_refresh_picked()


func _refresh_picked() -> void:
	for b: Node in _flow.get_children():
		(b.get_node("Card") as BannerCard).highlighted = b.get_meta(&"card_id") == picked_id
