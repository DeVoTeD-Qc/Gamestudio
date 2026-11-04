# brace_panel.gd
# Purpose: The Brace prompt (cz12): shown over the hand area (empty on the rival's turn) when the
#   human must brace. A view only: MatchScreen fills it with show_prompt(data) and handles option(key).
#   Left:  INCOMING · <weapon> FROM <area>
#          DMG 3 − Cover 1 − Down 0 = 2 damage          (the sum, in words and numbers)
#          YOU TAKE 2 HITS · HEALTH 4 → 2                (live: follows the cards chosen)
#          one short line: the suggestion and why / your choice / what comes up instead
#   Right: USE SUGGESTED (or CLEAR once chosen)  ·  BRACE · 0 HITS / TAKE 2 HITS
#   So the suggested brace is 2 taps (USE SUGGESTED, BRACE); adjusting is taps on the next-hand
#   cards (the strip, marked SUGGESTED under the suggested ones) then BRACE.
# Keys (option signal, button meta "key"): &"brace_suggested", &"brace_clear", &"brace".
# Dependencies: match_theme.gd variations (DockPanel, CaptionStrong, Caption, KeyNumber, DockButton).
# Author: UI/UX Agent (cz12)
extends PanelContainer

signal option(key: StringName)

const BUTTON_W: float = 236.0

var _title: Label
var _sum: Label
var _result: Label
var _line: Label
var _buttons: VBoxContainer
var _keys: Array[StringName] = []


func _init() -> void:
	name = "BracePanel"
	theme_type_variation = &"DockPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_title = _label(col, "BraceTitle", &"CaptionStrong")
	_sum = _label(col, "BraceSum", &"Caption")
	_result = _label(col, "BraceResult", &"KeyNumber")
	_line = _label(col, "BraceLine", &"Caption")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_line.max_lines_visible = 3
	_buttons = VBoxContainer.new()
	_buttons.name = "BraceButtons"
	_buttons.add_theme_constant_override(&"separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_buttons)


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.name = node_name
	l.theme_type_variation = variation
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## data: {title, sum, result, line, buttons: [{key, label, off (bool)}], tap (px)}.
func show_prompt(data: Dictionary) -> void:
	_title.text = String(data.get("title", ""))
	_sum.text = String(data.get("sum", ""))
	_result.text = String(data.get("result", ""))
	_line.text = String(data.get("line", ""))
	var tap: float = float(data.get("tap", 64.0))
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
		btn.custom_minimum_size = Vector2(maxf(BUTTON_W, tap), tap)
		i += 1
	visible = true


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
	return {"title": _title.text, "sum": _sum.text, "result": _result.text, "line": _line.text}


func get_labels() -> Array[Label]:
	return [_title, _sum, _result, _line]
