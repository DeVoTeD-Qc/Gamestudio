# test_art_memory.gd
# Purpose: kc-ios-mem. The art caches give back what nothing shows: BannerArtDB.trim() and
#   CardArt.trim() drop unused textures beyond a small budget (newest kept) and never touch a
#   texture a node still holds; the demo collection's licensed check decodes no image.
# Author: Technical Artist Agent (kc-ios-mem)
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
