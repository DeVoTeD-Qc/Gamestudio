# run_save.gd
# Purpose: Reads and writes the run save (JSON, one object, versioned by
#   RunProgress.SAVE_VERSION) so a run survives a browser reload. On the web build
#   user:// is IndexedDB-backed, so a write goes to a temporary file first and then
#   replaces the save, which keeps the old save if the tab closes mid-write.
#   A save that can't be read or doesn't fit the config is moved aside to
#   <path>.corrupt (for bug reports) and the caller starts fresh.
# Dependencies: RunProgress, RunConfig.
# Author: Mechanics Developer Agent
class_name RunSave
extends RefCounted

const CORRUPT_SUFFIX: String = ".corrupt"
const TEMP_SUFFIX: String = ".tmp"


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Writes the run. Returns OK or the error.
static func write(path: String, run: RunProgress) -> Error:
	var text: String = JSON.stringify(run.to_dict(), "\t")
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


## Reads a run. Returns {run: RunProgress or null, error: String, missing: bool}.
## missing = true when there is no save at all (not an error).
## opts go to RunProgress.from_dict ({map: true}: a v1-v6 save continues on a first-run-shaped map).
static func read(path: String, config: RunConfig, opts: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"run": null, "error": "", "missing": true}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"run": null, "error": "save file is empty or unreadable", "missing": false}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"run": null, "error": "save is not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()], "missing": false}
	var loaded: Dictionary = RunProgress.from_dict(config, json.data, opts)
	loaded["missing"] = false
	return loaded


## Moves a bad save aside so the next start is clean. Returns the new path.
static func quarantine(path: String) -> String:
	var dest: String = path + CORRUPT_SUFFIX
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if DirAccess.rename_absolute(path, dest) != OK:
		DirAccess.remove_absolute(path)
		return ""
	return dest


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
