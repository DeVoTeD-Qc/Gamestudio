# hand_area.gd
# Purpose: Hand area (bottom-center). Shows the hand as compact HandCard chips: cost, card
#   type, name, one rules line, FP/AR. The full CardView (p13) is NOT used here: at the
#   ~0.4x scale a hand slot allows, its name/cost text would be 7-10 pt on a phone
#   (see README "Phone readability"). CardView belongs in the long-press inspector (p09),
#   at >= 0.8x. Drag / tap-to-deploy arrive with p09; keep CardRow as the container.
#   Up to 7 cards (hand cap): CardRow is a plain Control and _fit_cards() places the
#   cards, centred, overlapping them when they don't fit (so the hand never widens the
#   bottom bar). Compact (phone) profile: smaller chips, no "HAND n/7" caption.
# Dependencies: hud_theme.tres variations (HandCard, CostBadge, UnitName, HudNumber, HudSubtle).
# Author: UI/UX Agent
extends PanelContainer

## Desktop chip size (about 45% of the 250x350 card frame); compact chip for the phone profile.
const CARD_SIZE: Vector2 = Vector2(112, 156)
const CARD_SIZE_COMPACT: Vector2 = Vector2(104, 108)
const CARD_GAP: int = 8
const HAND_CAP: int = 7

var compact: bool = false
var _cards_data: Array = []

@onready var _caption: Label = %CaptionLabel
@onready var _row: Control = %CardRow


func _ready() -> void:
	_row.resized.connect(_fit_cards)


func set_compact(value: bool) -> void:
	if value == compact:
		return
	compact = value
	_caption.visible = not compact
	set_hand(_cards_data)


## cards: Array of {name, type, cost, fp?, armor?, text}.
func set_hand(cards: Array) -> void:
	_cards_data = cards
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for card: Dictionary in cards:
		_row.add_child(_make_card(card))
	_caption.text = "HAND %d/%d" % [cards.size(), HAND_CAP]
	_fit_cards.call_deferred()


func get_cards() -> Array[Node]:
	return _row.get_children()


## Labels whose whole text must stay visible (cost, name, stats; the rules line may trim).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	for card: Node in get_cards():
		for label: Node in card.find_children("*", "Label", true, false):
			if label.has_meta(&"important"):
				out.append(label)
	return out


func _card_size() -> Vector2:
	return CARD_SIZE_COMPACT if compact else CARD_SIZE


func _fit_cards() -> void:
	var cards: Array[Node] = _row.get_children()
	var n: int = cards.size()
	var card_size: Vector2 = _card_size()
	for card: Node in cards:
		card_size = card_size.max((card as Control).get_combined_minimum_size())
	_row.custom_minimum_size = Vector2(card_size.x, card_size.y)
	if n == 0:
		return
	var pitch: float = card_size.x + CARD_GAP
	if n > 1:
		pitch = minf(pitch, (_row.size.x - card_size.x) / (n - 1))
	var total: float = card_size.x + pitch * (n - 1)
	var x: float = maxf(0.0, (_row.size.x - total) * 0.5)
	for card: Node in cards:
		var c: Control = card
		c.size = card_size
		c.position = Vector2(roundf(x), roundf((_row.size.y - card_size.y) * 0.5))
		x += pitch


func _make_card(card: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HandCard"
	panel.custom_minimum_size = _card_size()
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
	var cost: Label = _label(str(card.get("cost", 0)), &"HudNumber", true)
	cost.add_theme_color_override(&"font_color", Color("#12161A"))
	cost.custom_minimum_size = Vector2(14, 0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_to_group(&"key_number")
	badge.add_child(cost)
	var type_label: Label = _label(String(card.get("type", "")).to_upper(), &"HudTag", true)
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_label.clip_text = true
	type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(type_label)

	var title: Label = _label(String(card.get("name", "")), &"UnitName", true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	column.add_child(title)

	# The rules line takes what is left and trims; the full text is in the inspector (p09).
	var text: Label = _label(String(card.get("text", "")), &"HudSubtle", false)
	text.add_theme_color_override(&"font_color", Color("#D8DEE3"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(0, 20)
	column.add_child(text)

	if card.has("fp"):
		var stats: HBoxContainer = HBoxContainer.new()
		stats.add_theme_constant_override(&"separation", 3)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(stats)
		for pair: Array in [["FP", card.get("fp", 0)], ["AR", card.get("armor", 0)]]:
			var caption: Label = _label(pair[0], &"HudSubtle", false)
			caption.size_flags_vertical = Control.SIZE_SHRINK_END
			stats.add_child(caption)
			var value: Label = _label(str(pair[1]), &"HudNumber", true)
			value.add_to_group(&"key_number")
			stats.add_child(value)
			if pair[0] == "FP":
				var gap: Control = Control.new()
				gap.custom_minimum_size = Vector2(6, 0)
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stats.add_child(gap)
	return panel


func _label(text: String, variation: StringName, important: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if important:
		label.set_meta(&"important", true)
	return label
