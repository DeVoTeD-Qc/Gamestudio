# codex_view.gd
# Purpose: kc-ui3 CODEX (head: "We'll need a codex view"). A full-screen overlay that browses every
#   collectible card and every killstreak, opened from MENU (pause sheet) and from the Title screen.
#   Top bar: BACK, the title with the count shown, the chassis picker and STARTER (the starter deck
#   and the Operator pick, starter_panel.gd). Filter row: type chips (ALL / UNITS / TACTICS / FIELDS /
#   KILLSTREAKS) and weapon-class chips (ANY / AR / SMG / SHOTGUN / SNIPER / LMG). Below, a scrolling
#   grid with ONE tile per unique card (kc-ui4): the card as it looks on the board (BannerCard: the
#   banner with its cost hex and name). Long-press / right-click / hover = the card inspector (the
#   match's). Tap = the ART panel: every art of the card (licensed calling cards in the pitch build,
#   our own looks and trait-option placeholders in the public build), grouped by the trait it gives,
#   each tile with its trait in the trait slot (ArtTraits.trait_of; dashed = no trait) and FOUND /
#   not found yet (Settings.found_arts), a big preview with "GIVES <TRAIT>" and the subname.
#   kc-trait-ui (head): the Codex is a VIEWER / collection; there is no EQUIP. In a run every copy
#   comes with the art it was found with, and that art decides its trait. Every control is 64 px+
#   tall (44 pt on a phone). Reads CardDB, BannerArtDB, ArtTraits and Settings; writes nothing.
# Usage: var codex := CodexView.open_over(parent_control)   # adds itself full-rect and opens
# Dependencies: CardDB, BannerArtDB, CardInfo, cost_hex.gd, scenes/match/CardInspector.tscn,
#   hud_theme.tres (HudPanelDark, HudButton, HandCard, UnitName, HudTag, HudHeader, HudSubtle, Scrim).
# Author: UI/UX Agent (kc-ui3)
extends Control

signal closed

const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const INSPECTOR_SCENE: PackedScene = preload("res://scenes/match/CardInspector.tscn")
const THEME: Theme = preload("res://assets/ui/hud_theme.tres")
const TYPE_FILTERS: Array[StringName] = [&"all", &"unit", &"tactic", &"field", &"killstreak"]
const TYPE_WORDS: Dictionary = {&"all": "ALL", &"unit": "UNITS", &"tactic": "TACTICS", &"field": "FIELDS",
		&"killstreak": "KILLSTREAKS"}
const CLASS_FILTERS: Array[StringName] = [&"any", &"ar", &"smg", &"shotgun", &"sniper", &"lmg"]
const KS_ICONS: Dictionary = {&"recon_drone": "ks_recon_drone", &"mortar_barrage": "ks_mortar",
		&"sentry_turret": "ks_sentry", &"attack_helo": "ks_attack_helo", &"gunship": "ks_gunship"}
## kc-cards-impl: Codex tiles are Y2+ cards (the mock-up's Codex card is 172 wide).
const TILE: Vector2 = Vector2(196, 202)
const TILE_COMPACT: Vector2 = Vector2(172, 196)
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/match/CardView.tscn")
## The board's banner heights (desktop / phone): codex cards use the board's icon sizes.
const METRIC_H: float = 76.0
const METRIC_H_COMPACT: float = 57.0
const AMBER: Color = Color(0.961, 0.722, 0.239)
const BAR_H: float = 64.0

var type_filter: StringName = &"all"
var class_filter: StringName = &"any"
## Chassis (card / killstreak id) filter, &"" = all.
var chassis_filter: StringName = &""
## kc-ui4: always one tile per card (the alternate arts live in the ART panel). Kept for the QA bridge.
var all_arts: bool = false
var compact: bool = false
## Every entry: {key, id, kind (&"unit"/&"tactic"/&"field"/&"killstreak"), cls (&"ar"...), name,
## chassis (display name), art (art id), card (CardData) | item (LoadoutItem)}.
var entries: Array[Dictionary] = []

var _count: Label = null
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _empty: VBoxContainer = null
var _chassis: OptionButton = null
var _arts_button: Button = null
var _back: Button = null
var _type_buttons: Dictionary = {}
var _class_buttons: Dictionary = {}
var _inspector: Control = null
var _top: HBoxContainer = null
var _filters: HBoxContainer = null
var _starter_button: Button = null
var _glossary_button: Button = null
var _glossary: Control = null
var _starter: Control = null
## kc-ui4 ART panel: the entry shown, its art ids, the art previewed.
var art_entry: Dictionary = {}
var art_ids: Array[StringName] = []
var selected_art: StringName = &""
var _art_panel: Control = null
var _art_title: Label = null
var _art_preview_holder: Control = null
var _art_info: Label = null
var _art_trait: Label = null
var _art_grid: GridContainer = null
## kc-trait-ui: the "GIVES <TRAIT>" chip of the previewed art (icon + words) and its label.
var _gives: HBoxContainer = null
var _gives_label: Label = null
var _gives_trait: StringName = &""
var _art_inspect: Button = null
var _art_back: Button = null


