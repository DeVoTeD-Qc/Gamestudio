# Generates assets/ui/hud_theme.tres and assets/ui/card_theme.tres (p13). Run:
#   godot --headless --path . -s res://tests/tools/build_themes.gd
# Edit the palette/sizes here, re-run, and commit the regenerated .tres files.
# Author: Technical Artist Agent (p13); match-screen styles and bundled fonts: UI/UX Agent (f01)
# hud_theme.tres is the project theme (project.godot gui/theme/custom). Text sizes are logical px;
# on the smallest supported screen one logical px is ~0.72 pt (scripts/ui/screen_profile.gd), so
# body text is >= 16 px (11.5 pt) and key numbers >= 20 px (14.4 pt).
extends SceneTree

const SLATE := Color("#12161A")
const GUNMETAL := Color("#232A31")
const GUNMETAL_HI := Color("#2E3740")
const FOG := Color("#D8DEE3")
const FOG_DIM := Color("#8D979F")
const AMBER := Color("#FFB020")
const TEAL := Color("#2EC4B6")
const RED := Color("#E5383B")
const CYAN := Color("#5BC0EB")
const BRASS := Color("#C9A227")
const OLIVE := Color("#5B6B3A")
const SAND := Color("#C2A878")
const CONCRETE := Color("#7A828A")


func _initialize() -> void:
	var fonts := _fonts()
	ResourceSaver.save(_card_theme(fonts), "res://assets/ui/card_theme.tres")
	ResourceSaver.save(_hud_theme(fonts), "res://assets/ui/hud_theme.tres")
	print("themes written")
	quit()


## Bundled OFL fonts from the art direction (assets/fonts/, licences next to them). Every
## FontVariation gets an explicit base_font: a variation without one resolves its base from
## whatever theme is global at the time (engine default in the editor, this theme itself once it
## is the project theme), so its line height and glyphs changed between editor, tests and builds.
## Body uses Barlow Medium instead of Regular: thin strokes break up at 11-12 pt on a phone.
const FONT_BODY: String = "res://assets/fonts/Barlow-Medium.ttf"
const FONT_HEADING: String = "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
const FONT_NUMERIC: String = "res://assets/fonts/ShareTechMono-Regular.ttf"


func _fonts() -> Dictionary:
	var body_file: Font = load(FONT_BODY)
	var body := FontVariation.new()
	body.resource_name = "body"
	body.base_font = body_file
	var heading := FontVariation.new()
	heading.resource_name = "heading_condensed"
	heading.base_font = load(FONT_HEADING)
	heading.fallbacks = [body_file]
	heading.spacing_glyph = 1
	var numeric := FontVariation.new()
	numeric.resource_name = "numeric"
	numeric.base_font = load(FONT_NUMERIC)
	numeric.fallbacks = [body_file]  # Share Tech Mono lacks some symbols (·, −).
	numeric.variation_embolden = 0.3
	return {"body": body, "heading": heading, "numeric": numeric}


