# call_in_takeover.gd
# Purpose: Killstreak call-in takeover (art direction "Motion & feedback": 0.8 s full-screen
#   tablet takeover with cyan scanlines and a radio callout, then the effect plays).
#   The screen dims, a full-width band opens from its centre line, shows
#   "UPLINK // CALL-IN", the killstreak icon and name, and an original radio line, then closes.
#   An enemy call-in uses Hostile Red, says "HOSTILE UPLINK" and carries hazard ticks, so it
#   reads without colour. Reduced motion: it cross-fades and the scanlines stand still.
#   Fast animations: half length. Hidden and idle between call-ins; one instance is reused.
# Scene: res://scenes/fx/CallInTakeover.tscn (full-rect Control, mouse ignored).
# Dependencies: fx_style.gd, fx_timing.gd, assets/shaders/scanlines.gdshader, IconSheet.
# Author: Game Feel Engineer Agent (p14)
extends Control

signal call_in_finished

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const SCANLINES: Shader = preload("res://assets/shaders/scanlines.gdshader")

## Killstreak id -> icon sheet name.
const ICONS: Dictionary = {
	&"recon_drone": &"ks_recon_drone", &"mortar_barrage": &"ks_mortar", &"sentry_turret": &"ks_sentry",
	&"attack_helo": &"ks_attack_helo", &"gunship": &"ks_gunship",
}
## Original radio lines; {zone} is the zone label. Unknown ids use DEFAULT_LINE.
const LINES: Dictionary = {
	&"recon_drone": "Recon drone up. Eyes on {zone}.",
	&"mortar_barrage": "Fire mission, {zone}. Rounds inbound.",
	&"sentry_turret": "Sentry online, covering {zone}.",
	&"attack_helo": "Helo on station over {zone}.",
	&"gunship": "Gunship overhead. Weapons free.",
}
const DEFAULT_LINE: String = "Uplink confirmed. Stand by."
const ENEMY_LINE: String = "Hostile {name} inbound on {zone}. Take cover."

## Seconds the current call-in lasts (after timing options).
var duration: float = 0.0
var last_data: Dictionary = {}

var _dim: ColorRect
var _band: Control
var _band_bg: ColorRect
var _lines: ColorRect
var _caption: Label
var _icon: TextureRect
var _name: Label
var _callout: Label
var _tween: Tween = null
var _accent: Color = FxStyle.CYAN
var _hostile: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	resized.connect(_layout)


