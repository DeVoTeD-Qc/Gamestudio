# lane.gd
# Purpose: One board COLUMN (kc-board; board-and-cards-ux.md §2-§5). Top to bottom: the rival's
#   rows 4 (back) .. 1 (front), the objective tile, your rows 1 (front) .. 4 (back). Row 1 touches
#   the objective and is the frontline: full brightness, side-coloured outline and a FRONT tab;
#   back rows are dimmed. get_enemy_slots() / get_friendly_slots() are in LINE order (index 0 =
#   frontline), as in the rules (RulesSide.lines) and the p09 lane, so the FX locator, the
#   presenter and the tests keep working.
#   Input (p09): the whole column is the tap / drop target for playing a card; a tap or long-press
#   reports what was hit: [&"player"/&"enemy", unit uid], [&"incoming", -1], [&"objective", -1] or
#   [&"field_player"/&"field_enemy", field card uid]. While units are offered as targets
#   (set_unit_targets) a tap in a half snaps to the nearest target in that half (the phone's slot
#   pitch is 34 pt, below 44 pt).
#   set_target(): valid columns get a frame and a PLAY HERE badge in your half; invalid ones dim
#   with the reason. show_ghost(): the selected card's full banner at 50% in its landing slot
#   (the first free row, or row 1 for a Protector).
#   Motion (§5), diffed from the previous snapshot by unit uid: a new unit enters from its side's
#   outer edge and slides to its slot (180 ms + 70 ms per row, overshoot) with one shimmer pass;
#   a unit that landed in front of the line (Protector) first lands at the back, waits 160 ms and
#   slides to row 1 while the cards it passed shift back; units that moved up after an
#   elimination slide (320 ms, 60 ms stagger); removed units fade out (500 ms).
#   Settings.fast_animations halves the times; reduced motion uses short fades only.
# Dependencies: unit_slot.gd, objective_tile.gd, banner_view.gd, board_metrics.gd, press_gesture.gd.
# Author: Mechanics Developer Agent (kc-board), after the p09 Lane (UI/UX Agent)
extends Control

## Tap / long-press anywhere in the column (see the header for slot_side values).
signal tapped(zone_id: StringName, slot_side: StringName, uid: int)
signal long_pressed(zone_id: StringName, slot_side: StringName, uid: int)
## Mouse over a unit banner (desktop hover zoom); null when it leaves.
signal hovered(slot: Node)
## kc-loadout-clean: a press on one of your movable units (MOVE chip) that moved past 10 px: drag it
## to another column (positions are canvas coordinates).
signal unit_drag_started(zone_id: StringName, uid: int, pos: Vector2)
signal unit_drag_moved(pos: Vector2)
signal unit_drag_ended(pos: Vector2)

## kc-ui-wire2: the UI kit FRONT tab plate (desktop only; the phone keeps its 5 px bar).
const FRONT_TAB_PIECE: StringName = &"frm_front_tab"
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const UnitSlotScript: GDScript = preload("res://scripts/ui/unit_slot.gd")
const ObjectiveTile: GDScript = preload("res://scripts/ui/objective_tile.gd")
## kc-juice: the calling-card stamp when a new banner reaches its slot.
const CardLandFx: GDScript = preload("res://scripts/fx/card_land_fx.gd")
## Target states (set_target).
const TARGET_NONE: StringName = &"none"
const TARGET_VALID: StringName = &"valid"
const TARGET_HOVER: StringName = &"hover"
const TARGET_INVALID: StringName = &"invalid"
const TARGET_VARIATION: Dictionary = {
	TARGET_VALID: &"LaneTargetValid", TARGET_HOVER: &"LaneTargetHover", TARGET_INVALID: &"LaneTargetInvalid",
}
const ROWS: int = 4
## Motion (ms), board-and-cards-ux.md §5.
const LIFT_MS: float = 220.0
const SLIDE_BASE_MS: float = 180.0
const SLIDE_PER_ROW_MS: float = 70.0
const PROTECTOR_PAUSE_MS: float = 160.0
const SHIFT_MS: float = 450.0  # kc-fight-ui: readable line slides (was 320)
const SHIFT_STAGGER_MS: float = 60.0
const FADE_MS: float = 500.0

