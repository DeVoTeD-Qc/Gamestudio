# test_ui_kit_wire2.gd
# Purpose: kc-ui-wire2. The UI kit batch 2 pieces wired into the game, each with its code fallback:
#   (a) with no kit file the hook draws nothing from the kit (the code look stays);
#   (b) with a dummy image standing in (UiKit.piece_overrides / icon_overrides) the hook draws it.
#   Also: UiKit.kit_texture falls back to the largest icon export present (the web build drops the
#   256 / 128 exports), KitTheme builds StyleBoxTextures from the manifest margins and keeps the old
#   content margins, and the painted backdrops are added only when their image exists.
# Author: UI/UX Agent (kc-ui-wire2)
extends "res://tests/test_case.gd"

var _saved_dirs: PackedStringArray = PackedStringArray()


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _dummy(sz: Vector2i = Vector2i(64, 64)) -> ImageTexture:
	var img: Image = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _kit(ids: Array = [], icons: Array = []) -> void:
	if _saved_dirs.is_empty():
		_saved_dirs = UiKit.piece_dirs
	UiKit.enabled = true
	UiKit.piece_dirs = PackedStringArray(["res://does/not/exist/"])
	UiKit.icon_dir = "res://does/not/exist/"
	UiKit.piece_overrides = {}
	UiKit.icon_overrides = {}
	for id: StringName in ids:
		UiKit.piece_overrides[id] = _dummy(Vector2i(256, 128))
	for id: StringName in icons:
		UiKit.icon_overrides[id] = _dummy()
	UiKit.clear_cache()
	KitTheme.clear_cache()
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
	KitTheme.clear_cache()


func _redraw_all(n: Node) -> void:
	for c: Node in n.find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).queue_redraw()
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()


# =============================================================================
# Web trim: icon exports
# =============================================================================

func test_icon_export_falls_back_to_the_largest_present() -> void:
	assert_eq(UiKit.export_fallbacks(256), [256, 128, 64, 48, 32] as Array[int], "256 missing -> 128 -> 64 ...")
	assert_eq(UiKit.export_fallbacks(48), [48, 32, 64, 128, 256] as Array[int], "48 missing -> 32, then larger")
	# A scratch kit with only the 64 export: a 200 px request (master) gets the 64 px export.
	var dir: String = "user://kit_wire2_icons/"
	DirAccess.make_dir_recursive_absolute(dir.path_join("64"))
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var png: String = dir.path_join("64").path_join("ico_zz_test.png")
	img.save_png(png)
	UiKit.icon_dir = dir
	UiKit.clear_cache()
	# A plain PNG in user:// is not an imported resource, so ResourceLoader can't see it; check the
	# path logic instead and that a missing id still returns null.
	assert_eq(UiKit.path_for(&"zz_test", 64), dir.path_join("64").path_join("ico_zz_test.png"), "export path")
	assert_eq(UiKit.kit_texture(&"zz_missing", 200), null, "a missing icon is still null")
	UiKit.icon_dir = UiKit.ICON_DIR
	UiKit.clear_cache()
	DirAccess.remove_absolute(png)
	# The real kit (when present): a 256 px request resolves even if the master were left out.
	if ResourceLoader.exists(UiKit.path_for(&"stat_firepower", 64)):
		assert_not_null(UiKit.kit_texture(&"stat_firepower", 300), "the master size resolves")


func test_web_preset_leaves_out_the_big_icon_exports() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export presets load")
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options") or String(cfg.get_value(sec, "platform", "")) != "Web":
			continue
		var ex: String = String(cfg.get_value(sec, "exclude_filter", ""))
		assert_true("assets/ui/kit/icons/ico_*" in ex, "%s leaves out the 256 masters" % sec)
		assert_true("assets/ui/kit/icons/128/*" in ex, "%s leaves out the 128 exports" % sec)


# =============================================================================
# KitTheme
# =============================================================================