func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 0,
		chamfer: bool = false, margin: Vector4 = Vector4(8, 6, 8, 6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if chamfer:
		sb.corner_detail = 1  # straight cut corners: tactical-tablet look
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	return sb


func _palette(t: Theme, type_name: String) -> void:
	for pair: Array in [["background", SLATE], ["panel", GUNMETAL], ["panel_hi", GUNMETAL_HI],
			["text", FOG], ["text_dim", FOG_DIM], ["accent", AMBER], ["friend", TEAL],
			["enemy", RED], ["special", CYAN], ["elite", BRASS], ["olive", OLIVE],
			["sand", SAND], ["concrete", CONCRETE]]:
		t.set_color(pair[0], type_name, pair[1])


func _label_var(t: Theme, name: String, font: Font, size: int, color: Color,
		outline: int = 0, outline_color: Color = SLATE) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if outline > 0:
		t.set_constant("outline_size", name, outline)
		t.set_color("font_outline_color", name, outline_color)


func _card_theme(f: Dictionary) -> Theme:
	var t := Theme.new()
	t.default_font = f["body"]
	t.default_font_size = 14
	t.set_color("font_color", "Label", FOG)
	# Palette read by CardView (get_theme_color("friend", "Card")).
	_palette(t, "Card")
	t.set_color("face_unit", "Card", Color("#2A323A"))
	t.set_color("face_tactic", "Card", Color("#26302B"))
	t.set_color("face_equipment", "Card", Color("#302C25"))
	t.set_color("face_killstreak", "Card", Color("#152A35"))
	t.set_color("face_operator", "Card", Color("#2B2F36"))
	t.set_color("frame_standard", "Card", Color("#59636C"))
	t.set_constant("edge_cue_height", "Card", 14)
	# Text roles. Sizes are for the 250x350 base card; at 50% they halve.
	_label_var(t, "CardName", f["heading"], 20, FOG)
	_label_var(t, "CardCost", f["numeric"], 28, SLATE)
	_label_var(t, "CardThreshold", f["numeric"], 30, SLATE)
	_label_var(t, "CardStat", f["numeric"], 28, FOG, 6, SLATE)
	_label_var(t, "CardTag", f["heading"], 13, SLATE)
	_label_var(t, "CardKeyword", f["heading"], 15, FOG)
	_label_var(t, "CardBody", f["body"], 13, FOG)
	_label_var(t, "CardRange", f["numeric"], 13, FOG_DIM)
	# Panels inside the card.
	t.set_type_variation("CardChip", "PanelContainer")
	t.set_stylebox("panel", "CardChip", _box(FOG, Color.TRANSPARENT, 0, 3, true, Vector4(6, 1, 6, 1)))
	t.set_type_variation("CardArt", "PanelContainer")
	t.set_stylebox("panel", "CardArt", _box(Color("#171C21"), Color("#3A444D"), 1, 2, false, Vector4.ZERO))
	return t


func _hud_theme(f: Dictionary) -> Theme:
	var t := Theme.new()
	t.default_font = f["body"]
	t.default_font_size = 16
	_palette(t, "Hud")
	t.set_color("font_color", "Label", FOG)
	# Panels: gunmetal with chamfered corners.
	var panel := _box(GUNMETAL, Color("#3A444D"), 1, 6, true, Vector4(10, 8, 10, 8))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("HudPanelDark", "PanelContainer")
	t.set_stylebox("panel", "HudPanelDark", _box(Color(SLATE, 0.92), Color("#2C343B"), 1, 6, true, Vector4(10, 8, 10, 8)))
	# Zone states. Shape cue for "contested" (stripes) is drawn by the lane scene; the box
	# here gives the border language: friend solid, enemy double-weight, contested amber.
	t.set_type_variation("ZoneFriend", "PanelContainer")
	t.set_stylebox("panel", "ZoneFriend", _box(Color(TEAL, 0.14), TEAL, 2, 8, true))
	t.set_type_variation("ZoneEnemy", "PanelContainer")
	t.set_stylebox("panel", "ZoneEnemy", _box(Color(RED, 0.14), RED, 4, 8, true))
	t.set_type_variation("ZoneContested", "PanelContainer")
	t.set_stylebox("panel", "ZoneContested", _box(Color(AMBER, 0.08), Color(AMBER, 0.7), 2, 8, true))
	t.set_type_variation("ZoneNeutral", "PanelContainer")
	t.set_stylebox("panel", "ZoneNeutral", _box(Color(GUNMETAL, 0.5), Color("#3A444D"), 1, 8, true))
	# Buttons: amber means "interactive".
	var m := Vector4(14, 8, 14, 8)
	t.set_stylebox("normal", "Button", _box(GUNMETAL, AMBER, 2, 6, true, m))
	t.set_stylebox("hover", "Button", _box(GUNMETAL_HI, AMBER, 2, 6, true, m))
	t.set_stylebox("pressed", "Button", _box(AMBER, AMBER, 2, 6, true, m))
	t.set_stylebox("disabled", "Button", _box(Color(GUNMETAL, 0.6), Color("#4A535B"), 1, 6, true, m))
	var focus := _box(Color.TRANSPARENT, Color(AMBER, 0.9), 2, 8, true, m)
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", f["heading"])
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", FOG)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", SLATE)
	t.set_color("font_hover_pressed_color", "Button", SLATE)
	t.set_color("font_focus_color", "Button", FOG)
	t.set_color("font_disabled_color", "Button", FOG_DIM)
	t.set_color("icon_normal_color", "Button", FOG)
	t.set_color("icon_pressed_color", "Button", SLATE)
	t.set_constant("h_separation", "Button", 8)
	# READY: big solid amber.
	t.set_type_variation("ReadyButton", "Button")
	var rm := Vector4(28, 12, 28, 12)
	t.set_stylebox("normal", "ReadyButton", _box(AMBER, Color("#FFD27A"), 2, 8, true, rm))
	t.set_stylebox("hover", "ReadyButton", _box(Color("#FFC24D"), Color.WHITE, 2, 8, true, rm))
	t.set_stylebox("pressed", "ReadyButton", _box(Color("#D18E12"), Color("#D18E12"), 2, 8, true, rm))
	t.set_stylebox("disabled", "ReadyButton", _box(Color("#4A535B"), Color("#4A535B"), 2, 8, true, rm))
	t.set_font_size("font_size", "ReadyButton", 28)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "ReadyButton", SLATE)
	t.set_color("font_disabled_color", "ReadyButton", FOG_DIM)
	# Labels by role.
	_label_var(t, "HudHeader", f["heading"], 20, FOG)
	_label_var(t, "HudSubtle", f["body"], 16, FOG_DIM)
	_label_var(t, "HudNumber", f["numeric"], 22, FOG)
	_label_var(t, "HudAccent", f["heading"], 18, AMBER)
	_label_var(t, "RangeBadge", f["heading"], 16, FOG)
	_label_var(t, "KillfeedFriend", f["numeric"], 16, TEAL, 4)
	_label_var(t, "KillfeedEnemy", f["numeric"], 16, RED, 4)
	_label_var(t, "XpPopup", f["heading"], 22, AMBER, 6)
	_label_var(t, "StreakLabel", f["numeric"], 20, CYAN, 4)
	# Tooltips (keyword tooltips on long-press).
	t.set_stylebox("panel", "TooltipPanel", _box(Color(SLATE, 0.96), AMBER, 1, 4, true, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", FOG)
	t.set_font_size("font_size", "TooltipLabel", 16)
	# Bars and sliders (supply pips, settings).
	t.set_stylebox("background", "ProgressBar", _box(SLATE, Color("#3A444D"), 1, 3, true, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", _box(AMBER, Color.TRANSPARENT, 0, 3, true, Vector4.ZERO))
	t.set_color("font_color", "ProgressBar", FOG)
	t.set_stylebox("slider", "HSlider", _box(SLATE, Color("#3A444D"), 1, 3, false, Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber_area", "HSlider", _box(AMBER, Color.TRANSPARENT, 0, 3, false, Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("#FFC24D"), Color.TRANSPARENT, 0, 3, false, Vector4(0, 3, 0, 3)))
	t.set_stylebox("separator", "HSeparator", _box(Color("#3A444D"), Color.TRANSPARENT, 0, 0, false, Vector4(0, 1, 0, 1)))
	t.set_constant("separation", "HSeparator", 8)
	_match_styles(t, f)
	return t


## Styles for the match screen (scenes/Match.tscn and scenes/match/*, p08). The scenes only set
## theme_type_variation; tests/test_board_layout.gd checks every name used there exists here.
func _match_styles(t: Theme, f: Dictionary) -> void:
	var edge := Color("#3A444D")
	_panel_var(t, "LanePanel", _box(Color("#191F25"), edge, 1, 6, true, Vector4(4, 4, 4, 4)))
	_panel_var(t, "LaneRowFriendly", _box(Color(TEAL, 0.06), Color.TRANSPARENT, 0, 4, false, Vector4(3, 3, 3, 3)))
	_panel_var(t, "LaneRowEnemy", _box(Color(RED, 0.06), Color.TRANSPARENT, 0, 4, false, Vector4(3, 3, 3, 3)))
	# Zone headers are compact; the zone state colours/borders come from Zone* above.
	for zone: String in ["ZoneFriend", "ZoneEnemy", "ZoneContested", "ZoneNeutral"]:
		var sb: StyleBoxFlat = (t.get_stylebox("panel", zone) as StyleBoxFlat).duplicate()
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		t.set_stylebox("panel", zone, sb)
	# Unit tokens. Friend: chamfered top corners + teal edge. Operator: brass, double weight.
	# Enemy: square corners with a heavy top edge (hazard-stripe stand-in). Shape, not colour only.
	var m := Vector4(4, 3, 4, 3)
	var friendly := _box(Color("#1D2B2E"), TEAL, 2, 0, false, m)
	friendly.corner_radius_top_left = 10
	friendly.corner_radius_top_right = 10
	friendly.corner_detail = 1
	_panel_var(t, "SlotFriendly", friendly)
	var operator: StyleBoxFlat = friendly.duplicate()
	operator.bg_color = Color("#2A2A22")
	operator.border_color = BRASS
	operator.border_width_top = 4
	operator.border_width_bottom = 4
	_panel_var(t, "SlotOperator", operator)
	var enemy := _box(Color("#2D1D20"), RED, 2, 0, false, m)
	enemy.border_width_top = 6
	_panel_var(t, "SlotEnemy", enemy)
	_panel_var(t, "SlotEmpty", _box(Color(SLATE, 0.6), Color("#2C343B"), 1, 4, false, m))
	_panel_var(t, "SlotIncoming", _box(Color(RED, 0.08), Color(RED, 0.6), 1, 4, false, m))
	# Hand card chips (the full CardView is for the inspector, see README "Phone readability").
	_panel_var(t, "HandCard", _box(Color("#2A323A"), Color("#59636C"), 2, 6, true, Vector4(6, 4, 6, 4)))
	_panel_var(t, "CostBadge", _box(AMBER, Color.TRANSPARENT, 0, 3, true, Vector4(5, 0, 5, 0)))
	_panel_var(t, "MinimapCell", _box(SLATE, edge, 1, 4, true, Vector4(6, 2, 6, 3)))
	# Small shapes (Panel variations).
	_shape_var(t, "RedDot", _box(RED, RED.lightened(0.3), 2, 10, false, Vector4.ZERO))
	_shape_var(t, "SupplyPip", _box(FOG, Color.TRANSPARENT, 0, 2, true, Vector4.ZERO))
	_shape_var(t, "SupplyPipSpent", _box(Color.TRANSPARENT, FOG_DIM, 2, 2, true, Vector4.ZERO))
	_shape_var(t, "StreakSegment", _box(Color("#2E363E"), Color.TRANSPARENT, 0, 2, false, Vector4.ZERO))
	_shape_var(t, "StreakSegmentLit", _box(CYAN, Color.TRANSPARENT, 0, 2, false, Vector4.ZERO))
	_shape_var(t, "PerkSlot", _box(Color.TRANSPARENT, FOG_DIM, 2, 13, false, Vector4.ZERO))
	# Buttons: HudButton = small amber-edged button; KillstreakButton = cyan (special).
	_button_var(t, "HudButton", GUNMETAL, AMBER, FOG, f)
	_button_var(t, "KillstreakButton", Color("#152A35"), CYAN, CYAN, f)
	# Labels.
	_label_var(t, "HudBig", f["numeric"], 34, FOG)
	_label_var(t, "FriendlyLabel", f["heading"], 20, TEAL)
	_label_var(t, "EnemyLabel", f["heading"], 20, RED)
	_label_var(t, "UnitName", f["heading"], 17, FOG)
	t.set_stylebox("normal", "RangeBadge", _box(Color("#4F555B"), CONCRETE, 1, 3, true, Vector4(5, 0, 5, 0)))


func _panel_var(t: Theme, name: String, sb: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, sb)


func _shape_var(t: Theme, name: String, sb: StyleBox) -> void:
	t.set_type_variation(name, "Panel")
	t.set_stylebox("panel", name, sb)


func _button_var(t: Theme, name: String, bg: Color, edge: Color, fg: Color, f: Dictionary) -> void:
	var m := Vector4(6, 4, 6, 4)
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, _box(bg, edge, 2, 6, true, m))
	t.set_stylebox("hover", name, _box(bg.lightened(0.08), edge, 2, 6, true, m))
	t.set_stylebox("pressed", name, _box(bg.darkened(0.25), edge, 2, 6, true, m))
	t.set_stylebox("hover_pressed", name, _box(bg.darkened(0.25), edge, 2, 6, true, m))
	# Locked killstreaks still carry info ("AT 3"), so disabled text stays readable.
	t.set_stylebox("disabled", name, _box(Color(bg, 0.5), Color(edge, 0.35), 2, 6, true, m))
	t.set_font("font", name, f["heading"])
	t.set_font_size("font_size", name, 18)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, name, fg)
	t.set_color("font_disabled_color", name, Color(fg, 0.75))
