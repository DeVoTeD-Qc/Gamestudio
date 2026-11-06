# order_strip.gd
# Purpose: The firefight order indicator (kc-fight-ui, firefight-order.md §8): a thin
#   A -> B -> C strip in the hand tray while the round plays. The column being fought is lit
#   (amber box, dark letter, a pointer under it), finished columns get a tick, columns with no
#   fight are greyed with a strike and skipped at once, the ones still to come are outlined.
#   Shapes as well as colour: filled + pointer / tick / strike / outline. "TAP TO SKIP" sits at the
#   right end (tap anywhere skips the round, PLAYBACK_TAP_TO_SKIP).
#   Display only (mouse ignored); the match screen drives it from the FeedbackDirector's events.
# Dependencies: fx_style.gd.
# Author: UI/UX Agent (kc-fight-ui)
extends Control

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const ZONES: Array[StringName] = [&"left", &"mid", &"right"]
const LETTERS: Dictionary = {&"left": "A", &"mid": "B", &"right": "C"}
const WAIT: StringName = &"wait"
const ACTIVE: StringName = &"active"
const DONE: StringName = &"done"
const SKIP: StringName = &"skip"
const BOX: Vector2 = Vector2(34, 26)

var states: Dictionary = {&"left": WAIT, &"mid": WAIT, &"right": WAIT}
var show_skip_hint: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 34)


## A new firefight: the columns in `fighting` will play, the others are skipped (greyed).
func begin(fighting: Array) -> void:
	for z: StringName in ZONES:
		states[z] = WAIT if fighting.has(z) else SKIP
	queue_redraw()


func set_active(zone: StringName) -> void:
	for z: StringName in ZONES:
		if states[z] == ACTIVE and z != zone:
			states[z] = DONE
	if states.has(zone):
		states[zone] = ACTIVE
	queue_redraw()


func set_done(zone: StringName) -> void:
	if states.has(zone):
		states[zone] = DONE
	queue_redraw()


## The firefight is over (or skipped): every column that fought is ticked.
func finish() -> void:
	for z: StringName in ZONES:
		if states[z] != SKIP:
			states[z] = DONE
	queue_redraw()


func state_of(zone: StringName) -> StringName:
	return states.get(zone, WAIT)


## "A>B>C" with the state of each ("A*" active, "A+" done, "A-" skipped, "A" waiting): tests, QA.
func describe() -> String:
	var parts: PackedStringArray = []
	for z: StringName in ZONES:
		parts.append(String(LETTERS[z]) + {WAIT: "", ACTIVE: "*", DONE: "+", SKIP: "-"}[states[z]])
	return ">".join(parts)


func _draw() -> void:
	var font: Font = FxStyle.font_for(&"heading")
	var y: float = floorf((size.y - BOX.y) * 0.5) - 2.0
	var x: float = 4.0
	for i: int in ZONES.size():
		var z: StringName = ZONES[i]
		var r: Rect2 = Rect2(Vector2(x, y), BOX)
		_draw_box(r, z, states[z], font)
		x += BOX.x
		if i < ZONES.size() - 1:
			var cy: float = y + BOX.y * 0.5
			var c: Color = Color(FxStyle.FOG, 0.7)
			draw_polyline(PackedVector2Array([Vector2(x + 7, cy - 6), Vector2(x + 13, cy), Vector2(x + 7, cy + 6)]), c, 2.0)
			x += 20.0
	if show_skip_hint:
		var hint: String = "TAP TO SKIP"
		var fs: int = 16
		var w: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if size.x - w - 6.0 > x + 8.0:
			draw_string(font, Vector2(size.x - w - 6.0, y + BOX.y * 0.5 + font.get_ascent(fs) * 0.5 - 1.0), hint,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(FxStyle.FOG, 0.6))


func _draw_box(r: Rect2, z: StringName, st: StringName, font: Font) -> void:
	var letter: String = LETTERS[z]
	var fs: int = 20
	var text_c: Color = FxStyle.FOG
	match st:
		ACTIVE:
			draw_rect(r, FxStyle.AMBER)
			text_c = FxStyle.SLATE
			# Pointer under the lit box.
			var bx: float = r.get_center().x
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, r.end.y + 1), Vector2(bx + 5, r.end.y + 1),
					Vector2(bx, r.end.y + 6)]), FxStyle.AMBER)
		DONE:
			draw_rect(r, Color(FxStyle.GUNMETAL, 0.95))
			draw_rect(r, Color(FxStyle.TEAL, 0.8), false, 1.5)
			text_c = Color(FxStyle.FOG, 0.75)
		SKIP:
			draw_rect(r, Color(FxStyle.SLATE, 0.6))
			draw_rect(r, Color(FxStyle.FOG, 0.18), false, 1.0)
			text_c = Color(FxStyle.FOG, 0.3)
		_:
			draw_rect(r, Color(FxStyle.SLATE, 0.9))
			draw_rect(r, Color(FxStyle.FOG, 0.6), false, 1.5)
	var lw: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lx: float = r.position.x + (r.size.x - lw) * 0.5 - (5.0 if st == DONE else 0.0)
	draw_string(font, Vector2(lx, r.position.y + (r.size.y + font.get_ascent(fs)) * 0.5 - 2.0), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_c)
	if st == DONE:
		var t0: Vector2 = Vector2(r.end.x - 13, r.get_center().y)
		draw_polyline(PackedVector2Array([t0, t0 + Vector2(3, 4), t0 + Vector2(9, -5)]), FxStyle.TEAL, 2.0)
	elif st == SKIP:
		draw_line(Vector2(r.position.x + 5, r.end.y - 6), Vector2(r.end.x - 5, r.position.y + 6), Color(FxStyle.FOG, 0.35), 1.5)
