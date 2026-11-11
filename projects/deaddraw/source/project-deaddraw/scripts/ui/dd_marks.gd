# dd_marks.gd
# Purpose: dd-ux-v4: small vector marks drawn with Control._draw (no image assets), shared by the
#   street, the gun tiles, the Glossary and the Codex:
#   - StrengthMark: the zombie strength mark (M2). Tier colour + the number, in a shape that reads
#     as threat / attack AND toughness, not a shield. Variant "claw" (the pick: a disc raked by
#     1-4 claw slashes, one per tier) and the alternatives "fang" (a jaw with 2-5 fangs) and
#     "spike" (a jagged splat, 7-13 spikes). The tier (Shambler 1-3, Lurcher 4-6, Bruiser 7-9,
#     Hulk 10+) is the colour AND a count, so it reads for colour-blind players too.
#   - HitBurst: the weapon's hit number in a yellow 8-point burst (every gun, melee, Codex entry).
#   - Padlock: closed / open padlock icon for the room price plate.
#   - Socket: an empty kill socket (dashed) or the next one (gold dashed + what it accepts).
#   - WaveNumeral: the big blood-red wave number on the wave door (slams in on a new wave).
# Dependencies: DDUi. Loaded with preload() (no class_name, so no class-cache rescan).
# Author: UI/UX Agent (dd-ux-v4)
extends RefCounted

const INK: Color = Color("151214")
const BONE: Color = Color("ece6d6")
const BURST_YELLOW: Color = Color("f2c14e")
const BLOOD: Color = Color("c8322a")
## Tier colours (Shambler, Lurcher, Bruiser, Hulk): bone, amber, orange, red.
const TIER_COLORS: Array[Color] = [Color("bdb5a0"), Color("d99a3c"), Color("e8793a"), Color("e2574c")]
const TIER_NAMES: Array[String] = ["Shambler", "Lurcher", "Bruiser", "Hulk"]
## The strength mark the game uses (see ux-v4-pass.md for the alternatives).
const STRENGTH_VARIANT: String = "claw"


static func tier_of(n: int) -> int:
	return Mark.tier_of(n)


# ================================================================ shared base
class Mark:
	extends Control

	static func tier_of(n: int) -> int:
		if n <= 3:
			return 0
		if n <= 6:
			return 1
		if n <= 9:
			return 2
		return 3


	static func _font() -> Font:
		return ThemeDB.fallback_font


	## Draws text centred on c with an ink outline.
	static func draw_num(ci: CanvasItem, text: String, c: Vector2, fs: int, col: Color, outline: Color = Color(0, 0, 0, 0), ow: int = 0) -> void:
		var f: Font = _font()
		var sz: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos: Vector2 = Vector2(c.x - sz.x * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
		if ow > 0:
			ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, outline)
		ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


	static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		var out: PackedVector2Array = pts.duplicate()
		out.append(pts[0])
		return out


# ================================================================ strength mark
class StrengthMark:
	extends Mark
	var value: int = 1
	var variant: String = "claw"

	func _init(v: int = 1, var_name: String = "") -> void:
		value = v
		variant = var_name if var_name != "" else STRENGTH_VARIANT
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s <= 4.0:
			return
		var t: int = tier_of(value)
		var col: Color = TIER_COLORS[t]
		var c: Vector2 = size * 0.5
		var num_col: Color = INK if t < 3 else Color.WHITE
		match variant:
			"fang":
				_fang(c, s, col, t)
				draw_num(self, str(value), c - Vector2(0, s * 0.07), int(s * 0.44), num_col)
			"spike":
				_spike(c, s, col, t)
				draw_num(self, str(value), c, int(s * 0.42), num_col)
			_:
				_claw(c, s, col, t)
				draw_num(self, str(value), c + Vector2(-s * 0.05, 0), int(s * 0.44), num_col)

	## A tier-coloured disc raked by 1-4 claw slashes that tear out past its upper right edge.
	func _claw(c: Vector2, s: float, col: Color, t: int) -> void:
		var r: float = s * 0.36
		var cc: Vector2 = c + Vector2(-s * 0.07, s * 0.05)
		var n: int = t + 1
		var gap: float = s * 0.12
		var slashes: Array = []
		for k: int in n:
			var off: float = (k - (n - 1) * 0.5) * gap
			var a: Vector2 = cc + Vector2(-s * 0.02 + off, -s * 0.50 + off * 0.2)
			var b: Vector2 = cc + Vector2(s * 0.56 + off * 0.2, s * 0.02 + off)
			slashes.append([a, b])
		# ink outlines first, then the disc, then the slashes on top (they tear across its rim)
		for sl: Array in slashes:
			draw_colored_polygon(_leaf(sl[0], sl[1], s * 0.085 + 3.0, 3.0), INK)
		draw_circle(cc, r + 3.0, INK)
		draw_circle(cc, r, col)
		for sl2: Array in slashes:
			draw_colored_polygon(_leaf(sl2[0], sl2[1], s * 0.085, 0.0), col.lightened(0.25))
			draw_colored_polygon(_leaf(sl2[0], sl2[1], s * 0.03, -s * 0.06), INK.lightened(0.1))

	## A curved, tapered slash from a to b (bowed to one side), half-width w; ext lengthens the tips.
	func _leaf(a: Vector2, b: Vector2, w: float, ext: float) -> PackedVector2Array:
		var d: Vector2 = (b - a).normalized()
		var nrm: Vector2 = Vector2(-d.y, d.x)
		var a2: Vector2 = a - d * ext
		var b2: Vector2 = b + d * ext
		var pts: PackedVector2Array = []
		var steps: int = 10
		for k: int in steps + 1:
			var u: float = float(k) / steps
			var bow: float = sin(u * PI) * (b2 - a2).length() * 0.12
			pts.append(a2.lerp(b2, u) + nrm * (bow + sin(u * PI) * w))
		for k2: int in range(steps - 1, 0, -1):
			var u2: float = float(k2) / steps
			var bow2: float = sin(u2 * PI) * (b2 - a2).length() * 0.12
			pts.append(a2.lerp(b2, u2) + nrm * (bow2 - sin(u2 * PI) * w))
		return pts

	## A jaw: flat top, 2-5 fangs along the bottom (one more per tier).
	func _fang(c: Vector2, s: float, col: Color, t: int) -> void:
		var w: float = s * 0.86
		var x0: float = c.x - w * 0.5
		var x1: float = c.x + w * 0.5
		var y0: float = c.y - s * 0.44
		var ym: float = c.y + s * 0.12
		var y1: float = c.y + s * 0.48
		var fangs: int = t + 2
		var pts: PackedVector2Array = []
		for k0: int in 13:
			var ang: float = PI + PI * k0 / 12.0
			pts.append(Vector2(c.x + cos(ang) * w * 0.5, y0 + s * 0.2 + sin(ang) * s * 0.2))
		pts.append(Vector2(x1, ym))
		var fw: float = w / fangs
		for k: int in range(fangs - 1, -1, -1):
			var fx: float = x0 + fw * k
			pts.append(Vector2(fx + fw * 0.5, y1))
			pts.append(Vector2(fx, ym))
		draw_colored_polygon(pts, col)
		draw_polyline(_closed(pts), INK, 3.0, true)

	## A jagged splat: 7-13 spikes, sharper with each tier.
	func _spike(c: Vector2, s: float, col: Color, t: int) -> void:
		var m: int = 7 + t * 2
		var ro: float = s * 0.48
		var ri: float = s * (0.36 - t * 0.02)
		var pts: PackedVector2Array = []
		for k: int in m * 2:
			var ang: float = -PI * 0.5 + PI * k / m
			var jit: float = 1.0 + 0.08 * sin(k * 2.3 + value)
			var rr: float = (ro if k % 2 == 0 else ri) * jit
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, col)
		draw_polyline(_closed(pts), INK, 3.0, true)


