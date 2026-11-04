# banner_card.gd
# Purpose: BannerCard (cc14), the reusable calling-card view for the wall, hand, inspector and album.
#   A 4:1 banner (art-direction.md section 2): CardArt poster inside a Clearance frame (section 3),
#   enamel value pips (Top at the top, Side on both short ends, Bottom at the bottom), Clearance
#   pips, trait icon (+ word when large), name and set glyph (when large), the owner's lacquer ring
#   and corner tab (player solid / rival notched, so ownership never relies on colour), Signature
#   ribbon, Ambush card back, locked silhouette, set-complete edge light, capture-preview badge.
#   Size it freely at 4:1 (256x64 board, 1024x256 album); every measure scales with the height.
#   Text is drawn at its real pixel size (never scaled), so it stays sharp on a 3x phone.
# Usage:
#   var card: BannerCard = preload("res://scenes/card/BannerCard.tscn").instantiate()
#   card.configure(card_data)        # Dictionary or Resource: id, name, set, origin, clearance,
#                                    # top, side, bottom, trait, art_seed, glyph, frame
#   card.side = &"player"            # &"player" | &"rival" | &"" (album: no owner)
#   card.signature = true; card.face_down = true; card.locked = true; card.set_complete = true
#   card.highlighted = true          # amber outline (valid / selected)
#   card.preview_flip = true         # amber arrow badge: this card would flip
#   card.boost = Vector3i(1, 1, 1)   # placement bonus shown in amber (Set Link, Clutch, spring)
#   card.capture_to(&"rival")        # 0.25 s re-lacquer wipe, then owner changes (returns Tween)
#   card.pulse()                     # set-complete edge light pulses once (call on placement)
#   signals: tapped(card), inspect_requested(card)   (right-click or long-press 0.45 s)
# Dependencies: ArtKit, ArtIcons, CardArt, assets/shaders/frame_glint.gdshader, Settings (optional)
# Author: Technical Artist Agent (cc14)
class_name BannerCard
extends Control

signal tapped(card: BannerCard)
signal inspect_requested(card: BannerCard)

const GLINT_SHADER: String = "res://assets/shaders/frame_glint.gdshader"
const LONG_PRESS_S: float = 0.45
## Below this height the card shows values, trait icon and Clearance only (board size).
const FULL_DETAIL_HEIGHT: float = 96.0
## Smallest text the card ever draws (README phone rule: text >= 16 logical px).
const MIN_TEXT_PX: int = 16

@export var side: StringName = &"" : set = _set_side
@export var signature: bool = false : set = _set_redraw_flag_signature
@export var face_down: bool = false : set = _set_face_down
@export var locked: bool = false : set = _set_locked
@export var set_complete: bool = false : set = _set_set_complete
@export var highlighted: bool = false : set = _set_highlighted
@export var preview_flip: bool = false : set = _set_preview_flip
## Direction the preview arrow points (from the attacker towards this card).
@export var preview_dir: Vector2 = Vector2.RIGHT : set = _set_preview_dir
@export var boost: Vector3i = Vector3i.ZERO : set = _set_boost

var card_id: StringName = &""
var card_name: String = "Card"
var set_id: StringName = &"night_shift"
var origin: StringName = &""
var clearance: int = 1
var values: Vector3i = Vector3i(5, 4, 4)
var trait_id: StringName = &"none"
var frame_override: StringName = &""

@onready var _art: CardArt = %Art
@onready var _glint: ColorRect = %Glint
@onready var _overlay: Control = %Overlay

var _glint_mat: ShaderMaterial
var _press_t: float = -1.0
var _wash_tween: Tween
var _pulse_tween: Tween
var _last_layout: Dictionary = {}
var _pending_card: Variant = null
var _wash: float = 0.0


func _ready() -> void:
	_glint_mat = ShaderMaterial.new()
	_glint_mat.shader = load(GLINT_SHADER)
	_glint.material = _glint_mat
	_art.material = CardArt.grain_material()
	_art.clip_contents = true
	_overlay.draw.connect(_draw_overlay)
	resized.connect(_relayout)
	if _pending_card != null:
		_art.configure(_pending_card)
	_relayout()


