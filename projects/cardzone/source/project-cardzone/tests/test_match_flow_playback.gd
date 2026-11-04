# test_match_flow_playback.gd
# Purpose: cz12 rival turn playback through the real match screen on a phone, by touch:
#   - the rival's turn plays back one step at a time (drew, play, move, loot, Pack) in the
#     playback panel over the empty hand area, the map marks moves / loots / shots (tracer
#     placeholder), busy_changed true -> false and settled bracket it;
#   - FAST speeds the rest of the turn up, SKIP finishes it at once and the toast sums it up;
#     Instant event speed (delay 0) also sums it up; FAST / SKIP reset for the next playback;
#   - a game-feel hold (hold_playback / release_playback) keeps the loop on a step;
#   - the rival's private cards never reach a step, the panel, the toast or the log;
#   - the AI's Brace shows the cards it used.
# Author: UI/UX Agent (cz12)
extends "res://tests/test_match_flow_kit.gd"


## A scripted rival: plays its non-Hit cards, walks to Rail Yard, loots there, ends the turn.
class Wanderer extends RefCounted:
	var kind: String = "Wanderer"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		for t: String in ["brace", "play", "move", "loot"]:
			for a: Dictionary in legal:
				if a["type"] != t or int(a.get("seat", -1)) != seat:
					continue
				if t == "play" and a.has("adrenaline"):
					continue
				if t == "move" and String(a["to"]) != "rail_yard":
					continue
				return a
		for a: Dictionary in legal:
			if a["type"] == "end_turn" and int(a["seat"]) == seat and (a["hold"] as Array).is_empty():
				return a
		return legal[0] if not legal.is_empty() else {}


