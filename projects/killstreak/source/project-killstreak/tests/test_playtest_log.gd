# test_playtest_log.gd
# Purpose: p16 PlaytestLog checks. EventBus signals become JSONL lines with the common fields
#   (v, sid, seq, t_ms, event) plus exactly the fields in PlaytestLog.SCHEMA; nothing is
#   written before consent; rotation caps the file size; survey answers are recorded and
#   cleaned; withdraw deletes the log; the non-web export writes a file with the same lines.
#   Every test points the live autoload at its own folder under user://test_playtest/ and
#   restores it afterwards (_restore), so a real tester's log is never touched.
# Author: Data Scientist Agent
extends "res://tests/test_case.gd"

const DIR: String = "user://test_playtest"

var _saved: Dictionary = {}


func _plog() -> Node:
	var plog: Node = tree.root.get_node("PlaytestLog")
	_saved = {"log_path": plog.log_path, "consent_path": plog.consent_path,
			"max_file_bytes": plog.max_file_bytes, "max_backups": plog.max_backups}
	var dir: String = DIR.path_join(str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(dir)
	plog.enabled = false
	plog.consent_answered = false
	plog.pre_survey = {}
	plog.log_path = dir.path_join("playtest_log.jsonl")
	plog.consent_path = dir.path_join("consent.cfg")
	plog.new_session()
	return plog


func _restore(plog: Node) -> void:
	plog.flush()
	plog.delete_log()
	if FileAccess.file_exists(plog.consent_path):
		DirAccess.remove_absolute(plog.consent_path)
	DirAccess.remove_absolute(plog.log_path.get_base_dir())
	plog.enabled = false
	plog.consent_answered = false
	plog.pre_survey = {}
	for key: String in _saved:
		plog.set(key, _saved[key])
	plog.new_session()


func _bus() -> Node:
	return tree.root.get_node("EventBus")


## Emits one of every EventBus signal the logger listens to, in a plausible order.
func _play_sample(bus: Node) -> void:
	bus.screen_shown.emit(&"title")
	bus.run_started.emit(1234)
	bus.tutorial_step.emit(1)
	bus.match_started.emit(&"zone_control", &"freight_yard", 0)
	bus.round_started.emit(1)
	bus.card_deployed.emit(&"player", &"rifleman", &"mid")
	bus.card_deployed.emit(&"enemy", &"breacher", &"left")
	bus.streak_changed.emit(2)
	bus.unit_eliminated.emit(7, 3, &"mid", false)
	bus.killstreak_earned.emit(&"recon_drone", 1)
	bus.operator_down.emit(&"player", 1)
	bus.round_summary.emit(1, 1, 4)
	bus.round_ended.emit(1, 2, 1)
	bus.round_started.emit(2)
	bus.killstreak_used.emit(&"recon_drone", 2)
	bus.ability_used.emit(&"frag", &"left")
	bus.preview_toggled.emit(false)
	bus.round_ended.emit(2, 4, 1)
	bus.round_summary.emit(2, 0, 3)
	bus.match_ended.emit(&"win", 2, 191.46)
	var offered: Array[StringName] = [&"medic", &"sniper", &"smg"]
	bus.reward_offered.emit(&"supply_drop", offered)
	bus.reward_picked.emit(&"supply_drop", &"sniper")
	var perks: Array[StringName] = [&"scavenger", &"ghost"]
	bus.reward_offered.emit(&"perk", perks)
	bus.reward_picked.emit(&"perk", &"")
	bus.next_match_requested.emit()
	bus.tickets_changed.emit(2)
	bus.run_ended.emit(&"loss", 1, 400.0)


func _by_event(entries: Array[Dictionary], event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		if e.get("event", "") == event_name:
			out.append(e)
	return out


func test_nothing_written_before_consent() -> void:
	var plog: Node = _plog()
	_play_sample(_bus())
	plog.log_event(&"manual", {"x": 1})
	plog.record_end_survey({"q1": 5})
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "no log file without consent")
	assert_true(plog.read_entries().is_empty(), "no entries without consent")
	assert_true(plog.needs_consent(), "consent still needed")
	plog.set_consent(false)
	_play_sample(_bus())
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "no log file after saying no")
	assert_false(plog.needs_consent(), "a no is remembered")
	_restore(plog)


