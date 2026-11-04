# pause_menu.gd
# Purpose: CardZone pause menu (cz13), a modal overlay over the match (MatchShell opens it from
#   MENU) and, settings-only, over the Title (SETTINGS). Pages:
#     main      RESUME · RULES · SETTINGS · CONCEDE… · LEAVE TO TITLE (the match stays saved:
#               CONTINUE on the title picks it up)
#     rules     a short rules summary (scrolls)
#     settings  REDUCED MOTION off/on, EVENT SPEED normal/fast/instant (pause_settings.gd), and
#               SHOW TIPS AGAIN (resets the first-match coach)
#     concede   confirm: CONCEDE / KEEP PLAYING
#   Every page has a way back; nothing is hover-only; buttons >= 64 px, text >= 16 px.
# Signals: resumed, concede_confirmed, leave_requested, settings_changed, closed.
# Dependencies: setup_ui.gd, pause_settings.gd, coach_tips.gd.
# Author: UI/UX Agent (cz13)
extends Control

const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const PauseSettings: GDScript = preload("res://scripts/ui/pause_settings.gd")
const CoachTips: GDScript = preload("res://scripts/ui/coach_tips.gd")

signal resumed
signal concede_confirmed
signal leave_requested
signal settings_changed
## The menu closed (any way).
signal closed

const RULES_TEXT: String = """GOAL  Be the last one standing. Shots, Frags, the gas and the final circle put Hits on you; with no health left you are out. If the Zone deck runs out (the hard end), more health wins.

YOUR TURN  You draw your next hand from the top of your loadout. Play cards to your line for MOVE and SEARCH; move to a neighbouring area; loot the piles in your area with Search; fire weapons in your line at the rival in range. UNDO works until you fire.

PACK  END TURN, then tap up to 2 hand cards to HOLD them on top. Everything else goes under your loadout, so your cards come round again.

BRACE  When you are shot, armour in your NEXT HAND can stop Hits. Braced cards go to the bottom.

HITS  A Hit goes on top of your loadout. While it is in your next draw you are DOWN: shots at you deal 1 less. In your hand a Hit is ADRENALINE: play it for Move 1 or Search 1. PATCH UP (Search 2) heals 1.

ZONE  Each round flips a Zone card: gas closes areas and supply drops land. Cover in an area makes shots from other areas weaker. The final circle hurts everyone still standing."""

## Title mode: settings only, CLOSE instead of BACK.
var settings_only: bool = false
## The page on screen: &"main", &"rules", &"settings", &"concede".
var page: StringName = &"main"

var _panel: PanelContainer
var _title: Label
var _content: VBoxContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SetupUI.dim_layer(0.72))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.theme_type_variation = &"ShellPanel"
	center.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_panel.add_child(col)
	_title = SetupUI.label("PAUSED", &"ShellHeading")
	_title.name = "PauseTitle"
	col.add_child(_title)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 8)
	col.add_child(_content)
	resized.connect(_fit)
	visible = false


## Opens on the main page (settings_only: on the settings page).
func open() -> void:
	visible = true
	show_page(&"settings" if settings_only else &"main")


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func show_page(p: StringName) -> void:
	page = p
	_buttons.clear()
	for c: Node in _content.get_children():
		(c as CanvasItem).hide()  # freed at the end of the frame (the pressed button may be one of them)
		c.queue_free()
	match p:
		&"main":
			_title.text = "PAUSED"
			_row([_btn(&"resume", "RESUME", &"DockButton")])
			_row([_btn(&"rules", "RULES"), _btn(&"settings", "SETTINGS")])
			_row([_btn(&"concede", "CONCEDE…"), _btn(&"leave", "LEAVE TO TITLE")])
			_content.add_child(SetupUI.label("Your match is saved after every move: CONTINUE on the title picks it up.", &"ShellMuted", true))
		&"rules":
			_title.text = "RULES"
			var scroll: ScrollContainer = ScrollContainer.new()
			scroll.name = "RulesScroll"
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size.y = _scroll_height()
			var text: Label = SetupUI.label(RULES_TEXT, &"ShellBody", true)
			text.name = "RulesText"
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(text)
			_content.add_child(scroll)
			_row([_btn(&"back", "BACK")])
		&"settings":
			_title.text = "SETTINGS"
			_settings_rows()
			_row([_btn(&"back", "CLOSE" if settings_only else "BACK")])
		&"concede":
			_title.text = "CONCEDE?"
			_content.add_child(SetupUI.label("The rival wins this match and your saved match is cleared.", &"ShellBody", true))
			_row([_btn(&"keep_playing", "KEEP PLAYING", &"DockButton"), _btn(&"concede_yes", "CONCEDE", &"Button")])
	_fit()
	var first: Button = _buttons.values()[0] if not _buttons.is_empty() else null
	if first != null and is_inside_tree():
		first.grab_focus.call_deferred()


