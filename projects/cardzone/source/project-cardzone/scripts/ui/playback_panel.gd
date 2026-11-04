# playback_panel.gd
# Purpose: The rival's turn, played back step by step (cz12): shown over the hand area (empty
#   while the rival acts). A view only: MatchScreen feeds it the controller's playback steps.
#   Left:  RIVAL · VETERAN · STEP 4                 (title)
#          Rival moved to Quarry.                   (the current step, large)
#          Rival played Dash: Move +1. · Rival draws 5 cards.   (the two before it, smaller)
#   Right: FAST (the rest of this playback at FAST speed; FAST ON once pressed) · SKIP (all at once).
#   Steps are the controller's (events filtered for the human): the rival's private cards are
#   never in them.
# Keys (option signal, button meta "key"): &"fast", &"skip".
# Dependencies: match_theme.gd variations (DockPanel, CaptionStrong, Caption, KeyNumber, DockButton).
# Author: UI/UX Agent (cz12)
extends PanelContainer

signal option(key: StringName)

const BUTTON_W: float = 150.0
const HISTORY: int = 2

var steps: Array[String] = []
var step_count: int = 0

var _title: Label
var _now: Label
var _before: Label
var _fast: Button
var _skip: Button


func _init() -> void:
	name = "PlaybackPanel"
	theme_type_variation = &"DockPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_title = Label.new()
	_title.name = "PlaybackTitle"
	_title.theme_type_variation = &"CaptionStrong"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_title)
	_now = Label.new()
	_now.name = "PlaybackNow"
	_now.theme_type_variation = &"KeyNumber"
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_now.max_lines_visible = 2
	_now.custom_minimum_size = Vector2(0, 64)  # 2 lines at 24 px: an autowrap label needs its height
	_now.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_now.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_now)
	_before = Label.new()
	_before.name = "PlaybackBefore"
	_before.theme_type_variation = &"Caption"
	_before.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_before.max_lines_visible = 2
	_before.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_before.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_before.modulate = Color(1, 1, 1, 0.75)
	_before.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(_before)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.name = "PlaybackButtons"
	buttons.add_theme_constant_override(&"separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(buttons)
	_fast = _button(buttons, &"fast", "FAST")
	_skip = _button(buttons, &"skip", "SKIP")


func _button(parent: Node, key: StringName, label: String) -> Button:
	var b: Button = Button.new()
	b.name = "Playback_%s" % String(key)
	b.text = label
	b.theme_type_variation = &"DockButton"
	b.set_meta(&"key", key)
	b.pressed.connect(func() -> void: option.emit(key), CONNECT_DEFERRED)
	parent.add_child(b)
	return b


## A new playback (the rival's turn or drop): clears the steps.
func begin(title: String) -> void:
	steps.clear()
	step_count = 0
	_title.text = title
	_now.text = "…"
	_before.text = ""
	set_fast(false)


func set_title(title: String) -> void:
	_title.text = title


func add_step(text: String) -> void:
	steps.append(text)
	step_count += 1
	_now.text = text
	var older: Array[String] = []
	for i: int in range(steps.size() - 2, maxi(-1, steps.size() - 2 - HISTORY), -1):
		older.append(steps[i])
	_before.text = " · ".join(older)


func set_fast(on: bool) -> void:
	_fast.text = "FAST ON" if on else "FAST"
	_fast.theme_type_variation = &"DockButtonOff" if on else &"DockButton"


func set_tap(tap: float) -> void:
	for b: Button in [_fast, _skip]:
		b.custom_minimum_size = Vector2(maxf(BUTTON_W, tap), tap)


func get_button(key: StringName) -> Button:
	if not visible:
		return null
	return {&"fast": _fast, &"skip": _skip}.get(key, null)


func get_now_text() -> String:
	return _now.text


func get_title_text() -> String:
	return _title.text


func get_labels() -> Array[Label]:
	return [_title, _now, _before]