## Adds a codex over `parent` (full rect) and opens it. Frees itself when closed.
static func open_over(parent: Control) -> Control:
	var codex: Control = (load("res://scripts/ui/codex/codex_view.gd") as GDScript).new()
	codex.name = "Codex"
	parent.add_child(codex)
	codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex.closed.connect(codex.queue_free)
	codex.open()
	return codex


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_build()
	resized.connect(_on_resized)


func open() -> void:
	if entries.is_empty():
		entries = build_entries(false)
	_on_resized()
	refresh()
	show()
	_back.grab_focus.call_deferred()


func close() -> void:
	if _inspector != null and _inspector.is_open():
		_inspector.close()
	if _starter != null:
		_starter.queue_free()
		_starter = null
	hide()
	closed.emit()


func get_inspector() -> Control:
	return _inspector


func get_back_button() -> Button:
	return _back


func get_type_button(key: StringName) -> Button:
	return _type_buttons.get(key, null)


func get_class_button(key: StringName) -> Button:
	return _class_buttons.get(key, null)


func get_chassis_picker() -> OptionButton:
	return _chassis


## kc-ui4: gone (one tile per card; the arts are in the ART panel). Null.
func get_arts_button() -> Button:
	return _arts_button


func get_starter_button() -> Button:
	return _starter_button


## The ART panel (kc-ui4), its art tiles, EQUIP / USE VARIETY / INSPECT / BACK.
func get_art_panel() -> Control:
	return _art_panel


func is_art_panel_open() -> bool:
	return _art_panel != null and _art_panel.visible


func get_art_tiles() -> Array[Node]:
	return _art_grid.get_children()


## kc-trait-ui: the previewed art's "GIVES <TRAIT>" label (no EQUIP any more).
func get_gives_label() -> Label:
	return _gives_label


func get_art_inspect_button() -> Button:
	return _art_inspect


func get_art_back_button() -> Button:
	return _art_back


func get_glossary_button() -> Button:
	return _glossary_button


## kc-ui4: the glossary over the codex (scrolled to `focus` when given).
func open_glossary(focus: StringName = &"") -> Control:
	if _glossary != null and is_instance_valid(_glossary):
		_glossary.call(&"scroll_to", focus)
		return _glossary
	_glossary = (load("res://scripts/ui/codex/glossary.gd") as GDScript).call(&"open_over", self, focus)
	_glossary.closed.connect(func() -> void: _glossary = null)
	return _glossary


func get_glossary() -> Control:
	return _glossary if _glossary != null and is_instance_valid(_glossary) else null


## The starter-deck panel over the codex (null while closed).
func get_starter() -> Control:
	return _starter


## Tiles shown now (after the filters), in order.
func get_tiles() -> Array[Node]:
	return _grid.get_children()


# =============================================================================
# Entries and filters
# =============================================================================

## Every collectible card (one entry per chassis: kc-ui4 shows the alternate arts in the ART panel,
## listed in the entry's "arts") and every killstreak, sorted by type, then cost / threshold, then
## name. `arts` is ignored (kept for callers).
static func build_entries(_arts: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null(^"/root/CardDB") if tree != null else null
	if db == null:
		return out
	for card: CardData in db.all_cards():
		if not card.collectible:
			continue
		var kind: StringName = &"unit" if card.is_unit() else (&"field" if card.is_field() else &"tactic")
		var cls: StringName = StringName(String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_lower())
		var arts: Array[StringName] = arts_by_trait(card, BannerArtDB.alt_arts(card.id))
		out.append({"key": String(card.id), "id": card.id, "kind": kind, "cls": cls, "chassis": card.display_name,
				"card": card, "cost": card.cost, "name": card.display_name, "art": arts[0], "arts": arts,
				"alt": 1, "alts": arts.size()})
	for item: LoadoutItem in db.loadout_items_by_slot(DataEnums.LoadoutSlot.KILLSTREAK):
		out.append({"key": String(item.id), "id": item.id, "kind": &"killstreak", "cls": &"", "chassis": item.display_name,
				"item": item, "cost": item.streak_threshold, "name": item.display_name, "art": item.id,
				"arts": [item.id] as Array[StringName], "alt": 1, "alts": 1})
	var order: Dictionary = {&"unit": 0, &"tactic": 1, &"field": 2, &"killstreak": 3}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kind"] != b["kind"]:
			return int(order[a["kind"]]) < int(order[b["kind"]])
		if int(a["cost"]) != int(b["cost"]):
			return int(a["cost"]) < int(b["cost"])
		return String(a["chassis"]) < String(b["chassis"]))
	return out


