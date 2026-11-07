# dd_card_view.gd
# Purpose: One tappable, inspectable card tile (street cards, weapon slot, deck counter, finale,
#   perks, survivors, unlocks). Left click / tap emits `tapped`; right click or a long press
#   (touch is emulated as the left mouse button) emits `inspected` with the zoom payload.
# Dependencies: DDUi.
# Author: Mechanics Developer Agent
class_name DDCardView
extends PanelContainer

signal tapped(view: DDCardView)
signal inspected(payload: Dictionary)

const LONG_PRESS_MS: int = 450
const MOVE_CANCEL_PX: float = 28.0

## Zoom payload: {kind, tag, title, big, body}. See DDInspect.open().
var payload: Dictionary = {}
var kind: String = "D"
var index: int = -1

var _pressing: bool = false
var _long_fired: bool = false
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _box: VBoxContainer
var _selected: bool = false
var _dim: bool = false


## spec keys: kind, tag (top-left small), badge (top-right), big, title, lines: [[text, color]...],
## big_size, compact, selected, dim, payload
func setup(spec: Dictionary) -> DDCardView:
	kind = str(spec.get("kind", "D"))
	payload = spec.get("payload", {})
	_selected = bool(spec.get("selected", false))
	_dim = bool(spec.get("dim", false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var compact: bool = bool(spec.get("compact", false))
	_box = DDUi.vbox(2 if compact else 4)
	add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	var tag: String = str(spec.get("tag", ""))
	var tl: Label = DDUi.label(tag, DDUi.FONT_S - (2 if compact else 0), DDUi.accent(kind))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	top.add_child(tl)
	var badge: String = str(spec.get("badge", ""))
	if badge != "":
		var bp: PanelContainer = DDUi.panel(Color(spec.get("badge_color", DDUi.WARN)), 3)
		bp.add_child(DDUi.label(badge, DDUi.FONT_S - 3, DDUi.BG))
		top.add_child(bp)
	var big: String = str(spec.get("big", ""))
	if big != "":
		var bl: Label = DDUi.label(big, int(spec.get("big_size", DDUi.BIG_NUMBER)), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_box.add_child(bl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tt: Label = DDUi.label(title, DDUi.FONT_M - (6 if compact else 0), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		_box.add_child(tt)
	for ln: Variant in spec.get("lines", []):
		var arr: Array = ln
		var l: Label = DDUi.label(str(arr[0]), int(arr[2]) if arr.size() > 2 else DDUi.FONT_S, arr[1] if arr.size() > 1 else DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
		_box.add_child(l)
	_apply_style()
	DDUi.ignore_mouse(self)
	tooltip_text = ""
	return self


func set_selected(v: bool) -> void:
	_selected = v
	_apply_style()


func _apply_style() -> void:
	var bg: Color = DDUi.card_bg(kind)
	var border: Color = DDUi.SELECT if _selected else DDUi.accent(kind)
	var st: StyleBoxFlat = DDUi.box(bg, border, 5 if _selected else 2, 14, 10)
	if _selected:
		st.shadow_color = Color(DDUi.SELECT, 0.35)
		st.shadow_size = 10
	add_theme_stylebox_override("panel", st)
	modulate = Color(1, 1, 1, 0.55) if _dim else Color(1, 1, 1, 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_pressing = false
			_open_inspect()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_long_fired = false
				_press_ms = Time.get_ticks_msec()
				_press_pos = mb.position
				set_process(true)
			else:
				if _pressing and not _long_fired:
					tapped.emit(self)
				_pressing = false
				set_process(false)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > MOVE_CANCEL_PX:
			_pressing = false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _pressing and not _long_fired and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_long_fired = true
		_pressing = false
		set_process(false)
		_open_inspect()


func _open_inspect() -> void:
	if not payload.is_empty():
		inspected.emit(payload)
