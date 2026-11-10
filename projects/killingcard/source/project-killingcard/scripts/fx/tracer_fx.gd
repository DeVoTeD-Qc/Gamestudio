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
## kc-fight-ui: timing key of the travel (&"fight_tracer" inside a firefight beat) and a delay
## before the head leaves (a Pierce tracer starts when the shot it continues reaches its target).
var travel_key: StringName = &"tracer_travel"
var start_delay: float = 0.0

var _head: float = 0.0
var _tail: float = 0.0
var _alpha: float = 1.0
var _travel: float = 0.0
var _fade: float = 0.0


## kc-ui-wire2: the kit's tracer streak (fx_tracer, additive) along the path, when shipped.
const TRACER_PIECE: StringName = &"fx_tracer"
var _kit_layer: Control = null


func _ready() -> void:
	fx_kind = &"tracer"
	if UiKit.has_piece(TRACER_PIECE):
		_kit_layer = UiKit.fx_layer(self, _draw_kit, true, "KitTracer")


func _build(t: Tween, timing: RefCounted) -> void:
	_travel = maxf(0.01, timing.get_value(travel_key))
	_fade = maxf(0.01, timing.get_value(&"tracer_fade"))
	if wasted:
		to = from.lerp(to, 0.5)
	var d: float = maxf(0.0, start_delay)
	if d > 0.0:
		_alpha = 0.0
	t.set_parallel(true)
	if d > 0.0:
		t.tween_method(_set_alpha, 1.0, 1.0, 0.01).set_delay(d)
	t.tween_method(_set_head, 0.0, 1.0, _travel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(d)
	t.tween_method(_set_tail, 0.0, 1.0, _travel + _fade * 0.6).set_delay(d + _travel * 0.35)
	t.tween_method(_set_alpha, 1.0, 0.0, _fade).set_delay(d + _travel)


func _planned_duration(_timing: RefCounted) -> float:
	return start_delay + _travel + _fade


## Seconds until the head reaches the target (the hit marker waits for this).
func arrival_time() -> float:
	return start_delay + _travel


func _set_head(v: float) -> void:
	_head = v
	queue_redraw()


func _set_tail(v: float) -> void:
	_tail = minf(v, _head)
	queue_redraw()


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()


## The kit streak: stretched from tail to head, 4x the line width tall, tinted the side colour.
func _draw_kit(layer: Control) -> void:
	var a: Vector2 = from.lerp(to, _tail)
	var b: Vector2 = from.lerp(to, _head)
	var span: float = a.distance_to(b)
	if span <= 0.5:
		return
	var h: float = width * 4.0
	layer.draw_set_transform(a, (b - a).angle())
	UiKit.draw_piece(layer, TRACER_PIECE, Rect2(0.0, -h * 0.5, span, h), Color(color.lightened(0.35), _alpha))
	layer.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	var a: Vector2 = from.lerp(to, _tail)
	var b: Vector2 = from.lerp(to, _head)
	var c: Color = Color(color, _alpha)
	if _kit_layer != null:
		_kit_layer.queue_redraw()
		# The bright core stays a thin code line so the shot reads on the light Fog cards too.
		if a.distance_to(b) > 0.5:
			draw_line(a, b, Color(FxStyle.FOG, _alpha * 0.8), maxf(1.0, width * 0.35), true)
	elif a.distance_to(b) > 0.5:
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
