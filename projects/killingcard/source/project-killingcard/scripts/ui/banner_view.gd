# banner_view.gd
# Purpose: Draws one 4:1 calling-card banner (board-and-cards-ux.md §3.2-3.3): the art's 4:1 band
#   (BannerArtDB) plus the icon slots in the left / right ~15% columns. kc-ui4: ONE layout for both
#   sides (the head: attack and health icons in the same place on my cards and the rival's):
#     kc-trait-ui (head): top-left cost + NAME, top-right abilities / keywords, bottom-left trait +
#     weapon-type pip, bottom-right FP + Armor number plates (Cover chip left). No art subname on
#     cards (the inspector has it). See anatomy().
#   The camo / level band runs along the top edge. Hand and codex cards are this same banner
#   (taller, with a cost hex in `lead`); see layout() / stat_rects().
#   Spine on the left edge (side colour + pattern), frontline outline (row 1), back rows at 74%,
#   PLAN tag (your queued card), Operator mastery frame (brass border, camo band on the OUTER
#   edge, dog-tag plate in the effect slot), INCOMING back (rival hidden play), landing ghost
#   (50%, dashed), target reticle, Elite gold keyline.
#   Sizes scale with the banner height (phone 44 px: 22 px badges, 16 px numbers, 18 px plates;
#   desktop 64 px: 28 / 20 / 22; inspector 128 px). Display only: input is handled by the column.
#   Focus / placement plays the banner_shimmer shader on the art (one animated banner at a time is
#   the caller's job: BannerView.focus_owner). kc-cod2: an animated licensed art (BannerArt.frames_path)
#   plays its frame sheet as a flipbook instead, also only while focused / placed; licensed art gets
#   the art doc's side-gradient safety net (15% each side, black ~35%) so the corner icons stay
#   readable on art that was not composed for our icon columns.
# Dependencies: BannerArtDB, IconSheet, hud_theme.tres colours (Hud: friend, enemy, elite, accent).
# Author: Mechanics Developer Agent (kc-board)
class_name BannerView
extends Control

enum Mode { EMPTY, UNIT, INCOMING, GHOST }

const SHIMMER: Shader = preload("res://assets/shaders/banner_shimmer.gdshader")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const CLASS_ICONS: Dictionary = {
	"SMG": &"class_smg", "SHOTGUN": &"class_shotgun", "AR": &"class_ar", "SNIPER": &"class_sniper",
	"LMG": &"class_lmg", "OPERATOR": &"type_operator",
}
const BACK_ROW_TINT: Color = Color(0.74, 0.74, 0.74, 1.0)
const BRASS: Color = Color("#C9A227")
const BRASS_DARK: Color = Color("#5A4512")
const STEEL: Color = Color("#3A444D")
const INK: Color = Color(0.05, 0.06, 0.07, 1.0)
const DAMAGED: Color = Color("#F2A33A")
## Camo tiers of the Operator's mastery band (pattern differs per tier, not only colour).
const CAMO: Dictionary = {
	&"base": [Color("#4B5A3A"), Color("#2F3A25"), Color("#7A8A5A")],
	&"gold": [Color("#C9A227"), Color("#7A5E12"), Color("#F3D36B")],
	# kc-cod2 weapon-mastery tiers 2-4 (tier 1 Gilded = the Base camo, head B3).
	&"forged": [Color("#D9DEE3"), Color("#8E979F"), Color("#FFFFFF")],
	&"priceless": [Color("#3E8EDE"), Color("#1B3F78"), Color("#9FE3FF")],
	&"interstellar": [Color("#7B3FC4"), Color("#1A0F3A"), Color("#FF7AD9")],
}
## Safety net behind the icon columns on licensed art: width share per side and peak opacity.
const SAFETY_W: float = 0.15
const SAFETY_A: float = 0.35

## The one banner animating right now (focus / placement), so a new focus stops the old one.
static var focus_owner: WeakRef = null

var mode: Mode = Mode.EMPTY
## &"player" / &"enemy": whose banner (decides the inner edge and badge shapes).
var side: StringName = &"player"
## Unit entry (match_snapshot.gd unit_entry): name, cls, fp, armor, armor_max, operator, keywords,
## bolt, banner, pending, elite, camo.
var entry: Dictionary = {}
var is_front: bool = false
var is_target: bool = false
## Back rows are drawn at 74% brightness (frontline at full brightness).
var dim_back: bool = true
## INCOMING: the revealed name behind the back (Recon / Callout), "" = unknown.
var revealed: String = ""
## kc-ui4: the card's name (the chassis) and, under it, the art's subname (licensed calling-card
## title or our variant name) drawn between the FP and Armor badges. Off for the inspector's big
## banner (its title says it).
var show_name: bool = true
## kc-ui4: px kept free at the top-left for a hand / codex card's cost hex (the plate row starts
## after it).
var lead: float = 0.0:
	set(value):
		lead = value
		if _overlay != null:
			_overlay.queue_redraw()
## kc-hand-dim (head: "dim down the image so that we can better read all icons and the card name"):
## a dark gradient behind the top name / ability row and the bottom trait / FP / Armor row, plus the
## art darkened by ART_DIM. On for hand / Codex / list cards and board banners; off for the
## inspector's big banner and the hover zoom (the art at full strength).
var readability: bool = false:
	set(value):
		readability = value
		if _art != null:
			_refresh()
