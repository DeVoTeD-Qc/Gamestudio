# starter_panel.gd
# Purpose: kc-ui4 (head: "I should be able to see the starting deck and maybe choose a starting
#   operator/gun"). A full-rect panel with two columns:
#     OPERATOR  one tile per Operator you can start with (RunProgress.operator_options: the run's
#               Primary weapons): its brass banner (the weapon's mastery card in the pitch build),
#               class, FP / Armor, what the gun does, SELECTED on the current pick. Tap = pick it.
#     STARTER DECK  the plain Recruit starter grouped by card, each as its board banner (BannerCard)
#               with a "x3" count.
#   Long-press / right-click (or hover for the tooltip) any tile = the card inspector (its own).
#   Before a run (Loadout screen, `run` given) the pick goes to the run (RunState.set_primary) and
#   becomes the default for the next runs (Settings.operator_primary); from the Codex (no run) it
#   only sets that default. The rival's side never changes. Controls are 64 px+ (44 pt on a phone).
# Usage: var p := StarterPanel.new(); parent.add_child(p); p.setup(run_or_null, compact, "BACK")
# Dependencies: RunProgress, RunState, Settings, BannerCard, BannerArtDB, codex_view.gd
#   (inspector_info), CardInspector.tscn, card_info.gd, run_flow.gd, hud_theme.tres.
# Author: UI/UX Agent (kc-ui4)
extends Control

signal closed
signal operator_picked(id: StringName)

const THEME: Theme = preload("res://assets/ui/hud_theme.tres")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const RunFlowScript: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const AMBER: Color = Color(0.961, 0.722, 0.239)
const BAR_H: float = 64.0

var compact: bool = false
## The run this panel sets up (null: from the Codex, sets only the default for new runs).
var run: RunProgress = null
## The Operator picked now (a Primary id).
var picked: StringName = &""
var _config: RunConfig = null
var _close: Button = null
var _op_list: VBoxContainer = null
var _deck_grid: GridContainer = null
var _deck_title: Label = null
var _op_tiles: Dictionary = {}   # id -> Button
var _deck_tiles: Array[Control] = []
var _inspector: Control = null
var _close_text: String = "BACK"


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 5
	resized.connect(_layout)


## Builds the panel for `p_run` (null = no run: the Codex), phone layout when `p_compact`.
func setup(p_run: RunProgress, p_compact: bool, close_text: String = "BACK") -> void:
	run = p_run
	compact = p_compact
	_close_text = close_text
	_config = run.config if run != null else _default_config()
	picked = run.primary if run != null else _preferred(_config)
	_build()
	_layout()


func close() -> void:
	if _inspector != null and _inspector.is_open():
		_inspector.close()
		return
	hide()
	closed.emit()


func get_close_button() -> Button:
	return _close


func get_inspector() -> Control:
	return _inspector


## Operator tiles by Primary id.
func get_operator_tiles() -> Dictionary:
	return _op_tiles


## Deck tiles, one per card in the starter (meta: id, count).
func get_deck_tiles() -> Array[Control]:
	return _deck_tiles


## Picks the starting Operator: the run's Primary (in the loadout phase) and the default for the
## next runs and quick matches. Returns "" or the reason it can't.
func pick_operator(id: StringName) -> String:
	var err: String = ""
	if run != null:
		var rs: Node = get_node_or_null(^"/root/RunState")
		err = rs.set_primary(id) if rs != null and rs.get(&"run") == run else run.set_primary(id)
	elif not RunProgress.operator_options(_config).any(func(o: LoadoutItem) -> bool: return o.id == id):
		err = "'%s' is not an Operator you can start with" % id
	if err != "":
		return err
	picked = id
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null:
		var default_id: String = String(_config.starter_primary.id) if _config != null and _config.starter_primary != null else ""
		st.set_value(&"operator_primary", "" if String(id) == default_id else String(id))
	_refresh_ops()
	operator_picked.emit(id)
	return ""