## The art a card wears on its codex tile: its default art (kc-trait-ui: no EQUIP).
static func shown_art(e: Dictionary) -> StringName:
	return StringName(String(e["art"]))


## kc-trait-ui: True when `art` of entry `e` was found in a run (the default art always is).
static func is_found(e: Dictionary, art: StringName) -> bool:
	if e.get("kind", &"") == &"killstreak" or art == StringName(String(e.get("art", ""))):
		return true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null(^"/root/Settings") if tree != null else null
	return st != null and st.has_method(&"is_found") and st.is_found(art)


## kc-trait-ui: the arts of a card ordered by the trait option they give (default option first, plain
## arts last), keeping the pool order inside each group.
static func arts_by_trait(card: CardData, arts: Array[StringName]) -> Array[StringName]:
	if card == null or not card.has_trait_choice():
		return arts
	var order: Array[StringName] = card.trait_choices()
	var out: Array[StringName] = []
	for t: StringName in order:
		for a: StringName in arts:
			if ArtTraits.trait_of(a, card) == t:
				out.append(a)
	for a: StringName in arts:
		if not a in out:
			out.append(a)
	return out


## kc-trait-ui: "GIVES HEAVY" / "NO TRAIT" / "PRINTED: VANGUARD" for `art` on `card` ("" for tactics).
static func gives_text(card: CardData, art: StringName) -> String:
	if card == null or not card.is_unit():
		return ""
	var t: StringName = ArtTraits.trait_of(art, card)
	if not card.has_trait_choice():
		return ("PRINTED TRAIT: %s" % ArtTraits.trait_name(t).to_upper()) if t != &"" else ""
	return ("GIVES %s" % ArtTraits.trait_name(t).to_upper()) if t != &"" else "NO TRAIT"


## Settings.equipped_arts for a chassis (&"" = none: per-copy variety).
static func equipped_of(chassis: StringName) -> StringName:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var st: Node = tree.root.get_node_or_null(^"/root/Settings") if tree != null else null
	return st.equipped_art(chassis) if st != null else &""


## The entries the current filters let through.
func filtered() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for e: Dictionary in entries:
		if type_filter != &"all" and e["kind"] != type_filter:
			continue
		if class_filter != &"any" and e["cls"] != class_filter:
			continue
		if chassis_filter != &"" and e["id"] != chassis_filter:
			continue
		if not all_arts and seen.has(e["id"]):
			continue
		seen[e["id"]] = true
		out.append(e)
	return out


func set_type_filter(key: StringName) -> void:
	type_filter = key
	# Killstreaks have no weapon class: picking them clears the class filter.
	if key == &"killstreak" or key == &"tactic" or key == &"field":
		class_filter = &"any"
	refresh()


func set_class_filter(key: StringName) -> void:
	class_filter = key
	if key != &"any" and type_filter != &"unit" and type_filter != &"all":
		type_filter = &"unit"
	refresh()


func set_chassis_filter(id: StringName) -> void:
	chassis_filter = id
	refresh()


func set_all_arts(on: bool) -> void:
	all_arts = on
	refresh()


func clear_filters() -> void:
	type_filter = &"all"
	class_filter = &"any"
	chassis_filter = &""
	refresh()


func refresh() -> void:
	for k: StringName in _type_buttons:
		(_type_buttons[k] as Button).set_pressed_no_signal(k == type_filter)
	for k: StringName in _class_buttons:
		(_class_buttons[k] as Button).set_pressed_no_signal(k == class_filter)
	_fill_chassis()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var list: Array[Dictionary] = filtered()
	for e: Dictionary in list:
		_grid.add_child(_make_tile(e))
	var chassis_count: int = 0
	var seen: Dictionary = {}
	for e: Dictionary in list:
		if not seen.has(e["id"]):
			seen[e["id"]] = true
			chassis_count += 1
	_count.text = "CODEX · %d CARDS" % chassis_count
	_empty.visible = list.is_empty()
	_scroll.visible = not list.is_empty()
	_scroll.scroll_vertical = 0


func _fill_chassis() -> void:
	_chassis.clear()
	_chassis.add_item("ALL CHASSIS")
	_chassis.set_item_metadata(0, &"")
	var seen: Dictionary = {}
	for e: Dictionary in entries:
		if seen.has(e["id"]):
			continue
		if type_filter != &"all" and e["kind"] != type_filter:
			continue
		if class_filter != &"any" and e["cls"] != class_filter:
			continue
		seen[e["id"]] = true
		_chassis.add_item(String(e["chassis"]).to_upper())
		_chassis.set_item_metadata(_chassis.item_count - 1, e["id"])
	var sel: int = 0
	for i: int in _chassis.item_count:
		if _chassis.get_item_metadata(i) == chassis_filter:
			sel = i
	if sel == 0 and chassis_filter != &"":
		chassis_filter = &""
	_chassis.select(sel)


