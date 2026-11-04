# match_store.gd
# Purpose: MatchStore autoload (cz08). Keeps the match in progress on disk so a closed tab, a
#   crash or a web reload resumes at the same step. The match screen calls save() after every
#   action; the title screen asks has_saved_match() / saved_info() and calls resume().
#   A save is the replay record (origin + action list) plus the balance snapshot and tunables
#   hash, the AI level and seed (from meta) and a summary; see scripts/save/match_save_codec.gd
#   for the format. Resume replays the moves (U1) and checks the result against the saved
#   fingerprint, so a resumed match is exactly the saved one (undo history included).
#   Writes are atomic (temp file, then rename); on the web user:// lives in IndexedDB, which
#   Godot syncs asynchronously (measured 0.2-1 s after a write in Chromium), so on the web every
#   save is also mirrored to localStorage (synchronous) and the newer copy (header seq) wins:
#   a reload right after an action still resumes at that action.
#   A damaged, old, newer-schema or no-longer-replayable save never crashes: it is copied to
#   "<save>.<status>.bak", removed, and status()/status_text() say why, so the UI offers a new
#   match. Under the headless test runner the store never touches the real save (is_test_run):
#   it uses test_save_path(), one file per test process (user://test_match_store/<pid>/...), so
#   several suites running at once on one machine never share a save (cz14, as cz13 did for prefs).
#
# API (cz11 match screen, cz13 title/pause):
#   save(state, meta = {}) -> bool     after every action; meta is plain data, e.g.
#       {mode: "ai"|"hotseat", ai_level: "rookie", ai_seed: 1234, human_seat: 0}. An empty meta
#       keeps the last one. A finished match clears the save instead (nothing to resume).
#   has_saved_match() -> bool          a save exists and replays (the first call does the replay)
#   saved_info() -> Dictionary         {has_match, status, text, error, backup, step, round, phase,
#       active, pending_brace, undo_depth, saved_at, meta, ai_level, ai_seed, tunables_hash}
#   resume() -> Dictionary             {state: MatchState, meta: Dictionary}, or {} (see status())
#   clear()                            forget the saved match (new match, concede, match end)
#   status() / status_text() / last_error()   why there is nothing to resume
#   signal saved(step)                 after each successful write
# Dependencies: CardDB (content), MatchSaveCodec, SaveFile, MatchState, RulesData.
# Author: Mechanics Developer Agent
extends Node

## Emitted after a save was written; step = the number of logged actions.
signal saved(step: int)

const DEFAULT_SAVE_PATH: String = "user://cardzone_match.save"
## The autoload's own file under the test runner (wiped at start), so tests never touch a real save.
## The file actually used is per test process: see test_save_path().
const TEST_SAVE_PATH: String = "user://test_match_store/autoload_match.save"

## Where the save lives. Tests point their own instance at their own file.
var save_path: String = DEFAULT_SAVE_PATH
## Saving on/off (e.g. a QA fixture or tutorial that must not replace the player's match).
var enabled: bool = true
## Match content to rebuild with. Null = built from the CardDB autoload when needed.
var content: RulesData = null
## Web only: also keep the save in localStorage (see the header). Off outside the web.
var mirror_to_local_storage: bool = true

var _status: StringName = MatchSaveCodec.NONE
var _error: String = ""
var _backup: String = ""
var _probed: bool = false
var _body: Dictionary = {}           # decoded save body while status is OK
var _restored: MatchState = null     # replayed state from the probe, handed out by resume()
var _last_meta: Dictionary = {}
var _seq: int = 0                    # header seq of the newest save seen or written


func _ready() -> void:
	if is_test_run() and save_path == DEFAULT_SAVE_PATH:
		save_path = test_save_path()
		SaveFile.remove(save_path)
		SaveFile.remove(save_path + ".tmp")


## True when the main loop is the headless test runner (a script under res://tests/).
static func is_test_run() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var script: Script = loop.get_script() if loop != null else null
	return script != null and script.resource_path.begins_with("res://tests/")


