# round_recap.gd
# Purpose: kc-clarity (playtest v28: "I won without knowing why", "5-3 turned into 5-6 and I had no
#   idea why"). The panel over the bottom of the board at the start of each Deploy that says what the
#   last round did, per column, in plain words:
#       ROUND 2 · FIRST TO 6                                  ×
#       [A] you 2 vs 0 left · you +1
#       [B] you 1 vs 1 left · even, no point
#       [C] nobody left · no point
#       Score: you 3, rival 2. You eliminated 1.
#       Now: play cards, then READY.
#   The letter plates use the column tiles' shapes (yours solid, the rival's hatched, even dashed,
#   nobody a grey keyline), so it reads without colour. Long-press or right-click adds the one-line
#   rule of how a column scores (studio rule: everything inspectable).
#   kc-recap-dismiss (head: "pressed READY to skip it and it ended my turn"): it can never cause an
#   accidental action. While it shows, the first press anywhere (READY, cards, the board) only
#   closes it and is eaten with its release; a press that turns into a drag (past the gesture's
#   threshold) closes it and is replayed, so the drag still starts. It also hides itself after
#   AUTO_HIDE_S (paused while a mouse hovers it), and a shrinking amber line plus "tap to
#   continue" say so.
# Usage: var rr := RoundRecap.new(); add_child(rr); rr.show_recap(ScoreRace.recap(...), "Now: ...")
# Dependencies: PressGesture, hud_theme.tres (ToastPanel, HudHeader, Hud colours), BannerView (dashes).
# Author: UI/UX Agent (kc-clarity)
extends PanelContainer

signal dismissed

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const AMBER: Color = Color("#FFB020")
const MUTED: Color = Color("#B9C2C9")
const RULE: String = "A column scores for the side that still has units in it at round end (if both do, a Holder decides; else it is even). Held = +1, Hot Zone +2."
const ROW_FS: int = 20
const HEAD_FS: int = 20
## kc-recap-dismiss: seconds before it hides itself; after a long press (the rule shown), longer.
const AUTO_HIDE_S: float = 4.0
const INSPECT_HOLD_S: float = 7.0
const TIMER_LINE_H: float = 3.0
enum Outside { NONE, SWALLOW, REPLAY }

var _title: Label = null
var _rows: VBoxContainer = null
var _score: Label = null
var _now: Label = null
var _rule: Label = null
var _gesture: RefCounted = null
## The last recap shown (tests): {title, rows, score, ...}.
var data: Dictionary = {}
## kc-recap-dismiss: seconds left before it hides itself, out of _hold.
var time_left: float = 0.0
var _hold: float = AUTO_HIDE_S
## A real mouse is over it (auto-hide pauses); never set by touch (emulated mouse).
var _hovered: bool = false
var _outside: Outside = Outside.NONE
var _out_press: InputEventMouseButton = null
var _out_queue: Array[InputEvent] = []


func _init() -> void:
	name = "RoundRecap"
	visible = false
	theme_type_variation = &"ToastPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"tap_target")
	tooltip_text = RULE
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = _label("", HEAD_FS, AMBER)
	_title.name = "RecapTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x: Label = _label("tap to continue  ✕", ROW_FS - 6, MUTED)
	x.name = "CloseMark"
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(x)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override(&"separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows)
	_score = _label("", ROW_FS, Color("#F2F5F7"))
	_score.name = "RecapScore"
	col.add_child(_score)
	_now = _label("", ROW_FS - 2, MUTED)
	_now.name = "RecapNow"
	col.add_child(_now)
	_rule = _label(RULE, ROW_FS - 4, MUTED)
	_rule.name = "RecapRule"
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.visible = false
	col.add_child(_rule)
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: dismiss())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspect())
	set_process(false)