func test_consent_starts_session_and_is_saved() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	var entries: Array[Dictionary] = plog.read_entries()
	assert_eq(entries.size(), 2, "session_start + consent")
	if entries.size() >= 2:
		assert_eq(entries[0]["event"], "session_start", "first line")
		assert_eq(entries[1]["event"], "consent", "second line")
		var s: Dictionary = entries[0]
		for key: String in ["platform", "os_family", "device_class", "screen", "load_ms", "engine"]:
			assert_true(s.has(key), "session_start has %s" % key)
		var screen: Dictionary = s.get("screen", {})
		for key: String in ["window_px", "points", "pixel_ratio", "base", "logical", "pt_per_px", "compact"]:
			assert_true(screen.has(key), "screen profile has %s" % key)
		assert_eq(s["sid"], plog.session_id, "session id")
		assert_eq(int(s["v"]), plog.SCHEMA_VERSION, "schema version")
	# Consent survives a restart (load_consent on the same file).
	plog.enabled = false
	plog.consent_answered = false
	plog.load_consent()
	assert_true(plog.enabled, "stored consent re-enables logging")
	assert_false(plog.needs_consent(), "stored consent answers the question")
	_restore(plog)


func test_events_become_lines_with_schema_fields() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	_play_sample(_bus())
	var entries: Array[Dictionary] = plog.read_entries()
	var names: Dictionary = {}
	var last_seq: int = -1
	var last_t: int = -1
	for e: Dictionary in entries:
		var event_name: String = e.get("event", "")
		names[event_name] = true
		assert_true(plog.SCHEMA.has(event_name), "event %s is in SCHEMA" % event_name)
		var expected: Array = plog.COMMON_FIELDS.duplicate()
		expected.append_array(plog.SCHEMA.get(event_name, []))
		var keys: Array = e.keys()
		expected.sort()
		keys.sort()
		assert_eq(keys, expected, "%s fields" % event_name)
		assert_eq(e["sid"], plog.session_id, "%s sid" % event_name)
		assert_true(int(e["seq"]) == last_seq + 1, "seq increases by one (%s)" % event_name)
		assert_true(int(e["t_ms"]) >= last_t, "t_ms is monotonic (%s)" % event_name)
		last_seq = int(e["seq"])
		last_t = int(e["t_ms"])
	for event_name: String in ["screen", "run_start", "tutorial_step", "match_start", "card_played",
			"elimination", "killstreak_earned", "operator_down", "round_end", "round_stats",
			"killstreak_used", "ability_used", "preview_toggled", "match_end", "offer_shown",
			"reward_pick", "perk_pick", "next_match_clicked", "tickets", "run_end"]:
		assert_true(names.has(event_name), "logged %s" % event_name)

	var rounds: Array[Dictionary] = _by_event(entries, "round_end")
	assert_eq(rounds.size(), 2, "two round_end lines")
	if rounds.size() == 2:
		assert_eq(int(rounds[0]["supply_unspent"]), 1, "summary before round_ended is merged")
		assert_eq(int(rounds[0]["hand_size"]), 4, "hand size merged")
		assert_eq(int(rounds[0]["streak"]), 2, "streak at round end")
		assert_eq(rounds[1]["supply_unspent"], null, "summary after round_ended is not merged")
	var stats_lines: Array[Dictionary] = _by_event(entries, "round_stats")
	assert_eq(stats_lines.size(), 1, "late summary gets its own line")
	var cards: Array[Dictionary] = _by_event(entries, "card_played")
	assert_eq(cards.size(), 2, "both sides' plays")
	if cards.size() == 2:
		assert_eq(cards[0]["card_id"], "rifleman", "card id")
		assert_eq(cards[0]["zone"], "mid", "zone")
		assert_eq(int(cards[0]["round"]), 1, "round")
	var ends: Array[Dictionary] = _by_event(entries, "match_end")
	if ends.size() == 1:
		var m: Dictionary = ends[0]
		assert_eq(m["result"], "win", "match result")
		assert_eq(int(m["rounds"]), 2, "rounds")
		assert_eq(int(m["killstreaks_used"]), 1, "killstreaks used in match")
		assert_eq(int(m["max_streak"]), 2, "max streak")
		assert_eq(int(m["cards_played"]), 1, "player cards in match")
		assert_eq(int(m["operator_downs"]), 1, "operator downs")
	else:
		assert_true(false, "one match_end")
	var pick: Array[Dictionary] = _by_event(entries, "reward_pick")
	if pick.size() == 1:
		assert_eq(pick[0]["offered"], ["medic", "sniper", "smg"], "offered ids")
		assert_eq(pick[0]["chosen"], "sniper", "chosen id")
		assert_eq(pick[0]["skipped"], false, "not skipped")
	var perk: Array[Dictionary] = _by_event(entries, "perk_pick")
	if perk.size() == 1:
		assert_eq(perk[0]["skipped"], true, "perk skipped")
		assert_eq(perk[0]["chosen"], null, "no perk chosen")
	var next: Array[Dictionary] = _by_event(entries, "next_match_clicked")
	if next.size() == 1:
		assert_true(float(next[0]["seconds_after_end"]) >= 0.0, "seconds after match end")
	# Every line is one JSON object on its own line.
	for line: String in plog.read_all_text().split("\n", false):
		assert_true(JSON.parse_string(line) is Dictionary, "line parses: %s" % line.left(60))
	_restore(plog)


