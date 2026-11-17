# test_feedback_nov17_answers.gd
# Purpose: kc-feedback-2, the studio head's answers to the 17 Nov 2026 open questions:
#   1. "Yes, bigger bar, take space from the middle row": the score race over the board is clearly bigger
#      (taller bar, segments, numbers, "TO 6", "+N"), the banners are back to 228x57 (phone) / 304x76
#      (desktop) with a 43 pt slot pitch, and the thinner objective row stays readable and inspectable
#      (short tiles lay the two sides' Field chips side by side); nothing overlaps at 844x390, 390x844
#      and 1280x720.
#   3. "Yes, flash it": after each round's playback the LOG badge flashes (2 pulses, ~1.2 s, no sound),
#      never during a tip or overlay, never blocking input; reduced motion gets a steady highlight.
# Author: UI/UX Agent (kc-feedback-2)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const ObjectiveTile: GDScript = preload("res://scripts/ui/objective_tile.gd")
const LogFlash: GDScript = preload("res://scripts/ui/log_flash.gd")
const StripBadge: GDScript = preload("res://scripts/ui/strip_badge.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const PORTRAIT: Dictionary = {"name": "iPhone 390x844 @3x", "pt": Vector2(390, 844), "ratio": 3.0}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const EPS: float = 0.5

var _saved_root_size: Vector2i = Vector2i.ZERO


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size
	await tree.process_frame


# --- 1. the bigger score race, paid for by the objective row ----------------------------------------

func test_banners_restored_and_the_race_is_bigger() -> void:
	var k: float = Layout.points_per_px(Layout.PHONE)
	var m: Dictionary = BoardMetrics.compute(Vector2(1156, 540), true)
	assert_eq([m["bw"], m["bh"]], [228.0, 57.0], "phone banners back to 228x57")
	assert_true((m["bh"] + m["row_gap"]) * k >= 43.0, "phone slot pitch %.1f pt >= 43" % ((m["bh"] + m["row_gap"]) * k))
	var race: Rect2 = m["score_race"]
	# Before: 21 px (15 pt) tall. Now at least 26 px (19 pt).
	assert_true(race.size.y >= 26.0 and race.size.y * k >= 19.0, "phone race %.0f px = %.1f pt tall (was 21 px)" % [race.size.y, race.size.y * k])
	assert_eq(m["obj_h"], 28.0, "the objective row paid for it (52 -> 28 px)")
	assert_true(race.end.y <= (m["board"] as Rect2).position.y and race.position.y >= 0.0, "phone race over the board, on screen")
	var d: Dictionary = BoardMetrics.compute(Vector2(1268, 800), false)
	assert_eq([d["bw"], d["bh"]], [304.0, 76.0], "desktop banners back to 304x76")
	assert_true((d["score_race"] as Rect2).size.y >= 44.0, "desktop race %s (was 37 px)" % d["score_race"])
	assert_true((d["board"] as Rect2).end.y <= 800.0 and (d["score_race"] as Rect2).position.y >= 0.0, "desktop fits")
	var p: Dictionary = BoardMetrics.compute(Vector2(540, 1168), true)
	assert_true((p["score_race"] as Rect2).size.y >= 36.0, "portrait race %s (was 21 px)" % p["score_race"])


func test_the_race_reads_on_every_screen_and_overlaps_nothing() -> void:
	for screen: Dictionary in [Layout.PHONE, PORTRAIT, DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var label: String = screen["name"]
		var k: float = Layout.points_per_px(screen)
		var race: ScoreRaceBar = m.get_score_race()
		var rr: Rect2 = race.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS).encloses(rr), "%s: on screen" % label)
		# Big, readable parts: numbers >= 17 pt, words >= 11 pt, segments >= 11 pt tall.
		var g: Dictionary = race.layout()
		assert_true(race.number_font_size() * k >= 17.0, "%s: score numbers %.1f pt" % [label, race.number_font_size() * k])
		assert_true(race.font_size() * k >= 11.0 and race.goal_font_size() * k >= 11.0, "%s: YOU / RIVAL / TO n readable" % label)
		var bar: Rect2 = g["bars"][0]
		assert_true(bar.size.y * k >= 11.0 and bar.size.y >= rr.size.y * 0.55, "%s: tall segments (%.0f px)" % [label, bar.size.y])
		var n: int = maxi(1, race.target)
		assert_true((bar.size.x - 3.0 * (n - 1)) / n * k >= 14.0, "%s: each point's segment >= 14 pt wide" % label)
		# Nothing overlaps it: the board, the strip, the tray, the badges.
		var others: Array[Control] = [m.get_board(), m.get_tray()]
		var badges: Dictionary = m.get_key_controls()
		for key: String in ["menu", "log", "operator_panel", "streak", "deck"]:
			var cnode: Variant = badges.get(key)
			if cnode is Control and (cnode as Control).is_visible_in_tree():
				others.append(cnode)
		for o: Control in others:
			if o.is_visible_in_tree():
				assert_false(o.get_global_rect().grow(-EPS).intersects(rr.grow(-EPS)), "%s: the race clear of %s (%s / %s)" % [label, o.name, rr, o.get_global_rect()])
		# The objective row: readable and inspectable.
		for lane: Node in m.get_board().get_lanes():
			var tile: Control = lane.get_objective_tile()
			assert_true(tile.size.y * k >= 20.0, "%s: objective row %.1f pt tall" % [label, tile.size.y * k])
			assert_true(tile.mark_size() * k >= 14.0, "%s: the column letter's plate %.1f pt" % [label, tile.mark_size() * k])
			# FRONT bars stay in the tile's margin, clear of the letter plate.
			var tab: Vector2 = lane.front_tab_size()
			var plate_top: float = (tile.size.y - tile.mark_size()) * 0.5
			assert_true(1.0 + tab.y <= plate_top + EPS, "%s: the FRONT bar (%s) clear of the plate (top %.0f)" % [label, tab, plate_top])
		# Long press on a column's objective row still opens its inspector.
		var c: Node = s[2]
		var tile0: Control = (m.get_board().get_lanes()[1] as Node).get_objective_tile()
		var lane0: Node = m.get_board().get_lanes()[1]
		var hit: Array = lane0.call(&"_slot_hit", tile0.get_global_rect().get_center(), true)
		assert_false(hit.is_empty(), "%s: the objective row is a hit target (%s)" % [label, hit])
		c.call(&"_on_lane_long_pressed", 1, hit[0], int(hit[1]) if hit.size() > 1 else -1)
		await _frames(2)
		assert_true(m.get_inspector().is_open(), "%s: long press on the objective row inspects the column" % label)
		m.get_inspector().close()
		# "+N": a solid chip under the number, inside the screen.
		m.score_race_scored(1, 0)
		assert_eq(race.pop_texts(), ["+1"] as Array[String], "%s: +1 pops" % label)
		await _despawn(vp)


