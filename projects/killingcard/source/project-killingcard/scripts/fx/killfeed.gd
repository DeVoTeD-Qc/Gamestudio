# killfeed.gd
# Purpose: The killfeed (top-right of the match screen, art direction "Board & HUD"). A stack
#   of KillfeedEntry lines, newest at the bottom, each fading after its life (4 s, 2 s with
#   fast animations). It fits as many 22 px lines as its height allows (3 in the 72 px desktop
#   top bar, 2 in the phone's top-bar overlay; at most MAX_LINES); a push beyond that drops the oldest
#   and the others slide up one row. Its minimum size is 0, so it never grows the HUD bar
#   it sits in; it clips to its rect.
#   Display only: FeedbackDirector (or anything else) calls push() with names already resolved.
# Scene: res://scenes/fx/Killfeed.tscn (root Control, mouse ignored, expands in its parent slot).
# Dependencies: killfeed_entry.gd, fx_timing.gd.
# Author: Game Feel Engineer Agent (p14)
extends Control

const KillfeedEntry: GDScript = preload("res://scripts/fx/killfeed_entry.gd")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const MAX_LINES: int = 3
const SHIFT_TIME: float = 0.12

## Multiplies each line's life (feed_life); the phone layout shortens it (match_screen.gd, f04).
var life_scale: float = 1.0
## kc-board2: the tray's killfeed LOG keeps its lines (no fade); the newest line_cap lines show.
var persistent: bool = false
## Most lines shown at once (MAX_LINES unless set).
var line_cap: int = MAX_LINES
## Lines centred in the rect (the killfeed toasts over the board) instead of right-aligned.
var centered: bool = false
## A second feed every push() is copied to (the log's toasts), or null.
var mirror: Control = null
var _entries: Array[Control] = []
var _reduced: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout.bind(false))


## Adds a line. data: {attacker, attacker_side, victim, victim_side, icon, zone, killstreak}.
## Returns the entry node.
func push(data: Dictionary, timing: RefCounted = null) -> Control:
	if timing == null:
		timing = FxTiming.from_settings()
	_reduced = timing.reduced_motion
	if mirror != null and is_instance_valid(mirror):
		mirror.push(data, timing)
	var line: Control = KillfeedEntry.new()
	line.centered = centered
	line.setup(data)
	var keep: int = max_lines() - 1
	while _entries.size() > keep:
		_entries[0].expire_now()   # removes itself from _entries via expired
	_entries.append(line)
	line.expired.connect(_on_expired.bind(line))
	add_child(line)
	line.size = Vector2(size.x, KillfeedEntry.ROW_HEIGHT)
	line.position = _row_position(_entries.size() - 1)
	_layout(true)
	line.start(timing, -1.0 if persistent else life_scale)
	return line


## Lines that are still on screen (oldest first).
func get_entries() -> Array[Control]:
	return _entries.duplicate()


## How many lines fit the current height (1..MAX_LINES; MAX_LINES before the first layout).
func max_lines() -> int:
	if size.y <= 0.0:
		return line_cap
	return clampi(int(floor((size.y + 0.5) / KillfeedEntry.ROW_HEIGHT)), 1, line_cap)


## Fast-forward: finish every enter animation (lines keep their remaining life).
func finish_all() -> void:
	for line: Control in _entries:
		line.finish_enter()
	if mirror != null and is_instance_valid(mirror):
		mirror.finish_all()


func clear() -> void:
	for line: Control in _entries.duplicate():
		line.expire_now()


func _on_expired(line: Control) -> void:
	_entries.erase(line)
	_layout(true)


## Oldest line on top, newest below it; the lines shown are vertically centred in the rect
## (f04: a single line no longer sits at the bottom of an empty box). A persistent log and the
## toasts stack from the top instead.
func _row_position(index: int) -> Vector2:
	var shown: int = mini(_entries.size(), max_lines())
	var top: float = 0.0 if persistent or centered else (size.y - shown * KillfeedEntry.ROW_HEIGHT) * 0.5
	var row: int = index - (_entries.size() - shown)
	return Vector2(0, top + row * KillfeedEntry.ROW_HEIGHT)


func _layout(animate: bool) -> void:
	for i: int in _entries.size():
		var line: Control = _entries[i]
		line.size = Vector2(size.x, KillfeedEntry.ROW_HEIGHT)
		var target: Vector2 = _row_position(i)
		if animate and not _reduced and line.is_inside_tree() and line.position != target:
			line.create_tween().tween_property(line, ^"position", target, SHIFT_TIME) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			line.position = target
