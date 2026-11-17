# dd_callout.gd
# Purpose: ui-pass-3 "explain once": the callout that explains one concept (DDConcepts) the first
#   time it is on screen. A gold ring marks the thing it explains (the rest of the screen dims a
#   little) and a small bubble sits beside it, never on it: icon + title, 1-2 plain sentences, and
#   "Got it". A tap anywhere (or Got it, Esc, Enter) dismisses it.
#   Safety (the KillingCard recap bug, where a tap on an overlay pressed Ready underneath): while it
#   is open, the whole screen is one catcher that eats every press and release, so a dismissing tap
#   can never reach a card or a button; it dismisses on the release of a press it saw itself (the
#   tail of an earlier gesture does nothing), and main.gd only opens it while no button is held.
#   Dismissing never calls the rules: it emits `dismissed(id)` and main.gd only marks the concept
#   seen and looks for the next one.
# Dependencies: DDUi, DDConcepts, scripts/ui/dd_codex.gd (Guide icons).
# Author: UI/UX Agent (ui-pass-3)
extends Control

signal dismissed(id: String)

const RING: Color = Color("f0c040")
const DIM: Color = Color(0, 0, 0, 0.42)
const GAP: float = 14.0
const PAD: float = 8.0
## Taps that start this soon after the callout opens don't dismiss it (they were aimed at the game:
## a card, a banner that just closed). ui-pass-3 follow-up: 600 ms, the same grace main.gd keeps
## after a banner / overlay closes or a finger lifts before it opens one.
const GUARD_MS: int = 600

var concept: String = ""
var anchor_rect: Rect2 = Rect2()
var bubble: PanelContainer = null
var _press_seen: bool = false
var _opened_ms: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_open() -> bool:
	return visible and concept != ""


## Opens the callout for concept `id` next to `anchor` (a global rect in this control's space).
func open(id: String, title: String, text: String, anchor: Rect2, icon_id: String = "") -> void:
	close_now()
	concept = id
	anchor_rect = anchor
	_press_seen = false
	_opened_ms = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	var vp: Vector2 = get_viewport_rect().size
	var b: PanelContainer = DDUi.skin_panel(DDUi.panel(Color("16202a"), 14, RING, 3), "modal", 16)
	b.name = "Callout"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = minf(vp.x - 24.0, 520.0 if vp.x > vp.y else 460.0)
	b.custom_minimum_size = Vector2(w, 0)
	add_child(b)
	bubble = b
	var v: VBoxContainer = DDUi.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head: HBoxContainer = DDUi.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	if icon_id != "":
		var Codex: GDScript = load("res://scripts/ui/dd_codex.gd")
		var ic: Control = Codex.call("icon", icon_id)
		ic.custom_minimum_size = Vector2(44, 44)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(ic)
	var tl: Label = DDUi.label(title, DDUi.FONT_M, RING, HORIZONTAL_ALIGNMENT_LEFT, true)
	tl.name = "CalloutTitle"
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tl)
	var row: HBoxContainer = DDUi.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var tx: Label = DDUi.label(text, DDUi.FONT_S, DDUi.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	tx.name = "CalloutText"
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.custom_minimum_size = Vector2(maxf(120.0, w - 32.0 - 124.0), 0)
	row.add_child(tx)
	# the same name as the old first-run hint's button (web smoke / crash-reload tools tap it)
	var ok: Button = DDUi.button("Got it", Color("245236"), DDUi.FONT_S)
	ok.name = "HintOk"
	ok.custom_minimum_size = Vector2(112, DDUi.TAP_MIN)
	ok.size_flags_vertical = Control.SIZE_SHRINK_END
	ok.focus_mode = Control.FOCUS_NONE
	ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ok)
	_place.call_deferred()
	queue_redraw()
	if not _reduce_motion():
		b.modulate.a = 0.0
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "modulate:a", 1.0, 0.18)


