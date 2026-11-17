# dd-ios-mem (iPhone / iPad: the tab was killed for memory and reloaded mid-run). The art cache frees
# paintings nothing shows once they fall out of the recently used set (keep_bytes), finds a painting
# that is still on screen again without a second copy, and the engine font draws as one MSDF atlas
# (every size / outline / screen scale used to get its own glyph pages: ~70 MB after a few minutes).
extends "res://tests/dd_test_case.gd"

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const GameScript: GDScript = preload("res://autoload/game.gd")


func test_art_cache_frees_what_nothing_shows() -> void:
	Art.use_manifest(Art.DEFAULT_MANIFEST)
	var keep: int = Art.set_keep_bytes(6 * 1024 * 1024)   # four 768x512 paintings
	var keys: Array = []
	for v: int in range(1, 13):
		keys.append(Art.card_keys(DDCard.parse("Z%d" % v)))
	var first: Texture2D = Art.texture_for(keys[0])
	check(first != null, "zombie 1 art found")
	if first == null:
		return
	var w: WeakRef = weakref(first)
	check(Art.texture_for(keys[0]) == first, "asked again: the same texture (no second copy)")
	var shown: Texture2D = Art.texture_for(keys[1])   # stays referenced, like a tile on screen
	var shown_w: WeakRef = weakref(shown)
	first = null
	# use more paintings than keep_bytes holds (768x512 zombies at 1.5 MB each)
	var n: int = 0
	for rep: int in 3:
		for k: Array in keys.slice(2):
			var t: Texture2D = Art.texture_for(k)
			n += 1 if t != null else 0
	for v2: int in range(13, 33):
		Art.texture_for(["zombie_%d" % v2])
	check(n > 0, "other paintings loaded")
	check(w.get_ref() == null, "a painting nothing shows is freed once it leaves the recently used set")
	check(shown_w.get_ref() == shown, "a painting still referenced stays")
	check(Art.texture_for(keys[1]) == shown, "and is found again without loading a copy")
	check(Art.texture_for(keys[0]) != null, "a freed painting loads again when needed")
	check(Art._held_bytes <= 6 * 1024 * 1024 + 768 * 512 * 4, "the recently used set stays within its budget (%d MB)" % (Art._held_bytes / 1048576))
	Art.set_keep_bytes(keep)
	Art.reset()


func test_font_is_one_msdf_atlas() -> void:
	check(bool(ProjectSettings.get_setting("gui/theme/default_font_multichannel_signed_distance_field", false)), "project setting on")
	var ff: FontFile = ThemeDB.fallback_font as FontFile
	check(ff != null and ff.multichannel_signed_distance_field, "the engine font draws as MSDF")
	# the widest outline (14 on the 64 px zoom number) at the 48 px MSDF source size needs range >= 2 x 10.5
	check(GameScript.FONT_MSDF_RANGE >= int(ceil(2.0 * 14.0 * 48.0 / 64.0)), "pixel range covers the widest outline")
	var g: Node = GameScript.new()
	g.call("_setup_font")
	check(ff.msdf_pixel_range >= GameScript.FONT_MSDF_RANGE, "Game sets the pixel range")
	g.free()
