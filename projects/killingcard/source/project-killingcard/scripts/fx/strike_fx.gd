# strike_fx.gd
# Purpose: kc-ks-seq. One killstreak's own sequence on the board, so each streak reads differently
#   (studio head: "a huge flash popup that is the same for all killstreaks"):
#     &"shells"  Mortar Barrage: a lock reticle on the column, then one shell per target arcs in from
#                the caster's edge with a fading trail (the whistle plays), and bursts on its unit
#                (kit fx_hit_flash + a shock ring + debris). impact_times() says when each lands, so the
#                damage numbers land with them.
#     &"strafe"  Attack Helo: the helo icon flies across the top of the board with a rotor blur and
#                a shadow; over each column it fires a three-round burst (kit fx_tracer streaks) into
#                that column's front unit.
#     &"scan"    Recon Drone: a scan bar sweeps across the scanned half with the drone riding it,
#                leaving a faint grid; corner brackets lock when it is done.
#     &"drop"    Sentry Turret: a drop beam, the sentry icon falls to the back of its column, lands
#                with a ring and locks four brackets around itself.
#   Reduced motion: nothing travels; the end frame fades in and out where it lands. Fast animations
#   halve it (timing keys ks_shells / ks_strafe / ks_scan / ks_drop).
#   kc-da-ui: `color` is the OWNER's colour (teal yours, red the rival's; KillstreakFx.owner_color),
#   never a per-kind hue: the icon and the motion tell the kind. Impact flashes stay warm white.
#   Coordinates are local to the parent overlay. Display only.
# Dependencies: fx_transient.gd, fx_style.gd, UiKit (fx_hit_flash, fx_tracer pieces; optional).
# Author: Game Feel Engineer Agent (kc-ks-seq)
extends "res://scripts/fx/fx_transient.gd"

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const FLASH_PIECE: StringName = &"fx_hit_flash"
const TRACER_PIECE: StringName = &"fx_tracer"
## Shells: share of the sequence before the first shell leaves (the reticle locks), the gap between
## shells and each shell's flight.
const SHELL_LEAD: float = 0.18
const SHELL_GAP: float = 0.09
const SHELL_FLIGHT: float = 0.45
## Seconds an impact burst lasts as a share of the sequence.
const BURST: float = 0.22
## Impact flash and sparks: warm light (art direction §8), whoever fired.
const WARM: Color = Color("#FFE2B0")

var style: StringName = &"shells"
## The owner's colour (teal yours, red the rival's), set by the director.
var color: Color = FxStyle.TEAL
var icon: Texture2D = null
## Where shells leave from / where the helo enters.
var origin: Vector2 = Vector2.ZERO
## Shell landings / burst targets (one per hit unit, or the column centre when nothing is hit).
var targets: Array[Vector2] = []
## Scan area, or the column for a drop.
var area: Rect2 = Rect2()
## Drop landing point.
var end_point: Vector2 = Vector2.ZERO
var reduced: bool = false

var _k: float = 0.0
var _len: float = 0.0
var _kit: Control = null


func _ready() -> void:
	fx_kind = style
	if UiKit.has_piece(FLASH_PIECE) or UiKit.has_piece(TRACER_PIECE):
		_kit = UiKit.fx_layer(self, _draw_kit, false, "KitStrike")


func _build(t: Tween, timing: RefCounted) -> void:
	_len = maxf(0.05, timing.get_value(key_for(style)))
	reduced = reduced or timing.reduced_motion
	t.tween_method(_set_k, 0.0, 1.0, _len)


func _planned_duration(_timing: RefCounted) -> float:
	return _len


static func key_for(s: StringName) -> StringName:
	return {&"shells": &"ks_shells", &"strafe": &"ks_strafe", &"scan": &"ks_scan", &"drop": &"ks_drop"}.get(s, &"ks_shells")


func _set_k(v: float) -> void:
	_k = v
	queue_redraw()
	if _kit != null:
		_kit.queue_redraw()


