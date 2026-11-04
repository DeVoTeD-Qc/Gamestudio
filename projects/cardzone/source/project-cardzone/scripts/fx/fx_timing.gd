# fx_timing.gd
# Adapted from CallingCard scripts/fx/fx_timing.gd (cc15; same shape, CardZone values).
# Purpose: Every duration and amplitude of CardZone's looting and shooting feedback (cz17) in one
#   table, plus the options that change them:
#   - fast animations (fx_settings.gd: the FAST ANIMATIONS toggle, or Settings.fast_animations,
#     which follows the cz13 Event speed): times x FAST_SCALE, never below FAST_FLOOR;
#   - Settings.reduced_motion: no shake and no travel (tracers, falls, slams, rises, flying cards,
#     ember and dust particles). Effects appear and fade in place; colour and text stay.
#   art-direction.md section 8: "Motion is short and mechanical: 120-180 ms slides, no bounce", so
#   every slide here is 0.12-0.18 s and nothing overshoots.
# Usage: var t: RefCounted = FxTiming.from_settings(); t.get_value(&"tracer"); t.loot_total(&"E")
# Dependencies: Settings autoload, fx_settings.gd (both optional).
# Author: Game Feel Engineer Agent (cz17)
extends RefCounted

const FxSettings: GDScript = preload("res://scripts/fx/fx_settings.gd")

const FAST_SCALE: float = 0.5

## Base values in seconds (px for amplitudes, plain numbers for scales) at normal speed.
const BASE: Dictionary = {
	# Shot: a tracer runs shooter -> target, then the hit marker snaps on the target area.
	&"tracer": 0.14,
	&"marker_in": 0.08,
	&"marker_hold": 0.22,
	&"marker_out": 0.16,
	# Frag: a lobbed arc, then a blast ring on the area.
	&"frag_arc": 0.18,
	&"blast": 0.26,
	# Hits slam onto the top of the loadout (each extra Hit follows `slam_stagger` later).
	&"slam_fall": 0.14,
	&"slam_stagger": 0.07,
	&"slam_settle": 0.24,
	&"slam_px": 70.0,
	&"slam_shake": 0.12,
	&"slam_shake_px": 4.0,
	# Brace cards burn from the bottom up (canvas shader), embers rise.
	&"burn": 0.50,
	&"burn_tag": 0.60,
	# Loot pop: the looted card pops out of the area (time by rarity: LOOT_TIME).
	&"loot_in": 0.12,
	&"loot_rise_px": 18.0,
	&"loot_fly": 0.16,
	# Supply drop: the crate falls onto its area, dust, settles.
	&"drop_fall": 0.18,
	&"drop_px": 90.0,
	&"drop_settle": 0.30,
	&"drop_out": 0.14,
	# Gas sweep across a closing area.
	&"gas_sweep": 0.42,
	&"gas_out": 0.18,
	# Down pulse on the player panel (two pulses).
	&"down_pulse": 0.50,
	&"down_scale": 0.10,
	# Bounty heal on the shooter's panel.
	&"heal": 0.60,
	&"heal_rise_px": 14.0,
	# Elimination stamp (a skippable moment).
	&"stamp": 1.10,
	&"stamp_in": 0.12,
	&"stamp_out": 0.18,
	&"stamp_shake": 0.20,
	&"stamp_shake_px": 6.0,
	# Move mark (decorative, never holds playback).
	&"move_mark": 0.40,
}
## Seconds a looted card stays up, by rarity (C U R E L). Higher rarity = a bigger, longer pop.
const LOOT_TIME: Dictionary = {&"": 0.30, &"C": 0.30, &"U": 0.36, &"R": 0.46, &"E": 0.58, &"L": 0.74}
## Pop scale (x the compact card) and fleck count by rarity.
const LOOT_SCALE: Dictionary = {&"": 0.50, &"C": 0.50, &"U": 0.54, &"R": 0.58, &"E": 0.62, &"L": 0.68}
const LOOT_FLECKS: Dictionary = {&"": 0, &"C": 0, &"U": 4, &"R": 8, &"E": 12, &"L": 18}

## Values that are distances or scales, not times: never scaled by fast animations.
const DISTANCES: Array[StringName] = [&"slam_px", &"slam_shake_px", &"loot_rise_px", &"drop_px",
		&"down_scale", &"heal_rise_px", &"stamp_shake_px"]
## Motion that reduced motion removes entirely (returns 0).
const MOTION_ONLY: Array[StringName] = [&"tracer", &"frag_arc", &"slam_px", &"slam_shake", &"slam_shake_px",
		&"loot_rise_px", &"loot_fly", &"drop_px", &"down_scale", &"heal_rise_px", &"stamp_shake", &"stamp_shake_px"]
## Lower bounds under fast animations (a beat must still read).
const FAST_FLOOR: Dictionary = {&"marker_hold": 0.12, &"burn": 0.30, &"stamp": 0.70, &"gas_sweep": 0.26,
		&"down_pulse": 0.32}

var fast: bool = false
var reduced_motion: bool = false


static func create(fast_animations: bool, reduce_motion: bool) -> RefCounted:
	var t: RefCounted = (load("res://scripts/fx/fx_timing.gd") as GDScript).new()
	t.fast = fast_animations
	t.reduced_motion = reduce_motion
	return t


## Snapshot of the options now (defaults when the Settings autoload is missing).
static func from_settings() -> RefCounted:
	var settings: Node = null
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		settings = (loop as SceneTree).root.get_node_or_null(^"Settings")
	var reduced: bool = settings != null and bool(settings.get(&"reduced_motion"))
	return create(FxSettings.fast_animations(), reduced)


## Duration / amplitude for a key, after both options.
func get_value(key: StringName) -> float:
	var v: float = float(BASE.get(key, 0.0))
	if reduced_motion and key in MOTION_ONLY:
		return 0.0
	if fast and not key in DISTANCES:
		v = maxf(v * FAST_SCALE, float(FAST_FLOOR.get(key, 0.0)))
	return v


## Time a looted card of this rarity stays up (pop included).
func loot_total(rarity: StringName) -> float:
	var v: float = float(LOOT_TIME.get(rarity, LOOT_TIME[&""]))
	return maxf(v * FAST_SCALE, 0.2) if fast else v


## Whole length of each beat (what the hold and the tests use).
func beat_length(kind: StringName, extra: Dictionary = {}) -> float:
	match kind:
		&"shot":
			return get_value(&"tracer") + get_value(&"marker_in") + get_value(&"marker_hold") + get_value(&"marker_out")
		&"frag":
			return get_value(&"frag_arc") + get_value(&"blast") + get_value(&"marker_hold") * 0.5
		&"slam":
			var n: int = clampi(int(extra.get("count", 1)), 1, 3)
			return get_value(&"slam_fall") + get_value(&"slam_stagger") * (n - 1) + get_value(&"slam_settle")
		&"burn":
			return maxf(get_value(&"burn"), get_value(&"burn_tag"))
		&"loot":
			return loot_total(StringName(extra.get("rarity", &"")))
		&"drop":
			return get_value(&"drop_fall") + get_value(&"drop_settle") + get_value(&"drop_out") + (0.18 if reduced_motion else 0.0)
		&"gas":
			return get_value(&"gas_sweep") + get_value(&"gas_out")
		&"down":
			return get_value(&"down_pulse")
		&"heal":
			return get_value(&"heal")
		&"stamp":
			return get_value(&"stamp")
		&"move":
			return get_value(&"move_mark")
	return 0.0
