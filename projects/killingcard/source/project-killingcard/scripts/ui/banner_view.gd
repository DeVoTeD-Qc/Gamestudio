# banner_view.gd
# Purpose: Draws one 4:1 calling-card banner (board-and-cards-ux.md §3.2-3.3): the art's 4:1 band
#   (BannerArtDB) plus the icon slots in the left / right ~15% columns. Your banner has its numbers
#   on the INNER edge (top: the objective is above it); a rival banner is mirrored top to bottom.
#     inner-left  Firepower in this column (teal circle = yours, red diamond = rival)
#     inner-right Armor (grey shield; amber when damaged)
#     outer-left  weapon-class pip      outer-right  effect: up to 2 keyword glyphs, or a bolt
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


## Badge / number / plate sizes for a banner height h (phone 44: 22/16/18, desktop 64: 28/20/22).
static func metrics(h: float) -> Dictionary:
	var badge: float = roundf(0.3 * h + 8.8)
	return {
		"badge": badge, "number": roundf(badge * 0.72), "plate": roundf(0.2 * h + 9.2),
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
	var m: Dictionary = metrics(size.y)
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
	# Operator: camo band on the OUTER edge (bottom for you, top for the rival) + brass frame.
	var band_h: float = 6.0 if size.y < 100.0 else 10.0
	if op:
		var band: Rect2 = Rect2(spine, size.y - band_h if mine else 0.0, size.x - spine, band_h)
		_draw_camo(o, band, StringName(String(entry.get("camo", "base"))))
		var fr: Rect2 = r.grow(-1.5)
		o.draw_rect(fr.grow(1.0), INK, false, 1.0)
		o.draw_rect(fr, BRASS, false, 3.0)
	elif bool(entry.get("elite", false)):
		o.draw_rect(r.grow(-1.0), BRASS, false, 1.5)
	var inner_y: float = m["pad"] if mine else size.y - m["pad"] - m["badge"]
	var outer_y: float = size.y - m["pad"] - m["plate"] - (band_h if op and mine else 0.0) if mine \
			else m["pad"] + (band_h if op else 0.0)
	var left_x: float = spine + m["pad"]
	if entry.has("fp"):
		# Firepower (inner-left): teal circle (yours) / red notched diamond (rival).
		_draw_fp(o, Rect2(left_x, inner_y, m["badge"], m["badge"]), int(entry.get("fp", 0)), mine, m)
		# Armor (inner-right): grey shield, amber when damaged.
		var armor: int = int(entry.get("armor", 0))
		var damaged: bool = armor < int(entry.get("armor_max", armor))
		_draw_armor(o, Rect2(size.x - m["pad"] - m["badge"], inner_y, m["badge"], m["badge"] * 1.08), armor, damaged, m)
	# Class pip (outer-left).
	var cls: String = String(entry.get("cls", "")).to_upper()
	if CLASS_ICONS.has(cls) and not op:
		_draw_plate_icon(o, Rect2(left_x, outer_y, m["plate"], m["plate"]), IconSheet.get_icon(CLASS_ICONS[cls]), _col(&"text"))
	if bool(entry.get("elite", false)):
		# Elite (Commander / Ace): a gold star plate next to the class pip (the fonts have no star glyph).
		var sr: Rect2 = Rect2(left_x + m["plate"] + 2.0, outer_y, m["plate"], m["plate"])
		o.draw_rect(sr, Color(INK, 0.82))
		draw_star(o, sr.get_center(), sr.size.x * 0.42, BRASS)
	# Effect (outer-right): Operator dog tag, else up to 2 keyword glyphs, else a bolt.
	var ex: float = size.x - m["pad"] - m["plate"]
	if op:
		_draw_dog_tag(o, Rect2(ex, outer_y, m["plate"], m["plate"]))
	else:
		var icons: Array = []
		for kw: Dictionary in entry.get("keywords", []):
			var key: StringName = IconSheet.KEYWORD_ICONS.get(StringName(kw.get("id", &"")), &"")
			if key != &"" and IconSheet.has_icon(key):
				icons.append(key)
		if bool(entry.get("front_kw", false)):
			icons.push_front(&"protector")
		var bolt: bool = bool(entry.get("bolt", false)) or icons.size() > 2
		var shown: int = 0
		for key: StringName in icons:
			if shown >= (1 if bolt else 2):
				break
			var rr: Rect2 = Rect2(ex - shown * (m["plate"] + 2.0), outer_y, m["plate"], m["plate"])
			if key == &"protector":
				_draw_protector_glyph(o, rr)
			else:
				_draw_plate_icon(o, rr, IconSheet.get_icon(key), _col(&"accent"))
			shown += 1
		if bolt:
			_draw_bolt(o, Rect2(ex - shown * (m["plate"] + 2.0), outer_y, m["plate"], m["plate"]), icons.size() > 2)
	if pending:
		_draw_tag(o, "PLAN", _col(&"accent"), mine, m)
		_dashed_rect(o, r.grow(-1.0), _col(&"accent"), 2.0)
	elif is_front:
		o.draw_rect(r.grow(-1.0), side_c, false, 2.0)
	if mode == Mode.GHOST:
		_dashed_rect(o, r.grow(-1.0), _col(&"text"), 2.0)
	if is_target:
		_draw_reticle(o, r)


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
	_draw_number(o, rr, str(value), Color.WHITE, m)


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
	var rr: Rect2 = Rect2(Vector2((size.x - sz.x) * 0.5 - 4.0, 0.0 if mine else size.y - fs - 2.0), Vector2(sz.x + 8.0, fs + 2.0))
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