func _wander_fixture() -> MatchState:
	return _fixture({
		"P1": {"area": "motel", "health": 5, "hand": ["scavenge", "duck"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["dash", "scavenge", "scavenge", "medkit", "duck", "plate_vest", "dash"]}})


func _wait_idle(ctrl: Node, frames: int = 3000) -> int:
	var n: int = 0
	while ctrl.busy and n < frames:
		n += 1
		await tree.process_frame
	return n


func test_rival_turn_plays_back_step_by_step() -> void:
	var m: Control = await _spawn(_wander_fixture(), Wanderer.new())
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.05
	ctrl.opponent_delay = 0.03
	var steps: Array = []
	var busy_log: Array = []
	var panel_now: Array = []
	var marks: Array = []
	ctrl.playback_step.connect(func(st: Dictionary) -> void: steps.append(st))
	ctrl.busy_changed.connect(func(b: bool) -> void: busy_log.append(b))
	var settled: Array = [0]
	ctrl.settled.connect(func() -> void: settled[0] += 1)
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	var saw_panel: bool = false
	var guard: int = 0
	while ctrl.busy and guard < 3000:
		guard += 1
		await tree.process_frame
		var panel: PanelContainer = m.get_playback_panel()
		if panel.visible:
			saw_panel = true
			if panel_now.is_empty() or panel_now.back() != panel.get_now_text():
				panel_now.append(panel.get_now_text())
		var tr: Dictionary = m.get_tracer().mark
		if not tr.is_empty() and (marks.is_empty() or marks.back() != tr):
			marks.append(tr.duplicate())
	assert_false(ctrl.busy, "the rival's turn ends")
	assert_true(saw_panel, "the playback panel showed during the rival's turn")
	var rival: Array = steps.filter(func(st: Dictionary) -> bool: return bool(st["rival"]))
	var kinds: Array = rival.map(func(st: Dictionary) -> StringName: return st["kind"])
	for k: StringName in [&"turn", &"draw", &"play", &"move", &"loot", &"pack"]:
		assert_true(kinds.has(k), "a %s step (%s)" % [k, kinds])
	assert_true(kinds.find(&"move") < kinds.find(&"loot") and kinds.find(&"loot") < kinds.find(&"pack"), "in play order: %s" % [kinds])
	assert_true(panel_now.size() >= 4, "the panel moved step by step (%d texts: %s)" % [panel_now.size(), panel_now])
	assert_true(panel_now.has("Rival moved to Rail Yard."), "the move shown: %s" % [panel_now])
	assert_true(marks.any(func(mk: Dictionary) -> bool: return mk["kind"] == &"move" and mk["to"] == &"rail_yard"), "the move marked on the map: %s" % [marks])
	assert_true(marks.any(func(mk: Dictionary) -> bool: return mk["kind"] == &"loot"), "the loot marked on the map")
	for st: Dictionary in rival:
		assert_true(float(st["duration"]) > 0.0, "rival step %s paced (%.2f s)" % [st["text"], float(st["duration"])])
	var move: Dictionary = rival[kinds.find(&"move")]
	assert_true(float(move["duration"]) > float(rival[kinds.find(&"draw")]["duration"]), "a move stays up longer than a draw")
	assert_eq(busy_log, [true, false], "busy_changed: true, then false")
	assert_true(settled[0] >= 1, "settled after the playback")
	assert_false(m.get_playback_panel().visible, "the panel gives the hand back")
	assert_eq(m.mode, &"act", "your turn")
	_despawn(m)


func test_fast_and_skip_buttons_by_touch() -> void:
	var m: Control = await _spawn(_wander_fixture(), Wanderer.new())
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.4
	ctrl.opponent_delay = 0.3
	var steps: Array = []
	ctrl.playback_step.connect(func(st: Dictionary) -> void: steps.append(st))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	var guard: int = 0
	while not m.get_playback_panel().visible and guard < 600:
		guard += 1
		await tree.process_frame
	assert_true(m.get_playback_panel().visible, "playback panel up")
	var fast: Button = m.get_playback_button(&"fast")
	var skip: Button = m.get_playback_button(&"skip")
	for b: Button in [fast, skip]:
		var r: Rect2 = b.get_global_rect()
		assert_true(minf(r.size.x, r.size.y) >= 64.0 - EPS and m.safe_area_override.grow(EPS).encloses(r), "%s: 64 px, in the safe area %s" % [b.name, r])
	var before: int = steps.size()
	await _touch_playback(m, &"fast")
	assert_true(ctrl.playback_fast, "FAST on")
	assert_eq(fast.text, "FAST ON", "FAST shows it is on")
	assert_true(ctrl.step_duration(&"move") < 0.4 * 0.5, "steps now shorter (%.2f s)" % ctrl.step_duration(&"move"))
	# Wait for the next step, then SKIP: the turn finishes within a few frames.
	guard = 0
	while steps.size() == before and guard < 600:
		guard += 1
		await tree.process_frame
	await _touch_playback(m, &"skip")
	var frames: int = await _wait_idle(ctrl, 600)
	assert_false(ctrl.busy, "SKIP finished the playback")
	assert_true(frames < 30, "within a few frames (%d)" % frames)
	assert_true(m.get_toast_text().begins_with("Rival's turn: "), "the toast sums the turn up: '%s'" % m.get_toast_text())
	assert_true("moved to Rail Yard" in m.get_toast_text() and "packed (0 held)" in m.get_toast_text(), "summary names the moves: '%s'" % m.get_toast_text())
	assert_false(ctrl.playback_fast or ctrl.playback_skip, "FAST / SKIP reset for the next playback")
	assert_eq(m.mode, &"act", "your turn")
	assert_true(ctrl.log_lines.size() > 8, "every step is still in the LOG")
	_despawn(m)


func test_instant_speed_sums_up_and_a_hold_keeps_the_step() -> void:
	# Instant (delay 0): no waits, the toast sums the rival's turn up.
	var m: Control = await _spawn(_wander_fixture(), Wanderer.new())
	var ctrl: Node = m.get_controller()
	var finished: Array = []
	ctrl.playback_finished.connect(func(summary: String, steps: Array, skipped: bool) -> void: finished.append([summary, steps.size(), skipped]))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	assert_false(ctrl.busy, "instant: done at once")
	assert_eq(finished.size(), 1, "playback_finished once")
	if finished.size() == 1:
		assert_true(bool(finished[0][2]), "instant counts as skipped (nothing was watched)")
		assert_true(String(finished[0][0]).begins_with("Rival's turn: played"), "summary: %s" % finished[0][0])
	assert_eq(m.get_toast_text(), finished[0][0] if not finished.is_empty() else "", "the summary in the toast")
	_despawn(m)
	# A game-feel hold on the first rival step keeps the loop there until release.
	m = await _spawn(_wander_fixture(), Wanderer.new())
	ctrl = m.get_controller()
	ctrl.event_delay = 0.01
	ctrl.opponent_delay = 0.01
	var held: Array = [0]
	ctrl.playback_step.connect(func(st: Dictionary) -> void:
		if bool(st["rival"]) and held[0] == 0:
			held[0] = st["index"]
			ctrl.hold_playback())
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	var n: int = 0
	while held[0] == 0 and n < 300:
		n += 1
		await tree.process_frame
	var lines: int = ctrl.log_lines.size()
	for i: int in 20:
		await tree.process_frame
	assert_true(ctrl.busy, "held: still playing back")
	assert_eq(ctrl.log_lines.size(), lines, "no new step while held")
	ctrl.release_playback()
	await _wait_idle(ctrl)
	assert_false(ctrl.busy, "released: the turn finishes")
	assert_true(ctrl.log_lines.size() > lines, "steps went on")
	_despawn(m)


func test_private_cards_never_shown_and_the_ai_brace_reveals_its_cards() -> void:
	# The Veteran rival plays a turn; collect everything the screen could show.
	var s: MatchState = _fixture({
		"P1": {"area": "radio_hill", "health": 5, "hand": ["hunting_rifle", "scavenge"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "quarry", "health": 4, "hand": [], "loadout": ["plate_vest", "duck", "scavenge", "dash", "scavenge", "medkit", "longshot_50", "dash"]}})
	var m: Control = await _spawn(s, CzAI.for_level(&"veteran", 3))
	var ctrl: Node = m.get_controller()
	var shown: Array[String] = []
	var events: Array = []
	ctrl.playback_step.connect(func(st: Dictionary) -> void:
		shown.append(String(st["text"]))
		events.append(st["event"]))
	# The human shoots: the AI braces in front of you and its Brace cards are named.
	await _touch_card(m, &"hand", 0)
	await _touch_dock(m, &"play")
	await _touch_card(m, &"line", 0)
	await _touch_dock(m, &"fire")
	await _wait_idle(ctrl)
	var braced: Array = events.filter(func(e: Dictionary) -> bool: return e["type"] == "braced" and int(e["seat"]) == 1)
	assert_eq(braced.size(), 1, "the AI braced (its Brace step)")
	if braced.size() == 1 and not (braced[0]["card_ids"] as Array).is_empty():
		var name: String = ActionText.card_name(braced[0]["card_ids"][0])
		assert_true(shown.any(func(t: String) -> bool: return t.begins_with("Rival braced with ") and name in t), "the AI's Brace names %s: %s" % [name, shown])
	# Then its whole turn.
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	await _wait_idle(ctrl)
	assert_eq(m.mode, &"act", "back to you")
	# Rival cards that were never public: in its hand at the Pack (stowed unplayed), or still in
	# its loadout. None of their names may appear anywhere, unless the same card id went public.
	var public: Dictionary = {}
	for e: Dictionary in events:
		assert_false(e.has("secret"), "no secret part in a step event (%s)" % e["type"])
		for key: String in ["card_id", "weapon_id", "attachment_id"]:
			if e.has(key):
				public[StringName(str(e[key]))] = true
		for id: Variant in e.get("card_ids", []):
			public[StringName(str(id))] = true
		for inst: Variant in e.get("line_stowed", []):
			public[ctrl.state.card_id(int(inst))] = true
	for cv: Dictionary in ctrl.view()["opponent"]["line"]:
		public[StringName(cv["card"])] = true
	var private: Array = []
	for inst: int in ctrl.state.seats[1].loadout:
		var id: StringName = ctrl.state.card_id(inst)
		if not public.has(id) and not ctrl.state.is_hit(inst) and not private.has(id):
			private.append(id)
	var everything: String = "\n".join(shown) + "\n" + "\n".join(ctrl.log_lines) + "\n" + m.get_toast_text()
	for l: Label in m.get_playback_panel().get_labels():
		everything += "\n" + l.text
	for l: Label in m.get_important_labels():
		everything += "\n" + l.text
	assert_true(not private.is_empty(), "the rival has private cards to check (%s)" % [private])
	for id: StringName in private:
		var nm: String = ActionText.card_name(id)
		if nm in ["Scavenge", "Dash", "Duck"]:
			continue  # Starter names: the human owns the same cards
		assert_false(nm in everything, "private %s never shown" % nm)
	_despawn(m)