## Overall darken of the art under `readability` (0.2 = 20% darker).
const ART_DIM: float = 0.22
## Peak opacity of the top / bottom scrims, and the share of the height each covers.
const SCRIM_TOP_A: float = 0.78
const SCRIM_BOTTOM_A: float = 0.82
const SCRIM_TOP_H: float = 0.52
const SCRIM_BOTTOM_H: float = 0.58
## kc-ui4: badge / plate sizes follow this height instead of the banner's own (hand cards are
## taller than 4:1 but keep the board's icon sizes). 0 = the banner's height.
var metric_h: float = 0.0
var _art: TextureRect
var _overlay: Control
var _shimmer_until: float = -1.0
var _pulse: float = 0.0
## The shown art (null for INCOMING / EMPTY) and its flipbook while focused.
var _banner_art: BannerArt = null
var _still: Texture2D = null
var _flip: AtlasTexture = null
var _flip_t0: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	for c: Control in [_art, _overlay]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_overlay.queue_redraw)


## Shows a unit (or a queued unit / the Operator). unit_side: &"player" / &"enemy".
func show_unit(unit: Dictionary, unit_side: StringName, front: bool) -> void:
	mode = Mode.UNIT
	entry = unit
	side = unit_side
	is_front = front
	revealed = ""
	_set_art(StringName(String(unit.get("banner", unit.get("art", "")))), unit)
	_refresh()


## A rival's hidden play in its landing slot (face-down banner back).
func show_incoming(revealed_name: String = "") -> void:
	mode = Mode.INCOMING
	entry = {}
	side = &"enemy"
	is_front = false
	revealed = revealed_name
	_clear_art()
	_refresh()


## Landing preview of the selected card: its full banner at 50%, dashed outline.
func show_ghost(unit: Dictionary, unit_side: StringName = &"player") -> void:
	mode = Mode.GHOST
	entry = unit
	side = unit_side
	is_front = false
	_set_art(StringName(String(unit.get("banner", ""))), unit)
	_refresh()


func show_empty() -> void:
	mode = Mode.EMPTY
	entry = {}
	is_front = false
	_clear_art()
	_refresh()


func _clear_art() -> void:
	_flip = null
	_banner_art = null
	_still = null
	_art.texture = null


func set_target(value: bool) -> void:
	if is_target != value:
		is_target = value
		_overlay.queue_redraw()


## Plays the shimmer (animated banner) for `seconds` (<= 0: until set_focus(false)).
func set_focus(on: bool, seconds: float = 0.0) -> void:
	if on:
		if focus_owner != null:
			var prev: BannerView = focus_owner.get_ref() as BannerView
			if prev != null and prev != self:
				prev.set_focus(false)
		focus_owner = weakref(self)
		if not _start_flipbook():
			var mat := ShaderMaterial.new()
			mat.shader = SHIMMER
			mat.set_shader_parameter(&"start_time", Time.get_ticks_msec() / 1000.0)
			_art.material = mat
		_shimmer_until = Time.get_ticks_msec() / 1000.0 + seconds if seconds > 0.0 else INF
		set_process(true)
	else:
		_art.material = null
		_stop_flipbook()
		_shimmer_until = -1.0
		set_process(mode == Mode.INCOMING)


func is_focused() -> bool:
	return _art.material != null or _flip != null


## True while an animated (frame sheet) art plays.
func is_flipbook_playing() -> bool:
	return _flip != null


## The BannerArt shown (null when none).
func get_banner_art() -> BannerArt:
	return _banner_art


func _start_flipbook() -> bool:
	if _banner_art == null or mode not in [Mode.UNIT, Mode.GHOST]:
		return false
	var sheet: Texture2D = BannerArtDB.frames_texture(_banner_art)
	if sheet == null:
		return false
	var cell_h: float = sheet.get_height() / float(_banner_art.frame_count)
	_flip = AtlasTexture.new()
	_flip.atlas = sheet
	_flip.filter_clip = true
	_flip.region = Rect2(0, 0, sheet.get_width(), cell_h)
	_flip_t0 = Time.get_ticks_msec() / 1000.0
	_art.texture = _flip
	return true


func _stop_flipbook() -> void:
	if _flip != null:
		_flip = null
		_art.texture = _still


func _step_flipbook() -> void:
	var n: int = _banner_art.frame_count
	var i: int = int((Time.get_ticks_msec() / 1000.0 - _flip_t0) * 1000.0 / float(_banner_art.frame_ms)) % n
	var cell_h: float = _flip.atlas.get_height() / float(n)
	var r: Rect2 = Rect2(0, i * cell_h, _flip.atlas.get_width(), cell_h)
	if r != _flip.region:
		_flip.region = r


func has_art() -> bool:
	return _art.texture != null


## Badge / number / plate sizes for a banner height h (v2 phone 57: 28/20/22, desktop 76: 34/24/26).
static func metrics(h: float) -> Dictionary:
	# kc-board2 (board-layout-v2.md §2.1): phone 57 px -> 28 / 20 / 22, desktop 76 px -> 34 / 24 / 26.
	var badge: float = roundf(h * 6.0 / 19.0 + 10.0)
	return {
		"badge": badge, "number": roundf(badge * 0.72), "plate": roundf(h * 4.0 / 19.0 + 10.0),
		"spine": 4.0 if h < 56.0 else 6.0, "pad": maxf(2.0, roundf(h * 0.04)),
	}


func _process(_delta: float) -> void:
	if _shimmer_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _shimmer_until:
		set_focus(false)
	elif _flip != null:
		_step_flipbook()
	if mode == Mode.INCOMING:
		_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
		_overlay.queue_redraw()


