# board.gd
# Purpose: The match board (kc-board): three vertical columns A / B / C in map order (zones Left,
#   Mid, Right), each a Lane (lane.gd) with the rival's rows above the objective and yours below.
#   The match screen gives it BoardMetrics (banner size, gutters); the board places the columns.
#   Layout + display of a snapshot; forwards the columns' taps / long-presses with the zone index
#   (0 = A / left, 1 = B / mid, 2 = C / right, RulesIntent order).
# Dependencies: lane.gd, board_metrics.gd.
# Author: UI/UX Agent (p08), Mechanics Developer Agent (kc-board: columns)
extends Control

## slot_side / uid: the unit slot that was hit (&"" / -1 for empty space or an empty slot).
signal lane_tapped(zone: int, slot_side: StringName, uid: int)
signal lane_long_pressed(zone: int, slot_side: StringName, uid: int)
## kc-cards-impl (H1): a tap on the board outside the columns (cancels a selected card).
signal empty_tapped
## kc-loadout-clean: a movable unit of yours is dragged (Lane.unit_drag_*; canvas positions).
signal unit_drag_started(zone: int, uid: int, pos: Vector2)
signal unit_drag_moved(pos: Vector2)
signal unit_drag_ended(pos: Vector2)

@onready var _lanes: Array[Node] = [%LaneLeft, %LaneMid, %LaneRight]
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")


var metrics: Dictionary = {}
## Desktop hover zoom (board-and-cards-ux.md §3.7): the banner at 2x after 120 ms (kc-board2: 608 px
## wide for the 304 px desktop banner).
const HOVER_DELAY: float = 0.12
const ZOOM_SIZE: Vector2 = Vector2(512, 128)
var _zoom_size: Vector2 = ZOOM_SIZE
var hover_zoom_enabled: bool = true
var _zoom: BannerView = null
var _zoom_label: Label = null
var _hover_slot: Node = null
var _hover_id: int = 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (event as InputEventMouseButton).pressed:
		empty_tapped.emit()


func _ready() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		mouse_filter = Control.MOUSE_FILTER_PASS
	for i: int in _lanes.size():
		var zone: int = i
		_lanes[i].tapped.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			lane_tapped.emit(zone, slot_side, uid))
		_lanes[i].long_pressed.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			_hover_id += 1  # cancels a pending zoom
			_hide_zoom()
			lane_long_pressed.emit(zone, slot_side, uid))
		_lanes[i].hovered.connect(_on_hovered)
		_lanes[i].unit_drag_started.connect(func(_id: StringName, uid: int, pos: Vector2) -> void:
			_hover_id += 1
			_hide_zoom()
			unit_drag_started.emit(zone, uid, pos))
		_lanes[i].unit_drag_moved.connect(func(pos: Vector2) -> void: unit_drag_moved.emit(pos))
		_lanes[i].unit_drag_ended.connect(func(pos: Vector2) -> void: unit_drag_ended.emit(pos))
	_zoom = BannerView.new()
	_zoom.name = "HoverZoom"
	_zoom.dim_back = false
	_zoom.full_info = true  # kc-cards-impl: the zoom is a peek (cost, level, weapon)
	_zoom.z_index = 20
	_zoom.visible = false
	add_child(_zoom)
	_zoom_label = Label.new()
	_zoom_label.theme_type_variation = &"TargetText"
	_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_label.z_index = 20
	_zoom_label.visible = false
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.06, 0.07, 0.92)
	plate.set_content_margin_all(4)
	_zoom_label.add_theme_stylebox_override(&"normal", plate)
	add_child(_zoom_label)
	set_process(false)


# kc-pos-cut (the head: "remove the position based effect"): units no longer link, so the board
# draws no link ticks (kc-syn-ui's tick layer, ghost ticks and their API are gone).


## Desktop only (mouse; touch has no hover): show the hovered banner zoomed after HOVER_DELAY.
func _on_hovered(slot: Node) -> void:
	_hover_slot = slot
	_hover_id += 1
	var my_id: int = _hover_id
	if slot == null or not hover_zoom_enabled or bool(metrics.get("compact", metrics.get("bh", 64.0) < 56.0)):
		_hide_zoom()
		return
	var ws: WeakRef = weakref(slot)  # kc-clarity: the slot may be freed before the timer fires
	get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void:
		var sl: Node = ws.get_ref() as Node
		if my_id == _hover_id and sl != null and sl == _hover_slot:
			_show_zoom(sl))


