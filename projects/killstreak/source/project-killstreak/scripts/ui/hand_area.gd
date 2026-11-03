# hand_area.gd
# Purpose: Hand area (bottom-center). Shows the hand as compact HandCard chips, a mini version
#   of the card in CardView's icon language (f04): cost hex, card-type and weapon-class icons
#   (+ type word when it fits), name, keyword icons in amber (words when they fit; cards with no
#   keyword icon show one rules line instead), FP / Armor icons with their numbers.
#   The full CardView (p13) is NOT used here: at the
#   ~0.4x scale a hand slot allows, its name/cost text would be 7-10 pt on a phone
#   (see README "Phone readability"). CardView belongs in the long-press inspector (p09),
#   at >= 0.8x.
#   Input (p09): each chip runs a PressGesture: tap = select, drag = drag to a lane,
#   long-press / right-click = inspect. The hand only reports gestures with the card's rules
#   uid; match_controller.gd decides what they mean. set_selected() marks the chosen card;
#   chips the player can't afford (playable = false) use the dim style.
#   Up to 7 cards (hand cap): CardRow is a plain Control and _fit_cards() places the
#   cards, centred, overlapping them when they don't fit (so the hand never widens the
#   bottom bar). Compact (phone) profile: smaller chips, no "HAND n/7" caption.
# Dependencies: hud_theme.tres variations (HandCard, HandCardSelected, HandCardDim, UnitName,
#   HudNumber, HudSubtle, HudTag), press_gesture.gd, mini_icons.gd, cost_hex.gd, icon_sheet.gd.
# Author: UI/UX Agent
extends PanelContainer

signal card_tapped(uid: int)
signal card_inspected(uid: int)
signal card_drag_started(uid: int, pos: Vector2)
signal card_drag_moved(uid: int, pos: Vector2)
signal card_drag_ended(uid: int, pos: Vector2)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const MiniIcons: GDScript = preload("res://scripts/ui/mini_icons.gd")
const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")

## Desktop chip size (about 45% of the 250x350 card frame); compact chip for the phone profile.
const CARD_SIZE: Vector2 = Vector2(112, 156)
const CARD_SIZE_COMPACT: Vector2 = Vector2(104, 108)
const CARD_GAP: int = 8
## f04 icon sizes and cost hex (pointy-top, as on CardView).
const ICON_PX: float = 20.0
const ICON_PX_COMPACT: float = 18.0
const HEX_SIZE: Vector2 = Vector2(28, 32)
const HEX_SIZE_COMPACT: Vector2 = Vector2(24, 28)
const HAND_CAP: int = 7

var compact: bool = false
var _cards_data: Array = []
## Rules uid of the selected card, -1 = none.
var selected_uid: int = -1
## uid of the card being dragged (its chip is hidden while the ghost follows the pointer).
var dragging_uid: int = -1

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


## cards: Array of {name, type, cost, fp?, armor?, text, card_type?, weapon_class?, keywords?, elite?}
## (card_info.gd chip()).
func set_hand(cards: Array) -> void:
	_cards_data = cards
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for card: Dictionary in cards:
		var chip: Control = _make_card(card)
		_wire(chip, int(card.get("uid", -1)))
		_row.add_child(chip)
	_apply_styles()
	_caption.text = "HAND %d/%d" % [cards.size(), HAND_CAP]
	_fit_cards.call_deferred()


func get_cards() -> Array[Node]:
	return _row.get_children()


## The chip showing the card with this rules uid, or null.
func get_card(uid: int) -> Control:
	for chip: Node in _row.get_children():
		if int(chip.get_meta(&"uid", -1)) == uid:
			return chip
	return null


func set_selected(uid: int) -> void:
	selected_uid = uid
	_apply_styles()


## Hides the chip being dragged (-1 shows all again).
func set_dragging(uid: int) -> void:
	dragging_uid = uid
	_apply_styles()


