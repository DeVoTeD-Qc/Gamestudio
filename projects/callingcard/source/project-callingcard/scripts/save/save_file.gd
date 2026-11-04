# save_file.gd
# Purpose: Small JSON file helpers for saves under user:// (cc09). On the web, user:// is backed
#   by IndexedDB, so a save survives a browser reload. Writes go to "<path>.tmp" first and are
#   then moved over the real file, so a crash mid-write leaves the previous save intact.
#   read_json() never throws: it reports MISSING, CORRUPT or OK and the caller picks a fallback.
#   Also the type-safe readers used when loading JSON (numbers come back as floats).
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name SaveFile
extends RefCounted

const OK_STATUS: StringName = &"ok"
const MISSING: StringName = &"missing"
const CORRUPT: StringName = &"corrupt"


## {status: OK_STATUS | MISSING | CORRUPT, data: Dictionary ({} unless ok), error: String}.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": MISSING, "data": {}, "error": ""}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return {"status": CORRUPT, "data": {}, "error": "can't open (%s)" % error_string(FileAccess.get_open_error())}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"status": CORRUPT, "data": {}, "error": "line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"status": CORRUPT, "data": {}, "error": "top level is not an object"}
	return {"status": OK_STATUS, "data": json.data, "error": ""}


## Writes data as JSON via a temp file. Returns true on success.
static func write_json(path: String, data: Dictionary) -> bool:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveFile: can't write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("SaveFile: can't move %s to %s (%s)" % [tmp, path, error_string(err)])
		return false
	return true


## Copies a file (e.g. a corrupt save, kept for bug reports). Returns true on success.
static func copy_file(from: String, to: String) -> bool:
	return FileAccess.file_exists(from) and DirAccess.copy_absolute(from, to) == OK


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# --- Type-safe readers for parsed JSON -------------------------------------------

## Whole number or fallback (JSON numbers are floats; NaN, fractions and other types -> fallback).
static func to_int(v: Variant, fallback: int = 0) -> int:
	if v is int:
		return v
	if v is float and is_finite(v) and float(int(v)) == v:
		return int(v)
	return fallback


static func to_float(v: Variant, fallback: float = 0.0) -> float:
	if (v is float and is_finite(v)) or v is int:
		return float(v)
	return fallback


static func to_bool(v: Variant, fallback: bool = false) -> bool:
	return v if v is bool else fallback


## Array of distinct non-empty StringNames from an array of strings (other entries dropped).
static func to_id_list(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for e: Variant in v:
			if (e is String or e is StringName) and not String(e).is_empty() and not out.has(StringName(e)):
				out.append(StringName(e))
	return out


static func to_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
