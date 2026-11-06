# banner_art_db.gd
# Purpose: The BannerArt data path (kc-board). Turns a card art id (a card id, a killstreak id, the
#   Operator's art id) into a BannerArt and its two crops:
#     BannerArtDB.banner_texture(&"marksman")    # 4:1 band, for board banners and the inspector
#     BannerArtDB.portrait_texture(&"marksman")  # 2:3 column, for hand cards (option A)
#   Lookup order, so the head's ChatGPT banners drop in without code changes:
#   1. res://data/banners/<art_id>.tres (a BannerArt: master texture or image_path + crop centres).
#   1b. Optional licensed source (private pitch build only, kc-cod / kc-cod2): the first git-ignored
#      folder of LICENSED_DIRS with a manifest.csv (header row; columns file, kind, chassis or card,
#      optional banner_y, portrait_x, title, id, frames_file, frames, frame_ms, mastery_family,
#      tier_rank). res://assets/licensed/mw3_pitch/ is the curated pitch set (tools/
#      build_mw3_pitch_set.py), res://assets/licensed/mw3/ the full download. The first row per
#      chassis id is that chassis' default art; every row is also reachable by its own id (kc_mw3_*),
#      which is what per-copy art uses (copy_arts, MatchState.art_by_uid). Operator rows (kind
#      operator, card = the primary weapon id) form the weapon's mastery ladder (operator_art_id).
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
## Optional, git-ignored licensed art folders, first one with a manifest wins (see the header).
const LICENSED_DIRS: PackedStringArray = ["res://assets/licensed/mw3_pitch/", "res://assets/licensed/mw3/"]
## Tests point this at a scratch folder; "" = search LICENSED_DIRS.
static var licensed_dir: String = ""
const LICENSED_MANIFEST: String = "manifest.csv"
## Operator mastery tiers (MW3 multiplayer ladder) and the camo band id each one maps to.
## Tier 1 is the Base camo (head, kc-polish B3: Base for both sides until the mastery grind exists).
const MASTERY_TIERS: PackedStringArray = ["Gilded", "Forged", "Priceless", "Interstellar"]
const MASTERY_CAMO: Array[StringName] = [&"base", &"forged", &"priceless", &"interstellar"]
## Dev toggle for the pitch: 0 = the match's tier (Base), 1-4 = force that mastery tier on every
## Operator (URL ?mastery=N on the web build, or Ctrl+M on the match screen cycles it).
static var operator_tier_override: int = 0
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

## kc-ui4: our own alternate arts for the public build (no licensed art): "<chassis>~<variant>" ids,
## made from the chassis' placeholder art with a different grade and crop. The default art is the
## chassis id itself ("STANDARD"). [suffix, subname, overlay colour (alpha = strength), brightness,
## saturation, banner_y shift, mirrored].
const VARIANTS: Array = [
	["night", "Night Ops", Color(0.10, 0.22, 0.55, 0.42), 0.78, 0.45, -0.08, false],
	["dust", "Sandstorm", Color(0.85, 0.55, 0.18, 0.34), 1.02, 0.70, 0.08, false],
	["flip", "Flipside", Color(0.0, 0.0, 0.0, 0.0), 0.95, 1.15, 0.0, true],
]
const VARIANT_SEP: String = "~"
const DEFAULT_SUBNAME: String = "Standard"

## Off: never read data/banners (tests check the placeholder path); a kill switch too.
static var drop_in_enabled: bool = true
## Off: ignore the licensed folder even when present (tests, public builds).
static var licensed_enabled: bool = true
static var _arts: Dictionary = {}
static var _crops: Dictionary = {}
static var _licensed: Dictionary = {}   # chassis id -> manifest row Dictionary
static var _licensed_by_id: Dictionary = {}   # art id (kc_mw3_*) -> manifest row
static var _licensed_pool: Dictionary = {}    # chassis / weapon id -> Array[StringName] of art ids
static var _licensed_root: String = ""
static var _licensed_loaded: bool = false
static var _frames: Dictionary = {}           # art id -> frame sheet Texture2D


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
	if art == null and String(art_id).contains(VARIANT_SEP):
		art = _option_variant(art_id, hint)
	if art == null and String(art_id).contains(VARIANT_SEP):
		art = _variant(art_id, hint)
	if art == null:
		art = _placeholder(art_id, hint)
	_arts[art_id] = art
	return art


