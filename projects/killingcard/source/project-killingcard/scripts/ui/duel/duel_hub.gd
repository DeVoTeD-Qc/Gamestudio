# duel_hub.gd
# Purpose: kc-duel-ui. The DUEL hub (scenes/duel/DuelHub.tscn, duel-mode.md §4, §6.1): opened from the
#   Title next to the campaign. "Build a 10-pick deck, pick a hero, play one battle."
#   - Two modes: VS AI (your deck, the opponent preset or Random, RECRUIT / REGULAR / VETERAN with the
#     spec's line for each) and PASS & PLAY (two decks and two names on one device, the Open pool toggle).
#   - Two tabs: MY DECKS (up to 8; each tile: name, READY or "2 PICKS TO GO" chip, hero, trait plates
#     with copies, a mini curve; PLAY · EDIT · COPY · DELETE; "+ NEW DECK" = start empty or from a
#     preset) and PRESETS (the 4 loaners: "Preset: copy to edit", the plan line, your record vs it;
#     PLAY · COPY).
#   - Long press / right click on a deck tile, an opponent tile or a hero line = the deck list (every
#     row inspectable) or the hero kit. A "what just happened" line answers every action.
# Dependencies: run_screen.gd, duel_views.gd, duel_widgets.gd, duel_flow.gd.
# Author: UI/UX Agent (kc-duel-ui)
extends "res://scripts/ui/run/run_screen.gd"

const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const W: GDScript = preload("res://scripts/ui/duel/duel_widgets.gd")
const DuelFlow: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")

var tab: String = "mine"
## The VS AI / Pass & Play choices (kept while the hub is open).
var vs_deck_id: String = ""
var opponent_id: String = "random"
var tier: StringName = &"recruit"
var seat_decks: Array[String] = ["", ""]
var seat_names: Array[String] = ["Player 1", "Player 2"]
var open_pool: bool = false

var _tabs: Dictionary = {}
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _sheet: Dictionary = {}
var _built_portrait: int = -1
var _status: Label = null


func screen_id() -> StringName:
	return &"duel_hub"


func backdrop_key() -> StringName:
	return &"run"


func _build() -> void:
	var t: String = DuelFlow.hub_tab
	tab = "presets" if t == "presets" else "mine"
	var played: Dictionary = DuelFlow.setup
	if not played.is_empty():
		tier = StringName(str(played.get("tier", tier)))
		opponent_id = String(played.get("opponent_id", opponent_id))
	if DuelViews.saved_decks().is_empty() and not t.begins_with("play:"):
		tab = "presets"
	if t.begins_with("play:"):
		vs_deck_id = t.trim_prefix("play:")
		DuelFlow.set_hub_tab("mine")
		open_vs_ai.call_deferred(vs_deck_id)


func _apply_compact() -> void:
	var want: int = 1 if portrait else 0
	if want != _built_portrait or _grid == null:
		_built_portrait = want
		_rebuild()


# =============================================================================
# Public API (tests)
# =============================================================================

func get_tab_button(key: String) -> Button:
	return _tabs.get(key)


func get_tiles() -> Array[Node]:
	return _grid.get_children() if _grid != null else []


func get_tile(deck_id: String) -> Control:
	return _grid.get_node_or_null(NodePath("Deck_%s" % deck_id)) as Control if _grid != null else null


func get_sheet() -> Dictionary:
	return _sheet if not _sheet.is_empty() and is_instance_valid(_sheet.get("root")) else {}


func get_vs_ai_button() -> Button:
	return find_child("VsAiButton", true, false) as Button


func get_hot_seat_button() -> Button:
	return find_child("HotSeatButton", true, false) as Button


func set_tab(key: String) -> void:
	tab = key
	_fill()


## Every deck the player may pick to play: saved decks first, then the presets.
func playable_decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = DuelViews.saved_decks()
	out.append_array(DuelViews.presets())
	return out


func deck_by_id(id: String) -> Dictionary:
	for d: Dictionary in playable_decks():
		if String(d["id"]) == id:
			return d
	return {}


# =============================================================================
# Building
# =============================================================================

