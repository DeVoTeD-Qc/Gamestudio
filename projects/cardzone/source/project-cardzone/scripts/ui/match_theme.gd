# match_theme.gd
# Purpose: Placeholder theme for the match screen (cz10), built in code from the cz15 palette
#   (documentation/art/style-guides/art-direction.md §1-§2). Every colour the match screen uses
#   is a token here, so cz16 can re-theme by swapping this file (or returning its own Theme from
#   build()) without touching layout code. Fonts are the engine default until cz16 adds Barlow.
#   Hover styles equal normal styles: hover never carries information (touch first).
# Usage: MatchScreen sets `theme = MatchTheme.build()`. Labels pick a variation by
#   theme_type_variation (USED lists every one; tests check each is styled).
# Dependencies: none.
# Author: UI/UX Agent (cz10)
extends RefCounted

# --- Palette tokens (art-direction.md §1) --------------------------------------
const ZONE_VIOLET: Color = Color("#2B1840")
const ZONE_DUSK: Color = Color("#45285F")
const ZONE_EDGE: Color = Color("#B49CFF")
const GAS_LIME: Color = Color("#9BD43A")
const GAS_GLOW: Color = Color("#E2FF8A")
const GAS_SHADE: Color = Color("#3E5A12")
const BASALT: Color = Color("#2F333B")
const DUNE: Color = Color("#D8C8A2")
const SHOAL: Color = Color("#2C6E7F")
const RUST: Color = Color("#B0573A")
const PAPER: Color = Color("#F4F1FF")
const INK: Color = Color("#1A1424")
const HIT_RED: Color = Color("#E5484D")
const BRACE_STEEL: Color = Color("#C9D3E0")

## Rarity chip colour and letter colour (art-direction.md §2). S = Starter (no chip).
const RARITY: Dictionary = {
	&"C": [Color("#3F4552"), PAPER], &"U": [Color("#0F7A70"), PAPER], &"R": [Color("#4C8AF2"), INK],
	&"E": [Color("#FFB070"), INK], &"L": [Color("#FFEE80"), INK], &"S": [Color(0, 0, 0, 0), INK],
}

# --- Font sizes (logical px; ScreenProfile keeps 1 px >= 0.69 pt) -----------------
const FONT_BODY: int = 16      # >= 11 pt on every supported screen
const FONT_NUMBER: int = 24    # key numbers (cost, Brace, health): >= 24 px
const FONT_TITLE: int = 24

