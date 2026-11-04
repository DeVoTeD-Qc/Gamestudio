# hub_ui.gd
# Purpose: Small shared helpers for the cc13 screens (hub, Lobby Duel, "Match starting"): notch-safe
#   margins (same rule as the duel screen), themed labels and buttons, and short time / age words.
#   Tap targets are 64 logical px (>= 46 pt on an 844x390 phone); text uses theme variations of
#   16 px and up (>= 11.5 pt), the same floor tests/test_duel_layout.gd checks.
# Dependencies: screen_profile.gd, duel_setup.gd (rival names).
# Author: Mechanics Developer Agent
extends RefCounted

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")

const BASE_MARGIN: Vector2 = Vector2(32, 18)
const BASE_MARGIN_COMPACT: Vector2 = Vector2(16, 10)
const TAP: float = 64.0


static func is_compact(c: Control) -> bool:
	return c.get_viewport_rect().size.y < ScreenProfile.COMPACT_HEIGHT


## [left-top, right-bottom] margins in logical px: the base margin, grown to the device safe area
## on phones (or to override, a safe rect in logical px, for tests and previews).
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


static func button(node_name: String, text: String, variation: StringName = &"ActionButton",
		min_size: Vector2 = Vector2(0, TAP)) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(maxf(min_size.x, TAP), maxf(min_size.y, TAP))
	b.clip_text = false
	return b


## 75 -> "1:15".
static func clock(seconds: float) -> String:
	var s: int = maxi(int(seconds), 0)
	return "%d:%02d" % [s / 60, s % 60]


## How long ago something was saved, in words.
static func age_words(age_s: float) -> String:
	if age_s < 60.0:
		return "just now"
	if age_s < 3600.0:
		return "%d min ago" % int(age_s / 60.0)
	if age_s < 86400.0:
		return "%d h ago" % int(age_s / 3600.0)
	return "%d days ago" % int(age_s / 86400.0)


static func rival_name(rival_id: StringName) -> String:
	for r: Dictionary in DuelSetup.rivals():
		if r["id"] == rival_id:
			return String(r["name"])
	return "a rival" if rival_id == &"" else String(rival_id).capitalize()


## "win" / "loss" / "draw" -> a sentence for the banner after a quick duel ends.
static func result_words(word: StringName) -> String:
	match word:
		&"win":
			return "You won the quick duel."
		&"loss":
			return "You lost the quick duel."
		&"draw":
			return "The quick duel was a draw."
	return "The quick duel is over."


## Result word from WallRules.final_result() (winner P1 / P2 / NO_PLAYER for a draw).
static func result_word(result: Dictionary) -> StringName:
	var w: int = int(result.get("winner", WallState.NO_PLAYER))
	return &"draw" if w == WallState.NO_PLAYER else (&"win" if w == WallState.P1 else &"loss")