## &"left", &"mid" or &"right" (EventBus convention).
var zone_id: StringName = &""
var target_state: StringName = TARGET_NONE
var target_text: String = ""
var compact: bool = false
## Board metrics (BoardMetrics.compute); set by the board.
var metrics: Dictionary = {}
## Animate snapshot changes (off for the first fill and in tests that want a still board).
var animate: bool = true
var lane_data: Dictionary = {}
var _gesture: RefCounted = null
var _enemy_slots: Array[Node] = []
var _friendly_slots: Array[Node] = []
var _unit_targets: Array = []
var _prev_rows: Dictionary = {}   # uid -> [side, row]
var _has_prev: bool = false
var _ghost_row: int = -1
var _ghost: BannerView = null
## kc-ui3: the column's location art (the map's lane backdrop: containers / cranes / offices), low
## opacity and darkened behind the slots so banners stay readable. Public project art only.
var _backing: TextureRect = null
var _backing_key: StringName = &""
const BACKING_TINT: Color = Color(0.62, 0.68, 0.72, 0.34)

@onready var _enemy_row: Control = %EnemyRow
@onready var _friendly_row: Control = %FriendlyRow
@onready var _slots: Control = %Slots
@onready var _tile: Control = %Objective
@onready var _decor: Control = %Decor
@onready var _fx_layer: Control = %FxLayer
@onready var _badge: PanelContainer = %TargetBadge
@onready var _badge_text: Label = %TargetText


func _ready() -> void:
	for i: int in ROWS:
		_enemy_slots.append(_make_slot(&"enemy", i))
	for i: int in ROWS:
		_friendly_slots.append(_make_slot(&"player", i))
	_ghost = BannerView.new()
	_ghost.name = "Ghost"
	_ghost.show_name = false  # kc-onboard-ui (head W1): board banners carry no name
	_ghost.readability = true
	_ghost.visible = false
	_slots.add_child(_ghost)
	_backing = TextureRect.new()
	_backing.name = "Backing"
	_backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backing.self_modulate = BACKING_TINT
	_backing.clip_contents = true
	add_child(_backing)
	move_child(_backing, 0)
	for n: Node in find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_decor.draw.connect(_draw_decor)
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(pos: Vector2) -> void:
		var hit: Array = _slot_hit(pos)
		tapped.emit(zone_id, hit[0], hit[1]))
	_gesture.long_pressed.connect(func(pos: Vector2) -> void:
		_hover_slot = null
		var hit: Array = _slot_hit(pos, true)
		long_pressed.emit(zone_id, hit[0], hit[1]))
	_gesture.drag_started.connect(func(pos: Vector2) -> void:
		set_peek(null)
		unit_drag_started.emit(zone_id, _drag_uid, pos))
	_gesture.drag_moved.connect(func(pos: Vector2) -> void: unit_drag_moved.emit(pos))
	_gesture.drag_ended.connect(func(pos: Vector2) -> void: unit_drag_ended.emit(pos))
	resized.connect(_layout)


func _make_slot(slot_side: StringName, row: int) -> Node:
	var slot: Control = UnitSlotScript.new()
	slot.name = ("Enemy%d" if slot_side == &"enemy" else "Friendly%d") % (row + 1)
	slot.side = slot_side
	slot.row = row
	_slots.add_child(slot)
	slot.show_empty(slot_side)
	return slot


var _hover_slot: Node = null
var _drag_uid: int = -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var slot: Node = slot_at(get_global_transform() * (event as InputEventMouseMotion).position)
		if slot != null and slot.kind != slot.Kind.UNIT:
			slot = null
		if slot != _hover_slot:
			_hover_slot = slot
			hovered.emit(slot)
		# kc-cards-impl (C1+ peek): the hovered card shows its cost, level and weapon (a held finger
		# keeps the card it pressed until it lifts).
		if (event as InputEventMouseMotion).button_mask == 0:
			set_peek(slot)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			var held: Node = slot_at(get_global_transform() * mb.position)
			set_peek(held if held != null and held.kind == held.Kind.UNIT else null)
			# kc-loadout-clean: only a movable unit of yours can be dragged (the board stays still
			# under any other press, so a tap or a long press works as before).
			var can_drag: bool = held != null and held.kind == held.Kind.UNIT and held.side == &"player" and bool(held.movable)
			_drag_uid = int(held.slot_uid) if can_drag else -1
			if _gesture != null and not _gesture.pressed:
				_gesture.drag_enabled = can_drag
		elif mb.device == InputEvent.DEVICE_ID_EMULATION:
			set_peek(null)  # touch: the peek lasts while the finger holds the card
	if _gesture != null and _gesture.handle(event):
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		set_peek(null)
		if _hover_slot != null:
			_hover_slot = null
			hovered.emit(null)


