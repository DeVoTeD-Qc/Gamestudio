# test_art_memory.gd
# Purpose: kc-ios-mem. The art caches give back what nothing shows: BannerArtDB.trim() and
#   CardArt.trim() drop unused textures beyond a small budget (newest kept) and never touch a
#   texture a node still holds; the demo collection's licensed check decodes no image.
#   kc-codex-mem: a generated alternate art (<chassis>~night|dust|flip and the trait option looks) is
#   made from the source decoded on the CPU (the base master never goes to the GPU and back), holds
#   only its 4:1 band, looks exactly as before, and counts in trim()'s budget.
# Author: Technical Artist Agent (kc-ios-mem, kc-codex-mem)
extends "res://tests/test_case.gd"


func test_banner_trim_drops_only_unused_arts() -> void:
	BannerArtDB.clear_cache()
	var shown: Texture2D = BannerArtDB.banner_texture(&"kc_mem_test_a")
	BannerArtDB.banner_texture(&"kc_mem_test_b")
	BannerArtDB.banner_texture(&"kc_mem_test_c")
	assert_not_null(shown, "placeholder banner")
	var rect := TextureRect.new()
	rect.texture = shown
	shown = null
	var res: Dictionary = BannerArtDB.trim(0.0)
	assert_true(BannerArtDB._arts.has(&"kc_mem_test_a"), "an art on screen stays")
	assert_false(BannerArtDB._arts.has(&"kc_mem_test_b"), "an unused art is dropped")
	assert_false(BannerArtDB._crops.has("kc_mem_test_b/banner"), "with its crop")
	assert_eq(int(res["dropped"]), 2, "two dropped")
	assert_true(float(res["freed_mb"]) > 0.0, "memory freed")
	# The dropped art comes back on demand.
	assert_not_null(BannerArtDB.banner_texture(&"kc_mem_test_b"), "re-created when shown again")
	rect.free()
	BannerArtDB.trim(0.0)
	assert_false(BannerArtDB._arts.has(&"kc_mem_test_a"), "dropped once its node is gone")
	BannerArtDB.clear_cache()


func test_banner_trim_keeps_recent_unused_arts_within_the_budget() -> void:
	BannerArtDB.clear_cache()
	BannerArtDB.banner_texture(&"kc_mem_old")
	await tree.process_frame
	await tree.create_timer(0.02).timeout
	BannerArtDB.banner_texture(&"kc_mem_new")
	var one: float = BannerArtDB._art_mb(&"kc_mem_new")
	assert_true(one > 0.0, "an art has a size")
	BannerArtDB.trim(one * 1.5)
	assert_true(BannerArtDB._arts.has(&"kc_mem_new"), "the most recent unused art is kept")
	assert_false(BannerArtDB._arts.has(&"kc_mem_old"), "the older one goes")
	BannerArtDB.clear_cache()


func test_card_art_trim_drops_unused_bitmaps() -> void:
	CardArt.clear_cache()
	var shown: Texture2D = CardArt.backdrop_texture(&"run")
	if shown == null:
		assert_true(true, "no backdrop bitmap in this checkout")
		return
	CardArt.backdrop_texture(&"codex")
	var rect := TextureRect.new()
	rect.texture = shown
	shown = null
	var res: Dictionary = CardArt.trim(0.0)
	assert_eq(CardArt._bitmaps.size(), 1, "only the bitmap on screen stays")
	assert_true(int(res["dropped"]) >= 1, "unused bitmap dropped")
	assert_true(CardArt._bitmaps.values()[0] == rect.texture, "the shown one")
	rect.free()
	CardArt.trim(100.0)
	assert_eq(CardArt._bitmaps.size(), 1, "within the budget an unused bitmap is kept")
	CardArt.trim(0.0)
	assert_eq(CardArt._bitmaps.size(), 0, "budget 0: all unused dropped")
	CardArt.clear_cache()


func test_licensed_check_reads_the_manifest_only() -> void:
	BannerArtDB.clear_cache()
	assert_false(BannerArtDB.is_licensed_id(&"rifleman"), "licensed art off in tests")
	assert_eq(BannerArtDB._arts.size(), 0, "no art loaded to answer")
	BannerArtDB.clear_cache()