func _set_art(art_id: StringName, unit: Dictionary) -> void:
	var hint: Dictionary = {"cls": unit.get("cls", ""), "type": unit.get("type", "unit")}
	var prev: BannerArt = _banner_art
	var flip: AtlasTexture = _flip
	_flip = null
	_banner_art = BannerArtDB.get_art(art_id, hint) if art_id != &"" else null
	_still = BannerArtDB.banner_texture(art_id, hint) if art_id != &"" else null
	_art.texture = _still
	if flip != null:
		if prev == _banner_art:
			_flip = flip  # same art re-shown by a refresh: keep the loop running
			_art.texture = _flip
		elif not _start_flipbook():
			set_focus(false)
	# Rival figures face the other way (the art is mirrored, never recoloured).
	_art.flip_h = side == &"enemy"


func _refresh() -> void:
	var tint: Color = Color.WHITE
	if mode == Mode.UNIT and dim_back and not is_front:
		tint = BACK_ROW_TINT
	if mode == Mode.GHOST or bool(entry.get("pending", false)):
		tint.a = 0.55 if mode == Mode.GHOST else 0.85
	if readability:
		var k: float = 1.0 - ART_DIM
		tint = Color(tint.r * k, tint.g * k, tint.b * k, tint.a)
	_art.self_modulate = tint
	_art.visible = mode in [Mode.UNIT, Mode.GHOST]
	set_process(mode == Mode.INCOMING or _shimmer_until > 0.0)
	_overlay.queue_redraw()
	queue_redraw()


func _col(name: StringName) -> Color:
	return get_theme_color(name, &"Hud")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	match mode:
		Mode.EMPTY:
			return
		Mode.INCOMING:
			_draw_incoming_back(r)
		_:
			draw_rect(r, Color("#1C2228"))


func _draw_incoming_back(r: Rect2) -> void:
	draw_rect(r, Color("#2A1416"))
	var red: Color = _col(&"enemy")
	var step: float = maxf(10.0, size.y * 0.32)
	var x: float = -size.y
	while x < size.x:
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + step * 0.5, size.y),
				Vector2(x + step * 0.5 + size.y, 0), Vector2(x + size.y, 0)]), Color(red, 0.18))
		x += step


