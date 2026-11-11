# dd-art2-import: the painted UI kit (assets/art/painted/ui, scripts/ui/dd_skin.gd) is wired in:
# buttons get painted normal / hover / pressed / disabled plates by colour family, number badges pick
# the painted circle for their role and tier, card views carry a tinted painted rim on top, and with
# the kit switched off (an image missing) everything falls back to the StyleBoxFlat look.
extends "res://tests/dd_test_case.gd"

const Kit = preload("res://scripts/ui/dd_skin.gd")
const Marks = preload("res://scripts/ui/dd_marks.gd")


func test_every_kit_image_loads() -> void:
	Kit.set_skin("old")
	for f: String in ["dd_btn_red_normal", "dd_btn_dark_pressed", "dd_btn_disabled", "dd_badge_hit", "dd_badge_zombie_t4",
			"dd_pill_zombie", "dd_plate_door_afford", "dd_plate_fullset_lit", "dd_tag_red", "dd_bar_track", "dd_bar_fill_green",
			"dd_chip_filter_on", "dd_frame_card_rim", "dd_frame_chip_rim", "dd_panel_modal", "dd_bar_name", "dd_socket_next"]:
		check(Kit.tex(f) != null, f + " loads")
	Kit.set_skin(Kit.DEFAULT_SKIN)


func test_buttons_use_the_painted_family() -> void:
	Kit.set_skin("a")
	var b: Button = DDUi.button("Start run", Color("7a2d27"))
	check(b.get_theme_stylebox("normal") is Kit.Nine, "a red button is painted")
	eq(str(b.get_meta(&"painted", "")), "red", "the red family")
	eq(Kit.family(Color("5a2a1a")), "rust", "RUN is rust")
	eq(Kit.family(DDUi.PANEL_HI), "dark", "secondary buttons are dark")
	eq(Kit.family(Color("2f2f5a")), "indigo", "shop Patch rows are indigo")
	eq(Kit.family(Color("1f4a63")), "blue", "sheet equip choices are blue")
	eq(Kit.family(Color("3d4f2a")), "green", "machine choices are green")
	eq(Kit.family(Color("5a4a1d")), "rust", "scrap is rust")
	eq(b.custom_minimum_size.y, float(DDUi.TAP_MIN), "touch target unchanged")
	var hover: Kit.Nine = b.get_theme_stylebox("hover") as Kit.Nine
	check(hover != null and hover.tint.r > 1.0, "hover is the normal plate brightened")
	b.free()
	Kit.set_skin(Kit.DEFAULT_SKIN)


func test_badges_pick_their_painted_circle() -> void:
	var z: Marks.NumBadge = Marks.StrengthMark.new(8)
	eq(z.painted_file(false), "dd_badge_zombie_t3", "a strength-8 zombie is tier 3")
	eq(z.painted_file(true), "dd_pill_zombie", "wide zombie numbers use the pill")
	var h: Marks.NumBadge = Marks.HitBurst.new(3)
	eq(h.painted_file(false), "dd_badge_hit", "weapons use the hit badge")
	var heal: Marks.NumBadge = Marks.NumBadge.new(4, "item", DDUi.accent("M"))
	eq(heal.painted_file(false), "dd_badge_heal", "medkits use the heal badge")
	var cov: Marks.NumBadge = Marks.NumBadge.new(2, "item", DDUi.accent("C"))
	eq(cov.painted_file(false), "dd_badge_cover", "cover uses the cover badge")
	eq(cov.num_label.text, "2", "the game still draws the number")
	for n: Node in [z, h, heal, cov]:
		n.free()


func test_card_rim_and_fallback() -> void:
	Kit.set_skin("a")
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": "Z", "title": "Shambler", "strength": 3, "big": "3"})
	var rim: Node = v.get_node_or_null(^"PaintedRim")
	check(rim != null, "a card carries the painted rim")
	check(rim != null and rim.get_index() == v.get_child_count() - 1, "the rim is drawn on top")
	v.free()
	Kit.enabled = false
	Kit._tex.clear()
	var b: Button = DDUi.button("Codex")
	check(b.get_theme_stylebox("normal") is StyleBoxFlat, "no kit: the flat button stays")
	var v2: DDCardView = DDCardView.new()
	v2.setup({"kind": "Z", "title": "Shambler", "strength": 3, "big": "3"})
	check(v2.get_node_or_null(^"PaintedRim") == null, "no kit: no rim")
	b.free()
	v2.free()
	Kit.enabled = true
	Kit._tex.clear()
	Kit.set_skin(Kit.DEFAULT_SKIN)
