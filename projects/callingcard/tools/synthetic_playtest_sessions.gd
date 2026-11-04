# synthetic_playtest_sessions.gd
# Purpose: cc18 helper. Produces SYNTHETIC playtest exports for testing tools/kpi_sheet.py. It runs
#   the real PlaytestLog autoload headless and drives it through EventBus signals only, the way the
#   game emits them (same approach as tests/test_playtest_log.gd), for three differing personas:
#     A  menu entry, desktop, full walkthrough, survey answered
#     B  Find a Match entry, phone, slow load, weak album pull, D1 cleared slowly
#     C  menu entry, phone, partial: D1 never cleared, survey skipped, no quit line (tab hidden)
#   plus an empty export (consent off: the logger writes nothing).
#   These are NOT player data. Two things are simulated and the export says so:
#     - time: the logger reads the engine clock, so the driver moves PlaytestLog's session and
#       Dossier start ticks back to fake minutes of play (t_ms, session_s, since_start_s, load_ms);
#     - device: a headless run reports a desktop with no browser, so session_start's device fields
#       are patched for the phone personas after export.
#   Every export gets top-level "synthetic": true, and the files are named SYNTHETIC-*.json.
#   tools/kpi_sheet.py leaves synthetic files out unless --include-synthetic is passed.
#
# Usage (from source/project-callingcard; needs no game code change):
#   godot --headless --path . -s ../../tools/synthetic_playtest_sessions.gd -- --out=<dir>
#   (the absolute path of this file also works for -s)
# Writes nothing to the real log: the logger is pointed at user://synthetic_playtest/, which is
#   deleted afterwards, and the Collection autoload stops listening so no save changes.
# Author: Data Scientist Agent
extends SceneTree

const WORK_DIR: String = "user://synthetic_playtest"
const SLOTS: Array[String] = ["b2", "a1", "c3", "a3", "c1", "b1", "b3", "a2", "c2"]
const LINEUP: Array[String] = ["graveyard_shift", "neon_rain", "last_train", "snow_blind", "mayday"]
const LOANER: Array[String] = ["chrome_tiger", "glacier", "brass_tacks", "frostbite", "flare_up"]
const RIVAL_CARDS: Array[String] = ["polar_night", "flare_up", "dead_air", "gold_leaf", "honor_roll"]
const D1: String = "dossier_first_contact"
const D2: String = "dossier_same_page"

var plog: Node
var bus: Node
var out_dir: String = ""
var sim_s: float = 0.0
var _dossier_start_s: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir == "":
		push_error("pass -- --out=<directory>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	plog = root.get_node("PlaytestLog")
	bus = root.get_node("EventBus")
	root.get_node("Collection").listening = false
	var written: Array[String] = []
	written.append(_session("A-menu-desktop", _persona_a, {"device_class": "desktop", "mobile": false,
			"touchscreen": false, "input_type": "mouse", "web": true, "browser": "chrome", "os_family": "windows",
			"viewport": [1280, 720], "window_px": [1920, 1080], "pixel_ratio": 1.5}))
	written.append(_session("B-lobby-phone", _persona_b, {"device_class": "phone", "mobile": true,
			"touchscreen": true, "input_type": "touch", "web": true, "browser": "safari", "os_family": "ios",
			"viewport": [1280, 591], "window_px": [1170, 540], "pixel_ratio": 3.0}))
	written.append(_session("C-menu-phone-partial", _persona_c, {"device_class": "phone", "mobile": true,
			"touchscreen": true, "input_type": "touch", "web": true, "browser": "chrome", "os_family": "android",
			"viewport": [1280, 576], "window_px": [1080, 486], "pixel_ratio": 2.63}))
	written.append(_empty_export())
	for f: String in DirAccess.get_files_at(WORK_DIR):
		DirAccess.remove_absolute(WORK_DIR.path_join(f))
	DirAccess.remove_absolute(WORK_DIR)
	for p: String in written:
		print("wrote %s" % p)
	quit(0)


# =============================================================================
# Session plumbing
# =============================================================================

## Fresh logger state, consent YES, the persona, then export with the synthetic marker.
func _session(tag: String, persona: Callable, device: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	plog.log_path = WORK_DIR.path_join("%s.jsonl" % tag)
	plog.consent_path = WORK_DIR.path_join("%s_consent.cfg" % tag)
	plog.delete_log()
	plog.enabled = false
	plog.consent_answered = false
	plog.auto_prompt = false
	plog.survey_answers = {}
	plog.new_session()
	for key: String in plog.stats:
		if plog.stats[key] is int:
			plog.stats[key] = 0
	plog.set("_duel_index", 0)
	plog.set("_cipher_attempts", 0)
	plog.set("_screen_since_duel_end", true)
	plog.set("_dossier", {})
	plog.set("_duel", {})
	sim_s = 0.0
	persona.call()
	plog.flush()
	var doc: Dictionary = JSON.parse_string(plog.build_export())
	for e: Dictionary in doc["events"]:
		if e["event"] == "session_start":
			for key: String in device:
				e[key] = device[key]
	doc["synthetic"] = true
	doc["synthetic_note"] = "SYNTHETIC test data from tools/synthetic_playtest_sessions.gd (persona %s). Real PlaytestLog, scripted EventBus signals, simulated clock and device. Never count it as a playtest." % tag
	var name: String = "SYNTHETIC-%s.json" % tag
	var f: FileAccess = FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "", false))
	f.close()
	plog.delete_log()
	plog.enabled = false
	return name


