# board_fx_locator.gd
# Purpose: Tells FeedbackDirector where things are on screen, for the p08 match screen's Board
#   (scenes/match/Board.tscn -> Lane -> UnitSlot). It maps unit uids to slot positions
#   {side, zone, index} and returns global canvas rects. Read-only: it never changes the board.
#   With the p09 board (UnitSlot.slot_uid) it finds slots by uid on its own. Otherwise fill
#   the map from the rules state the board is showing (sync_from_state) or by hand (set_unit).
#   Either way the board must still show the PRE-resolution snapshot while a sequence plays,
#   so an eliminated unit still has a slot for its stamp; refresh the board afterwards.
#   Unknown uid: the director falls back to the zone rect (enemy half on top, own half below).
# Dependencies: none at load time (duck-typed Board / MatchState).
# Author: Game Feel Engineer Agent (p14)
extends RefCounted

## Board node (board.gd: get_lane(zone) -> Lane with get_enemy_slots()/get_friendly_slots()).
var board: Control = null
## Optional named anchors: &"score", &"streak", ... -> Control.
var anchors: Dictionary = {}
var _units: Dictionary = {}   # uid -> {side, zone, index}


func _init(board_node: Control = null) -> void:
	board = board_node


func set_unit(uid: int, side: StringName, zone: StringName, index: int) -> void:
	_units[uid] = {"side": side, "zone": zone, "index": index}


func clear_units() -> void:
	_units.clear()


func has_unit(uid: int) -> bool:
	return _units.has(uid)


func unit_info(uid: int) -> Dictionary:
	return _units.get(uid, {})


## Reads every line of a MatchState (scripts/rules/match_state.gd): slot index = line order.
func sync_from_state(state: Object) -> void:
	_units.clear()
	var sides: Array = state.get(&"sides")
	for si: int in sides.size():
		var side_name: StringName = state.call(&"side_name", si)
		for z: int in 3:
			var zone_name: StringName = state.call(&"zone_name", z)
			var units: Array = sides[si].call(&"line", z)
			for i: int in units.size():
				set_unit(int(units[i].get(&"uid")), side_name, zone_name, i)


## Global canvas rect of a unit's slot; Rect2() when unknown or off screen.
## Explicit set_unit() entries win; otherwise the slot whose `slot_uid` (unit_slot.gd, p09)
## is this uid, so a board showing a MatchSnapshot needs no mapping at all.
func unit_rect(uid: int) -> Rect2:
	var info: Dictionary = _units.get(uid, {})
	if board == null or uid < 0:
		return Rect2()
	if info.is_empty():
		var slot: Control = find_slot(uid)
		return slot.get_global_rect() if slot != null else Rect2()
	var lane: Node = board.call(&"get_lane", info["zone"])
	if lane == null:
		return Rect2()
	var slots: Array = lane.call(&"get_friendly_slots") if info["side"] == &"player" else lane.call(&"get_enemy_slots")
	var index: int = info["index"]
	if index < 0 or index >= slots.size():
		return Rect2()
	return (slots[index] as Control).get_global_rect()


## The UnitSlot currently showing this uid (its `slot_uid`), or null.
func find_slot(uid: int) -> Control:
	if board == null or not board.has_method(&"get_lanes"):
		return null
	for lane: Node in board.call(&"get_lanes"):
		for slot: Node in lane.call(&"get_enemy_slots") + lane.call(&"get_friendly_slots"):
			if "slot_uid" in slot and int(slot.get(&"slot_uid")) == uid:
				return slot as Control
	return null


## Global canvas rect of a zone's lane; Rect2() when unknown.
func zone_rect(zone: StringName) -> Rect2:
	if board == null:
		return Rect2()
	var lane: Node = board.call(&"get_lane", zone)
	return (lane as Control).get_global_rect() if lane != null else Rect2()


## Global canvas rect of a named anchor (&"score" for MODE_SCORED pop-ups).
func anchor_rect(anchor: StringName) -> Rect2:
	var node: Control = anchors.get(anchor) as Control
	return node.get_global_rect() if node != null and is_instance_valid(node) else Rect2()
