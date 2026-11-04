# test_hotseat_flow.gd
# Purpose: cz14 "done when": a full hot-seat match plays touch-only on the phone (Match.tscn at
#   844x390 pt @3x + notch, real InputEventScreenTouch), both seats through the real UI with the
#   kit's touch policy, every pass-the-device cover tapped through. Checks: the match ends; a cover
#   came up at every seat change (drop, each turn, each defender's Brace) and nothing could be
#   done behind it; every emitted view belongs to the seat on screen; the screen never showed a
#   card the watching seat may not know (test_hotseat_kit.gd walk); each seat's LOG is its own;
#   the playtest log (cz18) wrote no seat's private cards (turn_start.hand_ids / pack.hold_ids are
#   empty, mode "hotseat") and kept no private list in its cached view.
# Author: Mechanics Developer Agent (cz14)
extends "res://tests/test_hotseat_kit.gd"


func test_full_hotseat_match_touch_only_with_covers() -> void:
	var plog: Node = tree.root.get_node("PlaytestLog")
	var saved: Dictionary = {"log_path": plog.log_path, "consent_path": plog.consent_path, "enabled": plog.enabled,
			"answered": plog.consent_answered, "auto": plog.auto_prompt}
	var dir: String = "user://test_hotseat/%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	plog.log_path = dir.path_join("log.jsonl")
	plog.consent_path = dir.path_join("consent.cfg")
	plog.auto_prompt = false
	plog.delete_log()
	plog.set_consent(true, false)
	var entries: Array[Dictionary] = []
	var on_entry: Callable = func(e: Dictionary) -> void: entries.append(e)
	plog.event_logged.connect(on_entry)
	brace_policy = "alternate"
	brace_taps.clear()
	brace_vias.clear()
	var m: Control = await _spawn_hotseat(null)
	var ctrl: Node = m.get_controller()
	assert_true(ctrl.hotseat, "hot-seat mode from meta")
	assert_true(ctrl.is_covered(), "a hot-seat match starts behind the cover")
	assert_eq(ctrl.cover_seat, MatchState.P2, "Player 2 drops first (S5)")
	assert_eq(String(m.get_cover().get_texts()["heading"]), "PASS TO PLAYER 2", "cover heading")
	assert_true(ctrl.legal().is_empty() and ctrl.request({"type": "drop", "area": "motel"}) != "",
			"nothing can be done behind the cover")
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await _play_hotseat(m, 1500)
	assert_true(bool(r["over"]), "the hot-seat match ends by touch (%d decisions, %d cover taps)" % [int(r["decisions"]), int(r["taps"])])
	assert_true(m.get_sheet_title() in ["YOU WIN", "THE RIVAL WINS", "DRAW"], "end sheet: '%s'" % m.get_sheet_title())
	for t: String in ["drop", "play", "end_turn"]:
		assert_true((r["kinds"] as Dictionary).has(t), "%s done by touch" % t)
	var reasons: Dictionary = {}
	for c: Dictionary in covers:
		reasons[c["reason"]] = int(reasons.get(c["reason"], 0)) + 1
	assert_true(int(r["taps"]) >= 10, "covers tapped through: %d" % int(r["taps"]))
	assert_eq(int(r["taps"]), covers.size(), "every cover that went up was tapped")
	assert_true(reasons.has(&"drop") and reasons.has(&"turn"), "drop and turn covers: %s" % reasons)
	assert_true(reasons.has(&"brace"), "a cover before the defender's Brace prompt: %s" % reasons)
	assert_true(not brace_taps.is_empty(), "a Brace was made through the Brace panel after its cover")
	assert_true(view_checks > 50, "views checked: %d" % view_checks)
	assert_true(walk_checks > 50, "screen walks: %d (%d with cards to look for)" % [walk_checks, walk_armed])
	assert_eq(leaks, [] as Array[String], "no private card of the other seat ever reached the screen")
	assert_false(MatchStore.has_saved_match(), "the end clears the save")
	# Each seat's LOG is its own: the shown seat's lines only (each starts with its own drop or the rival's).
	assert_true(ctrl.log_lines.size() > 0, "the shown seat has a log")
	# Playtest log: mode, no private cards of either seat.
	plog.flush()
	var starts: Array = entries.filter(func(e: Dictionary) -> bool: return e["event"] == "match_start")
	assert_eq(starts.size(), 1, "one match_start")
	if starts.size() == 1:
		assert_eq(starts[0]["mode"], "hotseat", "logged as hot-seat")
		assert_eq(int(starts[0]["human_seat"]), 0, "\"human\" = Player 1")
	var turns: int = 0
	var packs: int = 0
	var bad: Array = []
	for e: Dictionary in entries:
		var errs: PackedStringArray = plog.validate_entry(e)
		if not errs.is_empty():
			bad.append("%s: %s" % [e["event"], errs])
		match String(e["event"]):
			"turn_start":
				turns += 1
				if not (e["hand_ids"] as Array).is_empty():
					bad.append("turn_start.hand_ids %s" % [e["hand_ids"]])
			"pack":
				packs += 1
				if not (e["hold_ids"] as Array).is_empty():
					bad.append("pack.hold_ids %s" % [e["hold_ids"]])
	assert_true(turns > 4 and packs > 2, "turns and packs logged (%d, %d)" % [turns, packs])
	assert_eq(bad, [], "no private card ids (and schema-valid lines) in the hot-seat log")
	var cached: Dictionary = plog.get("_view")
	var me: Dictionary = cached.get("me", {})
	assert_true((me.get("hand", []) as Array).is_empty() and (me.get("loadout", []) as Array).is_empty()
			and not cached.has("brace_prompt"), "the logger's cached view keeps no private list in hot-seat")
	print("     hot-seat: %d decisions, %d covers %s, braces %s, %s, %.1f s" % [int(r["decisions"]), covers.size(), reasons,
			brace_taps, ActionText.result_text(ctrl.view()["match_end"], 0), (Time.get_ticks_msec() - t0) / 1000.0])
	plog.event_logged.disconnect(on_entry)
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	plog.enabled = saved["enabled"]
	plog.consent_answered = saved["answered"]
	plog.auto_prompt = saved["auto"]
	plog.log_path = saved["log_path"]
	plog.consent_path = saved["consent_path"]
	_despawn(m)


