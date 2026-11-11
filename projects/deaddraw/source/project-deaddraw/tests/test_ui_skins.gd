# dd-ui-clean: the three switchable UI skins (scripts/ui/dd_skin.gd). Each skin loads every piece it
# draws, keeps the labels clear of its corner / rim decoration (content margins >= inset + 6 px, centred),
# keeps bone text at 4.5:1 or better on its button fills, and the "ui_skin" setting / Settings row switch it.
extends "res://tests/dd_test_case.gd"

const Kit = preload("res://scripts/ui/dd_skin.gd")

const PIECES: Array[String] = ["dd_btn_red_normal", "dd_btn_red_pressed", "dd_btn_rust_normal", "dd_btn_green_normal",
	"dd_btn_blue_normal", "dd_btn_indigo_normal", "dd_btn_dark_normal", "dd_btn_dark_pressed", "dd_btn_disabled",
	"dd_chip_filter_on", "dd_chip_filter_off", "dd_plate_door_afford", "dd_plate_door_locked", "dd_plate_door_use",
	"dd_plate_door_used", "dd_panel_modal", "dd_panel_tooltip", "dd_panel_overlay", "dd_panel_hud", "dd_tag_red", "dd_tag_boss"]
const LONG_LABELS: Array[String] = ["Start run as Rosa Vance", "BUY INTO SLOT 1 - 150 pts", "Help · Glossary", "Run again"]


func _restore() -> void:
	Kit.enabled = true
	Kit.set_skin(Kit.DEFAULT_SKIN)


func test_each_skin_loads() -> void:
	for k: String in Kit.SKINS:
		eq(Kit.set_skin(k), k, "skin %s selectable" % k)
		for f: String in PIECES:
			check(Kit.box(f, 10.0) != null, "%s: %s loads" % [k, f])
		check(Kit.tex("dd_badge_hit") != null, "%s: the painted badges stay" % k)
		var b: Button = DDUi.button("Start run", Color("7a2d27"))
		check(not (b.get_theme_stylebox("normal") is StyleBoxFlat), "%s: a skinned button" % k)
		check(b.get_theme_stylebox("hover") != null and b.get_theme_stylebox("disabled") != null, "%s: hover / disabled states" % k)
		eq(b.custom_minimum_size.y, float(DDUi.TAP_MIN), "%s: touch target unchanged" % k)
		b.free()
		var v: DDCardView = DDCardView.new()
		v.setup({"kind": "Z", "title": "Shambler", "strength": 3, "big": "3"})
		check(v.get_node_or_null(^"PaintedRim") != null, "%s: cards carry a rim" % k)
		v.free()
	Kit.set_skin("a")
	var t: Texture2D = Kit.tex("dd_btn_red_normal")
	check(t != null and t.resource_path.contains("/ui_clean/"), "a: buttons come from the clean (bolt-free) kit")
	check(Kit.tex("dd_badge_hit") != null and Kit.tex("dd_badge_hit").resource_path.contains("/ui/"), "a: badges from the kit")
	check(Kit.box("dd_btn_red_normal") is Kit.Nine, "a: painted 9-slice")
	Kit.set_skin("b")
	check(Kit.tex("dd_btn_red_normal") == null and Kit.box("dd_btn_red_normal") is Kit.Layers, "b: vector boxes")
	eq(Kit.radius(14.0), 6, "b: almost square corners")
	eq(Kit.set_skin("nonsense"), Kit.DEFAULT_SKIN, "unknown skin -> the default")
	eq(Kit.set_skin(""), Kit.DEFAULT_SKIN, "empty -> the default")
	_restore()


