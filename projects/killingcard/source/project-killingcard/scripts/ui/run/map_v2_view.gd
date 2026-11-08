# map_v2_view.gd
# Purpose: The body of the Run v2 map screen (kc-v2-ui; run-v2.md §2, §9 "Run map"): the MapGraph
#   (9 steps on 3 lanes) and the NODE BRIEF beside it (landscape, iPad) or under it (portrait).
#   The brief shows the decision for the selected node, in this order: what it is (icon + word +
#   mode), the crew, each Terrain with its column and its one-line rule, what it gives and what it
#   risks, and the GO button ("FIGHT HERE", "GO TO THE SHOP"...). A node you can't step on says why
#   on the button ("NOT ON YOUR PATH"). Under the brief, always, the BOSS plate: the run's boss and
#   its rule, from step 1 (the head: the boss is shown on the map from step 1).
#   Tap a node = brief it; tap the briefed node again or GO = step on it (node_chosen). Long press /
#   right click on a node, the boss plate or a Terrain row = the inspector with the full text
#   (inspect_requested(info) with a CardInspector info dictionary).
#   With nothing tapped yet the brief shows the first node you can step on.
# Dependencies: map_graph.gd, run_glyphs.gd, run_v2_views.gd, run_screen.gd builders, hud_theme.tres.
# Author: UI/UX Agent (kc-v2-ui)
extends BoxContainer

signal node_chosen(id: String)
signal inspect_requested(info: Dictionary)

const MapGraph: GDScript = preload("res://scripts/ui/run/map_graph.gd")
const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

const BRIEF_W: float = 380.0
## Portrait: px per map step (a 64 px tile + two lines of words + the gap).
const PORTRAIT_STEP_H: float = 112.0
const BRIEF_W_COMPACT: float = 340.0

var map: Dictionary = {}
var portrait: bool = false
var compact: bool = false
var selected_id: String = ""
var graph: Control = null
var _scroll: ScrollContainer = null
var _brief: PanelContainer = null
var _brief_col: VBoxContainer = null
var _go: Button = null
var _boss_plate: PanelContainer = null
var _graph_scroll: ScrollContainer = null


func _init() -> void:
	name = "MapV2"
	add_theme_constant_override(&"separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(p_map: Dictionary, p_portrait: bool, p_compact: bool) -> void:
	map = p_map
	portrait = p_portrait
	compact = p_compact
	vertical = portrait
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	graph = MapGraph.new()
	graph.name = "MapGraph"
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, 300)
	graph.node_tapped.connect(_on_tapped)
	graph.node_inspected.connect(func(id: String) -> void: inspect_requested.emit(node_info(map, RunV2Views.node_by_id(map, id))))
	if portrait:
		# Portrait: the map scrolls (a step needs its tile and two lines of words: PORTRAIT_STEP_H px),
		# opened on the step you stand on; the brief and GO stay pinned under it.
		_graph_scroll = ScrollContainer.new()
		_graph_scroll.name = "MapScroll"
		_graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_graph_scroll)
		graph.custom_minimum_size = Vector2(0, int(map.get("steps", 9)) * PORTRAIT_STEP_H)
		_graph_scroll.add_child(graph)
		_scroll_to_current.call_deferred()
	else:
		_graph_scroll = null
		add_child(graph)
	graph.set_map(map, portrait, compact)
	var side: VBoxContainer = VBoxContainer.new()
	side.name = "Side"
	side.add_theme_constant_override(&"separation", 8)
	side.custom_minimum_size.x = 0.0 if portrait else (BRIEF_W_COMPACT if compact else BRIEF_W)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(side)
	_brief = PanelContainer.new()
	_brief.name = "Brief"
	_brief.theme_type_variation = &"HudPanelDark"
	_brief.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if portrait else Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_SHRINK_END if portrait else Control.SIZE_EXPAND_FILL
	side.add_child(_brief)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if portrait:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_brief.add_child(_scroll)
	_brief_col = VBoxContainer.new()
	_brief_col.name = "BriefColumn"
	_brief_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brief_col.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_brief_col)
	_go = Button.new()
	_go.name = "GoButton"
	_go.theme_type_variation = &"ReadyButton"
	_go.custom_minimum_size = Vector2(0, 64)
	_go.add_to_group(&"tap_target")
	_go.pressed.connect(func() -> void:
		var n: Dictionary = RunV2Views.node_by_id(map, selected_id)
		if bool(n.get("reachable", false)):
			node_chosen.emit(selected_id))
	side.add_child(_go)
	_boss_plate = _make_boss_plate()
	side.add_child(_boss_plate)
	var first: String = ""
	for n: Dictionary in map.get("nodes", []):
		if bool(n.get("reachable", false)) and first == "":
			first = String(n["id"])
	select(first if selected_id == "" or RunV2Views.node_by_id(map, selected_id).is_empty() else selected_id)


