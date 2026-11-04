# playtest_log.gd
# Adapted from CallingCard autoload/playtest_log.gd (consent, writing, rotation, schema check,
#   export and JavaScriptBridge download kept; SCHEMA, handlers and survey replaced for CardZone).
# Purpose: PlaytestLog autoload (cz18). Listens to EventBus only (no gameplay code calls it) and
#   appends one JSON object per line to user://playtest_log.jsonl for the playtest plan in
#   documentation/production/prototype-milestone-plan.md section 8. Also owns consent, the survey
#   answers, the "Download log" export and the title's PLAYTEST corner button.
#   Field-by-field reference: documentation/production/playtest-log-schema.md.
#
#   Every line: {"v": SCHEMA_VERSION, "sid": <anonymous session id>, "seq": n, "t_ms": ms since
#   this session started (monotonic), "event": <name>, ...fields}. SCHEMA lists every event, its
#   fields and their types; validate_entry() checks a line against it (tests use it).
#
#   What it hears (all EventBus): screen_shown, match_context, match_view_changed, rules_event,
#   match_ended, coach_step. The match controller sends rules_event with
#   LoadoutRules.events_for(human) and match_view_changed with LoadoutRules.view(state, human),
#   so the logger only ever holds what the human may see: the AI's hand, held cards and loadout
#   order never reach it. Card ids for instance ids come from a cache filled from those views.
#   Seats are logged as "human" / "ai" (hot-seat: "ai" = the seat the controller isn't showing).
#   cz14 hot-seat (mode "hotseat"): "human" = Player 1 (P1), "ai" = Player 2, and both seats are
#   people, so neither seat's private cards are logged or cached: the views arrive from whichever
#   seat is on screen (view.seat says which), the card cache keeps public lists only (lines,
#   removed, drops, shots), turn_start.hand_ids and pack.hold_ids are [] (the counts stay), and
#   the latest view is kept without its private lists. The Brace prompt is read when the
#   defender's own view arrives (after the pass-the-device cover); only its counts are logged.
#   One extra hook: the match screen's option_pressed(&"end_turn") marks the start of the Pack
#   step (pack_ms); without it, pack_ms runs from the human's last action (pack_from says which).
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
# Dependencies: EventBus (signals), CardDB (printed damage for shot.raw), SceneRouter (survey),
#   scripts/ui/screen_profile.gd, scenes/survey/ConsentPrompt.tscn, scenes/survey/Survey.tscn.
# Author: Data Scientist Agent
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const CONSENT_PROMPT_SCENE: String = "res://scenes/survey/ConsentPrompt.tscn"
const SURVEY_SCENE: String = "res://scenes/survey/Survey.tscn"

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
const EXPORT_FORMAT: String = "cardzone-playtest-log"
const HUMAN: String = "human"
const AI: String = "ai"

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
	"match_start": {"match": "i", "mode": "s", "ai_level": "s", "first_player": "s", "human_seat": "i",
			"route": "s", "drop_human": "s", "drop_ai": "s", "hand_size": "i", "tunables_hash": "s",
			"tunables": "d", "setup_s": "n", "play_again": "b"},
	"match_resumed": {"match": "i", "age_s": "n", "actions": "i", "round": "i", "mode": "s", "ai_level": "s"},
	"round_start": {"round": "i", "zone_card": "i", "health_h": "i", "health_ai": "i", "bounty": "s"},
	"turn_start": {"seat": "s", "round": "i", "turn": "i", "hand_ids": "a", "hits_drawn": "i"},
	"card_play": {"seat": "s", "card_id": "s", "as": "s", "round": "i"},
	"move": {"seat": "s", "from": "s", "to": "s", "round": "i"},
	"loot": {"seat": "s", "card_id": "s", "source": "s", "cost": "i", "area": "s", "round": "i"},
	"attach": {"seat": "s", "attachment_id": "s", "weapon_id": "s", "round": "i"},
	"shot": {"shooter": "s", "kind": "s", "weapon_id": "s", "attachments": "a", "target": "s", "raw": "i",
			"cover": "i", "down": "i", "damage": "i", "suppressor": "b", "brace_allowed": "b",
			"brace_cards": "a", "brace_total": "i", "hits": "i", "bounty_claim": "b", "bounty_heal": "i",
			"eliminated": "b", "round": "i"},
	"brace": {"kind": "s", "prompt_ms": "i", "cards": "a", "card_count": "i", "total": "i", "damage": "i",
			"hits": "i", "eligible": "i", "possible": "b", "suggested_used": "b?", "round": "i"},
	"patch_up": {"seat": "s", "healed": "i", "health": "i", "round": "i"},
	"ditch": {"seat": "s", "card_id": "s", "round": "i"},
	"gas_hit": {"seat": "s", "area": "s", "hits": "i", "health": "i", "round": "i"},
	"final_circle": {"step": "i", "hits": "i", "health_h": "i", "health_ai": "i", "round": "i"},
	"pack": {"hold_ids": "a", "hold_count": "i", "pack_ms": "i", "pack_from": "s", "line_stowed": "i",
			"hand_stowed": "i", "round": "i"},
	"turn_end": {"turn_ms": "i", "undo_count": "i", "round": "i", "turn": "i"},
	"elimination": {"seat": "s", "round": "i", "by": "s"},
	"match_end": {"match": "i", "result": "s", "rounds": "i", "duration_s": "n", "cause": "s",
			"health_h": "i", "health_ai": "i", "mode": "s", "ai_level": "s", "resumed": "b", "human_turns": "i"},
	"coach_step": {"step": "s", "skipped": "b"},
	"survey": {"q1": "i?", "q2": "i?", "q3": "i?", "q4": "i?", "q5": "i?", "open": "s", "answered": "i"},
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
	"match_start.mode": ["ai", "hotseat"],
	"match_start.first_player": ["human", "ai"],
	"match_resumed.mode": ["ai", "hotseat"],
	"round_start.bounty": ["human", "ai", "none"],
	"turn_start.seat": ["human", "ai"],
	"card_play.seat": ["human", "ai"],
	"card_play.as": ["effect", "adrenaline_move", "adrenaline_search"],
	"move.seat": ["human", "ai"],
	"loot.seat": ["human", "ai"],
	"loot.source": ["pile", "drop", "crate"],
	"attach.seat": ["human", "ai"],
	"shot.shooter": ["human", "ai"],
	"shot.kind": ["shot", "frag"],
	"shot.target": ["human", "ai"],
	"brace.kind": ["shot", "frag"],
	"patch_up.seat": ["human", "ai"],
	"ditch.seat": ["human", "ai"],
	"gas_hit.seat": ["human", "ai"],
	"pack.pack_from": ["pack_step", "last_action"],
	"elimination.seat": ["human", "ai"],
	"elimination.by": ["shot", "frag", "gas", "final_circle"],
	"match_end.result": ["win", "loss", "draw"],
	"match_end.cause": ["shot", "frag", "gas", "final_circle", "hard_end", "concede"],
	"match_end.mode": ["ai", "hotseat"],
	"log_exported.method": ["download", "file"],
	"quit.reason": ["close", "pagehide"],
}

