# dev_panel.gd
# Purpose: The hidden dev panel (cz13, spec §16.8), opened by holding the Title logo for 2 s.
#   One row per tunable the playtest switches: hand size, F1-F8 and the visibility switches (plus
#   the two supply-drop switches that §16.4a ties to hand size). Each row offers exactly
#   BalanceConfig's allowed values (dev_panel_overrides.gd; the final-circle list offers allowed
#   presets). The current value is a light plate with a check-mark icon; a changed value is marked
#   "≠ shipped". Setting hand size 4 also sets supply drop cost 3 (§16.4a) and says so.
#   Changes apply to NEW matches only; the panel says that, and the Title shows a
#   "DEV SETTINGS ACTIVE" tag while any override is on. RESET ALL returns to the shipped values.
# Signals: changed (any value), closed.
# Dependencies: dev_panel_overrides.gd, setup_ui.gd, BalanceConfig.
# Author: UI/UX Agent (cz13)
extends Control

const DevOverrides: GDScript = preload("res://scripts/ui/dev_panel_overrides.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")

signal changed
signal closed

var _panel: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
var _tag: Label
var _buttons: Dictionary = {}   # "key=value_index" -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SetupUI.dim_layer(0.85))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "DevPanelBox"
	_panel.theme_type_variation = &"ShellPanel"
	center.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_panel.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	col.add_child(head)
	var title: Label = SetupUI.label("DEV SETTINGS", &"ShellHeading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_tag = SetupUI.label("DEV SETTINGS ACTIVE", &"ShellTag")
	_tag.name = "DevActiveTag"
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tag)
	_note = SetupUI.label("", &"ShellMuted", true)
	_note.name = "DevNote"
	col.add_child(_note)
	_scroll = ScrollContainer.new()
	_scroll.name = "DevScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var reset: Button = SetupUI.button("RESET ALL", &"Button")
	reset.name = "DevReset"
	reset.pressed.connect(_on_reset)
	row.add_child(reset)
	var close_b: Button = SetupUI.button("CLOSE", &"DockButton")
	close_b.name = "DevClose"
	close_b.pressed.connect(close)
	row.add_child(close_b)
	_buttons[&"reset"] = reset
	_buttons[&"close"] = close_b
	resized.connect(_fit)
	visible = false


func open() -> void:
	visible = true
	_note.text = "Changes apply to NEW matches only. A saved match keeps its own rules."
	_rebuild()
	_fit()


func close() -> void:
	visible = false
	closed.emit()


## The button for one value of a key (tests): option index in DevOverrides.options(key).
func get_option_button(key: StringName, index: int) -> Button:
	return _buttons.get("%s=%d" % [key, index])


## Scrolls a key's row into view.
func reveal(key: StringName) -> void:
	var b: Button = get_option_button(key, 0)
	if b != null:
		_scroll.ensure_control_visible(b)


func get_button(key: StringName) -> Button:
	return _buttons.get(key)


func get_note() -> String:
	return _note.text


func is_tag_shown() -> bool:
	return _tag.visible


func _rebuild() -> void:
	for c: Node in _list.get_children():
		(c as CanvasItem).hide()  # freed at the end of the frame (the pressed button may be one of them)
		c.queue_free()
	for k: Variant in _buttons.keys():
		if k is String:
			_buttons.erase(k)
	for g: Array in DevOverrides.GROUPS:
		var head: Label = SetupUI.label(String(g[0]), &"CaptionStrong")
		_list.add_child(head)
		for key: StringName in g[1]:
			_list.add_child(_key_row(key))
	_tag.visible = DevOverrides.is_active()


func _key_row(key: StringName) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % key
	row.add_theme_constant_override(&"separation", 6)
	var current: Variant = DevOverrides.value(key)
	var shipped: Variant = DevOverrides.shipped(key)
	var changed_mark: String = "" if DevOverrides._same(current, shipped) else "  ≠ shipped"
	var l: Label = SetupUI.label(DevOverrides.key_text(key) + changed_mark, &"ShellBody")
	l.custom_minimum_size.x = 260.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var opts: Array = DevOverrides.options(key)
	for i: int in opts.size():
		var v: Variant = opts[i]
		var b: Button = SetupUI.button(DevOverrides.value_text(key, v), &"SegOff")
		b.name = "Opt_%s_%d" % [key, i]
		b.custom_minimum_size = Vector2(SetupUI.TAP_PX * 1.2, SetupUI.TAP_PX)
		var on: bool = DevOverrides._same(v, current)
		SetupUI.set_seg(b, on, opts.size() > 1)
		var value: Variant = v
		b.pressed.connect(func() -> void: _on_pick(key, value))
		row.add_child(b)
		_buttons["%s=%d" % [key, i]] = b
	if opts.size() == 1:
		row.add_child(SetupUI.label("(the only allowed value)", &"ShellMuted"))
	return row


func _on_pick(key: StringName, v: Variant) -> void:
	var before_cost: Variant = DevOverrides.value(&"supply_drop_cost")
	if not DevOverrides.set_value(key, v):
		_note.text = "%s = %s isn't allowed (allowed: %s)." % [key, DevOverrides.value_text(key, v), BalanceConfig.allowed_text(key)]
		return
	var msg: String = "%s set to %s for new matches." % [DevOverrides.key_text(key), DevOverrides.value_text(key, v)]
	if key == &"hand_size" and DevOverrides.value(&"supply_drop_cost") != before_cost:
		msg += " Supply drop cost set to %s with it (spec §16.4a)." % str(DevOverrides.value(&"supply_drop_cost"))
	var y: float = _scroll.scroll_vertical
	_rebuild()
	_note.text = msg
	_restore_scroll.call_deferred(y)
	changed.emit()


func _restore_scroll(y: float) -> void:
	_scroll.scroll_vertical = int(y)


func _on_reset() -> void:
	DevOverrides.reset()
	_rebuild()
	_note.text = "Back to the shipped values. Changes apply to new matches only."
	changed.emit()


func _fit() -> void:
	if _panel == null:
		return
	_panel.custom_minimum_size.x = minf(900.0, size.x - 32.0)
	_scroll.custom_minimum_size.y = maxf(160.0, size.y - 64.0 - 220.0)
	_note.custom_minimum_size.x = _panel.custom_minimum_size.x - 48.0
