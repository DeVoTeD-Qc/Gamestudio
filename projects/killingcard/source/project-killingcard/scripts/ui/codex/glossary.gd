# glossary.gd
# Purpose: kc-ui4 GLOSSARY (head: every keyword, synergy icon and stat mark, with its icon and a
#   plain description). A full-rect overlay opened from the Codex (GLOSSARY), the MENU sheet and the
#   card inspector's "?" on any keyword line (it opens scrolled to that entry). Grouped by category
#   (chips ALL / KEYWORDS / SYNERGY / STATS & BOARD) and searchable (a search box filters names and
#   texts). Each row: the icon as the game draws it, the name, the rules text.
#   Single source: card keywords from CardInfo.KEYWORD_RULES, traits
#   from SynergyRules (TRAIT_NAMES, TIER_TEXT; kc-ipad-cards: no copy levels any more) and the rest
#   from CardInfo.GLOSSARY_EXTRA, so a text never drifts from what the inspector says.
# Usage: var g := Glossary.open_over(parent, &"pick")   # adds itself full-rect, scrolled to Pick
# Dependencies: card_info.gd, SynergyRules, IconSheet, SynergyGlyphs, BannerView, hud_theme.tres.
# Author: UI/UX Agent (kc-ui4)
extends Control

signal closed

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const THEME: Theme = preload("res://assets/ui/hud_theme.tres")
const CATEGORIES: Array[StringName] = [&"all", &"keyword", &"synergy", &"stats"]
const CATEGORY_WORDS: Dictionary = {&"all": "ALL", &"keyword": "KEYWORDS", &"synergy": "SYNERGY", &"stats": "STATS & BOARD"}
const ROW_H: float = 64.0
const ICON: float = 44.0
## Drawn glyphs for entries without a sheet icon (id -> kind).
const DRAWN: Dictionary = {&"arrives_front": &"protector", &"immediate": &"bolt", &"hidden": &"hidden",
		&"no_control": &"no_control", &"field": &"field", &"tactic": &"tactic", &"control": &"control", &"objective": &"objective",
		&"operator": &"operator", &"killstreak": &"killstreak", &"incoming": &"incoming",
		&"set_callout": &"callout", &"doctrine": &"doctrine",
		&"stat_colours": &"trend", &"firepower": &"fp", &"armor": &"armor", &"cover_stat": &"cover_chip",
		&"supply": &"hex", &"pierce": &"pierce", &"card_peek": &"peek", &"damaged": &"damaged",
		&"trait_chip": &"trait_chip", &"rail_highlight": &"rail", &"card_frames": &"frames",
		&"agile": &"agile", &"beam": &"beam", &"end_of_round": &"end_of_round"}
## kc-cards-impl: the card-anatomy entries (C1+ board card, Y2+ / T1 frames) lead the STATS & BOARD group.
const STATS_KEYS: Array[StringName] = [&"card_peek", &"firepower", &"armor", &"damaged", &"cover_stat", &"stat_colours", &"supply", &"card_frames",
		&"objective", &"control", &"field", &"operator", &"killstreak", &"incoming"]
const SYNERGY_EXTRA: Array[StringName] = [&"trait_chip", &"rail_highlight", &"set_callout", &"doctrine"]

var category: StringName = &"all"
var query: String = ""
var compact: bool = false
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _search: LineEdit = null
var _back: Button = null
var _chips: Dictionary = {}
var _rows: Dictionary = {}   # key -> row Control


## Adds a glossary over `parent` (full rect), scrolled to `focus` (an entry key) when given.
static func open_over(parent: Control, focus: StringName = &"") -> Control:
	var g: Control = (load("res://scripts/ui/codex/glossary.gd") as GDScript).new()
	g.name = "Glossary"
	parent.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.closed.connect(g.queue_free)
	g.open(focus)
	return g


