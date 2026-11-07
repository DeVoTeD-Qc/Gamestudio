# dd_inspect.gd
# Purpose: The zoomed-card overlay opened by right click / long press on anything inspectable.
#   payload: {kind, tag, title, big, body, extra_cards?: [payload...]} - tap anywhere or Esc to close.
# Dependencies: DDUi.
# Author: Mechanics Developer Agent
class_name DDInspect
extends Control

signal closed
signal opened

var _content: Control = null
var _opened_ms: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func open(payload: Dictionary) -> void:
	if _content != null:
		_content.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var kind: String = str(payload.get("kind", "D"))
	var card: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = DDUi.box(DDUi.card_bg(kind), DDUi.accent(kind), 4, 20, 24)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 18
	card.add_theme_stylebox_override("panel", st)
	var wide: bool = vp.x > vp.y
	var w: float = minf(980.0, vp.x - 40.0) if wide else minf(560.0, vp.x - 40.0)
	card.custom_minimum_size = Vector2(w, 0)
	center.add_child(card)
	var v: VBoxContainer = DDUi.vbox(8)
	card.add_child(v)
	# landscape: name block on the left, rules on the right, so tall text still fits the screen
	var split: BoxContainer = BoxContainer.new()
	split.vertical = not wide
	split.add_theme_constant_override("separation", 20)
	v.add_child(split)
	var head: VBoxContainer = DDUi.vbox(6)
	var head_w: float = 260.0 if wide else w - 48.0
	head.custom_minimum_size = Vector2(head_w, 0)
	split.add_child(head)
	head.add_child(DDUi.label(str(payload.get("tag", "")), DDUi.FONT_M, DDUi.accent(kind), HORIZONTAL_ALIGNMENT_LEFT, true))
	var big: String = str(payload.get("big", ""))
	if big != "":
		head.add_child(DDUi.label(big, 96 if not wide else 80, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(DDUi.label(str(payload.get("title", "")), DDUi.FONT_XL if not wide else DDUi.FONT_L, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var right: VBoxContainer = DDUi.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var body_w: float = (w - 48.0 - head_w - 20.0) if wide else (w - 48.0)
	var body: Label = DDUi.label(str(payload.get("body", "")), DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	body.custom_minimum_size = Vector2(body_w, 0)
	right.add_child(body)
	var extra: Array = payload.get("extra_cards", [])
	if not extra.is_empty():
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		right.add_child(flow)
		for e: Variant in extra:
			var d: Dictionary = e
			var chip: PanelContainer = DDUi.panel(DDUi.card_bg(str(d.get("kind", "D"))), 8, DDUi.accent(str(d.get("kind", "D"))), 2)
			chip.custom_minimum_size = Vector2(96, 0)
			var cv: VBoxContainer = DDUi.vbox(0)
			chip.add_child(cv)
			cv.add_child(DDUi.label(str(d.get("big", "")), DDUi.FONT_XL, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			cv.add_child(DDUi.label(str(d.get("title", "")), DDUi.FONT_S - 2, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
			flow.add_child(chip)
	v.add_child(DDUi.label("Tap anywhere to close", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	DDUi.ignore_mouse(root)
	visible = true
	_opened_ms = Time.get_ticks_msec()
	opened.emit()


func close() -> void:
	visible = false
	if _content != null:
		_content.queue_free()
		_content = null
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# ignore the tail of the long press that opened us
		if Time.get_ticks_msec() - _opened_ms > 150:
			close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
