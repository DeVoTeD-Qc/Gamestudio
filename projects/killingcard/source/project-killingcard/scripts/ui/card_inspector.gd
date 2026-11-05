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


func _ready() -> void:
	_banner = BannerView.new()
	_banner.name = "Banner"
	_banner.dim_back = false
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
	if bool(info.get("banner_back", false)):
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
		_keywords.add_child(name_label)
		var text_label: Label = Label.new()
		text_label.text = String(k.get("text", ""))
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_keywords.add_child(text_label)
	_keywords.visible = _keywords.get_child_count() > 0
	_status.text = String(info.get("status", ""))
	if art_line != "":
		_status.text = (_status.text + "\n" + art_line).strip_edges()
	_status.visible = not _status.text.is_empty()
	show()
	_fit()
	if _banner_holder.visible:
		_banner.set_focus(true)
	_close.grab_focus.call_deferred()


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
	var by_height: float = (room.y - 2.0 * MARGIN - banner_h) / CardView.BASE_SIZE.y
	var by_width: float = (room.x - 2.0 * MARGIN - info_w - 24.0) / CardView.BASE_SIZE.x
	var s: float = clampf(minf(by_height, by_width), MIN_SCALE, MAX_SCALE)
	_card.pivot_offset = Vector2.ZERO
	_card.position = Vector2.ZERO
	_card.scale = Vector2(s, s)
	_holder.custom_minimum_size = CardView.BASE_SIZE * s


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
