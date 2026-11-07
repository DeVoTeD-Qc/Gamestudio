# test_tutorial.gd
# Purpose: p15 tutorial match. The data (TutorialScript in CardDB, short texts), the scripted
#   match on the engine alone (stacked draws, scripted enemy, streak 2 earns the Recon Drone,
#   the drone reveals Round 4's enemy cards, the match ends at round 4), and the whole
#   scenes/tutorial/Tutorial.tscn played headless with simulated taps only: every step
#   advances in order and is sent as EventBus.tutorial_step, locked steps block other taps and
#   plays, the Recon Drone is called in, DONE goes to the Title. The skip path (SKIP TUTORIAL
#   twice) and the iPhone 844x390 @3x size rules (coach text >= 11 pt, taps >= 44 pt, coach card
#   on screen and never over the highlight) are checked on every step.
# Author: UI/UX Agent (p15)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const TUTORIAL_SCENE: String = "res://scenes/tutorial/Tutorial.tscn"
const Controller: GDScript = preload("res://scripts/ui/tutorial/tutorial_match_controller.gd")
const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const PROGRESS_PATH: String = "user://test_tutorial_progress.cfg"
## Reading time a new player needs per step and per tap, for the <= 5 minute estimate.
const READ_SECONDS_PER_STEP: float = 6.0
const SECONDS_PER_TAP: float = 1.5

var _saved_root_size: Vector2i = Vector2i.ZERO
var _saved_dry_run: bool = false
var _steps_seen: Array[int] = []


# --- Data -------------------------------------------------------------------------------------

func test_tutorial_script_is_loaded_and_valid() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var t: TutorialScript = db.get_tutorial_script()
	assert_not_null(t, "CardDB has tutorial_basic")
	if t == null:
		return
	var mine: Array = db.get_issues().filter(func(i: Dictionary) -> bool: return String(i["file"]).contains("tutorial"))
	assert_eq(mine.size(), 0, "no data issues for the tutorial: %s" % [mine])
	assert_false(db.has_issue(DataValidator.UNKNOWN_TYPE), "tutorial_script.tres is a known data type")
	assert_eq(db.get_report()["counts"]["tutorials"], 1, "one tutorial indexed")
	assert_eq(t.squad.id, &"squad_tutorial", "plays the training squad")
	assert_eq(t.map.id, &"port_vasel", "on Port Vasel")
	assert_true(t.steps.size() >= 10, "%d steps" % t.steps.size())
	for s: TutorialStep in t.steps:
		assert_true(s.text.length() <= TutorialStep.MAX_TEXT, "step %d short: %d chars" % [s.index, s.text.length()])
		assert_false(s.text.to_lower().contains("call of duty") or s.text.to_lower().contains("modern warfare"),
				"step %d: original wording" % s.index)
	var has_drone_step: bool = t.steps.any(func(s: TutorialStep) -> bool:
		return s.advance_on == &"use_item" and s.item_id == &"recon_drone" and s.lock_input)
	assert_true(has_drone_step, "a locked step calls in the Recon Drone")


func test_validator_catches_bad_steps() -> void:
	var t: TutorialScript = (tree.root.get_node("CardDB").get_tutorial_script() as TutorialScript).duplicate(true)
	var bad: TutorialStep = TutorialStep.new()
	bad.index = 99
	bad.text = "x".repeat(TutorialStep.MAX_TEXT + 1)
	bad.advance_on = &"teleport"
	t.steps.insert(0, bad)
	var v: DataValidator = DataValidator.new()
	v.index = tree.root.get_node("CardDB").get("_by_id")
	t.validate(v)
	var codes: Array = v.issues.map(func(i: Dictionary) -> String: return "%s:%s" % [i["code"], i["field"]])
	assert_true(codes.has("invalid_value:steps[0].index"), "index order: %s" % [codes])
	assert_true(codes.has("out_of_range:steps[0].text"), "text too long")
	assert_true(codes.has("invalid_value:steps[0].advance_on"), "unknown advance_on")


