# playtest_log.gd
# Purpose: PlaytestLog autoload (p16). Listens to EventBus only (no gameplay code calls it) and
#   appends one JSON object per line to user://playtest_log.jsonl for the playtest KPIs in
#   documentation/production/playtest-metrics-plan.md. Also owns consent, the survey answers,
#   the "Download log" export and the plain-text summary.
#
#   Every line: {"v": SCHEMA_VERSION, "sid": <anonymous session id>, "seq": n, "t_ms": ms since
#   this session started (monotonic), "event": <name>, ...fields}. The event list and fields
#   are in SCHEMA below (keep it in sync with the handlers; tests check it).
#
#   Privacy: nothing is written until the tester consents (set_consent(true)). The session id
#   is random per launch and is not tied to any account. No names, emails, IPs, locations,
#   raw user agents or free text other than the optional open survey answer (capped at
#   MAX_TEXT_CHARS, and the screen asks testers to leave out personal details).
#   withdraw() turns logging off and deletes the log files.
#
#   Size: when the current file would pass max_file_bytes it is rotated to .1.jsonl (older
#   backups shift up, the oldest past max_backups is deleted), so the log never exceeds about
#   max_file_bytes * (max_backups + 1).
# Dependencies: EventBus (signals), RunState and SceneRouter (read only, optional),
#   scripts/ui/screen_profile.gd (screen profile numbers).
# Author: Data Scientist Agent (p01 stub: Mechanics Developer Agent)
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")

## Emitted after consent is given or withdrawn.
signal consent_changed(given: bool)
## Emitted for every line written (after the line is queued), mainly for tests and debug.
signal event_logged(entry: Dictionary)

const SCHEMA_VERSION: int = 1
## Bump when the consent text changes in a way testers must agree to again.
const CONSENT_VERSION: int = 1
const LOG_PATH: String = "user://playtest_log.jsonl"
const CONSENT_PATH: String = "user://playtest_consent.cfg"
const MAX_FILE_BYTES: int = 1_000_000
const MAX_BACKUPS: int = 1
const MAX_TEXT_CHARS: int = 500
const DOWNLOAD_MIME: String = "application/octet-stream"

## Event name -> fields it carries besides v / sid / seq / t_ms / event. Documentation and test
## oracle: every line the logger writes has exactly the common fields plus these.
const SCHEMA: Dictionary = {
	"session_start": ["schema", "consent_version", "platform", "os_family", "web", "browser",
			"standalone", "embedded", "mobile", "touchscreen", "device_class", "engine", "build",
			"load_ms", "date_utc", "screen", "segment"],
	"consent": ["given"],
	"input_type": ["kind"],
	"screen_profile": ["screen"],
	"screen": ["name"],
	"app_hidden": ["screen", "session_s"],
	"app_visible": ["screen", "session_s"],
	"quit": ["screen", "session_s", "reason"],
	"tutorial_step": ["step"],
	"run_start": ["seed", "killstreaks", "deck_size", "tickets"],
	"run_end": ["result", "matches", "duration_s", "wins", "losses", "draws"],
	"tickets": ["tickets"],
	"match_start": ["mode", "map", "match", "threat", "rival", "squad"],
	"round_end": ["round", "score", "enemy_score", "streak", "supply_unspent", "hand_size"],
	"round_stats": ["round", "supply_unspent", "hand_size"],
	"card_played": ["side", "card_id", "zone", "round"],
	"elimination": ["by", "victim", "zone", "by_killstreak", "round"],
	"operator_down": ["side", "round"],
	"killstreak_earned": ["id", "round", "streak"],
	"killstreak_used": ["id", "round"],
	"match_end": ["result", "rounds", "duration_s", "match", "max_streak", "killstreaks_earned",
			"killstreaks_used", "cards_played", "operator_downs"],
	"next_match_clicked": ["seconds_after_end"],
	"offer_shown": ["kind", "offered"],
	"reward_pick": ["kind", "offered", "chosen", "skipped"],
	"attachment_pick": ["kind", "offered", "chosen", "skipped"],
	"perk_pick": ["kind", "offered", "chosen", "skipped"],
	"preview_toggled": ["on"],
	"pre_survey": ["shooter_weekly", "card_weekly", "deckbuilder", "segment"],
	"end_survey": ["q1", "q2", "q3", "q4", "q5", "open", "segment"],
	"log_exported": ["method", "bytes"],
}
const COMMON_FIELDS: Array[String] = ["v", "sid", "seq", "t_ms", "event"]
## Reward kind (RewardOffers) -> event name.
const PICK_EVENTS: Dictionary = {
	&"supply_drop": "reward_pick", &"attachment": "attachment_pick", &"perk": "perk_pick",
}
## End-survey statements (1-5 agreement) and the open question, from the metrics plan.
const END_QUESTIONS: Array[String] = [
	"It felt like a modern shooter match.",
	"I understood why I won or lost firefights.",
	"I had interesting choices each round.",
	"Killstreaks felt exciting.",
	"I want to play another run.",
]
const OPEN_QUESTION: String = "What shooter thing did you expect to see that was missing?"

