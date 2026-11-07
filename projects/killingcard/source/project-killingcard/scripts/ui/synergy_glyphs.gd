# synergy_glyphs.gd
# Purpose: The synergy layer's drawn language (kc-syn-ui; synergy-system.md §9). Everything is a
#   SHAPE first and a colour second (accessibility): trait icons (Vanguard chevrons, Spec Ops mask,
#   Heavy gear, Undead hand from the ground), keyword glyphs with the arrow that points at the
#   neighbours they use (Guard shield + down, Spotter eye + up, Fireteam two chevrons sideways,
#   Overwatch crosshair sideways), the copy-level camo bands (Recruit none, Trained Gilded, Veteran
#   Forged, Elite Priceless), link ticks (vertical bar for Guard / Spotter, horizontal for Fireteam /
#   Overwatch) and the buffed / lowered stat colours. Pure static drawing on any CanvasItem, plus
#   the words the UI uses for them.
# Dependencies: SynergyRules (names and texts only).
# Author: UI/UX Agent (kc-syn-ui)
extends RefCounted

const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
## Trait tints (the icon shape is what identifies the trait; the tint only helps).
const TRAIT_COLORS: Dictionary = {
	&"vanguard": Color("#F2B544"), &"specops": Color("#8FB8FF"), &"heavy": Color("#C9D1D8"), &"undead": Color("#8EDB6A"),
}
## Stat colours: buffed up (green-gold) / lowered (red) / plain.
const UP: Color = Color("#7CF29A")
const DOWN: Color = Color("#FF6B6B")
## Copy-level camo bands (Trained = Gilded, Veteran = Forged, Elite = Priceless): base, dark, light.
const BANDS: Dictionary = {
	&"gilded": [Color("#C9A227"), Color("#7A5E12"), Color("#F3D36B")],
	&"forged": [Color("#D9DEE3"), Color("#7E878F"), Color("#FFFFFF")],
	&"priceless": [Color("#3E8EDE"), Color("#1B3F78"), Color("#9FE3FF")],
}
const BAND_NAMES: Dictionary = {&"": "plain frame", &"gilded": "Gilded", &"forged": "Forged", &"priceless": "Priceless"}
const KEYWORD_NAMES: Dictionary = {&"guard": "Guard", &"spotter": "Spotter", &"fireteam": "Fireteam", &"overwatch": "Overwatch"}
## Which neighbours a keyword uses, in words (inspector).
const KEYWORD_USES: Dictionary = {
	&"guard": "the card behind it", &"spotter": "the card in front of it",
	&"fireteam": "a friendly card beside it (same row, next column)", &"overwatch": "the cards beside it (same row, next column)",
}


static func trait_color(t: StringName) -> Color:
	return TRAIT_COLORS.get(t, Color("#D8DEE3"))


static func trait_name(t: StringName) -> String:
	return String(SynergyRules.TRAIT_NAMES.get(t, String(t).capitalize()))


static func keyword_name(kw: StringName) -> String:
	return String(KEYWORD_NAMES.get(kw, String(kw).capitalize()))


## "Vanguard 2: Vanguard in row 1 get +1 FP" for tier 2 / 3.
static func tier_line(t: StringName, tier: int) -> String:
	var texts: Array = SynergyRules.TIER_TEXT.get(t, ["", ""])
	return "%s %d: %s" % [trait_name(t), tier, String(texts[0 if tier <= 2 else 1])]


# =============================================================================
# Drawing
# =============================================================================

## A plate (dark square) with a trait icon. lit = the set is on (tier 2+): filled plate in the
## trait tint with a dark icon; ring = tier 3. Unlit: dark plate with a tinted icon.
static func draw_trait_plate(ci: CanvasItem, r: Rect2, t: StringName, lit: bool = false, ring: bool = false) -> void:
	var c: Color = trait_color(t)
	ci.draw_rect(r, c if lit else Color(INK, 0.85))
	ci.draw_rect(r, Color(c, 0.9) if not lit else INK, false, 1.0)
	draw_trait_icon(ci, r.grow(-r.size.x * 0.14), t, INK if lit else c)
	if ring:
		ci.draw_rect(r.grow(2.0), Color.WHITE, false, 2.0)


