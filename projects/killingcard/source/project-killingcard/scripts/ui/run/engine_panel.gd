# engine_panel.gd
# Purpose: The run's deck view and Engine panel (kc-syn-ui; synergy-system.md §5.2, §9): an overlay
#   any run screen can open (DECK button). Top: the engine in one look: cards per trait (trait icon
#   + count + what the deck can switch on: "2 in play: tier 2"), neighbour keyword counts, Doctrine,
#   deck size over the deck floor (RunConfig.deck_floor, 8 since kc-econ) (kc-onboard-ui: the Engine part shows once RevealGate shows
#   ENGINE_PANEL; Standard Issue rows carry the title-style name). Below: every design in the deck,
#   one row each, with its copies' traits and keyword glyphs. kc-ipad-cards (kc-no-training): no
#   copy levels, camo level chips, Recruit counts or "Trains:" lines.
#   kc-loadout-clean (head: "The deck view should show the calling card properly"): CARDS is a grid of
#   card faces (BannerCard: the calling-card art, name, cost hex, stats) with an "x3" count badge,
#   one per design, the Operator first (its brass frame and OPERATOR tab). The grid picks the column
#   count that shows a 10-card deck whole (iPad, phone, desktop); bigger decks scroll (touch drags the
#   list). The Standard Issue count is a short chip (tap / long press: what it means).
#   Each card can be long-pressed / right-clicked for its full rules (row_inspected; with nobody
#   listening the panel opens its own inspector); CLOSE or a tap on the scrim closes it.
# Dependencies: RunProgress (engine_summary, deck_view), synergy_glyphs.gd, run_screen.gd builders,
#   press_gesture.gd, hud_theme.tres.
# Author: UI/UX Agent (kc-syn-ui)
extends Control

signal closed
signal row_inspected(card_id: StringName)

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
## Card grid: gap, the banner's width:height (the art is cover-cropped), widest / narrowest card.
const GRID_GAP: float = 10.0
const ART_RATIO: float = 3.2
const ART_RATIO_TALL: float = 2.4
const CARD_MAX_W: float = 440.0
const CARD_MIN_W: float = 190.0
const CAPTION_H: float = 22.0

var _panel: PanelContainer = null
var _list: VBoxContainer = null
var _title: Label = null
var _close: Button = null
var _gestures: Array = []
var _grid: GridContainer = null
var _si_chip: Button = null
var _inspector: Control = null
var _run: RunProgress = null


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
	_si_chip = Button.new()
	_si_chip.name = "StandardIssueChip"
	_si_chip.theme_type_variation = &"HudButton"
	_si_chip.custom_minimum_size = Vector2(0, 64)
	_si_chip.add_to_group(&"tap_target")
	_si_chip.tooltip_text = "Standard Issue cards: the basic kit. Tap for what that means."
	_si_chip.pressed.connect(_open_si_info)
	head.add_child(_si_chip)
	head.move_child(_si_chip, 1)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12  # touch: a drag on the cards scrolls the list
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)
	resized.connect(_fit)
	_inspector = INSPECTOR_SCENE.instantiate()
	_inspector.name = "Inspector"
	add_child(_inspector)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspector.hide()
	hide()


func _fit() -> void:
	if _panel == null:
		return
	var w: float = minf(size.x - 32.0, 1400.0)
	var h: float = size.y - 24.0
	_panel.custom_minimum_size = Vector2(w, h)
	var scroll: Control = _panel.find_child("Scroll", true, false)
	if scroll != null:
		scroll.custom_minimum_size.y = maxf(120.0, h - 64.0 - 40.0)
	_fit_grid.call_deferred()


