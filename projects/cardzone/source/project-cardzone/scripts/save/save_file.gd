# save_file.gd
# Adapted from CallingCard scripts/save/save_file.gd (cc09): same atomic-write pattern, but text
#   instead of JSON, because a CardZone match save is Godot variant text (ints and StringNames
#   survive; JSON would turn card instance ids into floats and dictionary keys into strings).
# Purpose: Small file helpers for saves under user://. On the web, user:// is backed by
#   IndexedDB, so a save survives a browser reload. Writes go to "<path>.tmp" first and are then
#   moved over the real file, so a crash mid-write leaves the previous save intact.
#   read_text() never throws: it reports MISSING, CORRUPT or OK and the caller picks a fallback.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name SaveFile
extends RefCounted

const OK_STATUS: StringName = &"ok"
const MISSING: StringName = &"missing"
const CORRUPT: StringName = &"corrupt"


## {status: OK_STATUS | MISSING | CORRUPT, text: String ("" unless ok), error: String}.
static func read_text(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": MISSING, "text": "", "error": ""}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"status": CORRUPT, "text": "", "error": "can't open (%s)" % error_string(FileAccess.get_open_error())}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var text: String = bytes.get_string_from_utf8()
	if text.is_empty() and not bytes.is_empty():
		return {"status": CORRUPT, "text": "", "error": "not UTF-8 text"}
	return {"status": OK_STATUS, "text": text, "error": ""}


## Writes text via a temp file, then renames it over `path`. Returns true on success.
static func write_text(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveFile: can't write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		push_error("SaveFile: write to %s failed (%s)" % [tmp, error_string(write_err)])
		remove(tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("SaveFile: can't move %s to %s (%s)" % [tmp, path, error_string(err)])
		return false
	return true


## Copies a file (e.g. a bad save, kept for bug reports). Returns true on success.
static func copy_file(from: String, to: String) -> bool:
	return FileAccess.file_exists(from) and DirAccess.copy_absolute(from, to) == OK


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
