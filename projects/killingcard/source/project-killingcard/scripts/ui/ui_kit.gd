# ui_kit.gd
# Purpose: Lookup for the generated UI kit (documentation/art/ui-kit-prompt-pack.md §7.4).
#   UiKit.icon(&"stat_firepower") returns the kit pictogram (res://assets/ui/kit/icons/) when it
#   has been imported, else the old placeholder sheet icon (IconSheet) under its alias, else null,
#   so code-drawn glyphs stay the last fallback (UiKit.draw_icon returns false -> draw your own).
#   Kit icons are white with alpha; the code tints them (UiKit.tint). Each icon ships as a 256 px
#   master plus 128 / 64 / 48 / 32 exports: canvas items draw with plain linear filtering (no
#   mipmaps), so picking the export nearest the on-screen size keeps strokes clean at 22-32 px.
#   IconSheet.get_icon() asks UiKit first, so every caller of the old sheet picks up kit images
#   with no change of its own.
# Dependencies: icon_sheet.gd (IconSheet), assets/ui/kit/icons/ (optional: may be missing).
# Author: Technical Artist Agent (kc-ui-import)
class_name UiKit
extends RefCounted

const ICON_DIR: String = "res://assets/ui/kit/icons/"
const MASTER_PX: int = 256
## Export sizes in assets/ui/kit/icons/<px>/ (the master sits in the folder itself).
const EXPORT_PX: Array[int] = [32, 48, 64, 128]
## Export used when the caller doesn't say how big it draws (the old sheet's callers: 14-34 px
## logical, x1-1.6 on phones).
const DEFAULT_PX: int = 48

## Old sheet / code names -> kit ids (manifest notes: "keep the id alias").
const ALIASES: Dictionary = {
	&"intel_contact": &"stat_intel", &"supply": &"stat_supply", &"kw_cover": &"stat_cover",
	&"type_equipment": &"type_field", &"elite": &"elite_star", &"intel": &"stat_intel",
	&"deck": &"stat_deck", &"firepower": &"stat_firepower", &"armor": &"stat_armor",
	&"cover": &"stat_cover",
}
## Kit id -> the old sheet's name, for the fallback.
const SHEET_FALLBACK: Dictionary = {
	&"stat_intel": &"intel_contact", &"stat_supply": &"supply", &"stat_cover": &"kw_cover",
	&"type_field": &"type_equipment", &"elite_star": &"elite",
}
## strip_badge.gd glyph -> kit id (the code-drawn glyph stays the fallback).
const STRIP_GLYPHS: Dictionary = {
	&"streak": &"streak", &"cards": &"stat_deck", &"cards_rival": &"stat_intel", &"score": &"score",
}

## Colour tokens for tinting white kit pieces (ui-kit-prompt-pack.md §2.2 / §2.4).
const FOG: Color = Color("#D8DEE3")
const FRIEND: Color = Color("#2EC4B6")
const ENEMY: Color = Color("#E5383B")
const AMBER: Color = Color("#FFB020")
const IDLE: Color = Color("#7E8890")
const DAMAGED: Color = Color("#F2A33A")
const UP: Color = Color("#7CF29A")
const DOWN: Color = Color("#FF6B6B")

## False = behave as if the kit folder were empty (tests, A/B checks).
static var enabled: bool = true
## Tests point this at a missing folder to prove every fallback still works.
static var icon_dir: String = ICON_DIR
static var _tex: Dictionary = {}    # "id@px" -> Texture2D or null (null = not in the kit)
static var _atlas: Dictionary = {}  # "id@px" -> AtlasTexture wrapping the kit texture


## Kit id for a name (resolves aliases such as &"intel_contact" -> &"stat_intel").
static func kit_id(icon_name: StringName) -> StringName:
	return ALIASES.get(icon_name, icon_name)


## Export size to load for an icon drawn `px` physical pixels wide: the smallest one >= px.
static func export_px(px: float) -> int:
	for s: int in EXPORT_PX:
		if px <= s:
			return s
	return MASTER_PX


