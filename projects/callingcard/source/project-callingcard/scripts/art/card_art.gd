# card_art.gd
# Purpose: CardArt Control (cc14). Draws ORIGINAL procedural duotone poster art for a calling card in
#   the set's palette (art-direction.md sections 1, 4, 7): a gradient field, 2-4 bold flat shapes from
#   the card's art brief (banner-wall-spec.md section 6) and seeded variation, plus the card's cipher
#   glyph when it carries one. Also draws the three Triptych panorama strips (spec 5.1).
#   Everything is vector drawing in a 512 x 128 design space (1536 x 128 for panoramas) scaled to the
#   control's size, so the same art is crisp at 256x64 on the board and 1024x256 in the album.
#   Film grain comes from assets/shaders/card_grain.gdshader (set as material in BannerCard.tscn, or
#   call CardArt.grain_material()).
# Usage:
#   var art := CardArt.new(); art.configure({"id": &"neon_rain", "set": &"night_shift", "art_seed": 7})
#   art.silhouette = true            # album: locked card, embossed grey silhouette
#   art.triptych = &"midnight_run"   # panorama strip (size it 12:1, e.g. 1536x128 or 768x64)
# Dependencies: ArtKit, ArtIcons
# Author: Technical Artist Agent (cc14)
@tool
class_name CardArt
extends Control

const DESIGN_H: float = 128.0
const CARD_W: float = 512.0
const PANORAMA_W: float = 1536.0
const TRIPTYCHS: Array[StringName] = [&"midnight_run", &"cold_signal", &"open_book"]
const GRAIN_SHADER: String = "res://assets/shaders/card_grain.gdshader"

## Card id / art key (e.g. &"neon_rain"). Unknown keys get the set's generic poster.
@export var art_key: StringName = &"" : set = _set_art_key
@export var set_id: StringName = &"night_shift" : set = _set_set_id
@export var art_seed: int = 0 : set = _set_art_seed
## Cipher glyph 1-4 drawn faintly into the art (0 = none).
@export_range(0, 4) var glyph: int = 0 : set = _set_glyph
## Locked album card: everything in dark greys (embossed silhouette).
@export var silhouette: bool = false : set = _set_silhouette
## When set, draws that Triptych's panorama instead of a card.
@export var triptych: StringName = &"" : set = _set_triptych
## Faint seams at 1/3 and 2/3 of a panorama (the three banners it merges).
@export var show_seams: bool = true : set = _set_show_seams

var _pal: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _k: Vector2 = Vector2.ONE

static var _grain: ShaderMaterial


## Shared film-grain material (one instance for every card keeps batching cheap).
static func grain_material() -> ShaderMaterial:
	if _grain == null:
		_grain = ShaderMaterial.new()
		_grain.shader = load(GRAIN_SHADER)
	return _grain


## Takes a card Dictionary or Resource (fields: id or art_key, set or set_id, art_seed, glyph).
func configure(card: Variant) -> void:
	art_key = StringName(str(_field(card, ["art_key", "art", "id"], "")))
	set_id = StringName(str(_field(card, ["set", "set_id"], "night_shift")))
	art_seed = int(_field(card, ["art_seed", "seed"], 0))
	var g: Variant = _field(card, ["glyph", "cipher_glyph"], 0)
	glyph = int(g) if (g is int or g is float) else (1 if g == true else 0)


static func _field(card: Variant, keys: Array, fallback: Variant) -> Variant:
	for k: String in keys:
		var v: Variant = null
		if card is Dictionary:
			v = card.get(k, card.get(StringName(k), null))
		elif card is Object:
			v = card.get(k)
		if v != null and str(v) != "":
			return v
	return fallback


func _set_art_key(v: StringName) -> void:
	art_key = v
	queue_redraw()


func _set_set_id(v: StringName) -> void:
	set_id = v
	queue_redraw()


func _set_art_seed(v: int) -> void:
	art_seed = v
	queue_redraw()


func _set_glyph(v: int) -> void:
	glyph = v
	queue_redraw()


func _set_silhouette(v: bool) -> void:
	silhouette = v
	queue_redraw()


func _set_triptych(v: StringName) -> void:
	triptych = v
	queue_redraw()


