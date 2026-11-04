# test_match_flow_ai.gd
# Purpose: cz12 "done when": a full match against each AI level (CzAI.for_level Rookie and Veteran,
#   cz09) is playable on a phone, touch only, through the real match screen (Match.tscn at
#   844x390 pt @3x + notch, real InputEventScreenTouch). Event pacing is on (short delays) so the
#   rival's turns really play back through the playback panel. Every human Brace goes through the
#   Brace panel: the suggestion (USE SUGGESTED + BRACE = 2 taps) alternating with an adjusted one.
#   Checks per match: it ends with the end sheet, the human dropped / played / ended turns by touch,
#   accepted suggestions took exactly 2 taps, the playback panel showed rival steps, no step carried
#   a private (secret) part, and the save is cleared at the end.
# Author: UI/UX Agent (cz12)
extends "res://tests/test_match_flow_kit.gd"


func test_full_match_vs_rookie_touch_only() -> void:
	await _full_match(&"rookie", 11)


func test_full_match_vs_veteran_touch_only() -> void:
	await _full_match(&"veteran", 5)


func _full_match(level: StringName, ai_seed: int) -> void:
	brace_policy = "alternate"
	brace_taps.clear()
	brace_vias.clear()
	brace_used = 0
	brace_adjusted = 0
	var m: Control = await _spawn(null, CzAI.for_level(level, ai_seed))
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.004
	ctrl.opponent_delay = 0.002
	assert_eq(ctrl.opponent_kind(), String(level).capitalize(), "the %s AI plays" % level)
	var rival_steps: Array = [0]
	var secrets: Array = [0]
	var panel_seen: Array = [0]
	ctrl.playback_step.connect(func(st: Dictionary) -> void:
		if bool(st["rival"]):
			rival_steps[0] += 1
		if (st["event"] as Dictionary).has("secret"):
			secrets[0] += 1
		if m.get_playback_panel().visible:
			panel_seen[0] += 1)
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await _play_to_end(m, 1200)
	assert_true(bool(r["over"]), "the match vs %s ends by touch (%d decisions)" % [level, int(r["decisions"])])
	assert_true(m.get_sheet_title() in ["YOU WIN", "THE RIVAL WINS", "DRAW"], "end sheet: '%s'" % m.get_sheet_title())
	for t: String in ["drop", "play", "end_turn"]:
		assert_true((r["kinds"] as Dictionary).has(t), "%s done by touch" % t)
	assert_true(int(rival_steps[0]) > 20, "the rival's turns played back (%d steps)" % int(rival_steps[0]))
	assert_true(int(panel_seen[0]) > 0, "the playback panel showed rival steps (%d)" % int(panel_seen[0]))
	assert_eq(int(secrets[0]), 0, "no step carried a private part")
	assert_true(not brace_taps.is_empty(), "the human braced at least once through the Brace panel")
	var two_tap: bool = true
	for i: int in brace_taps.size():
		if brace_vias[i] == "suggested" and brace_taps[i] > 2:
			two_tap = false
	assert_true(two_tap, "accepting the suggestion takes at most 2 taps: %s %s" % [brace_taps, brace_vias])
	assert_false(MatchStore.has_saved_match(), "the end clears the save")
	print("     vs %s: %d decisions, %d rival steps, braces %s (used %d, adjusted %d), %s, %.1f s" % [level, int(r["decisions"]),
			int(rival_steps[0]), brace_taps, brace_used, brace_adjusted, ActionText.result_text(ctrl.view()["match_end"], 0),
			(Time.get_ticks_msec() - t0) / 1000.0])
	_despawn(m)
