# streak_arc.gd
# Purpose: The streak meter (art direction "Board & HUD"): a shallow segmented arc, one segment
#   per streak point, with taller notched segments at each killstreak threshold. Segments fill
#   one by one in Uplink Cyan when the streak rises; a threshold notch flashes and keeps a glow
#   once it is reached. When the Operator goes down the lit segments crack and shatter into
#   shards that fall away (glass-crack effect), then the arc is empty.
#   Reduced motion: the shards fade where they are instead of flying apart.
#   Display only: it never computes a streak, it shows the numbers in STREAK_CHANGED.
# Scene: res://scenes/fx/StreakArc.tscn (Control, mouse ignored, min 120x30; it scales to its rect).
# API: configure(max, thresholds, streak) · play_change(event, timing) -> seconds · shatter(timing)
#      · set_streak(value, timing) · finish()
# Dependencies: fx_style.gd, fx_timing.gd, rules_event.gd (event names).
# Author: Game Feel Engineer Agent (p14)
extends Control

signal shattered

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const SEG_GAP_RAD: float = 0.045
const BAND: float = 8.0
const BAND_NOTCH: float = 12.0
## Arc height (sagitta) as a share of its width: shallow, so segments stay wide.
const CURVE: float = 0.16
const SHARDS_PER_SEGMENT: int = 3

## Number of segments (the highest threshold, or more).
@export var max_streak: int = 5
## Streak values that earn a killstreak (notched segments).
@export var thresholds: Array[int] = [2, 3, 5]
## Draw the streak number under the arc's middle.
@export var show_value: bool = false

## Streak the arc is showing or animating towards.
var streak: int = 0
## Animated fill in segments (0..max_streak).
var fill: float = 0.0
var _glow: Dictionary = {}           # threshold -> flash 0..1 (on top of the steady glow)
var _shards: Array[Dictionary] = []
var _shatter_t: float = 0.0
var _crack: float = 0.0
var _tween: Tween = null
var _reduced: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 30)


## Sets the arc without animation.
func configure(new_max: int, new_thresholds: Array, value: int) -> void:
	max_streak = maxi(1, new_max)
	thresholds.clear()
	for t: Variant in new_thresholds:
		thresholds.append(int(t))
		max_streak = maxi(max_streak, int(t))
	streak = maxi(0, value)
	fill = float(mini(streak, max_streak))
	_shards.clear()
	_glow.clear()
	queue_redraw()


