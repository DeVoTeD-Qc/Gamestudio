# new_card.gd
# Purpose: kc-onboard-ui (onboarding-progression.md §5.1-5.2): the one-time "New: X" explainer. A
#   half-screen card with the system's icon, one sentence, a mini example and GOT IT, shown at the
#   moment of use (a reward screen when the offer brings the system, the board when it is in play),
#   one per screen. Texts come from RevealFlags.text_of() (keyword tips: the card rules text);
#   GOT IT (or a tap outside the card) calls RunState.ack_explainer(flag), so it never shows again
#   until Settings "RESET TIPS". Long-press / right-click on the card says what it is (studio rule).
#   Art: pnl_new_card (card) and pnl_new_inset (example well) through UiKit.piece, else drawn.
# Usage: var nc := NewCard.new(); add_child(nc)
#        nc.offer(RevealFlags.run_triggers(run))   # shows the first pending explainer in that set
# Dependencies: RevealFlags, RunState (pending_explainers / ack_explainer), UiKit, SynergyGlyphs,
#   StandardIssueLook, card_info.gd (keyword rules), PressGesture.
# Author: UI/UX Agent (kc-onboard-ui)
class_name NewCard
extends Control

signal acknowledged(flag: StringName)

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const AMBER: Color = Color("#FFB020")
const FACE: Color = Color("#232A31")
const EDGE: Color = Color("#4A535B")
const ABOUT: String = "A one-time tip about something new. MENU > RESET TIPS shows the tips again."
## Keyword tip flag -> CardInfo.KEYWORD_RULES id (the printed keywords' tips use the card text).
const TIP_RULES: Dictionary = {&"kw_front": &"arrives_front"}

## Shows explainers on its own (offer()). Off in headless runs so the screen tests can tap through
## without dismissing tips; the onboarding UI tests switch it on.
static var auto_show: bool = DisplayServer.get_name() != "headless"

## The flag on show (&"" = closed).
var flag: StringName = &""
## Screen key of the last explainer shown (one per screen).
var _shown_for: String = ""
var _card: Control = null
var _icon: Control = null
var _title: Label = null
var _text: Label = null
var _example: Control = null
var _got_it: Button = null
var _about: Label = null
var _gesture: RefCounted = null


func _init() -> void:
	name = "NewCard"
	visible = false
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Control.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_card.draw.connect(_draw_card)
	_icon = Control.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_icon)
	_icon.draw.connect(func() -> void: draw_example(_icon, Rect2(Vector2.ZERO, _icon.size), flag, true))
	_title = _label("", &"HudHeader", 24)
	_title.name = "TitleLabel"
	_title.add_theme_color_override(&"font_color", AMBER)
	_card.add_child(_title)
	_text = _label("", &"", 18)
	_text.name = "TextLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_text)
	_example = Control.new()
	_example.name = "Example"
	_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_example)
	_example.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, _example.size)
		if not UiKit.draw_piece(_example, &"pnl_new_inset", r):
			_example.draw_rect(r, Color("#0F1316"))
			_example.draw_rect(r, Color("#3A444D"), false, 1.0)
		draw_example(_example, r.grow(-8.0), flag, false))
	_about = _label(ABOUT, &"HudTag", 16)
	_about.name = "AboutLabel"
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.visible = false
	_card.add_child(_about)
	_got_it = Button.new()
	_got_it.name = "GotItButton"
	_got_it.text = "GOT IT"
	_got_it.theme_type_variation = &"HudButton"
	_got_it.focus_mode = Control.FOCUS_ALL
	_got_it.add_to_group(&"tap_target")
	_got_it.tooltip_text = "Close. This tip won't show again."
	_got_it.pressed.connect(acknowledge)
	_card.add_child(_got_it)
	_gesture = PressGesture.new(_card)
	_gesture.drag_enabled = false
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: inspect())
	_card.gui_input.connect(func(e: InputEvent) -> void:
		if _gesture.handle(e):
			_card.accept_event())
	resized.connect(_layout)


