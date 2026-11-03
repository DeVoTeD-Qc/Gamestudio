# test_hand_input.gd
# Purpose: p09 hand input against the real rules engine. Runs scenes/Match.tscn (its
#   MatchController starts the local test match: starter deck vs squad_rusher on Port Vasel)
#   at desktop 1280x720 and iPhone 844x390 @3x, and drives it only with InputEvents pushed
#   into the viewport (mouse events, which is also what touch arrives as):
#   tap-tap deploy, drag deploy, Operator placement, long-press and right-click inspector,
#   refusals with reasons (Supply, zone full, wrong phase) that never reach the engine, UNDO
#   and READY. Each deploy asserts the intent MatchState.submit() received and accepted.
# Author: UI/UX Agent (p09)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

var _saved_root_size: Vector2i = Vector2i.ZERO


# --- Tap-tap ------------------------------------------------------------------------------

func test_tap_card_then_lane_desktop() -> void:
	await _tap_tap_deploy(Layout.DESKTOP)


func test_tap_card_then_lane_phone() -> void:
	await _tap_tap_deploy(Layout.PHONE)


func _tap_tap_deploy(screen: Dictionary) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var label: String = screen["name"]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	assert_not_null(rc, "%s an affordable unit in the opening hand" % label)
	if rc == null:
		_despawn(vp)
		return
	var chip: Control = m.get_hand().get_card(rc.uid)
	await _tap(vp, _chip_point(m, chip))
	assert_eq(c.selection.get("uid", -1), rc.uid, "%s tap selects the card" % label)
	assert_eq(chip.theme_type_variation, &"HandCardSelected", "%s selected style" % label)
	for lane: Node in m.get_board().get_lanes():
		assert_eq(lane.target_state, &"valid", "%s %s highlighted as a valid target" % [label, lane.zone_id])
		assert_eq(lane.target_text, "DEPLOY HERE", "%s %s badge" % [label, lane.zone_id])
	# Second tap on the same card deselects; a third selects again.
	await _tap(vp, _chip_point(m, chip))
	assert_true(c.selection.is_empty(), "%s tapping the card again deselects" % label)
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	var lane: Control = m.get_board().get_lanes()[2]
	await _tap(vp, _row_point(lane))
	var last: Dictionary = c.intent_log.back() if not c.intent_log.is_empty() else {}
	assert_eq(last.get("intent", {}).get("type"), RulesIntent.PLAY_CARD, "%s engine got play_card" % label)
	assert_eq(last.get("intent", {}).get("card_uid"), rc.uid, "%s intent card uid" % label)
	assert_eq(last.get("intent", {}).get("zone"), 2, "%s intent zone = right" % label)
	assert_true(last.get("result", {}).get("ok", false), "%s engine accepted: %s" % [label, last.get("result")])
	var me: RulesSide = c.state.sides[0]
	assert_eq(me.plays.size(), 1, "%s one queued play" % label)
	assert_null_card(me.find_in_hand(rc.uid), "%s card left the hand" % label)
	assert_true(c.selection.is_empty(), "%s selection cleared after the play" % label)
	assert_eq(lane.target_state, &"none", "%s highlights cleared" % label)
	var queued: Node = _find_slot(lane.get_friendly_slots(), rc.uid)
	assert_not_null(queued, "%s queued unit shows in the right lane" % label)
	if queued != null:
		assert_true(queued.pending, "%s tagged PLAN" % label)
	assert_false(m.get_undo_button().disabled, "%s UNDO enabled" % label)
	if not m.compact:
		assert_true(String(m.get_undo_button().text).contains(rc.card.display_name), "%s UNDO names the play: %s" % [label, m.get_undo_button().text])
	else:
		assert_eq(m.get_undo_button().get_parent(), m.get_node("%MenuButton").get_parent(), "%s phone UNDO sits in the top bar" % label)
	_despawn(vp)


# --- Drag ---------------------------------------------------------------------------------

func test_drag_card_to_lane_desktop() -> void:
	await _drag_deploy(Layout.DESKTOP)


func test_drag_card_to_lane_phone() -> void:
	await _drag_deploy(Layout.PHONE)


