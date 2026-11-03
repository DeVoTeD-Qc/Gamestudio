# match_screen.gd
# Purpose: Match screen (p08 layout). Composes the score bar, minimap intel strip,
#   killfeed area, board (3 lanes), Operator panel, hand area, Supply counter and
#   READY button with containers only (no hard-coded positions), and fills them
#   from a snapshot Dictionary. No game rules here: until p04 lands, it shows
#   mock_match_data.gd. Buttons only emit signals.
#
# Look: the project theme (assets/ui/hud_theme.tres, set in project.godot gui/theme/custom)
#   styles every theme_type_variation used here; nothing is styled in code.
#
# Layout (canvas_items + expand; the base is 1280x720 on desktop and drops to 960x540 on
#   phones, see scripts/ui/screen_profile.gd, so an 844x390 phone gets a 1168x540 canvas):
#   [SCORE BAR]        [INTEL MINIMAP]        [KILLFEED][MENU]
#   [ LEFT lane       ][ MID lane       ][ RIGHT lane      ]
#   [OPERATOR PANEL][        HAND        ][SUPPLY / READY]
#   Below COMPACT_HEIGHT (640) logical px the compact profile tightens bars, slots and buttons.
# Dependencies: scenes in scenes/match/, screen_profile.gd, mock_match_data.gd.
# Author: UI/UX Agent
extends Control

signal ready_pressed
signal menu_pressed

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const BASE_MARGIN: Vector2 = Vector2(16, 12)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(12, 8)
const KILLFEED_LINES: int = 3

## Fill the screen with the mock snapshot on _ready (off once p04 drives the match).
@export var use_mock_data: bool = true

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _score_bar: Control = %ScoreBar
@onready var _minimap: Control = %Minimap
@onready var _killfeed: VBoxContainer = %KillfeedSlot
@onready var _board: Control = %Board
@onready var _operator_panel: Control = %OperatorPanel
@onready var _hand: Control = %HandArea
@onready var _supply_value: Label = %SupplyValue
@onready var _supply_pips: HBoxContainer = %SupplyPips
@onready var _ready_button: Button = %ReadyButton
@onready var _menu_button: Button = %MenuButton
@onready var _layout: VBoxContainer = %Layout
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _action_panel: VBoxContainer = %ActionPanel

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## Safe rect in canvas px (inside get_viewport_rect()); tests set it to simulate a notched
## phone. Empty = read DisplayServer.get_display_safe_area() on mobile.
var safe_area_override: Rect2 = Rect2()
var _profile_set: bool = false


func _ready() -> void:
	_update_profile()
	resized.connect(_update_profile)
	get_viewport().size_changed.connect(_apply_safe_area)
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	if use_mock_data:
		show_snapshot(MockMatchData.round_3_sample())


## Renders a full match snapshot (shape: mock_match_data.gd).
func show_snapshot(snapshot: Dictionary) -> void:
	_score_bar.set_score(snapshot)
	_minimap.set_intel(snapshot.get("lanes", []))
	_board.set_lanes(snapshot.get("lanes", []))
	_operator_panel.set_operator(snapshot)
	_hand.set_hand(snapshot.get("hand", []))
	_set_supply(int(snapshot.get("supply", 0)), int(snapshot.get("supply_max", 0)))
	_set_killfeed(snapshot.get("killfeed", []))


## The controls that must stay on screen and never overlap (used by tests and QA).
func get_key_controls() -> Dictionary:
	return {
		"menu": _menu_button, "score_bar": _score_bar, "minimap": _minimap,
		"killfeed": _killfeed, "board": _board, "operator_panel": _operator_panel,
		"hand": _hand, "supply": %SupplyCounter, "ready": _ready_button,
	}


func get_board() -> Control:
	return _board


## Labels whose whole text must stay on screen (no clipping or ellipsis), for tests and QA.
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_supply_value]
	out.append_array(_score_bar.get_important_labels())
	out.append_array(_minimap.get_important_labels())
	for lane: Node in _board.get_lanes():
		out.append_array(lane.get_important_labels())
	out.append_array(_operator_panel.get_important_labels())
	out.append_array(_hand.get_important_labels())
	return out


## Switches between the desktop and compact (phone) layout from the logical height.
func _update_profile() -> void:
	var want: bool = size.y > 0.0 and size.y < ScreenProfile.COMPACT_HEIGHT
	if want == compact and _profile_set:
		return
	_profile_set = true
	compact = want
	_layout.add_theme_constant_override(&"separation", 6 if compact else 8)
	_top_bar.custom_minimum_size.y = 64 if compact else 72
	_menu_button.custom_minimum_size = Vector2(80, 64) if compact else Vector2(80, 72)
	_bottom_bar.custom_minimum_size.y = 0 if compact else 212
	_action_panel.custom_minimum_size.x = 150 if compact else 200
	_ready_button.custom_minimum_size = Vector2(150, 64) if compact else Vector2(200, 96)
	_board.set_compact(compact)
	_operator_panel.set_compact(compact)
	_hand.set_compact(compact)
	_minimap.set_compact(compact)
	_supply_pips.add_theme_constant_override(&"separation", 3 if compact else 4)
	for pip: Node in _supply_pips.get_children():
		(pip as Control).custom_minimum_size = _pip_size()
	_apply_safe_area()


## Supply pips: narrower on the phone so a 10-Supply bar fits the 150 px action column.
func _pip_size() -> Vector2:
	return Vector2(12, 16) if compact else Vector2(18, 20)


func _set_supply(supply: int, supply_max: int) -> void:
	_supply_value.text = "%d/%d" % [supply, supply_max]
	for child: Node in _supply_pips.get_children():
		_supply_pips.remove_child(child)
		child.queue_free()
	for i: int in supply_max:
		var pip: Panel = Panel.new()
		pip.theme_type_variation = &"SupplyPip" if i < supply else &"SupplyPipSpent"
		pip.custom_minimum_size = _pip_size()
		_supply_pips.add_child(pip)


## Placeholder lines; the real Killfeed.tscn (p14) is added as a child of KillfeedSlot.
func _set_killfeed(lines: Array) -> void:
	for child: Node in _killfeed.get_children():
		_killfeed.remove_child(child)
		child.queue_free()
	for i: int in mini(lines.size(), KILLFEED_LINES):
		var entry: Dictionary = lines[i]
		var label: Label = Label.new()
		var friendly: bool = entry.get("side", &"player") == &"player"
		label.theme_type_variation = &"KillfeedFriend" if friendly else &"KillfeedEnemy"
		label.text = String(entry.get("text", ""))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_killfeed.add_child(label)


## Keeps the HUD clear of phone notches / home indicator (Xogot on iPhone, mobile web).
func _apply_safe_area() -> void:
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
