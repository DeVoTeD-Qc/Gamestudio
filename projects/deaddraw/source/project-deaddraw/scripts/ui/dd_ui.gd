# dd_ui.gd
# Purpose: Palette, StyleBox and widget helpers for the DeadDraw placeholder look (Control nodes
#   and StyleBoxFlat only, no image assets).
# Dependencies: DDCard.
#   v2: ammo, drop, room, machine and Jawbreaker colours from the art manifest palette.
# Author: Mechanics Developer Agent
class_name DDUi
extends RefCounted

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
	"A": Color("17302f"), "X": Color("302a17"), "R": Color("22282c"), "K": Color("2a2420"), "J": Color("1e1a26"),
}
const KIND_ACCENT: Dictionary = {
	"Z": Color("e2574c"), "W": Color("5bb0e0"), "M": Color("6fd08a"), "B": Color("e0b04a"),
	"F": Color("c27ce0"), "P": Color("9aa8ff"), "S": Color("f0d27a"), "D": Color("b8c4c0"),
	"A": Color("4fd1c5"), "X": Color("f2d65c"), "R": Color("b8c4c0"), "K": Color("d9a066"), "J": Color("f08cc0"),
}
## v2 kinds: A ammo (teal), X Carrier drop / points (gold), R room / door, K machine, J Jawbreaker.

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
	s.set_corner_radius_all(radius)
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
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	return b


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