var _peek_slot: Node = null


## kc-cards-impl: the card that peeks (hover / hold), null = none.
func set_peek(slot: Node) -> void:
	if slot == _peek_slot:
		return
	if _peek_slot != null and is_instance_valid(_peek_slot):
		(_peek_slot.get(&"banner") as BannerView).peek = false
	_peek_slot = slot
	if slot != null:
		(slot.get(&"banner") as BannerView).peek = true


func get_peek_slot() -> Node:
	return _peek_slot if _peek_slot != null and is_instance_valid(_peek_slot) else null


## kc-cards-impl: the synergy rail's highlighted trait on every banner of this column.
func set_syn_focus(t: StringName) -> void:
	for slot: Node in _enemy_slots + _friendly_slots:
		(slot.get(&"banner") as BannerView).syn_focus = t


func set_metrics(m: Dictionary) -> void:
	metrics = m
	compact = bool(m.get("compact", m.get("bh", 64.0) < 56.0))
	_tile.compact = compact
	for slot: Node in _enemy_slots + _friendly_slots:
		slot.set_compact(compact)
	_layout()


func _layout() -> void:
	if metrics.is_empty():
		return
	var bw: float = metrics["bw"]
	var bh: float = metrics["bh"]
	for slot: Node in _enemy_slots + _friendly_slots:
		var c: Control = slot
		c.position = Vector2(0, BoardMetrics.row_y(metrics, slot.side, slot.row))
		c.size = Vector2(bw, bh)
	var oy: float = BoardMetrics.objective_y(metrics)
	_tile.position = Vector2(0, oy)
	_tile.size = Vector2(bw, metrics["obj_h"])
	_enemy_row.position = Vector2.ZERO
	_enemy_row.size = Vector2(bw, metrics["half_h"])
	_backing.position = Vector2.ZERO
	_backing.size = Vector2(bw, size.y if size.y > 0.0 else metrics["half_h"] * 2.0 + metrics["obj_h"])
	_friendly_row.position = Vector2(0, BoardMetrics.row_y(metrics, &"player", 0))
	_friendly_row.size = Vector2(bw, metrics["half_h"])
	_place_badge()
	_place_ghost()
	_decor.queue_redraw()
	queue_redraw()


## Shows whether the selected card / Operator can go here (TARGET_*), with a short badge text.
func set_target(state: StringName, text: String = "", chips: String = "") -> void:
	target_state = state
	target_text = text
	_set_chips(state != TARGET_NONE and state != TARGET_INVALID and not chips.is_empty(), chips)
	_badge.visible = state != TARGET_NONE and not text.is_empty()
	_badge.theme_type_variation = &"TargetBadgeBad" if state == TARGET_INVALID else &"TargetBadge"
	_badge_text.text = text
	_place_badge.call_deferred()
	_decor.queue_redraw()


## The selected card's landing preview (entry {} hides it). front: it takes row 1 (Protector).
func show_ghost(entry: Dictionary, front: bool = false) -> void:
	if entry.is_empty():
		_ghost.visible = false
		_ghost.set_focus(false)
		_ghost_row = -1
		_shift_for_ghost(false)
		_place_badge()
		return
	var line: int = (lane_data.get("friendly", []) as Array).size()
	_ghost_row = 0 if front else line
	if _ghost_row >= ROWS or (front and line >= ROWS):
		_ghost.visible = false
		_ghost_row = -1
		_shift_for_ghost(false)
		return
	_ghost.show_ghost(entry)
	_ghost.visible = true
	_show_play_here()
	# kc-polish (B1): a Protector's ghost takes row 1 and your cards preview their shift back one
	# row, so the ghost never covers your current front card.
	_shift_for_ghost(front and line > 0)
	_place_ghost()
	_place_badge()


var _ghost_shift: bool = false


