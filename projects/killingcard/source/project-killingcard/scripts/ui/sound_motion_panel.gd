# sound_motion_panel.gd
# Purpose: kc-juice. Settings > SOUND · MOTION, opened from the pause sheet (pause_menu.gd): a small
#   sheet over it with
#     MASTER  slider 0-100  -> Settings.master_volume (Master bus)
#     SFX     slider 0-100  -> Settings.sfx_volume (SFX bus)
#     SCREEN SHAKE: ON/OFF  -> Settings.screen_shake (default on)
#     REDUCE MOTION: ON/OFF -> Settings.reduced_motion (+ motion_chosen: the choice is kept; until
#                              then it follows the browser's prefers-reduced-motion)
#     BACK
#   Every change is applied and saved at once (Settings.set_value). Moving the SFX slider plays a
#   click so the level can be heard. Phone sizes: text >= 16 px, toggles and BACK 64 px tall,
#   sliders 48 px.
# Dependencies: Settings autoload, hud_theme.tres variations (Scrim, HudPanelDark, HudHeader,
#   HudSubtle, HudButton), sfx_bank.gd.
# Author: Game Feel Engineer Agent (kc-juice)
extends Control

signal closed

const SfxBank: GDScript = preload("res://scripts/fx/sfx_bank.gd")

var _master: HSlider = null
var _sfx: HSlider = null
var _master_value: Label = null
var _sfx_value: Label = null
var _shake: Button = null
var _motion: Button = null
var _back: Button = null


## Opens the panel over `parent` (full rect) and returns it.
static func open_over(parent: Control) -> Control:
	var p: Control = (load("res://scripts/ui/sound_motion_panel.gd") as GDScript).new()
	p.name = "SoundMotionPanel"
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: Panel = Panel.new()
	scrim.theme_type_variation = &"Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: PanelContainer = PanelContainer.new()
	box.theme_type_variation = &"HudPanelDark"
	center.add_child(box)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	v.custom_minimum_size = Vector2(400, 0)
	box.add_child(v)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudHeader"
	title.text = "SOUND · MOTION"
	v.add_child(title)
	var st: Node = _settings()
	_master = _slider_row(v, "MASTER", "Master volume (every sound)", float(st.get(&"master_volume")) if st != null else 0.8)
	_master_value = _master.get_meta(&"value_label") as Label
	_master.value_changed.connect(func(x: float) -> void: _set_volume(&"master_volume", x, _master_value))
	_sfx = _slider_row(v, "SFX", "Sound effects volume (hits, cues, buttons)", float(st.get(&"sfx_volume")) if st != null and "sfx_volume" in st else 0.8)
	_sfx_value = _sfx.get_meta(&"value_label") as Label
	_sfx.value_changed.connect(func(x: float) -> void:
		_set_volume(&"sfx_volume", x, _sfx_value)
		SfxBank.cue(&"click"))
	_shake = _toggle(v, "Screen shake on big hits and eliminations (small, directional)")
	_shake.set_pressed_no_signal(st == null or not "screen_shake" in st or bool(st.get(&"screen_shake")))
	_shake.toggled.connect(func(on: bool) -> void:
		_apply(&"screen_shake", on)
		_update_texts())
	_motion = _toggle(v, "Reduce motion: no shake, hit-stop, flashes or travelling effects")
	_motion.set_pressed_no_signal(st != null and bool(st.get(&"reduced_motion")))
	_motion.toggled.connect(func(on: bool) -> void:
		_apply(&"motion_chosen", true)
		_apply(&"reduced_motion", on)
		_update_texts())
	_back = Button.new()
	_back.name = "BackButton"
	_back.text = "BACK"
	_back.theme_type_variation = &"HudButton"
	_back.custom_minimum_size = Vector2(0, 64)
	_back.focus_mode = Control.FOCUS_ALL
	_back.add_to_group(&"tap_target")
	_back.tooltip_text = "Back to the pause menu"
	_back.pressed.connect(close)
	v.add_child(_back)
	_update_texts()
	_back.grab_focus.call_deferred()


func _slider_row(parent: Control, caption: String, tip: String, value: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.tooltip_text = tip
	parent.add_child(row)
	var l: Label = Label.new()
	l.theme_type_variation = &"HudSubtle"
	l.text = caption
	l.custom_minimum_size = Vector2(76, 0)
	l.add_theme_font_size_override(&"font_size", 18)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.name = "%sSlider" % caption.capitalize()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.value = roundf(clampf(value, 0.0, 1.0) * 100.0)
	s.custom_minimum_size = Vector2(220, 48)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.tooltip_text = tip
	s.add_to_group(&"tap_target")
	row.add_child(s)
	var val: Label = Label.new()
	val.theme_type_variation = &"HudSubtle"
	val.add_theme_font_size_override(&"font_size", 18)
	val.custom_minimum_size = Vector2(48, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = "%d" % int(s.value)
	row.add_child(val)
	s.set_meta(&"value_label", val)
	return s


func _toggle(parent: Control, tip: String) -> Button:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.theme_type_variation = &"HudButton"
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = tip
	b.add_to_group(&"tap_target")
	parent.add_child(b)
	return b


func _update_texts() -> void:
	_shake.text = "SCREEN SHAKE: %s" % ("ON" if _shake.button_pressed else "OFF")
	_motion.text = "REDUCE MOTION: %s" % ("ON" if _motion.button_pressed else "OFF")
	# Reduced motion removes the shake anyway: say so on the shake toggle.
	_shake.disabled = _motion.button_pressed
	if _motion.button_pressed:
		_shake.text = "SCREEN SHAKE: OFF (REDUCE MOTION)"


func _set_volume(key: StringName, x: float, label: Label) -> void:
	label.text = "%d" % int(x)
	_apply(key, x / 100.0)


func _apply(key: StringName, value: Variant) -> void:
	var st: Node = _settings()
	if st != null and st.has_method(&"set_value"):
		st.set_value(key, value)


func _settings() -> Node:
	return get_node_or_null(^"/root/Settings")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func get_master_slider() -> HSlider:
	return _master


func get_sfx_slider() -> HSlider:
	return _sfx


func get_shake_button() -> Button:
	return _shake


func get_motion_button() -> Button:
	return _motion


func get_back_button() -> Button:
	return _back
