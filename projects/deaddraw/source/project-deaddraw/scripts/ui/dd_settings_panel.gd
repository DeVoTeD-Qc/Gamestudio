# dd_settings_panel.gd
# Purpose: dd-feel. The Settings overlay: master volume, SFX volume, screen shake, reduce motion.
#   Every change goes through Game.set_setting(), which saves it in the profile (user://) and
#   applies it right away. Opened from the title, map and street screens; Done / Esc / tapping the
#   dim area closes it. Large touch targets (sliders 56 px tall, toggles 72 px).
# Dependencies: Game (autoload), DDUi, scripts/fx/dd_sfx.gd.
# Author: Game Feel Engineer Agent (dd-feel)
extends Control

const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")

signal closed
signal opened
## dd-ux-v4: the Menu also opens the Codex and the Help / Glossary.
signal codex_requested
signal help_requested

var _content: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if _content != null:
		_content.queue_free()
	var g: Node = get_node(^"/root/Game")
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
	var card: PanelContainer = DDUi.panel(DDUi.PANEL, 20, DDUi.accent("D"), 3)
	var wide: bool = vp.x > vp.y
	card.custom_minimum_size = Vector2(minf(640.0 if wide else 520.0, vp.x - 32.0), 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	DDUi.skin_panel(card, "modal", 24)
	center.add_child(card)
	var v: VBoxContainer = DDUi.vbox(8 if wide else 12)
	card.add_child(v)
	v.add_child(DDUi.label("SETTINGS", DDUi.FONT_L, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8 if wide else 12)
	v.add_child(grid)
	grid.add_child(_slider(g, "master_volume", "Master volume"))
	grid.add_child(_slider(g, "sfx_volume", "Sound effects"))
	grid.add_child(_toggle(g, "screen_shake", "Screen shake"))
	grid.add_child(_toggle(g, "reduce_motion", "Reduce motion"))
	v.add_child(DDUi.label("Reduce motion: cards fade instead of flying, no shake or zoom.", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(_skin_row(g))
	var more: HBoxContainer = DDUi.hbox(8)
	v.add_child(more)
	var cx: Button = DDUi.button("Codex", DDUi.PANEL_HI, DDUi.FONT_M)
	cx.name = "MenuCodex"
	cx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cx.pressed.connect(func() -> void: codex_requested.emit())
	more.add_child(cx)
	var hp: Button = DDUi.button("Help · Glossary", DDUi.PANEL_HI, DDUi.FONT_M)
	hp.name = "MenuHelp"
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.pressed.connect(func() -> void: help_requested.emit())
	more.add_child(hp)
	var done: Button = DDUi.button("Done", Color("245236"), DDUi.FONT_L)
	done.pressed.connect(close)
	v.add_child(done)
	visible = true
	opened.emit()


func _slider(g: Node, key: String, text: String) -> Control:
	var box: VBoxContainer = DDUi.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab: Label = DDUi.label("", DDUi.FONT_M, DDUi.TEXT)
	box.add_child(lab)
	var s: HSlider = HSlider.new()
	s.name = key
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(240, 56)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var track: StyleBoxFlat = DDUi.box(Color("0d0f10"), Color(0, 0, 0, 0), 0, 8, 0)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill: StyleBoxFlat = DDUi.box(DDUi.GOOD.darkened(0.2), Color(0, 0, 0, 0), 0, 8, 0)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	# dd-art2-import: the painted gauge (sunk track, green enamel fill)
	var ptrack: StyleBox = DDUi.Kit.box("dd_bar_track", 0.0)
	var pfill: StyleBox = DDUi.Kit.box("dd_bar_fill_green", 0.0)
	if ptrack != null and pfill != null:
		for st: StyleBox in [ptrack, pfill]:
			st.content_margin_top = 9
			st.content_margin_bottom = 9
		s.add_theme_stylebox_override("slider", ptrack)
		s.add_theme_stylebox_override("grabber_area", pfill)
		s.add_theme_stylebox_override("grabber_area_highlight", pfill)
	s.value = roundf(float(g.profile.setting(key)) * 100.0)
	lab.text = "%s  %d%%" % [text, int(s.value)]
	s.value_changed.connect(func(val: float) -> void:
		lab.text = "%s  %d%%" % [text, int(val)]
		g.set_setting(key, val / 100.0))
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.cue(&"hit" if key == "sfx_volume" else &"flip"))
	box.add_child(s)
	return box


func _toggle(g: Node, key: String, text: String) -> Control:
	var b: Button = DDUi.button("", DDUi.PANEL_HI, DDUi.FONT_M)
	b.name = key
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on: bool = g.reduce_motion() if key == "reduce_motion" else bool(g.profile.setting(key))
	var paint: Callable = func(state: bool) -> void:
		b.text = "%s: %s" % [text, "ON" if state else "OFF"]
		var c: Color = Color("245236") if state else DDUi.PANEL_HI
		b.add_theme_stylebox_override("normal", DDUi.box(c, c.lightened(0.25), 2, 12, 12))
		b.add_theme_stylebox_override("hover", DDUi.box(c.lightened(0.1), c.lightened(0.4), 2, 12, 12))
		# dd-art2-import: painted toggle (gold chip when on, dark slate when off; bone words, ink outline)
		if DDUi.Kit.skin_plate(b, "dd_chip_filter_on" if state else "dd_chip_filter_off", 12.0):
			DDUi.ink_outline(b)
	paint.call(on)
	b.pressed.connect(func() -> void:
		var now: bool = not (g.reduce_motion() if key == "reduce_motion" else bool(g.profile.setting(key)))
		g.set_setting(key, now)
		paint.call(now))
	return b


## dd-ui-clean: "UI style": the three UI skins side by side; the lit one is in use. Picking one saves it,
## rebuilds the screen behind (main.gd listens) and this panel in the new skin.
func _skin_row(g: Node) -> Control:
	var box: VBoxContainer = DDUi.vbox(4)
	box.name = "UiStyle"
	box.add_child(DDUi.label("UI style", DDUi.FONT_M, DDUi.TEXT))
	var row: HBoxContainer = DDUi.hbox(8)
	box.add_child(row)
	for k: String in DDUi.Kit.SKINS:
		var b: Button = DDUi.button(str(DDUi.Kit.SKIN_NAMES[k]), DDUi.PANEL_HI, DDUi.FONT_S)
		b.name = "Skin_" + k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on: bool = DDUi.Kit.skin == k
		if on:
			var c: Color = Color("245236")
			b.add_theme_stylebox_override("normal", DDUi.box(c, DDUi.SELECT, 3, 12, 12))
			b.add_theme_stylebox_override("hover", DDUi.box(c.lightened(0.1), DDUi.SELECT, 3, 12, 12))
		if DDUi.Kit.skin_plate(b, "dd_chip_filter_on" if on else "dd_chip_filter_off", 12.0):
			DDUi.ink_outline(b)
		b.pressed.connect(func() -> void:
			if DDUi.Kit.skin == k:
				return
			g.set_setting("ui_skin", k)
			Sfx.cue(&"flip")
			open.call_deferred())
		row.add_child(b)
	return box


func close() -> void:
	if not visible:
		return
	visible = false
	if _content != null:
		_content.queue_free()
		_content = null
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	# a tap on the dim area (outside the panel, which stops its own clicks) closes
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
