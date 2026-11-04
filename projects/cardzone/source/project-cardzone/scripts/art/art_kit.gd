# art_kit.gd
# Purpose: Single source of truth for the CardZone look (cz16), from art-direction.md v1.0 (cz15):
#   palette (section 1), the C/U/R/E/L rarity ladder with letters and ticks (section 2), card sizes
#   (section 3), area tile sizes and the gas treatment (section 4), and the bundled OFL fonts (section 7).
#   Adapted from CallingCard's ArtKit. CzCard, CzCardArt, CzAreaTile, CzMap and
#   tests/tools/build_themes.gd (assets/themes/cardzone_theme.tres) all read from here.
# Usage:
#   CzArtKit.GAS_LIME, CzArtKit.rarity(&"R") -> {letter, name, color, text, ticks}
#   CzArtKit.rarity_key("rare") -> &"R"   (accepts C/U/R/E/L, full names, "starter")
#   CzArtKit.tag_points(rect, cut)        -> PackedVector2Array clipped-tag outline (TL + BR cut 45 deg)
#   CzArtKit.gas_tone(color)              -> the gassed version of a base colour (darker, desaturated)
#   CzArtKit.font_display() / font_numeral() / font_body() / font_mono()
#   CzArtKit.compact_px(pt_per_px) / full_px(pt_per_px) -> card size in logical px for a screen
# Dependencies: assets/fonts/*.ttf
# Author: Technical Artist Agent (cz16)
class_name CzArtKit
extends RefCounted

# --- Palette (section 1) ---------------------------------------------------------------------------
const ZONE_VIOLET := Color("#2B1840")
const ZONE_DUSK := Color("#45285F")
const ZONE_EDGE := Color("#B49CFF")
const GAS_LIME := Color("#9BD43A")
const GAS_GLOW := Color("#E2FF8A")
const GAS_SHADE := Color("#3E5A12")
const BASALT := Color("#2F333B")
const DUNE := Color("#D8C8A2")
const SHOAL := Color("#2C6E7F")
const RUST := Color("#B0573A")
const SCRUB := Color("#7A8466")
const PAPER := Color("#F4F1FF")
const INK := Color("#1A1424")
const HIT_RED := Color("#E5484D")
const BRACE_STEEL := Color("#C9D3E0")

## Token name -> colour (theme builder, docs, tests).
const PALETTE: Dictionary = {
	"zone_violet": ZONE_VIOLET, "zone_dusk": ZONE_DUSK, "zone_edge": ZONE_EDGE,
	"gas_lime": GAS_LIME, "gas_glow": GAS_GLOW, "gas_shade": GAS_SHADE,
	"basalt": BASALT, "dune": DUNE, "shoal": SHOAL, "rust": RUST, "scrub": SCRUB,
	"paper": PAPER, "ink": INK, "hit_red": HIT_RED, "brace_steel": BRACE_STEEL,
}

# --- Rarity ladder (section 2) ----------------------------------------------------------------------
## Each step up is lighter, so rarity reads in greyscale. Every chip carries its letter; the inspector
## adds the word and 1-5 ticks. "text" is the letter colour (>= 4.6:1 on the chip).
const RARITIES: Dictionary = {
	&"C": {"letter": "C", "name": "COMMON", "color": Color("#3F4552"), "text": PAPER, "ticks": 1},
	&"U": {"letter": "U", "name": "UNCOMMON", "color": Color("#0F7A70"), "text": PAPER, "ticks": 2},
	&"R": {"letter": "R", "name": "RARE", "color": Color("#4C8AF2"), "text": INK, "ticks": 3},
	&"E": {"letter": "E", "name": "EPIC", "color": Color("#FFB070"), "text": INK, "ticks": 4},
	&"L": {"letter": "L", "name": "LEGENDARY", "color": Color("#FFEE80"), "text": INK, "ticks": 5},
}
const RARITY_ORDER: Array[StringName] = [&"C", &"U", &"R", &"E", &"L"]
## Starter cards: no chip (an empty dashed outline) and a quiet stripe.
const STARTER_STRIPE := Color("#8C8698")
## Rarities that get the animated glint (plan cz16). Strength and sweeps per second.
const GLINT: Dictionary = {&"E": {"strength": 0.55, "speed": 0.16}, &"L": {"strength": 0.8, "speed": 0.24}}

