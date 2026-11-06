# test_hand_input.gd
# Purpose: p09 hand input against the real rules engine. Runs scenes/Match.tscn (its
#   MatchController starts the local test match: starter deck vs squad_rusher on Port Vasel)
#   at desktop 1280x720 and iPhone 844x390 @3x, and drives it only with InputEvents pushed
#   into the viewport (mouse events, which is also what touch arrives as):
#   tap-tap deploy, drag deploy, Operator placement, long-press and right-click inspector,
#   refusals with reasons (Supply, zone full, wrong phase) that never reach the engine, UNDO
#   and READY. Each deploy asserts the intent MatchState.submit() received and accepted.
#   f02: Operator panel items (Frag on a lane, Sidearm on an enemy unit, blocked buttons with
#   their reason), killstreak call-in from the Streak Tray, the Round 1 mulligan panel (phone
#   sizes), and full rounds where the p07 AI plays (deterministic per seed) with the p14
#   feedback and the p16 EventBus signals.
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
		assert_eq(lane.target_text, "PLAY HERE", "%s %s badge" % [label, lane.zone_id])
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
	# kc-board2: UNDO sits in the hand tray beside READY; its tooltip names the play.
	assert_true(String(m.get_undo_button().tooltip_text).contains(rc.card.display_name), "%s UNDO names the play: %s" % [label, m.get_undo_button().tooltip_text])
	assert_eq(m.get_undo_button().get_parent(), m.get_tray(), "%s UNDO sits in the hand tray" % label)
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
	# kc-board2: while the Operator can deploy, the strip's OPERATOR badge is its handle.
	await _tap(vp, m.get_operator_handle().get_global_rect().get_center())
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
	var rules_text: String = inspector.get_node("%RulesLabel").text
	assert_true(rules_text == rc.card.text or (rules_text == "" and CardInfoKeywords.keywords(rc.card).size() > 0),
			"%s full rules text (or keyword lines for keyword-only text): '%s'" % [label, rules_text])
	# kc-syn-ui: printed keyword lines, then the copy's synergy lines (keyword, trait, level).
	var expected: int = CardInfoKeywords.keywords(rc.card).size() + c.synergy_lines(rc.card, rc.level, 0, null).size()
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
	assert_eq(lanes[0].target_text, "COLUMN FULL", "full zone badge")
	assert_eq(lanes[1].target_state, &"valid", "other zones still valid")
	await _tap(vp, _row_point(lanes[0]))
	assert_true(m.get_toast_text().begins_with("Column full"), "toast: %s" % m.get_toast_text())
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
	me.supply += c.state.operator_cost()  # kc-syn: the Operator's placement costs Supply
	c.select_operator()
	c.play_at(1)
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	await _tap(vp, _row_point(m.get_board().get_lanes()[0]))
	assert_eq(me.plays.size(), 2, "Operator + unit queued")
	await _tap(vp, m.get_ready_button().get_global_rect().get_center())
	assert_true(c.is_busy(), "the round's feedback is playing")
	await _until_presented(c)
	assert_false(c.is_busy(), "feedback finished")
	assert_eq(c.state.round_number, 2, "READY resolved Round 1 and started Round 2")
	assert_eq(c.state.phase, MatchState.Phase.DEPLOY, "back in Deploy")
	var arrived: bool = c.state.events.any(func(e: Dictionary) -> bool:
		return e["type"] == RulesEvent.UNIT_ARRIVED and int(e.get("uid", -1)) == rc.uid)
	assert_true(arrived, "the unit arrived on the board")
	# The AI plays now, so the unit may not survive the firefight; if it did, it is no PLAN any more.
	var slot: Node = _find_slot(m.get_board().get_lanes()[0].get_friendly_slots(), rc.uid)
	if me.find_unit(rc.uid) != null:
		assert_true(slot != null and not slot.pending, "the lane shows it as a unit, not PLAN")
	else:
		assert_null_card(slot, "an eliminated unit has no slot after the round")
	assert_eq(me.operator_unit.zone, 1, "Operator arrived in mid")
	_despawn(vp)


# --- f02: loadout items ------------------------------------------------------------------------

