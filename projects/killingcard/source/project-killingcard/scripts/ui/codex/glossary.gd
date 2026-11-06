# glossary.gd
# Purpose: kc-ui4 GLOSSARY (head: every keyword, synergy icon and stat mark, with its icon and a
#   plain description). A full-rect overlay opened from the Codex (GLOSSARY), the MENU sheet and the
#   card inspector's "?" on any keyword line (it opens scrolled to that entry). Grouped by category
#   (chips ALL / KEYWORDS / SYNERGY / STATS & BOARD) and searchable (a search box filters names and
#   texts). Each row: the icon as the game draws it, the name, the rules text.
#   Single source: card keywords from CardInfo.KEYWORD_RULES, neighbor keywords / traits / levels
#   from SynergyRules (KEYWORD_TEXT, TRAIT_NAMES, TIER_TEXT, LEVEL_NAMES, level_stats) and the rest
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
		&"no_control": &"no_control", &"field": &"field", &"control": &"control", &"objective": &"objective",
		&"range": &"range", &"operator": &"operator", &"killstreak": &"killstreak", &"incoming": &"incoming",
		&"link_tick": &"tick", &"set_callout": &"callout", &"doctrine": &"doctrine", &"level_band": &"band",
		&"stat_colours": &"trend", &"firepower": &"fp", &"armor": &"armor", &"cover_stat": &"cover_chip",
		&"supply": &"hex", &"pierce": &"pierce"}
const STATS_KEYS: Array[StringName] = [&"firepower", &"armor", &"cover_stat", &"stat_colours", &"supply", &"range",
		&"objective", &"control", &"field", &"operator", &"killstreak", &"incoming"]
