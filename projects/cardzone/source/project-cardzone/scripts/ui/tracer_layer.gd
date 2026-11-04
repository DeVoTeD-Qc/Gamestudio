# tracer_layer.gd
# Purpose: Placeholder playback marks on the map (cz12), drawn over the tiles: a shot or Frag is a
#   dashed tracer line with an arrowhead from the shooter's area to the target area; a move or loot
#   outlines the area it ends in. Each mark fades out over the step's time. Static drawing (no
#   travelling motion), so it is fine under reduced motion. cz17 (game feel) replaces it: hook the
#   controller's playback_step and set `enabled = false` here.
# Usage: a child of the CzMap (full rect, ignores the mouse). show_step(step, seconds).
# Dependencies: CzMap / CzAreaTile (tile rects), match_theme.gd colours.
# Author: UI/UX Agent (cz12)
extends Control

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MIN_TIME: float = 0.35

var enabled: bool = true
## The current mark: {kind, from, to} ({} = nothing).
var mark: Dictionary = {}

var _map: Control
var _tween: Tween


func _init() -> void:
	name = "TracerLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_map = get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Shows the mark for a playback step ({kind, from, to}) for about `seconds`.
func show_step(step: Dictionary, seconds: float) -> void:
	if not enabled:
		return
	var kind: StringName = StringName(step.get("kind", &""))
	var to: StringName = StringName(step.get("to", &""))
	if to == &"" or not kind in [&"shot", &"move", &"loot"]:
		return
	mark = {"kind": kind, "from": StringName(step.get("from", &"")), "to": to}
	modulate.a = 1.0
	queue_redraw()
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	var t: float = maxf(MIN_TIME, seconds)
	_tween.tween_interval(t * 0.6)
	_tween.tween_property(self, "modulate:a", 0.0, t * 0.4)
	_tween.tween_callback(clear)


func clear() -> void:
	mark = {}
	queue_redraw()


func _tile_rect(id: StringName) -> Rect2:
	if _map == null or not _map.has_method(&"tile"):
		return Rect2()
	var t: Control = _map.call("tile", id)
	if t == null:
		return Rect2()
	return Rect2(t.global_position - global_position, t.size)


func _draw() -> void:
	if mark.is_empty():
		return
	var to: Rect2 = _tile_rect(mark["to"])
	if not to.has_area():
		return
	if mark["kind"] == &"shot":
		var from: Rect2 = _tile_rect(mark["from"])
		var a: Vector2 = from.get_center() if from.has_area() else to.get_center()
		var b: Vector2 = to.get_center()
		draw_rect(to.grow(-3.0), MatchTheme.HIT_RED, false, 4.0)
		if a.distance_to(b) < 4.0:
			return
		draw_dashed_line(a, b, MatchTheme.HIT_RED, 5.0, 12.0)
		var dir: Vector2 = (b - a).normalized()
		var tip: Vector2 = b - dir * 18.0
		var side: Vector2 = dir.orthogonal() * 10.0
		draw_colored_polygon(PackedVector2Array([tip + dir * 14.0, tip + side, tip - side]), MatchTheme.HIT_RED)
		draw_circle(a, 7.0, MatchTheme.HIT_RED)
	else:
		draw_rect(to.grow(-3.0), MatchTheme.PAPER, false, 4.0)
		var from_m: Rect2 = _tile_rect(mark["from"])
		if mark["kind"] == &"move" and from_m.has_area():
			draw_dashed_line(from_m.get_center(), to.get_center(), Color(MatchTheme.PAPER, 0.85), 3.0, 8.0)
