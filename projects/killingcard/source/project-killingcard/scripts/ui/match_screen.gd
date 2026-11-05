# match_screen.gd
# Purpose: Match screen. kc-board layout (board-and-cards-ux.md §2): a left rail (score, Operator
#   panel with its loadout / killstreak buttons, deck counts), the board of 3 vertical columns
#   (A / B / C, the rival above the objectives, you below) with the hand under it, and a right
#   rail (UNDO, MENU, PREVIEW, rival hand + intel, killfeed, Supply, READY). The board, hand and
#   rails are placed from BoardMetrics (banners 176x44 on an 844x390 phone, 256x64 on a 1440x900
#   desktop), filled from a snapshot Dictionary. No game rules here: match_controller.gd (child node
#   MatchController, p09) owns the MatchState, turns input into intents and calls show_snapshot();
#   with autostart off (tests) the screen shows mock_match_data.gd.
#   Buttons only emit signals. View helpers: column target states, the selected card / Operator,
#   a drag ghost, a short toast for refusals and hints, and the card inspector. Rail boxes (score,
#   deck, rival hand, Supply) are inspectable too (long-press / right-click: rail_inspected).
#
# Look: the project theme (assets/ui/hud_theme.tres, set in project.godot gui/theme/custom).
#   Below COMPACT_HEIGHT (640) logical px the compact (phone) profile is used.
# Dependencies: scenes in scenes/match/, screen_profile.gd, board_metrics.gd, mock_match_data.gd.
# Author: UI/UX Agent (p08), Mechanics Developer Agent (kc-board layout)
extends Control

