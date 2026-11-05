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

@onready var _lanes: Array[Node] = [%LaneLeft, %LaneMid, %LaneRight]


var metrics: Dictionary = {}
## Desktop hover zoom (board-and-cards-ux.md §3.7): the banner at 512 px wide after 120 ms.
const HOVER_DELAY: float = 0.12
const ZOOM_SIZE: Vector2 = Vector2(512, 128)
var hover_zoom_enabled: bool = true
var _zoom: BannerView = null
var _zoom_label: Label = null
var _hover_slot: Node = null
var _hover_id: int = 0


func _ready() -> void:
	for i: int in _lanes.size():
		var zone: int = i
		_lanes[i].tapped.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			lane_tapped.emit(zone, slot_side, uid))
		_lanes[i].long_pressed.connect(func(_id: StringName, slot_side: StringName, uid: int) -> void:
			_hover_id += 1  # cancels a pending zoom
			_hide_zoom()
			lane_long_pressed.emit(zone, slot_side, uid))
		_lanes[i].hovered.connect(_on_hovered)
	_zoom = BannerView.new()
	_zoom.name = "HoverZoom"
	_zoom.dim_back = false
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


## Desktop only (mouse; touch has no hover): show the hovered banner zoomed after HOVER_DELAY.
func _on_hovered(slot: Node) -> void:
	_hover_slot = slot
	_hover_id += 1
	var my_id: int = _hover_id
	if slot == null or not hover_zoom_enabled or metrics.get("bh", 64.0) < 56.0:
		_hide_zoom()
		return
	get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void:
		if my_id == _hover_id and is_instance_valid(slot) and slot == _hover_slot:
			_show_zoom(slot))


func _show_zoom(slot: Node) -> void:
	# Only while the pointer is really on that column (not under the inspector or a menu).
	var lane: Node = slot.get_parent().get_parent()
	if get_viewport().gui_get_hovered_control() != lane:
		return
	var r: Rect2 = (slot as Control).get_global_rect()
	var local: Vector2 = get_global_transform().affine_inverse() * r.get_center()
	_zoom.size = ZOOM_SIZE
	_zoom.show_unit(slot.entry, slot.side, slot.row == 0)
	# Grow in place, over the objective side, kept inside the board.
	var pos: Vector2 = local - ZOOM_SIZE * 0.5
	pos.y += (ZOOM_SIZE.y - r.size.y) * 0.5 * (1.0 if slot.side == &"enemy" else -1.0)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - ZOOM_SIZE.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, size.y - ZOOM_SIZE.y))
	_zoom.position = pos
	var zoom_name: String = String(slot.entry.get("art_title", slot.entry.get("name", "")))
	_zoom_label.text = "%s · %s" % [zoom_name, String(slot.entry.get("cls", "")).capitalize()]
	_zoom_label.reset_size()
	var below: bool = pos.y + ZOOM_SIZE.y + _zoom_label.size.y <= size.y
	_zoom_label.position = Vector2(pos.x + (ZOOM_SIZE.x - _zoom_label.size.x) * 0.5,
			pos.y + ZOOM_SIZE.y if below else pos.y - _zoom_label.size.y)
	_zoom_label.visible = true
	_zoom.visible = true
	_zoom.set_focus(true)


func _hide_zoom() -> void:
	if _zoom != null and _zoom.visible:
		_zoom.set_focus(false)
		_zoom.visible = false
		_zoom_label.visible = false


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
		_lanes[i].set_target(t.get("state", &"none"), String(t.get("text", "")))


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
