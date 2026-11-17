# concept_guide.gd
# Purpose: kc-ui-pass ConceptGuide autoload: the ONE onboarding system ("explain once, the first time
#   you see it"). Screens call notice(id, anchor) for the concepts the player is looking at right now
#   (ConceptRegistry ids); an unseen one is queued, and one at a time, when nothing holds the screen,
#   it opens a small callout beside its anchor (concept_callout.gd). Dismissed = seen, for good
#   (Settings.seen_flags, saved through SaveMirror so a crash-reload keeps it). Settings "Tips" off
#   (Settings.tips_enabled) shows nothing; "Reset tips" clears the seen set.
#   - one at a time, queued in notice order, at most MAX_QUEUE waiting;
#   - only while no hold check says "busy" (a screen registers one: the match says busy while a round
#     plays, the recap or a sheet is up, the inspector or the pause menu is open);
#   - an entry whose anchor is gone or hidden when its turn comes is dropped, NOT marked seen (it
#     comes back the next time that thing is on screen); entries of a previous scene are dropped;
#   - the callout swallows every input while it is up (it never passes a tap to the game).
#   Headless runs never show callouts on their own (auto_show) so screen tests tap through as before;
#   the concept tests switch it on.
# Usage: ConceptGuide.notice(&"supply", supply_box)
#        ConceptGuide.notice(&"kw_pick", card_control, [ready_button])   # avoid covering READY
#        ConceptGuide.add_hold_check(self, func() -> bool: return _busy)
# Dependencies: ConceptRegistry, concept_callout.gd, Settings (seen_flags, tips_enabled).
# Author: UI/UX Agent (kc-ui-pass)
extends Node

signal shown(id: StringName)
signal dismissed(id: StringName)

const CalloutScript: GDScript = preload("res://scripts/ui/concepts/concept_callout.gd")
const MAX_QUEUE: int = 10
## A screen settles this long after the last notice / scene change before a callout opens.
const SETTLE_S: float = 0.45
## At most this many callouts in one "beat" (a screen visit, or the stretch between two holds such as
## a round playing): a newcomer is never buried. The rest come back the next time they are on screen.
const MAX_PER_BEAT: int = 4

## Shows callouts on its own. Off in headless runs (tests switch it on).
var auto_show: bool = DisplayServer.get_name() != "headless"
## Tests: a seen set of their own instead of the Settings autoload's (null = use Settings).
var seen_override: Variant = null
var tips_override: Variant = null
## Tests: where the callout layer goes (a SubViewport running a screen); null = the root.
var host: Node = null
var _queue: Array[Dictionary] = []
var _callout: Control = null
var _layer: CanvasLayer = null
var _current: StringName = &""
var _settle: float = 0.0
var _scene_id: int = 0
var _checks: Array[Dictionary] = []
var _beat_count: int = 0
var _was_held: bool = false
## Ids shown this session (tests, QA).
var shown_log: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- the seen set -------------------------------------------------------------------------------

func is_seen(id: StringName) -> bool:
	var cid: StringName = ConceptRegistry.resolve(id)
	if seen_override is Dictionary:
		return (seen_override as Dictionary).has(String(cid))
	var st: Node = _settings()
	return st != null and (bool(st.call(&"is_seen", cid)) or bool(st.call(&"is_seen", id)))


func mark_seen(id: StringName) -> void:
	var cid: StringName = ConceptRegistry.resolve(id)
	if seen_override is Dictionary:
		(seen_override as Dictionary)[String(cid)] = true
		return
	var st: Node = _settings()
	if st != null:
		st.call(&"mark_seen", cid)


func tips_enabled() -> bool:
	if tips_override != null:
		return bool(tips_override)
	var st: Node = _settings()
	return st == null or bool(st.get(&"tips_enabled"))


func set_tips_enabled(on: bool) -> void:
	if tips_override != null:
		tips_override = on
	else:
		var st: Node = _settings()
		if st != null:
			st.call(&"set_value", &"tips_enabled", on)
	if not on:
		clear_queue()


## Every concept explained again (Settings > RESET TIPS calls Settings.reset_tips(), which clears it).
func reset() -> void:
	if seen_override is Dictionary:
		(seen_override as Dictionary).clear()
	else:
		var st: Node = _settings()
		if st != null:
			st.call(&"reset_tips")
	clear_queue()


func seen_count() -> int:
	var n: int = 0
	for id: StringName in ConceptRegistry.ids():
		if is_seen(id):
			n += 1
	return n


# --- noticing -----------------------------------------------------------------------------------

## The player can see concept `id` now, at `anchor` (a Control, a canvas Rect2, or a Callable that
## returns either). Queued unless seen, tips are off, or it is already queued / showing.
## `avoid`: Controls (or Rect2s) the bubble must not cover (the button the player needs next).
func notice(id: StringName, anchor: Variant = null, avoid: Array = [], first: bool = false) -> bool:
	var cid: StringName = ConceptRegistry.resolve(id)
	if not ConceptRegistry.has(cid) or not tips_enabled() or is_seen(cid) or cid == _current:
		return false
	for e: Dictionary in _queue:
		if e["id"] == cid:
			return false
	if _queue.size() >= MAX_QUEUE:
		if not first:
			return false
		_queue.pop_back()  # a front entry always gets in
	var e: Dictionary = {"id": cid, "anchor": anchor, "avoid": avoid, "scene": _scene_key()}
	if first:
		_queue.push_front(e)
	else:
		_queue.append(e)
	_settle = SETTLE_S
	return true


## The id that would open next (&"" when none).
func peek_id() -> StringName:
	return _queue[0]["id"] if not _queue.is_empty() else &""