# ================================================================ hit burst
class HitBurst:
	extends Mark
	var value: int = 2

	func _init(v: int = 2) -> void:
		value = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s <= 4.0:
			return
		var c: Vector2 = size * 0.5
		var pts: PackedVector2Array = []
		for k: int in 16:
			var ang: float = -PI * 0.5 + PI * k / 8.0
			var rr: float = s * (0.49 if k % 2 == 0 else 0.29)
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, BURST_YELLOW)
		draw_polyline(_closed(pts), INK, maxf(2.0, s * 0.06), true)
		draw_num(self, str(value), c + Vector2(0, 1), int(s * 0.42), INK)


# ================================================================ padlock
class Padlock:
	extends Mark
	var open: bool = false
	var color: Color = BONE

	func _init(is_open: bool = false, col: Color = BONE) -> void:
		open = is_open
		color = col
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h: float = size.y
		var w: float = minf(size.x, h * 0.9)
		var x: float = (size.x - w) * 0.5
		var body: Rect2 = Rect2(x, h * 0.45, w, h * 0.55)
		var sw: float = maxf(2.0, w * 0.16)
		var sc: Vector2 = Vector2(x + w * 0.5, h * 0.45)
		var sr: float = w * 0.3
		if open:
			# the shackle swung up and to the side
			draw_arc(sc + Vector2(w * 0.32, -h * 0.12), sr, PI, TAU, 16, color, sw, true)
			draw_line(sc + Vector2(w * 0.32 + sr, -h * 0.12), sc + Vector2(w * 0.32 + sr, h * 0.0), color, sw)
		else:
			draw_arc(sc, sr, PI, TAU, 16, color, sw, true)
			draw_line(sc + Vector2(-sr, 0), sc + Vector2(-sr, h * 0.05), color, sw)
			draw_line(sc + Vector2(sr, 0), sc + Vector2(sr, h * 0.05), color, sw)
		draw_rect(body, color)
		draw_circle(body.get_center() - Vector2(0, h * 0.04), maxf(1.5, w * 0.1), INK)


# ================================================================ kill socket (empty / next)
class Socket:
	extends Mark
	var next_text: String = ""
	var is_next: bool = false

	func _init(nxt: bool = false, txt: String = "") -> void:
		is_next = nxt
		next_text = txt
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3))
		draw_rect(r, Color(0, 0, 0, 0.28))
		var col: Color = BURST_YELLOW if is_next else Color("4f5b62")
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for k: int in 4:
			draw_dashed_line(corners[k], corners[(k + 1) % 4], col, 2.0, 5.0)
		if is_next and next_text != "":
			var fs: int = int(clampf(minf(size.x * 0.34, size.y * 0.3), 11.0, 24.0))
			while fs > 9 and _font().get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 6.0:
				fs -= 1
			draw_num(self, next_text, size * 0.5, fs, BURST_YELLOW)


# ================================================================ the big wave numeral
class WaveNumeral:
	extends Mark
	var text: String = "1"
	var font_px: int = 64

	func _init(t: String = "1") -> void:
		text = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fs: int = int(minf(size.y * 0.95, size.x * (0.9 if text.length() <= 1 else 0.55)))
		if fs < 8:
			return
		font_px = fs
		draw_num(self, text, size * 0.5 + Vector2(0, 2), fs, BLOOD, Color(0, 0, 0, 0.95), maxi(4, fs / 10))
