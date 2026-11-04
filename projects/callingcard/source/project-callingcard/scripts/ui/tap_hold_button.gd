# tap_hold_button.gd
# Purpose: Button for touch-first cards and slots (plan §7: nothing hover-only):
#   - tap / click / Enter                -> tapped
#   - press and hold HOLD_TIME (400 ms)  -> inspect_requested (the release then does NOT tap)
#   - right-click, or the "inspect" key  -> inspect_requested
#   Touch arrives as left mouse (project setting emulate_mouse_from_touch), so one code path
#   covers mouse and touch. Used by WallSlot and the hand cards.
#   - a press that turns into a drag (moves > HOLD_SLOP, or a parent ScrollContainer starts a touch
#     scroll) is neither a tap nor a hold (cc19 BUG-02). Inside a ScrollContainer, set
#     mouse_filter = MOUSE_FILTER_PASS so the drag reaches it (lineup grid, album, duel hand).
# Dependencies: none (input action "inspect" from project.godot is optional).
# Author: UI/UX Agent (cc07)
extends Button

signal tapped
signal inspect_requested

const HOLD_TIME: float = 0.4
## A press that moves further than this (logical px) is a scroll/drag, not a hold.
const HOLD_SLOP: float = 18.0

var _hold_timer: Timer
var _held: bool = false
var _dragged: bool = false
var _pressing: bool = false  # own flag: a parent scroll may take the press over from BaseButton
var _press_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button_mask = MOUSE_BUTTON_MASK_LEFT


func _ready() -> void:
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_TIME
	_hold_timer.timeout.connect(_on_hold)
	add_child(_hold_timer, false, Node.INTERNAL_MODE_FRONT)
	pressed.connect(_on_pressed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			inspect_requested.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_held = false
				_dragged = false
				_pressing = true
				_press_pos = mb.global_position
				_hold_timer.start()
			else:
				_pressing = false
				_hold_timer.stop()
	elif event is InputEventMouseMotion:
		# Global position: while a ScrollContainer follows the finger the local one barely moves.
		var mm: InputEventMouseMotion = event
		if _pressing and mm.global_position.distance_to(_press_pos) > HOLD_SLOP:
			_cancel_as_drag()
	elif event.is_action_pressed(&"inspect", false, true):
		inspect_requested.emit()
		accept_event()


func _notification(what: int) -> void:
	# A parent ScrollContainer began a touch-drag scroll with this press in progress.
	if what == NOTIFICATION_SCROLL_BEGIN and (_pressing or is_pressed()):
		_cancel_as_drag()


func _cancel_as_drag() -> void:
	_dragged = true
	if _hold_timer != null:
		_hold_timer.stop()


## Test hook: what a completed long press does.
func simulate_hold() -> void:
	_on_hold()


func _on_hold() -> void:
	_held = true
	inspect_requested.emit()


func _on_pressed() -> void:
	if _dragged:
		_dragged = false
		return
	if _held:
		_held = false
		return
	tapped.emit()