## Consent off (the default): the logger writes nothing, so the export holds no events.
func _empty_export() -> String:
	plog.log_path = WORK_DIR.path_join("off.jsonl")
	plog.delete_log()
	plog.enabled = false
	plog.new_session()
	bus.screen_shown.emit(&"hub")
	bus.album_opened.emit(&"night_shift")
	plog.flush()
	var doc: Dictionary = JSON.parse_string(plog.build_export())
	doc["synthetic"] = true
	doc["synthetic_note"] = "SYNTHETIC: consent was off, so the logger wrote nothing (the real game offers no download then; this file only tests the KPI tool)."
	var name: String = "SYNTHETIC-D-consent-off-empty.json"
	var f: FileAccess = FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "", false))
	f.close()
	return name


## Moves the simulated clock to `s` seconds into the session (t_ms and session_s follow it).
func _at(s: float) -> void:
	sim_s = s
	plog.session_started_ms = Time.get_ticks_msec() - int(s * 1000.0)


func _wait(s: float) -> void:
	_at(sim_s + s)


func _consent(load_ms: int, first_screen: StringName) -> void:
	plog.set("_load_ms", load_ms)
	_at(load_ms / 1000.0 + 2.0)
	bus.screen_shown.emit(&"title")
	_wait(6.0)
	plog.set_consent(true, false)
	_wait(3.0)
	bus.screen_shown.emit(first_screen)


## One duel as the duel controller replays it. `capture_every`: a capture on every n-th placement.
func _duel(source: StringName, rival: StringName, first: StringName, loaner: bool, result: StringName,
		score_p: int, score_ai: int, duration_s: float, opts: Dictionary = {}) -> void:
	bus.duel_started.emit(source, rival, first)
	var lineup: Array = LOANER if loaner else LINEUP
	bus.duel_lineup_locked.emit(lineup, &"" if loaner else &"snow_blind", loaner)
	var placements: int = int(opts.get("placements", 9))
	var every: int = int(opts.get("capture_every", 3))
	var side: StringName = first
	var placed: Array[String] = []
	var step: float = duration_s / float(placements)
	for i: int in placements:
		bus.turn_started.emit(side, i + 1)
		var card: StringName = StringName(lineup[i % 5] if side == &"player" else RIVAL_CARDS[i % 5])
		var captures: Array = []
		if i > 0 and i % every == 0:
			captures.append(StringName(placed[i - 1]))
		bus.card_placed.emit(side, card, StringName(SLOTS[i]), captures)
		for s: Variant in captures:
			bus.card_captured.emit(side, &"some_card", s)
		if opts.get("carded_at", -1) == i:
			bus.carded.emit(&"rival" if side == &"player" else &"player", &"snow_blind")
		if opts.get("triptych_at", -1) == i:
			bus.triptych_scored.emit(side, &"midnight_run", true)
		if opts.get("link_at", -1) == i:
			bus.set_linked.emit(side, StringName(SLOTS[i]), [StringName(placed[0])])
		placed.append(SLOTS[i])
		_wait(step)
		side = &"rival" if side == &"player" else &"player"
		if opts.has("stop_after") and i + 1 >= int(opts["stop_after"]):
			bus.score_changed.emit(score_p, score_ai)
			return
	bus.score_changed.emit(score_p, score_ai)
	bus.duel_ended.emit(result, score_p, score_ai, placements, duration_s)