## Rows of the optional licensed manifest, keyed by chassis id ({} when the folder is absent).
static func licensed_rows() -> Dictionary:
	if _licensed_loaded:
		return _licensed
	_licensed_loaded = true
	var dirs: PackedStringArray = [licensed_dir] if licensed_dir != "" else LICENSED_DIRS
	var path: String = ""
	for d: String in dirs:
		if FileAccess.file_exists(d + LICENSED_MANIFEST):
			_licensed_root = d
			path = d + LICENSED_MANIFEST
			break
	if path == "":
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
		if chassis == "" or file == "":
			continue
		row["file"] = file
		var key := StringName(chassis)
		if not _licensed.has(key):
			_licensed[key] = row
		var art_id := StringName(String(row.get("id", "")))
		if art_id != &"" and not _licensed_by_id.has(art_id):
			_licensed_by_id[art_id] = row
			if not _licensed_pool.has(key):
				_licensed_pool[key] = [] as Array[StringName]
			(_licensed_pool[key] as Array[StringName]).append(art_id)
	return _licensed


## True when licensed art is loaded (the private pitch folder is present and enabled).
static func has_licensed() -> bool:
	return licensed_enabled and not licensed_rows().is_empty()


## kc-cod2 (head): a licensed calling card shows its own title as the card's name (the chassis name
## becomes the type line). Not for the Operator's mastery cards (the Operator keeps its weapon name).
static func is_card_art(art: BannerArt) -> bool:
	return art != null and art.licensed and art.mastery_tier == 0 and art.title != ""


## The art's own title for a card name ("" when the art is not a licensed calling card).
static func art_title(art_id: StringName) -> String:
	if art_id == &"" or not has_licensed():
		return ""
	var art: BannerArt = get_art(art_id)
	return art.title if is_card_art(art) else ""


## kc-ui4: every art a card can wear, default first: the licensed pool in the pitch build (calling
## cards), else the chassis id + our VARIANTS. The Codex lists these; Settings.equipped_arts holds the
## pick per chassis. kc-trait-ui: for a known card this is ArtTraits.arts_for(card), so the public
## placeholder art of every trait option ("<chassis>~honors|operators|mastery|horde") is listed too.
static func alt_arts(chassis: StringName) -> Array[StringName]:
	var card: CardData = _card_of(chassis)
	if card != null:
		var arts: Array[StringName] = ArtTraits.arts_for(card)
		if not arts.is_empty():
			return arts
	var pool: Array[StringName] = licensed_pool(chassis)
	if not pool.is_empty():
		return pool
	var out: Array[StringName] = [chassis]
	for v: Array in VARIANTS:
		out.append(StringName("%s%s%s" % [chassis, VARIANT_SEP, v[0]]))
	return out


## The CardData of a chassis id (null without CardDB or for a non-card id).
static func _card_of(chassis: StringName) -> CardData:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null(^"/root/CardDB") if tree != null else null
	return db.get_card(chassis) if db != null and db.has_card(chassis) else null


## kc-ui4 (head naming): the art's own name, shown UNDER the card name (the card keeps its chassis
## name whatever it wears): a licensed calling card's title, or our variant's name. "" for the
## chassis' default placeholder art and for the Operator's mastery cards.
static func subname(art_id: StringName) -> String:
	if art_id == &"":
		return ""
	var t: String = art_title(art_id)
	if t != "":
		return t
	var parts: PackedStringArray = String(art_id).split(VARIANT_SEP)
	if parts.size() == 2:
		for v: Array in VARIANTS:
			if v[0] == parts[1]:
				return String(v[1])
		# kc-trait-ui: our placeholder art of a trait option (ArtTraits.OPTION_VARIANTS).
		var fam := StringName(parts[1])
		if fam != ArtTraits.STANDARD and ArtTraits.OPTION_VARIANTS.has(fam):
			return String(ArtTraits.OPTION_VARIANTS[fam][0])
	return ""