## Plan section 8 statements (1-5 agreement, 4+ counts as agree) and the open question.
## kpi names and bars match documentation/production/playtest-log-schema.md and tools/kpi_sheet.py.
const SURVEY_QUESTIONS: Array[Dictionary] = [
	{"id": "q1", "kpi": "play_again", "text": "I want to play another match."},
	{"id": "q2", "kpi": "damage_clear", "text": "I understood why I took damage."},
	{"id": "q3", "kpi": "packing_quick", "text": "Packing felt quick."},
	{"id": "q4", "kpi": "choices_over_luck", "text": "My choices mattered more than luck."},
	{"id": "q5", "kpi": "ai_fair", "text": "The AI played fair."},
]
const OPEN_QUESTION: String = "Is there anything else you'd like to tell us about the game? (Please leave out names and personal details.)"
const SCALE_LOW: String = "Strongly disagree"
const SCALE_HIGH: String = "Strongly agree"

## Rules events that belong to a shot or Frag still being resolved (see _on_rules_event).
const SHOT_EVENTS: Array[String] = ["brace_requested", "braced", "hits_landed", "bounty_claimed", "spent",
		"eliminated", "crate_formed"]
## Human rules events that count as an action (pack_ms falls back to the last one).
const HUMAN_ACTIONS: Array[String] = ["played", "adrenaline", "moved", "looted", "attached", "patched_up",
		"ditched", "shot_declared", "frag_thrown", "undone"]

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
## Add the small PLAYTEST corner button on the title screen (unless the title has its own
## node named "PlaytestButton").
var show_title_button: bool = true
## Last survey answers ({} until submitted); kept with the consent so the screen can show them.
var survey_answers: Dictionary = {}
## Running totals for this session (summary line on the survey screen, tests).
var stats: Dictionary = {}
## Milliseconds clock. Tests and tools/synthetic_playtest_sessions.gd swap in a fake one.
var clock: Callable = Callable(Time, "get_ticks_msec")

