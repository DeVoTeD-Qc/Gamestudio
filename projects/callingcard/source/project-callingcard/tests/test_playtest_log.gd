# test_playtest_log.gd
# Purpose: cc16 playtest logger (autoload/playtest_log.gd), consent prompt and survey screen:
#   - schema: a scripted session through EventBus (hub entry, album, lineup, a rival duel that
#     ends in a draw plus a PLAY AGAIN win, unlocks, Cipher Lock, a Lobby Duel saved on "match
#     found" and resumed, a Dossier lost once then cleared, survey, export, quit) logs every
#     event of plan section 8, and every line matches SCHEMA (types, enums, no extra fields),
#   - consent off (the default) writes nothing; the consent prompt's NO keeps it off, YES starts
#     the session,
#   - the survey screen saves its answers (log line + kept on the device),
#   - the download builds valid JSON (one document holding every line) and the file export works,
#   - the hub's PLAYTEST button opens the survey; survey pages fit the phone and desktop screens.
#   Every test points the logger at user://test_playtest/ and switches the Collection autoload's
#   EventBus listening off, so nothing touches a real log or save.
# Author: Data Scientist Agent
extends "res://tests/test_case.gd"

const Lx: GDScript = preload("res://tests/test_lobby_fixtures.gd")
const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")
const TEST_DIR: String = "user://test_playtest"
const SURVEY_SCENE: String = "res://scenes/survey/Survey.tscn"
const PROMPT_SCENE: String = "res://scenes/survey/ConsentPrompt.tscn"
const HUB_SCENE: String = "res://scenes/Hub.tscn"

## Plan section 8 event names -> the logged event that carries it.
const PLAN_EVENTS: Dictionary = {
	"session_start": "session_start", "entry_point": "entry_point", "album_open": "album_open",
	"card_inspect": "card_inspect", "lineup_saved": "lineup_saved", "duel_start": "duel_start",
	"placement": "placement", "carded": "carded", "triptych_scored": "triptych_scored",
	"duel_end": "duel_end", "lobby_wait_start": "lobby_wait_start", "lobby_match_found": "lobby_match_found",
	"duel_resumed": "duel_resumed", "unlock": "unlock", "set_complete": "set_complete",
	"cipher_attempt": "cipher_attempt", "dossier_start": "dossier_start", "dossier_clear": "dossier_clear",
	"survey": "survey", "quit": "quit",
}
## Events a headless run cannot produce (real input, mobile pause / web visibility).
const NOT_DRIVEN: Array[String] = ["input_type", "app_hidden", "app_visible"]

var _saved: Dictionary = {}


func _plog() -> Node:
	return tree.root.get_node("PlaytestLog")


func _bus() -> Node:
	return tree.root.get_node("EventBus")


## Points the autoload at a fresh test file, fresh session, logging off.
func _setup(tag: String) -> Node:
	var plog: Node = _plog()
	_saved = {"log_path": plog.log_path, "consent_path": plog.consent_path, "enabled": plog.enabled,
			"answered": plog.consent_answered, "answers": plog.survey_answers, "auto": plog.auto_prompt,
			"listening": tree.root.get_node("Collection").listening}
	tree.root.get_node("Collection").listening = false
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	plog.log_path = TEST_DIR.path_join("%s.jsonl" % tag)
	plog.consent_path = TEST_DIR.path_join("%s_consent.cfg" % tag)
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	plog.enabled = false
	plog.consent_answered = false
	plog.auto_prompt = false
	plog.survey_answers = {}
	plog.new_session()
	return plog


func _teardown() -> void:
	var plog: Node = _plog()
	plog.flush()
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(f))
	plog.enabled = _saved["enabled"]
	plog.consent_answered = _saved["answered"]
	plog.survey_answers = _saved["answers"]
	plog.auto_prompt = _saved["auto"]
	plog.log_path = _saved["log_path"]
	plog.consent_path = _saved["consent_path"]
	plog.new_session()
	tree.root.get_node("Collection").listening = _saved["listening"]