## The test runner's save file for this process: user://test_match_store/<pid>/autoload_match.save.
static func test_save_path() -> String:
	return TEST_SAVE_PATH.get_base_dir().path_join(str(OS.get_process_id())).path_join(TEST_SAVE_PATH.get_file())


## The file actually used (the default path is swapped for the test file under the test runner,
## also for instances that never entered the tree).
func path() -> String:
	if save_path == DEFAULT_SAVE_PATH and is_test_run():
		return test_save_path()
	return save_path


# --- Saving ---------------------------------------------------------------------------

## Writes the match (call after every applied action). Returns true when written.
func save(state: MatchState, meta: Dictionary = {}) -> bool:
	if not enabled or state == null or state.data == null:
		return false
	if not meta.is_empty():
		_last_meta = MatchSaveCodec.plain_data(meta)
	if state.is_over():
		clear()
		return true
	if not _probed:
		_probe_seq_only()
	_seq += 1
	var text: String = MatchSaveCodec.encode(state, _last_meta, -1, _seq)
	_mirror_write(text)
	if not SaveFile.write_text(path(), text):
		_error = "could not write %s" % path()
		return false
	_status = MatchSaveCodec.OK
	_error = ""
	_backup = ""
	_probed = false  # re-read on the next query (cheap) rather than trust memory
	_body = {}
	_restored = null
	saved.emit(state.actions.size())
	return true


## Forgets the saved match (and any status from a failed load).
func clear() -> void:
	SaveFile.remove(path())
	SaveFile.remove(path() + ".tmp")
	_mirror_write("")
	_status = MatchSaveCodec.NONE
	_error = ""
	_backup = ""
	_body = {}
	_restored = null
	_probed = true


# --- Loading --------------------------------------------------------------------------

func has_saved_match() -> bool:
	_probe()
	return _status == MatchSaveCodec.OK


func saved_info() -> Dictionary:
	_probe()
	var info: Dictionary = {
		"has_match": _status == MatchSaveCodec.OK, "status": _status, "text": status_text(),
		"error": _error, "backup": _backup,
	}
	if _status == MatchSaveCodec.OK:
		var summary: Dictionary = _body.get("summary", {})
		for key: String in ["step", "round", "phase", "active", "pending_brace", "undo_depth"]:
			info[key] = summary.get(key)
		info["saved_at"] = _body.get("saved_at", 0)
		info["meta"] = (_body.get("meta", {}) as Dictionary).duplicate(true)
		info["ai_level"] = (_body["ai"] as Dictionary).get("level", "")
		info["ai_seed"] = (_body["ai"] as Dictionary).get("seed", 0)
		info["tunables_hash"] = _body.get("tunables_hash", "")
	return info


## The saved match, replayed: {state, meta}. {} when there is none or it can't be resumed
## (then status() says why and the bad file was backed up).
func resume() -> Dictionary:
	_probe()
	if _status != MatchSaveCodec.OK or _restored == null:
		return {}
	var meta: Dictionary = (_body.get("meta", {}) as Dictionary).duplicate(true)
	var state: MatchState = _restored
	_restored = null
	_probed = false  # a second resume() replays the file again
	_last_meta = meta.duplicate(true)
	return {"state": state, "meta": meta}


func status() -> StringName:
	return _status


func status_text() -> String:
	return MatchSaveCodec.status_text(_status)


func last_error() -> String:
	return _error


## Re-reads the file on the next query (tests; or after another tab wrote it).
func refresh() -> void:
	_probed = false


# --- Internals --------------------------------------------------------------------------

