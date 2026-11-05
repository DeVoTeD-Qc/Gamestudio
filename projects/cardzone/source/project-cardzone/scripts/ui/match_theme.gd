# match_theme.gd
# Purpose: Match screen theme (cz10): cz16's assets/themes/cardzone_theme.tres (Barlow fonts, palette,
#   its own variations) plus the few match-only variations below (top-bar buttons, panels, tags).
#   Colours are the cz15 palette tokens (documentation/art/style-guides/art-direction.md §1-§2).
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
## "becomes" in UI text ("HEALTH 5 -> 3"). The bundled fonts have no U+2192 arrow (cz19b BUG-04),
## so it is spelled with ASCII; tests/test_ui_glyphs.gd checks every UI string against the fonts.
const ARROW: String = "->"
const FONT_NUMBER: int = 24    # key numbers (cost, Brace, health): >= 24 px
const FONT_TITLE: int = 24

## theme_type_variation -> base type. Tests check each one is defined and styled.
const USED: Dictionary = {
	&"TopButton": &"Button", &"InfoPanelButton": &"Button", &"TileButton": &"Button", &"LineChip": &"Button",
	&"MatchPanel": &"PanelContainer", &"InspectorPanel": &"PanelContainer",
	&"Caption": &"Label", &"CaptionStrong": &"Label", &"KeyNumber": &"Label",
	&"TagBounty": &"Label", &"TagDown": &"Label", &"TagChip": &"Label",
	&"TagChipNow": &"Label", &"TagChipGas": &"Label", &"InspectorTitle": &"Label", &"InspectorBody": &"Label",
	# cz11: action dock, map-corner buttons, pools tag, toast.
	&"DockButton": &"Button", &"DockButtonOff": &"Button", &"CornerButton": &"Button",
	&"DockPanel": &"PanelContainer", &"ToastPanel": &"PanelContainer", &"PoolTag": &"Label", &"ToastText": &"Label",
	&"TurnPanel": &"PanelContainer", &"PhaseTitle": &"Label", &"FeedNew": &"Label", &"FeedOld": &"Label", &"DeckButton": &"Button",
}


const BASE_THEME: String = "res://assets/themes/cardzone_theme.tres"


