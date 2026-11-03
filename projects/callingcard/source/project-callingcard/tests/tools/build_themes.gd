# build_themes.gd: generates assets/themes/wall_theme.tres (cc14). Run from the project folder:
#   godot --headless --path . -s res://tests/tools/build_themes.gd
# Edit colours / sizes in scripts/art/art_kit.gd or here, re-run, and keep the regenerated .tres.
# Pipeline adapted from Killstreak tests/tools/build_themes.gd (fonts with explicit base_font,
# StyleBoxFlat helpers); the look is new: "Museum of the Grind" night gallery (art-direction.md).
# Text sizes are logical px. On the smallest supported phone one logical px is ~0.72 pt
# (scripts/ui/screen_profile.gd), so body text is >= 16 px and key numbers >= 24 px.
# Author: Technical Artist Agent (cc14)
extends SceneTree

const OUT: String = "res://assets/themes/wall_theme.tres"
const PANEL := Color("#1B1E25")
const PANEL_HI := Color("#262A33")
const PANEL_EDGE := Color("#343944")
const VELVET := Color("#22171C")
const BRASS := Color("#B98A3E")


func _initialize() -> void:
	var err: int = ResourceSaver.save(build(), OUT)
	print("wall theme written: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _fonts() -> Dictionary:
	# Fresh FontVariations (not ArtKit's cached ones) so they are saved inside the theme.
	var body_file: Font = load(ArtKit.FONT_BODY_PATH)
	var display_file: Font = load(ArtKit.FONT_DISPLAY_PATH)
	var body := FontVariation.new()
	body.resource_name = "body"
	body.base_font = body_file
	var display := FontVariation.new()
	display.resource_name = "display_condensed"
	display.base_font = display_file
	display.fallbacks = [body_file]
	display.spacing_glyph = 1
	var numeral := FontVariation.new()
	numeral.resource_name = "numeral"
	numeral.base_font = display_file
	numeral.variation_embolden = 0.35
	return {"body": body, "display": display, "numeral": numeral}


func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 6,
		margin: Vector4 = Vector4(12, 8, 12, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	return sb


func _lip(sb: StyleBoxFlat, px: int = 3, alpha: float = 0.5) -> StyleBoxFlat:
	sb.shadow_color = Color(0, 0, 0, alpha)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, px)
	return sb


func _glow(sb: StyleBoxFlat, color: Color, size: int = 8, alpha: float = 0.4) -> StyleBoxFlat:
	sb.shadow_color = Color(color, alpha)
	sb.shadow_size = size
	sb.shadow_offset = Vector2.ZERO
	return sb


func _label_var(t: Theme, name: String, font: Font, size: int, color: Color, outline: int = 0) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if outline > 0:
		t.set_constant("outline_size", name, outline)
		t.set_color("font_outline_color", name, ArtKit.WALL)


func _button_set(t: Theme, type_name: String, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat,
		disabled: StyleBoxFlat, text: Color, text_pressed: Color) -> void:
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, hover)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, pressed)
	t.set_stylebox("disabled", type_name, disabled)
	var focus := _box(Color.TRANSPARENT, Color(ArtKit.AMBER, 0.95), 2, 10)
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("focus", type_name, focus)
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, type_name, text)
	t.set_color("font_pressed_color", type_name, text_pressed)
	t.set_color("font_hover_pressed_color", type_name, text_pressed)
	t.set_color("font_disabled_color", type_name, ArtKit.TEXT_DIM)