# =============================================================================
# Inspector
# =============================================================================

## The card inspector's info for an entry (the match's open_card_inspector, without a match).
static func inspector_info(e: Dictionary, art_override: StringName = &"") -> Dictionary:
	if e["kind"] == &"killstreak":
		var item: LoadoutItem = e["item"]
		return {"view": {"name": item.display_name, "type": "killstreak", "threshold": item.streak_threshold,
				"art_icon": String(KS_ICONS.get(item.id, "")), "id": String(item.id), "text": item.text, "side": "friend",
				"cost": item.supply_cost},
				"title": item.display_name, "type": "killstreak · earned at streak %d%s" % [item.streak_threshold,
						(" · cost %d" % item.supply_cost) if item.supply_cost > 0 else ""],
				"text": item.text, "keywords": [], "status": "Loadout killstreak: eliminations build your streak; at %d it is ready to call in." % item.streak_threshold,
				"side": 0}
	var card: CardData = e["card"]
	var type_text: String = String(CardInfo.TYPE_WORDS.get(card.card_type, "card"))
	if card.is_field():
		type_text = "field"
	# kc-ipad-cards: the weapon class is never shown.
	if card.is_unit():
		type_text += " · FP %d · Armor %d" % [card.firepower, card.armor]
	type_text += " · cost %d" % card.cost
	var keywords: Array[Dictionary] = CardInfo.keywords(card)
	var names: PackedStringArray = []
	for k: Dictionary in keywords:
		names.append(String(k["name"]).to_lower())
	var text: String = "" if card.text.to_lower().trim_suffix(".") == ", ".join(names) else card.text
	var art_id: StringName = art_override if art_override != &"" else shown_art(e)
	var banner: Dictionary = {"name": card.display_name, "fp": card.firepower, "armor": card.armor, "armor_max": card.armor,
			"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(),
			"keywords": CardInfo.icon_keywords(keywords)}
	MatchSnapshot._banner_fields(banner, card, null, null)
	banner["banner"] = String(art_id)
	var art: BannerArt = BannerArtDB.get_art(art_id)
	var view: Dictionary = CardInfo.view_dict(card, "friend")
	# kc-ui4 (head naming): the title is the card's name; the art's own name is its subname.
	var sub: String = BannerArtDB.subname(art_id)
	if BannerArtDB.is_card_art(art):
		view["licensed_art"] = String(art.id)
	elif not art.is_default:
		view["art_id"] = String(art.id)
	if sub != "":
		view["subname"] = sub
		banner["subname"] = sub
	var arts: Array = e.get("arts", [])
	var n: int = maxi(1, arts.find(art_id) + 1)
	var art_line: String = "Banner: %s · art %d of %d%s" % [sub if sub != "" else BannerArtDB.DEFAULT_SUBNAME, n, maxi(1, arts.size()),
			" · MW3 calling card (reference art, private pitch)" if art.licensed else ""]
	var gives: String = gives_text(card, art_id)
	if gives != "":
		art_line += " · " + gives.capitalize().replace("Gives ", "gives ")
	art_line += " · found in a run" if is_found(e, art_id) else " · not found yet"
	if card.is_field():
		text = (text + " " if text != "" else "") + "Overrun: at the end of each round, if the enemy controls this column, this Field is destroyed (hidden traps are exempt)."
	return {"view": view, "title": card.display_name,
			"type": ("%s · %s" % [sub, type_text]) if sub != "" else type_text,
			"text": text, "keywords": keywords, "status": "In the reward pool" if card.is_elite else "",
			"banner": banner, "side": 0, "art_line": art_line, "is_unit": card.is_unit()}


## Long-press / right-click / INSPECT: the card inspector (the art previewed in the ART panel).
func open_entry(e: Dictionary, art_override: StringName = &"") -> void:
	_inspector.open(inspector_info(e, art_override))


## Tap on a tile: the ART panel for units, tactics and Fields; killstreaks have one art, so the
## inspector.
func tap_entry(e: Dictionary) -> void:
	if e["kind"] == &"killstreak" or (e.get("arts", []) as Array).size() <= 1:
		open_entry(e)
	else:
		open_arts(e)


# =============================================================================
# Building
# =============================================================================

