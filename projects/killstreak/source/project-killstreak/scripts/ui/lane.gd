# lane.gd
# Purpose: One board zone (lane): header with zone name, range badge and control
#   state, the enemy line on top and the player's line below (4 slots each,
#   core-rules.md section 1 zone capacity). Line order runs left to right; the
#   first unit is the point man. Display plus input (p09): the whole lane is the tap / drop
#   target for deploying (FriendlyRow stays >= 64 px); a tap or long-press reports which
#   slot was hit (side + unit uid) so the presenter can pick targets or open the inspector.
#   set_target() shows whether the selected card can go here: a framed lane with a badge
#   ("DEPLOY HERE") or a dimmed lane with the reason ("ZONE FULL", "NEED 3 SUPPLY").
#   v01: a low-contrast Port Vasel backdrop per zone (container stacks, crane yard, loading
#   offices; card_art.gd) sits behind the slots, which are see-through bracket frames when empty.
# Dependencies: unit_slot.gd, press_gesture.gd, card_art.gd.
# Author: UI/UX Agent
extends PanelContainer

## Tap / long-press anywhere in the lane. slot_side is &"player" / &"enemy" when a slot with a
## unit was hit (uid = its rules uid), else &"" and -1.
signal tapped(zone_id: StringName, slot_side: StringName, uid: int)
signal long_pressed(zone_id: StringName, slot_side: StringName, uid: int)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
## Target states (set_target).
const TARGET_NONE: StringName = &"none"
const TARGET_VALID: StringName = &"valid"
const TARGET_HOVER: StringName = &"hover"
const TARGET_INVALID: StringName = &"invalid"
const TARGET_VARIATION: Dictionary = {
	TARGET_NONE: &"LanePanel", TARGET_VALID: &"LaneTargetValid",
	TARGET_HOVER: &"LaneTargetHover", TARGET_INVALID: &"LaneTargetInvalid",
}

const CONTROL_TEXT: Dictionary = {
	&"player": "YOURS",
	&"enemy": "ENEMY",
	&"contested": "CONTESTED",
	&"empty": "OPEN",
}
const HEADER_VARIATION: Dictionary = {
	&"player": &"ZoneFriend",
	&"enemy": &"ZoneEnemy",
	&"contested": &"ZoneContested",
	&"empty": &"ZoneNeutral",
}

## &"left", &"mid" or &"right" (EventBus convention).
var zone_id: StringName = &""
var target_state: StringName = TARGET_NONE
var target_text: String = ""
var _gesture: RefCounted = null

var _backdrop_key: StringName = &""
var _backdrop_scale: float = 0.0

@onready var _backdrop: TextureRect = %Backdrop
@onready var _column: VBoxContainer = %Column
@onready var _header: PanelContainer = %Header
@onready var _name: Label = %NameLabel
@onready var _range: Label = %RangeLabel
@onready var _control: Label = %ControlLabel
@onready var _enemy_slots: HBoxContainer = %EnemyRow.get_node("Slots")
@onready var _friendly_slots: HBoxContainer = %FriendlyRow.get_node("Slots")
@onready var _badge: PanelContainer = %TargetBadge
@onready var _badge_text: Label = %TargetText


func _ready() -> void:
	# Children pass taps up to the lane, which works out the slot from the position.
	for n: Node in find_children("*", "Control", true, false):
		var c: Control = n
		if c is Label or c is TextureRect or c == _badge:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(pos: Vector2) -> void:
		var hit: Array = _slot_hit(pos)
		tapped.emit(zone_id, hit[0], hit[1]))
	_gesture.long_pressed.connect(func(pos: Vector2) -> void:
		var hit: Array = _slot_hit(pos)
		long_pressed.emit(zone_id, hit[0], hit[1]))


func _gui_input(event: InputEvent) -> void:
	if _gesture != null and _gesture.handle(event):
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_backdrop.call_deferred()


