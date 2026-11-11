# ability_button.gd
# Purpose: The Operator's once-per-match ability button (run-v2.md §7.1, "the charge pip"; kc-v2-ui).
#   A round button on the Operator card's top-right corner in the hand tray (landscape, iPad) or next
#   to the Operator in portrait. Its state is in shape AND word (never colour only):
#     READY   amber disk, full charge pip, "USE", a slow glow pulse   -> tap = pick a target (or queue)
#     AIM     the ability is selected and waits for a target: white ring, "AIM"  -> tap again = cancel
#     PLAN    queued this Deploy (Undo takes it back): amber ring, half pip, "PLAN"
#     WAIT    can't be used now (e.g. "Deploy your Operator first"): grey disk, hollow pip, "WAIT"
#     USED    spent: dark disk, dashed ring, struck pip, "USED"
#   Long press / right click = inspected (the ability's text, targets, "Once per match"). A tap in WAIT
#   or USED still reports pressed so the controller can say why.
#   Feedback: a ready -> planned / used change bursts a ring out of the button (reduced motion: a
#   colour flash only) and plays the "supply" cue; READY arriving plays "reward" once.
#   64 px (46 pt on an 844x390 phone).
# Dependencies: press_gesture.gd, Settings (reduced_motion), sfx_bank.gd.
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal pressed
signal inspected

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const SIZE_PX: float = 64.0
const INK: Color = Color(0.05, 0.06, 0.07, 1.0)

enum State { NONE, READY, AIM, PLAN, WAIT, USED }

var state: State = State.NONE
var ability: Dictionary = {}
var _gesture: RefCounted = null
var _burst: float = 0.0
var _flash: float = 0.0


func _init() -> void:
	name = "AbilityButton"
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = Vector2(SIZE_PX, SIZE_PX)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	add_to_group(&"tap_target")
	set_meta(&"inspectable", true)
	visible = false


func _ready() -> void:
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: pressed.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspected.emit())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton or e is InputEventMouseMotion:
		if _gesture.handle(e):
			accept_event()
	elif e.is_action_pressed(&"ui_accept"):
		accept_event()
		pressed.emit()


## a: MatchState.ability_view ({} hides the button); aiming: the ability is the current selection;
## planned: queued this Deploy.
func set_ability(a: Dictionary, aiming: bool, planned: bool) -> void:
	ability = a
	var before: State = state
	if a.is_empty():
		state = State.NONE
	elif aiming:
		state = State.AIM
	elif planned:
		state = State.PLAN
	elif bool(a.get("used", false)):
		state = State.USED
	elif bool(a.get("ready", false)):
		state = State.READY
	else:
		state = State.WAIT
	visible = state != State.NONE
	tooltip_text = "%s: %s" % [a.get("name", ""), word()] if not a.is_empty() else ""
	if before != state:
		_on_change(before)
	set_process(state == State.READY or state == State.AIM or _burst > 0.0 or _flash > 0.0)
	queue_redraw()


func _on_change(before: State) -> void:
	if not is_inside_tree():
		return
	var spent: bool = (before == State.READY or before == State.AIM) and (state == State.PLAN or state == State.USED)
	var lit: bool = before in [State.NONE, State.WAIT] and state == State.READY and before != State.NONE
	if spent or lit:
		var reduced: bool = _reduced_motion()
		_burst = 0.0 if reduced else 1.0
		_flash = 1.0
		set_process(true)
		(load("res://scripts/fx/sfx_bank.gd") as GDScript).call(&"cue", &"supply" if spent else &"reward")


func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.get(&"reduced_motion"))


## The ability resolved on the board (Reveal): one more burst + cue.
func celebrate() -> void:
	_flash = 1.0
	_burst = 0.0 if _reduced_motion() else 1.0
	set_process(true)
	(load("res://scripts/fx/sfx_bank.gd") as GDScript).call(&"cue", &"column_win")


## The state word on the button.
func word() -> String:
	return {State.READY: "USE", State.AIM: "AIM", State.PLAN: "PLAN", State.WAIT: "WAIT", State.USED: "USED"}.get(state, "")