func get_button(key: StringName) -> Button:
	return _buttons.get(key)


func get_title_text() -> String:
	return _title.text


func get_text_labels() -> Array[Label]:
	var out: Array[Label] = [_title]
	for l: Node in _content.find_children("*", "Label", true, false):
		out.append(l)
	return out


func _settings_rows() -> void:
	var motion: bool = PauseSettings.reduced_motion()
	_setting_row("REDUCED MOTION", [[&"motion_off", "OFF", not motion], [&"motion_on", "ON", motion]])
	var speed: String = PauseSettings.event_speed()
	var opts: Array = []
	for s: String in PauseSettings.SPEEDS:
		opts.append([StringName("speed_" + s), PauseSettings.speed_text(s), s == speed])
	_setting_row("EVENT SPEED", opts)
	var seen: int = CoachTips.seen_count()
	var tips: HBoxContainer = _setting_row("FIRST-MATCH TIPS", [])
	var reset: Button = _btn(&"reset_tips", "SHOW TIPS AGAIN")
	reset.disabled = seen == 0
	tips.add_child(reset)
	_content.add_child(SetupUI.label("%d of %d tips seen. Event speed sets how fast the rival's moves play out." % [
			seen, CoachTips.TIPS.size()], &"ShellMuted", true))


func _setting_row(text: String, opts: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var l: Label = SetupUI.label(text, &"CaptionStrong")
	l.custom_minimum_size.x = 210.0
	row.add_child(l)
	for o: Array in opts:
		var b: Button = _btn(o[0], o[1])
		b.custom_minimum_size.x = SetupUI.TAP_PX * 1.6
		SetupUI.set_seg(b, o[2])
		row.add_child(b)
	_content.add_child(row)
	return row


func _btn(key: StringName, text: String, variation: StringName = &"Button") -> Button:
	var b: Button = SetupUI.button(text, variation)
	b.name = "Pause_%s" % key
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _on_button(key))
	_buttons[key] = b
	return b


func _row(buttons: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	for b: Button in buttons:
		row.add_child(b)
	_content.add_child(row)


func _on_button(key: StringName) -> void:
	match key:
		&"resume":
			close()
			resumed.emit()
		&"rules":
			show_page(&"rules")
		&"settings":
			show_page(&"settings")
		&"back":
			if settings_only:
				close()
			else:
				show_page(&"main")
		&"concede":
			show_page(&"concede")
		&"keep_playing":
			show_page(&"main")
		&"concede_yes":
			close()
			concede_confirmed.emit()
		&"leave":
			close()
			leave_requested.emit()
		&"motion_off", &"motion_on":
			PauseSettings.set_reduced_motion(key == &"motion_on")
			show_page(&"settings")
			settings_changed.emit()
		&"reset_tips":
			CoachTips.reset()
			show_page(&"settings")
			settings_changed.emit()
		_:
			if String(key).begins_with("speed_"):
				PauseSettings.set_event_speed(String(key).trim_prefix("speed_"))
				show_page(&"settings")
				settings_changed.emit()


func _scroll_height() -> float:
	return clampf(size.y - 260.0, 160.0, 420.0)


func _fit() -> void:
	if _panel == null:
		return
	_panel.custom_minimum_size.x = minf(700.0, size.x - 48.0)
	for l: Node in _content.find_children("*", "Label", true, false):
		var label: Label = l as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			label.custom_minimum_size.x = minf(700.0, size.x - 48.0) - 48.0