func _set_show_seams(v: bool) -> void:
	show_seams = v
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var dw: float = PANORAMA_W if triptych != &"" else CARD_W
	_k = Vector2(size.x / dw, size.y / DESIGN_H)
	draw_set_transform(Vector2.ZERO, 0.0, _k)
	if triptych != &"":
		_pal = ArtKit.set_palette(_triptych_set())
		_rng.seed = hash(String(triptych))
		match triptych:
			&"midnight_run":
				_pano_midnight_run()
			&"cold_signal":
				_pano_cold_signal()
			_:
				_pano_open_book()
		if show_seams:
			for x: float in [512.0, 1024.0]:
				_rect(Rect2(x - 1.0, 0, 2.0, DESIGN_H), Color(0, 0, 0, 0.35))
	else:
		var palette_key: StringName = set_id
		if set_id == &"showcase" and String(art_key).contains("gold"):
			palette_key = &"showcase_gold"
		_pal = ArtKit.set_palette(palette_key)
		_rng.seed = hash(String(art_key)) ^ (art_seed * 7919) ^ hash(String(set_id))
		_draw_card_motif()
		if glyph > 0:
			_draw_glyph()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _triptych_set() -> StringName:
	return {&"midnight_run": &"night_shift", &"cold_signal": &"whiteout", &"open_book": &"old_guard"}.get(triptych, &"night_shift")


func _draw_card_motif() -> void:
	match art_key:
		&"graveyard_shift": _graveyard_shift()
		&"neon_rain": _neon_rain()
		&"last_train": _last_train()
		&"city_never_sleeps": _city_never_sleeps()
		&"frostbite": _frostbite()
		&"snow_blind": _snow_blind()
		&"polar_night": _polar_night()
		&"glacier": _glacier()
		&"mayday": _mayday()
		&"flare_up": _flare_up()
		&"dead_air": _dead_air()
		&"open_channel": _open_channel()
		&"brass_tacks": _brass_tacks()
		&"service_ribbon": _service_ribbon()
		&"long_watch": _long_watch()
		&"honor_roll": _honor_roll()
		&"null_glyph": _null_glyph()
		&"key_fragment": _key_fragment()
		&"chrome_tiger": _chrome_tiger()
		&"gold_leaf": _gold_leaf()
		_: _generic()


# --- Colour helpers -------------------------------------------------------------------------------
func _c(col: Color) -> Color:
	if not silhouette:
		return col
	var lum: float = col.get_luminance()
	var g: Color = ArtKit.SILHOUETTE_DARK.lerp(ArtKit.SILHOUETTE_LIGHT, clampf(lum * 1.1, 0.0, 1.0))
	g.a = col.a
	return g


func _deep(a: float = 1.0) -> Color:
	return Color(_pal["deep"], a)


func _mid(a: float = 1.0) -> Color:
	return Color(_pal["mid"], a)


func _hi(a: float = 1.0) -> Color:
	return Color(_pal["hi"], a)


# --- Drawing helpers (design units) ----------------------------------------------------------------
func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([_c(top), _c(top), _c(bottom), _c(bottom)]))


func _hgrad(r: Rect2, left: Color, right: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([_c(left), _c(right), _c(right), _c(left)]))


func _rect(r: Rect2, col: Color) -> void:
	draw_rect(r, _c(col))


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), _c(col))


func _circle(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, _c(col))


func _ring(c: Vector2, r: float, w: float, col: Color, from: float = 0.0, to: float = TAU) -> void:
	draw_arc(c, r, from, to, 40, _c(col), w, true)


func _line(a: Vector2, b: Vector2, col: Color, w: float = 2.0) -> void:
	draw_line(a, b, _c(col), w, true)


func _polyline(pts: Array, col: Color, w: float = 2.0) -> void:
	draw_polyline(PackedVector2Array(pts), _c(col), w, true)


## Cheap radial glow: stacked translucent discs.
func _glow(c: Vector2, r: float, col: Color, strength: float = 0.5) -> void:
	for i: int in 6:
		var t: float = 1.0 - float(i) / 6.0
		_circle(c, r * t, Color(col, strength * 0.22))


func _skyline(x0: float, x1: float, base: float, hmin: float, hmax: float, col: Color, win: Color, win_rate: float) -> void:
	var x: float = x0
	while x < x1:
		var w: float = _rng.randf_range(18.0, 42.0)
		var h: float = _rng.randf_range(hmin, hmax)
		_rect(Rect2(x, base - h, w - 2.0, h), col)
		if _rng.randf() < 0.3:
			_rect(Rect2(x + w * 0.35, base - h - 8.0, 3.0, 8.0), col)
		var wy: float = base - h + 6.0
		while wy < base - 6.0:
			var wx: float = x + 4.0
			while wx < x + w - 7.0:
				if _rng.randf() < win_rate:
					_rect(Rect2(wx, wy, 3.0, 4.0), win)
				wx += 7.0
			wy += 8.0
		x += w


