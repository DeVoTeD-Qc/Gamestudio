# coach_overlay.gd
# Purpose: The tutorial's coach layer over the real match UI (p15). Child "CoachOverlay" of
#   scenes/tutorial/Tutorial.tscn, drawn above the Match scene.
#   - Spotlight: amber frames around the highlight rects; while the step is locked the rest of
#     the screen is dimmed and taps outside the "holes" are blocked (_has_point is false inside
#     a hole, so the tap reaches the match control underneath). A blocked tap pulses the frame.
#   - Coach card: caption, step count, one or two short sentences, NEXT (only for "next"
#     steps) and SKIP TUTORIAL (tap twice). It is placed next to the highlight, never on it.
#   - End panel: "Drill complete" with REPLAY and DONE.
#   The overlay only shows; TutorialDirector decides the step, the rects and the lock.
#   Nothing hover-only. Text >= 16 px and buttons >= 64 px tall, so >= 11.6 pt and >= 46 pt on
#   an 844x390 phone (README "Phone readability").
# Dependencies: fx_style.gd (palette), the HUD theme variations (ToastPanel, HudAccent,
#   HudSubtle, HudHeader, HudButton, ReadyButton, RunTitle).
# Author: UI/UX Agent (p15)
extends Control

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")

signal next_pressed
signal skip_confirmed
signal replay_pressed
signal done_pressed
## A tap landed outside the holes of a locked step.
signal blocked_tap(pos: Vector2)

const DIM: Color = Color(0.071, 0.086, 0.102, 0.72)
const FRAME_PAD: float = 6.0
const FRAME_WIDTH: float = 4.0
const CARD_GAP: float = 12.0
const EDGE: float = 12.0
const CARD_WIDTH: float = 560.0
const CARD_WIDTH_COMPACT: float = 500.0
const SKIP_CONFIRM_SECONDS: float = 3.0

@onready var _card: PanelContainer = %CoachCard
@onready var _title: Label = %StepTitle
@onready var _count: Label = %StepCount
@onready var _body: Label = %Body
@onready var _next: Button = %NextButton
@onready var _skip: Button = %SkipButton
@onready var _end_panel: PanelContainer = %EndPanel
@onready var _end_title: Label = %EndTitle
@onready var _end_text: Label = %EndText
@onready var _replay: Button = %ReplayButton
@onready var _done: Button = %DoneButton

## Rects (overlay-local) that stay tappable while locked.
var holes: Array[Rect2] = []
## Rects that get the amber frame (usually one).
var frames: Array[Rect2] = []
## Taps outside the holes are blocked and the screen around them is dimmed.
var locked: bool = false
## Phone layout (set by the director from the match screen).
var compact: bool = false

var _pulse: float = 0.0
var _time: float = 0.0
var _skip_armed_until: int = 0
## kc-text: the step text drawn with each concept's icon inline (IconText); the Body Label under it
## keeps the words and the layout, with transparent ink.
var _body_rich: RichTextLabel = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.pressed.connect(func() -> void: next_pressed.emit())
	_skip.pressed.connect(_on_skip_pressed)
	_replay.pressed.connect(func() -> void: replay_pressed.emit())
	_done.pressed.connect(func() -> void: done_pressed.emit())
	_end_panel.hide()
	_body_rich = RichTextLabel.new()
	_body_rich.name = "BodyRich"
	IconText.setup(_body_rich)
	_body_rich.fit_content = false
	_body_rich.clip_contents = false
	_body_rich.add_theme_font_override(&"normal_font", _body.get_theme_font(&"font"))
	_body_rich.add_theme_font_size_override(&"normal_font_size", _body.get_theme_font_size(&"font_size"))
	_body_rich.add_theme_color_override(&"default_color", _body.get_theme_color(&"font_color"))
	_body.add_child(_body_rich)
	_body_rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	if _skip_armed_until > 0 and Time.get_ticks_msec() > _skip_armed_until:
		_skip_armed_until = 0
		_skip.text = "SKIP TUTORIAL"
	queue_redraw()


## Shows a step: caption, "n / total", text; NEXT only when the step advances on it.
func show_step(title: String, text: String, number: int, total: int, with_next: bool) -> void:
	_end_panel.hide()
	_card.show()
	_title.text = title
	_count.text = "%d / %d" % [number, total]
	_body.text = text
	if _body_rich != null:
		IconText.fill(_body_rich, text, int(_body.get_theme_font_size(&"font_size") * 1.05), _body.get_theme_color(&"font_color"))
		_body.self_modulate = Color(1, 1, 1, 0)
	_next.visible = with_next
	var w: float = CARD_WIDTH_COMPACT if compact else CARD_WIDTH
	_body.custom_minimum_size.x = w - 40.0
	_card.custom_minimum_size.x = w
	_card.reset_size()
	if with_next:
		_next.grab_focus.call_deferred()


## Sets what is framed / tappable and whether the rest is blocked. Rects are global canvas px.
func set_spotlight(p_frames: Array[Rect2], p_holes: Array[Rect2], p_locked: bool) -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	frames.clear()
	for r: Rect2 in p_frames:
		frames.append(inv * r)
	holes.clear()
	for r: Rect2 in p_holes:
		holes.append((inv * r).grow(FRAME_PAD))
	locked = p_locked
	mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	_place_card()


