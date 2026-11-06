# hand_glow_fx.gd
# Purpose: kc-fight-ui (head's kc-syn-ui answer): at the start of Deploy, every hand card that would
#   switch a trait bonus on if played this round glows briefly: two soft pulses of a frame in the
#   trait's colour around the card (plus a white inner line, so it reads without colour), then it
#   fades. It follows the card each frame (the tray slides in). Reduced motion: one steady frame that
#   fades. Display only, no input.
# Usage: var g := HandGlowFx.new(); g.target = card; g.color = tint; overlay.add_child(g); g.play(timing)
# Dependencies: fx_transient.gd.
# Author: UI/UX Agent (kc-fight-ui)
extends "res://scripts/fx/fx_transient.gd"

## Seconds at normal speed (scaled by fast animations).
const BASE_SECONDS: float = 1.6

var target: Control = null
var color: Color = Color("#FFB020")
var _k: float = 0.0
var _total: float = BASE_SECONDS
var _reduced: bool = false


func _ready() -> void:
	fx_kind = &"hand_glow"


func _build(t: Tween, timing: RefCounted) -> void:
	_total = BASE_SECONDS * timing.scale()
	_reduced = timing.reduced_motion
	t.tween_method(_set_k, 0.0, 1.0, _total)


func _planned_duration(_timing: RefCounted) -> float:
	return _total


func _set_k(v: float) -> void:
	_k = v
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


## Strength now (0..1): two pulses, then a fade; reduced motion: steady, then a fade.
func strength() -> float:
	var fade: float = clampf((1.0 - _k) / 0.25, 0.0, 1.0)
	if _reduced:
		return 0.8 * fade
	return (0.35 + 0.65 * absf(sin(_k * TAU))) * fade


func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var g: Rect2 = target.get_global_rect()
	var r: Rect2 = Rect2(get_global_transform().affine_inverse() * g.position, g.size)
	var a: float = strength()
	draw_rect(r.grow(5.0), Color(color, 0.25 * a), false, 6.0)
	draw_rect(r.grow(2.0), Color(color, a), false, 3.0)
	draw_rect(r.grow(-1.0), Color(1, 1, 1, 0.55 * a), false, 1.0)
