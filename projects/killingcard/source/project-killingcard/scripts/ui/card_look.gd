# card_look.gd
# Purpose: kc-cards-impl (the head's picks on the card design page, documentation/ux/
#   card-design-options.html): the shared drawing language of the new cards, in one place.
#     - C1+ board card pieces: the FP reticle ring (team colour: teal yours, red the rival's; green
#       number when buffed), the Armor ballistic plate (steel grey on both sides, amber when damaged,
#       showing only what is left), trait chips (45% faint, lit with a glow while their set bonus is
#       on), the cost hex (red when you can't pay), the damage crack, chip backings.
#       kc-ipad-cards: the level coin and the weapon pill are gone (no training, no gun type on cards).
#     - The one title style off the board: Barlow Condensed Bold, 16 px canvas, UPPERCASE, #F2F5F7
#       (title_label()); rules lines Barlow Condensed SemiBold 16 px #C9D1D8.
#   Pure static drawing on any CanvasItem; sizes are passed in, so the board (57 / 76 px banners),
#   the hand (X1), the Y2+ card and the inspector share it.
# Dependencies: SynergyGlyphs (trait icons, band colours), SynergyRules (names), UiKit.
#   kc-ui-hooks: the reticle, the Armor plate, the crack and the Pick glyph ask the
#   UI kit first (UiKit.draw_piece / draw_icon) and keep this code drawing as the fallback.
# Author: UI/UX Agent (kc-cards-impl); kit hooks: Technical Artist Agent (kc-ui-hooks)
class_name CardLook
extends RefCounted

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const TITLE_FONT: FontFile = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const RULE_FONT: FontFile = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
## kc-hand-y2: lore lines (cards with no effect): Barlow Condensed Medium Italic, dark grey.
const LORE_FONT: FontFile = preload("res://assets/fonts/BarlowCondensed-MediumItalic.ttf")
const LORE_COLOR: Color = Color("#8A949C")
## kc-readability (the head: "the cost icon and number as well as stats icon and number need to be
## bigger / more readable. We can use a better font"): every card number (cost, FP, Armor, the Supply
## counter) uses one bold condensed display face with tabular digits and a dark outline.
const NUM_FONT: Font = preload("res://assets/fonts/card_numbers_oswald.tres")
## Outline width (px) of card numbers drawn over art.
const NUM_OUTLINE: int = 4
## The title spec (every card off the board): 16 px canvas = 11.6 pt on the 844x390 phone.
const TITLE_PX: int = 16
const TITLE_COLOR: Color = Color("#F2F5F7")
const RULE_PX: int = 16
const RULE_COLOR: Color = Color("#C9D1D8")
const LOCKED_COLOR: Color = Color("#8C969E")
## FP reticle: team colours (the objective tiles' teal / red), the only plate in team colour.
const TEAM: Dictionary = {
	&"player": [Color("#2EC4B6"), Color("#0F2F2C")],
	&"enemy": [Color("#FF5A5D"), Color("#341113")],
}
## Armor plate: steel grey for both sides; amber when damaged (never red: red is the rival).
const AR_EDGE: Color = Color("#B9C2C9")
const AR_FILL: Color = Color("#2A3238")
const AR_DMG_EDGE: Color = Color("#F2A33A")
const AR_DMG_FILL: Color = Color("#4A3412")
const AR_DMG_NUM: Color = Color("#FFC067")
const UP: Color = Color("#7CF29A")
const DOWN: Color = Color("#FF6B6B")
const AMBER: Color = Color("#FFB020")
const BRASS: Color = Color("#F3D36B")
const CHIP: Color = Color(0.04, 0.05, 0.055, 0.86)
const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
## Trait chip opacity while its set bonus is off.
const TRAIT_FAINT: float = 0.45
## kc-ui-hooks: the v2 kit slots these badges ask UiKit for (prompt pack §7.4b); the code shape is the
## fallback and the numbers / letters always draw on top in code.
const PLATE_FP: StringName = &"plate_fp_reticle"
const PLATE_ARMOR: StringName = &"plate_armor_ballistic"
const FX_CRACK: StringName = &"fx_crack_damage"


## A Label in the title style (Barlow Condensed Bold 16 px, UPPERCASE, #F2F5F7, one line).
static func title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text.replace("★", "").strip_edges().to_upper()
	l.add_theme_font_override(&"font", TITLE_FONT)
	l.add_theme_font_size_override(&"font_size", TITLE_PX)
	l.add_theme_color_override(&"font_color", TITLE_COLOR)
	l.add_theme_constant_override(&"outline_size", 0)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_meta(&"title_style", true)
	return l


