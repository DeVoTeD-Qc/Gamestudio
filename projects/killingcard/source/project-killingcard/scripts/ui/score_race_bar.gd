# score_race_bar.gd
# Purpose: kc-feedback (studio head, 17 Nov 2026: "the scoring should be at the top of the battlefield
#   area with nice clear line of progress"). The score race across the top of the board: two progress
#   bars, one per side, each filling toward the target score in the middle, one segment per point:
#       YOU 3 [#][#][#][ ][ ][ ]  TO 6  [ ][ ][ ][ ][#][#] 2 RIVAL
#   Numbers at the ends, side colours (teal / red, the rival's fill hatched so it reads without colour).
#   First to reach the middle wins. When points are scored the fill slides to its new length and a brief "+N"
#   pops beside the number, so the player sees what just scored. Original styling (the project's own
#   palette and Barlow fonts).
#   Tap, long press or right click opens the score rules (inspected): the studio inspect rule.
# Usage: bar.set_score(you, rival, target, round, true)   # animate = a "+N" pop for what just scored
# Dependencies: press_gesture.gd, hud_theme.tres (Hud friend / enemy colours).
# Author: Mechanics Developer Agent (kc-feedback)
class_name ScoreRaceBar
extends Control

signal inspected

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const LABEL_FONT: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const NUMBER_FONT: Font = preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
const FRIEND: Color = Color(0.180392, 0.768627, 0.713726)
const ENEMY: Color = Color(0.898039, 0.219608, 0.231373)
const TRACK: Color = Color(1, 1, 1, 0.10)
const FACE: Color = Color(0.07, 0.09, 0.11, 0.86)
const MUTED: Color = Color("#B9C2C9")
const AMBER: Color = Color("#FFB020")
## Seconds the fill takes to slide to a new score; the "+N" stays this long.
const FILL_S: float = 0.6
const POP_S: float = 1.6
const SEG_GAP: float = 3.0

var you: int = 0
var rival: int = 0
var target: int = 0
var round_number: int = 1
## What the bars show right now (they slide toward you / rival).
var shown: Vector2 = Vector2.ZERO
## Live "+N" pops: {side: 0 you / 1 rival, text, t}.
var pops: Array[Dictionary] = []
var _gesture: RefCounted = null
var _tween: Tween = null
var _has_score: bool = false


func _ready() -> void:
	name = "ScoreRace"
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: inspected.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspected.emit())
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if (event as InputEventMouseButton).pressed:
			inspected.emit()
		accept_event()
		return
	if _gesture.handle(event):
		accept_event()


## New score. animate: slide the fill and pop "+N" for each side that gained (a round just scored).
func set_score(p_you: int, p_rival: int, p_target: int, p_round: int = 1, animate: bool = true) -> void:
	var gained: Array[int] = [p_you - you, p_rival - rival]
	var first: bool = not _has_score
	_has_score = true
	you = p_you
	rival = p_rival
	target = p_target
	round_number = p_round
	if first or not animate or not is_inside_tree() or _reduced_motion():
		shown = Vector2(you, rival)
	else:
		for i: int in 2:
			if gained[i] > 0:
				pops.append({"side": i, "text": "+%d" % gained[i], "t": 0.0})
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "shown", Vector2(you, rival), FILL_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(queue_redraw)
		set_process(true)
	queue_redraw()


## The words the inspector and tests read: "You 3, rival 2. First to 6."
func get_text() -> String:
	if target <= 0:
		return "You %d, rival %d." % [you, rival]
	return "You %d, rival %d. First to %d." % [you, rival, target]


## Live "+N" texts (tests).
func pop_texts() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in pops:
		out.append(String(p["text"]))
	return out


func _process(delta: float) -> void:
	for p: Dictionary in pops:
		p["t"] = float(p["t"]) + delta
	pops = pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < POP_S)
	queue_redraw()
	if pops.is_empty() and (_tween == null or not _tween.is_valid()):
		set_process(false)


func _reduced_motion() -> bool:
	var s: Node = get_node_or_null(^"/root/Settings")
	return s != null and bool(s.get(&"reduced_motion"))


