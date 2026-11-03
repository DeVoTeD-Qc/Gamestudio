# run_screen.gd
# Purpose: Base for the run screens (Title, Loadout, RunMap, AfterAction, Reward, RunEnd; p11).
#   Owns what they share: the compact (phone) profile below ScreenProfile.COMPACT_HEIGHT logical
#   px, safe-area margins for notched phones (same rule as match_screen.gd), the PlaytestLog
#   screen announcement and small builders for theme-styled Labels / Buttons / tiles.
#   Phone rules (README "Phone readability"): text >= 16 px and tap targets >= 64 px at the
#   540 px phone base, i.e. >= 11.6 pt and >= 46 pt on an 844x390 iPhone.
#   Subclasses override _build() (once, from _ready), _apply_compact() (when the profile
#   changes) and screen_id(). Styling comes from hud_theme.tres variations only.
# Scene contract: the root Control has a %SafeArea MarginContainer filling the screen.
# Dependencies: screen_profile.gd, run_flow.gd, pick_tile.gd, EventBus, RunState, SceneRouter.
# Author: UI/UX Agent (p11)
extends Control

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const PickTile: GDScript = preload("res://scripts/ui/run/pick_tile.gd")

const BASE_MARGIN: Vector2 = Vector2(32, 24)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
## Height of main buttons (px): 64 on the phone = 46 pt at 0.72 pt per px.
const BUTTON_H: float = 72.0
const BUTTON_H_COMPACT: float = 64.0

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## Safe rect in canvas px; tests set it to simulate a notched phone. Empty = read the display.
var safe_area_override: Rect2 = Rect2():
	set(value):
		safe_area_override = value
		if is_node_ready():
			_apply_safe_area()

var _profile_set: bool = false

@onready var _safe_area: MarginContainer = %SafeArea


func _ready() -> void:
	_build()
	resized.connect(_on_resized)
	get_viewport().size_changed.connect(_apply_safe_area)
	_on_resized()
	var id: StringName = screen_id()
	var bus: Node = RunFlow.event_bus()
	if id != &"" and bus != null:
		bus.screen_shown.emit(id)


## Builds the screen from the run (called once from _ready).
func _build() -> void:
	pass


## Re-applies sizes for the current profile (compact or not).
func _apply_compact() -> void:
	pass


## Name announced to PlaytestLog (EventBus.screen_shown).
func screen_id() -> StringName:
	return &""


func button_height() -> float:
	return BUTTON_H_COMPACT if compact else BUTTON_H


func run() -> RunProgress:
	var rs: Node = RunFlow.run_state()
	return rs.run if rs != null else null


func goto(path: String) -> void:
	RunFlow.goto(path)


func _on_resized() -> void:
	var want: bool = size.y > 0.0 and size.y < ScreenProfile.COMPACT_HEIGHT
	if want != compact or not _profile_set:
		compact = want
		_profile_set = true
		_apply_compact()
	_apply_safe_area()


func _apply_safe_area() -> void:
	if _safe_area == null:
		return
	var margin_lt: Vector2 = BASE_MARGIN_COMPACT if compact else BASE_MARGIN
	var margin_rb: Vector2 = margin_lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or safe_area_override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if safe_area_override.has_area():
			window = get_viewport_rect().size
			safe = safe_area_override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = get_viewport_rect().size / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
	_safe_area_changed()


## Called after the safe-area margins change (screens that size content to the room left).
func _safe_area_changed() -> void:
	pass


# =============================================================================
# Builders
# =============================================================================

static func make_label(text: String, variation: StringName = &"", wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_button(text: String, variation: StringName = &"HudButton", min_w: float = 160.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(min_w, BUTTON_H_COMPACT)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func make_tile() -> PickTile:
	return PickTile.new()


## "pick exactly 3" -> "Pick exactly 3."
static func sentence(text: String) -> String:
	if text == "":
		return ""
	var s: String = text[0].to_upper() + text.substr(1)
	return s if s.ends_with(".") else s + "."


static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Ticket tags: filled for tickets left, hollow for spent ones (shape, not colour only).
static func make_tickets(left: int, total: int, pip: Vector2 = Vector2(18, 26)) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in total:
		var p: Panel = Panel.new()
		p.theme_type_variation = &"TicketPip" if i < left else &"TicketPipSpent"
		p.custom_minimum_size = pip
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(p)
	return row
