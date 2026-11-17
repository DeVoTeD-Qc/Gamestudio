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
#   dd-ios-save (iPhone / iPad: the tab is killed for memory and reloaded, and the run was gone): in a
#   cross-origin iframe (itch.io, claude.ai) Safari keeps the game's storage partitioned and only for
#   the browser session, and any one store can be missing or refuse writes. So every save goes to
#   every store there is: the user:// file, window.localStorage AND window.sessionStorage (it survives
#   a reload of the same tab, which is what Safari does after a crash), and each write is read back
#   to check it landed (last_write says which did). Reading takes the newest copy that actually loads:
#   a copy that is corrupt, unreadable or not resumable is skipped (an older good copy is used), never
#   treated as "cleared", and nothing is ever deleted because it could not be read.
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
## dd-ios-save: which stores took the last save: {"file": bool, "mirror": bool} (plus the WebStorage
## detail "local" / "session" on the Web). Shown in window.ddState.store for the browser tests.
var last_write: Dictionary = {}


## window.localStorage and window.sessionStorage through JavaScriptBridge: written in the same frame,
## so they survive a reload or a closed tab even when the IndexedDB sync of user:// has not finished.
## Either may be missing or throw (sandboxed / partitioned third-party iframe, quota): each is tried on
## its own and checked by reading it back. The text goes over as a property of window (no script with
## the whole save inside it is compiled for every write).
class WebStorage:
	extends RefCounted
	## Which stores took the last write: {"local": bool, "session": bool}.
	var last: Dictionary = {}
	var _win: JavaScriptObject = null

	func _window() -> JavaScriptObject:
		if _win == null:
			_win = JavaScriptBridge.get_interface("window")
		return _win

	## Every copy there is (localStorage first, then sessionStorage); "" for a store without one.
	func get_items(key: String) -> Array[String]:
		var out: Array[String] = []
		for store: String in ["localStorage", "sessionStorage"]:
			var v: Variant = JavaScriptBridge.eval("(function(){try{return window.%s.getItem(%s)||''}catch(e){return ''}})()" % [store, JSON.stringify(key)], true)
			out.append(v if v is String else "")
		return out

	## The newest copy (by saved_at), "" when there is none.
	func get_item(key: String) -> String:
		return DDRunSave.newest_text(get_items(key))

	## Writes both stores; true when at least one of them reads the text back.
	func set_item(key: String, text: String) -> bool:
		var w: JavaScriptObject = _window()
		var r: Variant = ""
		if w != null:
			w.set("__ddSaveKey", key)
			w.set("__ddSaveText", text)
			r = JavaScriptBridge.eval("(function(){var k=window.__ddSaveKey,t=window.__ddSaveText,r='';" \
				+ "try{window.localStorage.setItem(k,t);if(window.localStorage.getItem(k)===t)r+='L'}catch(e){}" \
				+ "try{window.sessionStorage.setItem(k,t);if(window.sessionStorage.getItem(k)===t)r+='S'}catch(e){}" \
				+ "window.__ddSaveText=null;return r})()", true)
		var flags: String = r if r is String else ""
		last = {"local": flags.contains("L"), "session": flags.contains("S")}
		return flags != ""


## In-memory mirror for tests (stands in for localStorage).
class MemoryMirror:
	extends RefCounted
	var items: Dictionary = {}
	## Tests: false makes every write fail (a store that refuses writes, like a blocked localStorage).
	var writable: bool = true

	func get_items(key: String) -> Array[String]:
		return [str(items.get(key, ""))]

	func get_item(key: String) -> String:
		return str(items.get(key, ""))

	func set_item(key: String, text: String) -> bool:
		if not writable:
			return false
		items[key] = text
		return true


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
	var text: String = JSON.stringify({"version": VERSION, "screen": screen, "saved_at": _now(), "run": run.to_dict()})
	return _write_all(text)