const SYNERGY_EXTRA: Array[StringName] = [&"link_tick", &"set_callout", &"doctrine", &"level_band"]

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
## trait?, kw?, band?}. Order: card keywords, synergy (keywords, traits, levels, the rest), stats.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in CardInfo.KEYWORD_RULES:
		var row: Array = CardInfo.KEYWORD_RULES[id]
		var nm: String = String(row[0]).replace(" %d", " N").replace("%d", "N")
		var tx: String = String(row[1]).replace("%d", "N")
		out.append(_entry(id, &"keyword", nm, tx))
	out.append(_entry(&"field", &"keyword", CardInfo.GLOSSARY_EXTRA[&"field"][0], CardInfo.GLOSSARY_EXTRA[&"field"][1]))
	for kw: StringName in SynergyRules.KEYWORDS:
		var t: String = String(SynergyRules.KEYWORD_TEXT.get(kw, ""))
		var e: Dictionary = _entry(StringName("kw_" + String(kw)), &"synergy", SynergyGlyphs.keyword_name(kw),
				t.substr(t.find(":") + 2) if t.contains(":") else t)
		e["kw"] = kw
		e["text"] += " (A Trained card's keyword; it counts once per card that receives it.)"
		out.append(e)
	for tr: StringName in SynergyRules.TRAITS:
		var tiers: Array = SynergyRules.TIER_TEXT.get(tr, ["", ""])
		var e: Dictionary = _entry(StringName("trait_" + String(tr)), &"synergy", String(SynergyRules.TRAIT_NAMES.get(tr, tr)),
				"Trait set. %d in play: %s. %d in play: %s too." % [SynergyRules.TIER2, tiers[0], SynergyRules.TIER3, tiers[1]])
		e["trait"] = tr
		out.append(e)
	for lvl: int in SynergyRules.LEVEL_NAMES.size():
		var st: Dictionary = SynergyRules.level_stats(lvl)
		var gains: PackedStringArray = []
		if lvl == SynergyRules.LEVEL_RECRUIT:
			gains.append("no neighbor keyword and no trait yet (plain band)")
		else:
			gains.append("its neighbor keyword and trait")
			if int(st["armor"]) > 0:
				gains.append("+%d Armor" % int(st["armor"]))
			if int(st["fp"]) > 0:
				gains.append("+%d FP" % int(st["fp"]))
		var e: Dictionary = _entry(StringName("level_" + String(SynergyRules.LEVEL_NAMES[lvl]).to_lower()), &"synergy",
				"%s copy" % SynergyRules.LEVEL_NAMES[lvl], "A %s copy has %s." % [SynergyRules.LEVEL_NAMES[lvl], ", ".join(gains)])
		e["band"] = SynergyRules.LEVEL_BANDS[lvl]
		e["drawn"] = &"band"
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
	_back = _button("BACK", &"ReadyButton")
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
	row.tooltip_text = "%s: %s" % [e["name"], e["text"]]
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	row.add_child(h)
	var icon: Control = Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON * (2.0 if e["key"] in [&"link_tick", &"kw_guard", &"kw_spotter", &"kw_fireteam", &"kw_overwatch"] else 1.0), ICON)
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
	var t: Label = Label.new()
	t.text = String(e["text"])
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override(&"font_size", 18)
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
	if e.has("kw"):
		SynergyGlyphs.draw_keyword_plate(c, r, e["kw"], true, friend, true)
		_draw_neighbors(c, Rect2(s + 4.0, 0, s - 4.0, s), e["kw"], friend)
		return
	if e["icon"] != &"":
		c.draw_rect(r, Color(ink, 0.85))
		c.draw_texture_rect(IconSheet.get_icon(e["icon"]), r.grow(-6.0), false, accent)
		return
	var font: Font = get_theme_font(&"font", &"HudNumber")
	match StringName(e["drawn"]):
		&"fp":
			c.draw_circle(r.get_center(), s * 0.45, Color("#14524D"))
			c.draw_arc(r.get_center(), s * 0.45, 0, TAU, 28, friend, 2.0)
			c.draw_string(font, Vector2(0, s * 0.68), "3", HORIZONTAL_ALIGNMENT_CENTER, s, 22, Color.WHITE)
		&"armor":
			var pts: PackedVector2Array = [Vector2(4, 4), Vector2(s - 4, 4), Vector2(s - 4, s * 0.55), Vector2(s * 0.5, s - 2), Vector2(4, s * 0.55), Vector2(4, 4)]
			c.draw_colored_polygon(pts, Color("#2E3439"))
			c.draw_polyline(pts, Color("#B9C2C9"), 2.0)
			c.draw_string(font, Vector2(0, s * 0.62), "5", HORIZONTAL_ALIGNMENT_CENTER, s, 22, Color.WHITE)
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
		&"band":
			SynergyGlyphs.draw_band(c, Rect2(2, s * 0.35, s - 4, s * 0.3), StringName(e.get("band", &"gilded")))
			if StringName(e.get("band", &"gilded")) == &"":
				c.draw_rect(Rect2(2, s * 0.35, s - 4, s * 0.3), Color("#7A828A"), false, 1.5)
		&"tick":
			c.draw_rect(Rect2(0, 6, s * 0.9, s * 0.35), Color("#1C2228"))
			c.draw_rect(Rect2(0, s * 0.6, s * 0.9, s * 0.35), Color("#1C2228"))
			SynergyGlyphs.draw_tick(c, Vector2(s * 0.45, s * 0.3), Vector2(s * 0.45, s * 0.7), friend, 4.0)
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
		&"field":
			c.draw_line(Vector2(s * 0.5, 4), Vector2(s * 0.5, s - 2), accent, 2.5)
			c.draw_line(Vector2(s * 0.2, s * 0.35), Vector2(s * 0.8, s * 0.35), accent, 2.5)
			c.draw_line(Vector2(s * 0.28, s * 0.6), Vector2(s * 0.72, s * 0.6), accent, 2.5)
		&"control", &"objective":
			c.draw_rect(r.grow(-4.0), Color("#1C2228"))
			c.draw_rect(Rect2(4, 4, (s - 8) * 0.5, s - 8), Color(friend, 0.6))
			c.draw_rect(r.grow(-4.0), Color("#B9C2C9"), false, 1.5)
		&"range":
			for i: int in 3:
				c.draw_arc(Vector2(4, s * 0.5), s * (0.3 + i * 0.3), -0.6, 0.6, 10, accent, 2.0)
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
		_:
			# Any other keyword (a new one added to KEYWORD_RULES): its initial on a plate.
			c.draw_rect(r, Color(ink, 0.85))
			c.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)
			c.draw_string(font, Vector2(0, s * 0.68), String(e["name"]).left(1), HORIZONTAL_ALIGNMENT_CENTER, s, 24, accent)


## The small neighbor diagram: which slots a neighbor keyword uses (a 3x3 mini board, this card
## in the middle; the cells it counts are lit).
func _draw_neighbors(c: Control, r: Rect2, kw: StringName, col: Color) -> void:
	var cell: float = floorf(r.size.y / 3.0) - 1.0
	var lit: Array[Vector2i] = []
	match kw:
		SynergyRules.GUARD:
			lit = [Vector2i(1, 2)]   # the card behind
		SynergyRules.SPOTTER:
			lit = [Vector2i(1, 0)]   # the card in front
		SynergyRules.FIRETEAM, SynergyRules.OVERWATCH:
			lit = [Vector2i(0, 1), Vector2i(2, 1)]   # beside
	for x: int in 3:
		for y: int in 3:
			var cr: Rect2 = Rect2(r.position + Vector2(x * (cell + 1.0), y * (cell + 1.0)), Vector2(cell, cell))
			var me: bool = x == 1 and y == 1
			c.draw_rect(cr, col if me else (Color(col, 0.55) if Vector2i(x, y) in lit else Color(1, 1, 1, 0.08)))


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
