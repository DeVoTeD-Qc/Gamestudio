# engine_panel.gd
# Purpose: The run's deck view and Engine panel (kc-syn-ui; synergy-system.md §5.2, §9): an overlay
#   any run screen can open (DECK button). Top: the engine in one look: Trained cards per trait
#   (trait icon + count + what the deck can switch on: "2 in play: tier 2"), neighbour keyword
#   counts, how many Recruits are still waiting to be trained, Doctrine, deck size over the 15-card
#   floor (kc-onboard-ui: the Engine part shows from the first Promotion, RevealGate; Standard Issue
#   rows carry the stencil name and serial plate, Recruit rows their greyed "Trains:" line). Below: every design in the deck, one row each, with its copies by level (camo band chip:
#   plain Recruit, Gilded Trained, Forged Veteran, Priceless Elite), its trait and keyword glyphs.
#   Each row can be long-pressed / right-clicked for its card's full rules (row_inspected); CLOSE or
#   a tap on the scrim closes it.
# Dependencies: RunProgress (engine_summary, deck_view), synergy_glyphs.gd, run_screen.gd builders,
#   press_gesture.gd, hud_theme.tres.
# Author: UI/UX Agent (kc-syn-ui)
extends Control

signal closed
signal row_inspected(card_id: StringName, level: int)

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

var _panel: PanelContainer = null
var _list: VBoxContainer = null
var _title: Label = null
var _close: Button = null
var _gestures: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.05, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "EnginePanel"
	_panel.theme_type_variation = &"HudPanelDark"
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = &"HudHeader"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = "CLOSE"
	_close.theme_type_variation = &"HudButton"
	_close.custom_minimum_size = Vector2(140, 64)
	_close.add_to_group(&"tap_target")
	_close.pressed.connect(close)
	head.add_child(_close)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)
	resized.connect(_fit)
	hide()


func _fit() -> void:
	if _panel == null:
		return
	var w: float = minf(size.x - 32.0, 980.0)
	var h: float = size.y - 24.0
	_panel.custom_minimum_size = Vector2(w, h)
	var scroll: Control = _panel.find_child("Scroll", true, false)
	if scroll != null:
		scroll.custom_minimum_size.y = maxf(120.0, h - 64.0 - 40.0)


func is_open() -> bool:
	return visible


func close() -> void:
	if visible:
		hide()
		closed.emit()


## Shows the deck of `r` (RunProgress).
func open(r: RunProgress) -> void:
	if r == null:
		return
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_gestures.clear()
	var e: Dictionary = r.engine_summary()
	_title.text = "YOUR DECK  ·  %d CARDS (FLOOR %d)" % [int(e["deck_size"]), int(e["floor"])]
	# kc-onboard-ui: the Engine part arrives with the first Promotion (§5.2: RevealGate ENGINE_PANEL);
	# before that the deck view is the plain list, with the Standard Issue / calling-card split.
	var si_n: int = int(e.get("standard_issue", 0))
	_list.add_child(_line("Standard Issue: %d of %d cards (basic kit; Muster out sends it home). Calling cards: %d." % [
			si_n, int(e["deck_size"]), int(e["deck_size"]) - si_n]))
	if not RevealGate.shown(RevealFlags.ENGINE_PANEL):
		_list.add_child(_section("CARDS"))
		_add_rows(r)
		show()
		_fit()
		_close.grab_focus.call_deferred()
		return
	_list.add_child(_section("ENGINE"))
	var traits: Dictionary = e["traits"]
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 12)
	row.add_theme_constant_override(&"v_separation", 6)
	for t: StringName in SynergyRules.TRAITS:
		row.add_child(_trait_chip(t, int(traits.get(t, 0)), StringName(e["doctrine"]) == t, StringName(e["main_trait"]) == t))
	_list.add_child(row)
	var kw_bits: PackedStringArray = []
	var kws: Dictionary = e["keywords"]
	for kw: StringName in SynergyRules.KEYWORDS:
		if int(kws.get(kw, 0)) > 0:
			kw_bits.append("%s %d" % [SynergyGlyphs.keyword_name(kw), int(kws[kw])])
	_list.add_child(_line("Neighbour keywords (Trained): %s." % (", ".join(kw_bits) if not kw_bits.is_empty() else "none yet")))
	_list.add_child(_line("Recruits waiting to be trained: %d (Promotion trains one and unlocks its keywords)." % int(e["recruits"])))
	var doc: StringName = StringName(e["doctrine"])
	_list.add_child(_line("Doctrine: %s." % ("%s (its sets count +1 in every match)" % SynergyGlyphs.trait_name(doc) if doc != &"" else "not set yet (your first calling card sets it)")))
	var main: StringName = StringName(e["main_trait"])
	if main != &"":
		_list.add_child(_line("Main trait: %s. Supply Drops always offer one %s card first." % [SynergyGlyphs.trait_name(main), SynergyGlyphs.trait_name(main)]))
	_list.add_child(_section("CARDS"))
	_add_rows(r)
	show()
	_fit()
	_close.grab_focus.call_deferred()


