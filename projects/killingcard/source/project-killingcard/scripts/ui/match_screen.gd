# match_screen.gd
# Purpose: Match screen, layout v2 (kc-board2, board-layout-v2.md, approved). Landscape only:
#   - the ICON STRIP (left; right when mirrored): MENU, SCORE, OPERATOR, STREAK, RIVAL, PREVIEW and
#     DECK at the bottom. Each badge shows its key value; tap opens its flyout (ScoreBar, the
#     Operator panel's info or its killstreak tiles, the rival intel, deck counts), long-press /
#     right-click opens the rules (rail_inspected). While the Operator can deploy, the OPERATOR badge
#     is the Operator's handle (tap = select, drag = drag to a column) and glows.
#   - the BOARD at full height (3 columns x 4 rows per side; banners 228x57 on an 844x390 phone,
#     304x76 on a 1440x900 desktop). It never moves or resizes.
#   - the HAND TRAY (right; left when mirrored): the Supply row, then the hand grid and UNDO / READY
#     (OPEN, Deploy), or the firefight step header, the killfeed log, the HAND · n PEEK tab and
#     SPEED x2 (CLOSED: Reveal, Firefight, Score). PEEK shows the hand read-only outside Deploy.
#   - killfeed TOASTS at the top centre of the board (2 at most, 2.5 s, no input) + the tray log.
#   Settings.mirror_layout swaps the strip and the tray (left-handed players).
#   kc-ui3: the Operator is a card at the start of the hand grid (deploy it like any card; on the
#   board it reads ON BOARD / B · ROW 2, down it reads DOWN / NEXT ROUND); the OPERATOR badge is info
#   only (tap = its flyout). The KILLSTREAK tiles sit at the top of the tray (killstreak_row.gd):
#   always visible with their charge, amber glow + a one-time toast when one is ready, tap = use,
#   long-press = rules (item_inspected).
#   Filled from a snapshot Dictionary. No game rules here: match_controller.gd (child node
#   MatchController) owns the MatchState, turns input into intents and calls show_snapshot();
#   with autostart off (tests) the screen shows mock_match_data.gd.
#
# Look: the project theme (assets/ui/hud_theme.tres). Below COMPACT_HEIGHT (640) logical px the
#   compact (phone) profile is used.
# Dependencies: scenes in scenes/match/, screen_profile.gd, board_metrics.gd, strip_badge.gd,
#   mock_match_data.gd, Settings (mirror_layout).
# Author: UI/UX Agent (p08), Mechanics Developer Agent (kc-board layout, kc-board2 layout v2)
extends Control

signal ready_pressed
signal menu_pressed
signal undo_pressed
## After every show_snapshot() (p12: the outcome preview recomputes on it).
signal snapshot_shown(snapshot: Dictionary)
## Long-press / right-click on a strip badge or tray box: &"score", &"deck", &"intel", &"supply",
## &"streak", &"menu", &"preview", &"killfeed", &"hand_tab".
signal rail_inspected(key: StringName)
## The hand tray changed state (TRAY_OPEN / TRAY_CLOSED / TRAY_PEEK).
signal tray_state_changed(state: StringName)
## A strip flyout opened (its key) or closed (&"").
signal flyout_changed(key: StringName)
## kc-ui3: long-press / right-click on a killstreak tile (its loadout item id).
signal item_inspected(item_id: StringName)

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const KillfeedEntry: GDScript = preload("res://scripts/fx/killfeed_entry.gd")
const KillstreakRow: GDScript = preload("res://scripts/ui/killstreak_row.gd")
const TRAY_OPEN: StringName = &"open"
const TRAY_CLOSED: StringName = &"closed"
const TRAY_PEEK: StringName = &"peek"
## Side margins only: the strip and the tray keep their own top / bottom pads (BoardMetrics).
const BASE_MARGIN: Vector2 = Vector2(6, 0)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(6, 0)
const TOAST_SECONDS: float = 2.2
## Killfeed toasts: 2.5 s (feed_life 4 s x 0.625), 2 at most; the tray log keeps up to 8 lines.
const KILL_TOAST_LIFE: float = 0.625
const KILL_TOAST_LINES: int = 2
const LOG_LINES: int = 8
const TRAY_FADE: float = 0.2
const FLYOUT_W: float = 360.0
const FLYOUT_W_DESKTOP: float = 380.0
const ZONE_LETTERS: Dictionary = {&"left": "A", &"mid": "B", &"right": "C"}

