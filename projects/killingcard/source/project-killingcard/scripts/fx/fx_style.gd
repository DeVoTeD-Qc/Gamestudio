# fx_style.gd
# Purpose: Shared look for the combat feedback layer (p14): art-direction palette, fonts and a
#   factory for the outlined labels the FX use (damage numbers, pop-ups, stamps). The HUD theme
#   (hud_theme.tres) styles the match screen; FX labels float over it and need a heavier dark
#   outline to stay readable on any slot colour, so they are built here in one place.
#   Candidate for theme variations (FxNumber, FxStamp...) once the Technical Artist folds them
#   into tests/tools/build_themes.gd.
# Dependencies: assets/fonts/*.ttf, assets/ui/icons (IconSheet).
# Author: Game Feel Engineer Agent (p14)
extends RefCounted

const SLATE: Color = Color("#12161A")
const GUNMETAL: Color = Color("#232A31")
const FOG: Color = Color("#D8DEE3")
const FOG_DIM: Color = Color(0.847, 0.871, 0.89, 0.62)
const AMBER: Color = Color("#FFB020")
const TEAL: Color = Color("#2EC4B6")
const RED: Color = Color("#E5383B")
const CYAN: Color = Color("#5BC0EB")

const FONT_HEADING: FontFile = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")  # kc-da-ui type scale
const FONT_BODY: FontFile = preload("res://assets/fonts/Barlow-Medium.ttf")
const FONT_NUMERIC: FontFile = preload("res://assets/fonts/ShareTechMono-Regular.ttf")

## Phone floor (README "Phone readability"): text >= 16 px, key numbers >= 20 px.
const MIN_TEXT_PX: int = 16
const MIN_NUMBER_PX: int = 20


## Friendly = teal, enemy = red (art direction). Side is &"player" / &"enemy".
static func side_color(side: StringName) -> Color:
	return TEAL if side == &"player" else RED


## An outlined, non-interactive label. font: &"heading", &"body" or &"numeric".
static func make_label(text: String, font: StringName, size: int, color: Color, outline: int = 6) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", font_for(font))
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(SLATE, 0.92))
	label.add_theme_constant_override(&"outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func font_for(font: StringName) -> Font:
	match font:
		&"heading":
			return FONT_HEADING
		&"body":
			return FONT_BODY
	return FONT_NUMERIC