func _drag_deploy(screen: Dictionary) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var label: String = screen["name"]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc == null:
		assert_not_null(rc, "%s an affordable unit" % label)
		_despawn(vp)
		return
	var from: Vector2 = _chip_point(m, m.get_hand().get_card(rc.uid))
	var lane: Control = m.get_board().get_lanes()[1]
	var to: Vector2 = _row_point(lane)
	_mouse(vp, from, true)
	await _frames(2)
	for i: int in range(1, 9):
		_motion(vp, from.lerp(to, i / 8.0))
		await _frames(1)
	await _frames(2)
	assert_true(m.has_drag_ghost(), "%s drag shows a ghost card" % label)
	assert_eq(lane.target_state, &"hover", "%s lane under the finger is highlighted" % label)
	assert_eq(m.get_board().get_lanes()[0].target_state, &"valid", "%s other lanes stay marked valid" % label)
	_mouse(vp, to, false)
	await _frames(3)
	assert_false(m.has_drag_ghost(), "%s ghost removed on drop" % label)
	var last: Dictionary = c.intent_log.back() if not c.intent_log.is_empty() else {}
	assert_eq(last.get("intent", {}).get("card_uid"), rc.uid, "%s dropped card sent to the engine" % label)
	assert_eq(last.get("intent", {}).get("zone"), 1, "%s dropped into mid" % label)
	assert_true(last.get("result", {}).get("ok", false), "%s engine accepted the drop" % label)
	assert_eq(c.state.sides[0].plays.size(), 1, "%s one queued play" % label)
	# A drop outside the board cancels and sends nothing.
	var other: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if other != null:
		var p: Vector2 = _chip_point(m, m.get_hand().get_card(other.uid))
		var log_size: int = c.intent_log.size()
		_mouse(vp, p, true)
		await _frames(1)
		_motion(vp, p + Vector2(0, -20))
		await _frames(1)
		_motion(vp, p + Vector2(40, -30))
		await _frames(1)
		_mouse(vp, p + Vector2(40, -30), false)
		await _frames(3)
		assert_eq(c.intent_log.size(), log_size, "%s drop on the hand sends no intent" % label)
		assert_true(c.selection.is_empty(), "%s drop outside the board cancels" % label)
	_despawn(vp)


# --- Operator -----------------------------------------------------------------------------

func test_place_operator_tap_tap_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	assert_true(c.state.sides[0].operator_can_deploy, "Round 1: Operator can be placed")
	var panel: Control = m.get_operator_panel()
	var r: Rect2 = panel.get_global_rect()
	await _tap(vp, r.position + Vector2(30, 20))  # the info column (name / caption)
	assert_eq(c.selection.get("kind"), &"operator", "tap on the panel selects the Operator")
	assert_eq(panel.theme_type_variation, &"OperatorSelected", "Operator panel selected style")
	assert_eq(m.get_board().get_lanes()[1].target_text, "PLACE HERE", "lanes offer placement")
	await _tap(vp, _row_point(m.get_board().get_lanes()[1]))
	var last: Dictionary = c.intent_log.back() if not c.intent_log.is_empty() else {}
	assert_eq(last.get("intent", {}).get("type"), RulesIntent.PLACE_OPERATOR, "engine got place_operator")
	assert_eq(last.get("intent", {}).get("zone"), 1, "placed in mid")
	assert_true(last.get("result", {}).get("ok", false), "placement accepted")
	assert_eq(c.state.projected_operator_zone(0), 1, "engine plans the Operator in mid")
	# Selecting it again now offers a Rotation to the adjacent flanks only.
	c.select_operator()
	await _frames(1)
	var lanes: Array[Node] = m.get_board().get_lanes()
	assert_eq(lanes[1].target_state, &"invalid", "mid: Operator is already there")
	assert_eq(lanes[0].target_text, "ROTATE HERE", "left offers a Rotation")
	_despawn(vp)


# --- Inspector ----------------------------------------------------------------------------

func test_long_press_opens_inspector_desktop() -> void:
	await _long_press_inspector(Layout.DESKTOP)


func test_long_press_opens_inspector_phone() -> void:
	await _long_press_inspector(Layout.PHONE)