func _probe() -> void:
	if _probed:
		return
	_probed = true
	_body = {}
	_restored = null
	var p: String = path()
	# A crash between writing the temp file and the rename leaves only the temp file: use it
	# when it is complete (the checksum decides).
	if not FileAccess.file_exists(p) and FileAccess.file_exists(p + ".tmp"):
		var tmp_read: Dictionary = SaveFile.read_text(p + ".tmp")
		if MatchSaveCodec.decode(String(tmp_read["text"]))["status"] == MatchSaveCodec.OK:
			DirAccess.rename_absolute(p + ".tmp", p)
		else:
			SaveFile.remove(p + ".tmp")
	var read: Dictionary = SaveFile.read_text(p)
	var decoded: Dictionary = {}
	match read["status"]:
		SaveFile.MISSING:
			decoded = {"status": MatchSaveCodec.NONE, "error": "", "seq": -1}
		SaveFile.CORRUPT:
			decoded = {"status": MatchSaveCodec.CORRUPT, "error": String(read["error"]), "seq": -1}
		_:
			decoded = MatchSaveCodec.decode(String(read["text"]))
	# Web: the localStorage mirror wins when it is newer (the IndexedDB sync had not finished).
	var mirror_text: String = _mirror_read()
	if mirror_text != "":
		var from_mirror: Dictionary = MatchSaveCodec.decode(mirror_text)
		if from_mirror["status"] == MatchSaveCodec.OK and (decoded["status"] != MatchSaveCodec.OK
				or int(from_mirror["seq"]) > int(decoded["seq"])):
			if decoded["status"] != MatchSaveCodec.NONE and decoded["status"] != MatchSaveCodec.OK:
				SaveFile.copy_file(p, "%s.%s.bak" % [p, decoded["status"]])
			SaveFile.write_text(p, mirror_text)
			decoded = from_mirror
		elif from_mirror["status"] != MatchSaveCodec.OK:
			_mirror_write("")
	_seq = maxi(_seq, int(decoded.get("seq", -1)))
	if decoded["status"] == MatchSaveCodec.NONE:
		_status = MatchSaveCodec.NONE
		_error = ""
		return
	if decoded["status"] != MatchSaveCodec.OK:
		_reject(decoded["status"], String(decoded["error"]))
		return
	var restored: Dictionary = MatchSaveCodec.restore(decoded["body"], _content())
	if restored["status"] != MatchSaveCodec.OK:
		_reject(restored["status"], String(restored["error"]))
		return
	_status = MatchSaveCodec.OK
	_error = ""
	_body = decoded["body"]
	_restored = restored["state"]


## Only the newest seq on disk (so the first save of a session numbers after it), no replay.
func _probe_seq_only() -> void:
	for text: String in [String(SaveFile.read_text(path())["text"]), _mirror_read()]:
		var nl: int = text.find("\n")
		var header: String = text.substr(0, nl) if nl >= 0 else ""
		var at: int = header.find(" seq=")
		if at >= 0:
			_seq = maxi(_seq, header.substr(at + 5).get_slice(" ", 0).to_int())


func _mirror_on() -> bool:
	return mirror_to_local_storage and OS.has_feature("web")


func _mirror_key() -> String:
	return "cardzone:" + path()


## Writes (or with "" removes) the localStorage copy. Never throws into the game.
func _mirror_write(text: String) -> void:
	if not _mirror_on():
		return
	var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
	if storage == null:
		return
	if text == "":
		storage.removeItem(_mirror_key())
	else:
		storage.setItem(_mirror_key(), text)


func _mirror_read() -> String:
	if not _mirror_on():
		return ""
	var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
	if storage == null:
		return ""
	var v: Variant = storage.getItem(_mirror_key())
	return String(v) if v is String else ""


## Keeps a copy of the bad file, removes it and records why.
func _reject(why: StringName, error: String) -> void:
	var p: String = path()
	_backup = "%s.%s.bak" % [p, why]
	if not SaveFile.copy_file(p, _backup):
		_backup = ""
	SaveFile.remove(p)
	_mirror_write("")
	_status = why
	_error = error
	push_warning("MatchStore: saved match not resumable (%s: %s); %s. Offer a new match." % [
			why, error, ("backed up to " + _backup) if _backup != "" else "no backup"])


func _content() -> RulesData:
	if content != null:
		return content
	var db: Node = get_node_or_null("/root/CardDB") if is_inside_tree() else null
	if db == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		db = loop.root.get_node_or_null("CardDB") if loop != null else null
	if db == null or not db.call("is_valid"):
		return null
	return RulesData.from_card_db(db)
