# test_coach_pause_end.gd
# Purpose: cz13 first-match coach, pause menu and end screen, by touch on the phone.
#   - coach: Hold on the first Pack, Brace on the first Brace step, Down and Adrenaline when they
#     first come up; one tip at a time; the loop is held while a tip shows; every shown tip is
#     remembered (never shown twice); SKIP ALL TIPS; SHOW TIPS AGAIN in settings resets them.
#   - pause menu: MENU opens it and holds the match; RULES; SETTINGS (reduced motion, event speed
#     applied to the running match); CONCEDE… -> confirm -> end screen with CONCEDE; KEEP PLAYING.
#   - end screen words for every cause (elimination, gas, final circle, hard end, concede, draw).
# Author: UI/UX Agent (cz13)
extends "res://tests/test_setup_helpers.gd"

const MATCH: String = "res://scenes/match/Match.tscn"
const MatchShell: GDScript = preload("res://scripts/ui/pause_match_shell.gd")
const EndScreen: GDScript = preload("res://scripts/ui/end_screen.gd")
const PauseSettings: GDScript = preload("res://scripts/ui/pause_settings.gd")


## A scripted rival: fires every legal shot first, braces with nothing, else the first legal action.
class Shooter extends RefCounted:
	var kind: String = "Shooter"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		for a: Dictionary in legal:
			if a["type"] == "shoot" and int(a["seat"]) == seat:
				return a
		for a: Dictionary in legal:
			if int(a["seat"]) == seat:
				return a
		return {}


func test_tips_due_rules() -> void:
	await phone_begin()
	var base: Dictionary = {"match_end": {}, "me": {"down": false}, "opponent": {"down": false}}
	assert_eq(CoachTips.due(base, &"act", false), [] as Array[StringName], "nothing to coach")
	assert_eq(CoachTips.due(base, &"pack", false), [&"hold"] as Array[StringName], "Pack -> Hold")
	var braced: Dictionary = base.duplicate(true)
	braced["brace_prompt"] = {}
	assert_eq(CoachTips.due(braced, &"brace", false), [&"brace"] as Array[StringName], "Brace step -> Brace")
	var down: Dictionary = base.duplicate(true)
	down["opponent"]["down"] = true
	assert_eq(CoachTips.due(down, &"opponent", false), [&"down"] as Array[StringName], "anyone Down -> Down")
	assert_eq(CoachTips.due(base, &"act", true), [&"adrenaline"] as Array[StringName], "Hit in hand on my turn -> Adrenaline")
	assert_eq(CoachTips.due(base, &"opponent", true), [] as Array[StringName], "not during the rival's turn")
	CoachTips.mark_seen(&"hold")
	assert_eq(CoachTips.due(base, &"pack", false), [] as Array[StringName], "a seen tip never comes back")
	var over: Dictionary = base.duplicate(true)
	over["match_end"] = {"result": "win"}
	assert_eq(CoachTips.due(over, &"pack", true), [] as Array[StringName], "no tips after the end")
	CoachTips.reset()
	assert_eq(CoachTips.seen_count(), 0, "reset")
	assert_eq(CoachTips.text(&"hold", {"hold_limit": 1})["text"].begins_with("Tap up to 1 card in"), true, "Hold text follows hold_limit")
	assert_true("MOVE +1." in CoachTips.text(&"adrenaline", {"move_only": true})["text"], "Adrenaline text follows adrenaline_mode")
	await phone_end()