func test_a_short_tile_lays_its_field_chips_side_by_side() -> void:
	var t: Control = ObjectiveTile.new()
	t.compact = true
	t.size = Vector2(228, 28)
	tree.root.add_child(t)
	t.set_tile({"label": "B", "control": &"contested", "worth": 1, "fields": {
			"enemy": [{"card_id": &"x", "name": "Minefield"}], "player": [{"card_id": &"y", "name": "Floodlights"}]}})
	t.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	var chips: Array = t.chip_rects()
	assert_eq(chips.size(), 2, "both sides' Field chips drawn")
	var a: Rect2 = chips[0][0]
	var b: Rect2 = chips[1][0]
	assert_eq([chips[0][1], chips[1][1]], [&"enemy", &"player"], "the rival's left, yours right")
	assert_true(absf(a.position.y - b.position.y) < EPS and a.size.y >= 24.0 - EPS, "side by side, full height (%s / %s)" % [a, b])
	assert_true(a.end.x <= b.position.x, "they don't overlap")
	assert_true(t.field_area().encloses(a) and t.field_area().encloses(b), "inside the Field area")
	assert_false(a.intersects(t.worth_rect()) or b.intersects(t.worth_rect()), "clear of the +1 tag")
	assert_eq(t.field_at(a.get_center())[0], &"enemy", "each chip inspectable on its own")
	assert_eq(t.field_at(b.get_center())[0], &"player", "each chip inspectable on its own")
	# One side alone fills the area.
	t.set_tile({"label": "B", "control": &"player", "fields": {"player": [{"card_id": &"y", "name": "Floodlights"}]}})
	t.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_true(absf((t.chip_rects()[0][0] as Rect2).size.x - t.field_area().size.x) < EPS, "one chip: the whole area")
	# A tall tile keeps the stacked layout.
	t.size = Vector2(304, 80)
	t.set_tile({"label": "B", "fields": {"enemy": [{"card_id": &"x", "name": "Minefield"}], "player": [{"card_id": &"y", "name": "Floodlights"}]}})
	t.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	var ta: Rect2 = t.chip_rects()[0][0]
	var tb: Rect2 = t.chip_rects()[1][0]
	assert_true(ta.end.y <= tb.position.y, "tall tile: the rival's on top, yours under it")
	t.queue_free()


# --- 3. the LOG flash ---------------------------------------------------------------------------

func test_log_flash_two_pulses_about_1_2_s() -> void:
	assert_eq(LogFlash.PULSES, 2, "2 pulses")
	assert_true(LogFlash.DURATION_S >= 1.0 and LogFlash.DURATION_S <= 1.5, "about 1.2 s")
	var peaks: int = 0
	var prev: float = 0.0
	var rising: bool = true
	var t: float = 0.0
	while t <= LogFlash.DURATION_S + 0.05:
		var v: float = LogFlash.level_at(t, false)
		if rising and v < prev:
			peaks += 1
			rising = false
		elif not rising and v > prev:
			rising = true
		prev = v
		t += 0.01
	assert_eq(peaks, 2, "two peaks")
	assert_eq(LogFlash.level_at(0.0, false), 0.0, "starts dark")
	assert_eq(LogFlash.level_at(LogFlash.DURATION_S, false), 0.0, "ends dark")
	assert_true(LogFlash.level_at(0.3, true) == LogFlash.level_at(0.9, true) and LogFlash.level_at(0.6, true) > 0.0, "reduced motion: steady")


