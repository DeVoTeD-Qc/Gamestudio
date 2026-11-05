# killfeed_entry.gd
# Purpose: One killfeed line, right-aligned:
#   [side marker] ATTACKER [source icon] VICTIM [ZONE]
#   Side marker: friendly = teal chevron notch, enemy = red hazard stripes (colour-blind safe,
#   art direction). Names in Share Tech Mono via the theme's KillfeedFriend / KillfeedEnemy
#   variations, each in its own side's colour. Killstreak kills show the killstreak icon in
#   Uplink Cyan. A dark strip with a side-coloured edge sits behind the text.
#   Enters by sliding in 28 px from the right and fading in, lives `feed_life`, then fades.
# Dependencies: fx_style.gd, fx_timing.gd, icon_sheet.gd (IconSheet), hud_theme.tres variations.
# Author: Game Feel Engineer Agent (p14)
extends Control

signal expired

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const ROW_HEIGHT: float = 22.0
const MAX_NAME: int = 14
const ENTER_OFFSET: float = 28.0

## {attacker, attacker_side, victim, victim_side, icon (IconSheet name), zone, killstreak}
var entry: Dictionary = {}
## Life and fade lengths after timing options (seconds), set by start().
var life: float = 0.0
## kc-board2 toasts: the row is centred in the line (set before setup()).
var centered: bool = false

var _row: HBoxContainer = null
var _enter: Tween = null
var _life_tween: Tween = null
var _gone: bool = false
var _zone_tag: Label = null


class SideMarker:
	extends Control
	var friendly: bool = true

	func _draw() -> void:
		var h: float = size.y
		if friendly:
			var c: Color = FxStyle.TEAL
			draw_colored_polygon(PackedVector2Array([Vector2(1, 3), Vector2(7, 3), Vector2(13, h * 0.5),
					Vector2(7, h - 3), Vector2(1, h - 3), Vector2(7, h * 0.5)]), c)
		else:
			var c: Color = FxStyle.RED
			draw_rect(Rect2(1, 3, 12, h - 6), Color(c, 0.35))
			for i: int in 3:
				var x: float = 1.0 + i * 5.0
				draw_line(Vector2(x, h - 3), Vector2(x + 6.0, 3), c, 2.5)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## Builds the line from `data` (see `entry`). Call before adding to the tree.
func setup(data: Dictionary) -> void:
	entry = data
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER if centered else BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override(&"separation", 6)
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_right = -6.0
	var attacker_side: StringName = data.get("attacker_side", &"player")
	var victim_side: StringName = data.get("victim_side", &"enemy")
	var marker: SideMarker = SideMarker.new()
	marker.friendly = attacker_side == &"player"
	marker.custom_minimum_size = Vector2(14, ROW_HEIGHT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(marker)
	_row.add_child(_name_label(String(data.get("attacker", "")), attacker_side))
	var icon_name: StringName = data.get("icon", &"")
	if icon_name != &"" and IconSheet.has_icon(icon_name):
		var icon: TextureRect = TextureRect.new()
		icon.texture = IconSheet.get_icon(icon_name)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = FxStyle.CYAN if data.get("killstreak", false) else FxStyle.FOG
		_row.add_child(icon)
	_row.add_child(_name_label(String(data.get("victim", "")), victim_side))
	var zone: String = String(data.get("zone", "")).to_upper()
	if zone != "":
		var tag: Label = Label.new()
		tag.theme_type_variation = &"HudTag"
		tag.text = zone
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(tag)
		_zone_tag = tag
	resized.connect(_fit)


## Starts enter + life + fade. timing: FxTiming (null = Settings). life_scale shortens the life
## (phone layout, f04); a negative life_scale keeps the line until it is pushed out (tray log).
func start(timing: RefCounted = null, life_scale: float = 1.0) -> void:
	if timing == null:
		timing = FxTiming.from_settings()
	var enter: float = maxf(0.01, timing.get_value(&"feed_enter"))
	life = timing.get_value(&"feed_life") * life_scale
	var fade: float = maxf(0.01, timing.get_value(&"feed_fade"))
	modulate.a = 0.0
	_enter = create_tween().set_parallel(true)
	_enter.tween_property(self, ^"modulate:a", 1.0, enter)
	if not timing.reduced_motion:
		_row.position.x = ENTER_OFFSET
		_enter.tween_property(_row, ^"position:x", 0.0, enter).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if life_scale < 0.0:
		life = INF
		return
	_life_tween = create_tween()
	_life_tween.tween_interval(enter + life)
	_life_tween.tween_property(self, ^"modulate:a", 0.0, fade)
	_life_tween.finished.connect(_expire)


## Skip the enter animation (fast-forward); the line keeps its remaining life.
func finish_enter() -> void:
	if _enter != null and _enter.is_valid():
		_enter.custom_step(10.0)


## Removes the line at once.
func expire_now() -> void:
	if _life_tween != null and _life_tween.is_valid():
		_life_tween.kill()
	_expire()


func _expire() -> void:
	if _gone:
		return
	_gone = true
	expired.emit()
	queue_free()


## Narrow slots (phone killfeed): drop the zone tag first, then shorten the names, so the
## line never runs off its rect.
func _fit() -> void:
	if _row == null or size.x <= 0.0:
		return
	var room: float = size.x - 12.0
	# Start from the full names each time: a line laid out narrow first (before its slot got its
	# final width) must grow back (bug p18-005).
	for child: Node in _row.get_children():
		if child is Label and child != _zone_tag and child.has_meta(&"full"):
			(child as Label).text = String(child.get_meta(&"full"))
	if _zone_tag != null:
		_zone_tag.visible = true
		if _row.get_combined_minimum_size().x > room:
			_zone_tag.visible = false
	for limit: int in [MAX_NAME, 10, 8, 6]:
		if _row.get_combined_minimum_size().x <= room:
			break
		for child: Node in _row.get_children():
			if child is Label and child != _zone_tag:
				var full: String = String(child.get_meta(&"full", (child as Label).text))
				child.set_meta(&"full", full)
				(child as Label).text = full.left(limit)
	queue_redraw()


func _name_label(text: String, side: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"KillfeedFriend" if side == &"player" else &"KillfeedEnemy"
	label.text = text.to_upper().left(MAX_NAME)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _draw() -> void:
	if _row == null:
		return
	var right: float = _row.position.x + _row.size.x
	var x: float = maxf(0.0, right - _row.get_combined_minimum_size().x - 10.0)
	var end: float = size.x
	if centered:
		var w: float = _row.get_combined_minimum_size().x + 16.0
		x = maxf(0.0, _row.position.x + (_row.size.x - w) * 0.5)
		end = minf(size.x, x + w)
	var friendly: bool = entry.get("attacker_side", &"player") == &"player"
	draw_rect(Rect2(x, 1, end - x, size.y - 2), Color(FxStyle.GUNMETAL, 0.92))
	draw_rect(Rect2(x, 1, 2, size.y - 2), FxStyle.side_color(&"player" if friendly else &"enemy"))


func _process(_delta: float) -> void:
	# Keep the strip under the sliding row during the enter animation only.
	if _enter != null and _enter.is_valid() and _enter.is_running():
		queue_redraw()