## Portrait: scrolls the map so the step you stand on sits near the bottom (the next steps above it).
func _scroll_to_current() -> void:
	if _graph_scroll == null or not is_instance_valid(_graph_scroll):
		return
	await get_tree().process_frame
	var step: int = int(map.get("step", 1))
	var below: float = maxf(0.0, float(step - 1)) * PORTRAIT_STEP_H
	var target: float = graph.custom_minimum_size.y - below - _graph_scroll.size.y
	_graph_scroll.scroll_vertical = int(maxf(0.0, target))


func get_map_scroll() -> ScrollContainer:
	return _graph_scroll


func get_go_button() -> Button:
	return _go


func get_boss_plate() -> Control:
	return _boss_plate


func get_brief() -> Control:
	return _brief


func _on_tapped(id: String) -> void:
	var n: Dictionary = RunV2Views.node_by_id(map, id)
	if id == selected_id and bool(n.get("reachable", false)):
		node_chosen.emit(id)
		return
	select(id)


## Briefs node `id` (the GO button follows it).
func select(id: String) -> void:
	selected_id = id
	if graph != null:
		graph.set_selected(id)
	_fill_brief(RunV2Views.node_by_id(map, id))


func _fill_brief(n: Dictionary) -> void:
	for c: Node in _brief_col.get_children():
		_brief_col.remove_child(c)
		c.queue_free()
	if n.is_empty():
		_brief_col.add_child(_label("Tap a node to see what it gives and what it risks.", &"HudSubtle", true))
		_go.text = "PICK A NODE"
		_go.disabled = true
		return
	var t: StringName = n["type"]
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	head.add_child(RunGlyphs.make(&"node", t, RunGlyphs.node_tint(t), 34.0))
	var words: String = node_heading(map, n)
	var hl: Label = _label(words, &"TileName", true)
	hl.name = "BriefTitle"
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	_brief_col.add_child(head)
	var crew: String = String(n.get("crew", ""))
	if t == &"event":
		crew = String(n.get("event", ""))
	if t == &"boss":
		var b: Dictionary = map.get("boss", {})
		crew = "%s · %s" % [b.get("name", crew), b.get("crew", "")]
	if crew != "":
		_brief_col.add_child(_label(crew, &"UnitName", true))
	var ts: Array = n.get("terrain", [])
	if t in [&"fight", &"elite"]:
		if ts.is_empty():
			_brief_col.add_child(_label("No Terrain: plain columns.", &"HudSubtle", true))
		for td: Dictionary in ts:
			_brief_col.add_child(terrain_row(td, func() -> void: inspect_requested.emit(terrain_info(td))))
	if t == &"boss":
		var b2: Dictionary = map.get("boss", {})
		_brief_col.add_child(_label("BOSS RULE · %s" % String(b2.get("rule_name", "")).to_upper(), &"EnemyLabel", true))
		_brief_col.add_child(_label(String(b2.get("rule_text", "")), &"", true))
	var gives: Label = _label(String(n.get("gives", "")), &"FriendlyLabel", true)
	gives.name = "Gives"
	_brief_col.add_child(gives)
	var risk: Label = _label(String(n.get("risk", "")), &"HudSubtle", true)
	risk.name = "Risk"
	_brief_col.add_child(risk)
	_go.disabled = not bool(n.get("reachable", false))
	_go.text = go_text(n)


