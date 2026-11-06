# screen_profile.gd
# Purpose: Picks the canvas base size (root content_scale_size) from the real screen so the UI is
#   readable on phones. project.godot keeps a 1280x720 base with canvas_items + expand; on a
#   screen shorter than 540 points that base would shrink everything to ~0.54x (an 844x390
#   iPhone in landscape gave 8.7 pt text and 35 pt tap targets). Instead the base height drops
#   toward MIN_BASE_HEIGHT so one logical px is never less than MIN_POINTS_PER_PX points:
#     base_h = clamp(fitted_height_pt / (MIN_POINTS_PER_PX * ui_scale), 540, 720), base_w = base_h * 16/9
#   - 1280x720 desktop window: base stays 1280x720 (scale 1.0, unchanged).
#   - 844x390 iPhone landscape: base 960x540 -> logical canvas 1168x540, 0.722 pt per logical px.
#   The match screen switches to its compact layout when the logical height is below 640.
#   kc-portrait: a portrait window (taller than wide) gets a 9:16 base by the same rule (390x844
#   iPhone portrait: base 540x960, logical canvas 540x1168) and the match screen's portrait layout.
#   Points = physical px / DisplayServer.screen_get_scale() (devicePixelRatio on the web,
#   the UIScreen scale on iOS / Xogot, 2 on a Retina Mac, 1 on most desktops).
# Usage: Settings applies it at startup and on every window resize (ScreenProfile.apply(root)).
#   Tests call the pure functions (base_size, logical_size, points_per_px).
# Dependencies: none.
# Author: UI/UX Agent (f01)
extends RefCounted

const DESIGN_SIZE: Vector2 = Vector2(1280, 720)
const MIN_BASE_HEIGHT: float = 540.0
## Smallest on-screen size of one logical px, in points (iOS pt / CSS px). 16 px body text
## then never drops below 0.72 * 16 = 11.5 pt on any screen 405 pt tall or more, and 64 px tap
## targets stay >= 46 pt. Shorter screens hit the 540 floor and scale a little lower.
const MIN_POINTS_PER_PX: float = 0.75
## Below this logical height the match screen uses its compact (phone) layout.
const COMPACT_HEIGHT: float = 640.0


## Canvas base size for a window of window_px physical pixels on a screen with this scale.
static func base_size(window_px: Vector2, screen_scale: float = 1.0, ui_scale: float = 1.0) -> Vector2:
	var pts: Vector2 = window_px / maxf(screen_scale, 0.01)
	if pts.y > pts.x:
		# kc-portrait: a tall window gets the same rule turned 90 degrees (a 9:16 base, 540..720 wide):
		# a 390x844 iPhone in portrait -> base 540x960 -> logical canvas 540x1168, 0.722 pt per px.
		var fitted_w: float = minf(pts.x, pts.y * DESIGN_SIZE.y / DESIGN_SIZE.x)
		var bw: float = roundf(clampf(fitted_w / (MIN_POINTS_PER_PX * maxf(ui_scale, 0.1)), MIN_BASE_HEIGHT, DESIGN_SIZE.y))
		return Vector2(bw, roundf(bw * DESIGN_SIZE.x / DESIGN_SIZE.y))
	# Height the 16:9 design box gets on this screen (narrow screens are limited by width).
	var fitted_h: float = minf(pts.y, pts.x * DESIGN_SIZE.y / DESIGN_SIZE.x)
	var h: float = clampf(fitted_h / (MIN_POINTS_PER_PX * maxf(ui_scale, 0.1)), MIN_BASE_HEIGHT, DESIGN_SIZE.y)
	h = roundf(h)
	return Vector2(roundf(h * DESIGN_SIZE.x / DESIGN_SIZE.y), h)


## Logical canvas size that canvas_items + expand produces for this window and base.
static func logical_size(window_px: Vector2, base: Vector2) -> Vector2:
	var s: float = stretch(window_px, base)
	return (window_px / s).floor()


## Physical px per logical px (the canvas_items stretch factor).
static func stretch(window_px: Vector2, base: Vector2) -> float:
	return minf(window_px.x / base.x, window_px.y / base.y)


## Points per logical px: what a 16 px label measures on the real screen is 16 * this.
static func points_per_px(window_px: Vector2, screen_scale: float = 1.0, ui_scale: float = 1.0) -> float:
	return stretch(window_px, base_size(window_px, screen_scale, ui_scale)) / maxf(screen_scale, 0.01)


## Physical px per point on this device. Falls back to DPI on mobile when the scale reads 1.
static func screen_scale() -> float:
	var s: float = DisplayServer.screen_get_scale()
	if s <= 1.0 and OS.has_feature("mobile"):
		var dpi: int = DisplayServer.screen_get_dpi()
		if dpi > 200:
			s = dpi / 160.0
	return maxf(s, 1.0)


## Sets the root window's content scale size for the current window. Returns the base used.
static func apply(window: Window, ui_scale: float = 1.0) -> Vector2:
	var window_px: Vector2 = Vector2(DisplayServer.window_get_size())
	if window_px.x < 1.0 or window_px.y < 1.0:
		return Vector2(window.content_scale_size)
	var base: Vector2 = base_size(window_px, screen_scale(), ui_scale)
	if Vector2i(base) != window.content_scale_size:
		window.content_scale_size = Vector2i(base)
	return base