func _rain(count: int, col: Color, slant: float = -10.0, x0: float = 0.0, x1: float = CARD_W) -> void:
	for i: int in count:
		var x: float = _rng.randf_range(x0, x1)
		var y: float = _rng.randf_range(-10.0, DESIGN_H)
		var l: float = _rng.randf_range(10.0, 26.0)
		_line(Vector2(x, y), Vector2(x + slant * l / 26.0, y + l), col, 1.2)


func _hex_star(c: Vector2, r: float, col: Color, w: float) -> void:
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		var tip: Vector2 = c + Vector2.from_angle(a) * r
		_line(c, tip, col, w)
		for f: float in [0.45, 0.7]:
			var p: Vector2 = c + Vector2.from_angle(a) * r * f
			_line(p, p + Vector2.from_angle(a + 0.7) * r * 0.25, col, w * 0.7)
			_line(p, p + Vector2.from_angle(a - 0.7) * r * 0.25, col, w * 0.7)


func _figure(x: float, base: float, h: float, col: Color) -> void:
	_circle(Vector2(x, base - h + h * 0.12), h * 0.12, col)
	_poly([Vector2(x - h * 0.14, base - h * 0.74), Vector2(x + h * 0.14, base - h * 0.74),
			Vector2(x + h * 0.2, base), Vector2(x - h * 0.2, base)], col)


# --- Card motifs (art briefs from spec section 6, all original) -----------------------------------
func _graveyard_shift() -> void:  # empty bus stop under a flickering sign
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid().darkened(0.55))
	_skyline(0, CARD_W, 92, 18, 52, _deep().lightened(0.06), _hi(0.35), 0.12)
	_rect(Rect2(0, 92, CARD_W, 36), _deep().darkened(0.3))
	var x: float = 250.0 + _rng.randf_range(-20, 20)
	_glow(Vector2(x + 110, 34), 70, _mid(), 0.7)
	_rect(Rect2(x, 46, 130, 8), _hi())  # shelter roof
	_rect(Rect2(x + 6, 54, 5, 46), _hi(0.9))
	_rect(Rect2(x + 118, 54, 5, 46), _hi(0.9))
	_rect(Rect2(x + 24, 80, 80, 5), _hi(0.75))  # bench
	_rect(Rect2(x + 108, 20, 4, 80), _mid())  # sign pole
	_rect(Rect2(x + 94, 16, 32, 20), _mid())  # the sign
	_rect(Rect2(x + 98, 20, 24, 12), _hi(0.85 if _rng.randf() < 0.6 else 0.35))
	_rect(Rect2(0, 100, CARD_W, 2), _mid(0.5))


func _neon_rain() -> void:  # rain over magenta / cyan signage, wet asphalt
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _deep().lerp(_mid(), 0.35))
	for i: int in 5:
		var r := Rect2(_rng.randf_range(20, 440), _rng.randf_range(10, 50), _rng.randf_range(40, 90), _rng.randf_range(14, 26))
		var col: Color = _mid() if i % 2 == 0 else _hi()
		_glow(r.get_center(), r.size.x * 0.7, col, 0.4)
		draw_rect(r, _c(col), false, 3.0)
		_rect(Rect2(r.position.x + 8, r.get_center().y - 2, r.size.x - 16, 4), Color(col, 0.8))
		# reflection on the wet street
		_rect(Rect2(r.position.x + 4, 96 + (r.position.y * 0.15), r.size.x - 8, 3), Color(col, 0.45))
	_rect(Rect2(0, 92, CARD_W, 2), _hi(0.3))
	_rain(110, _hi(0.45), -9.0)


func _last_train() -> void:  # subway car lights receding into a tunnel
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _deep().darkened(0.4))
	var vp := Vector2(330 + _rng.randf_range(-30, 30), 66)
	for i: int in 7:
		var t: float = float(i) / 7.0
		var r := Rect2(lerpf(-40, vp.x - 14, t), lerpf(-30, vp.y - 10, t), 0, 0)
		r.end = Vector2(lerpf(CARD_W + 40, vp.x + 14, t), lerpf(DESIGN_H + 30, vp.y + 10, t))
		draw_rect(r, _c(_mid(0.25 + t * 0.5)), false, 3.0 - t * 2.0)
	_line(Vector2(120, 128), vp + Vector2(-3, 8), _hi(0.5), 2.0)
	_line(Vector2(520, 128), vp + Vector2(3, 8), _hi(0.5), 2.0)
	_glow(vp + Vector2(-6, 2), 26, _hi(), 0.9)
	_glow(vp + Vector2(6, 2), 26, _hi(), 0.9)
	_circle(vp + Vector2(-6, 2), 3, Color.WHITE)
	_circle(vp + Vector2(6, 2), 3, Color.WHITE)


