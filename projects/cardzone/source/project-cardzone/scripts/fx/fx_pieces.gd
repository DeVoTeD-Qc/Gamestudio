# fx_pieces.gd
# Purpose: The drawn pieces of CardZone's feedback layer (cz17). Each is a small Control that never
#   takes input and redraws when a tweened property changes. Flat shapes only: clipped tags, lines,
#   rings, hatching. No glows, no rays, no bevels (art-direction.md section 8). Lime appears only in
#   the gas pieces; violet only as the safe-zone edge.
#   Tracer        shot / Frag / move line between two points (travelling head, or whole + fade)
#   Marker        hit marker: four corner brackets on a rect, plus a number tag
#   Blast         Frag blast: a ring growing on an area, then fading
#   GasSweep      lime overlay with the 45 deg hatch sweeping left to right across a tile
#   Crate         supply crate (stencil plate) with a shadow and a rarity chip
#   Tag           clipped-tag plate with text and an optional icon
#   PanelPulse    an outline pulsing around a rect (Down, Bounty heal)
#   Stamp         the elimination stamp plate (title + caption)
# Usage: const P := preload("res://scripts/fx/fx_pieces.gd"); var t := P.Tracer.new()
# Dependencies: CzArtKit, CzIcons (cz16, API only).
# Author: Game Feel Engineer Agent (cz17)
extends RefCounted


class Piece:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _redraw_prop(_v: Variant = null) -> void:
		queue_redraw()


## A line from `a` to `b` (layer coordinates). `head` 0..1 is how far the tracer has run; `fade`
## 0..1 dims it. kind: &"shot" (paper head, red tail), &"frag" (arc), &"move" (dashed paper).
class Tracer:
	extends Piece
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var kind: StringName = &"shot"
	var width: float = 3.0
	var head: float = 1.0:
		set(v):
			head = v
			queue_redraw()
	var fade: float = 1.0:
		set(v):
			fade = v
			queue_redraw()

	func point_at(t: float) -> Vector2:
		if kind == &"frag":
			var mid: Vector2 = (a + b) * 0.5 + Vector2(0, -maxf(40.0, a.distance_to(b) * 0.45))
			return a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		return a.lerp(b, t)

	func _draw() -> void:
		if fade <= 0.0:
			return
		var steps: int = 14 if kind == &"frag" else 1
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in steps + 1:
			pts.append(point_at(head * float(i) / steps))
		match kind:
			&"move":
				for i: int in pts.size() - 1:
					draw_dashed_line(pts[i], pts[i + 1], Color(CzArtKit.PAPER, 0.85 * fade), width, width * 3.0)
				draw_circle(a, width * 1.6, Color(CzArtKit.PAPER, 0.85 * fade))
			_:
				# Tail: a thin hit_red line behind the head; head: a short paper streak.
				draw_polyline(pts, Color(CzArtKit.HIT_RED, 0.55 * fade), width, true)
				var h: Vector2 = point_at(head)
				var back: Vector2 = point_at(maxf(head - 0.18, 0.0))
				draw_line(back, h, Color(CzArtKit.PAPER, fade), width * 1.6, true)
				draw_circle(a, width * 1.8, Color(CzArtKit.HIT_RED, fade))


## Four corner brackets around `box` (local rect), `snap` 1 = in place (2 = twice as far out).
class Marker:
	extends Piece
	var box: Rect2 = Rect2()
	var color: Color = CzArtKit.HIT_RED
	var width: float = 4.0
	var snap: float = 1.0:
		set(v):
			snap = v
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = box.get_center()
		var half: Vector2 = box.size * 0.5 * snap
		var arm: float = minf(box.size.x, box.size.y) * 0.28
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var corner: Vector2 = c + Vector2(half.x * sx, half.y * sy)
				var pts: PackedVector2Array = PackedVector2Array([corner + Vector2(-sx * arm, 0), corner, corner + Vector2(0, -sy * arm)])
				draw_polyline(pts, CzArtKit.INK, width + 3.0)
				draw_polyline(pts, color, width)
		# Centre cross: a small X (hit) in the marker colour.
		var x: float = arm * 0.35
		draw_line(c + Vector2(-x, -x), c + Vector2(x, x), color, width)
		draw_line(c + Vector2(-x, x), c + Vector2(x, -x), color, width)


