# elim_stamp_fx.gd
# Purpose: The "ELIMINATED" stamp over a removed unit (art direction, Motion & feedback): a
#   tilted double-ruled box that slams down (scale 1.6 -> 1), holds, then fades.
#   Text by victim: enemy unit "ELIMINATED" (red), own unit "DOWN" (teal), an Operator
#   "OPERATOR DOWN". Hazard ticks on the enemy stamp so friend / foe reads without colour.
#   Reduced motion: no slam, it fades in place.
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (p14)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

var center: Vector2 = Vector2.ZERO
var text: String = "ELIMINATED"
var color: Color = FxStyle.RED
## true: hazard ticks on the frame (enemy victim).
var hazard: bool = true
var font_size: int = 22

var _label: Label = null
var _total: float = 0.0
const PAD: Vector2 = Vector2(10, 4)


func _ready() -> void:
	fx_kind = &"stamp"


func _build(t: Tween, timing: RefCounted) -> void:
	_total = maxf(0.05, timing.get_value(&"stamp"))
	_label = FxStyle.make_label(text, &"heading", font_size, color, 6)
	add_child(_label)
	var sz: Vector2 = _label.get_combined_minimum_size()
	_label.size = sz
	_label.position = PAD
	size = sz + PAD * 2.0
	pivot_offset = size * 0.5
	position = center - size * 0.5
	rotation = deg_to_rad(-6.0)
	var slam: float = minf(0.1, _total * 0.15)
	if timing.reduced_motion:
		modulate.a = 0.0
		t.tween_property(self, ^"modulate:a", 1.0, slam)
	else:
		scale = Vector2(1.6, 1.6)
		modulate.a = 0.3
		t.set_parallel(true)
		t.tween_property(self, ^"scale", Vector2.ONE, slam).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(self, ^"modulate:a", 1.0, slam)
		t.set_parallel(false)
	t.tween_interval(_total * 0.55)
	t.tween_property(self, ^"modulate:a", 0.0, _total * 0.45 - slam)


func _planned_duration(_timing: RefCounted) -> float:
	return _total


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(FxStyle.SLATE, 0.78))
	draw_rect(r, color, false, 2.0)
	draw_rect(r.grow(-4.0), Color(color, 0.6), false, 1.0)
	if hazard:
		for i: int in 3:
			var x: float = 6.0 + i * 7.0
			draw_line(Vector2(x, size.y), Vector2(x + 5.0, size.y - 5.0), color, 2.0)
			draw_line(Vector2(size.x - x, 0), Vector2(size.x - x - 5.0, 5.0), color, 2.0)
