# test_recap_dismiss.gd
# Purpose: kc-recap-dismiss (head: "the recap saying on screen made me press ready to like skip it
#   and it ended my turn"). The round recap panel can never cause an accidental action:
#   - a tap on READY while it shows only closes it (the turn does not end); the next tap is READY;
#   - a tap on a hand card while it shows only closes it (nothing gets selected);
#   - a drag from a hand card closes it and still deploys (the press is handed back);
#   - it hides itself after AUTO_HIDE_S, paused while a mouse hovers it, not by touch;
#   - long press / right click on it shows the scoring rule and keeps it up a little longer;
#   - it says it is dismissable ("tap to continue" and the shrinking timer line).
#   Driven by InputEvents pushed into a SubViewport running scenes/Match.tscn (desktop 1280x720).
# Author: UI/UX Agent (kc-recap-dismiss)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const RECAP: Dictionary = {
	"title": "ROUND 1 · FIRST TO 6",
	"rows": [
		{"letter": "A", "owner": &"player", "text": "you 2 vs 0 left · you +1"},
		{"letter": "B", "owner": &"contested", "text": "you 1 vs 1 left · even, no point"},
		{"letter": "C", "owner": &"empty", "text": "nobody left · no point"},
	],
	"score": "Score: you 1, rival 0.",
	"plain": "Round 1: you +1 (1-0).",
}

var _saved_root_size: Vector2i = Vector2i.ZERO


func test_tap_on_ready_only_closes_the_recap() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var recap: Control = m.get_round_recap()
	m.show_round_recap(RECAP, "Round 1: play cards, then READY.")
	await _frames(2)
	assert_true(recap.is_open(), "the recap is up")
	var ready_at: Vector2 = m.get_ready_button().get_global_rect().get_center()
	await _tap(vp, ready_at)
	assert_false(recap.is_open(), "the tap on READY closed the recap")
	assert_false(c.state.sides[0].ready, "the tap that closed the recap did not end the turn")
	assert_false(c.is_busy(), "no round is resolving")
	assert_eq(c.state.round_number, 1, "still Round 1")
	await _tap(vp, ready_at)
	assert_true(c.state.sides[0].ready or c.is_busy() or c.state.round_number > 1, "the next tap on READY ends the turn")
	_despawn(vp)


func test_tap_on_a_card_only_closes_the_recap() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var rc: RulesCard = c.state.sides[0].hand[0]
	c.state.sides[0].supply = maxi(c.state.sides[0].supply, rc.card.cost)  # kc-r2-fixes: affordable, so it stays selected
	c.refresh()
	await _frames(2)
	m.show_round_recap(RECAP, "")
	await _frames(2)
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	assert_false(m.get_round_recap().is_open(), "closed")
	assert_true(c.selection.is_empty(), "the closing tap selected nothing")
	await _tap(vp, _chip_point(m, m.get_hand().get_card(rc.uid)))
	assert_eq(c.selection.get("uid", -1), rc.uid, "the next tap selects the card")
	_despawn(vp)


func test_drag_closes_the_recap_and_still_deploys() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var me: RulesSide = c.state.sides[0]
	var rc: RulesCard = null
	for h: RulesCard in me.hand:
		if h.card.card_type == DataEnums.CardType.UNIT and h.card.cost <= me.supply:
			rc = h
			break
	assert_not_null(rc, "an affordable unit")
	if rc == null:
		_despawn(vp)
		return
	m.show_round_recap(RECAP, "")
	await _frames(2)
	var from: Vector2 = _chip_point(m, m.get_hand().get_card(rc.uid))
	var to: Vector2 = (m.get_board().get_lanes()[1].get_node("%FriendlyRow") as Control).get_global_rect().get_center()
	_mouse(vp, from, true)
	await _frames(2)
	assert_false(m.get_round_recap().is_open(), "the press closed the recap")
	for i: int in range(1, 9):
		_motion(vp, from.lerp(to, i / 8.0))
		await _frames(1)
	await _frames(2)
	assert_true(m.has_drag_ghost(), "the drag started after all")
	_mouse(vp, to, false)
	await _frames(3)
	assert_eq(me.plays.size(), 1, "the dragged card deployed")
	_despawn(vp)


