# playtest_log.gd
# Adapted from Killstreak autoload/playtest_log.gd (consent, writing, rotation, export machinery
#   kept; SCHEMA, handlers and survey replaced for Banner Wall).
# Purpose: PlaytestLog autoload (cc16). Listens to EventBus only (no gameplay code calls it) and
#   appends one JSON object per line to user://playtest_log.jsonl for the playtest plan in
#   documentation/production/prototype-milestone-plan.md section 8 (KPIs: vision.md section 8).
#   Also owns consent, the survey answers and the "Download log" export.
#   Field-by-field reference: documentation/production/playtest-log-schema.md.
#
#   Every line: {"v": SCHEMA_VERSION, "sid": <anonymous session id>, "seq": n, "t_ms": ms since
#   this session started (monotonic), "event": <name>, ...fields}. SCHEMA below lists every
#   event, its fields and their types; validate_entry() checks a line against it (tests use it).
#
#   Sides: EventBus sides are &"player" / &"rival" and duel results are &"win" / &"loss" /
#   &"draw" from the player's point of view. They are logged as those strings; per-side counters
#   compare against &"player" / &"rival" (never "win"/"loss"), and a draw is its own result.
#
#   Privacy: nothing is written until the tester opts in (set_consent(true); default off). The
#   session id is random per launch and is not tied to any account. No names, emails, IPs,
#   locations, raw user agents or free text other than the optional open survey answer (capped at
#   MAX_TEXT_CHARS; the screen asks testers to leave out personal details).
#   withdraw() turns logging off and deletes the log files.
#
#   Size: when the current file would pass max_file_bytes it is rotated to .1.jsonl (the oldest
#   backup past max_backups is deleted), so the log never exceeds about
#   max_file_bytes * (max_backups + 1).
#
#   Consent prompt: on a real (non-headless) run, the first screen_shown while the tester has not
#   answered opens scenes/survey/ConsentPrompt.tscn on top of that screen.
# Dependencies: EventBus (signals), scripts/ui/screen_profile.gd (screen numbers),
#   scenes/survey/ConsentPrompt.tscn (shown on first launch).
# Author: Data Scientist Agent (cc01 stub: Mechanics Developer Agent)
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const CONSENT_PROMPT_SCENE: String = "res://scenes/survey/ConsentPrompt.tscn"

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
## octet-stream so iOS Safari saves the file instead of opening it as text.
const DOWNLOAD_MIME: String = "application/octet-stream"
const EXPORT_FORMAT: String = "callingcard-playtest-log"

