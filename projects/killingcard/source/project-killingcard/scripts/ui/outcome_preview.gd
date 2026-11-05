# outcome_preview.gd
# Purpose: Outcome preview overlay (p12), child "OutcomePreview" of scenes/Match.tscn. When on,
#   each lane gets a cyan forecast card over its header: the damage your side deals / takes in
#   that zone, eliminations both ways, and who holds the zone after the firefight:
#       DEAL 5 · TAKE 3          ENDS YOURS
#       KILLS 2 · LOST 1         +2 UNKNOWN
#   The numbers come from OutcomeForecast (the real rules engine on a copy of the match) and use
#   only what the player can see: their own plays and the board. Enemy red dots are never
#   simulated; the card says "+N UNKNOWN" for them (or "NO RED DOTS"), so a forecast is never
#   presented as certain. It recomputes on every redraw of the board (match_screen.gd
#   snapshot_shown: plays, undo, new round) and hides outside the player's open Deploy, while
#   the round plays and under the mulligan panel.
#   Toggle: the PREVIEW button in the top bar, or P (toggle_preview). Each change emits
#   EventBus.preview_toggled(enabled) (the playtest log records it, p16).
#   Display only: every Control here ignores the mouse, so taps reach the lanes underneath.
# Dependencies: OutcomeForecast, match_screen.gd (parent: get_board / get_preview_button /
#   snapshot_shown), match_controller.gd (sibling MatchController: state, is_busy,
#   is_mulligan_open, mulligan_done), EventBus, hud_theme.tres Preview* variations.
# Author: UI/UX Agent (p12)
extends Control

signal toggled(enabled: bool)

const CONTROL_WORDS: Dictionary = {
	&"player": "ENDS YOURS", &"enemy": "ENDS ENEMY", &"contested": "ENDS CONTESTED", &"empty": "ENDS OPEN",
}
const CONTROL_VARIATION: Dictionary = {
	&"player": &"PreviewFriend", &"enemy": &"PreviewEnemy", &"contested": &"PreviewContested", &"empty": &"PreviewQuiet",
}

## Preview on / off (the player's choice; it still hides outside Deploy).
var enabled: bool = false
## Last forecast shown (OutcomeForecast.forecast shape), for tests and QA.
var last_forecast: Dictionary = {}

var _screen: Control = null
var _controller: Node = null
var _button: Button = null
## Per lane: {card, damage, control, kills, unknown}.
var _cards: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen = get_parent() as Control
	if _screen == null or not _screen.has_method(&"get_board"):
		return
	_controller = _screen.get_node_or_null(^"MatchController")
	for i: int in 3:
		_cards.append(_make_card())
	if _screen.is_node_ready():
		_wire()
	else:
		_screen.ready.connect(_wire, CONNECT_ONE_SHOT)


func _wire() -> void:
	_screen.snapshot_shown.connect(func(_snap: Dictionary) -> void: refresh())
	if _controller != null and _controller.has_signal(&"mulligan_done"):
		_controller.mulligan_done.connect(func(_put_back: Array) -> void: refresh())
	if _screen.has_method(&"get_preview_button"):
		_button = _screen.get_preview_button()
		_button.toggle_mode = true
		_button.toggled.connect(set_enabled)
	for lane: Node in _screen.get_board().get_lanes():
		(lane as Control).item_rect_changed.connect(_place_cards)
	_sync_button()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_preview") and not event.is_echo():
		get_viewport().set_input_as_handled()
		set_enabled(not enabled)


## Turns the preview on / off (button, P key, tests). Emits toggled + EventBus.preview_toggled.
func set_enabled(value: bool) -> void:
	if value == enabled:
		_sync_button()
		return
	enabled = value
	_sync_button()
	refresh()
	toggled.emit(enabled)
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus != null:
		bus.preview_toggled.emit(enabled)


