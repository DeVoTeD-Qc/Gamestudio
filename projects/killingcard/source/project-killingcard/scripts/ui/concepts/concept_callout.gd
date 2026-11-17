# concept_callout.gd
# Purpose: kc-ui-pass: one "explain once" callout (ConceptGuide shows it). A small bubble with the
#   concept's title, 1-2 plain sentences, GOT IT and TIPS OFF, anchored beside the thing it explains
#   (an amber ring around it, a soft dim elsewhere). Placement never covers the target or the
#   `avoid` rects (READY ...) when the screen has room anywhere else.
#   Input (head: "an overlay made me press Ready by accident"): while it is up it SWALLOWS every
#   pointer and key event in _input (it is the last node under the root, so it sees them first):
#   nothing reaches the game. A release anywhere dismisses it, but only for a press that began while
#   it was up and after ARM_S (a tap already on its way, or a double tap, never dismisses and
#   never passes through). After it closes it keeps swallowing for LINGER_S so the rest of that tap
#   (touch + its emulated mouse events) never lands on what is under it.
# Dependencies: hud_theme.tres (fonts / colours via the Hud types).
# Author: UI/UX Agent (kc-ui-pass)
extends Control

signal dismissed(tips_off: bool)

const AMBER: Color = Color("#FFB020")
const INK: Color = Color("#F2F5F7")
const FACE: Color = Color("#1B2127")
const DIM: Color = Color(0.0, 0.0, 0.0, 0.42)
## A press must start this long after the callout appeared to count (no accidental double tap).
const ARM_S: float = 0.35
## After closing, pointer events are still eaten this long (the rest of the dismissing tap).
const LINGER_S: float = 0.3
const GAP: float = 14.0
const MARGIN: float = 12.0
const TITLE_FONT: Font = preload("res://assets/fonts/Barlow-Medium.ttf")

var concept: Dictionary = {}
## Target rect (canvas px). Empty = no target (the bubble is centred).
var target: Rect2 = Rect2()
var avoid: Array[Rect2] = []
var age: float = 0.0
var closing: bool = false
var _linger: float = 0.0
var _armed: bool = false
var _bubble: PanelContainer = null
var _title: Label = null
var _body: Label = null
var _got_it: Button = null
var _tips_off: Button = null
var _placed: bool = false


func _init() -> void:
	name = "ConceptCallout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://assets/ui/hud_theme.tres")


func setup(p_concept: Dictionary, p_target: Rect2, p_avoid: Array[Rect2] = []) -> void:
	concept = p_concept
	target = p_target
	avoid = p_avoid


func _ready() -> void:
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = FACE
	sb.border_color = AMBER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	_bubble.add_theme_stylebox_override(&"panel", sb)
	add_child(_bubble)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	_bubble.add_child(box)
	_title = Label.new()
	_title.name = "Title"
	_title.text = String(concept.get("title", "")).to_upper()
	_title.add_theme_font_override(&"font", TITLE_FONT)
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", AMBER)
	box.add_child(_title)
	_body = Label.new()
	_body.name = "Body"
	_body.text = String(concept.get("text", ""))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override(&"font_size", 19)
	_body.add_theme_color_override(&"font_color", INK)
	box.add_child(_body)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	_tips_off = Button.new()
	_tips_off.name = "TipsOff"
	_tips_off.text = "TIPS OFF"
	_tips_off.theme_type_variation = &"HudButton"
	_tips_off.custom_minimum_size = Vector2(120, 60)
	_tips_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tips_off.focus_mode = Control.FOCUS_NONE
	row.add_child(_tips_off)
	var hint := Label.new()
	hint.text = "tap anywhere"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 16)
	hint.add_theme_color_override(&"font_color", Color("#A3ADB5"))
	row.add_child(hint)
	_got_it = Button.new()
	_got_it.name = "GotIt"
	_got_it.text = "GOT IT"
	_got_it.theme_type_variation = &"ReadyButton"
	_got_it.custom_minimum_size = Vector2(150, 60)
	_got_it.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_got_it.focus_mode = Control.FOCUS_NONE
	row.add_child(_got_it)
	modulate.a = 0.0
	_place.call_deferred()


func bubble_width() -> float:
	var vw: float = get_viewport_rect().size.x
	return clampf(vw * 0.4, minf(380.0, vw - 2.0 * MARGIN), 470.0)


## Puts the bubble on the side of the target with room, off the target and the avoid rects.
func _place() -> void:
	var w: float = bubble_width()
	_body.custom_minimum_size.x = w - 28.0
	_bubble.size = Vector2(w, 0)
	_bubble.reset_size()
	var bs: Vector2 = Vector2(w, _bubble.get_combined_minimum_size().y)
	_bubble.size = bs
	_bubble.position = best_position(bs, get_viewport_rect().size, target, avoid)
	_placed = true
	queue_redraw()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