## Seconds after play() at which each target is hit (same order as targets).
func impact_times(timing: RefCounted) -> Array[float]:
	var total: float = maxf(0.05, timing.get_value(key_for(style)))
	var out: Array[float] = []
	for i: int in targets.size():
		out.append(total * _impact_k(i))
	return out


## Progress (0..1) at which target i is hit.
func _impact_k(i: int) -> float:
	if reduced:
		return 0.45
	match style:
		&"shells":
			return minf(0.95, SHELL_LEAD + i * SHELL_GAP + SHELL_FLIGHT)
		&"strafe":
			var p: Vector2 = targets[i]
			return clampf(_helo_k_at(p.x) + 0.06, 0.05, 0.95)
		&"drop":
			return 0.62
	return 0.5


# --- helpers -----------------------------------------------------------------------------

func _shell_pos(i: int, k: float) -> Vector2:
	var to: Vector2 = targets[i]
	var t0: float = SHELL_LEAD + i * SHELL_GAP
	var u: float = clampf((k - t0) / SHELL_FLIGHT, 0.0, 1.0)
	var lift: float = maxf(60.0, origin.distance_to(to) * 0.55)
	var p: Vector2 = origin.lerp(to, u)
	p.y -= 4.0 * lift * u * (1.0 - u)
	return p


func _helo_span() -> Vector2:
	var left: float = area.position.x - 40.0
	var right: float = area.end.x + 40.0
	return Vector2(left, right) if origin.x <= area.get_center().x else Vector2(right, left)


func _helo_k_at(x: float) -> float:
	var span: Vector2 = _helo_span()
	return clampf((x - span.x) / (span.y - span.x), 0.0, 1.0) if span.y != span.x else 0.5


func _helo_pos(k: float) -> Vector2:
	var span: Vector2 = _helo_span()
	# Over the objective line between the two halves, clear of the killfeed at the top.
	return Vector2(lerpf(span.x, span.y, k), area.get_center().y - 4.0 + sin(k * TAU) * 3.0)


func _burst_alpha(k: float, at: float) -> float:
	var d: float = (k - at) / BURST
	return 0.0 if d < 0.0 or d > 1.0 else 1.0 - d


func _draw_icon(center: Vector2, s: float, tint: Color) -> void:
	if icon != null:
		draw_texture_rect(icon, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		draw_circle(center, s * 0.3, tint)


func _brackets(r: Rect2, c: Color, arm: float, w: float) -> void:
	for sx: float in [0.0, 1.0]:
		for sy: float in [0.0, 1.0]:
			var p: Vector2 = r.position + Vector2(r.size.x * sx, r.size.y * sy)
			var dx: float = arm if sx == 0.0 else -arm
			var dy: float = arm if sy == 0.0 else -arm
			draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), c, w, true)


func _fade_all(k: float) -> float:
	return clampf(minf(k / 0.12, (1.0 - k) / 0.15), 0.0, 1.0)


# --- drawing -----------------------------------------------------------------------------

func _draw() -> void:
	match style:
		&"shells":
			_draw_shells()
		&"strafe":
			_draw_strafe()
		&"scan":
			_draw_scan()
		&"drop":
			_draw_drop()


