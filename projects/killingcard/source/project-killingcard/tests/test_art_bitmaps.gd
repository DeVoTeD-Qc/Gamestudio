# test_art_bitmaps.gd
# Purpose: k-art3 painted art (studio batch 1). Every art slot shows its approved image when the
#   file is there and its procedural fallback when it is not (forced here with
#   CardArt.missing_paths, and checked for real by deleting files in a temp copy of the project);
#   the shipped WebPs are imported as "keep" (byte for byte, never VRAM compressed); the screens
#   pick the art up: lanes (dimmed), Title key art, run / Supply Drop backdrops under a scrim,
#   run map mode art, the card back on INCOMING slots and circle-masked perk patches.
# Author: Technical Artist Agent (k-art3)
extends "res://tests/test_case.gd"

const Data: GDScript = preload("res://scripts/ui/art/card_art_data.gd")
## The 48 images approved: 47 from assets/incoming/batch1, fx_callin_tablet from batch2.
const APPROVED: Dictionary = {
	"res://assets/sprites/cards/": 37,  # 32 card art + 4 run map modes + card back
	"res://assets/sprites/board/": 3,
	"res://assets/ui/backgrounds/": 4,  # title key art, bg_run, bg_supply_drop, fx_callin_tablet
	"res://assets/ui/perks/": 4,
}
const MODES: Array[StringName] = [&"zone_control", &"firefight", &"detonator", &"rival"]
const PERKS: Array[StringName] = [&"streak_discipline", &"field_salvage", &"grit", &"objective_focus"]


func _reset() -> void:
	CardArt.bitmaps_enabled = true
	CardArt.missing_paths.clear()
	CardArt.clear_cache()


func _webps(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".webp"):
			out.append(dir + f)
	return out


func test_approved_images_shipped() -> void:
	for dir: String in APPROVED:
		assert_eq(_webps(dir).size(), int(APPROVED[dir]), "approved images in %s" % dir)
	assert_true(FileAccess.file_exists("res://assets/incoming/.gdignore"), "incoming/ is never imported")
	var stack: Array[String] = ["res://assets/incoming"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d: String in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(d))
		for f: String in DirAccess.get_files_at(dir):
			assert_false(f.get_extension() in ["webp", "png", "jpg", "import"], "raw drop or import left in incoming: %s/%s" % [dir, f])
	var preset := ConfigFile.new()
	assert_eq(preset.load("res://export_presets.cfg"), OK, "export presets load")
	assert_true("assets/incoming/*" in String(preset.get_value("preset.0", "exclude_filter", "")), "export excludes incoming/")


func test_cards_use_image_or_svg() -> void:
	_reset()
	for key: StringName in Data.CARDS:
		var path: String = CardArt.card_path(key)
		var tex: Texture2D = CardArt.card_texture(key, 2.0)
		assert_not_null(tex, "card %s has art" % key)
		if CardArt.has_bitmap(path):
			assert_true(tex == CardArt.bitmap(path, 444), "card %s uses its image" % key)
		else:
			assert_eq(tex.get_width(), 444, "card %s falls back to its SVG" % key)
	# Aliases (class_*, ks_*, type_*) resolve to the same image as their card.
	for alias: StringName in Data.ALIASES:
		assert_true(CardArt.card_texture(alias, 2.0) == CardArt.card_texture(Data.ALIASES[alias], 2.0), "alias %s" % alias)
	_reset()