## "FIGHT 2 · ZONE CONTROL" / "ELITE · FIREFIGHT" / "EVENT" / "BOSS · ZONE CONTROL".
static func node_heading(m: Dictionary, n: Dictionary) -> String:
	var t: StringName = n.get("type", &"fight")
	var w: String = String(RunV2Views.NODE_WORDS.get(t, ["?"])[0])
	if t == &"fight" and int(n.get("fight", 0)) > 0:
		w = "FIGHT %d" % int(n["fight"])
	var mode: String = String(n.get("mode", ""))
	if t == &"boss" and mode == "":
		mode = String(m.get("boss", {}).get("mode", ""))
	return ("%s · %s" % [w, mode.to_upper()]) if mode != "" else w


## The GO button's words for a node.
static func go_text(n: Dictionary) -> String:
	if bool(n.get("current", false)):
		return "YOU ARE HERE"
	if bool(n.get("done", false)):
		return "ALREADY PLAYED"
	if not bool(n.get("reachable", false)):
		return "NOT ON YOUR PATH YET"
	match n.get("type", &"fight"):
		&"fight":
			return "FIGHT HERE"
		&"elite":
			return "TAKE THE ELITE"
		&"event":
			return "GO: EVENT"
		&"shop":
			return "GO TO THE SHOP"
		&"rest":
			return "MAKE CAMP"
		&"boss":
			return "FACE THE BOSS"
	return "GO"


## One Terrain line: its chip (icon on its tint + column letter), name and rule. Long press: inspect.
func terrain_row(td: Dictionary, on_inspect: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Terrain_%s" % String(td.get("id", ""))
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta(&"inspectable", true)
	var chip: Control = RunGlyphs.make(&"terrain", StringName(str(td.get("id", ""))), RunGlyphs.INK, 30.0)
	chip.backing = false
	var holder: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = RunGlyphs.terrain_tint(StringName(str(td.get("id", ""))))
	holder.add_theme_stylebox_override(&"panel", sb)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(chip)
	row.add_child(holder)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var z: int = int(td.get("zone", -1))
	var where: String = ("COLUMN %s · " % RunV2Views.ZONE_LETTERS[z]) if z >= 0 and z < 3 else ""
	var nm: Label = _label("%s%s" % [where, String(td.get("name", "")).to_upper()], &"HudAccent", true)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var tx: Label = _label(String(td.get("text", "")), &"", true)
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tx)
	row.add_child(col)
	var g: RefCounted = PressGesture.new(row)
	g.drag_enabled = false
	g.long_pressed.connect(func(_p: Vector2) -> void: on_inspect.call())
	g.tapped.connect(func(_p: Vector2) -> void: on_inspect.call())
	row.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			row.accept_event())
	return row


func _make_boss_plate() -> PanelContainer:
	var b: Dictionary = map.get("boss", {})
	var p: PanelContainer = PanelContainer.new()
	p.name = "BossPlate"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#2A1416")
	sb.border_color = get_theme_color(&"enemy", &"Hud") if is_inside_tree() else Color("#E5383B")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override(&"panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.set_meta(&"inspectable", true)
	p.add_to_group(&"tap_target")
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(RunGlyphs.make(&"node", &"boss", Color("#E5383B"), 34.0))
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	if b.is_empty():
		col.add_child(_label("BOSS: unknown", &"EnemyLabel", true))
		return p
	var l1: Label = _label("BOSS · %s · %s" % [String(b.get("name", "")).to_upper(), String(b.get("rule_name", "")).to_upper()], &"EnemyLabel", true)
	l1.name = "BossName"
	col.add_child(l1)
	var l2: Label = _label(String(b.get("rule_text", "")), &"", true)
	l2.name = "BossRule"
	col.add_child(l2)
	for l: Label in [l1, l2]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g: RefCounted = PressGesture.new(p)
	g.drag_enabled = false
	var open: Callable = func(_pos: Vector2) -> void: inspect_requested.emit(boss_info(b))
	g.long_pressed.connect(open)
	g.tapped.connect(open)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			p.accept_event())
	return p


