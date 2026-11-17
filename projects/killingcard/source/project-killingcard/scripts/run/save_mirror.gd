# save_mirror.gd
# Purpose: kc-ios-save. A synchronous second copy of every save file (run, settings / profile,
#   tutorial) so progress survives a crash-reload on the web.
#   Why: on the web build user:// is an in-memory file system that Godot copies to IndexedDB with an
#   async FS.syncfs() on a later frame. When iOS kills the tab for memory (Safari then reloads it),
#   or the tab is closed right after a save, the last writes may never reach IndexedDB; and where
#   IndexedDB is unavailable (some cross-origin iframes, private mode) user:// does not persist at
#   all. So every save is ALSO written, in the same frame, to window.localStorage (try/catch: a
#   blocked or full storage just means file only). Reads take the newer of the file and the mirror by
#   a "saved_at" stamp written into both copies; a deleted save leaves a "cleared" tombstone in the
#   mirror so a stale IndexedDB copy can't come back.
#   Tests (and native builds) have no mirror unless a test sets SaveMirror.store = MemoryStore.new().
# Usage:
#   SaveMirror.stamp()                     # the saved_at value for a new save (monotonic)
#   SaveMirror.put(path, text) / SaveMirror.get_text(path)
#   SaveMirror.save_cfg(cfg, path) / SaveMirror.load_cfg(cfg, path)   # ConfigFile saves
# Dependencies: JavaScriptBridge (web only).
# Author: Technical Artist Agent (kc-ios-save)
class_name SaveMirror
extends RefCounted

const KEY_PREFIX: String = "killingcard:"
const META_SECTION: String = "save_meta"
const STAMP_KEY: String = "saved_at"

## The mirror backend: anything with get_item(key) -> String and set_item(key, text). null = file only.
## Set on first use: WebStorage on a web build, else null.
static var store: RefCounted = null
static var _store_ready: bool = false
static var _last_stamp: float = 0.0


## window.localStorage through JavaScriptBridge (synchronous; survives a reload or a killed tab).
class WebStorage:
	extends RefCounted

	func get_item(key: String) -> String:
		var v: Variant = JavaScriptBridge.eval("(function(){try{return window.localStorage.getItem(%s)||''}catch(e){return ''}})()" % JSON.stringify(key), true)
		return v if v is String else ""

	func set_item(key: String, text: String) -> void:
		JavaScriptBridge.eval("(function(){try{window.localStorage.setItem(%s,%s)}catch(e){}})()" % [JSON.stringify(key), JSON.stringify(text)], true)


## In-memory backend for tests (stands in for localStorage).
class MemoryStore:
	extends RefCounted
	var items: Dictionary = {}

	func get_item(key: String) -> String:
		return str(items.get(key, ""))

	func set_item(key: String, text: String) -> void:
		items[key] = text


static func backend() -> RefCounted:
	if not _store_ready:
		_store_ready = true
		if store == null and OS.has_feature("web"):
			store = WebStorage.new()
	return store


## Tests: use `s` as the mirror (null = none).
static func use_store(s: RefCounted) -> void:
	store = s
	_store_ready = true


static func key_for(path: String) -> String:
	return KEY_PREFIX + path


## A saved_at stamp (unix seconds with ms), strictly increasing within a session so two saves in the
## same millisecond still order.
static func stamp() -> float:
	var t: float = Time.get_unix_time_from_system()
	if t <= _last_stamp:
		t = _last_stamp + 0.001
	_last_stamp = t
	return t


static func put(path: String, text: String) -> void:
	var s: RefCounted = backend()
	if s != null:
		s.set_item(key_for(path), text)


## The mirrored text for path ("" when none).
static func get_text(path: String) -> String:
	var s: RefCounted = backend()
	return s.get_item(key_for(path)) if s != null else ""


## Writes a "cleared" tombstone (newer than any stale copy) for path.
static func put_tombstone(path: String) -> void:
	if backend() != null:
		put(path, JSON.stringify({"cleared": true, STAMP_KEY: stamp()}))


static func is_tombstone(text: String) -> bool:
	var p: Variant = parse_json(text)
	return p is Dictionary and bool((p as Dictionary).get("cleared", false))


## The parsed JSON of text, or null (quietly: no error printed for bad or empty text).
static func parse_json(text: String) -> Variant:
	if text == "" or not text.strip_edges().begins_with("{"):
		return null
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## Saves a ConfigFile to path and its mirror (stamped). Returns the file's Error; when the file
## fails but the mirror took it, the save still survives a reload.
static func save_cfg(cfg: ConfigFile, path: String) -> Error:
	cfg.set_value(META_SECTION, STAMP_KEY, stamp())
	put(path, cfg.encode_to_text())
	return cfg.save(path)


## Loads the newer of path and its mirror into cfg. OK when either was read; a tombstone or nothing
## at all is ERR_FILE_NOT_FOUND. An unreadable copy is skipped, never deleted.
static func load_cfg(cfg: ConfigFile, path: String) -> Error:
	var from_file := ConfigFile.new()
	var file_ok: bool = FileAccess.file_exists(path) and from_file.load(path) == OK
	var text: String = get_text(path)
	var from_mirror := ConfigFile.new()
	var mirror_ok: bool = text != "" and not is_tombstone(text) and from_mirror.parse(text) == OK
	var best: ConfigFile = null
	if file_ok and mirror_ok:
		best = from_mirror if _cfg_stamp(from_mirror) >= _cfg_stamp(from_file) else from_file
	elif file_ok:
		best = from_file
		if is_tombstone(text) and _text_stamp(text) > _cfg_stamp(from_file):
			best = null
	elif mirror_ok:
		best = from_mirror
	if best == null:
		return ERR_FILE_NOT_FOUND
	cfg.clear()
	for section: String in best.get_sections():
		for key: String in best.get_section_keys(section):
			cfg.set_value(section, key, best.get_value(section, key))
	return OK


static func _cfg_stamp(cfg: ConfigFile) -> float:
	return float(cfg.get_value(META_SECTION, STAMP_KEY, 0.0))


## saved_at of a JSON text (0 when it has none or does not parse).
static func _text_stamp(text: String) -> float:
	var p: Variant = parse_json(text)
	return float((p as Dictionary).get(STAMP_KEY, 0.0)) if p is Dictionary else 0.0
