# float_text_fx.gd
# Purpose: Floating text for damage numbers ("-3"), heals ("+2"), short tags ("BLOCKED",
#   "HOLDS", "SUPPRESSED") and XP / score pop-ups ("+100 ELIMINATION"). It pops in (scale
#   1.25 -> 1), rises `rise_key` px and fades over `duration_key`. Reduced motion: no pop and no
#   rise, it only fades. Text sizes respect the phone floor (>= 16 px, numbers >= 20 px).
# Usage: var fx := FloatTextFx.new(); fx.setup("+100 ELIMINATION", &"heading", 22, FxStyle.AMBER)
#        fx.anchor = point; overlay.add_child(fx); fx.play(timing)
# Dependencies: fx_transient.gd, fx_style.gd.
# Author: Game Feel Engineer Agent (p14)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

## Centre of the text at the start (parent-local px).
var anchor: Vector2 = Vector2.ZERO
var rise_key: StringName = &"damage_rise"
var duration_key: StringName = &"damage_number"
## Hold this share of the duration at full opacity before the fade.
var hold_share: float = 0.45

var label: Label = null
var _total: float = 0.0


func setup(text: String, font: StringName, size: int, color: Color, kind: StringName = &"float_text") -> void:
	fx_kind = kind
	label = FxStyle.make_label(text, font, size, color, 6 if size < 30 else 8)
	add_child(label)


func _build(t: Tween, timing: RefCounted) -> void:
	_total = maxf(0.05, timing.get_value(duration_key))
	label.reset_size()
	var sz: Vector2 = label.get_combined_minimum_size()
	label.size = sz
	label.pivot_offset = sz * 0.5
	position = anchor - sz * 0.5
	var rise: float = timing.get_value(rise_key)
	t.set_parallel(true)
	if not timing.reduced_motion:
		label.scale = Vector2(1.25, 1.25)
		t.tween_property(label, ^"scale", Vector2.ONE, minf(0.12, _total * 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rise > 0.0:
		t.tween_property(self, ^"position:y", position.y - rise, _total).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, ^"modulate:a", 0.0, _total * (1.0 - hold_share)).set_delay(_total * hold_share)


func _planned_duration(_timing: RefCounted) -> float:
	return _total
