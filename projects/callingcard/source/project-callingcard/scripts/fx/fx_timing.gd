# fx_timing.gd
# Adapted from Killstreak scripts/fx/fx_timing.gd (same shape, Banner Wall values).
# Purpose: Every duration and amplitude of the duel feedback layer (cc15) in one table, plus the two
#   player options that change them:
#   - Settings.fast_animations: durations x FAST_SCALE (the capture wipe keeps a 0.15 s floor so
#     the colour change still reads).
#   - Settings.reduced_motion: no screen shake, no travel (drop, slides, stamp slam, flip squash, the
#     running Set Link light); effects fade in place instead. Colour and text feedback stay.
#   Values follow art-direction.md section 6 and section 5 ("Carded!" about 0.8 s, Triptych 1.5 s,
#   capture wipe 0.25 s).
# Dependencies: Settings autoload (read through the scene tree, optional).
# Author: Game Feel Engineer Agent (cc15)
extends RefCounted

const FAST_SCALE: float = 0.5

## Base values in seconds (px for amplitudes) at normal speed.
const BASE: Dictionary = {
	# Placement: the card falls a few px, squashes on the mortar and puffs dust.
	&"drop_fall": 0.10,
	&"drop_settle": 0.09,
	&"drop_px": 10.0,
	&"dust": 0.35,
	# Capture / Reclaim: frame colour wipe (BannerCard.capture_to).
	&"wipe": 0.25,
	# Ambush spring: squash flip + eye-open flash.
	&"flip_half": 0.09,
	&"flash": 0.22,
	# Set Link: a thin light runs between the linked cards.
	&"link": 0.45,
	# "Carded!" (about 0.8 s, skippable).
	&"carded": 0.80,
	&"crack": 0.12,
	&"stamp_in": 0.14,
	&"stamp_out": 0.18,
	&"shake": 0.22,
	&"shake_px": 5.0,
	# Triptych merge (1.5 s, skippable).
	&"triptych": 1.50,
	&"tri_slide": 0.35,
	&"tri_merge": 0.30,
	&"tri_out": 0.25,
}
## Values that are distances, not times: never scaled by fast animations.
const DISTANCES: Array[StringName] = [&"drop_px", &"shake_px"]
## Motion that reduced motion removes entirely (returns 0).
const MOTION_ONLY: Array[StringName] = [&"shake", &"shake_px", &"drop_px", &"flip_half"]
## Lower bound under fast animations.
const FAST_FLOOR: Dictionary = {&"wipe": 0.15}

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
	var reduced: bool = settings != null and bool(settings.get(&"reduced_motion"))
	return create(fast_on, reduced)


## Duration / amplitude for a key, after both options.
func get_value(key: StringName) -> float:
	var v: float = float(BASE.get(key, 0.0))
	if reduced_motion and key in MOTION_ONLY:
		return 0.0
	if fast and not key in DISTANCES:
		v = maxf(v * FAST_SCALE, float(FAST_FLOOR.get(key, 0.0)))
	return v