## A rules line Label (Barlow Condensed SemiBold 16 px).
static func rule_label(text: String, bold: bool = false, color: Color = RULE_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", TITLE_FONT if bold else RULE_FONT)
	l.add_theme_font_size_override(&"font_size", RULE_PX)
	l.add_theme_color_override(&"font_color", TITLE_COLOR if bold else color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## The team of a banner side (&"player" / &"enemy"; anything else = &"player").
static func team_of(side: StringName) -> StringName:
	return &"enemy" if side == &"enemy" or side == &"rival" else &"player"


static func _text_center(ci: CanvasItem, r: Rect2, text: String, fs: int, c: Color, font: Font = NUM_FONT, outline: int = 0) -> void:
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, INK)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## FP: a reticle ring with four gaps (team colour), a dark fill, the number on top. trend > 0 = buffed
## (green), < 0 = lowered (red).
static func draw_reticle(ci: CanvasItem, r: Rect2, value: int, team: StringName = &"player", trend: int = 0, with_number: bool = true) -> void:
	var cols: Array = TEAM.get(team_of(team), TEAM[&"player"])
	var c: Vector2 = r.get_center()
	var rad: float = minf(r.size.x, r.size.y) * 0.5
	# kc-ui-hooks: the painted steel badge (plate_fp_reticle), modulated to the team colour; else drawn.
	if not UiKit.draw_piece(ci, PLATE_FP, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), cols[0]):
		var w: float = maxf(1.6, rad * 0.17)
		ci.draw_circle(c, rad - w * 0.4, cols[1])
		# Four arcs with gaps at the cardinal points (the reticle).
		var gap: float = 0.32
		for i: int in 4:
			ci.draw_arc(c, rad - w * 0.5, i * PI * 0.5 + gap * 0.5, (i + 1) * PI * 0.5 - gap * 0.5, 10, cols[0], w, true)
	if not with_number:
		return
	var num: Color = trend_color(trend)
	var txt: String = str(value)
	var fs: int = maxi(14, int(roundf(rad * (1.2 if txt.length() > 1 else 1.4))))
	_text_center(ci, Rect2(c - Vector2(rad, rad + rad * 0.06), Vector2(rad, rad) * 2.0), txt, fs, num, NUM_FONT, NUM_OUTLINE)


## Armor: a ballistic plate (clipped top corners, rounded bottom), steel grey; amber when damaged.
static func draw_armor(ci: CanvasItem, r: Rect2, value: int, damaged: bool = false, with_number: bool = true) -> void:
	var w: float = r.size.x
	var h: float = r.size.y
	var p: Vector2 = r.position
	# kc-ui-hooks: the painted steel plate (plate_armor_ballistic), as is; amber when damaged. Else drawn.
	if not UiKit.draw_piece(ci, PLATE_ARMOR, r, AR_DMG_EDGE if damaged else Color.WHITE):
		var cut: float = w * 0.22
		var rr: float = w * 0.14
		var pts: PackedVector2Array = [p + Vector2(cut, 1), p + Vector2(w - cut, 1), p + Vector2(w - 1, cut), p + Vector2(w - 1, h - rr - 1)]
		for i: int in 5:
			var a: float = i * PI * 0.5 / 4.0
			pts.append(p + Vector2(w - 1 - rr, h - 1 - rr) + Vector2(cos(a), sin(a)) * rr)
		for i: int in 5:
			var a: float = PI * 0.5 + i * PI * 0.5 / 4.0
			pts.append(p + Vector2(1 + rr, h - 1 - rr) + Vector2(cos(a), sin(a)) * rr)
		pts.append(p + Vector2(1, cut))
		ci.draw_colored_polygon(pts, AR_DMG_FILL if damaged else AR_FILL)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		ci.draw_polyline(outline, AR_DMG_EDGE if damaged else AR_EDGE, maxf(1.5, w * 0.075), true)
	if not with_number:
		return
	var txt: String = str(value)
	var fs: int = maxi(14, int(roundf(w * (0.62 if txt.length() > 1 else 0.74))))
	_text_center(ci, Rect2(p + Vector2(0, -h * 0.02), Vector2(w, h * 0.96)), txt, fs, AR_DMG_NUM if damaged else Color.WHITE, NUM_FONT, NUM_OUTLINE)


## The FP number's colour: green when buffed, red when lowered, else white.
static func trend_color(trend: int) -> Color:
	return UP if trend > 0 else (DOWN if trend < 0 else Color.WHITE)