var _seq: int = 0
var _pending: PackedStringArray = []
var _flush_queued: bool = false
var _session_logged: bool = false
var _load_ms: int = 0
var _screen: String = ""
var _inputs_seen: Dictionary = {}
var _prompt: Node = null
var _title_layer: CanvasLayer = null
var _js_callbacks: Array = []
var _match_screen: WeakRef = null
# Match tracking (reset by match_context).
var _m: Dictionary = {}
var _match_index: int = 0
var _title_since_end: bool = true
var _cards: Dictionary = {}       # instance id -> card id, from the human's views only
var _view: Dictionary = {}        # the latest human view
var _health: Array[int] = [0, 0]  # by seat
var _shots: Array[Dictionary] = []  # shot / Frag records being resolved


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
	session_started_ms = _now()
	_seq = 0
	_session_logged = false
	_screen = ""
	_inputs_seen = {}
	_m = {}
	_match_index = 0
	_title_since_end = true
	_cards = {}
	_view = {}
	_shots = []
	stats = {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "resumes": 0, "packs": 0,
			"holds": 0, "shots": 0, "braces": 0, "inputs": {}}


func _now() -> int:
	return int(clock.call())


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


## Opens the PLAYTEST screen (survey + Download log). For the title button and cz13's end screen.
func open_survey() -> bool:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router == null:
		return false
	return bool(router.call("goto_scene", SURVEY_SCENE))


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
		"t_ms": _now() - session_started_ms, "event": event_name,
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
	for key: String in ["hand_ids", "hold_ids", "cards", "brace_cards", "attachments"]:
		if entry.get(key) is Array:
			for v: Variant in entry[key]:
				if not v is String:
					errors.append("%s.%s: %s is not a card id" % [event_name, key, str(v)])
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

## answers: {"q1".."q5": int 1-5 (anything else is stored as null = skipped), "open": String}.
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

## File name for downloads: cardzone-playtest-<date>-<sid>.json.
func export_file_name() -> String:
	return "cardzone-playtest-%s-%s.json" % [Time.get_date_string_from_system(true), session_id]


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
	return "Session %s · %d match%s (%d W / %d L / %d D) · %d resumed" % [
			session_id, stats["matches"], "" if stats["matches"] == 1 else "es", stats["wins"],
			stats["losses"], stats["draws"], stats["resumes"]]


# =============================================================================
# EventBus handlers
# =============================================================================

func _connect_bus() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		push_warning("PlaytestLog: EventBus missing, nothing will be logged")
		return
	var hooks: Dictionary = {
		"screen_shown": _on_screen_shown, "match_context": _on_match_context,
		"match_view_changed": _on_view, "rules_event": _on_rules_event,
		"match_ended": _on_match_ended, "coach_step": _on_coach_step,
	}
	for sig: String in hooks:
		if bus.has_signal(sig):
			bus.connect(sig, hooks[sig])
		else:
			push_warning("PlaytestLog: EventBus has no signal %s" % sig)


func _on_screen_shown(screen_id: StringName) -> void:
	var screen_name: String = String(screen_id)
	if screen_name == "title":
		_title_since_end = true
	if screen_name != _screen:
		_screen = screen_name
		_write("screen", {"name": screen_name})
	_update_title_button()
	if screen_name == "match":
		_find_match_screen.call_deferred()
	if auto_prompt and needs_consent():
		auto_prompt = false
		show_consent_prompt.call_deferred()


func _on_coach_step(step: StringName, skipped: bool) -> void:
	_write("coach_step", {"step": step, "skipped": skipped})


