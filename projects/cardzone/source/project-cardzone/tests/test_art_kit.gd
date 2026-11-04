# test_art_kit.gd
# Purpose: cz16 art kit checks (adapted from CallingCard tests/test_art_kit.gd).
#   - cardzone_theme.tres loads with the palette, rarity colours, fonts and clipped-tag styles;
#   - the three OFL fonts ship with their licence files;
#   - every icon / silhouette / area glyph exists as SVG and rasterises, and the art-direction icon list
#     is covered; marks are plain original vectors (no text, images, filters, brands);
#   - the rarity ladder gets lighter C -> L and every letter keeps >= 4.5:1 on its chip;
#   - CzCard instantiates for every sample card in both layouts and every state;
#   - legibility: at the phone scales (0.722 and 0.694 pt per logical px) every game-critical numeral
#     on a compact card is >= 12 pt, every numeral >= 8 pt, names >= 9 pt and fit; inspector numerals >= 12 pt;
#   - no element overlaps another (cards in both layouts, area tiles open / gassed with pawns, the map),
#     and every element stays inside its plate;
#   - Epic / Legendary get the glint (static with reduced motion), lower rarities do not;
#   - cz05 CardData / AreaData resources feed the views directly;
#   - imported art assets stay under 5 MB.
# Author: Technical Artist Agent (cz16)
extends "res://tests/test_case.gd"

const Samples: GDScript = preload("res://tests/tools/art_samples.gd")
const CARD_SCENE: String = "res://scenes/card/CzCard.tscn"
const THEME_PATH: String = "res://assets/themes/cardzone_theme.tres"
## Plan cz16: imported assets stay under 5 MB.
const BUDGET_BYTES: int = 5_000_000
const ART_DIRS: Array[String] = ["res://assets", "res://scripts/art", "res://scenes/card"]
const SCREENS: Array[float] = [CzArtKit.PHONE_PT_PER_PX, CzArtKit.SMALL_PHONE_PT_PER_PX]
## Icons the art direction lists (section 5), by kit name.
const REQUIRED_ICONS: Array[String] = ["weapon", "item", "attachment", "starter", "hit", "bounty",
	"search", "move", "damage", "range", "brace", "heal", "pull", "spent", "attach", "down", "cover", "fires_twice",
	"gas", "safe_zone", "supply_drop", "crate_open", "loot_pile", "pawn_player", "pawn_ai", "zone_card",
	"route_a", "route_b", "route_c", "final_circle", "padlock",
	"play", "hold", "stow", "end_turn", "undo", "shoot", "loot", "patch_up", "ditch", "adrenaline",
	"loadout", "next_hand", "health", "round", "opp_hand", "hidden", "public", "ai_thinking", "timer",
	"info", "pause", "settings", "close", "back", "confirm", "dev", "coach", "hotseat"]
const BANNED_WORDS: Array[String] = ["glock", "kalashnikov", "ak-47", "ak47", "barrett", "colt", "remington",
	"beretta", "sig sauer", "heckler", "uzi", "ar-15", "m16", "pubg", "fortnite", "apex", "warzone", "battlegrounds"]
const EPS: float = 0.01


func _card(data: Dictionary, sz: Vector2, mode: String = "auto") -> CzCard:
	var c: CzCard = (load(CARD_SCENE) as PackedScene).instantiate()
	c.layout_mode_override = mode
	tree.root.add_child(c)
	c.size = sz
	c.configure(data)
	return c