static func draw_trait_icon(ci: CanvasItem, r: Rect2, t: StringName, c: Color) -> void:
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	var w: float = maxf(1.5, s * 0.13)
	match t:
		&"vanguard":
			for k: int in 2:
				var y: float = s * (0.42 + k * 0.3)
				ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.14, y), o + Vector2(s * 0.5, y - s * 0.3), o + Vector2(s * 0.86, y)]), c, w)
		&"specops":
			var pts: PackedVector2Array = [o + Vector2(s * 0.08, s * 0.3), o + Vector2(s * 0.92, s * 0.3), o + Vector2(s * 0.84, s * 0.66),
					o + Vector2(s * 0.58, s * 0.62), o + Vector2(s * 0.5, s * 0.74), o + Vector2(s * 0.42, s * 0.62), o + Vector2(s * 0.16, s * 0.66)]
			ci.draw_colored_polygon(pts, c)
			var hole: Color = Color(INK, 1.0) if c != INK else Color(1, 1, 1, 0.9)
			ci.draw_rect(Rect2(o + Vector2(s * 0.22, s * 0.4), Vector2(s * 0.2, s * 0.1)), hole)
			ci.draw_rect(Rect2(o + Vector2(s * 0.58, s * 0.4), Vector2(s * 0.2, s * 0.1)), hole)
		&"heavy":
			var ctr: Vector2 = o + Vector2(s, s) * 0.5
			for k: int in 8:
				var a: float = TAU * k / 8.0
				ci.draw_line(ctr + Vector2(cos(a), sin(a)) * s * 0.26, ctr + Vector2(cos(a), sin(a)) * s * 0.46, c, w * 1.4)
			ci.draw_arc(ctr, s * 0.27, 0, TAU, 20, c, w * 1.2)
			ci.draw_circle(ctr, s * 0.09, c)
		&"undead":
			ci.draw_line(o + Vector2(s * 0.06, s * 0.88), o + Vector2(s * 0.94, s * 0.88), c, w)
			ci.draw_rect(Rect2(o + Vector2(s * 0.34, s * 0.5), Vector2(s * 0.34, s * 0.36)), c)
			for k: int in 4:
				var x: float = s * (0.36 + k * 0.085)
				ci.draw_line(o + Vector2(x, s * 0.52), o + Vector2(x, s * (0.14 + 0.06 * absf(k - 1.5))), c, w * 0.8)
			ci.draw_line(o + Vector2(s * 0.34, s * 0.62), o + Vector2(s * 0.2, s * 0.44), c, w * 0.8)


## Keyword glyph with its arrow (Guard ▼, Spotter ▲, Fireteam / Overwatch ◄►). up_dir: the
## objective is up (your banners); the rival's banners are mirrored, so their arrows flip.
static func draw_keyword_plate(ci: CanvasItem, r: Rect2, kw: StringName, active: bool, accent: Color, up_dir: bool = true) -> void:
	ci.draw_rect(r, Color(INK, 0.85))
	ci.draw_rect(r, Color(accent, 0.95) if active else Color(1, 1, 1, 0.18), false, 1.5 if active else 1.0)
	var c: Color = accent if active else Color("#7E8890")
	draw_keyword_icon(ci, r.grow(-r.size.x * 0.1), kw, c, up_dir)


static func draw_keyword_icon(ci: CanvasItem, r: Rect2, kw: StringName, c: Color, up_dir: bool = true) -> void:
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	var w: float = maxf(1.5, s * 0.11)
	var flip: float = 1.0 if up_dir else -1.0
	match kw:
		&"guard":
			# Shield on top, arrow pointing BEHIND (down for you).
			var sh: PackedVector2Array = [o + Vector2(s * 0.22, s * 0.08), o + Vector2(s * 0.78, s * 0.08), o + Vector2(s * 0.78, s * 0.36),
					o + Vector2(s * 0.5, s * 0.56), o + Vector2(s * 0.22, s * 0.36)]
			_flip_y(sh, o, s, flip)
			ci.draw_colored_polygon(sh, c)
			_arrow(ci, o, s, 0.62 if up_dir else 0.38, flip, c)
		&"spotter":
			# Eye at the bottom, arrow pointing IN FRONT (up for you).
			var ey: float = 0.7 if up_dir else 0.3
			var ctr: Vector2 = o + Vector2(s * 0.5, s * ey)
			var pts: PackedVector2Array = []
			for i: int in 13:
				var t: float = PI * i / 12.0
				pts.append(ctr + Vector2(-cos(t) * s * 0.4, -sin(t) * s * 0.2))
			for i: int in 13:
				var t: float = PI * i / 12.0
				pts.append(ctr + Vector2(cos(t) * s * 0.4, sin(t) * s * 0.2))
			ci.draw_polyline(pts, c, w)
			ci.draw_circle(ctr, s * 0.1, c)
			_arrow(ci, o, s, 0.4 if up_dir else 0.6, -flip, c)
		&"fireteam":
			for k: int in 2:
				var dx: float = -1.0 if k == 0 else 1.0
				var x0: float = s * (0.5 + dx * 0.1)
				var x1: float = s * (0.5 + dx * 0.42)
				ci.draw_polyline(PackedVector2Array([o + Vector2(x0, s * 0.22), o + Vector2(x1, s * 0.5), o + Vector2(x0, s * 0.78)]), c, w * 1.2)
		&"overwatch":
			var ctr2: Vector2 = o + Vector2(s, s) * 0.5
			ci.draw_arc(ctr2, s * 0.22, 0, TAU, 18, c, w)
			ci.draw_circle(ctr2, s * 0.05, c)
			ci.draw_line(o + Vector2(s * 0.5, s * 0.1), o + Vector2(s * 0.5, s * 0.24), c, w)
			ci.draw_line(o + Vector2(s * 0.5, s * 0.76), o + Vector2(s * 0.5, s * 0.9), c, w)
			for dx: float in [-1.0, 1.0]:
				var tip: Vector2 = o + Vector2(s * (0.5 + dx * 0.48), s * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-dx * s * 0.16, -s * 0.11), tip + Vector2(-dx * s * 0.16, s * 0.11)]), c)


