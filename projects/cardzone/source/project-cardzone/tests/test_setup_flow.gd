# test_setup_flow.gd
# Purpose: cz13 "a new player can start, finish and replay a match without help", by TOUCH only,
#   on the phone: Title -> NEW MATCH -> Match setup (Rookie AI, Me first, route B; Hot-seat
#   selectable since cz14, see test_hotseat_setup.gd) -> START -> the match screen (shell: coach tips dismissed with GOT IT as
#   they come) -> the drop and a whole match against the AI (CzAI Rookie when it loads, else the
#   placeholder) -> the end screen (winner, cause tag, stats) -> NEW MATCH (same setup) ->
#   MENU -> LEAVE TO TITLE (saved) -> CONTINUE, also after a simulated reload.
#   Also: setup choices S1 / S2 (Alternate swaps, Pick for me rotates A, B, C), the human as P2
#   when the opponent goes first, and the setup screen's layout on the phone.
# Author: UI/UX Agent (cz13)
extends "res://tests/test_setup_helpers.gd"

const TITLE: String = "res://scenes/Title.tscn"
const SETUP: String = "res://scenes/setup/MatchSetup.tscn"
const MATCH: String = "res://scenes/match/Match.tscn"
const CZ_AI: String = "res://scripts/ai/cz_ai.gd"


func test_touch_only_title_setup_full_match_end_new_match_and_continue() -> void:
	await phone_begin()
	# Title with no save: no CONTINUE, NEW MATCH is the main button.
	var title: Control = await spawn(TITLE)
	var tb: Dictionary = title.get_buttons()
	assert_false((tb[&"continue"] as Button).visible, "no CONTINUE without a saved match")
	assert_eq((tb[&"new_match"] as Button).theme_type_variation, &"DockButton", "NEW MATCH is the main button")
	await touch(tb[&"new_match"])
	# Match setup.
	var setup: Control = await follow(title, SETUP)
	await touch(setup.get_choice_button("opponent", "hotseat"))
	assert_eq(setup.choices["opponent"], "hotseat", "hot-seat can be chosen (cz14)")
	await touch(setup.get_choice_button("opponent", "rookie"))
	await touch(setup.get_choice_button("first", "me"))
	await touch(setup.get_choice_button("route", "B"))
	assert_eq(setup.choices, {"opponent": "rookie", "first": "me", "route": "B"}, "choices by touch")
	assert_true(setup.get_choice_button("route", "B").text.begins_with("✓"), "chosen route marked with a check")
	assert_true("route B" in setup.get_next_text() and "you take the first turn" in setup.get_next_text(),
			"next-match line: %s" % setup.get_next_text())
	await touch(setup.get_button(&"start"))
	assert_true(SetupLaunch.has_pending(), "START leaves a launch request")
	# The match: the shell starts it from the setup choices.
	var m: Control = await follow(setup, MATCH)
	var ctrl: Node = m.get_controller()
	assert_not_null(m.shell, "match started from setup runs the shell")
	assert_eq(ctrl.state.route, DataEnums.Route.B, "route B")
	assert_eq(ctrl.human, MatchState.P1, "Me first: the human is P1")
	assert_eq(ctrl.event_delay, 0.0, "event speed (instant in tests) applied")
	_check_opponent(ctrl, "rookie")
	assert_eq(ctrl.phase, &"drop", "the drop happens on the match screen (P2 dropped first)")
	await _play_to_end(m)
	# End screen.
	var end: Control = m.shell.end_screen
	assert_true(end.is_visible_in_tree(), "end screen shown")
	var sum: Dictionary = end.get_summary()
	assert_true(sum["title"] in ["YOU WIN", "THE RIVAL WINS", "DRAW"], "winner shown: %s" % sum["title"])
	assert_true(sum["tag"] in ["ELIMINATION", "GAS", "FINAL CIRCLE", "HARD END", "CONCEDE"], "cause shown: %s" % sum["tag"])
	assert_true(sum["stats"].begins_with("Round "), "stats line: %s" % sum["stats"])
	print("     cz13 flow: %s · %s · %s · %s" % [sum["title"], sum["tag"], sum["detail"], sum["stats"]])
	check_buttons([end.get_button(&"new_match"), end.get_button(&"title"), end.get_button(&"board")], "end screen")
	check_labels(end.get_text_labels(), "end screen")
	assert_false(MatchStore.has_saved_match(), "the end clears the save")
	assert_true(CoachTips.seen_count() >= 1, "coach tips came up and were dismissed (%d seen)" % CoachTips.seen_count())
	# NEW MATCH: same setup again.
	var first_state: MatchState = ctrl.state
	await touch(end.get_button(&"new_match"))
	assert_false(end.is_visible_in_tree(), "end screen closes")
	assert_true(ctrl.state != first_state, "a new match started")
	assert_eq(ctrl.phase, &"drop", "new match at the drop")
	assert_eq(ctrl.state.route, DataEnums.Route.B, "same route")
	_check_opponent(ctrl, "rookie")
	# Drop, then leave to the title: the match is saved.
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"drop")
	assert_eq(ctrl.phase, &"act", "dropped")
	var saved_print: String = ctrl.state.fingerprint()
	await touch(m.get_node("%MenuButton"))
	assert_true(m.shell.pause_menu.visible, "MENU opens the pause menu")
	await touch(m.shell.pause_menu.get_button(&"leave"))
	assert_true(MatchStore.has_saved_match(), "LEAVE TO TITLE keeps the save")
	title = await follow(m, TITLE)
	tb = title.get_buttons()
	assert_true((tb[&"continue"] as Button).is_visible_in_tree(), "CONTINUE shown with a saved match")
	var info: String = (title.get_node("%ContinueInfo") as Label).text
	assert_true("Round 1" in info and "Rookie" in info, "continue line: %s" % info)
	check_buttons(tb.values(), "title")
	# Simulated reload: forget everything in memory, keep only what is on disk.
	title.queue_free()
	await _simulate_reload()
	title = await spawn(TITLE)
	tb = title.get_buttons()
	assert_true((tb[&"continue"] as Button).is_visible_in_tree(), "CONTINUE after a reload")
	await touch(tb[&"continue"])
	m = await follow(title, MATCH)
	ctrl = m.get_controller()
	assert_eq(ctrl.state.fingerprint(), saved_print, "CONTINUE resumes the exact saved match")
	assert_eq(ctrl.phase, &"act", "resumed at the human's turn")
	_check_opponent(ctrl, "rookie")
	await phone_end(m)