func test_frag_targets_a_lane_then_goes_on_cooldown_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var panel: Control = m.get_operator_panel()
	var frag: Button = panel.get_item_button(&"frag_grenade")
	assert_not_null(frag, "Frag button")
	assert_true(frag.disabled, "Frag disabled while the Operator is off the board")
	assert_true(frag.text.contains("NO OP"), "button says why: %s" % frag.text)
	await _tap(vp, await _item_point(vp, m, &"frag_grenade"))
	assert_true(m.get_toast_text().contains("Operator is not on the board"), "tap on a disabled button toasts the reason: %s" % m.get_toast_text())
	assert_true(c.selection.is_empty(), "nothing selected")
	c.select_operator()
	c.play_at(1)
	await _frames(2)
	frag = panel.get_item_button(&"frag_grenade")
	assert_false(frag.disabled, "Frag usable with the Operator planned in Mid")
	await _tap(vp, await _item_point(vp, m, &"frag_grenade"))
	assert_eq(c.selection, {"kind": &"item", "id": &"frag_grenade"}, "tap selects Frag for targeting")
	assert_true(panel.get_item_button(&"frag_grenade").button_pressed, "Frag button shows as pressed")
	for lane: Node in m.get_board().get_lanes():
		assert_eq([lane.target_state, lane.target_text], [&"valid", "THROW HERE"], "%s offers the throw (Mid Operator reaches all)" % lane.zone_id)
	await _tap(vp, _row_point(m.get_board().get_lanes()[2]))
	var last: Dictionary = c.intent_log.back() if not c.intent_log.is_empty() else {}
	assert_eq(last.get("intent", {}), RulesIntent.use_item(&"frag_grenade", 2), "engine got use_item(frag, right)")
	assert_true(last.get("result", {}).get("ok", false), "accepted")
	assert_true(m.get_toast_text().contains("Frag Grenade queued on column C"), "toast: %s" % m.get_toast_text())
	frag = panel.get_item_button(&"frag_grenade")
	assert_true(frag.disabled, "Frag now on cooldown")
	assert_true(frag.text.contains("CD 3"), "cooldown shown: %s" % frag.text)
	await _tap(vp, await _item_point(vp, m, &"frag_grenade"))
	assert_true(m.get_toast_text().contains("cooldown: ready in 3 rounds"), "toast: %s" % m.get_toast_text())
	# UNDO gives the cooldown back.
	c.undo()
	await _frames(2)
	assert_false(panel.get_item_button(&"frag_grenade").disabled, "undo refunds the cooldown")
	_despawn(vp)


func test_sidearm_taps_an_enemy_in_the_operator_zone_desktop() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var foe_card: CardData = CardDB.get_card(&"rifleman")
	var near: RulesUnit = st.create_unit(1, foe_card)
	st.put_in_line(near, 0)
	var far: RulesUnit = st.create_unit(1, foe_card)
	st.put_in_line(far, 2)
	st.sides[0].supply += st.operator_cost()  # kc-syn: the Operator's placement costs Supply
	c.select_operator()
	c.play_at(0)
	await _frames(2)
	var panel: Control = m.get_operator_panel()
	var sidearm: Button = panel.get_item_button(&"p12_sidearm")
	assert_false(sidearm.disabled, "Sidearm usable: an enemy in the Operator's zone")
	assert_true(sidearm.text.contains("1 SUP"), "costs 1 Supply: %s" % sidearm.text)
	await _tap(vp, await _item_point(vp, m, &"p12_sidearm"))
	assert_eq(c.selection.get("id"), &"p12_sidearm", "Sidearm selected")
	var left: Node = m.get_board().get_lanes()[0]
	var right: Node = m.get_board().get_lanes()[2]
	var near_slot: Node = _find_slot(left.get_enemy_slots(), near.uid)
	var far_slot: Node = _find_slot(right.get_enemy_slots(), far.uid)
	assert_true(near_slot != null and near_slot.is_target, "the enemy in Left is pickable")
	assert_true(far_slot != null and not far_slot.is_target, "the enemy in Right is out of range")
	if far_slot != null:
		await _tap(vp, (far_slot as Control).get_global_rect().get_center())
		assert_eq(c.intent_log.size(), 1, "tapping an out-of-range enemy sends nothing (only the placement)")
	if near_slot != null:
		await _tap(vp, (near_slot as Control).get_global_rect().get_center())
	var last: Dictionary = c.intent_log.back()
	assert_eq(last["intent"], RulesIntent.use_item(&"p12_sidearm", -1, near.uid), "engine got use_item(sidearm, target)")
	assert_true(last["result"]["ok"], "Sidearm accepted")
	sidearm = panel.get_item_button(&"p12_sidearm")
	assert_true(sidearm.disabled and sidearm.text.contains("USED"), "once per round: %s" % sidearm.text)
	_despawn(vp)


