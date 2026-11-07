# supply_spend_fx.gd
# Purpose: kc-juice. A Supply hex being spent (match_screen.gd adds one over each pip that went
#   from full to spent): the amber hex bursts out (x1 -> x1.6) and fades in 0.28 s, over the empty
#   outline the pip now shows, with the "supply" tick. Reduced motion: it fades in place.
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (kc-juice)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

var _k: float = 0.0
var _grow: bool = true
var _total: float = 0.0


func _ready() -> void:
	fx_kind = &"supply_spend"


func _build(t: Tween, timing: RefCounted) -> void:
	_total = maxf(0.05, timing.get_value(&"supply_spend"))
	_grow = not timing.reduced_motion
	t.tween_method(_set_k, 0.0, 1.0, _total).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _planned_duration(_timing: RefCounted) -> float:
	return _total


func _set_k(v: float) -> void:
	_k = v
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var rad: float = minf(size.x, size.y * 1.1) * 0.5 * (1.0 + (0.6 * _k if _grow else 0.0))
	var pts: PackedVector2Array = []
	for i: int in 7:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	var a: float = 1.0 - _k
	draw_colored_polygon(pts.slice(0, 6), Color(FxStyle.AMBER, 0.55 * a))
	draw_polyline(pts, Color(FxStyle.AMBER, a), 2.0, true)
