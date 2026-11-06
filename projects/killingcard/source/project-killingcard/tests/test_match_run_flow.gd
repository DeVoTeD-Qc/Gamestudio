# test_match_run_flow.gd
# Purpose: f03 "play a whole run". Drives the REAL match screen (scenes/Match.tscn and its
#   MatchController) inside the run flow headless, with simulated taps only, at the iPhone
#   844x390 @3x canvas (with notch insets):
#   Title -> Loadout -> RunMap -> DEPLOY -> Match 1 played tap by tap (mulligan, Operator, cards,
#   READY, tap to fast-forward) until it ends -> result banner -> CONTINUE -> AfterAction ->
#   offers (skipped) -> RunMap -> Match 2 forfeited from the pause sheet (counts as a loss) ->
#   AfterAction -> RunMap -> Match 3 quit to title from the pause sheet -> Title CONTINUE RUN ->
#   RunMap -> DEPLOY replays Match 3 with the same seed and opening hand.
#   Also: the local test match (no run) offers BACK TO TITLE and never touches the run, the
#   pause sheet's fast-animations toggle and cancel paths, Title's TUTORIAL button and
#   first-launch drill offer, and red-dot intel revealed by Recon Drone / Callout on the
#   INCOMING slots and the minimap.
#   SceneRouter runs in dry_run, so routes are recorded and this test opens the next scene.
# Author: Mechanics Developer Agent (f03)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const TutorialProgress: GDScript = preload("res://scripts/ui/tutorial/tutorial_progress.gd")
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0, "notch": true}
const MIN_TAP_PT: float = 44.0
const MIN_TEXT_PT: float = 11.0
const EPS: float = 0.5
const MAX_ROUNDS: int = 16
const SEED: int = 777

var _rs: Node = null
var _router: Node = null
var _settings: Node = null
var _saved: Dictionary = {}
var _vp: SubViewport = null
var _routes: Array[String] = []
var _bus_log: Array = []
## Set on the last line of the long test (a script error mid-coroutine would skip the rest).
var _reached_end: bool = false


# =============================================================================
# Setup
# =============================================================================

func _setup() -> void:
	_rs = tree.root.get_node("RunState")
	_router = tree.root.get_node("SceneRouter")
	_settings = tree.root.get_node("Settings")
	var plog: Node = tree.root.get_node("PlaytestLog")
	_saved = {"save_path": _rs.save_path, "autosave": _rs.autosave, "dry_run": _router.dry_run,
			"plog_enabled": plog.enabled, "root_size": tree.root.size, "fast": _settings.fast_animations}
	plog.enabled = false
	var dir: String = "user://test_match_run_flow/s%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	_rs.save_path = dir.path_join("run_save.json")
	_rs.autosave = true
	_rs.reset()
	TutorialProgress.use_path(dir.path_join("tutorial.cfg"))
	_router.dry_run = true
	_router.pending_match = null
	_router.active_match = null
	_router.last_match_report = {}
	_routes.clear()
	_router.scene_change_started.connect(_on_route)
	var bus: Node = tree.root.get_node("EventBus")
	_bus_log.clear()
	bus.match_started.connect(_on_match_started)
	bus.match_ended.connect(_on_match_ended)
	tree.root.size = Vector2i(1280, 720)


func _teardown() -> void:
	_close()
	_router.scene_change_started.disconnect(_on_route)
	var bus: Node = tree.root.get_node("EventBus")
	bus.match_started.disconnect(_on_match_started)
	bus.match_ended.disconnect(_on_match_ended)
	var dir: String = _rs.save_path.get_base_dir()
	_rs.abandon_run()
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	TutorialProgress.use_path("")
	_rs.save_path = _saved["save_path"]
	_rs.autosave = _saved["autosave"]
	_rs.reset()
	_router.dry_run = _saved["dry_run"]
	_router.pending_match = null
	_router.active_match = null
	_router.last_match_report = {}
	_settings.fast_animations = _saved["fast"]
	tree.root.get_node("PlaytestLog").enabled = _saved["plog_enabled"]
	tree.root.size = _saved["root_size"]


func _on_route(path: String) -> void:
	_routes.append(path)


