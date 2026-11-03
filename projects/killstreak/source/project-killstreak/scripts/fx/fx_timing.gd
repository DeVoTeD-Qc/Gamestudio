# fx_timing.gd
# Purpose: Every duration, delay and amplitude of the combat feedback layer (p14) in one table,
#   plus the two player options that change them:
#   - Settings.fast_animations: every duration and beat x FAST_SCALE (killfeed life included).
#   - Settings.reduced_motion: no screen shake, no hit-stop, no travel (pop-ups and stamps fade
#     in place, the StreakArc fades instead of flying apart, the takeover cross-fades and its
#     scanlines stand still). Colour and text feedback stay, so nothing is lost, only motion.
#   An FxTiming instance is a snapshot of those two options; FX components take one in play().
# Dependencies: Settings autoload (read through the scene tree, optional).
# Author: Game Feel Engineer Agent (p14)
extends RefCounted

const FAST_SCALE: float = 0.5

## Base values in seconds (px for amplitudes) at normal speed.
const BASE: Dictionary = {
	# Firefight
	&"shot_stagger": 0.06,      # art direction: tracers staggered 60 ms per shot
	&"tracer_travel": 0.12,
	&"tracer_fade": 0.16,
	&"step_pause": 0.12,        # between First Shot and Main steps / zones
	&"hit_marker": 0.32,
	&"damage_number": 0.75,
	&"damage_rise": 26.0,
	# Eliminations
	&"elim_beat": 0.30,
	&"stamp": 0.95,
	&"hitstop": 0.06,
	&"shake": 0.18,
	&"shake_px": 3.0,           # art direction: 2-4 px
	&"shake_px_big": 4.0,
	# Streak
	&"streak_beat": 0.35,
	&"streak_fill": 0.14,       # per segment
	&"shatter": 0.70,
	&"earned_beat": 0.45,
	# Pop-ups
	&"popup": 1.0,
	&"popup_rise": 40.0,
	&"popup_beat": 0.18,
	# Killfeed
	&"feed_enter": 0.16,
	&"feed_life": 4.0,          # art direction: lines fade after 4 s
	&"feed_fade": 0.3,
	# Killstreak call-in takeover (art direction: 0.8 s)
	&"takeover": 0.8,
	&"takeover_in": 0.14,
	&"takeover_out": 0.16,
}
## Values that are distances, not times: never scaled by fast animations.
const DISTANCES: Array[StringName] = [&"damage_rise", &"shake_px", &"shake_px_big", &"popup_rise"]
## Motion that reduced motion removes entirely (returns 0).
const MOTION_ONLY: Array[StringName] = [&"hitstop", &"shake", &"shake_px", &"shake_px_big"]
## Travel distances that reduced motion removes (the element fades in place instead).
const TRAVEL: Array[StringName] = [&"damage_rise", &"popup_rise"]

var fast: bool = false
var reduced_motion: bool = false


static func create(fast_animations: bool, reduce_motion: bool) -> RefCounted:
	var t: RefCounted = (load("res://scripts/fx/fx_timing.gd") as GDScript).new()
	t.fast = fast_animations
	t.reduced_motion = reduce_motion
	return t


## Snapshot of the Settings autoload (defaults when it is missing, e.g. a bare test scene).
static func from_settings() -> RefCounted:
	var settings: Node = null
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		settings = (loop as SceneTree).root.get_node_or_null(^"Settings")
	var fast_on: bool = settings != null and bool(settings.get(&"fast_animations"))
	var reduced: bool = settings != null and "reduced_motion" in settings and bool(settings.get(&"reduced_motion"))
	return create(fast_on, reduced)


## Duration / delay / amplitude for a key, after both options.
func get_value(key: StringName) -> float:
	var v: float = float(BASE.get(key, 0.0))
	if reduced_motion and (key in MOTION_ONLY or key in TRAVEL):
		return 0.0
	if fast and not key in DISTANCES:
		v *= FAST_SCALE
	return v


## Speed multiplier for durations (1.0 normal, 0.5 fast).
func scale() -> float:
	return FAST_SCALE if fast else 1.0