func _rebuild() -> void:
	var layout: VBoxContainer = %Layout
	clear(layout)
	_tabs.clear()
	layout.add_theme_constant_override(&"separation", 8 if compact else 12)
	var header: BoxContainer = BoxContainer.new()
	header.vertical = portrait
	header.add_theme_constant_override(&"separation", 8)
	layout.add_child(header)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(top)
	var back_b: Button = make_button("BACK", &"HudButton", 110)
	back_b.name = "BackButton"
	back_b.add_to_group(&"tap_target")
	back_b.tooltip_text = "Back to the title"
	back_b.pressed.connect(func() -> void: goto(DuelFlow.SCENE_TITLE))
	top.add_child(back_b)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override(&"separation", 0)
	top.add_child(titles)
	titles.add_child(make_label("DUEL", &"TileName"))
	var sub: Label = make_label("Build a 10-pick deck, pick a hero, play one battle.", &"HudSubtle", true)
	sub.name = "Subtitle"
	titles.add_child(sub)
	var modes: HBoxContainer = HBoxContainer.new()
	modes.name = "Modes"
	modes.add_theme_constant_override(&"separation", 8)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_END
	header.add_child(modes)
	var vs: Button = make_button("VS AI", &"ReadyButton", 170)
	vs.name = "VsAiButton"
	vs.add_to_group(&"tap_target")
	vs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs.tooltip_text = "Play one battle against the AI (it plays a preset deck)"
	vs.pressed.connect(func() -> void: open_vs_ai(vs_deck_id))
	modes.add_child(vs)
	var hs: Button = make_button("PASS & PLAY", &"HudButton", 190)
	hs.name = "HotSeatButton"
	hs.add_to_group(&"tap_target")
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.tooltip_text = "Two players on this device: each Deploy is played behind a cover screen"
	hs.pressed.connect(func() -> void: open_hot_seat())
	modes.add_child(hs)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override(&"separation", 8)
	layout.add_child(tabs)
	for key: String in ["mine", "presets"]:
		var b: Button = make_button("", &"HudButton", 200)
		b.name = "Tab_%s" % key
		b.toggle_mode = true
		b.add_to_group(&"tap_target")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
		b.pressed.connect(set_tab.bind(key))
		_tabs[key] = b
		tabs.add_child(b)
	var rec: Dictionary = DuelViews.records()
	var w: int = 0
	var l: int = 0
	for h: Variant in rec.get("heroes", {}):
		w += int((rec["heroes"][h] as Dictionary).get("w", 0))
		l += int((rec["heroes"][h] as Dictionary).get("l", 0))
	var rp: PanelContainer = W.panel(Color("#1B2228"), W.PANEL_RIM, 6.0)
	rp.name = "RecordChip"
	rp.size_flags_horizontal = Control.SIZE_SHRINK_END
	var rl: Label = W.label("RECORD %d W · %d L" % [w, l], &"HudTag", 16, W.FOG)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rp.add_child(rl)
	wire_inspect_control(rp, func() -> void: inspector().open(_records_info()), true)
	if not portrait:
		var sp: Control = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(sp)
		tabs.add_child(rp)
	_scroll = ScrollContainer.new()
	_scroll.name = "DeckScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "DeckGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 10)
	_grid.add_theme_constant_override(&"v_separation", 10)
	_scroll.add_child(_grid)
	_status = make_label("", &"HudHeader", true)
	_status.name = "StatusLine"
	_status.visible = false
	layout.add_child(_status)
	if portrait:
		layout.add_child(rp)
	_fill()


func _fill() -> void:
	if _grid == null:
		return
	var mine: Array[Dictionary] = DuelViews.saved_decks()
	(_tabs["mine"] as Button).text = "MY DECKS · %d/%d" % [mine.size(), DuelViews.MAX_SLOTS]
	(_tabs["presets"] as Button).text = "PRESETS · 4"
	for k: String in _tabs:
		(_tabs[k] as Button).set_pressed_no_signal(k == tab)
	clear(_grid)
	var vr: Vector2 = get_viewport_rect().size
	_grid.columns = 1 if portrait else maxi(2, int((vr.x - 40.0) / 380.0))
	if tab == "mine":
		for d: Dictionary in mine:
			_grid.add_child(_deck_tile(d))
		if mine.size() < DuelViews.MAX_SLOTS:
			_grid.add_child(_new_tile())
	else:
		for d: Dictionary in DuelViews.presets():
			_grid.add_child(_deck_tile(d))