## Fill the screen with the mock snapshot on _ready (off once p04 drives the match).
@export var use_mock_data: bool = true

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _layout: Control = %Layout
@onready var _strip: Control = %IconStrip
@onready var _menu_button: Button = %MenuButton
@onready var _preview_button: Button = %PreviewButton
@onready var _score_badge: Control = %ScoreBadge
@onready var _operator_badge: Control = %OperatorBadge
@onready var _streak_badge: Control = %StreakBadge
@onready var _rival_badge: Control = %RivalBadge
@onready var _deck_badge: Control = %DeckBadge
@onready var _board: Control = %Board
@onready var _toasts: Control = %KillfeedToasts
@onready var _peek_catcher: Control = %PeekCatcher
@onready var _tray: Control = %HandTray
@onready var _supply_box: PanelContainer = %SupplyCounter
@onready var _supply_value: Label = %SupplyValue
@onready var _supply_pips: HBoxContainer = %SupplyPips
@onready var _hand: Control = %HandArea
@onready var _feed_box: VBoxContainer = %FeedBox
@onready var _step_header: Label = %StepHeader
@onready var _killfeed: VBoxContainer = %KillfeedSlot
@onready var _killfeed_fx: Control = %Killfeed
@onready var _hand_tab: Button = %HandTab
@onready var _undo_button: Button = %UndoButton
@onready var _ready_button: Button = %ReadyButton
@onready var _speed_button: Button = %SpeedButton
@onready var _flyout: Control = %Flyout
@onready var _flyout_scrim: ColorRect = %FlyoutScrim
@onready var _flyout_panel: PanelContainer = %FlyoutPanel
@onready var _flyout_title: Label = %FlyoutTitle
@onready var _flyout_hint: Label = %FlyoutHint
@onready var _score_bar: Control = %ScoreBar
@onready var _operator_panel: Control = %OperatorPanel
@onready var _minimap: Control = %Minimap
@onready var _deck_box: PanelContainer = %DeckBox
@onready var _deck_value: Label = %DeckValue
@onready var _used_value: Label = %UsedValue
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _drag_layer: Control = %DragLayer
@onready var _inspector: Control = %Inspector
@onready var _fx: Control = %FeedbackDirector
@onready var _mulligan: Control = %MulliganPanel
@onready var _preview: Control = %OutcomePreview
@onready var _end_banner: Control = %MatchEndBanner
@onready var _pause_menu: Control = %PauseMenu

## True while the phone layout is active (logical height < ScreenProfile.COMPACT_HEIGHT).
var compact: bool = false
## Safe rect in canvas px (inside get_viewport_rect()); tests set it to simulate a notched
## phone. Empty = read DisplayServer.get_display_safe_area() on mobile.
var safe_area_override: Rect2 = Rect2()
## Mirror layout (tray left, strip right); follows Settings.mirror_layout unless a test sets it.
var mirror: bool = false
var _profile_set: bool = false
var _ghost: Control = null
var _toast_id: int = 0
## BoardMetrics of the current layout.
var metrics: Dictionary = {}
var _gestures: Array = []
var tray_state: StringName = TRAY_OPEN
var _deploy_open: bool = true
var _phase: String = ""
var _hand_count: int = 0
## Which flyout is open (&"" = none): &"score", &"operator", &"streak", &"rival", &"deck".
var flyout_key: StringName = &""
var _operator_can_deploy: bool = false
var _flyout_dragging: bool = false
var _streak_callout_shown: bool = false
## kc-ui3: the killstreak tiles at the top of the tray, and the killstreaks already announced ready.
var _ks_row: Control = null
var _ks_announced: Dictionary = {}
var _supply_stacked: bool = false
var _supply_stack: VBoxContainer = null


func _ready() -> void:
	# p14 combat feedback: the director finds unit slots by uid on the board; the score and streak
	# anchors are the strip badges (their flyouts are usually closed).
	_fx.locator = BoardFxLocator.new(_board)
	_fx.locator.anchors[&"score"] = _score_badge
	_fx.locator.anchors[&"streak"] = _streak_badge
	_fx.streak_arc = _operator_panel.get_streak_arc()
	# Killfeed: the director pushes toasts (over the board); each push is copied to the tray log.
	_toasts.centered = true
	_toasts.line_cap = KILL_TOAST_LINES
	_toasts.life_scale = KILL_TOAST_LIFE
	_toasts.mirror = _killfeed_fx
	_killfeed_fx.persistent = true
	_killfeed_fx.left_aligned = true
	_killfeed_fx.line_cap = LOG_LINES
	_fx.killfeed = _toasts
	if _fx.has_signal(&"event_started"):
		_fx.event_started.connect(_on_fx_event)
	if _fx.has_signal(&"sequence_started"):
		_fx.sequence_started.connect(func(_n: int) -> void: _apply_speed(true))
	if _fx.has_signal(&"sequence_finished"):
		_fx.sequence_finished.connect(func() -> void: _apply_speed(false))
	tree_exiting.connect(func() -> void: Engine.time_scale = 1.0)
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		mirror = bool(settings.get(&"mirror_layout"))
		settings.settings_changed.connect(_on_settings_changed)
	_ks_row = KillstreakRow.new()
	_ks_row.name = "KillstreakRow"
	_tray.add_child(_ks_row)
	_tray.move_child(_ks_row, _supply_box.get_index() + 1)
	_update_profile()
	resized.connect(_update_profile)
	_layout.resized.connect(_layout_regions)
	_setup_strip()
	_setup_tray()
	_setup_flyout()
	get_viewport().size_changed.connect(_apply_safe_area)
	_ready_button.pressed.connect(func() -> void: ready_pressed.emit())
	_menu_button.pressed.connect(func() -> void:
		close_flyout()
		menu_pressed.emit())
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
	_hand.set_operator(operator_card_entry(snapshot))
	_hand.set_hand(snapshot.get("hand", []))
	_ks_row.set_killstreaks(snapshot.get("killstreaks", []), int(snapshot.get("streak", 0)))
	_set_supply(int(snapshot.get("supply", 0)), int(snapshot.get("supply_max", 0)))
	_set_actions(snapshot)
	_set_badges(snapshot)
	_follow_phase(snapshot)
	snapshot_shown.emit(snapshot)


