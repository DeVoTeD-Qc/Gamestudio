# codex_view.gd
# Purpose: kc-ui3 CODEX (head: "We'll need a codex view"). A full-screen overlay that browses every
#   collectible card and every killstreak, opened from MENU (pause sheet) and from the Title screen.
#   Top bar: BACK, the title with the count shown, the chassis picker and (private pitch build only,
#   when licensed art is loaded) ARTS: ALL / ONE. Filter row: type chips (ALL / UNITS / TACTICS /
#   FIELDS / KILLSTREAKS) and weapon-class chips (ANY / AR / SMG / SHOTGUN / SNIPER / LMG). Below, a
#   scrolling grid of card tiles (art window, cost hex or streak threshold, name, type line). With
#   ARTS: ALL every licensed alternate art of a chassis is its own tile, named by its calling-card
#   title with the chassis under it. Tap (or long-press / right-click) a tile = the card inspector,
#   the same one the match uses. Every control is 64 px+ tall (44 pt on a phone).
#   Display only: reads CardDB and BannerArtDB, changes nothing.
# Usage: var codex := CodexView.open_over(parent_control)   # adds itself full-rect and opens
# Dependencies: CardDB, BannerArtDB, CardInfo, cost_hex.gd, scenes/match/CardInspector.tscn,
#   hud_theme.tres (HudPanelDark, HudButton, HandCard, UnitName, HudTag, HudHeader, HudSubtle, Scrim).
# Author: UI/UX Agent (kc-ui3)
extends Control

signal closed

const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")
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
const TILE: Vector2 = Vector2(144, 184)
const TILE_COMPACT: Vector2 = Vector2(120, 156)
const BAR_H: float = 64.0

var type_filter: StringName = &"all"
var class_filter: StringName = &"any"
## Chassis (card / killstreak id) filter, &"" = all.
var chassis_filter: StringName = &""
## Private pitch: show every licensed alternate art as its own tile.
var all_arts: bool = true
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
		entries = build_entries(BannerArtDB.has_licensed())
	_arts_button.visible = BannerArtDB.has_licensed()
	_on_resized()
	refresh()
	show()
	_back.grab_focus.call_deferred()


func close() -> void:
	if _inspector != null and _inspector.is_open():
		_inspector.close()
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


func get_arts_button() -> Button:
	return _arts_button


## Tiles shown now (after the filters), in order.
func get_tiles() -> Array[Node]:
	return _grid.get_children()


# =============================================================================
# Entries and filters
# =============================================================================

