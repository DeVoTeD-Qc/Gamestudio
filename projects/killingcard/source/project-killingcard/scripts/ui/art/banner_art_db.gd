# banner_art_db.gd
# Purpose: The BannerArt data path (kc-board). Turns a card art id (a card id, a killstreak id, the
#   Operator's art id) into a BannerArt and its two crops:
#     BannerArtDB.banner_texture(&"marksman")    # 4:1 band, for board banners and the inspector
#     BannerArtDB.portrait_texture(&"marksman")  # 2:3 column, for hand cards (option A)
#   Lookup order, so the head's ChatGPT banners drop in without code changes:
#   1. res://data/banners/<art_id>.tres (a BannerArt: master texture or image_path + crop centres).
#   1b. Optional licensed source (private pitch build only, kc-cod): when the git-ignored folder
#      res://assets/licensed/mw3/ exists with a manifest.csv (header row; columns file, kind,
#      chassis or card, optional banner_y, portrait_x, title), the first row per chassis id is used.
#      A clean checkout has no such folder and silently falls through to the placeholders.
#   2. Placeholder from Killstreak's painted card art (assets/sprites/cards/card_<id>.webp, or its
#      SVG when bitmaps are off), cut with PLACEHOLDER_CROPS (eyeballed per card so the head and the
#      weapon sit in the band).
#   3. Generated placeholder: a per-id colour gradient with a class silhouette, so every card still
#      gets a recognisable, distinct banner.
#   Crops are AtlasTextures on the master (no copies); results are cached per art id.
# Dependencies: BannerArt (scripts/data/banner_art.gd), CardArt (scripts/ui/art/card_art.gd).
# Author: Mechanics Developer Agent (kc-board)
class_name BannerArtDB
extends RefCounted

const BANNER_DIR: String = "res://data/banners/"
## Optional, git-ignored licensed art (never required; see the header).
static var licensed_dir: String = "res://assets/licensed/mw3/"
const LICENSED_MANIFEST: String = "manifest.csv"
## art id -> [banner_y, portrait_x] for the Killstreak card art (888x544) placeholders.
const PLACEHOLDER_CROPS: Dictionary = {
	&"ammo_resupply": [0.40, 0.42], &"attack_helo": [0.42, 0.40], &"breach_and_clear": [0.45, 0.50],
	&"breacher": [0.34, 0.45], &"callout": [0.34, 0.45], &"combat_medic": [0.42, 0.62],
	&"comms_relay": [0.42, 0.60], &"demolitions_expert": [0.38, 0.48], &"flank_route": [0.50, 0.50],
	&"flanker": [0.40, 0.42], &"flashbang": [0.48, 0.48], &"frag_grenade": [0.45, 0.55],
	&"gunner": [0.38, 0.33], &"gunship": [0.45, 0.40], &"halek_wren": [0.30, 0.45],
	&"hold_the_line": [0.40, 0.50], &"kestrel_ar7": [0.50, 0.45], &"longreach_338": [0.48, 0.50],
	&"marksman": [0.50, 0.42], &"mortar_barrage": [0.48, 0.45], &"okafor_anvil": [0.32, 0.45],
	&"p12_sidearm": [0.50, 0.50], &"point_man": [0.38, 0.55], &"recon_drone": [0.42, 0.55],
	&"recon_specialist": [0.42, 0.40], &"rifleman": [0.36, 0.45], &"sentry": [0.42, 0.40],
	&"sentry_turret": [0.40, 0.45], &"shieldman": [0.36, 0.45], &"suppressing_fire": [0.48, 0.50],
	&"tripwire_charge": [0.45, 0.40], &"wasp_9": [0.50, 0.45],
}
## Generated placeholder master (3:2) and its silhouette height.
const GEN_SIZE: Vector2i = Vector2i(480, 320)
## Silhouette per card for generated art (class token; structures use the sentry, emblems the shield).
const GEN_TOKENS: Dictionary = {
	&"brawler": &"shotgun", &"smoke_screen": &"shield", &"blackout": &"shield", &"sabotage": &"smg",
	&"listening_post": &"sentry", &"mortar_pit": &"sentry", &"bulwark": &"shield",
	&"war_standard": &"shield", &"sniper_perch": &"sniper", &"aid_station": &"shield",
}

