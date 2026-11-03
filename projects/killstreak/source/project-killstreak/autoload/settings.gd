# settings.gd
# Purpose: Settings autoload. Player options (fast animations, UI scale, sound).
#   Persistence to user://settings.cfg arrives with the options screen.
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

signal settings_changed

## Shorten non-essential animations (killfeed, call-in takeover).
var fast_animations: bool = false
## Extra UI scale on top of the canvas_items stretch (0.8 - 1.5).
var ui_scale: float = 1.0
## Master volume, linear 0.0 - 1.0.
var master_volume: float = 0.8
## Show the firefight outcome preview by default.
var show_outcome_preview: bool = true


## Applies a setting by name and notifies listeners.
func set_value(key: StringName, value: Variant) -> void:
	if not key in self:
		push_error("Settings: unknown key %s" % key)
		return
	set(key, value)
	settings_changed.emit()