## One placement as the duel controller replays it: card_placed, set_linked, captures, extras.
func _place(side: StringName, card: StringName, slot: StringName, captured: Array, extras: Callable = Callable()) -> void:
	var bus: Node = _bus()
	bus.card_placed.emit(side, card, slot, captured)
	for s: Variant in captured:
		bus.card_captured.emit(side, &"some_card", s)
	if extras.is_valid():
		extras.call()
	bus.turn_started.emit(&"rival" if side == &"player" else &"player", 2)


## The scripted session for the schema test (only EventBus signals, as the game emits them).
func _scripted_session(plog: Node) -> void:
	var bus: Node = _bus()
	bus.screen_shown.emit(&"title")
	bus.screen_shown.emit(&"hub")
	# Album: two opens, a locked card inspected.
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"night_shift")
	bus.card_inspected.emit(&"city_never_sleeps", false)
	bus.album_opened.emit(&"cipher")
	bus.screen_shown.emit(&"lineup")
	bus.card_inspected.emit(&"snow_blind", true)
	bus.lineup_saved.emit([&"graveyard_shift", &"neon_rain", &"last_train", &"snow_blind", &"mayday"], 10, &"snow_blind", false)
	# Rival duel from the hub: ends in a draw (Tempo tie rule), then PLAY AGAIN and a win.
	bus.screen_shown.emit(&"duel")
	bus.duel_started.emit(&"rival", &"archivist", &"player")
	bus.duel_lineup_locked.emit([&"graveyard_shift", &"neon_rain"], &"snow_blind", false)
	bus.turn_started.emit(&"player", 1)
	_place(&"player", &"graveyard_shift", &"a1", [])
	_place(&"rival", &"polar_night", &"b2", [&"a1"], func() -> void: bus.carded.emit(&"rival", &"snow_blind"))
	_place(&"player", &"last_train", &"b1", [], func() -> void: bus.ambush_sprung.emit(&"player", &"last_train", &"b1"))
	bus.card_placed.emit(&"player", &"neon_rain", &"b3", [&"b2"])
	bus.set_linked.emit(&"player", &"b3", [&"a1"])
	bus.card_captured.emit(&"player", &"polar_night", &"b2")
	bus.card_reclaimed.emit(&"player", &"graveyard_shift", &"a1")
	bus.triptych_scored.emit(&"player", &"midnight_run", true)
	bus.score_changed.emit(5, 5)
	bus.duel_ended.emit(&"draw", 5, 5, 10, 182.4)
	bus.duel_started.emit(&"rival", &"archivist", &"rival")
	_place(&"rival", &"polar_night", &"b2", [])
	bus.duel_ended.emit(&"win", 7, 5, 10, 151.0)
	# Rewards.
	bus.unlock_progress.emit(&"win_three", 1, 3)
	bus.unlock_goal_completed.emit(&"beat_warden")
	bus.card_unlocked.emit(&"polar_night", &"beat_warden")
	bus.unlocked.emit(&"card", &"polar_night")
	bus.unlocked.emit(&"title", &"set_night_shift")
	bus.unlocked.emit(&"frame", &"gold_cipher")
	bus.set_completed.emit(&"night_shift")
	bus.triptych_revealed.emit(&"midnight_run")
	bus.cipher_attempted.emit(false)
	bus.cipher_attempted.emit(true)
	bus.cipher_solved.emit()
	# Lobby Duel: wait, quick duel, match found mid-duel, SAVE & LEAVE; later CONTINUE from the hub.
	bus.screen_shown.emit(&"lobby")
	bus.lobby_wait_started.emit(95.0)
	bus.duel_started.emit(&"lobby", &"quartermaster", &"player")
	bus.duel_lineup_locked.emit([&"graveyard_shift"], &"", true)
	_place(&"player", &"graveyard_shift", &"a1", [])
	_place(&"rival", &"flare_up", &"a2", [])
	bus.score_changed.emit(1, 1)
	bus.lobby_duel_saved.emit(true)
	bus.lobby_match_found.emit(&"save")
	bus.screen_shown.emit(&"match_starting")
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"lobby")
	bus.duel_resumed.emit(312.0)
	_place(&"player", &"neon_rain", &"a3", [&"a2"])
	bus.duel_ended.emit(&"loss", 4, 6, 10, 240.0)
	bus.lobby_duel_saved.emit(false)
	# Dossier D1: lost once, cleared on the retry.
	bus.screen_shown.emit(&"dossier")
	bus.dossier_started.emit(&"d1")
	bus.duel_started.emit(&"dossier", &"d1", &"player")
	_place(&"player", &"mayday", &"b2", [])
	bus.duel_ended.emit(&"loss", 1, 2, 1, 20.0)
	bus.duel_started.emit(&"dossier", &"d1", &"player")
	_place(&"player", &"mayday", &"b1", [&"b2"])
	bus.duel_ended.emit(&"win", 3, 0, 2, 35.5)
	bus.dossier_completed.emit(&"d1")  # a second report of the same clear: not logged twice
	bus.collection_reset.emit()
	bus.screen_shown.emit(&"survey")
	plog.record_survey({"q1": 4, "q2": 5, "q3": 0, "q4": 3, "open": "More\tsets\nplease"})
	plog.export_log()
	plog._on_quit("close")
	plog.flush()