func say(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	_status.visible = text != ""
	_status.modulate = Color(1.5, 1.4, 1.1, 1.0)
	if is_inside_tree():
		create_tween().tween_property(_status, "modulate", Color.WHITE, 0.3)


func status_text() -> String:
	return _status.text if _status != null and _status.visible else ""


## A deck tile: name + status chip, hero line, trait plates, mini curve, (preset) plan, actions.
func _deck_tile(d: Dictionary) -> PanelContainer:
	var preset: bool = bool(d.get("preset", false))
	var p: PanelContainer = W.panel(Color("#161C21"), W.AMBER if String(d["id"]) == vs_deck_id else W.PANEL_RIM, 10.0)
	p.name = "Deck_%s" % d["id"]
	p.set_meta(&"deck", d["id"])
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	p.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	col.add_child(head)
	var nm: Label = W.label(String(d["name"]), &"TileName", 22)
	nm.name = "DeckName"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(nm)
	var st: Dictionary = DuelViews.status_chip(d)
	if preset:
		var lk: PanelContainer = PanelContainer.new()
		lk.add_theme_stylebox_override(&"panel", W.flat(Color("#262D33"), W.FOG, 1, 4, 3))
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lr: HBoxContainer = HBoxContainer.new()
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lr.add_theme_constant_override(&"separation", 4)
		lk.add_child(lr)
		lr.add_child(W.Mark.new(&"lock", W.FOG, 14))
		lr.add_child(W.label("PRESET: COPY TO EDIT", &"HudTag", 14, W.FOG))
		head.add_child(lk)
	else:
		head.add_child(W.status_chip(String(st["text"]), bool(st["ok"]), String(st["text"]) == "NEEDS ATTENTION"))
	var h: Dictionary = DuelViews.hero(StringName(str(d.get("hero", ""))))
	var mid: HBoxContainer = HBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 8)
	col.add_child(mid)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 2)
	mid.add_child(info)
	var hl: Label = W.label("HERO %s" % (String(h["name"]) if not h.is_empty() else "— none —"), &"UnitName", 17, W.AMBER if not h.is_empty() else W.RED)
	hl.name = "HeroLine"
	info.add_child(hl)
	var traits: HBoxContainer = HBoxContainer.new()
	traits.add_theme_constant_override(&"separation", 4)
	info.add_child(traits)
	var comp: Dictionary = DuelViews.composition(d)
	for t: StringName in SynergyRules.TRAITS:
		var n: int = int(comp["traits"].get(t, 0))
		if n > 0:
			traits.add_child(W.TraitPlate.new(t, 22))
			traits.add_child(W.label("%d" % n, &"HudNumber", 16, W.FOG))
	var doc: StringName = StringName(str(d.get("doctrine", "")))
	if doc != &"":
		traits.add_child(W.label("· DOCTRINE %s" % SynergyGlyphs.trait_name(doc).to_upper(), &"HudTag", 14, W.FOG))
	info.add_child(W.label("Units %d · Tactics %d · Fields %d" % [comp["units"], comp["tactics"], comp["fields"]], &"HudSubtle", 16))
	var curve: Control = W.CurveChart.new(64.0)
	curve.name = "MiniCurve"
	curve.show_marker = false
	curve.custom_minimum_size = Vector2(130, 64)
	curve.set_counts(DuelViews.curve(d))
	curve.bar_inspected.connect(func(i: int) -> void: inspector().open(W.curve_info(DuelViews.curve(d), i)))
	curve.bar_tapped.connect(func(_i: int) -> void: open_deck_list(d))
	mid.add_child(curve)
	if preset:
		col.add_child(W.label(String(d.get("plan", "")), &"", 16, Color(0, 0, 0, 0), true))
		var r: Dictionary = DuelViews.preset_record(String(d["id"]))
		col.add_child(W.label("You vs %s: %s" % [d["name"], DuelViews.record_text(r)], &"HudSubtle", 16))
	var acts: HBoxContainer = HBoxContainer.new()
	acts.name = "Actions"
	acts.add_theme_constant_override(&"separation", 6)
	col.add_child(acts)
	var play_b: Button = _act("PLAY", &"ReadyButton", acts)
	play_b.name = "PlayButton"
	play_b.tooltip_text = "Play this deck against the AI"
	play_b.pressed.connect(func() -> void: open_vs_ai(String(d["id"])))
	if not preset:
		var edit_b: Button = _act("EDIT", &"HudButton", acts)
		edit_b.name = "EditButton"
		edit_b.pressed.connect(func() -> void: DuelFlow.open_builder(d))
	var copy_b: Button = _act("COPY", &"HudButton", acts)
	copy_b.name = "CopyButton"
	copy_b.tooltip_text = "Save a copy you can edit" if not preset else "Copy this preset into My Decks to edit it"
	copy_b.pressed.connect(func() -> void: copy_deck(d))
	if not preset:
		var del_b: Button = _act("DELETE", &"HudButton", acts)
		del_b.name = "DeleteButton"
		del_b.pressed.connect(func() -> void: ask_delete(d))
	else:
		var list_b: Button = _act("LIST", &"HudButton", acts)
		list_b.name = "ListButton"
		list_b.tooltip_text = "The 10 picks and the hero"
		list_b.pressed.connect(func() -> void: open_deck_list(d))
	wire_inspect_control(p, func() -> void: open_deck_list(d), false)
	p.tooltip_text = "%s · hold / right click: the deck list" % d["name"]
	return p


