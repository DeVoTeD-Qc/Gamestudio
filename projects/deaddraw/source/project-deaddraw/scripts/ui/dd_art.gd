# dd_art.gd
# Purpose: dd-feel art hook. Reads the card-art manifest (res://assets/art/manifest.json, made by
#   the Sr Game Artist) and hands out textures for card tiles and zoom views. Anything without a
#   manifest entry (or whose file is missing) gets null, and the tile keeps the plain look.
#   The manifest may be any of these shapes (they can be mixed); every key is matched lowercase:
#     {"Z9": "cards/zombie_9.svg", "rosa": "cards/rosa.svg"}                      flat id -> file
#     {"cards": {"zombie_9": "..."}, "survivors": {"rosa": {"file": "..."}}}     grouped
#     {"cards": [{"id": "Z9", "file": "..."}, {"name": "rosa", "path": "..."}]}  lists
#   A grouped key is also registered as "<group>_<key>" and "<group>:<key>" with the group name
#   singular ("survivors" -> "survivor_rosa"). Entry values: a path string, or a dictionary with
#   file / path / svg / src / image. Paths: res:// or user:// as given, else relative to the
#   manifest's folder (then its cards/ subfolder).
#   Lookup keys tried, most specific first (see the *_keys functions): street cards "Z9",
#   "zombie_9", "zombie9", then "zombie" / "z"; finale cards their name slug, "finale_<trait>",
#   then the district; survivors "<id>" / "survivor_<id>"; perks "<id>" / "perk_<id>"; districts
#   "<id>" / "district_<id>"; the card back "card_back" / "back".
# Dependencies: DDCard.
# Author: Game Feel Engineer Agent (dd-feel)
extends RefCounted

const DEFAULT_MANIFEST: String = "res://assets/art/manifest.json"
const KIND_WORD: Dictionary = {"Z": "zombie", "W": "weapon", "M": "medkit", "B": "barricade"}

static var _path: String = DEFAULT_MANIFEST
static var _entries: Dictionary = {}   # lowercase key -> resolved file path
static var _loaded: bool = false
static var _tex: Dictionary = {}       # file path -> Texture2D (or null)


## Points the hook at another manifest (tests) and forgets what was loaded.
static func use_manifest(path: String) -> void:
	_path = path
	reset()


static func reset() -> void:
	_entries = {}
	_loaded = false
	_tex = {}


## Number of manifest entries found (0 = no manifest / empty).
static func entry_count() -> int:
	_ensure()
	return _entries.size()


## The file registered for a key ("" if none).
static func file_for(key: String) -> String:
	_ensure()
	return str(_entries.get(key.to_lower(), ""))


## The texture of the first key that has art, or null (the caller keeps its fallback look).
static func texture_for(keys: Array) -> Texture2D:
	_ensure()
	if _entries.is_empty():
		return null
	for k: Variant in keys:
		var f: String = str(_entries.get(str(k).to_lower(), ""))
		if f == "":
			continue
		var t: Texture2D = _texture(f)
		if t != null:
			return t
	return null


# ---------------------------------------------------------------- lookup keys
static func card_keys(c: DDCard, district_id: String = "") -> Array:
	var w: String = str(KIND_WORD.get(c.kind, c.kind))
	var out: Array = []
	if c.is_finale():
		if c.finale_name != "":
			out.append(slug(c.finale_name))
			out.append("finale_" + slug(c.finale_name))
		out.append("finale_" + c.boss_trait)
		if district_id != "":
			out.append("finale_" + district_id)
			out.append(district_id + "_finale")
		out.append("finale")
	out.append_array([c.code(), "%s_%d" % [w, c.value], "%s%d" % [w, c.value], w, c.kind])
	return out


static func survivor_keys(id: String) -> Array:
	return [id, "survivor_" + id, "survivor:" + id]


static func perk_keys(id: String) -> Array:
	return [id, "perk_" + id, "perk:" + id, "perk"]