## A match starts (or resumes). Resets the match context; a new match's match_start is written
## once both drops are known (round 1), a resume writes match_resumed now.
func _on_match_context(info: Dictionary) -> void:
	_close_shots()
	_match_index += 1
	_cards = {}
	_view = {}
	_shots = []
	var human: int = int(info.get("human_seat", 0))
	_m = {"human": human, "mode": str(info.get("mode", "ai")), "ai_level": str(info.get("ai_level", "")),
			"first_seat": int(info.get("first_seat", 0)), "route": str(info.get("route", "")),
			"hand_size": int(info.get("hand_size", 0)), "tunables_hash": str(info.get("tunables_hash", "")),
			"tunables": info.get("tunables", {}), "resumed": bool(info.get("resumed", false)),
			"started_ms": _now(), "drops": {}, "start_logged": false, "round": 0, "turn": 0,
			"zone_card": 0, "bounty": -1, "human_turns": 0, "turn_started_ms": -1, "last_action_ms": -1,
			"pack_mark_ms": -1, "undos": 0, "brace_ms": -1, "brace_prompt": {}, "over": false,
			"play_again": not _title_since_end, "match": _match_index, "health_known": false}
	if (_m["mode"] as String) not in ["ai", "hotseat"]:
		_m["mode"] = "ai"
	_title_since_end = false
	if _m["resumed"]:
		stats["resumes"] += 1
		_m["start_logged"] = true
		_m["round"] = int(info.get("round", 0))
		_m["turn_started_ms"] = _now()
		_m["last_action_ms"] = _now()
		var age: float = float(info.get("age_s", -1.0))
		_write("match_resumed", {"match": _match_index, "age_s": snappedf(age, 0.1),
				"actions": int(info.get("actions", 0)), "round": _m["round"], "mode": _m["mode"], "ai_level": _m["ai_level"]})


## The human's view after each action: card names for instance ids, health, bounty, Brace prompt.
func _on_view(view: Dictionary) -> void:
	if _m.is_empty():
		return
	var hot: bool = _hotseat()
	_view = _public_view(view) if hot else view  # cz14: hot-seat keeps no private list
	var me: Dictionary = view.get("me", {})
	var opp: Dictionary = view.get("opponent", {})
	var lists: Array = [me.get("line", []), opp.get("line", []), opp.get("held_cards", []), view.get("removed", [])]
	if not hot:
		lists.append_array([me.get("hand", []), me.get("loadout", []), me.get("next_hand", [])])
	for list: Variant in lists:
		_remember(list)
	for area_drops: Variant in (view.get("drops", {}) as Dictionary).values():
		_remember(area_drops)
	var ls: Dictionary = view.get("last_shot", {})
	for key: String in ["weapon", "card"]:
		if ls.get(key) is Dictionary:
			_remember([ls[key]])
	var prompt: Dictionary = view.get("brace_prompt", {})
	if not hot:
		_remember(prompt.get("next_hand", []))
	elif not prompt.is_empty() and int(view.get("seat", -1)) == int(_m["human"]) and int(_m.get("brace_ms", -1)) >= 0 \
			and (_m.get("brace_prompt", {}) as Dictionary).is_empty():
		# cz14: the defender's prompt opens after the cover: the Brace time starts here.
		_m["brace_prompt"] = _prompt_counts(prompt)
		_m["brace_ms"] = _now()
	# Health and the Bounty come from the first view only; after that the events carry them, so
	# round_start shows the health at the round's start (a view is taken after the whole action).
	if not bool(_m["health_known"]):
		_m["health_known"] = true
		var h: int = int(view.get("seat", _m["human"]))  # cz14: the seat this view belongs to
		_health[h] = int(me.get("health", 0))
		_health[1 - h] = int(opp.get("health", 0))
		_m["zone_card"] = int(view.get("zone_card", 0))
		_m["bounty"] = int(view.get("bounty", -1))


## cz14: true for a hot-seat match (two people: no seat's private cards are logged or cached).
func _hotseat() -> bool:
	return str(_m.get("mode", "")) == "hotseat"


## cz14: a view without its seat-private lists (hand, loadout, next draw / hand, held, Brace prompt).
func _public_view(view: Dictionary) -> Dictionary:
	var v: Dictionary = view.duplicate(true)
	var me: Dictionary = v.get("me", {})
	for key: String in ["hand", "loadout", "next_draw", "next_hand", "held"]:
		if me.has(key):
			me[key] = []
	v.erase("brace_prompt")
	v.erase("shot_preview")
	return v


## cz14: what the brace line needs from a prompt (counts and the suggested / eligible instance
## ids it compares with the public braced cards), no card ids.
func _prompt_counts(prompt: Dictionary) -> Dictionary:
	return {"damage": prompt.get("damage", 0), "kind": prompt.get("kind", "shot"),
			"eligible": (prompt.get("eligible", []) as Array).duplicate(),
			"suggested": (prompt.get("suggested", []) as Array).duplicate() if prompt.get("suggested") is Array else null}


func _remember(list: Variant) -> void:
	if not list is Array:
		return
	for cv: Variant in list:
		if cv is Dictionary and cv.has("id") and cv.has("card"):
			_cards[int(cv["id"])] = str(cv["card"])