## Shows a call-in. data: {item_id, name, side, zone}. Returns its length in seconds.
func show_call_in(data: Dictionary, timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	last_data = data
	finish_quietly()
	var item_id: StringName = data.get("item_id", &"")
	_hostile = data.get("side", &"player") != &"player"
	_accent = FxStyle.RED if _hostile else FxStyle.CYAN
	var zone: String = _zone_label(data.get("zone", &""))
	var ks_name: String = String(data.get("name", String(item_id).replace("_", " "))).to_upper()
	_caption.text = "HOSTILE UPLINK // CALL-IN" if _hostile else "UPLINK // CALL-IN"
	_name.text = ks_name
	if _hostile:
		_callout.text = ENEMY_LINE.format({"name": ks_name.to_lower(), "zone": zone})
	else:
		_callout.text = String(LINES.get(item_id, DEFAULT_LINE)).format({"zone": zone})
	var icon_name: StringName = ICONS.get(item_id, &"type_killstreak")
	_icon.texture = IconSheet.get_icon(icon_name) if IconSheet.has_icon(icon_name) else null
	_icon.modulate = _accent
	_caption.add_theme_color_override(&"font_color", _accent)
	var mat: ShaderMaterial = _lines.material as ShaderMaterial
	mat.set_shader_parameter(&"line_color", Color(_accent, 0.2))
	mat.set_shader_parameter(&"scroll_speed", 0.0 if timing.reduced_motion else 0.6)
	_band_bg.color = Color(FxStyle.SLATE.lerp(_accent, 0.12), 0.94)
	_band.queue_redraw()

	duration = maxf(0.1, timing.get_value(&"takeover"))
	var t_in: float = minf(timing.get_value(&"takeover_in"), duration * 0.3)
	var t_out: float = minf(timing.get_value(&"takeover_out"), duration * 0.3)
	var hold: float = maxf(0.0, duration - t_in - t_out)
	visible = true
	_layout()
	modulate.a = 1.0
	_tween = create_tween()
	if timing.reduced_motion:
		modulate.a = 0.0
		_band.scale = Vector2.ONE
		_tween.tween_property(self, ^"modulate:a", 1.0, t_in)
		_tween.tween_interval(hold)
		_tween.tween_property(self, ^"modulate:a", 0.0, t_out)
	else:
		_dim.modulate.a = 0.0
		_band.scale = Vector2(1.0, 0.04)
		_tween.set_parallel(true)
		_tween.tween_property(_dim, ^"modulate:a", 1.0, t_in)
		_tween.tween_property(_band, ^"scale:y", 1.0, t_in).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tween.set_parallel(false)
		_tween.tween_interval(hold)
		_tween.set_parallel(true)
		_tween.tween_property(_band, ^"scale:y", 0.0, t_out).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_tween.tween_property(_dim, ^"modulate:a", 0.0, t_out)
		_tween.set_parallel(false)
	_tween.tween_callback(_on_done)
	return duration


func is_showing() -> bool:
	return visible and _tween != null and _tween.is_valid() and _tween.is_running()


## Ends the call-in now (fast-forward); emits call_in_finished.
func finish() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.custom_step(60.0)
	visible = false


func finish_quietly() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false


func _on_done() -> void:
	visible = false
	call_in_finished.emit()


func _zone_label(zone: StringName) -> String:
	return String(zone).capitalize() if zone != &"" else "the line"


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(FxStyle.SLATE, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.draw.connect(_draw_band_frame)
	add_child(_band)
	_band_bg = ColorRect.new()
	_band_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_band_bg)
	_band_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines = ColorRect.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SCANLINES
	mat.set_shader_parameter(&"line_count", 60.0)
	_lines.material = mat
	_band.add_child(_lines)
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	_band.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = FxStyle.make_label("", &"numeric", 20, FxStyle.CYAN, 4)
	column.add_child(_caption)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override(&"separation", 14)
	column.add_child(title_row)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_icon)
	_name = FxStyle.make_label("", &"heading", 52, FxStyle.FOG, 8)
	title_row.add_child(_name)
	_callout = FxStyle.make_label("", &"body", 20, FxStyle.FOG, 4)
	column.add_child(_callout)


func _layout() -> void:
	if _band == null:
		return
	var h: float = clampf(size.y * 0.34, 150.0, 240.0)
	_band.position = Vector2(0, (size.y - h) * 0.5)
	_band.size = Vector2(size.x, h)
	_band.pivot_offset = Vector2(size.x * 0.5, h * 0.5)


func _draw_band_frame() -> void:
	var s: Vector2 = _band.size
	var c: Color = _accent
	_band.draw_line(Vector2(0, 1), Vector2(s.x, 1), c, 2.0)
	_band.draw_line(Vector2(0, s.y - 1), Vector2(s.x, s.y - 1), c, 2.0)
	# Tablet corner brackets, inset from the screen edge.
	var inset: Vector2 = Vector2(maxf(24.0, s.x * 0.12), 14.0)
	var arm: float = 26.0
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner: Vector2 = Vector2(s.x * 0.5 + sx * (s.x * 0.5 - inset.x), s.y * 0.5 + sy * (s.y * 0.5 - inset.y))
			_band.draw_polyline(PackedVector2Array([corner - Vector2(sx * arm, 0), corner, corner - Vector2(0, sy * arm)]), c, 3.0)
	if _hostile:
		for i: int in 6:
			var x: float = 12.0 + i * 12.0
			_band.draw_line(Vector2(x, s.y - 4), Vector2(x + 8, 4), Color(c, 0.6), 3.0)
			_band.draw_line(Vector2(s.x - x, 4), Vector2(s.x - x - 8, s.y - 4), Color(c, 0.6), 3.0)