func _label(text: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HudHeader"
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		inspect()
		return
	if _gesture.handle(event):
		accept_event()


## Shows a ScoreRace.recap() dictionary plus the "what to do now" line.
func show_recap(recap: Dictionary, now: String) -> void:
	data = recap.duplicate()
	_title.text = String(recap.get("title", "ROUND"))
	for c: Node in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for row: Dictionary in recap.get("rows", []):
		_rows.add_child(_row(row))
	var units: String = String(recap.get("units", ""))
	_score.text = String(recap.get("score", "")) + (" " + units if units != "" else "")
	if (recap.get("rows", []) as Array).is_empty():
		_score.text = String(recap.get("plain", _score.text))
	_now.text = now
	_now.visible = now != ""
	_rule.visible = false
	visible = true
	_restart_timer(AUTO_HIDE_S)
	reset_size()


func _row(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owner: StringName = StringName(row.get("owner", &"empty"))
	var plate := Control.new()
	plate.name = "Plate"
	plate.custom_minimum_size = Vector2(ROW_FS + 6, ROW_FS + 6)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter: String = String(row.get("letter", "?"))
	h.set_meta(&"letter", letter)
	plate.draw.connect(func() -> void: _draw_plate(plate, letter, owner))
	h.add_child(plate)
	var friend: Color = get_theme_color(&"friend", &"Hud") if has_theme_color(&"friend", &"Hud") else Color("#3FD0C9")
	var enemy: Color = get_theme_color(&"enemy", &"Hud") if has_theme_color(&"enemy", &"Hud") else Color("#FF5A5F")
	var c: Color = {&"player": friend, &"enemy": enemy}.get(owner, MUTED)
	var l: Label = _label(String(row.get("text", "")), ROW_FS, c)
	l.name = "RowText"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## The column letter on the tile's control plate: solid teal (yours), hatched red (the rival's),
## dashed (even), grey keyline (nobody).
static func _draw_plate(ci: Control, letter: String, owner: StringName) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, ci.size).grow(-1.0)
	var friend: Color = ci.get_theme_color(&"friend", &"Hud")
	var enemy: Color = ci.get_theme_color(&"enemy", &"Hud")
	var ink: Color = Color.WHITE
	match owner:
		&"player":
			ci.draw_rect(r, friend)
			ink = Color("#12161A")
		&"enemy":
			ci.draw_rect(r, Color("#8F1F21"))
			var x: float = -r.size.y
			while x < r.size.x:
				var x0: float = maxf(0.0, x)
				var x1: float = minf(r.size.x, x + r.size.y)
				if x1 > x0:
					ci.draw_line(r.position + Vector2(x0, r.size.y - (x0 - x)), r.position + Vector2(x1, r.size.y - (x1 - x)), enemy, 2.0)
				x += 5.0
			ci.draw_rect(r, enemy, false, 2.0)
		&"contested":
			ci.draw_rect(r, Color("#2E3439"))
			BannerView._dashed_rect(ci, r, Color("#D8DEE3"), 2.0)
		_:
			ci.draw_rect(r, Color("#59636C"), false, 2.0)
			ink = Color("#9AA4AD")
	var font: Font = ci.get_theme_font(&"font", &"HudHeader")
	var fs: int = int(r.size.y * 0.72)
	var sz: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base: Vector2 = Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	if owner == &"enemy":
		ci.draw_string_outline(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color("#3A0C0D"))
	ci.draw_string(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## Long-press / right-click: the rule of how a column scores.
func inspect() -> void:
	_rule.visible = true
	_rule.custom_minimum_size.x = maxf(200.0, size.x - 24.0)
	reset_size()
	# Time to read the rule, then it goes away by itself (or on a tap).
	_restart_timer(INSPECT_HOLD_S)


func dismiss() -> void:
	if not visible:
		return
	visible = false
	_gesture.cancel()
	set_process(false)
	dismissed.emit()


# --- kc-recap-dismiss: auto-hide ------------------------------------------------------------

func _restart_timer(seconds: float) -> void:
	_hold = seconds
	time_left = seconds
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Runs the auto-hide clock by `delta` seconds (the frame loop, and tests). Paused while a mouse
## hovers the panel or a press on it is held (a long press in progress).
func advance(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if is_paused():
		return
	time_left -= delta
	queue_redraw()
	if time_left <= 0.0:
		dismiss()


func is_paused() -> bool:
	return _hovered or _gesture.pressed


func _draw() -> void:
	# The shrinking timer line along the bottom edge (inside the panel's border).
	if _hold <= 0.0:
		return
	var frac: float = clampf(time_left / _hold, 0.0, 1.0)
	var w: float = (size.x - 16.0) * frac
	if w <= 0.5:
		return
	var c: Color = AMBER if not is_paused() else MUTED
	draw_rect(Rect2(Vector2(8.0, size.y - TIMER_LINE_H - 3.0), Vector2(w, TIMER_LINE_H)), c)


# --- kc-recap-dismiss: the first press outside only closes it -------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_track_hover(event as InputEventMouse)
	if _outside != Outside.NONE:
		_follow_outside_press(event)
		return
	if not is_visible_in_tree():
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return  # the wheel scrolls as usual
	if _is_inside(mb.position):
		return  # the panel's own _gui_input: tap closes, long press / right click shows the rule
	if _layer_above_at(mb.position):
		return  # a sheet, the inspector or a flyout over the recap gets its own press
	get_viewport().set_input_as_handled()
	_out_press = mb.duplicate() as InputEventMouseButton
	_out_queue.clear()
	_outside = Outside.SWALLOW
	dismiss()


## After the closing press: eat its release (a tap only closes); if it moves past the drag
## threshold first, hand the press and the moves back so the drag starts after all.
func _follow_outside_press(event: InputEvent) -> void:
	if _outside == Outside.REPLAY:
		if event is InputEventMouse:
			get_viewport().set_input_as_handled()
			_out_queue.append(event.duplicate())
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == _out_press.button_index and not mb.pressed:
			get_viewport().set_input_as_handled()
			_outside = Outside.NONE
			_out_press = null
		return
	if event is InputEventMouseMotion and _out_press.button_index == MOUSE_BUTTON_LEFT:
		var mm: InputEventMouseMotion = event
		if mm.position.distance_to(_out_press.position) > PressGesture.DRAG_THRESHOLD:
			get_viewport().set_input_as_handled()
			_outside = Outside.REPLAY
			_out_queue.append(mm.duplicate())
			_replay.call_deferred()


func _replay() -> void:
	var vp: Viewport = get_viewport()
	var press: InputEventMouseButton = _out_press
	var queued: Array[InputEvent] = _out_queue.duplicate()
	_outside = Outside.NONE
	_out_press = null
	_out_queue.clear()
	if vp == null or press == null:
		return
	vp.push_input(press, true)
	for e: InputEvent in queued:
		vp.push_input(e, true)


func _is_inside(pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * pos)


## True when a visible control drawn over the recap (a later sibling: sheets, inspector, flyout)
## takes the press at `pos`.
func _layer_above_at(pos: Vector2) -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	for i: int in range(get_index() + 1, parent.get_child_count()):
		var n: Node = parent.get_child(i)
		if n is Control and _takes_press(n as Control, pos):
			return true
	return false


static func _takes_press(c: Control, pos: Vector2) -> bool:
	if not c.visible:
		return false
	if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and Rect2(Vector2.ZERO, c.size).has_point(c.get_global_transform_with_canvas().affine_inverse() * pos):
		return true
	for ch: Node in c.get_children():
		if ch is Control and _takes_press(ch as Control, pos):
			return true
	return false


func _track_hover(e: InputEventMouse) -> void:
	# Touch arrives as emulated mouse events: a finger never "hovers", so it never pauses the clock.
	var was: bool = _hovered
	_hovered = e.device != InputEvent.DEVICE_ID_EMULATION and is_visible_in_tree() and _is_inside(e.position)
	if was != _hovered:
		queue_redraw()


func is_open() -> bool:
	return visible


## Plain text (tests, QA).
func get_text() -> String:
	var out: PackedStringArray = [_title.text]
	for h: Node in _rows.get_children():
		var t: Label = h.get_node_or_null(^"RowText")
		out.append("%s: %s" % [String(h.get_meta(&"letter", "")), t.text if t != null else ""])
	out.append(_score.text)
	if _now.visible:
		out.append(_now.text)
	return "\n".join(out)
