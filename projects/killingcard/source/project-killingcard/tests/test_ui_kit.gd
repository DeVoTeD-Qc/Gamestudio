# test_ui_kit.gd
# Purpose: kc-ui-import. UiKit serves the batch 1 kit pictograms (assets/ui/kit/icons/) for their ids
#   and aliases, IconSheet callers get them through get_icon(), and with the kit missing every
#   lookup falls back to the old sheet (or null, so code-drawn glyphs stay).
# Author: Technical Artist Agent (kc-ui-import)
extends "res://tests/test_case.gd"

const BATCH1: Array[StringName] = [&"kw_first_shot", &"kw_pick", &"score", &"stat_armor", &"stat_cover",
		&"stat_deck", &"stat_firepower", &"stat_intel", &"stat_supply", &"streak"]


## The suite also runs with assets/ui/kit removed (ui-kit-prompt-pack.md §7.4.5): then the kit tests
## only check that nothing resolves to it.
func _kit_shipped() -> bool:
	return ResourceLoader.exists(UiKit.ICON_DIR.path_join("ico_streak.png"))


func _reset() -> void:
	UiKit.enabled = true
	UiKit.icon_dir = UiKit.ICON_DIR
	UiKit.clear_cache()


func test_batch1_textures_and_exports() -> void:
	_reset()
	if not _kit_shipped():
		assert_false(UiKit.has_kit(&"streak"), "kit folder absent: no kit textures")
		return
	for id: StringName in BATCH1:
		assert_true(UiKit.has_kit(id), "kit has %s" % id)
		for px: int in UiKit.EXPORT_PX + [UiKit.MASTER_PX]:
			var tex: Texture2D = UiKit.kit_texture(id, px)
			assert_not_null(tex, "%s @%d" % [id, px])
			if tex != null:
				assert_eq(tex.get_size(), Vector2(px, px), "%s export size" % id)
				assert_true(tex.resource_path.begins_with(UiKit.ICON_DIR), "%s from the kit folder" % id)
	# Export choice: smallest export at or above the drawn size.
	assert_eq(UiKit.export_px(22.0), 32, "22 px -> 32 export")
	assert_eq(UiKit.export_px(35.0), 48, "35 px -> 48 export")
	assert_eq(UiKit.export_px(300.0), UiKit.MASTER_PX, "big -> master")


func test_aliases_and_icon_sheet_hook() -> void:
	_reset()
	if not _kit_shipped():
		assert_false(UiKit.has_kit(&"streak"), "kit folder absent: no kit textures")
		return
	var intel: Texture2D = UiKit.icon(&"intel_contact")
	assert_not_null(intel, "intel_contact alias")
	if intel != null:
		assert_true(intel.resource_path.ends_with("ico_stat_intel.png"), "intel_contact -> stat_intel")
	assert_eq(UiKit.kit_id(&"supply"), &"stat_supply", "supply alias")
	assert_eq(UiKit.kit_id(&"kw_cover"), &"stat_cover", "cover alias")
	# Old sheet callers now get the kit image (wrapped as an AtlasTexture).
	for name: StringName in [&"stat_firepower", &"stat_armor", &"kw_pick", &"kw_first_shot", &"streak", &"kw_cover", &"supply"]:
		var a: AtlasTexture = IconSheet.get_icon(name)
		assert_not_null(a, "IconSheet %s" % name)
		if a != null:
			assert_true(a.atlas.resource_path.begins_with(UiKit.ICON_DIR), "IconSheet %s comes from the kit" % name)
	var kw: AtlasTexture = IconSheet.get_keyword_icon(&"first_shot")
	assert_true(kw != null and kw.atlas.resource_path.ends_with("ico_kw_first_shot.png"), "First Shot keyword icon from the kit")
	assert_true(IconSheet.has_icon(&"score"), "kit-only id is visible through has_icon")
	# Ids neither the kit nor the sheet has yet still resolve to the sheet.
	var flank: AtlasTexture = IconSheet.get_icon(&"kw_flank")
	assert_true(flank != null and flank.atlas.resource_path == IconSheet.SHEET_PATH, "kw_flank still from the sheet")
	assert_null_tex(UiKit.icon(&"kw_guard"), "kw_guard has no image yet (code-drawn)")
	var t: Color = UiKit.tint(&"player")
	assert_true(t.is_equal_approx(UiKit.FRIEND), "player tint")
	assert_true(UiKit.tint(&"rival", &"idle").is_equal_approx(UiKit.IDLE), "idle wins over side")


func test_fallback_when_kit_missing() -> void:
	UiKit.icon_dir = "res://assets/ui/kit/__missing__/"
	UiKit.clear_cache()
	for id: StringName in BATCH1:
		assert_false(UiKit.has_kit(id), "no kit %s" % id)
	var fp: AtlasTexture = IconSheet.get_icon(&"stat_firepower")
	assert_true(fp != null and fp.atlas.resource_path == IconSheet.SHEET_PATH, "FP falls back to the sheet")
	var intel: Texture2D = UiKit.icon(&"stat_intel")
	assert_true(intel is AtlasTexture and (intel as AtlasTexture).atlas.resource_path == IconSheet.SHEET_PATH, "stat_intel -> intel_contact cell")
	assert_null_tex(UiKit.icon(&"score"), "score: no kit, no sheet cell -> null (code fallback)")
	assert_false(IconSheet.has_icon(&"score"), "has_icon false without the kit")
	var ci := Control.new()
	ci.size = Vector2(26, 26)
	assert_false(UiKit.draw_icon(ci, &"streak", Rect2(0, 0, 26, 26)), "draw_icon declines -> caller draws its glyph")
	ci.free()
	UiKit.enabled = false
	UiKit.icon_dir = UiKit.ICON_DIR
	UiKit.clear_cache()
	assert_false(UiKit.has_kit(&"streak"), "disabled kit")
	_reset()


func test_strip_badges_draw_with_and_without_kit() -> void:
	_reset()
	for kit_on: bool in [true, false]:
		UiKit.enabled = kit_on
		UiKit.clear_cache()
		var badge: Control = (load("res://scripts/ui/strip_badge.gd") as GDScript).new()
		badge.glyph = &"streak"
		badge.size = Vector2(60, 60)
		tree.root.add_child(badge)
		badge.set_value([[["3", Color.WHITE]]])
		await tree.process_frame
		await tree.process_frame
		assert_true(is_instance_valid(badge), "badge drew (kit %s)" % kit_on)
		badge.queue_free()
		await tree.process_frame
	_reset()


func assert_null_tex(value: Variant, message: String) -> void:
	assert_true(value == null, message)
