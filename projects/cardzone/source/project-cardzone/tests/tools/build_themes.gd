# build_themes.gd: generates assets/themes/cardzone_theme.tres (cz16). Run from the project folder:
#   godot --headless --path . -s res://tests/tools/build_themes.gd
# Edit colours / sizes in scripts/art/art_kit.gd or here, re-run, and keep the regenerated .tres.
# Pipeline adapted from CallingCard tests/tools/build_themes.gd (fonts with explicit base_font,
# StyleBoxFlat helpers); the look is CardZone's "survey stencil at dusk" (art-direction.md):
# flat clipped-tag plates (top-left and bottom-right corners cut at 45 deg via corner_detail = 1),
# no gloss, verbs in caps on buttons, violet = safe UI frame, lime only for gas warnings.
# Text sizes are logical px. On the 844x390 phone one logical px is 0.722 pt (scripts/ui/screen_profile.gd),
# so body >= 16 px (11.5 pt, floor 11 pt), names >= 14 px (10 pt), numbers >= 17 px (12 pt),
# mono >= 13 px (9 pt), tap targets 62 px (44.8 pt).
# Author: Technical Artist Agent (cz16)
extends SceneTree

const OUT: String = "res://assets/themes/cardzone_theme.tres"
const TAP_PX: int = 62