## Pass every tap through (inspector open, end panel).
func release() -> void:
	locked = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_end(title: String, text: String) -> void:
	release()
	frames.clear()
	holes.clear()
	_card.hide()
	_end_title.text = title
	_end_text.text = text
	_end_text.custom_minimum_size.x = (CARD_WIDTH_COMPACT if compact else CARD_WIDTH) - 40.0
	_end_panel.show()
	_end_panel.reset_size()
	_end_panel.position = (size - _end_panel.size) * 0.5
	_done.grab_focus.call_deferred()


func is_end_shown() -> bool:
	return _end_panel.visible


func pulse() -> void:
	_pulse = 1.0


func get_card() -> PanelContainer:
	return _card


func get_next_button() -> Button:
	return _next


func get_skip_button() -> Button:
	return _skip


func get_done_button() -> Button:
	return _done


func get_replay_button() -> Button:
	return _replay


func get_body_text() -> String:
	return _body.text


## Labels that must stay readable (tests: >= 11 pt on the phone).
func get_text_labels() -> Array[Label]:
	return [_title, _count, _body, _end_title, _end_text]


func get_buttons() -> Array[Button]:
	return [_next, _skip, _replay, _done]


## True when a tap at this overlay-local point would reach the match underneath.
func is_open_at(point: Vector2) -> bool:
	if not locked:
		return true
	for r: Rect2 in holes:
		if r.has_point(point):
			return true
	return false


func _has_point(point: Vector2) -> bool:
	# Locked: the overlay owns every point except the holes, which fall through to the match.
	return locked and not is_open_at(point)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		pulse()
		blocked_tap.emit((event as InputEventMouseButton).position)


func _on_skip_pressed() -> void:
	if _skip_armed_until > 0:
		_skip_armed_until = 0
		skip_confirmed.emit()
		return
	_skip_armed_until = Time.get_ticks_msec() + int(SKIP_CONFIRM_SECONDS * 1000.0)
	_skip.text = "TAP AGAIN TO SKIP"


## Puts the coach card beside the first frame (above, below, right, left) where it covers no
## frame and no tappable hole; failing that, anywhere along the screen edges that is clear;
## failing that, beside the frame. No frame: bottom centre (over the hand, which is idle while
## a round plays).
func _place_card() -> void:
	if not _card.visible:
		return
	_card.reset_size()
	var cs: Vector2 = _card.size
	var bounds: Rect2 = Rect2(Vector2.ZERO, size).grow(-EDGE)
	if frames.is_empty():
		_card.position = Vector2((size.x - cs.x) * 0.5, bounds.end.y - cs.y)
		return
	var avoid: Array[Rect2] = []
	for r: Rect2 in frames + holes:
		avoid.append(r.grow(FRAME_PAD))
	var f: Rect2 = frames[0].grow(FRAME_PAD + CARD_GAP)
	var cx: float = clampf(f.get_center().x - cs.x * 0.5, bounds.position.x, bounds.end.x - cs.x)
	var cy: float = clampf(f.get_center().y - cs.y * 0.5, bounds.position.y, bounds.end.y - cs.y)
	var beside: Array[Vector2] = [
		Vector2(cx, f.position.y - cs.y),   # above
		Vector2(cx, f.end.y),               # below
		Vector2(f.end.x, cy),               # right
		Vector2(f.position.x - cs.x, cy),   # left
	]
	var edges: Array[Vector2] = []
	for y: float in [bounds.position.y, (size.y - cs.y) * 0.5, bounds.end.y - cs.y]:
		for x: float in [(size.x - cs.x) * 0.5, bounds.position.x, bounds.end.x - cs.x]:
			edges.append(Vector2(x, y))
	for p: Vector2 in beside + edges:
		var r: Rect2 = Rect2(p, cs)
		if bounds.encloses(r) and not avoid.any(func(a: Rect2) -> bool: return a.intersects(r)):
			_card.position = p
			return
	for p: Vector2 in beside:
		if bounds.encloses(Rect2(p, cs)) and not Rect2(p, cs).intersects(f):
			_card.position = p
			return
	# Nothing fits beside it: the side of the screen away from the frame.
	var top: bool = f.get_center().y > size.y * 0.5
	_card.position = Vector2(cx, bounds.position.y if top else bounds.end.y - cs.y)


func _draw() -> void:
	if locked and not holes.is_empty():
		_draw_dim()
	var glow: float = 0.65 + 0.35 * sin(_time * 4.0)
	for r: Rect2 in frames:
		var grown: Rect2 = r.grow(FRAME_PAD + _pulse * 6.0)
		var c: Color = FxStyle.AMBER
		c.a = clampf(glow + _pulse, 0.0, 1.0)
		draw_rect(grown, c, false, FRAME_WIDTH + _pulse * 3.0)


## Dims every cell of the grid made by the hole edges that is not inside a hole.
func _draw_dim() -> void:
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for r: Rect2 in holes:
		xs.append_array([clampf(r.position.x, 0.0, size.x), clampf(r.end.x, 0.0, size.x)])
		ys.append_array([clampf(r.position.y, 0.0, size.y), clampf(r.end.y, 0.0, size.y)])
	xs.sort()
	ys.sort()
	for i: int in xs.size() - 1:
		for j: int in ys.size() - 1:
			var cell: Rect2 = Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var inside: bool = false
			for r: Rect2 in holes:
				if r.has_point(cell.get_center()):
					inside = true
					break
			if not inside:
				draw_rect(cell, DIM)
