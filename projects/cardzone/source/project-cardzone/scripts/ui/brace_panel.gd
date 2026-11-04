# brace_panel.gd
# Purpose: The Brace prompt (cz12): shown over the hand area (empty on the rival's turn) when the
#   human must brace. A view only: MatchScreen fills it with show_prompt(data) and handles option(key).
#   Left:  INCOMING · <weapon> FROM <area>
#          DMG 3 − Cover 1 − Down 0 = 2 damage          (the sum, in words and numbers)
#          YOU TAKE 2 HITS · HEALTH 4 -> 2               (live: follows the cards chosen)
#          one short line: the suggestion and why / your choice / what comes up instead
#   Right: USE SUGGESTED (or CLEAR once chosen)  ·  BRACE · 0 HITS / TAKE 2 HITS
#   So the suggested brace is 2 taps (USE SUGGESTED, BRACE); adjusting is taps on the next-hand
#   cards (the strip, marked SUGGESTED under the suggested ones) then BRACE.
#   Fitting (cz19b BUG-05 / BUG-09): the panel never cuts its key lines. The source line and the sum
#   wrap; the result line goes onto two lines ("YOU TAKE 2 HITS" / "HEALTH 4 -> 2") and then a
#   smaller size (down to the 16 px body floor, >= 11 pt) when one line does not fit, so the health
#   after the Brace always shows; the buttons are only as wide as their words need; the
#   suggestion line gets the lines that are left. On tall screens (tablets) MatchScreen passes a
#   text scale (data "scale") so the panel's text and buttons grow with the extra room.
# Keys (option signal, button meta "key"): &"brace_suggested", &"brace_clear", &"brace".
# Dependencies: match_theme.gd variations (DockPanel, CaptionStrong, Caption, KeyNumber, DockButton).
# Author: UI/UX Agent (cz12)
extends PanelContainer

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")

signal option(key: StringName)

const BUTTON_W: float = 236.0
## Smallest text in the panel (logical px): the body floor (MatchTheme.FONT_BODY, >= 11 pt).
const MIN_TEXT_PX: int = 16
## Room around a button's words (stylebox + breathing space), logical px.
const BUTTON_PAD: float = 36.0

var _title: Label
var _sum: Label
var _result: Label
var _line: Label
var _buttons: VBoxContainer
var _keys: Array[StringName] = []
var _row: HBoxContainer
var _col: VBoxContainer
## The result as given (get_texts); the label may show it on two lines.
var _result_text: String = ""
var _scale: float = 1.0
var _tap: float = 64.0
## The room MatchScreen gives the panel (over the hand area); the panel uses its full width and
## only the height its content needs (set_area).
var _area: Rect2 = Rect2()


