# card_inspector.gd
# Purpose: Card inspector overlay (scenes/match/CardInspector.tscn, p09). Opened by long-press
#   (touch) or right-click (mouse) on a hand card, a unit on the board or the Operator panel.
#   Shows the full CardView at 0.8x-1.4x of its 250x350 base (as big as the screen height
#   allows) next to a text panel: name, type line, full rules text, one line per keyword /
#   trigger with its rule (card_info.gd), and a status line ("Costs 3 Supply - you have 2").
#   Closes on CLOSE, a tap anywhere outside the text panel, or the cancel action (Esc).
#   kc-board: above the card, the full 512x128 banner (the art's 4:1 band with large badges; the
#   rival's mirrored as on the board), animated (shimmer) while the inspector is open, and a line
#   naming the art. info.view = {} hides the card (objective tiles, incoming backs, rail boxes).
#   kc-da-ui2 (art direction #4, "pulling one card into the light"): ONE big card plus a paper rules
#   sheet, nothing else. The 512x128 banner shows only when there is no card to show (tokens,
#   face-down backs, rail boxes); the text panel is orders paper (paper_sheet.gd) with dark ink;
#   the art line is a short mono caption with no placeholder words; the glossary links are
#   steel info-icon sockets, not blank "?" plates.
# Dependencies: CardView.tscn (card_view.gd), hud_theme.tres variations (Scrim, HudPanelDark,
#   HudHeader, HudSubtle, HudAccent, KeywordName, HudButton).
# Author: UI/UX Agent (p09)
extends Control

signal closed

const MIN_SCALE: float = 0.8
const MAX_SCALE: float = 1.4
const MARGIN: float = 24.0
## Width of the text panel; narrower on short (phone) canvases so card + text fit side by side.
const INFO_WIDTH: float = 440.0
const INFO_WIDTH_COMPACT: float = 400.0
const BANNER_SIZE: Vector2 = Vector2(512, 128)
const PaperSheet: GDScript = preload("res://scripts/ui/paper_sheet.gd")
## kc-da-ui2: the card may grow to this width when the room allows (one big card).
const CARD_MAX_W: float = 360.0

@onready var _center: Control = $Center
@onready var _holder: Control = %CardHolder
@onready var _card: Control = %Card
@onready var _info_panel: PanelContainer = %InfoPanel
@onready var _title: Label = %TitleLabel
@onready var _type: Label = %TypeLabel
@onready var _rules: Label = %RulesLabel
@onready var _keywords: VBoxContainer = %KeywordList
@onready var _status: Label = %StatusLabel
@onready var _close: Button = %CloseButton
@onready var _banner_holder: Control = %BannerHolder
var _banner: BannerView = null
## kc-syn-ui: rules, keyword lines and status scroll inside the text panel when they would make it
## taller than the room (the phone inspector of a Protector was 1 px too tall, and the synergy
## lines add more). Title, type and CLOSE always stay visible.
var _body: ScrollContainer = null
var _body_col: VBoxContainer = null
## kc-da-ui2: the art caption (mono, muted ink) under the status line.
var _art_label: Label = null


func _ready() -> void:
	var info: VBoxContainer = _rules.get_parent() as VBoxContainer
	_body = ScrollContainer.new()
	_body.name = "Body"
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body_col = VBoxContainer.new()
	_body_col.name = "BodyColumn"
	_body_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_col.add_theme_constant_override(&"separation", info.get_theme_constant(&"separation"))
	_body.add_child(_body_col)
	info.add_child(_body)
	info.move_child(_body, _rules.get_index())
	_body.owner = self
	_body_col.owner = self
	for n: Control in [_rules, _keywords, _status]:
		n.reparent(_body_col, false)
		n.owner = self
		n.unique_name_in_owner = true
	_art_label = Label.new()
	_art_label.name = "ArtLabel"
	_art_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_art_label.add_theme_font_override(&"font", PaperSheet.mono_font())
	_art_label.add_theme_font_size_override(&"font_size", 12)
	_body_col.add_child(_art_label)
	_art_label.owner = self
	_art_label.unique_name_in_owner = true
	_paper()
	_banner = BannerView.new()
	_banner.name = "Banner"
	_banner.dim_back = false
	_banner.show_name = false  # kc-ui4: the title above names it
	_banner.size = BANNER_SIZE
	_banner_holder.add_child(_banner)
	_close.pressed.connect(close)
	resized.connect(_fit)