## Every entry: {key, category, name, text, icon (IconSheet name or &""), drawn (glyph kind or &""),
## trait?, kw?}. Order: card keywords, synergy (keywords, traits, the rest), stats.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in CardInfo.KEYWORD_RULES:
		var row: Array = CardInfo.KEYWORD_RULES[id]
		var nm: String = String(row[0]).replace(" %d", " N").replace("%d", "N")
		var tx: String = String(row[2]).replace("%d", "N")  # kc-text: the full rule lives here only
		out.append(_entry(id, &"keyword", nm, tx))
	# kc-deck-match: Tactic and Field side by side, each with its own type icon.
	out.append(_entry(&"tactic", &"keyword", CardInfo.GLOSSARY_EXTRA[&"tactic"][0], CardInfo.GLOSSARY_EXTRA[&"tactic"][1]))
	out.append(_entry(&"field", &"keyword", CardInfo.GLOSSARY_EXTRA[&"field"][0], CardInfo.GLOSSARY_EXTRA[&"field"][1]))
	# kc-pos-cut: no neighbour keywords (Guard / Spotter / Fireteam / Overwatch) any more.
	for tr: StringName in SynergyRules.TRAITS:
		var tiers: Array = SynergyRules.TIER_TEXT.get(tr, ["", ""])
		var e: Dictionary = _entry(StringName("trait_" + String(tr)), &"synergy", String(SynergyRules.TRAIT_NAMES.get(tr, tr)),
				"Trait set. %d in play: %s. %d in play: %s too." % [SynergyRules.TIER2, tiers[0], SynergyRules.TIER3, tiers[1]])
		e["trait"] = tr
		out.append(e)
	for k: StringName in SYNERGY_EXTRA:
		out.append(_entry(k, &"synergy", CardInfo.GLOSSARY_EXTRA[k][0], CardInfo.GLOSSARY_EXTRA[k][1]))
	for k: StringName in STATS_KEYS:
		if k == &"field":
			continue
		out.append(_entry(k, &"stats", CardInfo.GLOSSARY_EXTRA[k][0], CardInfo.GLOSSARY_EXTRA[k][1]))
	return out


static func _entry(key: StringName, cat: StringName, nm: String, tx: String) -> Dictionary:
	var icon: StringName = IconSheet.KEYWORD_ICONS.get(key, &"")
	if icon != &"" and not IconSheet.has_icon(icon):
		icon = &""
	return {"key": key, "category": cat, "name": nm, "text": tx, "icon": icon, "drawn": DRAWN.get(key, &"")}


## The glossary key of an inspector keyword line id (&"" when none).
static func key_for(id: StringName) -> StringName:
	for e: Dictionary in entries():
		if e["key"] == id or e["key"] == StringName("kw_" + String(id)) or e["key"] == StringName("trait_" + String(id)):
			return e["key"]
	return &""


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_build()


func open(focus: StringName = &"") -> void:
	compact = get_viewport_rect().size.y < 600.0
	refresh()
	show()
	if focus != &"":
		scroll_to.call_deferred(focus)
	_back.grab_focus.call_deferred()


func close() -> void:
	hide()
	closed.emit()


func get_back_button() -> Button:
	return _back


func get_search() -> LineEdit:
	return _search


func get_category_button(cat: StringName) -> Button:
	return _chips.get(cat, null)


## Rows shown now (after the category and the search), in order.
func get_rows() -> Array[Node]:
	return _list.get_children()


func get_row(key: StringName) -> Control:
	return _rows.get(key, null)


func set_category(cat: StringName) -> void:
	category = cat
	refresh()


func set_query(q: String) -> void:
	query = q.strip_edges().to_lower()
	if _search.text != q:
		_search.text = q
	refresh()


func filtered() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries():
		if category != &"all" and e["category"] != category:
			continue
		if query != "" and not (String(e["name"]).to_lower().contains(query) or String(e["text"]).to_lower().contains(query)):
			continue
		out.append(e)
	return out


## Scrolls to an entry (showing every category and clearing the search first if it is hidden) and
## flashes it.
func scroll_to(key: StringName) -> void:
	if not _rows.has(key):
		category = &"all"
		query = ""
		_search.text = ""
		refresh()
	var row: Control = _rows.get(key, null)
	if row == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(row.position.y)
	row.modulate = Color(1.4, 1.25, 0.8)
	var tw: Tween = row.create_tween()
	tw.tween_property(row, "modulate", Color.WHITE, 1.2)