func test_labels_clear_the_corner_insets() -> void:
	for k: String in Kit.SKINS:
		Kit.set_skin(k)
		for f: String in PIECES:
			if f.begins_with("dd_tag_"):
				continue
			var st: StyleBox = Kit.box(f, 2.0)
			var ins: float = Kit.inset(f)
			var need: float = ins + Kit.GAP
			for side: int in 4:
				check(st.get_content_margin(side) >= need - 0.01, "%s %s: margin %d clears the decoration (%.0f >= %.0f)" % [k, f, side, st.get_content_margin(side), need])
			# a 300 x 72 button / plate: the label rect never meets a corner square of the decoration
			var r: Rect2 = Rect2(Vector2.ZERO, Vector2(300, 72))
			var text: Rect2 = Rect2(st.get_content_margin(SIDE_LEFT), st.get_content_margin(SIDE_TOP),
				r.size.x - st.get_content_margin(SIDE_LEFT) - st.get_content_margin(SIDE_RIGHT),
				r.size.y - st.get_content_margin(SIDE_TOP) - st.get_content_margin(SIDE_BOTTOM))
			check(text.size.x > 0.0 and text.size.y > 0.0, "%s %s: room for the label" % [k, f])
			for c: Vector2 in [Vector2.ZERO, Vector2(r.size.x - ins, 0), Vector2(0, r.size.y - ins), r.size - Vector2(ins, ins)]:
				check(not text.intersects(Rect2(c, Vector2(ins, ins))), "%s %s: label off the corner at %s" % [k, f, c])
		for s: String in LONG_LABELS:
			var b: Button = DDUi.button(s, Color("1f4a63"), DDUi.FONT_M)
			eq(b.alignment, HORIZONTAL_ALIGNMENT_CENTER, "%s: '%s' is centred" % [k, s])
			var n: StyleBox = b.get_theme_stylebox("normal")
			check(n.get_content_margin(SIDE_LEFT) >= Kit.inset("dd_btn_") + Kit.GAP - 0.01, "%s: '%s' clears the corners" % [k, s])
			b.free()
	_restore()


func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_contrast_on_every_fill() -> void:
	for fam: String in Kit.FLAT_FILL:
		var fill: Color = Kit.FLAT_FILL[fam]
		check(_contrast(DDUi.TEXT, fill) >= 4.5, "b %s: bone text 4.5:1 (%.2f)" % [fam, _contrast(DDUi.TEXT, fill)])
		var hov: Color = Kit.Layers._tinted(fill, Color(1.12, 1.12, 1.12))
		check(_contrast(DDUi.TEXT, hov) >= 4.5, "b %s hover: 4.5:1 (%.2f)" % [fam, _contrast(DDUi.TEXT, hov)])
	for fam2: String in Kit.RIM_COLOR:
		# c: the body over the dark page, pressed tint included
		var body: Color = DDUi.BG.lerp(Color(Kit.RIM_COLOR[fam2], 1.0), 0.26)
		check(_contrast(DDUi.TEXT, body) >= 4.5, "c %s pressed: 4.5:1 (%.2f)" % [fam2, _contrast(DDUi.TEXT, body)])
	for f: Color in [Color("f2c14e"), Color("6fd08a")]:
		check(_contrast(DDUi.BG, f) >= 4.5, "dark words on the USE / afford plates")
	for tg: String in ["yellow", "red", "bone"]:
		check(_contrast(DDUi.BG, Kit.TAG_FILL[tg]) >= 4.5, "dark words on the %s tag" % tg)
	check(_contrast(DDUi.TEXT, Kit.TAG_FILL["boss"]) >= 4.5, "bone words on the boss tag")


func test_setting_and_settings_row_switch_the_skin() -> void:
	var path: String = "user://dd_test_skins_%d.json" % Time.get_ticks_usec()
	var p: DDProfile = DDProfile.new(bal(), path)
	eq(str(p.setting("ui_skin")), "", "no choice yet: the studio default")
	check(p.set_setting("ui_skin", "C"), "ui_skin is a setting")
	eq(str(p.setting("ui_skin")), "c", "stored lower case")
	var p2: DDProfile = DDProfile.new(bal(), path)
	p2.load_profile()
	eq(str(p2.setting("ui_skin")), "c", "saved in the profile")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game: Node = tree.root.get_node_or_null("Game")
	if game == null:
		check(false, "Game autoload missing")
		return
	var keep: DDProfile = game.get("profile")
	game.set("profile", DDProfile.new(bal(), path))
	var sp: Control = (load("res://scripts/ui/dd_settings_panel.gd") as GDScript).new()
	tree.root.add_child(sp)
	sp.call("open")
	var row: Node = sp.find_child("UiStyle", true, false)
	check(row != null, "Settings has a UI style row")
	for k: String in Kit.SKINS:
		check(sp.find_child("Skin_" + k, true, false) != null, "UI style offers %s" % k)
	var bc: Button = sp.find_child("Skin_c", true, false) as Button
	if bc != null:
		bc.pressed.emit()
		eq(Kit.skin, "c", "tapping Minimal frame switches the skin")
		eq(str((game.get("profile") as DDProfile).setting("ui_skin")), "c", "and saves it")
	sp.queue_free()
	game.set("profile", keep)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_restore()
