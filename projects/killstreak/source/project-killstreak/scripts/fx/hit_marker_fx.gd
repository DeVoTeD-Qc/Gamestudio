# hit_marker_fx.gd
# Purpose: Hit confirmation on a target: four L-shaped "lock" brackets snap in from wide to
#   tight around the impact point, with a small centre diamond, then fade. A lethal hit adds a
#   rotated outer square of ticks. Colour follows the shooter's side (teal / red). This is an
#   original target-lock look (bracket corners from the HUD frames), not a cross-shaped marker.
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (p14)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

var center: Vector2 = Vector2.ZERO
var color: Color = FxStyle.TEAL
var lethal: bool = false
## Bracket half-size when locked (px).
var radius: float = 16.0

var _spread: float = 1.0
var _alpha: float = 1.0
var _total: float = 0.0


func _ready() -> void:
	fx_kind = &"hit_marker"


func _build(t: Tween, timing: RefCounted) -> void:
	_total = maxf(0.02, timing.get_value(&"hit_marker"))
	var snap: float = _total * 0.3
	_spread = 0.0 if timing.reduced_motion else 1.0
	t.tween_method(_set_spread, _spread, 0.0, snap).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(_total * 0.3)
	t.tween_method(_set_alpha, 1.0, 0.0, _total * 0.4)


func _planned_duration(_timing: RefCounted) -> float:
	return _total


func _set_spread(v: float) -> void:
	_spread = v
	queue_redraw()


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()


func _draw() -> void:
	var r: float = radius * (1.0 + _spread * 0.9)
	var arm: float = radius * 0.55
	var c: Color = Color(color, _alpha)
	var shadow: Color = Color(FxStyle.SLATE, _alpha * 0.8)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner: Vector2 = center + Vector2(sx * r, sy * r)
			var pts: PackedVector2Array = [corner - Vector2(sx * arm, 0), corner, corner - Vector2(0, sy * arm)]
			draw_polyline(pts, shadow, 5.0, true)
			draw_polyline(pts, c, 2.5, true)
	var d: float = 3.5
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -d), center + Vector2(d, 0),
			center + Vector2(0, d), center + Vector2(-d, 0)]), Color(FxStyle.FOG, _alpha))
	if lethal:
		var o: float = r * 1.45
		for i: int in 4:
			var dir: Vector2 = Vector2.from_angle(PI * 0.5 * i)
			draw_line(center + dir * o, center + dir * (o - radius * 0.45), shadow, 5.0, true)
			draw_line(center + dir * o, center + dir * (o - radius * 0.45), c, 2.5, true)
