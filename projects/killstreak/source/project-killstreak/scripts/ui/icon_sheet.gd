# icon_sheet.gd
# Purpose: Lookup for the single original placeholder icon sheet (res://assets/ui/icons/icon_sheet.svg).
#   Icons are white line art in 64 px cells, 8 columns, row-major. Tint them with modulate or
#   self_modulate. IconSheet.get_icon(&"kw_pick") returns a cached AtlasTexture.
# Dependencies: assets/ui/icons/icon_sheet.svg
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


## True when the sheet has an icon with this name.
static func has_icon(icon_name: StringName) -> bool:
	return NAMES.has(String(icon_name))


## Returns the icon as an AtlasTexture, or null for an unknown name.
static func get_icon(icon_name: StringName) -> AtlasTexture:
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