func _build() -> void:
	var scrim: Panel = Panel.new()
	scrim.theme_type_variation = &"Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.055, 0.065, 0.075, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	margin.add_child(col)
	# Top bar.
	_top = HBoxContainer.new()
	_top.add_theme_constant_override(&"separation", 8)
	col.add_child(_top)
	_back = _button("BACK", &"ReadyButton")
	_back.custom_minimum_size.x = 120
	_back.pressed.connect(close)
	_back.tooltip_text = "Close the codex"
	_top.add_child(_back)
	_count = Label.new()
	_count.theme_type_variation = &"HudHeader"
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.clip_text = true
	_top.add_child(_count)
	_chassis = OptionButton.new()
	_chassis.theme_type_variation = &"HudButton"
	_chassis.custom_minimum_size = Vector2(240, BAR_H)
	_chassis.add_to_group(&"tap_target")
	_chassis.fit_to_longest_item = false
	_chassis.clip_text = true
	_chassis.tooltip_text = "Show one chassis (all its arts)"
	_chassis.item_selected.connect(func(i: int) -> void: set_chassis_filter(StringName(_chassis.get_item_metadata(i))))
	# Phone-sized rows in the chassis list.
	var popup: PopupMenu = _chassis.get_popup()
	popup.add_theme_font_size_override(&"font_size", 22)
	popup.add_theme_constant_override(&"v_separation", 34)
	_top.add_child(_chassis)
	_starter_button = _button("STARTER", &"HudButton")
	_starter_button.name = "StarterButton"
	_starter_button.custom_minimum_size.x = 150
	_starter_button.tooltip_text = "The starter deck and your starting Operator"
	_starter_button.pressed.connect(open_starter)
	_top.add_child(_starter_button)
	_glossary_button = _button("GLOSSARY", &"HudButton")
	_glossary_button.name = "GlossaryButton"
	_glossary_button.custom_minimum_size.x = 150
	_glossary_button.tooltip_text = "Every keyword, synergy icon and stat mark in plain words"
	_glossary_button.pressed.connect(func() -> void: open_glossary())
	_top.add_child(_glossary_button)
	# Filter row (scrolls sideways on narrow screens).
	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.custom_minimum_size.y = BAR_H
	col.add_child(filter_scroll)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override(&"separation", 6)
	filter_scroll.add_child(_filters)
	for k: StringName in TYPE_FILTERS:
		var b: Button = _chip(String(TYPE_WORDS[k]))
		b.name = "Type_%s" % k
		b.pressed.connect(set_type_filter.bind(k))
		_type_buttons[k] = b
		_filters.add_child(b)
		# kc-deck-match: TACTICS and FIELDS carry their type icons (an empty icon keeps the room).
		var kind: StringName = k if k == &"tactic" or k == &"field" else &""
		if kind != &"":
			var blank := Image.create(20, 20, false, Image.FORMAT_RGBA8)
			b.icon = ImageTexture.create_from_image(blank)
			b.set_meta(&"type_icon", kind)
			b.draw.connect(func() -> void:
				var ir: Rect2 = Rect2(Vector2(10, (b.size.y - 20.0) * 0.5), Vector2(20, 20))
				CardLook.draw_type_icon(b, ir, kind, CardView.FRAME_T1.lightened(0.25) if kind == &"tactic" else CardView.FIELD_TINT))
	# kc-ipad-cards follow-up (the head: "leave out the gun type"): no weapon-class filter chips
	# (set_class_filter stays for callers; nothing on screen sets it).
	# Grid.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	_scroll.add_child(_grid)
	_empty = VBoxContainer.new()
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.visible = false
	col.add_child(_empty)
	var none: Label = Label.new()
	none.theme_type_variation = &"HudSubtle"
	none.text = "No card matches these filters."
	none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(none)
	var clear: Button = _button("CLEAR FILTERS", &"HudButton")
	clear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clear.custom_minimum_size.x = 240
	clear.pressed.connect(clear_filters)
	_empty.add_child(clear)
	_build_art_panel()
	# Inspector on top.
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspector.hide()


func _on_resized() -> void:
	var was: bool = compact
	compact = size.y > 0.0 and size.y < ScreenProfile.COMPACT_HEIGHT
	if was != compact and _grid.get_child_count() > 0:
		refresh.call_deferred()
	var tile: Vector2 = TILE_COMPACT if compact else TILE
	var room: float = size.x - 20.0 - 16.0  # margins + the scroll bar
	_grid.columns = maxi(1, int(floorf((room + 8.0) / (tile.x + 8.0))))
	_chassis.custom_minimum_size.x = 220.0 if compact else 280.0
	# kc-portrait: a narrow screen: the count label folds away and the bar's buttons shrink.
	var tall: bool = size.y > size.x
	_count.visible = not tall
	if tall:
		_chassis.custom_minimum_size.x = 130.0
		_back.custom_minimum_size.x = 90.0
		_starter_button.custom_minimum_size.x = 110.0
		_glossary_button.custom_minimum_size.x = 120.0
	else:
		_back.custom_minimum_size.x = 120.0
		_starter_button.custom_minimum_size.x = 150.0
		_glossary_button.custom_minimum_size.x = 150.0
	for t: Node in _grid.get_children():
		(t as Control).custom_minimum_size = tile
	_layout_art_panel()


func _button(text: String, variation: StringName) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, BAR_H)
	b.add_to_group(&"tap_target")
	b.focus_mode = Control.FOCUS_ALL
	return b