## Rasterises the zone backdrop for the lane's on-screen size (bucketed and cached in CardArt).
func _update_backdrop() -> void:
	if _backdrop_key == &"" or _backdrop == null or not is_inside_tree():
		return
	var lane_px: float = CardArt.screen_scale(self) * maxf(size.x / CardArt.Data.LANE_SIZE.x, size.y / CardArt.Data.LANE_SIZE.y)
	var s: float = CardArt.bucket(minf(lane_px, 2.0))  # soft background: 2x is plenty
	if is_equal_approx(s, _backdrop_scale):
		return
	_backdrop_scale = s
	_backdrop.texture = CardArt.lane_texture(_backdrop_key, s)


## Shows whether the selected card / Operator can go here (TARGET_*), with a short badge text.
func set_target(state: StringName, text: String = "") -> void:
	target_state = state
	target_text = text
	theme_type_variation = TARGET_VARIATION.get(state, &"LanePanel")
	_backdrop.modulate.a = 0.35 if state == TARGET_INVALID else 1.0
	_badge.visible = state != TARGET_NONE and not text.is_empty()
	_badge.theme_type_variation = &"TargetBadgeBad" if state == TARGET_INVALID else &"TargetBadge"
	_badge_text.text = text


## Frames the units whose uid is in `uids` as pickable targets (empty clears).
func set_unit_targets(uids: Array) -> void:
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		slot.set_target(slot.kind == slot.Kind.UNIT and uids.has(slot.slot_uid))


## The unit slot (friendly or enemy) under a canvas position, or null.
func slot_at(global_pos: Vector2) -> Node:
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		if (slot as Control).get_global_rect().has_point(global_pos):
			return slot
	return null


## [side, uid] of the unit under a canvas position, or [&"", -1].
func _slot_hit(global_pos: Vector2) -> Array:
	var slot: Node = slot_at(global_pos)
	if slot != null and slot.kind == slot.Kind.UNIT:
		return [slot.side, slot.slot_uid]
	return [&"", -1]


## lane: see mock_match_data.gd for the shape.
func set_lane(lane: Dictionary) -> void:
	zone_id = lane.get("id", &"")
	_name.text = String(lane.get("name", "")).to_upper()
	var key: StringName = CardArt.lane_key(_name.text, zone_id)
	if key != _backdrop_key:
		_backdrop_key = key
		_backdrop_scale = 0.0
		_update_backdrop()
	_range.text = String(lane.get("range", "")).to_upper()
	var control: StringName = lane.get("control", &"empty")
	_control.text = CONTROL_TEXT.get(control, "OPEN")
	_header.theme_type_variation = HEADER_VARIATION.get(control, &"ZoneNeutral")
	_fill_line(_enemy_slots, lane.get("enemy", []), &"enemy", int(lane.get("incoming", 0)), lane.get("revealed", []))
	_fill_line(_friendly_slots, lane.get("friendly", []), &"player", 0)


## Phone layout: tighter spacing, compact slots (see screen_profile.gd).
func set_compact(compact: bool) -> void:
	_column.add_theme_constant_override(&"separation", 2 if compact else 4)
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		slot.set_compact(compact)


## Labels whose whole text must stay visible (zone name, range, control, unit names and stats).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = [_name, _range, _control, _badge_text]
	for slot: Node in get_enemy_slots() + get_friendly_slots():
		out.append_array(slot.get_important_labels())
	return out


func get_enemy_slots() -> Array[Node]:
	return _enemy_slots.get_children()


func get_friendly_slots() -> Array[Node]:
	return _friendly_slots.get_children()


## revealed (f03): names behind the red dots (Recon Drone / Callout), one per incoming slot.
func _fill_line(row: HBoxContainer, units: Array, side: StringName, incoming: int, revealed: Array = []) -> void:
	var slots: Array[Node] = row.get_children()
	for i: int in slots.size():
		var slot: Node = slots[i]
		if i < units.size():
			slot.show_unit(units[i], side, i == 0)
		elif i < units.size() + incoming:
			var k: int = i - units.size()
			slot.show_incoming(String(revealed[k]) if k < revealed.size() else "")
		else:
			slot.show_empty(side)