## The chassis an art id belongs to (a variant's base, a licensed row's card), else the id itself.
static func chassis_of(art_id: StringName) -> StringName:
	var parts: PackedStringArray = String(art_id).split(VARIANT_SEP)
	if parts.size() == 2:
		return StringName(parts[0])
	if has_licensed():
		licensed_rows()
		var row: Dictionary = _licensed_by_id.get(art_id, {})
		if not row.is_empty():
			return StringName(String(row.get("card", row.get("chassis", art_id))))
	return art_id


## kc-ui4 / kc-trait-ui: the trait a copy wearing `art_id` carries (ArtTraits.trait_of: the art's
## family, limited to the chassis' options; printed cards keep theirs). Without a known card, the
## licensed manifest's `trait` column, else &"" (the Codex shows an empty trait slot = no trait).
static func art_trait(art_id: StringName, card: CardData = null) -> StringName:
	if art_id == &"":
		return &""
	var c: CardData = card if card != null else _card_of(chassis_of(art_id))
	if c != null:
		return ArtTraits.trait_of(art_id, c)
	var art: BannerArt = get_art(art_id)
	return StringName(String(art.tags.get("trait", ""))) if art != null else &""


## Licensed art ids for a chassis (or an Operator weapon's mastery ladder, tier order), [] without.
static func licensed_pool(chassis: StringName) -> Array[StringName]:
	if not licensed_enabled:
		return [] as Array[StringName]
	licensed_rows()
	return (_licensed_pool.get(chassis, [] as Array[StringName]) as Array[StringName]).duplicate()


## Per-copy art (card-system §5.2, display only): one art id per entry of `card_ids` (a deck, in
## order). The n-th copy of a chassis across all `decks` gets the n-th art of its licensed pool
## (wrapping), so copies of the same chassis wear different banners on the board, also across the
## two sides. &"" = the chassis' default art. Without licensed art every entry is &"".
static func copy_arts(decks: Array) -> Array:
	var used: Dictionary = {}
	var out: Array = []
	for deck: Array in decks:
		var arts: Array[StringName] = []
		for id: Variant in deck:
			var chassis := StringName(String(id))
			var pool: Array[StringName] = licensed_pool(chassis)
			if pool.is_empty():
				arts.append(&"")
				continue
			var n: int = int(used.get(chassis, 0))
			used[chassis] = n + 1
			arts.append(pool[n % pool.size()])
		out.append(arts)
	return out


## The Operator's banner art id for its primary weapon at mastery tier (1-4; the dev override wins).
## Licensed: the weapon's mastery card of that tier (clamped to the ladder). Otherwise the weapon id.
static func operator_art_id(weapon_id: StringName, tier: int = 1) -> StringName:
	var pool: Array[StringName] = licensed_pool(weapon_id)
	if pool.is_empty():
		return weapon_id
	var t: int = operator_tier_override if operator_tier_override > 0 else tier
	return pool[clampi(t, 1, pool.size()) - 1]


## Camo band id for a mastery tier (1 = Base).
static func camo_for_tier(tier: int) -> StringName:
	var t: int = operator_tier_override if operator_tier_override > 0 else tier
	return MASTERY_CAMO[clampi(t, 1, MASTERY_CAMO.size()) - 1]


## Frame sheet of an animated art (null when the art is still or the sheet is missing).
static func frames_texture(art: BannerArt) -> Texture2D:
	if art == null or art.frames_path == "" or art.frame_count < 2:
		return null
	if _frames.has(art.id):
		return _frames[art.id]
	var tex: Texture2D = _load_image(art.frames_path)
	_frames[art.id] = tex
	return tex