func _chip(text: String) -> Button:
	var b: Button = _button(text, &"HudButton")
	b.toggle_mode = true
	# 64 px wide at least: a 44 pt tap target on a phone even for "AR".
	b.custom_minimum_size.x = 64
	return b


func _make_tile(e: Dictionary) -> Control:
	var tile_size: Vector2 = TILE_COMPACT if compact else TILE
	var b: Button = Button.new()
	b.name = "Tile_%s" % String(e["key"])
	b.flat = true
	b.custom_minimum_size = tile_size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_to_group(&"tap_target")
	b.set_meta(&"entry", e)
	var arts: Array = e.get("arts", [])
	var found: int = 0
	for a: Variant in arts:
		found += 1 if is_found(e, StringName(String(a))) else 0
	b.set_meta(&"found", found)
	b.tooltip_text = "%s · tap: %s · long-press / right-click: rules" % [String(e["name"]),
			"its %d arts (%d found)" % [arts.size(), found] if arts.size() > 1 else "rules"]
	_wire_press(b, tap_entry.bind(e), open_entry.bind(e, &""))
	var cv: CardView = make_card_view(_card_view(e, shown_art(e)), tile_size.x)
	b.custom_minimum_size = CardView.size_for(tile_size.x)
	b.add_child(cv)
	return b


## kc-cards-impl: a Y2+ card at width w that ignores the mouse (the tile button takes the taps).
static func make_card_view(view: Dictionary, w: float) -> CardView:
	var cv: CardView = CARD_VIEW_SCENE.instantiate() as CardView
	cv.name = "Card"
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.set_card_data(view)
	cv.set_card_width(w)
	cv.ready.connect(func() -> void:
		for c: Node in cv.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE)
	return cv


## The Y2+ data of a codex entry wearing `art`.
static func _card_view(e: Dictionary, art: StringName) -> Dictionary:
	if e["kind"] == &"killstreak":
		var item: LoadoutItem = e["item"]
		return {"name": item.display_name, "type": "killstreak", "threshold": item.streak_threshold, "banner": String(item.id),
				"text": item.text}
	return CardView.view_for_card(e["card"], art)


## The BannerCard entry of a codex entry wearing `art`.
static func _card_entry(e: Dictionary, art: StringName) -> Dictionary:
	if e["kind"] == &"killstreak":
		var item: LoadoutItem = e["item"]
		return {"name": item.display_name, "cost": item.streak_threshold, "banner": String(item.id),
				"kind_word": "STREAK %d" % item.streak_threshold, "bolt": true}
	return BannerCard.entry_for_card(e["card"], art)


func _tag_label(text: String, bg: Color, fg: Color) -> Label:
	var tag: Label = Label.new()
	tag.text = text
	tag.theme_type_variation = &"HudTag"
	tag.add_theme_font_size_override(&"font_size", 16)
	tag.add_theme_color_override(&"font_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	tag.add_theme_stylebox_override(&"normal", sb)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag


## Tap = on_tap, long-press / right-click = on_inspect (PressGesture, mouse and touch alike).
func _wire_press(b: Control, on_tap: Callable, on_inspect: Callable) -> void:
	var g: RefCounted = PressGesture.new(b)
	g.drag_enabled = false
	b.set_meta(&"gesture", g)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if g.handle(ev):
			b.accept_event())
	g.tapped.connect(func(_p: Vector2) -> void: on_tap.call())
	g.long_pressed.connect(func(_p: Vector2) -> void: on_inspect.call())
	if b is Button:
		# Keyboard / controller: Enter = tap.
		(b as Button).pressed.connect(func() -> void:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not g.pressed:
				on_tap.call())


# =============================================================================
# kc-ui4: the ART panel (alternate arts, EQUIP)
# =============================================================================