static func district_keys(d: Dictionary) -> Array:
	var id: String = str(d.get("id", ""))
	var fname: String = slug(str((d.get("finale", {}) as Dictionary).get("name", "")))
	var out: Array = ["finale_" + id, id + "_finale", "district_" + id, id]
	if fname != "":
		out.insert(0, fname)
		out.insert(1, "finale_" + fname)
	return out


static func back_keys() -> Array:
	return ["card_back", "back", "cardback", "deck"]


## "The Groundskeeper" -> "the_groundskeeper"; also tries without a leading "the_".
static func slug(s: String) -> String:
	var out: String = ""
	for ch: String in s.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


# ---------------------------------------------------------------- loading
static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_entries = {}
	if not FileAccess.file_exists(_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if parsed == null:
		push_warning("DDArt: %s is not valid JSON" % _path)
		return
	_walk(parsed, "")


static func _walk(v: Variant, group: String) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			var key: String = str(k)
			var val: Variant = v[k]
			var file: String = _file_of(val)
			if file != "":
				_register(key, group, file)
				var alt: Variant = (val as Dictionary).get("id", (val as Dictionary).get("name", null)) if val is Dictionary else null
				if alt != null:
					_register(str(alt), group, file)
			elif val is Dictionary or val is Array:
				_walk(val, key)
	elif v is Array:
		for e: Variant in v:
			if e is Dictionary:
				var file2: String = _file_of(e)
				if file2 == "":
					_walk(e, group)
					continue
				for idk: String in ["id", "key", "code", "name", "card"]:
					if (e as Dictionary).has(idk):
						_register(str(e[idk]), group, file2)


static func _file_of(val: Variant) -> String:
	if val is String:
		var s: String = val
		return s if s.get_extension().to_lower() in ["svg", "png", "webp", "jpg", "jpeg"] else ""
	if val is Dictionary:
		for fk: String in ["file", "path", "svg", "src", "image", "png"]:
			if (val as Dictionary).has(fk) and (val as Dictionary)[fk] is String:
				return _file_of(val[fk])
	return ""


static func _register(key: String, group: String, file: String) -> void:
	var path: String = _resolve(file)
	var k: String = key.to_lower()
	_put(k, path)
	if group != "" and not group.to_lower() in ["cards", "entries", "art", "assets", "files", "items"]:
		var g: String = group.to_lower()
		var single: String = g.trim_suffix("s") if g.ends_with("s") else g
		for gg: String in [g, single]:
			_put(gg + "_" + k, path)
			_put(gg + ":" + k, path)


static func _put(k: String, path: String) -> void:
	if not _entries.has(k):
		_entries[k] = path


static func _resolve(file: String) -> String:
	if file.begins_with("res://") or file.begins_with("user://"):
		return file
	var base: String = _path.get_base_dir()
	var a: String = base.path_join(file)
	if _exists(a):
		return a
	var b: String = base.path_join("cards").path_join(file)
	if _exists(b):
		return b
	return a


static func _exists(p: String) -> bool:
	return ResourceLoader.exists(p) or FileAccess.file_exists(p)


## Imported texture when there is one, else rasterise the raw SVG / image file. Cached.
static func _texture(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null and FileAccess.file_exists(path):
		var img: Image = Image.new()
		var err: int = ERR_FILE_UNRECOGNIZED
		if path.get_extension().to_lower() == "svg":
			var src: String = FileAccess.get_file_as_string(path)
			err = img.load_svg_from_string(src, 1.0)
			# rasterise at roughly 512 px on the long side: sharp on phones, light on memory
			if err == OK and not img.is_empty():
				var longest: float = float(maxi(img.get_width(), img.get_height()))
				if longest < 360.0 or longest > 1024.0:
					err = img.load_svg_from_string(src, clampf(512.0 / longest, 0.1, 8.0))
		else:
			err = img.load(path)
		if err == OK and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex[path] = t
	return t