func test_schema_scripted_session() -> void:
	var plog: Node = _setup("schema")
	plog.set_consent(true, false)
	_scripted_session(plog)
	var entries: Array[Dictionary] = plog.read_entries()
	assert_true(entries.size() > 50, "a full session logs plenty of lines (%d)" % entries.size())
	var seen: Dictionary = {}
	var bad: PackedStringArray = []
	var sid: String = plog.session_id
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		seen[e["event"]] = int(seen.get(e["event"], 0)) + 1
		bad.append_array(plog.validate_entry(e))
		if e["sid"] != sid:
			bad.append("line %d has another session id" % i)
		if int(e["seq"]) != i:
			bad.append("line %d has seq %s" % [i, e["seq"]])
	assert_eq(Array(bad), [], "every logged line matches SCHEMA")
	for plan_name: String in PLAN_EVENTS:
		assert_true(seen.has(PLAN_EVENTS[plan_name]), "plan event %s logged" % plan_name)
	for event_name: String in plog.SCHEMA:
		if not NOT_DRIVEN.has(event_name):
			assert_true(seen.has(event_name), "schema event %s produced by the scripted session" % event_name)
	assert_eq(entries[0]["event"], "session_start", "session_start comes first")
	# Spot checks on the KPI fields.
	var by: Dictionary = {}
	for e: Dictionary in entries:
		if not by.has(e["event"]):
			by[e["event"]] = []
		by[e["event"]].append(e)
	assert_eq(by["entry_point"][0]["entry"], "menu", "ENTER THE WALL -> hub is the menu entry")
	assert_eq(by["album_open"].size(), 2, "two album opens")
	assert_eq(int(by["album_open"][1]["count"]), 2, "album open count")
	assert_eq(by["card_inspect"][0]["owned"], false, "locked card inspected")
	var ends: Array = by["duel_end"]
	assert_eq(ends.map(func(e: Dictionary) -> String: return e["result"]), ["draw", "win", "loss", "loss", "win"], "results incl. the draw")
	assert_eq(ends.map(func(e: Dictionary) -> String: return e["source"]), ["rival", "rival", "lobby", "dossier", "dossier"], "duel sources")
	assert_eq(ends[0]["carded_ai"], 1.0, "rival carded the Signature once")
	assert_eq(ends[0]["captures_p"], 1.0, "player captured once")
	assert_eq(ends[0]["captures_ai"], 1.0, "rival captured once")
	assert_eq(ends[0]["triptychs_p"], 1.0, "player Triptych")
	assert_eq(ends[1]["play_again"], true, "PLAY AGAIN duel flagged")
	assert_eq(ends[0]["play_again"], false, "first duel not a replay")
	assert_eq(ends[2]["resumed"], true, "resumed Lobby Duel flagged")
	assert_eq(plog.stats["draws"], 1, "draw counted as its own result")
	assert_eq(plog.stats["wins"], 1, "one non-Dossier win")
	assert_eq(plog.stats["losses"], 1, "one non-Dossier loss")
	var found: Dictionary = by["lobby_match_found"][0]
	assert_eq(found["choice"], "save", "save choice")
	assert_eq(found["duel_state"]["in_duel"], true, "match found mid-duel")
	assert_eq(found["duel_state"]["placements"], 2.0, "two placements before the match was found")
	assert_eq(by["placement"][0]["preview_shown"], true, "player placement previewed")
	var clears: Array = by["dossier_clear"]
	assert_eq(clears.size(), 1, "one Dossier clear logged (no duplicate)")
	assert_eq(clears[0]["attempts"], 2.0, "cleared on the second attempt")
	assert_eq(clears[0]["via"], "duel_end", "clear derived from the winning duel_end")
	var unlock: Dictionary = by["unlock"][0]
	assert_eq([unlock["kind"], unlock["id"], unlock["source"]], ["card", "polar_night", "beat_warden"], "card unlock with its source")
	var survey: Dictionary = by["survey"][0]
	assert_eq([survey["q1"], survey["q2"], survey["q3"], survey["q4"]], [4.0, 5.0, null, 3.0], "survey answers (0 = skipped)")
	assert_eq(survey["open"], "More sets please", "open answer cleaned")
	assert_eq(by["quit"][0]["screen"], "survey", "quit records the screen")
	_teardown()


