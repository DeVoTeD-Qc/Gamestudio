# pause_settings.gd
# Purpose: The two player settings of the pause menu (cz13), kept on this device (SetupPrefs
#   [settings]) and applied to the Settings autoload and the running match:
#     reduced_motion  no shake or travelling effects (Settings.reduced_motion; starts from the
#                     browser's prefers-reduced-motion until the player sets it)
#     event_speed     how fast the rival's moves and each rules event play out:
#                     normal (0.45 s / 0.35 s), fast (0.2 / 0.15), instant (0 / 0)
#   Settings.fast_animations follows event_speed (fast or instant).
# Dependencies: setup_prefs.gd, Settings (autoload), MatchController (event_delay, opponent_delay).
# Author: UI/UX Agent (cz13)
extends RefCounted

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const SECTION: String = "settings"

const SPEEDS: Array[String] = ["normal", "fast", "instant"]
## speed -> [event_delay, opponent_delay] in seconds.
const DELAYS: Dictionary = {"normal": [0.45, 0.35], "fast": [0.2, 0.15], "instant": [0.0, 0.0]}


static func event_speed() -> String:
	var s: String = String(SetupPrefs.get_value(SECTION, "event_speed", "normal"))
	return s if SPEEDS.has(s) else "normal"


static func set_event_speed(speed: String) -> void:
	if SPEEDS.has(speed):
		SetupPrefs.set_value(SECTION, "event_speed", speed)
		apply_to_settings()


## The saved choice, or the Settings autoload's current value (the browser preference) if unset.
static func reduced_motion() -> bool:
	var v: Variant = SetupPrefs.get_value(SECTION, "reduced_motion", null)
	if v != null:
		return bool(v)
	var s: Node = _settings()
	return bool(s.get("reduced_motion")) if s != null else false


static func set_reduced_motion(on: bool) -> void:
	SetupPrefs.set_value(SECTION, "reduced_motion", on)
	apply_to_settings()


## Pushes the saved values into the Settings autoload (Title calls it at start).
static func apply_to_settings() -> void:
	var s: Node = _settings()
	if s == null:
		return
	s.call("set_value", &"reduced_motion", reduced_motion())
	s.call("set_value", &"fast_animations", event_speed() != "normal")


## Sets the controller's pacing from event_speed.
static func apply_to_controller(ctrl: Node) -> void:
	if ctrl == null:
		return
	var d: Array = DELAYS[event_speed()]
	ctrl.set("event_delay", float(d[0]))
	ctrl.set("opponent_delay", float(d[1]))


static func speed_text(speed: String) -> String:
	return speed.to_upper()


static func _settings() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Settings") if loop != null else null