func _apply_styles() -> void:
	for chip: Node in _row.get_children():
		var uid: int = int(chip.get_meta(&"uid", -1))
		var playable: bool = bool(chip.get_meta(&"playable", true))
		var variation: StringName = &"HandCard" if playable else &"HandCardDim"
		if uid == selected_uid and uid >= 0:
			variation = &"HandCardSelected"
		(chip as Control).theme_type_variation = variation
		# Unaffordable chips fade so the playable ones stand out; the dragged one fades more.
		var alpha: float = 1.0 if playable or uid == selected_uid else 0.55
		(chip as Control).modulate.a = 0.35 if uid == dragging_uid and uid >= 0 else alpha


func _wire(chip: Control, uid: int) -> void:
	chip.set_meta(&"uid", uid)
	var g: RefCounted = PressGesture.new(chip)
	chip.set_meta(&"gesture", g)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			chip.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void: card_tapped.emit(uid))
	g.long_pressed.connect(func(_p: Vector2) -> void: card_inspected.emit(uid))
	g.drag_started.connect(func(p: Vector2) -> void: card_drag_started.emit(uid, p))
	g.drag_moved.connect(func(p: Vector2) -> void: card_drag_moved.emit(uid, p))
	g.drag_ended.connect(func(p: Vector2) -> void: card_drag_ended.emit(uid, p))


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
	panel.set_meta(&"playable", bool(card.get("playable", true)))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0 if compact else 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var ctype: String = MiniIcons.card_type(card)
	var weapon: String = MiniIcons.weapon_class(card)
	var text_color: Color = get_theme_color(&"text", &"Hud")
	var icon_px: float = ICON_PX_COMPACT if compact else ICON_PX

	# Row 1 (as on CardView): cost hex, card-type icon, weapon-class icon, elite mark, then the
	# type word if it still fits (words go before icons).
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var badge: Control = CostHex.new()
	badge.custom_minimum_size = HEX_SIZE_COMPACT if compact else HEX_SIZE
	badge.set_text(str(card.get("cost", 0)))
	badge.label.set_meta(&"important", true)
	badge.label.add_to_group(&"key_number")
	top.add_child(badge)
	var type_icon: TextureRect = MiniIcons.icon(StringName("type_" + ctype), icon_px, text_color)
	type_icon.tooltip_text = ctype.to_upper()
	top.add_child(type_icon)
	if weapon != "":
		top.add_child(MiniIcons.icon(StringName("class_" + weapon), icon_px, text_color))
	if bool(card.get("elite", false)):
		top.add_child(MiniIcons.icon(&"elite", icon_px, get_theme_color(&"elite", &"Hud")))
	var type_word: Label = MiniIcons.word(String(card.get("type", "")).to_upper())
	type_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(type_word)
	top.resized.connect(MiniIcons.fit_words.bind(top))

	var title: Label = _label(String(card.get("name", "")), &"UnitName", true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	column.add_child(title)

	# Keyword icons (amber, words only when they fit); cards without keyword icons keep their
	# rules line, which trims (the full text is in the inspector, p09).
	var keywords: Array = card.get("keywords", [])
	if not keywords.is_empty():
		var kw: HBoxContainer = MiniIcons.keyword_row(keywords, icon_px, get_theme_color(&"accent", &"Hud"))
		column.add_child(kw)
		kw.resized.connect(MiniIcons.fit_words.bind(kw))
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(spacer)
	else:
		var text: Label = _label(String(card.get("text", "")), &"HudSubtle", false)
		text.add_theme_color_override(&"font_color", text_color)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(0, 20)
		column.add_child(text)

	# FP bottom-left, Armor bottom-right, each with its CardView icon.
	if card.has("fp"):
		var stats: HBoxContainer = HBoxContainer.new()
		stats.add_theme_constant_override(&"separation", 2)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(stats)
		for pair: Array in [[&"stat_firepower", card.get("fp", 0)], [&"stat_armor", card.get("armor", 0)]]:
			if pair[0] == &"stat_armor":
				var gap: Control = Control.new()
				gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stats.add_child(gap)
			stats.add_child(MiniIcons.icon(pair[0], icon_px, text_color))
			var value: Label = _label(str(pair[1]), &"HudNumber", true)
			value.add_to_group(&"key_number")
			stats.add_child(value)
	return panel


func _label(text: String, variation: StringName, important: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if important:
		label.set_meta(&"important", true)
	return label