## A trait chip: the trait's icon in a square; lit = its set bonus is on (full colour + glow), else
## faint (TRAIT_FAINT). focus = the synergy rail highlights it (full + white ring).
static func draw_trait(ci: CanvasItem, r: Rect2, t: StringName, lit: bool, focus: bool = false, alpha: float = -1.0) -> void:
	if t == &"":
		return
	var tc: Color = SynergyGlyphs.trait_color(t)
	var a: float = alpha if alpha >= 0.0 else (1.0 if lit or focus else TRAIT_FAINT)
	if lit or focus:
		ci.draw_rect(r.grow(2.5), Color(tc if not focus else Color.WHITE, 0.32 * a))
	ci.draw_rect(r, Color(0.04, 0.05, 0.06, 0.92 * maxf(a, 0.6)))
	ci.draw_rect(r, Color(tc if not focus else Color.WHITE, a), false, maxf(1.2, r.size.x * 0.07))
	SynergyGlyphs.draw_trait_icon(ci, r.grow(-r.size.x * 0.17), t, Color(tc, a))


## The cost hex (amber; can't pay = dark red with a red rim and number).
static func draw_cost(ci: CanvasItem, r: Rect2, value: String, cant_pay: bool = false) -> void:
	var c: Vector2 = r.get_center()
	var rad: float = minf(r.size.x, r.size.y * 1.1) * 0.5
	var pts: PackedVector2Array = []
	for i: int in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	ci.draw_colored_polygon(pts, Color("#4A1A1C") if cant_pay else AMBER)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color("#FF5A5D") if cant_pay else AMBER.darkened(0.45), 1.5, true)
	# kc-readability: a bigger digit in the number face (dark on amber reads without an outline).
	_text_center(ci, Rect2(r.position - Vector2(0, r.size.y * 0.04), r.size), value, maxi(12, int(r.size.y * 0.8)), Color("#FF9A9A") if cant_pay else INK, NUM_FONT, 0)


## A small dark backing behind one group of icons (never a band across the art). kc-readability: soft
## edged (a feathered shadow around a ~80% black rounded plate) so the badges read on bright art.
static func draw_chip(ci: CanvasItem, r: Rect2, radius: float = 3.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BACKING
	sb.set_corner_radius_all(int(maxf(radius, 4.0)))
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = int(maxf(3.0, r.size.y * 0.14))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## The backing's colour (tests).
const BACKING: Color = Color(0.03, 0.035, 0.04, 0.8)


## The damage crack (amber over a dark stroke), top-left corner.
static func draw_crack(ci: CanvasItem, origin: Vector2, s: float) -> void:
	# kc-ui-hooks: the painted crack (fx_crack_damage, white + alpha): a dark copy 1 px larger, then amber.
	if UiKit.has_piece(FX_CRACK):
		UiKit.draw_piece(ci, FX_CRACK, Rect2(origin, Vector2(s, s)).grow(1.0), Color(0.04, 0.05, 0.06, 0.75))
		UiKit.draw_piece(ci, FX_CRACK, Rect2(origin, Vector2(s, s)), AR_DMG_EDGE)
		return
	var k: float = s / 22.0
	var pts: PackedVector2Array = [Vector2(1, 2), Vector2(7, 7), Vector2(5, 11), Vector2(11, 14), Vector2(10, 19)]
	var br: PackedVector2Array = [Vector2(7, 7), Vector2(12, 5)]
	for i: int in pts.size():
		pts[i] = origin + pts[i] * k
	for i: int in br.size():
		br[i] = origin + br[i] * k
	ci.draw_polyline(pts, Color(0.04, 0.05, 0.06, 0.75), 3.0 * k, true)
	ci.draw_polyline(br, Color(0.04, 0.05, 0.06, 0.75), 3.0 * k, true)
	ci.draw_polyline(pts, AR_DMG_EDGE, 1.4 * k, true)
	ci.draw_polyline(br, AR_DMG_EDGE, 1.4 * k, true)


## The damaged bottom edge: a thin amber line along the bottom, fading in from the left.
static func draw_damage_edge(ci: CanvasItem, r: Rect2, thickness: float = 2.0) -> void:
	var y: float = r.end.y - thickness
	ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, y), Vector2(r.end.x, y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color(AR_DMG_EDGE, 0.25), AR_DMG_EDGE, AR_DMG_EDGE, Color(AR_DMG_EDGE, 0.25)]))