## Off: never read data/banners (tests check the placeholder path); a kill switch too.
static var drop_in_enabled: bool = true
## Off: ignore the licensed folder even when present (tests, public builds).
static var licensed_enabled: bool = true
static var _arts: Dictionary = {}
static var _crops: Dictionary = {}
static var _licensed: Dictionary = {}   # chassis id -> manifest row Dictionary
static var _licensed_loaded: bool = false


## The BannerArt for an art id (never null; a generated placeholder at worst).
static func get_art(art_id: StringName, hint: Dictionary = {}) -> BannerArt:
	if _arts.has(art_id):
		return _arts[art_id]
	var art: BannerArt = null
	var path: String = BANNER_DIR + String(art_id) + ".tres"
	if drop_in_enabled and art_id != &"" and ResourceLoader.exists(path):
		art = load(path) as BannerArt
	if art == null and licensed_enabled:
		art = _licensed_art(art_id)
	if art == null:
		art = _placeholder(art_id, hint)
	_arts[art_id] = art
	return art


## Rows of the optional licensed manifest, keyed by chassis id ({} when the folder is absent).
static func licensed_rows() -> Dictionary:
	if _licensed_loaded:
		return _licensed
	_licensed_loaded = true
	var path: String = licensed_dir + LICENSED_MANIFEST
	if not FileAccess.file_exists(path):
		return _licensed
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _licensed
	var header: PackedStringArray = f.get_csv_line()
	for i: int in header.size():
		header[i] = header[i].strip_edges().to_lower()
	while not f.eof_reached():
		var cells: PackedStringArray = f.get_csv_line()
		if cells.size() < 2:
			continue
		var row: Dictionary = {}
		for i: int in mini(cells.size(), header.size()):
			row[header[i]] = cells[i].strip_edges()
		var chassis: String = String(row.get("chassis", row.get("card", row.get("chassis_id", ""))))
		var file: String = String(row.get("file", row.get("filename", row.get("path", ""))))
		if chassis != "" and file != "" and not _licensed.has(StringName(chassis)):
			row["file"] = file
			_licensed[StringName(chassis)] = row
	return _licensed


static func _licensed_art(art_id: StringName) -> BannerArt:
	var row: Dictionary = licensed_rows().get(art_id, {})
	if row.is_empty():
		return null
	var path: String = String(row["file"])
	if not path.contains("://"):
		path = licensed_dir + path
	var tex: Texture2D = _load_image(path)
	if tex == null:
		return null
	var art := BannerArt.new()
	art.id = art_id
	art.card_id = art_id
	art.texture = tex
	art.title = String(row.get("title", String(art_id).capitalize()))
	art.banner_y = float(row.get("banner_y", "0.5")) if String(row.get("banner_y", "")) != "" else 0.5
	art.portrait_x = float(row.get("portrait_x", "0.5")) if String(row.get("portrait_x", "")) != "" else 0.5
	art.source_note = "Licensed reference art (private pitch build): " + path.get_file()
	return art


