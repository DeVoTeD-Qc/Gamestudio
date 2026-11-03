# hud_placeholder_style.gd
# Purpose: Builds the placeholder look of the match HUD in code (no theme file), so the
#   layout reads correctly before the real HUD theme (p13, assets/ui/) exists.
#   Every styled match control uses a theme type variation listed in VARIATIONS.
#   Names already used by assets/ui/hud_theme.tres (p13) are reused on purpose:
#   HudPanelDark, ZoneFriend/ZoneEnemy/ZoneContested/ZoneNeutral, HudSubtle,
#   HudHeader, HudNumber, RangeBadge (a Label), ReadyButton, KillfeedFriend/Enemy,
#   StreakLabel. The rest (Slot*, LaneRow*, HandCard, RedDot, SupplyPip...) are new
#   and should be added to hud_theme.tres. match_screen.gd merges the real theme
#   over this placeholder, so whatever the real theme defines wins.
# Dependencies: none.
# Author: UI/UX Agent
extends RefCounted

# Palette from documentation/art/style-guides/art-direction.md.
const SLATE: Color = Color("#12161A")
const GUNMETAL: Color = Color("#232A31")
const FOG: Color = Color("#D8DEE3")
const FOG_DIM: Color = Color("#8C969E")
const AMBER: Color = Color("#FFB020")
const TEAL: Color = Color("#2EC4B6")
const RED: Color = Color("#E5383B")
const CYAN: Color = Color("#5BC0EB")
const BRASS: Color = Color("#C9A227")
const CONCRETE: Color = Color("#7A828A")

## Theme type variation -> base type. The real hud_theme.tres should define these names.
const VARIATIONS: Dictionary = {
	&"HudPanelDark": &"PanelContainer",
	&"LanePanel": &"PanelContainer",
	&"ZoneFriend": &"PanelContainer",
	&"ZoneEnemy": &"PanelContainer",
	&"ZoneContested": &"PanelContainer",
	&"ZoneNeutral": &"PanelContainer",
	&"LaneRowFriendly": &"PanelContainer",
	&"LaneRowEnemy": &"PanelContainer",
	&"SlotFriendly": &"PanelContainer",
	&"SlotOperator": &"PanelContainer",
	&"SlotEnemy": &"PanelContainer",
	&"SlotEmpty": &"PanelContainer",
	&"SlotIncoming": &"PanelContainer",
	&"HandCard": &"PanelContainer",
	&"CostBadge": &"PanelContainer",
	&"MinimapCell": &"PanelContainer",
	&"RedDot": &"Panel",
	&"SupplyPip": &"Panel",
	&"SupplyPipSpent": &"Panel",
	&"StreakSegment": &"Panel",
	&"StreakSegmentLit": &"Panel",
	&"PerkSlot": &"Panel",
	&"ReadyButton": &"Button",
	&"HudButton": &"Button",
	&"KillstreakButton": &"Button",
	&"HudSubtle": &"Label",
	&"HudHeader": &"Label",
	&"HudNumber": &"Label",
	&"HudBig": &"Label",
	&"FriendlyLabel": &"Label",
	&"EnemyLabel": &"Label",
	&"KillfeedFriend": &"Label",
	&"KillfeedEnemy": &"Label",
	&"RangeBadge": &"Label",
	&"StreakLabel": &"Label",
}