func test_validator_catches_bad_lines() -> void:
	var plog: Node = _plog()
	var good: Dictionary = {"v": 1, "sid": "ab", "seq": 0, "t_ms": 5, "event": "carded", "by": "player", "card_id": "x", "duel": 1}
	assert_eq(Array(plog.validate_entry(good)), [], "good line passes")
	var extra: Dictionary = good.duplicate()
	extra["name"] = "someone"
	assert_true(plog.validate_entry(extra).size() > 0, "extra field rejected")
	var wrong_side: Dictionary = good.duplicate()
	wrong_side["by"] = "enemy"
	assert_true(plog.validate_entry(wrong_side).size() > 0, "side outside player/rival rejected")
	var missing: Dictionary = good.duplicate()
	missing.erase("duel")
	assert_true(plog.validate_entry(missing).size() > 0, "missing field rejected")
	assert_true(plog.validate_entry({"event": "nope"}).size() > 0, "unknown event rejected")
	var result: Dictionary = {"v": 1, "sid": "ab", "seq": 0, "t_ms": 5, "event": "duel_end", "result": "tie"}
	assert_true(plog.validate_entry(result).size() > 0, "result outside win/loss/draw rejected")


func test_consent_off_logs_nothing() -> void:
	var plog: Node = _setup("off")
	assert_false(plog.enabled, "logging is off by default")
	var lines: Array = []
	var grab: Callable = func(e: Dictionary) -> void: lines.append(e)
	plog.event_logged.connect(grab)
	_scripted_session(plog)
	plog.event_logged.disconnect(grab)
	assert_eq(lines.size(), 0, "no line produced while consent is off")
	assert_false(FileAccess.file_exists(plog.log_path), "no log file written")
	assert_eq(plog.read_all_text(), "", "log empty")
	var result: Dictionary = plog.export_log()
	assert_false(result["ok"], "nothing to download")
	# The consent prompt: NO keeps it off (and is remembered), YES starts the session.
	var prompt: CanvasLayer = (load(PROMPT_SCENE) as PackedScene).instantiate()
	prompt.plog = plog
	tree.root.add_child(prompt)
	await tree.process_frame
	assert_not_null(prompt.get_button(true), "YES button")
	prompt.get_button(false).pressed.emit()
	assert_false(plog.enabled, "NO keeps logging off")
	assert_true(plog.consent_answered, "NO is an answer (no prompt next launch)")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(plog.consent_path), OK, "answer saved")
	assert_eq(cfg.get_value("consent", "given", true), false, "saved as no")
	_bus().album_opened.emit(&"night_shift")
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "still nothing after NO")
	await tree.process_frame
	plog.consent_answered = false
	var prompt2: CanvasLayer = (load(PROMPT_SCENE) as PackedScene).instantiate()
	prompt2.plog = plog
	tree.root.add_child(prompt2)
	await tree.process_frame
	prompt2.get_button(true).pressed.emit()
	await tree.process_frame
	assert_true(plog.enabled, "YES turns logging on")
	var events: Array = plog.read_entries().map(func(e: Dictionary) -> String: return e["event"])
	assert_eq(events.slice(0, 2), ["session_start", "consent"], "YES starts the session")
	# Withdraw: off again and the file is gone.
	plog.withdraw()
	assert_false(plog.enabled, "withdraw turns logging off")
	assert_false(FileAccess.file_exists(plog.log_path), "withdraw deletes the log")
	_teardown()


