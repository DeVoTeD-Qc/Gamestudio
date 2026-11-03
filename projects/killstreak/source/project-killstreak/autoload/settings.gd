# settings.gd
# Purpose: Settings autoload. Player options (fast animations, UI scale, sound).
#   Persistence to user://settings.cfg arrives with the options screen.
#   Also owns the screen profile: at startup and on every window resize it sets the root's
#   canvas base size from the real screen (scripts/ui/screen_profile.gd, f01) so phones get
#   readable text and >= 44 pt tap targets. ui_scale feeds into that rule.
# Dependencies: scripts/ui/screen_profile.gd.
# Author: Mechanics Developer Agent (screen profile: UI/UX Agent, f01)
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")

signal settings_changed

## Shorten non-essential animations (killfeed, call-in takeover).
var fast_animations: bool = false
## Extra UI scale (0.8 - 1.5): raises the minimum on-screen size of one logical px.
var ui_scale: float = 1.0
## Master volume, linear 0.0 - 1.0.
var master_volume: float = 0.8
## Show the firefight outcome preview by default.
var show_outcome_preview: bool = true


func _ready() -> void:
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


func _apply_screen_profile() -> void:
	ScreenProfile.apply(get_tree().root, ui_scale)


## Applies a setting by name and notifies listeners.
func set_value(key: StringName, value: Variant) -> void:
	if not key in self:
		push_error("Settings: unknown key %s" % key)
		return
	set(key, value)
	settings_changed.emit()