## kc-fight-ui: the Pierce glyph (firefight-order.md §3): an arrow through a chevron, pointing down
## the enemy column (toward the rival's back row: up on your banners, down on theirs; down_dir false
## points it up). Drawn, not from the icon sheet.
static func draw_pierce_icon(ci: CanvasItem, r: Rect2, c: Color, down_dir: bool = true) -> void:
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	var w: float = maxf(2.0, s * 0.15)
	var d: float = 1.0 if down_dir else -1.0
	var y0: float = s * (0.5 - d * 0.46)
	var y1: float = s * (0.5 + d * 0.18)
	# Shaft through the chevron, then a wide head.
	ci.draw_line(o + Vector2(s * 0.5, y0), o + Vector2(s * 0.5, y1), c, w)
	var tip: Vector2 = o + Vector2(s * 0.5, s * (0.5 + d * 0.48))
	ci.draw_colored_polygon(PackedVector2Array([tip, o + Vector2(s * 0.24, y1), o + Vector2(s * 0.76, y1)]), c)
	var cy: float = s * (0.5 - d * 0.12)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.1, cy - d * s * 0.22), o + Vector2(s * 0.5, cy + d * s * 0.08),
			o + Vector2(s * 0.9, cy - d * s * 0.22)]), c, w)


## Pierce glyph on a dark plate (banner effect slot, glossary).
static func draw_pierce_plate(ci: CanvasItem, r: Rect2, c: Color, down_dir: bool = true) -> void:
	ci.draw_rect(r, Color(INK, 0.82))
	ci.draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)
	draw_pierce_icon(ci, r.grow(-r.size.x * 0.12), c, down_dir)


static func _flip_y(pts: PackedVector2Array, o: Vector2, s: float, flip: float) -> void:
	if flip > 0.0:
		return
	for i: int in pts.size():
		pts[i] = Vector2(pts[i].x, o.y + s - (pts[i].y - o.y))


## A small triangle whose base line sits at y (share of s), pointing down (dir 1) or up (dir -1).
static func _arrow(ci: CanvasItem, o: Vector2, s: float, y: float, dir: float, c: Color) -> void:
	var cy: float = s * y
	var tip: Vector2 = o + Vector2(s * 0.5, cy + dir * s * 0.24)
	ci.draw_colored_polygon(PackedVector2Array([tip, o + Vector2(s * 0.24, cy), o + Vector2(s * 0.76, cy)]), c)


## Camo band of a copy level (the weapon-mastery ladder). Recruit (&"") draws nothing.
static func draw_band(ci: CanvasItem, band: Rect2, band_id: StringName) -> void:
	if not BANDS.has(band_id) or band.size.x <= 0.0:
		return
	var cols: Array = BANDS[band_id]
	ci.draw_rect(band, cols[1])
	var cell: float = maxf(2.0, band.size.y / 2.0)
	var seed_v: int = 11 + band_id.length()
	var x: float = band.position.x
	while x < band.end.x:
		var y: float = band.position.y
		while y < band.end.y:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			var pick: int = seed_v % 5
			if pick < 2:
				ci.draw_rect(Rect2(x, y, minf(cell, band.end.x - x), minf(cell, band.end.y - y)), cols[0])
			elif pick == 2:
				ci.draw_rect(Rect2(x, y, minf(cell, band.end.x - x), minf(cell, band.end.y - y)), cols[2])
			y += cell
		x += cell


## A link tick between two banner edges: a short glowing bar (vertical for Guard / Spotter, a
## horizontal bar across the column gap for Fireteam / Overwatch). ghost = preview (dashed, 60%).
static func draw_tick(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, width: float, ghost: bool = false) -> void:
	if ghost:
		ci.draw_dashed_line(a, b, Color(c, 0.75), width, 4.0)
		return
	ci.draw_line(a, b, Color(c, 0.35), width + 4.0)
	ci.draw_line(a, b, c, width)
	ci.draw_circle(a, width * 0.75, c)
	ci.draw_circle(b, width * 0.75, c)


## A small dot (hand card: "this would complete a tier").
static func draw_dot(ci: CanvasItem, ctr: Vector2, rad: float, c: Color) -> void:
	ci.draw_circle(ctr, rad + 1.5, INK)
	ci.draw_circle(ctr, rad, c)