func _process(delta: float) -> void:
	_burst = maxf(0.0, _burst - delta / 0.45)
	_flash = maxf(0.0, _flash - delta / 0.3)
	queue_redraw()
	if _burst <= 0.0 and _flash <= 0.0 and state != State.READY and state != State.AIM:
		set_process(false)


func _draw() -> void:
	if state == State.NONE:
		return
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 3.0
	var amber: Color = Color("#FFB020")
	var t: float = Time.get_ticks_msec() / 1000.0
	# Backing shadow so the button reads over any card art.
	draw_circle(c + Vector2(0, 2), r + 2.0, Color(0, 0, 0, 0.55))
	match state:
		State.READY:
			var glow: float = 0.5 + 0.5 * sin(t * 3.2)
			draw_circle(c, r + 3.0 + glow * 2.0, Color(amber, 0.25 + 0.2 * glow))
			draw_circle(c, r, amber)
			draw_arc(c, r, 0, TAU, 40, Color.WHITE, 2.0, true)
			_pip(c + Vector2(0, -r * 0.3), r * 0.26, INK, 1.0)
		State.AIM:
			draw_circle(c, r, Color("#2E3439"))
			var a0: float = t * 4.0
			draw_arc(c, r, a0, a0 + TAU * 0.75, 32, Color.WHITE, 3.0, true)
			_pip(c + Vector2(0, -r * 0.3), r * 0.26, amber, 1.0)
		State.PLAN:
			draw_circle(c, r, Color("#2B2618"))
			draw_arc(c, r, 0, TAU, 40, amber, 3.0, true)
			_pip(c + Vector2(0, -r * 0.3), r * 0.26, amber, 0.5)
		State.WAIT:
			draw_circle(c, r, Color("#3A444D"))
			draw_arc(c, r, 0, TAU, 40, Color("#8D979F"), 2.0, true)
			_pip(c + Vector2(0, -r * 0.3), r * 0.26, Color("#B9C2C9"), 0.0)
		State.USED:
			draw_circle(c, r, Color("#15191D"))
			var n: int = 16
			for i: int in n:
				if i % 2 == 0:
					draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 4, Color("#59636C"), 2.0)
			_pip(c + Vector2(0, -r * 0.3), r * 0.26, Color("#59636C"), 0.0)
			var pc: Vector2 = c + Vector2(0, -r * 0.3)
			draw_line(pc + Vector2(-r * 0.3, r * 0.3), pc + Vector2(r * 0.3, -r * 0.3), Color("#8D979F"), 2.0)
	if _flash > 0.0:
		draw_circle(c, r, Color(1, 1, 1, 0.45 * _flash))
	if _burst > 0.0:
		var br: float = r + (1.0 - _burst) * 26.0
		draw_arc(c, br, 0, TAU, 40, Color(amber, _burst), 3.0, true)
	# The state word (16 px, outlined).
	var font: Font = get_theme_font(&"font", &"HudHeader")
	var fs: int = 16
	var w: String = word()
	var tw: float = font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: Vector2 = Vector2(c.x - tw * 0.5, c.y + r * 0.58)
	var fg: Color = INK if state == State.READY else Color.WHITE
	if state != State.READY:
		draw_string_outline(font, base, w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, INK)
	draw_string(font, base, w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
	if has_focus():
		draw_arc(c, r + 5.0, 0, TAU, 40, Color(amber, 0.8), 1.5)


## The charge pip: a small hex; fill 1 = full, 0.5 = half (planned), 0 = hollow.
func _pip(c: Vector2, r: float, col: Color, fill: float) -> void:
	var pts: PackedVector2Array = []
	for i: int in 6:
		var a: float = PI / 6.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if fill >= 1.0:
		draw_colored_polygon(pts, col)
	elif fill > 0.0:
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3]]), col)
	pts.append(pts[0])
	draw_polyline(pts, col, 2.0, true)


## kc-text: hover tooltips show each concept's icon inline (IconText), like every other text.
func _make_custom_tooltip(for_text: String) -> Object:
	return IconText.tooltip(for_text)