signal ready_pressed
signal menu_pressed
signal undo_pressed
## After every show_snapshot() (p12: the outcome preview recomputes on it).
signal snapshot_shown(snapshot: Dictionary)
## Long-press / right-click on a rail box: &"score", &"deck", &"intel", &"supply".
signal rail_inspected(key: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const KillfeedEntry: GDScript = preload("res://scripts/fx/killfeed_entry.gd")
## Side margins only: the board's own top gap and the hand row reach the canvas edges (§2).
const BASE_MARGIN: Vector2 = Vector2(12, 0)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(12, 0)
## Rails keep this much air at the top and bottom of the canvas.
const RAIL_PAD: float = 8.0
const KILLFEED_LINES: int = 3
const TOAST_SECONDS: float = 2.2

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
@onready var _layout: Control = %Layout
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _left_rail: VBoxContainer = %LeftRail
@onready var _right_rail: VBoxContainer = %RightRail
@onready var _deck_box: PanelContainer = %DeckBox
@onready var _deck_value: Label = %DeckValue
@onready var _used_value: Label = %UsedValue
@onready var _undo_button: Button = %UndoButton
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _drag_layer: Control = %DragLayer
@onready var _inspector: Control = %Inspector
@onready var _fx: Control = %FeedbackDirector
@onready var _killfeed_fx: Control = %Killfeed
@onready var _mulligan: Control = %MulliganPanel
@onready var _preview_button: Button = %PreviewButton
@onready var _preview: Control = %OutcomePreview
@onready var _end_banner: Control = %MatchEndBanner
@onready var _pause_menu: Control = %PauseMenu

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## Safe rect in canvas px (inside get_viewport_rect()); tests set it to simulate a notched
## phone. Empty = read DisplayServer.get_display_safe_area() on mobile.
var safe_area_override: Rect2 = Rect2()
var _profile_set: bool = false
var _ghost: Control = null
var _toast_id: int = 0
## BoardMetrics of the current layout.
var metrics: Dictionary = {}
var _rail_gestures: Array = []


func _ready() -> void:
	# p14 combat feedback (documentation/production/p14-fx-wiring.md): the director finds unit
	# slots by uid on the board, the killfeed and the streak arc live in the HUD.
	_fx.locator = BoardFxLocator.new(_board)
	_fx.locator.anchors[&"score"] = _score_bar
	_fx.locator.anchors[&"streak"] = _operator_panel
	_fx.killfeed = _killfeed_fx
	_fx.streak_arc = _operator_panel.get_streak_arc()
	_update_profile()
	resized.connect(_update_profile)
	_layout.resized.connect(_layout_regions)
	for pair: Array in [[&"score", _score_bar], [&"deck", _deck_box], [&"intel", _minimap], [&"supply", %SupplyCounter]]:
		_wire_rail_box(pair[1], pair[0])
	get_viewport().size_changed.connect(_apply_safe_area)
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_undo_button.pressed.connect(func() -> void: undo_pressed.emit())
	if use_mock_data:
		show_snapshot(MockMatchData.round_3_sample())


## Renders a full match snapshot (shape: mock_match_data.gd).
func show_snapshot(snapshot: Dictionary) -> void:
	_score_bar.set_score(snapshot)
	_minimap.set_intel(snapshot.get("lanes", []))
	_board.set_lanes(snapshot.get("lanes", []))
	_operator_panel.set_operator(snapshot)
	_minimap.set_rival_hand(int(snapshot.get("enemy_hand", 0)))
	_deck_value.text = str(int(snapshot.get("deck_count", 0)))
	_used_value.text = str(int(snapshot.get("discard_count", 0)))
	_hand.set_hand(snapshot.get("hand", []))
	_set_supply(int(snapshot.get("supply", 0)), int(snapshot.get("supply_max", 0)))
	_set_killfeed(snapshot.get("killfeed", []))
	_set_actions(snapshot)
	snapshot_shown.emit(snapshot)


func get_hand() -> Control:
	return _hand


func get_operator_panel() -> Control:
	return _operator_panel


func get_inspector() -> Control:
	return _inspector


## p14 FeedbackDirector (plays the engine's events after READY).
func get_fx() -> Control:
	return _fx


## f02 Round 1 mulligan panel.
func get_mulligan_panel() -> Control:
	return _mulligan


## p12 outcome preview overlay (scenes/match/OutcomePreview.tscn) and its top-bar toggle.
func get_preview() -> Control:
	return _preview


func get_preview_button() -> Button:
	return _preview_button


## f03 match result banner (scenes/match/MatchEndBanner.tscn).
func get_end_banner() -> Control:
	return _end_banner


## f03 pause sheet opened by MENU (scenes/match/PauseMenu.tscn).
func get_pause_menu() -> Control:
	return _pause_menu


func get_menu_button() -> Button:
	return _menu_button


func get_undo_button() -> Button:
	return _undo_button


func get_ready_button() -> Button:
	return _ready_button


## Short message over the board (refusal reasons, hints). Hides itself after TOAST_SECONDS.
func show_toast(text: String) -> void:
	_toast_id += 1
	var my_id: int = _toast_id
	_toast_label.text = text
	_toast.show()
	_toast.reset_size()
	_toast.position.x = (size.x - _toast.size.x) * 0.5
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if my_id == _toast_id:
			_toast.hide())


func get_toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


## A copy of `source` (a hand chip, or the Operator panel's name) that follows the pointer.
func begin_drag_ghost(source: Control, pos: Vector2) -> void:
	end_drag_ghost()
	var ghost: Control = source.duplicate(0) as Control
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: Node in ghost.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0.9)
	ghost.size = source.size
	_drag_layer.add_child(ghost)
	_ghost = ghost
	move_drag_ghost(pos)


func move_drag_ghost(pos: Vector2) -> void:
	if _ghost != null:
		# Centred on the finger, a little above it so the finger doesn't hide the card.
		_ghost.position = pos - Vector2(_ghost.size.x * 0.5, _ghost.size.y * 0.8)


func end_drag_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


func has_drag_ghost() -> bool:
	return _ghost != null