func test_missing_image_falls_back() -> void:
	_reset()
	var card: String = CardArt.card_path(&"rifleman")
	var lane: String = CardArt.BOARD_DIR + "lane_cranes.webp"
	var key_art: String = CardArt.BACKDROP_DIR + "title_key_art.webp"
	var mode: String = CardArt.CARD_DIR + "runmap_mode_rival.webp"
	for p: String in [card, lane, key_art, mode, CardArt.BACKDROP_DIR + "bg_run.webp",
			CardArt.CARD_DIR + "card_back.webp", CardArt.PERK_DIR + "perk_grit.webp"]:
		CardArt.missing_paths[p] = true
	assert_false(CardArt.has_bitmap(card), "marked missing")
	assert_eq(CardArt.card_texture(&"rifleman", 2.0).get_width(), 444, "card -> SVG at 2x")
	assert_eq(CardArt.card_texture(&"class_ar", 1.0).get_width(), 222, "alias -> SVG at 1x")
	assert_eq(CardArt.lane_texture(&"cranes", 1.0).get_width(), Data.LANE_SIZE.x, "lane -> SVG")
	assert_false(CardArt.lane_is_bitmap(&"cranes"), "lane not painted, so not dimmed")
	assert_eq(CardArt.key_art_texture(1.0).get_width(), Data.KEY_ART_SIZE.x, "key art -> SVG")
	assert_true(CardArt.mode_texture(&"rival", &"gunship", 2.0) == CardArt.card_texture(&"gunship", 2.0), "rival mode -> gunship card art")
	assert_eq(CardArt.backdrop_texture(&"run"), null, "no bg_run -> plain backdrop")
	assert_eq(CardArt.card_back_texture(256), null, "no card back -> old INCOMING look")
	assert_eq(CardArt.perk_texture(&"grit", 96), null, "no patch")
	assert_eq(CardArt.perk_patch(&"grit", 96), null, "no patch node")
	CardArt.missing_paths[CardArt.BACKDROP_DIR + "fx_callin_tablet.webp"] = true
	assert_eq(CardArt.fx_texture(&"callin_tablet"), null, "no tablet -> procedural takeover")
	# Kill switch: everything procedural.
	CardArt.missing_paths.clear()
	CardArt.bitmaps_enabled = false
	CardArt.clear_cache()
	assert_eq(CardArt.card_texture(&"gunner", 1.0).get_width(), 222, "bitmaps off -> SVG")
	_reset()


func test_new_slots_load_images() -> void:
	_reset()
	for m: StringName in MODES:
		var path: String = CardArt.CARD_DIR + "runmap_mode_%s.webp" % m
		if CardArt.has_bitmap(path):
			assert_true(CardArt.mode_texture(m, &"gunship", 2.0) == CardArt.bitmap(path, 444), "mode %s image" % m)
		else:
			assert_not_null(CardArt.mode_texture(m, &"gunship", 2.0), "mode %s falls back" % m)
	for k: StringName in [&"run", &"supply_drop"]:
		var tex: Texture2D = CardArt.backdrop_texture(k)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(1536, 864), "bg_%s full size" % k)
		else:
			assert_false(FileAccess.file_exists(CardArt.BACKDROP_DIR + "bg_%s.webp" % k), "bg_%s null only when missing" % k)
	var back: Texture2D = CardArt.card_back_texture()
	if back != null:
		assert_eq(back.get_size(), Vector2(500, 700), "card back full size")
		assert_eq(CardArt.card_back_texture(192).get_width(), 192, "card back downscaled for a slot")
	for p: StringName in PERKS:
		var patch: TextureRect = CardArt.perk_patch(p, 96)
		if patch != null:
			assert_eq(patch.texture.get_width(), 128, "perk %s downscaled (96 -> 128 bucket)" % p)
			assert_true(patch.material is ShaderMaterial, "perk %s masked" % p)
			assert_true((patch.material as ShaderMaterial).shader == CardArt.CIRCLE_MASK, "circle mask")
			patch.free()
		else:
			assert_false(FileAccess.file_exists(CardArt.PERK_DIR + "perk_%s.webp" % p), "perk %s null only when missing" % p)
	_reset()


func test_no_vram_compressed_imports() -> void:
	var stack: Array[String] = ["res://"]
	var checked: int = 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d: String in DirAccess.get_directories_at(dir):
			if not d.begins_with(".") and not FileAccess.file_exists(dir.path_join(d).path_join(".gdignore")):
				stack.append(dir.path_join(d))
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".import"):
				continue
			var cfg := ConfigFile.new()
			assert_eq(cfg.load(dir.path_join(f)), OK, "%s parses" % f)
			var importer: String = String(cfg.get_value("remap", "importer", ""))
			if f.ends_with(".webp.import"):
				assert_eq(importer, "keep", "%s ships as delivered (no re-encode)" % f)
			if importer == "texture":
				assert_true(int(cfg.get_value("params", "compress/mode", 0)) != 2, "%s is not VRAM compressed" % f)
			checked += 1
	var shipped: int = 0
	for dir: String in APPROVED:
		for f: String in _webps(dir):
			shipped += 1
			assert_true(FileAccess.file_exists(f + ".import"), "%s has its keep import" % f)
	assert_true(checked >= shipped and checked > 0, "checked the imports (%d)" % checked)