## Puts the bubble beside the anchor (below, above, right, left: the first side where it fits
## without touching the anchor; else the side with the most room), inside the screen.
func _place() -> void:
	if bubble == null or not is_instance_valid(bubble):
		return
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = bubble.get_combined_minimum_size()
	bubble.size = sz
	bubble.position = place_rect(anchor_rect, sz, vp)


## Where a bubble of size `sz` goes for `anchor` on a `vp` screen (static: tested).
static func place_rect(anchor: Rect2, sz: Vector2, vp: Vector2) -> Vector2:
	var cx: float = clampf(anchor.get_center().x - sz.x * 0.5, PAD, maxf(PAD, vp.x - sz.x - PAD))
	var cy: float = clampf(anchor.get_center().y - sz.y * 0.5, PAD, maxf(PAD, vp.y - sz.y - PAD))
	var options: Array = [
		[Vector2(cx, anchor.end.y + GAP), vp.y - anchor.end.y],
		[Vector2(cx, anchor.position.y - GAP - sz.y), anchor.position.y],
		[Vector2(anchor.end.x + GAP, cy), vp.x - anchor.end.x],
		[Vector2(anchor.position.x - GAP - sz.x, cy), anchor.position.x],
	]
	var best: Vector2 = options[0][0]
	var best_overlap: float = INF
	for o: Array in options:
		var p: Vector2 = o[0]
		var r: Rect2 = Rect2(p, sz)
		var inside: bool = r.position.x >= PAD - 0.5 and r.position.y >= PAD - 0.5 and r.end.x <= vp.x - PAD + 0.5 and r.end.y <= vp.y - PAD + 0.5
		if inside and not r.intersects(anchor):
			return p
		# no clean side: the least overlap with the anchor, kept on screen
		var q: Vector2 = Vector2(clampf(p.x, PAD, maxf(PAD, vp.x - sz.x - PAD)), clampf(p.y, PAD, maxf(PAD, vp.y - sz.y - PAD)))
		var ov: Rect2 = Rect2(q, sz).intersection(anchor)
		var area: float = ov.get_area() if Rect2(q, sz).intersects(anchor) else 0.0
		if area < best_overlap:
			best_overlap = area
			best = q
	return best


func _draw() -> void:
	if not is_open():
		return
	var vp: Vector2 = get_viewport_rect().size
	var h: Rect2 = anchor_rect.grow(6.0).intersection(Rect2(Vector2.ZERO, vp))
	# the dim around the hole, the hole itself clear
	draw_rect(Rect2(0, 0, vp.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, vp.x, vp.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, vp.x - h.end.x, h.size.y), DIM)
	draw_rect(h, RING, false, 4.0)


func _gui_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		accept_event()
		if mb.pressed:
			# a tap in the first moment was meant for what was there before (a banner, a card): it is
			# eaten, and the callout stays to be read
			_press_seen = not in_guard()
		elif _press_seen:
			dismiss()
	elif event is InputEventScreenTouch or event is InputEventMouseMotion:
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		if in_guard():
			# a key pressed for the screen before: eaten, the callout stays to be read
			get_viewport().set_input_as_handled()
			return
		dismiss()
		get_viewport().set_input_as_handled()


## True in the callout's first GUARD_MS: a tap or key then doesn't dismiss it.
func in_guard() -> bool:
	return Time.get_ticks_msec() - _opened_ms < GUARD_MS


## Got it / a tap: closes and tells main.gd which concept was read. Never touches the run.
func dismiss() -> void:
	if not is_open():
		return
	var id: String = concept
	close_now()
	dismissed.emit(id)


## Closes without marking anything (a screen change, an overlay opened on top).
func close_now() -> void:
	concept = ""
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null
	queue_redraw()


func _reduce_motion() -> bool:
	var g: Node = get_node_or_null(^"/root/Game")
	return g != null and g.has_method(&"reduce_motion") and bool(g.call(&"reduce_motion"))