func test_killstreak_in_tray_is_called_in_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var panel: Control = m.get_operator_panel()
	var mortar: Button = panel.get_item_button(&"mortar_barrage")
	assert_true(mortar.disabled, "Mortar locked before it is earned")
	assert_true(mortar.text.contains("AT 3"), "threshold shown: %s" % mortar.text)
	await _tap(vp, await _item_point(vp, m, &"mortar_barrage"))
	assert_true(m.get_toast_text().contains("not earned yet: reach a streak of 3"), "toast: %s" % m.get_toast_text())
	StreakTracker.grant(c.state, 0, &"mortar_barrage")
	StreakTracker.grant(c.state, 0, &"recon_drone")
	c.refresh()
	await _frames(1)
	mortar = panel.get_item_button(&"mortar_barrage")
	assert_false(mortar.disabled, "in the Streak Tray: enabled")
	assert_true(mortar.text.contains("CALL IN"), "tray state: %s" % mortar.text)
	await _tap(vp, await _item_point(vp, m, &"mortar_barrage"))
	assert_eq(c.selection.get("id"), &"mortar_barrage", "Mortar selected for a zone")
	assert_eq(m.get_board().get_lanes()[1].target_text, "CALL IN HERE", "lanes offer the call-in")
	await _tap(vp, _row_point(m.get_board().get_lanes()[1]))
	assert_eq(c.intent_log.back()["intent"], RulesIntent.use_item(&"mortar_barrage", 1), "use_item(mortar, mid)")
	assert_false(&"mortar_barrage" in c.state.sides[0].streak_tray, "taken from the tray")
	assert_true(panel.get_item_button(&"mortar_barrage").text.contains("AT 3"), "back to locked")
	# Recon Drone needs no target: one tap queues it.
	await _tap(vp, await _item_point(vp, m, &"recon_drone"))
	assert_eq(c.intent_log.back()["intent"], RulesIntent.use_item(&"recon_drone"), "Recon Drone queued at once")
	assert_true(c.intent_log.back()["result"]["ok"], "accepted")
	assert_true(c.selection.is_empty(), "nothing left selected")
	_despawn(vp)


# --- f02: mulligan ---------------------------------------------------------------------------------

func test_mulligan_panel_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE, false)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	assert_true(c.is_mulligan_open(), "Round 1 opens the mulligan panel")
	var panel: Control = m.get_mulligan_panel()
	var me: RulesSide = c.state.sides[0]
	var buttons: Array[Node] = panel.get_card_buttons()
	assert_eq(buttons.size(), me.hand.size(), "one button per card")
	var pt: float = Layout.points_per_px(Layout.PHONE)
	var all: Array[Node] = buttons.duplicate()
	all.append_array([panel.get_keep_button(), panel.get_confirm_button()])
	for b: Node in all:
		var r: Rect2 = (b as Control).get_global_rect()
		assert_true(r.size.y * pt >= Layout.MIN_TAP_PT - Layout.EPS, "tap target %.1f pt tall" % (r.size.y * pt))
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(r), "on screen: %s" % r)
		var font_pt: float = (b as Control).get_theme_font_size(&"font_size") * pt
		assert_true(font_pt >= Layout.MIN_BODY_PT, "button text %.1f pt" % font_pt)
	for l: Label in panel.get_important_labels():
		assert_true(l.get_theme_font_size(&"font_size") * pt >= Layout.MIN_BODY_PT, "label text >= 11 pt")
	# A tap on the board under the panel does nothing.
	await _tap(vp, _row_point(m.get_board().get_lanes()[0]))
	assert_eq(c.intent_log.size(), 0, "board is blocked while the panel is open")
	var back: Array[int] = [int(buttons[0].get_meta(&"uid")), int(buttons[1].get_meta(&"uid"))]
	await _tap(vp, (buttons[0] as Control).get_global_rect().get_center())
	await _tap(vp, (buttons[1] as Control).get_global_rect().get_center())
	assert_eq(panel.get_picked(), back, "two cards marked")
	assert_eq(panel.get_confirm_button().text, "REDRAW 2", "confirm counts them")
	var size_before: int = me.hand.size()
	await _tap(vp, panel.get_confirm_button().get_global_rect().get_center())
	await _frames(2)
	assert_false(c.is_mulligan_open(), "panel closed")
	assert_eq(me.hand.size(), size_before, "same hand size")
	assert_eq(me.mulligans_left, 0, "the free mulligan is spent")
	assert_eq(c.state.events.filter(func(e: Dictionary) -> bool:
		return e["type"] == RulesEvent.MULLIGAN and e["side"] == &"player").size(), 1, "engine mulligan")
	assert_true(m.get_toast_text().contains("Put back 2 cards"), "toast: %s" % m.get_toast_text())
	_despawn(vp)


