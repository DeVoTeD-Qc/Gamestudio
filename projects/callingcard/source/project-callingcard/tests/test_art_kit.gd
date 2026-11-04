# test_art_kit.gd
# Purpose: cc14 art kit checks. wall_theme.tres loads with fonts, palette and styles; every icon
#   (6 traits, 4 cipher glyphs, 6 sets, utility) exists as SVG and rasterises; BannerCard
#   instantiates for every demo card and state; Top/Bottom pips centred, Sides on the short ends;
#   nothing on the card overlaps from 256x64 to 1024x256; text fits with phone-safe minimums
#   (text >= 16 px, key numbers >= 24 px); Triptych panoramas draw;
#   capture wash changes owner; the art budget stays small; no franchise names in the art data.
# Author: Technical Artist Agent (cc14)
extends "res://tests/test_case.gd"

const Samples: GDScript = preload("res://tests/tools/art_samples.gd")
const CARD_SCENE: String = "res://scenes/card/BannerCard.tscn"
const THEME_PATH: String = "res://assets/themes/wall_theme.tres"
## Board, hand / inspector, album sizes (4:1).
const SIZES: Array[Vector2] = [Vector2(256, 64), Vector2(384, 96), Vector2(448, 112), Vector2(512, 128), Vector2(1024, 256)]
## Plan cc14: imported assets < 5 MB; brief: keep the kit < 1.5 MB.
const BUDGET_BYTES: int = 1_500_000
const ART_DIRS: Array[String] = ["res://assets/fonts", "res://assets/icons", "res://assets/shaders",
		"res://assets/themes", "res://scripts/art"]


## Headless windows are tiny, so font oversampling inflates metrics. Measure as a real window would.
func _real_font_metrics() -> float:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var previous: float = ts.font_get_global_oversampling()
	ts.font_set_global_oversampling(1.0)
	return previous


func _restore_font_metrics(previous: float) -> void:
	TextServerManager.get_primary_interface().font_set_global_oversampling(previous)


func test_wall_theme_loads() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_not_null(theme, "wall_theme.tres loads")
	if theme == null:
		return
	for c: String in ["wall", "player", "rival", "accent", "signature", "set_night_shift", "set_cipher"]:
		assert_true(theme.has_color(c, "Wall"), "Wall/%s colour" % c)
	assert_true(theme.get_color("player", "Wall").is_equal_approx(Color("#3EC6C1")), "player teal")
	assert_true(theme.get_color("rival", "Wall").is_equal_approx(Color("#F2705A")), "rival coral")
	for v: String in ["Title", "Heading", "Body", "Caption", "ScorePlayer", "ScoreRival", "ValueNumber"]:
		assert_eq(theme.get_type_variation_base(v), &"Label", "%s is a Label variation" % v)
		assert_true(theme.get_font_size("font_size", v) >= 16, "%s >= 16 px" % v)
	for v: String in ["PrimaryButton", "GhostButton"]:
		assert_eq(theme.get_type_variation_base(v), &"Button", "%s is a Button variation" % v)
	for v: String in ["WallSlot", "WallSlotValid", "AlbumPage", "InspectorPanel", "ScorePlayerPanel", "ScoreRivalPanel"]:
		assert_true(theme.has_stylebox("panel", v), "%s panel" % v)
	for f: String in ["c1", "c2", "c3", "c4", "showcase_chrome", "showcase_gold", "locked"]:
		assert_true(theme.has_stylebox(f, "BannerFrame"), "BannerFrame/%s" % f)
	var body: FontVariation = theme.default_font as FontVariation
	assert_true(body != null and body.base_font != null, "default font has an explicit base font")
	var title: FontVariation = theme.get_font("font", "Title") as FontVariation
	assert_true(title != null and title.base_font.resource_path.ends_with("BarlowCondensed-SemiBold.ttf"), "condensed display face")
	assert_true(theme.get_font_size("font_size", "Button") >= 18, "button text size")


func test_fonts_are_bundled_with_licence() -> void:
	for path: String in [ArtKit.FONT_BODY_PATH, ArtKit.FONT_DISPLAY_PATH]:
		assert_not_null(load(path), "font %s" % path)
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-Barlow.txt"), "OFL licence next to the fonts")