## Writes the text to the mirror (first: it is durable the moment this returns; the Web file waits for
## an IndexedDB sync) and to the file, and reads each back. True when at least one store has it.
func _write_all(text: String) -> bool:
	var ok_m: bool = false
	if mirror != null:
		ok_m = bool(mirror.set_item(_mirror_key(), text))
	var ok_f: bool = false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()   # on the Web this marks user:// for the engine's next IndexedDB sync
		ok_f = FileAccess.get_file_as_string(path) == text
	last_write = {"file": ok_f, "mirror": ok_m}
	if mirror != null and mirror.get("last") is Dictionary:
		last_write.merge(mirror.get("last"))
	if not ok_f and not ok_m and not _warned:
		_warned = true
		push_warning("DDRunSave: no store took the save (%s)" % path)
	return ok_f or ok_m


var _warned: bool = false
var _last_at: float = 0.0


## saved_at: wall-clock seconds, always moving forward (two saves in the same instant, or a clock that
## steps back, still order newest last).
func _now() -> float:
	_last_at = maxf(Time.get_unix_time_from_system(), _last_at + 0.001)
	return _last_at


## Every copy there is, parsed (file first, then the mirror's), newest first. Unparseable copies are left out.
func _copies() -> Array[Dictionary]:
	var texts: Array[String] = []
	if FileAccess.file_exists(path):
		texts.append(FileAccess.get_file_as_string(path))
	if mirror != null:
		if mirror.has_method("get_items"):
			for t: String in mirror.get_items(_mirror_key()):
				texts.append(t)
		else:
			texts.append(str(mirror.get_item(_mirror_key())))
	var out: Array[Dictionary] = []
	for t: String in texts:
		var p: Variant = JSON.parse_string(t) if t != "" else null
		if p is Dictionary:
			out.append(p)
	# newest first; on a tie a tombstone first (a clear in the same instant as the save it ends)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: float = float(a.get("saved_at", 0.0))
		var tb: float = float(b.get("saved_at", 0.0))
		return ta > tb if ta != tb else (bool(a.get("cleared", false)) and not bool(b.get("cleared", false))))
	return out


## The newest of several saved texts (by saved_at); "" when none parses.
static func newest_text(texts: Array) -> String:
	var best: String = ""
	var best_at: float = -1.0
	for t: Variant in texts:
		var p: Variant = JSON.parse_string(str(t)) if str(t) != "" else null
		if p is Dictionary and float((p as Dictionary).get("saved_at", 0.0)) > best_at:
			best_at = float((p as Dictionary).get("saved_at", 0.0))
			best = str(t)
	return best


## The newest saved data (file or mirror, by saved_at); {} when there is none or it was cleared.
func _read() -> Dictionary:
	var c: Array[Dictionary] = _copies()
	if c.is_empty() or bool(c[0].get("cleared", false)):
		return {}
	return c[0]


func exists() -> bool:
	return not _read().is_empty()


## {run: DDRun, screen: String} or {} when there is no usable saved run.
## dd-ios-save: the newest copy that loads; a newer copy that does not (wrong version, broken run data)
## is skipped, a newer "cleared" tombstone means there is no run.
func load_run(bal: DDBalance = null) -> Dictionary:
	for parsed: Dictionary in _copies():
		if bool(parsed.get("cleared", false)):
			return {}
		if int(parsed.get("version", 0)) != VERSION:
			continue
		var d: Variant = parsed.get("run", null)
		if not d is Dictionary:
			continue
		var run: DDRun = DDRun.from_dict(d, bal)
		if run == null or run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON:
			continue
		return {"run": run, "screen": str(parsed.get("screen", "STREET"))}
	return {}


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
	var stone: String = JSON.stringify({"version": VERSION, "cleared": true, "saved_at": _now()})
	if mirror != null:
		var stale: bool = false
		var texts: Array = mirror.get_items(_mirror_key()) if mirror.has_method("get_items") else [mirror.get_item(_mirror_key())]
		for t: Variant in texts:
			stale = stale or (str(t) != "" and not _is_tombstone(str(t)))
		if stale:
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