## A ring at `center` growing to `radius` x grow while fading (Frag blast).
class Blast:
	extends Piece
	var center: Vector2 = Vector2.ZERO
	var radius: float = 30.0
	var grow: float = 0.0:
		set(v):
			grow = v
			queue_redraw()

	func _draw() -> void:
		var r: float = radius * (0.35 + 0.65 * grow)
		var a: float = 1.0 - grow * 0.85
		draw_arc(center, r, 0.0, TAU, 40, Color(CzArtKit.INK, a * 0.8), 9.0, true)
		draw_arc(center, r, 0.0, TAU, 40, Color(CzArtKit.HIT_RED, a), 5.0, true)


## Gas closing over `box`: lime at 55 % with the 45 deg gas_shade hatch, swept from the left up to
## `sweep` (0..1), its leading edge a dashed gas_glow line. Lime is the gas colour: gas only.
class GasSweep:
	extends Piece
	var box: Rect2 = Rect2()
	var cut: float = 8.0
	var pitch: float = 9.0
	var sweep: float = 0.0:
		set(v):
			sweep = v
			queue_redraw()

	func _draw() -> void:
		if sweep <= 0.0:
			return
		var w: float = box.size.x * clampf(sweep, 0.0, 1.0)
		var r: Rect2 = Rect2(box.position, Vector2(w, box.size.y))
		if w < 0.5:
			return
		var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(CzArtKit.tag_points(box, cut), PackedVector2Array(
				[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		if parts.is_empty() or parts[0].size() < 3:
			return
		var pts: PackedVector2Array = parts[0]
		draw_colored_polygon(pts, Color(CzArtKit.GAS_LIME, 0.55))
		# Hatch: 45 deg lines, clipped to the swept part.
		var x0: float = box.position.x - box.size.y
		while x0 < r.end.x:
			var p0: Vector2 = Vector2(x0, box.end.y)
			var p1: Vector2 = Vector2(x0 + box.size.y, box.position.y)
			for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([p0, p1]), pts):
				if seg.size() >= 2:
					draw_line(seg[0], seg[1], Color(CzArtKit.GAS_SHADE, 0.7), 2.0)
			x0 += pitch
		if sweep < 1.0:
			draw_dashed_line(Vector2(r.end.x, box.position.y), Vector2(r.end.x, box.end.y), CzArtKit.GAS_GLOW, 3.0, 10.0)


## A supply crate: a clipped rust plate with a dune lid band and the supply_drop mark, a shadow
## under it (`shadow` 0..1) and the contents' rarity chip.
class Crate:
	extends Piece
	var rarity: StringName = &""
	var shadow: float = 1.0:
		set(v):
			shadow = v
			queue_redraw()
	var ground: Vector2 = Vector2.ZERO  # shadow centre (layer coordinates relative to this piece)

	func _draw() -> void:
		var s: Vector2 = size
		if shadow > 0.0:
			var rx: float = s.x * 0.55 * (0.4 + 0.6 * shadow)
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 20:
				var a: float = TAU * i / 20.0
				pts.append(ground + Vector2(cos(a) * rx, sin(a) * rx * 0.28))
			draw_colored_polygon(pts, Color(CzArtKit.INK, 0.45 * shadow))
		var box: Rect2 = Rect2(Vector2.ZERO, s)
		CzArtKit.draw_tag(self, box, s.x * 0.14, CzArtKit.RUST, CzArtKit.INK, 3.0)
		var band: Rect2 = Rect2(Vector2(3, s.y * 0.18), Vector2(s.x - 6, s.y * 0.14))
		draw_rect(band, CzArtKit.DUNE)
		var icon: Texture2D = CzIcons.get_icon(&"supply_drop", s.x * 0.5)
		if icon != null:
			var ir: Rect2 = Rect2(Vector2(s.x * 0.25, s.y * 0.38), Vector2(s.x * 0.5, s.x * 0.5))
			draw_texture_rect(icon, ir, false, CzArtKit.INK)
		if rarity != &"":
			var rd: Dictionary = CzArtKit.rarity(rarity)
			var chip: Rect2 = Rect2(Vector2(s.x - s.x * 0.42, -s.x * 0.16), Vector2(s.x * 0.42, s.x * 0.3))
			CzArtKit.draw_tag(self, chip, 4.0, rd["color"], CzArtKit.INK, 2.0)
			var px: int = maxi(10, int(chip.size.y * 0.75))
			draw_string(CzArtKit.font_display(), Vector2(chip.position.x, chip.get_center().y + px * 0.36), rd["letter"],
					HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, px, rd["text"])


## A clipped-tag plate with a line of text (and an icon on the left). Sizes itself (fit()).
class Tag:
	extends Piece
	var text: String = ""
	var icon: StringName = &""
	var fill: Color = CzArtKit.INK
	var line: Color = CzArtKit.PAPER
	var ink: Color = CzArtKit.PAPER
	var font_px: int = 22
	var ticks: int = 0

	func fit() -> Vector2:
		var f: Font = CzArtKit.font_display()
		var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
		var h: float = font_px * 1.35
		var icon_w: float = h * 0.8 if icon != &"" else 0.0
		var tick_w: float = ticks * font_px * 0.28
		size = Vector2(ceilf(w + icon_w + tick_w + font_px * 1.2), ceilf(h))
		pivot_offset = size * 0.5
		return size

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		CzArtKit.draw_tag(self, r, minf(8.0, size.y * 0.3), fill, line, 2.0)
		var x: float = font_px * 0.6
		if icon != &"":
			var tex: Texture2D = CzIcons.get_icon(icon, size.y * 0.7)
			if tex != null:
				var s: float = size.y * 0.66
				draw_texture_rect(tex, Rect2(Vector2(x - font_px * 0.2, (size.y - s) * 0.5), Vector2(s, s)), false, ink)
				x += size.y * 0.8
		draw_string(CzArtKit.font_display(), Vector2(x, size.y * 0.5 + font_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)
		if ticks > 0:
			var tx: float = size.x - font_px * 0.5 - ticks * font_px * 0.28
			for i: int in ticks:
				draw_rect(Rect2(Vector2(tx + i * font_px * 0.28, size.y * 0.3), Vector2(font_px * 0.14, size.y * 0.4)), ink)


## An outline pulsing out from `box`: `pulse` 0..1 per pulse (scale out + fade). `pulses` rings.
class PanelPulse:
	extends Piece
	var box: Rect2 = Rect2()
	var color: Color = CzArtKit.HIT_RED
	var spread: float = 0.10
	var pulse: float = 0.0:
		set(v):
			pulse = v
			queue_redraw()

	func _draw() -> void:
		var p: float = fposmod(pulse, 1.0) if pulse < 2.0 else 1.0
		var g: Vector2 = box.size * spread * p * 0.5
		var r: Rect2 = box.grow_individual(g.x, g.y, g.x, g.y)
		var a: float = 1.0 - p
		CzArtKit.draw_tag(self, r, 8.0, Color(color, 0.18 * a), Color(color, a), 4.0)


## The elimination stamp: a clipped ink plate with a hit_red border, the title and a caption.
class Stamp:
	extends Piece
	var title: String = "ELIMINATED"
	var caption: String = ""
	var title_px: int = 72
	var caption_px: int = 22

	func fit() -> Vector2:
		var f: Font = CzArtKit.font_display()
		var w: float = maxf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x,
				CzArtKit.font_body().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_px).x)
		size = Vector2(ceilf(w + title_px * 0.9), ceilf(title_px * 1.1 + caption_px * 1.7 + 16.0))
		pivot_offset = size * 0.5
		return size

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		CzArtKit.draw_tag(self, r, 18.0, Color(CzArtKit.INK, 0.94), CzArtKit.HIT_RED, 6.0)
		CzArtKit.draw_tag(self, r.grow(-12.0), 12.0, Color(0, 0, 0, 0), Color(CzArtKit.HIT_RED, 0.5), 2.0)
		var f: Font = CzArtKit.font_display()
		draw_string(f, Vector2(0, 10.0 + title_px * 0.86), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_px, CzArtKit.HIT_RED)
		draw_string(CzArtKit.font_body(), Vector2(0, 10.0 + title_px * 1.08 + caption_px * 0.95), caption,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_px, CzArtKit.PAPER)