func _draw_overlay() -> void:
	var o: Control = _overlay
	var m: Dictionary = metrics(minf(size.y, metric_h) if metric_h > 0.0 else size.y)
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if mode == Mode.EMPTY:
		return
	var mine: bool = side == &"player"
	var side_c: Color = _col(&"friend") if mine else _col(&"enemy")
	if mode == Mode.INCOMING:
		_draw_incoming_text(o, r, m)
		o.draw_rect(r.grow(-1), Color(_col(&"enemy"), 0.9), false, 2.0)
		return
	var op: bool = bool(entry.get("operator", false))
	var pending: bool = bool(entry.get("pending", false))
	if _banner_art != null and _banner_art.licensed and has_art():
		_draw_safety_net(o)
	if readability and has_art() and mode in [Mode.UNIT, Mode.GHOST]:
		_draw_readability_scrim(o)
	# Spine: side colour + pattern (chevrons for you, hazard stripes for the rival).
	var spine: float = m["spine"]
	o.draw_rect(Rect2(0, 0, spine, size.y), side_c)
	var k: float = 0.0
	while k < size.y:
		if mine:
			o.draw_polyline(PackedVector2Array([Vector2(0, k + spine), Vector2(spine, k), Vector2(spine, k)]), INK, 1.0)
		else:
			o.draw_line(Vector2(0, k + spine), Vector2(spine, k), INK, 1.5)
		k += spine * 2.0
	# kc-ui4 (head: "attack and health icons at the same place for both my cards and opponent
	# cards"): ONE layout for every banner, both sides. Top edge: the Operator's camo / the copy
	# level's band, then the plate row (class, Elite, trait on the left; effects, keyword pip on the
	# right). Bottom row: Firepower bottom-left, Armor bottom-right, the name between them. Side
	# identity stays in the spine pattern, the badge shapes and the colours.
	var band_h: float = 6.0 if size.y < 100.0 else 10.0
	if op:
		_draw_camo(o, Rect2(spine, 0.0, size.x - spine, band_h), StringName(String(entry.get("camo", "base"))))
		var fr: Rect2 = r.grow(-1.5)
		o.draw_rect(fr.grow(1.0), INK, false, 1.0)
		o.draw_rect(fr, BRASS, false, 3.0)
	elif bool(entry.get("elite", false)):
		o.draw_rect(r.grow(-1.0), BRASS, false, 1.5)
	elif StandardIssueLook.is_si(entry):
		# kc-onboard-ui: the plain Standard Issue frame (no band, no foil, low contrast).
		StandardIssueLook.draw_frame(o, r, 0.85 if mode == Mode.GHOST else 1.0)
	# kc-syn-ui: the copy level's camo band (Trained Gilded, Veteran Forged, Elite Priceless; a
	# Recruit keeps the plain frame).
	var lvl_band: StringName = StringName(String(entry.get("band", "")))
	var lband_h: float = 0.0
	if not op and lvl_band != &"":
		lband_h = 4.0 if size.y < 100.0 else 8.0
		SynergyGlyphs.draw_band(o, Rect2(spine, 0.0, size.x - spine, lband_h), lvl_band)
	var an: Dictionary = anatomy(size, m, entry, lead if lead > 0.0 else -1.0)
	# Cost (top-left): drawn here on the board; hand / codex cards place a CostHex node in `lead`.
	if lead <= 0.0 and (an["cost"] as Rect2).size.x > 0.0:
		_draw_cost(o, an["cost"], str(entry.get("cost", "")))
	# Weapon-type pip (bottom-left, after the trait) and Elite star (top-left, after the cost).
	var cls: String = String(entry.get("cls", "")).to_upper()
	if an.has("class"):
		_draw_plate_icon(o, an["class"], IconSheet.get_icon(CLASS_ICONS[cls]), _col(&"text"))
	if an.has("elite"):
		var sr: Rect2 = an["elite"]
		o.draw_rect(sr, Color(INK, 0.82))
		draw_star(o, sr.get_center(), sr.size.x * 0.42, BRASS)
	# Trait (bottom-left): lit at tier 2, ring at 3. The Operator: its dog tag.
	if an.has("trait"):
		if op:
			_draw_dog_tag(o, an["trait"])
		elif String(entry.get("trait", "")) != "":
			var tier: int = int(entry.get("trait_tier", 0))
			SynergyGlyphs.draw_trait_plate(o, an["trait"], StringName(String(entry.get("trait", ""))), tier >= 2, tier >= 3)
		elif StandardIssueLook.is_si(entry):
			StandardIssueLook.draw_empty_socket(o, an["trait"])
	# kc-onboard-ui: the copy level badge (R / T / V / E) after the trait and class pips.
	if an.has("level"):
		StandardIssueLook.draw_level_badge(o, an["level"], int(entry.get("level", 0)), get_theme_font(&"font", &"HudNumber"))
	# Abilities (top-right).
	for ab: Array in an["abilities"]:
		var kind: Variant = ab[0]
		var rr: Rect2 = ab[1]
		if kind is Array and kind[0] == &"serial":
			StandardIssueLook.draw_serial_plate(o, rr, String(kind[1]), not mine)
		elif kind is Array and kind[0] == &"locked":
			StandardIssueLook.draw_locked_keyword(o, rr, String(kind[1]))
		elif kind is Array:
			SynergyGlyphs.draw_keyword_plate(o, rr, kind[1], bool(entry.get("kw_active", false)), side_c, mine)
		elif kind == &"protector":
			_draw_protector_glyph(o, rr)
		elif kind == &"pierce":
			SynergyGlyphs.draw_pierce_plate(o, rr, _col(&"accent"), not mine)
		elif kind == &"bolt" or kind == &"bolt_more":
			_draw_bolt(o, rr, kind == &"bolt_more")
		else:
			_draw_plate_icon(o, rr, IconSheet.get_icon(kind), _col(&"accent"))
	# FP and Armor (bottom-right), each a plate with its number inside; Cover chip left of them.
	if entry.has("fp"):
		var fp_rect: Rect2 = an["fp"]
		_draw_fp(o, fp_rect, int(entry.get("fp", 0)), mine, m)
		_draw_trend(o, fp_rect, int(entry.get("fp_trend", 0)), mine)
		var armor: int = int(entry.get("armor", 0))
		var damaged: bool = armor < int(entry.get("armor_max", armor))
		_draw_armor(o, an["armor"], armor, damaged, m)
		if an.has("cover"):
			_draw_cover_chip(o, an["cover"], int(entry.get("cover", 0)), int(entry.get("cover_trend", 0)), m)
	if show_name and mode in [Mode.UNIT, Mode.GHOST]:
		_draw_names(o, an)
	if pending:
		_draw_tag(o, "PLAN", _col(&"accent"), mine, m)
		_dashed_rect(o, r.grow(-1.0), _col(&"accent"), 2.0)
	elif is_front:
		o.draw_rect(r.grow(-1.0), side_c, false, 2.0)
	if mode == Mode.GHOST:
		_dashed_rect(o, r.grow(-1.0), _col(&"text"), 2.0)
	if is_target:
		_draw_reticle(o, r)