func _set_actions(snapshot: Dictionary) -> void:
	var open: bool = bool(snapshot.get("deploy_open", true))
	_ready_button.disabled = not open
	var result: StringName = snapshot.get("result", &"")
	if result != &"":
		_ready_button.text = {&"player": "WON", &"enemy": "LOST"}.get(result, "DRAW")
	else:
		_ready_button.text = "READY" if open else "WAIT"
	_undo_button.disabled = not bool(snapshot.get("can_undo", false))
	var label: String = String(snapshot.get("undo_label", ""))
	# The phone's UNDO is too narrow for the play's name (the toast names it after undoing).
	_undo_button.text = "UNDO" if compact or _undo_button.disabled or label.is_empty() else "UNDO\n%s" % label
	_undo_button.tooltip_text = "Undo %s" % label if not label.is_empty() else ""


## The controls that must stay on screen and never overlap (used by tests and QA).
func get_key_controls() -> Dictionary:
	return {
		"menu": _menu_button, "score_bar": _score_bar, "minimap": _minimap,
		"killfeed": _killfeed, "board": _board, "operator_panel": _operator_panel,
		"hand": _hand, "supply": %SupplyCounter, "undo": _undo_button, "ready": _ready_button,
		"preview": _preview_button, "deck": _deck_box,
	}


func get_board() -> Control:
	return _board


## Labels whose whole text must stay on screen (no clipping or ellipsis), for tests and QA.
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_supply_value, _deck_value, _used_value]
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
	_board.set_compact(compact)
	_operator_panel.set_compact(compact)
	_hand.set_compact(compact)
	_minimap.set_compact(compact)
	_mulligan.set_compact(compact)
	_end_banner.set_compact(compact)
	_pause_menu.set_compact(compact)
	_supply_pips.add_theme_constant_override(&"separation", 2 if compact else 4)
	for pip: Node in _supply_pips.get_children():
		(pip as Control).custom_minimum_size = _pip_size()
	_apply_safe_area()
	_layout_regions.call_deferred()


## Places the rails, the board and the hand from BoardMetrics (§2) inside the safe area.
func _layout_regions() -> void:
	var area: Vector2 = _layout.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	metrics = BoardMetrics.compute(area, compact)
	var board_rect: Rect2 = metrics["board"]
	_board.position = board_rect.position
	_board.size = board_rect.size
	_board.set_metrics(metrics)
	var hand_rect: Rect2 = metrics["hand"]
	_hand.position = hand_rect.position
	_hand.size = hand_rect.size
	_hand.set_card_size(metrics["card"], metrics["card_gap"])
	for pair: Array in [[_left_rail, metrics["left"]], [_right_rail, metrics["right"]]]:
		var rail: Control = pair[0]
		var r: Rect2 = pair[1]
		rail.position = Vector2(r.position.x, r.position.y + RAIL_PAD)
		rail.size = Vector2(r.size.x, r.size.y - 2.0 * RAIL_PAD)
	_operator_panel.fit_rail_width((metrics["left"] as Rect2).size.x)
	_killfeed_fx.custom_minimum_size = Vector2(0, KillfeedEntry.ROW_HEIGHT * (2 if compact else 3))


## The killfeed lines' node (tests: p18-005 lines must fit it at 844x390).
func get_killfeed() -> Control:
	return _killfeed_fx


## Where the killfeed draws, in global (canvas) coordinates (its right-rail slot).
func get_killfeed_rect() -> Rect2:
	return _killfeed_fx.get_global_rect()


## Long-press / right-click on a rail box opens its explanation (studio rule: inspect anything).
func _wire_rail_box(box: Control, key: StringName) -> void:
	var g: RefCounted = PressGesture.new(box)
	g.drag_enabled = false
	_rail_gestures.append(g)
	if box.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			box.accept_event())
	g.long_pressed.connect(func(_p: Vector2) -> void: rail_inspected.emit(key))


## Supply pips: narrower on the phone so a 10-Supply bar fits the 140 px action column.
func _pip_size() -> Vector2:
	return Vector2(10, 16) if compact else Vector2(18, 20)


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


## p14: the Killfeed (scenes/fx/Killfeed.tscn in %KillfeedSlot) is fed by FeedbackDirector as
## eliminations play, so the snapshot's killfeed list is no longer drawn here.
func _set_killfeed(_lines: Array) -> void:
	pass


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
	_inspector.set_safe_margins(margin_lt, margin_rb)