## Every collectible card (one entry per chassis, or one per licensed alternate art when `arts`)
## and every killstreak, sorted by type, then cost / threshold, then name.
static func build_entries(arts: bool) -> Array[Dictionary]:
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
		var base: Dictionary = {"id": card.id, "kind": kind, "cls": cls, "chassis": card.display_name, "card": card,
				"cost": card.cost, "name": card.display_name, "art": card.id, "alt": 0, "alts": 1}
		var pool: Array[StringName] = BannerArtDB.licensed_pool(card.id) if arts else ([] as Array[StringName])
		if pool.is_empty():
			base["key"] = String(card.id)
			out.append(base)
			continue
		for i: int in pool.size():
			var e: Dictionary = base.duplicate()
			e["art"] = pool[i]
			e["key"] = String(pool[i])
			e["alt"] = i + 1
			e["alts"] = pool.size()
			var title: String = BannerArtDB.art_title(pool[i])
			if title != "":
				e["name"] = title
			out.append(e)
	for item: LoadoutItem in db.loadout_items_by_slot(DataEnums.LoadoutSlot.KILLSTREAK):
		out.append({"key": String(item.id), "id": item.id, "kind": &"killstreak", "cls": &"", "chassis": item.display_name,
				"item": item, "cost": item.streak_threshold, "name": item.display_name, "art": item.id, "alt": 0, "alts": 1})
	var order: Dictionary = {&"unit": 0, &"tactic": 1, &"field": 2, &"killstreak": 3}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kind"] != b["kind"]:
			return int(order[a["kind"]]) < int(order[b["kind"]])
		if a["chassis"] != b["chassis"]:
			if int(a["cost"]) != int(b["cost"]):
				return int(a["cost"]) < int(b["cost"])
			return String(a["chassis"]) < String(b["chassis"])
		return int(a["alt"]) < int(b["alt"]))
	return out


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
	_arts_button.set_pressed_no_signal(all_arts)
	_arts_button.text = "ARTS: ALL" if all_arts else "ARTS: ONE"
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
	if all_arts and list.size() > chassis_count:
		_count.text = "CODEX · %d CARDS · %d ARTS" % [chassis_count, list.size()]
	else:
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
static func inspector_info(e: Dictionary) -> Dictionary:
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
	if card.is_unit() and CardInfo.CLASS_WORDS.get(card.weapon_class, "") != "":
		type_text += " · " + String(CardInfo.CLASS_WORDS[card.weapon_class])
	if card.is_unit():
		type_text += " · FP %d · Armor %d" % [card.firepower, card.armor]
	type_text += " · cost %d" % card.cost
	var keywords: Array[Dictionary] = CardInfo.keywords(card)
	var names: PackedStringArray = []
	for k: Dictionary in keywords:
		names.append(String(k["name"]).to_lower())
	var text: String = "" if card.text.to_lower().trim_suffix(".") == ", ".join(names) else card.text
	var art_id: StringName = StringName(String(e["art"]))
	var banner: Dictionary = {"name": card.display_name, "fp": card.firepower, "armor": card.armor, "armor_max": card.armor,
			"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(),
			"keywords": CardInfo.icon_keywords(keywords)}
	MatchSnapshot._banner_fields(banner, card, null, null)
	banner["banner"] = String(art_id)
	var art: BannerArt = BannerArtDB.get_art(art_id)
	var view: Dictionary = CardInfo.view_dict(card, "friend")
	var licensed: bool = BannerArtDB.is_card_art(art)
	if licensed:
		view["licensed_art"] = String(art.id)
		view["name"] = art.title
		banner["art_title"] = art.title
	var art_line: String = ""
	if art.licensed:
		art_line = "Banner: %s · art %d of %d · MW3 calling card (reference art, private pitch)" % [
				art.title if art.title != "" else String(art.id), int(e.get("alt", 1)), int(e.get("alts", 1))]
	if card.is_field():
		text = (text + " " if text != "" else "") + "Overrun: at the end of each round, if the enemy controls this column, this Field is destroyed (hidden traps are exempt)."
	return {"view": view, "title": art.title if licensed else card.display_name,
			"type": (card.display_name + " · " + type_text) if licensed else type_text,
			"text": text, "keywords": keywords, "status": "In the reward pool" if card.is_elite else "",
			"banner": banner, "side": 0, "art_line": art_line, "is_unit": card.is_unit()}


