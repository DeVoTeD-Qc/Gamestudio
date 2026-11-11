# dd_inspect.gd
# Purpose: The overlay opened by right click / long press on anything inspectable.
#   dd-ux-v4 (head's M3 b): a 2-line tooltip: payload "t1" (bold: what it is and its numbers now)
#   and "t2" (what it does for you), next to a small picture of the thing. The full rules live
#   only in the Glossary and the Codex. A payload with "list": true (the history, how to play)
#   keeps the long layout with its "body".
#   payload: {kind, tag, title, big, body, art?: Texture2D, extra_cards?: [payload...]} - tap anywhere
#   or Esc to close. dd-feel: the zoom pops in (fades only with reduce motion).
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


const Marks: GDScript = preload("res://scripts/ui/dd_marks.gd")
const ArtLib: GDScript = preload("res://scripts/ui/dd_art.gd")

## The two lines the last tooltip showed (tests).
var last_lines: PackedStringArray = []


func open(payload: Dictionary) -> void:
	if _content != null:
		_content.queue_free()
	if not bool(payload.get("list", false)):
		_open_tip(payload)
		return
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
	var art: Variant = payload.get("art", null)
	if art is Texture2D:
		# dd-feel: the card art, with the big number laid over its lower edge
		var frame: Control = Control.new()
		frame.custom_minimum_size = Vector2(head_w, 230.0 if not wide else minf(220.0, vp.y * 0.42))
		frame.clip_contents = true
		var tr: TextureRect = TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(tr)
		if big != "":
			var bl: Label = DDUi.label(big, 80 if not wide else 64, DDUi.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
			bl.add_theme_constant_override("outline_size", 14)
			bl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.92))
			bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			bl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			frame.add_child(bl)
		head.add_child(frame)
	elif big != "":
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
	_pop_in(root, card)
	opened.emit()


## The 2-line tooltip: a small picture (the art, the strength mark / hit burst or the big number),
## then t1 in bold and t2 in plain words.
func _open_tip(payload: Dictionary) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var kind: String = str(payload.get("kind", "D"))
	var card: PanelContainer = PanelContainer.new()
	card.name = "Tooltip"
	var st: StyleBoxFlat = DDUi.box(Color("0f1214"), DDUi.accent(kind), 3, 14, 16)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 14
	card.add_theme_stylebox_override("panel", st)
	var w: float = minf(620.0, vp.x - 32.0)
	card.custom_minimum_size = Vector2(w, 0)
	center.add_child(card)
	var h: HBoxContainer = DDUi.hbox(14)
	card.add_child(h)
	var pic_d: float = 96.0
	var art: Variant = payload.get("art", null)
	if not (art is Texture2D) and payload.get("art_keys", null) is Array:
		art = ArtLib.texture_for(payload["art_keys"])
	var big: String = str(payload.get("big", ""))
	var has_pic: bool = art is Texture2D or payload.has("strength") or payload.has("hit") or big != ""
	if has_pic:
		var pic: PanelContainer = PanelContainer.new()
		pic.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg(kind), DDUi.accent(kind).darkened(0.3), 2, 10, 0))
		pic.custom_minimum_size = Vector2(pic_d, pic_d)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.clip_contents = true
		h.add_child(pic)
		var layer: Control = Control.new()
		pic.add_child(layer)
		if art is Texture2D:
			var tr: TextureRect = TextureRect.new()
			tr.texture = art
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer.add_child(tr)
		var mark: Control = null
		if payload.has("strength"):
			mark = Marks.StrengthMark.new(int(payload["strength"]))
		elif payload.has("hit"):
			mark = Marks.HitBurst.new(int(payload["hit"]))
		if mark != null:
			mark.position = Vector2(2, 2)
			mark.size = Vector2(44, 44)
			layer.add_child(mark)
		elif big != "" and not (art is Texture2D):
			var bl: Label = DDUi.label(big, 40 if big.length() <= 3 else 24, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer.add_child(bl)
	var v: VBoxContainer = DDUi.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t1: String = str(payload.get("t1", payload.get("title", "")))
	var t2: String = str(payload.get("t2", ""))
	if not payload.has("t2"):
		t2 = str(payload.get("body", "")).split("\n")[0]
	var tw: float = w - 32.0 - ((pic_d + 14.0) if has_pic else 0.0)
	var l1: Label = DDUi.label(t1, DDUi.FONT_M, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	l1.name = "Line1"
	l1.custom_minimum_size = Vector2(tw, 0)
	l1.add_theme_constant_override("outline_size", 1)
	l1.add_theme_color_override("font_outline_color", DDUi.TEXT)
	v.add_child(l1)
	if t2 != "":
		var l2: Label = DDUi.label(t2, DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
		l2.name = "Line2"
		l2.custom_minimum_size = Vector2(tw, 0)
		v.add_child(l2)
	last_lines = PackedStringArray([t1, t2])
	DDUi.ignore_mouse(root)
	visible = true
	_opened_ms = Time.get_ticks_msec()
	_pop_in(root, card)
	opened.emit()


## dd-feel: 120 ms fade + slight scale-up (fade only with reduce motion). Never blocks input.
func _pop_in(root: Control, card: Control) -> void:
	root.modulate.a = 0.0
	var tw: Tween = root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.12)
	var g: Node = get_node_or_null(^"/root/Game")
	if g != null and g.has_method(&"reduce_motion") and bool(g.call(&"reduce_motion")):
		return
	card.scale = Vector2(0.94, 0.94)
	(func() -> void:
		if is_instance_valid(card):
			card.pivot_offset = card.size * 0.5).call_deferred()
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
