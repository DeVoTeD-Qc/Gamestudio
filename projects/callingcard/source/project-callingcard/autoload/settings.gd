# settings.gd
# Adapted from Killstreak autoload/settings.gd (trimmed to what Banner Wall uses).
# Purpose: Settings autoload. Player options (fast animations, reduced motion, UI scale, volume).
#   Persistence to user://settings.cfg arrives with an options screen.
#   Also owns the screen profile: at startup and on every window resize it sets the root's
#   canvas base size from the real screen (scripts/ui/screen_profile.gd) so phones get
#   readable text and >= 44 pt tap targets. ui_scale feeds into that rule.
# Dependencies: scripts/ui/screen_profile.gd.
# Author: Mechanics Developer Agent
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")

signal settings_changed

## Shorten non-essential animations ("Carded!" stamp, Triptych merge) - cc15.
var fast_animations: bool = false
## No shake or travelling effects. On the web it starts from the browser's prefers-reduced-motion.
var reduced_motion: bool = false
## Extra UI scale (0.8 - 1.5): raises the minimum on-screen size of one logical px.
var ui_scale: float = 1.0
## Master volume, linear 0.0 - 1.0.
var master_volume: float = 0.8


func _ready() -> void:
	reduced_motion = _system_prefers_reduced_motion()
	# Headless runs (tests, exports) have no real screen; tests check ScreenProfile directly.
	if DisplayServer.get_name() == "headless":
		return
	var root: Window = get_tree().root
	root.size_changed.connect(_apply_screen_profile)
	settings_changed.connect(_apply_screen_profile)
	_apply_screen_profile()
	var base: Vector2 = Vector2(root.content_scale_size)
	print("Screen profile: window %s px, screen scale %.2f, base %s, %.3f pt per px" % [
			DisplayServer.window_get_size(), ScreenProfile.screen_scale(), base,
			ScreenProfile.points_per_px(Vector2(DisplayServer.window_get_size()), ScreenProfile.screen_scale(), ui_scale)])


## True when the current logical canvas is short enough for the compact (phone) layout.
func is_compact() -> bool:
	if not is_inside_tree():
		return false
	return get_tree().root.get_visible_rect().size.y < ScreenProfile.COMPACT_HEIGHT


## Browser prefers-reduced-motion (web builds only; false elsewhere).
func _system_prefers_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var matches: Variant = JavaScriptBridge.eval(
			"window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches", true)
	return bool(matches)


func _apply_screen_profile() -> void:
	ScreenProfile.apply(get_tree().root, ui_scale)


## Applies a setting by name and notifies listeners. Returns false for an unknown key.
func set_value(key: StringName, value: Variant) -> bool:
	if not key in self or key == &"name":
		push_error("Settings: unknown key %s" % key)
		return false
	set(key, value)
	settings_changed.emit()
	return true