## kc-trait-ui card anatomy (the head, 2026-11-06; one layout for every card form and both sides;
## the right side is all the fast-read combat info):
##   top-left     cost (hex), the Elite star, then the card NAME (the chassis) next to it
##   top-right    abilities: Protector, up to 2 keyword glyphs or the effect bolt, the neighbor
##                keyword (right-aligned, the first one at the corner)
##   bottom-left  trait (the Operator: its dog tag), then the weapon-type (class) pip
##   bottom-right FP and Armor side by side, each a plate with its number inside (Cover chip left)
##   bottom-mid   only the kind word of a card without stats ("TACTIC" / "FIELD"); the art's
##                subname is NOT on cards any more (head): it is in the more-info view (inspector)
## Rects for a banner of `sz`. `entry` decides how many ability plates; `lead_px` > 0 = a cost hex
## owned by the caller (hand / codex cards); else the banner draws the cost itself when `entry` has one.
static func anatomy(sz: Vector2, m: Dictionary, e: Dictionary, lead_px: float = -1.0) -> Dictionary:
	var op: bool = bool(e.get("operator", false))
	var band: float = (6.0 if sz.y < 100.0 else 10.0) if op else ((4.0 if sz.y < 100.0 else 8.0) if String(e.get("band", "")) != "" else 0.0)
	var pad: float = m["pad"]
	var plate: float = m["plate"]
	var badge: float = m["badge"]
	var x0: float = m["spine"] + pad
	var top: float = pad + band
	var out: Dictionary = {"plate_y": top, "band": band}
	var has_cost: bool = str(e.get("cost", "")) != "" and not op
	var cost_w: float = lead_px if lead_px > 0.0 else (roundf(plate * 1.05) + 2.0 if has_cost else 0.0)
	out["cost"] = Rect2(x0, top, maxf(0.0, cost_w - 2.0), plate) if has_cost or lead_px > 0.0 else Rect2()
	var lx: float = x0 + cost_w
	if bool(e.get("elite", false)):
		out["elite"] = Rect2(lx, top, plate, plate)
		lx += plate + 2.0
	# Top-right: ability plates, right to left from the corner (the first one at the corner).
	var kinds: Array = ability_kinds(e)
	var kws: Array = []
	var kx: float = sz.x - pad - plate
	for k: Variant in kinds:
		# kc-onboard-ui: a Standard Issue card's serial plate is wider than a socket.
		var w: float = StandardIssueLook.serial_width(String(k[1]), plate) if k is Array and k[0] == &"serial" else plate
		kx += plate - w
		kws.append([k, Rect2(kx, top, w, plate)])
		kx -= plate + 2.0
	out["abilities"] = kws
	var name_end: float = kx + plate - 2.0 if not kinds.is_empty() else sz.x - pad
	out["name"] = Rect2(lx + 2.0, top, maxf(0.0, name_end - lx - 4.0), plate)
	# Bottom-right: Armor at the corner, FP left of it (each a plate with the number inside).
	var ar_h: float = badge * 1.08
	var armor: Rect2 = Rect2(sz.x - pad - badge, sz.y - pad - ar_h, badge, ar_h)
	var fp: Rect2 = Rect2(armor.position.x - 3.0 - badge, sz.y - pad - badge, badge, badge)
	out["armor"] = armor
	out["fp"] = fp
	var stat_x: float = fp.position.x if e.has("fp") else sz.x - pad
	if e.has("fp") and int(e.get("cover", 0)) > 0:
		var cs: float = roundf(badge * 0.78)
		out["cover"] = Rect2(fp.position.x - cs - 3.0, fp.position.y + (badge - cs) * 0.5, cs, cs)
		stat_x = (out["cover"] as Rect2).position.x
	# Bottom-left: trait (or the Operator's dog tag), then the weapon-type pip, centred on the stat row.
	var by: float = sz.y - pad - badge + (badge - plate) * 0.5 if e.has("fp") else sz.y - pad - plate
	var bx: float = x0
	if op or String(e.get("trait", "")) != "" or bool(e.get("reserve_trait", false)):
		out["trait"] = Rect2(bx, by, plate, plate)
		bx += plate + 2.0
	if CLASS_ICONS.has(String(e.get("cls", "")).to_upper()) and not op:
		out["class"] = Rect2(bx, by, plate, plate)
		bx += plate + 2.0
	# kc-onboard-ui: the copy level badge (Recruits always: the "Trains:" teaser; others once met).
	if bool(e.get("level_badge", false)) and not op and e.has("fp"):
		out["level"] = Rect2(bx, by, plate, plate)
		bx += plate + 2.0
	out["sub"] = Rect2(bx + 2.0, sz.y - pad - badge, maxf(0.0, stat_x - bx - 6.0), badge)
	out["mid"] = Rect2(x0, top + plate + 1.0, sz.x - x0 - pad, maxf(0.0, (sz.y - pad - badge) - (top + plate + 1.0)))
	return out


## The ability plates of an entry in order: [&"protector"?, keyword icon ids (max 2, 1 with a bolt),
## &"bolt"?, [&"kw", keyword]?]. The Operator shows its keywords too.
static func ability_kinds(e: Dictionary) -> Array:
	var icons: Array = []
	for kw: Dictionary in e.get("keywords", []):
		var id: StringName = StringName(kw.get("id", &""))
		var key: StringName = IconSheet.KEYWORD_ICONS.get(id, &"")
		if key != &"" and IconSheet.has_icon(key):
			icons.append(key)
		elif id == &"pierce":
			icons.append(&"pierce")  # kc-fight-ui: drawn glyph (no sheet icon)
	if bool(e.get("front_kw", false)):
		icons.push_front(&"protector")
	var bolt: bool = bool(e.get("bolt", false)) or icons.size() > 2
	var out: Array = icons.slice(0, 1 if bolt else 2)
	if bolt:
		out.append(&"bolt_more" if icons.size() > 2 else &"bolt")
	if String(e.get("kw", "")) != "":
		out.append([&"kw", StringName(String(e["kw"]))])
	# kc-onboard-ui: a Recruit's locked keywords (greyed, padlock; at most 2, the neighbor keyword
	# last), and a Standard Issue card's serial plate in the otherwise empty abilities slot.
	var locked: Array = e.get("locked", [])
	if not locked.is_empty():
		var shown: Array = locked.slice(0, 1) + [locked[-1]] if locked.size() > 2 else locked
		for name: Variant in shown:
			out.append([&"locked", String(name)])
	if String(e.get("serial", "")) != "":
		out.append([&"serial", String(e["serial"])])
	return out


## Kept for callers: the plate row's y / first x and the FP / Armor rects (anatomy()).
static func layout(sz: Vector2, m: Dictionary, op: bool = false, level_band: float = 0.0, lead_px: float = 0.0) -> Dictionary:
	var e: Dictionary = {"operator": op, "band": "x" if level_band > 0.0 else "", "fp": 0}
	var a: Dictionary = anatomy(sz, m, e, lead_px if lead_px > 0.0 else -1.0)
	return {"plate_y": a["plate_y"], "left_x": m["spine"] + m["pad"] + maxf(0.0, lead_px), "fp": a["fp"], "armor": a["armor"]}