func _act(text: String, variation: StringName, parent: Control) -> Button:
	var b: Button = make_button(text, variation, 0)
	b.add_to_group(&"tap_target")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(70, W.TAP)
	parent.add_child(b)
	return b


func _new_tile() -> Button:
	var b: Button = Button.new()
	b.name = "NewDeck"
	b.theme_type_variation = &"PickTile"
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plus: Control = W.Mark.new(&"plus", W.AMBER, 34)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(plus)
	var l: Label = W.label("NEW DECK", &"TileName", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var s: Label = W.label("%d of %d slots free · start empty or from a preset" % [DuelViews.free_slots(), DuelViews.MAX_SLOTS], &"HudSubtle", 16)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	b.pressed.connect(open_new_deck)
	return b


# =============================================================================
# Actions
# =============================================================================

func copy_deck(d: Dictionary) -> Dictionary:
	var r: Dictionary = DuelViews.copy_deck(d)
	if bool(r.get("ok", false)):
		tab = "mine"
		_fill()
		say("Copied %s: \"%s\" is in My Decks (%d/%d)." % [d["name"], (r["deck"] as Dictionary)["name"], DuelViews.saved_decks().size(), DuelViews.MAX_SLOTS])
	else:
		say(String(r.get("text", "Could not copy.")))
	return r


func ask_delete(d: Dictionary) -> Dictionary:
	_sheet = W.sheet(self, "Delete %s? This can't be undone." % d["name"], "CANCEL", 640.0)
	_sheet["root"].name = "DeleteConfirm"
	var b: Button = make_button("DELETE", &"HudButton", 200)
	b.name = "ConfirmDelete"
	b.add_theme_color_override(&"font_color", W.RED)
	b.pressed.connect(func() -> void:
		DuelViews.delete_deck(String(d["id"]))
		_sheet["root"].queue_free()
		if vs_deck_id == String(d["id"]):
			vs_deck_id = ""
		_fill()
		say("Deleted %s (%d/%d decks)." % [d["name"], DuelViews.saved_decks().size(), DuelViews.MAX_SLOTS]))
	_sheet["body"].add_child(b)
	return _sheet


## "+ NEW DECK": start empty, or from one of the presets.
func open_new_deck() -> Dictionary:
	_sheet = W.sheet(self, "NEW DECK · %d of %d slots free" % [DuelViews.free_slots(), DuelViews.MAX_SLOTS], "CANCEL", 720.0)
	_sheet["root"].name = "NewDeckSheet"
	var body: VBoxContainer = _sheet["body"]
	var empty_b: Button = make_button("START EMPTY", &"ReadyButton", 0)
	empty_b.name = "StartEmpty"
	empty_b.pressed.connect(func() -> void: DuelFlow.open_builder(DuelViews.new_deck()))
	body.add_child(empty_b)
	body.add_child(W.label("Or start from a preset (a copy you can change):", &"HudSubtle", 16))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 1 if portrait else 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	body.add_child(grid)
	for d: Dictionary in DuelViews.presets():
		var b: Button = make_button("FROM %s" % String(d["name"]).to_upper(), &"HudButton", 0)
		b.name = "From_%s" % d["id"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: DuelFlow.open_builder(DuelViews.copy_of(d)))
		wire_inspect_button(b, func() -> void: open_deck_list(d))
		grid.add_child(b)
	return _sheet


## The deck list sheet (hero + 10 rows, each inspectable).
func open_deck_list(d: Dictionary) -> Dictionary:
	var s: Dictionary = W.sheet(self, "%s · 10 PICKS ×2 = 20 CARDS" % String(d["name"]).to_upper(), "CLOSE", 760.0)
	s["root"].name = "DeckListSheet"
	var body: VBoxContainer = s["body"]
	var h: Dictionary = DuelViews.hero(StringName(str(d.get("hero", ""))))
	body.add_child(W.hero_strip(h, Callable(), func() -> void: inspector().open(W.hero_info(h)), compact))
	if String(d.get("plan", "")) != "":
		body.add_child(W.label(String(d["plan"]), &"HudAccent", 16, Color(0, 0, 0, 0), true))
	var picks: Array = (d.get("picks", []) as Array).duplicate()
	picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = DuelViews.card(StringName(str(a["card"])))
		var cb: CardData = DuelViews.card(StringName(str(b["card"])))
		if ca == null or cb == null:
			return false
		return ca.cost < cb.cost if ca.cost != cb.cost else ca.display_name < cb.display_name)
	for p: Dictionary in picks:
		body.add_child(W.deck_row(p, func(id: StringName) -> void:
			var c: CardData = DuelViews.card(id)
			if c != null:
				inspector().open(W.card_info(c, StringName(str(p.get("art", ""))), "IN %s ×2" % String(d["name"]).to_upper())),
			Callable()))
	var curve: Control = W.CurveChart.new(90.0)
	curve.set_counts(DuelViews.curve(d))
	curve.bar_inspected.connect(func(i: int) -> void: inspector().open(W.curve_info(DuelViews.curve(d), i)))
	body.add_child(curve)
	_sheet = s
	# The inspector opens over the sheet.
	if _v2_inspector != null:
		move_child(_v2_inspector, get_child_count() - 1)
	return s