## kc-loadout-clean: the card size and column count. The widest cards that show every tile without
## scrolling win; when none fit (a big deck on a short screen) the cards keep CARD_MIN_W and scroll.
func _fit_grid() -> void:
	if _grid == null or not is_instance_valid(_grid) or _panel == null:
		return
	var scroll: ScrollContainer = _panel.find_child("Scroll", true, false) as ScrollContainer
	var n: int = _grid.get_child_count()
	if scroll == null or n == 0:
		return
	var room_w: float = maxf(200.0, maxf(scroll.size.x, _panel.custom_minimum_size.x - 24.0) - 14.0)
	var others: float = 0.0
	for c: Node in _list.get_children():
		if c != _grid and c is Control and (c as Control).visible:
			others += (c as Control).get_combined_minimum_size().y + float(_list.get_theme_constant(&"separation"))
	var room_h: float = maxf(80.0, maxf(scroll.size.y, scroll.custom_minimum_size.y) - others - 4.0)
	# Each layout: the width the columns give, the banner as tall as the rows allow (between
	# ART_RATIO and ART_RATIO_TALL, cover-cropped). The biggest card that fits wins.
	var best: Vector2 = Vector2.ZERO
	var best_cols: int = 0
	for cols: int in range(2, 7):
		var w: float = minf(CARD_MAX_W, floorf((room_w - (cols - 1) * GRID_GAP) / cols))
		if w < CARD_MIN_W and cols > 2:
			break
		var rows: int = ceili(float(n) / cols)
		var per_row: float = floorf((room_h - (rows - 1) * GRID_GAP) / rows)
		if per_row < tile_h(w):
			continue
		var th: float = minf(per_row, tile_h(w, ART_RATIO_TALL))
		if w * th > best.x * best.y + 1.0:
			best = Vector2(w, th)
			best_cols = cols
	if best_cols == 0:
		# Too many cards to show at once: the narrowest comfortable card, as many columns as fit.
		var cols2: int = clampi(int(floorf((room_w + GRID_GAP) / (CARD_MIN_W + GRID_GAP))), 2, 6)
		var w2: float = minf(CARD_MAX_W, floorf((room_w - (cols2 - 1) * GRID_GAP) / cols2))
		best = Vector2(w2, tile_h(w2))
		best_cols = cols2
	_grid.columns = best_cols
	for t: Node in _grid.get_children():
		var tile: Control = t as Control
		tile.custom_minimum_size = best
		var card: Control = tile.get_node_or_null(^"Card") as Control
		if card != null:
			card.custom_minimum_size = Vector2(best.x, best.y - CAPTION_H)
			card.size = card.custom_minimum_size


## A card's height at width w (the banner at `ratio` plus the name plate).
static func card_h(w: float, ratio: float = ART_RATIO) -> float:
	return roundf(w / ratio) + BannerCard.PLATE_H + 6.0


## A grid tile's height (the card plus its caption line).
static func tile_h(w: float, ratio: float = ART_RATIO) -> float:
	return card_h(w, ratio) + CAPTION_H


func is_open() -> bool:
	return visible


func close() -> void:
	if _inspector != null and _inspector.visible:
		_inspector.close()
		return
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
	_run = r
	var e: Dictionary = r.engine_summary()
	_title.text = "YOUR DECK  ·  %d CARDS" % int(e["deck_size"])
	# kc-onboard-ui: the Engine part arrives with RevealGate ENGINE_PANEL (§5.2). kc-loadout-clean:
	# the Standard Issue / calling-card split is a short chip by the title (tap: what it means).
	var si_n: int = int(e.get("standard_issue", 0))
	_si_chip.text = "Standard Issue: %d of %d" % [si_n, int(e["deck_size"])]
	_si_chip.visible = si_n > 0
	_si_chip.set_meta(&"info", {"si": si_n, "deck": int(e["deck_size"]), "floor": int(e["floor"])})
	if not RevealGate.shown(RevealFlags.ENGINE_PANEL):
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
	if not kw_bits.is_empty():
		_list.add_child(_line("Neighbour keywords: %s." % ", ".join(kw_bits)))
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


