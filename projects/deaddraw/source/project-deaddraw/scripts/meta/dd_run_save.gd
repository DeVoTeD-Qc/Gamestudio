# dd_run_save.gd
# Purpose: dd-save. The mid-run save: the whole DDRun (DDRun.to_dict(), RNG state included) plus
#   which screen the player was on, in its own file next to the profile (user://, IndexedDB on the
#   Web). Save version 5 (DeadDraw v4 rules, run data "v": 4). Written after every run event and on
#   screen changes; cleared when the run ends (death / win) or is abandoned. A missing, corrupt or
#   unusable file reads as "no saved run" and never crashes. An older version (save 4 = a v3 run:
#   crowbar melee, points carried between districts; save 3 and older = v2 runs) can't be played
#   under the v4 rules: discard_old() removes it and the title says so once.
#   dd-save-fix: on the Web, user:// is MEMFS mirrored to IndexedDB by an async FS.syncfs() that
#   the engine starts on a later frame (queued behind any sync already running), so a tab closed or
#   reloaded right after a Run could lose it. Every save (and clear) is therefore also written,
#   synchronously, to a mirror (window.localStorage on the Web, same JSON); reads take the newer of
#   the file and the mirror by saved_at, and a clear leaves a "cleared" tombstone so a stale file
#   that IndexedDB still holds can't come back as Continue.
# Dependencies: DDRun, DDBalance, DDText.
# Author: Mechanics Developer Agent
class_name DDRunSave
extends RefCounted

const DEFAULT_PATH: String = "user://deaddraw_run.json"
const VERSION: int = 5

var path: String = DEFAULT_PATH
## Synchronous second copy of the save (null = file only). Web: WebStorage (localStorage). Tests
## pass a MemoryMirror. Anything with get_item(key) -> String and set_item(key, text).
var mirror: RefCounted = null


## window.localStorage through JavaScriptBridge: written in the same frame, survives a reload or a
## closed tab even when the IndexedDB sync of user:// has not finished.
class WebStorage:
	extends RefCounted

	func get_item(key: String) -> String:
		var v: Variant = JavaScriptBridge.eval("(function(){try{return window.localStorage.getItem(%s)||''}catch(e){return ''}})()" % JSON.stringify(key), true)
		return v if v is String else ""

	func set_item(key: String, text: String) -> void:
		JavaScriptBridge.eval("(function(){try{window.localStorage.setItem(%s,%s)}catch(e){}})()" % [JSON.stringify(key), JSON.stringify(text)], true)


## In-memory mirror for tests (stands in for localStorage).
class MemoryMirror:
	extends RefCounted
	var items: Dictionary = {}

	func get_item(key: String) -> String:
		return str(items.get(key, ""))

	func set_item(key: String, text: String) -> void:
		items[key] = text


func _init(save_path: String = DEFAULT_PATH, save_mirror: RefCounted = null) -> void:
	path = save_path
	mirror = save_mirror
	if mirror == null and OS.has_feature("web"):
		mirror = WebStorage.new()


func _mirror_key() -> String:
	return "deaddraw:" + path


## Saves a run in progress. screen: the UI screen to come back to ("STREET", "MAP", "SAFEHOUSE").
## A finished run (dead / won) clears the file instead.
func save(run: DDRun, screen: String = "STREET") -> bool:
	if run == null or run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON:
		clear()
		return false
	var text: String = JSON.stringify({"version": VERSION, "screen": screen, "saved_at": Time.get_unix_time_from_system(), "run": run.to_dict()})
	# the mirror first: it is durable the moment this returns (the Web file waits for an IDB sync)
	if mirror != null:
		mirror.set_item(_mirror_key(), text)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("DDRunSave: cannot write %s" % path)
		return mirror != null
	f.store_string(text)
	f.close()   # on the Web this marks user:// for the engine's next IndexedDB sync
	return true


## The newest saved data (file or mirror, by saved_at); {} when there is none or it was cleared.
func _read() -> Dictionary:
	var best: Dictionary = {}
	if FileAccess.file_exists(path):
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if p is Dictionary:
			best = p
	if mirror != null:
		var t: String = mirror.get_item(_mirror_key())
		if t != "":
			var q: Variant = JSON.parse_string(t)
			if q is Dictionary and (best.is_empty() or float((q as Dictionary).get("saved_at", 0.0)) >= float(best.get("saved_at", 0.0))):
				best = q
	if bool(best.get("cleared", false)):
		return {}
	return best


func exists() -> bool:
	return not _read().is_empty()


## {run: DDRun, screen: String} or {} when there is no usable saved run.
func load_run(bal: DDBalance = null) -> Dictionary:
	var parsed: Dictionary = _read()
	if parsed.is_empty() or int(parsed.get("version", 0)) != VERSION:
		return {}
	var d: Variant = parsed.get("run", null)
	if not d is Dictionary:
		return {}
	var run: DDRun = DDRun.from_dict(d, bal)
	if run == null or run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON:
		return {}
	return {"run": run, "screen": str(parsed.get("screen", "STREET"))}


## One line for the title's Continue button: survivor, district, wave, HP.
func summary(bal: DDBalance = null) -> String:
	var s: Dictionary = load_run(bal)
	if s.is_empty():
		return ""
	var run: DDRun = s["run"]
	var where: String = "safehouse after %s" % str(run.district().get("name", "")) if run.phase == DDRun.Phase.SAFEHOUSE \
		else ("%s, boss" % str(run.district().get("name", "")) if run.boss_street else "%s, wave %d" % [str(run.district().get("name", "")), run.wave_index + 1])
	return "%s - %s - HP %d/%d - %d pts" % [str(run.bal.survivor(run.survivor_id).get("name", run.survivor_id)), where, run.hp, run.max_hp, run.bal.shown(run.points)]


## True when the file holds a run from an older version of the game (not resumable).
func is_old() -> bool:
	var v: int = int(_read().get("version", 0))
	return v > 0 and v < VERSION


## Deletes an older-version run. Returns true when one was discarded.
func discard_old() -> bool:
	if not is_old():
		return false
	clear()
	return true


## Clears the saved run: the file and the mirror hold a "cleared" tombstone (newer than any stale
## copy), so neither is a Continue any more.
## dd-ux-text (playtest: repeated console errors on the death / end screen): the file is no longer
## deleted. On the Web, removing a file while the engine's IndexedDB sync of user:// is running
## made that sync fail ("Failed to save IDB file system"), once per clear. A tombstone is an
## ordinary write, and a run that is already cleared is not written again.
func clear() -> void:
	var stone: String = JSON.stringify({"version": VERSION, "cleared": true, "saved_at": Time.get_unix_time_from_system()})
	if mirror != null and not _is_tombstone(mirror.get_item(_mirror_key())):
		mirror.set_item(_mirror_key(), stone)
	if FileAccess.file_exists(path) and not _is_tombstone(FileAccess.get_file_as_string(path)):
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(stone)
			f.close()


static func _is_tombstone(text: String) -> bool:
	if text == "":
		return false
	var p: Variant = JSON.parse_string(text)
	return p is Dictionary and bool((p as Dictionary).get("cleared", false))
