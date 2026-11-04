# setup_ui.gd
# Purpose: Small shared kit for the cz13 shell screens (Title, Match setup, pause menu, end
#   screen, coach, dev panel): the theme (the match theme plus a few shell variations), buttons
#   and labels at the touch sizes, segmented choice rows and the safe-area margins.
#   Sizes: buttons >= 64 logical px tall (46 pt on the 844x390 phone, >= 44 pt everywhere the
#   screen profile allows), text >= 16 px (>= 11 pt). Selected choices are a light plate AND carry
#   a check mark, so the choice never depends on colour alone. Hover never carries information.
# Dependencies: match_theme.gd, CzArtKit (fonts, TAP_PT), screen_profile.gd.
# Author: UI/UX Agent (cz13)
extends RefCounted

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")

const TAP_PX: float = 64.0
const MARGIN: Vector2 = Vector2(32, 18)
const MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const CHECK: String = "✓ "

## Shell variations on top of MatchTheme (tests check each is styled).
const USED: Dictionary = {
	&"ShellTitle": &"Label", &"ShellHeading": &"Label", &"ShellBody": &"Label", &"ShellMuted": &"Label",
	&"ShellTag": &"Label", &"ShellWarn": &"Label", &"ShellPanel": &"PanelContainer",
	&"SegOn": &"Button", &"SegOff": &"Button", &"SegNo": &"Button",
}


static func build_theme() -> Theme:
	var t: Theme = MatchTheme.build()
	var display: Font = CzArtKit.font_display()
	_label(t, &"ShellTitle", MatchTheme.PAPER, 72, display)
	_label(t, &"ShellHeading", MatchTheme.PAPER, 28, display)
	_label(t, &"ShellBody", MatchTheme.PAPER, 18)
	_label(t, &"ShellMuted", Color(MatchTheme.PAPER, 0.8), 16)
	_label(t, &"ShellTag", MatchTheme.INK, 16, null, MatchTheme._box(MatchTheme.GAS_GLOW, MatchTheme.INK, 2, 3, 8, 2))
	_label(t, &"ShellWarn", MatchTheme.INK, 16, null, MatchTheme._box(Color("#FFB070"), MatchTheme.INK, 2, 3, 8, 4))
	t.set_type_variation(&"ShellPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"ShellPanel", MatchTheme._box(MatchTheme.ZONE_DUSK, MatchTheme.ZONE_EDGE, 2, 8, 20, 16))
	# Segmented choices: on = paper plate + check mark; off = dusk plate; no = not available (tap says why).
	_copy_button(t, &"DockButton", &"SegOn")
	_copy_button(t, &"Button", &"SegOff")
	_copy_button(t, &"DockButtonOff", &"SegNo")
	return t


static func button(text: String, variation: StringName = &"Button") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(TAP_PX * 2.0, TAP_PX)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func label(text: String, variation: StringName = &"ShellBody", wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Margins (left-top, right-bottom) in logical px for a full-screen shell page: the base margins
## grown to the notch insets (override = a safe rect in logical px, for tests and screenshots).
static func safe_margins(logical: Vector2, override: Rect2 = Rect2()) -> Array[Vector2]:
	var compact: bool = logical.y < 640.0
	var lt: Vector2 = MARGIN_COMPACT if compact else MARGIN
	var rb: Vector2 = lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area()) if on_phone else Rect2()
	if override.has_area():
		window = logical
		safe = override
	if safe.has_area() and window.x > 0.0 and window.y > 0.0:
		var to_canvas: Vector2 = logical / window
		lt = lt.max(safe.position * to_canvas)
		rb = rb.max((window - safe.end) * to_canvas)
	return [lt.ceil(), rb.ceil()]


static func apply_margins(box: MarginContainer, logical: Vector2, override: Rect2 = Rect2()) -> void:
	var m: Array[Vector2] = safe_margins(logical, override)
	box.add_theme_constant_override(&"margin_left", int(m[0].x))
	box.add_theme_constant_override(&"margin_top", int(m[0].y))
	box.add_theme_constant_override(&"margin_right", int(m[1].x))
	box.add_theme_constant_override(&"margin_bottom", int(m[1].y))


## Marks a segmented button on/off (variation and check mark). Keeps its base text in meta.
static func set_seg(b: Button, on: bool, available: bool = true) -> void:
	if not b.has_meta(&"base_text"):
		b.set_meta(&"base_text", b.text)
	var base: String = b.get_meta(&"base_text")
	b.text = (CHECK + base) if on else base
	b.theme_type_variation = &"SegNo" if not available else (&"SegOn" if on else &"SegOff")
	b.set_meta(&"on", on)


## A full-screen dim layer that swallows taps (modal overlays).
static func dim_layer(alpha: float = 0.72) -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.name = "Dim"
	c.color = Color(MatchTheme.INK, alpha)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func _label(t: Theme, v: StringName, color: Color, size: int, font: Font = null, box: StyleBox = null) -> void:
	t.set_type_variation(v, &"Label")
	t.set_color(&"font_color", v, color)
	t.set_font_size(&"font_size", v, size)
	if font != null:
		t.set_font(&"font", v, font)
	if box != null:
		t.set_stylebox(&"normal", v, box)


static func _copy_button(t: Theme, from: StringName, to: StringName) -> void:
	t.set_type_variation(to, &"Button")
	for s: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		if t.has_stylebox(s, from):
			t.set_stylebox(s, to, t.get_stylebox(s, from))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		if t.has_color(c, from):
			t.set_color(c, to, t.get_color(c, from))
	t.set_font_size(&"font_size", to, MatchTheme.FONT_BODY)