# --- Engine only ------------------------------------------------------------------------------

func test_scripted_match_on_the_engine() -> void:
	var t: TutorialScript = tree.root.get_node("CardDB").get_tutorial_script()
	var m: MatchState = Controller.build_state(t)
	assert_not_null(m, "state built")
	m.start_match()
	var me: RulesSide = m.sides[0]
	var hand_ids: Array = me.hand.map(func(rc: RulesCard) -> StringName: return rc.card.id)
	assert_eq(hand_ids, [&"si_grunt", &"si_trooper", &"si_sergeant", &"si_grunt", &"si_trooper"], "stacked opening hand (kc-onboard-ui: Standard Issue)")
	# Round 1: Operator + Grunt in Left vs their Grunt (kc-onboard-ui: Standard Issue on both sides).
	Controller.play_scripted_enemy(t, m)
	assert_eq(m.red_dots(0), PackedInt32Array([1, 0, 0]), "one red dot in Left")
	assert_true(m.submit(0, RulesIntent.place_operator(0))["ok"], "place Operator Left")
	assert_true(m.submit(0, RulesIntent.play_card(_uid(me, &"si_grunt"), 0))["ok"], "Grunt Left")
	_resolve(m)
	assert_eq(me.streak, 1, "R1 elimination: streak 1")
	assert_true(me.operator_unit.is_on_board(), "Operator survives")
	# Round 2: Sergeant (3 FP) Right vs their Trooper (2/3): the beat order, no First Shot.
	m.begin_round()
	Controller.play_scripted_enemy(t, m)
	assert_true(m.submit(0, RulesIntent.play_card(_uid(me, &"si_sergeant"), 2))["ok"], "Sergeant Right")
	_resolve(m)
	assert_eq(me.streak, 2, "R2 elimination: streak 2")
	assert_true(&"recon_drone" in me.streak_tray, "Recon Drone earned by the scripted firefight")
	# Round 3: call in the drone; Round 4 shows the enemy cards face-up.
	m.begin_round()
	Controller.play_scripted_enemy(t, m)
	assert_true(m.submit(0, RulesIntent.use_item(&"recon_drone"))["ok"], "Recon Drone called in")
	_resolve(m)
	m.begin_round()
	Controller.play_scripted_enemy(t, m)
	var mid: Array[StringName] = m.revealed_red_dots(0, 1)
	assert_eq(mid.size(), 2, "drone shows Round 4's Mid cards: %s" % [mid])
	_resolve(m)
	assert_eq(m.phase, MatchState.Phase.ENDED, "ends after round %d" % t.round_cap)
	assert_eq(m.result, &"player", "the player leads on points: %d-%d" % [me.score, m.sides[1].score])


# --- Whole tutorial by taps ---------------------------------------------------------------------

func test_full_tutorial_by_taps_phone() -> void:
	await _play_through(Layout.PHONE, true)


func test_full_tutorial_by_taps_desktop_real_speed() -> void:
	# No fast-forward: the rounds play at full length, to estimate a new player's time.
	await _play_through(Layout.DESKTOP, false)