func get_hand() -> Control:
	return _hand


func get_operator_panel() -> Control:
	return _operator_panel


## The Operator's handle (QA, tests, the tutorial): kc-ui3 the Operator card in the hand tray (the
## OPERATOR badge when the tray hides the hand).
func get_operator_handle() -> Control:
	var card: Control = _hand.get_operator_card()
	return card if card != null and card.is_visible_in_tree() else _operator_badge


## kc-ui3: the killstreak tiles at the top of the tray.
func get_killstreak_row() -> Control:
	return _ks_row


## The tile of one killstreak (loadout item id), or null.
func get_killstreak_tile(item_id: StringName) -> Control:
	return _ks_row.get_tile(item_id) if _ks_row != null else null


## kc-ui3: shows what is selected outside the hand cards: the Operator card and the killstreak tile
## being targeted (match_controller.gd _show_selection()).
func show_selection_state(operator_selected: bool, item_id: StringName) -> void:
	_hand.set_operator_selected(operator_selected)
	_ks_row.set_selected(item_id)


## kc-ui3: the hand tray's Operator card from a snapshot ({} = no Operator). state: &"deploy" (it can
## be placed now), &"planned" (placed this Deploy), &"board", &"down" (off the board, not placeable),
## &"none"; status = the words on the card; active = a tap selects it (else a tap inspects).
static func operator_card_entry(snapshot: Dictionary) -> Dictionary:
	var op: Dictionary = snapshot.get("operator", {})
	if op.is_empty() or String(op.get("name", "")) in ["", "NO OPERATOR"]:
		return {}
	var open: bool = bool(snapshot.get("deploy_open", false)) and StringName(snapshot.get("result", &"")) == &""
	var e: Dictionary = op.duplicate()
	var on_board: bool = bool(op.get("on_board", String(op.get("zone", "OFF BOARD")) != "OFF BOARD"))
	var planned: String = String(op.get("planned_zone", ""))
	if bool(snapshot.get("operator_can_deploy", false)):
		e["state"] = &"deploy"
		e["status"] = "DEPLOY"
	elif planned != "":
		e["state"] = &"planned"
		e["status"] = "PLAN · %s" % planned
	elif on_board:
		e["state"] = &"board"
		var where: String = String(op.get("zone_label", ""))
		e["status"] = "ON BOARD\n%s · ROW %d" % [where, int(op.get("row", 1))] if where != "" else "ON BOARD"
	else:
		e["state"] = &"down"
		e["status"] = "DOWN\n%s" % ("NEXT ROUND" if bool(op.get("respawns", true)) else "NO RESPAWN")
	# Tap selects it in Deploy (place, or Rotate from the board); otherwise a tap shows its rules.
	e["active"] = open and e["state"] != &"down"
	e["draggable"] = e["active"]
	return e


## Strip badge by key: &"menu", &"score", &"operator", &"streak", &"rival", &"preview", &"deck".
func get_badge(key: StringName) -> Control:
	return {&"menu": _menu_button, &"score": _score_badge, &"operator": _operator_badge, &"streak": _streak_badge,
			&"rival": _rival_badge, &"preview": _preview_button, &"deck": _deck_badge}.get(key, null)


func get_inspector() -> Control:
	return _inspector


## p14 FeedbackDirector (plays the engine's events after READY).
func get_fx() -> Control:
	return _fx


## f02 Round 1 mulligan panel.
func get_mulligan_panel() -> Control:
	return _mulligan


## p12 outcome preview overlay (scenes/match/OutcomePreview.tscn) and its strip toggle.
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


func get_hand_tab() -> Button:
	return _hand_tab


func get_speed_button() -> Button:
	return _speed_button


func get_tray() -> Control:
	return _tray


## Short message over the board (refusal reasons, hints). Hides itself after TOAST_SECONDS.
func show_toast(text: String) -> void:
	_toast_id += 1
	var my_id: int = _toast_id
	_toast_label.text = text
	_toast.show()
	_toast.reset_size()
	# Centred over the board (not the whole screen: the tray is beside it).
	var board_r: Rect2 = _board.get_global_rect()
	var cx: float = board_r.get_center().x if board_r.has_area() else size.x * 0.5
	_toast.position.x = clampf(cx - _toast.size.x * 0.5, 0.0, maxf(0.0, size.x - _toast.size.x))
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if my_id == _toast_id:
			_toast.hide())