func test_theme_loads() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_not_null(theme, "cardzone_theme.tres loads")
	if theme == null:
		return
	for token: String in CzArtKit.PALETTE:
		assert_true(theme.has_color(token, "CardZone"), "theme colour %s" % token)
	for k: String in ["rarity_c", "rarity_u", "rarity_r", "rarity_e", "rarity_l"]:
		assert_true(theme.has_color(k, "CardZone"), "theme colour %s" % k)
	assert_true(theme.get_color("gas_lime", "CardZone").is_equal_approx(CzArtKit.GAS_LIME), "gas lime value")
	assert_true(theme.get_constant("tap_target", "CardZone") * CzArtKit.PHONE_PT_PER_PX >= CzArtKit.TAP_PT, "tap target >= 44 pt")
	assert_not_null(theme.default_font, "default font")
	var sb: StyleBoxFlat = theme.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_not_null(sb, "button stylebox")
	if sb != null:
		assert_true(sb.corner_radius_top_left > 0 and sb.corner_radius_bottom_right > 0, "clipped corners TL + BR")
		assert_eq(sb.corner_radius_top_right, 0, "square TR corner")
		assert_eq(sb.corner_detail, 1, "45 degree cut")
	for v: String in ["Title", "Body", "Mono", "StatNumber", "GasWarning", "PrimaryButton", "InspectorPanel", "GasBanner"]:
		assert_true(theme.get_type_variation_base(v) != &"", "variation %s" % v)
	# Body text >= 11 pt on the phone, names / buttons >= 10 pt.
	assert_true(theme.get_font_size("font_size", "Body") * CzArtKit.PHONE_PT_PER_PX >= 11.0, "body >= 11 pt")
	assert_true(theme.get_font_size("font_size", "Caption") * CzArtKit.PHONE_PT_PER_PX >= 11.0, "caption >= 11 pt")
	assert_true(theme.get_font_size("font_size", "Mono") * CzArtKit.PHONE_PT_PER_PX >= 9.0, "mono >= 9 pt")


func test_fonts_are_bundled_with_licence() -> void:
	for f: String in [CzArtKit.FONT_DISPLAY_PATH, CzArtKit.FONT_BODY_PATH, CzArtKit.FONT_MONO_PATH]:
		assert_not_null(load(f), "font %s loads" % f)
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-Barlow.txt"), "Barlow OFL licence")
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-ShareTechMono.txt"), "Share Tech Mono OFL licence")
	var lic: String = FileAccess.get_file_as_string("res://assets/fonts/OFL-Barlow.txt")
	assert_true(lic.contains("SIL OPEN FONT LICENSE"), "licence text is the OFL")
	assert_not_null(CzArtKit.font_numeral(), "tabular numeral font")
	assert_not_null(CzArtKit.font_mono(), "mono font")


func test_icons_exist_and_rasterise() -> void:
	var all: Array = []
	all.append_array(CzIcons.icon_names())
	for s: StringName in CzIcons.silhouette_names():
		all.append(StringName("sil_" + String(s)))
	all.append_array(CzIcons.area_names())
	assert_true(all.size() >= 90, "kit has %d marks" % all.size())
	for n: StringName in all:
		assert_true(FileAccess.file_exists("res://assets/icons/%s.svg" % n), "svg file %s" % n)
		assert_not_null(CzIcons.get_icon(n, 32), "rasterise %s" % n)
	for n: String in REQUIRED_ICONS:
		assert_true(CzIcons.has_icon(StringName(n)), "art-direction icon %s" % n)
	for a: StringName in CzCardArt.AREA_IDS:
		assert_not_null(CzIcons.area_glyph(a, 48, false), "area glyph %s open" % a)
		assert_not_null(CzIcons.area_glyph(a, 48, true), "area glyph %s gassed" % a)
	# Every sample card resolves to a real silhouette (or its Hit / Bounty mark).
	for d: Dictionary in Samples.CARDS:
		var info: Dictionary = CzCardArt.read(d)
		var art: StringName = info["art"]
		assert_true(art == &"hit" or art == &"bounty" or CzIcons.has_silhouette(art), "%s has art (%s)" % [d["name"], art])


func test_art_is_original_vector_only() -> void:
	var data: GDScript = load("res://scripts/art/art_icon_data.gd")
	for n: StringName in data.SVG:
		var s: String = String(data.SVG[n])
		for bad: String in ["<text", "<image", "<filter", "<mask", "<use", "href", "font-family"]:
			assert_false(s.contains(bad), "%s uses %s" % [n, bad])
	var words: Array = []
	for d: Dictionary in Samples.CARDS:
		words.append(str(d["name"]).to_lower())
	for n: StringName in data.SVG:
		words.append(String(n).to_lower())
	for w: String in words:
		for bad: String in BANNED_WORDS:
			assert_false(w.contains(bad), "'%s' names a real brand (%s)" % [w, bad])