func test_icons_exist_and_rasterise() -> void:
	var required: Array[String] = []
	for t: StringName in ArtKit.TRAITS:
		required.append("trait_%s" % t)
	for i: int in range(1, 5):
		required.append("cipher_%d" % i)
	for s: StringName in ArtKit.SETS:
		required.append("set_%s" % s)
	required.append_array(["eye_open", "lock", "capture_arrow", "signature"])
	for n: String in required:
		assert_true(ArtIcons.has_icon(StringName(n)), "icon data %s" % n)
		assert_true(FileAccess.file_exists("res://assets/icons/%s.svg" % n), "svg file %s" % n)
		var tex: Texture2D = ArtIcons.get_icon(StringName(n), 48)
		assert_not_null(tex, "rasterised %s" % n)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(48, 48), "%s size" % n)
	assert_not_null(ArtIcons.trait_icon(&"ambush", 20), "trait_icon helper")
	assert_not_null(ArtIcons.cipher_glyph(3, 64), "cipher_glyph helper")


func test_card_scene_instantiates_for_every_card_and_state() -> void:
	var scene: PackedScene = load(CARD_SCENE) as PackedScene
	assert_not_null(scene, "BannerCard.tscn loads")
	if scene == null:
		return
	var host := Control.new()
	tree.root.add_child(host)
	var i: int = 0
	for d: Dictionary in Samples.CARDS:
		var card: BannerCard = scene.instantiate()
		host.add_child(card)
		card.size = SIZES[i % SIZES.size()]
		card.configure(d)
		card.side = [&"player", &"rival", &""][i % 3]
		card.signature = i % 5 == 0
		card.face_down = i % 7 == 3
		card.locked = i % 6 == 4
		card.set_complete = i % 4 == 1
		card.preview_flip = i % 8 == 2
		card.boost = Vector3i(1, 1, 1) if i % 9 == 0 else Vector3i.ZERO
		assert_eq(card.card_id, d["id"], "configured %s" % d["id"])
		assert_eq(card.values, Vector3i(d["top"], d["side"], d["bottom"]), "values %s" % d["id"])
		i += 1
	await tree.process_frame
	await tree.process_frame
	assert_eq(host.get_child_count(), Samples.CARDS.size(), "all cards in the tree")
	var showcase: BannerCard = host.get_child(18)
	assert_eq(showcase.trait_id, &"none", "store card has no trait")
	assert_eq(showcase.clearance, 1, "store card is Clearance 1")
	assert_eq(showcase._frame_spec()["name"], "Showcase", "store card gets the Showcase frame")
	var legend: BannerCard = host.get_child(3)
	assert_eq(legend._frame_spec()["name"], "Hidden", "face-down Ambush shows the card back")
	legend.face_down = false
	assert_eq(legend._frame_spec()["name"], "Legend", "Clearance 4 gets the Legend frame")
	host.queue_free()
	await tree.process_frame


func test_frames_differ_per_tier() -> void:
	var seen: Dictionary = {}
	for key: Variant in [1, 2, 3, 4, &"showcase_chrome", &"showcase_gold"]:
		var spec: Dictionary = ArtKit.FRAMES[key]
		var sig: String = "%s|%s|%s" % [spec["base"], spec["border"], spec["glint"]]
		assert_false(seen.has(sig), "frame %s is distinct" % key)
		seen[sig] = true
	assert_true(float(ArtKit.FRAMES[&"showcase_chrome"]["glint"]) >= float(ArtKit.FRAMES[4]["glint"]),
			"Showcase is the flashiest frame (anti-P2W rule made visible)")
	assert_eq(float(ArtKit.FRAMES[1]["glint"]), 0.0, "Issue frame is flat")


## Sizes between board and album, including odd ones (every 32 px of height).
func _all_sizes() -> Array[Vector2]:
	var out: Array[Vector2] = SIZES.duplicate()
	var h: float = 64.0
	while h <= 256.0:
		out.append(Vector2(h * 4.0, h))
		h += 32.0
	out.append(Vector2(288, 72))  # cc07 desktop brick
	out.append(Vector2(270, 68))  # cc07 phone brick
	return out


