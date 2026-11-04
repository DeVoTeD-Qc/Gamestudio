# duel_theme.gd
# Purpose: Theme for the duel screen (cc07): cc14's wall_theme.tres (fonts, palette, buttons,
#   score labels, WallSlot panels) plus the few duel-only type variations it does not define.
#   Anything wall_theme.tres defines wins; this file only fills gaps, and builds the slot BUTTON
#   styles from cc14's WallSlot / WallSlotValid panel styles so slots look like the art kit.
#   USED lists every variation the duel scenes use (tests/test_duel_layout.gd checks them).
# Dependencies: assets/themes/wall_theme.tres, ArtKit (scripts/art/art_kit.gd).
# Author: UI/UX Agent (cc07)
extends RefCounted

const WALL_THEME_PATH: String = "res://assets/themes/wall_theme.tres"

## Variations the duel scenes use -> base type. cc14 owns: ScorePlayer, ScoreRival,
## ScorePlayerPanel, ScoreRivalPanel, InspectorPanel, PrimaryButton, TraitName, Caption.
const USED: Dictionary = {
	&"ScorePlayer": &"Label", &"ScoreRival": &"Label", &"ScorePlayerPanel": &"PanelContainer",
	&"ScoreRivalPanel": &"PanelContainer", &"InspectorPanel": &"PanelContainer", &"PrimaryButton": &"Button",
	&"TraitName": &"Label", &"Caption": &"Label",
	# duel-only (filled here when wall_theme lacks them)
	&"SlotId": &"Label", &"CounterName": &"Label", &"RibbonText": &"Label", &"TurnTitle": &"Label",
	&"InspectorName": &"Label", &"InspectorBody": &"Label", &"InspectorHeading": &"Label",
	&"InspectorValue": &"Label", &"WallPanel": &"PanelContainer", &"TurnPanel": &"PanelContainer",
	&"SlotButton": &"Button", &"SlotButtonValid": &"Button", &"HandCard": &"Button", &"ActionButton": &"Button",
}

static var _cache: Theme = null