## Plays a RulesEvent.STREAK_CHANGED dictionary {streak, before, gained, reset, earned}.
## Returns how long it takes (seconds) so a sequencer can wait for it.
func play_change(event: Dictionary, timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	var before: int = int(event.get("before", streak))
	var gained: int = int(event.get("gained", 0))
	var peak: int = maxi(0, before + gained)
	if bool(event.get("reset", false)):
		var t_up: float = set_streak(peak, timing) if peak != streak else 0.0
		var t_hold: float = timing.get_value(&"streak_beat") * 0.5
		_chain(func() -> void: shatter(timing), t_up + t_hold)
		return t_up + t_hold + timing.get_value(&"shatter")
	return set_streak(int(event.get("streak", peak)), timing)


## Animates the fill to `value`. Returns the duration.
func set_streak(value: int, timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	_reduced = timing.reduced_motion
	var target: float = float(clampi(value, 0, max_streak))
	var start: float = fill
	streak = maxi(0, value)
	var per: float = timing.get_value(&"streak_fill")
	var dur: float = maxf(0.01, absf(target - start) * per)
	_kill()
	_tween = create_tween()
	_tween.tween_method(_set_fill.bind(start), start, target, dur)
	return dur


## Cracks and drops every lit segment; the arc ends empty. Returns the duration.
func shatter(timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	_reduced = timing.reduced_motion
	var dur: float = maxf(0.05, timing.get_value(&"shatter"))
	_build_shards()
	fill = 0.0
	streak = 0
	_glow.clear()
	_kill()
	_tween = create_tween().set_parallel(true)
	_crack = 1.0
	_tween.tween_method(_set_shatter, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, ^"_crack", 0.0, dur * 0.3)
	_tween.finished.connect(func() -> void:
		_shards.clear()
		queue_redraw()
		shattered.emit())
	return dur


## Jumps every running animation to its end (fast-forward).
func finish() -> void:
	for i: int in 4:  # chained steps (fill -> shatter) may start new tweens while finishing
		if _tween != null and _tween.is_valid() and _tween.is_running():
			_tween.custom_step(60.0)
	fill = float(mini(streak, max_streak))
	queue_redraw()


func is_animating() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func shard_count() -> int:
	return _shards.size()


func is_threshold_lit(threshold: int) -> bool:
	return fill >= float(threshold) - 0.001


# --- internals ------------------------------------------------------------------------

func _chain(fn: Callable, delay: float) -> void:
	_kill()
	_tween = create_tween()
	if delay > 0.0:
		# The fill to the peak runs inside this same tween so finish() completes both.
		_tween.tween_method(_set_fill.bind(fill), fill, float(clampi(streak, 0, max_streak)), maxf(0.01, delay * 0.7))
		_tween.tween_interval(delay * 0.3)
	_tween.tween_callback(fn)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _set_fill(v: float, start: float) -> void:
	var old: float = fill
	fill = v
	for t: int in thresholds:
		if old < t and v >= t - 0.001 and start < t:
			_glow[t] = 1.0
			var g: Tween = create_tween()
			g.tween_method(func(a: float) -> void:
				_glow[t] = a
				queue_redraw(), 1.0, 0.0, 0.45)
	queue_redraw()


func _set_shatter(v: float) -> void:
	_shatter_t = v
	queue_redraw()


## Arc geometry for the current rect: {center, radius, a0, a1}.
func _geometry() -> Dictionary:
	var w: float = maxf(20.0, size.x - 12.0)
	var h: float = clampf(size.y - BAND_NOTCH - 4.0, 4.0, w * CURVE)
	var r: float = (w * w * 0.25 + h * h) / (2.0 * h)
	var top: float = BAND_NOTCH * 0.5 + 2.0
	var c: Vector2 = Vector2(size.x * 0.5, top + r)
	var half: float = asin(clampf((w * 0.5) / r, -1.0, 1.0))
	return {"center": c, "radius": r, "a0": -PI * 0.5 - half, "a1": -PI * 0.5 + half}


func _segment_span(i: int, g: Dictionary) -> Vector2:
	var a0: float = g["a0"]
	var step: float = (float(g["a1"]) - a0) / float(max_streak)
	return Vector2(a0 + step * i + SEG_GAP_RAD * 0.5, a0 + step * (i + 1) - SEG_GAP_RAD * 0.5)


func _band(c: Vector2, r: float, thick: float, from_a: float, to_a: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps: int = maxi(2, int(ceil((to_a - from_a) / 0.05)))
	for k: int in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(from_a, to_a, float(k) / steps)) * (r + thick * 0.5))
	for k: int in range(steps, -1, -1):
		pts.append(c + Vector2.from_angle(lerpf(from_a, to_a, float(k) / steps)) * (r - thick * 0.5))
	return pts


func _build_shards() -> void:
	_shards.clear()
	var g: Dictionary = _geometry()
	var c: Vector2 = g["center"]
	var r: float = g["radius"]
	var lit: int = int(ceil(fill - 0.001))
	for i: int in mini(lit, max_streak):
		var span: Vector2 = _segment_span(i, g)
		var thick: float = BAND_NOTCH if (i + 1) in thresholds else BAND
		for k: int in SHARDS_PER_SEGMENT:
			var a: float = lerpf(span.x, span.y, float(k) / SHARDS_PER_SEGMENT)
			var b: float = lerpf(span.x, span.y, float(k + 1) / SHARDS_PER_SEGMENT)
			var poly: PackedVector2Array = _band(c, r, thick, a, b)
			var centroid: Vector2 = Vector2.ZERO
			for p: Vector2 in poly:
				centroid += p
			centroid /= poly.size()
			var local: PackedVector2Array = []
			for p: Vector2 in poly:
				local.append(p - centroid)
			var out_dir: Vector2 = (centroid - c).normalized()
			var seed_v: float = float((i * 7 + k * 13) % 11) / 10.0   # deterministic spread
			_shards.append({
				"poly": local, "pos": centroid,
				"vel": out_dir * (18.0 + seed_v * 22.0) + Vector2((seed_v - 0.5) * 30.0, -10.0),
				"spin": (seed_v - 0.5) * 5.0,
				"notch": (i + 1) in thresholds,
			})


func _draw() -> void:
	var g: Dictionary = _geometry()
	var c: Vector2 = g["center"]
	var r: float = g["radius"]
	for i: int in max_streak:
		var span: Vector2 = _segment_span(i, g)
		var value: int = i + 1
		var notch: bool = value in thresholds
		var thick: float = BAND_NOTCH if notch else BAND
		draw_colored_polygon(_band(c, r, thick, span.x, span.y), Color(FxStyle.GUNMETAL, 0.95))
		var lit: float = clampf(fill - i, 0.0, 1.0)
		if lit > 0.0:
			var end_a: float = lerpf(span.x, span.y, lit)
			if notch and fill >= value - 0.001:
				var glow: float = 0.35 + 0.65 * float(_glow.get(value, 0.0))
				draw_colored_polygon(_band(c, r, thick + 6.0, span.x - 0.01, span.y + 0.01), Color(FxStyle.CYAN, 0.25 * glow + 0.1))
			draw_colored_polygon(_band(c, r, thick, span.x, end_a), FxStyle.CYAN)
		else:
			draw_polyline(_band(c, r, thick, span.x, span.y), Color(FxStyle.FOG, 0.25), 1.0)
		if notch:
			# Notch tick on the outside edge at the segment's end (where the threshold is reached).
			var p_in: Vector2 = c + Vector2.from_angle(span.y) * (r + thick * 0.5)
			var p_out: Vector2 = c + Vector2.from_angle(span.y) * (r + thick * 0.5 + 4.0)
			draw_line(p_in, p_out, FxStyle.CYAN if fill >= value - 0.001 else FxStyle.FOG_DIM, 2.0)
	if not _shards.is_empty():
		var t: float = _shatter_t
		var alpha: float = 1.0 - t
		for s: Dictionary in _shards:
			var pos: Vector2 = s["pos"]
			var rot: float = 0.0
			if not _reduced:
				pos += (s["vel"] as Vector2) * t * 1.6 + Vector2(0, 70.0) * t * t
				rot = float(s["spin"]) * t
			var xf: Transform2D = Transform2D(rot, pos)
			draw_set_transform_matrix(xf)
			draw_colored_polygon(s["poly"], Color(FxStyle.CYAN.lerp(FxStyle.FOG, 0.3), alpha))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		if _crack > 0.0:
			# Glass-crack flash: jagged white lines across the arc.
			for s: Dictionary in _shards:
				var p: Vector2 = s["pos"]
				var q: Vector2 = p + Vector2(4, -BAND)
				draw_polyline(PackedVector2Array([p + Vector2(-3, BAND * 0.6), p, q]), Color(FxStyle.FOG, _crack), 1.5)
	if show_value:
		var font: Font = FxStyle.FONT_NUMERIC
		var text: String = str(streak)
		var fs: int = FxStyle.MIN_NUMBER_PX
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x * 0.5 - tw * 0.5, size.y - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FxStyle.CYAN)