## Moves your banners back one row (preview of the Protector slide), or returns them.
func _shift_for_ghost(on: bool) -> void:
	if on == _ghost_shift or metrics.is_empty():
		return
	_ghost_shift = on
	var pitch: float = metrics["bh"] + metrics["row_gap"]
	for slot: Node in _friendly_slots:
		if slot.kind == slot.Kind.EMPTY:
			continue
		var b: BannerView = slot.banner
		var tw: Tween = _motion(b)
		tw.tween_property(b, "position:y", pitch if on else 0.0, _ms(140.0) / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


var _play_here: Label = null


## kc-cards-impl (H1): the legal landing slot says PLAY HERE (over the card's ghost).
func _show_play_here() -> void:
	if _play_here == null:
		_play_here = Label.new()
		_play_here.name = "PlayHere"
		_play_here.text = "PLAY HERE"
		_play_here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_play_here.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_play_here.add_theme_font_override(&"font", CardLook.TITLE_FONT)
		_play_here.add_theme_font_size_override(&"font_size", 18)
		_play_here.add_theme_color_override(&"font_color", Color("#FFB020"))
		_play_here.add_theme_constant_override(&"outline_size", 4)
		_play_here.add_theme_color_override(&"font_outline_color", Color(0.05, 0.06, 0.07))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.69, 0.13, 0.16)
		sb.border_color = Color("#FFB020")
		sb.set_border_width_all(2)
		_play_here.add_theme_stylebox_override(&"normal", sb)
		_ghost.add_child(_play_here)
	_play_here.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_here.text = "PLAY HERE · %s" % String(lane_data.get("label", "")) if String(lane_data.get("label", "")) != "" else "PLAY HERE"
	_play_here.visible = true


## The PLAY HERE label of this column's landing slot (null when no card is selected).
func get_play_here() -> Label:
	return _play_here if _play_here != null and _ghost.visible and _play_here.visible else null


func is_ghost_shift() -> bool:
	return _ghost_shift


func get_ghost() -> BannerView:
	return _ghost if _ghost.visible else null


func _place_ghost() -> void:
	if _ghost == null or _ghost_row < 0 or metrics.is_empty():
		return
	_ghost.position = Vector2(0, BoardMetrics.row_y(metrics, &"player", _ghost_row))
	_ghost.size = Vector2(metrics["bw"], metrics["bh"])
	_slots.move_child(_ghost, -1)


## kc-syn-ui: the placement preview's chips under the column badge ("VANGUARD 3 ON · +1 FP").
var _chip: PanelContainer = null
var _chip_text: Label = null
var target_chips: String = ""


func _set_chips(on: bool, text: String) -> void:
	if _chip == null:
		_chip = PanelContainer.new()
		_chip.name = "SynergyChips"
		_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip.theme_type_variation = &"TargetBadge"
		_chip_text = Label.new()
		_chip_text.theme_type_variation = &"TargetText"
		_chip_text.add_theme_color_override(&"font_color", Color("#7CF29A"))
		_chip.add_child(_chip_text)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.07, 0.9)
		sb.border_color = Color("#7CF29A")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(3)
		_chip.add_theme_stylebox_override(&"panel", sb)
		_fx_layer.add_child(_chip)
	target_chips = text if on else ""
	_chip.visible = on
	_chip_text.text = text
	_place_badge.call_deferred()


## The chips text shown now ("" = none; tests / QA).
func get_target_chips() -> String:
	return target_chips if _chip != null and _chip.visible else ""


## The badge sits in your half, over the first empty row (clear of the landing ghost).
func _place_badge() -> void:
	if metrics.is_empty() or _badge == null:
		return
	_badge.reset_size()
	var line: int = (lane_data.get("friendly", []) as Array).size() + (1 if _ghost_shift else 0)
	var row: int = clampi(line, 0, ROWS - 1)
	if row == _ghost_row:
		row = mini(row + 1, ROWS - 1) if row < ROWS - 1 else maxi(row - 1, 0)
	var y: float = BoardMetrics.row_y(metrics, &"player", row) + (metrics["bh"] - _badge.size.y) * 0.5
	_badge.position = Vector2(roundf((size.x - _badge.size.x) * 0.5), roundf(y))
	if _chip != null and _chip.visible:
		_chip.reset_size()
		var cy: float = _badge.position.y + _badge.size.y + 2.0
		if cy + _chip.size.y > size.y:
			cy = _badge.position.y - _chip.size.y - 2.0
		_chip.position = Vector2(roundf((size.x - _chip.size.x) * 0.5), roundf(cy))