## One row per design: copies by level.
func _add_rows(r: RunProgress) -> void:
	var order: Array[StringName] = []
	var by_id: Dictionary = {}
	for d: Dictionary in r.deck_view():
		var id: StringName = d["id"]
		if not by_id.has(id):
			order.append(id)
			by_id[id] = []
		(by_id[id] as Array).append(d)
	for id: StringName in order:
		_list.add_child(_card_row(r, id, by_id[id]))


func _section(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"KeywordName"
	l.text = text
	return l


func _line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Trait counter: icon + "Vanguard 4" + what it reaches on the board.
func _trait_chip(t: StringName, n: int, doctrine: bool, main: bool) -> Control:
	var box := HBoxContainer.new()
	box.name = "Trait_%s" % t
	box.add_theme_constant_override(&"separation", 6)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		SynergyGlyphs.draw_trait_plate(icon, Rect2(Vector2.ZERO, icon.size), t, n >= SynergyRules.TIER2, n >= SynergyRules.TIER3))
	box.add_child(icon)
	var words: String = "%s %d%s%s" % [SynergyGlyphs.trait_name(t), n, " · DOCTRINE" if doctrine else "", " · MAIN" if main else ""]
	var l := Label.new()
	l.text = words
	l.add_theme_color_override(&"font_color", SynergyGlyphs.trait_color(t) if n > 0 else Color("#8A949C"))
	box.add_child(l)
	return box