func test_mulligan_keep_hand_desktop() -> void:
	var s: Array = await _spawn(Layout.DESKTOP, false)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var hand_before: Array = c.state.sides[0].hand.map(func(rc: RulesCard) -> int: return rc.uid)
	assert_true(m.get_mulligan_panel().get_confirm_button().disabled, "REDRAW disabled with nothing marked")
	await _tap(vp, m.get_mulligan_panel().get_keep_button().get_global_rect().get_center())
	await _frames(2)
	assert_false(c.is_mulligan_open(), "KEEP HAND closes it")
	assert_eq(c.state.sides[0].hand.map(func(rc: RulesCard) -> int: return rc.uid), hand_before, "hand unchanged")
	_despawn(vp)


# --- f02: the enemy AI plays ---------------------------------------------------------------------

func test_full_rounds_with_the_ai_phone() -> void:
	var counts: Dictionary = {"summary": 0, "deployed_enemy": 0, "deployed_player": 0, "round_ended": 0}
	var bus: Node = tree.root.get_node("EventBus")
	var on_summary: Callable = func(_r: int, _s: int, _h: int) -> void: counts["summary"] += 1
	var on_deployed: Callable = func(side: StringName, _id: StringName, _z: StringName) -> void:
		counts["deployed_" + String(side)] += 1
	var on_round_ended: Callable = func(_r: int, _p: int, _e: int) -> void:
		assert_eq(counts["summary"], counts["round_ended"] + 1, "round_summary comes just before round_ended")
		counts["round_ended"] += 1
	bus.round_summary.connect(on_summary)
	bus.card_deployed.connect(on_deployed)
	bus.round_ended.connect(on_round_ended)
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var foe: RulesSide = c.state.sides[1]
	assert_not_null(c.enemy_ai_player, "default planner is the p07 AI")
	assert_false(foe.plays.is_empty(), "the AI committed its Deploy before the player")
	assert_true(foe.ready, "the AI is READY")
	assert_eq(c.enemy_ai_player.last_rejected, [] as Array[Dictionary], "the engine accepted every AI intent")
	var dots: PackedInt32Array = c.state.red_dots(0)
	assert_true(dots[0] + dots[1] + dots[2] > 0, "red dots show the AI's deployments")
	var incoming: int = 0
	for lane: Node in m.get_board().get_lanes():
		incoming += lane.get_enemy_slots().filter(func(n: Node) -> bool: return n.kind == n.Kind.INCOMING).size()
	assert_eq(incoming, dots[0] + dots[1] + dots[2], "lanes show them as incoming")
	var ai_first: Array[Dictionary] = c.enemy_ai_player.last_intents.duplicate()
	c.select_operator()
	c.play_at(1)
	var rc: RulesCard = _affordable(c, DataEnums.CardType.UNIT)
	if rc != null:
		c.select_card(rc.uid)
		c.play_at(1)
	var fx: Control = m.get_fx()
	fx.clear_log()
	await _tap(vp, m.get_ready_button().get_global_rect().get_center())
	await _frames(2)
	assert_true(c.is_busy() and fx.is_playing(), "the round plays as feedback")
	await _until_presented(c)
	assert_eq(c.state.round_number, 2, "Round 2")
	# kc-syn: with the Operator's Supply cost, a Round 1 AI may only place its Operator.
	var enemy_revealed: int = c.state.events.filter(func(e: Dictionary) -> bool:
		return e["type"] in [RulesEvent.CARD_REVEALED, RulesEvent.OPERATOR_PLACED] and e["side"] == &"enemy" and int(e["round"]) == 1).size()
	assert_true(enemy_revealed > 0, "the AI's cards were revealed")
	var shots: int = c.state.events.filter(func(e: Dictionary) -> bool:
		return e["type"] == RulesEvent.SHOT_FIRED and int(e["round"]) == 1).size()
	print("     [f02 AI round 1] shots %d, enemy reveals %d, fx %s" % [shots, enemy_revealed, fx.logged_kinds()])
	if shots > 0:
		assert_true(&"tracer" in fx.logged_kinds(), "shots played as tracers")
	else:
		assert_false(fx.logged_kinds().is_empty(), "the round played some feedback")
	assert_false(foe.plays.is_empty(), "the AI planned Round 2 too")
	assert_eq(c.enemy_ai_player.last_rejected, [] as Array[Dictionary], "Round 2: no refused AI intent")
	# Round 2 with a fast-forward: a tap during the feedback skips it.
	await _tap(vp, m.get_ready_button().get_global_rect().get_center())
	var t0: int = Time.get_ticks_msec()
	await _tap(vp, Vector2(vp.size) * 0.5)
	await _until_presented(c)
	assert_true(Time.get_ticks_msec() - t0 < 3000, "a tap fast-forwards the feedback")
	assert_eq(c.state.round_number, 3, "Round 3")
	assert_eq(counts["round_ended"], 2, "two round_ended")
	assert_eq(counts["summary"], 2, "two round_summary")
	assert_true(counts["deployed_enemy"] > 0, "enemy card_deployed at reveal")
	bus.round_summary.disconnect(on_summary)
	bus.card_deployed.disconnect(on_deployed)
	bus.round_ended.disconnect(on_round_ended)
	_despawn(vp)
	# Deterministic: the same seed gives the same AI plan.
	var s2: Array = await _spawn(Layout.PHONE)
	assert_eq(s2[2].enemy_ai_player.last_intents, ai_first, "same seed, same AI Round 1")
	_despawn(s2[0])