static func _licensed_art(art_id: StringName) -> BannerArt:
	var row: Dictionary = licensed_rows().get(art_id, _licensed_by_id.get(art_id, {}))
	if row.is_empty():
		return null
	var path: String = String(row["file"])
	if not path.contains("://"):
		path = _licensed_root + path
	var tex: Texture2D = _load_image(path)
	if tex == null:
		return null
	var art := BannerArt.new()
	art.id = StringName(String(row.get("id", ""))) if String(row.get("id", "")) != "" else art_id
	art.card_id = StringName(String(row.get("card", row.get("chassis", art_id))))
	art.texture = tex
	art.licensed = true
	art.title = String(row.get("title", String(art_id).capitalize()))
	art.banner_y = float(row.get("banner_y", "0.5")) if String(row.get("banner_y", "")) != "" else 0.5
	art.portrait_x = float(row.get("portrait_x", "0.5")) if String(row.get("portrait_x", "")) != "" else 0.5
	var frames_file: String = String(row.get("frames_file", ""))
	if frames_file != "" and String(row.get("frames", "")).is_valid_int():
		art.frames_path = frames_file if frames_file.contains("://") else _licensed_root + frames_file
		art.frame_count = int(row["frames"])
		art.frame_ms = maxi(30, int(row.get("frame_ms", "80"))) if String(row.get("frame_ms", "")).is_valid_int() else 80
		art.animated = &"yes"
	art.mastery_family = StringName(String(row.get("mastery_family", "")))
	if String(row.get("trait", "")) != "":
		art.tags = {"trait": String(row["trait"])}
	art.mastery_tier = int(row.get("tier_rank", "0")) if String(row.get("tier_rank", "")).is_valid_int() else 0
	art.licence = "Activision. NOT LICENSED: private pitch prototype only, never ship or publish."
	art.source_note = "Licensed reference art (private pitch build): " + path.get_file()
	return art


## Imported texture, else the raw PNG / JPG / WebP bytes decoded (null when unreadable).
static func _load_image(path: String) -> Texture2D:
	# A "keep" import (the pitch set's WebP) ships the raw bytes: decode them, never load().
	if FileAccess.file_exists(path + ".import") and not FileAccess.get_file_as_string(path + ".import").contains('importer="keep"') \
			and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var err: Error = ERR_FILE_UNRECOGNIZED
	# Sniff the bytes, not the extension (some downloads are WebP saved as .png).
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	elif bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
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
	_licensed_by_id.clear()
	_licensed_pool.clear()
	_licensed_root = ""
	_frames.clear()
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
	# Licensed art is already a 4:1 strip: its "portrait" is the whole strip (hand cards show it
	# letterboxed, hand_area.gd), never an 85x128 column.
	atlas.region = art.banner_region(sz) if kind == &"banner" or art.licensed else art.portrait_region(sz)
	atlas.filter_clip = true
	_crops[key] = atlas
	return atlas