## The starter deck grouped by card, in first-appearance order: [{card, count}].
static func grouped_starter(cfg: RunConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cfg == null:
		return out
	var idx: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		if c == null:
			continue
		if not idx.has(c.id):
			idx[c.id] = out.size()
			out.append({"card": c, "count": 0})
		out[idx[c.id]]["count"] = int(out[idx[c.id]]["count"]) + 1
	return out


static func _default_config() -> RunConfig:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var rs: Node = tree.root.get_node_or_null(^"/root/RunState") if tree != null else null
	if rs != null and rs.has_method(&"_config"):
		return rs.call(&"_config")
	var db: Node = tree.root.get_node_or_null(^"/root/CardDB") if tree != null else null
	return db.get_run_config() if db != null else null


static func _preferred(cfg: RunConfig) -> StringName:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null(^"/root/Settings") if tree != null else null
	var pref: String = String(st.get(&"operator_primary")) if st != null else ""
	for item: LoadoutItem in RunProgress.operator_options(cfg):
		if String(item.id) == pref:
			return item.id
	return cfg.starter_primary.id if cfg != null and cfg.starter_primary != null else &""


# =============================================================================
# Building
# =============================================================================

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.045, 0.055, 0.065, 0.985)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	margin.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	col.add_child(top)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudHeader"
	title.text = "STARTING SQUAD"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = BAR_H
	top.add_child(title)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"HudSubtle"
	hint.text = "Pick your Operator. Long-press any card for its rules."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(hint)
	_close = Button.new()
	_close.name = "StarterClose"
	_close.text = _close_text
	_close.theme_type_variation = &"ReadyButton"
	_close.custom_minimum_size = Vector2(maxf(140.0, _close_text.length() * 13.0 + 40.0), BAR_H)
	_close.add_to_group(&"tap_target")
	_close.pressed.connect(close)
	top.add_child(_close)
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 14)
	col.add_child(body)
	# Operators.
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "Operators"
	left.add_theme_constant_override(&"separation", 6)
	body.add_child(left)
	var ol: Label = Label.new()
	ol.theme_type_variation = &"HudAccent"
	ol.text = "OPERATOR · TAP TO PICK"
	left.add_child(ol)
	var oscroll: ScrollContainer = ScrollContainer.new()
	oscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	oscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(oscroll)
	_op_list = VBoxContainer.new()
	_op_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_op_list.add_theme_constant_override(&"separation", 8)
	oscroll.add_child(_op_list)
	for item: LoadoutItem in RunProgress.operator_options(_config):
		var t: Button = _operator_tile(item)
		_op_tiles[item.id] = t
		_op_list.add_child(t)
	# Deck.
	var right: VBoxContainer = VBoxContainer.new()
	right.name = "Deck"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 6)
	body.add_child(right)
	_deck_title = Label.new()
	_deck_title.theme_type_variation = &"HudAccent"
	var groups: Array[Dictionary] = grouped_starter(_config)
	var total: int = 0
	for g: Dictionary in groups:
		total += int(g["count"])
	_deck_title.text = "STARTER DECK · %d CARDS · PLAIN RECRUITS" % total
	_deck_title.clip_text = true
	right.add_child(_deck_title)
	var dscroll: ScrollContainer = ScrollContainer.new()
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(dscroll)
	_deck_grid = GridContainer.new()
	_deck_grid.add_theme_constant_override(&"h_separation", 8)
	_deck_grid.add_theme_constant_override(&"v_separation", 8)
	dscroll.add_child(_deck_grid)
	var levels: Array[int] = _config.starter_levels() if _config != null else ([] as Array[int])
	var i0: int = 0
	for g: Dictionary in groups:
		var card: CardData = g["card"]
		var lvl: int = SynergyRules.LEVEL_RECRUIT
		var at: int = _config.starter_deck.find(card) if _config != null else -1
		if at >= 0 and at < levels.size():
			lvl = levels[at]
		var tile: Control = _deck_tile(card, int(g["count"]), lvl)
		_deck_tiles.append(tile)
		_deck_grid.add_child(tile)
		i0 += 1
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspector.hide()
	_refresh_ops()


func _tile_size() -> Vector2:
	return Vector2(216, 86) if compact else Vector2(240, 96)


func _metric() -> float:
	return 57.0 if compact else 76.0