func test_rarity_ladder_lightness_and_contrast() -> void:
	var prev: float = -1.0
	var letters: Dictionary = {}
	for i: int in CzArtKit.RARITY_ORDER.size():
		var r: Dictionary = CzArtKit.RARITIES[CzArtKit.RARITY_ORDER[i]]
		var l: float = (r["color"] as Color).get_luminance()
		assert_true(l > prev, "%s is lighter than the rarity below" % r["name"])
		prev = l
		letters[r["letter"]] = true
		assert_eq(int(r["ticks"]), i + 1, "%s ticks" % r["name"])
		assert_true(_contrast(r["color"], r["text"]) >= 4.5, "%s letter contrast %.2f" % [r["name"], _contrast(r["color"], r["text"])])
		# Lime is gas only, violet is safe only: no rarity sits near either.
		var c: Color = r["color"]
		var limeish: bool = c.h > 0.19 and c.h < 0.36 and c.s > 0.35
		var violetish: bool = c.h > 0.70 and c.h < 0.86 and c.s > 0.3
		assert_false(limeish, "%s is not a lime / green (gas only)" % r["name"])
		assert_false(violetish, "%s is not a violet (safe zone only)" % r["name"])
	assert_eq(letters.size(), 5, "five distinct letters")
	assert_eq(CzArtKit.rarity_key("legendary"), &"L", "full name")
	assert_eq(CzArtKit.rarity_key("starter"), &"", "starter has no chip")
	assert_true(_contrast(CzArtKit.PAPER, CzArtKit.ZONE_VIOLET) >= 7.0, "paper on violet")
	assert_true(_contrast(CzArtKit.GAS_GLOW, CzArtKit.ZONE_VIOLET) >= 7.0, "gas glow on violet")


