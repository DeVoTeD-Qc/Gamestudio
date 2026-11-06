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
	# kc-syn-ui: neighbour link ticks over the columns (under the hover zoom).
	_links = Control.new()
	_links.name = "LinkLayer"
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_links)
	move_child(_links, _zoom.get_index())
	_links.draw.connect(_draw_links)
	resized.connect(func() -> void:
		_links.size = size
		_links.queue_redraw())
	set_process(false)


# =============================================================================
# kc-syn-ui: link ticks (synergy-system.md §9): one short glowing tick per active link between the
# two linked banners, vertical across the row gap for Guard / Spotter, horizontal across the column
# gutter for Fireteam / Overwatch, in the owner's colour. Ghost ticks (dashed) preview the links a
# selected card would make in each column. Ticks follow the banners while they slide.
# =============================================================================

var _links: Control = null
## {&"player": [{kind, from_uid, to_uid}], &"enemy": [...]}
var _link_data: Dictionary = {}
## [{zone, uid (the ghost card / Operator uid), links: [...]}]
var _ghost_links: Array = []
var _tick_redraw_left: float = 0.0


## links: {player: [...], enemy: [...]} (MatchState.synergy_view side links).
func set_links(links: Dictionary) -> void:
	_link_data = links.duplicate(true)
	_kick_ticks()


func set_ghost_links(ghost_links: Array) -> void:
	_ghost_links = ghost_links.duplicate(true)
	_kick_ticks()


## Active link count drawn now (tests / QA).
func get_drawn_ticks() -> Array:
	return _tick_segments(false)


func get_ghost_ticks() -> Array:
	return _tick_segments(true)


func _kick_ticks() -> void:
	if _links == null:
		return
	_links.size = size
	_links.queue_redraw()
	# Redraw for a moment so ticks follow the placement / advance motion.
	_tick_redraw_left = 1.6
	set_process(true)


func _process(delta: float) -> void:
	_tick_redraw_left -= delta
	if _links != null:
		_links.queue_redraw()
	if _tick_redraw_left <= 0.0:
		set_process(false)


## Board-local rect of a banner by unit uid on one side (the banner's live position), or Rect2().
func _banner_rect(side: StringName, uid: int) -> Rect2:
	var inv: Transform2D = get_global_transform().affine_inverse()
	for lane: Node in _lanes:
		var slots: Array[Node] = lane.get_friendly_slots() if side == &"player" else lane.get_enemy_slots()
		for slot: Node in slots:
			if slot.kind == slot.Kind.UNIT and slot.slot_uid == uid:
				var g: Rect2 = (slot.banner as Control).get_global_rect()
				return Rect2(inv * g.position, g.size)
	return Rect2()


## [{a, b, kind, side, ghost}] segments in board-local coordinates.
func _tick_segments(ghost: bool) -> Array:
	var out: Array = []
	if metrics.is_empty():
		return out
	var inv: Transform2D = get_global_transform().affine_inverse()
	var groups: Array = []
	if ghost:
		for g: Dictionary in _ghost_links:
			groups.append([&"player", g.get("links", []), int(g.get("zone", -1)), int(g.get("uid", -1))])
	else:
		for side: StringName in [&"player", &"enemy"]:
			groups.append([side, _link_data.get(side, []), -1, -1])
	for grp: Array in groups:
		var side: StringName = grp[0]
		var seen: Dictionary = {}
		for l: Dictionary in grp[1]:
			var kind: StringName = StringName(l.get("kind", &""))
			var a_uid: int = int(l.get("from_uid", -1))
			var b_uid: int = int(l.get("to_uid", -1))
			var key: String = "%s:%d:%d" % [kind, mini(a_uid, b_uid), maxi(a_uid, b_uid)]
			if seen.has(key):
				continue
			seen[key] = true
			var ra: Rect2 = _rect_for(side, a_uid, grp[2], grp[3], inv)
			var rb: Rect2 = _rect_for(side, b_uid, grp[2], grp[3], inv)
			if not ra.has_area() or not rb.has_area():
				continue
			var seg: Array = _segment(ra, rb, kind)
			if seg.is_empty():
				continue
			out.append({"a": seg[0], "b": seg[1], "kind": kind, "side": side, "ghost": ghost})
	return out


func _rect_for(side: StringName, uid: int, zone: int, ghost_uid: int, inv: Transform2D) -> Rect2:
	if zone >= 0 and uid == ghost_uid:
		var g: BannerView = _lanes[zone].get_ghost()
		if g == null:
			return Rect2()
		var gr: Rect2 = g.get_global_rect()
		return Rect2(inv * gr.position, gr.size)
	return _banner_rect(side, uid)


## Tick from banner a to banner b: vertical (same column) or horizontal (next column).
func _segment(ra: Rect2, rb: Rect2, kind: StringName) -> Array:
	var vertical: bool = kind in [SynergyRules.GUARD, SynergyRules.SPOTTER]
	var reach: float = 6.0 if bool(metrics.get("compact", true)) else 9.0
	if vertical:
		var x: float = ra.position.x + ra.size.x * (0.36 if kind == SynergyRules.GUARD else 0.64)
		var top: Rect2 = ra if ra.position.y < rb.position.y else rb
		var bot: Rect2 = rb if top == ra else ra
		var y0: float = top.end.y - reach
		var y1: float = bot.position.y + reach
		return [Vector2(x, y0), Vector2(x, y1)]
	var left: Rect2 = ra if ra.position.x < rb.position.x else rb
	var right: Rect2 = rb if left == ra else ra
	var y: float = left.position.y + left.size.y * (0.4 if kind == SynergyRules.FIRETEAM else 0.6)
	return [Vector2(left.end.x - reach, y), Vector2(right.position.x + reach, y)]


func _draw_links() -> void:
	var w: float = 4.0 if bool(metrics.get("compact", true)) else 5.0
	for ghost: bool in [true, false]:
		for seg: Dictionary in _tick_segments(ghost):
			var c: Color = get_theme_color(&"friend" if seg["side"] == &"player" else &"enemy", &"Hud")
			if ghost:
				c = get_theme_color(&"accent", &"Hud")
			SynergyGlyphs.draw_tick(_links, seg["a"], seg["b"], c, w, ghost)


## Desktop only (mouse; touch has no hover): show the hovered banner zoomed after HOVER_DELAY.
func _on_hovered(slot: Node) -> void:
	_hover_slot = slot
	_hover_id += 1
	var my_id: int = _hover_id
	if slot == null or not hover_zoom_enabled or bool(metrics.get("compact", metrics.get("bh", 64.0) < 56.0)):
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
		zoom_name += " “%s”" % String(slot.entry["subname"])
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