func test_slots_and_screens_show_art() -> void:
	_reset()
	# kc-board: an INCOMING slot is a face-down banner back; a unit replaces it with its banner.
	var slot: Control = (load("res://scenes/match/UnitSlot.tscn") as PackedScene).instantiate()
	tree.root.add_child(slot)
	await tree.process_frame
	slot.show_incoming()
	assert_eq(slot.banner.mode, BannerView.Mode.INCOMING, "incoming shows the banner back")
	assert_false(slot.has_art(), "no unit art on a back")
	slot.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "banner": "rifleman"}, &"enemy", true)
	await tree.process_frame
	assert_true(slot.has_art(), "unit replaces the back")
	slot.queue_free()
	# Operator panel: earned perks get a masked patch, empty slots stay empty.
	var panel: Control = (load("res://scenes/match/OperatorPanel.tscn") as PackedScene).instantiate()
	tree.root.add_child(panel)
	await tree.process_frame
	panel.set_operator({"operator": {"name": "Kestrel AR-7"}, "perks": [&"grit"], "perk_slots": 3})
	var slots: Array = panel.get_node("%PerkRow").get_children().filter(func(n: Node) -> bool: return n is Panel)
	assert_eq(slots.size(), 3, "three perk slots")
	if slots.size() == 3:
		var patch: Node = slots[0].get_node_or_null("Patch")
		assert_eq(patch != null, CardArt.perk_texture(&"grit") != null, "earned perk shows its patch")
		assert_eq(slots[1].get_child_count(), 0, "empty slot stays empty")
	panel.queue_free()
	# Call-in takeover: painted tablet behind the band, graded red for a hostile call-in.
	var takeover: Control = (load("res://scenes/fx/CallInTakeover.tscn") as PackedScene).instantiate()
	tree.root.add_child(takeover)
	await tree.process_frame
	var tablet: TextureRect = takeover.find_child("Tablet", true, false)
	var has_tablet: bool = CardArt.fx_texture(&"callin_tablet") != null
	assert_eq(tablet != null, has_tablet, "takeover tablet iff its image exists")
	if tablet != null:
		assert_eq(tablet.texture.get_size(), Vector2(1536, 864), "tablet full size")
		takeover.show_call_in({"item_id": &"gunship", "name": "Gunship", "side": &"enemy", "zone": &"mid"})
		assert_true(tablet.modulate.g < 0.6, "hostile call-in grades the tablet red")
		takeover.show_call_in({"item_id": &"recon_drone", "name": "Recon Drone", "side": &"player", "zone": &"mid"})
		assert_true(tablet.modulate.g > 0.6, "own call-in keeps it neutral")
		takeover.finish_quietly()
	takeover.queue_free()
	# kc-board: columns have no zone backdrop (the banners are the art); an invalid target dims.
	var lane: Control = (load("res://scenes/match/Lane.tscn") as PackedScene).instantiate()
	tree.root.add_child(lane)
	await tree.process_frame
	lane.set_lane({"id": &"mid", "name": "Crane Yard"})
	lane.set_target(&"invalid", "NO")
	assert_eq(lane.target_state, &"invalid", "invalid-target state still applies")
	lane.queue_free()
	# Run screens: painted backdrop between the Background and the UI, with a scrim.
	for path: String in ["res://scenes/run/RunMap.tscn", "res://scenes/run/Reward.tscn", "res://scenes/Title.tscn"]:
		var screen: Control = (load(path) as PackedScene).instantiate()
		tree.root.add_child(screen)
		await tree.process_frame
		var art: TextureRect = screen.get_node_or_null("BackdropArt")
		var key: StringName = screen.backdrop_key()
		if key == &"":
			assert_true(art == null, "%s keeps its own key art" % path)
			var key_art: Texture2D = (screen.get_node("%KeyArt") as TextureRect).texture
			var painted: bool = CardArt.has_bitmap(CardArt.BACKDROP_DIR + "title_key_art.webp")
			assert_eq(key_art.get_width(), 1536 if painted else key_art.get_width(), "Title key art")
		elif CardArt.backdrop_texture(key) != null:
			assert_not_null(art, "%s has its backdrop" % path)
			var scrim: ColorRect = screen.get_node_or_null("BackdropScrim")
			assert_not_null(scrim, "%s has a scrim" % path)
			if art != null and scrim != null:
				assert_true(scrim.get_index() == art.get_index() + 1, "scrim right above the art")
				assert_true(scrim.color.a >= 0.6, "scrim keeps text readable")
				assert_true(art.get_index() < screen.get_node("%SafeArea").get_index(), "art under the UI")
		screen.queue_free()
		await tree.process_frame
	_reset()
