# card_land_fx.gd
# Purpose: kc-juice. The calling-card "stamp" when a card lands on the board (lane.gd calls it when
#   a new banner reaches its slot: your plays in Deploy and every card turned over at Reveal):
#   - a scale punch: 1.0 -> 1.07 (60 ms) -> 1.0 (140 ms), about the banner's centre;
#   - a short flash: a white veil with a side-coloured rim over the banner, 0.5 -> 0 in 160 ms;
#   - the stamp sound (card_land).
#   All of it is over within 250 ms (fast animations: half) and nothing stays on the banner after,
#   so its stats are never covered once it settled. Reduced motion: the sound only (no punch, no
#   flash). The banner's position (the lane's slide) is never touched.
# Dependencies: fx_timing.gd, fx_style.gd, sfx_bank.gd.
# Author: Game Feel Engineer Agent (kc-juice)
extends RefCounted

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const SfxBank: GDScript = preload("res://scripts/fx/sfx_bank.gd")
const FLASH_NAME: String = "LandFlash"
## Stamps played since the last reset (tests): {side, punched, flashed, duration}.
static var stamps: Array[Dictionary] = []


## The flash veil (a child of the banner, freed when it has faded).
class LandFlash:
	extends Control
	var rim: Color = Color.WHITE
	var alpha: float = 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		name = "LandFlash"

	func set_alpha(v: float) -> void:
		alpha = v
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, alpha * 0.55))
		draw_rect(r.grow(-1.0), Color(rim, alpha), false, 2.0)


## Plays the stamp on `banner` (a Control in the tree). Returns the effect's length in seconds
## (0 = sound only). timing: an FxTiming (null = read Settings now).
static func stamp(banner: Control, side: StringName = &"player", timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	SfxBank.cue(&"card_land", 1.0 if side == &"player" else 0.92)
	if banner == null or not is_instance_valid(banner) or not banner.is_inside_tree():
		stamps.append({"side": side, "punched": false, "flashed": false, "duration": 0.0})
		return 0.0
	var k_in: float = timing.get_value(&"land_punch_in")
	var k_out: float = timing.get_value(&"land_punch_out")
	var k_flash: float = timing.get_value(&"land_flash")
	var peak: float = timing.get_value(&"land_scale")
	var punched: bool = k_in > 0.0 and peak > 1.0
	var flashed: bool = k_flash > 0.0
	if punched:
		if banner.has_meta(&"land_fx"):
			var old: Tween = banner.get_meta(&"land_fx") as Tween
			if old != null and old.is_valid():
				old.kill()
		banner.pivot_offset = banner.size * 0.5
		var tw: Tween = banner.create_tween()
		tw.tween_property(banner, "scale", Vector2(peak, peak), k_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(banner, "scale", Vector2.ONE, k_out).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		banner.set_meta(&"land_fx", tw)
	if flashed:
		var old_flash: Node = banner.get_node_or_null(FLASH_NAME)
		if old_flash != null:
			old_flash.free()
		var f: LandFlash = LandFlash.new()
		f.rim = FxStyle.side_color(side)
		banner.add_child(f)
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ft: Tween = f.create_tween()
		ft.tween_method(f.set_alpha, 1.0, 0.0, k_flash).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.tween_callback(f.queue_free)
	var dur: float = maxf(k_in + k_out if punched else 0.0, k_flash if flashed else 0.0)
	stamps.append({"side": side, "punched": punched, "flashed": flashed, "duration": dur})
	return dur