## Frames the units whose uid is in `uids` as pickable targets (empty clears).
func set_unit_targets(uids: Array) -> void:
	_unit_targets = uids.duplicate()
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		slot.set_target(slot.kind == slot.Kind.UNIT and uids.has(slot.slot_uid))


## The unit slot (friendly or enemy) under a canvas position, or null.
func slot_at(global_pos: Vector2) -> Node:
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		if (slot as Control).get_global_rect().has_point(global_pos):
			return slot
	return null


## [side, uid] hit at a canvas position (see the header). Taps snap to the nearest offered target
## in the tapped half; inspect (long-press) never snaps.
func _slot_hit(global_pos: Vector2, inspect: bool = false) -> Array:
	var slot: Node = slot_at(global_pos)
	var local: Vector2 = get_global_transform().affine_inverse() * global_pos
	if not inspect and not _unit_targets.is_empty():
		if slot == null or not _unit_targets.has(slot.slot_uid):
			var half: StringName = &"enemy" if local.y < BoardMetrics.objective_y(metrics) else &"player"
			if (_tile as Control).get_rect().has_point(local):
				half = &""
			var best: Node = null
			var best_d: float = INF
			for s: Node in (get_enemy_slots() if half == &"enemy" else get_friendly_slots() if half == &"player" else []):
				if s.kind == s.Kind.UNIT and _unit_targets.has(s.slot_uid):
					var d: float = absf((s as Control).get_global_rect().get_center().y - global_pos.y)
					if d < best_d:
						best_d = d
						best = s
			if best != null:
				slot = best
	if slot != null and slot.kind == slot.Kind.UNIT:
		return [slot.side, slot.slot_uid]
	if slot != null and slot.kind == slot.Kind.INCOMING:
		return [&"incoming", -1]
	if (_tile as Control).get_rect().has_point(local):
		# kc-v2-ui: the Terrain chip is its own target (tap = its rule, long press = its inspector).
		if _tile.terrain_hit(local - (_tile as Control).position):
			return [&"terrain", -1]
		var f: Array = _tile.field_at(local - (_tile as Control).position)
		if not f.is_empty():
			return [StringName("field_" + String(f[0])), int((f[1] as Dictionary).get("card_uid", -1))]
		return [&"objective", -1]
	return [&"", -1]


## lane: see mock_match_data.gd / match_snapshot.gd for the shape.
func set_lane(lane: Dictionary) -> void:
	lane_data = lane
	zone_id = lane.get("id", &"")
	_set_backing(CardArt.lane_key(String(lane.get("name", "")), zone_id))
	if _ghost_shift:
		_ghost_shift = false
		for slot: Node in _friendly_slots:
			_motion(slot.banner).kill()
			slot.banner.position.y = 0.0
	_tile.set_tile(lane)
	var enemy: Array = lane.get("enemy", [])
	var friendly: Array = lane.get("friendly", [])
	_fill_line(_enemy_slots, enemy, &"enemy", int(lane.get("incoming", 0)), lane.get("revealed", []))
	_fill_line(_friendly_slots, friendly, &"player", 0)
	_animate_changes(enemy, friendly)
	_place_badge()
	_decor.queue_redraw()


## The column's location art (kc-ui3), by CardArt lane key; loaded once per key.
func _set_backing(key: StringName) -> void:
	if key == _backing_key:
		return
	_backing_key = key
	_backing.texture = CardArt.lane_texture(key, 1.0)
	_backing.set_meta(&"lane_key", key)


## The location art behind the column (tests / QA): the TextureRect, or null when it has none.
func get_backing() -> TextureRect:
	return _backing if _backing != null and _backing.texture != null else null


## Phone layout flag (the board passes metrics; this keeps the p08 API).
func set_compact(value: bool) -> void:
	compact = value


## Labels whose whole text must stay visible (the badge; banners draw their own numbers).
func get_important_labels() -> Array[Label]:
	return [_badge_text]


func get_enemy_slots() -> Array[Node]:
	return _enemy_slots


func get_friendly_slots() -> Array[Node]:
	return _friendly_slots


func get_objective_tile() -> Control:
	return _tile


## Column-local rect of a row slot (row 0 = front), for callouts and tests.
func row_rect(slot_side: StringName, row: int) -> Rect2:
	return Rect2(Vector2(0, BoardMetrics.row_y(metrics, slot_side, row)), Vector2(metrics["bw"], metrics["bh"]))