## Geometry, shared by _draw and the tests: one row, a tug of war toward the middle:
##   YOU 3 [#][#][#][ ][ ][ ] TO 6 [ ][ ][ ][ ][#][#] 2 RIVAL
## {bars: [Rect2 you (fills left -> right), Rect2 rival (fills right -> left)], nums: [Rect2, Rect2],
##  labels: [Rect2, Rect2], goal: Rect2}.
func layout() -> Dictionary:
	var h: float = size.y
	var fs: int = font_size()
	var nfs: int = fs + 4
	var label_w: float = ceilf(LABEL_FONT.get_string_size("RIVAL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 8.0
	var num_w: float = ceilf(NUMBER_FONT.get_string_size("00", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x) + 8.0
	var goal_w: float = ceilf(LABEL_FONT.get_string_size("TO 00", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 14.0
	var pad: float = 6.0
	var bar_h: float = maxf(6.0, roundf(h * 0.42))
	var y: float = (h - bar_h) * 0.5
	var bar_w: float = maxf(20.0, (size.x - 2.0 * (pad + label_w + num_w) - goal_w) * 0.5)
	var lx: float = pad
	var you_bar: Rect2 = Rect2(lx + label_w + num_w, y, bar_w, bar_h)
	var goal: Rect2 = Rect2(you_bar.end.x, 0.0, goal_w, h)
	var rival_bar: Rect2 = Rect2(goal.end.x, y, bar_w, bar_h)
	return {"bars": [you_bar, rival_bar], "goal": goal, "fs": fs, "nfs": nfs,
			"labels": [Rect2(lx, 0, label_w, h), Rect2(rival_bar.end.x + num_w, 0, label_w, h)],
			"nums": [Rect2(lx + label_w, 0, num_w, h), Rect2(rival_bar.end.x, 0, num_w, h)]}


func font_size() -> int:
	return clampi(int(size.y * 0.62), 15, 22)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = FACE
	sb.set_corner_radius_all(5)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	draw_style_box(sb, r)
	var g: Dictionary = layout()
	var fs: int = g["fs"]
	var nfs: int = g["nfs"]
	var names: Array[String] = ["YOU", "RIVAL"]
	var cols: Array[Color] = [FRIEND, ENEMY]
	var vals: Array[float] = [shown.x, shown.y]
	var nums: Array[int] = [you, rival]
	for i: int in 2:
		var lr: Rect2 = g["labels"][i]
		var nr: Rect2 = g["nums"][i]
		_text_c(LABEL_FONT, names[i], lr.get_center(), fs, cols[i])
		_text_c(NUMBER_FONT, str(nums[i]), nr.get_center(), nfs, Color.WHITE)
		_bar(g["bars"][i], vals[i], cols[i], i == 1)
		for p: Dictionary in pops:
			if int(p["side"]) == i:
				# "+N" rises out of the number and fades (amber: it just scored).
				var k: float = float(p["t"]) / POP_S
				var a: float = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
				var pc: Vector2 = Vector2(nr.get_center().x, nr.get_center().y + size.y * (0.9 - 0.5 * k))
				_pop_chip(String(p["text"]), pc, nfs, a)
	var goal: Rect2 = g["goal"]
	if target > 0:
		_text_c(LABEL_FONT, "TO %d" % target, goal.get_center(), fs, Color.WHITE)
	else:
		_text_c(LABEL_FONT, "R%d" % round_number, goal.get_center(), fs, MUTED)


## The "+N" chip under the number (drawn over the board's top edge so it never hides the bar).
func _pop_chip(text: String, center: Vector2, fs: int, a: float) -> void:
	var w: float = NUMBER_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
	var rr: Rect2 = Rect2(center.x - w * 0.5, center.y - fs * 0.55, w, fs * 1.1)
	draw_rect(rr, Color(0, 0, 0, 0.75 * a))
	draw_rect(rr, Color(AMBER, a), false, 1.5)
	_text_c(NUMBER_FONT, text, rr.get_center(), fs, Color(AMBER, a))


## One side's track: `target` segments (one per point), filled up to `value` (fractional while sliding),
## from the outside in.
func _bar(row: Rect2, value: float, col: Color, hatched: bool) -> void:
	var n: int = maxi(1, target)
	var seg_w: float = (row.size.x - SEG_GAP * float(n - 1)) / float(n)
	for s: int in n:
		# Yours fills left -> right, the rival's right -> left: both toward the target in the middle.
		var slot: int = s if not hatched else n - 1 - s
		var seg: Rect2 = Rect2(row.position.x + slot * (seg_w + SEG_GAP), row.position.y, seg_w, row.size.y)
		draw_rect(seg, TRACK)
		var fill: float = clampf(value - float(s), 0.0, 1.0) if target > 0 else 0.0
		if fill <= 0.0:
			continue
		var f: Rect2 = Rect2(seg.position, Vector2(seg.size.x * fill, seg.size.y))
		if hatched:
			f.position.x = seg.end.x - f.size.x
		draw_rect(f, col)
		if hatched:
			# The rival's fill carries dark diagonal hatching (readable without colour).
			var step: float = 6.0
			var x: float = f.position.x - f.size.y
			while x < f.end.x:
				var p0: Vector2 = Vector2(x, f.end.y)
				var p1: Vector2 = Vector2(x + f.size.y, f.position.y)
				var t0: float = clampf((f.position.x - x) / f.size.y, 0.0, 1.0)
				var t1: float = clampf((f.end.x - x) / f.size.y, 0.0, 1.0)
				if t1 > t0:
					draw_line(p0.lerp(p1, t0), p0.lerp(p1, t1), Color(0, 0, 0, 0.35), 1.5)
				x += step
		else:
			draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), Color(1, 1, 1, 0.35))


func _text(font: Font, text: String, left_mid: Vector2, fs: int, col: Color) -> void:
	var asc: float = font.get_ascent(fs)
	var dsc: float = font.get_descent(fs)
	draw_string(font, Vector2(left_mid.x, left_mid.y + (asc - dsc) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_c(font: Font, text: String, center: Vector2, fs: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(font, text, Vector2(center.x - w * 0.5, center.y), fs, col)