## The new Pick glyph (kc-cards-impl): a shield with a downward arrow ("hits the lowest Armor"), so it
## is never a crosshair like the FP reticle. White, tint it.
## kc-ui-hooks: the kit's painted Pick (ico_kw_pick_v2, IconSheet.PICK_KIT_ID) wins when imported, so
## every caller (board banners, the O2 tray card, the Y2+ text box) picks it up; code_only skips it.
static func draw_pick_icon(ci: CanvasItem, r: Rect2, c: Color, code_only: bool = false) -> void:
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	if not code_only and UiKit.draw_icon(ci, IconSheet.PICK_KIT_ID, Rect2(o, Vector2(s, s)), c):
		return
	var w: float = maxf(1.5, s * 0.1)
	var pts: PackedVector2Array = [Vector2(0.5, 0.1), Vector2(0.85, 0.22), Vector2(0.85, 0.5), Vector2(0.72, 0.75), Vector2(0.5, 0.92),
			Vector2(0.28, 0.75), Vector2(0.15, 0.5), Vector2(0.15, 0.22), Vector2(0.5, 0.1)]
	for i: int in pts.size():
		pts[i] = o + pts[i] * s
	ci.draw_polyline(pts, c, w, true)
	ci.draw_line(o + Vector2(0.5, 0.32) * s, o + Vector2(0.5, 0.68) * s, c, w, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(0.36, 0.55) * s, o + Vector2(0.5, 0.69) * s, o + Vector2(0.64, 0.55) * s]), c, w, true)


## kc-ipad-cards: one ability plate (board banners, hand cards, the Y2+ stats bar), as BannerView
## lists them (ability_kinds): a keyword icon id (kw_first_shot ...), &"kw_pick", &"pierce",
## &"protector", &"bolt" / &"bolt_more", or [&"kw", neighbour keyword]. `mine` turns the arrows of
## Protector / Pierce toward the rival.
static func draw_ability(ci: CanvasItem, rr: Rect2, kind: Variant, accent: Color, mine: bool = true, kw_active: bool = false,
		side_c: Color = Color("#2EC4B6")) -> void:
	if kind is Array:
		SynergyGlyphs.draw_keyword_plate(ci, rr, kind[1], kw_active, side_c, mine)
		return
	if kind == &"pierce":
		SynergyGlyphs.draw_pierce_plate(ci, rr, accent, not mine)
		return
	ci.draw_rect(rr, Color(INK, 0.82))
	ci.draw_rect(rr, Color(1, 1, 1, 0.18), false, 1.0)
	var inner: Rect2 = rr.grow(-rr.size.x * 0.12)
	match kind:
		&"protector":
			_draw_protector(ci, rr, accent, mine)
		&"bolt", &"bolt_more":
			_draw_bolt(ci, rr, accent, kind == &"bolt_more")
		&"kw_pick":
			draw_pick_icon(ci, rr.grow(-rr.size.x * 0.1), accent)
		_:
			var tex: Texture2D = IconSheet.get_icon(kind)
			if tex != null:
				ci.draw_texture_rect(tex, inner, false, accent)


## A keyword's glyph alone (no plate) by keyword id (first_shot, pick, pierce, arrives_front,
## on_deploy ...): the Y2+ text box lines.
static func draw_keyword_icon(ci: CanvasItem, r: Rect2, id: StringName, tint: Color) -> void:
	if id == &"pick":
		draw_pick_icon(ci, r, tint)
	elif id == &"pierce":
		SynergyGlyphs.draw_pierce_icon(ci, r, tint)
	elif id == &"arrives_front":
		_draw_chevron(ci, r, tint, true)
	else:
		var tex: Texture2D = IconSheet.get_keyword_icon(id)
		if tex != null:
			ci.draw_texture_rect(tex, r, false, tint)


## The effect bolt (a dot when the card has more than fits).
static func _draw_bolt(ci: CanvasItem, rr: Rect2, c: Color, more: bool) -> void:
	var s: float = rr.size.x
	var p: Vector2 = rr.position
	# kc-ui-import2: the UI kit's ico_effect_bolt wins when imported (the "more" dot stays code).
	if UiKit.draw_icon(ci, &"effect_bolt", rr.grow(-s * 0.12), c):
		if more:
			ci.draw_circle(p + Vector2(s * 0.85, s * 0.85), s * 0.1, c)
		return
	var pts: PackedVector2Array = [p + Vector2(s * 0.58, s * 0.12), p + Vector2(s * 0.28, s * 0.55), p + Vector2(s * 0.48, s * 0.55),
			p + Vector2(s * 0.38, s * 0.88), p + Vector2(s * 0.72, s * 0.42), p + Vector2(s * 0.52, s * 0.42)]
	ci.draw_colored_polygon(pts, c)
	if more:
		ci.draw_circle(p + Vector2(s * 0.85, s * 0.85), s * 0.1, c)


