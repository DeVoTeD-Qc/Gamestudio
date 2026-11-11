# test_ui_kit_hooks.gd
# Purpose: kc-ui-hooks. The prompt pack v2 UI-kit slots (ui-kit-prompt-pack.md §7.4b) are wired with a
#   code fallback each. For every hook:
#     (a) with no kit image, nothing is drawn from the kit and the code drawing runs (the look the
#         screenshots compare is unchanged);
#     (b) with a dummy image standing in for the slot (UiKit.piece_overrides / icon_overrides), the hook
#         draws the kit image, with the tint the manifest asks for (team colour, amber damage, brass).
#   Also: the 9-slice margins and the 0.5 scale of the 2x kit, the fx/ folder, and that the manifest's
#   final folders are the ones UiKit searches (so tools/ui_kit_icons.py and the game agree).
# Author: Technical Artist Agent (kc-ui-hooks)
extends "res://tests/test_case.gd"

const CARD_SCENE: String = "res://scenes/match/CardView.tscn"
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
## The manifest lives next to the project in the repo (projects/killingcard/documentation/art/).
const MANIFEST_REL: String = "../../documentation/art/ui-kit-manifest.csv"
const UNIT: Dictionary = {"name": "Rifleman", "cls": "AR", "fp": 3, "armor": 2, "armor_max": 4, "banner": "rifleman", "cost": 2,
		"keywords": [{"id": &"pick"}], "trait": "vanguard", "trait_tier": 1}

var _saved_dirs: PackedStringArray = PackedStringArray()


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _dummy(sz: Vector2i = Vector2i(64, 64)) -> ImageTexture:
	var img: Image = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## Kit state for a case: `kit` = the ids to stand in with dummy images (kit_id for icons); the real
## folders are pointed at a missing path so a later import never changes what (a) checks.
func _kit(ids: Array = [], icons: Array = []) -> void:
	if _saved_dirs.is_empty():
		_saved_dirs = UiKit.piece_dirs
	UiKit.enabled = true
	UiKit.piece_dirs = PackedStringArray(["res://does/not/exist/"])
	UiKit.icon_dir = "res://does/not/exist/"
	UiKit.piece_overrides = {}
	UiKit.icon_overrides = {}
	for id: StringName in ids:
		UiKit.piece_overrides[id] = _dummy(Vector2i(500, 432) if String(id).begins_with("frm_") else Vector2i(64, 64))
	for id: StringName in icons:
		UiKit.icon_overrides[id] = _dummy()
	UiKit.clear_cache()
	UiKit.draw_log.clear()
	UiKit.draw_tint_log.clear()
	UiKit.log_draws = true


func _reset() -> void:
	UiKit.log_draws = false
	UiKit.draw_log.clear()
	UiKit.draw_tint_log.clear()
	UiKit.piece_overrides = {}
	UiKit.icon_overrides = {}
	if not _saved_dirs.is_empty():
		UiKit.piece_dirs = _saved_dirs
	UiKit.icon_dir = UiKit.ICON_DIR
	UiKit.clear_cache()


## Runs `fn` (a draw callback taking the CanvasItem) in a real draw pass; returns true once it ran.
func _draw_once(fn: Callable) -> bool:
	var ci := Control.new()
	ci.size = Vector2(260, 220)
	tree.root.add_child(ci)
	var ran: Array = [false]
	ci.draw.connect(func() -> void:
		fn.call(ci)
		ran[0] = true)
	ci.queue_redraw()
	await _frames(2)
	ci.queue_free()
	await tree.process_frame
	return ran[0]


func _tint_of(id: StringName) -> Color:
	var i: int = UiKit.draw_log.find(id)
	return UiKit.draw_tint_log[i] if i >= 0 else Color(0, 0, 0, 0)


# =============================================================================
# UiKit: tables, folders, the scaled 9-slice
# =============================================================================