## Field type codes used in SCHEMA: s string, i integer, n number, b bool, a array, d dictionary;
## a trailing "?" also allows null.
## Event name -> {field: type} besides the COMMON_FIELDS. Every line the logger writes has exactly
## the common fields plus these (tests check it through validate_entry()).
const SCHEMA: Dictionary = {
	"session_start": {"schema": "i", "consent_version": "i", "load_ms": "i", "input_type": "s",
			"viewport": "a", "window_px": "a", "pixel_ratio": "n", "browser": "s", "os_family": "s",
			"web": "b", "mobile": "b", "touchscreen": "b", "device_class": "s", "engine": "s",
			"build": "s", "date_utc": "s"},
	"consent": {"given": "b"},
	"input_type": {"kind": "s"},
	"screen": {"name": "s"},
	"entry_point": {"entry": "s", "screen": "s"},
	"album_open": {"page": "s", "count": "i"},
	"card_inspect": {"card_id": "s", "owned": "b", "screen": "s"},
	"lineup_saved": {"card_ids": "a", "clearance": "i", "signature_id": "s", "loaner": "b"},
	"duel_start": {"source": "s", "rival": "s", "first_player": "s", "duel": "i", "play_again": "b"},
	"duel_lineup": {"card_ids": "a", "signature_id": "s", "loaner": "b", "duel": "i"},
	"placement": {"side": "s", "card_id": "s", "slot": "s", "captures": "a", "preview_shown": "b",
			"turn": "i", "duel": "i"},
	"set_link": {"side": "s", "slot": "s", "linked": "a", "duel": "i"},
	"capture": {"by": "s", "card_id": "s", "slot": "s", "duel": "i"},
	"reclaim": {"by": "s", "card_id": "s", "slot": "s", "duel": "i"},
	"ambush": {"side": "s", "card_id": "s", "slot": "s", "duel": "i"},
	"carded": {"by": "s", "card_id": "s", "duel": "i"},
	"triptych_scored": {"side": "s", "id": "s", "first_time": "b", "duel": "i"},
	"triptych_reveal": {"id": "s"},
	"duel_end": {"result": "s", "score_p": "i", "score_ai": "i", "turns": "i", "duration_s": "n",
			"source": "s", "rival": "s", "duel": "i", "resumed": "b", "play_again": "b",
			"captures_p": "i", "captures_ai": "i", "carded_p": "i", "carded_ai": "i", "triptychs_p": "i"},
	"lobby_wait_start": {"wait_s": "n"},
	"lobby_match_found": {"choice": "s", "duel_state": "d"},
	"lobby_save": {"saved": "b"},
	"duel_resumed": {"age_s": "n", "duel": "i", "rival": "s"},
	"unlock": {"kind": "s", "id": "s", "source": "s"},
	"goal_progress": {"goal_id": "s", "current": "i", "target": "i"},
	"goal_complete": {"goal_id": "s"},
	"set_complete": {"set_id": "s"},
	"cipher_attempt": {"correct": "b", "attempt": "i"},
	"cipher_solved": {"attempts": "i"},
	"dossier_start": {"id": "s"},
	"dossier_clear": {"id": "s", "attempts": "i", "duration_s": "n", "since_start_s": "n", "via": "s"},
	"collection_reset": {},
	"survey": {"q1": "i?", "q2": "i?", "q3": "i?", "q4": "i?", "open": "s", "answered": "i"},
	"log_exported": {"method": "s", "bytes": "i"},
	"app_hidden": {"screen": "s", "session_s": "n"},
	"app_visible": {"screen": "s", "session_s": "n"},
	"quit": {"screen": "s", "session_s": "n", "reason": "s"},
}
const COMMON_FIELDS: Dictionary = {"v": "i", "sid": "s", "seq": "i", "t_ms": "i", "event": "s"}
## "event.field" -> allowed values.
const ENUMS: Dictionary = {
	"session_start.input_type": ["touch", "mouse"],
	"session_start.device_class": ["phone", "tablet", "desktop"],
	"input_type.kind": ["touch", "mouse", "keyboard", "gamepad"],
	"entry_point.entry": ["menu", "lobby"],
	"duel_start.source": ["rival", "lobby", "dossier"],
	"duel_start.first_player": ["player", "rival"],
	"placement.side": ["player", "rival"],
	"set_link.side": ["player", "rival"],
	"capture.by": ["player", "rival"],
	"reclaim.by": ["player", "rival"],
	"ambush.side": ["player", "rival"],
	"carded.by": ["player", "rival"],
	"triptych_scored.side": ["player", "rival"],
	"duel_end.result": ["win", "loss", "draw"],
	"duel_end.source": ["rival", "lobby", "dossier"],
	"lobby_match_found.choice": ["keep", "save"],
	"unlock.kind": ["card", "title", "frame"],
	"dossier_clear.via": ["duel_end", "dossier_cleared", "dossier_completed"],
	"log_exported.method": ["download", "file"],
	"quit.reason": ["close", "pagehide"],
}
## Keys of lobby_match_found.duel_state.
const DUEL_STATE_FIELDS: Dictionary = {"in_duel": "b", "placements": "i", "score_p": "i", "score_ai": "i", "source": "s"}

## The four vision section 8 statements (1-5 agreement, 4+ counts as agree) and the open question.
## kpi names match documentation/production/playtest-log-schema.md.
const SURVEY_QUESTIONS: Array[Dictionary] = [
	{"id": "q1", "kpi": "intent_to_collect", "text": "I'd go after specific cards to use them in Banner Wall."},
	{"id": "q2", "kpi": "album_pull", "text": "I wanted to look through the album and find out about the cards I don't own yet."},
	{"id": "q3", "kpi": "session_fit", "text": "A duel fits comfortably into a matchmaking wait."},
	{"id": "q4", "kpi": "fairness", "text": "Earned cards being stronger feels fair, store cards being cosmetic feels fair."},
]
const OPEN_QUESTION: String = "What made you want to collect a card, or what put you off? (Please leave out names and personal details.)"
const SCALE_LOW: String = "Strongly disagree"
const SCALE_HIGH: String = "Strongly agree"

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
## Show the consent prompt on the first screen (off under the headless test runner).
var auto_prompt: bool = false
## Last survey answers ({} until submitted); kept with the consent so the screen can show them.
var survey_answers: Dictionary = {}
## Running totals for this session (summary line on the survey screen, tests).
var stats: Dictionary = {}