## Imported texture, else the raw PNG / JPG / WebP bytes decoded (null when unreadable).
static func _load_image(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var err: Error = ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if err == OK and not img.is_empty() else null


## True when the art is the head's banner (data/banners), not a placeholder.
static func has_final_art(art_id: StringName) -> bool:
	return not get_art(art_id).placeholder


## The master image of an art (Texture2D), loading image_path when needed.
static func master_texture(art: BannerArt) -> Texture2D:
	if art.texture != null:
		return art.texture
	if art.image_path != "" and CardArt.has_bitmap(art.image_path):
		art.texture = CardArt.bitmap(art.image_path)
	return art.texture


## 4:1 band of the art (board banners, the inspector's 512x128 banner).
static func banner_texture(art_id: StringName, hint: Dictionary = {}) -> Texture2D:
	return _crop(art_id, &"banner", hint)


## 2:3 hand column of the art (hand card option A's art window).
static func portrait_texture(art_id: StringName, hint: Dictionary = {}) -> Texture2D:
	return _crop(art_id, &"portrait", hint)


static func clear_cache() -> void:
	_arts.clear()
	_crops.clear()
	_licensed.clear()
	_licensed_loaded = false


static func _crop(art_id: StringName, kind: StringName, hint: Dictionary) -> Texture2D:
	var key: String = "%s/%s" % [art_id, kind]
	if _crops.has(key):
		return _crops[key]
	var art: BannerArt = get_art(art_id, hint)
	var tex: Texture2D = master_texture(art)
	if tex == null:
		return null
	var sz: Vector2 = tex.get_size()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = art.banner_region(sz) if kind == &"banner" else art.portrait_region(sz)
	atlas.filter_clip = true
	_crops[key] = atlas
	return atlas


## hint: {cls (unit class word), type ("unit" / "tactic" / "field" / "operator")}.
static func _placeholder(art_id: StringName, hint: Dictionary) -> BannerArt:
	var art := BannerArt.new()
	art.id = art_id
	art.card_id = art_id
	art.placeholder = true
	art.title = String(art_id).capitalize()
	if art_id != &"" and CardArt.has_card(art_id):
		var crops: Array = PLACEHOLDER_CROPS.get(art_id, [0.45, 0.5])
		art.banner_y = crops[0]
		art.portrait_x = crops[1]
		# Full-size bitmap (the band is ~888 px wide, shown at <= 512 logical px).
		var path: String = CardArt.card_path(art_id)
		art.texture = CardArt.bitmap(path) if CardArt.has_bitmap(path) else CardArt.card_texture(art_id, 2.0)
		art.source_note = "Placeholder: Killstreak card art, cropped to 4:1."
	if art.texture == null:
		art.texture = _generated(art_id, hint)
		art.banner_y = 0.40
		art.portrait_x = 0.5
		art.source_note = "Placeholder: generated gradient and silhouette."
	return art


## A 3:2 gradient with a dark class silhouette, its hue taken from the art id.
static func _generated(art_id: StringName, hint: Dictionary) -> Texture2D:
	var h: int = absi(hash(String(art_id)))
	var hue: float = float(h % 360) / 360.0
	var top: Color = Color.from_hsv(hue, 0.55, 0.42)
	var bottom: Color = Color.from_hsv(fposmod(hue + 0.08, 1.0), 0.7, 0.85)
	var img := Image.create(GEN_SIZE.x, GEN_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in GEN_SIZE.y:
		var t: float = float(y) / float(GEN_SIZE.y - 1)
		img.fill_rect(Rect2i(0, y, GEN_SIZE.x, 1), top.lerp(bottom, smoothstep(0.15, 0.85, t)))
	# A low sun / emblem disc behind the figure, offset per id so cards differ at a glance.
	var sun: Vector2 = Vector2(GEN_SIZE.x * (0.3 + 0.4 * float((h >> 9) % 100) / 100.0), GEN_SIZE.y * 0.42)
	var sun_r: float = GEN_SIZE.y * 0.13
	var sun_c: Color = Color.from_hsv(fposmod(hue + 0.12, 1.0), 0.35, 1.0)
	for y: int in range(int(sun.y - sun_r), int(sun.y + sun_r) + 1):
		for x: int in range(int(sun.x - sun_r), int(sun.x + sun_r) + 1):
			if Vector2(x, y).distance_to(sun) <= sun_r:
				img.set_pixel(x, y, sun_c)
	# Diagonal light rays (the mock-up's placeholder look).
	for x: int in range(0, GEN_SIZE.x, 24):
		var ray: Color = Color(1, 1, 1, 0.06)
		for y: int in GEN_SIZE.y:
			var px: int = x + y / 3
			if px < GEN_SIZE.x:
				img.set_pixel(px, y, img.get_pixel(px, y).blend(ray))
	var token: StringName = _token_for(art_id, hint)
	var tok_tex: Texture2D = CardArt.token_texture(token, 1.6)
	if tok_tex != null:
		var fig: Image = tok_tex.get_image()
		fig.convert(Image.FORMAT_RGBA8)
		var ink: Color = Color(0.05, 0.06, 0.07)
		for y: int in fig.get_height():
			for x: int in fig.get_width():
				var a: float = fig.get_pixel(x, y).a
				fig.set_pixel(x, y, Color(ink, a))
		var at: Vector2i = Vector2i((GEN_SIZE.x - fig.get_width()) / 2, int(GEN_SIZE.y * 0.62) - fig.get_height() / 2)
		img.blend_rect(fig, Rect2i(Vector2i.ZERO, fig.get_size()), at)
	return ImageTexture.create_from_image(img)


static func _token_for(art_id: StringName, hint: Dictionary) -> StringName:
	if GEN_TOKENS.has(art_id):
		return GEN_TOKENS[art_id]
	var cls: String = String(hint.get("cls", "")).to_upper()
	if CardArt.TOKEN_FOR_CLASS.has(cls):
		return CardArt.TOKEN_FOR_CLASS[cls]
	return &"shield"