func test_v2_margins_scale_and_folders() -> void:
	assert_eq(UiKit.PIECE_MARGINS[&"frm_standard_issue"], Vector4(16, 16, 16, 16), "frm_standard_issue: no notch, 16 on every side")
	for id: StringName in [&"frm_y2_unit", &"frm_y2_operator", &"frm_y2_standard_issue"]:
		assert_eq(UiKit.PIECE_MARGINS[id], Vector4(24, 24, 24, 24), "%s margins" % id)
	assert_eq(UiKit.PIECE_MARGINS[&"frm_t1_orders"], Vector4(24, 64, 48, 24), "frm_t1_orders margins")
	assert_eq(UiKit.PIECE_MARGINS[&"fx_glow_rail"], Vector4(48, 48, 48, 48), "fx_glow_rail margins")
	for id: StringName in [&"frm_standard_issue", &"frm_y2_unit", &"frm_t1_orders", &"tex_orders_paper"]:
		assert_eq(UiKit.piece_scale(id), 0.5, "%s is 2x art, drawn at 0.5" % id)
	assert_true(UiKit.PIECE_DIRS.has("res://assets/ui/kit/fx/"), "fx/ is searched")
	assert_true(UiKit.PIECE_DIRS.has("res://assets/ui/kit/frames/"), "frames/ is searched")