## A short callout on the board ("FIELD OVERRUN", "PICK: lowest Armor (2)"), fading after ~1.4 s.
func show_callout(text: String, slot_side: StringName = &"player") -> void:
	if metrics.is_empty():
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TargetBadgeBad" if slot_side == &"enemy" else &"TargetBadge"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.theme_type_variation = &"TargetText"
	l.text = text
	panel.add_child(l)
	_fx_layer.add_child(panel)
	panel.reset_size()
	var oy: float = BoardMetrics.objective_y(metrics)
	panel.position = Vector2((size.x - panel.size.x) * 0.5, oy + (metrics["obj_h"] - panel.size.y) * 0.5)
	var tw: Tween = panel.create_tween()
	tw.tween_interval(_ms(1100.0) / 1000.0)
	tw.tween_property(panel, "modulate:a", 0.0, _ms(300.0) / 1000.0)
	tw.tween_callback(panel.queue_free)


## revealed (f03): names behind the hidden plays (Recon Drone / Callout), one per incoming slot.
func _fill_line(slots: Array[Node], units: Array, slot_side: StringName, incoming: int, revealed: Array = []) -> void:
	for i: int in slots.size():
		var slot: Node = slots[i]
		if i < units.size():
			slot.show_unit(units[i], slot_side, i == 0)
		elif i < units.size() + incoming:
			var k: int = i - units.size()
			slot.show_incoming(String(revealed[k]) if k < revealed.size() else "")
		else:
			slot.show_empty(slot_side)


# =============================================================================
# Motion
# =============================================================================

func _ms(t: float) -> float:
	var s: Node = get_node_or_null(^"/root/Settings")
	if s != null and bool(s.get(&"fast_animations")):
		return t * 0.5
	return t


func _reduced() -> bool:
	var s: Node = get_node_or_null(^"/root/Settings")
	return s != null and bool(s.get(&"reduced_motion"))


func _animate_changes(enemy: Array, friendly: Array) -> void:
	var now: Dictionary = {}
	for pair: Array in [[&"enemy", enemy], [&"player", friendly]]:
		var units: Array = pair[1]
		for i: int in units.size():
			var uid: int = int((units[i] as Dictionary).get("uid", -1))
			if uid >= 0:
				now[uid] = [pair[0], i, units[i]]
	var can_animate: bool = animate and _has_prev and is_inside_tree() and not metrics.is_empty() and is_visible_in_tree()
	if can_animate:
		_play_motion(now, enemy, friendly)
	_prev_rows = now
	_has_prev = true


func _play_motion(now: Dictionary, enemy: Array, friendly: Array) -> void:
	var reduced: bool = _reduced()
	# Removed units fade out where they stood.
	for uid: int in _prev_rows:
		if not now.has(uid):
			var was: Array = _prev_rows[uid]
			_fade_out_copy(was[0], was[1], was[2])
	for pair: Array in [[&"enemy", enemy, _enemy_slots], [&"player", friendly, _friendly_slots]]:
		var s_side: StringName = pair[0]
		var units: Array = pair[1]
		var slots: Array[Node] = pair[2]
		# A unit that is new AND in front of units that were already there slid in (Protector).
		var protector_row: int = -1
		for i: int in units.size():
			var uid: int = int((units[i] as Dictionary).get("uid", -1))
			if not _prev_rows.has(uid) and i < units.size() - 1:
				for j: int in range(i + 1, units.size()):
					if _prev_rows.has(int((units[j] as Dictionary).get("uid", -1))):
						protector_row = i
						break
			if protector_row >= 0:
				break
		var back_row: int = units.size() - 1
		var arrive_ms: float = LIFT_MS + SLIDE_BASE_MS + SLIDE_PER_ROW_MS * float(ROWS - 1 - back_row)
		for i: int in units.size():
			var uid: int = int((units[i] as Dictionary).get("uid", -1))
			var slot: Node = slots[i]
			var banner: BannerView = slot.banner
			if reduced:
				if not _prev_rows.has(uid) or (_prev_rows[uid] as Array)[1] != i:
					banner.modulate.a = 0.0
					banner.create_tween().tween_property(banner, "modulate:a", 1.0, 0.15)
				if not _prev_rows.has(uid):
					CardLandFx.stamp(banner, s_side)  # kc-juice: reduced motion: the stamp sound only
				continue
			if not _prev_rows.has(uid):
				if i == protector_row:
					_enter(slot, s_side, back_row, i, true)
				else:
					_enter(slot, s_side, i, i, false)
			else:
				var from_row: int = (_prev_rows[uid] as Array)[1]
				if from_row != i:
					var delay: float = 0.0
					if protector_row >= 0 and i > protector_row:
						delay = arrive_ms + PROTECTOR_PAUSE_MS  # the cards the Protector passes shift back
					else:
						delay = SHIFT_STAGGER_MS * float(i)
					_shift(slot, s_side, from_row, i, delay)


