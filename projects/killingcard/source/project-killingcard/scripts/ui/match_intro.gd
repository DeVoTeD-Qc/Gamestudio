# match_intro.gd
# Purpose: The match intro card (run-v2.md §4, §6.2, §9; kc-v2-ui): before the mulligan of a fight with
#   Terrain, an elite or the boss, one sheet says what is different about this ground and this crew:
#     - the heading: FIGHT 3 / ELITE / BOSS · the crew · the mode;
#     - the BOSS RULE plate (boss fights): skull, rule name, the one line, when it starts;
#     - one row per column A / B / C: its Terrain chip, name and rule, or "Plain ground";
#     - "Terrain applies to both sides. Your Field cards still go on top."
#   TO THE BOARD closes it (then the mulligan). Long press / right click on a row = its inspector
#   (inspect_requested). It never hides anything the board doesn't also show: the board keeps the
#   Terrain chips and the boss plate.
# Dependencies: run_glyphs.gd, run_v2_views.gd, map_v2_view.gd (inspector texts), press_gesture.gd.
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal closed
signal inspect_requested(info: Dictionary)

const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const MapV2View: GDScript = preload("res://scripts/ui/run/map_v2_view.gd")
const RunScreen: GDScript = preload("res://scripts/ui/run/run_screen.gd")

var compact: bool = false
var _panel: PanelContainer = null
var _col: VBoxContainer = null
var _go: Button = null


func _ready() -> void:
	name = "MatchIntro"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.05, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "IntroPanel"
	_panel.theme_type_variation = &"HudPanelDark"
	center.add_child(_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override(&"separation", 8)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_col)
	hide()


## Wants an intro: the match has Terrain, a boss or is an elite.
static func wanted(terrain: Array, boss: Dictionary, node: Dictionary) -> bool:
	return not terrain.is_empty() or not boss.is_empty() or StringName(str(node.get("type", ""))) == &"elite"


## terrain: the snapshot's Terrain rows (filtered); boss: MatchState.boss_view(); node: the run node
## (RunState.current_node(), normalised) for the heading; mode: the mode word.
func open(terrain: Array, boss: Dictionary, node: Dictionary, mode: String) -> void:
	for c: Node in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	var vr: Vector2 = get_viewport_rect().size
	var w: float = clampf(vr.x - 32.0, 320.0, 620.0)
	_col.custom_minimum_size.x = w
	var scroll: ScrollContainer = _col.get_parent() as ScrollContainer
	scroll.custom_minimum_size = Vector2(w, minf(vr.y - 48.0, 640.0))
	var t: StringName = StringName(str(node.get("type", "boss" if not boss.is_empty() else "fight")))
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	head.add_child(RunGlyphs.make(&"node", t, RunGlyphs.node_tint(t), 44.0))
	var title: String = {&"boss": "BOSS FIGHT", &"elite": "ELITE FIGHT"}.get(t, "FIGHT")
	var fl: String = String(node.get("fight_label", ""))
	if t == &"fight" and fl != "":
		title = "FIGHT %s" % fl.trim_prefix("F")
	var tl: Label = RunScreen.make_label("%s%s" % [title, (" · " + mode.to_upper()) if mode != "" else ""], &"TileName", true)
	tl.name = "IntroTitle"
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	_col.add_child(head)
	var crew: String = String(node.get("crew", ""))
	if not boss.is_empty():
		crew = String(boss.get("name", crew))
	if crew != "":
		_col.add_child(RunScreen.make_label(crew, &"UnitName", true))
	if t == &"elite":
		_col.add_child(RunScreen.make_label("A tougher crew: +1 Armor and 2 Terrains. Win: an Elite Cache (one rung ahead) and +5 REQ.", &"HudSubtle", true))
	if not boss.is_empty():
		_col.add_child(_boss_plate(boss))
	_col.add_child(RunScreen.make_label("THE GROUND", &"HudTag"))
	for z: int in 3:
		_col.add_child(_column_row(z, RunV2Views.terrain_at(terrain, z)))
	if not terrain.is_empty():
		_col.add_child(RunScreen.make_label("Terrain applies to both sides and stays all match. Your Field cards still go on top of it.", &"HudSubtle", true))
	_go = RunScreen.make_button("TO THE BOARD", &"ReadyButton", 240)
	_go.name = "IntroGo"
	_go.custom_minimum_size.y = 64.0
	_go.pressed.connect(close)
	_col.add_child(_go)
	show()
	_go.grab_focus.call_deferred()


func get_go_button() -> Button:
	return _go


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _boss_plate(b: Dictionary) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.name = "IntroBossRule"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2A1416")
	sb.border_color = Color("#E5383B")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override(&"panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(RunGlyphs.make(&"node", &"boss", Color("#E5383B"), 40.0))
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var l1: Label = RunScreen.make_label("BOSS RULE · %s" % String(b.get("rule_name", "")).to_upper(), &"EnemyLabel", true)
	var l2: Label = RunScreen.make_label(String(b.get("rule_text", b.get("text", ""))), &"", true)
	col.add_child(l1)
	col.add_child(l2)
	var note: String = String(b.get("note", ""))
	if note != "":
		col.add_child(RunScreen.make_label(note, &"HudSubtle", true))
	for l: Label in col.get_children():
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RunScreen.wire_inspect_control(p, func() -> void: inspect_requested.emit(MapV2View.boss_info(RunV2Views.boss_entry(b))), false)
	return p


func _column_row(z: int, td: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Column%s" % RunV2Views.ZONE_LETTERS[z]
	row.add_theme_constant_override(&"separation", 10)
	var letter: Label = RunScreen.make_label(RunV2Views.ZONE_LETTERS[z], &"HudHeader")
	letter.custom_minimum_size.x = 22.0
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(letter)
	if td.is_empty():
		var l: Label = RunScreen.make_label("Plain ground: no Terrain.", &"HudSubtle", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		return row
	var chip: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = RunGlyphs.terrain_tint(StringName(str(td.get("id", ""))))
	chip.add_theme_stylebox_override(&"panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g: Control = RunGlyphs.make(&"terrain", StringName(str(td.get("id", ""))), RunGlyphs.INK, 36.0)
	g.set(&"backing", false)
	chip.add_child(g)
	row.add_child(chip)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm: Label = RunScreen.make_label(String(td.get("name", "")).to_upper(), &"HudAccent", true)
	var tx: Label = RunScreen.make_label(String(td.get("text", "")), &"", true)
	for l: Label in [nm, tx]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	RunScreen.wire_inspect_control(row, func() -> void: inspect_requested.emit(MapV2View.terrain_info(td)), false)
	return row
