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
#   then the district; survivors "<id>" / "survivor_<id>"; perks "<id>" / "perk_<id>"; district
#   banners "district_<id>" / "<id>"; a district's finale card finale_keys(); the card back
#   "card_back" / "back". Also the card's display name (the manifest's by_name group).
#   v2 (art manifest version 2): weapons by sim id (weapons_<wid>), Carrier zombies
#   (zombie_carrier_<n>), ammo (ammo_<n>), machines, Wall Racks, rooms, Jawbreakers, drops, badges and
#   icons have their own *_keys functions; anything missing falls back to the plain tile.
#   v3 (manifest v3): Patches (patch_keys), gun-rule icons (rule_keys), deck backs
#   (deck_back_keys), Patient Zero phases, v3 machine kinds (bench / patch / wall).
#   v5 (dd-art-fit): the manifest's "focus" group, {file: {"box": [x0, y0, x1, y1], "focus": [x, y]}}
#   in 0..1 of the image, says where a painting's subject is; cover_rect() then crops around it and
#   never cuts the box (dd_art_rect.gd).
# Dependencies: DDCard, DDText.
# Author: Game Feel Engineer Agent (dd-feel)
extends RefCounted

const DEFAULT_MANIFEST: String = "res://assets/art/manifest.json"
const KIND_WORD: Dictionary = {"Z": "zombie", "W": "weapon", "M": "medkit", "C": "barricade", "B": "barricade", "A": "ammo"}
## v3 machine kinds -> the manifest's machine ids.
const MACHINE_ART: Dictionary = {"bench": "retrofit_bench", "patch": "patch_press", "wall": "wall_rack"}
const ArtRect: GDScript = preload("res://scripts/ui/dd_art_rect.gd")

static var _path: String = DEFAULT_MANIFEST
static var _entries: Dictionary = {}   # lowercase key -> resolved file path
static var _loaded: bool = false
static var _tex: Dictionary = {}       # file path -> Texture2D (or null)
static var _focus: Dictionary = {}     # file path -> {"box": Rect2, "focus": Vector2}


## Points the hook at another manifest (tests) and forgets what was loaded.
static func use_manifest(path: String) -> void:
	_path = path
	reset()


static func reset() -> void:
	_entries = {}
	_loaded = false
	_tex = {}
	_focus = {}


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


## dd-art-fit: where a painting's subject is ({} when the manifest says nothing about it).
static func focus_for(tex: Texture2D) -> Dictionary:
	_ensure()
	if tex == null or _focus.is_empty():
		return {}
	if tex.resource_path != "" and _focus.has(tex.resource_path):
		return _focus[tex.resource_path]
	for p: Variant in _tex.keys():
		if _tex[p] == tex:
			return _focus.get(p, {})
	return {}


## dd-art-fit: a full-cover art rect. Paintings with a focus entry crop around their subject and
## never cut its box (dd_art_rect.gd); anything else is a plain cover TextureRect, as before.
static func cover_rect(tex: Texture2D) -> TextureRect:
	var fz: Dictionary = focus_for(tex)
	if fz.is_empty():
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return tr
	var ar: TextureRect = ArtRect.new()
	ar.set("art", tex)
	ar.set("box", fz.get("box", Rect2()))
	ar.set("focus", fz.get("focus", Vector2(0.5, 0.5)))
	return ar


# ---------------------------------------------------------------- lookup keys
static func card_keys(c: DDCard, district_id: String = "") -> Array:
	var w: String = str(KIND_WORD.get(c.kind, c.kind))
	var out: Array = []
	if c.is_boss():
		if c.phase > 0:
			out.append_array(["boss_phases_%s_%d" % [slug(c.boss_name), c.phase], "boss_phases_%s_v%d" % [slug(c.boss_name), c.value]])
		if c.boss_name != "":
			out.append(slug(c.boss_name))
			out.append("finale_" + slug(c.boss_name))
		if district_id != "":
			out.append("finales_" + district_id)
			out.append("finale_" + district_id)
		out.append("finale_" + c.boss_trait)
	if c.kind == DDCard.WEAPON:
		return weapon_keys(c.wid, DDText.card_name(c))
	out.append_array([c.code(), "%s_%d" % [w, c.value], "%s%d" % [w, c.value]])
	if not c.is_boss():
		out.append(DDText.card_name(c).to_lower())
	out.append_array([w, c.kind])
	return out


static func weapon_keys(wid: String, display_name: String = "") -> Array:
	var out: Array = ["weapons_" + wid, "weapons:" + wid]
	if display_name != "":
		out.append_array(["weapon_" + slug(display_name), display_name.to_lower()])
	return out


