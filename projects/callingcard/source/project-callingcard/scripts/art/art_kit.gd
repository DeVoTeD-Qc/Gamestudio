# art_kit.gd
# Purpose: Single source of truth for the Banner Wall look (cc14): palette (art-direction.md section 4),
#   set duotones, Clearance / Showcase / set-complete frame treatments (section 3), and the bundled
#   OFL fonts (Barlow Condensed SemiBold for numbers and titles, Barlow Medium for body text).
#   BannerCard, CardArt and tests/tools/build_themes.gd (wall_theme.tres) all read from here.
# Usage:
#   ArtKit.PLAYER, ArtKit.side_color(&"rival"), ArtKit.set_palette(&"night_shift")
#   ArtKit.frame_spec(3)  /  ArtKit.frame_spec(1, &"showcase_gold")  -> Dictionary of frame values
#   ArtKit.frame_box(spec, 128.0)  -> StyleBoxFlat scaled for a card that is 128 px tall
#   ArtKit.font_display(), ArtKit.font_body()
# Dependencies: assets/fonts/*.ttf
# Author: Technical Artist Agent (cc14)
class_name ArtKit
extends RefCounted

# --- Palette (art-direction section 4) -----------------------------------------------------------
const WALL := Color("#14161B")
const MORTAR := Color("#23262E")
const BRICK := Color("#1B1E25")
const TEXT := Color("#ECE8DF")
const TEXT_DIM := Color("#A9A59C")
const PLAYER := Color("#3EC6C1")
const RIVAL := Color("#F2705A")
const AMBER := Color("#F5B63F")
const SIGNATURE := Color("#E9D8A6")
const NEUTRAL := Color("#8A8F99")
const ENAMEL := Color("#121419")
const SILHOUETTE_DARK := Color("#1A1C22")
const SILHOUETTE_LIGHT := Color("#3B3F49")

## Set ids used across the kit. Unknown sets fall back to "showcase"-free neutral greys.
const SETS: Array[StringName] = [&"night_shift", &"whiteout", &"signal_fire", &"old_guard", &"cipher", &"showcase"]
const SET_NAMES: Dictionary = {
	&"night_shift": "Night Shift", &"whiteout": "Whiteout", &"signal_fire": "Signal Fire",
	&"old_guard": "Old Guard", &"cipher": "Cipher", &"showcase": "Showcase",
}
## Poster duotones (art-direction section 4): a = first listed hex, b = second. deep/mid/hi are the
## three tones the poster art is painted in; edge is the set-complete edge-light colour.
const SET_PALETTES: Dictionary = {
	&"night_shift": {"a": Color("#C2408A"), "b": Color("#47B8D6"), "deep": Color("#1A0E22"), "mid": Color("#C2408A"), "hi": Color("#47B8D6"), "edge": Color("#E05AA8")},
	&"whiteout": {"a": Color("#CFE3EE"), "b": Color("#4E6475"), "deep": Color("#1E2A35"), "mid": Color("#4E6475"), "hi": Color("#CFE3EE"), "edge": Color("#BFE6FA")},
	&"signal_fire": {"a": Color("#E0452E"), "b": Color("#1D2A44"), "deep": Color("#0F1626"), "mid": Color("#1D2A44"), "hi": Color("#E0452E"), "edge": Color("#FF6A4A")},
	&"old_guard": {"a": Color("#B98A3E"), "b": Color("#5A1F24"), "deep": Color("#2A0E12"), "mid": Color("#5A1F24"), "hi": Color("#B98A3E"), "edge": Color("#E2B562")},
	&"cipher": {"a": Color("#0B0B0D"), "b": Color("#3FE0C5"), "deep": Color("#0B0B0D"), "mid": Color("#13302C"), "hi": Color("#3FE0C5"), "edge": Color("#3FE0C5")},
	&"showcase": {"a": Color("#C9D2DC"), "b": Color("#3A4250"), "deep": Color("#1A1E26"), "mid": Color("#5A6474"), "hi": Color("#E6ECF2"), "edge": Color("#F3F6FA")},
	&"showcase_gold": {"a": Color("#E8C766"), "b": Color("#5A3D12"), "deep": Color("#22170A"), "mid": Color("#7A5418"), "hi": Color("#F0D27A"), "edge": Color("#FFE49A")},
}