func _city_never_sleeps() -> void:  # skyline panorama, every window lit, gold trim
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid().darkened(0.3))
	_glow(Vector2(400, 20), 40, _hi(), 0.4)
	_skyline(-10, CARD_W, 116, 30, 70, _deep().lightened(0.08), _hi(0.55), 0.35)
	_skyline(-20, CARD_W, 128, 40, 100, _deep(), Color("#F0C866"), 0.75)
	_rect(Rect2(0, 120, CARD_W, 8), Color("#D9B45A", 0.9))


func _frostbite() -> void:  # ice crystals creeping over a glove
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	var gx: float = 120.0 + _rng.randf_range(-20, 20)
	_poly([Vector2(gx - 50, 128), Vector2(gx - 46, 60), Vector2(gx - 20, 34), Vector2(gx + 24, 30),
			Vector2(gx + 54, 48), Vector2(gx + 58, 90), Vector2(gx + 40, 128)], _deep().darkened(0.2))
	_poly([Vector2(gx + 50, 70), Vector2(gx + 86, 52), Vector2(gx + 96, 64), Vector2(gx + 58, 92)], _deep().darkened(0.2))
	for i: int in 9:
		_hex_star(Vector2(gx + _rng.randf_range(-50, 70), _rng.randf_range(30, 110)), _rng.randf_range(5, 11), _hi(0.8), 1.5)
	_hex_star(Vector2(360 + _rng.randf_range(-30, 30), 64), 46, _hi(), 4.0)
	_hex_star(Vector2(460, 28), 16, _hi(0.6), 2.0)


func _snow_blind() -> void:  # white field, one silhouette, flare glow
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _hi(), _hi().darkened(0.06))
	_rect(Rect2(0, 84, CARD_W, 1.5), _mid(0.25))
	var x: float = 300.0 + _rng.randf_range(-60, 60)
	_glow(Vector2(x + 40, 44), 46, Color("#F2705A"), 0.35)
	_circle(Vector2(x + 40, 44), 3.5, Color("#F2705A", 0.9))
	_figure(x, 92, 34, _deep())
	for i: int in 50:
		_circle(Vector2(_rng.randf_range(0, CARD_W), _rng.randf_range(0, DESIGN_H)), _rng.randf_range(0.8, 1.8), _mid(0.35))


func _polar_night() -> void:  # aurora over a dark ridge
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep().darkened(0.4), _deep())
	for b: int in 3:
		var pts: Array = []
		var y0: float = 30.0 + b * 14.0
		var ph: float = _rng.randf_range(0, TAU)
		for i: int in 33:
			var x: float = i * 16.0
			pts.append(Vector2(x, y0 + sin(x * 0.018 + ph) * 12.0))
		_polyline(pts, _hi(0.35 - b * 0.08), 12.0 - b * 3.0)
		_polyline(pts, _hi(0.7), 2.0)
	for i: int in 30:
		_circle(Vector2(_rng.randf_range(0, CARD_W), _rng.randf_range(0, 40)), 0.9, _hi(0.6))
	_poly([Vector2(0, 128), Vector2(0, 100), Vector2(80, 84), Vector2(150, 96), Vector2(240, 70),
			Vector2(330, 92), Vector2(420, 78), Vector2(512, 96), Vector2(512, 128)], _deep().darkened(0.6))


func _glacier() -> void:  # cracked blue ice wall, vertical strata
	var x: float = 0.0
	var flip: bool = false
	while x < CARD_W:
		var w: float = _rng.randf_range(10, 34)
		_vgrad(Rect2(x, 0, w, DESIGN_H), (_hi() if flip else _mid()).lightened(0.05), (_mid() if flip else _deep()))
		flip = not flip
		x += w
	var pts: Array = [Vector2(260 + _rng.randf_range(-40, 40), 0)]
	for i: int in 6:
		pts.append(pts[-1] + Vector2(_rng.randf_range(-22, 22), 22))
	_polyline(pts, _deep().darkened(0.4), 4.0)
	_polyline(pts, _hi(0.6), 1.0)