func _play_through(screen: Dictionary, fast_forward: bool) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var d: Control = s[1]
	var label: String = screen["name"]
	var c: Node = d.controller
	var t: TutorialScript = d.tutorial
	var coach: Control = d.get_node("%CoachOverlay")
	var taps: int = 0
	var t0: int = Time.get_ticks_msec()
	var guard: int = 0
	var intel: String = ""
	assert_eq(_steps_seen, [1], "%s first step sent as tutorial_step(1)" % label)
	while not d.is_finished() and guard < 200:
		guard += 1
		var pos: int = d.position_index
		var st: TutorialStep = d.current_step()
		await _frames(2)
		if screen == Layout.PHONE:
			_check_phone_step(d, coach, st)
		if st.lock_input:
			await _check_lock(vp, d, st)
		if st.text.contains("{intel}"):
			intel = coach.get_body_text()
		match st.advance_on:
			&"next":
				await _tap(vp, coach.get_next_button().get_global_rect().get_center())
				taps += 1
			&"place_operator":
				await _tap(vp, _op_point(d))
				assert_eq(c.selection.get("kind"), &"operator", "%s step %d: Operator selected" % [label, st.index])
				await _frames(1)
				var fr: Array = d.spotlight_rects()[0]
				assert_true(not fr.is_empty() and fr[0] == d._lane_rect(st.zone), "%s frame moves to the lane once selected" % label)
				await _tap(vp, _row_point(d, st.zone))
				taps += 2
			&"play_card":
				var chip: Control = d._chip_for(st.card_id)
				assert_not_null(chip, "%s step %d: %s in hand" % [label, st.index, st.card_id])
				await _tap(vp, d._chip_visible_rect(chip).get_center())
				await _tap(vp, _row_point(d, st.zone))
				taps += 2
			&"use_item":
				# kc-ui3: a killstreak's tile sits at the top of the hand tray (one tap); other loadout
				# items still live in the STREAK flyout (the coach points at its badge first).
				var tile: Control = d.match_screen.get_killstreak_tile(st.item_id)
				if tile != null:
					assert_true(tile.is_visible_in_tree(), "%s %s tile shows in the tray" % [label, st.item_id])
					var fr: Array = d.spotlight_rects()[0]
					assert_true(not fr.is_empty() and fr[0] == tile.get_global_rect(), "%s the coach frames the tile" % label)
					await _tap(vp, tile.get_global_rect().get_center())
					taps += 1
				else:
					await _tap(vp, d.match_screen.get_badge(&"streak").get_global_rect().get_center())
					await _frames(2)
					var b: Button = d.match_screen.get_operator_panel().get_item_button(st.item_id)
					assert_false(b.disabled, "%s %s is ready in the tray" % [label, st.item_id])
					assert_true(b.is_visible_in_tree(), "%s %s shows in the STREAK flyout" % [label, st.item_id])
					await _tap(vp, b.get_global_rect().get_center())
					taps += 2
			&"ready":
				if not st.lock_input:
					await _free_play(vp, d)
					taps += 2
				await _tap(vp, d.match_screen.get_ready_button().get_global_rect().get_center())
				taps += 1
			&"round_end", &"match_end":
				var w0: int = Time.get_ticks_msec()
				while d.position_index == pos and Time.get_ticks_msec() - w0 < 60000:
					if fast_forward and c.is_busy():
						await _tap(vp, d._lane_rect(1).get_center())
					else:
						await _frames(2)
		await _frames(2)
		assert_true(d.position_index > pos, "%s step %d (%s) advanced" % [label, st.index, st.advance_on])
		if d.position_index == pos:
			break
	var expected: Array[int] = []
	for st: TutorialStep in t.steps:
		expected.append(st.index)
	assert_eq(_steps_seen, expected, "%s every step sent once, in order" % label)
	assert_true(d.is_finished(), "%s end panel reached" % label)
	assert_true(coach.is_end_shown(), "%s DRILL COMPLETE shown" % label)
	var drone_calls: Array = c.intent_log.filter(func(e: Dictionary) -> bool:
		return e["intent"].get("item_id") == &"recon_drone" and e["result"]["ok"])
	assert_eq(drone_calls.size(), 1, "%s Recon Drone called in once" % label)
	var revealed: bool = c.state.events.any(func(e: Dictionary) -> bool:
		return e["type"] == RulesEvent.ITEM_REVEALED and e.get("item_id") == &"recon_drone")
	assert_true(revealed, "%s the drone resolved at Reveal" % label)
	assert_eq(c.state.result, &"player", "%s the drill is won" % label)
	assert_true(intel.contains("Armored Trooper and Grunt to column B"), "%s drone intel lists the face-up column B cards: %s" % [label, intel])
	var refused: Array = c.intent_log.filter(func(e: Dictionary) -> bool: return not e["result"]["ok"])
	assert_eq(refused.size(), 0, "%s no engine refusals: %s" % [label, refused])
	if not fast_forward:
		var match_s: float = (Time.get_ticks_msec() - t0) / 1000.0
		var estimate: float = match_s + t.steps.size() * READ_SECONDS_PER_STEP + taps * SECONDS_PER_TAP
		print("    p15 time estimate: %.0f s (rounds %.0f s + reading %d steps + %d taps)" % [estimate, match_s, t.steps.size(), taps])
		assert_true(estimate <= 300.0, "%s finishable in 5 minutes: ~%.0f s" % [label, estimate])
	# DONE -> Title, recorded as completed.
	await _tap(vp, coach.get_done_button().get_global_rect().get_center())
	var router: Node = tree.root.get_node("SceneRouter")
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "%s DONE goes to the Title" % label)
	assert_true(TutorialProgress.is_completed(), "%s recorded as completed" % label)
	assert_false(TutorialProgress.should_offer(), "%s not auto-offered again" % label)
	_despawn(vp)