## A new banner enters at its side's back row (yours) or outer edge (rival), lands at land_row, then (Protector) slides to row.
func _enter(slot: Node, s_side: StringName, land_row: int, row: int, protector: bool) -> void:
	var banner: BannerView = slot.banner
	var slot_y: float = BoardMetrics.row_y(metrics, s_side, row)
	# kc-board2 (board-layout-v2.md §4.4): your card morphs from the tray INTO the back-row slot (the
	# back row touches the screen edge); the rival's still enters from just past the top edge.
	var outer_y: float = BoardMetrics.row_y(metrics, s_side, ROWS - 1) + (0.0 if s_side == &"player" else -(metrics["bh"] + metrics["row_gap"]))
	var land_y: float = BoardMetrics.row_y(metrics, s_side, land_row)
	banner.position = Vector2(0, outer_y - slot_y)
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.04, 1.04)
	banner.pivot_offset = banner.size * 0.5
	banner.set_focus(true, _ms(900.0) / 1000.0 if not protector else _ms(1300.0) / 1000.0)
	var tw: Tween = _motion(banner)
	tw.tween_property(banner, "modulate:a", 1.0, _ms(LIFT_MS) / 1000.0)
	var slide: float = SLIDE_BASE_MS + SLIDE_PER_ROW_MS * float(ROWS - 1 - land_row)
	tw.tween_property(banner, "position:y", land_y - slot_y, _ms(slide) / 1000.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, _ms(slide) / 1000.0)
	# kc-juice: the card lands: scale punch + flash + stamp sound (card_land_fx.gd, < 250 ms).
	tw.tween_callback(func() -> void: CardLandFx.stamp(banner, s_side))
	if protector:
		tw.tween_interval(_ms(PROTECTOR_PAUSE_MS) / 1000.0)
		tw.tween_property(banner, "position:y", 0.0, _ms(SHIFT_MS) / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var callout: Callable = show_callout.bind("TAKES THE FRONT", s_side)
		tw.tween_callback(callout)


func _shift(slot: Node, s_side: StringName, from_row: int, row: int, delay_ms: float) -> void:
	var banner: BannerView = slot.banner
	banner.position = Vector2(0, BoardMetrics.row_y(metrics, s_side, from_row) - BoardMetrics.row_y(metrics, s_side, row))
	var tw: Tween = _motion(banner)
	if delay_ms > 0.0:
		tw.tween_interval(_ms(delay_ms) / 1000.0)
	tw.tween_property(banner, "position:y", 0.0, _ms(SHIFT_MS) / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## One motion tween per banner: a new move replaces the one still running.
func _motion(b: BannerView) -> Tween:
	if b.has_meta(&"motion"):
		var old: Tween = b.get_meta(&"motion") as Tween
		if old != null and old.is_valid():
			old.kill()
	var tw: Tween = b.create_tween()
	b.set_meta(&"motion", tw)
	return tw


func _fade_out_copy(s_side: StringName, row: int, entry: Dictionary) -> void:
	if row < 0 or row >= ROWS:
		return
	var copy := BannerView.new()
	copy.show_name = false
	copy.readability = true
	_fx_layer.add_child(copy)
	copy.position = Vector2(0, BoardMetrics.row_y(metrics, s_side, row))
	copy.size = Vector2(metrics["bw"], metrics["bh"])
	copy.show_unit(entry, s_side, row == 0)
	copy.modulate = Color(0.55, 0.55, 0.55, 0.9)
	var tw: Tween = copy.create_tween()
	tw.tween_property(copy, "modulate:a", 0.0, _ms(FADE_MS) / 1000.0)
	tw.tween_callback(copy.queue_free)


# =============================================================================
# Decor: frame, FRONT tabs, dim
# =============================================================================

func _draw() -> void:
	if metrics.is_empty():
		return
	# Faint column backing behind each half.
	var c: Color = Color(0.1, 0.12, 0.14, 0.55)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, metrics["half_h"])), c)
	draw_rect(Rect2(Vector2(0, BoardMetrics.row_y(metrics, &"player", 0)), Vector2(size.x, metrics["half_h"])), c)