func _mayday() -> void:  # distress flare arcing over dark water
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	_rect(Rect2(0, 96, CARD_W, 32), _deep().darkened(0.3))
	for i: int in 8:
		var y: float = 100.0 + i * 3.5
		_line(Vector2(_rng.randf_range(0, 200), y), Vector2(_rng.randf_range(260, 512), y), _hi(0.12 + i * 0.02), 1.2)
	var pts: Array = []
	var x0: float = 60.0 + _rng.randf_range(0, 40)
	var apex := Vector2(330 + _rng.randf_range(-30, 30), 26)
	for i: int in 17:
		var t: float = float(i) / 16.0
		pts.append(Vector2(lerpf(x0, apex.x, t), lerpf(96, apex.y, 1.0 - pow(1.0 - t, 2.0))))
	_polyline(pts, _hi(0.6), 2.5)
	_glow(apex, 60, _hi(), 0.8)
	_circle(apex, 6, Color("#FFE0C8"))
	_rect(Rect2(apex.x - 1, 98, 2, 26), _hi(0.5))  # reflection


func _flare_up() -> void:  # burst of red flares
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	for i: int in 4:
		var c := Vector2(_rng.randf_range(60, 460), _rng.randf_range(24, 80))
		var r: float = _rng.randf_range(24, 50)
		_glow(c, r * 1.6, _hi(), 0.5)
		for j: int in 14:
			var a: float = TAU * float(j) / 14.0 + _rng.randf() * 0.2
			_line(c + Vector2.from_angle(a) * r * 0.3, c + Vector2.from_angle(a) * r, _hi(0.85), 2.0)
		_circle(c, 3.0, Color("#FFE0C8"))


func _dead_air() -> void:  # old radio, needle at silence, static bands
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	for i: int in 16:
		var y: float = _rng.randf_range(0, DESIGN_H)
		_rect(Rect2(0, y, CARD_W, _rng.randf_range(1, 3)), _hi(_rng.randf_range(0.05, 0.18)))
	var body := Rect2(180, 22, 220, 92)
	draw_rect(body, _c(_deep()))
	draw_rect(body, _c(_hi(0.8)), false, 3.0)
	var dial := Rect2(196, 34, 120, 34)
	_rect(dial, _hi(0.85))
	for i: int in 11:
		_rect(Rect2(dial.position.x + 8 + i * 10.4, dial.position.y + 4, 1.5, 8 if i % 2 == 0 else 5), _deep())
	_rect(Rect2(dial.position.x + 14, dial.position.y + 4, 3, 28), _deep())  # needle parked at silence
	for gx: int in 4:
		for gy: int in 4:
			_circle(Vector2(338 + gx * 13, 40 + gy * 12), 3.0, _hi(0.6))
	_circle(Vector2(236, 92), 10, _hi(0.7))
	_circle(Vector2(276, 92), 10, _hi(0.7))


func _open_channel() -> void:  # antenna tower with pulsing rings
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	var top := Vector2(300 + _rng.randf_range(-40, 40), 18)
	for i: int in 5:
		_ring(top, 22.0 + i * 24.0, 3.0, _hi(0.75 - i * 0.13), -PI * 0.95, -PI * 0.05)
	_line(top, Vector2(top.x - 26, 128), _hi(), 3.0)
	_line(top, Vector2(top.x + 26, 128), _hi(), 3.0)
	for i: int in 5:
		var y: float = 34.0 + i * 19.0
		var hw: float = 26.0 * (y - top.y) / (128.0 - top.y)
		_line(Vector2(top.x - hw, y), Vector2(top.x + hw, y + 19), _hi(0.6), 1.5)
		_line(Vector2(top.x + hw, y), Vector2(top.x - hw, y + 19), _hi(0.6), 1.5)
	_glow(top, 18, _hi(), 0.9)