func _long_press_inspector(screen: Dictionary) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var label: String = screen["name"]
	var rc: RulesCard = c.state.sides[0].hand[0]
	var p: Vector2 = _chip_point(m, m.get_hand().get_card(rc.uid))
	var inspector: Control = m.get_inspector()
	_mouse(vp, p, true)
	await _frames(2)
	assert_false(inspector.is_open(), "%s not open before the long-press time" % label)
	await tree.create_timer(PressGesture.LONG_PRESS_S + 0.15).timeout
	await _frames(2)
	assert_true(inspector.is_open(), "%s long-press opens the inspector" % label)
	_mouse(vp, p, false)
	await _frames(2)
	assert_true(inspector.is_open(), "%s stays open after the finger lifts" % label)
	assert_true(c.selection.is_empty(), "%s a long-press does not select the card" % label)
	assert_eq(c.intent_log.size(), 0, "%s a long-press sends nothing to the engine" % label)
	assert_true(inspector.get_card_scale() >= 0.8, "%s CardView at %.2fx (>= 0.8x)" % [label, inspector.get_card_scale()])
	assert_eq(inspector.get_node("%TitleLabel").text, rc.card.display_name, "%s inspects the pressed card" % label)
	assert_eq(inspector.get_card_view().data.get("name"), rc.card.display_name, "%s CardView shows it" % label)
	assert_eq(inspector.get_node("%RulesLabel").text, rc.card.text, "%s full rules text" % label)
	var expected: int = CardInfoKeywords.keywords(rc.card).size()
	assert_eq(inspector.get_node("%KeywordList").get_child_count(), expected * 2, "%s keyword lines" % label)
	assert_true(String(inspector.get_node("%StatusLabel").text).contains("Supply"), "%s cost / Supply status" % label)
	await _tap(vp, inspector.get_node("%CloseButton").get_global_rect().get_center())
	assert_false(inspector.is_open(), "%s CLOSE closes it" % label)
	_despawn(vp)


func test_right_click_inspects_and_tap_outside_closes_desktop() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var rc: RulesCard = c.state.sides[0].hand[1]
	var p: Vector2 = _chip_point(m, m.get_hand().get_card(rc.uid))
	_mouse(vp, p, true, MOUSE_BUTTON_RIGHT)
	await _frames(1)
	_mouse(vp, p, false, MOUSE_BUTTON_RIGHT)
	await _frames(2)
	var inspector: Control = m.get_inspector()
	assert_true(inspector.is_open(), "right-click opens the inspector at once")
	assert_eq(inspector.get_node("%TitleLabel").text, rc.card.display_name, "right-clicked card")
	await _tap(vp, Vector2(8, 8))
	assert_false(inspector.is_open(), "a tap outside the text panel closes it")
	assert_true(c.selection.is_empty(), "closing does not select anything")
	_despawn(vp)


func test_long_press_unit_on_board_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc == null:
		assert_not_null(rc, "an affordable unit")
		_despawn(vp)
		return
	c.select_card(rc.uid)
	c.play_at(0)
	await _frames(2)
	var slot: Node = _find_slot(m.get_board().get_lanes()[0].get_friendly_slots(), rc.uid)
	assert_not_null(slot, "queued unit slot")
	if slot == null:
		_despawn(vp)
		return
	var p: Vector2 = (slot as Control).get_global_rect().get_center()
	_mouse(vp, p, true)
	await tree.create_timer(PressGesture.LONG_PRESS_S + 0.15).timeout
	_mouse(vp, p, false)
	await _frames(2)
	assert_true(m.get_inspector().is_open(), "long-press on a queued unit opens the inspector")
	assert_eq(m.get_inspector().get_node("%TitleLabel").text, rc.card.display_name, "inspects that unit")
	_despawn(vp)


# --- Refusals -------------------------------------------------------------------------------

func test_refused_not_enough_supply() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	c.state.sides[0].supply = 0
	c.refresh()
	await _frames(1)
	var rc: RulesCard = _first_costing(c, 1)
	if rc == null:
		assert_not_null(rc, "a card that costs Supply")
		_despawn(vp)
		return
	var chip: Control = m.get_hand().get_card(rc.uid)
	assert_eq(chip.theme_type_variation, &"HandCardDim", "unaffordable card is dimmed")
	await _tap(vp, _chip_point(m, chip))
	var lane: Control = m.get_board().get_lanes()[0]
	assert_eq(lane.target_state, &"invalid", "lanes refuse the card")
	assert_eq(lane.target_text, "NEED %d SUPPLY" % rc.card.cost, "lane badge gives the reason")
	await _tap(vp, _row_point(lane))
	assert_true(m.get_toast_text().contains("Not enough Supply"), "toast: %s" % m.get_toast_text())
	assert_eq(c.intent_log.size(), 0, "refused play never reaches the engine")
	assert_true(c.state.sides[0].plays.is_empty(), "nothing queued")
	assert_false(c.selection.is_empty(), "card stays selected after a refusal")
	_despawn(vp)