## A new beat: the per-beat budget starts again (scene change, or after a hold).
func new_beat() -> void:
	_beat_count = 0


## Several at once, same anchor (the keywords of one card).
func notice_all(ids: Array, anchor: Variant = null, avoid: Array = []) -> void:
	for id: Variant in ids:
		notice(StringName(id), anchor, avoid)


## While fn() returns true (and owner is alive), nothing opens. One per owner.
func add_hold_check(owner: Node, fn: Callable) -> void:
	for c: Dictionary in _checks:
		if c["owner"].get_ref() == owner:
			c["fn"] = fn
			return
	_checks.append({"owner": weakref(owner), "fn": fn})


func is_held() -> bool:
	var keep: Array[Dictionary] = []
	var held: bool = false
	for c: Dictionary in _checks:
		var o: Object = c["owner"].get_ref()
		if o == null or not is_instance_valid(o) or not (o as Node).is_inside_tree():
			continue
		keep.append(c)
		if (c["fn"] as Callable).is_valid() and bool((c["fn"] as Callable).call()):
			held = true
	_checks = keep
	return held


func clear_queue() -> void:
	_queue.clear()


func queued_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in _queue:
		out.append(e["id"])
	return out


func is_showing() -> bool:
	return _callout != null and is_instance_valid(_callout) and not bool(_callout.get(&"closing"))


func current_id() -> StringName:
	return _current if is_showing() else &""


func get_callout() -> Control:
	return _callout if is_showing() else null


## Closes the callout on show (as GOT IT would).
func dismiss() -> void:
	if is_showing():
		_callout.call(&"close", false)


func _process(delta: float) -> void:
	var key: int = _scene_key()
	if key != _scene_id:
		_scene_id = key
		_settle = SETTLE_S
		new_beat()
		# Entries of the screen we left point at freed or hidden controls; a callout still up from
		# it closes without counting as seen.
		_queue = _queue.filter(func(e: Dictionary) -> bool: return e["scene"] == key)
		if is_showing():
			_drop_current()
	if not auto_show or is_showing() or _queue.is_empty():
		return
	if _callout != null and is_instance_valid(_callout):
		return  # still lingering after a close
	_settle -= delta
	# Never in the middle of a press or a drag (its release would be swallowed by the callout).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_settle = maxf(_settle, 0.2)
		return
	var held: bool = is_held()
	if held:
		_was_held = true
		return
	if _was_held:
		_was_held = false
		new_beat()
	if _settle > 0.0 or _beat_count >= MAX_PER_BEAT:
		return
	show_next()


## Opens the next queued callout whose anchor is on screen (tests call it directly). Returns its id.
func show_next() -> StringName:
	while not _queue.is_empty():
		var e: Dictionary = _queue.pop_front()
		if is_seen(e["id"]) or not tips_enabled():
			continue
		var r: Variant = _rect_of(e["anchor"])
		if r == null:
			continue  # gone or hidden: not seen, it comes back next time
		var avoid: Array[Rect2] = []
		for a: Variant in e["avoid"]:
			var ar: Variant = _rect_of(a)
			if ar != null:
				avoid.append(ar)
		_open(e["id"], r, avoid)
		_beat_count += 1
		return e["id"]
	return &""


func _open(id: StringName, target: Rect2, avoid: Array[Rect2]) -> void:
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.name = "ConceptLayer"
		_layer.layer = 100
	if _layer.get_parent() != null:
		_layer.get_parent().remove_child(_layer)
	# Last child of the root: its _input runs before the scene's, so nothing passes through.
	var parent: Node = host if host != null and is_instance_valid(host) else get_tree().root
	parent.add_child(_layer)
	var c: Control = CalloutScript.new()
	c.call(&"setup", ConceptRegistry.get_concept(id), target, avoid)
	_layer.add_child(c)
	c.dismissed.connect(_on_dismissed.bind(id))
	_callout = c
	_current = id
	shown_log.append(id)
	print("CONCEPT shown ", id)
	shown.emit(id)


func _drop_current() -> void:
	var c: Control = _callout
	_current = &""
	if c != null and is_instance_valid(c):
		c.dismissed.disconnect(_on_dismissed)
		c.call(&"close", false)


func _on_dismissed(tips_off: bool, id: StringName) -> void:
	mark_seen(id)
	_current = &""
	_settle = 0.25
	if tips_off:
		set_tips_enabled(false)
	dismissed.emit(id)


## kc-ui-pass QA: what window.kcQa.concept publishes ({} when no callout is up).
func qa_info() -> Dictionary:
	if not is_showing():
		return {}
	var c: Control = _callout
	return {"id": String(_current), "bubble": c.call(&"bubble_rect"), "got_it": c.call(&"get_got_it"),
			"tips_off": c.call(&"get_tips_off"), "target": c.get(&"target")}


func _rect_of(a: Variant) -> Variant:
	if a is Callable:
		if not (a as Callable).is_valid():
			return null
		a = (a as Callable).call()
	if a == null:
		return Rect2()  # no anchor: a centred bubble
	if a is Rect2:
		return a
	if a is Control:
		var c: Control = a
		if not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
			return null
		var r: Rect2 = c.get_global_rect()
		var vr: Rect2 = c.get_viewport_rect()
		if r.size.x < 2.0 or r.size.y < 2.0 or not vr.intersects(r):
			return null
		return r.intersection(vr)
	return null


func _scene_key() -> int:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return 0
	return tree.current_scene.get_instance_id()


func _settings() -> Node:
	return get_node_or_null(^"/root/Settings")