func test_card_scene_instantiates_for_every_card_and_state() -> void:
	var compact: Vector2 = CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX)
	var full: Vector2 = CzArtKit.full_px(CzArtKit.PHONE_PT_PER_PX)
	for d: Dictionary in Samples.CARDS:
		for sz: Vector2 in [compact, full]:
			var c: CzCard = _card(d, sz)
			assert_eq(c.is_full(), sz == full, "%s auto layout at %s" % [d["id"], sz])
			c.queue_free()
	var c2: CzCard = _card(Samples.card("CZ-023"), compact)
	await tree.process_frame
	for prop: String in ["held", "face_down", "selected", "dimmed", "down"]:
		c2.set(prop, true)
		assert_true(bool(c2.get(prop)), "state %s sets" % prop)
	c2.attachments = ["+1 DMG", "+1 RNG"]
	assert_true(c2.attachment_tabs_height() > 0.0, "attachment tabs add height")
	assert_true(c2.hold_hit_rect().size.x * CzArtKit.PHONE_PT_PER_PX >= CzArtKit.TAP_PT - EPS, "hold hit area >= 44 pt")
	c2.face_down = true
	assert_true(c2.layout_report()["boxes"].is_empty(), "card back hides the face")
	await tree.process_frame
	c2.queue_free()
	# Signals.
	var c3: CzCard = _card(Samples.card("CZ-014"), compact)
	var got: Array = []
	c3.tapped.connect(func(_c: CzCard) -> void: got.append("tap"))
	c3.hold_toggled.connect(func(_c: CzCard, h: bool) -> void: got.append("hold %s" % h))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(compact.x * 0.5, compact.y * 0.7)
	c3._gui_input(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	c3._gui_input(release)
	c3.hold_enabled = true
	press.position = Vector2(compact.x * 0.5, -4.0)
	release.position = press.position
	c3._gui_input(press)
	c3._gui_input(release)
	assert_eq(got, ["tap", "hold true"], "tap and hold toggle")
	c3.queue_free()


func test_compact_numerals_meet_the_floors_on_phones() -> void:
	for ppp: float in SCREENS:
		var sz: Vector2 = CzArtKit.compact_px(ppp)
		for d: Dictionary in Samples.CARDS:
			var c: CzCard = _card(d, sz)
			var lay: Dictionary = c.layout_report()
			assert_eq(lay["mode"], "compact", "%s compact" % d["id"])
			var nums: Dictionary = lay["numerals"]
			for key: String in nums:
				var pt: float = float(nums[key]) * ppp
				assert_true(pt >= CzArtKit.NUMERAL_FLOOR_PT - EPS, "%s %s %.1f pt >= 8" % [d["id"], key, pt])
				assert_true(pt >= CzArtKit.CRITICAL_NUMERAL_PT - EPS, "%s %s %.1f pt >= 12 (game-critical)" % [d["id"], key, pt])
			var type: StringName = CzArtKit.type_key(d["type"])
			if type != &"hit" and type != &"bounty":
				assert_true(nums.has("brace"), "%s shows a Brace shield" % d["id"])
				var name_pt: float = float(lay["texts"]["name"]) * ppp
				assert_true(name_pt >= CzArtKit.NAME_FLOOR_PT - EPS, "%s name %.1f pt >= 9" % [d["id"], name_pt])
				assert_true(bool(lay["name_fits"]), "%s name fits one line (%s)" % [d["id"], lay["name_text"]])
				if int(c.info["cost"]) >= 0:
					assert_true(float(nums["cost"]) * ppp >= 14.0 - EPS, "%s cost 14 pt" % d["id"])
			else:
				assert_true(float(lay["texts"]["lines"]) * ppp >= 10.0 - EPS, "%s lines 10 pt" % d["id"])
			c.queue_free()


func test_inspector_numerals_and_text() -> void:
	var ppp: float = CzArtKit.PHONE_PT_PER_PX
	for d: Dictionary in Samples.CARDS:
		var c: CzCard = _card(d, CzArtKit.full_px(ppp), "full")
		var lay: Dictionary = c.layout_report()
		for key: String in lay["numerals"]:
			assert_true(float(lay["numerals"][key]) * ppp >= 22.0 - EPS, "%s inspector %s >= 22 pt" % [d["id"], key])
		assert_true(float(lay["texts"]["effect"]) * ppp >= 12.0 - EPS, "%s effect text 12 pt" % d["id"])
		assert_true(float(lay["texts"]["card_id"]) * ppp >= 9.0 - EPS, "%s id 9 pt" % d["id"])
		if lay["texts"].has("name"):
			assert_true(bool(lay["name_fits"]), "%s inspector name fits" % d["id"])
		c.queue_free()
	assert_eq(CzCard.effect_bbcode("Move 2. Search 1."), "[b]Move[/b] 2. [b]Search[/b] 1.", "keywords in SemiBold")


func test_card_elements_never_overlap() -> void:
	var sizes: Array = [CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX), CzArtKit.compact_px(CzArtKit.SMALL_PHONE_PT_PER_PX),
			CzArtKit.COMPACT_PT, CzArtKit.full_px(CzArtKit.PHONE_PT_PER_PX), CzArtKit.FULL_PT]
	for sz: Vector2 in sizes:
		for d: Dictionary in Samples.CARDS:
			var c: CzCard = _card(d, sz)
			var lay: Dictionary = c.layout_report()
			var k: float = lay["k"]
			var plate: PackedVector2Array = CzArtKit.tag_points(Rect2(Vector2.ZERO, sz).grow(-CzArtKit.CARD_BORDER_PT * k + 0.5), CzArtKit.CARD_CUT_PT * k)
			_check_boxes("%s %s %s" % [d["id"], lay["mode"], sz], lay["boxes"], plate, [["band", "name"], ["art", "twice_badge"]])
			c.queue_free()