## Protector: an up-chevron over a bar ("takes the front"); pointing down on the rival's cards.
static func _draw_protector(ci: CanvasItem, rr: Rect2, c: Color, up: bool) -> void:
	var s: float = rr.size.x
	var p: Vector2 = rr.position
	var w: float = maxf(2.0, s * 0.08)
	var y0: float = s * (0.62 if up else 0.38)
	var y1: float = s * (0.3 if up else 0.7)
	ci.draw_polyline(PackedVector2Array([p + Vector2(s * 0.22, y0), p + Vector2(s * 0.5, y1), p + Vector2(s * 0.78, y0)]), c, w)
	ci.draw_line(p + Vector2(s * 0.22, s * (0.8 if up else 0.2)), p + Vector2(s * 0.78, s * (0.8 if up else 0.2)), c, w)


static func _draw_chevron(ci: CanvasItem, r: Rect2, c: Color, up: bool) -> void:
	_draw_protector(ci, r, c, up)


# =============================================================================
# kc-deck-match (the head: "Tactic and Field cards should have a different icon"): the card type
# icons. The UI kit's ico_type_tactic / ico_type_field (UiKit ids type_tactic / type_field) win when
# imported; the code glyphs below are the fallback: Tactic = an orders sheet with a lightning bolt,
# Field = a flag planted on a strip of ground. Units keep their look (no type icon).
# =============================================================================

const ICO_TYPE_TACTIC: StringName = &"type_tactic"
const ICO_TYPE_FIELD: StringName = &"type_field"


## The kit id of a card kind's type icon (&"tactic" / &"field" or &"equipment"); &"" for the rest.
static func type_icon_id(kind: StringName) -> StringName:
	match kind:
		&"tactic":
			return ICO_TYPE_TACTIC
		&"field", &"equipment":
			return ICO_TYPE_FIELD
	return &""


## The kind (&"tactic" / &"field" / &"") from a card's type word ("TACTIC", "FIELD", "equipment" ...).
static func type_kind(word: String) -> StringName:
	var w: String = word.to_lower()
	if w.begins_with("tactic"):
		return &"tactic"
	if w.begins_with("field") or w.begins_with("equip"):
		return &"field"
	return &""


## Draws the type icon of `kind` in r (square, centred), tinted. code_only skips the kit image.
static func draw_type_icon(ci: CanvasItem, r: Rect2, kind: StringName, tint: Color, code_only: bool = false) -> void:
	var id: StringName = type_icon_id(kind)
	if id == &"":
		return
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.position + (r.size - Vector2(s, s)) * 0.5
	if not code_only and UiKit.draw_icon(ci, id, Rect2(o, Vector2(s, s)), tint):
		return
	var w: float = maxf(1.5, s * 0.09)
	if id == ICO_TYPE_TACTIC:
		# Orders: a sheet with a folded corner, a lightning bolt on it.
		var pts: PackedVector2Array = [Vector2(0.18, 0.06), Vector2(0.64, 0.06), Vector2(0.84, 0.26), Vector2(0.84, 0.94),
				Vector2(0.18, 0.94), Vector2(0.18, 0.06)]
		for i: int in pts.size():
			pts[i] = o + pts[i] * s
		ci.draw_polyline(pts, tint, w, true)
		ci.draw_polyline(PackedVector2Array([o + Vector2(0.64, 0.06) * s, o + Vector2(0.64, 0.26) * s, o + Vector2(0.84, 0.26) * s]), tint, w * 0.8, true)
		var bolt: PackedVector2Array = [Vector2(0.56, 0.3), Vector2(0.32, 0.6), Vector2(0.49, 0.6), Vector2(0.42, 0.84), Vector2(0.68, 0.52), Vector2(0.51, 0.52)]
		for i: int in bolt.size():
			bolt[i] = o + bolt[i] * s
		ci.draw_colored_polygon(bolt, tint)
	else:
		# Field: a flag on a pole, planted on a strip of ground.
		ci.draw_line(o + Vector2(0.3, 0.1) * s, o + Vector2(0.3, 0.82) * s, tint, w, true)
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0.33, 0.12) * s, o + Vector2(0.84, 0.25) * s, o + Vector2(0.33, 0.42) * s]), tint)
		ci.draw_line(o + Vector2(0.08, 0.86) * s, o + Vector2(0.92, 0.86) * s, tint, w * 1.3, true)
		ci.draw_line(o + Vector2(0.18, 0.94) * s, o + Vector2(0.38, 0.94) * s, tint, w * 0.8, true)
		ci.draw_line(o + Vector2(0.56, 0.94) * s, o + Vector2(0.8, 0.94) * s, tint, w * 0.8, true)
