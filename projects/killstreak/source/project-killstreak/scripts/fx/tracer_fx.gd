# tracer_fx.gd
# Purpose: One tracer from a shooter to its target: a short bright streak whose head travels
#   to the target (tracer_travel) while the tail catches up and fades (tracer_fade), with a
#   small muzzle diamond at the start. A wasted shot (no target) travels half way and fizzles.
#   Coordinates are local to the parent overlay. Drawn with _draw: no textures, no particles.
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (p14)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var color: Color = FxStyle.TEAL
var wasted: bool = false
var width: float = 3.0

var _head: float = 0.0
var _tail: float = 0.0
var _alpha: float = 1.0
var _travel: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	fx_kind = &"tracer"


func _build(t: Tween, timing: RefCounted) -> void:
	_travel = maxf(0.01, timing.get_value(&"tracer_travel"))
	_fade = maxf(0.01, timing.get_value(&"tracer_fade"))
	if wasted:
		to = from.lerp(to, 0.5)
	t.set_parallel(true)
	t.tween_method(_set_head, 0.0, 1.0, _travel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_tail, 0.0, 1.0, _travel + _fade * 0.6).set_delay(_travel * 0.35)
	t.tween_method(_set_alpha, 1.0, 0.0, _fade).set_delay(_travel)


func _planned_duration(_timing: RefCounted) -> float:
	return _travel + _fade


## Seconds until the head reaches the target (the hit marker waits for this).
func arrival_time() -> float:
	return _travel


func _set_head(v: float) -> void:
	_head = v
	queue_redraw()


func _set_tail(v: float) -> void:
	_tail = minf(v, _head)
	queue_redraw()


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()


func _draw() -> void:
	var a: Vector2 = from.lerp(to, _tail)
	var b: Vector2 = from.lerp(to, _head)
	var c: Color = Color(color, _alpha)
	if a.distance_to(b) > 0.5:
		draw_line(a, b, Color(c, _alpha * 0.45), width * 2.2, true)
		draw_line(a, b, c, width, true)
		draw_line(a, b, Color(FxStyle.FOG, _alpha * 0.9), maxf(1.0, width * 0.4), true)
	# Muzzle diamond, gone by the time the tail leaves.
	var m: float = (1.0 - _tail) * 6.0
	if m > 0.5:
		draw_colored_polygon(PackedVector2Array([from + Vector2(0, -m), from + Vector2(m, 0),
				from + Vector2(0, m), from + Vector2(-m, 0)]), Color(FxStyle.FOG, _alpha))
	if wasted and _head >= 1.0:
		# Fizzle: two short sparks at the end point.
		var dir: Vector2 = (to - from).normalized()
		var side: Vector2 = dir.orthogonal() * 5.0
		draw_line(to, to + dir * 6.0 + side, Color(c, _alpha), 2.0, true)
		draw_line(to, to + dir * 6.0 - side, Color(c, _alpha), 2.0, true)