## Taps outside the highlight do nothing on a locked step; READY and other plays are refused.
func _check_lock(vp: SubViewport, d: Control, st: TutorialStep) -> void:
	var c: Node = d.controller
	var log_size: int = c.intent_log.size()
	var plays: int = c.state.sides[0].plays.size()
	if st.advance_on != &"ready":
		await _tap(vp, d.match_screen.get_ready_button().get_global_rect().get_center())
		assert_false(c.state.sides[0].ready, "step %d: READY blocked" % st.index)
	await _tap(vp, d.match_screen.get_key_controls()["menu"].get_global_rect().get_center())
	# A play the step doesn't teach is refused before the engine (gate), even without the overlay.
	if st.advance_on == &"play_card":
		var res: Dictionary = c._submit(RulesIntent.play_card(_uid(c.state.sides[0], st.card_id), (st.zone + 1) % 3))
		assert_eq(res.get("code"), &"tutorial_locked", "step %d: wrong lane refused" % st.index)
	assert_eq(c.intent_log.size(), log_size, "step %d: nothing reached the engine" % st.index)
	assert_eq(c.state.sides[0].plays.size(), plays, "step %d: no play queued" % st.index)
	assert_eq(d.current_step(), st, "step %d: still on the step" % st.index)
	assert_true(c.selection.is_empty(), "step %d: blocked taps select nothing" % st.index)


## Unlocked "your call" steps: play the cheapest affordable unit to Mid.
func _free_play(vp: SubViewport, d: Control) -> void:
	var me: RulesSide = d.controller.state.sides[0]
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and rc.card.cost <= me.supply and d.controller.state.projected_occupancy(0, 1) < 4:
			var chip: Control = d.match_screen.get_hand().get_card(rc.uid)
			await _tap(vp, d._chip_visible_rect(chip).get_center())
			await _tap(vp, _row_point(d, 1))
			return


func _check_phone_step(d: Control, coach: Control, st: TutorialStep) -> void:
	var ppx: float = Layout.points_per_px(Layout.PHONE)
	var view: Rect2 = Rect2(Vector2.ZERO, Layout.logical_size(Layout.PHONE))
	for l: Label in coach.get_text_labels():
		if l.is_visible_in_tree():
			var pt: float = l.get_theme_font_size(&"font_size") * ppx
			assert_true(pt >= Layout.MIN_BODY_PT - 0.01, "step %d: %s %.1f pt" % [st.index, l.name, pt])
	for b: Button in coach.get_buttons():
		if b.is_visible_in_tree():
			var r: Rect2 = b.get_global_rect()
			assert_true(minf(r.size.x, r.size.y) * ppx >= Layout.MIN_TAP_PT, "step %d: %s %.0fx%.0f pt" % [st.index, b.name, r.size.x * ppx, r.size.y * ppx])
	var card: Rect2 = coach.get_card().get_global_rect()
	assert_true(view.grow(0.5).encloses(card), "step %d: coach card on screen %s" % [st.index, card])
	var frames: Array = d.spotlight_rects()[0]
	if not frames.is_empty() and not d.controller.is_busy():
		assert_false(card.intersects((frames[0] as Rect2).grow(4.0)), "step %d: coach card clear of the highlight" % st.index)
		for h: Rect2 in d.spotlight_rects()[1]:
			assert_false(card.intersects(h), "step %d: coach card clear of the tappable area %s" % [st.index, h])