func test_area_tiles_open_and_gassed() -> void:
	var ppp: float = CzArtKit.PHONE_PT_PER_PX
	for a: Dictionary in Samples.AREAS:
		for gassed: bool in [false, true]:
			var t := CzAreaTile.new()
			t.configure(a)
			tree.root.add_child(t)
			t.size = (t.design_pt() / ppp).ceil()
			t.gassed = gassed
			t.pawns = [&"player", &"ai"]
			var lay: Dictionary = t.layout_report()
			var label: String = "%s %s" % [a["id"], "gassed" if gassed else "open"]
			assert_eq(t.core, a["id"] == "old_town", "%s core flag" % label)
			assert_true(float(lay["texts"]["name"]) * ppp >= 12.0 - EPS, "%s name 12 pt" % label)
			assert_true(float(lay["texts"]["pip_letter"]) * ppp >= 9.0 - EPS, "%s pip letters" % label)
			if gassed:
				assert_true(lay["boxes"].has("gas_tag") and lay["boxes"].has("hint") and lay["boxes"].has("padlock"), "%s gas tag, hint, padlock" % label)
				assert_true(float(lay["texts"]["hint"]) * ppp >= 10.0 - EPS, "%s hint 10 pt" % label)
			var boxes: Dictionary = lay["boxes"].duplicate()
			boxes.erase("glyph")  # background art: pawns and the gas hint may sit over it
			for p: int in 2:
				assert_true((boxes["pawn%d" % p] as Rect2).size.x * ppp >= 28.0 - EPS, "%s pawn 28 pt" % label)
			var plate: PackedVector2Array = CzArtKit.tag_points(Rect2(Vector2.ZERO, t.size).grow(0.5), CzAreaTile.CUT_PT * float(lay["k"]))
			_check_boxes(label, boxes, plate, [])
			assert_true(t.size.x * ppp >= CzArtKit.TAP_PT and t.size.y * ppp >= CzArtKit.TAP_PT, "%s tile is a 44 pt tap target" % label)
			t.queue_free()
	await tree.process_frame


func test_map_lays_out_seven_tiles() -> void:
	var map := CzMap.new()
	tree.root.add_child(map)
	map.size = CzMap.DESIGN_PT / CzArtKit.PHONE_PT_PER_PX
	map.configure(Samples.AREAS)
	await tree.process_frame
	assert_eq(map.tiles().size(), 7, "seven tiles")
	var rects: Array = []
	for t: CzAreaTile in map.tiles():
		var r := Rect2(t.position, t.size)
		assert_true(Rect2(Vector2.ZERO, map.size).grow(0.5).encloses(r), "%s inside the map" % t.area_id)
		for o: Rect2 in rects:
			assert_false(r.grow(-0.5).intersects(o.grow(-0.5)), "%s overlaps another tile" % t.area_id)
		rects.append(r)
	map.set_state({"gassed": [&"docks"], "pawns": {&"quarry": [&"player"]}, "selected": &"quarry"})
	assert_true(map.tile(&"docks").gassed, "docks gassed")
	assert_false(map.tile(&"quarry").gassed, "quarry open")
	assert_eq(map.tile(&"quarry").pawns.size(), 1, "pawn placed")
	assert_true(map.tile(&"quarry").selected, "selected tile")
	assert_true(map.tile(&"old_town").core, "core tile")
	var got: Array = []
	map.area_pressed.connect(func(id: StringName) -> void: got.append(id))
	map.tile(&"motel").pressed.emit(&"motel")
	assert_eq(got, [&"motel"], "area_pressed forwards")
	map.queue_free()


func test_glint_only_on_epic_and_legendary() -> void:
	var sz: Vector2 = CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX)
	for d: Dictionary in Samples.CARDS:
		var c: CzCard = _card(d, sz)
		var on: bool = bool(c.layout_report()["glint"]["on"])
		var rar: StringName = CzArtKit.rarity_key(d.get("rarity", ""))
		var t: StringName = CzArtKit.type_key(d["type"])
		var expected: bool = (rar == &"E" or rar == &"L") and t != &"hit" and t != &"bounty"
		assert_eq(on, expected, "%s glint" % d["id"])
		c.queue_free()
	var settings: Node = tree.root.get_node_or_null("Settings")
	if settings != null:
		var before: bool = settings.reduced_motion
		settings.reduced_motion = true
		var c2: CzCard = _card(Samples.card("CZ-032"), sz)
		assert_eq(float(c2.layout_report()["glint"]["speed"]), 0.0, "reduced motion: static glint")
		c2.queue_free()
		settings.reduced_motion = before
	assert_true(load("res://assets/shaders/rarity_glint.gdshader") is Shader, "glint shader loads")