func _on_match_started(mode: StringName, map_id: StringName, index: int) -> void:
	_bus_log.append(["started", mode, map_id, index])


func _on_match_ended(result: StringName, rounds: int, _d: float) -> void:
	_bus_log.append(["ended", result, rounds])


func _logical(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


func _k(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


## Opens a scene in a SubViewport the size of the phone's logical canvas, with notch insets.
func _open(path: String, screen: Dictionary = PHONE) -> Control:
	_close()
	_vp = SubViewport.new()
	_vp.size = Vector2i(_logical(screen))
	_vp.disable_3d = true
	_vp.handle_input_locally = true
	tree.root.add_child(_vp)
	var node: Control = (load(path) as PackedScene).instantiate()
	_vp.add_child(node)
	if screen["notch"] and "safe_area_override" in node:
		var k: float = _k(screen)
		var sz: Vector2 = Vector2(_vp.size)
		node.set("safe_area_override", Rect2(47.0 / k, 0.0, sz.x - 94.0 / k, sz.y - 21.0 / k))
	await _frames(4)
	return node


func _close() -> void:
	if _vp != null:
		_vp.queue_free()
		_vp = null


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_vp.push_input(e)


func _tap_at(pos: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	_vp.push_input(motion)
	_mouse(pos, true)
	await _frames(1)
	_mouse(pos, false)
	await _frames(3)


func _tap(ctl: Control) -> void:
	assert_true(ctl != null and ctl.is_visible_in_tree(), "tap target %s is visible" % (ctl.name if ctl != null else "null"))
	if ctl == null:
		return
	await _tap_at(ctl.get_global_rect().get_center())


func _button(node: Node, text_starts: String) -> Button:
	for c: Node in node.find_children("*", "Button", true, false):
		var b: Button = c
		if b.is_visible_in_tree() and b.text.begins_with(text_starts):
			return b
	return null


func _all_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for c: Node in node.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree():
			parts.append((c as Label).text)
	return "\n".join(parts)


## Every visible control of `root` (an overlay) on screen, texts >= 11 pt, buttons >= 44 pt.
func _check_overlay(root: Control, what: String, screen: Dictionary = PHONE) -> void:
	var k: float = _k(screen)
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(_vp.size)).grow(EPS)
	var checked: int = 0
	for c: Node in root.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree():
			continue
		assert_true(rect.encloses(ctl.get_global_rect()), "%s: %s at %s is off screen" % [what, ctl.name, ctl.get_global_rect()])
		if ctl is Label and (ctl as Label).text != "":
			var pt: float = ctl.get_theme_font_size(&"font_size") * k
			assert_true(pt >= MIN_TEXT_PT - 0.01, "%s: %s text %.1f pt" % [what, ctl.name, pt])
			checked += 1
		elif ctl is Button:
			assert_true(ctl.size.y * k >= MIN_TAP_PT and ctl.size.x * k >= MIN_TAP_PT,
					"%s: %s tap target %.1fx%.1f pt" % [what, ctl.name, ctl.size.x * k, ctl.size.y * k])
			checked += 1
	assert_true(checked >= 3, "%s: checked %d controls" % [what, checked])


# =============================================================================
# Run navigation helpers
# =============================================================================

## Title -> START NEW RUN -> Loadout -> BEGIN RUN -> RunMap (by taps).
func _new_run_to_map() -> Control:
	var title: Control = await _open(RunFlow.SCENE_TITLE)
	_routes.clear()
	await _tap(title.get_node("%StartButton"))
	assert_eq(_routes.back() if not _routes.is_empty() else "", RunFlow.SCENE_LOADOUT, "START -> Loadout")
	_rs.run.seed_value = SEED
	var loadout: Control = await _open(RunFlow.SCENE_LOADOUT)
	# kc-ui4: the loadout opens on STARTING SQUAD; NEXT goes on to the killstreaks.
	await _frames(2)
	if loadout.get_starter() != null:
		await _tap(_button(loadout.get_starter(), "NEXT"))
	_routes.clear()
	await _tap(_button(loadout, "BEGIN RUN"))
	assert_eq(_routes.back() if not _routes.is_empty() else "", RunFlow.SCENE_RUN_MAP, "BEGIN RUN -> RunMap")
	return await _open(RunFlow.SCENE_RUN_MAP)


## RunMap DEPLOY -> Match.tscn opened on the pending run match. Returns [match screen, controller].
func _deploy(map: Control) -> Array:
	_routes.clear()
	await _tap(_button(map, "DEPLOY"))
	assert_eq(_routes.back() if not _routes.is_empty() else "", RunFlow.SCENE_MATCH, "DEPLOY -> Match")
	assert_not_null(_router.pending_match, "DEPLOY left a pending run match")
	var m: Control = await _open(RunFlow.SCENE_MATCH)
	var c: Node = m.get_node("%MatchController")
	return [m, c]


## AfterAction -> CONTINUE -> every offer skipped -> RunMap.
func _after_action_to_map() -> Control:
	var aa: Control = await _open(RunFlow.SCENE_AFTER_ACTION)
	_routes.clear()
	await _tap(aa.get_node("%ContinueButton") if aa.has_node("%ContinueButton") else _button(aa, "CONTINUE"))
	var guard: int = 0
	while not _routes.is_empty() and _routes.back() == RunFlow.SCENE_REWARD and guard < 6:
		guard += 1
		var reward: Control = await _open(RunFlow.SCENE_REWARD)
		_routes.clear()
		while _routes.is_empty() and guard < 12:
			guard += 1
			await _tap(reward._skip_button)
			await _frames(2)
	assert_eq(_routes.back() if not _routes.is_empty() else "", RunFlow.SCENE_RUN_MAP, "offers done -> RunMap")
	return await _open(RunFlow.SCENE_RUN_MAP)


# =============================================================================
# Playing the match by taps
# =============================================================================

func _row_point(lane: Control) -> Vector2:
	return (lane.get_node("%FriendlyRow") as Control).get_global_rect().get_center()


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


## One Deploy by taps: the Operator if it can deploy, then affordable units into the lanes,
## then READY; taps through the round's feedback. Returns the number of accepted plays.
func _play_round(m: Control, c: Node) -> int:
	var me: RulesSide = c.state.sides[0]
	var lanes: Array[Node] = m.get_board().get_lanes()
	var accepted: int = 0
	var log_start: int = c.intent_log.size()
	if me.operator_can_deploy:
		# kc-board2: the strip's OPERATOR badge is the Operator's handle while it can deploy.
		await _tap_at(m.get_operator_handle().get_global_rect().get_center())
		await _tap_at(_row_point(lanes[1]))
	var tried: Array[int] = []
	for attempt: int in 6:
		var rc: RulesCard = null
		for h: RulesCard in me.hand:
			if h.card.card_type == DataEnums.CardType.UNIT and h.card.cost <= me.supply and h.uid not in tried:
				rc = h
				break
		if rc == null:
			break
		tried.append(rc.uid)
		var chip: Control = m.get_hand().get_card(rc.uid)
		if chip == null:
			continue
		await _tap_at(_chip_point(m, chip))
		var zone: int = (c.state.round_number + attempt) % 3
		var before: int = c.intent_log.size()
		await _tap_at(_row_point(lanes[zone]))
		var ok: bool = c.intent_log.size() > before and c.intent_log.back()["result"]["ok"]
		if not ok and not c.selection.is_empty():
			c.clear_selection()  # refused (zone full ...): the toast said why; try another card
	for e: Dictionary in c.intent_log.slice(log_start):
		if e["result"]["ok"]:
			accepted += 1
	await _tap(m.get_ready_button())
	var t0: int = Time.get_ticks_msec()
	while c.is_busy() and Time.get_ticks_msec() - t0 < 30000:
		await _tap_at(Vector2(_vp.size) * Vector2(0.5, 0.45))  # a tap fast-forwards the feedback
	await _frames(3)
	return accepted


## Plays rounds until the match has ended. Returns the number of rounds played.
func _play_to_end(m: Control, c: Node) -> int:
	if c.is_mulligan_open():
		await _tap(m.get_mulligan_panel().get_keep_button())
	var rounds: int = 0
	while c.state.phase != MatchState.Phase.ENDED and rounds < MAX_ROUNDS:
		await _play_round(m, c)
		rounds += 1
	return rounds


# =============================================================================
# The whole run through the real match screen
# =============================================================================

func test_full_run_through_the_match_screen_phone() -> void:
	_setup()
	_settings.fast_animations = true
	_reached_end = false
	await _full_run_body()
	assert_true(_reached_end, "the whole run was played to the end (no script error)")
	if not _reached_end:
		_teardown()


func _full_run_body() -> void:
	var map: Control = await _new_run_to_map()
	assert_eq(_rs.run.phase, RunProgress.PHASE_MATCH, "run begun")

	# --- Match 1: played to the end by taps ---------------------------------------------------
	var s: Array = await _deploy(map)
	var m: Control = s[0]
	var c: Node = s[1]
	var slot: RunMatchData = _rs.run.config.matches[0]
	assert_true(c.is_run_match, "Match.tscn took the run match")
	assert_true(_router.is_run_match(c.state), "the router's active match is the one on screen")
	assert_true(_router.pending_match == null, "pending match taken")
	assert_eq(c.state.seed_value, _rs.run.match_seed(), "run match seed")
	assert_eq(c.map, slot.map, "map from the run slot")
	assert_eq(c.match_index, 0, "match index 0")
	assert_not_null(c.enemy_ai_player, "the AI plays the run squad")
	assert_true(c.is_mulligan_open(), "Round 1 mulligan on the run match")
	assert_eq(_bus_log.filter(func(e: Array) -> bool: return e[0] == "started").size(), 1, "match_started emitted")
	assert_eq(_bus_log[0][3], 0, "match_started carries match index 0")
	var rounds: int = await _play_to_end(m, c)
	assert_eq(c.state.phase, MatchState.Phase.ENDED, "match 1 ended after %d rounds of taps" % rounds)
	print("     [f03] match 1: %s after %d rounds, score %d-%d" % [c.state.result, rounds,
			c.state.sides[0].score, c.state.sides[1].score])
	assert_true(c.intent_log.filter(func(e: Dictionary) -> bool: return e["result"]["ok"]).size() >= rounds,
			"the player deployed through the taps")
	var ended: Array = _bus_log.filter(func(e: Array) -> bool: return e[0] == "ended")
	assert_eq(ended.size(), 1, "match_ended emitted once")
	var banner: Control = m.get_end_banner()
	assert_true(banner.is_open(), "result banner shown")
	var word: String = {&"player": "VICTORY", &"enemy": "DEFEAT"}.get(c.state.result, "DRAW")
	assert_eq(banner.get_result_text(), word, "banner says %s" % word)
	assert_true(("%d  -  %d" % [c.state.sides[0].score, c.state.sides[1].score]) in banner.get_score_text(), "banner score")
	assert_true("MATCH 1 OF 5" in _all_text(banner), "banner names the run match")
	assert_eq(banner.get_continue_button().text, "CONTINUE", "run match: CONTINUE")
	_check_overlay(banner, "result banner")
	assert_eq(_rs.run.history.size(), 0, "nothing recorded before CONTINUE")
	# Taps on the board under the banner do nothing.
	var log_size: int = c.intent_log.size()
	await _tap_at(_row_point(m.get_board().get_lanes()[0]))
	assert_eq(c.intent_log.size(), log_size, "board blocked under the banner")
	_routes.clear()
	await _tap(banner.get_continue_button())
	assert_eq(_routes, [RunFlow.SCENE_AFTER_ACTION] as Array[String], "CONTINUE -> AfterAction")
	assert_eq(_rs.run.history.size(), 1, "match 1 recorded")
	assert_eq(_rs.run.history[0]["result"], String(c.state.result), "recorded result")
	assert_false(_router.is_run_match(c.state), "hand-off closed")
	# Exactly once: a second tap / call records nothing more.
	c.continue_after_match()
	await _frames(2)
	assert_eq(_rs.run.history.size(), 1, "finish_run_match only once")
	var score_1: String = "%d-%d" % [c.state.sides[0].score, c.state.sides[1].score]
	var aa: Control = await _open(RunFlow.SCENE_AFTER_ACTION)
	assert_true(word in _all_text(aa), "AfterAction says %s" % word)
	assert_true(score_1 in _all_text(aa), "AfterAction score %s" % score_1)
	map = await _after_action_to_map()
	assert_eq(_rs.run.match_index, 1, "on to match 2")

	# --- Match 2: forfeited from the pause sheet ----------------------------------------------
	var tickets: int = _rs.run.tickets
	s = await _deploy(map)
	m = s[0]
	c = s[1]
	assert_eq(c.match_index, 1, "match index 1")
	assert_eq(c.map, _rs.run.config.matches[1].map, "match 2 map")
	if c.is_mulligan_open():
		await _tap(m.get_mulligan_panel().get_keep_button())
	await _play_round(m, c)
	var pause: Control = m.get_pause_menu()
	await _tap(m.get_menu_button())
	assert_true(pause.is_open(), "MENU opens the pause sheet")
	_check_overlay(pause, "pause sheet")
	# Fast animations toggle writes Settings.
	var fast_before: bool = _settings.fast_animations
	await _tap(pause.get_fast_button())
	assert_eq(_settings.fast_animations, not fast_before, "toggle flips Settings.fast_animations")
	await _tap(pause.get_fast_button())
	assert_eq(_settings.fast_animations, fast_before, "and back")
	# FORFEIT asks first; KEEP PLAYING backs out.
	await _tap(pause.get_forfeit_button())
	assert_true(pause.is_confirming(), "forfeit asks for confirmation")
	assert_true("-1 ticket" in _all_text(pause), "the confirmation says what it costs")
	_check_overlay(pause, "forfeit confirmation")
	await _tap(pause.get_forfeit_cancel_button())
	assert_false(pause.is_confirming(), "KEEP PLAYING backs out")
	assert_true(c.state.phase != MatchState.Phase.ENDED, "still playing")
	await _tap(pause.get_resume_button())
	assert_false(pause.is_open(), "RESUME closes the sheet")
	await _tap(m.get_menu_button())
	await _tap(pause.get_forfeit_button())
	_bus_log.clear()
	await _tap(pause.get_forfeit_confirm_button())
	assert_true(c.forfeited, "forfeited")
	assert_eq(c.state.phase, MatchState.Phase.ENDED, "forfeit ends the match")
	assert_eq(c.state.result, &"enemy", "forfeit is a loss")
	assert_eq(_bus_log, [["ended", &"loss", c.state.round_number]], "match_ended(loss) for the playtest log")
	assert_false(pause.is_open(), "sheet closed")
	assert_true(m.get_end_banner().is_open(), "banner after the forfeit")
	assert_eq(m.get_end_banner().get_result_text(), "DEFEAT", "forfeit banner DEFEAT")
	assert_true("forfeited" in m.get_end_banner().get_reason_text(), "banner says why")
	_routes.clear()
	await _tap(m.get_end_banner().get_continue_button())
	assert_eq(_routes, [RunFlow.SCENE_AFTER_ACTION] as Array[String], "forfeit -> AfterAction (same path)")
	assert_eq(_rs.run.history.size(), 2, "match 2 recorded")
	assert_eq(_rs.run.history[1]["result"], "enemy", "recorded as a loss")
	assert_eq(_rs.run.history[1]["reason"], "forfeit", "reason forfeit")
	assert_eq(_rs.run.tickets, tickets - 1, "a ticket lost")
	aa = await _open(RunFlow.SCENE_AFTER_ACTION)
	assert_true("DEFEAT" in _all_text(aa), "AfterAction: DEFEAT")
	map = await _after_action_to_map()
	assert_eq(_rs.run.match_index, 2, "on to match 3")

	# --- Match 3: quit to title, continue from the save, same seed ----------------------------
	s = await _deploy(map)
	m = s[0]
	c = s[1]
	var seed_3: int = c.state.seed_value
	var hand_3: Array = c.state.sides[0].hand.map(func(rc: RulesCard) -> StringName: return rc.card.id)
	await _tap(m.get_mulligan_panel().get_keep_button())
	await _tap(m.get_menu_button())
	assert_true("run is saved" in _all_text(m.get_pause_menu()), "the sheet says the run is saved")
	_routes.clear()
	await _tap(m.get_pause_menu().get_quit_button())
	assert_eq(_routes, [RunFlow.SCENE_TITLE] as Array[String], "QUIT TO TITLE -> Title")
	assert_eq(_rs.run.history.size(), 2, "quit records nothing")
	assert_true(_router.active_match == null, "hand-off dropped")
	# Reload: the in-memory run is gone, the save is on disk.
	_rs.reset()
	var title: Control = await _open(RunFlow.SCENE_TITLE)
	assert_true(title.get_node("%ContinueButton").visible, "CONTINUE RUN offered")
	_routes.clear()
	await _tap(title.get_node("%ContinueButton"))
	assert_eq(_routes, [RunFlow.SCENE_RUN_MAP] as Array[String], "continue -> RunMap")
	assert_eq(_rs.run.match_index, 2, "still at match 3")
	map = await _open(RunFlow.SCENE_RUN_MAP)
	s = await _deploy(map)
	c = s[1]
	assert_eq(c.state.seed_value, seed_3, "match 3 replays with the same seed")
	assert_eq(c.state.sides[0].hand.map(func(rc: RulesCard) -> StringName: return rc.card.id), hand_3, "same opening hand")
	assert_true(c.is_run_match and _router.is_run_match(c.state), "the replay is the run match again")
	_reached_end = true
	_teardown()


## No run: the local test match ends via forfeit and offers BACK TO TITLE; the run is untouched.
func test_local_match_offers_back_to_title() -> void:
	_setup()
	var m: Control = await _open(RunFlow.SCENE_MATCH)
	var c: Node = m.get_node("%MatchController")
	assert_false(c.is_run_match, "no pending run match: local test match")
	assert_not_null(c.state, "local match running")
	if c.is_mulligan_open():
		await _tap(m.get_mulligan_panel().get_keep_button())
	await _tap(m.get_menu_button())
	assert_true("Local test match" in _all_text(m.get_pause_menu()), "local wording")
	await _tap(m.get_pause_menu().get_forfeit_button())
	await _tap(m.get_pause_menu().get_forfeit_confirm_button())
	var banner: Control = m.get_end_banner()
	assert_true(banner.is_open(), "banner")
	assert_eq(banner.get_continue_button().text, "BACK TO TITLE", "local: back to title")
	_routes.clear()
	await _tap(banner.get_continue_button())
	assert_eq(_routes, [RunFlow.SCENE_TITLE] as Array[String], "-> Title")
	assert_true(_rs.run == null, "no run touched")
	_teardown()


## MENU does nothing over the mulligan; Esc closes the pause sheet.
func test_menu_blocked_during_mulligan() -> void:
	_setup()
	var m: Control = await _open(RunFlow.SCENE_MATCH)
	var c: Node = m.get_node("%MatchController")
	assert_true(c.is_mulligan_open(), "mulligan open")
	c.open_pause_menu()
	assert_false(m.get_pause_menu().is_open(), "no pause sheet over the mulligan")
	c.keep_hand()
	await _frames(2)
	c.open_pause_menu()
	assert_true(m.get_pause_menu().is_open(), "pause sheet after the mulligan")
	# Esc backs out.
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"cancel"
	esc.pressed = true
	_vp.push_input(esc)
	await _frames(2)
	assert_false(m.get_pause_menu().is_open(), "Esc resumes")
	_teardown()


# =============================================================================
# Title: TUTORIAL and the first-launch drill offer
# =============================================================================

func test_title_tutorial_button_and_first_launch_offer() -> void:
	_setup()
	TutorialProgress.reset()
	var title: Control = await _open(RunFlow.SCENE_TITLE)
	assert_true(title.is_offering_tutorial(), "first launch, no save: drill offered")
	assert_true("New here? Play the 3-minute drill." in _all_text(title), "offer text")
	_check_overlay(title.get_node("%SafeArea"), "title with offer")
	_routes.clear()
	await _tap(title.get_node("%PlayDrillButton"))
	assert_eq(_routes, [_router.SCENE_TUTORIAL] as Array[String], "PLAY DRILL -> Tutorial")
	_routes.clear()
	await _tap(title.get_node("%NotNowButton"))
	assert_false(title.is_offering_tutorial(), "NOT NOW hides it")
	assert_false(TutorialProgress.should_offer(), "NOT NOW records a skip")
	assert_true(_routes.is_empty(), "NOT NOW stays on the title")
	title = await _open(RunFlow.SCENE_TITLE)
	assert_false(title.is_offering_tutorial(), "not offered again")
	await _tap(title.get_node("%TutorialButton"))
	assert_eq(_routes, [_router.SCENE_TUTORIAL] as Array[String], "TUTORIAL -> Tutorial")
	# With a saved run the offer stays away even if never played.
	TutorialProgress.reset()
	_rs.start_run(SEED)
	title = await _open(RunFlow.SCENE_TITLE)
	assert_false(title.is_offering_tutorial(), "no offer when a run is saved")
	_check_overlay(title.get_node("%SafeArea"), "title with save")
	TutorialProgress.reset()
	_teardown()


# =============================================================================
# Red dots revealed by Recon Drone / Callout
# =============================================================================

func test_revealed_red_dots_name_the_incoming_slots_phone() -> void:
	_setup()
	var m: Control = await _open(RunFlow.SCENE_MATCH)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	var dots: PackedInt32Array = st.red_dots(0)
	assert_true(dots[0] + dots[1] + dots[2] > 0, "the AI committed plays (red dots)")
	var lanes: Array[Node] = m.get_board().get_lanes()
	var minimap: Control = m.get_node("%Minimap")
	# Unrevealed: INCOMING, no names.
	for z: int in 3:
		assert_eq(MatchSnapshot.revealed_names(st, 0, z), [], "zone %d hidden" % z)
		for slot: Node in lanes[z].get_enemy_slots():
			if slot.kind == slot.Kind.INCOMING:
				assert_eq(slot.revealed, "", "hidden dot has no name")
		assert_eq(minimap.get_spotted_text(z), "", "minimap shows dots only")
	# Callout on one zone (intel_reveals): only that zone is named.
	var zone: int = 0
	for z: int in 3:
		if dots[z] > dots[zone]:
			zone = z
	me.intel_reveals[st.round_number] = [zone]
	c.refresh()
	await _frames(2)
	var names: Array = MatchSnapshot.revealed_names(st, 0, zone)
	assert_eq(names.size(), dots[zone], "one name per red dot in zone %d" % zone)
	var shown: Array = []
	for slot: Node in lanes[zone].get_enemy_slots():
		if slot.kind == slot.Kind.INCOMING:
			shown.append(slot.revealed)
			assert_eq(slot.banner.revealed, slot.revealed, "revealed back names the card (SPOTTED)")
	assert_eq(shown, names, "INCOMING slots name the revealed cards")
	assert_eq(minimap.get_spotted_text(zone), ", ".join(PackedStringArray(names)), "minimap names them")
	for z: int in 3:
		if z != zone:
			assert_eq(minimap.get_spotted_text(z), "", "other zones stay hidden")
	# Recon Drone (REVEAL_DEPLOYMENTS): every zone named.
	me.intel_reveals.erase(st.round_number)
	me.flags[DataEnums.EffectKind.REVEAL_DEPLOYMENTS] = st.round_number
	c.refresh()
	await _frames(2)
	var total: int = 0
	for z: int in 3:
		var n: Array = MatchSnapshot.revealed_names(st, 0, z)
		assert_eq(n.size(), dots[z], "drone: zone %d named" % z)
		for nm: Variant in n:
			assert_true(String(nm) != "" and not String(nm).contains("_"), "display name, not an id: %s" % nm)
		total += n.size()
	assert_eq(total, dots[0] + dots[1] + dots[2], "every dot named")
	# Readable on the phone: the slot names stay inside the board and >= 11 pt.
	var k: float = _k(PHONE)
	for lane: Node in lanes:
		for slot: Node in lane.get_enemy_slots():
			if slot.kind == slot.Kind.INCOMING and slot.revealed != "":
				assert_true(BannerView.metrics(slot.size.y)["number"] * k >= MIN_TEXT_PT, "slot name >= 11 pt")
	me.flags.erase(DataEnums.EffectKind.REVEAL_DEPLOYMENTS)
	_teardown()