# --- Skip -------------------------------------------------------------------------------------

func test_skip_tutorial_phone() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var d: Control = s[1]
	var coach: Control = d.get_node("%CoachOverlay")
	var router: Node = tree.root.get_node("SceneRouter")
	router.last_requested = ""
	# Advance one step, then skip from a locked step (SKIP is always tappable).
	await _tap(vp, coach.get_next_button().get_global_rect().get_center())
	assert_true(d.current_step().lock_input, "on a locked step")
	var skip: Button = coach.get_skip_button()
	await _tap(vp, skip.get_global_rect().get_center())
	assert_eq(router.last_requested, "", "one tap only arms SKIP")
	assert_true(skip.text.contains("AGAIN"), "asks to confirm: %s" % skip.text)
	await _tap(vp, skip.get_global_rect().get_center())
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "second tap skips to the Title")
	assert_true(d.is_finished(), "director ended")
	assert_true(TutorialProgress.is_skipped(), "recorded as skipped")
	assert_false(TutorialProgress.is_completed(), "not completed")
	assert_false(TutorialProgress.should_offer(), "first-launch offer is spent")
	_despawn(vp)


func test_progress_offer_on_first_launch() -> void:
	TutorialProgress.use_path(PROGRESS_PATH)
	TutorialProgress.reset()
	assert_true(TutorialProgress.should_offer(), "fresh install: offer the tutorial")
	TutorialProgress.record(true, 17)
	assert_false(TutorialProgress.should_offer(), "after finishing: no offer")
	TutorialProgress.reset()
	TutorialProgress.use_path("")


# --- Helpers ----------------------------------------------------------------------------------

func _spawn(screen: Dictionary) -> Array:
	TutorialProgress.use_path(PROGRESS_PATH)
	TutorialProgress.reset()
	_steps_seen.clear()
	var bus: Node = tree.root.get_node("EventBus")
	bus.tutorial_step.connect(_on_step)
	var router: Node = tree.root.get_node("SceneRouter")
	_saved_dry_run = router.dry_run
	router.dry_run = true
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var d: Control = (load(TUTORIAL_SCENE) as PackedScene).instantiate()
	vp.add_child(d)
	await _frames(4)
	assert_not_null(d.controller, "%s controller" % screen["name"])
	assert_not_null(d.controller.state, "%s tutorial match started" % screen["name"])
	return [vp, d]


func _on_step(step: int) -> void:
	_steps_seen.append(step)


func _despawn(vp: SubViewport) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	if bus.tutorial_step.is_connected(_on_step):
		bus.tutorial_step.disconnect(_on_step)
	tree.root.get_node("SceneRouter").dry_run = _saved_dry_run
	vp.queue_free()
	tree.root.size = _saved_root_size
	TutorialProgress.reset()
	TutorialProgress.use_path("")


func _resolve(m: MatchState) -> void:
	m.set_ready(0)
	m.set_ready(1)
	m.resolve_round()


func _uid(side: RulesSide, card_id: StringName) -> int:
	for rc: RulesCard in side.hand:
		if rc.card.id == card_id:
			return rc.uid
	return -1


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


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)


func _row_point(d: Control, zone: int) -> Vector2:
	var lane: Control = d.match_screen.get_board().get_lanes()[zone]
	return (lane.get_node("%FriendlyRow") as Control).get_global_rect().get_center()


## The Operator's handle: kc-ui3's Operator card at the start of the hand tray.
func _op_point(d: Control) -> Vector2:
	return d.match_screen.get_operator_handle().get_global_rect().get_center()