func _show_zoom(slot: Node) -> void:
	# Only while the pointer is really on that column (not under the inspector or a menu).
	var lane: Node = slot.get_parent().get_parent()
	if get_viewport().gui_get_hovered_control() != lane:
		return
	var r: Rect2 = (slot as Control).get_global_rect()
	_zoom_size = Vector2(maxf(ZOOM_SIZE.x, r.size.x * 2.0), maxf(ZOOM_SIZE.y, r.size.y * 2.0))
	var local: Vector2 = get_global_transform().affine_inverse() * r.get_center()
	_zoom.size = _zoom_size
	_zoom.show_unit(slot.entry, slot.side, slot.row == 0)
	# Grow in place, over the objective side, kept inside the board.
	var pos: Vector2 = local - _zoom_size * 0.5
	pos.y += (_zoom_size.y - r.size.y) * 0.5 * (1.0 if slot.side == &"enemy" else -1.0)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - _zoom_size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, size.y - _zoom_size.y))
	_zoom.position = pos
	var zoom_name: String = String(slot.entry.get("name", ""))
	if String(slot.entry.get("subname", "")) != "":
		zoom_name += " · %s" % String(slot.entry["subname"])
	_zoom_label.text = "%s · %s" % [zoom_name, String(slot.entry.get("cls", "")).capitalize()]
	_zoom_label.reset_size()
	var below: bool = pos.y + _zoom_size.y + _zoom_label.size.y <= size.y
	_zoom_label.position = Vector2(pos.x + (_zoom_size.x - _zoom_label.size.x) * 0.5,
			pos.y + _zoom_size.y if below else pos.y - _zoom_label.size.y)
	_zoom_label.visible = true
	_zoom.visible = true
	_zoom.set_focus(true)


func _hide_zoom() -> void:
	if _zoom != null and _zoom.visible:
		_zoom.set_focus(false)
		_zoom.visible = false
		_zoom_label.visible = false


## kc-cards-impl: the synergy rail's highlight (a trait id, &"" = off) on every banner.
func set_syn_focus(t: StringName) -> void:
	syn_focus = t
	for lane: Node in _lanes:
		lane.set_syn_focus(t)


var syn_focus: StringName = &""


func get_hover_zoom() -> BannerView:
	return _zoom if _zoom != null and _zoom.visible else null


## Index of the lane under a canvas position (drag drops), or -1.
func lane_index_at(global_pos: Vector2) -> int:
	for i: int in _lanes.size():
		if (_lanes[i] as Control).get_global_rect().has_point(global_pos):
			return i
	return -1


## targets: one {state, text} per lane (lane.gd TARGET_*); empty Array clears every lane.
func show_targets(targets: Array) -> void:
	for i: int in _lanes.size():
		var t: Dictionary = targets[i] if i < targets.size() else {}
		_lanes[i].set_target(t.get("state", &"none"), String(t.get("text", "")), String(t.get("chips", "")))


func set_unit_targets(uids: Array) -> void:
	for lane: Node in _lanes:
		lane.set_unit_targets(uids)


## lanes: Array of lane Dictionaries in map order (see mock_match_data.gd).
func set_lanes(lanes: Array) -> void:
	for i: int in mini(lanes.size(), _lanes.size()):
		_lanes[i].set_lane(lanes[i])


func get_lanes() -> Array[Node]:
	return _lanes


func set_compact(compact: bool) -> void:
	for lane: Node in _lanes:
		lane.set_compact(compact)


## BoardMetrics.compute() result; the board's own size is set by the match screen.
func set_metrics(m: Dictionary) -> void:
	metrics = m
	for i: int in _lanes.size():
		var lane: Control = _lanes[i]
		lane.position = Vector2(float(m["col_x"][i]), 0.0)
		lane.size = Vector2(m["bw"], (m["board"] as Rect2).size.y)
		lane.set_metrics(m)


## ghosts: one {entry, front} per column ({} hides); the selected card's landing preview.
func show_ghosts(ghosts: Array) -> void:
	for i: int in _lanes.size():
		var g: Dictionary = ghosts[i] if i < ghosts.size() else {}
		_lanes[i].show_ghost(g.get("entry", {}), bool(g.get("front", false)))


## A short on-board callout in a column (zone index), e.g. "FIELD OVERRUN".
func show_callout(zone: int, text: String, side: StringName = &"player") -> void:
	if zone >= 0 and zone < _lanes.size():
		_lanes[zone].show_callout(text, side)


## Returns the Lane for a zone id (&"left", &"mid", &"right"), or null.
func get_lane(zone_id: StringName) -> Node:
	for lane: Node in _lanes:
		if lane.zone_id == zone_id:
			return lane
	return null
