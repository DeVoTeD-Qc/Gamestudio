# kit_theme.gd
# Purpose: kc-ui-wire2. Turns the UI kit's button and panel plates (assets/ui/kit/buttons/, panels/)
#   into StyleBoxTextures (pack §7.4 step 2) and puts them into the project theme (hud_theme.tres)
#   at startup, or onto single nodes (READY, danger buttons, the pause sheet...). The theme file itself
#   is never changed: without a kit file each slot keeps its StyleBoxFlat (the current code look).
#   The kit ships its plates at 2x; KitTheme downscales each one once (Lanczos) to the drawn scale and
#   uses the manifest's 9-slice margins (ui-kit-manifest.csv nine_slice_margins_ltrb) at that scale, so
#   a 40 px ship margin is a 16-20 px rim. Content margins are copied from the StyleBoxFlat each one
#   replaces, so no layout moves.
#   Pressed state: the kit's pressed plates were rejected (batch 2), so pressed = the same plate darker
#   (x0.8, pack §2.6). A toggled-on HudButton (Codex filters, settings rows) keeps the amber-rimmed
#   flat style: the switch from steel to amber is what tells the player "on" at phone size.
# Usage: KitTheme.apply(ThemeDB.get_project_theme())   # Settings._ready (once)
#        KitTheme.style_button(ready_button, &"btn_ready")
#        KitTheme.style_panel(box, &"pnl_modal")
# Dependencies: ui_kit.gd (UiKit.piece)
# Author: UI/UX Agent (kc-ui-wire2)
class_name KitTheme
extends RefCounted

## 9-slice margins (L, T, R, B) at ship size, from ui-kit-manifest.csv.
const MARGINS: Dictionary = {
	&"btn_primary": Vector4(40, 40, 40, 48), &"btn_secondary": Vector4(40, 40, 40, 48),
	&"btn_danger": Vector4(40, 40, 40, 48), &"btn_ready": Vector4(48, 40, 128, 48),
	&"btn_badge": Vector4(24, 24, 24, 24), &"btn_chip": Vector4(24, 20, 24, 20),
	&"btn_chip_on": Vector4(24, 20, 24, 20), &"btn_tab": Vector4(28, 24, 28, 8),
	&"tgl_track": Vector4(30, 30, 30, 30), &"sld_track": Vector4(14, 14, 14, 14),
	&"pnl_tray": Vector4(32, 32, 32, 32), &"pnl_flyout": Vector4(32, 32, 32, 32),
	&"pnl_toast": Vector4(40, 16, 24, 16), &"pnl_inspector": Vector4(40, 40, 40, 40),
	&"pnl_tooltip": Vector4(16, 16, 16, 16), &"pnl_modal": Vector4(48, 48, 48, 48),
	&"pnl_header": Vector4(40, 16, 40, 16), &"pnl_counter": Vector4(16, 16, 16, 16),
	&"pnl_order_strip": Vector4(24, 12, 24, 12), &"pnl_rail_chip": Vector4(20, 20, 20, 20),
	&"pnl_callout": Vector4(32, 12, 32, 12), &"pnl_pick_tile": Vector4(32, 32, 32, 80),
	&"pnl_coach": Vector4(64, 32, 32, 48), &"pnl_result": Vector4(160, 48, 160, 48),
}
## Drawn scale of a plate's rims. Buttons draw at 0.4 (a 40 px ship rim = 16 px) so a 46 pt phone
## button keeps most of its height for the label; panels at 0.5 (§7.4 step 3).
const BUTTON_SCALE: float = 0.4
const PANEL_SCALE: float = 0.5
const HOVER: Color = Color(1.12, 1.12, 1.12, 1.0)
const PRESSED: Color = Color(0.8, 0.8, 0.8, 1.0)
const DISABLED: Color = Color(0.62, 0.62, 0.62, 0.7)

## Theme variation -> {style name: [piece id, modulate]} applied by apply(). Only these slots change.
const THEME_SLOTS: Dictionary = {
	&"HudButton": {&"normal": [&"btn_secondary", Color.WHITE], &"hover": [&"btn_secondary", HOVER],
			&"disabled": [&"btn_secondary", DISABLED]},
	&"ReadyButton": {&"normal": [&"btn_primary", Color.WHITE], &"hover": [&"btn_primary", HOVER],
			&"pressed": [&"btn_primary", PRESSED], &"hover_pressed": [&"btn_primary", PRESSED]},
	&"HudPanelDark": {&"panel": [&"pnl_inspector", Color.WHITE]},
	&"TooltipPanel": {&"panel": [&"pnl_tooltip", Color.WHITE]},
}

## True once apply() has changed the project theme (tests).
static var applied: int = 0
static var _tex: Dictionary = {}  # "id@scale" -> Texture2D or null
static var _originals: Dictionary = {}  # theme instance id -> {"type/name": StyleBox replaced by apply()}


## The scale a piece draws at (buttons 0.4, everything else 0.5).
static func scale_for(id: StringName) -> float:
	var s: String = String(id)
	return BUTTON_SCALE if s.begins_with("btn_") or s.begins_with("tgl_") or s.begins_with("sld_") else PANEL_SCALE


## The kit plate downscaled to `scale` (one Lanczos resize, cached), or null without the kit file.
static func scaled(id: StringName, scale: float = -1.0) -> Texture2D:
	var k: float = scale_for(id) if scale <= 0.0 else scale
	var key: String = "%s@%.3f" % [id, k]
	if _tex.has(key):
		return _tex[key]
	var out: Texture2D = null
	var src: Texture2D = UiKit.piece(id)
	if src != null:
		var img: Image = src.get_image()
		if img != null and not img.is_empty():
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(img)
	_tex[key] = out
	return out


