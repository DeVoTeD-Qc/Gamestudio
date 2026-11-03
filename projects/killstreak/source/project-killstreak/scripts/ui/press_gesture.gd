# press_gesture.gd
# Purpose: Turns one Control's raw gui_input into tap / long-press / drag / inspect gestures,
#   the same way for mouse and touch (touch arrives as emulated mouse events, see project.godot
#   "emulate mouse from touch"; ScreenTouch / ScreenDrag are ignored so nothing fires twice).
#   - tap:        press + release without moving more than DRAG_THRESHOLD and before LONG_PRESS_S
#   - long press: held still for LONG_PRESS_S (400 ms, README "Input actions") -> inspect
#   - right click: inspect at once (mouse)
#   - drag:       press + move past DRAG_THRESHOLD (only when drag_enabled); then moved / ended
#   Nothing is hover-only. Positions are in the owner's canvas (viewport) coordinates.
# Usage:
#   var g := PressGesture.new(self)
#   g.tapped.connect(...)
#   func _gui_input(e): g.handle(e)
# Dependencies: none.
# Author: UI/UX Agent (p09)
extends RefCounted

signal tapped(pos: Vector2)
signal long_pressed(pos: Vector2)
signal drag_started(pos: Vector2)
signal drag_moved(pos: Vector2)
signal drag_ended(pos: Vector2)

const LONG_PRESS_S: float = 0.4
## Canvas px of movement before a press becomes a drag (about 7 pt on the phone).
const DRAG_THRESHOLD: float = 10.0

var drag_enabled: bool = true
var pressed: bool = false
var dragging: bool = false

var _owner: Control = null
var _start: Vector2 = Vector2.ZERO
var _press_id: int = 0
var _long_fired: bool = false


func _init(owner: Control) -> void:
	_owner = owner


## Feed every event of the owner's _gui_input here. Returns true when the event was used.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var pos: Vector2 = _to_canvas(mb.position)
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			cancel()
			long_pressed.emit(pos)
			return true
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			_begin(pos)
		else:
			_release(pos)
		return true
	if event is InputEventMouseMotion and pressed:
		var pos: Vector2 = _to_canvas((event as InputEventMouseMotion).position)
		if dragging:
			drag_moved.emit(pos)
		elif drag_enabled and not _long_fired and pos.distance_to(_start) > DRAG_THRESHOLD:
			dragging = true
			drag_started.emit(_start)
			drag_moved.emit(pos)
		return true
	return false


## Forget the current press (e.g. the owner was hidden or rebuilt mid-gesture).
func cancel() -> void:
	pressed = false
	dragging = false
	_press_id += 1


func _begin(pos: Vector2) -> void:
	pressed = true
	dragging = false
	_long_fired = false
	_start = pos
	_press_id += 1
	var my_id: int = _press_id
	if _owner != null and _owner.is_inside_tree():
		_owner.get_tree().create_timer(LONG_PRESS_S).timeout.connect(func() -> void:
			if pressed and not dragging and my_id == _press_id:
				_long_fired = true
				long_pressed.emit(_start))


func _release(pos: Vector2) -> void:
	if not pressed:
		return
	pressed = false
	_press_id += 1
	if dragging:
		dragging = false
		drag_ended.emit(pos)
	elif not _long_fired:
		tapped.emit(pos)


func _to_canvas(local: Vector2) -> Vector2:
	return _owner.get_global_transform() * local if _owner != null else local