func _card(inst: Variant) -> String:
	return str(_cards.get(int(inst), ""))


func _seat(seat: Variant) -> String:
	return HUMAN if int(seat) == int(_m.get("human", 0)) else AI


func _is_human(seat: Variant) -> bool:
	return not _m.is_empty() and int(seat) == int(_m["human"])


## One engine event as the human may see it (LoadoutRules.events_for(human)), in play order.
func _on_rules_event(e: Dictionary) -> void:
	if _m.is_empty():
		return
	var t: String = str(e.get("type", ""))
	if not SHOT_EVENTS.has(t):
		_close_shots()
	var now: int = _now()
	if _is_human(e.get("seat", -1)) and HUMAN_ACTIONS.has(t):
		_m["last_action_ms"] = now
		_m["pack_mark_ms"] = -1
		if t == "undone":
			_m["undos"] = int(_m["undos"]) + 1
	var rnd: int = int(_m["round"])
	match t:
		"dropped":
			(_m["drops"] as Dictionary)[_seat(e["seat"])] = str(e.get("area", ""))
		"round_started":
			_m["round"] = int(e.get("round", 0))
			if not bool(_m["start_logged"]):
				_log_match_start()
		"bounty_changed":
			_m["bounty"] = int(e.get("to", -1))
		"zone_flipped":
			_m["zone_card"] = int(e.get("card", 0))
			var h: int = int(_m["human"])
			var b: int = int(_m["bounty"])
			_write("round_start", {"round": _m["round"], "zone_card": _m["zone_card"], "health_h": _health[h],
					"health_ai": _health[1 - h], "bounty": "none" if b < 0 else _seat(b)})
		"final_circle":
			var hp: Array = e.get("health", [])
			if hp.size() == 2:
				_health = [int(hp[0]), int(hp[1])]
			var h: int = int(_m["human"])
			_write("final_circle", {"step": int(e.get("step", 0)), "hits": int(e.get("hits", 0)),
					"health_h": _health[h], "health_ai": _health[1 - h], "round": rnd})
		"turn_started":
			_m["turn"] = int(_m["turn"]) + 1
			_m["round"] = int(e.get("round", rnd))
		"drew":
			var human_turn: bool = _is_human(e["seat"])
			var ids: Array = []
			if human_turn and not _hotseat():  # cz14: hot-seat logs no seat's drawn cards
				for inst: Variant in e.get("cards", []):
					ids.append(_card(inst))
				_m["human_turns"] = int(_m["human_turns"]) + 1
				_m["turn_started_ms"] = now
				_m["last_action_ms"] = now
				_m["pack_mark_ms"] = -1
				_m["undos"] = 0
			_write("turn_start", {"seat": _seat(e["seat"]), "round": int(_m["round"]), "turn": int(_m["turn"]),
					"hand_ids": ids, "hits_drawn": int(e.get("hits", 0))})
		"played":
			_write("card_play", {"seat": _seat(e["seat"]), "card_id": str(e.get("card_id", "")), "as": "effect", "round": rnd})
		"adrenaline":
			_write("card_play", {"seat": _seat(e["seat"]), "card_id": _card(e.get("card", 0)),
					"as": "adrenaline_" + str(e.get("mode", "move")), "round": rnd})
		"healed", "patched_up", "hits_landed", "gas_hit", "bounty_claimed":
			if e.has("health") and e.has("seat"):
				_health[int(e["seat"])] = int(e["health"])
			match t:
				"patched_up":
					_write("patch_up", {"seat": _seat(e["seat"]), "healed": int(e.get("healed", 0)),
							"health": int(e.get("health", 0)), "round": rnd})
				"gas_hit":
					_write("gas_hit", {"seat": _seat(e["seat"]), "area": str(e.get("area", "")),
							"hits": int(e.get("count", 0)), "health": int(e.get("health", 0)), "round": rnd})
				"hits_landed":
					for s: Dictionary in _shots:
						if int(s["seat"]) == int(e["seat"]):
							s["landed"] = int(e.get("count", 0))
				"bounty_claimed":
					for s: Dictionary in _shots:
						s["bounty_claim"] = true
						s["bounty_heal"] = int(e.get("healed", 0))
		"moved":
			_write("move", {"seat": _seat(e["seat"]), "from": str(e.get("from", "")), "to": str(e.get("to", "")), "round": rnd})
		"looted":
			_write("loot", {"seat": _seat(e["seat"]), "card_id": str(e.get("card_id", "")), "source": str(e.get("source", "pile")),
					"cost": int(e.get("cost", 0)), "area": str(e.get("area", "")), "round": rnd})
		"attached":
			_write("attach", {"seat": _seat(e["seat"]), "attachment_id": str(e.get("attachment_id", "")),
					"weapon_id": str(e.get("weapon_id", "")), "round": rnd})
		"ditched":
			_write("ditch", {"seat": _seat(e["seat"]), "card_id": str(e.get("card_id", "")), "round": rnd})
		"shot_declared":
			_open_shot(e, "shot")
		"frag_thrown":
			_open_shot(e, "frag")
		"brace_requested":
			if _is_human(e["seat"]):
				_m["brace_ms"] = now
				_m["brace_prompt"] = (_view.get("brace_prompt", {}) as Dictionary).duplicate(true)
				_m["brace_damage"] = int(e.get("damage", 0))
		"braced":
			_on_braced(e, now)
		"packed":
			if _is_human(e["seat"]):
				_log_pack(e, now)
		"eliminated":
			for s: Dictionary in _shots:
				if int(s["seat"]) == int(e["seat"]):
					s["eliminated"] = true
			var cause: String = str(e.get("cause", "shot"))
			_write("elimination", {"seat": _seat(e["seat"]), "round": rnd,
					"by": cause if ENUMS["elimination.by"].has(cause) else "shot"})
		"match_ended", "conceded":
			_close_shots()
			_m["cause"] = "concede" if t == "conceded" else str(e.get("cause", _m.get("cause", "")))
			if t == "match_ended":
				_m["winner"] = int(e.get("winner", -1)) if str(e.get("result", "")) == "win" else -1