# --- Card types -------------------------------------------------------------------------------------
const TYPES: Array[StringName] = [&"weapon", &"item", &"attachment", &"hit", &"bounty"]
const TYPE_WORDS: Dictionary = {
	&"weapon": "WEAPON", &"item": "ITEM", &"attachment": "ATTACHMENT", &"hit": "HIT", &"bounty": "BOUNTY",
}

# --- Sizes (sections 3 and 4), in points -----------------------------------------------------------
const COMPACT_PT := Vector2(84, 118)
const FULL_PT := Vector2(220, 308)
const TILE_PT := Vector2(120, 64)
const CORE_TILE_PT := Vector2(136, 76)
## Card frame: clipped corners, ink border, rarity stripe on the left edge.
const CARD_CUT_PT: float = 6.0
const CARD_BORDER_PT: float = 2.0
const CARD_STRIPE_PT: float = 4.0
const TAP_PT: float = 44.0
## Floors (section 3): every numeral >= 8 pt, game-critical numbers >= 12 pt, names >= 9 pt.
const NUMERAL_FLOOR_PT: float = 8.0
const CRITICAL_NUMERAL_PT: float = 12.0
const NAME_FLOOR_PT: float = 9.0
## iPhone 844x390 landscape with scripts/ui/screen_profile.gd: one logical px = 0.722 pt.
const PHONE_PT_PER_PX: float = 0.7222
## iPhone SE 667x375 landscape (the canvas base floors at 540 px): one logical px = 0.694 pt.
const SMALL_PHONE_PT_PER_PX: float = 0.6944

const FONT_DISPLAY_PATH: String = "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
const FONT_BODY_PATH: String = "res://assets/fonts/Barlow-Medium.ttf"
const FONT_MONO_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"

static var _fonts: Dictionary = {}


## Normalises a rarity value: C/U/R/E/L, common..legendary, or "starter"/"" -> &"" (no chip).
static func rarity_key(value: Variant) -> StringName:
	var s: String = str(value).strip_edges().to_upper()
	if s == "" or s == "STARTER" or s == "S" or s == "-" or s == "NONE" or s == "<NULL>":
		return &""
	for k: StringName in RARITY_ORDER:
		if s == String(k) or s == String(RARITIES[k]["name"]):
			return k
	return &""


## Rarity spec, or an empty Dictionary for starters / unknown values.
static func rarity(value: Variant) -> Dictionary:
	var k: StringName = rarity_key(value)
	return RARITIES.get(k, {})


static func rarity_color(value: Variant) -> Color:
	var r: Dictionary = rarity(value)
	return r.get("color", STARTER_STRIPE)


static func type_key(value: Variant) -> StringName:
	var s: String = str(value).strip_edges().to_lower()
	if s.begins_with("weapon"):
		return &"weapon"
	if s.begins_with("attach"):
		return &"attachment"
	if s == "hit":
		return &"hit"
	if s.begins_with("bounty") or s == "marker":
		return &"bounty"
	return &"item"


## Logical px size of a compact / full card on a screen where one logical px is pt_per_px points.
static func compact_px(pt_per_px: float = 1.0) -> Vector2:
	return (COMPACT_PT / maxf(pt_per_px, 0.01)).ceil()


static func full_px(pt_per_px: float = 1.0) -> Vector2:
	return (FULL_PT / maxf(pt_per_px, 0.01)).ceil()


## Clipped-tag outline (the motif, section intro): top-left and bottom-right corners cut at 45 deg.
static func tag_points(r: Rect2, cut: float) -> PackedVector2Array:
	var c: float = minf(cut, minf(r.size.x, r.size.y) * 0.5)
	var p: Vector2 = r.position
	var e: Vector2 = r.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - c),
			Vector2(e.x - c, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + c)])