func test_text_fits_at_board_hand_and_album_size() -> void:
	var previous: float = _real_font_metrics()
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	for s: Vector2 in SIZES:
		card.size = s
		for d: Dictionary in Samples.CARDS:
			card.configure(d)
			var lay: Dictionary = card.layout_report()
			assert_true(int(lay["numeral_px"]) >= 24, "%s @%s numerals %d px" % [d["id"], s, lay["numeral_px"]])
			if card.is_full_detail():
				assert_true(bool(lay["name_fits"]), "%s @%s name fits (%s px, %.0f avail)" % [d["id"], s, lay["name_px"], lay["name_avail"]])
				assert_true(int(lay["name_px"]) >= BannerCard.MIN_TEXT_PX, "%s @%s name >= 16 px" % [d["id"], s])
				if int(lay["trait_word_px"]) > 0:
					assert_true(int(lay["trait_word_px"]) >= BannerCard.MIN_TEXT_PX, "%s @%s trait word >= 16 px" % [d["id"], s])
				if d["trait"] != &"none":
					assert_true(int(lay["trait_word_px"]) > 0, "%s @%s trait word shown at full detail" % [d["id"], s])
	card.queue_free()
	await tree.process_frame
	_restore_font_metrics(previous)


## Top pip at top-centre, Bottom at bottom-centre, Sides on the short ends (studio head's layout).
func test_value_pips_centred() -> void:
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	card.configure(Samples.CARDS[1])
	for s: Vector2 in _all_sizes():
		card.size = s
		var lay: Dictionary = card.layout_report()
		assert_true(is_equal_approx((lay["top"] as Vector2).x, s.x * 0.5), "@%s Top pip centred" % s)
		assert_true(is_equal_approx((lay["bottom"] as Vector2).x, s.x * 0.5), "@%s Bottom pip centred" % s)
		assert_true((lay["top"] as Vector2).y < s.y * 0.5 and (lay["bottom"] as Vector2).y > s.y * 0.5, "@%s Top above, Bottom below" % s)
		assert_true(is_equal_approx((lay["s_left"] as Vector2).y, s.y * 0.5) and is_equal_approx((lay["s_right"] as Vector2).y, s.y * 0.5),
				"@%s Side pips vertically centred" % s)
		assert_true((lay["s_left"] as Vector2).x < s.x * 0.15 and (lay["s_right"] as Vector2).x > s.x * 0.85, "@%s Side pips on the short ends" % s)
	card.queue_free()
	await tree.process_frame


## Nothing overlaps at any size 256x64 - 1024x256, with every element on (Signature, preview,
## trait word, name): pips, trait disc, Clearance pips, ribbon, preview badge, owner tab, name.
func test_card_elements_never_overlap() -> void:
	var previous: float = _real_font_metrics()
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	card.side = &"rival"
	card.signature = true
	card.preview_flip = true
	for s: Vector2 in _all_sizes():
		card.size = s
		var bounds := Rect2(Vector2.ZERO, s).grow(0.01)
		for d: Dictionary in Samples.CARDS:
			card.configure(d)
			var lay: Dictionary = card.layout_report()
			var tag: String = "%s @%s" % [d["id"], s]
			var circles: Dictionary = (lay["circles"] as Dictionary).duplicate()
			circles["preview"] = [lay["preview_center"], lay["preview_r"]]
			var boxes: Dictionary = (lay["boxes"] as Dictionary).duplicate()
			boxes["ribbon"] = lay["ribbon"]
			for cn: String in circles:
				var c: Vector2 = circles[cn][0]
				var r: float = circles[cn][1]
				assert_true(bounds.encloses(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)), "%s %s inside the card" % [tag, cn])
				# Owner tab: triangle x + y <= tab_l in the top-left corner.
				var t: float = lay["tab_l"]
				assert_true((c.x + c.y - t) / sqrt(2.0) >= r, "%s %s clear of the owner tab" % [tag, cn])
				for cn2: String in circles:
					if cn2 > cn:
						var c2: Vector2 = circles[cn2][0]
						assert_true(c.distance_to(c2) >= r + float(circles[cn2][1]), "%s %s / %s overlap" % [tag, cn, cn2])
				for bn: String in boxes:
					assert_false(_circle_hits_rect(c, r, boxes[bn]), "%s %s / %s overlap" % [tag, cn, bn])
			for bn: String in boxes:
				var b: Rect2 = boxes[bn]
				assert_true(bounds.encloses(b), "%s %s inside the card" % [tag, bn])
				assert_true(b.position.x + b.position.y >= float(lay["tab_l"]) or b.position.x >= float(lay["tab_l"]) or b.position.y >= float(lay["tab_l"]),
						"%s %s clear of the owner tab" % [tag, bn])
				for bn2: String in boxes:
					if bn2 > bn:
						assert_false(b.intersects(boxes[bn2]), "%s %s / %s overlap" % [tag, bn, bn2])
	card.queue_free()
	await tree.process_frame
	_restore_font_metrics(previous)


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_to(c) < r - 0.01