func _build_art_panel() -> void:
	_art_panel = Control.new()
	_art_panel.name = "ArtPanel"
	_art_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_art_panel.visible = false
	add_child(_art_panel)
	_art_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.045, 0.055, 0.065, 0.99)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_panel.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	_art_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	margin.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	col.add_child(top)
	_art_back = _button("BACK", &"ReadyButton")
	_art_back.name = "ArtBack"
	_art_back.custom_minimum_size.x = 120
	_art_back.tooltip_text = "Back to every card"
	_art_back.pressed.connect(close_arts)
	top.add_child(_art_back)
	_art_title = Label.new()
	_art_title.theme_type_variation = &"HudHeader"
	_art_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_art_title.clip_text = true
	top.add_child(_art_title)
	_art_inspect = _button("RULES", &"HudButton")
	_art_inspect.name = "ArtInspect"
	_art_inspect.custom_minimum_size.x = 120
	_art_inspect.tooltip_text = "The card's rules, wearing this art"
	_art_inspect.pressed.connect(func() -> void: open_entry(art_entry, selected_art))
	top.add_child(_art_inspect)
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	col.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "Preview"
	left.add_theme_constant_override(&"separation", 6)
	body.add_child(left)
	_art_preview_holder = Control.new()
	_art_preview_holder.name = "PreviewHolder"
	_art_preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_art_preview_holder.tooltip_text = "Long-press / right-click: the rules"
	left.add_child(_art_preview_holder)
	_wire_press(_art_preview_holder, func() -> void: pass, func() -> void: open_entry(art_entry, selected_art))
	_art_info = Label.new()
	_art_info.theme_type_variation = &"UnitName"
	_art_info.add_theme_font_size_override(&"font_size", 18)
	_art_info.add_theme_color_override(&"font_color", BannerCard.SUB_COLOUR)
	_art_info.clip_text = true
	left.add_child(_art_info)
	_art_trait = Label.new()
	_art_trait.name = "ArtTrait"
	_art_trait.theme_type_variation = &"HudSubtle"
	_art_trait.add_theme_font_size_override(&"font_size", 16)
	_art_trait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_art_trait)
	# kc-trait-ui: what the previewed art gives (trait icon + words); no EQUIP (head: a viewer).
	_gives = HBoxContainer.new()
	_gives.name = "Gives"
	_gives.add_theme_constant_override(&"separation", 8)
	left.add_child(_gives)
	var gicon: Control = Control.new()
	gicon.name = "GivesIcon"
	gicon.custom_minimum_size = Vector2(30, 30)
	gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gicon.draw.connect(func() -> void:
		if _gives_trait != &"":
			SynergyGlyphs.draw_trait_plate(gicon, Rect2(Vector2.ZERO, gicon.size), _gives_trait, true, false)
		else:
			BannerView._dashed_rect(gicon, Rect2(Vector2.ZERO, gicon.size).grow(-1.0), Color(1, 1, 1, 0.45), 1.0))
	_gives.add_child(gicon)
	_gives_label = Label.new()
	_gives_label.name = "GivesLabel"
	_gives_label.theme_type_variation = &"UnitName"
	_gives_label.add_theme_font_size_override(&"font_size", 18)
	_gives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gives.add_child(_gives_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ArtScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_art_grid = GridContainer.new()
	_art_grid.name = "ArtGrid"
	_art_grid.add_theme_constant_override(&"h_separation", 8)
	_art_grid.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_art_grid)


## Opens the ART panel for a codex entry, previewing its equipped (else default) art.
func open_arts(e: Dictionary) -> void:
	art_entry = e
	art_ids.assign(e.get("arts", [e["art"]]))
	selected_art = shown_art(e) if shown_art(e) in art_ids else (art_ids[0] if not art_ids.is_empty() else &"")
	_art_panel.visible = true
	_fill_art_panel()
	_art_back.grab_focus.call_deferred()


func close_arts() -> void:
	_art_panel.visible = false
	art_entry = {}
	refresh()


## Previews `art` (one of the open card's arts).
func select_art(art: StringName) -> void:
	if art in art_ids:
		selected_art = art
		_fill_art_panel()


func _fill_art_panel() -> void:
	if art_entry.is_empty():
		return
	var card: CardData = art_entry.get("card") as CardData
	var found: int = 0
	for a: StringName in art_ids:
		found += 1 if is_found(art_entry, a) else 0
	_art_title.text = "%s · %d ARTS · %d FOUND" % [String(art_entry["name"]).to_upper(), art_ids.size(), found]
	for c: Node in _art_preview_holder.get_children():
		_art_preview_holder.remove_child(c)
		c.queue_free()
	var prev: PanelContainer = BannerCard.build(_card_entry(art_entry, selected_art), Vector2(10, 10),
			METRIC_H_COMPACT if compact else METRIC_H)
	prev.name = "PreviewCard"
	BannerCard.banner_of(prev).readability = false  # kc-hand-dim: the art panel shows the art at full strength
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_preview_holder.add_child(prev)
	prev.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The more-info view: the art's subname lives here (head: never on the card itself).
	var sub: String = BannerArtDB.subname(selected_art)
	var n: int = art_ids.find(selected_art) + 1
	_art_info.text = "%s · ART %d OF %d%s" % [(sub if sub != "" else BannerArtDB.DEFAULT_SUBNAME).to_upper(), n, art_ids.size(),
			"" if is_found(art_entry, selected_art) else " · NOT FOUND YET"]
	_gives_trait = BannerArtDB.art_trait(selected_art, card) if card != null and card.is_unit() else &""
	var gives: String = gives_text(card, selected_art)
	_gives_label.text = gives if gives != "" else "NO TRAIT"
	_gives.visible = card != null and card.is_unit()
	_gives.get_node("GivesIcon").queue_redraw()
	if card != null and card.has_trait_choice():
		var names: PackedStringArray = []
		for t: StringName in card.trait_choices():
			names.append("%s (%d)" % [ArtTraits.trait_name(t), ArtTraits.arts_with_trait(card, t).filter(func(x: StringName) -> bool: return x in art_ids).size()])
		_art_trait.text = "Can be: %s. The art decides the trait. In a run every copy comes with the art it was found with." % " · ".join(names)
	elif card != null and card.card_trait != &"":
		_art_trait.text = "Trait: printed (%s), whatever it wears. The art is its look." % ArtTraits.trait_name(card.card_trait)
	else:
		_art_trait.text = "Same card, same rules: the art is its look."
	for c: Node in _art_grid.get_children():
		_art_grid.remove_child(c)
		c.queue_free()
	for art: StringName in art_ids:
		_art_grid.add_child(_make_art_tile(art, false, art == selected_art))
	_layout_art_panel()