func get_toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


## A copy of `source` (a hand chip, or the Operator handle) that follows the pointer.
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
	# The tray's UNDO is too narrow for the play's name (the toast names it after undoing).
	_undo_button.text = "UNDO"
	_undo_button.tooltip_text = "Undo %s" % label if not label.is_empty() else ""


## The controls that must stay on screen and never overlap (used by tests and QA). The tray's
## controls depend on its state (OPEN: hand, UNDO, READY; otherwise the log, the tab, SPEED).
func get_key_controls() -> Dictionary:
	var out: Dictionary = {
		"menu": _menu_button, "score_bar": _score_badge, "operator_panel": _operator_badge,
		"streak": _streak_badge, "minimap": _rival_badge, "preview": _preview_button, "deck": _deck_badge,
		"board": _board, "supply": _supply_box,
	}
	if tray_state == TRAY_OPEN:
		out.merge({"hand": _hand, "undo": _undo_button, "ready": _ready_button})
		if not _ks_row.get_tiles().is_empty():
			out["killstreaks"] = _ks_row
	else:
		out.merge({"hand_tab": _hand_tab, "speed": _speed_button})
		if tray_state == TRAY_PEEK:
			out["hand"] = _hand
		else:
			out["killfeed"] = _feed_box
	return out


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
	# kc-ui3: the desktop tray (224 px) wraps each log line to two rows instead of cutting names.
	_killfeed_fx.two_line = not compact
	_supply_pips.add_theme_constant_override(&"separation", 3)
	_apply_safe_area()
	_layout_regions.call_deferred()


## Mirror layout on / off (Settings.mirror_layout, or a test).
func set_mirror(value: bool) -> void:
	if value == mirror:
		return
	mirror = value
	close_flyout()
	_layout_regions()


func _on_settings_changed() -> void:
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null:
		set_mirror(bool(settings.get(&"mirror_layout")))


## Places the strip, the board and the tray from BoardMetrics (board-layout-v2.md §2).
func _layout_regions() -> void:
	var area: Vector2 = _layout.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	metrics = BoardMetrics.compute(area, compact, mirror)
	var board_rect: Rect2 = metrics["board"]
	_board.position = board_rect.position
	_board.size = board_rect.size
	_board.set_metrics(metrics)
	# Icon strip.
	var strip: Rect2 = metrics["strip"]
	_strip.position = strip.position
	_strip.size = strip.size
	var rects: Array[Rect2] = BoardMetrics.badge_rects(metrics)
	var badges: Array[Control] = [_menu_button, _score_badge, _operator_badge, _streak_badge, _rival_badge, _preview_button, _deck_badge]
	for i: int in badges.size():
		badges[i].position = rects[i].position
		badges[i].size = rects[i].size
		badges[i].custom_minimum_size = rects[i].size
		badges[i].queue_redraw()
	# Killfeed toasts: top centre of the board, over the rival's back row.
	var tw: float = minf(board_rect.size.x - 16.0, 460.0)
	_toasts.position = Vector2(board_rect.position.x + (board_rect.size.x - tw) * 0.5, board_rect.position.y + 4.0)
	_toasts.size = Vector2(tw, KillfeedEntry.ROW_HEIGHT * KILL_TOAST_LINES + 2.0)
	# Tray.
	var tray: Rect2 = metrics["tray"]
	_tray.position = tray.position
	_tray.size = tray.size
	_peek_catcher.position = Vector2.ZERO
	_peek_catcher.size = area
	_layout_tray()


func _layout_tray() -> void:
	if metrics.is_empty():
		return
	var w: float = _tray.size.x
	var h: float = _tray.size.y
	var btn_h: float = metrics["btn_h"]
	var tab_h: float = metrics["tab_h"]
	_set_supply_stacked(bool(metrics.get("ks_inline", false)))
	_place(_supply_box, metrics.get("supply", Rect2(0, 0, w, metrics["supply_h"])))
	_place(_ks_row, metrics.get("ks", Rect2()))
	_fit_pips()
	var grid: Rect2 = metrics["grid"]
	_place(_hand, grid)
	_hand.set_card_size(metrics["card"], metrics["card_gap"], int(metrics["hand_cols"]), 1.0 if mirror else -1.0)
	var undo_w: float = roundf(w * 0.3)
	_place(_undo_button, Rect2(0, h - btn_h, undo_w, btn_h))
	_place(_ready_button, Rect2(undo_w + 8.0, h - btn_h, w - undo_w - 8.0, btn_h))
	_place(_speed_button, Rect2(0, h - btn_h, w, btn_h))
	var tab_y: float = h - btn_h - 8.0 - tab_h
	_place(_hand_tab, Rect2(0, tab_y, w, tab_h))
	var feed_top: float = float(metrics["supply_h"]) + 8.0
	_place(_feed_box, Rect2(0, feed_top, w, maxf(0.0, tab_y - 8.0 - feed_top)))


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