func _label(text: String, variation: StringName, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.add_theme_font_size_override(&"font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A tap outside the card counts as GOT IT (forgiving: nothing else on the screen needs a second tap).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		acknowledge()


## Shows the first pending explainer whose flag is in `relevant` (RunState.pending_explainers order),
## once per `screen_key`. Returns the flag shown (&"" = none). No-op while one is open.
func offer(relevant: Array, screen_key: String = "") -> StringName:
	if not auto_show or visible or (screen_key != "" and screen_key == _shown_for):
		return &""
	var rs: Node = _run_state()
	if rs == null:
		return &""
	for f: StringName in rs.pending_explainers():
		# kc-pos-cut: units no longer link; the "New: Links" card is never offered.
		if f == RevealFlags.LINKS:
			continue
		if f in relevant and not RevealFlags.text_of(f).is_empty():
			_shown_for = screen_key
			show_flag(f)
			return f
	return &""


## Opens the card for `f` (tests and QA call it directly).
func show_flag(f: StringName) -> void:
	flag = f
	var t: Dictionary = text_for(f)
	_title.text = String(t.get("title", "New")).to_upper()
	_text.text = String(t.get("text", ""))
	_about.visible = false
	visible = true
	_layout()
	_icon.queue_redraw()
	_example.queue_redraw()
	if not DisplayServer.is_touchscreen_available():
		_got_it.grab_focus.call_deferred()


## {title, text} of a flag: RevealFlags.text_of, with the card's own rules line for a keyword tip.
static func text_for(f: StringName) -> Dictionary:
	var t: Dictionary = RevealFlags.text_of(f).duplicate()
	if String(t.get("text", "")) == "" and RevealFlags.KEYWORD_TIPS.has(f):
		var id: StringName = TIP_RULES.get(f, StringName(String(f).trim_prefix(RevealFlags.KW_PREFIX)))
		if CardInfo.KEYWORD_RULES.has(id):
			var row: Array = CardInfo.KEYWORD_RULES[id]
			t["text"] = String(row[1]).replace("%d", "1")
	return t


## GOT IT: never again (RunState.ack_explainer), then close.
func acknowledge() -> void:
	if flag == &"":
		visible = false
		return
	var f: StringName = flag
	var rs: Node = _run_state()
	if rs != null:
		rs.ack_explainer(f)
	flag = &""
	visible = false
	acknowledged.emit(f)


## Long-press / right-click: what this card is.
func inspect() -> void:
	_about.visible = true
	_layout()


func is_open() -> bool:
	return visible and flag != &""


func get_got_it_button() -> Button:
	return _got_it


func get_card() -> Control:
	return _card


func _run_state() -> Node:
	return get_node_or_null(^"/root/RunState") if is_inside_tree() else null


func _layout() -> void:
	if not visible or size.x <= 0.0:
		return
	var compact: bool = size.y < 640.0
	var w: float = clampf(size.x * 0.56, 440.0, 620.0)
	var pad: float = 18.0
	var icon_s: float = 64.0
	var tx: float = pad + icon_s + 14.0
	var tw: float = w - tx - pad
	_title.position = Vector2(tx, pad)
	_title.size = Vector2(tw, _title.get_combined_minimum_size().y)
	_text.custom_minimum_size.x = tw
	_text.size = Vector2(tw, 0)
	_text.position = Vector2(tx, _title.position.y + _title.size.y + 4.0)
	var text_h: float = _wrapped_h(_text, tw)
	_text.size.y = text_h
	var y: float = _text.position.y + text_h + 10.0
	var ex_h: float = 84.0 if compact else 110.0
	_example.position = Vector2(tx, y)
	_example.size = Vector2(tw, ex_h)
	y += ex_h + 8.0
	if _about.visible:
		_about.custom_minimum_size.x = tw
		_about.position = Vector2(tx, y)
		_about.size = Vector2(tw, _wrapped_h(_about, tw))
		y += _about.size.y + 6.0
	var bh: float = 64.0
	_got_it.size = Vector2(200, bh)
	_got_it.position = Vector2(w - pad - 200.0, y)
	y += bh + pad
	_icon.position = Vector2(pad, pad + 6.0)
	_icon.size = Vector2(icon_s, icon_s)
	_card.size = Vector2(w, y)
	_card.position = Vector2(roundf((size.x - w) * 0.5), roundf(maxf(4.0, (size.y - y) * 0.5)))
	_card.queue_redraw()


## Height of a wrapped label's text at width w (its own font and size).
static func _wrapped_h(l: Label, w: float) -> float:
	var font: Font = l.get_theme_font(&"font")
	var fs: int = l.get_theme_font_size(&"font_size")
	var para := TextParagraph.new()
	para.add_string(l.text, font, fs)
	para.width = w
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return ceilf(para.get_size().y + l.get_theme_constant(&"line_spacing") * maxi(0, para.get_line_count() - 1)) + 2.0


func _draw_card() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _card.size)
	if UiKit.draw_piece(_card, &"pnl_new_card", r):
		return
	var c: float = 14.0
	var pts: PackedVector2Array = [Vector2(c, 0), Vector2(r.end.x - c, 0), Vector2(r.end.x, c), Vector2(r.end.x, r.end.y - c),
			Vector2(r.end.x - c, r.end.y), Vector2(c, r.end.y), Vector2(0, r.end.y - c), Vector2(0, c)]
	_card.draw_colored_polygon(pts, FACE)
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	_card.draw_polyline(outline, EDGE, 2.0)
	_card.draw_line(Vector2(c, 1.5), Vector2(r.end.x - c, 1.5), AMBER, 2.0)
	_card.draw_rect(Rect2(c + 4.0, 0, 44.0, 8.0), AMBER)


## The flag's mini example (or, with `icon`, its icon) drawn in r on ci.
static func draw_example(ci: CanvasItem, r: Rect2, f: StringName, icon: bool) -> void:
	if r.size.x <= 4.0 or r.size.y <= 4.0:
		return
	var font: Font = ThemeDB.fallback_font
	var fog: Color = Color("#D8DEE3")
	var s: float = minf(r.size.y, r.size.x)
	var sq: Rect2 = Rect2(r.position + Vector2((r.size.x - s) * 0.5 if icon else 0.0, (r.size.y - s) * 0.5), Vector2(s, s))
	var trait_id: StringName = &"vanguard"
	match f:
		RevealFlags.CALLING_CARDS, RevealFlags.DOCTRINE, RevealFlags.TRAIT_RAIL:
			if icon:
				SynergyGlyphs.draw_trait_plate(ci, sq.grow(-6.0), trait_id, true, false)
				return
			# A plain Standard Issue banner next to a calling card with its trait plate, and "2/3".
			var bw: float = minf(r.size.x * 0.42, r.size.y * 2.6)
			var bh: float = bw / 4.0
			var a: Rect2 = Rect2(r.position + Vector2(0, (r.size.y - bh) * 0.5), Vector2(bw, bh))
			ci.draw_rect(a, Color("#2B312A"))
			StandardIssueLook.draw_frame(ci, a)
			var b: Rect2 = Rect2(a.end.x + 16.0, a.position.y, bw, bh)
			ci.draw_rect(b, Color("#1C2228"))
			ci.draw_rect(b, Color("#B9C2C9"), false, 1.5)
			var p: float = bh * 0.5
			SynergyGlyphs.draw_trait_plate(ci, Rect2(b.position + Vector2(4, bh - p - 4), Vector2(p, p)), trait_id, true, false)
			ci.draw_string(font, Vector2(b.end.x + 10.0, b.get_center().y + 7.0), "2/3", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					SynergyGlyphs.trait_color(trait_id))
		RevealFlags.KEYWORDS:
			_draw_unlock(ci, r if not icon else sq, icon, &"first_shot")
		RevealFlags.ENGINE_PANEL:
			# kc-ipad-cards: the trait counts of a deck (no level coins: there is no training).
			var cs: float = minf(r.size.y - 4.0, 30.0)
			var y: float = r.get_center().y - cs * 0.5
			for i: int in 3:
				var tid: StringName = SynergyRules.TRAITS[i]
				var tr: Rect2 = Rect2(r.position.x + i * (cs + 30.0), y, cs, cs)
				SynergyGlyphs.draw_trait_plate(ci, tr, tid, true, false)
				ci.draw_string(font, Vector2(tr.end.x + 4.0, tr.get_center().y + 7.0), str(3 - i), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fog)
		RevealFlags.MUSTER_OUT:
			var bw3: float = minf(r.size.x * (0.9 if icon else 0.45), r.size.y * 3.2)
			var bh3: float = bw3 / 4.0
			var c: Rect2 = Rect2(r.position + Vector2(0.0, (r.size.y - bh3) * 0.5), Vector2(bw3, bh3))
			ci.draw_rect(c, Color("#2B312A"))
			StandardIssueLook.draw_frame(ci, c)
			if not icon:
				var ax: float = c.end.x + 14.0
				ci.draw_line(Vector2(ax, c.get_center().y), Vector2(ax + 40.0, c.get_center().y), AMBER, 3.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(ax + 48.0, c.get_center().y), Vector2(ax + 38.0, c.get_center().y - 7.0),
						Vector2(ax + 38.0, c.get_center().y + 7.0)]), AMBER)
				ci.draw_string(font, Vector2(ax + 56.0, c.get_center().y + 7.0), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fog)
		RevealFlags.SALVAGE, RevealFlags.MULTI_PICK:
			var n: int = 2 if f == RevealFlags.SALVAGE else 4
			var ch: float = r.size.y - 4.0
			var cw: float = minf(ch * 0.7, (r.size.x - 6.0 * (n - 1)) / n)
			for k: int in n:
				var cr: Rect2 = Rect2(r.position.x + k * (cw + 6.0), r.position.y + 2.0, cw, ch)
				ci.draw_rect(cr, Color("#1C2228"))
				ci.draw_rect(cr, AMBER if (k < 2 and f == RevealFlags.MULTI_PICK) or (k == 0 and f == RevealFlags.SALVAGE) else Color("#5A646C"), false, 2.0)
		RevealFlags.FIELDS:
			ci.draw_rect(Rect2(sq.position + Vector2(0, s * 0.3), Vector2(sq.size.x, s * 0.4)), Color("#2E3740"))
			ci.draw_line(sq.position + Vector2(s * 0.5, s * 0.15), sq.position + Vector2(s * 0.5, s * 0.85), AMBER, 3.0)
		RevealFlags.ELITES:
			BannerView.draw_star(ci, sq.get_center(), s * 0.4, Color("#C9A227"))
		_:
			if RevealFlags.KEYWORD_TIPS.has(f):
				var kw: StringName = StringName(String(f).trim_prefix(RevealFlags.KW_PREFIX))
				_draw_unlock(ci, r if not icon else sq, icon, kw)
			else:
				ci.draw_circle(sq.get_center(), s * 0.3, AMBER)