func test_hold_tip_on_first_pack_holds_the_loop_and_skip_all() -> void:
	await phone_begin()
	SetupLaunch.request_new({"opponent": "rookie", "first": "me", "route": "A"})
	var m: Control = await spawn(MATCH)
	var ctrl: Node = m.get_controller()
	var coach: Control = m.shell.coach
	await touch(m.get_area_touch(&"motel"))
	await touch(m.get_dock_button(&"drop"))
	assert_eq(ctrl.phase, &"act", "turn 1")
	assert_false(coach.is_showing(), "no tip on turn 1 before the Pack")
	await touch(m.get_corner_buttons()[&"end_turn"])
	await tree.process_frame
	assert_eq(m.mode, &"pack", "END TURN opens Pack")
	assert_eq(coach.current, &"hold", "the Hold tip comes up with the first Pack")
	assert_true("HOLD" in coach.get_title_text(), "tip title %s" % coach.get_title_text())
	assert_true(ctrl.paused, "the loop is held while the tip shows")
	check_buttons([coach.get_ok_button(), coach.get_skip_button()], "coach")
	check_labels(coach.get_text_labels(), "coach")
	# A tap on the hand is blocked while the tip is up.
	var hand0: Control = m.get_cards(&"hand")[0]
	await touch_at(hand0.get_global_rect().get_center())
	assert_eq(m.hold_set.size(), 0, "the tip is modal")
	await touch(coach.get_skip_button())
	assert_false(coach.is_showing(), "SKIP ALL TIPS closes it")
	assert_false(ctrl.paused, "the loop runs again")
	assert_eq(CoachTips.seen_count(), CoachTips.TIPS.size(), "every tip marked seen")
	# Reset from the pause menu's settings.
	await touch(m.get_node("%MenuButton"))
	var pm: Control = m.shell.pause_menu
	assert_true(pm.visible and ctrl.paused, "MENU opens the pause menu and holds the match")
	await touch(pm.get_button(&"settings"))
	await touch(pm.get_button(&"reset_tips"))
	assert_eq(CoachTips.seen_count(), 0, "SHOW TIPS AGAIN resets the coach")
	await touch(pm.get_button(&"back"))
	await touch(pm.get_button(&"resume"))
	assert_false(pm.visible, "RESUME closes the menu")
	await phone_end(m)