func _draw_shells() -> void:
	var k: float = _k
	# Lock reticle over every landing point (shrinks onto it before the shells arrive).
	var lock_a: float = clampf(1.0 - (k - 0.75) / 0.2, 0.0, 1.0) * clampf(k / 0.1, 0.0, 1.0)
	for i: int in targets.size():
		var p: Vector2 = targets[i]
		var r: float = lerpf(30.0, 15.0, clampf(k / (SHELL_LEAD + 0.1), 0.0, 1.0))
		draw_arc(p, r, 0.0, TAU, 28, Color(color, 0.8 * lock_a), 2.0, true)
		for a: int in 4:
			var dir: Vector2 = Vector2.RIGHT.rotated(a * PI * 0.5 + PI * 0.25)
			draw_line(p + dir * (r - 5.0), p + dir * (r + 5.0), Color(color, lock_a), 2.0, true)
	if reduced:
		for i: int in targets.size():
			var a: float = _burst_alpha(k, 0.45) if k >= 0.45 else 0.0
			draw_circle(targets[i], 18.0, Color(color, 0.45 * a))
		return
	for i: int in targets.size():
		var t0: float = SHELL_LEAD + i * SHELL_GAP
		var land: float = _impact_k(i)
		if k >= t0 and k < land:
			# Trail: the last stretch of the arc, fading toward the tail.
			var pts: PackedVector2Array = PackedVector2Array()
			var cols: PackedColorArray = PackedColorArray()
			for j: int in 8:
				var kk: float = maxf(t0, k - 0.07 * (7 - j) / 7.0)
				pts.append(_shell_pos(i, kk))
				cols.append(Color(color, 0.15 + 0.85 * j / 7.0))
			draw_polyline_colors(pts, cols, 3.0, true)
			var head: Vector2 = _shell_pos(i, k)
			draw_circle(head, 4.5, FxStyle.FOG)
			draw_circle(head, 2.5, color.lightened(0.4))
		var a: float = _burst_alpha(k, land)
		if a > 0.0:
			var grow: float = 1.0 - a
			draw_arc(targets[i], 10.0 + 34.0 * grow, 0.0, TAU, 32, Color(color, a), 3.0 * a + 1.0, true)
			draw_circle(targets[i], 14.0 * a, Color(FxStyle.FOG, 0.7 * a))
			for d: int in 6:
				var dir: Vector2 = Vector2.UP.rotated(d * TAU / 6.0 + i)
				var p0: Vector2 = targets[i] + dir * (8.0 + 20.0 * grow)
				draw_line(p0, p0 + dir * 8.0, Color(WARM, a), 2.0, true)


func _draw_strafe() -> void:
	var k: float = _k
	var a_all: float = _fade_all(k) if not reduced else clampf(1.0 - absf(k - 0.45) / 0.45, 0.0, 1.0)
	var helo: Vector2 = _helo_pos(0.5 if reduced else k)
	# Shadow and rotor blur.
	draw_set_transform(Vector2(helo.x + 10.0, helo.y + 26.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.25 * a_all))
	draw_set_transform(Vector2.ZERO)
	var blade: float = (k * 40.0) if not reduced else 0.0
	for b: int in 2:
		var dir: Vector2 = Vector2.RIGHT.rotated(blade + b * PI * 0.5)
		draw_line(helo - dir * 26.0 + Vector2(0, -14), helo + dir * 26.0 + Vector2(0, -14), Color(FxStyle.FOG, 0.5 * a_all), 2.0, true)
	_draw_icon(helo, 40.0, Color(color.lightened(0.2), a_all))
	# Bursts: three rounds into each target as the helo passes it.
	for i: int in targets.size():
		var at: float = _impact_k(i)
		for r: int in 3:
			var start: float = at - 0.1 + r * 0.035
			var u: float = clampf((k - start) / 0.06, 0.0, 1.0)
			var fade: float = clampf(1.0 - (k - start - 0.06) / 0.08, 0.0, 1.0)
			if k < start or fade <= 0.0:
				continue
			var from: Vector2 = helo + Vector2(0, 10)
			var to: Vector2 = targets[i] + Vector2((r - 1) * 5.0, 0)
			draw_line(from.lerp(to, maxf(0.0, u - 0.4)), from.lerp(to, u), Color(color.lightened(0.4), fade), 2.0, true)
		var a: float = _burst_alpha(k, at)
		if a > 0.0:
			draw_arc(targets[i], 8.0 + 18.0 * (1.0 - a), 0.0, TAU, 24, Color(color, a), 2.0, true)