func _draw_decor() -> void:
	if metrics.is_empty():
		return
	var oy: float = BoardMetrics.objective_y(metrics)
	# FRONT tabs: each side's row 1 meets the objective tile. kc-cards-impl: the tab sits INSIDE the
	# tile's top (rival) / bottom (yours) margin, clear of the banners and of the tile's labels
	# (kc-abc-labels: over the letter mark, clear of the Field chips):
	# desktop keeps the FRONT word (the 96 px tile has a 26 px margin), the phone's 52 px tile has a
	# 6 px margin, so there it is a side-coloured bar (no word).
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var obj_h: float = metrics["obj_h"]
	var tab: Vector2 = Vector2(48, 5) if compact else Vector2(64, 15)
	var fs: int = 13
	for pair: Array in [[&"enemy", _enemy_slots], [&"player", _friendly_slots]]:
		var slot: Node = pair[1][0]
		if slot.kind != slot.Kind.UNIT or slot.pending:
			continue
		var side_c: Color = get_theme_color(&"friend" if pair[0] == &"player" else &"enemy", &"Hud")
		var y: float = oy + 1.0 if pair[0] == &"enemy" else oy + obj_h - 1.0 - tab.y
		var r: Rect2 = Rect2(Vector2(front_tab_x(tab.x), y), tab)
		if compact:
			# The phone's 5 px bar is too thin for the kit tab's chamfers: it stays a plain bar.
			_decor.draw_rect(r, side_c)
			continue
		# kc-ui-wire2: the kit's FRONT tab (frm_front_tab) tinted the side colour; else a flat tab.
		if not UiKit.draw_piece(_decor, FRONT_TAB_PIECE, r, side_c):
			_decor.draw_rect(r, side_c)
		var sz: Vector2 = font.get_string_size("FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_decor.draw_string(font, Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
				"FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.06, 0.07))
	# Target frame / dim.
	var full: Rect2 = Rect2(Vector2.ZERO, size).grow(-1.0)
	match target_state:
		TARGET_INVALID:
			_decor.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.06, 0.55))
		TARGET_VALID, TARGET_HOVER:
			# The theme style's border only (its fill would cover the banners).
			var sb: StyleBox = get_theme_stylebox(&"panel", TARGET_VARIATION[target_state])
			var border: Color = get_theme_color(&"friend", &"Hud")
			var w: float = 2.0
			if sb is StyleBoxFlat:
				border = (sb as StyleBoxFlat).border_color
				w = maxf(2.0, float((sb as StyleBoxFlat).border_width_top))
			_decor.draw_rect(full, border, false, w)
			if target_state == TARGET_HOVER:
				_decor.draw_rect(_friendly_row.get_rect(), Color(border, 0.14))


## kc-abc-labels: the FRONT tab sits over the column letter's mark (the tile's left, where the mark
## leaves a margin above and below), so it never covers the Field chips that now fill the tile.
func front_tab_x(tab_w: float) -> float:
	var obj_h: float = float(metrics.get("obj_h", 52.0))
	var mm: float = minf(roundf(obj_h * 0.76), 64.0)
	return maxf(1.0, 6.0 + (mm - tab_w) * 0.5)


## The FRONT tab rects (lane-local) drawn now (tests): {&"enemy": Rect2, &"player": Rect2} for the
## sides with a front unit.
func front_tab_rects() -> Dictionary:
	var out: Dictionary = {}
	if metrics.is_empty():
		return out
	var oy: float = BoardMetrics.objective_y(metrics)
	var tab: Vector2 = Vector2(48, 5) if compact else Vector2(64, 15)
	for pair: Array in [[&"enemy", _enemy_slots], [&"player", _friendly_slots]]:
		var slot: Node = pair[1][0]
		if slot.kind != slot.Kind.UNIT or slot.pending:
			continue
		var y: float = oy + 1.0 if pair[0] == &"enemy" else oy + float(metrics["obj_h"]) - 1.0 - tab.y
		out[pair[0]] = Rect2(Vector2(front_tab_x(tab.x), y), tab)
	return out