func inspector() -> Control:
	var insp: Control = super()
	move_child(insp, get_child_count() - 1)
	return insp


# =============================================================================
# VS AI
# =============================================================================

## The VS AI setup: your deck, the opponent (a preset or Random), the tier, START.
func open_vs_ai(deck_id: String = "") -> Dictionary:
	if is_instance_valid(get_sheet().get("root")):
		get_sheet()["root"].queue_free()
	var decks: Array[Dictionary] = playable_decks()
	if deck_id == "" or deck_by_id(deck_id).is_empty():
		deck_id = ""
		for d: Dictionary in decks:
			if bool(DuelViews.validate(d)["ok"]):
				deck_id = String(d["id"])
				break
	vs_deck_id = deck_id
	_sheet = W.sheet(self, "VS AI · ONE BATTLE", "CLOSE", 980.0)
	_sheet["root"].name = "VsAiSheet"
	_fill_vs_ai()
	return _sheet


func _fill_vs_ai() -> void:
	var body: VBoxContainer = _sheet["body"]
	clear(body)
	body.add_child(W.label("YOUR DECK", &"HudTag", 16, W.AMBER))
	body.add_child(_deck_picker(vs_deck_id, func(id: String) -> void:
		vs_deck_id = id
		_fill_vs_ai(), "YourDeck"))
	body.add_child(W.label("OPPONENT · the AI plays a preset deck (hold a tile to see its list)", &"HudTag", 16, W.AMBER))
	var og: GridContainer = GridContainer.new()
	og.name = "Opponents"
	og.columns = 2 if portrait else 5
	og.add_theme_constant_override(&"h_separation", 8)
	og.add_theme_constant_override(&"v_separation", 8)
	body.add_child(og)
	var opts: Array[Dictionary] = DuelViews.presets()
	opts.append({"id": "random", "name": "Random", "hero": &"", "plan": "One of the 4 presets, picked at the start.", "picks": []})
	for d: Dictionary in opts:
		og.add_child(_opponent_tile(d))
	body.add_child(W.label("DIFFICULTY", &"HudTag", 16, W.AMBER))
	var tr: HBoxContainer = HBoxContainer.new()
	tr.name = "Tiers"
	tr.add_theme_constant_override(&"separation", 8)
	body.add_child(tr)
	var line: String = ""
	for t: Dictionary in DuelViews.tiers():
		var b: Button = make_button(String(t["name"]), &"HudButton", 0)
		b.name = "Tier_%s" % t["id"]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(t["id"] == tier)
		b.tooltip_text = String(t["text"])
		b.pressed.connect(func() -> void:
			tier = t["id"]
			_fill_vs_ai())
		wire_inspect_button(b, func() -> void: inspector().open({"title": String(t["name"]), "type": "AI difficulty",
				"text": String(t["text"]), "keywords": [], "status": "Your record at this tier: %s" % DuelViews.record_text(_tier_record(t["id"]))}))
		tr.add_child(b)
		if t["id"] == tier:
			line = String(t["text"]) if String(t["text"]).to_lower().begins_with(String(t["name"]).to_lower()) else "%s: %s" % [String(t["name"]).capitalize(), t["text"]]
	var tl: Label = W.label(line, &"", 17, W.FOG, true)
	tl.name = "TierLine"
	body.add_child(tl)
	var mine: Dictionary = deck_by_id(vs_deck_id)
	var r: Dictionary = DuelViews.validate(mine) if not mine.is_empty() else {"ok": false, "errors": [{"text": "Pick a deck"}]}
	var go: Button = make_button("", &"ReadyButton", 0)
	go.name = "StartButton"
	go.add_to_group(&"tap_target")
	go.custom_minimum_size.y = 72
	if bool(r["ok"]):
		var opp: String = "a random preset" if opponent_id == "random" else String(deck_by_id(opponent_id).get("name", opponent_id))
		var vs_line: Label = W.label("%s vs %s · %s" % [mine["name"], opp, TIER_WORD(tier)], &"UnitName", 18, W.FOG, true)
		vs_line.name = "Matchup"
		body.add_child(vs_line)
		go.text = "START DUEL"
	else:
		body.add_child(W.rule_line(String(r["errors"][0]["text"]), &"error"))
		go.text = "CAN'T START YET"
		go.modulate = Color(1, 1, 1, 0.55)
	go.clip_text = true
	go.pressed.connect(func() -> void: start_vs_ai())
	body.add_child(go)
	if DuelViews.records().get("heroes", {}).is_empty():
		body.add_child(W.label("First duel? Try Spearhead against RECRUIT.", &"HudSubtle", 16))


