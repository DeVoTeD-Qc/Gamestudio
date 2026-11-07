# reward_reveal_fx.gd
# Purpose: kc-juice. Reward cards revealed one after the other: when a new reward offer opens
#   (reward_screen.gd), each option fades in 70 ms after the one before (180 ms each) with the
#   "reward" cue. Only the alpha changes: the tiles keep their place and size and take taps at once.
#   Reduced motion: shown at once (the cue still plays).
# Dependencies: fx_timing.gd, sfx_bank.gd.
# Author: Game Feel Engineer Agent (kc-juice)
extends RefCounted

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const SfxBank: GDScript = preload("res://scripts/fx/sfx_bank.gd")


## Fades `nodes` (CanvasItems) in, staggered. Returns the total time (0 with reduced motion).
static func reveal(nodes: Array, timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	if nodes.is_empty():
		return 0.0
	SfxBank.cue(&"reward")
	if timing.reduced_motion:
		return 0.0
	var stagger: float = timing.get_value(&"reward_stagger")
	var fade: float = timing.get_value(&"reward_fade")
	var total: float = 0.0
	for i: int in nodes.size():
		var n: CanvasItem = nodes[i] as CanvasItem
		if n == null or not n.is_inside_tree():
			continue
		n.modulate.a = 0.0
		var tw: Tween = n.create_tween()
		if i > 0:
			tw.tween_interval(stagger * i)
		tw.tween_property(n, "modulate:a", 1.0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		total = stagger * i + fade
	return total