## Fills the card from a Dictionary or a Resource (CardData). Field names follow spec section 3;
## a few aliases are accepted so cc02's Resource names and mock dictionaries both work.
func configure(card: Variant) -> void:
	card = CardArt.as_dict(card)
	card_id = StringName(str(CardArt._field(card, ["id", "card_id"], "")))
	card_name = str(CardArt._field(card, ["name", "display_name", "title"], String(card_id).capitalize()))
	set_id = StringName(str(CardArt._field(card, ["set", "set_id"], "night_shift")))
	origin = StringName(str(CardArt._field(card, ["origin"], "")).to_lower())
	clearance = clampi(int(CardArt._field(card, ["clearance"], 1)), 1, 4)
	values = Vector3i(int(CardArt._field(card, ["top"], 0)), int(CardArt._field(card, ["side"], 0)),
			int(CardArt._field(card, ["bottom"], 0)))
	var t: String = str(CardArt._field(card, ["trait", "trait_id"], "")).to_lower()
	if t == "" and ArtKit.ORIGIN_TRAIT.has(origin):
		t = String(ArtKit.ORIGIN_TRAIT[origin])
	trait_id = StringName(t if t != "" else "none")
	frame_override = StringName(str(CardArt._field(card, ["frame"], "")))
	_pending_card = card
	if is_node_ready():
		_art.configure(card)
	_relayout()


## Re-lacquers the frame in the captor's colour (left-to-right wipe), then sets the owner.
func capture_to(new_side: StringName, duration: float = 0.25) -> Tween:
	if _wash_tween != null and _wash_tween.is_valid():
		_wash_tween.kill()
	if not is_inside_tree():
		side = new_side
		return null
	_glint.visible = true
	_glint_mat.set_shader_parameter("wash_color", ArtKit.side_color(new_side))
	_wash_tween = create_tween()
	_wash_tween.tween_method(_set_wash, 0.0, 1.0, maxf(duration, 0.01))
	_wash_tween.tween_callback(func() -> void:
		side = new_side
		_set_wash(0.0))
	return _wash_tween


## One pulse of the set-complete edge light (art-direction: "pulses once per placement").
func pulse(duration: float = 0.7) -> void:
	if not set_complete or not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(func(v: float) -> void: _glint_mat.set_shader_parameter("edge_pulse", v), 1.0, 0.0, duration)


## Measures used for the last draw (tests and layout checks): fonts, pip radius, name fit.
func layout_report() -> Dictionary:
	_compute_layout()
	return _last_layout.duplicate()


func is_full_detail() -> bool:
	return size.y >= FULL_DETAIL_HEIGHT


# --- Setters -----------------------------------------------------------------------------------
func _set_side(v: StringName) -> void:
	side = v
	queue_redraw()
	_redraw_overlay()


func _set_redraw_flag_signature(v: bool) -> void:
	signature = v
	_redraw_overlay()


func _set_face_down(v: bool) -> void:
	face_down = v
	_relayout()


func _set_locked(v: bool) -> void:
	locked = v
	_relayout()


func _set_set_complete(v: bool) -> void:
	set_complete = v
	_relayout()


func _set_highlighted(v: bool) -> void:
	highlighted = v
	queue_redraw()


func _set_preview_flip(v: bool) -> void:
	preview_flip = v
	_redraw_overlay()


func _set_preview_dir(v: Vector2) -> void:
	preview_dir = v
	_redraw_overlay()


func _set_boost(v: Vector3i) -> void:
	boost = v
	_redraw_overlay()


func _set_wash(v: float) -> void:
	_wash = v
	if _glint_mat != null:
		_glint_mat.set_shader_parameter("wash_progress", v)
	if v <= 0.0:
		_update_glint_visibility()


func _redraw_overlay() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


# --- Layout ------------------------------------------------------------------------------------
func _frame_spec() -> Dictionary:
	if face_down:
		return ArtKit.FRAMES[&"back"]
	if locked:
		return ArtKit.FRAMES[&"locked"]
	var forced: StringName = frame_override
	if set_id == &"showcase" and forced == &"":
		forced = &"showcase_gold" if String(card_id).contains("gold") else &"showcase_chrome"
	return ArtKit.frame_spec(clearance, forced, set_id)


func _k() -> float:
	return size.y / CardArt.DESIGN_H


func _inset() -> float:
	var spec: Dictionary = _frame_spec()
	return float(spec["border"]) * _k() + maxf(ArtKit.LACQUER * _k(), 1.5)