static func path_for(icon_name: StringName, px: int = DEFAULT_PX) -> String:
	var file: String = "ico_%s.png" % kit_id(icon_name)
	return icon_dir.path_join(file) if px >= MASTER_PX else icon_dir.path_join(str(px)).path_join(file)


## True when the kit has an imported image for this name (or its alias).
static func has_kit(icon_name: StringName) -> bool:
	return kit_texture(icon_name) != null


## The kit image (white + alpha) at the export nearest px, or null when the kit lacks it.
static func kit_texture(icon_name: StringName, px: float = DEFAULT_PX) -> Texture2D:
	if not enabled or icon_name == &"":
		return null
	var size: int = export_px(px)
	var cache_key: String = "%s@%d" % [kit_id(icon_name), size]
	if _tex.has(cache_key):
		return _tex[cache_key]
	var tex: Texture2D = null
	var path: String = path_for(icon_name, size)
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex[cache_key] = tex
	return tex


## Kit image as an AtlasTexture (full region), for IconSheet callers typed to AtlasTexture.
static func kit_atlas(icon_name: StringName, px: float = DEFAULT_PX) -> AtlasTexture:
	var tex: Texture2D = kit_texture(icon_name, px)
	if tex == null:
		return null
	var cache_key: String = "%s@%d" % [kit_id(icon_name), export_px(px)]
	var a: AtlasTexture = _atlas.get(cache_key, null)
	if a == null or a.atlas != tex:
		a = AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(Vector2.ZERO, tex.get_size())
		_atlas[cache_key] = a
	return a


## Any icon for this name: the kit image, else the old sheet icon (by alias), else null.
static func icon(icon_name: StringName, px: float = DEFAULT_PX) -> Texture2D:
	var tex: Texture2D = kit_texture(icon_name, px)
	if tex != null:
		return tex
	var sheet_name: StringName = SHEET_FALLBACK.get(kit_id(icon_name), icon_name)
	if IconSheet.NAMES.has(String(sheet_name)):
		return IconSheet.get_sheet_icon(sheet_name)
	if IconSheet.NAMES.has(String(icon_name)):
		return IconSheet.get_sheet_icon(icon_name)
	return null


## True when icon() returns something (kit or sheet).
static func has(icon_name: StringName) -> bool:
	return icon(icon_name) != null


## Draws the kit image for `icon_name` into rect on `ci`, tinted; picks the export from the real
## on-screen size. Returns false (and draws nothing) when the kit lacks it, so the caller keeps
## its code-drawn glyph.
static func draw_icon(ci: CanvasItem, icon_name: StringName, rect: Rect2, tint_color: Color = Color.WHITE) -> bool:
	if ci == null or icon_name == &"":
		return false
	var scale: float = ci.get_global_transform_with_canvas().get_scale().x
	if ci.is_inside_tree():
		scale *= ci.get_viewport().get_final_transform().get_scale().x
	var tex: Texture2D = kit_texture(icon_name, rect.size.x * absf(scale))
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false, tint_color)
	return true


## Tint for a white kit piece: side (&"player" / &"rival" / &"" neutral) and state
## (&"normal", &"lit", &"idle", &"ready", &"damaged", &"up", &"down", &"disabled").
static func tint(side: StringName = &"", state: StringName = &"normal") -> Color:
	match state:
		&"idle":
			return IDLE
		&"ready":
			return AMBER
		&"damaged":
			return DAMAGED
		&"up":
			return UP
		&"down":
			return DOWN
		&"disabled":
			return Color(Color("#8C8C8C"), 0.6)
	var base: Color = FRIEND if side == &"player" else ENEMY if side == &"rival" else FOG
	return base.lightened(0.25) if state == &"lit" else base


## Drops cached lookups (after toggling `enabled` / `icon_dir`, or importing new kit files).
static func clear_cache() -> void:
	_tex.clear()
	_atlas.clear()
