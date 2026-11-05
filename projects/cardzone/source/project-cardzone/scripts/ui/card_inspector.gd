# card_inspector.gd
# Adapted from CallingCard scripts/ui/card_inspector.gd (cc07): same contract (open from tap /
#   long-press / right-click / "inspect" key / INFO, CLOSE + dimmed backdrop + Esc close it, safe
#   margins from the screen, compact flag), rebuilt in code for CardZone cards and with an info
#   mode for things that are not one card (areas, the Zone deck, player panels, the loadout).
# Purpose: The match screen's inspector (cz10). Nothing on the match screen is hover-only: every
#   card, tile and panel opens this. The big card is cz16's CzCard in its full layout, 220x308 pt
#   (art-direction.md §3), shrunk only if a screen is too short for it. Text comes from the card
#   data (CardData, cz05/cz06). A card the viewer may not see (the rival's held cards) shows only
#   what the rules reveal (face down).
# Dependencies: scenes/card/CzCard.tscn (cz16), CardData, match_theme.gd.
# Author: UI/UX Agent (cc07; adapted cz10)
extends Control

signal closed

const CARD_SCENE: PackedScene = preload("res://scenes/card/CzCard.tscn")
const CardWords: GDScript = preload("res://scripts/ui/card_words.gd")
const BIG_CARD_PT: Vector2 = Vector2(220, 308)
const TYPE_WORD: Dictionary = {&"weapon": "Weapon", &"item": "Item", &"attachment": "Attachment",
		&"hit": "Hit card", &"marker": "Shared marker card"}
const RARITY_WORD: Dictionary = {"S": "Starter", "C": "Common", "U": "Uncommon", "R": "Rare",
		"E": "Epic", "L": "Legendary"}

var compact: bool = false
var card: CardData = null
var mode: StringName = &"card"
## Logical px per point on this screen (1 / pt per px). MatchScreen sets it.
var px_per_pt: float = 1.0

var _scrim: ColorRect
var _margin: MarginContainer
var _panel: PanelContainer
var _card_view: CzCard
var _right: VBoxContainer
var _title: Label
var _subtitle: Label
var _stats: Label
var _scroll: ScrollContainer
var _body: Label
var _where: Label
var _close: Button
var _avail: Vector2 = Vector2(1280, 720)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(0.05, 0.02, 0.08, 0.84)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)
	_margin = MarginContainer.new()
	_margin.name = "SafeMargin"
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "InspectorPanel"
	_panel.theme_type_variation = &"InspectorPanel"
	center.add_child(_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_panel.add_child(row)
	_card_view = CARD_SCENE.instantiate()
	_card_view.name = "InspectorCard"
	_card_view.layout_mode_override = "full"
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_card_view)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override(&"separation", 6)
	row.add_child(_right)
	_title = _label(_right, &"InspectorTitle")
	_subtitle = _label(_right, &"Caption")
	_stats = _label(_right, &"CaptionStrong")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(_scroll)
	_body = _label(_scroll, &"InspectorBody")
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where = _label(_right, &"Caption")
	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = "CLOSE"
	_close.theme_type_variation = &"TopButton"
	_close.custom_minimum_size = Vector2(140, 64)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right.add_child(_close)
	for l: Label in [_title, _subtitle, _stats, _body, _where]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _ready() -> void:
	hide()
	_close.pressed.connect(close)
	_scrim.gui_input.connect(_on_scrim_input)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		close()
		get_viewport().set_input_as_handled()


## Sizes the panel for this screen: avail = logical size inside the safe margins.
func set_layout(avail: Vector2, pt_per_px: float, is_compact: bool) -> void:
	_avail = avail
	compact = is_compact
	px_per_pt = 1.0 / maxf(pt_per_px, 0.01)
	_size_panel()


## Keeps the panel clear of notches (MatchScreen passes its safe margins, logical px).
func set_safe_margins(lt: Vector2, rb: Vector2) -> void:
	_margin.add_theme_constant_override(&"margin_left", int(lt.x))
	_margin.add_theme_constant_override(&"margin_top", int(lt.y))
	_margin.add_theme_constant_override(&"margin_right", int(rb.x))
	_margin.add_theme_constant_override(&"margin_bottom", int(rb.y))


