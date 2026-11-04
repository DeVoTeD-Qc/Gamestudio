# album_theme.gd
# Purpose: Theme for the Album (cc11): the duel theme (cc14's wall_theme.tres plus cc07's inspector
#   variations, so the shared CardInspector looks the same) plus the album-only variations below.
#   art-direction.md section 5: a velvet portfolio (AlbumPage from wall_theme), hint text in the
#   Handwritten face, a brass 4-dial Cipher Lock. Hover never carries information (hover = normal).
#   USED lists every variation the album scenes and scripts use (tests/test_album_layout.gd checks).
# Dependencies: scripts/ui/duel_theme.gd, ArtKit.
# Author: UI/UX Agent (cc11)
extends RefCounted

const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")

const BRASS: Color = Color("#B98A3E")
const BRASS_HI: Color = Color("#F0CE84")
const BRASS_DEEP: Color = Color("#3A2A12")

## Variation -> base type, for everything the album uses (wall_theme / DuelTheme ones included).
const USED: Dictionary = {
	&"AlbumPage": &"PanelContainer", &"InspectorPanel": &"PanelContainer", &"Heading": &"Label",
	&"Subheading": &"Label", &"Body": &"Label", &"Caption": &"Label", &"Handwritten": &"Label",
	&"PrimaryButton": &"Button", &"GhostButton": &"Button", &"ActionButton": &"Button",
	&"InspectorName": &"Label", &"InspectorBody": &"Label", &"InspectorHeading": &"Label",
	&"InspectorValue": &"Label",
	# album-only (built here)
	&"AlbumTab": &"Button", &"AlbumHanger": &"Button", &"DialButton": &"Button", &"DialFace": &"Button",
	&"CipherPanel": &"PanelContainer", &"TriptychFrame": &"PanelContainer", &"ToastPanel": &"PanelContainer",
	&"GoalLabel": &"Label", &"AlbumCount": &"Label", &"RevealTitle": &"Label",
}

static var _cache: Theme = null


static func build() -> Theme:
	if _cache != null:
		return _cache
	var t: Theme = (DuelTheme.build() as Theme).duplicate()
	var display: Font = ArtKit.font_display()
	var body: Font = ArtKit.font_body()
	var numeral: Font = ArtKit.font_numeral()
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), ArtKit.AMBER, 3, 8, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(3)

	# Page tabs: the theme's Button (enamel, amber edge; pressed = solid amber) at tab size.
	t.set_type_variation(&"AlbumTab", &"Button")
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		if t.has_stylebox(st, &"Button"):
			var sb: StyleBox = t.get_stylebox(st, &"Button").duplicate()
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			t.set_stylebox(st, &"AlbumTab", sb)
	t.set_stylebox(&"hover", &"AlbumTab", t.get_stylebox(&"normal", &"AlbumTab"))
	t.set_stylebox(&"hover_pressed", &"AlbumTab", t.get_stylebox(&"pressed", &"AlbumTab"))
	t.set_font(&"font", &"AlbumTab", display)
	t.set_font_size(&"font_size", &"AlbumTab", 20)
	t.set_constant(&"h_separation", &"AlbumTab", 8)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		t.set_color(c, &"AlbumTab", ArtKit.TEXT)
	for c: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(c, &"AlbumTab", ArtKit.WALL)

	# Card hangers: the BannerCard is the face; only the focus ring is drawn.
	_button(t, &"AlbumHanger", StyleBoxEmpty.new(), focus, ArtKit.TEXT, 16, display)

	# Cipher Lock: brass mechanism, enamel arrow keys, brass dial faces.
	var dial_btn: StyleBoxFlat = _box(Color("#1E2026"), Color(BRASS, 0.9), 2, 8, 6)
	var dial_btn_down: StyleBoxFlat = _box(BRASS, BRASS_HI, 2, 8, 6)
	_button(t, &"DialButton", dial_btn, focus, BRASS_HI, 20, display)
	t.set_stylebox(&"pressed", &"DialButton", dial_btn_down)
	t.set_stylebox(&"hover_pressed", &"DialButton", dial_btn_down)
	var face: StyleBoxFlat = _box(BRASS_DEEP, BRASS, 4, 12, 8)
	face.shadow_color = Color(0, 0, 0, 0.5)
	face.shadow_size = 4
	_button(t, &"DialFace", face, focus, BRASS_HI, 20, display)
	var cp: StyleBoxFlat = _box(Color("#221A10"), BRASS, 3, 12, 18)
	cp.border_width_top = 5
	_panel(t, &"CipherPanel", cp)

	# Triptych slots: three joined empty frames on velvet.
	_panel(t, &"TriptychFrame", _box(Color(0, 0, 0, 0.28), Color(BRASS, 0.55), 2, 6, 8))
	_panel(t, &"ToastPanel", _box(Color("#1C1F26", 0.97), ArtKit.AMBER, 2, 8, 14))

	_label(t, &"GoalLabel", 18, ArtKit.AMBER, body)
	_label(t, &"AlbumCount", 24, ArtKit.TEXT, numeral)
	_label(t, &"RevealTitle", 40, ArtKit.SIGNATURE, display)
	for v: StringName in USED:
		if t.get_type_variation_base(v) == &"":
			t.set_type_variation(v, USED[v])
	_cache = t
	return t


static func _label(t: Theme, v: StringName, size: int, color: Color, font: Font) -> void:
	t.set_type_variation(v, &"Label")
	t.set_font_size(&"font_size", v, size)
	t.set_color(&"font_color", v, color)
	t.set_font(&"font", v, font)


static func _panel(t: Theme, v: StringName, box: StyleBox) -> void:
	t.set_type_variation(v, &"PanelContainer")
	t.set_stylebox(&"panel", v, box)


static func _button(t: Theme, v: StringName, normal: StyleBox, focus: StyleBox, font_color: Color, size: int, font: Font) -> void:
	t.set_type_variation(v, &"Button")
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(state, v, normal)
	t.set_stylebox(&"focus", v, focus)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		t.set_color(c, v, font_color)
	t.set_font_size(&"font_size", v, size)
	t.set_font(&"font", v, font)


static func _box(bg: Color, border: Color, border_w: int, radius: int, margin: float) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	b.anti_aliasing = true
	return b