## The old pipeline (whole master read back, regraded, then cut): the reference look.
static func _reference_band(base: BannerArt, spec: Array, centre_y: float) -> Image:
	var img: Image = BannerArtDB.master_texture(base).get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(float(spec[3]), 1.08, float(spec[4]))
	var tint: Color = spec[2]
	if tint.a > 0.0:
		var over := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		over.fill(tint)
		img.blend_rect(over, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	if bool(spec[6]):
		img.flip_x()
	return img.get_region(Rect2i(BannerArt.band_rect(Vector2(img.get_size()), centre_y)))


func test_variants_are_band_only_cpu_made_and_look_the_same() -> void:
	var lic: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	# A data/banners drop-in, a Killstreak card-art placeholder and a generated placeholder.
	for chassis: StringName in [&"marksman", &"sentry", &"kc_mem_gen"]:
		for spec: Array in BannerArtDB.VARIANTS:
			BannerArtDB.clear_cache()
			var id := StringName("%s~%s" % [chassis, spec[0]])
			var art: BannerArt = BannerArtDB.get_art(id)
			var base: BannerArt = BannerArtDB._arts[chassis]
			if not base.placeholder and spec == BannerArtDB.VARIANTS[0]:
				assert_true(base.texture == null, "%s: the base master was never put on the GPU to be read back" % id)
			var got: Image = art.texture.get_image()
			got.convert(Image.FORMAT_RGBA8)
			var want: Image = _reference_band(base, spec, art.banner_y)
			assert_eq(got.get_size(), want.get_size(), "%s: the master is the 4:1 band at full width" % id)
			assert_eq(art.banner_region(Vector2(got.get_size())), Rect2(Vector2.ZERO, Vector2(got.get_size())), "%s: the banner is the whole master" % id)
			var worst: float = 0.0
			for y: int in range(0, got.get_height(), 5):
				for x: int in range(0, got.get_width(), 5):
					var a: Color = got.get_pixel(x, y)
					var b: Color = want.get_pixel(x, y)
					worst = maxf(worst, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
			assert_true(worst * 255.0 <= 1.0, "%s: looks as before (max diff %.1f / 255)" % [id, worst * 255.0])
	# A trait option look is band-only too (its family marks and emblem are tested in test_trait_ui).
	BannerArtDB.clear_cache()
	var opt: BannerArt = BannerArtDB.get_art(&"marksman~honors")
	var full: Vector2 = BannerArtDB.master_texture(BannerArtDB.get_art(&"marksman")).get_size()
	assert_eq(opt.texture.get_size(), BannerArt.band_rect(full, opt.banner_y).size, "an option look holds only its band")
	BannerArtDB.clear_cache()
	BannerArtDB.licensed_enabled = lic


func test_variant_arts_count_in_the_trim_budget() -> void:
	var lic: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var shown: Texture2D = BannerArtDB.banner_texture(&"marksman~night")
	BannerArtDB.banner_texture(&"marksman~dust")
	BannerArtDB.banner_texture(&"marksman~horde")
	var mb: float = BannerArtDB._art_mb(&"marksman~dust")
	assert_true(mb > 0.0 and mb < 2.0, "a variant weighs its band only (%.2f MB)" % mb)
	var rect := TextureRect.new()
	rect.texture = shown
	shown = null
	BannerArtDB.trim(0.0)
	assert_true(BannerArtDB._arts.has(&"marksman~night"), "the variant on screen stays")
	assert_false(BannerArtDB._arts.has(&"marksman~dust") or BannerArtDB._arts.has(&"marksman~horde"), "unused variants are dropped")
	assert_eq(BannerArtDB._art_mb(&"marksman"), 0.0, "their base holds no texture (only its file was read)")
	rect.free()
	BannerArtDB.trim(0.0)
	var left: float = 0.0
	for id: StringName in BannerArtDB._arts:
		left += BannerArtDB._art_mb(id)
	assert_false(BannerArtDB._arts.has(&"marksman~night"), "dropped once its node is gone")
	assert_eq(left, 0.0, "no texture memory left once nothing shows them")
	BannerArtDB.clear_cache()
	BannerArtDB.licensed_enabled = lic