## c: CardData. context: {where: String (e.g. "In your hand"), hidden: bool, attached: [CardData],
## now: String (cz-clarity: what you can do with it right now, shown first)}.
func open_card(c: CardData, context: Dictionary = {}) -> void:
	mode = &"card"
	card = c
	var hidden: bool = context.get("hidden", false) or c == null
	_card_view.visible = true
	_card_view.face_down = hidden
	_card_view.held = false
	_card_view.attachments = []
	if hidden:
		_title.text = "Hidden card"
		_subtitle.text = "The rival's held card"
		_stats.text = ""
		_body.text = "Held cards are private in this prototype: you see how many the rival holds, not which. They sit on top of the rival's loadout and are part of their next hand, so they can Brace with them."
	else:
		_card_view.configure(c)
		_title.text = c.display_name
		_subtitle.text = _subtitle_for(c)
		_stats.text = _stats_for(c)
		# cz-clarity: what the card gives you, in plain words, before the printed card text.
		var lines: PackedStringArray = []
		var now: String = String(context.get("now", ""))
		if now != "":
			lines.append(now)
		lines.append("WHAT IT GIVES YOU")
		lines.append_array(CardWords.gives(c))
		var att: Array = context.get("attached", [])
		if not att.is_empty():
			var names: PackedStringArray = []
			for a: CardData in att:
				names.append("%s (%s)" % [a.display_name, CardWords.short(a).trim_prefix("a gun attachment: ")])
			lines.append("Attached: %s." % ", ".join(names))
		if c.rules_text != "":
			lines.append("Card text: %s" % c.rules_text)
		var legend: String = CardWords.icon_legend(c)
		if legend != "":
			lines.append(legend)
		_body.text = "\n".join(lines)
	_where.text = String(context.get("where", ""))
	_where.visible = _where.text != ""
	_show()


## Text-only sheet (areas, Zone deck, player panels, loadout list).
func open_info(title: String, subtitle: String, body: String) -> void:
	mode = &"info"
	card = null
	_card_view.visible = false
	_title.text = title
	_subtitle.text = subtitle
	_stats.text = ""
	_body.text = body
	_where.text = ""
	_where.visible = false
	_show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func get_card_view() -> CzCard:
	return _card_view


func get_panel() -> Control:
	return _panel


func get_title_text() -> String:
	return _title.text


func get_body_text() -> String:
	return _body.text


func get_important_labels() -> Array[Label]:
	return [_title, _subtitle, _stats, _where]


func _show() -> void:
	_stats.visible = _stats.text != ""
	_subtitle.visible = _subtitle.text != ""
	_size_panel()
	_scroll.scroll_vertical = 0
	show()
	(func() -> void: if is_instance_valid(_close) and _close.is_inside_tree(): _close.grab_focus()).call_deferred()


func _size_panel() -> void:
	var chrome: float = 24.0 + 4.0
	var card_px: Vector2 = (BIG_CARD_PT * px_per_pt).floor()
	var max_h: float = _avail.y - chrome
	if card_px.y > max_h:
		card_px = (card_px * (max_h / card_px.y)).floor()
	_card_view.custom_minimum_size = card_px
	_card_view.size = card_px
	var right_w: float = clampf(_avail.x - chrome - 16.0 - (card_px.x if _card_view.visible else 0.0), 280.0, 460.0)
	if not _card_view.visible:
		right_w = clampf(_avail.x - chrome, 280.0, 620.0)
	_right.custom_minimum_size = Vector2(right_w, minf(card_px.y, max_h))
	_scroll.custom_minimum_size.y = 0
	_panel.custom_minimum_size = Vector2.ZERO
	# The body scrolls inside whatever height is left (long Zone lists on short screens).
	_panel.size = Vector2.ZERO


func _subtitle_for(c: CardData) -> String:
	var d: Dictionary = c.to_dict()
	var type: StringName = d["type"]
	var parts: PackedStringArray = [TYPE_WORD.get(type, "Card")]
	var r: String = c.rarity_letter()
	if type in [&"weapon", &"item", &"attachment"]:
		parts.append("Starter" if c.is_starter() else "%s (%s)" % [RARITY_WORD.get(r, r), r])
	if c.supply_drop:
		parts.append("Supply drop: Search %d" % CzCardArt.drop_cost())
	elif c.cost > 0:
		parts.append("Loot: Search %d" % c.cost)
	return " · ".join(parts)


func _stats_for(c: CardData) -> String:
	var parts: PackedStringArray = []
	if c.is_weapon():
		parts.append("DMG %d · RNG %d" % [c.dmg, c.rng])
	for k: String in ["move", "search", "heal", "pull"]:
		if int(c.get(k)) > 0:
			parts.append("%s %d" % [k.capitalize(), int(c.get(k))])
	if c.brace > 0:
		parts.append("Brace %d" % c.brace)
	return " · ".join(parts)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()


func _label(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	parent.add_child(l)
	return l