func open_entry(e: Dictionary) -> void:
	_inspector.open(inspector_info(e))


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
	_arts_button = _button("ARTS: ALL", &"HudButton")
	_arts_button.toggle_mode = true
	_arts_button.custom_minimum_size.x = 150
	_arts_button.tooltip_text = "Every alternate art of each card (calling cards, private pitch)"
	_arts_button.toggled.connect(set_all_arts)
	_top.add_child(_arts_button)
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
	var sep: VSeparator = VSeparator.new()
	sep.custom_minimum_size.x = 10
	_filters.add_child(sep)
	for k: StringName in CLASS_FILTERS:
		var b: Button = _chip("ANY CLASS" if k == &"any" else String(k).to_upper())
		b.name = "Class_%s" % k
		b.pressed.connect(set_class_filter.bind(k))
		_class_buttons[k] = b
		_filters.add_child(b)
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
	for t: Node in _grid.get_children():
		(t as Control).custom_minimum_size = tile


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
	b.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_to_group(&"tap_target")
	b.set_meta(&"entry", e)
	b.tooltip_text = "%s · %s" % [String(e["name"]), String(e["chassis"])]
	b.pressed.connect(open_entry.bind(e))
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HandCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var face: Control = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	panel.add_child(face)
	var art_h: float = roundf(tile_size.y * 0.56)
	var art_id: StringName = StringName(String(e["art"]))
	var kind: StringName = e["kind"]
	var tex: Texture2D = null
	var licensed: bool = false
	if kind == &"killstreak":
		tex = CardArt.card_texture(CardArt.card_key({"id": String(e["id"]), "type": "killstreak",
				"art_icon": String(KS_ICONS.get(e["id"], ""))}), 1.0)
	else:
		var art: BannerArt = BannerArtDB.get_art(art_id)
		licensed = art != null and art.licensed
		tex = BannerArtDB.banner_texture(art_id) if licensed else BannerArtDB.portrait_texture(art_id, {"type": String(kind)})
	if licensed:
		var back: TextureRect = _art_rect(tex)
		back.self_modulate = Color(0.42, 0.42, 0.45)
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.add_child(back)
		back.set_meta(&"rect", Rect2(0, 0, tile_size.x, art_h))
	var art_rect: TextureRect = _art_rect(tex)
	art_rect.name = "Art"
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if licensed else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.add_child(art_rect)
	var hex: Control = CostHex.new()
	hex.custom_minimum_size = Vector2(28, 32)
	hex.size = hex.custom_minimum_size
	hex.label.add_theme_font_size_override(&"font_size", 18)
	hex.set_text(("%d" % int(e["cost"])) if kind != &"killstreak" else "%d" % int(e["cost"]))
	hex.tooltip_text = "Cost" if kind != &"killstreak" else "Streak to earn it"
	face.add_child(hex)
	var title: Label = Label.new()
	title.theme_type_variation = &"UnitName"
	title.text = String(e["name"])
	title.add_theme_font_size_override(&"font_size", 16)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(title)
	var sub: Label = Label.new()
	sub.theme_type_variation = &"HudTag"
	sub.add_theme_font_size_override(&"font_size", 16)
	sub.text = _sub_line(e)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_color_override(&"font_color", Color(0.961, 0.722, 0.239) if kind == &"killstreak" else Color("#9AA5AE"))
	face.add_child(sub)
	panel.sort_children.connect(func() -> void:
		face.position = Vector2(2, 2)
		face.size = panel.size - Vector2(4, 4)
		var ah: float = art_h - 2.0
		for n: Node in face.get_children():
			if n is TextureRect:
				(n as TextureRect).position = Vector2.ZERO
				(n as TextureRect).size = Vector2(face.size.x, ah)
		hex.position = Vector2(2, 2)
		var lh: float = title.get_combined_minimum_size().y
		title.position = Vector2(5, ah + 4.0)
		title.size = Vector2(face.size.x - 10.0, lh)
		sub.position = Vector2(5, ah + 6.0 + lh)
		sub.size = Vector2(face.size.x - 10.0, sub.get_combined_minimum_size().y))
	return b


## The line under the name: the chassis for an alternate art, else type and class.
func _sub_line(e: Dictionary) -> String:
	if e["kind"] == &"killstreak":
		return "STREAK %d" % int(e["cost"])
	if String(e["name"]) != String(e["chassis"]):
		return String(e["chassis"]).to_upper()
	var word: String = {&"unit": "UNIT", &"tactic": "TACTIC", &"field": "FIELD"}.get(e["kind"], "")
	if e["cls"] != &"":
		word = String(e["cls"]).to_upper()
	return word


func _art_rect(tex: Texture2D) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _inspector.is_open():
			_inspector.close()
		else:
			close()
		get_viewport().set_input_as_handled()