## The keyword's icon, lit (kc-ipad-cards: no locked socket or arrow: keywords are never locked).
static func _draw_unlock(ci: CanvasItem, r: Rect2, icon: bool, kw: StringName) -> void:
	var s: float = minf(r.size.y, 56.0)
	var lit: Rect2 = Rect2(r.position + Vector2((r.size.x - s) * 0.5 if icon else 0.0, (r.size.y - s) * 0.5), Vector2(s, s))
	ci.draw_rect(lit, Color(0.05, 0.06, 0.07, 0.85))
	ci.draw_rect(lit, AMBER, false, 1.5)
	var tex: Texture2D = IconSheet.get_keyword_icon(kw) if IconSheet.KEYWORD_ICONS.has(kw) else null
	if tex != null:
		ci.draw_texture_rect(tex, lit.grow(-s * 0.14), false, AMBER)
	elif SynergyGlyphs.KEYWORD_NAMES.has(kw):
		SynergyGlyphs.draw_keyword_icon(ci, lit.grow(-s * 0.16), kw, AMBER)
	elif kw == &"pierce":
		SynergyGlyphs.draw_pierce_icon(ci, lit.grow(-s * 0.16), AMBER)
	else:
		ci.draw_circle(lit.get_center(), s * 0.22, AMBER)