func test_manifest_folders_and_margins_match_the_game() -> void:
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://").path_join(MANIFEST_REL).simplify_path(), FileAccess.READ)
	if f == null:
		assert_true(true, "manifest not next to the project (export): skipped")
		return
	var head: PackedStringArray = f.get_csv_line()
	var col: Dictionary = {}
	for i: int in head.size():
		col[head[i]] = i
	var seen: Dictionary = {}
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < head.size():
			continue
		var id: StringName = StringName(row[col["id"]])
		if not (UiKit.V2_PIECES.has(id) or id == &"frm_standard_issue" or id == &"kw_pick_v2"):
			continue
		seen[id] = true
		var folder: String = "res://" + row[col["final_folder"]]
		if id == &"kw_pick_v2":
			assert_eq(folder, UiKit.ICON_DIR, "kw_pick_v2 ships with the icons")
			continue
		assert_true(UiKit.PIECE_DIRS.has(folder), "%s ships to %s, which UiKit searches" % [id, folder])
		var mtxt: String = row[col["nine_slice_margins_ltrb"]]
		var parts: PackedStringArray = mtxt.split(",")
		if parts.size() == 4 and parts[0].strip_edges().is_valid_int():
			var mv: Vector4 = Vector4(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
			assert_eq(UiKit.PIECE_MARGINS.get(id, Vector4.ZERO), mv, "%s: PIECE_MARGINS = the manifest" % id)
	f.close()
	for id: StringName in UiKit.V2_PIECES:
		assert_true(seen.has(id), "%s is in the manifest" % id)


func test_nine_slice_draws_rims_at_scale() -> void:
	var ts: Vector2 = Vector2(500, 432)
	var m: Vector4 = Vector4(24, 24, 24, 24)
	var cells: Array = UiKit.nine_rects(ts, Rect2(0, 0, 250, 216), m, 0.5)
	assert_eq(cells.size(), 9, "nine cells")
	assert_eq((cells[0][0] as Rect2).size, Vector2(12, 12), "2x art: a 24 px ship margin draws a 12 px rim")
	assert_eq((cells[0][1] as Rect2).size, Vector2(24, 24), "from the full 24 px source corner")
	assert_eq((cells[8][0] as Rect2).end, Vector2(250, 216), "fills the rect")
	var one: Array = UiKit.nine_rects(ts, Rect2(0, 0, 250, 216), m, 1.0)
	assert_eq((one[0][0] as Rect2).size, Vector2(24, 24), "scale 1: ship-size rims")
	var tiny: Array = UiKit.nine_rects(ts, Rect2(0, 0, 16, 16), m, 0.5)
	assert_true((tiny[0][0] as Rect2).size.x <= 8.0, "a small rect shrinks the rims so they never overlap")
	# The Standard Issue board frame: 512x128 at 228x57 -> 8 px rims (not 16).
	var si: Array = UiKit.nine_rects(Vector2(512, 128), Rect2(0, 0, 228, 57), UiKit.PIECE_MARGINS[&"frm_standard_issue"], UiKit.piece_scale(&"frm_standard_issue"))
	assert_eq((si[0][0] as Rect2).size, Vector2(8, 8), "frm_standard_issue draws 8 px rims on the 228x57 card")


func test_draw_piece_keeps_the_callers_transform_and_declines_when_missing() -> void:
	_kit()
	var res: Array = [true]
	var ran: bool = await _draw_once(func(ci: CanvasItem) -> void:
		res[0] = UiKit.draw_piece(ci, &"frm_y2_unit", Rect2(0, 0, 250, 216)) or UiKit.draw_tiled(ci, &"tex_orders_paper", Rect2(0, 0, 250, 216)))
	assert_true(ran and not res[0], "missing pieces: draw_piece / draw_tiled return false")
	_kit([&"frm_y2_unit", &"tex_orders_paper"])
	ran = await _draw_once(func(ci: CanvasItem) -> void:
		ci.draw_set_transform(Vector2(5, 5), 0.0, Vector2(2, 2))
		res[0] = UiKit.draw_piece(ci, &"frm_y2_unit", Rect2(0, 0, 100, 90)) and UiKit.draw_tiled(ci, &"tex_orders_paper", Rect2(0, 0, 100, 90))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	assert_true(ran and res[0], "with the images: both draw")
	assert_eq(UiKit.draw_log, [&"frm_y2_unit", &"tex_orders_paper"] as Array[StringName], "logged")
	_reset()


# =============================================================================
# CardLook: badges, crack, Pick
# =============================================================================

func test_badges_fallback_without_kit() -> void:
	_kit()
	var ran: bool = await _draw_once(func(ci: CanvasItem) -> void:
		CardLook.draw_reticle(ci, Rect2(0, 0, 28, 28), 3, &"enemy", 1)
		CardLook.draw_armor(ci, Rect2(30, 0, 27, 28), 2, true)
		CardLook.draw_crack(ci, Vector2(3, 3), 22.0)
		CardLook.draw_pick_icon(ci, Rect2(80, 0, 16, 16), Color.WHITE))
	assert_true(ran, "the code badges, crack and Pick glyph drew")
	assert_true(UiKit.draw_log.is_empty(), "nothing from the kit: %s" % [UiKit.draw_log])
	_reset()


func test_badges_use_the_kit_with_their_tints() -> void:
	_kit([CardLook.PLATE_FP, CardLook.PLATE_ARMOR, CardLook.FX_CRACK], [IconSheet.PICK_KIT_ID])
	var ran: bool = await _draw_once(func(ci: CanvasItem) -> void:
		CardLook.draw_reticle(ci, Rect2(0, 0, 28, 28), 3, &"enemy", 1))
	assert_true(ran and UiKit.draw_log.has(CardLook.PLATE_FP), "reticle: plate_fp_reticle")
	assert_true(_tint_of(CardLook.PLATE_FP).is_equal_approx(CardLook.TEAM[&"enemy"][0]), "rival: modulated red")
	_kit([CardLook.PLATE_FP])
	await _draw_once(func(ci: CanvasItem) -> void: CardLook.draw_reticle(ci, Rect2(0, 0, 28, 28), 3, &"player"))
	assert_true(_tint_of(CardLook.PLATE_FP).is_equal_approx(CardLook.TEAM[&"player"][0]), "yours: modulated teal")
	assert_true(CardLook.trend_color(1).is_equal_approx(CardLook.UP), "the buffed number stays green (drawn on top in code)")
	_kit([CardLook.PLATE_ARMOR])
	await _draw_once(func(ci: CanvasItem) -> void:
		CardLook.draw_armor(ci, Rect2(0, 0, 27, 28), 4, false)
		CardLook.draw_armor(ci, Rect2(30, 0, 27, 28), 2, true))
	assert_eq(UiKit.draw_log, [CardLook.PLATE_ARMOR, CardLook.PLATE_ARMOR] as Array[StringName], "armor: plate_armor_ballistic both times")
	assert_true(UiKit.draw_tint_log[0].is_equal_approx(Color.WHITE), "normal: as is")
	assert_true(UiKit.draw_tint_log[1].is_equal_approx(CardLook.AR_DMG_EDGE), "damaged: amber, never red")
	# kc-ipad-cards (kc-no-training): the level coin (coin_level) is gone from every card.
	_kit([CardLook.FX_CRACK])
	await _draw_once(func(ci: CanvasItem) -> void: CardLook.draw_crack(ci, Vector2(3, 3), 22.0))
	assert_eq(UiKit.draw_log, [CardLook.FX_CRACK, CardLook.FX_CRACK] as Array[StringName], "crack: a dark copy, then the amber one")
	assert_true(UiKit.draw_tint_log[1].is_equal_approx(CardLook.AR_DMG_EDGE), "the top copy is amber #F2A33A")
	_kit([], [IconSheet.PICK_KIT_ID])
	await _draw_once(func(ci: CanvasItem) -> void:
		CardLook.draw_pick_icon(ci, Rect2(0, 0, 16, 16), CardLook.AMBER)
		CardLook.draw_pick_icon(ci, Rect2(20, 0, 16, 16), CardLook.AMBER, true))
	# kc-layout-a (the icon table): Pick is lock-on brackets, drawn in code; the kit's kw_pick_v2 (a
	# shield, Armor's shape) is no longer used.
	assert_eq(UiKit.draw_log, [] as Array[StringName], "Pick: the brackets, never kw_pick_v2")
	_reset()


## kc-ui-import2: trait chips (ico_trait_*), the Fireteam keyword (ico_kw_fireteam) and the effect bolt
## (ico_effect_bolt) ask the kit first, tinted like their code glyph, and keep the code glyph without it.
func test_import2_trait_fireteam_bolt_hooks() -> void:
	var draw_all: Callable = func(ci: CanvasItem) -> void:
		SynergyGlyphs.draw_trait_icon(ci, Rect2(0, 0, 20, 20), &"vanguard", Color.RED)
		SynergyGlyphs.draw_trait_icon(ci, Rect2(24, 0, 20, 20), &"undead", Color.GREEN)
		SynergyGlyphs.draw_keyword_icon(ci, Rect2(48, 0, 20, 20), &"fireteam", Color.BLUE)
		CardLook.draw_ability(ci, Rect2(72, 0, 21, 21), &"bolt_more", Color.YELLOW)
	_kit()
	var ran: bool = await _draw_once(draw_all)
	assert_true(ran and UiKit.draw_log.is_empty(), "no kit: the code glyphs draw (%s)" % [UiKit.draw_log])
	_kit([], [&"trait_vanguard", &"trait_undead", &"kw_fireteam", &"effect_bolt"])
	await _draw_once(draw_all)
	assert_eq(UiKit.draw_log, [&"trait_vanguard", &"trait_undead", &"kw_fireteam", &"effect_bolt"] as Array[StringName], "kit icons drawn")
	assert_true(_tint_of(&"trait_vanguard").is_equal_approx(Color.RED), "trait tint kept")
	assert_true(_tint_of(&"effect_bolt").is_equal_approx(Color.YELLOW), "bolt tint kept")
	_reset()


# =============================================================================
# BannerView (board): Pick ability, crack, rail glow
# =============================================================================

func _banner(entry: Dictionary, focus: StringName = &"") -> BannerView:
	var b: BannerView = BannerView.new()
	tree.root.add_child(b)
	b.size = Vector2(228, 57)
	b.show_unit(entry, &"player", false)
	b.syn_focus = focus
	return b


func _banner_log(entry: Dictionary, focus: StringName = &"") -> Array[StringName]:
	var b: BannerView = _banner(entry, focus)
	for c: Node in b.find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).queue_redraw()
	b.queue_redraw()
	await _frames(3)
	var out: Array[StringName] = UiKit.draw_log.duplicate()
	b.queue_free()
	await tree.process_frame
	return out


func test_banner_hooks_fallback_and_kit() -> void:
	_kit()
	var none: Array[StringName] = await _banner_log(UNIT, &"vanguard")
	assert_true(none.is_empty(), "no kit: the board card draws all code (%s)" % [none])
	_kit([&"fx_glow_rail", CardLook.FX_CRACK], [IconSheet.PICK_KIT_ID])
	var got: Array[StringName] = await _banner_log(UNIT, &"vanguard")
	assert_false(got.has(IconSheet.PICK_KIT_ID), "board Pick ability: the brackets, not kw_pick_v2 (%s)" % [got])
	assert_true(got.has(CardLook.FX_CRACK), "damaged: fx_crack_damage")
	assert_true(got.has(&"fx_glow_rail"), "rail highlight: fx_glow_rail")
	assert_true(_tint_of(&"fx_glow_rail").is_equal_approx(SynergyGlyphs_trait(&"vanguard")), "the glow takes the trait colour")
	_kit([&"fx_glow_rail"])
	var off: Array[StringName] = await _banner_log(UNIT, &"")
	assert_false(off.has(&"fx_glow_rail"), "no rail highlight: no glow")
	_reset()


func SynergyGlyphs_trait(t: StringName) -> Color:
	return (load("res://scripts/ui/synergy_glyphs.gd") as GDScript).trait_color(t)


# =============================================================================
# CardView (Y2+ / T1) and the O2 Operator card
# =============================================================================

func _card(view: Dictionary) -> CardView:
	var cv: CardView = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(view)
	cv.set_card_width(250)
	return cv


func _views() -> Dictionary:
	var op: Dictionary = {"name": "Kestrel", "type": "operator", "cost": 2, "firepower": 3, "armor": 7, "keywords": []}
	var si: Dictionary = CardView.view_for_card(CardDB.get_card(&"si_grunt"))
	si["standard_issue"] = true
	return {
		&"frm_y2_unit": CardView.view_for_card(CardDB.get_card(&"marksman")),
		&"frm_y2_operator": op,
		&"frm_y2_standard_issue": si,
		&"frm_t1_orders": CardView.view_for_card(CardDB.get_card(&"suppressing_fire")),
	}


func test_card_view_frames_fallback_and_kit() -> void:
	var views: Dictionary = _views()
	for id: StringName in views:
		_kit()
		var cv: CardView = _card(views[id])
		await _frames(2)
		assert_eq(cv.frame_piece(), id, "%s is the frame of its card" % id)
		assert_true(UiKit.draw_log.is_empty(), "%s missing: the drawn frame (%s)" % [id, UiKit.draw_log])
		cv.free()
		_kit([id, &"tex_orders_paper"])
		cv = _card(views[id])
		await _frames(2)
		assert_true(UiKit.draw_log.has(id), "%s drawn from the kit (%s)" % [id, UiKit.draw_log])
		assert_eq(UiKit.draw_log.has(&"tex_orders_paper"), id == &"frm_t1_orders", "%s: the orders paper only on Tactics" % id)
		cv.free()
	# A marked card keeps its amber rim over the kit frame (state colour differs from the base).
	_kit([&"frm_y2_unit"])
	var marked: Dictionary = (views[&"frm_y2_unit"] as Dictionary).duplicate()
	marked["marked"] = true
	var mv: CardView = _card(marked)
	await _frames(2)
	assert_true(mv._frame_colors()[0] != mv._base_frame_color(), "marked: the rim keyline is drawn over the frame")
	mv.free()
	_reset()


func test_operator_tray_card_frame() -> void:
	var hand: Control = (load("res://scenes/match/HandArea.tscn") as PackedScene).instantiate()
	tree.root.add_child(hand)
	await _frames(1)
	var e: Dictionary = {"name": "Kestrel", "fp": 3, "armor": 7, "armor_max": 7, "state": &"deploy", "cost": 1}
	_kit()
	hand.set_operator(e)
	hand.set_hand([])
	await _frames(2)
	var card: Control = hand.get_operator_card()
	assert_false(card.has_meta(&"kit_frame"), "no kit: the drawn brass frame")
	assert_true(card.get_theme_stylebox(&"panel") is StyleBoxFlat, "the StyleBoxFlat frame stays")
	assert_false(UiKit.draw_log.has(&"frm_y2_operator"), "nothing from the kit")
	_kit([&"frm_y2_operator"])
	hand.set_operator(e.duplicate())
	hand.set_hand([])
	await _frames(2)
	card = hand.get_operator_card()
	card.queue_redraw()
	await _frames(2)
	assert_eq(card.get_meta(&"kit_frame", &""), &"frm_y2_operator", "kit: the painted Operator frame")
	assert_true(UiKit.draw_log.has(&"frm_y2_operator"), "drawn from the kit (%s)" % [UiKit.draw_log])
	hand.free()
	_reset()


# =============================================================================
# Leftovers
# =============================================================================

func test_retired_pick_crosshair_is_gone() -> void:
	for px: String in ["", "32/", "48/", "64/", "128/"]:
		assert_false(FileAccess.file_exists(UiKit.ICON_DIR + px + "ico_kw_pick.png"), "ico_kw_pick.png removed (%s)" % px)