## kc-trait-ui: the public placeholder art of a trait option ("<chassis>~honors|operators|mastery|
## horde", ArtTraits.OPTION_VARIANTS): the chassis' art with the family's backdrop tint, a family
## treatment across the band (Honors: gold rules; Operators: black tape; Mastery: field camo; Horde:
## drips) and the family emblem in the band's middle right. Our own art, clearly a placeholder. Null
## for an id that is not an option family.
static func _option_variant(art_id: StringName, hint: Dictionary) -> BannerArt:
	var parts: PackedStringArray = String(art_id).split(VARIANT_SEP)
	if parts.size() != 2:
		return null
	var fam := StringName(parts[1])
	if fam == ArtTraits.STANDARD or not ArtTraits.OPTION_VARIANTS.has(fam):
		return null
	var spec: Array = ArtTraits.OPTION_VARIANTS[fam]
	var base: BannerArt = get_art(StringName(parts[0]), hint)
	var tex: Texture2D = master_texture(base)
	var art := BannerArt.new()
	art.id = art_id
	art.card_id = base.card_id
	art.placeholder = true
	art.is_default = false
	art.title = String(spec[0])
	art.banner_y = base.banner_y
	art.portrait_x = base.portrait_x
	art.tags = {"family": String(fam), "emblem": String(spec[2])}
	art.source_note = "Placeholder option art (%s, %s family): the chassis art with the family tint and emblem." % [spec[0], ArtTraits.FAMILY_NAMES[fam]]
	if tex == null:
		return art
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		art.texture = tex
		return art
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var tint: Color = spec[1]
	img.adjust_bcs(0.92, 1.06, 0.85)
	if tint.a > 0.0:
		var over: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		over.fill(tint)
		img.blend_rect(over, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	var band: Rect2i = Rect2i(art.banner_region(Vector2(img.get_size())))
	_family_treatment(img, band, fam)
	var es: int = maxi(16, int(band.size.y * 0.44))
	var emblem: Image = option_emblem(StringName(String(spec[2])), es)
	img.blend_rect(emblem, Rect2i(0, 0, es, es),
			Vector2i(band.position.x + int(band.size.x * 0.64) - es / 2, band.position.y + (band.size.y - es) / 2))
	art.texture = ImageTexture.create_from_image(img)
	return art


## The family's treatment across the 4:1 band of `img` (in place).
static func _family_treatment(img: Image, band: Rect2i, fam: StringName) -> void:
	var h: int = band.size.y
	match fam:
		ArtTraits.HONORS:
			var gold: Color = Color("#E2B84A")
			var t: int = maxi(2, h / 28)
			for y0: int in [band.position.y + t * 2, band.end.y - t * 3]:
				img.fill_rect(Rect2i(band.position.x, y0, band.size.x, t), gold)
		ArtTraits.OPERATORS:
			var tape: Color = Color("#121417")
			var edge: Color = Color("#E8C547")
			var w: int = maxi(6, h / 6)
			for x0f: float in [0.10, 0.62]:
				var x0: int = band.position.x + int(band.size.x * x0f)
				for y: int in range(band.position.y, band.end.y):
					var x: int = x0 + (y - band.position.y) / 2
					img.fill_rect(Rect2i(x, y, w, 1).intersection(Rect2i(Vector2i.ZERO, img.get_size())), tape)
					img.fill_rect(Rect2i(x - 2, y, 2, 1).intersection(Rect2i(Vector2i.ZERO, img.get_size())), edge)
		ArtTraits.MASTERY:
			var cols: Array[Color] = [Color(0.22, 0.27, 0.14, 0.55), Color(0.42, 0.36, 0.22, 0.50), Color(0.10, 0.12, 0.08, 0.55)]
			var rng := RandomNumberGenerator.new()
			rng.seed = 4242
			for i: int in 26:
				var r: int = maxi(6, int(h * rng.randf_range(0.10, 0.22)))
				var stamp: Image = _disc(r, cols[i % cols.size()])
				img.blend_rect(stamp, Rect2i(0, 0, r * 2, r * 2), Vector2i(band.position.x + rng.randi_range(0, band.size.x) - r,
						band.position.y + rng.randi_range(0, h) - r))
		ArtTraits.HORDE:
			var rot: Color = Color("#3E6B22")
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 1313
			var dw: int = maxi(3, h / 22)
			img.fill_rect(Rect2i(band.position.x, band.position.y, band.size.x, dw), rot)
			for i: int in 14:
				var x: int = band.position.x + rng2.randi_range(0, band.size.x - dw)
				var l: int = int(h * rng2.randf_range(0.12, 0.45))
				img.fill_rect(Rect2i(x, band.position.y, dw, l), rot)
				var d: Image = _disc(dw, rot)
				img.blend_rect(d, Rect2i(0, 0, dw * 2, dw * 2), Vector2i(x + dw / 2 - dw, band.position.y + l - dw))


## A filled disc stamp of radius r (2r x 2r, transparent outside).
static func _disc(r: int, c: Color) -> Image:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	var ctr: Vector2 = Vector2(r, r)
	for y: int in r * 2:
		for x: int in r * 2:
			if Vector2(x + 0.5, y + 0.5).distance_to(ctr) <= r:
				img.set_pixel(x, y, c)
	return img


## kc-trait-ui: a family emblem roundel (s x s): dark disc, family-coloured ring and glyph. laurel =
## a wreath (Honors), tape = crossed tape (Operators), camo = a camo disc (Mastery), rot = three drips
## (Horde). The Codex and the art itself use it; its shape is distinct from the trait icons.
static func option_emblem(emblem: StringName, s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(s, s) * 0.5
	var r: float = s * 0.5 - 1.0
	var ink: Color = Color(0.06, 0.07, 0.08, 0.92)
	var col: Color = {&"laurel": Color("#E2B84A"), &"tape": Color("#E8C547"), &"camo": Color("#A8B36A"), &"rot": Color("#8EDB6A")}.get(emblem, Color.WHITE)
	for y: int in s:
		for x: int in s:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var d: float = p.length()
			if d > r:
				continue
			var px: Color = ink
			if d > r * 0.84:
				px = col
			else:
				var u: Vector2 = p / r
				match emblem:
					&"laurel":
						var a: float = absf(atan2(u.x, -u.y))
						if d > r * 0.46 and d < r * 0.70 and a > 0.45 and a < 2.7 and fmod(a * 4.0, 1.0) < 0.62:
							px = col
						elif d < r * 0.16:
							px = col
					&"tape":
						if absf(u.x - u.y) < 0.20 or absf(u.x + u.y) < 0.20:
							px = Color("#1A1C1F") if (absf(u.x - u.y) < 0.13 or absf(u.x + u.y) < 0.13) else col
					&"camo":
						var n: float = sin(u.x * 7.0) + cos(u.y * 6.0 + u.x * 2.0) + sin((u.x + u.y) * 4.0)
						px = [Color("#3A4524"), Color("#6B5E38"), Color("#A8B36A"), Color("#1E2414")][clampi(int((n + 3.0) * 0.67), 0, 3)]
					&"rot":
						for k: int in 3:
							var cx: float = -0.42 + 0.42 * k
							var len: float = [0.55, 0.85, 0.45][k]
							if absf(u.x - cx) < 0.12 and u.y > -0.7 and u.y < -0.7 + len:
								px = col
							elif Vector2(u.x - cx, u.y - (-0.7 + len)).length() < 0.16:
								px = col
			img.set_pixel(x, y, px)
	return img


## kc-ui4: a public alternate art ("<chassis>~<variant>"): the chassis' art regraded (overlay,
## brightness, saturation), re-cropped and optionally mirrored. Null for an unknown variant.
static func _variant(art_id: StringName, hint: Dictionary) -> BannerArt:
	var parts: PackedStringArray = String(art_id).split(VARIANT_SEP)
	if parts.size() != 2:
		return null
	var spec: Array = []
	for v: Array in VARIANTS:
		if v[0] == parts[1]:
			spec = v
	if spec.is_empty():
		return null
	var base: BannerArt = get_art(StringName(parts[0]), hint)
	var tex: Texture2D = master_texture(base)
	var art := BannerArt.new()
	art.id = art_id
	art.card_id = base.card_id
	art.placeholder = true
	art.is_default = false
	art.title = String(spec[1])
	art.banner_y = clampf(base.banner_y + float(spec[5]), 0.1, 0.9)
	art.portrait_x = clampf(1.0 - base.portrait_x if bool(spec[6]) else base.portrait_x, 0.0, 1.0)
	art.source_note = "Placeholder alternate art (%s): the chassis art regraded." % spec[1]
	if tex == null:
		return art
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		art.texture = tex
		return art
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(float(spec[3]), 1.08, float(spec[4]))
	var tint: Color = spec[2]
	if tint.a > 0.0:
		var over: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		over.fill(tint)
		img.blend_rect(over, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	if bool(spec[6]):
		img.flip_x()
	art.texture = ImageTexture.create_from_image(img)
	return art


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
		art.source_note = "Placeholder: the project's painted card art, cropped to 4:1."
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