## True only while the tester has consented. Off by default so tests and editor runs write nothing.
var enabled: bool = false
var log_path: String = LOG_PATH
var consent_path: String = CONSENT_PATH
var max_file_bytes: int = MAX_FILE_BYTES
var max_backups: int = MAX_BACKUPS
## Random per launch; regenerate with new_session().
var session_id: String = ""
var session_started_ms: int = 0
## True once the tester answered the consent question (either way) for CONSENT_VERSION.
var consent_answered: bool = false
## Pre-survey answers ({} until answered); persisted with the consent so it is asked once.
var pre_survey: Dictionary = {}
var end_survey_done: bool = false
## Running totals for the copy-able summary (this session only).
var stats: Dictionary = {}

var _seq: int = 0
var _pending: PackedStringArray = []
var _flush_queued: bool = false
var _session_logged: bool = false
var _load_ms: int = 0
var _screen: String = ""
var _round: int = 0
var _streak: int = 0
var _match: Dictionary = {}
var _match_index: int = 0
var _round_summaries: Dictionary = {}
var _last_offer: Dictionary = {}
var _last_match_end_ms: int = -1
var _inputs_seen: Dictionary = {}
var _profile_timer: Timer = null
var _js_callbacks: Array = []


func _ready() -> void:
	new_session()
	_load_ms = _measure_load_ms()
	_connect_bus()
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null and router.has_signal("scene_change_finished"):
		router.scene_change_finished.connect(_on_scene_changed)
	_profile_timer = Timer.new()
	_profile_timer.one_shot = true
	_profile_timer.wait_time = 0.75
	_profile_timer.timeout.connect(_on_profile_settled)
	add_child(_profile_timer)
	get_tree().root.size_changed.connect(func() -> void: _profile_timer.start())
	# Headless runs (tests, exports) never pick up a stored consent.
	if DisplayServer.get_name() != "headless":
		load_consent()
		_listen_to_page()


## Starts a fresh anonymous session (new id, clock, counters). Called once at startup.
func new_session() -> void:
	session_id = _random_id()
	session_started_ms = Time.get_ticks_msec()
	_seq = 0
	_session_logged = false
	_screen = ""
	_round = 0
	_streak = 0
	_match = {}
	_match_index = 0
	_round_summaries = {}
	_last_offer = {}
	_last_match_end_ms = -1
	_inputs_seen = {}
	end_survey_done = false
	stats = {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "rounds": 0, "cards_played": 0,
			"killstreaks_earned": 0, "killstreaks_used": 0, "matches_with_killstreak": 0,
			"operator_downs": 0, "max_streak": 0, "runs": 0, "run_result": "", "next_match_60s": 0,
			"next_match_clicks": 0, "tutorial_steps": 0, "inputs": {}}


# =============================================================================
# Consent
# =============================================================================

## True when the consent screen should be shown (never answered for this CONSENT_VERSION).
func needs_consent() -> bool:
	return not consent_answered


## True when logging is on but the pre-survey was not answered yet.
func needs_pre_survey() -> bool:
	return enabled and pre_survey.is_empty()


## Records the tester's answer. Yes starts logging (session_start first); no keeps it off.
func set_consent(given: bool, persist: bool = true) -> void:
	consent_answered = true
	var was_enabled: bool = enabled
	enabled = given
	if persist:
		_save_consent()
	if given and not was_enabled:
		if not _session_logged:
			_session_logged = true
			_write("session_start", _session_info())
		_write("consent", {"given": true})
		flush()
	if given != was_enabled:
		consent_changed.emit(given)


