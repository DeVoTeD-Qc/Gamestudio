# dd_drag.gd
# Purpose: dd-ux-equip (head: "I would like to also support drag"). One drag model for the street,
#   mouse and touch alike:
#   - a tile lifts once the press moves DDCardView.DRAG_PX (10 px); taps and long-press zooms
#     keep working below that, and a long press can't fire once the drag has started;
#   - the lifted copy (the ghost) follows the pointer / finger, the tile it came from fades;
#   - every drop target lights up (gold rim) when the drop would work, and goes dark when it
#     wouldn't (the lit / dark rule of the street); the one under the pointer glows brighter;
#   - a drop on a lit target does the action, anything else snaps the ghost back (instantly with
#     reduce motion).
#   main.gd decides the sources and targets (DDDrag only knows rectangles and callables), so the
#   rules stay in DDRun and the previews it already shows.
#   target: {name, control (Control, hit-tested by its global rect), ok, reason, act (Callable)}.
# Dependencies: DDUi, DDCardView.
# Author: UI/UX Agent (dd-ux-equip)
class_name DDDrag
extends Control

signal drag_finished(target: Dictionary)

const LIFT: float = 1.06
const SNAP_S: float = 0.18
## The lifted card's widest (logical px) and how far above the finger its bottom edge floats.
const GHOST_W: float = 150.0
const FLOAT_Y: float = 22.0

var source: Control = null
var targets: Array[Dictionary] = []
var ghost: Control = null
var reduce: bool = false
## What the drag is (main.gd's source dictionary), for tests and the web smoke.
var info: Dictionary = {}
var hovered: String = ""
var _grab: Vector2 = Vector2.ZERO
var _fit: float = 1.0
var _glows: Dictionary = {}
var _extras: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "DragLayer"


func is_active() -> bool:
	return source != null


## Starts a drag of `src`. ghost_view: the lifted copy (added here, sized like src); tgts: the
## targets; extras: Controls that exist only during the drag (a SCRAP zone), freed at the end.
func begin(src: Control, ghost_view: Control, tgts: Array[Dictionary], gpos: Vector2, src_info: Dictionary = {}, extras: Array[Control] = []) -> void:
	cancel()
	source = src
	info = src_info
	targets = tgts
	for e: Control in extras:
		_ignore_mouse(e)
		add_child(e)
		_extras.append(e)
	var r: Rect2 = src.get_global_rect()
	_grab = gpos - r.position
	if ghost_view != null:
		ghost = ghost_view
		_ignore_mouse(ghost)
		ghost.set_meta(&"drag_ghost", true)
		add_child(ghost)
		# the lifted card floats just above the finger (so the target under it stays visible), at
		# most GHOST_W wide; a gun / melee button lifts a small token of its weapon
		var gs: Vector2 = ghost.custom_minimum_size if ghost.custom_minimum_size != Vector2.ZERO else r.size
		ghost.size = gs
		_fit = minf(1.0, GHOST_W / maxf(1.0, gs.x))
		_grab = Vector2(gs.x * 0.5, gs.y)
		ghost.pivot_offset = _grab
		ghost.z_index = 10
		ghost.scale = Vector2.ONE * _fit * (LIFT if not reduce else 1.0)
		if not reduce:
			ghost.rotation = deg_to_rad(-2.5)
		ghost.modulate = Color(1, 1, 1, 0.95)
	src.modulate.a = 0.35
	for t: Dictionary in targets:
		var g: Panel = Panel.new()
		g.name = "Glow_" + str(t.get("name", ""))
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.set_meta(&"ok", bool(t.get("ok", false)))
		add_child(g)
		_glows[str(t["name"])] = g
	_layout_glows()
	move(gpos)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in n.get_children():
		_ignore_mouse(c)


func _style(ok: bool, hot: bool) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	if ok:
		# lit: a gold rim and glow around the target (its face stays readable)
		st.bg_color = Color(DDUi.SELECT, 0.18 if hot else 0.0)
		st.border_color = DDUi.SELECT if hot else Color(DDUi.SELECT, 0.85)
		st.set_border_width_all(6 if hot else 4)
		st.shadow_color = Color(DDUi.SELECT, 0.5 if hot else 0.3)
		st.shadow_size = 16 if hot else 9
	else:
		# dark: this drop would not work
		st.bg_color = Color(0, 0, 0, 0.55)
		st.border_color = Color(0, 0, 0, 0)
	return st


func _layout_glows() -> void:
	for t: Dictionary in targets:
		var c: Control = t.get("control")
		var g: Panel = _glows.get(str(t["name"]))
		if g == null:
			continue
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			g.visible = false
			continue
		var r: Rect2 = c.get_global_rect()
		g.global_position = r.position - Vector2(3, 3)
		g.size = r.size + Vector2(6, 6)
		var hot: bool = str(t["name"]) == hovered
		g.add_theme_stylebox_override("panel", _style(bool(t.get("ok", false)), hot))


## The target under gpos ({} when none).
func target_at(gpos: Vector2) -> Dictionary:
	for t: Dictionary in targets:
		var c: Control = t.get("control")
		if c != null and is_instance_valid(c) and c.is_inside_tree() and c.get_global_rect().has_point(gpos):
			return t
	return {}


func move(gpos: Vector2) -> void:
	if source == null:
		return
	if ghost != null and is_instance_valid(ghost):
		ghost.global_position = gpos - _grab - Vector2(0, FLOAT_Y)
	var t: Dictionary = target_at(gpos)
	var h: String = str(t.get("name", ""))
	if h != hovered:
		hovered = h
		_layout_glows()


## Ends the drag at gpos: a lit target runs its action (returned), anything else snaps back
## (returns {} or the dark target with "ok": false).
func release(gpos: Vector2) -> Dictionary:
	if source == null:
		return {}
	var t: Dictionary = target_at(gpos)
	var ok: bool = not t.is_empty() and bool(t.get("ok", false))
	if ok:
		_end(false)
		var act: Variant = t.get("act")
		if act is Callable and (act as Callable).is_valid():
			(act as Callable).call()
	else:
		_end(true)
	drag_finished.emit(t)
	return t


## Drops the drag without doing anything (a re-render, a cancelled gesture).
func cancel() -> void:
	if source != null:
		_end(true)


func _end(snap_back: bool) -> void:
	var src: Control = source
	var gh: Control = ghost
	source = null
	ghost = null
	hovered = ""
	targets = []
	for g: Variant in _glows.values():
		if is_instance_valid(g):
			(g as Node).queue_free()
	_glows = {}
	for e: Control in _extras:
		if is_instance_valid(e):
			e.queue_free()
	_extras = []
	var src_ok: bool = src != null and is_instance_valid(src) and src.is_inside_tree()
	if src_ok:
		src.modulate.a = 1.0
	if gh == null or not is_instance_valid(gh):
		return
	if not snap_back or reduce or not src_ok:
		gh.queue_free()
		return
	# snap back to where it came from
	var tw: Tween = gh.create_tween().set_parallel(true)
	var sr: Rect2 = src.get_global_rect()
	var back: Vector2 = Vector2(sr.get_center().x, sr.end.y) - gh.pivot_offset
	var full: Vector2 = Vector2(sr.size.x / maxf(1.0, gh.size.x), sr.size.y / maxf(1.0, gh.size.y))
	tw.tween_property(gh, "global_position", back, SNAP_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(gh, "scale", full, SNAP_S)
	tw.tween_property(gh, "modulate:a", 0.0, SNAP_S)
	tw.tween_property(gh, "rotation", 0.0, SNAP_S)
	tw.chain().tween_callback(gh.queue_free)