func test_alternate_and_pick_for_me_rotate_per_device() -> void:
	await phone_begin()
	var c: Dictionary = {"opponent": "rookie", "first": "alternate", "route": "rotate"}
	var seats: Array = []
	var routes: Array = []
	for i: int in 4:
		var r: Dictionary = SetupLaunch.resolve(c)
		seats.append(r["human_seat"])
		routes.append(r["route_letter"])
		SetupLaunch._commit(c, r)
	assert_eq(seats, [0, 1, 0, 1], "Alternate: P1 on the first match ever, then swaps")
	assert_eq(routes, ["A", "B", "C", "A"], "Pick for me: A, B, C in rotation")
	assert_eq(SetupLaunch.resolve({"first": "me", "route": "C"})["human_seat"], 0, "Me = P1")
	assert_eq(SetupLaunch.resolve({"first": "opponent", "route": "C"})["human_seat"], 1, "Opponent first = the human is P2")
	assert_eq(SetupLaunch.last_choices(), c, "last choices remembered")
	assert_eq(SetupLaunch.why_not({"opponent": "hotseat"}), "", "hot-seat can start (cz14)")
	await phone_end()


func test_opponent_first_makes_the_human_p2_who_drops_first() -> void:
	await phone_begin()
	SetupLaunch.request_new({"opponent": "rookie", "first": "opponent", "route": "A"})
	var m: Control = await spawn(MATCH)
	var ctrl: Node = m.get_controller()
	assert_eq(ctrl.human, MatchState.P2, "the human is P2")
	assert_eq(ctrl.phase, &"drop", "P2 drops first: the human's drop")
	assert_eq(String(ctrl.view()["opponent"]["area"]), "", "the rival has not dropped yet")
	await _touch_area(m, &"docks")
	await _touch_dock(m, &"drop")
	assert_eq(String(ctrl.view()["me"]["area"]), "docks", "the human dropped")
	assert_true(ctrl.view()["opponent"]["area"] != &"", "then the rival (P1) dropped and took the first turn")
	assert_eq(int(MatchStore.saved_info()["meta"]["human_seat"]), 1, "human seat saved")
	await phone_end(m)