const CLEARANCE_NAMES: Array[String] = ["", "Issue", "Merit", "Distinction", "Legend"]
const TRAITS: Array[StringName] = [&"steady", &"veteran", &"ambush", &"reclaim", &"clutch", &"cipher"]
const TRAIT_NAMES: Dictionary = {
	&"steady": "Steady", &"veteran": "Veteran", &"ambush": "Ambush", &"reclaim": "Reclaim",
	&"clutch": "Clutch", &"cipher": "Cipher", &"none": "",
}
## Origin -> trait (spec 4.4). Lets the card show the right icon when only the origin is known.
const ORIGIN_TRAIT: Dictionary = {
	&"challenge": &"steady", &"mastery": &"veteran", &"event": &"ambush", &"prestige": &"reclaim",
	&"ranked": &"clutch", &"secret": &"cipher", &"showcase": &"none", &"store": &"none",
}

# --- Frames (art-direction section 3) -------------------------------------------------------------
## Frame values in DESIGN UNITS for a card 128 units tall (512 x 128 source size). frame_box() and
## BannerCard scale them to the real card height. Keys:
##   border  frame width          base / hi / lo  frame colour, bevel highlight, bevel shadow
##   inlay   inlay line colour (alpha 0 = none)   glow  outer glow colour (alpha 0 = none), glow_size
##   glint   shader glint strength (0 = none), glint_speed (sweeps per second), sheen (glint over art)
const FRAMES: Dictionary = {
	1: {"name": "Issue", "border": 6.0, "radius": 6.0, "base": Color("#474B54"), "hi": Color("#5A5F69"), "lo": Color("#2E3138"),
		"inlay": Color(0, 0, 0, 0), "glow": Color(0, 0, 0, 0), "glow_size": 0.0, "glint": 0.0, "glint_speed": 0.0, "sheen": 0.0},
	2: {"name": "Merit", "border": 7.0, "radius": 6.0, "base": Color("#8E969F"), "hi": Color("#D3D9DF"), "lo": Color("#4F555D"),
		"inlay": Color(0, 0, 0, 0), "glow": Color(0, 0, 0, 0), "glow_size": 0.0, "glint": 0.18, "glint_speed": 0.07, "sheen": 0.0},
	3: {"name": "Distinction", "border": 8.0, "radius": 7.0, "base": Color("#B98A3E"), "hi": Color("#F0CE84"), "lo": Color("#6A4A1C"),
		"inlay": Color(0, 0, 0, 0), "glow": Color(0, 0, 0, 0), "glow_size": 0.0, "glint": 0.55, "glint_speed": 0.12, "sheen": 0.0},
	4: {"name": "Legend", "border": 10.0, "radius": 8.0, "base": Color("#101114"), "hi": Color("#2C2E35"), "lo": Color("#050506"),
		"inlay": Color("#D9B45A"), "glow": Color("#E6C266", 0.55), "glow_size": 9.0, "glint": 0.75, "glint_speed": 0.22, "sheen": 0.0},
	&"showcase_chrome": {"name": "Showcase", "border": 10.0, "radius": 10.0, "base": Color("#B9C3CE"), "hi": Color("#FFFFFF"), "lo": Color("#59626E"),
		"inlay": Color("#2A303A"), "glow": Color("#DDEBFF", 0.45), "glow_size": 10.0, "glint": 1.0, "glint_speed": 0.45, "sheen": 0.22},
	&"showcase_gold": {"name": "Showcase", "border": 10.0, "radius": 10.0, "base": Color("#D8B04E"), "hi": Color("#FFF0B8"), "lo": Color("#7A5418"),
		"inlay": Color("#3B2A0C"), "glow": Color("#FFD978", 0.45), "glow_size": 10.0, "glint": 1.0, "glint_speed": 0.45, "sheen": 0.22},
	&"locked": {"name": "Locked", "border": 6.0, "radius": 6.0, "base": Color("#2A2D34"), "hi": Color("#3A3E47"), "lo": Color("#16181D"),
		"inlay": Color(0, 0, 0, 0), "glow": Color(0, 0, 0, 0), "glow_size": 0.0, "glint": 0.0, "glint_speed": 0.0, "sheen": 0.0},
	&"back": {"name": "Hidden", "border": 6.0, "radius": 6.0, "base": Color("#30333B"), "hi": Color("#454954"), "lo": Color("#1A1C21"),
		"inlay": Color(0, 0, 0, 0), "glow": Color(0, 0, 0, 0), "glow_size": 0.0, "glint": 0.0, "glint_speed": 0.0, "sheen": 0.0},
}
## Owner lacquer ring just inside the frame (design units).
const LACQUER: float = 3.0