static func TIER_WORD(t: StringName) -> String:
	return String(DuelViews.TIER_NAMES.get(t, String(t).to_upper()))


func _tier_record(t: StringName) -> Dictionary:
	var out: Dictionary = {"w": 0, "l": 0, "d": 0}
	for p: Dictionary in DuelViews.presets():
		var r: Dictionary = DuelViews.preset_record(String(p["id"]), t)
		for k: String in ["w", "l", "d"]:
			out[k] = int(out[k]) + int(r.get(k, 0))
	return out


func _opponent_tile(d: Dictionary) -> Button:
	var id: String = String(d["id"])
	var b: Button = Button.new()
	b.name = "Opp_%s" % id
	b.theme_type_variation = &"PickTileSelected" if id == opponent_id else &"PickTile"
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(150, 118)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_top = 6
	col.offset_right = -8
	col.add_child(W.label(String(d["name"]).to_upper(), &"TileName", 18))
	var h: Dictionary = DuelViews.hero(StringName(str(d.get("hero", ""))))
	col.add_child(W.label(String(h["name"]) if not h.is_empty() else "Any hero", &"HudAccent", 16))
	var t: StringName = DuelViews.main_trait(d)
	if t != &"":
		var tr: HBoxContainer = HBoxContainer.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.add_child(W.TraitPlate.new(t, 20))
		tr.add_child(W.label(SynergyGlyphs.trait_name(t), &"HudSubtle", 16))
		col.add_child(tr)
	if id != "random":
		col.add_child(W.label(DuelViews.record_text(DuelViews.preset_record(id, tier)), &"HudSubtle", 16))
	if id == opponent_id:
		col.add_child(W.status_chip("CHOSEN", true))
	b.pressed.connect(func() -> void:
		opponent_id = id
		_fill_vs_ai())
	if id != "random":
		wire_inspect_button(b, func() -> void: open_deck_list(d))
	else:
		wire_inspect_button(b, func() -> void: inspector().open({"title": "Random opponent", "type": "AI deck",
				"text": "The AI plays one of the 4 presets, picked when the duel starts. Its deck list is shown in the match intro.", "keywords": [], "status": ""}))
	b.tooltip_text = "%s · tap: choose · hold / right click: its deck list" % d["name"]
	return b


