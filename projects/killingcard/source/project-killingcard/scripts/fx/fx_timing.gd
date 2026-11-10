# fx_timing.gd
# Purpose: Every duration, delay and amplitude of the combat feedback layer (p14) in one table,
#   plus the two player options that change them:
#   - Settings.fast_animations: every duration and beat x FAST_SCALE (killfeed life included).
#   - Settings.reduced_motion: no screen shake, no hit-stop, no travel (pop-ups and stamps fade
#     in place, the StreakArc fades instead of flying apart, the killstreak banner fades and the
#     killstreak sequences show their end frame without travel). Colour and text feedback stay, so nothing is lost, only motion.
#   - Settings.screen_shake (kc-juice, default on): off = no screen shake (hit-stop and flashes stay).
#   An FxTiming instance is a snapshot of those options; FX components take one in play().
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
	# kc-fight-ui: step-by-step firefight playback. The head (2026-11-06, after playing): "way too
	# fast, I can't understand what happens", so x1 is slower than the §5 model: per beat the
	# shooter lifts 0.25 s, the tracer flies 0.3 s, the damage number is held ~0.5 s, then a 0.6 s
	# pause before the next beat; 0.8 s for each column banner.
	&"fight_column": 0.8,       # "COLUMN A" banner; the column brightens, the others dim
	&"fight_beat": 1.1,         # a beat's body: lift + tracer + damage numbers (minimum)
	&"fight_beat_gap": 0.6,     # the pause after a beat, before the next one
	&"fight_lift": 0.25,        # the shooter lifts before its tracer leaves
	&"fight_tracer": 0.3,       # tracer travel inside a beat (the Pierce tracer continues after it)
	&"fight_number": 1.1,       # damage numbers in the firefight (held ~0.5 s, then they fade)
	&"fight_elim": 0.45,        # after an elimination stamp, before the next event
	&"fight_advance_hold": 0.35, # the stamp is read before the line moves
	&"fight_advance": 0.5,      # the line slides up after an elimination
	&"fight_summary": 0.5,      # column summary before the next column
	&"reveal_rival": 0.7,       # each rival card revealed at Reveal (one at a time)
	&"reveal_own": 0.25,        # each of your own arrivals
	&"hit_marker": 0.32,
	&"damage_number": 0.75,
	&"damage_rise": 26.0,
	# Eliminations
	&"elim_beat": 0.30,
	&"stamp": 0.95,
	# kc-juice: hit-stop by importance (60-90 ms): a unit, a killstreak kill, the Operator.
	&"hitstop": 0.06,
	&"hitstop_mid": 0.075,
	&"hitstop_big": 0.09,
	&"shake": 0.18,
	&"shake_px": 3.0,           # art direction: 2-4 px
	&"shake_px_big": 4.0,
	# kc-juice: a big hit that does not kill (Damage >= BIG_HIT, or on the Operator): a smaller nudge.
	&"shake_hit": 0.14,
	&"shake_hit_px": 2.0,
	# kc-juice: the calling-card stamp when a card lands (scale punch + flash, < 250 ms).
	&"land_punch_in": 0.06,
	&"land_punch_out": 0.14,
	&"land_flash": 0.16,
	&"land_scale": 1.07,
	# kc-juice: small wins.
	&"supply_spend": 0.28,      # a spent Supply hex bursts and fades
	&"column_win": 0.5,         # your column at the Score step: a sweeping outline
	&"reward_stagger": 0.07,    # reward cards fade in one after the other
	&"reward_fade": 0.18,
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
	# kc-ks-seq: killstreak banner + per-streak sequences (killstreak_fx.gd, strike_fx.gd). The banner
	# is compact and never blocks: the playback waits only ks_banner_beat while it shows.
	&"ks_banner": 1.7,          # on screen, in + hold + out
	&"ks_banner_in": 0.18,
	&"ks_banner_out": 0.22,
	&"ks_banner_beat": 0.45,    # what the playback waits for a banner
	&"ks_queued": 0.3,          # the INCOMING marker drops onto its column
	&"ks_shells": 1.0,          # mortar: three shells arc in (whistle), then impact
	&"ks_strafe": 1.15,         # helo: a pass over the columns, bursts into each front unit
	&"ks_scan": 0.9,            # recon drone: a scan sweep over the scanned half
	&"ks_drop": 0.75,           # sentry: drops in at the back of its column, lands
	&"ks_resolved": 0.55,       # after the strike's log line, before the fight goes on
	# Killstreak call-in takeover (art direction: 0.8 s; retired from the match by kc-ks-seq)
	&"takeover": 0.8,
	&"takeover_in": 0.14,
	&"takeover_out": 0.16,
}
## Values that are distances, not times: never scaled by fast animations.
const DISTANCES: Array[StringName] = [&"damage_rise", &"shake_px", &"shake_px_big", &"shake_hit_px", &"popup_rise", &"land_scale"]
## Motion that reduced motion removes entirely (returns 0). kc-juice: the card-land punch and flash too.
const MOTION_ONLY: Array[StringName] = [&"hitstop", &"hitstop_mid", &"hitstop_big", &"shake", &"shake_px", &"shake_px_big",
		&"shake_hit", &"shake_hit_px", &"land_punch_in", &"land_punch_out", &"land_flash", &"land_scale"]
## kc-juice: what Settings.screen_shake = false removes.
const SHAKE_KEYS: Array[StringName] = [&"shake", &"shake_px", &"shake_px_big", &"shake_hit", &"shake_hit_px"]
## kc-juice: the largest shake offset ever applied (px), whatever the caller asks.
const SHAKE_CAP_PX: float = 4.0
## Travel distances that reduced motion removes (the element fades in place instead).
const TRAVEL: Array[StringName] = [&"damage_rise", &"popup_rise"]

var fast: bool = false
var reduced_motion: bool = false
## kc-juice: Settings.screen_shake.
var shake_on: bool = true


static func create(fast_animations: bool, reduce_motion: bool, shake: bool = true) -> RefCounted:
	var t: RefCounted = (load("res://scripts/fx/fx_timing.gd") as GDScript).new()
	t.fast = fast_animations
	t.reduced_motion = reduce_motion
	t.shake_on = shake
	return t


## Snapshot of the Settings autoload (defaults when it is missing, e.g. a bare test scene).
static func from_settings() -> RefCounted:
	var settings: Node = null
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		settings = (loop as SceneTree).root.get_node_or_null(^"Settings")
	var fast_on: bool = settings != null and bool(settings.get(&"fast_animations"))
	var reduced: bool = settings != null and "reduced_motion" in settings and bool(settings.get(&"reduced_motion"))
	var shake: bool = settings == null or not "screen_shake" in settings or bool(settings.get(&"screen_shake"))
	return create(fast_on, reduced, shake)


## Duration / delay / amplitude for a key, after both options.
func get_value(key: StringName) -> float:
	var v: float = float(BASE.get(key, 0.0))
	if reduced_motion and (key in MOTION_ONLY or key in TRAVEL):
		return 0.0
	if not shake_on and key in SHAKE_KEYS:
		return 0.0
	if fast and not key in DISTANCES:
		v *= FAST_SCALE
	return v


## Speed multiplier for durations (1.0 normal, 0.5 fast).
func scale() -> float:
	return FAST_SCALE if fast else 1.0