# =============================================================================
# Icon strip and flyouts
# =============================================================================

func _setup_strip() -> void:
	for pair: Array in [[_score_badge, &"score"], [_streak_badge, &"streak"], [_rival_badge, &"rival"], [_deck_badge, &"deck"]]:
		var b: Control = pair[0]
		var key: StringName = pair[1]
		b.tapped.connect(func() -> void: toggle_flyout(key))
		b.inspected.connect(func() -> void:
			close_flyout()
			rail_inspected.emit({&"rival": &"intel"}.get(key, key)))
	# OPERATOR: the Operator's handle while it can deploy, else its flyout.
	# kc-ui3: the OPERATOR badge is info only (tap = its flyout); the Operator deploys from its card
	# at the start of the hand tray, which forwards to the Operator panel's signals (the controller's).
	_operator_badge.tapped.connect(func() -> void: toggle_flyout(&"operator"))
	_operator_badge.inspected.connect(func() -> void:
		close_flyout()
		_operator_panel.operator_inspected.emit())
	_hand.operator_tapped.connect(func() -> void:
		close_flyout()
		_operator_panel.operator_tapped.emit())
	_hand.operator_inspected.connect(func() -> void: _operator_panel.operator_inspected.emit())
	_hand.operator_drag_started.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_started.emit(p))
	_hand.operator_drag_moved.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_moved.emit(p))
	_hand.operator_drag_ended.connect(func(p: Vector2) -> void: _operator_panel.operator_drag_ended.emit(p))
	# MENU and PREVIEW are real buttons; right-click / long-press opens their rules.
	_wire_button_inspect(_menu_button, &"menu")
	_wire_button_inspect(_preview_button, &"preview")
	_preview_button.set_meta(&"badge", true)
	_preview_button.pressed.connect(close_flyout)
	_add_glyph(_menu_button, &"menu")
	_add_glyph(_preview_button, &"eye")


## A long-press (touch) or right-click on a Button opens its rules instead of pressing it.
func _wire_button_inspect(b: Button, key: StringName) -> void:
	var state: Dictionary = {"id": 0, "fired": false}
	b.gui_input.connect(func(e: InputEvent) -> void:
		if not e is InputEventMouseButton:
			return
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			b.accept_event()
			rail_inspected.emit(key)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			state["id"] = int(state["id"]) + 1
			state["fired"] = false
			var my_id: int = state["id"]
			get_tree().create_timer(PressGesture.LONG_PRESS_S).timeout.connect(func() -> void:
				if int(state["id"]) == my_id and _is_held(b):
					state["fired"] = true
					rail_inspected.emit(key))
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			state["id"] = int(state["id"]) + 1
			if bool(state["fired"]):
				# The hold opened the rules: swallow the release so the button doesn't press.
				state["fired"] = false
				b.accept_event()
				if b.toggle_mode:
					b.set_pressed_no_signal(b.button_pressed))


func _is_held(b: Button) -> bool:
	return b.is_hovered() or b.get_global_rect().has_point(b.get_global_mouse_position())


## Small glyphs drawn on the MENU (three bars) and PREVIEW (an eye over ON / OFF) buttons.
func _add_glyph(b: Button, kind: StringName) -> void:
	var g: Control = Control.new()
	g.name = "Glyph"
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	g.draw.connect(func() -> void:
		var c: Color = b.get_theme_color(&"font_color")
		var s: float = 24.0
		var o: Vector2 = Vector2((b.size.x - s) * 0.5, (b.size.y - s) * 0.5 if kind == &"menu" else 6.0)
		if kind == &"menu":
			for i: int in 3:
				var y: float = o.y + 5.0 + i * 7.0
				g.draw_line(Vector2(o.x + 2.0, y), Vector2(o.x + s - 2.0, y), c, 2.6)
		else:
			var ctr: Vector2 = o + Vector2(s * 0.5, s * 0.5)
			var pts: PackedVector2Array = []
			for i: int in 25:
				var t: float = PI * i / 24.0
				pts.append(ctr + Vector2(-cos(t) * s * 0.48, -sin(t) * s * 0.3))
			for i: int in 25:
				var t: float = PI * i / 24.0
				pts.append(ctr + Vector2(cos(t) * s * 0.48, sin(t) * s * 0.3))
			g.draw_polyline(pts, c, 2.0)
			g.draw_circle(ctr, s * 0.14, c))
	b.resized.connect(func() -> void:
		g.size = b.size
		g.queue_redraw())


