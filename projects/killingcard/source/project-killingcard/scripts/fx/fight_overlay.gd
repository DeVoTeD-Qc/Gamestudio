# fight_overlay.gd
# Purpose: The persistent part of the step-by-step firefight playback (kc-fight-ui,
#   firefight-order.md §8), drawn by FeedbackDirector over the board while a round plays:
#   - the active column stays bright and the other two dim (a slate veil over their lanes);
#   - "now firing": each shooter of the current beat gets a thick outline in its side's colour
#     with corner brackets (shape as well as colour), and its banner lifts a few px toward the
#     enemy (the director moves the banner, this draws the frame);
#   - "fired" pips: a small spent cartridge (brass case with a dark primer ring) on every banner
#     that has fired this round, so "everyone fires once" reads at a glance. Cleared when the
#     sequence ends (the Score step).
#   Everything follows the slots each frame (the board refreshes and slides under it). Display
#   only: no input, no game state.
# Dependencies: fx_style.gd; the director's locator (unit_rect / zone_rect / find_slot).
# Author: UI/UX Agent (kc-fight-ui)
extends Control

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const ZONES: Array[StringName] = [&"left", &"mid", &"right"]
const BRASS: Color = Color("#D9A441")
const BRASS_DARK: Color = Color("#7A5418")

## Object with unit_rect(uid) / zone_rect(zone) (global canvas px); set by the director.
var locator: RefCounted = null
## The column being fought (&"" = none: nothing dims).
var active_zone: StringName = &""
## uid -> side (&"player" / &"enemy") of the units firing in the current beat.
var shooters: Dictionary = {}
## uid -> true: the units that have fired this round.
var fired: Dictionary = {}
## The side whose screen this is (its outline is teal).
var viewer_side: StringName = &"player"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if is_active():
		queue_redraw()


func is_active() -> bool:
	return active_zone != &"" or not shooters.is_empty() or not fired.is_empty()


func set_active_zone(zone: StringName) -> void:
	active_zone = zone
	queue_redraw()


func set_shooters(by_uid: Dictionary) -> void:
	shooters = by_uid.duplicate()
	queue_redraw()


func mark_fired(uid: int) -> void:
	if uid >= 0:
		fired[uid] = true
		queue_redraw()


func clear() -> void:
	active_zone = &""
	shooters.clear()
	fired.clear()
	queue_redraw()


## Overlay-local rect of a unit's slot (Rect2() when the board does not show it).
func unit_rect_local(uid: int) -> Rect2:
	if locator == null or uid < 0:
		return Rect2()
	var r: Rect2 = locator.unit_rect(uid)
	if not r.has_area():
		return Rect2()
	return Rect2(get_global_transform().affine_inverse() * r.position, r.size)


func _zone_rect_local(zone: StringName) -> Rect2:
	if locator == null:
		return Rect2()
	var r: Rect2 = locator.zone_rect(zone)
	if not r.has_area():
		return Rect2()
	return Rect2(get_global_transform().affine_inverse() * r.position, r.size)


## Where a fired pip sits: a round token centred ON the banner's inner edge (toward the objective),
## a third of the way along, so it reads as a marker on the card (not one of its plates) and stays
## clear of the FRONT tab (centre), the FP / Armor numbers and the keyword plates.
static func pip_rect(banner: Rect2, side: StringName, viewer: StringName) -> Rect2:
	var d: float = clampf(banner.size.y * 0.36, 18.0, 26.0)
	var cx: float = banner.position.x + banner.size.x * 0.34
	# The viewer's banners face the objective with their top edge; the rival's with their bottom.
	var cy: float = banner.position.y if side == viewer else banner.end.y
	return Rect2(cx - d * 0.5, cy - d * 0.5, d, d)


func _draw() -> void:
	if active_zone != &"":
		for z: StringName in ZONES:
			if z == active_zone:
				continue
			var zr: Rect2 = _zone_rect_local(z)
			if zr.has_area():
				draw_rect(zr, Color(FxStyle.SLATE, 0.5))
		var ar: Rect2 = _zone_rect_local(active_zone)
		if ar.has_area():
			draw_rect(ar.grow(1.0), Color(FxStyle.FOG, 0.35), false, 2.0)
	for uid: Variant in fired:
		var r: Rect2 = unit_rect_local(int(uid))
		if r.has_area():
			var side: StringName = _side_of(int(uid))
			_draw_cartridge(pip_rect(r, side, viewer_side))
	for uid: Variant in shooters:
		var r2: Rect2 = unit_rect_local(int(uid))
		if r2.has_area():
			_draw_now_firing(r2, FxStyle.side_color(StringName(shooters[uid])))


func _side_of(uid: int) -> StringName:
	if shooters.has(uid):
		return StringName(shooters[uid])
	if locator != null and locator.has_method(&"find_slot"):
		var slot: Control = locator.find_slot(uid)
		if slot != null and "side" in slot:
			return StringName(slot.get(&"side"))
	return viewer_side


## Thick side-coloured frame with a soft halo and corner brackets (the shape reads without colour).
func _draw_now_firing(r: Rect2, c: Color) -> void:
	draw_rect(r.grow(4.0), Color(c, 0.28), false, 5.0)
	draw_rect(r.grow(1.0), c, false, 3.0)
	var k: float = minf(14.0, r.size.y * 0.32)
	var g: Rect2 = r.grow(5.0)
	for corner: Array in [[g.position, Vector2(1, 1)], [Vector2(g.end.x, g.position.y), Vector2(-1, 1)],
			[Vector2(g.position.x, g.end.y), Vector2(1, -1)], [g.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(p, p + Vector2(d.x * k, 0), FxStyle.FOG, 3.0)
		draw_line(p, p + Vector2(0, d.y * k), FxStyle.FOG, 3.0)


## The fired token: a dark disc with a brass ring and a spent cartridge lying across it (shape, not
## only colour: the tilted case and its open neck).
func _draw_cartridge(r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.5
	draw_circle(c, rad, Color(FxStyle.SLATE, 0.95))
	draw_arc(c, rad - 1.0, 0.0, TAU, 20, BRASS, 2.0)
	var ax: Vector2 = Vector2(cos(-0.7), sin(-0.7))
	var ln: float = rad * 1.15
	var w: float = rad * 0.5
	var a: Vector2 = c - ax * ln * 0.5
	var b: Vector2 = c + ax * ln * 0.5
	var n: Vector2 = ax.orthogonal() * w * 0.5
	draw_colored_polygon(PackedVector2Array([a + n, b - ax * ln * 0.28 + n, b - ax * ln * 0.28 - n, a - n]), BRASS)
	draw_colored_polygon(PackedVector2Array([b - ax * ln * 0.28 + n * 0.6, b + n * 0.45, b - n * 0.45, b - ax * ln * 0.28 - n * 0.6]), BRASS_DARK)
	draw_line(a + n, a - n, BRASS_DARK, 2.0)