## Draws a clipped tag on any CanvasItem: fill, then an outline of width line_w (0 = none).
static func draw_tag(ci: CanvasItem, r: Rect2, cut: float, fill: Color, line: Color = Color(0, 0, 0, 0),
		line_w: float = 0.0, dashed: bool = false, dash: float = 4.0) -> void:
	var pts: PackedVector2Array = tag_points(r, cut)
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	if line_w > 0.0 and line.a > 0.0:
		var inset: PackedVector2Array = tag_points(r.grow(-line_w * 0.5), maxf(cut - line_w * 0.2, 0.0))
		if dashed:
			for i: int in inset.size():
				ci.draw_dashed_line(inset[i], inset[(i + 1) % inset.size()], line, line_w, dash, false)
		else:
			var closed: PackedVector2Array = inset.duplicate()
			closed.append(inset[0])
			ci.draw_polyline(closed, line, line_w, true)


## Gassed version of a base colour (section 4: darkened 40 % and desaturated).
static func gas_tone(c: Color) -> Color:
	var grey: float = c.get_luminance()
	var d: Color = c.lerp(Color(grey, grey, grey, c.a), 0.6)
	return d.darkened(0.4)


## Shield outline in a box (Brace value, cover badge).
static func shield_points(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w: float = r.size.x
	var h: float = r.size.y
	var o: Vector2 = r.position
	pts.append(o + Vector2(w * 0.5, 0))
	pts.append(o + Vector2(w, h * 0.13))
	pts.append(o + Vector2(w, h * 0.46))
	for i: int in range(1, 8):
		var t: float = float(i) / 8.0
		# Curve from the right shoulder down to the point.
		pts.append(o + Vector2(w * (1.0 - 0.5 * t * t), h * (0.46 + 0.54 * t)))
	pts.append(o + Vector2(w * 0.5, h))
	for i: int in range(7, 0, -1):
		var t: float = float(i) / 8.0
		pts.append(o + Vector2(w * 0.5 * t * t, h * (0.46 + 0.54 * t)))
	pts.append(o + Vector2(0, h * 0.46))
	pts.append(o + Vector2(0, h * 0.13))
	return pts


# --- Fonts (section 7) ------------------------------------------------------------------------------
## Barlow Condensed SemiBold: card names, labels, buttons, headers. Explicit base font so metrics never
## depend on whichever theme is global.
static func font_display() -> Font:
	if not _fonts.has("display"):
		var f := FontVariation.new()
		f.resource_name = "display_condensed"
		f.base_font = load(FONT_DISPLAY_PATH)
		f.fallbacks = [load(FONT_BODY_PATH)]
		f.spacing_glyph = 0
		_fonts["display"] = f
	return _fonts["display"]


## Barlow Condensed SemiBold with tabular figures: every stat number (cost, Brace, DMG, RNG).
static func font_numeral() -> Font:
	if not _fonts.has("numeral"):
		var f := FontVariation.new()
		f.resource_name = "numeral_tabular"
		f.base_font = load(FONT_DISPLAY_PATH)
		var ts: TextServer = TextServerManager.get_primary_interface()
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
		_fonts["numeral"] = f
	return _fonts["numeral"]


## Barlow Medium: effect text, coach, settings.
static func font_body() -> Font:
	if not _fonts.has("body"):
		var f := FontVariation.new()
		f.resource_name = "body"
		f.base_font = load(FONT_BODY_PATH)
		_fonts["body"] = f
	return _fonts["body"]


## Share Tech Mono: card ids, Zone track, round, timers, dev panel (never game-critical).
static func font_mono() -> Font:
	if not _fonts.has("mono"):
		var f := FontVariation.new()
		f.resource_name = "mono"
		f.base_font = load(FONT_MONO_PATH)
		f.fallbacks = [load(FONT_BODY_PATH)]
		_fonts["mono"] = f
	return _fonts["mono"]