func _setup_flyout() -> void:
	_operator_panel.set_section(&"operator")
	_flyout_scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_flyout_scrim.accept_event()
			close_flyout())
	for sig: StringName in [&"ability_pressed", &"killstreak_pressed"]:
		_operator_panel.connect(sig, func(_id: StringName) -> void: close_flyout.call_deferred())
	_operator_panel.operator_tapped.connect(func() -> void: close_flyout.call_deferred())
	_operator_panel.operator_inspected.connect(close_flyout)
	# Dragging the Operator out of its flyout: the flyout fades but keeps the gesture alive.
	_operator_panel.operator_drag_started.connect(func(_p: Vector2) -> void:
		if flyout_key != &"":
			_flyout_dragging = true
			_flyout.modulate.a = 0.0
			_flyout_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	_operator_panel.operator_drag_ended.connect(func(_p: Vector2) -> void:
		if _flyout_dragging:
			close_flyout.call_deferred())
	for box: Array in [[_score_bar, &"score"], [_deck_box, &"deck"], [_minimap, &"intel"]]:
		_wire_box(box[0], box[1])


func toggle_flyout(key: StringName) -> void:
	if flyout_key == key:
		close_flyout()
	else:
		open_flyout(key)


## Opens a badge's flyout next to it: &"score", &"operator", &"streak", &"rival", &"deck".
func open_flyout(key: StringName) -> void:
	var badge: Control = get_badge(key)
	if badge == null:
		return
	flyout_key = key
	_flyout_dragging = false
	_flyout.modulate.a = 1.0
	_flyout_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_score_bar.visible = key == &"score"
	_operator_panel.visible = key == &"operator" or key == &"streak"
	if _operator_panel.visible:
		_operator_panel.set_section(key)
	_minimap.visible = key == &"rival"
	_deck_box.visible = key == &"deck"
	_flyout_title.text = {&"score": "SCORE", &"operator": "OPERATOR", &"streak": "KILLSTREAKS", &"rival": "RIVAL HAND",
			&"deck": "DECK"}[key]
	_flyout_hint.text = {
		&"operator": "Tap the Operator here to select it, then a column · long-press for rules",
		&"streak": "Tap a ready streak to arm it · long-press for rules",
	}.get(key, "Long-press for the rules · tap outside to close")
	var w: float = FLYOUT_W if compact else FLYOUT_W_DESKTOP
	_flyout_hint.custom_minimum_size.x = w - 24.0
	_flyout.show()
	_flyout_panel.reset_size()
	_flyout_panel.size.x = maxf(w, _flyout_panel.get_combined_minimum_size().x)
	_place_flyout.call_deferred(badge)


func _place_flyout(badge: Control) -> void:
	if not _flyout.visible:
		return
	_flyout_panel.reset_size()
	var w: float = maxf(FLYOUT_W if compact else FLYOUT_W_DESKTOP, _flyout_panel.size.x)
	_flyout_panel.size.x = w
	var br: Rect2 = badge.get_global_rect()
	var local: Rect2 = Rect2(_flyout.get_global_transform().affine_inverse() * br.position, br.size)
	var x: float = local.end.x + 8.0 if not mirror else local.position.x - 8.0 - w
	var y: float = clampf(local.position.y, 4.0, maxf(4.0, _flyout.size.y - _flyout_panel.size.y - 4.0))
	_flyout_panel.position = Vector2(clampf(x, 0.0, maxf(0.0, _flyout.size.x - w)), y)
	flyout_changed.emit(flyout_key)


func close_flyout() -> void:
	var was: StringName = flyout_key
	flyout_key = &""
	_flyout_dragging = false
	if _flyout != null:
		_flyout.hide()
		_flyout.modulate.a = 1.0
	if was != &"":
		flyout_changed.emit(&"")


func is_flyout_open() -> bool:
	return _flyout.visible and flyout_key != &""


func _set_badges(snapshot: Dictionary) -> void:
	var text_c: Color = get_theme_color(&"text", &"Hud")
	var muted: Color = Color("#9AA5AE")
	var friend: Color = get_theme_color(&"friend", &"Hud")
	var enemy: Color = get_theme_color(&"enemy", &"Hud")
	_score_badge.set_value([[["R%d" % int(snapshot.get("round", 1)), muted]],
			[[str(int(snapshot.get("score_player", 0))), friend], ["-", muted], [str(int(snapshot.get("score_enemy", 0))), enemy]]])
	var op: Dictionary = snapshot.get("operator", {})
	_operator_can_deploy = bool(snapshot.get("operator_can_deploy", false))
	var op_text: String = "OFF"
	if _operator_can_deploy:
		op_text = "DEPLOY"
	elif op.has("armor") and String(op.get("zone", "OFF BOARD")) != "OFF BOARD":
		op_text = "%d/%d" % [int(op.get("armor", 0)), int(op.get("armor_max", 0))]
	_operator_badge.font_size = 20
	_operator_badge.set_value([[[op_text, text_c]]], false)
	_operator_badge.set_drag_enabled(false)
	var ready_ks: bool = false
	for ks: Dictionary in snapshot.get("killstreaks", []):
		ready_ks = ready_ks or (bool(ks.get("earned", false)) and bool(ks.get("ready", false)))
	_streak_badge.set_value([[[str(int(snapshot.get("streak", 0))), text_c]]], ready_ks)
	# kc-ui3: a one-time toast when each killstreak first becomes ready (its tile glows in the tray).
	if bool(snapshot.get("deploy_open", false)):
		for ks: Dictionary in snapshot.get("killstreaks", []):
			var id: StringName = StringName(ks.get("id", &""))
			if KillstreakRow.is_ready(ks) and not _ks_announced.has(id):
				_ks_announced[id] = true
				_streak_callout_shown = true
				show_toast.call_deferred("%s ready: tap it at the top of your hand" % String(ks.get("full_name", ks.get("name", "A killstreak"))))
	_rival_badge.set_value([[[str(int(snapshot.get("enemy_hand", 0))), Color("#ffb3b5")]]])
	_deck_badge.set_value([[[str(int(snapshot.get("deck_count", 0))), text_c]]])


## Long-press / right-click on a flyout or tray box opens its explanation (studio rule).
func _wire_box(box: Control, key: StringName) -> void:
	var g: RefCounted = PressGesture.new(box)
	g.drag_enabled = false
	_gestures.append(g)
	if box.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			box.accept_event())
	g.long_pressed.connect(func(_p: Vector2) -> void:
		close_flyout()
		rail_inspected.emit(key))