static func _label(text: String, variation: StringName, wrap: bool) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# =============================================================================
# Inspector texts (CardInspector.open info; view {} = no card)
# =============================================================================

static func node_info(m: Dictionary, n: Dictionary) -> Dictionary:
	if n.is_empty():
		return {}
	var t: StringName = n["type"]
	var kws: Array[Dictionary] = []
	for td: Dictionary in n.get("terrain", []):
		var z: int = int(td.get("zone", -1))
		kws.append({"name": "Terrain · %s%s" % [String(td["name"]), (" (column %s)" % RunV2Views.ZONE_LETTERS[z]) if z >= 0 and z < 3 else ""],
				"text": "%s Applies to both sides." % String(td["text"])})
	var text: String = ""
	match t:
		&"fight", &"elite":
			text = "%s\nMode: %s." % [String(n.get("crew", "")), String(n.get("mode", ""))]
			if (n.get("terrain", []) as Array).is_empty():
				text += "\nNo Terrain: plain columns."
			var deck: Array = n.get("deck", [])
			if not deck.is_empty():
				text += "\nDeck: %s." % ", ".join(PackedStringArray(deck.map(func(x: Variant) -> String: return str(x))))
		&"event":
			text = "%s\nThe options show when you arrive. Every result is printed on its button; an event never costs a ticket without saying so." % String(n.get("event", "An event"))
		&"shop":
			text = "Spend REQ (Requisition). Unit 4 · Tactic 3 · Field 3 · Elite card 7 · Muster out a Standard Issue card 2 · Discharge any other card 3 · Perk 6 · Restock 1. No tickets for sale."
		&"rest":
			var cfg: RunConfig = CardDB.get_run_config()
			text = "Pick one: +1 ticket (max 3), Drill (send 2 cards of your choice home, never under %d) or Field-strip (a weapon level now)." % (cfg.deck_floor if cfg != null else 8)
		&"boss":
			var b: Dictionary = m.get("boss", {})
			text = "%s · %s\nMode: %s · Armor +%d.\nRule · %s: %s" % [b.get("name", ""), b.get("crew", ""), b.get("mode", ""),
					int(b.get("armor_bonus", 0)), b.get("rule_name", ""), b.get("rule_text", "")]
			if String(b.get("tip", "")) != "":
				text += "\n" + String(b["tip"])
	var status: String = "Gives: %s\nRisk: %s\n%s" % [n.get("gives", ""), n.get("risk", ""), go_text(n).capitalize()]
	return {"title": node_heading(m, n), "type": "map node · step %d · %s lane" % [int(n.get("step", 0)),
			RunV2Views.LANE_WORDS[clampi(int(n.get("lane", 1)), 0, 2)].to_lower()], "text": text, "keywords": kws, "status": status}


static func terrain_info(td: Dictionary) -> Dictionary:
	var id: StringName = StringName(str(td.get("id", "")))
	var z: int = int(td.get("zone", -1))
	return {"title": String(td.get("name", "")), "type": "terrain%s" % ((" · column %s" % RunV2Views.ZONE_LETTERS[z]) if z >= 0 and z < 3 else ""),
			"text": String(td.get("text", "")),
			"keywords": [{"name": "Applies to both sides", "text": "Terrain is part of the column, not a card: it can't be shot, Sabotaged, Overrun or replaced, and it never counts for traits. Your Field cards still go on top of it."},
				{"name": "Read the ground", "text": String(RunV2Views.TERRAIN_TIPS.get(id, ""))}],
			"status": ""}


static func boss_info(b: Dictionary) -> Dictionary:
	return {"title": String(b.get("name", "Boss")), "type": "boss · %s" % String(b.get("mode", "")),
			"text": "%s\nArmor +%d on every enemy unit." % [b.get("crew", ""), int(b.get("armor_bonus", 0))],
			"keywords": [{"name": "Boss rule · %s" % b.get("rule_name", ""), "text": String(b.get("rule_text", ""))},
				{"name": "How to answer it", "text": String(b.get("tip", ""))}],
			"status": "The boss is the last step of the run. Plan your path, your Operator and your deck against it."}