## kc-loadout-clean: the card grid: the Operator first, then one card face per design (its first
## copy's art) with an "x3" badge and, for calling cards, the copies' traits under it.
func _add_rows(r: RunProgress) -> void:
	var order: Array[StringName] = []
	var by_id: Dictionary = {}
	for d: Dictionary in r.deck_view():
		var id: StringName = d["id"]
		if not by_id.has(id):
			order.append(id)
			by_id[id] = []
		(by_id[id] as Array).append(d)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.add_theme_constant_override(&"h_separation", int(GRID_GAP))
	_grid.add_theme_constant_override(&"v_separation", int(GRID_GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(_grid)
	var op: Control = _operator_tile(r)
	if op != null:
		_grid.add_child(op)
	for id: StringName in order:
		_grid.add_child(_card_row(r, id, by_id[id]))
	_fit_grid.call_deferred()


## The Operator's tile (brass frame, OPERATOR tab), or null when the run has none.
func _operator_tile(r: RunProgress) -> Control:
	var item: LoadoutItem = r.resource(r.primary) as LoadoutItem if r.primary != &"" else null
	if item == null:
		return null
	var kws: Array = []
	for k: StringName in [&"first_shot", &"pick", &"flank"]:
		if bool(item.get(k)):
			kws.append({"id": k})
	if item.cover > 0:
		kws.append({"id": &"cover", "value": item.cover})
	var entry: Dictionary = {"name": item.display_name, "cls": "OPERATOR", "operator": true, "fp": item.operator_firepower,
			"armor": item.operator_armor, "armor_max": item.operator_armor, "keywords": kws, "cost": "",
			"camo": String(BannerArtDB.camo_for_tier(1)), "banner": String(BannerArtDB.operator_art_id(item.id, 1))}
	var tile: VBoxContainer = _tile_box("Operator_%s" % item.id, entry, "OPERATOR  ·  ALWAYS IN HAND", -1)
	tile.set_meta(&"operator", true)
	tile.tooltip_text = "%s: your Operator. It starts in your hand every match. Long-press / right-click: its rules." % item.display_name
	_wire_tile(tile, func() -> void:
		var sp: Control = (load("res://scripts/ui/run/starter_panel.gd") as GDScript).new()
		sp.set(&"run", r)
		sp.set(&"_config", r.config)
		sp.set(&"picked", item.id)
		var info: Dictionary = sp.call(&"operator_info", item)
		sp.free()
		info["status"] = "Your Operator for this run."
		_inspector.open(info))
	return tile


## A grid tile: the card face (BannerCard) with its count badge, and a caption line under it.
func _tile_box(tile_name: String, entry: Dictionary, caption: String, count: int) -> VBoxContainer:
	var tile := VBoxContainer.new()
	tile.name = tile_name
	tile.add_theme_constant_override(&"separation", 0)
	tile.add_to_group(&"tap_target")
	tile.set_meta(&"inspectable", true)
	var w: float = CARD_MIN_W
	var card: PanelContainer = BannerCard.build(entry, Vector2(w, card_h(w)))
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in card.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(card)
	if count > 0:
		var badge := Label.new()
		badge.name = "CountBadge"
		badge.text = "x%d" % count
		badge.add_theme_font_override(&"font", CardLook.NUM_FONT)
		badge.add_theme_font_size_override(&"font_size", 18)
		badge.add_theme_color_override(&"font_color", Color.WHITE)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.06, 0.92)
		sb.border_color = Color("#F5B83D")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		badge.add_theme_stylebox_override(&"normal", sb)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		# Top-right of the banner (the cost hex is top-left).
		card.sort_children.connect(func() -> void:
			var need: Vector2 = badge.get_combined_minimum_size()
			badge.size = need
			badge.position = Vector2(card.size.x - need.x - 6.0, 6.0))
	var cap := Label.new()
	cap.name = "Caption"
	cap.text = caption
	cap.theme_type_variation = &"HudSubtle"
	cap.custom_minimum_size.y = CAPTION_H
	cap.clip_text = true
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(cap)
	return tile


## Tap or long press / right click on a tile opens its rules (a drag scrolls the list on touch).
func _wire_tile(tile: Control, on_inspect: Callable) -> void:
	var g: RefCounted = PressGesture.new(tile)
	# A move past 10 px is a drag: no tap, no long press. The events PASS up, so the ScrollContainer
	# scrolls the list under a finger.
	g.drag_enabled = true
	_gestures.append(g)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.gui_input.connect(func(e: InputEvent) -> void: g.handle(e))
	g.long_pressed.connect(func(_p: Vector2) -> void: on_inspect.call())
	g.tapped.connect(func(_p: Vector2) -> void: on_inspect.call())


## The deck card's inspector: row_inspected for a screen that has its own, else the panel's.
func _inspect(id: StringName) -> void:
	if not row_inspected.get_connections().is_empty():
		row_inspected.emit(id)
		return
	var card: CardData = _run.resource(id) as CardData if _run != null else null
	if card == null:
		return
	var e: Dictionary = {"kind": &"unit" if card.is_unit() else (&"field" if card.is_field() else &"tactic"), "card": card,
			"id": card.id, "art": card.id, "arts": BannerArtDB.alt_arts(card.id), "name": card.display_name}
	_inspector.open((load("res://scripts/ui/codex/codex_view.gd") as GDScript).call(&"inspector_info", e))


## The Standard Issue chip: what the count means.
func _open_si_info() -> void:
	var m: Dictionary = _si_chip.get_meta(&"info", {})
	var si: int = int(m.get("si", 0))
	var deck: int = int(m.get("deck", 0))
	_inspector.open({"title": "Standard Issue", "type": "deck · %d of %d cards" % [si, deck],
			"text": "Standard Issue cards are the basic kit: no trait, no calling card. Muster out (at a shop) sends one home. Calling cards: %d. Your deck never goes under %d cards." % [deck - si, int(m.get("floor", 0))],
			"status": "Long-press any card for its rules."})


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
	var art: StringName = StringName(str((copies[0] as Dictionary).get("art", ""))) if not copies.is_empty() else &""
	var entry: Dictionary = BannerCard.entry_for_card(card, art) if card != null else {"name": String(id), "banner": String(id)}
	var si: bool = card != null and card.standard_issue
	# kc-trait-ui: per copy, the trait its art gives (two copies of one card can differ).
	var per: Dictionary = {}
	var order_t: Array[StringName] = []
	for d: Dictionary in copies:
		if card == null or (not card.has_trait_choice() and card.card_trait == &""):
			break
		var tc: StringName = StringName(d.get("trait_choice", &""))
		if not per.has(tc):
			per[tc] = 0
			order_t.append(tc)
		per[tc] = int(per[tc]) + 1
	var words: PackedStringArray = []
	for tc: StringName in order_t:
		words.append("%s %d" % [ArtTraits.trait_name(tc) if tc != &"" else "plain", int(per[tc])])
	# The card face already says Standard Issue / TACTIC: the caption only adds the copies' traits.
	var caption: String = " · ".join(words)
	var tile: VBoxContainer = _tile_box("Row_%s" % id, entry, caption, copies.size())
	tile.set_meta(&"id", id)
	tile.set_meta(&"count", copies.size())
	if not words.is_empty():
		tile.get_node("Caption").name = "CopyTraits"
	var nm: String = card.display_name if card != null else String(id)
	tile.tooltip_text = ("%d x %s: Standard Issue %s, basic kit with no trait. Long-press / right-click: rules." % [copies.size(), nm, RunProgress.standard_issue_serial(card)]) if si else \
			("%d x %s: %s. Each copy keeps the art it was found with; the art decides its trait. Long-press / right-click: rules." % [
			copies.size(), nm, " · ".join(words) if not words.is_empty() else "no trait"])
	_wire_tile(tile, _inspect.bind(id))
	return tile