# =============================================================================
# Hand tray
# =============================================================================

func _setup_tray() -> void:
	_wire_box(_supply_box, &"supply")
	# kc-ui3: killstreak tiles: tap = use (the controller selects / calls it in), long-press = rules.
	_ks_row.killstreak_tapped.connect(func(id: StringName) -> void:
		close_flyout()
		_operator_panel.killstreak_pressed.emit(id))
	_ks_row.killstreak_inspected.connect(func(id: StringName) -> void:
		close_flyout()
		item_inspected.emit(id))
	_feed_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_wire_box(_feed_box, &"killfeed")
	_hand_tab.pressed.connect(func() -> void:
		set_tray_state(TRAY_CLOSED if tray_state == TRAY_PEEK else TRAY_PEEK))
	_wire_button_inspect(_hand_tab, &"hand_tab")
	_peek_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_peek_catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_peek_catcher.accept_event()
			set_tray_state(TRAY_CLOSED))
	_speed_button.toggled.connect(func(on: bool) -> void:
		_speed_button.text = "SPEED x2" if on else "SPEED x1"
		var st: Node = get_node_or_null(^"/root/Settings")
		if st != null and bool(st.get(&"speed_x2")) != on:
			st.set_value(&"speed_x2", on)
		_apply_speed(_fx.is_playing() if _fx.has_method(&"is_playing") else false))
	# kc-ui3: SPEED x2 is kept between sessions (Settings.speed_x2).
	var settings: Node = get_node_or_null(^"/root/Settings")
	var fast: bool = settings != null and bool(settings.get(&"speed_x2"))
	_speed_button.set_pressed_no_signal(fast)
	_speed_button.text = "SPEED x2" if fast else "SPEED x1"
	_apply_tray_state(false)


## OPEN at the start of Deploy, CLOSED when READY is pressed (Reveal, Firefight, Score); a PEEK
## closes when the next step starts.
func _follow_phase(snapshot: Dictionary) -> void:
	var open: bool = bool(snapshot.get("deploy_open", true)) and StringName(snapshot.get("result", &"")) == &""
	var phase: String = String(snapshot.get("phase", ""))
	var cards: int = (snapshot.get("hand", []) as Array).size()
	_hand_count = cards
	if open:
		set_tray_state(TRAY_OPEN)
	elif tray_state == TRAY_OPEN or (tray_state == TRAY_PEEK and phase != _phase):
		set_tray_state(TRAY_CLOSED)
	if not open and (phase != _phase or _deploy_open):
		_step_header.text = phase if phase != "" else "FIREFIGHT"
	if open and not _deploy_open:
		_killfeed_fx.clear()
	_deploy_open = open
	_phase = phase
	_update_tab_text()


func set_tray_state(value: StringName) -> void:
	if value == tray_state:
		return
	tray_state = value
	_apply_tray_state(true)
	tray_state_changed.emit(value)