func test_card_data_resources_feed_the_views() -> void:
	var db: Node = tree.root.get_node_or_null("CardDB")
	var checked: int = 0
	if db != null and db.has_method("get_card"):
		for pair: Array in [[&"pump_shotgun", &"weapon", &"U", 4], [&"bandage", &"item", &"C", 2], [&"hit", &"hit", &"", -1],
				[&"scavenge", &"item", &"", -1], [&"red_dot_sight", &"attachment", &"C", 2]]:
			var cd: Resource = db.get_card(pair[0])
			if cd == null:
				continue
			var info: Dictionary = CzCardArt.read(cd)
			assert_eq(info["type"], pair[1], "%s type" % pair[0])
			assert_eq(info["rarity"], pair[2], "%s rarity" % pair[0])
			assert_eq(int(info["cost"]), int(pair[3]), "%s cost" % pair[0])
			assert_true(str(info["id"]).begins_with("CZ-"), "%s printed number" % pair[0])
			var c: CzCard = _card({}, CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX))
			c.configure(cd)
			assert_eq(c.info["name"], cd.get("display_name"), "%s name" % pair[0])
			c.queue_free()
			checked += 1
		if db.has_method("all_areas"):
			for a: Resource in db.all_areas():
				var t := CzAreaTile.new()
				t.configure(a)
				assert_true(t.area_id != &"", "area %s configures" % t.area_id)
				t.free()
	# The fixture path always works; the CardDB path is checked whenever cz05 data is present.
	var info2: Dictionary = CzCardArt.read({"code": "CZ-024", "id": "marksman_rifle", "display_name": "Marksman Rifle",
			"type": "weapon", "rarity": "R", "cost": 6, "dmg": 2, "rng": 2, "fires_per_turn": 1, "art_key": "marksman_rifle"})
	assert_eq(info2["art"], &"marksman_rifle", "art_key picks the silhouette")
	assert_eq(info2["id"], "CZ-024", "code is the printed id")
	assert_true(checked >= 0, "CardDB cards checked: %d" % checked)
	# Supply drops show the balance cost (BalanceConfig.supply_drop_cost), not a hard-coded number.
	var expected_drop: int = CzCardArt.DROP_COST_DEFAULT
	if db != null and db.has_method("get_balance"):
		expected_drop = int(db.get_balance().supply_drop_cost)
	assert_eq(CzCardArt.drop_cost(), expected_drop, "drop cost from balance")
	assert_eq(int(CzCardArt.read(Samples.card("CZ-032"))["cost"]), expected_drop, "Longshot shows the drop cost")
	assert_eq(int(CzCardArt.read({"type": "weapon", "drop": true, "cost": 0, "drop_cost": 3})["cost"]), 3, "card-level drop_cost wins")


func test_art_budget_under_5mb() -> void:
	var total: int = 0
	var names: Dictionary = {}
	for d: String in ART_DIRS:
		total += _dir_bytes(d, names)
	# Imported copies (.godot/imported) of the kit's assets count too.
	var imported: String = "res://.godot/imported"
	if DirAccess.dir_exists_absolute(imported):
		for f: String in DirAccess.get_files_at(imported):
			var base: String = f.get_slice("-", 0)
			if names.has(base):
				total += _file_bytes(imported.path_join(f))
	assert_true(total < BUDGET_BYTES, "art kit is %d bytes (< %d)" % [total, BUDGET_BYTES])


# --- helpers -----------------------------------------------------------------------------------------
func _check_boxes(label: String, boxes: Dictionary, plate: PackedVector2Array, allowed: Array) -> void:
	var keys: Array = boxes.keys()
	for i: int in keys.size():
		var a: Rect2 = boxes[keys[i]]
		if a.size.x <= 0.0 or a.size.y <= 0.0:
			continue
		var inner: Rect2 = a.grow(-0.5)
		for p: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
			assert_true(Geometry2D.is_point_in_polygon(p, plate), "%s: %s leaves the plate" % [label, keys[i]])
		for j: int in range(i + 1, keys.size()):
			var b: Rect2 = boxes[keys[j]]
			if [keys[i], keys[j]] in allowed or [keys[j], keys[i]] in allowed:
				continue
			assert_false(inner.intersects(b.grow(-0.5)), "%s: %s overlaps %s" % [label, keys[i], keys[j]])


func _dir_bytes(path: String, names: Dictionary) -> int:
	var total: int = 0
	for f: String in DirAccess.get_files_at(path):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		names[f] = true
		total += _file_bytes(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		total += _dir_bytes(path.path_join(sub), names)
	return total


func _file_bytes(path: String) -> int:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	return fa.get_length() if fa != null else 0


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