## Returns a fresh Theme with every variation in VARIATIONS styled.
static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 20
	for variation: StringName in VARIATIONS:
		t.set_type_variation(variation, VARIATIONS[variation])

	t.set_color(&"font_color", &"Label", FOG)

	# Panels
	_panel(t, &"HudPanelDark", _box(GUNMETAL, Color.TRANSPARENT, 0, 6, 10))
	_panel(t, &"LanePanel", _box(Color("#1A2026"), Color("#3A444E"), 2, 6, 4))
	_panel(t, &"ZoneFriend", _box(TEAL.darkened(0.55), TEAL, 2, 4, 6))
	_panel(t, &"ZoneEnemy", _box(RED.darkened(0.6), RED, 2, 4, 6))
	# Contested: neutral fill with thick side bars (shape cue, not color alone).
	var contested: StyleBoxFlat = _box(GUNMETAL, FOG_DIM, 2, 4, 6)
	contested.border_width_left = 6
	contested.border_width_right = 6
	_panel(t, &"ZoneContested", contested)
	_panel(t, &"ZoneNeutral", _box(GUNMETAL, Color("#3A444E"), 2, 4, 6))
	_panel(t, &"LaneRowFriendly", _box(Color(TEAL, 0.06), Color.TRANSPARENT, 0, 4, 4))
	_panel(t, &"LaneRowEnemy", _box(Color(RED, 0.06), Color.TRANSPARENT, 0, 4, 4))
	_panel(t, &"MinimapCell", _box(SLATE, Color("#3A444E"), 1, 4, 4))
	_panel(t, &"CostBadge", _box(AMBER, Color.TRANSPARENT, 0, 3, 1))

	# Friendly units: beveled ("chevron notch") top corners, teal edge.
	var friendly: StyleBoxFlat = _box(Color("#1E2D30"), TEAL, 2, 0, 4)
	friendly.corner_radius_top_left = 12
	friendly.corner_radius_top_right = 12
	friendly.corner_detail = 1
	_panel(t, &"SlotFriendly", friendly)
	var operator: StyleBoxFlat = friendly.duplicate()
	operator.border_color = BRASS
	operator.border_width_top = 4
	operator.border_width_bottom = 4
	_panel(t, &"SlotOperator", operator)
	# Enemy units: square corners, thick top edge (the hazard-stripe stand-in).
	var enemy: StyleBoxFlat = _box(Color("#2E1E21"), RED, 2, 0, 4)
	enemy.border_width_top = 8
	_panel(t, &"SlotEnemy", enemy)
	_panel(t, &"SlotEmpty", _box(Color(SLATE, 0.6), Color("#2E363E"), 1, 4, 4))
	_panel(t, &"SlotIncoming", _box(Color(RED, 0.08), Color(RED, 0.6), 1, 4, 4))
	_panel(t, &"HandCard", _box(Color("#2A333B"), FOG_DIM, 2, 6, 6))

	# Small shapes
	_shape(t, &"RedDot", _box(RED, RED.lightened(0.3), 2, 10, 0))
	_shape(t, &"SupplyPip", _box(FOG, Color.TRANSPARENT, 0, 2, 0))
	_shape(t, &"SupplyPipSpent", _box(Color.TRANSPARENT, FOG_DIM, 2, 2, 0))
	_shape(t, &"StreakSegment", _box(Color("#2E363E"), Color.TRANSPARENT, 0, 2, 0))
	_shape(t, &"StreakSegmentLit", _box(CYAN, Color.TRANSPARENT, 0, 2, 0))
	_shape(t, &"PerkSlot", _box(Color.TRANSPARENT, FOG_DIM, 2, 16, 0))

	# Buttons (amber = interactive)
	_button(t, &"ReadyButton", AMBER, SLATE, 36, AMBER)
	_button(t, &"HudButton", GUNMETAL.lightened(0.08), FOG, 18, AMBER)
	_button(t, &"KillstreakButton", Color("#16252D"), CYAN, 18, CYAN)

	# Labels
	_label(t, &"HudSubtle", 16, FOG_DIM)
	_label(t, &"HudHeader", 22, FOG)
	_label(t, &"HudNumber", 26, FOG)
	_label(t, &"HudBig", 34, FOG)
	_label(t, &"FriendlyLabel", 20, TEAL)
	_label(t, &"EnemyLabel", 20, RED)
	_label(t, &"KillfeedFriend", 16, TEAL)
	_label(t, &"KillfeedEnemy", 16, RED)
	_label(t, &"StreakLabel", 18, CYAN)
	_label(t, &"RangeBadge", 16, FOG)
	t.set_stylebox(&"normal", &"RangeBadge", _box(CONCRETE.darkened(0.35), CONCRETE, 1, 3, 4))
	return t


static func _box(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func _panel(t: Theme, variation: StringName, sb: StyleBox) -> void:
	t.set_stylebox(&"panel", variation, sb)


static func _shape(t: Theme, variation: StringName, sb: StyleBox) -> void:
	t.set_stylebox(&"panel", variation, sb)


static func _button(t: Theme, variation: StringName, bg: Color, fg: Color, size: int, edge: Color) -> void:
	var normal: StyleBoxFlat = _box(bg, edge, 2, 6, 8)
	var pressed: StyleBoxFlat = _box(bg.darkened(0.25), edge, 2, 6, 8)
	var disabled: StyleBoxFlat = _box(Color(bg, 0.35), Color(edge, 0.3), 2, 6, 8)
	var focus: StyleBoxFlat = _box(Color.TRANSPARENT, FOG, 3, 6, 8)
	focus.draw_center = false
	t.set_stylebox(&"normal", variation, normal)
	t.set_stylebox(&"hover", variation, normal)
	t.set_stylebox(&"pressed", variation, pressed)
	t.set_stylebox(&"hover_pressed", variation, pressed)
	t.set_stylebox(&"disabled", variation, disabled)
	t.set_stylebox(&"focus", variation, focus)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(key, variation, fg)
	# Locked killstreaks still carry info ("AT 3"), so keep disabled text readable.
	t.set_color(&"font_disabled_color", variation, Color(fg, 0.75))
	t.set_font_size(&"font_size", variation, size)


static func _label(t: Theme, variation: StringName, size: int, color: Color) -> void:
	t.set_font_size(&"font_size", variation, size)
	t.set_color(&"font_color", variation, color)