func _brass_tacks() -> void:  # brass tacks pinning a torn map
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	var pts: Array = [Vector2(70, 12), Vector2(450, 8), Vector2(440, 60)]
	for i: int in 8:
		pts.append(Vector2(440 - i * 6, 60 + i * 8) + Vector2(_rng.randf_range(-6, 6), 0))
	pts.append(Vector2(60, 118))
	_poly(pts, _hi(0.85))
	for i: int in 5:
		var c := Vector2(_rng.randf_range(120, 380), _rng.randf_range(35, 90))
		for r: float in [10.0, 20.0, 30.0]:
			_ring(c, r * _rng.randf_range(0.8, 1.2), 1.5, _mid(0.6))
	_polyline([Vector2(100, 90), Vector2(170, 70), Vector2(250, 84), Vector2(330, 50)], _deep(0.8), 2.0)
	for p: Vector2 in [Vector2(84, 22), Vector2(430, 20), Vector2(80, 104)]:
		_circle(p + Vector2(2, 3), 8, Color(0, 0, 0, 0.35))
		_circle(p, 8, _hi().lightened(0.25))
		_circle(p + Vector2(-2, -2), 3, Color(1, 1, 1, 0.6))


func _service_ribbon() -> void:  # striped ribbon bar on felt
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	for i: int in 40:
		_line(Vector2(i * 14, 0), Vector2(i * 14 - 30, 128), _deep(0.25), 1.0)
	var bar := Rect2(150 + _rng.randf_range(-20, 20), 40, 220, 48)
	_rect(bar.grow(4), _deep().darkened(0.5))
	var stripes: Array = [_hi(), _mid(), _hi().lightened(0.35), _deep(), _hi(), _mid().lightened(0.2), _hi()]
	var sx: float = bar.position.x
	var widths: Array = [30, 26, 22, 64, 22, 26, 30]
	for i: int in stripes.size():
		_rect(Rect2(sx, bar.position.y, widths[i], bar.size.y), stripes[i])
		sx += widths[i]
	_rect(Rect2(bar.position.x, bar.position.y, bar.size.x, 6), Color(1, 1, 1, 0.18))


func _long_watch() -> void:  # lone lighthouse beam across fog
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	var x: float = 110.0 + _rng.randf_range(-20, 20)
	_poly([Vector2(x + 20, 34), Vector2(CARD_W + 20, 10), Vector2(CARD_W + 20, 70)], _hi(0.28))
	_poly([Vector2(x + 20, 34), Vector2(CARD_W + 20, 24), Vector2(CARD_W + 20, 50)], _hi(0.3))
	for i: int in 4:
		_rect(Rect2(0, 70 + i * 13, CARD_W, 7), _hi(0.07 + i * 0.03))
	_poly([Vector2(x - 12, 128), Vector2(x - 6, 40), Vector2(x + 6, 40), Vector2(x + 12, 128)], _deep().darkened(0.3))
	_rect(Rect2(x - 9, 30, 18, 12), _hi())
	_poly([Vector2(x - 11, 30), Vector2(x, 20), Vector2(x + 11, 30)], _deep().darkened(0.3))
	_glow(Vector2(x, 36), 30, _hi(), 0.8)


func _honor_roll() -> void:  # engraved plaque wall, names as abstract lines
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	for col: int in 6:
		for row: int in 2:
			var r := Rect2(16 + col * 82, 12 + row * 56, 72, 48)
			_rect(r, _hi(0.85))
			draw_rect(r.grow(-3), _c(_mid(0.7)), false, 1.5)
			for l: int in 4:
				var w: float = _rng.randf_range(24, 54)
				_rect(Rect2(r.position.x + (72 - w) * 0.5, r.position.y + 10 + l * 8, w, 2.5), _mid(0.8))


func _null_glyph() -> void:  # black field, one glowing unknown symbol
	_rect(Rect2(0, 0, CARD_W, DESIGN_H), _deep())
	for i: int in 24:
		_rect(Rect2(i * 22, 0, 1, DESIGN_H), _hi(0.04))
	var c := Vector2(256 + _rng.randf_range(-60, 60), 64)
	_glow(c, 60, _hi(), 0.7)
	_ring(c, 26, 3.5, _hi())
	_line(c + Vector2(-14, -18), c + Vector2(14, 18), _hi(), 4.0)
	_line(c + Vector2(-20, 4), c + Vector2(6, -4), _hi(), 3.0)
	_circle(c + Vector2(16, -12), 3.5, _hi())


