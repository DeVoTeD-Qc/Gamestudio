# fx_settings.gd
# Purpose: The FAST ANIMATIONS toggle (cz17). Kept on this device in SetupPrefs [settings]
#   fast_animations (bool). Until the player sets it, it follows Settings.fast_animations, which
#   the cz13 Event speed sets (fast or instant = on). Fast animations halve every effect (with
#   floors, fx_timing.gd); they do not change the rules pacing (that is Event speed).
#   The pause menu's settings page shows it as FAST ANIMATIONS OFF / ON.
# Usage: FxSettings.fast_animations(); FxSettings.set_fast_animations(true)
# Dependencies: setup_prefs.gd, Settings autoload (optional).
# Author: Game Feel Engineer Agent (cz17)
extends RefCounted

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const SECTION: String = "settings"
const KEY: String = "fast_animations"


## The player's choice, else Settings.fast_animations (the Event speed), else false.
static func fast_animations() -> bool:
	var v: Variant = SetupPrefs.get_value(SECTION, KEY, null)
	if v != null:
		return bool(v)
	var s: Node = _settings()
	return s != null and bool(s.get(&"fast_animations"))


static func is_set() -> bool:
	return SetupPrefs.get_value(SECTION, KEY, null) != null


static func set_fast_animations(on: bool) -> void:
	SetupPrefs.set_value(SECTION, KEY, on)
	var s: Node = _settings()
	if s != null:
		s.call(&"set_value", &"fast_animations", on)


static func _settings() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(^"Settings") if loop != null else null