## Turns logging off and deletes every log file on this device. The answer is remembered
## (no consent screen next launch); set_consent(true) turns it back on.
func withdraw() -> void:
	set_consent(false)
	_pending.clear()
	delete_log()


func load_consent() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(consent_path) != OK:
		return
	if int(cfg.get_value("consent", "version", 0)) != CONSENT_VERSION:
		return
	var saved: Variant = cfg.get_value("survey", "pre", {})
	if saved is Dictionary:
		pre_survey = saved
	if bool(cfg.get_value("consent", "given", false)):
		set_consent(true, false)
	else:
		consent_answered = true


func _save_consent() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("consent", "version", CONSENT_VERSION)
	cfg.set_value("consent", "given", enabled)
	cfg.set_value("survey", "pre", pre_survey)
	_ensure_dir(consent_path)
	if cfg.save(consent_path) != OK:
		push_warning("PlaytestLog: cannot save %s" % consent_path)


# =============================================================================
# Writing
# =============================================================================

## Appends one event line. No-op while disabled. Prefer the EventBus signals; this stays for
## events that have no signal (and for the p01 API).
func log_event(event_name: StringName, data: Dictionary = {}) -> void:
	_write(String(event_name), data)


## Writes queued lines to disk now (normally done at the end of the frame).
func flush() -> void:
	_flush_queued = false
	if _pending.is_empty():
		return
	var chunk: String = "\n".join(_pending) + "\n"
	_pending.clear()
	var bytes: int = chunk.to_utf8_buffer().size()
	if FileAccess.file_exists(log_path):
		var current: int = _file_size(log_path)
		if current > 0 and current + bytes > max_file_bytes:
			_rotate()
	_ensure_dir(log_path)
	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file == null:
		push_warning("PlaytestLog: cannot open %s (%s)" % [log_path, error_string(FileAccess.get_open_error())])
		return
	file.seek_end()
	file.store_string(chunk)
	file.close()