func _draw_scan() -> void:
	var k: float = _k
	var a_all: float = _fade_all(k)
	var r: Rect2 = area
	# Faint grid where the scan has passed.
	var x_now: float = r.position.x + r.size.x * (1.0 if reduced else k)
	var gc: Color = Color(color, 0.18 * a_all)
	var step: float = 22.0
	var y: float = r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(x_now, y), gc, 1.0)
		y += step
	var x: float = r.position.x
	while x <= x_now:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), gc, 1.0)
		x += step
	if not reduced:
		# The bar with a soft wake behind it, and the drone riding on top.
		for w: int in 6:
			draw_rect(Rect2(x_now - (w + 1) * 6.0, r.position.y, 6.0, r.size.y), Color(color, 0.12 * (6 - w) / 6.0 * a_all))
		draw_line(Vector2(x_now, r.position.y), Vector2(x_now, r.end.y), Color(color.lightened(0.3), a_all), 3.0)
		_draw_icon(Vector2(x_now, r.position.y - 4.0), 30.0, Color(FxStyle.FOG, a_all))
	var lock: float = clampf((k - 0.8) / 0.12, 0.0, 1.0) * a_all if not reduced else a_all
	if lock > 0.0:
		_brackets(r.grow(-4.0), Color(color, lock), 18.0, 3.0)


func _draw_drop() -> void:
	var k: float = _k
	var a_all: float = _fade_all(k)
	var land_k: float = _impact_k(0)
	var top: Vector2 = Vector2(end_point.x, area.position.y - 30.0)
	var u: float = 1.0 if reduced else clampf(k / land_k, 0.0, 1.0)
	var pos: Vector2 = top.lerp(end_point, u * u)
	# Drop beam (dashed) from the top of the column.
	var beam_a: float = (1.0 - clampf((k - land_k) / 0.2, 0.0, 1.0)) * a_all
	var y: float = top.y
	while y < end_point.y:
		draw_line(Vector2(end_point.x, y), Vector2(end_point.x, minf(y + 7.0, end_point.y)), Color(color, 0.5 * beam_a), 2.0)
		y += 12.0
	_draw_icon(pos, 36.0, Color(FxStyle.FOG, a_all))
	var a: float = _burst_alpha(k, land_k)
	if a > 0.0:
		draw_arc(end_point, 12.0 + 30.0 * (1.0 - a), 0.0, TAU, 32, Color(color, a), 3.0, true)
	if k >= land_k:
		var lock: float = clampf((k - land_k) / 0.12, 0.0, 1.0) * a_all
		_brackets(Rect2(end_point - Vector2(26, 26), Vector2(52, 52)), Color(color, lock), 10.0, 3.0)


## The kit's additive flashes on impact and tracer streaks for the helo bursts.
func _draw_kit(layer: Control) -> void:
	if style in [&"shells", &"strafe", &"drop"] and UiKit.has_piece(FLASH_PIECE):
		for i: int in targets.size():
			var a: float = _burst_alpha(_k, _impact_k(i))
			if a > 0.0:
				var s: float = (70.0 if style == &"shells" else 44.0) * (0.6 + 0.4 * (1.0 - a))
				UiKit.draw_piece(layer, FLASH_PIECE, Rect2(targets[i] - Vector2(s, s) * 0.5, Vector2(s, s)), Color(WARM, a))
	if style == &"strafe" and not reduced and UiKit.has_piece(TRACER_PIECE):
		var helo: Vector2 = _helo_pos(_k)
		for i: int in targets.size():
			var at: float = _impact_k(i)
			var fade: float = clampf(1.0 - absf(_k - at + 0.04) / 0.07, 0.0, 1.0)
			if fade <= 0.0:
				continue
			var a: Vector2 = helo + Vector2(0, 10)
			var b: Vector2 = targets[i]
			layer.draw_set_transform(a, (b - a).angle())
			UiKit.draw_piece(layer, TRACER_PIECE, Rect2(0.0, -5.0, a.distance_to(b), 10.0), Color(color.lightened(0.35), fade))
			layer.draw_set_transform(Vector2.ZERO)
