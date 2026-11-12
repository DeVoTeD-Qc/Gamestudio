# dd_touch_scroll.gd
# Purpose: dd-ux-equip (head: "On mobile using touch, I should be able to scroll codex with 2
#   fingers"). Attach one to a ScrollContainer (DDTouchScroll.attach(sc)) and it scrolls it with
#   - two fingers anywhere over it (the average of the fingers' movement), and
#   - one finger (or a mouse drag) started anywhere over it, on a tile or on empty space.
#   A gesture becomes a scroll only after it moves THRESHOLD px; from then on the tile under the
#   finger neither taps nor opens its zoom (DDCardView.cancel_presses()) and the motion is eaten so
#   nothing else reacts to it. A short tap or a long press without movement still works as before.
#   It reads input in _input (before the GUI), so tiles that stop the mouse don't block it.
#   A fling keeps the scroll going a little (none with reduce motion).
# Dependencies: DDCardView, Game (feel settings, optional).
# Author: UI/UX Agent (dd-ux-equip)
class_name DDTouchScroll
extends Node

const THRESHOLD: float = 10.0
const FRICTION: float = 6.0

var scroll: ScrollContainer = null
## Active touches: index -> position (screen touch events, real fingers).
var _touches: Dictionary = {}
var _tracking: bool = false
var _start: Vector2 = Vector2.ZERO
var _start_v: float = 0.0
var scrolling: bool = false
var _velocity: float = 0.0
var _two: bool = false


## Adds a DDTouchScroll to sc and returns it.
static func attach(sc: ScrollContainer) -> DDTouchScroll:
	var t: DDTouchScroll = DDTouchScroll.new()
	t.name = "TouchScroll"
	t.scroll = sc
	sc.add_child(t)
	return t


func _ready() -> void:
	set_process(false)


func _over(pos: Vector2) -> bool:
	return scroll != null and scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(pos)


func _reduce() -> bool:
	var g: Node = get_node_or_null(^"/root/Game")
	return g != null and g.has_method(&"reduce_motion") and bool(g.call(&"reduce_motion"))


func _scroll_by(dy: float) -> void:
	scroll.scroll_vertical = int(round(scroll.scroll_vertical - dy))


func _begin_scroll() -> void:
	if not scrolling:
		scrolling = true
		DDCardView.cancel_presses()


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		_touches.clear()
		_tracking = false
		scrolling = false
		return
	# two fingers: real touch events (the first finger is also sent as the emulated mouse)
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed and _over(st.position):
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_two = _touches.size() >= 2
		if _two:
			_begin_scroll()
		return
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
			if _touches.size() >= 2:
				_begin_scroll()
				_velocity = sd.relative.y / float(_touches.size()) * 60.0
				_scroll_by(sd.relative.y / float(_touches.size()))
				get_viewport().set_input_as_handled()
		return
	# one finger / the mouse
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _over(mb.position):
				_tracking = true
				scrolling = false
				_start = mb.position
				_start_v = scroll.scroll_vertical
				_velocity = 0.0
				set_process(false)
		else:
			if scrolling and not _reduce() and absf(_velocity) > 120.0:
				set_process(true)
			_tracking = false
			# keep `scrolling` true for this release: the tile's release sees the cancelled press
			scrolling = false
		return
	if event is InputEventMouseMotion and _tracking:
		var mm: InputEventMouseMotion = event
		if _two:
			# the two-finger path is scrolling already
			get_viewport().set_input_as_handled()
			return
		if not scrolling and mm.position.distance_to(_start) > THRESHOLD:
			_begin_scroll()
		if scrolling:
			scroll.scroll_vertical = int(round(_start_v - (mm.position.y - _start.y)))
			_velocity = mm.relative.y * 60.0 if mm.relative.y != 0.0 else _velocity
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if scroll == null or not is_instance_valid(scroll) or absf(_velocity) < 20.0:
		set_process(false)
		return
	_scroll_by(_velocity * delta)
	_velocity = lerpf(_velocity, 0.0, clampf(FRICTION * delta, 0.0, 1.0))
