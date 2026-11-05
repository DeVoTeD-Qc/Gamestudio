# art_underlay.gd
# Purpose: Painted card art behind a small card view (k-art4): hand chips, unit slots on the board,
#   mulligan buttons. The art covers the control (cropped, aspect kept), optionally mirrored for
#   the enemy, under a vertical slate scrim so the text and numbers on top stay readable. Side
#   colour never goes into the art: the frame / tab of the view says whose it is.
#   The texture comes from CardArt.card_texture() (the shipped WebP, or the procedural SVG when the
#   image is missing), requested at the size the control covers on screen (scale-bucketed), so it
#   shares CardArt's decode / Lanczos-downscale cache with every other view of the same card.
# Usage:
#   var art := ArtUnderlay.new()
#   art.set_art(&"rifleman", ArtUnderlay.SCRIM_CHIP, flip_for_enemy)
#   panel.add_child(art); panel.move_child(art, 0)      # first child = drawn first
# Dependencies: card_art.gd
# Author: Technical Artist Agent (k-art4)
class_name ArtUnderlay
extends Control

## Scrim profiles: [offset, alpha] stops, top to bottom (slate #12161A).
## Hand chip art band (under the name): a soft top edge, then the art nearly clear (keywords and
## stats on it have their own plates).
const SCRIM_CHIP: StringName = &"chip"
## Unit slot: tab and name at the top, stats (on plates) at the bottom.
const SCRIM_SLOT: StringName = &"slot"
## Mulligan button: two centred text lines.
const SCRIM_BUTTON: StringName = &"button"
const SCRIMS: Dictionary = {
	&"chip": [[0.0, 0.45], [0.30, 0.08], [1.0, 0.22]],
	&"slot": [[0.0, 0.66], [0.30, 0.22], [0.66, 0.28], [1.0, 0.76]],
	&"button": [[0.0, 0.62], [0.5, 0.72], [1.0, 0.62]],
}
const SLATE: Color = Color(0.0705882, 0.0862745, 0.101961)
## Art is 1.63:1; a control is covered by height when it is narrower than that.
const ART_ASPECT: float = 1.6324

## Off: no small view shows art (each keeps its pre-art look: silhouette, rules line, plain
## button). Tests compare against it; also a kill switch.
static var enabled: bool = true
static var _scrim_textures: Dictionary = {}

var art_key: StringName = &""
var flip: bool = false
var _scale: float = 0.0
var _art: TextureRect
var _scrim: TextureRect


func _init() -> void:
	name = "ArtUnderlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_scrim = TextureRect.new()
	_scrim.name = "Scrim"
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	for c: Control in [_art, _scrim]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_update_texture)


## Card art key (CardArt.card_key / a card id); &"" or an unknown key hides the underlay.
func set_art(key: StringName, scrim: StringName = SCRIM_CHIP, mirrored: bool = false) -> void:
	art_key = key if enabled and key != &"" and CardArt.has_card(key) else &""
	flip = mirrored
	_art.flip_h = mirrored
	_scrim.texture = scrim_texture(scrim)
	visible = art_key != &""
	_scale = 0.0
	_update_texture()


func has_art() -> bool:
	return art_key != &"" and _art.texture != null


func get_art_texture() -> Texture2D:
	return _art.texture


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_update_texture.call_deferred()


## Requests the art at the pixel width the cover crop needs on screen (bucketed, cached).
func _update_texture() -> void:
	if art_key == &"" or not is_inside_tree():
		return
	var cover_w: float = maxf(size.x, size.y * ART_ASPECT)
	if cover_w <= 0.0:
		return
	var s: float = CardArt.bucket(CardArt.screen_scale(self) * cover_w / CardArt.Data.CARD_SIZE.x)
	if is_equal_approx(s, _scale):
		return
	_scale = s
	_art.texture = CardArt.card_texture(art_key, s)


## Vertical slate gradient for a scrim profile (built once, shared).
static func scrim_texture(profile: StringName) -> Texture2D:
	if _scrim_textures.has(profile):
		return _scrim_textures[profile]
	var g := Gradient.new()
	var stops: Array = SCRIMS.get(profile, SCRIMS[SCRIM_CHIP])
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return Color(SLATE, s[1])))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = 64
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	_scrim_textures[profile] = tex
	return tex


## Dark rounded plate drawn behind a stat / tab (StyleBoxFlat, shared per colour).
static func plate(color: Color = Color(SLATE, 0.86), radius: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


## Slate outline on a label over art (kept thin so small text stays crisp).
static func outline(label: Label, px: int = 4) -> void:
	label.add_theme_color_override(&"font_outline_color", Color(SLATE, 0.9))
	label.add_theme_constant_override(&"outline_size", px)