## Pure placement (tests): the candidate beside the target (below, above, right, left; centred on
## it, clamped to the screen) that overlaps the target and the avoid rects least.
static func best_position(bs: Vector2, view: Vector2, tgt: Rect2, avoid_rects: Array[Rect2]) -> Vector2:
	var screen: Rect2 = Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2.0)
	if tgt.size == Vector2.ZERO:
		return ((view - bs) * 0.5).round()
	var c: Vector2 = tgt.get_center()
	var cands: Array[Vector2] = [
		Vector2(c.x - bs.x * 0.5, tgt.end.y + GAP),
		Vector2(c.x - bs.x * 0.5, tgt.position.y - GAP - bs.y),
		Vector2(tgt.end.x + GAP, c.y - bs.y * 0.5),
		Vector2(tgt.position.x - GAP - bs.x, c.y - bs.y * 0.5),
	]
	# Corners of the screen as a last resort (a target that fills most of it).
	cands.append(screen.position)
	cands.append(Vector2(screen.end.x - bs.x, screen.position.y))
	cands.append(Vector2(screen.position.x, screen.end.y - bs.y))
	cands.append(screen.end - bs)
	var best: Vector2 = cands[0]
	var best_cost: float = INF
	for i: int in cands.size():
		var raw: Vector2 = cands[i]
		var p: Vector2 = Vector2(clampf(raw.x, screen.position.x, maxf(screen.position.x, screen.end.x - bs.x)),
				clampf(raw.y, screen.position.y, maxf(screen.position.y, screen.end.y - bs.y)))
		var r: Rect2 = Rect2(p, bs)
		var cost: float = _overlap(r, tgt.grow(4.0)) * 4.0
		for a: Rect2 in avoid_rects:
			cost += _overlap(r, a) * 2.0
		cost += raw.distance_to(p) * 0.5 + float(i) * 0.01  # prefer the unclamped, earlier sides
		if cost < best_cost:
			best_cost = cost
			best = p
	return best.round()


static func _overlap(a: Rect2, b: Rect2) -> float:
	var i: Rect2 = a.intersection(b)
	return i.get_area() if a.intersects(b) else 0.0


func bubble_rect() -> Rect2:
	return _bubble.get_global_rect() if _bubble != null else Rect2()


func get_got_it() -> Button:
	return _got_it


func get_tips_off() -> Button:
	return _tips_off


func _process(delta: float) -> void:
	age += delta
	if closing:
		_linger -= delta
		if _linger <= 0.0:
			queue_free()


func _draw() -> void:
	if closing or not _placed:
		return
	var vr: Rect2 = Rect2(Vector2.ZERO, size)
	if target.size == Vector2.ZERO:
		draw_rect(vr, DIM)
		return
	var hole: Rect2 = target.grow(6.0).intersection(vr)
	# The dim around the hole (4 rects), then the ring.
	draw_rect(Rect2(0, 0, vr.size.x, hole.position.y), DIM)
	draw_rect(Rect2(0, hole.end.y, vr.size.x, vr.size.y - hole.end.y), DIM)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM)
	draw_rect(Rect2(hole.end.x, hole.position.y, vr.size.x - hole.end.x, hole.size.y), DIM)
	draw_rect(hole, AMBER, false, 3.0)
	# A short pointer from the bubble's nearest edge to the ring.
	var b: Rect2 = bubble_rect()
	var from: Vector2 = Vector2(clampf(hole.get_center().x, b.position.x + 12, b.end.x - 12), clampf(hole.get_center().y, b.position.y + 12, b.end.y - 12))
	var to: Vector2 = Vector2(clampf(from.x, hole.position.x, hole.end.x), clampf(from.y, hole.position.y, hole.end.y))
	if from.distance_to(to) > 4.0:
		draw_line(from, to, AMBER, 2.0)
		draw_circle(to, 4.0, AMBER)


## Every pointer / key event stops here while the callout is up (and for LINGER_S after).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).button_mask != 0:
			get_viewport().set_input_as_handled()
		return
	var pointer: bool = event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag
	if not pointer and not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	if closing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		_pointer(mb.pressed, mb.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		_pointer(st.pressed, st.position)
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and age >= ARM_S and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			close(false)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and age >= ARM_S:
		close(false)


func _pointer(pressed: bool, pos: Vector2) -> void:
	if pressed:
		_armed = age >= ARM_S
		return
	if not _armed:
		return
	_armed = false
	var off: bool = _tips_off != null and _tips_off.get_global_rect().has_point(pos)
	close(off)


func close(tips_off: bool = false) -> void:
	if closing:
		return
	closing = true
	_linger = LINGER_S
	for c: Node in get_children():
		(c as CanvasItem).hide()
	queue_redraw()
	dismissed.emit(tips_off)