func _operator_tile(item: LoadoutItem) -> Button:
	var b: Button = Button.new()
	b.name = "Operator_%s" % item.id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.set_meta(&"id", item.id)
	b.tooltip_text = "%s: %s" % [item.display_name, RunFlowScript.item_effect_line(item)]
	b.custom_minimum_size = Vector2(0, _tile_size().y + 8.0)
	_wire(b, func() -> void: pick_operator(item.id), func() -> void: _inspector.open(operator_info(item)))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_bottom = -4
	var entry: Dictionary = {"name": item.display_name, "fp": item.operator_firepower, "armor": item.operator_armor,
			"armor_max": item.operator_armor, "operator": true, "camo": String(BannerArtDB.camo_for_tier(1)),
			"banner": String(BannerArtDB.operator_art_id(item.id, 1)), "keywords": _op_keywords(item)}
	var card: PanelContainer = BannerCard.build(entry, _tile_size(), _metric())
	card.name = "OperatorBanner"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = _tile_size()
	row.add_child(card)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	var line: Label = _text(RunFlowScript.item_effect_line(item).to_upper(), &"UnitName", 16)
	line.name = "OperatorLine"
	text.add_child(line)
	var what: Label = _text(item.text, &"HudSubtle", 16)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.clip_text = false
	text.add_child(what)
	var tag: Label = _text("SELECTED", &"HudTag", 16)
	tag.name = "SelectedTag"
	tag.clip_text = false
	tag.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	tag.add_theme_color_override(&"font_color", Color(0.07, 0.08, 0.1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = AMBER
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	tag.add_theme_stylebox_override(&"normal", sb)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(tag)
	return b


func _deck_tile(card: CardData, count: int, level: int) -> Control:
	var b: Button = Button.new()
	b.name = "Deck_%s" % card.id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.set_meta(&"id", card.id)
	b.set_meta(&"count", count)
	b.custom_minimum_size = _tile_size()
	b.tooltip_text = "%d x %s · long-press / right-click: rules" % [count, card.display_name]
	var e: Dictionary = {"kind": &"unit" if card.is_unit() else (&"field" if card.is_field() else &"tactic"), "card": card,
			"id": card.id, "art": card.id, "arts": BannerArtDB.alt_arts(card.id), "name": card.display_name}
	var info: Callable = func() -> void: _inspector.open(load("res://scripts/ui/codex/codex_view.gd").call(&"inspector_info", e))
	_wire(b, info, info)
	var panel: PanelContainer = BannerCard.build(BannerCard.entry_for_card(card, _equipped(card.id), level), _tile_size(), _metric())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var face: Control = panel.get_node("Face")
	var n: Label = _text("x%d" % count, &"HudNumber", 22)
	n.name = "CountLabel"
	n.clip_text = false
	n.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	n.set_meta(&"important", true)
	n.add_theme_color_override(&"font_color", Color(0.07, 0.08, 0.1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = AMBER
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	n.add_theme_stylebox_override(&"normal", sb)
	face.add_child(n)
	var bv: BannerView = BannerCard.banner_of(panel)
	panel.sort_children.connect(func() -> void:
		# The count sits in the bottom-centre slot (between the abilities and the stats).
		n.size = n.get_combined_minimum_size()
		var mm: Dictionary = BannerView.metrics(minf(face.size.y, _metric()))
		var sr: Rect2 = BannerView.anatomy(face.size, mm, bv.entry, bv.lead if bv.lead > 0.0 else -1.0)["sub"]
		n.position = Vector2(roundf(sr.position.x + (sr.size.x - n.size.x) * 0.5), roundf(sr.position.y + (sr.size.y - n.size.y) * 0.5)))
	return b


## kc-trait-ui (head): no Codex EQUIP; the starter list shows each card's default art.
func _equipped(_id: StringName) -> StringName:
	return &""


func _op_keywords(item: LoadoutItem) -> Array:
	var out: Array = []
	for id: StringName in [&"first_shot", &"pick", &"flank"]:
		if bool(item.get(id)):
			out.append({"id": id})
	if item.cover > 0:
		out.append({"id": &"cover", "value": item.cover})
	if item.suppress:
		out.append({"id": &"suppress"})
	return out


## The inspector's info for an Operator option.
func operator_info(item: LoadoutItem) -> Dictionary:
	var kws: Array[Dictionary] = []
	for k: Dictionary in _op_keywords(item):
		kws.append(CardInfo._entry(StringName(k["id"]), int(k.get("value", 0))))
	var entry: Dictionary = {"name": item.display_name, "fp": item.operator_firepower, "armor": item.operator_armor,
			"armor_max": item.operator_armor, "operator": true, "camo": String(BannerArtDB.camo_for_tier(1)),
			"banner": String(BannerArtDB.operator_art_id(item.id, 1)), "keywords": _op_keywords(item),
			"cls": "OPERATOR"}
	return {"title": item.display_name, "type": "Operator · " + RunFlowScript.item_effect_line(item),
			"text": "%s Your Operator is never drawn or discarded: it costs Supply to place and comes back after it goes down." % item.text,
			"keywords": kws, "banner": entry, "side": 0, "is_unit": true,
			"status": "SELECTED: you start with this Operator" if item.id == picked else "Tap the tile to start with this Operator"}


func _refresh_ops() -> void:
	for id: StringName in _op_tiles:
		var b: Button = _op_tiles[id]
		var on: bool = id == picked
		var tag: Control = b.find_child("SelectedTag", true, false)
		if tag != null:
			tag.visible = on
		var card: PanelContainer = b.find_child("OperatorBanner", true, false) as PanelContainer
		if card != null:
			card.theme_type_variation = &"HandCardSelected" if on else &"HandCard"
		b.modulate = Color.WHITE if on else Color(0.82, 0.82, 0.85)


func _layout() -> void:
	if _deck_grid == null:
		return
	var left: Control = _op_list.get_parent().get_parent() as Control
	var lw: float = roundf(size.x * (0.47 if compact else 0.42))
	left.custom_minimum_size.x = lw
	var tile: Vector2 = _tile_size()
	var room: float = size.x - 20.0 - 14.0 - lw - 12.0
	_deck_grid.columns = maxi(1, int(floorf((room + 8.0) / (tile.x + 8.0))))


func _wire(b: Control, on_tap: Callable, on_inspect: Callable) -> void:
	var g: RefCounted = PressGesture.new(b)
	g.drag_enabled = false
	b.set_meta(&"gesture", g)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if g.handle(ev):
			b.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void: on_tap.call())
	g.long_pressed.connect(func(_p: Vector2) -> void: on_inspect.call())


func _text(t: String, variation: StringName, fs: int) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.theme_type_variation = variation
	l.add_theme_font_size_override(&"font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