func test_auto_hides_after_the_timeout() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var recap: Control = m.get_round_recap()
	m.show_round_recap(RECAP, "")
	await _frames(1)
	assert_true(absf(recap.time_left - recap.AUTO_HIDE_S) < 0.2, "the clock starts at about 4 s")
	assert_true(recap.AUTO_HIDE_S >= 3.0 and recap.AUTO_HIDE_S <= 5.0, "about 4 s")
	var close: Label = recap.find_child("CloseMark", true, false)
	assert_true(close != null and "tap to continue" in close.text, "it says it is dismissable")
	recap.advance(recap.AUTO_HIDE_S - 0.5)
	assert_true(recap.is_open(), "still up before the timeout")
	recap.advance(0.6)
	assert_false(recap.is_open(), "hid itself after the timeout")
	# Real time too: the frame loop runs the same clock.
	m.show_round_recap(RECAP, "")
	var t0: int = Time.get_ticks_msec()
	while recap.is_open() and Time.get_ticks_msec() - t0 < 8000:
		await _frames(1)
	assert_false(recap.is_open(), "the frame loop hid it")
	assert_true(Time.get_ticks_msec() - t0 >= int((recap.AUTO_HIDE_S - 0.5) * 1000.0), "not before its time")
	# A real mouse over it pauses the clock; a finger (emulated mouse) does not.
	m.show_round_recap(RECAP, "")
	await _frames(1)
	var mid: Vector2 = recap.get_global_rect().get_center()
	_motion(vp, mid, false)
	await _frames(1)
	assert_true(recap.is_paused(), "a hovering mouse pauses it")
	recap.advance(10.0)
	assert_true(recap.is_open(), "paused while hovered")
	_motion(vp, mid + Vector2(0, -400), false)
	await _frames(1)
	recap.advance(recap.AUTO_HIDE_S + 0.1)
	assert_false(recap.is_open(), "the clock runs again once the mouse leaves")
	m.show_round_recap(RECAP, "")
	await _frames(1)
	var touch: InputEventMouseMotion = InputEventMouseMotion.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.position = mid
	touch.global_position = mid
	vp.push_input(touch)
	await _frames(1)
	assert_false(recap.is_paused(), "a finger never pauses it")
	_despawn(vp)


func test_long_press_shows_the_rule_then_goes() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var recap: Control = m.get_round_recap()
	m.show_round_recap(RECAP, "")
	await _frames(2)
	var at: Vector2 = recap.get_global_rect().get_center()
	_mouse(vp, at, true)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await _frames(1)
	_mouse(vp, at, false)
	await _frames(2)
	var rule: Label = recap.find_child("RecapRule", true, false)
	assert_true(recap.is_open() and rule.visible, "long press shows the scoring rule")
	assert_true(recap.time_left > recap.AUTO_HIDE_S, "and keeps it up long enough to read")
	_motion(vp, at + Vector2(0, -400), false)  # the mouse leaves (hover pauses the clock)
	await _frames(1)
	recap.advance(recap.INSPECT_HOLD_S + 0.1)
	assert_false(recap.is_open(), "then it goes by itself")
	assert_false(c.state.sides[0].ready, "nothing else happened")
	_despawn(vp)


# --- helpers ----------------------------------------------------------------------------------

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
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	afford_a_unit(c)
	await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)


func _motion(vp: SubViewport, pos: Vector2, held: bool = true) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)


func _chip_point(m: Control, chip: Control) -> Vector2:
	var r: Rect2 = chip.get_global_rect()
	var cards: Array[Node] = m.get_hand().get_cards()
	var i: int = cards.find(chip)
	var visible_w: float = r.size.x
	if i >= 0 and i + 1 < cards.size():
		var nxt: Rect2 = (cards[i + 1] as Control).get_global_rect()
		if absf(nxt.position.y - r.position.y) < 1.0 and nxt.position.x > r.position.x:
			visible_w = minf(visible_w, nxt.position.x - r.position.x)
	return Vector2(r.position.x + visible_w * 0.5, r.position.y + r.size.y * 0.5)