func refresh() -> void:
	for k: StringName in _chips:
		(_chips[k] as Button).set_pressed_no_signal(k == category)
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var last_cat: StringName = &""
	for e: Dictionary in filtered():
		if e["category"] != last_cat and category == &"all":
			last_cat = e["category"]
			var h: Label = Label.new()
			h.theme_type_variation = &"HudAccent"
			h.text = String(CATEGORY_WORDS[last_cat])
			h.name = "Header_%s" % last_cat
			_list.add_child(h)
		var row: Control = _row(e)
		_rows[e["key"]] = row
		_list.add_child(row)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.045, 0.055, 0.065, 0.99)
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
	top.add_theme_constant_override(&"separation", 8)
	col.add_child(top)
	_back = _button("BACK", &"HudButton")  # kc-da-ui (#6): steel BACK
	_back.name = "GlossaryBack"
	_back.custom_minimum_size.x = 120
	_back.pressed.connect(close)
	top.add_child(_back)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudHeader"
	title.text = "GLOSSARY"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search: cover, spotter, overrun..."
	_search.custom_minimum_size = Vector2(0, ROW_H)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override(&"font_size", 20)
	_search.clear_button_enabled = true
	_search.add_to_group(&"tap_target")
	_search.text_changed.connect(set_query)
	top.add_child(_search)
	var fs: ScrollContainer = ScrollContainer.new()
	fs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fs.custom_minimum_size.y = ROW_H
	col.add_child(fs)
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override(&"separation", 6)
	fs.add_child(chips)
	for k: StringName in CATEGORIES:
		var b: Button = _button(String(CATEGORY_WORDS[k]), &"HudButton")
		b.name = "Cat_%s" % k
		b.toggle_mode = true
		b.custom_minimum_size.x = 96
		b.pressed.connect(set_category.bind(k))
		_chips[k] = b
		chips.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_list)


func _row(e: Dictionary) -> Control:
	var row: PanelContainer = PanelContainer.new()
	row.name = "Row_%s" % e["key"]
	row.theme_type_variation = &"HudPanelDark"
	row.custom_minimum_size.y = ROW_H
	row.set_meta(&"entry", e)
	# kc-text: no hover tooltip: the row already shows the whole entry.
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	row.add_child(h)
	var icon: Control = Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON * 1.0, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"has_icon", e["icon"] != &"" or e["drawn"] != &"" or e.has("trait") or e.has("kw"))
	icon.draw.connect(_draw_icon.bind(icon, e))
	h.add_child(icon)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 0)
	h.add_child(v)
	var n: Label = Label.new()
	n.theme_type_variation = &"KeywordName"
	n.text = String(e["name"])
	v.add_child(n)
	# kc-text: the concepts the text names show their icons inline (the row's own icon is at left).
	var t: RichTextLabel = RichTextLabel.new()
	t.name = "EntryText"
	IconText.setup(t)
	t.add_theme_font_size_override(&"normal_font_size", 18)
	t.add_theme_color_override(&"default_color", get_theme_color(&"font_color", &"Label"))
	IconText.fill(t, String(e["text"]), 18, Color("#E6EBEF"), false, [IconText.first_concept(String(e["name"]))])
	v.add_child(t)
	return row