func build() -> Theme:
	var f: Dictionary = _fonts()
	var t := Theme.new()
	t.default_font = f["body"]
	t.default_font_size = 18
	t.set_color("font_color", "Label", ArtKit.TEXT)

	# Palette, read by UI code as get_theme_color("player", "Wall").
	for pair: Array in [["wall", ArtKit.WALL], ["mortar", ArtKit.MORTAR], ["brick", ArtKit.BRICK],
			["text", ArtKit.TEXT], ["text_dim", ArtKit.TEXT_DIM], ["player", ArtKit.PLAYER],
			["rival", ArtKit.RIVAL], ["accent", ArtKit.AMBER], ["signature", ArtKit.SIGNATURE],
			["neutral", ArtKit.NEUTRAL], ["panel", PANEL], ["velvet", VELVET], ["brass", BRASS]]:
		t.set_color(pair[0], "Wall", pair[1])
	for set_id: StringName in ArtKit.SETS:
		var pal: Dictionary = ArtKit.set_palette(set_id)
		t.set_color("set_%s" % set_id, "Wall", pal["edge"])
		t.set_color("set_%s_deep" % set_id, "Wall", pal["deep"])
	t.set_constant("tap_target", "Wall", 64)
	t.set_constant("card_ratio_x100", "Wall", 400)

	# Text roles.
	_label_var(t, "Title", f["display"], 56, ArtKit.TEXT)
	_label_var(t, "Heading", f["display"], 32, ArtKit.TEXT)
	_label_var(t, "Subheading", f["display"], 24, ArtKit.AMBER)
	_label_var(t, "Body", f["body"], 18, ArtKit.TEXT)
	_label_var(t, "Caption", f["body"], 16, ArtKit.TEXT_DIM)
	_label_var(t, "Handwritten", f["display"], 22, ArtKit.SIGNATURE)  # Triptych hints on velvet
	_label_var(t, "ScorePlayer", f["numeral"], 44, ArtKit.PLAYER, 4)
	_label_var(t, "ScoreRival", f["numeral"], 44, ArtKit.RIVAL, 4)
	_label_var(t, "ValueNumber", f["numeral"], 28, ArtKit.TEXT)
	_label_var(t, "TraitName", f["display"], 22, ArtKit.TEXT)
	_label_var(t, "Stamp", f["display"], 72, ArtKit.RIVAL, 8)  # "CARDED" stamp (cc15)

	# Panels: dark enamel; inspector glass; album velvet with a brass edge.
	var panel := _lip(_box(Color(PANEL, 0.96), PANEL_EDGE, 1, 8, Vector4(14, 10, 14, 10)), 3, 0.4)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("InspectorPanel", "PanelContainer")
	t.set_stylebox("panel", "InspectorPanel", _lip(_box(Color("#181B22", 0.97), Color(ArtKit.TEXT, 0.18), 1, 10, Vector4(18, 14, 18, 14)), 4, 0.5))
	t.set_type_variation("AlbumPage", "PanelContainer")
	t.set_stylebox("panel", "AlbumPage", _box(VELVET, Color(BRASS, 0.7), 3, 10, Vector4(20, 16, 20, 16)))
	t.set_type_variation("ScorePlayerPanel", "PanelContainer")
	t.set_stylebox("panel", "ScorePlayerPanel", _lip(_box(Color("#0F2B2A"), ArtKit.PLAYER, 3, 12, Vector4(16, 4, 16, 4))))
	t.set_type_variation("ScoreRivalPanel", "PanelContainer")
	var rival_panel := _lip(_box(Color("#33160F"), ArtKit.RIVAL, 3, 12, Vector4(16, 4, 16, 4)))
	rival_panel.corner_detail = 1  # chamfered: shape differs from the player's counter, not only colour
	t.set_stylebox("panel", "ScoreRivalPanel", rival_panel)
	t.set_type_variation("SignatureRibbon", "PanelContainer")
	t.set_stylebox("panel", "SignatureRibbon", _box(ArtKit.SIGNATURE, Color.TRANSPARENT, 0, 3, Vector4(8, 2, 8, 2)))

	# Wall slots (board): chalk outline when empty, amber when a valid drop, mortar background.
	t.set_type_variation("WallSlot", "PanelContainer")
	t.set_stylebox("panel", "WallSlot", _box(Color(ArtKit.BRICK, 0.6), Color(ArtKit.TEXT, 0.22), 2, 6, Vector4.ZERO))
	t.set_type_variation("WallSlotValid", "PanelContainer")
	t.set_stylebox("panel", "WallSlotValid", _glow(_box(Color(ArtKit.AMBER, 0.12), ArtKit.AMBER, 3, 6, Vector4.ZERO), ArtKit.AMBER, 10, 0.45))
	t.set_type_variation("WallSlotPreview", "PanelContainer")
	t.set_stylebox("panel", "WallSlotPreview", _box(Color(ArtKit.AMBER, 0.06), Color(ArtKit.AMBER, 0.6), 2, 6, Vector4.ZERO))

	# Frames by Clearance as theme styleboxes (album hangers, inspector, lineup slots).
	t.set_type_variation("BannerFrame", "PanelContainer")
	for key: Variant in ArtKit.FRAMES:
		var name: String = ("c%d" % key) if key is int else String(key)
		var sb: StyleBoxFlat = ArtKit.frame_box(ArtKit.FRAMES[key], 128.0)
		t.set_stylebox(name, "BannerFrame", sb)
	t.set_stylebox("panel", "BannerFrame", ArtKit.frame_box(ArtKit.FRAMES[1], 128.0))

	# Buttons: amber means "interactive". Secondary = enamel with amber edge, Primary = solid amber.
	var m := Vector4(20, 10, 20, 10)
	t.set_font("font", "Button", f["display"])
	t.set_font_size("font_size", "Button", 24)
	t.set_constant("h_separation", "Button", 10)
	_button_set(t, "Button",
			_lip(_box(PANEL, ArtKit.AMBER, 2, 8, m)), _lip(_box(PANEL_HI, Color("#FFC95E"), 2, 8, m)),
			_box(ArtKit.AMBER, ArtKit.AMBER, 2, 8, Vector4(m.x, m.y + 2, m.z, m.w - 2)),
			_box(Color(PANEL, 0.6), Color("#4A4F5A"), 1, 8, m), ArtKit.TEXT, ArtKit.WALL)
	t.set_type_variation("PrimaryButton", "Button")
	_button_set(t, "PrimaryButton",
			_glow(_box(ArtKit.AMBER, Color("#FFD27A"), 2, 8, m), ArtKit.AMBER, 8, 0.35),
			_glow(_box(Color("#FFC24F"), Color("#FFE0A0"), 2, 8, m), ArtKit.AMBER, 10, 0.45),
			_box(Color("#D99A2B"), Color("#D99A2B"), 2, 8, Vector4(m.x, m.y + 2, m.z, m.w - 2)),
			_box(Color(ArtKit.AMBER, 0.35), Color.TRANSPARENT, 0, 8, m), ArtKit.WALL, ArtKit.WALL)
	t.set_type_variation("GhostButton", "Button")
	_button_set(t, "GhostButton",
			_box(Color.TRANSPARENT, Color(ArtKit.TEXT, 0.3), 1, 8, m), _box(Color(ArtKit.TEXT, 0.06), Color(ArtKit.TEXT, 0.5), 1, 8, m),
			_box(Color(ArtKit.TEXT, 0.14), Color(ArtKit.TEXT, 0.5), 1, 8, m), _box(Color.TRANSPARENT, Color(ArtKit.TEXT, 0.12), 1, 8, m),
			ArtKit.TEXT, ArtKit.TEXT)

	# Clearance meter (lineup builder x/12).
	t.set_stylebox("background", "ProgressBar", _box(ArtKit.MORTAR, PANEL_EDGE, 1, 6, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", _box(ArtKit.AMBER, Color.TRANSPARENT, 0, 6, Vector4.ZERO))
	t.set_font("font", "ProgressBar", f["numeral"])
	t.set_font_size("font_size", "ProgressBar", 18)
	t.set_color("font_color", "ProgressBar", ArtKit.WALL)

	# Touch-friendly scroll bars (hand strip, album).
	for bar: String in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color(ArtKit.MORTAR, 0.8), Color.TRANSPARENT, 0, 6, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber", bar, _box(Color(ArtKit.TEXT, 0.35), Color.TRANSPARENT, 0, 6, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_highlight", bar, _box(Color(ArtKit.AMBER, 0.7), Color.TRANSPARENT, 0, 6, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_pressed", bar, _box(ArtKit.AMBER, Color.TRANSPARENT, 0, 6, Vector4(6, 6, 6, 6)))
	return t