func _card_row(r: RunProgress, id: StringName, copies: Array) -> Control:
	var card: CardData = r.resource(id) as CardData
	var panel := PanelContainer.new()
	panel.name = "Row_%s" % id
	panel.theme_type_variation = &"HudPanelDark"
	panel.custom_minimum_size.y = 44
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var name_l := Label.new()
	name_l.text = "%s  x%d" % [card.display_name if card != null else String(id), copies.size()]
	name_l.custom_minimum_size.x = 250
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var si: bool = card != null and card.standard_issue
	if si:
		# kc-onboard-ui: the Standard Issue name in the stencil font, with its serial.
		name_l.text = "%s  x%d" % [card.display_name.to_upper(), copies.size()]
		name_l.add_theme_font_override(&"font", CardLook.TITLE_FONT)  # kc-cards-impl: one title style
		name_l.add_theme_color_override(&"font_color", StandardIssueLook.NAME)
	row.add_child(name_l)
	if si:
		var plate := Control.new()
		plate.name = "SerialPlate"
		var serial: String = RunProgress.standard_issue_serial(card)
		plate.custom_minimum_size = Vector2(StandardIssueLook.serial_width(serial, 24.0), 24)
		plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.draw.connect(func() -> void: StandardIssueLook.draw_serial_plate(plate, Rect2(Vector2.ZERO, plate.size), serial))
		row.add_child(plate)
	var cost_l := Label.new()
	cost_l.theme_type_variation = &"HudSubtle"
	cost_l.text = "cost %d" % card.cost if card != null else ""
	cost_l.custom_minimum_size.x = 70
	cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost_l)
	# Level chips: a camo swatch + the level name per copy (counted).
	var levels: Dictionary = {}
	for d: Dictionary in copies:
		levels[int(d["level"])] = int(levels.get(int(d["level"]), 0)) + 1
	var trained_kw: StringName = &""
	for d: Dictionary in copies:
		if StringName(d["keyword"]) != &"":
			trained_kw = d["keyword"]
	var has_syn: bool = card != null and not card.standard_issue and (card.card_trait != &"" or card.neighbor_keyword != &"" or card.has_trait_choice())
	if not si:
		for lv: int in [0, 1, 2, 3]:
			if not levels.has(lv):
				continue
			row.add_child(_level_chip(lv, int(levels[lv]), has_syn))
	# kc-onboard-ui: a Recruit's locked keywords ("Trains: First Shot · Guard", greyed).
	var trains: String = ""
	for d: Dictionary in copies:
		if String(d.get("trains", "")) != "":
			trains = String(d["trains"])
	if trains != "":
		var tr := Label.new()
		tr.name = "TrainsLine"
		tr.theme_type_variation = &"HudSubtle"
		tr.text = trains
		tr.add_theme_color_override(&"font_color", Color("#8C969E"))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	# kc-trait-ui: per copy, the trait its art gives (two copies of one card can differ). Lit plate =
	# a Trained copy carries it; dark = Recruits that will train into it. Words next to it.
	var per: Dictionary = {}   # trait -> [trained, recruits]
	var order_t: Array[StringName] = []
	for d: Dictionary in copies:
		var tc: StringName = StringName(d.get("trait_choice", &""))
		if card == null or (not card.has_trait_choice() and card.card_trait == &""):
			break
		if not per.has(tc):
			per[tc] = [0, 0]
			order_t.append(tc)
		(per[tc] as Array)[0 if int(d["level"]) >= SynergyRules.LEVEL_TRAINED else 1] += 1
	var words: PackedStringArray = []
	for tc: StringName in order_t:
		var pr: Array = per[tc]
		var nm: String = ArtTraits.trait_name(tc) if tc != &"" else "plain"
		if int(pr[0]) > 0:
			words.append("%s %d" % [nm, int(pr[0])])
		if int(pr[1]) > 0:
			words.append("%s %d (Recruit)" % [nm, int(pr[1])])
	if not words.is_empty():
		var tl := Label.new()
		tl.name = "CopyTraits"
		tl.theme_type_variation = &"HudSubtle"
		tl.text = " · ".join(words)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tl)
		row.move_child(tl, row.get_child_count() - 2)
	var glyphs := Control.new()
	glyphs.name = "Glyphs"
	glyphs.custom_minimum_size = Vector2(28 * maxi(1, order_t.size()) + 24, 24)
	glyphs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyphs.set_meta(&"traits", order_t)
	var kw: StringName = card.neighbor_keyword if card != null else &""
	glyphs.draw.connect(func() -> void:
		var x: float = 0.0
		for tc: StringName in order_t:
			if tc != &"":
				SynergyGlyphs.draw_trait_plate(glyphs, Rect2(x, 0, 24, 24), tc, int((per[tc] as Array)[0]) > 0, false)
				if int((per[tc] as Array)[0]) == 0:
					glyphs.draw_rect(Rect2(x, 0, 24, 24), Color(0, 0, 0, 0.45))
			else:
				BannerView._dashed_rect(glyphs, Rect2(x, 0, 24, 24).grow(-1.0), Color(1, 1, 1, 0.4), 1.0)
			x += 28.0
		if kw != &"":
			SynergyGlyphs.draw_keyword_plate(glyphs, Rect2(x, 0, 24, 24), kw, trained_kw != &"", Color("#2EC4B6"), true))
	row.add_child(glyphs)
	panel.tooltip_text = ("%s: Standard Issue %s, basic kit with no trait. Long-press / right-click: rules." % [card.display_name, RunProgress.standard_issue_serial(card)]) if si else \
			("%s: %s. Each copy keeps the art it was found with; the art decides its trait. Long-press / right-click: rules." % [
			card.display_name if card != null else String(id), " · ".join(words) if not words.is_empty() else "no trait"])
	var g: RefCounted = PressGesture.new(panel)
	g.drag_enabled = false
	_gestures.append(g)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if g.handle(e):
			panel.accept_event())
	var top_level: int = 0
	for d: Dictionary in copies:
		top_level = maxi(top_level, int(d["level"]))
	g.long_pressed.connect(func(_p: Vector2) -> void: row_inspected.emit(id, top_level))
	return panel


func _level_chip(lv: int, n: int, has_syn: bool) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(18, 18)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band: StringName = SynergyGlyphs.band_of(lv)
	sw.draw.connect(func() -> void:
		if band == &"":
			sw.draw_rect(Rect2(Vector2.ZERO, sw.size), Color("#2A3036"))
			sw.draw_rect(Rect2(Vector2.ZERO, sw.size), Color("#8A949C"), false, 1.0)
		else:
			SynergyGlyphs.draw_band(sw, Rect2(Vector2.ZERO, sw.size), band))
	box.add_child(sw)
	var l := Label.new()
	l.text = "%d %s" % [n, SynergyGlyphs.level_name(lv) if has_syn or lv >= 2 else "plain"]
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box