func _draw_icon(c: Control, e: Dictionary) -> void:
	var s: float = ICON
	var r: Rect2 = Rect2(Vector2.ZERO, Vector2(s, s))
	var accent: Color = get_theme_color(&"accent", &"Hud")
	var friend: Color = get_theme_color(&"friend", &"Hud")
	var ink: Color = Color(0.05, 0.06, 0.07)
	if e.has("trait"):
		SynergyGlyphs.draw_trait_plate(c, r, e["trait"], true, false)
		return
	if e["icon"] != &"":
		c.draw_rect(r, Color(ink, 0.85))
		c.draw_texture_rect(IconSheet.get_icon(e["icon"]), r.grow(-6.0), false, accent)
		return
	var font: Font = get_theme_font(&"font", &"HudNumber")
	match StringName(e["drawn"]):
		&"fp":
			# kc-cards-impl: the FP reticle (yours teal, the rival's red).
			CardLook.draw_reticle(c, Rect2(1, 6, s * 0.62, s * 0.62), 3, &"player")
			CardLook.draw_reticle(c, Rect2(s * 0.5, s * 0.36, s * 0.5, s * 0.5), 2, &"enemy")
		&"armor":
			CardLook.draw_armor(c, Rect2(4, 2, s * 0.62, s * 0.66), 5, false)
		&"damaged":
			c.draw_rect(Rect2(0, 4, s, s * 0.6), Color("#2A3036"))
			CardLook.draw_crack(c, Vector2(3, 7), 20.0)
			CardLook.draw_damage_edge(c, Rect2(0, 4, s, s * 0.6), 2.0)
			CardLook.draw_armor(c, Rect2(s * 0.5, s * 0.36, s * 0.48, s * 0.56), 2, true)
		&"peek":
			CardLook.draw_cost(c, Rect2(s * 0.2, s * 0.2, s * 0.6, s * 0.6), "2")
		&"trait_chip":
			CardLook.draw_trait(c, Rect2(1, 12, 20, 20), &"vanguard", false)
			CardLook.draw_trait(c, Rect2(23, 12, 20, 20), &"vanguard", true)
		&"rail":
			c.draw_rect(Rect2(2, 4, s - 4, s - 8), Color(SynergyGlyphs.trait_color(&"heavy"), 0.22))
			c.draw_rect(Rect2(2, 4, s - 4, s - 8), Color.WHITE, false, 2.0)
			SynergyGlyphs.draw_trait_icon(c, Rect2(10, 10, s - 20, s - 20), &"heavy", SynergyGlyphs.trait_color(&"heavy"))
		&"frames":
			var unit: PackedVector2Array = CardView.outline(Rect2(1, 6, s * 0.44, s * 0.62), 0.0)
			c.draw_colored_polygon(unit, CardView.FRAME_UNIT)
			var t1: PackedVector2Array = CardView.outline(Rect2(s * 0.52, 6, s * 0.46, s * 0.62), 7.0)
			c.draw_colored_polygon(t1, CardView.FRAME_T1)
		&"cover_chip":
			c.draw_rect(r.grow(-6.0), Color(ink, 0.86))
			c.draw_rect(r.grow(-6.0), Color("#B9C2C9"), false, 1.5)
			c.draw_string(font, Vector2(0, s * 0.66), "1", HORIZONTAL_ALIGNMENT_CENTER, s, 20, Color("#B9C2C9"))
		&"trend":
			c.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.25, 4), Vector2(s * 0.45, s * 0.4), Vector2(s * 0.05, s * 0.4)]), SynergyGlyphs.UP)
			c.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.75, s - 4), Vector2(s * 0.95, s * 0.6), Vector2(s * 0.55, s * 0.6)]), SynergyGlyphs.DOWN)
		&"hex":
			var hx: PackedVector2Array = []
			for i: int in 6:
				hx.append(r.get_center() + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * s * 0.45)
			c.draw_colored_polygon(hx, accent)
			c.draw_string(font, Vector2(0, s * 0.66), "2", HORIZONTAL_ALIGNMENT_CENTER, s, 20, ink)
		&"bolt", &"killstreak":
			c.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.58, 4), Vector2(s * 0.26, s * 0.56), Vector2(s * 0.48, s * 0.56),
					Vector2(s * 0.38, s - 4), Vector2(s * 0.74, s * 0.42), Vector2(s * 0.52, s * 0.42)]), accent if e["drawn"] == &"bolt" else Color("#5BC0EB"))
		&"protector":
			c.draw_polyline(PackedVector2Array([Vector2(s * 0.2, s * 0.6), Vector2(s * 0.5, s * 0.28), Vector2(s * 0.8, s * 0.6)]), accent, 3.0)
			c.draw_line(Vector2(s * 0.2, s * 0.8), Vector2(s * 0.8, s * 0.8), accent, 3.0)
		&"hidden":
			c.draw_arc(r.get_center(), s * 0.3, PI * 1.1, PI * 1.9, 16, accent, 2.5)
			c.draw_arc(r.get_center(), s * 0.3, PI * 0.1, PI * 0.9, 16, accent, 2.5)
			c.draw_line(Vector2(6, s - 6), Vector2(s - 6, 6), accent, 2.5)
		&"no_control":
			c.draw_line(Vector2(s * 0.3, 6), Vector2(s * 0.3, s - 4), accent, 2.5)
			c.draw_colored_polygon(PackedVector2Array([Vector2(s * 0.3, 6), Vector2(s * 0.8, s * 0.2), Vector2(s * 0.3, s * 0.36)]), Color(accent, 0.6))
			c.draw_line(Vector2(6, 6), Vector2(s - 6, s - 6), get_theme_color(&"enemy", &"Hud"), 2.5)
		&"field", &"tactic":
			# kc-deck-match: the card type icons (ico_type_field / ico_type_tactic, else drawn).
			CardLook.draw_type_icon(c, r.grow(-4.0), StringName(e["drawn"]), CardView.FIELD_TINT if e["drawn"] == &"field" else CardView.FRAME_T1.lightened(0.25))
		&"control", &"objective":
			c.draw_rect(r.grow(-4.0), Color("#1C2228"))
			c.draw_rect(Rect2(4, 4, (s - 8) * 0.5, s - 8), Color(friend, 0.6))
			c.draw_rect(r.grow(-4.0), Color("#B9C2C9"), false, 1.5)
		&"operator":
			c.draw_rect(r.grow(-4.0), Color("#3A2D0B"))
			c.draw_rect(r.grow(-4.0), BannerView.BRASS, false, 3.0)
		&"incoming":
			c.draw_rect(r.grow(-4.0), Color("#2A1416"))
			c.draw_circle(r.get_center(), s * 0.14, get_theme_color(&"enemy", &"Hud"))
		&"callout":
			c.draw_rect(Rect2(2, s * 0.3, s - 4, s * 0.4), Color(friend, 0.25))
			c.draw_rect(Rect2(2, s * 0.3, s - 4, s * 0.4), friend, false, 1.5)
		&"doctrine":
			c.draw_arc(r.get_center(), s * 0.42, 0, TAU, 28, accent, 2.5)
			SynergyGlyphs.draw_trait_icon(c, r.grow(-10.0), SynergyRules.VANGUARD, accent)
		&"pierce":
			SynergyGlyphs.draw_pierce_plate(c, r, accent)  # kc-fight-ui
		&"agile":
			# kc-wip-impl: a sideways double arrow (a free move to the next column).
			c.draw_line(Vector2(6, s * 0.5), Vector2(s - 6, s * 0.5), accent, 3.0)
			c.draw_colored_polygon(PackedVector2Array([Vector2(4, s * 0.5), Vector2(14, s * 0.3), Vector2(14, s * 0.7)]), accent)
			c.draw_colored_polygon(PackedVector2Array([Vector2(s - 4, s * 0.5), Vector2(s - 14, s * 0.3), Vector2(s - 14, s * 0.7)]), accent)
		&"beam":
			# kc-wip-impl: a beam down the column through a friendly (teal) and an enemy (red) dot.
			c.draw_line(Vector2(s * 0.5, 4), Vector2(s * 0.5, s - 4), accent, 4.0)
			c.draw_circle(Vector2(s * 0.5, s * 0.3), s * 0.12, friend)
			c.draw_circle(Vector2(s * 0.5, s * 0.72), s * 0.12, get_theme_color(&"enemy", &"Hud"))
		&"end_of_round":
			# kc-wip-impl: a round arrow (each round's end).
			c.draw_arc(r.get_center(), s * 0.32, -PI * 0.35, PI * 1.35, 24, accent, 3.0)
			var tip: Vector2 = r.get_center() + Vector2.from_angle(-PI * 0.35) * s * 0.32
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -3), tip + Vector2(5, -5), tip + Vector2(1, 6)]), accent)
		_:
			# Any other keyword (a new one added to KEYWORD_RULES): its initial on a plate.
			c.draw_rect(r, Color(ink, 0.85))
			c.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)
			c.draw_string(font, Vector2(0, s * 0.68), String(e["name"]).left(1), HORIZONTAL_ALIGNMENT_CENTER, s, 24, accent)


func _button(text: String, variation: StringName) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.add_to_group(&"tap_target")
	b.focus_mode = Control.FOCUS_ALL
	return b


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