func _key_fragment() -> void:  # broken key, edges glowing teal, glyph etched
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	var y: float = 64.0
	var x0: float = 120.0 + _rng.randf_range(-20, 20)
	_glow(Vector2(x0 + 150, y), 70, _hi(), 0.35)
	_ring(Vector2(x0, y), 26, 10, _hi(0.9))
	_rect(Rect2(x0 + 24, y - 6, 120, 12), _hi(0.9))
	_poly([Vector2(x0 + 144, y - 6), Vector2(x0 + 150, y - 2), Vector2(x0 + 146, y + 2), Vector2(x0 + 152, y + 6), Vector2(x0 + 144, y + 6)], _hi(0.9))
	# the broken-off bit, drifting
	_poly([Vector2(x0 + 168, y - 4), Vector2(x0 + 230, y - 2), Vector2(x0 + 230, y + 20), Vector2(x0 + 214, y + 20),
			Vector2(x0 + 214, y + 10), Vector2(x0 + 200, y + 10), Vector2(x0 + 200, y + 22), Vector2(x0 + 186, y + 22), Vector2(x0 + 186, y + 8), Vector2(x0 + 172, y + 8)], _hi(0.9))
	_ring(Vector2(x0, y), 9, 2, _deep())


func _chrome_tiger() -> void:  # low-poly chrome tiger head
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid().darkened(0.4))
	for i: int in 9:
		_line(Vector2(i * 64 - 40, 128), Vector2(i * 64 + 40, 0), _hi(0.08), 10.0)
	var c := Vector2(256 + _rng.randf_range(-40, 40), 66)
	var tones: Array = [_hi(), _hi().darkened(0.15), _mid().lightened(0.3), _mid(), _hi().darkened(0.3)]
	var head: Array = [Vector2(-46, -40), Vector2(-20, -50), Vector2(20, -50), Vector2(46, -40), Vector2(58, -6),
			Vector2(40, 34), Vector2(0, 52), Vector2(-40, 34), Vector2(-58, -6)]
	for i: int in head.size():
		var a: Vector2 = head[i]
		var b: Vector2 = head[(i + 1) % head.size()]
		_poly([c, c + a, c + b], tones[i % tones.size()])
	_poly([c + Vector2(-46, -40), c + Vector2(-58, -66), c + Vector2(-24, -48)], tones[0])  # ears
	_poly([c + Vector2(46, -40), c + Vector2(58, -66), c + Vector2(24, -48)], tones[2])
	for s: float in [-1.0, 1.0]:  # stripes
		_poly([c + Vector2(s * 50, -24), c + Vector2(s * 26, -18), c + Vector2(s * 48, -12)], _deep())
		_poly([c + Vector2(s * 52, 2), c + Vector2(s * 30, 4), c + Vector2(s * 46, 12)], _deep())
		_poly([c + Vector2(s * 8, -48), c + Vector2(s * 4, -30), c + Vector2(s * 14, -46)], _deep())
		_poly([c + Vector2(s * 26, -10), c + Vector2(s * 12, -14), c + Vector2(s * 16, -4)], Color("#3FE0C5"))  # eyes
	_poly([c + Vector2(-9, 14), c + Vector2(9, 14), c + Vector2(0, 24)], _deep())


func _gold_leaf() -> void:  # gilded leaf pattern
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _mid(), _deep())
	for row: int in 4:
		for col: int in 12:
			var c := Vector2(col * 46 + (23 if row % 2 == 1 else 0) + 4, row * 36 + 10)
			var a: float = (0.6 if (row + col) % 2 == 0 else -0.6) + _rng.randf_range(-0.2, 0.2)
			var d := Vector2.from_angle(a)
			var n := Vector2(-d.y, d.x)
			var tone: Color = _hi().lerp(_mid(), _rng.randf_range(0.0, 0.5))
			_poly([c - d * 18, c + n * 8, c + d * 18, c - n * 8], tone)
			_line(c - d * 16, c + d * 16, _deep(0.6), 1.2)


func _generic() -> void:  # fallback poster for unknown art keys: bold bands + a sun
	_vgrad(Rect2(0, 0, CARD_W, DESIGN_H), _deep(), _mid())
	var c := Vector2(_rng.randf_range(100, 420), _rng.randf_range(30, 70))
	_glow(c, 50, _hi(), 0.6)
	_circle(c, 18, _hi())
	for i: int in 3:
		var y: float = 80.0 + i * 14.0
		_poly([Vector2(0, y + _rng.randf_range(-8, 8)), Vector2(CARD_W, y + _rng.randf_range(-8, 8)), Vector2(CARD_W, 128), Vector2(0, 128)], _deep(0.5 + i * 0.15))