## A StyleBoxTexture of the plate `id`: margins from MARGINS at the drawn scale, content margins
## copied from `like` (the style it replaces), modulated. Null without the kit file.
static func stylebox(id: StringName, like: StyleBox = null, modulate: Color = Color.WHITE, scale: float = -1.0) -> StyleBoxTexture:
	var k: float = scale_for(id) if scale <= 0.0 else scale
	var tex: Texture2D = scaled(id, k)
	if tex == null:
		return null
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = tex
	var m: Vector4 = MARGINS.get(id, Vector4.ZERO) * k
	sb.texture_margin_left = roundf(m.x)
	sb.texture_margin_top = roundf(m.y)
	sb.texture_margin_right = roundf(m.z)
	sb.texture_margin_bottom = roundf(m.w)
	if like != null:
		sb.content_margin_left = like.get_margin(SIDE_LEFT)
		sb.content_margin_top = like.get_margin(SIDE_TOP)
		sb.content_margin_right = like.get_margin(SIDE_RIGHT)
		sb.content_margin_bottom = like.get_margin(SIDE_BOTTOM)
	sb.modulate_color = modulate
	sb.set_meta(&"kit_piece", id)
	return sb


## Puts the kit plates into `theme` (THEME_SLOTS) where the kit has them; the rest keep their
## StyleBoxFlat. Returns how many styles changed. Safe to call twice.
static func apply(theme: Theme) -> int:
	if theme == null:
		return 0
	var n: int = 0
	var orig: Dictionary = _originals.get(theme.get_instance_id(), {})
	_originals[theme.get_instance_id()] = orig
	for type: StringName in THEME_SLOTS:
		var slots: Dictionary = THEME_SLOTS[type]
		for style: StringName in slots:
			var key: String = "%s/%s" % [type, style]
			var old: StyleBox = orig.get(key, theme.get_stylebox(style, type) if theme.has_stylebox(style, type) else null)
			var sb: StyleBoxTexture = stylebox(slots[style][0], old, slots[style][1])
			if sb == null:
				continue
			if not orig.has(key):
				orig[key] = old
			theme.set_stylebox(style, type, sb)
			n += 1
	# Slider: the kit track and the knob (24 px).
	var track: StyleBoxTexture = stylebox(&"sld_track", theme.get_stylebox(&"slider", &"HSlider") if theme.has_stylebox(&"slider", &"HSlider") else null)
	var knob: Texture2D = scaled(&"tgl_knob", 0.375)
	if track != null and knob != null:
		for pair: Array in [[&"slider", track]]:
			var key2: String = "HSlider/%s" % pair[0]
			if not orig.has(key2):
				orig[key2] = theme.get_stylebox(pair[0], &"HSlider") if theme.has_stylebox(pair[0], &"HSlider") else null
			theme.set_stylebox(pair[0], &"HSlider", pair[1])
		theme.set_icon(&"grabber", &"HSlider", knob)
		theme.set_icon(&"grabber_highlight", &"HSlider", knob)
		n += 1
	applied = n
	return n


## Puts back every StyleBoxFlat apply() replaced (tests, A/B).
static func restore(theme: Theme) -> void:
	if theme == null:
		return
	var orig: Dictionary = _originals.get(theme.get_instance_id(), {})
	for key: String in orig:
		var parts: PackedStringArray = key.split("/")
		var old: StyleBox = orig[key]
		if old != null:
			theme.set_stylebox(StringName(parts[1]), StringName(parts[0]), old)
		else:
			theme.clear_stylebox(StringName(parts[1]), StringName(parts[0]))
	if theme.has_icon(&"grabber", &"HSlider") and orig.has("HSlider/slider"):
		theme.clear_icon(&"grabber", &"HSlider")
		theme.clear_icon(&"grabber_highlight", &"HSlider")
	_originals.erase(theme.get_instance_id())
	applied = 0


## A momentary button drawn on the kit plate `id` (normal, hover, pressed darker, disabled greyed),
## as overrides on that node; content margins from its current styles. False without the kit file.
static func style_button(b: Button, id: StringName, keep_disabled: bool = false) -> bool:
	if b == null or UiKit.piece(id) == null:
		return false
	var states: Dictionary = {&"normal": Color.WHITE, &"hover": HOVER, &"pressed": PRESSED, &"hover_pressed": PRESSED}
	if not keep_disabled:
		states[&"disabled"] = DISABLED
	for st: StringName in states:
		var sb: StyleBoxTexture = stylebox(id, b.get_theme_stylebox(st), states[st])
		if sb != null:
			b.add_theme_stylebox_override(st, sb)
	return true


## A panel (PanelContainer / Panel) drawn on the kit plate `id`; content margins kept. False
## without the kit file.
static func style_panel(c: Control, id: StringName, scale: float = -1.0) -> bool:
	if c == null:
		return false
	var sb: StyleBoxTexture = stylebox(id, c.get_theme_stylebox(&"panel"), Color.WHITE, scale)
	if sb == null:
		return false
	c.add_theme_stylebox_override(&"panel", sb)
	return true


## Drops the cached plates (after UiKit.enabled / piece_dirs change).
static func clear_cache() -> void:
	_tex.clear()