func _make_art_tile(art: StringName, _equipped: bool, selected: bool) -> Control:
	var tile_size: Vector2 = TILE_COMPACT if compact else TILE
	var card: CardData = art_entry.get("card") as CardData
	var b: Button = Button.new()
	b.name = "Art_%s" % String(art).replace("~", "_")
	b.flat = true
	b.custom_minimum_size = tile_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.set_meta(&"art", art)
	b.set_meta(&"equipped", false)
	var found: bool = is_found(art_entry, art)
	b.set_meta(&"found", found)
	var sub: String = BannerArtDB.subname(art)
	var gives: String = gives_text(card, art)
	b.tooltip_text = "%s%s · %s · tap: preview · long-press / right-click: rules" % [sub if sub != "" else BannerArtDB.DEFAULT_SUBNAME,
			(" · " + gives.capitalize()) if gives != "" else "", "found" if found else "not found yet"]
	_wire_press(b, select_art.bind(art), open_entry.bind(art_entry, art))
	var entry: Dictionary = _card_entry(art_entry, art)
	# The art's trait slot is the anatomy's bottom-left trait slot: the trait this art gives
	# (ArtTraits.trait_of), or an empty dashed slot (no trait).
	var tr: StringName = BannerArtDB.art_trait(art, card) if card != null and card.is_unit() else &""
	if tr != &"":
		entry["trait"] = String(tr)
	else:
		entry.erase("trait")
	entry["reserve_trait"] = card != null and card.is_unit()
	var view: Dictionary = _card_view(art_entry, art)
	if tr != &"":
		view["trait"] = String(tr)
	else:
		view.erase("trait")
	view["not_found"] = not found
	view["marked"] = selected
	var cv: CardView = make_card_view(view, tile_size.x)
	b.custom_minimum_size = CardView.size_for(tile_size.x)
	b.add_child(cv)
	var slot: Control = Control.new()
	slot.name = "TraitSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta(&"trait", tr)
	cv.add_child(slot)
	var tr_rect: Rect2 = cv.regions()["traits"]
	slot.position = tr_rect.position
	slot.size = tr_rect.size
	slot.draw.connect(func() -> void:
		if tr == &"" and bool(entry["reserve_trait"]):
			BannerView._dashed_rect(slot, Rect2(Vector2.ZERO, slot.size).grow(-1.0), Color(1, 1, 1, 0.35), 1.0))
	return b


func _layout_art_panel() -> void:
	if _art_panel == null or _art_preview_holder == null:
		return
	var w: float = maxf(300.0, roundf(size.x * (0.42 if compact else 0.4)))
	var h: float = roundf(minf(w / 2.4, size.y * 0.42))
	_art_preview_holder.custom_minimum_size = Vector2(w, h)
	(_art_preview_holder.get_parent() as Control).custom_minimum_size.x = w
	var tile: Vector2 = TILE_COMPACT if compact else TILE
	var room: float = size.x - 20.0 - 12.0 - w - 16.0
	_art_grid.columns = maxi(1, int(floorf((room + 8.0) / (tile.x + 8.0))))


# =============================================================================
# kc-ui4: STARTER (the starter deck and the Operator pick)
# =============================================================================

## Opens the starter panel over the codex (the Operator you pick is saved as the next run's default).
func open_starter() -> Control:
	if _starter != null:
		return _starter
	var script: GDScript = load("res://scripts/ui/run/starter_panel.gd") as GDScript
	_starter = script.new()
	_starter.name = "Starter"
	add_child(_starter)
	move_child(_starter, _inspector.get_index())
	_starter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_starter.call(&"setup", null, compact)
	_starter.connect(&"closed", func() -> void:
		if _starter != null:
			_starter.queue_free()
			_starter = null)
	return _starter


func _art_rect(tex: Texture2D) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if get_glossary() != null:
			return  # the glossary closes itself
		if _inspector.is_open():
			_inspector.close()
		elif _starter != null:
			_starter.call(&"close")
		elif is_art_panel_open():
			close_arts()
		else:
			close()
		get_viewport().set_input_as_handled()