## An OptionButton with every playable deck (legal ones first), marking illegal ones.
func _deck_picker(selected: String, on_pick: Callable, n: String) -> OptionButton:
	var o: OptionButton = OptionButton.new()
	o.name = n
	o.theme_type_variation = &"HudButton"
	o.custom_minimum_size = Vector2(0, W.TAP)
	o.add_to_group(&"tap_target")
	o.clip_text = true
	var popup: PopupMenu = o.get_popup()
	popup.add_theme_font_size_override(&"font_size", 22)
	popup.add_theme_constant_override(&"v_separation", 30)
	var sel: int = -1
	for d: Dictionary in playable_decks():
		var ok: bool = bool(DuelViews.validate(d)["ok"])
		var h: Dictionary = DuelViews.hero(StringName(str(d.get("hero", ""))))
		o.add_item("%s%s · %s%s" % ["PRESET " if bool(d.get("preset", false)) else "", d["name"], h.get("name", "no hero"), "" if ok else " · NOT READY"])
		o.set_item_metadata(o.item_count - 1, String(d["id"]))
		if String(d["id"]) == selected:
			sel = o.item_count - 1
	if sel >= 0:
		o.select(sel)
	else:
		o.select(-1)
		o.text = "Pick a deck"
	o.item_selected.connect(func(i: int) -> void: on_pick.call(String(o.get_item_metadata(i))))
	return o


## START (VS AI). {ok, text}.
func start_vs_ai() -> Dictionary:
	var mine: Dictionary = deck_by_id(vs_deck_id)
	if mine.is_empty():
		say("Pick a deck first.")
		return {"ok": false, "text": "Pick a deck first."}
	var r: Dictionary = DuelFlow.start_match({"mode": DuelFlow.MODE_VS_AI, "decks": [mine, deck_by_id(opponent_id)],
			"names": ["You", String(deck_by_id(opponent_id).get("name", "AI"))], "tier": tier, "opponent_id": opponent_id})
	if not bool(r["ok"]):
		say(String(r["text"]))
		_sheet_say(String(r["text"]))
	return r


func _sheet_say(text: String) -> void:
	var s: Dictionary = get_sheet()
	if s.is_empty():
		return
	var l: Label = s["body"].get_node_or_null(^"SheetStatus") as Label
	if l == null:
		l = W.label("", &"", 17, W.RED.lightened(0.2), true)
		l.name = "SheetStatus"
		s["body"].add_child(l)
	l.text = text


# =============================================================================
# Pass & Play
# =============================================================================

func open_hot_seat() -> Dictionary:
	if is_instance_valid(get_sheet().get("root")):
		get_sheet()["root"].queue_free()
	for i: int in 2:
		if seat_decks[i] == "" or deck_by_id(seat_decks[i]).is_empty():
			seat_decks[i] = String(DuelViews.presets()[i]["id"])
	_sheet = W.sheet(self, "PASS & PLAY · two players, one device", "CLOSE", 980.0)
	_sheet["root"].name = "HotSeatSheet"
	_fill_hot_seat()
	return _sheet


