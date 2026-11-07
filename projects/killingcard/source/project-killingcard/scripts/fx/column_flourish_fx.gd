# column_flourish_fx.gd
# Purpose: kc-juice. The column-win flourish: when your column is secured at the Score step, an
#   outline in your side colour (teal) sweeps out from the column edge (0 -> 8 px) with corner brackets and fades
#   (0.5 s). Reduced motion: the outline fades in place (no sweep). It sits under the "+50 ZONE
#   SECURED" pop-up and never takes input.
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (kc-juice)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

## The column, in the overlay's local px.
var rect: Rect2 = Rect2()
var color: Color = FxStyle.AMBER
const GROW_PX: float = 8.0

var _grow: float = 0.0
var _alpha: float = 0.0
var _total: float = 0.0


func _ready() -> void:
	fx_kind = &"column_win"


func _build(t: Tween, timing: RefCounted) -> void:
	_total = maxf(0.05, timing.get_value(&"column_win"))
	_alpha = 0.95
	if timing.reduced_motion:
		t.tween_method(_set_alpha, 0.95, 0.0, _total)
		return
	t.tween_method(_set_grow, 0.0, GROW_PX, _total).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_alpha, 0.95, 0.0, _total).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _planned_duration(_timing: RefCounted) -> float:
	return _total


func _set_grow(v: float) -> void:
	_grow = v
	queue_redraw()


func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()


func _draw() -> void:
	if not rect.has_area():
		return
	var r: Rect2 = rect.grow(_grow)
	draw_rect(r, Color(color, _alpha * 0.9), false, 3.0)
	var arm: float = minf(26.0, minf(r.size.x, r.size.y) * 0.2)
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx: float = 1.0 if corner.x <= r.get_center().x else -1.0
		var sy: float = 1.0 if corner.y <= r.get_center().y else -1.0
		var pts: PackedVector2Array = [corner + Vector2(sx * arm, 0), corner, corner + Vector2(0, sy * arm)]
		draw_polyline(pts, Color(FxStyle.SLATE, _alpha * 0.7), 7.0)
		draw_polyline(pts, Color(color, _alpha), 4.0)
