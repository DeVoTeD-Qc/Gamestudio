# survey_ui.gd
# Adapted from CallingCard scripts/hub/hub_ui.gd (only the helpers the playtest screens need).
# Purpose: Small builders for the playtest consent prompt and survey screen (cz18): labels,
#   64 px tap-target buttons, the compact flag and safe-area margins (device safe area on phones,
#   or an override rect in logical px for tests and previews). Styling comes from MatchTheme.
# Dependencies: scripts/ui/screen_profile.gd.
# Author: Data Scientist Agent
extends RefCounted

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")

## Minimum tap target in logical px (>= 46 pt on every supported phone, see ScreenProfile).
const TAP: float = 64.0
const BASE_MARGIN: Vector2 = Vector2(32, 24)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)


static func is_compact(c: Control) -> bool:
	return c.get_viewport_rect().size.y < ScreenProfile.COMPACT_HEIGHT


## [left-top, right-bottom] margins in logical px: the base margin, grown to the device safe area
## on phones (or to override, a safe rect in logical px).
static func safe_margins(c: Control, override: Rect2 = Rect2()) -> Array[Vector2]:
	var logical: Vector2 = c.get_viewport_rect().size
	var lt: Vector2 = BASE_MARGIN_COMPACT if is_compact(c) else BASE_MARGIN
	var rb: Vector2 = lt
	var on_phone: bool = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	if on_phone or override.has_area():
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		if override.has_area():
			window = logical
			safe = override
		if window.x > 0.0 and window.y > 0.0 and safe.size.x > 0.0:
			var to_canvas: Vector2 = logical / window
			lt = lt.max(safe.position * to_canvas)
			rb = rb.max((window - safe.end) * to_canvas)
	return [lt, rb]


static func apply_margins(m: MarginContainer, lt: Vector2, rb: Vector2) -> void:
	m.add_theme_constant_override(&"margin_left", int(ceilf(lt.x)))
	m.add_theme_constant_override(&"margin_top", int(ceilf(lt.y)))
	m.add_theme_constant_override(&"margin_right", int(ceilf(rb.x)))
	m.add_theme_constant_override(&"margin_bottom", int(ceilf(rb.y)))


static func label(node_name: String, text: String, variation: StringName,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.name = node_name
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## variation: &"Button" (dark plate) or &"DockButton" (the light "do this" plate).
static func button(node_name: String, text: String, variation: StringName = &"Button",
		min_size: Vector2 = Vector2(0, TAP)) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(maxf(min_size.x, TAP), maxf(min_size.y, TAP))
	b.clip_text = false
	b.focus_mode = Control.FOCUS_ALL
	return b