## info: {view (CardView Dictionary, {} = no card), title, type, text, keywords: [{name, text}],
## status, banner (unit entry for the 512x128 banner), banner_back (bool: a face-down back),
## side (0 you / 1 rival), art_line}.
func open(info: Dictionary) -> void:
	var view: Dictionary = info.get("view", {})
	_holder.visible = not view.is_empty()
	if not view.is_empty():
		_card.set_card_data(view)
	var banner: Dictionary = info.get("banner", {})
	var side: StringName = &"enemy" if int(info.get("side", 0)) == 1 else &"player"
	if _holder.visible:
		# kc-da-ui2: one copy of the card only; the banner is the picture when there is no card.
		_banner.show_empty()
	elif bool(info.get("banner_back", false)):
		_banner.show_incoming()
	elif not banner.is_empty():
		var shown: Dictionary = banner.duplicate()
		shown["pending"] = false
		if not bool(info.get("is_unit", true)) and not bool(shown.get("operator", false)):
			shown.erase("fp")
			shown["bolt"] = true
		_banner.show_unit(shown, side, true)
	else:
		_banner.show_empty()
	_banner_holder.visible = _banner.mode != BannerView.Mode.EMPTY
	var art_line: String = String(info.get("art_line", ""))
	_title.text = String(info.get("title", ""))
	_type.text = String(info.get("type", "")).to_upper()
	_rules.text = String(info.get("text", ""))
	_rules.visible = not _rules.text.is_empty()
	for child: Node in _keywords.get_children():
		_keywords.remove_child(child)
		child.queue_free()
	for k: Dictionary in info.get("keywords", []):
		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"KeywordName"
		name_label.text = String(k.get("name", ""))
		PaperSheet.ink(name_label, PaperSheet.INK_BRASS)
		_keywords.add_child(name_label)
		_add_glossary_link(name_label, StringName(String(k.get("id", ""))))
		var text_label: Label = Label.new()
		text_label.text = String(k.get("text", ""))
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PaperSheet.ink(text_label)
		_keywords.add_child(text_label)
	_keywords.visible = _keywords.get_child_count() > 0
	_status.text = String(info.get("status", ""))
	_status.visible = not _status.text.is_empty()
	_art_label.text = art_line.to_upper()
	_art_label.visible = art_line != ""
	_art_label.tooltip_text = art_line
	show()
	_body.scroll_vertical = 0
	_fit()
	if _banner_holder.visible:
		_banner.set_focus(true)
	_close.grab_focus.call_deferred()
	# Wrapped labels know their height only once the panel has its width: measure again after layout.
	for i: int in 2:
		await get_tree().process_frame
		if not visible:
			return
		_fit()


## kc-ui4: a "?" at the end of a keyword line opens the glossary at that entry (over the inspector).
## The label keeps its place in KeywordList (the button is its child).
func _add_glossary_link(label: Label, id: StringName) -> void:
	var G: GDScript = load("res://scripts/ui/codex/glossary.gd") as GDScript
	var key: StringName = G.call(&"key_for", id) if id != &"" else &""
	if key == &"":
		return
	var q: Button = Button.new()
	q.name = "GlossaryLink"
	q.text = "?"
	q.theme_type_variation = &"HudButton"
	q.tooltip_text = "Glossary: %s" % label.text
	q.custom_minimum_size = Vector2(64, 64)
	# kc-da-ui2: an info icon in a steel socket (the "?" text stays only without the kit icon).
	if UiKit.set_button_icon(q, &"ui_info", 26.0):
		q.text = ""
		q.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.focus_mode = Control.FOCUS_ALL
	q.add_to_group(&"tap_target")
	q.set_meta(&"glossary_key", key)
	label.add_child(q)
	label.custom_minimum_size.y = 64
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.resized.connect(func() -> void: q.position = Vector2(label.size.x - q.size.x, (label.size.y - q.size.y) * 0.5))
	q.pressed.connect(func() -> void: open_glossary(key))