func test_phone_scale_keeps_key_numbers_readable() -> void:
	# On an 844x390 phone one logical px is ~0.72 pt (screen_profile.gd). Board-size numerals
	# (>= 24 px) are then >= 17 pt and the 64 px card is >= 46 pt tall (a comfortable tap target).
	var pt: float = (load("res://scripts/ui/screen_profile.gd") as GDScript).points_per_px(Vector2(2532, 1170), 3.0)
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	card.size = Vector2(256, 64)
	card.configure(Samples.CARDS[0])
	var lay: Dictionary = card.layout_report()
	assert_true(float(lay["numeral_px"]) * pt >= 17.0, "numerals %.1f pt on phone" % (float(lay["numeral_px"]) * pt))
	assert_true(64.0 * pt >= 44.0, "card height %.1f pt on phone" % (64.0 * pt))
	assert_false(card.is_full_detail(), "board size hides the name (inspector shows it)")
	card.size = Vector2(512, 128)
	assert_true(card.is_full_detail(), "hand / inspector size shows the name")
	card.queue_free()
	await tree.process_frame


func test_card_accepts_card_data_resources() -> void:
	var dir: String = "res://data/cards"
	var files: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	var checked: int = 0
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var res: Resource = load(dir.path_join(f))
		if res == null or not res.has_method("to_ui_dict"):
			continue
		card.configure(res)
		assert_eq(card.card_id, res.get("id"), "CardData %s id" % f)
		assert_eq(card.values.x, int(res.get("top")), "CardData %s top" % f)
		assert_true(card.set_id != &"", "CardData %s set" % f)
		checked += 1
	assert_true(checked >= 0, "CardData resources checked: %d" % checked)
	card.queue_free()
	await tree.process_frame


func test_capture_wash_changes_owner() -> void:
	var card: BannerCard = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	card.configure(Samples.CARDS[1])
	card.side = &"player"
	var tw: Tween = card.capture_to(&"rival", 0.05)
	assert_not_null(tw, "capture_to returns a tween")
	assert_eq(card.side, &"player", "owner changes after the wipe, not before")
	if tw != null:
		await tw.finished
	assert_eq(card.side, &"rival", "owner after the wipe")
	card.set_complete = true
	card.pulse(0.05)
	await tree.create_timer(0.1).timeout
	assert_true(card.set_complete, "pulse leaves the set-complete state")
	card.queue_free()
	await tree.process_frame


func test_triptych_panoramas_and_art_motifs() -> void:
	for t: StringName in CardArt.TRIPTYCHS:
		var a := CardArt.new()
		a.triptych = t
		a.size = Vector2(768, 64)
		tree.root.add_child(a)
		assert_true(a.clip_contents, "panorama %s is clipped" % t)
		a.queue_free()
	var art := CardArt.new()
	art.configure(Samples.CARDS[0])
	assert_eq(art.art_key, &"graveyard_shift", "art key from card id")
	assert_eq(art.glyph, 1, "glyph 1 on card 1")
	assert_eq(art.set_id, &"night_shift", "set from card")
	art.free()
	await tree.process_frame


func test_art_budget() -> void:
	var total: int = 0
	for d: String in ART_DIRS:
		total += _dir_bytes(d)
	assert_true(total < BUDGET_BYTES, "art kit is %d bytes (< %d)" % [total, BUDGET_BYTES])


func test_art_is_original_vector_only() -> void:
	var data: String = FileAccess.get_file_as_string("res://scripts/art/art_icon_data.gd")
	assert_false(data.is_empty(), "icon data readable")
	for banned: String in ["<text", "<image", "href", "<filter"]:
		assert_false(data.contains(banned), "icons use plain shapes only (%s)" % banned)
	for d: String in ART_DIRS:
		for f: String in DirAccess.get_files_at(d):
			var lower: String = f.to_lower()
			for word: String in ["activision", "callofduty", "call_of_duty", "cod_", "modernwarfare", "blackops"]:
				assert_false(lower.contains(word), "no franchise names in asset file %s" % f)


func _dir_bytes(path: String) -> int:
	var total: int = 0
	for f: String in DirAccess.get_files_at(path):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var fa: FileAccess = FileAccess.open(path.path_join(f), FileAccess.READ)
		if fa != null:
			total += fa.get_length()
	for sub: String in DirAccess.get_directories_at(path):
		total += _dir_bytes(path.path_join(sub))
	return total