func test_kit_theme_stylebox_margins_and_content() -> void:
	_kit([&"btn_secondary", &"pnl_modal"])
	var like: StyleBoxFlat = StyleBoxFlat.new()
	like.content_margin_left = 6
	like.content_margin_top = 4
	like.content_margin_right = 6
	like.content_margin_bottom = 4
	var sb: StyleBoxTexture = KitTheme.stylebox(&"btn_secondary", like)
	assert_not_null(sb, "a kit plate makes a StyleBoxTexture")
	assert_eq(sb.texture_margin_left, 16.0, "40 px ship margin at 0.4 = 16")
	assert_eq(sb.texture_margin_bottom, 19.0, "48 px ship margin at 0.4 = 19")
	assert_eq(sb.content_margin_top, 4.0, "content margins copied from the style it replaces")
	assert_eq(sb.texture.get_size(), Vector2(102, 51), "the 2x plate is downscaled once")
	var p: StyleBoxTexture = KitTheme.stylebox(&"pnl_modal")
	assert_eq(p.texture_margin_left, 24.0, "panels draw at 0.5")
	_kit()
	assert_eq(KitTheme.stylebox(&"btn_secondary", like), null, "no kit: no stylebox")
	_reset()


func test_kit_theme_apply_and_restore() -> void:
	var th: Theme = Theme.new()
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	th.set_stylebox(&"normal", &"HudButton", flat)
	th.set_stylebox(&"panel", &"HudPanelDark", flat)
	_kit()
	assert_eq(KitTheme.apply(th), 0, "no kit: the theme is untouched")
	assert_true(th.get_stylebox(&"normal", &"HudButton") == flat, "HudButton keeps its flat style")
	_kit([&"btn_secondary", &"btn_primary", &"pnl_inspector", &"pnl_tooltip", &"sld_track", &"tgl_knob"])
	assert_true(KitTheme.apply(th) > 0, "kit: styles change")
	assert_true(th.get_stylebox(&"normal", &"HudButton") is StyleBoxTexture, "HudButton normal is the kit plate")
	assert_false(th.has_stylebox(&"pressed", &"HudButton") and th.get_stylebox(&"pressed", &"HudButton") is StyleBoxTexture,
			"a toggled-on HudButton keeps the amber code style")
	assert_true(th.get_stylebox(&"panel", &"HudPanelDark") is StyleBoxTexture, "HudPanelDark is the kit panel")
	KitTheme.restore(th)
	assert_true(th.get_stylebox(&"normal", &"HudButton") == flat, "restore puts the flat style back")
	_reset()


func test_style_button_and_panel_fallback() -> void:
	var b: Button = Button.new()
	tree.root.add_child(b)
	_kit()
	assert_false(KitTheme.style_button(b, &"btn_danger"), "no kit: the button is unchanged")
	assert_false(b.has_theme_stylebox_override(&"normal"), "no override without the kit")
	_kit([&"btn_danger", &"pnl_modal"])
	assert_true(KitTheme.style_button(b, &"btn_danger"), "kit: the danger plate")
	assert_true(b.get_theme_stylebox(&"normal") is StyleBoxTexture, "normal is the kit plate")
	assert_true(b.get_theme_stylebox(&"pressed") is StyleBoxTexture, "pressed is the same plate, darker")
	var pc: PanelContainer = PanelContainer.new()
	tree.root.add_child(pc)
	assert_true(KitTheme.style_panel(pc, &"pnl_modal"), "kit: the modal plate")
	b.queue_free()
	pc.queue_free()
	await tree.process_frame
	_reset()


# =============================================================================
# Banner, lane, tile, slot and run-map hooks
# =============================================================================

func _banner(mode: StringName, entry: Dictionary = {}) -> BannerView:
	var b: BannerView = BannerView.new()
	tree.root.add_child(b)
	b.size = Vector2(228, 57)
	match mode:
		&"incoming":
			b.show_incoming()
		&"ghost":
			b.show_ghost(entry)
		_:
			b.show_unit(entry, &"player", false)
	return b


func _banner_log(mode: StringName, entry: Dictionary = {}) -> Array[StringName]:
	var b: BannerView = _banner(mode, entry)
	_redraw_all(b)
	await _frames(3)
	var out: Array[StringName] = UiKit.draw_log.duplicate()
	b.queue_free()
	await tree.process_frame
	return out