## The FP and Armor badge rects of this banner as drawn now (tests, FX anchors).
func stat_rects() -> Dictionary:
	var a: Dictionary = anatomy(size, _metrics_now(), entry, lead if lead > 0.0 else -1.0)
	return {"fp": a["fp"], "armor": a["armor"]}


## Every slot of this banner as drawn now (tests: cost, class, trait, name, abilities, sub...).
func anatomy_now() -> Dictionary:
	return anatomy(size, _metrics_now(), entry, lead if lead > 0.0 else -1.0)


func _metrics_now() -> Dictionary:
	return metrics(minf(size.y, metric_h) if metric_h > 0.0 else size.y)


## Name sizes for a banner height (phone 57: 16 / 16; desktop 76: 18 / 16): 16 px is the phone's
## 11 pt floor, so the subname differs by colour and weight, not size.
static func name_sizes(h: float) -> Vector2i:
	return Vector2i(clampi(int(roundf(h * 0.24)), 16, 18), 16)


## kc-trait-ui (head): the card's name (always the chassis) top-left, next to the cost; shrinks to
## 13 px, then ends in "…". The art's subname is not drawn on cards (inspector only); a card without
## stats shows its kind word ("TACTIC" / "FIELD") bottom-centre.
func _draw_names(o: Control, a: Dictionary) -> void:
	var nm: String = String(entry.get("name", "")).replace("★", "").strip_edges().to_upper()
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var si: bool = StandardIssueLook.is_si(entry)
	var name_font: Font = StandardIssueLook.stencil() if si else font
	var fs: Vector2i = name_sizes(metric_h if metric_h > 0.0 else size.y)
	var nr: Rect2 = a["name"]
	if nm != "" and nr.size.x >= 16.0:
		var nfs: int = fs.x
		while nfs > 13 and name_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > nr.size.x:
			nfs -= 1
		nm = fit_text(nm, name_font, nfs, nr.size.x, "." if si else "…")
		var base: Vector2 = Vector2(nr.position.x, nr.position.y + (nr.size.y + name_font.get_ascent(nfs) - name_font.get_descent(nfs)) * 0.5)
		o.draw_string_outline(name_font, base, nm, HORIZONTAL_ALIGNMENT_LEFT, nr.size.x, nfs, 4, INK)
		o.draw_string(name_font, base, nm, HORIZONTAL_ALIGNMENT_LEFT, nr.size.x, nfs, StandardIssueLook.NAME if si else Color.WHITE)
	if entry.has("fp"):
		return
	var sub: String = String(entry.get("kind_word", ""))
	var sr: Rect2 = a["sub"]
	if sub == "" or sr.size.x < 24.0:
		return
	var sb: Vector2 = Vector2(sr.position.x, sr.position.y + (sr.size.y + font.get_ascent(fs.y) - font.get_descent(fs.y)) * 0.5)
	o.draw_string_outline(font, sb, sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs.y, 3, INK)
	o.draw_string(font, sb, sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs.y, Color("#B9C2C9"))