const FONT_BODY_PATH: String = "res://assets/fonts/Barlow-Medium.ttf"
const FONT_DISPLAY_PATH: String = "res://assets/fonts/BarlowCondensed-SemiBold.ttf"

static var _fonts: Dictionary = {}


static func side_color(side: StringName) -> Color:
	match side:
		&"player":
			return PLAYER
		&"rival":
			return RIVAL
	return NEUTRAL


static func set_palette(set_id: StringName) -> Dictionary:
	return SET_PALETTES.get(set_id, SET_PALETTES[&"showcase"])


static func set_name(set_id: StringName) -> String:
	return SET_NAMES.get(set_id, String(set_id).capitalize())


static func trait_name(trait_id: StringName) -> String:
	return TRAIT_NAMES.get(trait_id, String(trait_id).capitalize())


## Frame key for a card: Showcase frames for store cards, else its Clearance (1-4).
## frame_key may force one (&"showcase_chrome", &"showcase_gold", &"locked", &"back").
static func frame_key(clearance: int, set_id: StringName = &"", frame: StringName = &"") -> Variant:
	if FRAMES.has(frame):
		return frame
	if frame == &"showcase" or set_id == &"showcase":
		return &"showcase_chrome"
	return clampi(clearance, 1, 4)


static func frame_spec(clearance: int, frame: StringName = &"", set_id: StringName = &"") -> Dictionary:
	return FRAMES[frame_key(clearance, set_id, frame)]


## StyleBoxFlat for a frame at a card height (px). Transparent centre: the art shows through.
static func frame_box(spec: Dictionary, card_height: float = 128.0) -> StyleBoxFlat:
	var k: float = card_height / 128.0
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = spec["base"]
	sb.set_border_width_all(maxi(1, roundi(float(spec["border"]) * k)))
	sb.set_corner_radius_all(maxi(1, roundi(float(spec["radius"]) * k)))
	var glow: Color = spec["glow"]
	if glow.a > 0.0:
		sb.shadow_color = glow
		sb.shadow_size = maxi(1, roundi(float(spec["glow_size"]) * k))
	sb.anti_aliasing = true
	return sb


# --- Fonts ------------------------------------------------------------------------------------------
## Condensed display face: values, titles, card names. Explicit base_font so metrics don't depend on
## whichever theme is global (lesson from Killstreak build_themes.gd).
static func font_display() -> Font:
	if not _fonts.has("display"):
		var f := FontVariation.new()
		f.resource_name = "display_condensed"
		f.base_font = load(FONT_DISPLAY_PATH)
		f.fallbacks = [load(FONT_BODY_PATH)]
		_fonts["display"] = f
	return _fonts["display"]


## Heavier numerals for enamel pips (slight embolden keeps 1 and 7 solid at 24 px on a phone).
static func font_numeral() -> Font:
	if not _fonts.has("numeral"):
		var f := FontVariation.new()
		f.resource_name = "numeral"
		f.base_font = load(FONT_DISPLAY_PATH)
		f.variation_embolden = 0.35
		_fonts["numeral"] = f
	return _fonts["numeral"]


static func font_body() -> Font:
	if not _fonts.has("body"):
		var f := FontVariation.new()
		f.resource_name = "body"
		f.base_font = load(FONT_BODY_PATH)
		_fonts["body"] = f
	return _fonts["body"]