func test_refused_zone_full() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc == null:
		assert_not_null(rc, "an affordable unit")
		_despawn(vp)
		return
	# Fill Left with four units already on the board.
	for i: int in c.state.config.zone_capacity:
		var u: RulesUnit = c.state.create_unit(0, rc.card)
		c.state.put_in_line(u, 0)
	c.refresh()
	await _frames(1)
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	var lanes: Array[Node] = m.get_board().get_lanes()
	assert_eq(lanes[0].target_state, &"invalid", "full zone is greyed out")
	assert_eq(lanes[0].target_text, "ZONE FULL", "full zone badge")
	assert_eq(lanes[1].target_state, &"valid", "other zones still valid")
	await _tap(vp, _row_point(lanes[0]))
	assert_true(m.get_toast_text().begins_with("Zone full"), "toast: %s" % m.get_toast_text())
	assert_eq(c.intent_log.size(), 0, "refused play never reaches the engine")
	# The engine agrees with the presenter.
	assert_false(c.state.submit(0, RulesIntent.play_card(rc.uid, 0))["ok"], "engine refuses it too")
	_despawn(vp)


func test_refused_wrong_phase() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc == null:
		assert_not_null(rc, "an affordable unit")
		_despawn(vp)
		return
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	c.state.phase = MatchState.Phase.REVEAL
	await _tap(vp, _row_point(m.get_board().get_lanes()[1]))
	assert_true(m.get_toast_text().begins_with("Wrong phase"), "toast: %s" % m.get_toast_text())
	assert_eq(c.intent_log.size(), 0, "refused play never reaches the engine")
	_despawn(vp)


# --- Undo / READY ---------------------------------------------------------------------------

func test_undo_then_ready_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var me: RulesSide = c.state.sides[0]
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc == null:
		assert_not_null(rc, "an affordable unit")
		_despawn(vp)
		return
	var supply_before: int = me.supply
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	await _tap(vp, _row_point(m.get_board().get_lanes()[0]))
	assert_eq(me.plays.size(), 1, "deployed")
	assert_false(m.get_undo_button().disabled, "UNDO enabled after a play")
	await _tap(vp, m.get_undo_button().get_global_rect().get_center())
	assert_true(me.plays.is_empty(), "UNDO took the play back")
	assert_eq(me.supply, supply_before, "Supply refunded")
	assert_not_null(me.find_in_hand(rc.uid), "card back in hand")
	assert_true(m.get_undo_button().disabled, "UNDO disabled with nothing to undo")
	# Place the Operator and deploy the unit again, then READY.
	c.select_operator()
	c.play_at(1)
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	await _tap(vp, _row_point(m.get_board().get_lanes()[0]))
	assert_eq(me.plays.size(), 2, "Operator + unit queued")
	await _tap(vp, m.get_ready_button().get_global_rect().get_center())
	await _frames(2)
	assert_eq(c.state.round_number, 2, "READY resolved Round 1 and started Round 2")
	assert_eq(c.state.phase, MatchState.Phase.DEPLOY, "back in Deploy")
	assert_not_null(me.find_unit(rc.uid), "the unit arrived on the board")
	var slot: Node = _find_slot(m.get_board().get_lanes()[0].get_friendly_slots(), rc.uid)
	assert_true(slot != null and not slot.pending, "the lane shows it as a unit, not PLAN")
	assert_eq(me.operator_unit.zone, 1, "Operator arrived in mid")
	_despawn(vp)


# --- Helpers ----------------------------------------------------------------------------------

const CardInfoKeywords: GDScript = preload("res://scripts/ui/card_info.gd")


func assert_null_card(value: Variant, message: String) -> void:
	assert_true(value == null, message)


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	assert_not_null(c.state, "%s live match started" % screen["name"])
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	vp.push_input(e)


func _motion(vp: SubViewport, pos: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)


## Middle of the part of a hand chip that isn't covered by the next chip.
func _chip_point(m: Control, chip: Control) -> Vector2:
	var r: Rect2 = chip.get_global_rect()
	var cards: Array[Node] = m.get_hand().get_cards()
	var i: int = cards.find(chip)
	var visible_w: float = r.size.x
	if i >= 0 and i + 1 < cards.size():
		visible_w = minf(visible_w, (cards[i + 1] as Control).get_global_rect().position.x - r.position.x)
	return Vector2(r.position.x + visible_w * 0.5, r.position.y + r.size.y * 0.5)


## Centre of a lane's friendly row (the deploy target).
func _row_point(lane: Control) -> Vector2:
	return (lane.get_node("%FriendlyRow") as Control).get_global_rect().get_center()


func _affordable(c: Node, card_type: int) -> RulesCard:
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.card_type == card_type and rc.card.cost <= me.supply:
			return rc
	return null


func _first_costing(c: Node, min_cost: int) -> RulesCard:
	for rc: RulesCard in c.state.sides[0].hand:
		if rc.card.cost >= min_cost:
			return rc
	return null


func _find_slot(slots: Array[Node], uid: int) -> Node:
	for slot: Node in slots:
		if slot.kind == slot.Kind.UNIT and slot.slot_uid == uid:
			return slot
	return null