func _log_match_start() -> void:
	_m["start_logged"] = true
	var drops: Dictionary = _m["drops"]
	stats["matches"] += 1
	_write("match_start", {"match": _m["match"], "mode": _m["mode"], "ai_level": _m["ai_level"],
			"first_player": _seat(_m["first_seat"]), "human_seat": _m["human"], "route": _m["route"],
			"drop_human": str(drops.get(HUMAN, "")), "drop_ai": str(drops.get(AI, "")),
			"hand_size": _m["hand_size"], "tunables_hash": _m["tunables_hash"], "tunables": _m["tunables"],
			"setup_s": snappedf((_now() - int(_m["started_ms"])) / 1000.0, 0.1), "play_again": _m["play_again"]})


## A shot or Frag starts: one record per target (from the view of this action, which holds the
## declared shot's Cover / Down / damage per target).
func _open_shot(e: Dictionary, kind: String) -> void:
	var ls: Dictionary = _view.get("last_shot", {})
	var targets: Dictionary = ls.get("targets", {})
	var weapon: Dictionary = (ls.get("weapon", ls.get("card", {})) as Dictionary)
	var weapon_id: String = str(e.get("weapon_id", weapon.get("card", "")))
	if weapon_id == "":
		weapon_id = _card(e.get("card", e.get("weapon", 0)))
	var atts: Array = (weapon.get("attachments", []) as Array).duplicate()
	var order: Array = []
	if kind == "shot":
		order = [int(e.get("target", -1))]
	else:
		for k: Variant in (e.get("targets", {}) as Dictionary).keys():
			order.append(int(k))
	for target: int in order:
		var rec: Dictionary = targets.get(target, targets.get(str(target), {}))
		var shown: Dictionary = (e.get("targets", {}) as Dictionary).get(target, (e.get("targets", {}) as Dictionary).get(str(target), {}))
		var damage: int = int(e.get("damage", rec.get("damage_before_brace", shown.get("damage", 0))))
		var cover: int = int(e.get("cover", rec.get("cover", 0)))
		var down: int = int(e.get("down", rec.get("down", shown.get("down", 0))))
		var suppressed: bool = bool(e.get("suppressed", rec.get("suppressed", false)))
		var raw: int = _raw_damage(weapon_id, atts, kind)
		if raw < 0:
			raw = damage + cover + down
		_shots.append({"seat": target, "shooter": _seat(e.get("seat", 0)), "kind": kind, "weapon_id": weapon_id,
				"attachments": atts, "target": _seat(target), "raw": raw, "cover": cover, "down": down,
				"damage": damage, "suppressor": suppressed, "brace_allowed": damage > 0 and not suppressed,
				"brace_cards": [], "brace_total": 0, "hits": damage, "landed": -1, "bounty_claim": false,
				"bounty_heal": 0, "eliminated": false, "round": int(_m["round"])})
	stats["shots"] += order.size()