func test_down_and_adrenaline_tips_one_at_a_time_and_brace_tip() -> void:
	await phone_begin()
	# Down + Adrenaline: a Hit in hand and a Hit on top of the loadout.
	var s: MatchState = _fixture({
		"P1": {"area": "motel", "health": 3, "hand": ["hit", "scavenge", "duck"], "loadout": ["hit", "dash", "scavenge", "scavenge", "dash", "duck"]},
		"P2": {"area": "quarry", "health": 5, "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}})
	var m: Control = await _spawn_shell(s, null)
	var coach: Control = m.shell.coach
	assert_true(coach.current in [&"down", &"adrenaline"], "a tip shows: %s" % coach.current)
	var first: StringName = coach.current
	await touch(coach.get_ok_button())
	await tree.process_frame
	assert_true(coach.current in [&"down", &"adrenaline"] and coach.current != first, "then the other one: %s" % coach.current)
	await touch(coach.get_ok_button())
	await tree.process_frame
	assert_false(coach.is_showing(), "both seen")
	assert_true(CoachTips.is_seen(&"down") and CoachTips.is_seen(&"adrenaline"), "remembered")
	m.queue_free()
	await tree.process_frame
	# Brace: the rival shoots the human.
	s = _fixture({"active": "P2",
		"P1": {"area": "rail_yard", "health": 5, "loadout": ["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"]},
		"P2": {"area": "docks", "health": 5, "line": ["pump_shotgun", "hunting_rifle"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}})
	m = await _spawn_shell(s, Shooter.new())
	coach = m.shell.coach
	assert_eq(m.get_controller().phase, &"brace", "brace step")
	assert_eq(coach.current, &"brace", "the Brace tip comes up on the first Brace")
	assert_true("NEXT HAND" in coach.get_body_text(), "brace text: %s" % coach.get_body_text())
	await touch(coach.get_ok_button())
	assert_false(coach.is_showing(), "GOT IT closes it")
	await phone_end(m)


func test_pause_menu_rules_settings_and_concede_to_end_screen() -> void:
	await phone_begin()
	SetupPrefs.set_value("settings", "event_speed", "instant")
	SetupLaunch.request_new({"opponent": "rookie", "first": "me", "route": "C"})
	var m: Control = await spawn(MATCH)
	var ctrl: Node = m.get_controller()
	CoachTips.mark_all_seen()
	await touch(m.get_area_touch(&"farmstead"))
	await touch(m.get_dock_button(&"drop"))
	await touch(m.get_node("%MenuButton"))
	var pm: Control = m.shell.pause_menu
	assert_eq(pm.get_title_text(), "PAUSED", "pause menu")
	check_buttons([pm.get_button(&"resume"), pm.get_button(&"rules"), pm.get_button(&"settings"),
			pm.get_button(&"concede"), pm.get_button(&"leave")], "pause")
	check_labels(pm.get_text_labels(), "pause")
	await touch(pm.get_button(&"rules"))
	assert_eq(pm.get_title_text(), "RULES", "rules page")
	assert_true("BRACE" in (pm.find_child("RulesText", true, false) as Label).text, "rules summary text")
	await touch(pm.get_button(&"back"))
	await touch(pm.get_button(&"settings"))
	check_buttons([pm.get_button(&"motion_on"), pm.get_button(&"speed_fast"), pm.get_button(&"reset_tips")], "settings")
	await touch(pm.get_button(&"speed_fast"))
	assert_eq(PauseSettings.event_speed(), "fast", "event speed saved")
	assert_eq(ctrl.event_delay, 0.2, "fast applied to the running match")
	assert_true(SetupUI.is_checked(pm.get_button(&"speed_fast")), "chosen speed marked with a check")
	await touch(pm.get_button(&"motion_on"))
	assert_true(Settings.reduced_motion, "reduced motion on")
	await touch(pm.get_button(&"motion_off"))
	assert_false(Settings.reduced_motion, "reduced motion off")
	await touch(pm.get_button(&"speed_instant"))
	await touch(pm.get_button(&"back"))
	await touch(pm.get_button(&"concede"))
	assert_eq(pm.get_title_text(), "CONCEDE?", "concede asks first")
	await touch(pm.get_button(&"keep_playing"))
	assert_eq(pm.get_title_text(), "PAUSED", "KEEP PLAYING goes back")
	await touch(pm.get_button(&"concede"))
	await touch(pm.get_button(&"concede_yes"))
	assert_eq(ctrl.phase, &"over", "conceded")
	var end: Control = m.shell.end_screen
	assert_true(end.is_visible_in_tree(), "end screen")
	assert_eq(end.get_summary()["tag"], "CONCEDE", "how it ended: concede")
	assert_eq(end.get_summary()["title"], "THE RIVAL WINS", "winner")
	assert_false(MatchStore.has_saved_match(), "concede clears the save")
	# SEE BOARD, then MENU shows the result again.
	await touch(end.get_button(&"board"))
	assert_false(end.is_visible_in_tree(), "SEE BOARD hides it")
	await touch(m.get_node("%MenuButton"))
	assert_true(end.is_visible_in_tree(), "MENU after the end shows the result again")
	await touch(end.get_button(&"title"))
	assert_eq(SceneRouter.last_requested, "res://scenes/Title.tscn", "TITLE")
	await phone_end(m)


func test_end_screen_words_for_every_cause() -> void:
	var v: Dictionary = {"seat": 0, "round": 9, "me": {"health": 2}, "opponent": {"health": 0}}
	var st: Dictionary = {"turns": 17, "seconds": 372.0, "hits_on_me": 3, "hits_on_rival": 5}
	var cases: Array = [
		[{"result": "win", "winner": 0, "cause": "shot"}, "YOU WIN", "ELIMINATION", "You eliminated the rival with a shot."],
		[{"result": "win", "winner": 1, "cause": "frag"}, "THE RIVAL WINS", "ELIMINATION", "The rival eliminated you with a Frag."],
		[{"result": "win", "winner": 0, "cause": "gas"}, "YOU WIN", "GAS", "The rival was caught in the gas."],
		[{"result": "win", "winner": 1, "cause": "final_circle"}, "THE RIVAL WINS", "FINAL CIRCLE", "You didn't survive the final circle."],
		[{"result": "win", "winner": 0, "cause": "hard_end"}, "YOU WIN", "HARD END", "The Zone ran out. You had more health, so you win."],
		[{"result": "draw", "cause": "hard_end"}, "DRAW", "HARD END", "The Zone ran out with the scores level: a draw."],
		[{"result": "win", "winner": 1, "cause": "concede"}, "THE RIVAL WINS", "CONCEDE", "You conceded."],
		[{"result": "draw", "cause": "final_circle"}, "DRAW", "FINAL CIRCLE", "The final circle took you both out."],
	]
	for c: Array in cases:
		v["match_end"] = c[0]
		var s: Dictionary = EndScreen.summary(v, st)
		assert_eq([s["title"], s["tag"], s["detail"]], [c[1], c[2], c[3]], "end words for %s" % [c[0]])
	assert_eq(EndScreen.summary(v, st)["stats"], "Round 9 · 17 turns · health: you 2, rival 0 · Hits landed: on the rival 5, on you 3 · 6:12", "stats line")



## cz19b BUG-06: hot-seat end screens name the seats in every line, never "you" / "rival".
func test_end_screen_hotseat_names_the_seats() -> void:
	var st: Dictionary = {"turns": 17, "seconds": 372.0, "hits_on_me": 3, "hits_on_rival": 5, "hotseat": true}
	# The final view belongs to Player 1 (seat 0) here; Player 1 died in the gas.
	var v: Dictionary = {"seat": 0, "round": 9, "me": {"health": 0}, "opponent": {"health": 2},
			"match_end": {"result": "win", "winner": 1, "cause": "gas"}}
	var s: Dictionary = EndScreen.summary(v, st)
	assert_eq(s["title"], "PLAYER 2 WINS", "hot-seat title")
	assert_eq(s["detail"], "Player 1 was caught in the gas.", "hot-seat detail")
	assert_eq(s["stats"], "Round 9 · 17 turns · health: P1 0, P2 2 · Hits landed: on P2 5, on P1 3 · 6:12", "hot-seat stats")
	var cases: Array = [
		[1, {"result": "win", "winner": 1, "cause": "shot"}, "Player 2 eliminated Player 1 with a shot."],
		[1, {"result": "win", "winner": 0, "cause": "frag"}, "Player 1 eliminated Player 2 with a Frag."],
		[0, {"result": "win", "winner": 1, "cause": "final_circle"}, "Player 1 didn't survive the final circle."],
		[1, {"result": "win", "winner": 1, "cause": "hard_end"}, "The Zone ran out. Player 2 had more health, so Player 2 wins."],
		[0, {"result": "win", "winner": 1, "cause": "concede"}, "Player 1 conceded."],
		[0, {"result": "draw", "cause": "gas"}, "The gas took both players out."],
		[0, {"result": "draw", "cause": "shot"}, "Both players went out to a shot at the same time."],
	]
	for c: Array in cases:
		v["seat"] = c[0]
		v["match_end"] = c[1]
		s = EndScreen.summary(v, st)
		assert_eq(s["detail"], c[2], "hot-seat words for %s" % [c[1]])
		for word: String in ["you", "You", "rival"]:
			assert_false(word in s["detail"] or word in s["stats"], "no '%s' in hot-seat lines: %s / %s" % [word, s["detail"], s["stats"]])

# --- Helpers ----------------------------------------------------------------------------

func _fixture(players: Dictionary) -> MatchState:
	var setup: Dictionary = {"round": 3, "zone_card": 3, "route": "A", "active": players.get("active", "P1"),
			"players": {"P1": players["P1"], "P2": players["P2"]}}
	var errors: Array = []
	var s: MatchState = MatchState.from_fixture(setup, RulesData.from_card_db(CardDB), {}, errors)
	if not errors.is_empty():
		failures.append("fixture errors: %s" % [errors])
	return s


## A fixture match with the shell attached (no launch request: the shell is attached by hand).
func _spawn_shell(s: MatchState, opponent: Object) -> Control:
	var m: Control = (load(MATCH) as PackedScene).instantiate()
	m.auto_start = false
	m.points_per_px_override = points_per_px()
	m.safe_area_override = safe_rect()
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	ctrl.save_enabled = false
	if opponent != null:
		ctrl.opponent = opponent
	tree.root.add_child(m)
	m.shell = MatchShell.attach(m)
	m.shell.coach.watch(m, ctrl)
	for i: int in 3:
		await tree.process_frame
	m.start_live(s)
	for i: int in 4:
		await tree.process_frame
	return m
