# paper_sheet.gd
# Purpose: The "orders paper" material of the art direction (art-direction.md §2.1, §4): light paper
#   #E9DFC6 with dark ink #2B2716, a khaki #B8913A rim and clip strip, square corners and a faint
#   fibre; plus the stencil stamp (Stardos Stencil, rotated, double rule) used for VICTORY / DEFEAT
#   and map labels. One place for the inspector rules sheet (#4), the debrief (#9) and the briefing
#   map (#8), so the paper looks the same everywhere.
# Dependencies: assets/fonts (Stardos Stencil, Share Tech Mono, Barlow Condensed).
# Use: const PaperSheet: GDScript = preload("res://scripts/ui/paper_sheet.gd") (no class_name: headless runs
#   need no class cache refresh).
# Author: UI/UX Agent (kc-da-ui2)
extends RefCounted

const PAPER: Color = Color("#E9DFC6")
const PAPER_SHADE: Color = Color("#D8CBA8")
const INK: Color = Color("#2B2716")
## Captions and secondary lines on paper (contrast 5.6:1 on PAPER).
const INK_MUTED: Color = Color("#5E5440")
const KHAKI: Color = Color("#B8913A")
## Keyword names and headings on paper: dark brass (contrast 6.4:1 on PAPER).
const INK_BRASS: Color = Color("#6E5310")
## Stamp inks: teal and red deepened for paper (both >= 4.5:1 on PAPER).
const STAMP_WIN: Color = Color("#0E6B62")
const STAMP_LOSS: Color = Color("#A3171B")
const STAMP_DRAW: Color = Color("#4A4536")

const FONT_STENCIL: String = "res://assets/fonts/StardosStencil-Bold.ttf"
const FONT_MONO: String = "res://assets/fonts/ShareTechMono-Regular.ttf"
const FONT_HEAD: String = "res://assets/fonts/BarlowCondensed-Bold.ttf"


static func stencil_font() -> Font:
	return load(FONT_STENCIL) as Font


static func mono_font() -> Font:
	return load(FONT_MONO) as Font


static func head_font() -> Font:
	return load(FONT_HEAD) as Font


## The paper panel: square corners, khaki rim, a thicker khaki clip strip on top.
static func stylebox(margin: float = 14.0, top_strip: int = 6) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = KHAKI
	sb.set_border_width_all(1)
	sb.border_width_top = top_strip
	sb.set_corner_radius_all(0)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin + float(top_strip) * 0.5
	sb.content_margin_bottom = margin
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 3)
	return sb


## Makes a PanelContainer read as orders paper (stylebox + fibre) and marks it with meta "paper".
static func apply(panel: PanelContainer, margin: float = 14.0, top_strip: int = 6) -> void:
	panel.add_theme_stylebox_override(&"panel", stylebox(margin, top_strip))
	if panel.has_meta(&"paper"):
		return
	panel.set_meta(&"paper", true)
	var seed_value: int = int(panel.get_instance_id() % 997)
	panel.draw.connect(func() -> void: draw_fibre(panel, Rect2(Vector2.ZERO, panel.size), seed_value))


## A faint paper fibre: short hairlines at 4-6% ink, deterministic for a given seed.
static func draw_fibre(ci: CanvasItem, rect: Rect2, seed_value: int = 7) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var n: int = clampi(int(rect.size.x * rect.size.y / 900.0), 12, 260)
	for i: int in n:
		var p: Vector2 = rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var a: float = rng.randf_range(-0.5, 0.5)
		var l: float = rng.randf_range(4.0, 12.0)
		ci.draw_line(p, p + Vector2(cos(a), sin(a)) * l, Color(INK, rng.randf_range(0.035, 0.07)), 1.0)


## Gives a Label dark ink on paper.
static func ink(label: Label, color: Color = INK) -> Label:
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override(&"outline_size", 0)
	return label


## Draws a stencil stamp centred on `center`: the word in Stardos Stencil inside a double rule,
## rotated by `angle_deg`, in `color` at ~90% (ink on paper never fully opaque).
static func draw_stamp(ci: CanvasItem, center: Vector2, text: String, color: Color, font_size: int, angle_deg: float = -8.0) -> void:
	var f: Font = stencil_font()
	var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad: Vector2 = Vector2(font_size * 0.45, font_size * 0.18)
	var box: Rect2 = Rect2(-ts * 0.5 - pad, ts + pad * 2.0)
	var c: Color = Color(color, color.a * 0.9)
	ci.draw_set_transform(center, deg_to_rad(angle_deg), Vector2.ONE)
	var w1: float = maxf(2.0, font_size * 0.07)
	ci.draw_rect(box, c, false, w1)
	ci.draw_rect(box.grow(-w1 * 2.2), c, false, maxf(1.0, w1 * 0.45))
	var asc: float = f.get_ascent(font_size)
	var desc: float = f.get_descent(font_size)
	ci.draw_string(f, Vector2(-ts.x * 0.5, (asc - desc) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The size a stamp needs (its rotated box), for layout.
static func stamp_size(text: String, font_size: int, angle_deg: float = -8.0) -> Vector2:
	var ts: Vector2 = stencil_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad: Vector2 = Vector2(font_size * 0.45, font_size * 0.18)
	var s: Vector2 = ts + pad * 2.0
	var a: float = absf(deg_to_rad(angle_deg))
	return Vector2(s.x * cos(a) + s.y * sin(a), s.x * sin(a) + s.y * cos(a)).ceil()


## A Control that shows one stamp at its centre (minimum size = the rotated stamp).
static func make_stamp(text: String, color: Color, font_size: int, angle_deg: float = -8.0) -> Control:
	var c: Control = Control.new()
	c.name = "Stamp"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = stamp_size(text, font_size, angle_deg)
	c.set_meta(&"stamp_text", text)
	c.draw.connect(func() -> void: draw_stamp(c, c.size * 0.5, text, color, font_size, angle_deg))
	return c
