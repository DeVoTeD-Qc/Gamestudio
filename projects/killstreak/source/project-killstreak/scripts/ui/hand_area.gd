# hand_area.gd
# Purpose: Hand area PLACEHOLDER (bottom-center). Shows the hand as simple card
#   rectangles so the layout reads with real content. The real hand (CardView,
#   drag / tap-to-deploy, long-press inspector) replaces the card building in
#   _make_card() with p09; keep CardRow as the container.
#   Up to 7 cards (hand cap): when they don't fit, the row overlaps them.
# Dependencies: hud_placeholder_style.gd variation names (HandCard, CostBadge).
# Author: UI/UX Agent
extends PanelContainer

## Card size at 50% of the 250x350 card frame (art-direction.md), slightly trimmed to fit.
const CARD_SIZE: Vector2 = Vector2(112, 156)
const CARD_GAP: int = 8
const HAND_CAP: int = 7

@onready var _caption: Label = %CaptionLabel
@onready var _row: HBoxContainer = %CardRow


func _ready() -> void:
	_row.resized.connect(_fit_cards)


## cards: Array of {name, type, cost, fp?, armor?, text}.
func set_hand(cards: Array) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for card: Dictionary in cards:
		_row.add_child(_make_card(card))
	_caption.text = "HAND %d/%d" % [cards.size(), HAND_CAP]
	_fit_cards()


func get_cards() -> Array[Node]:
	return _row.get_children()


func _fit_cards() -> void:
	var n: int = _row.get_child_count()
	if n < 2:
		return
	var spare: float = _row.size.x - n * CARD_SIZE.x
	_row.add_theme_constant_override(&"separation", mini(CARD_GAP, floori(spare / (n - 1))))


func _make_card(card: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HandCard"
	panel.custom_minimum_size = CARD_SIZE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_to_group(&"tap_target")
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	# Row 1: cost badge + type. Row 2: name across the full card width.
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var badge: PanelContainer = PanelContainer.new()
	badge.theme_type_variation = &"CostBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(badge)
	var cost: Label = _label(str(card.get("cost", 0)), 20)
	cost.add_theme_color_override(&"font_color", Color("#12161A"))
	cost.custom_minimum_size = Vector2(16, 0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(cost)
	var type_label: Label = _label(String(card.get("type", "")), 14)
	type_label.theme_type_variation = &"HudSubtle"
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_label.clip_text = true
	top.add_child(type_label)

	var title: Label = _label(String(card.get("name", "")), 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	column.add_child(title)

	var text: Label = _label(String(card.get("text", "")), 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 2
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text)

	if card.has("fp"):
		var stats: Label = _label("FP %d   AR %d" % [card.get("fp", 0), card.get("armor", 0)], 18)
		column.add_child(stats)
	return panel


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