func _init() -> void:
	name = "BracePanel"
	theme_type_variation = &"DockPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_row = row
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_col = col
	_title = _label(col, "BraceTitle", &"CaptionStrong")
	_sum = _label(col, "BraceSum", &"Caption")
	_result = _label(col, "BraceResult", &"KeyNumber")
	_line = _label(col, "BraceLine", &"Caption")
	for l: Label in [_title, _sum, _line]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = false
	# Key lines never trim (an autowrapped label that may trim reports no minimum height).
	for l: Label in [_title, _sum, _result]:
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_result.clip_text = false
	# No trimming: an autowrapped label that may trim reports no minimum height, and the panel is
	# sized to its content. max_lines_visible (set in _fit) caps it to the room there is.
	_line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_line.max_lines_visible = 3
	_buttons = VBoxContainer.new()
	_buttons.name = "BraceButtons"
	_buttons.add_theme_constant_override(&"separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_buttons)
	resized.connect(_fit)


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.name = node_name
	l.theme_type_variation = variation
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## data: {title, sum, result, line, buttons: [{key, label, off (bool)}], tap (px), scale (text, 1 = phone/desktop)}.
func show_prompt(data: Dictionary) -> void:
	_title.text = String(data.get("title", ""))
	_sum.text = String(data.get("sum", ""))
	_result_text = String(data.get("result", ""))
	_result.text = _result_text
	_line.text = String(data.get("line", ""))
	var tap: float = float(data.get("tap", 64.0))
	_scale = maxf(1.0, float(data.get("scale", 1.0)))
	tap = ceilf(tap * _scale)
	_tap = tap
	var want: Array[StringName] = []
	for b: Dictionary in data.get("buttons", []):
		want.append(b["key"])
	if want != _keys:
		for c: Node in _buttons.get_children():
			_buttons.remove_child(c)
			c.queue_free()
		for b: Dictionary in data.get("buttons", []):
			var btn: Button = Button.new()
			var key: StringName = b["key"]
			btn.name = "Brace_%s" % String(key)
			btn.set_meta(&"key", key)
			btn.pressed.connect(func() -> void: option.emit(key), CONNECT_DEFERRED)
			_buttons.add_child(btn)
		_keys = want
	var i: int = 0
	for b: Dictionary in data.get("buttons", []):
		var btn: Button = _buttons.get_child(i)
		btn.text = String(b["label"])
		btn.theme_type_variation = &"DockButtonOff" if bool(b.get("off", false)) else &"DockButton"
		i += 1
	visible = true
	_fit()
	_fit.call_deferred()  # again once the labels have their new widths


## The room over the hand area. The panel takes the full width and as much height as it needs.
func set_area(r: Rect2) -> void:
	_area = r
	position = r.position
	size = r.size
	_fit()
	_shrink.call_deferred()


func _shrink() -> void:
	if not _area.has_area() or not visible:
		return
	var need: float = get_combined_minimum_size().y
	var h: float = clampf(need, 0.0, _area.size.y)
	if absf(size.y - h) > 0.5:
		size = Vector2(_area.size.x, h)


## Sizes the text and buttons to the panel (see the header). Runs on every prompt and resize.
func _fit() -> void:
	if _title == null or not visible:
		return
	var body_px: int = int(roundf(MatchTheme.FONT_BODY * _scale))
	var number_px: int = int(roundf(MatchTheme.FONT_NUMBER * _scale))
	for l: Label in [_title, _sum, _line]:
		l.add_theme_font_size_override(&"font_size", body_px)
	# Buttons: as wide as their words need (>= one tap target), at most BUTTON_W (scaled).
	var bw: float = _tap
	for b: Node in _buttons.get_children():
		var btn: Button = b
		btn.add_theme_font_size_override(&"font_size", body_px)
		var f: Font = btn.get_theme_font(&"font")
		if f != null:
			bw = maxf(bw, f.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, body_px).x + BUTTON_PAD)
	bw = ceilf(minf(bw, maxf(_tap, BUTTON_W * _scale)))
	for b: Node in _buttons.get_children():
		(b as Button).custom_minimum_size = Vector2(bw, _tap)
	var box: StyleBox = get_theme_stylebox(&"panel")
	var pad: Vector2 = box.get_minimum_size() if box != null else Vector2.ZERO
	var room: float = size.x - pad.x - bw - float(_row.get_theme_constant(&"separation"))
	if room <= 1.0:
		return
	# Result: one line, else two (split at the first " · "), else smaller down to the body floor.
	var rf: Font = _result.get_theme_font(&"font")
	var lines: PackedStringArray = [_result_text]
	var px: int = number_px
	if rf != null and _width(rf, lines, px) > room:
		var cut: int = _result_text.find(" · ")
		if cut > 0:
			lines = [_result_text.left(cut), _result_text.substr(cut + 3)]
		while px > MIN_TEXT_PX and _width(rf, lines, px) > room:
			px -= 1
	_result.text = "\n".join(lines)
	_result.add_theme_font_size_override(&"font_size", px)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if rf != null and _width(rf, lines, px) > room else TextServer.AUTOWRAP_OFF
	# Suggestion line: the lines left under the key lines.
	var lh: float = maxf(1.0, _line.get_line_height())
	var used: float = 0.0
	for l: Label in [_title, _sum, _result]:
		used += l.get_minimum_size().y + float(_col.get_theme_constant(&"separation"))
	var full_h: float = _area.size.y if _area.has_area() else size.y
	_line.max_lines_visible = clampi(int(floorf((full_h - pad.y - used) / lh)), 1, 4)
	_line.size_flags_vertical = Control.SIZE_FILL
	_shrink.call_deferred()


static func _width(f: Font, lines: PackedStringArray, px: int) -> float:
	var w: float = 0.0
	for t: String in lines:
		w = maxf(w, f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	return w


func get_button(key: StringName) -> Button:
	if not visible:
		return null
	for b: Node in _buttons.get_children():
		if b.get_meta(&"key", &"") == key and not b.is_queued_for_deletion():
			return b
	return null


func get_keys() -> Array[StringName]:
	return _keys.duplicate()


func get_texts() -> Dictionary:
	return {"title": _title.text, "sum": _sum.text, "result": _result_text, "line": _line.text}


## The result as shown (may hold a line break on small screens).
func get_result_shown() -> String:
	return _result.text


func get_labels() -> Array[Label]:
	return [_title, _sum, _result, _line]