func _dossier_start(id: StringName) -> void:
	bus.screen_shown.emit(&"dossier")
	bus.dossier_started.emit(id)
	_dossier_start_s = sim_s


## A Dossier attempt; on a win the logger derives dossier_clear (its since_start_s from the tick
## moved back to the simulated start).
func _dossier_attempt(id: StringName, win: bool, duration_s: float) -> void:
	var d: Dictionary = plog.get("_dossier")
	if not d.is_empty():
		d["started_ms"] = Time.get_ticks_msec() - int((sim_s - _dossier_start_s) * 1000.0)
	bus.duel_started.emit(&"dossier", id, &"player")
	bus.card_placed.emit(&"player", &"mayday", &"b2", [])
	_wait(duration_s)
	d = plog.get("_dossier")
	d["started_ms"] = Time.get_ticks_msec() - int((sim_s - _dossier_start_s) * 1000.0)
	bus.duel_ended.emit(&"win" if win else &"loss", 3 if win else 1, 0 if win else 2, 2, duration_s)


# =============================================================================
# Personas
# =============================================================================

## A: ENTER THE WALL, desktop. Album keen, rival duels, Cipher Lock, Lobby save + resume, D1 fast.
func _persona_a() -> void:
	_consent(3800, &"hub")
	_wait(8.0)
	_dossier_start(StringName(D1))
	_wait(25.0)
	_dossier_attempt(StringName(D1), true, 74.0)
	bus.card_unlocked.emit(&"long_watch", StringName(D1))
	bus.unlocked.emit(&"card", &"long_watch")
	_wait(10.0)
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"night_shift")
	_wait(12.0)
	bus.card_inspected.emit(&"city_never_sleeps", false)
	_wait(9.0)
	bus.card_inspected.emit(&"graveyard_shift", true)
	bus.album_opened.emit(&"cipher")
	_wait(15.0)
	bus.cipher_attempted.emit(false)
	_wait(20.0)
	bus.cipher_attempted.emit(true)
	bus.cipher_solved.emit()
	bus.card_unlocked.emit(&"key_fragment", &"unlock_cipher_lock")
	bus.unlocked.emit(&"card", &"key_fragment")
	bus.screen_shown.emit(&"lineup")
	_wait(40.0)
	bus.lineup_saved.emit(LINEUP, 10, &"snow_blind", false)
	bus.screen_shown.emit(&"duel")
	_duel(&"rival", &"archivist", &"player", false, &"draw", 5, 5, 182.4, {"carded_at": 4, "link_at": 6})
	_wait(4.0)
	_duel(&"rival", &"archivist", &"rival", false, &"win", 7, 3, 151.0, {"triptych_at": 7})
	bus.unlock_progress.emit(&"unlock_wins_5", 1, 5)
	_wait(6.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"duel")
	_duel(&"rival", &"warden", &"player", false, &"loss", 4, 6, 205.0, {"capture_every": 2})
	bus.screen_shown.emit(&"hub")
	_wait(5.0)
	bus.screen_shown.emit(&"lobby")
	bus.lobby_wait_started.emit(90.0)
	_wait(4.0)
	_duel(&"lobby", &"quartermaster", &"player", false, &"win", 0, 0, 86.0, {"stop_after": 4})
	bus.lobby_duel_saved.emit(true)
	bus.lobby_match_found.emit(&"save")
	bus.screen_shown.emit(&"match_starting")
	_wait(20.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"whiteout")
	bus.card_inspected.emit(&"polar_night", false)
	_wait(30.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"lobby")
	plog.note_resumed_rival(&"quartermaster")
	bus.duel_resumed.emit(312.0)
	_duel_resume_tail(&"loss", 4, 6, 118.0)
	bus.lobby_duel_saved.emit(false)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"survey")
	_wait(70.0)
	plog.record_survey({"q1": 5, "q2": 4, "q3": 4, "q4": 4,
			"open": "SYNTHETIC: wanted the Whiteout set after seeing the silhouettes."})
	plog.export_log()
	_wait(5.0)
	plog._on_quit("close")


