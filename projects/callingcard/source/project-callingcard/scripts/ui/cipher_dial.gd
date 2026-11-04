# cipher_dial.gd
# Purpose: One brass dial of the Cipher Lock (cc11, art-direction section 5). Shows one of the
#   four original glyphs (ArtIcons.cipher_glyph) - the glyph only, never its number, so the
#   player has to find each glyph in the card art. Turn it with the up / down keys (64 px), a tap
#   on the face (next glyph), or the arrow keys while the face has focus. Glyphs differ by shape,
#   not colour.
# Dependencies: ArtIcons (cc14). Theme variations DialButton, DialFace, Caption (album_theme.gd).
# Author: UI/UX Agent (cc11)
extends VBoxContainer

signal value_changed(dial_index: int, value: int)

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI"]

var dial_index: int = 0
var glyph_count: int = 4
var value: int = 1
var locked: bool = false

var _up: Button
var _face: Button
var _down: Button
var _glyph: TextureRect
var _caption: Label


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_up = _arrow_button("Up", true)
	_face = Button.new()
	_face.name = "Face"
	_face.theme_type_variation = &"DialFace"
	_face.focus_mode = Control.FOCUS_ALL
	_face.add_to_group(&"tap_target")
	add_child(_face)
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.add_child(_glyph)
	_down = _arrow_button("Down", false)
	_caption = Label.new()
	_caption.name = "DialCaption"
	_caption.theme_type_variation = &"Caption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_caption)
	_up.pressed.connect(func() -> void: turn(1))
	_down.pressed.connect(func() -> void: turn(-1))
	_face.pressed.connect(func() -> void: turn(1))
	_face.gui_input.connect(_on_face_input)


## index: 0-based dial position; start: the glyph shown first (1..glyphs).
func setup(index: int, glyphs: int, start: int) -> void:
	dial_index = index
	glyph_count = maxi(glyphs, 1)
	name = "Dial%d" % (index + 1)
	_caption.text = "Dial %s" % ROMAN[clampi(index, 0, ROMAN.size() - 1)]
	set_value(start, false)


## Face size in logical px (arrow keys stay >= 64 px).
func set_face_size(px: float) -> void:
	var s: float = maxf(px, 64.0)
	_face.custom_minimum_size = Vector2(s, s)
	_up.custom_minimum_size = Vector2(s, 64)
	_down.custom_minimum_size = Vector2(s, 64)
	var inset: float = roundf(s * 0.16)
	_glyph.offset_left = inset
	_glyph.offset_top = inset
	_glyph.offset_right = -inset
	_glyph.offset_bottom = -inset
	_glyph.texture = ArtIcons.cipher_glyph(value, (s - 2.0 * inset) * 3.0)


func set_value(v: int, notify: bool = true) -> void:
	value = wrapi(v - 1, 0, glyph_count) + 1
	var px: float = maxf(_face.custom_minimum_size.x, 64.0)
	_glyph.texture = ArtIcons.cipher_glyph(value, px * 3.0)
	if notify:
		value_changed.emit(dial_index, value)


func turn(step: int) -> void:
	if locked:
		return
	set_value(value + step)


func set_locked(v: bool) -> void:
	locked = v
	for b: Button in [_up, _down, _face]:
		b.disabled = v
	_face.focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL


## Tint used for the open / wrong feedback (the face stays brass otherwise).
func flash(col: Color) -> void:
	_glyph.modulate = col


func get_face() -> Button:
	return _face


func get_up() -> Button:
	return _up


func get_down() -> Button:
	return _down


func _on_face_input(event: InputEvent) -> void:
	if locked:
		return
	if event.is_action_pressed(&"ui_up", true):
		turn(1)
		_face.accept_event()
	elif event.is_action_pressed(&"ui_down", true):
		turn(-1)
		_face.accept_event()


func _arrow_button(n: String, up: bool) -> Button:
	var b := Button.new()
	b.name = n
	b.theme_type_variation = &"DialButton"
	b.focus_mode = Control.FOCUS_NONE  # the face takes focus; arrows keys turn it
	b.add_to_group(&"tap_target")
	add_child(b)
	var chevron := Control.new()
	chevron.name = "Chevron"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(chevron)
	chevron.draw.connect(func() -> void:
		var c: Vector2 = chevron.size * 0.5
		var w: float = minf(chevron.size.x, chevron.size.y) * 0.32
		var d: float = -1.0 if up else 1.0
		var col: Color = Color("#F0CE84") if not b.disabled else Color("#F0CE84", 0.35)
		chevron.draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -d * w * 0.45), c + Vector2(w, -d * w * 0.45),
				c + Vector2(0, d * w * 0.55)]), col))
	return b