## Opens the glossary over the inspector at `key`.
func open_glossary(key: StringName = &"") -> Control:
	var existing: Node = get_node_or_null(^"Glossary")
	if existing != null:
		existing.call(&"scroll_to", key)
		return existing
	return (load("res://scripts/ui/codex/glossary.gd") as GDScript).call(&"open_over", self, key)


## kc-da-ui2: the orders-paper rules sheet: paper stylebox + fibre, dark ink on every label.
func _paper() -> void:
	PaperSheet.apply(_info_panel, 16.0, 6)
	PaperSheet.ink(_title)
	_title.add_theme_font_override(&"font", PaperSheet.head_font())
	PaperSheet.ink(_type, PaperSheet.INK_MUTED)
	PaperSheet.ink(_rules)
	PaperSheet.ink(_status)
	PaperSheet.ink(_art_label, PaperSheet.INK_MUTED)


## True when the text panel is the paper sheet (tests).
func is_paper() -> bool:
	return _info_panel.has_meta(&"paper")


func get_art_label() -> Label:
	return _art_label


func get_banner() -> BannerView:
	return _banner if _banner_holder.visible else null


## Keeps the card and text clear of notches / the home indicator (set by match_screen.gd).
func set_safe_margins(left_top: Vector2, right_bottom: Vector2) -> void:
	_center.offset_left = left_top.x
	_center.offset_top = left_top.y
	_center.offset_right = -right_bottom.x
	_center.offset_bottom = -right_bottom.y
	_fit()


func close() -> void:
	if not visible:
		return
	_banner.set_focus(false)
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


## Effective scale of the card face (for tests: >= 0.8).
func get_card_scale() -> float:
	return _card.scale.x


func get_card_view() -> Control:
	return _card


## Labels whose whole text must show (name and type line; rules/keywords wrap).
func get_important_labels() -> Array[Label]:
	return [_title, _type]


func _fit() -> void:
	if not visible or size.y <= 0.0:
		return
	var room: Vector2 = size - Vector2(_center.offset_left - _center.offset_right, _center.offset_top - _center.offset_bottom)
	var compact: bool = size.y < 640.0
	var info_w: float = INFO_WIDTH_COMPACT if compact else INFO_WIDTH
	_info_panel.custom_minimum_size.x = info_w
	var banner_h: float = BANNER_SIZE.y + 8.0 if _banner_holder.visible else 0.0
	# kc-cards-impl: the Y2+ card at its own width (never scaled): as wide as the room allows, 220..330.
	var by_height: float = (room.y - 2.0 * MARGIN - banner_h - (CardView.height_for(0.0) - 0.0)) * 4.0 + 8.0
	var by_width: float = room.x - 2.0 * MARGIN - info_w - 24.0
	var w: float = clampf(floorf(minf(by_height, by_width)), 220.0, CARD_MAX_W)
	_card.pivot_offset = Vector2.ZERO
	_card.position = Vector2.ZERO
	_card.scale = Vector2.ONE
	if _card.has_method(&"set_card_width"):
		_card.set_card_width(w)
	# kc-da-ui2: on big screens the one card is pulled into the light: scaled up to 1.5x while the
	# card and the sheet still fit side by side.
	var base: Vector2 = CardView.size_for(w)
	var grow: float = 1.0
	if w >= CARD_MAX_W:
		grow = clampf(minf((room.y - 2.0 * MARGIN) / base.y, (room.x - 2.0 * MARGIN - info_w - 24.0) / base.x), 1.0, 1.5)
	_card.pivot_offset = Vector2.ZERO
	_card.scale = Vector2(grow, grow)
	_holder.custom_minimum_size = base * grow
	# The text panel may be as tall as the room under the banner; its body scrolls past that.
	var info_max: float = room.y - banner_h - 4.0
	_body_col.custom_minimum_size.x = info_w - 32.0
	var content_h: float = _body_col.get_combined_minimum_size().y
	_body.custom_minimum_size.y = 0.0
	var fixed_h: float = _info_panel.get_combined_minimum_size().y
	_body.custom_minimum_size.y = clampf(content_h, 0.0, maxf(48.0, info_max - fixed_h))


func _gui_input(event: InputEvent) -> void:
	# A tap outside the text panel closes (the panel itself stops its own taps).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		if not _info_panel.get_global_rect().has_point(get_global_transform() * (event as InputEventMouseButton).position):
			close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		close()