func test_log_flash_waits_for_tips_and_stops_under_overlays() -> void:
	var badge: Control = StripBadge.new()
	badge.size = Vector2(62, 61)
	tree.root.add_child(badge)
	var lf: Node = LogFlash.new()
	tree.root.add_child(lf)
	lf.badge = badge
	var blocked: Array = [true]
	lf.request(func() -> bool: return blocked[0])
	for i: int in 30:
		lf._process(0.1)
	assert_eq(lf.phase, LogFlash.Phase.WAITING, "a tip is up: it waits")
	assert_eq(badge.flash, 0.0, "nothing drawn while waiting")
	blocked[0] = false
	lf._process(0.25)
	assert_eq(lf.phase, LogFlash.Phase.WAITING, "settles first (the Deploy's tip opens before it)")
	lf._process(0.25)
	assert_eq(lf.phase, LogFlash.Phase.FLASHING, "then flashes")
	lf._process(0.3)
	assert_true(badge.flash > 0.5, "the badge glows (%.2f)" % badge.flash)
	# Input still works during the flash (drawing only).
	assert_eq(badge.mouse_filter, Control.MOUSE_FILTER_STOP, "the badge still takes taps")
	var tapped: Array = [0]
	badge.tapped.connect(func() -> void: tapped[0] += 1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(30, 30)
	badge._gui_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	badge._gui_input(up)
	assert_eq(tapped[0], 1, "a tap during the flash opens the log as usual")
	# A tip opens mid-flash: the flash stops at once.
	blocked[0] = true
	lf._process(0.05)
	assert_eq([lf.phase, badge.flash, lf.interrupted], [LogFlash.Phase.IDLE, 0.0, 1], "stopped under the tip")
	# A clean flash plays to the end and leaves the badge dark.
	blocked[0] = false
	lf.request(func() -> bool: return blocked[0])
	for i: int in 40:
		lf._process(0.05)
	assert_eq([lf.phase, lf.played, badge.flash], [LogFlash.Phase.IDLE, 1, 0.0], "played once, then dark")
	# Never-clear requests give up.
	blocked[0] = true
	lf.request(func() -> bool: return blocked[0])
	for i: int in 220:
		lf._process(0.1)
	assert_eq(lf.phase, LogFlash.Phase.IDLE, "dropped after %.0f s" % LogFlash.WAIT_MAX_S)
	# Reduced motion: a steady highlight.
	var st: Node = tree.root.get_node("Settings")
	var saved: bool = st.reduced_motion
	st.reduced_motion = true
	blocked[0] = false
	lf.request(func() -> bool: return blocked[0])
	lf._process(0.5)
	lf._process(0.2)
	var a: float = badge.flash
	lf._process(0.3)
	assert_true(badge.flash_gentle and absf(badge.flash - a) < 0.001 and a > 0.0, "reduced motion: steady, gentle (%.2f)" % a)
	st.reduced_motion = saved
	lf.cancel()
	assert_eq(badge.flash, 0.0, "cancel clears it")
	lf.queue_free()
	badge.queue_free()


func test_log_flash_after_a_rounds_playback_in_a_match() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var lf: Node = m.get_log_flash()
	assert_eq(lf.badge, m.get_badge(&"score"), "it flashes the LOG badge")
	assert_eq(lf.phase, LogFlash.Phase.IDLE, "nothing before a round played")
	var me: RulesSide = c.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.card_type == DataEnums.CardType.UNIT and rc.card.cost <= me.supply:
			if c.state.submit(0, RulesIntent.play_card(rc.uid, 1))["ok"]:
				break
	c.refresh()
	c.press_ready()
	var guard: int = 0
	var during: Array[int] = []
	while c.is_busy() and guard < 600:
		guard += 1
		during.append(int(lf.phase))
		c.skip_feedback()
		await tree.process_frame
	assert_false(during.has(LogFlash.Phase.FLASHING), "never during the playback")
	assert_true(lf.phase != LogFlash.Phase.IDLE, "requested when the playback ended")
	assert_true(c.log_flash_blocked() == false or lf.phase == LogFlash.Phase.WAITING, "waits while anything is up")
	# A tip up: the flash waits.
	var g: Node = tree.root.get_node("ConceptGuide")
	if g.is_showing():
		assert_true(c.log_flash_blocked(), "a tip blocks it")
	# The inspector up: blocked too.
	m.get_badge(&"score").inspected.emit()
	await _frames(1)
	assert_true(c.log_flash_blocked(), "an overlay blocks it")
	m.get_inspector().close()
	g.dismiss()
	await _despawn(vp)
