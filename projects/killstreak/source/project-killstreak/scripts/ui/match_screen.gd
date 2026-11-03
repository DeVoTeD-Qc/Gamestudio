# match_screen.gd
# Purpose: Match screen (p08 layout). Composes the score bar, minimap intel strip,
#   killfeed area, board (3 lanes), Operator panel, hand area, Supply counter and
#   READY button with containers only (no hard-coded positions), and fills them
#   from a snapshot Dictionary. No game rules here: until p04 lands, it shows
#   mock_match_data.gd. Buttons only emit signals.
#
# Theme hook: the placeholder look is built in code (hud_placeholder_style.gd).
#   To apply the HUD theme from p13: assign `hud_theme`, or tick `use_hud_theme_file`
#   (loads HUD_THEME_PATH). It is merged over the placeholder, so every type and
#   variation it defines replaces ours. Off by default while p13 is in progress.
#
# Layout at the 1280x720 base (canvas_items + expand, so height is always 720
#   logical px and wider screens such as an 844x390 phone get extra width):
#   [SCORE BAR]        [INTEL MINIMAP]        [KILLFEED][MENU]
#   [ LEFT lane       ][ MID lane       ][ RIGHT lane      ]
#   [OPERATOR PANEL][        HAND        ][SUPPLY / READY]
# Dependencies: scenes in scenes/match/, hud_placeholder_style.gd, mock_match_data.gd.
# Author: UI/UX Agent
extends Control

signal ready_pressed
signal menu_pressed

const HUD_THEME_PATH: String = "res://assets/ui/hud_theme.tres"
const PlaceholderStyle: GDScript = preload("res://scripts/ui/hud_placeholder_style.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const BASE_MARGIN: Vector2 = Vector2(16, 12)
const KILLFEED_LINES: int = 3

## Real HUD theme (p13), merged over the placeholder look.
@export var hud_theme: Theme
## Load HUD_THEME_PATH when hud_theme is empty (turn on once p13's theme is final).
@export var use_hud_theme_file: bool = false
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


func _ready() -> void:
	_apply_theme()
	_apply_safe_area()
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


func _set_supply(supply: int, supply_max: int) -> void:
	_supply_value.text = "%d/%d" % [supply, supply_max]
	for child: Node in _supply_pips.get_children():
		_supply_pips.remove_child(child)
		child.queue_free()
	for i: int in supply_max:
		var pip: Panel = Panel.new()
		pip.theme_type_variation = &"SupplyPip" if i < supply else &"SupplyPipSpent"
		pip.custom_minimum_size = Vector2(18, 20)
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


func _apply_theme() -> void:
	var merged: Theme = PlaceholderStyle.build()
	var real: Theme = hud_theme
	if real == null and use_hud_theme_file and ResourceLoader.exists(HUD_THEME_PATH):
		real = load(HUD_THEME_PATH) as Theme
	if real != null:
		merged.merge_with(real)
	theme = merged


## Keeps the HUD clear of phone notches / home indicator (Xogot on iPhone, mobile web).
func _apply_safe_area() -> void:
	var margin_lt: Vector2 = BASE_MARGIN
	var margin_rb: Vector2 = BASE_MARGIN
	if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = get_viewport_rect().size / window
			margin_lt = margin_lt.max(safe.position * to_canvas)
			margin_rb = margin_rb.max((window - safe.end) * to_canvas)
	_safe_area.add_theme_constant_override(&"margin_left", int(margin_lt.x))
	_safe_area.add_theme_constant_override(&"margin_top", int(margin_lt.y))
	_safe_area.add_theme_constant_override(&"margin_right", int(margin_rb.x))
	_safe_area.add_theme_constant_override(&"margin_bottom", int(margin_rb.y))
