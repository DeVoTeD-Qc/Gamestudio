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
#   nobody a grey keyline), so it reads without colour. It stays until a tap on it, or until the
#   player starts to plan (the controller hides it on select / drag / READY). Long-press or
#   right-click adds the one-line rule of how a column scores (studio rule: everything inspectable).
#   Not modal: only the panel itself takes taps.
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

var _title: Label = null
var _rows: VBoxContainer = null
var _score: Label = null
var _now: Label = null
var _rule: Label = null
var _gesture: RefCounted = null
## The last recap shown (tests): {title, rows, score, ...}.
var data: Dictionary = {}


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
	var x: Label = _label("✕", HEAD_FS, MUTED)
	x.name = "CloseMark"
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


func dismiss() -> void:
	if not visible:
		return
	visible = false
	_gesture.cancel()
	dismissed.emit()


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