func _write(event_name: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry: Dictionary = {
		"v": SCHEMA_VERSION, "sid": session_id, "seq": _seq,
		"t_ms": Time.get_ticks_msec() - session_started_ms, "event": event_name,
	}
	for key: Variant in data:
		entry[String(key)] = _plain(data[key])
	_seq += 1
	_pending.append(JSON.stringify(entry))
	event_logged.emit(entry)
	if not _flush_queued:
		_flush_queued = true
		flush.call_deferred()


## Moves log -> log.1 -> log.2 ... and drops the oldest past max_backups.
func _rotate() -> void:
	if max_backups <= 0:
		DirAccess.remove_absolute(log_path)
		return
	var oldest: String = backup_path(max_backups)
	if FileAccess.file_exists(oldest):
		DirAccess.remove_absolute(oldest)
	for i: int in range(max_backups - 1, 0, -1):
		if FileAccess.file_exists(backup_path(i)):
			DirAccess.rename_absolute(backup_path(i), backup_path(i + 1))
	DirAccess.rename_absolute(log_path, backup_path(1))


## Path of the n-th rotated file (1 = newest backup).
func backup_path(n: int) -> String:
	return "%s.%d.jsonl" % [log_path.trim_suffix(".jsonl"), n]


## Every log file that exists, oldest first.
func log_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for i: int in range(max_backups, 0, -1):
		if FileAccess.file_exists(backup_path(i)):
			files.append(backup_path(i))
	if FileAccess.file_exists(log_path):
		files.append(log_path)
	return files


## The whole log (backups first), as JSON lines.
func read_all_text() -> String:
	flush()
	var text: String = ""
	for path: String in log_files():
		text += FileAccess.get_file_as_string(path)
	return text


## The whole log parsed into Dictionaries (bad lines are skipped).
func read_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: String in read_all_text().split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out


func delete_log() -> void:
	for path: String in log_files():
		DirAccess.remove_absolute(path)


# =============================================================================
# Surveys
# =============================================================================

## Segment from the pre-survey (metrics plan): shooter / card / both / neither.
static func segment_for(shooter_weekly: bool, card_weekly: bool) -> String:
	if shooter_weekly and card_weekly:
		return "both"
	if shooter_weekly:
		return "shooter"
	if card_weekly:
		return "card"
	return "neither"


func segment() -> String:
	return String(pre_survey.get("segment", ""))


func record_pre_survey(shooter_weekly: bool, card_weekly: bool, deckbuilder: bool) -> void:
	pre_survey = {
		"shooter_weekly": shooter_weekly, "card_weekly": card_weekly, "deckbuilder": deckbuilder,
		"segment": segment_for(shooter_weekly, card_weekly),
	}
	_write("pre_survey", pre_survey)
	if consent_answered:
		_save_consent()
	flush()


## answers: {"q1".."q5": int 1-5 (anything else is stored as null = skipped), "open": String}.
func record_end_survey(answers: Dictionary) -> Dictionary:
	var entry: Dictionary = {}
	for i: int in END_QUESTIONS.size():
		var key: String = "q%d" % (i + 1)
		var value: Variant = answers.get(key, null)
		var ok: bool = (value is int or value is float) and int(value) == value and int(value) >= 1 and int(value) <= 5
		entry[key] = int(value) if ok else null
	entry["open"] = clean_text(String(answers.get("open", "")))
	entry["segment"] = segment()
	_write("end_survey", entry)
	end_survey_done = true
	flush()
	return entry


## Trims, collapses control characters and caps free text at MAX_TEXT_CHARS.
static func clean_text(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		out += " " if c < 32 or c == 127 else text[i]
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.left(MAX_TEXT_CHARS)


# =============================================================================
# Export
# =============================================================================

## File name for downloads: killstreak-playtest-<date>-<sid>.jsonl.
func export_file_name() -> String:
	return "killstreak-playtest-%s-%s.jsonl" % [Time.get_date_string_from_system(true), session_id]


## "Download log": on the web the browser downloads the JSONL (Blob + anchor, through
## JavaScriptBridge.download_buffer); elsewhere a copy is saved under user:// and its real
## path is returned. Returns {ok, method: "download"|"file", path, bytes, lines, error}.
func export_log() -> Dictionary:
	var web: bool = OS.has_feature("web")
	if enabled:
		# Size of what was on disk before this line; the line itself is in the file too.
		_write("log_exported", {"method": "download" if web else "file", "bytes": _total_bytes()})
	var text: String = read_all_text()
	var buffer: PackedByteArray = text.to_utf8_buffer()
	var result: Dictionary = {"ok": false, "method": "download" if web else "file", "path": "",
			"bytes": buffer.size(), "lines": text.count("\n"), "error": ""}
	if buffer.is_empty():
		result["error"] = "The log is empty."
		return result
	if web:
		JavaScriptBridge.download_buffer(buffer, export_file_name(), DOWNLOAD_MIME)
		result["ok"] = true
		result["path"] = export_file_name()
		return result
	var path: String = log_path.get_base_dir().path_join(export_file_name())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["error"] = "Cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		return result
	file.store_buffer(buffer)
	file.close()
	result["ok"] = true
	result["path"] = ProjectSettings.globalize_path(path)
	return result


## Short plain-text summary a tester can paste into a form or message (no personal data).
func summary_text() -> String:
	var lines: PackedStringArray = []
	lines.append("KillingCard playtest summary (log v%d)" % SCHEMA_VERSION)
	lines.append("Session: %s  Date: %s" % [session_id, Time.get_date_string_from_system(true)])
	var info: Dictionary = _device_info()
	lines.append("Device: %s / %s / %s, %s, input %s" % [info["device_class"], info["os_family"],
			info["browser"], _screen_text(info["screen"]), _primary_input()])
	lines.append("Segment: %s" % (segment() if segment() != "" else "not answered"))
	lines.append("Played: %d min, %d matches (%d W / %d L / %d D), %d rounds" % [
			int(_session_s() / 60.0), stats["matches"], stats["wins"], stats["losses"], stats["draws"], stats["rounds"]])
	if stats["runs"] > 0:
		lines.append("Run: %s" % stats["run_result"])
	lines.append("Killstreaks: %d earned, %d used; matches with one used: %d of %d" % [
			stats["killstreaks_earned"], stats["killstreaks_used"], stats["matches_with_killstreak"], stats["matches"]])
	lines.append("Best streak: %d; Operator down: %d; cards played: %d" % [
			stats["max_streak"], stats["operator_downs"], stats["cards_played"]])
	lines.append("Next match within 60 s: %d of %d" % [stats["next_match_60s"], stats["next_match_clicks"]])
	lines.append("Logging: %s" % ("on" if enabled else "off"))
	return "\n".join(lines)


## Copies summary_text() to the clipboard and returns it (so a screen can also show it).
func copy_summary() -> String:
	var text: String = summary_text()
	DisplayServer.clipboard_set(text)
	return text


# =============================================================================
# EventBus handlers
# =============================================================================

func _connect_bus() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		push_warning("PlaytestLog: EventBus missing, nothing will be logged")
		return
	var hooks: Dictionary = {
		"run_started": _on_run_started, "run_ended": _on_run_ended,
		"tickets_changed": _on_tickets_changed, "match_started": _on_match_started,
		"match_ended": _on_match_ended, "round_started": _on_round_started,
		"round_summary": _on_round_summary, "round_ended": _on_round_ended,
		"card_deployed": _on_card_deployed, "unit_eliminated": _on_unit_eliminated,
		"operator_down": _on_operator_down, "streak_changed": _on_streak_changed,
		"killstreak_earned": _on_killstreak_earned, "killstreak_used": _on_killstreak_used,
		"reward_offered": _on_reward_offered,
		"reward_picked": _on_reward_picked, "preview_toggled": _on_preview_toggled,
		"tutorial_step": _on_tutorial_step, "next_match_requested": _on_next_match_requested,
		"screen_shown": _on_screen_shown,
	}
	for sig: String in hooks:
		if bus.has_signal(sig):
			bus.connect(sig, hooks[sig])
		else:
			push_warning("PlaytestLog: EventBus has no signal %s" % sig)


func _on_run_started(seed_value: int) -> void:
	var run: Object = _run()
	_write("run_start", {
		"seed": seed_value,
		"killstreaks": run.get("killstreaks") if run != null else [],
		"deck_size": (run.get("deck") as Array).size() if run != null else 0,
		"tickets": run.get("tickets") if run != null else 0,
	})


func _on_run_ended(result: StringName, matches_played: int, duration_s: float) -> void:
	var run: Object = _run()
	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	if run != null and run.has_method("count_results"):
		wins = run.count_results(&"player")
		losses = run.count_results(&"enemy")
		draws = run.count_results(&"draw")
	stats["runs"] += 1
	stats["run_result"] = "%s after %d matches (%d min)" % [result, matches_played, int(duration_s / 60.0)]
	_write("run_end", {"result": result, "matches": matches_played, "duration_s": snappedf(duration_s, 0.1),
			"wins": wins, "losses": losses, "draws": draws})
	flush()


func _on_tickets_changed(tickets: int) -> void:
	_write("tickets", {"tickets": tickets})


func _on_match_started(mode: StringName, map_id: StringName, match_index: int) -> void:
	_match_index = match_index
	_round = 0
	_streak = 0
	_round_summaries = {}
	_match = {"max_streak": 0, "killstreaks_earned": 0, "killstreaks_used": 0, "cards_played": 0,
			"operator_downs": 0}
	var threat: int = 0
	var rival: bool = false
	var squad: String = ""
	var run: Object = _run()
	if run != null and run.has_method("current_match"):
		var md: Resource = run.current_match()
		if md != null:
			threat = int(md.get("bracket"))
			rival = bool(run.is_rival_match())
			var sq: Resource = md.get("squad")
			if sq != null:
				squad = String(sq.get("id"))
	_write("match_start", {"mode": mode, "map": map_id, "match": match_index, "threat": threat,
			"rival": rival, "squad": squad})


func _on_match_ended(result: StringName, rounds: int, duration_s: float) -> void:
	_last_match_end_ms = Time.get_ticks_msec()
	stats["matches"] += 1
	match String(result):
		"win": stats["wins"] += 1
		"loss": stats["losses"] += 1
		_: stats["draws"] += 1
	if int(_match.get("killstreaks_used", 0)) > 0:
		stats["matches_with_killstreak"] += 1
	var entry: Dictionary = {"result": result, "rounds": rounds, "duration_s": snappedf(duration_s, 0.1),
			"match": _match_index}
	for key: String in ["max_streak", "killstreaks_earned", "killstreaks_used", "cards_played", "operator_downs"]:
		entry[key] = int(_match.get(key, 0))
	_write("match_end", entry)
	flush()


func _on_round_started(round_number: int) -> void:
	_round = round_number


func _on_round_summary(round_number: int, supply_unspent: int, hand_size: int) -> void:
	if _round_summaries.has(-round_number):
		# round_ended already went out for this round: write the numbers on their own line.
		_write("round_stats", {"round": round_number, "supply_unspent": supply_unspent, "hand_size": hand_size})
		return
	_round_summaries[round_number] = [supply_unspent, hand_size]


func _on_round_ended(round_number: int, player_score: int, enemy_score: int) -> void:
	stats["rounds"] += 1
	var summary: Array = _round_summaries.get(round_number, [null, null])
	_round_summaries.erase(round_number)
	if summary[0] == null:
		_round_summaries[-round_number] = true
	_write("round_end", {"round": round_number, "score": player_score, "enemy_score": enemy_score,
			"streak": _streak, "supply_unspent": summary[0], "hand_size": summary[1]})


func _on_card_deployed(side: StringName, card_id: StringName, zone: StringName) -> void:
	if side == &"player":
		stats["cards_played"] += 1
		_match["cards_played"] = int(_match.get("cards_played", 0)) + 1
	_write("card_played", {"side": side, "card_id": card_id, "zone": zone, "round": _round})


func _on_unit_eliminated(victim_uid: int, by_uid: int, zone: StringName, by_killstreak: bool) -> void:
	_write("elimination", {"by": by_uid, "victim": victim_uid, "zone": zone,
			"by_killstreak": by_killstreak, "round": _round})


func _on_operator_down(side: StringName, round_number: int) -> void:
	if side == &"player":
		stats["operator_downs"] += 1
		_match["operator_downs"] = int(_match.get("operator_downs", 0)) + 1
	_write("operator_down", {"side": side, "round": round_number})


func _on_streak_changed(streak: int) -> void:
	_streak = streak
	_match["max_streak"] = maxi(int(_match.get("max_streak", 0)), streak)
	stats["max_streak"] = maxi(int(stats["max_streak"]), streak)


func _on_killstreak_earned(killstreak_id: StringName, round_number: int) -> void:
	stats["killstreaks_earned"] += 1
	_match["killstreaks_earned"] = int(_match.get("killstreaks_earned", 0)) + 1
	_write("killstreak_earned", {"id": killstreak_id, "round": round_number, "streak": _streak})


func _on_killstreak_used(killstreak_id: StringName, round_number: int) -> void:
	stats["killstreaks_used"] += 1
	_match["killstreaks_used"] = int(_match.get("killstreaks_used", 0)) + 1
	_write("killstreak_used", {"id": killstreak_id, "round": round_number})


func _on_reward_offered(kind: StringName, offered_ids: Array[StringName]) -> void:
	_last_offer[kind] = offered_ids.duplicate()
	_write("offer_shown", {"kind": kind, "offered": offered_ids})


func _on_reward_picked(kind: StringName, chosen_id: StringName) -> void:
	var skipped: bool = chosen_id == &""
	_write(PICK_EVENTS.get(kind, "reward_pick"), {"kind": kind, "offered": _last_offer.get(kind, []),
			"chosen": null if skipped else String(chosen_id), "skipped": skipped})
	_last_offer.erase(kind)


func _on_preview_toggled(on: bool) -> void:
	_write("preview_toggled", {"on": on})


func _on_tutorial_step(step: int) -> void:
	stats["tutorial_steps"] = maxi(int(stats["tutorial_steps"]), step)
	_write("tutorial_step", {"step": step})


func _on_next_match_requested() -> void:
	var seconds: Variant = null
	if _last_match_end_ms >= 0:
		seconds = snappedf((Time.get_ticks_msec() - _last_match_end_ms) / 1000.0, 0.1)
		stats["next_match_clicks"] += 1
		if seconds <= 60.0:
			stats["next_match_60s"] += 1
	_write("next_match_clicked", {"seconds_after_end": seconds})


func _on_screen_shown(screen: StringName) -> void:
	_set_screen(String(screen))


func _on_scene_changed(path: String) -> void:
	_set_screen(path.get_file().get_basename().to_snake_case())


func _set_screen(screen_name: String) -> void:
	if screen_name == _screen:
		return
	_screen = screen_name
	_write("screen", {"name": screen_name})


# =============================================================================
# Session, device, input, quit
# =============================================================================

func _input(event: InputEvent) -> void:
	var kind: String = ""
	if event is InputEventScreenTouch and event.pressed:
		kind = "touch"
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		kind = "mouse"
	elif event is InputEventKey and event.pressed and not event.echo:
		kind = "keyboard"
	elif event is InputEventJoypadButton and event.pressed:
		kind = "gamepad"
	if kind == "":
		return
	var counts: Dictionary = stats["inputs"]
	counts[kind] = int(counts.get(kind, 0)) + 1
	if enabled and not _inputs_seen.has(kind):
		_inputs_seen[kind] = true
		_write("input_type", {"kind": kind})


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_on_quit("close")
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not OS.has_feature("web") and OS.has_feature("mobile"):
				_write("app_hidden", {"screen": _screen, "session_s": snappedf(_session_s(), 0.1)})
				flush()
		NOTIFICATION_APPLICATION_RESUMED:
			if not OS.has_feature("web") and OS.has_feature("mobile"):
				_write("app_visible", {"screen": _screen, "session_s": snappedf(_session_s(), 0.1)})


func _on_quit(reason: String) -> void:
	_write("quit", {"screen": _screen, "session_s": snappedf(_session_s(), 0.1), "reason": reason})
	flush()


## Web only: page hide / tab switch / close. pagehide is the last event a page reliably gets
## (iOS Safari may skip it, so visibility "hidden" is logged and flushed too).
func _listen_to_page() -> void:
	if not OS.has_feature("web"):
		return
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if document == null or window == null:
		return
	var on_visibility: JavaScriptObject = JavaScriptBridge.create_callback(_on_js_visibility)
	var on_pagehide: JavaScriptObject = JavaScriptBridge.create_callback(_on_js_pagehide)
	_js_callbacks = [on_visibility, on_pagehide]  # keep them alive
	document.addEventListener("visibilitychange", on_visibility)
	window.addEventListener("pagehide", on_pagehide)


func _on_js_visibility(_args: Array) -> void:
	var state: String = str(JavaScriptBridge.eval("document.visibilityState", true))
	_write("app_hidden" if state == "hidden" else "app_visible", {"screen": _screen,
			"session_s": snappedf(_session_s(), 0.1)})
	flush()


func _on_js_pagehide(_args: Array) -> void:
	_on_quit("pagehide")


func _on_profile_settled() -> void:
	_write("screen_profile", {"screen": _screen_info()})


func _session_s() -> float:
	return (Time.get_ticks_msec() - session_started_ms) / 1000.0


func _session_info() -> Dictionary:
	var info: Dictionary = _device_info()
	info["schema"] = SCHEMA_VERSION
	info["consent_version"] = CONSENT_VERSION
	info["load_ms"] = _load_ms
	info["date_utc"] = Time.get_date_string_from_system(true)
	info["segment"] = segment()
	return info


## Coarse device / platform info (no raw user agent, no hardware ids).
func _device_info() -> Dictionary:
	var web: bool = OS.has_feature("web")
	var page: Dictionary = {"browser": "", "standalone": false, "embedded": false}
	if web:
		var raw: Variant = JavaScriptBridge.eval("""(function(){var u=navigator.userAgent;
			var b=/Edg\\//.test(u)?'edge':/CriOS|Chrome\\//.test(u)?'chrome':/FxiOS|Firefox\\//.test(u)?'firefox':/Safari\\//.test(u)?'safari':'other';
			var s=(window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||navigator.standalone===true;
			var e=false;try{e=window.self!==window.top;}catch(x){e=true;}
			return JSON.stringify({browser:b,standalone:!!s,embedded:e});})()""", true)
		var parsed: Variant = JSON.parse_string(str(raw)) if raw != null else null
		if parsed is Dictionary:
			page = parsed
	var screen: Dictionary = _screen_info()
	var mobile: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	return {
		"platform": OS.get_name(),
		"os_family": _os_family(),
		"web": web,
		"browser": page.get("browser", ""),
		"standalone": page.get("standalone", false),
		"embedded": page.get("embedded", false),
		"mobile": mobile,
		"touchscreen": DisplayServer.is_touchscreen_available(),
		"device_class": _device_class(screen, mobile, DisplayServer.is_touchscreen_available()),
		"engine": Engine.get_version_info().get("string", ""),
		"build": String(ProjectSettings.get_setting("application/config/version", "")),
		"screen": screen,
	}


## Screen profile: window size in px and points, pixel ratio, canvas base and logical size.
func _screen_info() -> Dictionary:
	var window_px: Vector2 = Vector2(DisplayServer.window_get_size())
	var scale: float = ScreenProfile.screen_scale() if DisplayServer.get_name() != "headless" else 1.0
	var ui_scale: float = 1.0
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null:
		ui_scale = float(settings.get("ui_scale"))
	var root: Window = get_tree().root
	var base: Vector2 = Vector2(root.content_scale_size)
	var logical: Vector2 = root.get_visible_rect().size
	return {
		"window_px": [int(window_px.x), int(window_px.y)],
		"points": [int(round(window_px.x / scale)), int(round(window_px.y / scale))],
		"pixel_ratio": snappedf(scale, 0.01),
		"base": [int(base.x), int(base.y)],
		"logical": [int(logical.x), int(logical.y)],
		"pt_per_px": snappedf(ScreenProfile.points_per_px(window_px, scale, ui_scale), 0.001) if window_px.y > 0 else 0.0,
		"ui_scale": ui_scale,
		"compact": logical.y < ScreenProfile.COMPACT_HEIGHT,
		"orientation": "landscape" if window_px.x >= window_px.y else "portrait",
	}


func _os_family() -> String:
	for tag: String in ["web_ios", "web_android", "web_macos", "web_windows", "web_linuxbsd"]:
		if OS.has_feature(tag):
			return tag.trim_prefix("web_")
	return OS.get_name().to_lower()


## phone / tablet / desktop from the OS tags, touch support and the short side in points
## (a touch screen under 500 pt is a phone even when the browser reports a desktop OS).
static func _device_class(screen: Dictionary, mobile: bool, touch: bool = false) -> String:
	var pts: Array = screen.get("points", [0, 0])
	var short_side: int = mini(int(pts[0]), int(pts[1]))
	if (mobile or touch) and short_side > 0 and short_side < 500:
		return "phone"
	if mobile:
		return "tablet"
	return "desktop"


func _screen_text(screen: Dictionary) -> String:
	var pts: Array = screen.get("points", [0, 0])
	return "%dx%d pt @%sx" % [int(pts[0]), int(pts[1]), str(screen.get("pixel_ratio", 1.0))]


## The pointer kind used most (touch / mouse / gamepad); keyboard only when nothing else was used,
## since typing the open answer would otherwise outvote the taps.
func _primary_input() -> String:
	var counts: Dictionary = stats["inputs"]
	var best: String = "keyboard" if counts.has("keyboard") else "none"
	var most: int = 0
	for kind: String in counts:
		if kind != "keyboard" and int(counts[kind]) > most:
			most = int(counts[kind])
			best = kind
	return best


## Page load to engine start: performance.now() on the web, engine ticks elsewhere.
func _measure_load_ms() -> int:
	if OS.has_feature("web"):
		var now: Variant = JavaScriptBridge.eval("performance.now()", true)
		if now != null:
			return int(float(now))
	return Time.get_ticks_msec()


func _run() -> Object:
	var rs: Node = get_node_or_null("/root/RunState")
	return rs.get("run") if rs != null else null


func _total_bytes() -> int:
	var total: int = 0
	for path: String in log_files():
		total += _file_size(path)
	return total


static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0


static func _ensure_dir(path: String) -> void:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


## JSON-friendly copy: StringName -> String, typed arrays -> plain arrays, floats rounded.
static func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_STRING:
			return clean_text(value) if value.length() > MAX_TEXT_CHARS else value
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var out: Array = []
			for v: Variant in value:
				out.append(_plain(v))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in value:
				d[String(k)] = _plain(value[k])
			return d
		TYPE_FLOAT:
			return snappedf(value, 0.001)
	return value


static func _random_id() -> String:
	return Crypto.new().generate_random_bytes(6).hex_encode()