func _relayout() -> void:
	if not is_node_ready():
		return
	var inset: float = _inset()
	_art.position = Vector2(inset, inset)
	_art.size = (size - Vector2(inset, inset) * 2.0).max(Vector2.ONE)
	_art.visible = not face_down
	_art.silhouette = locked
	_glint.position = Vector2.ZERO
	_glint.size = size
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	var spec: Dictionary = _frame_spec()
	_glint_mat.set_shader_parameter("card_size", size)
	_glint_mat.set_shader_parameter("border", float(spec["border"]) * _k())
	_glint_mat.set_shader_parameter("radius", float(spec["radius"]) * _k())
	var reduced: bool = _reduced_motion()
	_glint_mat.set_shader_parameter("glint_strength", float(spec["glint"]))
	_glint_mat.set_shader_parameter("glint_speed", 0.0 if reduced else float(spec["glint_speed"]))
	_glint_mat.set_shader_parameter("glint_phase", float(hash(String(card_id)) % 1000) / 1000.0)
	_glint_mat.set_shader_parameter("sheen", float(spec["sheen"]))
	_glint_mat.set_shader_parameter("glint_color", (spec["hi"] as Color).lightened(0.3))
	var edge: bool = set_complete and not face_down and not locked
	_glint_mat.set_shader_parameter("edge_amount", 1.0 if edge else 0.0)
	_glint_mat.set_shader_parameter("edge_color", ArtKit.set_palette(set_id)["edge"])
	_update_glint_visibility()
	queue_redraw()
	_redraw_overlay()


func _update_glint_visibility() -> void:
	if _glint_mat == null:
		return
	var spec: Dictionary = _frame_spec()
	_glint.visible = float(spec["glint"]) > 0.0 or (set_complete and not face_down and not locked) or _wash > 0.0


func _reduced_motion() -> bool:
	var s: Node = get_node_or_null("/root/Settings")
	return s != null and bool(s.get("reduced_motion"))


## Pip, font and text measures for the current size, in logical px.
func _compute_layout() -> Dictionary:
	var h: float = size.y
	var w: float = size.x
	var inset: float = _inset()
	var r: float = clampf(15.0 + (h - 64.0) * 0.055, 12.0, 26.0)
	var gap: float = maxf(2.0, h * 0.03)
	var m: float = inset + gap * 0.5
	var full: bool = is_full_detail()
	var lay: Dictionary = {
		"r": r, "m": m, "gap": gap, "full": full,
		"numeral_px": _numeral_px(r),
		"s_left": Vector2(m + r, h * 0.5),
		"s_right": Vector2(w - m - r, h * 0.5),
		"top": Vector2(m + 3.0 * r + gap, m + r),
		"bottom": Vector2(w - m - 3.0 * r - gap, h - m - r),
		"dot_r": maxf(2.5, h * 0.035),
	}
	var trait_px: float = r * 1.5
	lay["trait_px"] = trait_px
	lay["trait_center"] = lay["bottom"] - Vector2(r + gap + trait_px * 0.5, 0)
	lay["name_px"] = 0
	lay["name_fits"] = true
	lay["name_text"] = ""
	lay["trait_word_px"] = 0
	if full:
		var font: Font = ArtKit.font_display()
		var trait_word: String = ArtKit.trait_name(trait_id).to_upper() if not face_down else ""
		var word_px: int = maxi(MIN_TEXT_PX, int(roundf(h * 0.085)))
		var word_w: float = font.get_string_size(trait_word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_px).x if trait_word != "" else 0.0
		lay["trait_word_px"] = word_px if trait_word != "" else 0
		lay["trait_word_w"] = word_w
		var trait_left: float = (lay["trait_center"] as Vector2).x - trait_px * 0.5 - (word_w + gap if word_w > 0.0 else 0.0)
		var glyph_px: float = maxf(16.0, h * 0.12)
		var name_left: float = m + gap + glyph_px + gap
		var avail: float = trait_left - gap * 2.0 - name_left
		var name_text: String = "HIDDEN" if face_down else card_name.to_upper()
		var px: int = maxi(MIN_TEXT_PX, int(roundf(h * 0.15)))
		while px > MIN_TEXT_PX and font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > avail:
			px -= 1
		var fits: bool = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= avail
		lay["name_px"] = px
		lay["name_fits"] = fits
		lay["name_avail"] = avail
		lay["name_left"] = name_left
		lay["glyph_px"] = glyph_px
		lay["trait_left"] = trait_left
		lay["name_text"] = name_text if fits else _ellipsize(font, name_text, px, avail)
	_last_layout = lay
	return lay