func test_setup_layout_on_phone() -> void:
	await phone_begin()
	var setup: Control = await spawn(SETUP)
	var buttons: Array = []
	for r: Array in setup.ROWS:
		for o: Array in r[2]:
			buttons.append(setup.get_choice_button(r[0], o[0]))
	buttons.append(setup.get_button(&"start"))
	buttons.append(setup.get_button(&"back"))
	check_buttons(buttons, "setup")
	check_labels(setup.get_text_labels(), "setup")
	for i: int in buttons.size():
		for j: int in range(i + 1, buttons.size()):
			assert_false((buttons[i] as Button).get_global_rect().intersects((buttons[j] as Button).get_global_rect()),
					"setup buttons don't overlap: %s / %s" % [buttons[i].text, buttons[j].text])
	assert_true("gas closes" in (setup.get_node("SafeArea/Column/AboutLabel") as Label).text or setup.choices["route"] == "rotate",
			"route text explains the gas order")
	await touch(setup.get_button(&"back"))
	assert_eq(SceneRouter.last_requested, TITLE, "BACK goes to the title")
	await phone_end(setup)


# --- Helpers ----------------------------------------------------------------------------

func _check_opponent(ctrl: Node, level: String) -> void:
	var ai_ok: bool = ResourceLoader.exists(CZ_AI) and (load(CZ_AI) as GDScript).can_instantiate()
	if ai_ok:
		assert_true("level" in ctrl.opponent and String(ctrl.opponent.get("level")) == level,
				"CzAI %s plays (%s)" % [level, ctrl.opponent_kind()])
	else:
		assert_eq(ctrl.opponent_kind(), "Placeholder", "placeholder fallback: %s" % SetupLaunch.ai_fallback_reason())
		print("     NOTE: CzAI did not load; the placeholder played (%s)" % SetupLaunch.ai_fallback_reason())


## Everything a reload loses: the launch request, MatchStore's memory, the Title's state.
func _simulate_reload() -> void:
	SetupLaunch.clear_pending()
	MatchStore.refresh()
	# A brand-new store reading the same file must see the same match (what the next boot does).
	var fresh: Node = (load("res://autoload/match_store.gd") as GDScript).new()
	assert_true(fresh.call("has_saved_match"), "a fresh MatchStore finds the save on disk")
	fresh.free()
	await tree.process_frame


func _dismiss_coach(m: Control) -> void:
	var guard: int = 0
	while m.shell != null and m.shell.coach.is_showing() and guard < 8:
		guard += 1
		await touch(m.shell.coach.get_ok_button())
		await tree.process_frame


func _play_to_end(m: Control) -> void:
	var ctrl: Node = m.get_controller()
	var guard: int = 0
	var turn_actions: int = 0
	var last_round: int = -1
	while ctrl.phase != &"over" and guard < 1200:
		guard += 1
		await _dismiss_coach(m)
		var legal: Array[Dictionary] = ctrl.legal()
		if legal.is_empty():
			await tree.process_frame
			continue
		if int(ctrl.view()["round"]) != last_round:
			last_round = int(ctrl.view()["round"])
			turn_actions = 0
		var a: Dictionary = _pick(ctrl, legal, turn_actions)
		turn_actions += 1
		var before: int = ctrl.state.actions.size()
		await _do_by_touch(m, a)
		await _dismiss_coach(m)
		if ctrl.state.actions.size() == before and ctrl.phase != &"over":
			failures.append("touch did not apply %s (notice '%s', mode %s)" % [a, m.last_notice, m.mode])
			break
	assert_eq(ctrl.phase, &"over", "the match reaches its end by touch (%d decisions)" % guard)
	await tree.process_frame


## Same touch policy as cz11's full-match test: shoot, loot, play, move, then end the turn.
func _pick(ctrl: Node, legal: Array[Dictionary], n: int) -> Dictionary:
	var by: Dictionary = {}
	for a: Dictionary in legal:
		if not by.has(a["type"]):
			by[a["type"]] = []
		by[a["type"]].append(a)
	for t: String in ["drop", "brace", "shoot", "loot", "attach", "play"]:
		if by.has(t) and (n < 14 or t == "brace" or t == "drop"):
			if t == "brace":
				return by[t].back()
			return by[t][0]
	if by.has("move") and n < 14 and int(ctrl.view()["me"]["search"]) == 0:
		return by["move"][0]
	var ends: Array = by.get("end_turn", [])
	return ends.back() if not ends.is_empty() else legal[0]