## Recomputes the forecast from the live match and redraws the cards (or hides them).
func refresh() -> void:
	var state: MatchState = _controller.get(&"state") if _controller != null else null
	var show_it: bool = enabled and state != null and not _controller.is_busy() and not _controller.is_mulligan_open()
	last_forecast = OutcomeForecast.forecast(state) if show_it else {}
	visible = show_it and bool(last_forecast.get("ok", false))
	if not visible:
		return
	var zones: Array = last_forecast["zones"]
	for z: int in mini(zones.size(), _cards.size()):
		_fill(_cards[z], zones[z])
	_place_cards()


## Text of one zone's card: [damage line, control line, kills line, unknown line] (also for tests).
static func card_lines(zone: Dictionary) -> PackedStringArray:
	var dealt: int = int(zone.get("dealt", 0))
	var taken: int = int(zone.get("taken", 0))
	var kills: int = int(zone.get("kills", 0))
	var losses: int = int(zone.get("losses", 0))
	var active: bool = bool(zone.get("fight", false)) or dealt + taken + kills + losses > 0
	var unknown: int = int(zone.get("unknown", 0))
	return PackedStringArray([
		"DEAL %d · TAKE %d" % [dealt, taken] if active else "NO FIREFIGHT",
		String(CONTROL_WORDS.get(zone.get("control", &"empty"), "ENDS OPEN")),
		"KILLS %d · LOST %d" % [kills, losses] if active else "NO LOSSES",
		"+%d UNKNOWN" % unknown if unknown > 0 else "NO RED DOTS",
	])


## The forecast card over each lane (for tests / QA): PanelContainers in lane order.
func get_cards() -> Array[Control]:
	var out: Array[Control] = []
	for c: Dictionary in _cards:
		out.append(c["card"])
	return out


## Labels whose whole text must stay visible (tests check size and clipping).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = []
	for c: Dictionary in _cards:
		for key: String in ["damage", "control", "kills", "unknown"]:
			out.append(c[key])
	return out


func _fill(c: Dictionary, zone: Dictionary) -> void:
	var lines: PackedStringArray = card_lines(zone)
	(c["damage"] as Label).text = lines[0]
	var ctl: Label = c["control"]
	ctl.text = lines[1]
	ctl.theme_type_variation = CONTROL_VARIATION.get(zone.get("control", &"empty"), &"PreviewQuiet")
	(c["kills"] as Label).text = lines[2]
	var unk: Label = c["unknown"]
	unk.text = lines[3]
	unk.theme_type_variation = &"PreviewUnknown" if int(zone.get("unknown", 0)) > 0 else &"PreviewQuiet"


## kc-board: each card sits over its column's objective tile (full column width, bottom aligned with
## the tile), growing up into the rival's half if it needs more height; your rows stay free.
func _place_cards() -> void:
	if _screen == null or not visible:
		return
	var lanes: Array[Node] = _screen.get_board().get_lanes()
	for i: int in mini(lanes.size(), _cards.size()):
		var tile: Control = lanes[i].get_objective_tile()
		var card: Control = _cards[i]["card"]
		var r: Rect2 = tile.get_global_rect()
		var to_local: Transform2D = get_global_transform().affine_inverse()
		var h: float = maxf(card.get_combined_minimum_size().y, r.size.y)
		card.size = Vector2(r.size.x, h)
		card.position = to_local * Vector2(r.position.x, r.end.y - h)


func _make_card() -> Dictionary:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"PreviewCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	# kc-board: a column is narrow (176 px on the phone), so the four values stack.
	var row1: Array = [_line(col, &"PreviewText"), _line(col, &"PreviewQuiet")]
	var row2: Array = [_line(col, &"PreviewText"), _line(col, &"PreviewQuiet")]
	add_child(card)
	return {"card": card, "damage": row1[0], "control": row1[1], "kills": row2[0], "unknown": row2[1]}


func _line(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _row(parent: Control, left_var: StringName, right_var: StringName) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left: Label = Label.new()
	left.theme_type_variation = left_var
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right: Label = Label.new()
	right.theme_type_variation = right_var
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	row.add_child(right)
	return [left, right]


func _sync_button() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(enabled)
	_button.text = "PREVIEW\nON" if enabled else "PREVIEW\nOFF"
	_button.tooltip_text = "Forecast each column from what you can see (P)"