func _draw_glyph() -> void:
	var px: float = 30.0
	var tex: Texture2D = ArtIcons.cipher_glyph(glyph, px * maxf(_k.y, 0.5) * 2.0)
	if tex == null:
		return
	# Hidden in plain sight: upper middle of the art, between the T pip and the Clearance pips.
	var pos := Vector2(232 + _rng.randf_range(-30, 30), 10)
	draw_texture_rect(tex, Rect2(pos, Vector2(px, px)), false, _c(Color(_pal["hi"].lightened(0.2), 0.55)))


# --- Triptych panoramas (spec 5.1), 1536 x 128 ------------------------------------------------------
func _pano_midnight_run() -> void:  # night city, the last train crossing a viaduct, rain
	_vgrad(Rect2(0, 0, PANORAMA_W, DESIGN_H), _deep(), _mid().darkened(0.45))
	_glow(Vector2(1240, 26), 40, _hi(), 0.5)
	_circle(Vector2(1240, 26), 12, _hi().lightened(0.4))
	_skyline(0, PANORAMA_W, 110, 26, 70, _deep().lightened(0.07), _hi(0.5), 0.3)
	_rect(Rect2(0, 78, PANORAMA_W, 6), _deep().darkened(0.2))  # viaduct deck
	for i: int in 16:
		_rect(Rect2(i * 100 + 20, 84, 10, 44), _deep().darkened(0.2))
	for car: int in 4:  # the train
		var r := Rect2(420 + car * 150, 52, 140, 26)
		_rect(r, _mid())
		for w: int in 8:
			_rect(Rect2(r.position.x + 8 + w * 16, r.position.y + 6, 10, 8), _hi())
	_glow(Vector2(1020, 66), 40, _hi(), 0.7)
	_rain(260, _hi(0.35), -9.0, 0.0, PANORAMA_W)


func _pano_cold_signal() -> void:  # ice field, a radio mast calling out under aurora
	_vgrad(Rect2(0, 0, PANORAMA_W, DESIGN_H), _deep().darkened(0.3), _mid())
	for b: int in 2:
		var pts: Array = []
		for i: int in 97:
			var x: float = i * 16.0
			pts.append(Vector2(x, 34.0 + b * 14.0 + sin(x * 0.01 + b) * 14.0))
		_polyline(pts, Color("#3FE0C5", 0.25), 12.0)
		_polyline(pts, Color("#3FE0C5", 0.6), 2.0)
	_poly([Vector2(0, 128), Vector2(0, 92), Vector2(300, 84), Vector2(700, 98), Vector2(1100, 86), Vector2(1536, 94), Vector2(1536, 128)], _hi())
	for i: int in 3:
		_hex_star(Vector2(160 + i * 120, 104), 10, _mid(0.7), 1.5)
	var top := Vector2(1230, 22)
	for i: int in 6:
		_ring(top, 24.0 + i * 30.0, 3.0, Color("#E0452E", 0.7 - i * 0.1), -PI * 0.95, -PI * 0.05)
	_line(top, Vector2(top.x - 22, 92), _deep(), 3.5)
	_line(top, Vector2(top.x + 22, 92), _deep(), 3.5)
	_glow(top, 16, Color("#E0452E"), 0.9)
	_figure(760, 96, 30, _deep())


func _pano_open_book() -> void:  # plaque columns, glowing glyphs, a key made whole
	_vgrad(Rect2(0, 0, PANORAMA_W, DESIGN_H), _mid(), _deep())
	for col: int in 5:
		var r := Rect2(20 + col * 92, 16, 80, 96)
		_rect(r, _hi(0.8))
		for l: int in 7:
			_rect(Rect2(r.position.x + 12, r.position.y + 12 + l * 11, _rng.randf_range(30, 56), 2.5), _mid(0.8))
	var teal := Color("#3FE0C5")
	for i: int in 4:
		var c := Vector2(640 + i * 80, 64)
		_glow(c, 34, teal, 0.5)
		var tex: Texture2D = ArtIcons.cipher_glyph(i + 1, 40.0 * maxf(_k.y, 0.5) * 2.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(20, 20), Vector2(40, 40)), false, _c(teal))
	var y: float = 64.0
	var x0: float = 1080.0
	_glow(Vector2(x0 + 140, y), 90, teal, 0.35)
	_ring(Vector2(x0, y), 30, 11, _hi())
	_rect(Rect2(x0 + 28, y - 7, 260, 14), _hi())
	_rect(Rect2(x0 + 230, y + 7, 16, 22), _hi())
	_rect(Rect2(x0 + 262, y + 7, 16, 30), _hi())