func test_survey_saves_answers() -> void:
	var plog: Node = _setup("survey")
	var lx: RefCounted = Lx.new(tree)
	var screen: Control = (load(SURVEY_SCENE) as PackedScene).instantiate()
	screen.plog = plog
	await lx.spawn(screen, Lx.PHONE)
	assert_eq(screen.get_page_name(), "OFF", "logging off -> the opt-in page")
	assert_false(plog.enabled, "opening the survey does not opt in")
	screen.get_button("ConsentButton").pressed.emit()
	assert_true(plog.enabled, "TURN ON LOGGING opts in")
	assert_eq(screen.get_page_name(), "QUESTION", "first statement")
	assert_eq(screen._statement.text, plog.SURVEY_QUESTIONS[0]["text"], "q1 is the intent-to-collect statement")
	screen.get_scale_button(4).pressed.emit()
	screen.get_button("SkipButton").pressed.emit()
	screen.get_scale_button(5).pressed.emit()
	screen.get_scale_button(2).pressed.emit()
	assert_eq(screen.get_page_name(), "OPEN", "open question after the four statements")
	screen.get_open_answer().text = "The album silhouettes"
	screen.get_button("SubmitButton").pressed.emit()
	assert_eq(screen.get_page_name(), "DONE", "done page")
	var surveys: Array = plog.read_entries().filter(func(e: Dictionary) -> bool: return e["event"] == "survey")
	assert_eq(surveys.size(), 1, "one survey line")
	if surveys.size() == 1:
		var s: Dictionary = surveys[0]
		assert_eq([s["q1"], s["q2"], s["q3"], s["q4"], s["open"], s["answered"]],
				[4.0, null, 5.0, 2.0, "The album silhouettes", 3.0], "answers logged")
		assert_eq(Array(plog.validate_entry(s)), [], "survey line matches SCHEMA")
	assert_eq(plog.survey_answers.get("q1"), 4, "answers kept in memory")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(plog.consent_path), OK, "answers saved on the device")
	assert_eq((cfg.get_value("survey", "answers", {}) as Dictionary).get("q3"), 5, "saved q3")
	assert_eq((cfg.get_value("survey", "answers", {}) as Dictionary).get("open"), "The album silhouettes", "saved open answer")
	await lx.frames(2)
	var fails: Array[String] = lx.layout_failures(screen, screen.get_key_controls(), Lx.PHONE)
	assert_eq(fails, [] as Array[String], "done page fits the phone")
	# Download from the screen (desktop: a file under user://).
	var result: Dictionary = screen.download_log()
	assert_true(result.get("ok", false), "download from the survey screen")
	# Opening the screen again starts on DONE; ANSWER AGAIN restarts at question 1.
	await lx.despawn()
	var again: Control = (load(SURVEY_SCENE) as PackedScene).instantiate()
	again.plog = plog
	await lx.spawn(again, Lx.DESKTOP)
	assert_eq(again.get_page_name(), "DONE", "answered -> DONE")
	again.get_button("AgainButton").pressed.emit()
	assert_eq(again.get_page_name(), "QUESTION", "ANSWER AGAIN")
	await lx.finish()
	_teardown()


