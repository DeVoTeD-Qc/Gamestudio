# duel_placeholder_theme.gd
# Purpose: Placeholder Theme for the duel layout (cc07) until cc14's wall_theme.tres lands.
#   Built in code so there is no hand-kept .tres. It defines every theme type variation the duel
#   scenes use (VARIATIONS); cc14's theme must define the same names (tests/test_duel_layout.gd
#   checks whichever theme DuelScreen applies). Colors: wall_palette.gd (art direction §4).
#   Sizes follow the phone rules: body text >= 16 px, key numbers >= 24 px.
# Hook for cc14: DuelScreen.pick_theme() uses WALL_THEME_PATH when that file exists and defines
#   all VARIATIONS; otherwise this placeholder (with a warning naming what is missing).
# Dependencies: wall_palette.gd.
# Author: UI/UX Agent (cc07)
extends RefCounted

const Palette: GDScript = preload("res://scripts/ui/wall_palette.gd")

const WALL_THEME_PATH: String = "res://assets/ui/wall_theme.tres"

## Every theme type variation the duel scenes and scripts use, with its base type.
const VARIATIONS: Dictionary = {
	# Labels
	&"CardName": &"Label", &"PipValue": &"Label", &"TraitWord": &"Label", &"TraitMark": &"Label",
	&"SlotId": &"Label", &"CounterName": &"Label", &"CounterScore": &"Label", &"RibbonText": &"Label",
	&"SubtleText": &"Label", &"TurnTitle": &"Label", &"HandHint": &"Label", &"InspectorName": &"Label",
	&"InspectorBody": &"Label", &"InspectorHeading": &"Label", &"InspectorValue": &"Label",
	&"ValueCaption": &"Label",
	# Panels
	&"CardFrameC1": &"PanelContainer", &"CardFrameC2": &"PanelContainer", &"CardFrameC3": &"PanelContainer",
	&"CardFrameC4": &"PanelContainer", &"CardFrameShowcase": &"PanelContainer", &"ValuePip": &"PanelContainer",
	&"TraitBadge": &"PanelContainer", &"WallPanel": &"PanelContainer", &"CounterPlayer": &"PanelContainer",
	&"CounterRival": &"PanelContainer", &"TurnPanel": &"PanelContainer", &"InspectorPanel": &"PanelContainer",
	# Buttons
	&"WallSlot": &"Button", &"WallSlotValid": &"Button", &"HandCard": &"Button",
	&"HandCardSelected": &"Button", &"ActionButton": &"Button", &"PrimaryButton": &"Button",
}


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 16
	t.set_color(&"font_color", &"Label", Palette.TEXT)
	for v: StringName in VARIATIONS:
		t.set_type_variation(v, VARIATIONS[v])

	var tight: FontVariation = FontVariation.new()
	tight.resource_name = "TightNumerals"
	tight.base_font = ThemeDB.fallback_font
	# Digits have no descenders: trim line height so two 24 px value rows fit a 64 px card.
	tight.spacing_top = -5
	tight.spacing_bottom = -4
	tight.variation_embolden = 0.6

	_label(t, &"CardName", 18, Palette.TEXT)
	_label(t, &"PipValue", 24, Palette.TEXT, tight)
	_label(t, &"TraitWord", 16, Palette.TEXT)
	_label(t, &"TraitMark", 16, Palette.ENAMEL, tight)
	_label(t, &"SlotId", 16, Color(Palette.TEXT_DIM, 0.85))
	_label(t, &"CounterName", 18, Palette.TEXT)
	_label(t, &"CounterScore", 40, Palette.TEXT, tight)
	_label(t, &"RibbonText", 16, Palette.SIGNATURE)
	_label(t, &"SubtleText", 16, Palette.TEXT_DIM)
	_label(t, &"TurnTitle", 24, Palette.AMBER)
	_label(t, &"HandHint", 16, Palette.TEXT_DIM)
	_label(t, &"InspectorName", 30, Palette.TEXT)
	_label(t, &"InspectorBody", 18, Palette.TEXT)
	_label(t, &"InspectorHeading", 16, Palette.AMBER)
	_label(t, &"InspectorValue", 32, Palette.TEXT, tight)
	_label(t, &"ValueCaption", 16, Palette.TEXT_DIM)

	# Card frames by Clearance (art direction §3, placeholder materials; cc14 replaces).
	t.set_stylebox(&"panel", &"CardFrameC1", _box(Color(0, 0, 0, 0), Color("#5B5F66"), 2, 4, 3))
	t.set_stylebox(&"panel", &"CardFrameC2", _box(Color(0, 0, 0, 0), Color("#A9B0B8"), 2, 4, 3))
	t.set_stylebox(&"panel", &"CardFrameC3", _box(Color(0, 0, 0, 0), Color("#B98A3E"), 3, 4, 3))
	t.set_stylebox(&"panel", &"CardFrameC4", _box(Color(0, 0, 0, 0), Color("#E2B34A"), 3, 4, 3))
	t.set_stylebox(&"panel", &"CardFrameShowcase", _box(Color(0, 0, 0, 0), Color("#E6E3DA"), 3, 4, 3))
	var pip: StyleBoxFlat = _box(Color(Palette.ENAMEL, 0.88), Color(Palette.TEXT, 0.35), 1, 6, 0)
	pip.content_margin_left = 5
	pip.content_margin_right = 5
	pip.content_margin_top = 1
	pip.content_margin_bottom = 1
	t.set_stylebox(&"panel", &"ValuePip", pip)
	var badge: StyleBoxFlat = _box(Color(Palette.TEXT, 0.9), Color(0, 0, 0, 0), 0, 4, 0)
	badge.content_margin_left = 4
	badge.content_margin_right = 4
	t.set_stylebox(&"panel", &"TraitBadge", badge)
	t.set_stylebox(&"panel", &"WallPanel", _box(Color("#1A1D23"), Palette.MORTAR, 2, 6, 12))
	var counter_p: StyleBoxFlat = _box(Color("#173332"), Palette.PLAYER, 3, 6, 12)
	var counter_r: StyleBoxFlat = _box(Color("#3A201C"), Palette.RIVAL, 3, 6, 12)
	for b: StyleBoxFlat in [counter_p, counter_r]:
		b.content_margin_top = 6
		b.content_margin_bottom = 6
	t.set_stylebox(&"panel", &"CounterPlayer", counter_p)
	t.set_stylebox(&"panel", &"CounterRival", counter_r)
	t.set_stylebox(&"panel", &"TurnPanel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4))
	t.set_stylebox(&"panel", &"InspectorPanel", _box(Color("#1C1F26"), Palette.AMBER, 2, 8, 16))

	# Buttons. Hover never carries information (touch first): hover = normal.
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), Palette.AMBER, 3, 6, 0)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	_button(t, &"WallSlot", _box(Color("#20232A"), Color(Palette.TEXT, 0.28), 2, 4, 0), focus, Palette.TEXT_DIM, 16)
	_button(t, &"WallSlotValid", _box(Color(Palette.AMBER, 0.14), Palette.AMBER, 3, 4, 0), focus, Palette.AMBER, 16)
	_button(t, &"HandCard", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 0), focus, Palette.TEXT, 16)
	var sel: StyleBoxFlat = _box(Color(Palette.AMBER, 0.12), Palette.AMBER, 3, 6, 0)
	sel.expand_margin_left = 4
	sel.expand_margin_top = 4
	sel.expand_margin_right = 4
	sel.expand_margin_bottom = 4
	_button(t, &"HandCardSelected", sel, focus, Palette.TEXT, 16)
	_button(t, &"ActionButton", _box(Color("#262A32"), Color(Palette.TEXT, 0.4), 2, 6, 10), focus, Palette.TEXT, 18)
	_button(t, &"PrimaryButton", _box(Palette.AMBER, Palette.AMBER, 2, 6, 10), focus, Palette.ENAMEL, 20)
	t.set_stylebox(&"disabled", &"PrimaryButton", _box(Color("#3A3833"), Color("#5A564C"), 2, 6, 10))
	t.set_color(&"font_disabled_color", &"PrimaryButton", Palette.TEXT_DIM)
	t.set_stylebox(&"disabled", &"ActionButton", _box(Color("#1E2127"), Color(Palette.TEXT, 0.15), 2, 6, 10))
	t.set_color(&"font_disabled_color", &"ActionButton", Palette.TEXT_DIM)
	return t


static func _label(t: Theme, v: StringName, size: int, color: Color, font: Font = null) -> void:
	t.set_font_size(&"font_size", v, size)
	t.set_color(&"font_color", v, color)
	if font != null:
		t.set_font(&"font", v, font)


static func _button(t: Theme, v: StringName, normal: StyleBox, focus: StyleBox, font_color: Color, size: int) -> void:
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
	b.content_margin_left = margin
	b.content_margin_right = margin
	b.content_margin_top = margin
	b.content_margin_bottom = margin
	return b