func test_each_seat_keeps_its_own_log_and_hears_what_the_other_did() -> void:
	var m: Control = await _spawn_hotseat(null)
	var ctrl: Node = m.get_controller()
	var summaries: Array = []
	ctrl.playback_finished.connect(func(s: String, _st: Array, _k: bool) -> void: summaries.append(s))
	await _tap_cover(m)  # Player 2: drop
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P2, &"drop"], "Player 2's drop")
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"drop")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "pass to Player 1 after the drop")
	assert_eq(m.get_toast_text(), "", "no toast left under the cover")
	await _tap_cover(m)  # Player 1: sees where Player 2 landed
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P1, &"drop"], "Player 1's drop")
	assert_true(not summaries.is_empty() and "Player 2: dropped into" in String(summaries.back()),
			"Player 1 hears Player 2's drop: %s" % [summaries])
	assert_true("dropped into" in m.get_toast_text(), "the catch-up line is in the toast: '%s'" % m.get_toast_text())
	var p1_log: PackedStringArray = ctrl.log_lines.duplicate()
	assert_true(p1_log.size() == 1 and "Rival dropped" in p1_log[0], "Player 1's log: %s" % [p1_log])
	await _touch_area(m, &"quarry")
	await _touch_dock(m, &"drop")
	# Player 1 takes the first turn (S6): the same seat goes on, so no cover in between.
	assert_false(ctrl.is_covered(), "no cover between Player 1's drop and Player 1's first turn")
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P1, &"act"], "Player 1's first turn")
	assert_eq(m.get_cards(&"hand").size(), 5, "Player 1's hand on screen")
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P2, "END TURN passes to Player 2")
	assert_true(m.get_cards(&"hand").is_empty() and m.get_cards(&"next").is_empty(), "no card under the cover")
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P2, &"act"], "Player 2's turn")
	var p2_log: PackedStringArray = ctrl.log_lines.duplicate()
	assert_true(p2_log.size() > 0 and "You dropped" in p2_log[0], "Player 2's own log: %s" % [p2_log])
	for line: String in p2_log:
		assert_false(line.begins_with("You drew") and line in p1_log, "Player 1's draw line is not in Player 2's log")
	_check_screen(m, "after the drops")
	assert_eq(leaks, [] as Array[String], "no leaks")
	_despawn(m)
