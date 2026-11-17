# run_save.gd
# Purpose: Reads and writes the run save (JSON, one object, versioned by
#   RunProgress.SAVE_VERSION) so a run survives a browser reload. On the web build
#   user:// is IndexedDB-backed, so a write goes to a temporary file first and then
#   replaces the save, which keeps the old save if the tab closes mid-write.
#   A save that can't be read or doesn't fit the config is moved aside to
#   <path>.corrupt (for bug reports) and the caller starts fresh.
#   kc-ios-save: every write also goes, synchronously, to SaveMirror (window.localStorage on the
#   web) with a "saved_at" stamp in the JSON, because the IndexedDB copy of user:// is written on a
#   later frame and is lost when iOS kills the tab first. read() takes the newest usable copy (file
#   or mirror); a copy that can't be read is skipped (the other one is used) and never deleted;
#   delete() leaves a tombstone in the mirror so a stale file can't come back as Continue.
# Dependencies: RunProgress, RunConfig, SaveMirror.
# Author: Mechanics Developer Agent
class_name RunSave
extends RefCounted

const CORRUPT_SUFFIX: String = ".corrupt"
const TEMP_SUFFIX: String = ".tmp"


## True when a save is there to continue (the newest copy is not a tombstone).
static func exists(path: String) -> bool:
	return not _newest(path).is_empty()


## Writes the run (mirror first: it is durable the moment it returns). Returns OK or the file's
## error (the mirror may still hold the run).
static func write(path: String, run: RunProgress) -> Error:
	var d: Dictionary = run.to_dict()
	d[SaveMirror.STAMP_KEY] = SaveMirror.stamp()
	var text: String = JSON.stringify(d, "\t")
	SaveMirror.put(path, text)
	var tmp: String = path + TEMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		# Fall back to writing in place.
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(text)
		f.close()
		DirAccess.remove_absolute(tmp)
	return OK


## Reads a run. Returns {run: RunProgress or null, error: String, missing: bool, source: "file" |
## "mirror" | ""}. missing = true when there is no save at all (not an error). The newest copy that
## loads wins; when the newest can't be read the older one is used.
## opts go to RunProgress.from_dict ({map: true}: a v1-v6 save continues on a first-run-shaped map).
static func read(path: String, config: RunConfig, opts: Dictionary = {}) -> Dictionary:
	var copies: Array[Dictionary] = _copies(path)
	if copies.is_empty() or bool(copies[0].get("cleared", false)):
		return {"run": null, "error": "", "missing": true, "source": ""}
	var first_error: String = ""
	for c: Dictionary in copies:
		if bool(c.get("cleared", false)):
			break
		var loaded: Dictionary
		if c["data"] == null:
			loaded = {"run": null, "error": c["error"]}
		else:
			loaded = RunProgress.from_dict(config, c["data"], opts)
		if loaded["run"] != null:
			loaded["missing"] = false
			loaded["source"] = c["source"]
			return loaded
		if first_error == "":
			first_error = String(loaded["error"])
	return {"run": null, "error": first_error, "missing": false, "source": ""}


## The copies of a save, newest first: [{source, stamp, data (Dictionary or null), error, cleared}].
## A copy that is not valid JSON sorts as oldest (stamp -1) so a readable one is tried first.
static func _copies(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if FileAccess.file_exists(path):
		out.append(_copy("file", FileAccess.get_file_as_string(path)))
	var mirrored: String = SaveMirror.get_text(path)
	if mirrored != "":
		out.append(_copy("mirror", mirrored))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["stamp"]) > float(b["stamp"]))
	return out


static func _copy(source: String, text: String) -> Dictionary:
	if text.is_empty():
		return {"source": source, "stamp": -1.0, "data": null, "error": "save file is empty or unreadable", "cleared": false}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"source": source, "stamp": -1.0, "data": null, "cleared": false,
				"error": "save is not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()]}
	var d: Variant = json.data
	var st: float = float((d as Dictionary).get(SaveMirror.STAMP_KEY, 0.0)) if d is Dictionary else 0.0
	return {"source": source, "stamp": st, "data": d, "error": "", "cleared": d is Dictionary and bool((d as Dictionary).get("cleared", false))}


## The newest copy unless it is a tombstone ({} when there is no save).
static func _newest(path: String) -> Dictionary:
	var copies: Array[Dictionary] = _copies(path)
	if copies.is_empty() or bool(copies[0].get("cleared", false)):
		return {}
	return copies[0]


## Moves a bad save aside so the next start is clean. Returns the new path.
## The mirror's copy moves aside the same way (to <path>.corrupt in the mirror) and leaves a tombstone.
static func quarantine(path: String) -> String:
	var dest: String = path + CORRUPT_SUFFIX
	var mirrored: String = SaveMirror.get_text(path)
	if mirrored != "" and not SaveMirror.is_tombstone(mirrored):
		SaveMirror.put(dest, mirrored)
		SaveMirror.put_tombstone(path)
	if not FileAccess.file_exists(path):
		return dest if mirrored != "" else ""
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if DirAccess.rename_absolute(path, dest) != OK:
		DirAccess.remove_absolute(path)
		return ""
	return dest


static func delete(path: String) -> void:
	SaveMirror.put_tombstone(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