## Printed damage plus attachment damage (CardDB, public card text); -1 when unknown.
func _raw_damage(weapon_id: String, atts: Array, kind: String) -> int:
	var db: Node = get_node_or_null("/root/CardDB")
	if db == null or weapon_id == "" or not db.has_method(&"get_card"):
		return -1
	var c: Object = db.call("get_card", StringName(weapon_id))
	if c == null:
		return -1
	var raw: int = int(c.get("blast_dmg")) if kind == "frag" else int(c.get("dmg"))
	for a: Variant in atts:
		var ac: Object = db.call("get_card", StringName(str(a)))
		if ac != null:
			raw += int(ac.get("attach_dmg"))
	return raw


func _on_braced(e: Dictionary, now: int) -> void:
	var ids: Array = e.get("card_ids", [])
	for s: Dictionary in _shots:
		if int(s["seat"]) == int(e["seat"]):
			s["brace_cards"] = ids.duplicate()
			s["brace_total"] = int(e.get("total", 0))
			s["hits"] = int(e.get("hits", s["hits"]))
	if not _is_human(e["seat"]):
		return
	stats["braces"] += 1
	var prompt: Dictionary = _m.get("brace_prompt", {})
	var eligible: int = (prompt.get("eligible", []) as Array).size()
	var suggested: Variant = null
	if prompt.get("suggested") is Array:
		var want: Array = (prompt["suggested"] as Array).map(func(x: Variant) -> int: return int(x))
		var got: Array = (e.get("cards", []) as Array).map(func(x: Variant) -> int: return int(x))
		want.sort()
		got.sort()
		suggested = want == got
	var started: int = int(_m.get("brace_ms", -1))
	_write("brace", {"kind": str(prompt.get("kind", _shots[0]["kind"] if not _shots.is_empty() else "shot")),
			"prompt_ms": maxi(0, now - started) if started >= 0 else 0, "cards": ids,
			"card_count": ids.size(), "total": int(e.get("total", 0)),
			"damage": int(prompt.get("damage", _m.get("brace_damage", 0))), "hits": int(e.get("hits", 0)),
			"eligible": eligible, "possible": eligible > 0, "suggested_used": suggested, "round": int(_m["round"])})
	_m["brace_ms"] = -1


## Writes every shot record still open (one line per target), in declaration order.
func _close_shots() -> void:
	if _shots.is_empty():
		return
	var open: Array[Dictionary] = _shots
	_shots = []
	for s: Dictionary in open:
		var line: Dictionary = s.duplicate()
		line.erase("seat")
		line.erase("landed")
		_write("shot", line)


func _log_pack(e: Dictionary, now: int) -> void:
	var held: Array = []
	for inst: Variant in ([] if _hotseat() else e.get("held", [])):  # cz14: no held ids in hot-seat
		held.append(_card(inst))
	var mark: int = int(_m["pack_mark_ms"])
	var from: String = "pack_step"
	if mark < 0:
		mark = int(_m["last_action_ms"])
		from = "last_action"
	stats["packs"] += 1
	if not held.is_empty():
		stats["holds"] += 1
	_write("pack", {"hold_ids": held, "hold_count": int(e.get("held_count", held.size())),
			"pack_ms": maxi(0, now - mark) if mark >= 0 else 0, "pack_from": from,
			"line_stowed": (e.get("line_stowed", []) as Array).size(),
			"hand_stowed": int(e.get("hand_stowed_count", 0)), "round": int(_m["round"])})
	var started: int = int(_m["turn_started_ms"])
	_write("turn_end", {"turn_ms": maxi(0, now - started) if started >= 0 else 0, "undo_count": int(_m["undos"]),
			"round": int(_m["round"]), "turn": int(_m["turn"])})
	_m["pack_mark_ms"] = -1
	_m["undos"] = 0


## Marks the start of the Pack step (the first END TURN press after the human's last action).
## The match screen's option_pressed(&"end_turn") calls it; tests and tools may call it directly.
func mark_pack_step() -> void:
	if _m.is_empty() or int(_m["pack_mark_ms"]) >= 0:
		return
	_m["pack_mark_ms"] = _now()


func _on_option_pressed(key: StringName) -> void:
	if key == &"end_turn":
		mark_pack_step()