func test_rotation_caps_size() -> void:
	var plog: Node = _plog()
	plog.max_file_bytes = 4000
	plog.max_backups = 2
	plog.set_consent(true)
	for i: int in 400:
		plog.log_event(&"filler", {"i": i, "pad": "x".repeat(40)})
		if i % 10 == 0:
			plog.flush()
	plog.flush()
	var files: PackedStringArray = plog.log_files()
	assert_eq(files.size(), 3, "current + 2 backups")
	var total: int = 0
	for path: String in files:
		var size: int = FileAccess.open(path, FileAccess.READ).get_length()
		total += size
		assert_true(size <= 4000, "%s is %d bytes, cap 4000" % [path, size])
	assert_true(total <= 4000 * 3, "total %d within cap" % total)
	var entries: Array[Dictionary] = plog.read_entries()
	assert_true(entries.size() > 0, "entries remain")
	if entries.size() > 0:
		assert_eq(int(entries[-1].get("i", -1)), 399, "newest line kept")
		var seqs_in_order: bool = true
		for j: int in range(1, entries.size()):
			if int(entries[j]["seq"]) <= int(entries[j - 1]["seq"]):
				seqs_in_order = false
		assert_true(seqs_in_order, "backups are read oldest first")
	assert_false(FileAccess.file_exists(plog.backup_path(3)), "no third backup")
	_restore(plog)