static func build() -> Theme:
	var base: Theme = load(BASE_THEME) as Theme if ResourceLoader.exists(BASE_THEME) else null
	var t: Theme = base.duplicate() if base != null else Theme.new()
	t.default_font_size = FONT_BODY
	t.set_color(&"font_color", &"Label", PAPER)

	# Buttons: hover == normal (no hover-only information); a visible focus ring for keys/pads.
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), ZONE_EDGE, 3, 6)
	focus.draw_center = false
	for v: StringName in [&"Button", &"TopButton", &"InfoPanelButton", &"LineChip", &"DockButton", &"DockButtonOff", &"CornerButton", &"DeckButton"]:
		var normal: StyleBoxFlat = _box(ZONE_DUSK, ZONE_EDGE, 2, 6, 10)
		var pressed: StyleBoxFlat = _box(ZONE_VIOLET, ZONE_EDGE, 2, 6, 10)
		var disabled: StyleBoxFlat = _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.35), 2, 6, 10)
		if v == &"DockButton":
			# The thing to do: a light plate (paper on ink), the strongest button on screen.
			normal = _box(PAPER, INK, 2, 6, 4)
			pressed = _box(BRACE_STEEL, INK, 3, 6, 4)
		if v == &"DockButtonOff":
			# Not possible now: dark plate, dashed-looking thin border; a tap says why.
			normal = _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.45), 1, 6, 4)
			pressed = _box(ZONE_VIOLET, ZONE_EDGE, 1, 6, 4)
		if v == &"CornerButton":
			normal = _box(ZONE_DUSK, ZONE_EDGE, 2, 6, 4)
			pressed = _box(ZONE_VIOLET, ZONE_EDGE, 3, 6, 4)
		if v == &"LineChip":
			normal = _box(PAPER, INK, 2, 4, 8, 4)
			pressed = _box(BRACE_STEEL, INK, 2, 4, 8, 4)
		if v == &"DeckButton":
			# cz-clarity: the deck pile row (tap to peek at the next hand): a quiet plate.
			normal = _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.55), 2, 6, 10, 4)
			pressed = _box(ZONE_DUSK, ZONE_EDGE, 2, 6, 10, 4)
		if v == &"InfoPanelButton":
			normal = _box(ZONE_DUSK, Color(ZONE_EDGE, 0.55), 2, 6, 8)
			pressed = _box(ZONE_VIOLET, ZONE_EDGE, 2, 6, 8)
		t.set_stylebox(&"normal", v, normal)
		t.set_stylebox(&"hover", v, normal)
		t.set_stylebox(&"pressed", v, pressed)
		t.set_stylebox(&"hover_pressed", v, pressed)
		t.set_stylebox(&"disabled", v, disabled)
		t.set_stylebox(&"focus", v, focus)
		var fc: Color = INK if (v == &"LineChip" or v == &"DockButton") else PAPER
		t.set_color(&"font_color", v, fc)
		t.set_color(&"font_hover_color", v, fc)
		t.set_color(&"font_pressed_color", v, fc)
		t.set_color(&"font_focus_color", v, fc)
		t.set_color(&"font_disabled_color", v, Color(PAPER, 0.5))
		t.set_font_size(&"font_size", v, FONT_BODY)
		if v != &"Button":
			t.set_type_variation(v, &"Button")
	# Tile overlay buttons draw nothing (the cz16 tile draws); focus ring only.
	for v: StringName in [&"TileButton"]:
		t.set_type_variation(v, &"Button")
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for s: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(s, v, empty)
		t.set_stylebox(&"focus", v, focus)
		t.set_font_size(&"font_size", v, FONT_BODY)

	_panel(t, &"MatchPanel", _box(ZONE_DUSK, Color(ZONE_EDGE, 0.45), 2, 6, 8))
	_panel(t, &"InspectorPanel", _box(ZONE_DUSK, ZONE_EDGE, 2, 8, 12))
	_panel(t, &"DockPanel", _box(ZONE_DUSK, ZONE_EDGE, 2, 6, 8))
	_panel(t, &"ToastPanel", _box(PAPER, INK, 2, 4, 8, 2))

	_label(t, &"Caption", Color(PAPER, 0.86), FONT_BODY)
	_label(t, &"CaptionStrong", PAPER, FONT_BODY)
	_label(t, &"KeyNumber", PAPER, FONT_NUMBER)
	_label(t, &"InspectorTitle", PAPER, FONT_TITLE)
	_label(t, &"InspectorBody", PAPER, FONT_BODY)
	# Tags: text + shape, never colour alone.
	_label(t, &"TagBounty", INK, FONT_BODY, _box(Color("#FFEE80"), INK, 1, 3, 3, 0))
	_label(t, &"TagDown", INK, FONT_BODY, _box(HIT_RED, INK, 1, 3, 3, 0))
	_label(t, &"TagChip", PAPER, FONT_BODY, _box(ZONE_VIOLET, Color(ZONE_EDGE, 0.6), 1, 3, 5, 0))
	_label(t, &"TagChipNow", INK, FONT_BODY, _box(PAPER, INK, 1, 3, 5, 0))
	_label(t, &"TagChipGas", INK, FONT_BODY, _box(GAS_LIME, INK, 1, 3, 5, 0))
	_label(t, &"PoolTag", PAPER, FONT_BODY, _box(Color(ZONE_VIOLET, 0.92), Color(ZONE_EDGE, 0.6), 1, 4, 2, 2))
	_label(t, &"ToastText", INK, FONT_BODY)
	# cz-clarity: the turn panel (what to do now + what just happened).
	_panel(t, &"TurnPanel", _box(Color(ZONE_VIOLET, 0.6), Color(ZONE_EDGE, 0.35), 1, 6, 10, 6))
	_label(t, &"PhaseTitle", PAPER, FONT_TITLE - 4)
	_label(t, &"FeedNew", PAPER, FONT_BODY)
	_label(t, &"FeedOld", Color(PAPER, 0.62), FONT_BODY)
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