## Key numbers never go below 24 logical px (README phone rule).
static func _numeral_px(r: float) -> int:
	return maxi(24, int(roundf(r * 1.6)))


static func _ellipsize(font: Font, text: String, px: int, avail: float) -> String:
	var t: String = text
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > avail:
		t = t.substr(0, t.length() - 1)
	return t + "…"


# --- Drawing: frame (behind the art) ------------------------------------------------------------
func _draw() -> void:
	var k: float = _k()
	var spec: Dictionary = _frame_spec()
	var rect := Rect2(Vector2.ZERO, size)
	if highlighted:
		var hl := StyleBoxFlat.new()
		hl.draw_center = false
		hl.border_color = ArtKit.AMBER
		hl.set_border_width_all(maxi(2, roundi(3.0 * k)))
		hl.set_corner_radius_all(roundi((float(spec["radius"]) + 4.0) * k))
		hl.shadow_color = Color(ArtKit.AMBER, 0.45)
		hl.shadow_size = maxi(3, roundi(8.0 * k))
		draw_style_box(hl, rect.grow(maxf(3.0, 4.0 * k)))
	# Base frame (with its outer glow for Legend / Showcase).
	var box: StyleBoxFlat = ArtKit.frame_box(spec, size.y)
	box.draw_center = true
	box.bg_color = ArtKit.ENAMEL
	draw_style_box(box, rect)
	var b: float = float(spec["border"]) * k
	# Bevel: light along the top and left, shadow along the bottom and right.
	var lw: float = maxf(1.0, b * 0.28)
	var hi: Color = spec["hi"]
	var lo: Color = spec["lo"]
	draw_line(Vector2(b * 0.6, lw * 0.5), Vector2(size.x - b * 0.6, lw * 0.5), hi, lw, true)
	draw_line(Vector2(lw * 0.5, b * 0.6), Vector2(lw * 0.5, size.y - b * 0.6), Color(hi, 0.7), lw, true)
	draw_line(Vector2(b * 0.6, size.y - lw * 0.5), Vector2(size.x - b * 0.6, size.y - lw * 0.5), lo, lw, true)
	draw_line(Vector2(size.x - lw * 0.5, b * 0.6), Vector2(size.x - lw * 0.5, size.y - b * 0.6), Color(lo, 0.8), lw, true)
	var inlay: Color = spec["inlay"]
	if inlay.a > 0.0:
		var il := StyleBoxFlat.new()
		il.draw_center = false
		il.border_color = inlay
		il.set_border_width_all(maxi(1, roundi(b * 0.2)))
		il.set_corner_radius_all(roundi(float(spec["radius"]) * k * 0.6))
		draw_style_box(il, rect.grow(-b * 0.4))
	# Owner lacquer ring just inside the frame (re-lacquered on capture).
	var lac_w: float = maxf(ArtKit.LACQUER * k, 1.5)
	var lac := StyleBoxFlat.new()
	lac.draw_center = false
	lac.border_color = ArtKit.side_color(side) if side != &"" else Color(spec["lo"], 1.0)
	lac.set_border_width_all(maxi(1, roundi(lac_w)))
	draw_style_box(lac, rect.grow(-b))


# --- Drawing: overlay (above the art and glint) -------------------------------------------------
func _draw_overlay() -> void:
	var lay: Dictionary = _compute_layout()
	var o: Control = _overlay
	var h: float = size.y
	var inset: float = _inset()
	var art_rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if face_down:
		_draw_back(o, art_rect)
	if bool(lay["full"]):
		# Scrim under the name line for 4.5:1 text contrast over any poster.
		var top_y: float = h - inset - h * 0.3
		o.draw_polygon(PackedVector2Array([Vector2(art_rect.position.x, top_y), Vector2(art_rect.end.x, top_y),
				art_rect.end, Vector2(art_rect.position.x, art_rect.end.y)]),
				PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.78), Color(0, 0, 0, 0.78)]))
	if locked and not face_down:
		var lp: float = h * 0.36
		var lock_tex: Texture2D = ArtIcons.get_icon(&"lock", lp * _screen_scale())
		if lock_tex != null:
			o.draw_texture_rect(lock_tex, Rect2(size * 0.5 - Vector2(lp, lp) * 0.5 - Vector2(0, h * 0.06), Vector2(lp, lp)), false, Color(ArtKit.TEXT, 0.55))
	if not face_down:
		_draw_values(o, lay)
		_draw_trait(o, lay)
	_draw_clearance(o, lay)
	if bool(lay["full"]):
		_draw_name(o, lay)
	if signature:
		_draw_signature(o, lay)
	_draw_owner_tab(o)
	if preview_flip:
		_draw_preview(o)