## EventBus.match_ended (right after the rules' match_ended): result from the human's view.
## duration_s is measured on the logger's own clock from match_context (the controller's timer
## starts at the same call, so they agree in play; a resumed match counts from the resume).
func _on_match_ended(winner: int, reason: StringName, rounds: int, _duration_s: float) -> void:
	if _m.is_empty() or bool(_m["over"]):
		return
	_close_shots()
	_m["over"] = true
	_title_since_end = false
	if not bool(_m["start_logged"]):
		_log_match_start()
	var h: int = int(_m["human"])
	var result: String = "draw" if winner < 0 else ("win" if winner == h else "loss")
	match result:
		"win": stats["wins"] += 1
		"loss": stats["losses"] += 1
		"draw": stats["draws"] += 1
	var cause: String = str(_m.get("cause", String(reason)))
	if cause == "":
		cause = String(reason)
	if not ENUMS["match_end.cause"].has(cause):
		cause = "shot"
	var me: Dictionary = _view.get("me", {})
	var opp: Dictionary = _view.get("opponent", {})
	if int(_view.get("seat", h)) != h:  # cz14: hot-seat ends on either seat's view
		var swap: Dictionary = me
		me = opp
		opp = swap
	_write("match_end", {"match": _m["match"], "result": result, "rounds": rounds,
			"duration_s": snappedf((_now() - int(_m["started_ms"])) / 1000.0, 0.1), "cause": cause,
			"health_h": int(me.get("health", _health[h])), "health_ai": int(opp.get("health", _health[1 - h])),
			"mode": _m["mode"], "ai_level": _m["ai_level"], "resumed": _m["resumed"],
			"human_turns": int(_m["human_turns"])})
	flush()


## The match screen's END TURN button (option_pressed) starts the Pack step: hook it once.
func _find_match_screen() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.root.find_children("*", "Control", true, false):
		if n.has_signal(&"option_pressed") and n.has_signal(&"card_tapped"):
			if not n.is_connected(&"option_pressed", _on_option_pressed):
				n.connect(&"option_pressed", _on_option_pressed)
			_match_screen = weakref(n)
			return


# =============================================================================
# Title button
# =============================================================================

## On the title: a small PLAYTEST button in the top-right corner (inside the safe area) that
## opens the survey / Download log screen. Skipped when the title has its own "PlaytestButton".
func _update_title_button() -> void:
	var want: bool = show_title_button and _screen == "title"
	if want:
		var tree: SceneTree = get_tree()
		var scene: Node = tree.current_scene if tree != null else null
		if scene != null and scene.find_child("PlaytestButton", true, false) != null:
			want = false
	if not want:
		if _title_layer != null and is_instance_valid(_title_layer):
			_title_layer.queue_free()
		_title_layer = null
		return
	if _title_layer != null and is_instance_valid(_title_layer):
		return
	_title_layer = CanvasLayer.new()
	_title_layer.name = "PlaytestCorner"
	_title_layer.layer = 50
	add_child(_title_layer)
	var root: Control = Control.new()
	root.name = "PlaytestCornerRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_script: GDScript = load("res://scripts/ui/match_theme.gd") as GDScript
	if theme_script != null:
		root.theme = theme_script.call("build")  # the title's dark button plate
	_title_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b: Button = Button.new()
	b.name = "PlaytestCornerButton"
	b.text = "PLAYTEST"
	b.custom_minimum_size = Vector2(150, 64)
	b.add_theme_font_size_override(&"font_size", 16)
	b.pressed.connect(func() -> void: open_survey())
	root.add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_place_corner_button.call_deferred(b)


func _place_corner_button(b: Button) -> void:
	if not is_instance_valid(b):
		return
	var logical: Vector2 = b.get_viewport_rect().size
	var margin: Vector2 = Vector2(16, 12)
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone:
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if window.x > 0.0 and safe.size.x > 0.0:
			var k: Vector2 = logical / window
			margin.x = maxf(margin.x, (window.x - safe.end.x) * k.x)
			margin.y = maxf(margin.y, safe.position.y * k.y)
	b.size = b.custom_minimum_size
	b.position = Vector2(logical.x - b.size.x - margin.x, margin.y)


## The corner button while the title shows (tests), else null.
func get_title_button() -> Button:
	if _title_layer == null or not is_instance_valid(_title_layer):
		return null
	return _title_layer.find_child("PlaytestCornerButton", true, false) as Button


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
	_close_shots()
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
	return (_now() - session_started_ms) / 1000.0


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