var _seq: int = 0
var _pending: PackedStringArray = []
var _flush_queued: bool = false
var _session_logged: bool = false
var _load_ms: int = 0
var _screen: String = ""
var _entry: String = ""
var _entry_logged: bool = false
var _duel: Dictionary = {}
var _duel_index: int = 0
var _turn: int = 0
var _screen_since_duel_end: bool = true
var _card_sources: Dictionary = {}
var _dossier: Dictionary = {}
var _cipher_attempts: int = 0
var _inputs_seen: Dictionary = {}
var _prompt: Node = null
var _js_callbacks: Array = []


func _ready() -> void:
	new_session()
	_load_ms = _measure_load_ms()
	_connect_bus()
	# Headless runs (tests, CI) never pick up a stored consent or show the prompt.
	if DisplayServer.get_name() != "headless":
		auto_prompt = true
		load_consent()
		_listen_to_page()


## Starts a fresh anonymous session (new id, clock, counters). Called once at startup.
func new_session() -> void:
	session_id = _random_id()
	session_started_ms = Time.get_ticks_msec()
	_seq = 0
	_session_logged = false
	_screen = ""
	_entry = ""
	_entry_logged = false
	_duel = {}
	_duel_index = 0
	_turn = 0
	_screen_since_duel_end = true
	_card_sources = {}
	_dossier = {}
	_cipher_attempts = 0
	_inputs_seen = {}
	stats = {"duels": 0, "wins": 0, "losses": 0, "draws": 0, "dossier_attempts": 0,
			"dossier_clears": 0, "album_opens": 0, "locked_inspects": 0, "unlocks": 0,
			"lobby_waits": 0, "lobby_saves": 0, "resumes": 0, "inputs": {}}


# =============================================================================
# Consent
# =============================================================================

## True when the consent prompt should be shown (never answered for this CONSENT_VERSION).
func needs_consent() -> bool:
	return not consent_answered


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
		if _screen != "":
			_write("screen", {"name": _screen})
		_log_entry_point()
		flush()
	if given != was_enabled:
		consent_changed.emit(given)


## Turns logging off and deletes every log file on this device. The answer is remembered
## (no prompt next launch); set_consent(true) turns it back on.
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
	var saved: Variant = cfg.get_value("survey", "answers", {})
	if saved is Dictionary:
		survey_answers = saved
	if bool(cfg.get_value("consent", "given", false)):
		set_consent(true, false)
	else:
		consent_answered = true


func _save_consent() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("consent", "version", CONSENT_VERSION)
	cfg.set_value("consent", "given", enabled)
	cfg.set_value("survey", "answers", survey_answers)
	_ensure_dir(consent_path)
	if cfg.save(consent_path) != OK:
		push_warning("PlaytestLog: cannot save %s" % consent_path)


## Opens the consent prompt over the current screen (once; it frees itself when answered).
func show_consent_prompt() -> Node:
	if _prompt != null and is_instance_valid(_prompt):
		return _prompt
	var scene: PackedScene = load(CONSENT_PROMPT_SCENE) as PackedScene
	if scene == null:
		return null
	_prompt = scene.instantiate()
	add_child(_prompt)
	return _prompt


# =============================================================================
# Writing
# =============================================================================

## Appends one event line. No-op while disabled. Prefer the EventBus signals; this stays for
## events that have no signal. The event must be in SCHEMA.
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
# Schema check
# =============================================================================

