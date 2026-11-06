# icon_sheet.gd
# Purpose: Lookup for the single original placeholder icon sheet (res://assets/ui/icons/icon_sheet.svg).
#   Icons are white line art in 64 px cells, 8 columns, row-major. Tint them with modulate or
#   self_modulate. IconSheet.get_icon(&"kw_pick") returns a cached AtlasTexture.
#   kc-ui-import: get_icon() / has_icon() ask UiKit first, so a generated kit pictogram
#   (assets/ui/kit/icons/) replaces the sheet cell wherever the game already draws it; the sheet
#   (get_sheet_icon) is the fallback when the kit lacks an id.
# Dependencies: assets/ui/icons/icon_sheet.svg, ui_kit.gd (UiKit)
# Author: Technical Artist Agent (p13)
class_name IconSheet
extends RefCounted

const SHEET_PATH: String = "res://assets/ui/icons/icon_sheet.svg"
const CELL: int = 64
const COLUMNS: int = 8

## Icon names in sheet order. Keep in sync with the SVG (each <g id> matches a name here).
const NAMES: PackedStringArray = [
	"range_close", "range_mid", "range_long",
	"type_unit", "type_tactic", "type_equipment", "type_killstreak", "type_operator",
	"class_smg", "class_shotgun", "class_ar", "class_sniper", "class_lmg",
	"kw_first_shot", "kw_pick", "kw_flank", "kw_cover", "kw_suppress", "kw_patch", "kw_holder",
	"trig_on_deploy", "trig_on_down",
	"stat_firepower", "stat_armor", "streak", "supply",
	"ks_recon_drone", "ks_mortar", "ks_sentry", "ks_attack_helo", "ks_gunship",
	"intel_contact", "elite", "eliminated",
]

## Keyword id (as written in card data) -> icon name.
const KEYWORD_ICONS: Dictionary = {
	&"first_shot": &"kw_first_shot", &"pick": &"kw_pick", &"flank": &"kw_flank",
	&"cover": &"kw_cover", &"suppress": &"kw_suppress", &"patch": &"kw_patch",
	&"holder": &"kw_holder", &"on_deploy": &"trig_on_deploy", &"on_down": &"trig_on_down",
}

static var _cache: Dictionary = {}
static var _sheet: Texture2D = null


## True when the sheet (or the UI kit) has an icon with this name.
static func has_icon(icon_name: StringName) -> bool:
	return NAMES.has(String(icon_name)) or UiKit.has_kit(icon_name)


## Returns the icon as an AtlasTexture (the UI kit image when imported, else the sheet cell),
## or null for an unknown name.
static func get_icon(icon_name: StringName) -> AtlasTexture:
	if icon_name == &"kw_pick":
		# kc-cards-impl: Pick is no longer a crosshair (the FP reticle is one): a shield with a down
		# arrow ("shoots the lowest Armor"). A UI kit piece kw_pick_v2 wins; else the built-in glyph.
		var v2: AtlasTexture = UiKit.kit_atlas(PICK_KIT_ID)
		return v2 if v2 != null else pick_glyph()
	var kit: AtlasTexture = UiKit.kit_atlas(icon_name)
	if kit != null:
		return kit
	return get_sheet_icon(icon_name)


## The UI kit id of the new Pick icon (assets/ui/kit/icons/ico_kw_pick_v2.png when the artist ships it).
const PICK_KIT_ID: StringName = &"kw_pick_v2"
## The built-in Pick glyph's SVG (64 px, white; tint it): the same shape as CardLook.draw_pick_icon.
const PICK_SVG: String = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path d="M32 6.4L54.4 14V32L46 48L32 58.9L18 48L9.6 32V14Z"/><path d="M32 20.5V43.5"/><path d="M23 35.2L32 44L41 35.2"/></svg>"""
static var _pick: AtlasTexture = null


## The new Pick icon (built-in, cached).
static func pick_glyph() -> AtlasTexture:
	if _pick == null:
		var img := Image.new()
		img.load_svg_from_string(PICK_SVG, 1.0)
		var at := AtlasTexture.new()
		at.atlas = ImageTexture.create_from_image(img)
		at.region = Rect2(0, 0, img.get_width(), img.get_height())
		_pick = at
	return _pick


## The placeholder sheet cell only (UiKit's fallback), or null for an unknown name.
static func get_sheet_icon(icon_name: StringName) -> AtlasTexture:
	if _cache.has(icon_name):
		return _cache[icon_name]
	var index: int = NAMES.find(String(icon_name))
	if index < 0:
		push_warning("IconSheet: unknown icon '%s'" % icon_name)
		return null
	if _sheet == null:
		_sheet = load(SHEET_PATH) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	@warning_ignore("integer_division")
	var row: int = index / COLUMNS
	atlas.region = Rect2((index % COLUMNS) * CELL, row * CELL, CELL, CELL)
	_cache[icon_name] = atlas
	return atlas


## Icon for a card keyword id such as &"first_shot" or &"cover". Null when the keyword is unknown.
static func get_keyword_icon(keyword: StringName) -> AtlasTexture:
	var icon_name: StringName = KEYWORD_ICONS.get(keyword, &"")
	return get_icon(icon_name) if icon_name != &"" else null