func _draw_back(o: Control, art_rect: Rect2) -> void:
	o.draw_rect(art_rect, Color("#1C1F26"))
	var tint: Color = ArtKit.side_color(side) if side != &"" else ArtKit.NEUTRAL
	var step: float = maxf(6.0, size.y * 0.12)
	var x: float = art_rect.position.x - art_rect.size.y
	while x < art_rect.end.x:
		var a := Vector2(maxf(x, art_rect.position.x), art_rect.end.y - maxf(0.0, art_rect.position.x - x))
		var b := Vector2(minf(x + art_rect.size.y, art_rect.end.x), art_rect.position.y + maxf(0.0, x + art_rect.size.y - art_rect.end.x))
		o.draw_line(a, b, Color(tint, 0.13), maxf(1.0, size.y * 0.02), true)
		x += step
	var ep: float = size.y * 0.5
	var eye: Texture2D = ArtIcons.get_icon(&"trait_ambush", ep * _screen_scale())
	if eye != null:
		o.draw_texture_rect(eye, Rect2(size * 0.5 - Vector2(ep, ep) * 0.5, Vector2(ep, ep)), false, Color(ArtKit.TEXT, 0.85))


func _pip(o: Control, center: Vector2, r: float, value: int, bonus: int, rim: Color) -> void:
	o.draw_circle(center + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.45))
	o.draw_circle(center, r, rim)
	o.draw_circle(center, r * 0.84, ArtKit.ENAMEL)
	o.draw_arc(center, r * 0.72, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.16), maxf(1.0, r * 0.1), true)
	var font: Font = ArtKit.font_numeral()
	var px: int = _numeral_px(r)
	var text: String = str(value + bonus)
	var col: Color = ArtKit.AMBER if bonus > 0 else ArtKit.TEXT
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var asc: float = font.get_ascent(px)
	var desc: float = font.get_descent(px)
	var baseline: float = center.y + (asc - desc) * 0.5 - px * 0.04
	o.draw_string(font, Vector2(center.x - ts.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_values(o: Control, lay: Dictionary) -> void:
	var r: float = lay["r"]
	var rim: Color = _frame_spec()["base"]
	rim = rim.lightened(0.15) if rim.get_luminance() < 0.2 else rim
	if locked:
		return
	_pip(o, lay["top"], r, values.x, boost.x, rim)
	_pip(o, lay["s_left"], r, values.y, boost.y, rim)
	_pip(o, lay["s_right"], r, values.y, boost.y, rim)
	_pip(o, lay["bottom"], r, values.z, boost.z, rim)


func _draw_trait(o: Control, lay: Dictionary) -> void:
	if trait_id == &"none" or trait_id == &"":
		return
	var px: float = lay["trait_px"]
	var c: Vector2 = lay["trait_center"]
	o.draw_circle(c, px * 0.62, Color(ArtKit.ENAMEL, 0.82))
	var tex: Texture2D = ArtIcons.trait_icon(trait_id, px * _screen_scale())
	if tex != null:
		var ip: float = px * 0.8
		o.draw_texture_rect(tex, Rect2(c - Vector2(ip, ip) * 0.5, Vector2(ip, ip)), false, ArtKit.TEXT)
	if int(lay["trait_word_px"]) > 0:
		var font: Font = ArtKit.font_display()
		var wp: int = lay["trait_word_px"]
		var word: String = ArtKit.trait_name(trait_id).to_upper()
		var x: float = c.x - px * 0.62 - float(lay["gap"]) - float(lay["trait_word_w"])
		o.draw_string(font, Vector2(x, c.y + (font.get_ascent(wp) - font.get_descent(wp)) * 0.5), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, wp, ArtKit.TEXT)


func _draw_clearance(o: Control, lay: Dictionary) -> void:
	var dr: float = lay["dot_r"]
	var m: float = lay["m"]
	var right: float = size.x - m - dr * 1.5
	var y: float = m + dr * 1.6
	var spec: Dictionary = ArtKit.frame_spec(clearance)
	var fill: Color = spec["base"]
	if clearance == 4:
		fill = spec["inlay"]
	fill = fill.lightened(0.2) if fill.get_luminance() < 0.35 else fill
	for i: int in 4:
		var c := Vector2(right - i * dr * 2.8, y)
		o.draw_circle(c, dr + 1.0, Color(0, 0, 0, 0.6))
		if 3 - i < clearance:
			o.draw_circle(c, dr, fill)
		else:
			o.draw_arc(c, dr * 0.8, 0, TAU, 16, Color(ArtKit.TEXT, 0.35), maxf(1.0, dr * 0.3), true)


func _draw_name(o: Control, lay: Dictionary) -> void:
	var font: Font = ArtKit.font_display()
	var px: int = lay["name_px"]
	var gp: float = lay["glyph_px"]
	var baseline: float = size.y - float(lay["m"]) - float(lay["gap"]) - font.get_descent(px)
	var gtex: Texture2D = ArtIcons.set_icon(set_id, gp * _screen_scale())
	if gtex != null:
		var gy: float = baseline - font.get_ascent(px) * 0.5 - gp * 0.5 - px * 0.08
		o.draw_texture_rect(gtex, Rect2(Vector2(float(lay["m"]) + float(lay["gap"]), gy), Vector2(gp, gp)), false,
				Color(ArtKit.set_palette(set_id)["edge"]).lerp(ArtKit.TEXT, 0.35))
	o.draw_string(font, Vector2(lay["name_left"], baseline), lay["name_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			ArtKit.TEXT if not locked else ArtKit.TEXT_DIM)


func _draw_signature(o: Control, lay: Dictionary) -> void:
	var h: float = size.y
	var rw: float = maxf(14.0, h * 0.2)
	var rh: float = rw * 1.35
	var x: float = size.x * 0.6
	var tex: Texture2D = ArtIcons.get_icon(&"signature", rh * _screen_scale())
	o.draw_rect(Rect2(x - rw * 0.5 + 2, 2, rw, rh), Color(0, 0, 0, 0.4))
	if tex != null:
		o.draw_texture_rect(tex, Rect2(x - rh * 0.5, 0, rh, rh), false, ArtKit.SIGNATURE)


## Ownership shape cue (art-direction section 4): player = solid corner tab, rival = notched tab.
func _draw_owner_tab(o: Control) -> void:
	if side == &"":
		return
	var l: float = maxf(18.0, size.y * 0.32)
	var col: Color = ArtKit.side_color(side)
	var pts: PackedVector2Array
	if side == &"rival":
		pts = PackedVector2Array([Vector2.ZERO, Vector2(l, 0), Vector2(l * 0.66, l * 0.34), Vector2(l * 0.26, l * 0.26),
				Vector2(l * 0.34, l * 0.66), Vector2(0, l)])
	else:
		pts = PackedVector2Array([Vector2.ZERO, Vector2(l, 0), Vector2(0, l)])
	var shadow := PackedVector2Array()
	for p: Vector2 in pts:
		shadow.append(p + Vector2(1.5, 1.5))
	o.draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	o.draw_colored_polygon(pts, col)


func _draw_preview(o: Control) -> void:
	var r: float = maxf(16.0, size.y * 0.26)
	var c: Vector2 = size * 0.5
	o.draw_circle(c, r + 2.0, Color(0, 0, 0, 0.55))
	o.draw_circle(c, r, ArtKit.AMBER)
	var tex: Texture2D = ArtIcons.get_icon(&"capture_arrow", r * 1.4 * _screen_scale())
	if tex != null:
		o.draw_set_transform(c, preview_dir.angle(), Vector2.ONE)
		o.draw_texture_rect(tex, Rect2(-Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), false, ArtKit.WALL)
		o.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var xf: Transform2D = get_viewport().get_screen_transform() * get_global_transform_with_canvas()
	return maxf(1.0, maxf(absf(xf.get_scale().x), absf(xf.get_scale().y)))


# --- Input -------------------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			inspect_requested.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_t = Time.get_ticks_msec() / 1000.0
			elif _press_t >= 0.0:
				var held: float = Time.get_ticks_msec() / 1000.0 - _press_t
				_press_t = -1.0
				if held >= LONG_PRESS_S:
					inspect_requested.emit(self)
				else:
					tapped.emit(self)
				accept_event()