## Problems with one log line (written or parsed back from JSON): unknown event, missing or extra
## fields, wrong types, values outside ENUMS. Empty when the line matches SCHEMA.
static func validate_entry(entry: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var event_name: String = str(entry.get("event", ""))
	if not SCHEMA.has(event_name):
		errors.append("unknown event '%s'" % event_name)
		return errors
	var fields: Dictionary = (SCHEMA[event_name] as Dictionary).merged(COMMON_FIELDS)
	for key: Variant in entry:
		if not fields.has(String(key)):
			errors.append("%s: unexpected field '%s'" % [event_name, key])
	for key: String in fields:
		if not entry.has(key):
			errors.append("%s: missing field '%s'" % [event_name, key])
		elif not _type_ok(entry[key], fields[key]):
			errors.append("%s.%s: %s is not of type %s" % [event_name, key, str(entry[key]), fields[key]])
		elif ENUMS.has("%s.%s" % [event_name, key]) and not (ENUMS["%s.%s" % [event_name, key]] as Array).has(str(entry[key])):
			errors.append("%s.%s: '%s' not in %s" % [event_name, key, str(entry[key]), str(ENUMS["%s.%s" % [event_name, key]])])
	if event_name == "lobby_match_found" and entry.get("duel_state") is Dictionary:
		var ds: Dictionary = entry["duel_state"]
		for key: String in DUEL_STATE_FIELDS:
			if not ds.has(key) or not _type_ok(ds[key], DUEL_STATE_FIELDS[key]):
				errors.append("lobby_match_found.duel_state.%s missing or wrong type" % key)
	if event_name == "survey":
		for q: Dictionary in SURVEY_QUESTIONS:
			var value: Variant = entry.get(q["id"])
			if value != null and (int(value) < 1 or int(value) > 5):
				errors.append("survey.%s: %s outside 1-5" % [q["id"], str(value)])
	return errors


static func _type_ok(value: Variant, code: String) -> bool:
	if code.ends_with("?"):
		if value == null:
			return true
		code = code.trim_suffix("?")
	match code:
		"s": return value is String
		"i": return value is int or (value is float and is_equal_approx(value, roundf(value)))
		"n": return value is int or value is float
		"b": return value is bool
		"a": return value is Array
		"d": return value is Dictionary
	return false


# =============================================================================
# Survey
# =============================================================================

## answers: {"q1".."q4": int 1-5 (anything else is stored as null = skipped), "open": String}.
## Writes the survey line (when logging is on), keeps the answers on this device and returns
## the cleaned answers.
func record_survey(answers: Dictionary) -> Dictionary:
	var entry: Dictionary = {}
	var answered: int = 0
	for q: Dictionary in SURVEY_QUESTIONS:
		var key: String = q["id"]
		var value: Variant = answers.get(key, null)
		var ok: bool = (value is int or value is float) and int(value) == value and int(value) >= 1 and int(value) <= 5
		entry[key] = int(value) if ok else null
		if ok:
			answered += 1
	entry["open"] = clean_text(str(answers.get("open", "")))
	entry["answered"] = answered
	survey_answers = entry.duplicate()
	_write("survey", entry)
	if consent_answered:
		_save_consent()
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

## File name for downloads: callingcard-playtest-<date>-<sid>.json.
func export_file_name() -> String:
	return "callingcard-playtest-%s-%s.json" % [Time.get_date_string_from_system(true), session_id]


## The download: one JSON document {format, schema_version, exported_utc, session_ids, events}
## holding every line of the log (all sessions on this device, oldest first).
func build_export() -> String:
	var events: Array[Dictionary] = read_entries()
	var sids: Array[String] = []
	for e: Dictionary in events:
		var sid: String = str(e.get("sid", ""))
		if sid != "" and not sids.has(sid):
			sids.append(sid)
	var doc: Dictionary = {
		"format": EXPORT_FORMAT, "schema_version": SCHEMA_VERSION,
		"exported_utc": Time.get_datetime_string_from_system(true) + "Z",
		"session_ids": sids, "event_count": events.size(), "events": events,
	}
	return JSON.stringify(doc, "", false)


## "Download log": on the web the browser downloads the JSON (JavaScriptBridge.download_buffer,
## a Blob + anchor click); elsewhere a copy is saved next to the log under user:// and its real
## path is returned. Returns {ok, method: "download"|"file", path, bytes, events, error}.
func export_log() -> Dictionary:
	var web: bool = OS.has_feature("web")
	if enabled:
		# Size of what was on disk before this line; the line itself is in the export too.
		_write("log_exported", {"method": "download" if web else "file", "bytes": _total_bytes()})
	var text: String = build_export()
	var buffer: PackedByteArray = text.to_utf8_buffer()
	var parsed: Variant = JSON.parse_string(text)
	var count: int = int((parsed as Dictionary).get("event_count", 0)) if parsed is Dictionary else 0
	var result: Dictionary = {"ok": false, "method": "download" if web else "file", "path": "",
			"bytes": buffer.size(), "events": count, "error": ""}
	if count == 0:
		result["error"] = "The log is empty."
		return result
	if web:
		JavaScriptBridge.download_buffer(buffer, export_file_name(), DOWNLOAD_MIME)
		result["ok"] = true
		result["path"] = export_file_name()
		print("PlaytestLog: download %s (%d bytes, %d events)" % [result["path"], buffer.size(), count])
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


## One line for the survey screen: what this session logged so far (no personal data).
func summary_line() -> String:
	return "Session %s · %d duels (%d W / %d L / %d D) · %d album opens · %d unlocks" % [
			session_id, stats["duels"], stats["wins"], stats["losses"], stats["draws"],
			stats["album_opens"], stats["unlocks"]]


# =============================================================================
# EventBus handlers
# =============================================================================

func _connect_bus() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		push_warning("PlaytestLog: EventBus missing, nothing will be logged")
		return
	var hooks: Dictionary = {
		"screen_shown": _on_screen_shown, "duel_started": _on_duel_started,
		"duel_lineup_locked": _on_duel_lineup_locked, "turn_started": _on_turn_started,
		"card_placed": _on_card_placed, "card_captured": _on_card_captured,
		"card_reclaimed": _on_card_reclaimed, "ambush_sprung": _on_ambush_sprung,
		"set_linked": _on_set_linked, "carded": _on_carded, "triptych_scored": _on_triptych_scored,
		"score_changed": _on_score_changed, "duel_ended": _on_duel_ended,
		"album_opened": _on_album_opened, "card_inspected": _on_card_inspected,
		"lineup_saved": _on_lineup_saved, "unlocked": _on_unlocked, "card_unlocked": _on_card_unlocked,
		"set_completed": _on_set_completed, "cipher_attempted": _on_cipher_attempted,
		"cipher_solved": _on_cipher_solved, "dossier_started": _on_dossier_started,
		"dossier_cleared": _on_dossier_cleared, "dossier_completed": _on_dossier_completed,
		"lobby_wait_started": _on_lobby_wait_started, "lobby_match_found": _on_lobby_match_found,
		"duel_resumed": _on_duel_resumed, "lobby_duel_saved": _on_lobby_duel_saved,
		"unlock_progress": _on_unlock_progress, "unlock_goal_completed": _on_unlock_goal_completed,
		"triptych_revealed": _on_triptych_revealed, "collection_reset": _on_collection_reset,
	}
	for sig: String in hooks:
		if bus.has_signal(sig):
			bus.connect(sig, hooks[sig])
		else:
			push_warning("PlaytestLog: EventBus has no signal %s" % sig)


func _on_screen_shown(screen_id: StringName) -> void:
	var screen_name: String = String(screen_id)
	_screen_since_duel_end = true
	if _entry == "" and (screen_name == "hub" or screen_name == "lobby"):
		_entry = "menu" if screen_name == "hub" else "lobby"
	if screen_name != _screen:
		_screen = screen_name
		_write("screen", {"name": screen_name})
	_log_entry_point()
	if auto_prompt and needs_consent():
		auto_prompt = false
		show_consent_prompt.call_deferred()


func _log_entry_point() -> void:
	if _entry == "" or _entry_logged or not enabled:
		return
	_entry_logged = true
	_write("entry_point", {"entry": _entry, "screen": _screen})


func _on_duel_started(source: StringName, rival_id: StringName, first_player: StringName) -> void:
	_duel_index += 1
	_turn = 0
	var play_again: bool = not _screen_since_duel_end
	_screen_since_duel_end = false
	_duel = {"source": String(source), "rival": String(rival_id), "resumed": false, "play_again": play_again,
			"placements": 0, "score_p": 0, "score_ai": 0, "captures_p": 0, "captures_ai": 0,
			"carded_p": 0, "carded_ai": 0, "triptychs_p": 0, "over": false}
	if source == &"dossier":
		stats["dossier_attempts"] += 1
		_ensure_dossier(String(rival_id), 0)
		_dossier["attempts"] = int(_dossier["attempts"]) + 1
	_write("duel_start", {"source": source, "rival": rival_id, "first_player": first_player,
			"duel": _duel_index, "play_again": play_again})


func _on_duel_lineup_locked(card_ids: Array, signature_id: StringName, loaner: bool) -> void:
	_write("duel_lineup", {"card_ids": card_ids, "signature_id": signature_id, "loaner": loaner, "duel": _duel_index})


func _on_turn_started(_side: StringName, turn_index: int) -> void:
	_turn = turn_index


func _on_card_placed(side: StringName, card_id: StringName, slot: StringName, captures: Array) -> void:
	_duel["placements"] = int(_duel.get("placements", 0)) + 1
	# The duel and Dossier screens always show the capture preview before the player's PLACE
	# (no EventBus signal reports it), so a player placement counts as previewed.
	_write("placement", {"side": side, "card_id": card_id, "slot": slot, "captures": captures,
			"preview_shown": side == &"player", "turn": int(_duel["placements"]), "duel": _duel_index})


func _on_set_linked(side: StringName, slot: StringName, linked: Array) -> void:
	_write("set_link", {"side": side, "slot": slot, "linked": linked, "duel": _duel_index})


func _on_card_captured(by_side: StringName, card_id: StringName, slot: StringName) -> void:
	var key: String = "captures_p" if by_side == &"player" else "captures_ai"
	_duel[key] = int(_duel.get(key, 0)) + 1
	_write("capture", {"by": by_side, "card_id": card_id, "slot": slot, "duel": _duel_index})


func _on_card_reclaimed(by_side: StringName, card_id: StringName, slot: StringName) -> void:
	_write("reclaim", {"by": by_side, "card_id": card_id, "slot": slot, "duel": _duel_index})


func _on_ambush_sprung(side: StringName, card_id: StringName, slot: StringName) -> void:
	_write("ambush", {"side": side, "card_id": card_id, "slot": slot, "duel": _duel_index})


func _on_carded(by_side: StringName, card_id: StringName) -> void:
	var key: String = "carded_p" if by_side == &"player" else "carded_ai"
	_duel[key] = int(_duel.get(key, 0)) + 1
	_write("carded", {"by": by_side, "card_id": card_id, "duel": _duel_index})


func _on_triptych_scored(side: StringName, triptych_id: StringName, first_time: bool) -> void:
	if side == &"player":
		_duel["triptychs_p"] = int(_duel.get("triptychs_p", 0)) + 1
	_write("triptych_scored", {"side": side, "id": triptych_id, "first_time": first_time, "duel": _duel_index})


func _on_triptych_revealed(triptych_id: StringName) -> void:
	_write("triptych_reveal", {"id": triptych_id})


func _on_score_changed(player_score: int, rival_score: int) -> void:
	_duel["score_p"] = player_score
	_duel["score_ai"] = rival_score


func _on_duel_ended(result: StringName, player_score: int, rival_score: int, turns: int, duration_s: float) -> void:
	var source: String = str(_duel.get("source", ""))
	_duel["over"] = true
	_duel["duration_s"] = duration_s
	_duel["score_p"] = player_score
	_duel["score_ai"] = rival_score
	_screen_since_duel_end = false
	if source != "dossier":
		stats["duels"] += 1
		match result:
			&"win": stats["wins"] += 1
			&"loss": stats["losses"] += 1
			&"draw": stats["draws"] += 1
	_write("duel_end", {"result": result, "score_p": player_score, "score_ai": rival_score, "turns": turns,
			"duration_s": snappedf(duration_s, 0.1), "source": source, "rival": str(_duel.get("rival", "")),
			"duel": _duel_index, "resumed": bool(_duel.get("resumed", false)),
			"play_again": bool(_duel.get("play_again", false)),
			"captures_p": int(_duel.get("captures_p", 0)), "captures_ai": int(_duel.get("captures_ai", 0)),
			"carded_p": int(_duel.get("carded_p", 0)), "carded_ai": int(_duel.get("carded_ai", 0)),
			"triptychs_p": int(_duel.get("triptychs_p", 0))})
	if source == "dossier" and result == &"win":
		_log_dossier_clear(str(_duel.get("rival", "")), duration_s, "duel_end")
	flush()


func _on_album_opened(page_id: StringName) -> void:
	stats["album_opens"] += 1
	_write("album_open", {"page": page_id, "count": stats["album_opens"]})


func _on_card_inspected(card_id: StringName, owned: bool) -> void:
	if not owned:
		stats["locked_inspects"] += 1
	_write("card_inspect", {"card_id": card_id, "owned": owned, "screen": _screen})


func _on_lineup_saved(card_ids: Array, clearance: int, signature_id: StringName, loaner: bool) -> void:
	_write("lineup_saved", {"card_ids": card_ids, "clearance": clearance, "signature_id": signature_id, "loaner": loaner})


func _on_card_unlocked(card_id: StringName, source_id: StringName) -> void:
	_card_sources[card_id] = source_id


func _on_unlocked(kind: StringName, item_id: StringName) -> void:
	stats["unlocks"] += 1
	var source: StringName = _card_sources.get(item_id, &"") if kind == &"card" else &""
	_write("unlock", {"kind": kind, "id": item_id, "source": source})


func _on_unlock_progress(goal_id: StringName, current: int, target: int) -> void:
	_write("goal_progress", {"goal_id": goal_id, "current": current, "target": target})


func _on_unlock_goal_completed(goal_id: StringName) -> void:
	_write("goal_complete", {"goal_id": goal_id})


func _on_set_completed(set_id: StringName) -> void:
	_write("set_complete", {"set_id": set_id})


func _on_cipher_attempted(correct: bool) -> void:
	_cipher_attempts += 1
	_write("cipher_attempt", {"correct": correct, "attempt": _cipher_attempts})


func _on_cipher_solved() -> void:
	_write("cipher_solved", {"attempts": _cipher_attempts})


func _on_dossier_started(dossier_id: StringName) -> void:
	_dossier = {"id": String(dossier_id), "started_ms": Time.get_ticks_msec(), "attempts": 0, "cleared_attempt": -1}
	_write("dossier_start", {"id": dossier_id})


## Dossier code pays the clear through Collection.complete_dossier (no EventBus signal), so the
## clear is logged from the winning duel_ended; these two signals are logged only when they arrive
## for an attempt that was not logged yet.
func _on_dossier_cleared(dossier_id: StringName, attempts: int, duration_s: float) -> void:
	_ensure_dossier(String(dossier_id), attempts)
	_log_dossier_clear(String(dossier_id), duration_s, "dossier_cleared")


func _on_dossier_completed(dossier_id: StringName) -> void:
	_ensure_dossier(String(dossier_id), 1)
	_log_dossier_clear(String(dossier_id), float(_duel.get("duration_s", 0.0)), "dossier_completed")


## Starts tracking dossier_id unless it is the one already tracked.
func _ensure_dossier(dossier_id: String, attempts: int) -> void:
	if _dossier.is_empty() or str(_dossier.get("id", "")) != dossier_id:
		_dossier = {"id": dossier_id, "started_ms": Time.get_ticks_msec(), "attempts": attempts, "cleared_attempt": -1}


func _log_dossier_clear(dossier_id: String, duration_s: float, via: String) -> void:
	_ensure_dossier(dossier_id, 1)
	var attempt: int = maxi(int(_dossier.get("attempts", 1)), 1)
	if int(_dossier.get("cleared_attempt", -1)) == attempt:
		return
	_dossier["cleared_attempt"] = attempt
	stats["dossier_clears"] += 1
	_write("dossier_clear", {"id": dossier_id, "attempts": attempt, "duration_s": snappedf(duration_s, 0.1),
			"since_start_s": snappedf((Time.get_ticks_msec() - int(_dossier["started_ms"])) / 1000.0, 0.1), "via": via})


func _on_lobby_wait_started(wait_s: float) -> void:
	stats["lobby_waits"] += 1
	_write("lobby_wait_start", {"wait_s": snappedf(wait_s, 0.1)})


func _on_lobby_match_found(choice: StringName) -> void:
	var in_duel: bool = not _duel.is_empty() and not bool(_duel.get("over", false))
	_write("lobby_match_found", {"choice": choice, "duel_state": {
		"in_duel": in_duel, "placements": int(_duel.get("placements", 0)),
		"score_p": int(_duel.get("score_p", 0)), "score_ai": int(_duel.get("score_ai", 0)),
		"source": str(_duel.get("source", "")),
	}})
	flush()


func _on_lobby_duel_saved(saved: bool) -> void:
	if saved:
		stats["lobby_saves"] += 1
	_write("lobby_save", {"saved": saved})


## cc19 BUG-05: the rival of the Lobby Duel about to resume (lobby_duel.gd calls this right before
## EventBus.duel_resumed, which carries no rival). Used once by _on_duel_resumed.
func note_resumed_rival(rival_id: StringName) -> void:
	_resumed_rival = String(rival_id)


var _resumed_rival: String = ""


## A saved Lobby Duel continues: no duel_started follows, so a new duel context starts here
## (source lobby; the rival from note_resumed_rival, else the Collection's saved duel, else "").
func _on_duel_resumed(age_s: float) -> void:
	stats["resumes"] += 1
	_duel_index += 1
	_turn = 0
	_screen_since_duel_end = false
	var rival: String = _resumed_rival
	_resumed_rival = ""
	if rival == "":
		var col: Node = get_node_or_null("/root/Collection")
		if col != null and col.has_method(&"saved_lobby_duel_info"):
			rival = str(col.saved_lobby_duel_info().get("rival_id", ""))
	_duel = {"source": "lobby", "rival": rival, "resumed": true, "play_again": false, "placements": 0,
			"score_p": 0, "score_ai": 0, "captures_p": 0, "captures_ai": 0, "carded_p": 0,
			"carded_ai": 0, "triptychs_p": 0, "over": false}
	_write("duel_resumed", {"age_s": snappedf(age_s, 0.1), "duel": _duel_index, "rival": rival})


func _on_collection_reset() -> void:
	_write("collection_reset")


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
		NOTIFICATION_APPLICATION_PAUSED:
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


func _session_s() -> float:
	return (Time.get_ticks_msec() - session_started_ms) / 1000.0


## Coarse device / platform info (no raw user agent, no hardware ids).
func _session_info() -> Dictionary:
	var web: bool = OS.has_feature("web")
	var browser: String = ""
	if web:
		var raw: Variant = JavaScriptBridge.eval("""(function(){var u=navigator.userAgent;
			return /Edg\\//.test(u)?'edge':/CriOS|Chrome\\//.test(u)?'chrome':/FxiOS|Firefox\\//.test(u)?'firefox':/Safari\\//.test(u)?'safari':'other';})()""", true)
		browser = str(raw) if raw != null else ""
	var window_px: Vector2 = Vector2(DisplayServer.window_get_size())
	var scale: float = ScreenProfile.screen_scale() if DisplayServer.get_name() != "headless" else 1.0
	var logical: Vector2 = get_tree().root.get_visible_rect().size
	var touch: bool = DisplayServer.is_touchscreen_available()
	var mobile: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	var points: Vector2 = window_px / maxf(scale, 0.01)
	return {
		"schema": SCHEMA_VERSION, "consent_version": CONSENT_VERSION, "load_ms": _load_ms,
		"input_type": "touch" if touch else "mouse",
		"viewport": [int(logical.x), int(logical.y)],
		"window_px": [int(window_px.x), int(window_px.y)],
		"pixel_ratio": snappedf(scale, 0.01), "browser": browser, "os_family": _os_family(),
		"web": web, "mobile": mobile, "touchscreen": touch,
		"device_class": device_class(points, mobile, touch),
		"engine": str(Engine.get_version_info().get("string", "")),
		"build": str(ProjectSettings.get_setting("application/config/version", "")),
		"date_utc": Time.get_date_string_from_system(true),
	}


func _os_family() -> String:
	for tag: String in ["web_ios", "web_android", "web_macos", "web_windows", "web_linuxbsd"]:
		if OS.has_feature(tag):
			return tag.trim_prefix("web_")
	return OS.get_name().to_lower()


## phone / tablet / desktop from the OS tags, touch support and the short side in points
## (a touch screen under 500 pt is a phone even when the browser reports a desktop OS).
static func device_class(points: Vector2, mobile: bool, touch: bool = false) -> String:
	var short_side: float = minf(points.x, points.y)
	if (mobile or touch) and short_side > 0.0 and short_side < 500.0:
		return "phone"
	if mobile:
		return "tablet"
	return "desktop"


## Page load to engine start: performance.now() on the web, engine ticks elsewhere.
func _measure_load_ms() -> int:
	if OS.has_feature("web"):
		var now: Variant = JavaScriptBridge.eval("performance.now()", true)
		if now != null:
			return int(float(now))
	return Time.get_ticks_msec()


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