func test_banner_frames_fallback_and_kit() -> void:
	var unit: Dictionary = {"name": "Rifleman", "fp": 3, "armor": 4, "armor_max": 4, "banner": "rifleman", "cost": 2}
	var op: Dictionary = unit.duplicate()
	op["operator"] = true
	var plan: Dictionary = unit.duplicate()
	plan["pending"] = true
	_kit()
	for pair: Array in [[&"incoming", {}], [&"ghost", unit], [&"unit", op], [&"unit", plan]]:
		var none: Array[StringName] = await _banner_log(pair[0], pair[1])
		for id: StringName in [BannerView.INCOMING_PIECE, BannerView.GHOST_PIECE, BannerView.DOGTAG_PIECE, BannerView.PLAN_PIECE]:
			assert_false(none.has(id), "no kit: %s draws code (%s)" % [pair[0], none])
	_kit([BannerView.INCOMING_PIECE, BannerView.GHOST_PIECE, BannerView.DOGTAG_PIECE, BannerView.PLAN_PIECE])
	assert_true((await _banner_log(&"incoming")).has(BannerView.INCOMING_PIECE), "INCOMING: frm_incoming")
	assert_true((await _banner_log(&"ghost", unit)).has(BannerView.GHOST_PIECE), "ghost: frm_ghost")
	assert_true((await _banner_log(&"unit", op)).has(BannerView.DOGTAG_PIECE), "Operator: frm_dogtag_plate")
	assert_true((await _banner_log(&"unit", plan)).has(BannerView.PLAN_PIECE), "PLAN: frm_plan_plate")
	_reset()


func test_slot_tile_and_chip_backers() -> void:
	_kit()
	var slot: Node = (load("res://scenes/match/UnitSlot.tscn") as PackedScene).instantiate()
	tree.root.add_child(slot)
	(slot as Control).size = Vector2(228, 57)
	slot.show_empty(&"player")
	_redraw_all(slot)
	await _frames(3)
	assert_false(UiKit.draw_log.has(&"tile_slot_empty"), "no kit: the dashed empty slot")
	_kit([&"tile_slot_empty"])
	_redraw_all(slot)
	await _frames(3)
	assert_true(UiKit.draw_log.has(&"tile_slot_empty"), "kit: tile_slot_empty")
	slot.queue_free()
	await tree.process_frame
	_reset()


func test_run_map_node_and_path() -> void:
	var MapGraph: GDScript = load("res://scripts/ui/run/map_graph.gd")
	_kit([&"runmap_node", &"runmap_path"])
	var g: Control = MapGraph.new()
	tree.root.add_child(g)
	g.size = Vector2(600, 300)
	# Draw a dashed link inside a real draw pass.
	var ran: Array = [false]
	g.draw.connect(func() -> void:
		g.call(&"_dashed", Vector2(10, 10), Vector2(200, 80), Color.GRAY, 2.0)
		ran[0] = true)
	g.queue_redraw()
	await _frames(2)
	assert_true(ran[0] and UiKit.draw_log.has(&"runmap_path"), "kit: the dashed path is runmap_path")
	g.queue_free()
	await tree.process_frame
	_reset()


# =============================================================================
# Backdrops and icons
# =============================================================================

func test_backdrop_only_with_its_image() -> void:
	var host: Control = Control.new()
	tree.root.add_child(host)
	assert_false(CardArt.add_backdrop(host, &"no_such_backdrop"), "a missing image adds nothing")
	assert_eq(host.get_child_count(), 0, "nothing added")
	if CardArt.backdrop_texture(&"codex") != null:
		assert_true(CardArt.add_backdrop(host, &"codex"), "bg_codex adds art + scrim")
		assert_eq(host.get_child_count(), 2, "art and scrim")
		assert_eq(host.get_child(1).name, &"BackdropScrim", "the scrim sits over the art")
	host.queue_free()
	await tree.process_frame


func test_button_icon_and_icon_rect_fallback() -> void:
	var b: Button = Button.new()
	tree.root.add_child(b)
	_kit()
	assert_false(UiKit.set_button_icon(b, &"ui_codex"), "no kit: no icon")
	assert_true(b.icon == null, "the button keeps no icon")
	assert_eq(UiKit.icon_rect(&"perk_slot", 20.0), null, "no kit: no icon rect")
	_kit([], [&"ui_codex", &"perk_slot"])
	assert_true(UiKit.set_button_icon(b, &"ui_codex"), "kit: the icon")
	assert_not_null(b.icon, "the button shows the kit icon")
	var r: TextureRect = UiKit.icon_rect(&"perk_slot", 20.0)
	assert_not_null(r, "kit: an icon rect")
	r.free()
	b.queue_free()
	await tree.process_frame
	_reset()


func test_card_back_lookup() -> void:
	_kit([&"card_back_hand", &"card_back_banner"])
	assert_true(CardArt.kit_card_back() == UiKit.piece_overrides[&"card_back_hand"], "the kit hand back")
	assert_true(CardArt.kit_card_back(&"banner") == UiKit.piece_overrides[&"card_back_banner"], "the 4:1 back")
	_kit()
	assert_eq(CardArt.kit_card_back(&"banner"), null, "no kit: no 4:1 back")
	_reset()