## B: FIND A MATCH first, phone, slow load. Lobby duel finished before the match (keep), longer
## duels, default (loaner) lineup, one album open with owned cards only, D1 lost twice.
func _persona_b() -> void:
	_consent(14200, &"lobby")
	plog.log_event(&"input_type", {"kind": "touch"})
	bus.lobby_wait_started.emit(120.0)
	_wait(5.0)
	bus.screen_shown.emit(&"duel")
	_duel(&"lobby", &"quartermaster", &"player", true, &"win", 6, 4, 198.0)
	bus.unlock_progress.emit(&"unlock_wins_5", 1, 5)
	bus.lobby_match_found.emit(&"keep")
	bus.screen_shown.emit(&"match_starting")
	_wait(15.0)
	bus.screen_shown.emit(&"hub")
	_wait(12.0)
	bus.screen_shown.emit(&"duel")
	_duel(&"rival", &"warden", &"rival", true, &"loss", 3, 7, 262.0, {"carded_at": 3, "capture_every": 2})
	_wait(3.0)
	_duel(&"rival", &"warden", &"player", true, &"loss", 4, 6, 288.0, {"capture_every": 2})
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"old_guard")
	_wait(20.0)
	bus.card_inspected.emit(&"chrome_tiger", true)
	bus.cipher_attempted.emit(false)
	_wait(15.0)
	bus.cipher_attempted.emit(false)
	_wait(15.0)
	bus.cipher_attempted.emit(false)
	bus.screen_shown.emit(&"hub")
	_dossier_start(StringName(D1))
	_wait(30.0)
	_dossier_attempt(StringName(D1), false, 58.0)
	_wait(10.0)
	_dossier_attempt(StringName(D1), false, 61.0)
	_wait(12.0)
	_dossier_attempt(StringName(D1), true, 65.0)
	bus.card_unlocked.emit(&"long_watch", StringName(D1))
	bus.unlocked.emit(&"card", &"long_watch")
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"survey")
	_wait(55.0)
	plog.record_survey({"q1": 3, "q2": 2, "q3": 0, "q4": 5,
			"open": "SYNTHETIC: the rival felt hard with the starter cards."})
	plog.export_log()
	_wait(4.0)
	plog._on_quit("pagehide")


## C: ENTER THE WALL, phone. Album twice with a locked card, one rival win, D1 lost and left,
## a Lobby Duel interrupted by the match (keep), survey opened and skipped, then the tab is hidden.
func _persona_c() -> void:
	_consent(8900, &"hub")
	plog.log_event(&"input_type", {"kind": "touch"})
	_wait(6.0)
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"signal_fire")
	_wait(18.0)
	bus.card_inspected.emit(&"open_channel", false)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"duel")
	_duel(&"rival", &"archivist", &"player", true, &"win", 6, 4, 176.0, {"triptych_at": 8})
	bus.screen_shown.emit(&"hub")
	_dossier_start(StringName(D1))
	_wait(20.0)
	_dossier_attempt(StringName(D1), false, 49.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"album")
	bus.album_opened.emit(&"night_shift")
	_wait(10.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"lobby")
	bus.lobby_wait_started.emit(45.0)
	_duel(&"lobby", &"archivist", &"rival", true, &"win", 0, 0, 45.0, {"stop_after": 5})
	bus.lobby_match_found.emit(&"keep")
	bus.screen_shown.emit(&"match_starting")
	_wait(10.0)
	bus.screen_shown.emit(&"hub")
	bus.screen_shown.emit(&"survey")
	_wait(20.0)
	plog.record_survey({"open": ""})
	plog.export_log()
	_wait(3.0)
	plog.log_event(&"app_hidden", {"screen": "survey", "session_s": snappedf(sim_s, 0.1)})


## The rest of a resumed Lobby Duel (no duel_start follows a resume).
func _duel_resume_tail(result: StringName, score_p: int, score_ai: int, duration_s: float) -> void:
	var side: StringName = &"player"
	for i: int in range(4, 9):
		var captures: Array = [StringName(SLOTS[i - 1])] if i % 3 == 0 else []
		bus.card_placed.emit(side, StringName(LINEUP[i % 5] if side == &"player" else RIVAL_CARDS[i % 5]), StringName(SLOTS[i]), captures)
		for s: Variant in captures:
			bus.card_captured.emit(side, &"some_card", s)
		_wait(duration_s / 5.0)
		side = &"rival" if side == &"player" else &"player"
	bus.score_changed.emit(score_p, score_ai)
	bus.duel_ended.emit(result, score_p, score_ai, 9, duration_s)