## `text` cut to `width` at font size `fs`, ending in "…" when cut.
static func fit_text(text: String, font: Font, fs: int, width: float, ellipsis: String = "…") -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	var t: String = text
	while t.length() > 1 and font.get_string_size(t + ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + ellipsis


## A cost hex (board banners; hand / codex cards place their own CostHex node).
func _draw_cost(o: Control, rr: Rect2, text: String) -> void:
	var c: Vector2 = rr.get_center()
	var rad: float = minf(rr.size.x, rr.size.y * 1.1) * 0.5
	var pts: PackedVector2Array = []
	for i: int in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	o.draw_colored_polygon(pts, _col(&"accent"))
	pts.append(pts[0])
	o.draw_polyline(pts, _col(&"accent").darkened(0.4), 1.5)
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var fs: int = maxi(12, int(rr.size.y * 0.7))
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	o.draw_string(font, Vector2(c.x - sz.x * 0.5, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


## Art doc safety net: a black gradient (SAFETY_A at the edge to 0) over each side's icon column.
func _draw_safety_net(o: Control) -> void:
	var w: float = size.x * SAFETY_W
	var a: float = SAFETY_A * (_art.self_modulate.a if mode == Mode.GHOST else 1.0)
	var edge: Color = Color(0, 0, 0, a)
	var clear: Color = Color(0, 0, 0, 0)
	o.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
			PackedColorArray([edge, clear, clear, edge]))
	o.draw_polygon(PackedVector2Array([Vector2(size.x - w, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - w, size.y)]),
			PackedColorArray([clear, edge, edge, clear]))


## kc-hand-dim: black gradients behind the top row (cost, name, abilities) and the bottom row (trait,
## weapon pip, FP / Armor plates), fading to clear toward the middle of the art.
func _draw_readability_scrim(o: Control) -> void:
	var a_mul: float = _art.self_modulate.a if mode == Mode.GHOST else 1.0
	var top_h: float = size.y * SCRIM_TOP_H
	var bot_h: float = size.y * SCRIM_BOTTOM_H
	var dark_t: Color = Color(0, 0, 0, SCRIM_TOP_A * a_mul)
	var dark_b: Color = Color(0, 0, 0, SCRIM_BOTTOM_A * a_mul)
	var clear: Color = Color(0, 0, 0, 0)
	# Solid behind the row itself (the first 45% of each band), then a fade to clear.
	var t_solid: float = top_h * 0.45
	var b_solid: float = size.y - bot_h * 0.45
	o.draw_rect(Rect2(0, 0, size.x, t_solid), dark_t)
	o.draw_polygon(PackedVector2Array([Vector2(0, t_solid), Vector2(size.x, t_solid), Vector2(size.x, top_h), Vector2(0, top_h)]),
			PackedColorArray([dark_t, dark_t, clear, clear]))
	o.draw_polygon(PackedVector2Array([Vector2(0, size.y - bot_h), Vector2(size.x, size.y - bot_h), Vector2(size.x, b_solid), Vector2(0, b_solid)]),
			PackedColorArray([clear, clear, dark_b, dark_b]))
	o.draw_rect(Rect2(0, b_solid, size.x, size.y - b_solid), dark_b)


## The art's colour multiplier now (tests: dimmed hand / board art, full-strength inspector).
func get_art_modulate() -> Color:
	return _art.self_modulate


func _draw_incoming_text(o: Control, r: Rect2, m: Dictionary) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = int(m["number"])
	var text: String = ("SPOTTED: " + revealed.to_upper()) if revealed != "" else "INCOMING"
	var dot_r: float = fs * 0.3
	var room: float = size.x - dot_r * 2.0 - 16.0
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room and revealed != "":
		text = revealed.to_upper()
	var w: float = minf(room, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var total: float = w + dot_r * 2.0 + 6.0
	var x: float = (size.x - total) * 0.5
	var cy: float = size.y * 0.5
	o.draw_circle(Vector2(x + dot_r, cy), dot_r * (0.8 + 0.3 * _pulse), Color(_col(&"enemy"), 0.6 + 0.4 * _pulse))
	o.draw_string(font, Vector2(x + dot_r * 2.0 + 6.0, cy + font.get_ascent(fs) * 0.5 - 1.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, room, fs, Color("#F1D9D9"))


func _draw_fp(o: Control, rr: Rect2, value: int, mine: bool, m: Dictionary) -> void:
	var c: Vector2 = rr.get_center()
	var rad: float = rr.size.x * 0.5
	if mine:
		o.draw_circle(c, rad, INK)
		o.draw_circle(c, rad - 1.5, Color("#14524D"))
		o.draw_arc(c, rad - 1.0, 0, TAU, 24, _col(&"friend"), 2.0)
	else:
		var pts: PackedVector2Array = [c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)]
		o.draw_colored_polygon(pts, Color("#5A1A1C"))
		pts.append(pts[0])
		o.draw_polyline(pts, _col(&"enemy"), 2.0)
	var trend: int = int(entry.get("fp_trend", 0))
	_draw_number(o, rr, str(value), SynergyGlyphs.UP if trend > 0 else (SynergyGlyphs.DOWN if trend < 0 else Color.WHITE), m)


## Buffed (green, up triangle) / lowered (red, down triangle) marker on a stat badge's outer corner.
func _draw_trend(o: Control, rr: Rect2, trend: int, mine: bool) -> void:
	if trend == 0:
		return
	var c: Color = SynergyGlyphs.UP if trend > 0 else SynergyGlyphs.DOWN
	var s: float = maxf(7.0, rr.size.x * 0.34)
	var base: Vector2 = Vector2(rr.end.x - s * 0.2, rr.position.y + s * 0.2)
	var pts: PackedVector2Array
	if trend > 0:
		pts = [base + Vector2(0, -s * 0.5), base + Vector2(s * 0.5, s * 0.4), base + Vector2(-s * 0.5, s * 0.4)]
	else:
		pts = [base + Vector2(0, s * 0.5), base + Vector2(s * 0.5, -s * 0.4), base + Vector2(-s * 0.5, -s * 0.4)]
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	o.draw_colored_polygon(pts, c)
	o.draw_polyline(outline, INK, 1.5)


func _draw_cover_chip(o: Control, rr: Rect2, value: int, trend: int, m: Dictionary) -> void:
	o.draw_rect(rr, Color(INK, 0.86))
	var c: Color = SynergyGlyphs.UP if trend > 0 else Color("#B9C2C9")
	o.draw_rect(rr, c, false, 1.5)
	var tex: Texture2D = IconSheet.get_icon(&"kw_cover") if IconSheet.has_icon(&"kw_cover") else null
	if tex != null:
		o.draw_texture_rect(tex, Rect2(rr.position + Vector2(1, 1), rr.size * 0.55), false, c)
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var fs: int = maxi(11, int(rr.size.y * 0.62))
	var txt: String = str(value)
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(rr.end.x - sz.x - 2.0, rr.end.y - font.get_descent(fs) - 1.0)
	o.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, INK)
	o.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _draw_armor(o: Control, rr: Rect2, value: int, damaged: bool, m: Dictionary) -> void:
	var w: float = rr.size.x
	var h: float = rr.size.y
	var p: Vector2 = rr.position
	var pts: PackedVector2Array = [p, p + Vector2(w, 0), p + Vector2(w, h * 0.55), p + Vector2(w * 0.5, h),
			p + Vector2(0, h * 0.55)]
	o.draw_colored_polygon(pts, Color("#2E3439") if not damaged else Color("#4A3412"))
	pts.append(pts[0])
	o.draw_polyline(pts, DAMAGED if damaged else Color("#B9C2C9"), 2.0)
	_draw_number(o, Rect2(p, Vector2(w, h * 0.9)), str(value), DAMAGED if damaged else Color.WHITE, m)


func _draw_number(o: Control, rr: Rect2, text: String, c: Color, m: Dictionary) -> void:
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var fs: int = int(m["number"])
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(rr.get_center().x - sz.x * 0.5, rr.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	o.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, INK)
	o.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _draw_plate_icon(o: Control, rr: Rect2, tex: Texture2D, tint: Color) -> void:
	o.draw_rect(rr, Color(INK, 0.82))
	o.draw_rect(rr, Color(1, 1, 1, 0.18), false, 1.0)
	if tex != null:
		o.draw_texture_rect(tex, rr.grow(-rr.size.x * 0.12), false, tint)


func _draw_bolt(o: Control, rr: Rect2, more: bool) -> void:
	o.draw_rect(rr, Color(INK, 0.82))
	o.draw_rect(rr, Color(1, 1, 1, 0.18), false, 1.0)
	var s: float = rr.size.x
	var p: Vector2 = rr.position
	var pts: PackedVector2Array = [p + Vector2(s * 0.58, s * 0.12), p + Vector2(s * 0.28, s * 0.55), p + Vector2(s * 0.48, s * 0.55),
			p + Vector2(s * 0.38, s * 0.88), p + Vector2(s * 0.72, s * 0.42), p + Vector2(s * 0.52, s * 0.42)]
	o.draw_colored_polygon(pts, _col(&"accent"))
	if more:
		o.draw_circle(p + Vector2(s * 0.85, s * 0.85), s * 0.1, _col(&"accent"))


## Protector: an up-chevron over a bar ("takes the front").
func _draw_protector_glyph(o: Control, rr: Rect2) -> void:
	o.draw_rect(rr, Color(INK, 0.82))
	o.draw_rect(rr, Color(1, 1, 1, 0.18), false, 1.0)
	var s: float = rr.size.x
	var p: Vector2 = rr.position
	var up: bool = side == &"player"
	var y0: float = s * (0.62 if up else 0.38)
	var y1: float = s * (0.3 if up else 0.7)
	o.draw_polyline(PackedVector2Array([p + Vector2(s * 0.22, y0), p + Vector2(s * 0.5, y1), p + Vector2(s * 0.78, y0)]), _col(&"accent"), 2.0)
	o.draw_line(p + Vector2(s * 0.22, s * (0.8 if up else 0.2)), p + Vector2(s * 0.78, s * (0.8 if up else 0.2)), _col(&"accent"), 2.0)


func _draw_dog_tag(o: Control, rr: Rect2) -> void:
	var tag: Rect2 = Rect2(rr.position + Vector2(rr.size.x * 0.12, 0), Vector2(rr.size.x * 0.76, rr.size.y))
	o.draw_rect(tag, Color("#1B1608"))
	o.draw_rect(tag, BRASS, false, 1.5)
	o.draw_circle(tag.position + Vector2(tag.size.x * 0.5, tag.size.y * 0.2), tag.size.x * 0.1, BRASS)
	for i: int in 3:
		var y: float = tag.position.y + tag.size.y * (0.45 + i * 0.16)
		o.draw_line(Vector2(tag.position.x + 3, y), Vector2(tag.end.x - 3, y), Color(BRASS, 0.8), 1.0)


func _draw_camo(o: Control, band: Rect2, tier: StringName) -> void:
	var cols: Array = CAMO.get(tier, CAMO[&"base"])
	o.draw_rect(band, cols[1])
	var cell: float = maxf(2.0, band.size.y / 2.0)
	var seed_v: int = 7
	var x: float = band.position.x
	while x < band.end.x:
		var y: float = band.position.y
		while y < band.end.y:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			var pick: int = seed_v % 5
			if pick < 2:
				o.draw_rect(Rect2(x, y, minf(cell, band.end.x - x), minf(cell, band.end.y - y)), cols[0])
			elif pick == 2:
				o.draw_rect(Rect2(x, y, minf(cell, band.end.x - x), minf(cell, band.end.y - y)), cols[2])
			y += cell
		x += cell


func _draw_tag(o: Control, text: String, c: Color, mine: bool, m: Dictionary) -> void:
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = maxi(11, int(m["number"]) - 4)
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var rr: Rect2 = Rect2(Vector2((size.x - sz.x) * 0.5 - 4.0, 0.0), Vector2(sz.x + 8.0, fs + 2.0))
	o.draw_rect(rr, c)
	o.draw_string(font, Vector2(rr.position.x + 4.0, rr.position.y + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _draw_reticle(o: Control, r: Rect2) -> void:
	var c: Color = _col(&"enemy") if side == &"enemy" else _col(&"friend")
	var rr: Rect2 = r.grow(-2.0)
	o.draw_rect(rr, c, false, 2.0)
	var l: float = minf(14.0, rr.size.y * 0.35)
	for corner: Vector2 in [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]:
		var sx: float = 1.0 if corner.x == rr.position.x else -1.0
		var sy: float = 1.0 if corner.y == rr.position.y else -1.0
		o.draw_polyline(PackedVector2Array([corner + Vector2(0, sy * l), corner, corner + Vector2(sx * l, 0)]), c, 4.0)
	var ctr: Vector2 = rr.get_center()
	var rad: float = rr.size.y * 0.28
	o.draw_arc(ctr, rad, 0, TAU, 28, c, 2.0)
	o.draw_line(ctr - Vector2(rad * 1.5, 0), ctr - Vector2(rad * 0.5, 0), c, 2.0)
	o.draw_line(ctr + Vector2(rad * 0.5, 0), ctr + Vector2(rad * 1.5, 0), c, 2.0)


## A filled 5-point star (Elite mark).
static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i: int in 10:
		var a: float = -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func _dashed_rect(o: Control, rr: Rect2, c: Color, w: float) -> void:
	var pts: Array[Vector2] = [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y), rr.position]
	for i: int in 4:
		o.draw_dashed_line(pts[i], pts[i + 1], c, w, 6.0)