static func machine_keys(m: Dictionary) -> Array:
	var kind: String = str(m.get("kind", ""))
	var art: String = str(MACHINE_ART.get(kind, kind))
	var out: Array = []
	if (kind == "wall" or kind == "wallrack") and str(m.get("wid", "")) != "":
		out.append_array(["wall_racks_" + str(m["wid"]), "wall_rack_" + str(m["wid"])])
	out.append_array(["machines_" + art, "machines_" + kind, "machine_" + art, DDText.machine_name(kind).to_lower()])
	return out


## v3: a Patch (the v3 group first: plain "thick_jacket" still points at the v2 perk art).
static func patch_keys(id: String) -> Array:
	return ["patches_" + id, "patch_" + id, "patch:" + id, (DDText.patch_name(id) + " Patch").to_lower()]


## v3: the rule icon on a gun card ("down", "bent" for Loose Grip).
static func rule_keys(rule: String) -> Array:
	return ["rules_" + rule, "rule_" + rule]


## v3: the back of a wave deck / room deck / the draw pile.
static func deck_back_keys(kind: String) -> Array:
	return ["deck_backs_" + kind, "deck_backs_%s_deck" % kind, "deck_back_" + kind] + back_keys()


static func room_keys(district_id: String, room_name: String) -> Array:
	var r: String = slug(room_name)
	return ["rooms_%s_%s" % [district_id, r], "room_%s_%s" % [district_id, r], "rooms_" + r, room_name.to_lower()]


static func jawbreaker_keys(id: String) -> Array:
	return ["jawbreakers_" + id, "jawbreaker_" + id]


static func drop_keys(id: String) -> Array:
	return ["drops_" + id, "drop_" + id]


static func badge_keys(id: String) -> Array:
	return ["badges_" + id, "badge_" + id]


## dd-mods-import: a Gun Mod's painted badge (art pack 3). small = the 64 px copy for the 24 px gun-tile
## chip and the 48 px safehouse card (falls back to the 256 px badge). [] -> null: the text chip stays.
static func mod_keys(id: String, small: bool = false) -> Array:
	var big: Array = ["mods_" + id, "mod:" + id]
	return (["mods_small_" + id] + big) if small else big


## A Gun Mod badge as a fixed-size TextureRect (null when the badge is not painted).
static func mod_badge(id: String, px: float) -> TextureRect:
	var t: Texture2D = texture_for(mod_keys(id, px <= 72.0))
	if t == null:
		return null
	var tr: TextureRect = TextureRect.new()
	tr.name = "ModBadge"
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func icon_keys(id: String) -> Array:
	return ["icons_" + id, "icon_" + id]


static func survivor_keys(id: String) -> Array:
	return [id, "survivor_" + id, "survivor:" + id]


static func perk_keys(id: String) -> Array:
	return [id, "perk_" + id, "perk:" + id, "perk"]


## The district banner (map node background). Banner first: a bare district id resolves to it
## because the manifest lists "districts" before "finales".
static func district_keys(d: Dictionary) -> Array:
	var id: String = str(d.get("id", ""))
	return ["district_" + id, "districts_" + id, id]


## The district's Finale card art.
static func finale_keys(d: Dictionary) -> Array:
	var id: String = str(d.get("id", ""))
	var fname: String = slug(str((d.get("boss", d.get("finale", {})) as Dictionary).get("name", "")))
	var out: Array = []
	if fname != "":
		out.append_array([fname, "finale_" + fname])
	out.append_array(["finales_" + id, "finale_" + id, id + "_finale"])
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
	if parsed is Dictionary and (parsed as Dictionary).get("focus", null) is Dictionary:
		var fz: Dictionary = parsed["focus"]
		for f: Variant in fz.keys():
			var e: Variant = fz[f]
			if not (e is Dictionary):
				continue
			var bx: Array = (e as Dictionary).get("box", [])
			var out: Dictionary = {}
			if bx.size() == 4:
				out["box"] = Rect2(Vector2(float(bx[0]), float(bx[1])), Vector2(float(bx[2]) - float(bx[0]), float(bx[3]) - float(bx[1])))
				out["focus"] = (out["box"] as Rect2).get_center()
			var fc: Array = (e as Dictionary).get("focus", [])
			if fc.size() == 2:
				out["focus"] = Vector2(float(fc[0]), float(fc[1]))
			_focus[_resolve(str(f))] = out
		parsed = (parsed as Dictionary).duplicate()
		(parsed as Dictionary).erase("focus")
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
