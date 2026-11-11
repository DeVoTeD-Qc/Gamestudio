# dd_ui.gd
# Purpose: Palette, StyleBox and widget helpers for the DeadDraw placeholder look (Control nodes
#   and StyleBoxFlat only, no image assets).
# Dependencies: DDCard.
#   v2: ammo, drop, room, machine and Jawbreaker colours from the art manifest palette.
# Author: Mechanics Developer Agent
#   dd-art2-import: buttons, panels, tags and bars use the painted UI kit (dd_skin.gd) when its image
#   exists; the StyleBoxFlat look stays the fallback.
class_name DDUi
extends RefCounted

const Kit = preload("res://scripts/ui/dd_skin.gd")

const BG: Color = Color("15181a")
const PANEL: Color = Color("20262a")
const PANEL_HI: Color = Color("2b3338")
const TEXT: Color = Color("ece6d6")
const TEXT_DIM: Color = Color("9aa39f")
const GOOD: Color = Color("6fd08a")
const BAD: Color = Color("ff6b5e")
const WARN: Color = Color("f2c14e")
const COVER: Color = Color("e0b04a")
const SELECT: Color = Color("fff2b0")

const KIND_BG: Dictionary = {
	"Z": Color("3b2321"), "W": Color("1f2e3a"), "M": Color("1d3325"), "B": Color("37301d"),
	"F": Color("2c1d35"), "P": Color("26283a"), "S": Color("2a2a24"), "D": Color("22282c"),
	"A": Color("17302f"), "C": Color("37301d"), "X": Color("302a17"), "R": Color("22282c"), "K": Color("2a2420"), "J": Color("1e1a26"), "Q": Color("1c2a24"),
}
const KIND_ACCENT: Dictionary = {
	"Z": Color("e2574c"), "W": Color("5bb0e0"), "M": Color("6fd08a"), "B": Color("e0b04a"),
	"F": Color("c27ce0"), "P": Color("9aa8ff"), "S": Color("f0d27a"), "D": Color("b8c4c0"),
	"A": Color("4fd1c5"), "C": Color("e0b04a"), "X": Color("f2d65c"), "R": Color("b8c4c0"), "K": Color("d9a066"), "J": Color("f08cc0"), "Q": Color("7fd1a6"),
}
## dd-ux-v4: K is melee (tan: Bare Hands, melee weapon cards); Q is an open room's machine (green).
## v3: C cover card (gold). v2 kinds: A ammo (teal), X Carrier drop / points (gold), R room / door, K machine, J Jawbreaker.

const FONT_S: int = 18
const FONT_M: int = 22
const FONT_L: int = 28
const FONT_XL: int = 40
const BIG_NUMBER: int = 64
const TAP_MIN: int = 72


static func accent(kind: String) -> Color:
	return KIND_ACCENT.get(kind, TEXT)


static func card_bg(kind: String) -> Color:
	return KIND_BG.get(kind, PANEL)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 14, pad: int = 10) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	# dd-ui-clean: the skin caps the corner radius (b / c: 6 px, a: 8 px)
	s.set_corner_radius_all(Kit.radius(radius))
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	return s


static func label(text: String, size: int = FONT_M, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, color: Color = PANEL_HI, size: int = FONT_M, min_w: int = 0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, TAP_MIN)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(TEXT_DIM, 0.75))
	b.add_theme_stylebox_override("normal", box(color, color.lightened(0.25), 2, 12, 12))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), color.lightened(0.4), 2, 12, 12))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), SELECT, 2, 12, 12))
	b.add_theme_stylebox_override("disabled", box(Color(PANEL, 0.8), Color(TEXT_DIM, 0.25), 2, 12, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if Kit.skin_button(b, Kit.family(color)):
		ink_outline(b)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	return b


## dd-art2-import: an ink outline so words stay readable on the painted plates.
static func ink_outline(c: Control, px: int = 4) -> void:
	c.add_theme_constant_override("outline_size", px)
	c.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04, 0.85))


## dd-art2-import: a painted panel ("tooltip", "modal", "overlay", "hud") or null when its image is missing.
static func painted(role: String, pad: int = 10) -> StyleBox:
	return Kit.box("dd_panel_" + role, pad)


## Puts the painted panel `role` on p (keeps p's flat style when the image is missing). Returns p.
static func skin_panel(p: PanelContainer, role: String, pad: int = -1) -> PanelContainer:
	var cur: StyleBox = p.get_theme_stylebox("panel")
	var pd: int = pad if pad >= 0 else (int(cur.content_margin_left) if cur != null and cur.content_margin_left >= 0.0 else 10)
	# the painted rim is ~12 px deep: keep content off it
	var st: StyleBox = painted(role, maxi(pd, 12))
	if st != null:
		p.add_theme_stylebox_override("panel", st)
	return p


## A painted tag ("yellow", "red", "bone", "boss") with a word on it, or a flat chip when missing.
static func tag(text: String, color: String, fs: int, flat_bg: Color = WARN) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark_word: bool = color != "boss"
	var st: StyleBox = Kit.box("dd_tag_" + color, 0.0)
	if st != null:
		st.content_margin_left = maxf(6.0, fs * 0.6)
		st.content_margin_right = maxf(6.0, fs * 0.6)
		st.content_margin_top = 2.0
		st.content_margin_bottom = 2.0
		p.add_theme_stylebox_override("panel", st)
	else:
		p.add_theme_stylebox_override("panel", box(flat_bg, Color(0, 0, 0, 0), 0, 14, 3))
	var l: Label = label(text, fs, BG if dark_word else TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Word"
	p.add_child(l)
	return p


## dd-art2-import: painted bar track / fill on a ProgressBar or Slider style slot (flat fallback).
static func bar_style(file: String, flat: Color, radius: int = 6) -> StyleBox:
	var st: StyleBox = Kit.box(file, 0.0)
	return st if st != null else box(flat, Color(0, 0, 0, 0), 0, radius, 0)


static func panel(bg: Color = PANEL, pad: int = 10, border: Color = Color(0, 0, 0, 0), width: int = 0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, width, 14, pad))
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func ignore_mouse(n: Node) -> void:
	for c: Node in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(c)