func _initialize() -> void:
	var err: int = ResourceSaver.save(build(), OUT)
	print("cardzone theme written: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _fonts() -> Dictionary:
	# Fresh FontVariations (not CzArtKit's cached ones) so they are saved inside the theme.
	var body_file: Font = load(CzArtKit.FONT_BODY_PATH)
	var display_file: Font = load(CzArtKit.FONT_DISPLAY_PATH)
	var mono_file: Font = load(CzArtKit.FONT_MONO_PATH)
	var body := FontVariation.new()
	body.resource_name = "body"
	body.base_font = body_file
	var display := FontVariation.new()
	display.resource_name = "display_condensed"
	display.base_font = display_file
	display.fallbacks = [body_file]
	var numeral := FontVariation.new()
	numeral.resource_name = "numeral_tabular"
	numeral.base_font = display_file
	numeral.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	var mono := FontVariation.new()
	mono.resource_name = "mono"
	mono.base_font = mono_file
	mono.fallbacks = [body_file]
	return {"body": body, "display": display, "numeral": numeral, "mono": mono}


## Clipped-tag StyleBoxFlat: only the top-left and bottom-right corners are cut (45 deg).
func _tag(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, cut: int = 8,
		margin: Vector4 = Vector4(14, 8, 14, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.corner_radius_top_left = cut
	sb.corner_radius_bottom_right = cut
	sb.corner_detail = 1
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	return sb


func _label_var(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _button_set(t: Theme, type_name: String, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat,
		disabled: StyleBoxFlat, text: Color, text_pressed: Color) -> void:
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, hover)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, pressed)
	t.set_stylebox("disabled", type_name, disabled)
	var focus := _tag(Color.TRANSPARENT, CzArtKit.ZONE_EDGE, 2, 10)
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("focus", type_name, focus)
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, type_name, text)
	t.set_color("font_pressed_color", type_name, text_pressed)
	t.set_color("font_hover_pressed_color", type_name, text_pressed)
	t.set_color("font_disabled_color", type_name, Color(CzArtKit.PAPER, 0.4))


func build() -> Theme:
	var f: Dictionary = _fonts()
	var t := Theme.new()
	t.default_font = f["body"]
	t.default_font_size = 16
	t.set_color("font_color", "Label", CzArtKit.PAPER)

	# Palette + rarity colours, read by UI code as get_theme_color("gas_lime", "CardZone").
	for token: String in CzArtKit.PALETTE:
		t.set_color(token, "CardZone", CzArtKit.PALETTE[token])
	for k: StringName in CzArtKit.RARITY_ORDER:
		t.set_color("rarity_%s" % String(k).to_lower(), "CardZone", CzArtKit.RARITIES[k]["color"])
	t.set_constant("tap_target", "CardZone", TAP_PX)

	# Text roles.
	_label_var(t, "Title", f["display"], 48, CzArtKit.PAPER)
	_label_var(t, "Heading", f["display"], 30, CzArtKit.PAPER)
	_label_var(t, "Subheading", f["display"], 22, CzArtKit.ZONE_EDGE)
	_label_var(t, "Body", f["body"], 17, CzArtKit.PAPER)
	_label_var(t, "Caption", f["body"], 16, Color(CzArtKit.PAPER, 0.75))
	_label_var(t, "Mono", f["mono"], 14, CzArtKit.ZONE_EDGE)
	_label_var(t, "StatNumber", f["numeral"], 28, CzArtKit.PAPER)
	_label_var(t, "HitNumber", f["numeral"], 28, CzArtKit.HIT_RED)
	_label_var(t, "GasWarning", f["display"], 20, CzArtKit.GAS_GLOW)
	_label_var(t, "InkLabel", f["display"], 17, CzArtKit.INK)

	# Panels: violet frame, raised dusk panels, inspector backdrop, gas banner, paper tag.
	var panel := _tag(CzArtKit.ZONE_DUSK, Color(CzArtKit.ZONE_EDGE, 0.35), 1, 10, Vector4(14, 10, 14, 10))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("OpponentPanel", "PanelContainer")
	t.set_stylebox("panel", "OpponentPanel", _tag(CzArtKit.ZONE_DUSK, CzArtKit.INK, 2, 10, Vector4(12, 8, 12, 8)))
	t.set_type_variation("InspectorPanel", "PanelContainer")
	t.set_stylebox("panel", "InspectorPanel", _tag(Color(CzArtKit.ZONE_VIOLET, 0.94), CzArtKit.ZONE_EDGE, 2, 14, Vector4(18, 14, 18, 14)))
	t.set_type_variation("GasBanner", "PanelContainer")
	t.set_stylebox("panel", "GasBanner", _tag(CzArtKit.GAS_GLOW, CzArtKit.INK, 2, 8, Vector4(12, 4, 12, 4)))
	t.set_type_variation("PaperTag", "PanelContainer")
	t.set_stylebox("panel", "PaperTag", _tag(CzArtKit.PAPER, CzArtKit.INK, 1, 6, Vector4(8, 2, 8, 2)))
	t.set_type_variation("HitBadge", "PanelContainer")
	t.set_stylebox("panel", "HitBadge", _tag(CzArtKit.HIT_RED, CzArtKit.INK, 1, 6, Vector4(8, 2, 8, 2)))
	for k: StringName in CzArtKit.RARITY_ORDER:
		var name: String = "RarityChip%s" % String(k)
		t.set_type_variation(name, "PanelContainer")
		t.set_stylebox("panel", name, _tag(CzArtKit.RARITIES[k]["color"], CzArtKit.INK, 2, 6, Vector4(6, 2, 6, 2)))
	# Card slots (hand / line / loadout strip): dashed look approximated by a faint outline.
	t.set_type_variation("CardSlot", "PanelContainer")
	t.set_stylebox("panel", "CardSlot", _tag(Color(CzArtKit.ZONE_VIOLET, 0.5), Color(CzArtKit.ZONE_EDGE, 0.3), 2, 6, Vector4.ZERO))
	t.set_type_variation("CardSlotValid", "PanelContainer")
	t.set_stylebox("panel", "CardSlotValid", _tag(Color(CzArtKit.ZONE_EDGE, 0.12), CzArtKit.ZONE_EDGE, 3, 6, Vector4.ZERO))

	# Buttons: verbs in caps (HOLD, STOW, SHOOT, LOOT, END TURN). Never lime, never green.
	var m := Vector4(20, 10, 20, 10)
	t.set_font("font", "Button", f["display"])
	t.set_font_size("font_size", "Button", 22)
	t.set_constant("h_separation", "Button", 8)
	_button_set(t, "Button",
			_tag(CzArtKit.ZONE_DUSK, CzArtKit.ZONE_EDGE, 2, 10, m), _tag(CzArtKit.ZONE_DUSK.lightened(0.12), CzArtKit.ZONE_EDGE, 2, 10, m),
			_tag(CzArtKit.ZONE_EDGE, CzArtKit.ZONE_EDGE, 2, 10, Vector4(m.x, m.y + 2, m.z, m.w - 2)),
			_tag(Color(CzArtKit.ZONE_DUSK, 0.5), Color(CzArtKit.ZONE_EDGE, 0.25), 1, 10, m), CzArtKit.PAPER, CzArtKit.INK)
	t.set_type_variation("PrimaryButton", "Button")
	_button_set(t, "PrimaryButton",
			_tag(CzArtKit.PAPER, CzArtKit.INK, 2, 10, m), _tag(Color.WHITE, CzArtKit.ZONE_EDGE, 2, 10, m),
			_tag(CzArtKit.ZONE_EDGE, CzArtKit.INK, 2, 10, Vector4(m.x, m.y + 2, m.z, m.w - 2)),
			_tag(Color(CzArtKit.PAPER, 0.35), Color.TRANSPARENT, 0, 10, m), CzArtKit.INK, CzArtKit.INK)
	t.set_type_variation("DangerButton", "Button")
	_button_set(t, "DangerButton",
			_tag(CzArtKit.HIT_RED, CzArtKit.INK, 2, 10, m), _tag(CzArtKit.HIT_RED.lightened(0.12), CzArtKit.INK, 2, 10, m),
			_tag(CzArtKit.HIT_RED.darkened(0.2), CzArtKit.INK, 2, 10, Vector4(m.x, m.y + 2, m.z, m.w - 2)),
			_tag(Color(CzArtKit.HIT_RED, 0.35), Color.TRANSPARENT, 0, 10, m), CzArtKit.INK, CzArtKit.INK)
	t.set_type_variation("GhostButton", "Button")
	_button_set(t, "GhostButton",
			_tag(Color.TRANSPARENT, Color(CzArtKit.PAPER, 0.3), 1, 10, m), _tag(Color(CzArtKit.PAPER, 0.08), Color(CzArtKit.PAPER, 0.5), 1, 10, m),
			_tag(Color(CzArtKit.PAPER, 0.16), Color(CzArtKit.PAPER, 0.5), 1, 10, m), _tag(Color.TRANSPARENT, Color(CzArtKit.PAPER, 0.12), 1, 10, m),
			CzArtKit.PAPER, CzArtKit.PAPER)

	# Zone track / health meters.
	t.set_stylebox("background", "ProgressBar", _tag(CzArtKit.ZONE_VIOLET, Color(CzArtKit.ZONE_EDGE, 0.4), 1, 4, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", _tag(CzArtKit.ZONE_EDGE, Color.TRANSPARENT, 0, 4, Vector4.ZERO))
	t.set_font("font", "ProgressBar", f["mono"])
	t.set_font_size("font_size", "ProgressBar", 14)
	t.set_color("font_color", "ProgressBar", CzArtKit.INK)

	# Tooltips and coach hints: paper speech tags.
	t.set_stylebox("panel", "TooltipPanel", _tag(CzArtKit.PAPER, CzArtKit.INK, 1, 6, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", CzArtKit.INK)
	t.set_font("font", "TooltipLabel", f["body"])
	t.set_font_size("font_size", "TooltipLabel", 16)

	# Touch-friendly scroll bars (hand strip, inspector text).
	for bar: String in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar, _tag(Color(CzArtKit.ZONE_VIOLET, 0.8), Color.TRANSPARENT, 0, 4, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber", bar, _tag(Color(CzArtKit.ZONE_EDGE, 0.5), Color.TRANSPARENT, 0, 4, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_highlight", bar, _tag(CzArtKit.ZONE_EDGE, Color.TRANSPARENT, 0, 4, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_pressed", bar, _tag(CzArtKit.PAPER, Color.TRANSPARENT, 0, 4, Vector4(6, 6, 6, 6)))
	return t