# --- Helpers ----------------------------------------------------------------------------------

const CardInfoKeywords: GDScript = preload("res://scripts/ui/card_info.gd")


func assert_null_card(value: Variant, message: String) -> void:
	assert_true(value == null, message)


## Spawns Match.tscn; the Round 1 mulligan is kept unless `keep_hand` is false.
func _spawn(screen: Dictionary, keep_hand: bool = true) -> Array:
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
	if keep_hand and c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


## Waits until the resolved round has played (FeedbackDirector) and the next Deploy is up.
func _until_presented(c: Node, max_s: float = 30.0) -> void:
	var t0: int = Time.get_ticks_msec()
	while c.is_busy() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await _frames(1)
	await _frames(2)


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
	# kc-board2: a grid; only a card further along the SAME row can cover this one.
	if i >= 0 and i + 1 < cards.size():
		var nxt: Rect2 = (cards[i + 1] as Control).get_global_rect()
		if absf(nxt.position.y - r.position.y) < 1.0 and nxt.position.x > r.position.x:
			visible_w = minf(visible_w, nxt.position.x - r.position.x)
	return Vector2(r.position.x + visible_w * 0.5, r.position.y + r.size.y * 0.5)


## kc-board2: the item / killstreak tiles live in the STREAK flyout. Opens it with a tap on its
## badge (if closed) and returns the centre of the item's button.
func _item_point(vp: SubViewport, m: Control, item_id: StringName) -> Vector2:
	if m.flyout_key != &"streak":
		await _tap(vp, m.get_badge(&"streak").get_global_rect().get_center())
		await _frames(2)
	var b: Button = m.get_operator_panel().get_item_button(item_id)
	assert_true(b != null and b.is_visible_in_tree(), "%s tile shows in the STREAK flyout" % item_id)
	return b.get_global_rect().get_center() if b != null else Vector2.ZERO


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