func _do_by_touch(m: Control, a: Dictionary) -> void:
	var ctrl: Node = m.get_controller()
	match String(a["type"]):
		"drop":
			await _touch_area(m, StringName(a["area"]))
			await _touch_dock(m, &"drop")
		"brace":
			for inst: Variant in a["cards"]:
				var ids: Array = m.get_state()["you"]["next_ids"]
				await _touch_card(m, &"next", ids.find(int(inst)))
			await _dismiss_coach(m)
			await touch(m.get_brace_button(&"brace"))  # cz12: BRACE is on the Brace panel
		"play":
			var i: int = (m.get_state()["you"]["hand_ids"] as Array).find(int(a["card"]))
			await _touch_card(m, &"hand", i)
			var key: StringName = &"play"
			if a.has("adrenaline"):
				key = &"adrenaline_move" if a["adrenaline"] == "move" else &"adrenaline_search"
			await _touch_dock(m, key)
		"move":
			await _touch_area(m, StringName(a["to"]))
			await _touch_dock(m, &"move")
		"loot":
			await _touch_area(m, StringName(ctrl.view()["me"]["area"]))
			await _touch_dock(m, &"loot")
			var key: StringName = StringName("loot_" + str(a["pile"])) if a.has("pile") else &""
			if key == &"":
				for b: Button in m.get_sheet_buttons():
					if String(b.get_meta(&"key")).ends_with("_%d" % int(a["card"])):
						key = b.get_meta(&"key")
			await touch(m.get_sheet_button(key))
		"shoot":
			var idx: int = _line_index(m, int(a["weapon"]))
			await _touch_card(m, &"line", idx)
			await _touch_dock(m, &"fire")
		"attach":
			var att: int = int(a["attachment"])
			var hi: int = (m.get_state()["you"]["hand_ids"] as Array).find(att)
			if hi >= 0:
				await _touch_card(m, &"hand", hi)
			else:
				await _touch_card(m, &"line", _line_index(m, att))
			await _touch_dock(m, &"attach")
			if m.is_sheet_open():
				await touch(m.get_sheet_button(StringName("attach_%d" % int(a["weapon"]))))
		"end_turn":
			await touch(m.get_corner_buttons()[&"end_turn"])
			await _dismiss_coach(m)  # the Hold tip comes up with the first Pack
			for inst: Variant in a.get("hold", []):
				var ids: Array = m.get_state()["you"]["hand_ids"]
				await _touch_card(m, &"hand", ids.find(int(inst)))
			await _touch_dock(m, &"end_turn")
		_:
			failures.append("no touch path for %s" % a)


func _line_index(m: Control, inst: int) -> int:
	var line: Array = m.get_state()["you"]["line"]
	for i: int in line.size():
		if int(line[i]["id"]) == inst:
			m.get_line_scroll().ensure_control_visible(m.get_cards(&"line")[i])
			return i
	return -1


func _touch_card(m: Control, zone: StringName, index: int) -> void:
	await _dismiss_coach(m)
	await tree.process_frame
	var cards: Array[Control] = m.get_cards(zone)
	if index < 0 or index >= cards.size():
		failures.append("no %s card %d (have %d)" % [zone, index, cards.size()])
		return
	var c: Control = cards[index]
	var r: Rect2 = c.get_global_rect()
	var pos: Vector2 = r.get_center()
	var parent: Node = c.get_parent()
	if c is CzCard and parent != null and c.get_index() + 1 < parent.get_child_count():
		var nxt: Control = parent.get_child(c.get_index() + 1)
		pos = Vector2((r.position.x + minf(r.end.x, nxt.get_global_rect().position.x)) * 0.5, r.get_center().y)
	await touch_at(pos)


func _touch_area(m: Control, area: StringName) -> void:
	await _dismiss_coach(m)
	await touch(m.get_area_touch(area))


func _touch_dock(m: Control, key: StringName) -> void:
	await _dismiss_coach(m)
	var b: Button = m.get_dock_button(key)
	if b == null:
		failures.append("dock has no %s (keys %s, title '%s', notice '%s')" % [key, m.get_dock_keys(), m.get_dock_title(), m.last_notice])
		return
	await touch(b)