static func build() -> Theme:
	if _cache != null:
		return _cache
	var t: Theme
	var wall: Theme = load(WALL_THEME_PATH) as Theme if ResourceLoader.exists(WALL_THEME_PATH) else null
	if wall != null:
		t = wall.duplicate()
	else:
		push_warning("DuelTheme: %s missing; duel uses engine defaults plus its own variations" % WALL_THEME_PATH)
		t = Theme.new()
		t.default_font_size = 18
	var display: Font = ArtKit.font_display()
	var body: Font = ArtKit.font_body()
	var numeral: Font = ArtKit.font_numeral()

	_label(t, &"SlotId", 16, Color(ArtKit.TEXT_DIM, 0.8), display)
	_label(t, &"CounterName", 18, ArtKit.TEXT, display)
	_label(t, &"RibbonText", 16, ArtKit.SIGNATURE, body)
	_label(t, &"TurnTitle", 26, ArtKit.AMBER, display)
	_label(t, &"InspectorName", 32, ArtKit.TEXT, display)
	_label(t, &"InspectorBody", 18, ArtKit.TEXT, body)
	_label(t, &"InspectorHeading", 18, ArtKit.AMBER, display)
	_label(t, &"InspectorValue", 34, ArtKit.TEXT, numeral)
	_label(t, &"Caption", 16, ArtKit.TEXT_DIM, body)
	_label(t, &"TraitName", 22, ArtKit.TEXT, display)

	_panel(t, &"WallPanel", _box(ArtKit.BRICK, ArtKit.MORTAR, 2, 6, 12))
	_panel(t, &"TurnPanel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	_panel(t, &"InspectorPanel", _box(Color("#1C1F26"), ArtKit.AMBER, 2, 8, 16))
	_panel(t, &"ScorePlayerPanel", _box(Color("#173332"), ArtKit.PLAYER, 3, 6, 12))
	_panel(t, &"ScoreRivalPanel", _box(Color("#3A201C"), ArtKit.RIVAL, 3, 6, 12))
	if not t.has_font_size(&"font_size", &"ScorePlayer"):
		_label(t, &"ScorePlayer", 44, ArtKit.PLAYER, numeral)
		_label(t, &"ScoreRival", 44, ArtKit.RIVAL, numeral)

	# Counters: keep the score row inside a 64 px bar (cc14 panels may carry bigger margins).
	for v: StringName in [&"ScorePlayerPanel", &"ScoreRivalPanel"]:
		var sb: StyleBox = t.get_stylebox(&"panel", v).duplicate()
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		t.set_stylebox(&"panel", v, sb)

	# Slot buttons from cc14's WallSlot panels. Hover never carries information: hover = normal.
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), ArtKit.AMBER, 3, 6, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	var slot: StyleBox = t.get_stylebox(&"panel", &"WallSlot") if t.has_stylebox(&"panel", &"WallSlot") \
			else _box(ArtKit.BRICK, Color(ArtKit.TEXT, 0.28), 2, 4, 0)
	var valid: StyleBox = t.get_stylebox(&"panel", &"WallSlotValid") if t.has_stylebox(&"panel", &"WallSlotValid") \
			else _box(Color(ArtKit.AMBER, 0.14), ArtKit.AMBER, 3, 4, 0)
	_button(t, &"SlotButton", slot, focus, ArtKit.TEXT_DIM, 16)
	_button(t, &"SlotButtonValid", valid, focus, ArtKit.AMBER, 16)
	_button(t, &"HandCard", StyleBoxEmpty.new(), focus, ArtKit.TEXT, 16)
	if not t.has_stylebox(&"normal", &"ActionButton"):
		var src: StringName = &"GhostButton" if t.has_stylebox(&"normal", &"GhostButton") else &""
		if src != &"":
			t.set_type_variation(&"ActionButton", &"Button")
			for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
				t.set_stylebox(st, &"ActionButton", t.get_stylebox(st, src))
			for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
					&"font_hover_pressed_color", &"font_disabled_color"]:
				t.set_color(c, &"ActionButton", t.get_color(c, src))
		else:
			_button(t, &"ActionButton", _box(Color("#262A32"), Color(ArtKit.TEXT, 0.4), 2, 6, 10), focus, ArtKit.TEXT, 20)
		t.set_font_size(&"font_size", &"ActionButton", 20)
		t.set_font(&"font", &"ActionButton", display)
	if not t.has_stylebox(&"normal", &"PrimaryButton"):
		_button(t, &"PrimaryButton", _box(ArtKit.AMBER, ArtKit.AMBER, 2, 6, 10), focus, ArtKit.ENAMEL, 22)
	for v: StringName in USED:
		if t.get_type_variation_base(v) == &"":
			t.set_type_variation(v, USED[v])
	_cache = t
	return t


## Sets a label variation unless wall_theme already defines it.
static func _label(t: Theme, v: StringName, size: int, color: Color, font: Font) -> void:
	if t.get_type_variation_base(v) != &"" and t.has_font_size(&"font_size", v):
		return
	t.set_type_variation(v, &"Label")
	t.set_font_size(&"font_size", v, size)
	t.set_color(&"font_color", v, color)
	t.set_font(&"font", v, font)


static func _panel(t: Theme, v: StringName, box: StyleBox) -> void:
	if t.has_stylebox(&"panel", v):
		return
	t.set_type_variation(v, &"PanelContainer")
	t.set_stylebox(&"panel", v, box)


static func _button(t: Theme, v: StringName, normal: StyleBox, focus: StyleBox, font_color: Color, size: int) -> void:
	t.set_type_variation(v, &"Button")
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(state, v, normal)
	t.set_stylebox(&"focus", v, focus)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		t.set_color(c, v, font_color)
	t.set_font_size(&"font_size", v, size)


static func _box(bg: Color, border: Color, border_w: int, radius: int, margin: float) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b