func _apply_tray_state(animate: bool) -> void:
	var open: bool = tray_state == TRAY_OPEN
	var peek: bool = tray_state == TRAY_PEEK
	_hand.visible = open or peek
	_hand.set_read_only(peek)
	_undo_button.visible = open
	_ready_button.visible = open
	_feed_box.visible = tray_state == TRAY_CLOSED
	_hand_tab.visible = not open
	_speed_button.visible = not open
	_peek_catcher.visible = peek
	_update_tab_text()
	if animate and not _reduced_motion():
		# 200 ms cross-fade, plus a 160 ms slide on the cards (board-layout-v2.md §4.1).
		for c: Control in [_hand, _feed_box]:
			if c.visible:
				c.modulate.a = 0.0
				var tw: Tween = c.create_tween()
				tw.tween_property(c, "modulate:a", 1.0, TRAY_FADE)
		if _hand.visible and not metrics.is_empty():
			var to_x: float = (metrics["grid"] as Rect2).position.x
			_hand.position.x = to_x + (-24.0 if mirror else 24.0)
			_hand.create_tween().tween_property(_hand, "position:x", to_x, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_tab_text() -> void:
	_hand_tab.text = "HAND · %d   %s" % [_hand_count, "CLOSE" if tray_state == TRAY_PEEK else "PEEK"]


func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.get(&"reduced_motion"))


## SPEED x2: the round's feedback plays at double speed while it runs.
func _apply_speed(playing: bool) -> void:
	Engine.time_scale = 2.0 if playing and _speed_button.button_pressed else 1.0


## The tray header names the firefight step as it plays (FIREFIGHT · B · FIRST SHOT).
func _on_fx_event(ev: Dictionary) -> void:
	var t: StringName = ev.get("type", &"")
	if t == RulesEvent.FIREFIGHT_STARTED:
		_step_header.text = "FIREFIGHT · %s" % ZONE_LETTERS.get(StringName(ev.get("zone", &"")), "")
	elif t == RulesEvent.FIREFIGHT_STEP:
		var step: String = {&"first_shot": "FIRST SHOT", &"main": "MAIN STEP"}.get(StringName(ev.get("step", &"")), "")
		_step_header.text = "FIREFIGHT · %s · %s" % [ZONE_LETTERS.get(StringName(ev.get("zone", &"")), ""), step]
	elif t == RulesEvent.PHASE_CHANGED:
		var ph: String = String(ev.get("phase", "")).to_upper()
		if ph != "" and ph != "FIREFIGHT":
			_step_header.text = ph


## The killfeed log in the tray (tests: lines must fit it).
func get_killfeed() -> Control:
	return _killfeed_fx


## The killfeed toasts over the board.
func get_killfeed_toasts() -> Control:
	return _toasts


## Where the killfeed log draws, in global (canvas) coordinates.
func get_killfeed_rect() -> Rect2:
	return _killfeed_fx.get_global_rect()


## Supply pips: as wide as the tray's Supply row allows for the current Supply (6..14 px).
func _pip_size() -> Vector2:
	var n: int = maxi(1, _supply_pips.get_child_count())
	var box_w: float = _supply_box.size.x if _supply_box != null and _supply_box.size.x > 0.0 else 300.0
	# kc-ui3: stacked (pips under SUPPLY 3/4) the pips get the whole row; in one row, what the words leave.
	var room: float = box_w - (28.0 if _supply_stacked else 150.0)
	var w: float = clampf(floorf(room / n) - 3.0, 6.0, 14.0)
	return Vector2(w, 18 if compact else 20)


func _set_supply(supply: int, supply_max: int) -> void:
	_supply_value.text = "%d/%d" % [supply, supply_max]
	for child: Node in _supply_pips.get_children():
		_supply_pips.remove_child(child)
		child.queue_free()
	for i: int in supply_max:
		var pip: Panel = Panel.new()
		pip.theme_type_variation = &"SupplyPip" if i < supply else &"SupplyPipSpent"
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_supply_pips.add_child(pip)
	_fit_pips()


## kc-ui3: when the killstreak tiles share the Supply row (phone), the pips go under SUPPLY 3/4.
func _set_supply_stacked(on: bool) -> void:
	if on == _supply_stacked:
		return
	_supply_stacked = on
	var row: HBoxContainer = _supply_pips.get_parent() as HBoxContainer if not on else _supply_value.get_parent() as HBoxContainer
	if on:
		if _supply_stack == null:
			_supply_stack = VBoxContainer.new()
			_supply_stack.name = "SupplyStack"
			_supply_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_supply_stack.alignment = BoxContainer.ALIGNMENT_CENTER
			_supply_stack.add_theme_constant_override(&"separation", 4)
		_supply_box.remove_child(row)
		_supply_box.add_child(_supply_stack)
		_supply_stack.add_child(row)
		row.remove_child(_supply_pips)
		_supply_stack.add_child(_supply_pips)
		_supply_pips.size_flags_horizontal = Control.SIZE_FILL
	else:
		_supply_stack.remove_child(_supply_pips)
		row = _supply_stack.get_child(0) as HBoxContainer
		row.add_child(_supply_pips)
		row.move_child(_supply_pips, 1)
		_supply_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_supply_stack.remove_child(row)
		_supply_box.remove_child(_supply_stack)
		_supply_box.add_child(row)
	# Stacked: SUPPLY on the left, the value on the right of the top line.
	var caption: Control = row.get_child(0) as Control
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL


func _fit_pips() -> void:
	for pip: Node in _supply_pips.get_children():
		(pip as Control).custom_minimum_size = _pip_size()


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