## theme_type_variation -> base type. Tests check each one is defined and styled.
const USED: Dictionary = {
	&"TopButton": &"Button", &"CardButton": &"Button", &"TileButton": &"Button", &"InfoPanelButton": &"Button",
	&"MatchPanel": &"PanelContainer", &"InspectorPanel": &"PanelContainer",
	&"CardFace": &"PanelContainer", &"CardFaceHit": &"PanelContainer", &"CardFaceBack": &"PanelContainer",
	&"CardFaceStack": &"PanelContainer",
	&"Caption": &"Label", &"CaptionStrong": &"Label", &"KeyNumber": &"Label",
	&"CardText": &"Label", &"CardNumber": &"Label", &"CardName": &"Label",
	&"TagBounty": &"Label", &"TagDown": &"Label", &"TagHold": &"Label", &"TagGas": &"Label",
	&"TagDrop": &"Label", &"TagCover": &"Label", &"TagBrace": &"Label", &"TagChip": &"Label",
	&"TagChipNow": &"Label", &"TagChipGas": &"Label", &"TileName": &"Label", &"TileText": &"Label",
	&"InspectorTitle": &"Label", &"InspectorBody": &"Label",
}


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_BODY
	t.set_color(&"font_color", &"Label", PAPER)

	# Buttons: hover == normal (no hover-only information); a visible focus ring for keys/pads.
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), ZONE_EDGE, 3, 6)
	focus.draw_center = false
	for v: StringName in [&"Button", &"TopButton", &"InfoPanelButton"]:
		var normal: StyleBoxFlat = _box(ZONE_DUSK, ZONE_EDGE, 2, 6, 10)
		var pressed: StyleBoxFlat = _box(ZONE_VIOLET, ZONE_EDGE, 2, 6, 10)
		var disabled: StyleBoxFlat = _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.35), 2, 6, 10)
		if v == &"InfoPanelButton":
			normal = _box(ZONE_DUSK, Color(ZONE_EDGE, 0.55), 2, 6, 8)
			pressed = _box(ZONE_VIOLET, ZONE_EDGE, 2, 6, 8)
		t.set_stylebox(&"normal", v, normal)
		t.set_stylebox(&"hover", v, normal)
		t.set_stylebox(&"pressed", v, pressed)
		t.set_stylebox(&"hover_pressed", v, pressed)
		t.set_stylebox(&"disabled", v, disabled)
		t.set_stylebox(&"focus", v, focus)
		t.set_color(&"font_color", v, PAPER)
		t.set_color(&"font_hover_color", v, PAPER)
		t.set_color(&"font_pressed_color", v, PAPER)
		t.set_color(&"font_focus_color", v, PAPER)
		t.set_color(&"font_disabled_color", v, Color(PAPER, 0.5))
		t.set_font_size(&"font_size", v, FONT_BODY)
		if v != &"Button":
			t.set_type_variation(v, &"Button")
	# Card and tile buttons draw nothing themselves (the face / tile draws); focus ring only.
	for v: StringName in [&"CardButton", &"TileButton"]:
		t.set_type_variation(v, &"Button")
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for s: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(s, v, empty)
		t.set_stylebox(&"focus", v, focus)
		t.set_font_size(&"font_size", v, FONT_BODY)

	_panel(t, &"MatchPanel", _box(ZONE_DUSK, Color(ZONE_EDGE, 0.45), 2, 6, 8))
	_panel(t, &"InspectorPanel", _box(ZONE_DUSK, ZONE_EDGE, 2, 8, 12))
	var face: StyleBoxFlat = _box(PAPER, INK, 2, 6, 4)
	face.content_margin_left = 9  # room for the rarity stripe
	_panel(t, &"CardFace", face)
	_panel(t, &"CardFaceHit", _box(HIT_RED, INK, 2, 6, 4))
	_panel(t, &"CardFaceBack", _box(BASALT, ZONE_EDGE, 2, 6, 4))
	_panel(t, &"CardFaceStack", _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.7), 2, 6, 4))

	_label(t, &"Caption", Color(PAPER, 0.86), FONT_BODY)
	_label(t, &"CaptionStrong", PAPER, FONT_BODY)
	_label(t, &"KeyNumber", PAPER, FONT_NUMBER)
	_label(t, &"CardText", INK, FONT_BODY)
	_label(t, &"CardNumber", INK, FONT_NUMBER)
	_label(t, &"CardName", INK, FONT_BODY)
	_label(t, &"TileName", INK, FONT_BODY, _box(PAPER, INK, 1, 3, 2, 0))
	_label(t, &"TileText", INK, FONT_BODY)
	_label(t, &"InspectorTitle", PAPER, FONT_TITLE)
	_label(t, &"InspectorBody", PAPER, FONT_BODY)
	# Tags: text + shape, never colour alone.
	_label(t, &"TagBounty", INK, FONT_BODY, _box(Color("#FFEE80"), INK, 1, 3, 3, 0))
	_label(t, &"TagDown", INK, FONT_BODY, _box(HIT_RED, INK, 1, 3, 3, 0))
	_label(t, &"TagHold", INK, FONT_BODY, _box(ZONE_EDGE, INK, 1, 3, 3, 0))
	_label(t, &"TagGas", INK, FONT_BODY, _box(GAS_GLOW, INK, 1, 3, 3, 0))
	_label(t, &"TagDrop", INK, FONT_BODY, _box(Color("#FFB070"), INK, 1, 3, 3, 0))
	_label(t, &"TagCover", INK, FONT_BODY, _box(BRACE_STEEL, INK, 1, 3, 3, 0))
	_label(t, &"TagBrace", INK, FONT_NUMBER, _box(BRACE_STEEL, INK, 1, 8, 4, 0))
	_label(t, &"TagChip", PAPER, FONT_BODY, _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.6), 1, 3, 5, 0))
	_label(t, &"TagChipNow", INK, FONT_BODY, _box(PAPER, INK, 1, 3, 5, 0))
	_label(t, &"TagChipGas", INK, FONT_BODY, _box(GAS_LIME, INK, 1, 3, 5, 0))
	return t


static func rarity_colors(rarity: StringName) -> Array:
	return RARITY.get(rarity, RARITY[&"S"])


static func _box(bg: Color, border: Color, bw: int, radius: int, pad_x: int = 6, pad_y: int = -1) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(radius)
	b.content_margin_left = pad_x
	b.content_margin_right = pad_x
	var py: int = pad_x if pad_y < 0 else pad_y
	b.content_margin_top = py
	b.content_margin_bottom = py
	return b


static func _panel(t: Theme, v: StringName, box: StyleBox) -> void:
	t.set_type_variation(v, &"PanelContainer")
	t.set_stylebox(&"panel", v, box)


static func _label(t: Theme, v: StringName, color: Color, size: int, box: StyleBox = null) -> void:
	t.set_type_variation(v, &"Label")
	t.set_color(&"font_color", v, color)
	t.set_font_size(&"font_size", v, size)
	if box != null:
		t.set_stylebox(&"normal", v, box)
