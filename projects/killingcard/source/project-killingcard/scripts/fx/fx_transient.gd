# fx_transient.gd
# Purpose: Base for one-shot feedback effects (tracer, hit marker, floating text, stamp).
#   Add the node anywhere under a Control overlay, set its fields, call play(timing).
#   The effect runs one Tween, frees itself when done and emits `done`.
#   finish() jumps to the end at once (fast-forward / skip), which also frees it.
#   Effects never take input (mouse_filter IGNORE) and never touch game state.
# Dependencies: fx_timing.gd (the timing snapshot passed to play()).
# Author: Game Feel Engineer Agent (p14)
extends Control

signal done

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")

## Total length of the effect in seconds after timing options (set by play()).
var duration: float = 0.0
## Effect id for logs and tests (&"tracer", &"hit_marker", ...).
var fx_kind: StringName = &""
var _tween: Tween = null
var _finished: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Starts the effect. timing: an FxTiming instance (null = read Settings now).
func play(timing: RefCounted = null) -> void:
	if timing == null:
		timing = FxTiming.from_settings()
	_tween = create_tween()
	_build(_tween, timing)
	_tween.finished.connect(_on_finished)
	duration = _planned_duration(timing)


## Ends the effect immediately (its last frame is never shown) and frees it.
func finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_on_finished()


func is_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Subclasses add their tweeners here.
func _build(_t: Tween, _timing: RefCounted) -> void:
	pass


## Subclasses return the total length they built (seconds).
func _planned_duration(_timing: RefCounted) -> float:
	return 0.0


func _on_finished() -> void:
	if _finished:
		return
	_finished = true
	done.emit()
	queue_free()