func _fill_hot_seat() -> void:
	var body: VBoxContainer = _sheet["body"]
	clear(body)
	body.add_child(W.label("Each player deploys in private behind a cover screen; the device passes between you. The side that deploys first alternates every round.", &"HudSubtle", 16, Color(0, 0, 0, 0), true))
	var cols: BoxContainer = BoxContainer.new()
	cols.vertical = portrait
	cols.add_theme_constant_override(&"separation", 12)
	body.add_child(cols)
	for i: int in 2:
		var col: VBoxContainer = VBoxContainer.new()
		col.name = "Seat%d" % (i + 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override(&"separation", 6)
		cols.add_child(col)
		col.add_child(W.label("PLAYER %d" % (i + 1), &"HudTag", 16, W.AMBER))
		var e: LineEdit = LineEdit.new()
		e.name = "Name"
		e.max_length = 16
		e.text = seat_names[i]
		e.custom_minimum_size = Vector2(0, W.TAP)
		e.add_theme_font_size_override(&"font_size", 20)
		e.text_changed.connect(func(t: String) -> void: seat_names[i] = t)
		col.add_child(e)
		col.add_child(_deck_picker(seat_decks[i], func(id: String) -> void:
			seat_decks[i] = id
			_fill_hot_seat(), "Deck"))
		var d: Dictionary = deck_by_id(seat_decks[i])
		var r: Dictionary = DuelViews.validate(d, open_pool) if not d.is_empty() else {"ok": false, "errors": [{"text": "Pick a deck"}]}
		col.add_child(W.rule_line(String(r.get("ready_text", "")) if bool(r["ok"]) else String(r["errors"][0]["text"]), &"ok" if bool(r["ok"]) else &"error"))
	var pool_b: Button = make_button("OPEN POOL FOR THIS MATCH: %s" % ("ON" if open_pool else "OFF"), &"HudButton", 0)
	pool_b.name = "OpenPool"
	pool_b.toggle_mode = true
	pool_b.set_pressed_no_signal(open_pool)
	pool_b.tooltip_text = "On: both players may use every card, also the ones not found in a campaign run yet"
	pool_b.pressed.connect(func() -> void:
		open_pool = not open_pool
		_fill_hot_seat())
	body.add_child(pool_b)
	var go: Button = make_button("START · coin flip for the first seat", &"ReadyButton", 0)
	go.name = "StartButton"
	go.custom_minimum_size.y = 72
	go.pressed.connect(func() -> void: start_hot_seat())
	body.add_child(go)


func start_hot_seat() -> Dictionary:
	var a: Dictionary = deck_by_id(seat_decks[0])
	var b: Dictionary = deck_by_id(seat_decks[1])
	if a.is_empty() or b.is_empty():
		say("Both players need a deck.")
		return {"ok": false, "text": "Both players need a deck."}
	var r: Dictionary = DuelFlow.start_match({"mode": DuelFlow.MODE_HOT_SEAT, "decks": [a, b],
			"names": [seat_names[0].strip_edges() if seat_names[0].strip_edges() != "" else "Player 1",
					seat_names[1].strip_edges() if seat_names[1].strip_edges() != "" else "Player 2"], "open_pool": open_pool})
	if not bool(r["ok"]):
		say(String(r["text"]))
		_sheet_say(String(r["text"]))
	return r


func _records_info() -> Dictionary:
	var kws: Array[Dictionary] = []
	for h: Dictionary in DuelViews.heroes():
		kws.append({"name": String(h["name"]), "text": DuelViews.record_text(DuelViews.hero_record(h["id"]))})
	var rec: Dictionary = DuelViews.records()
	return {"title": "Duel record", "type": "Wins and losses vs the AI, by hero",
			"text": "Duel gives records and cosmetics only: a Duelist banner frame for a win with each hero, a map stamp for each preset beaten on Veteran.",
			"keywords": kws, "status": "Pass & Play games: %d" % int(rec.get("hot_seat_games", 0))}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if not get_sheet().is_empty():
			get_sheet()["root"].queue_free()
		elif _v2_inspector == null or not _v2_inspector.visible:
			goto(DuelFlow.SCENE_TITLE)
		get_viewport().set_input_as_handled()