func test_surveys_recorded_and_cleaned() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	plog.record_pre_survey(true, false, true)
	assert_eq(plog.segment(), "shooter", "segment")
	assert_false(plog.needs_pre_survey(), "pre-survey answered")
	var long_text: String = "Slide\ncancel\tplease  " + "y".repeat(800)
	var recorded: Dictionary = plog.record_end_survey({"q1": 5, "q2": 4, "q3": 9, "q4": 2.5, "open": long_text})
	assert_eq(recorded["q3"], null, "out-of-range answer stored as null")
	assert_eq(recorded["q4"], null, "non-integer answer stored as null")
	assert_eq(recorded["q5"], null, "missing answer stored as null")
	var entries: Array[Dictionary] = plog.read_entries()
	var pre: Array[Dictionary] = _by_event(entries, "pre_survey")
	var post: Array[Dictionary] = _by_event(entries, "end_survey")
	assert_eq(pre.size(), 1, "pre_survey line")
	assert_eq(post.size(), 1, "end_survey line")
	if pre.size() == 1:
		assert_eq(pre[0]["segment"], "shooter", "segment on line")
		assert_eq(pre[0]["deckbuilder"], true, "deckbuilder answer")
	if post.size() == 1:
		assert_eq(int(post[0]["q1"]), 5, "q1")
		assert_eq(int(post[0]["q2"]), 4, "q2")
		var open: String = post[0]["open"]
		assert_eq(open.length(), plog.MAX_TEXT_CHARS, "open answer capped")
		assert_false(open.contains("\n") or open.contains("\t"), "control characters removed")
		assert_true(open.begins_with("Slide cancel please y"), "spaces collapsed: %s" % open.left(30))
		assert_eq(post[0]["segment"], "shooter", "segment repeated on end_survey")
	# The pre-survey answer is stored with the consent, so it is asked once per device.
	plog.pre_survey = {}
	plog.load_consent()
	assert_eq(plog.segment(), "shooter", "segment survives a restart")
	assert_eq(PlaytestLogScript.segment_for(true, true), "both", "both")
	assert_eq(PlaytestLogScript.segment_for(false, true), "card", "card")
	assert_eq(PlaytestLogScript.segment_for(false, false), "neither", "neither")
	_restore(plog)


const PlaytestLogScript: GDScript = preload("res://autoload/playtest_log.gd")


func test_withdraw_deletes_log() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	_play_sample(_bus())
	plog.flush()
	assert_true(FileAccess.file_exists(plog.log_path), "log exists")
	plog.withdraw()
	assert_false(plog.enabled, "logging off")
	assert_true(plog.log_files().is_empty(), "files deleted")
	_play_sample(_bus())
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "nothing written after withdraw")
	_restore(plog)


func test_export_and_summary() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	_play_sample(_bus())
	var result: Dictionary = plog.export_log()
	assert_true(result["ok"], "export ok: %s" % result["error"])
	assert_eq(result["method"], "file", "headless export saves a file")
	var exported: String = FileAccess.get_file_as_string(result["path"])
	assert_eq(exported, plog.read_all_text(), "export matches the log")
	assert_true(exported.contains("\"log_exported\""), "export is itself logged")
	var summary: String = plog.summary_text()
	assert_true(summary.contains(plog.session_id), "summary has session id")
	assert_true(summary.contains("1 matches (1 W / 0 L / 0 D)"), "summary has results:\n%s" % summary)
	assert_true(summary.contains("1 earned, 1 used"), "summary has killstreaks")
	DirAccess.remove_absolute(result["path"])
	_restore(plog)


func test_empty_export_reports_error() -> void:
	var plog: Node = _plog()
	var result: Dictionary = plog.export_log()
	assert_false(result["ok"], "nothing to export")
	assert_true(String(result["error"]) != "", "error text")
	_restore(plog)


func test_device_class() -> void:
	var phone: Dictionary = {"points": [844, 390]}
	var ipad: Dictionary = {"points": [1024, 768]}
	assert_eq(PlaytestLogScript._device_class(phone, true), "phone", "mobile OS, short side 390")
	assert_eq(PlaytestLogScript._device_class(phone, false, true), "phone", "touch screen, short side 390")
	assert_eq(PlaytestLogScript._device_class(ipad, true, true), "tablet", "iPad")
	assert_eq(PlaytestLogScript._device_class(ipad, false, true), "desktop", "touch laptop")
	assert_eq(PlaytestLogScript._device_class(phone, false, false), "desktop", "small desktop window")


func test_input_type_only_logged_after_consent() -> void:
	var plog: Node = _plog()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	plog._input(touch)
	plog.set_consent(true)
	plog._input(touch)
	plog._input(touch)
	var lines: Array[Dictionary] = _by_event(plog.read_entries(), "input_type")
	assert_eq(lines.size(), 1, "first touch after consent logged once")
	assert_eq(int(plog.stats["inputs"]["touch"]), 3, "all touches counted for the summary")
	_restore(plog)