func test_survey_layout_phone_and_desktop() -> void:
	var plog: Node = _setup("survey_layout")
	plog.set_consent(true, false)
	for screen_def: Dictionary in Lx.SCREENS:
		var lx: RefCounted = Lx.new(tree)
		var screen: Control = (load(SURVEY_SCENE) as PackedScene).instantiate()
		screen.plog = plog
		await lx.spawn(screen, screen_def)
		for step: int in 3:
			var fails: Array[String] = lx.layout_failures(screen, screen.get_key_controls(), screen_def)
			assert_eq(fails, [] as Array[String], "%s page fits %s" % [screen.get_page_name(), screen_def["name"]])
			if step == 0:
				for i: int in 4:
					screen.choose(3)
			elif step == 1:
				screen.submit()
			await lx.frames(2)
		await lx.finish()
	plog.enabled = false
	var lx_off: RefCounted = Lx.new(tree)
	var off: Control = (load(SURVEY_SCENE) as PackedScene).instantiate()
	off.plog = plog
	await lx_off.spawn(off, Lx.PHONE)
	assert_eq(lx_off.layout_failures(off, off.get_key_controls(), Lx.PHONE), [] as Array[String], "OFF page fits the phone")
	await lx_off.finish()
	_teardown()


func test_download_builds_valid_json() -> void:
	var plog: Node = _setup("export")
	plog.set_consent(true, false)
	_bus().screen_shown.emit(&"hub")
	_bus().album_opened.emit(&"night_shift")
	_bus().lobby_wait_started.emit(60.0)
	plog.record_survey({"q1": 5, "open": "quote \" and \\ backslash, é"})
	var text: String = plog.build_export()
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the download is one valid JSON document")
	if not parsed is Dictionary:
		_teardown()
		return
	var doc: Dictionary = parsed
	assert_eq(doc["format"], plog.EXPORT_FORMAT, "format tag")
	assert_eq(int(doc["schema_version"]), plog.SCHEMA_VERSION, "schema version")
	assert_eq(doc["session_ids"], [plog.session_id], "one anonymous session id")
	assert_eq(int(doc["event_count"]), (doc["events"] as Array).size(), "event count")
	var bad: PackedStringArray = []
	for e: Variant in doc["events"]:
		bad.append_array(plog.validate_entry(e))
	assert_eq(Array(bad), [], "every exported event matches SCHEMA")
	var survey: Array = (doc["events"] as Array).filter(func(e: Dictionary) -> bool: return e["event"] == "survey")
	assert_eq(survey[0]["open"], "quote \" and \\ backslash, é", "free text survives the round trip")
	# File export (desktop / editor): a .json next to the log, same content plus the log_exported line.
	var result: Dictionary = plog.export_log()
	assert_true(result["ok"], "export ok")
	assert_eq(result["method"], "file", "desktop export writes a file")
	var file_text: String = FileAccess.get_file_as_string(TEST_DIR.path_join(plog.export_file_name()))
	var from_file: Variant = JSON.parse_string(file_text)
	assert_true(from_file is Dictionary and (from_file["events"] as Array).back()["event"] == "log_exported",
			"exported file parses and ends with log_exported")
	assert_true(plog.export_file_name().ends_with(".json"), "download name ends in .json")
	# Personal data: no line carries anything but the schema's fields (checked above); the only
	# identifier is the random 12-hex session id.
	assert_eq(plog.session_id.length(), 12, "session id is 6 random bytes in hex")
	_teardown()


func test_hub_playtest_button_opens_survey() -> void:
	var fx: RefCounted = Fx.new(tree)
	var lx: RefCounted = Lx.new(tree)
	var col: Node = fx.make("hub_playtest")
	var hub: Control = (load(HUB_SCENE) as PackedScene).instantiate()
	hub.collection = col
	await lx.spawn(hub, Lx.PHONE)
	var b: Button = hub.get_button(&"playtest")
	assert_not_null(b, "hub has a PLAYTEST button")
	if b != null:
		lx.router().last_requested = ""
		b.pressed.emit()
		assert_eq(lx.router().last_requested, SURVEY_SCENE, "PLAYTEST opens the survey")
	await lx.finish()
	fx.finish()
