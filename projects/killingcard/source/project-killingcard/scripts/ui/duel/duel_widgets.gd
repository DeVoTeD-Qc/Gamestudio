# duel_widgets.gd
# Purpose: kc-duel-ui. Small builders the Duel screens share: the drawn marks (tick, cross, bang, lock,
#   plus: the fonts have no check-mark glyph, and a status is always shape + word, never colour alone),
#   status chips (READY / 2 PICKS TO GO), rule lines (red errors that block PLAY, amber advice, the
#   green READY line), trait plates, the cost hex, the mana-curve chart, a deck row, the hero strip and
#   a sheet (modal panel over the screen with a title row and a close button).
#   Everything inspectable is wired with run_screen.gd wire_inspect_* (long press on touch, right
#   click on desktop).
# Dependencies: run_screen.gd builders, card_look.gd, synergy_glyphs.gd, cost_hex.gd, duel_views.gd,
#   UiKit (lock icon, optional).
# Author: UI/UX Agent (kc-duel-ui)
extends RefCounted

const RunScreen: GDScript = preload("res://scripts/ui/run/run_screen.gd")
const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")

const RED: Color = Color("#FF6B6B")
const RED_BG: Color = Color("#3A1517")
const AMBER: Color = Color("#FFB020")
const AMBER_BG: Color = Color("#33270E")
const GREEN: Color = Color("#7CF29A")
const GREEN_BG: Color = Color("#13301E")
const FOG: Color = Color("#D8DEE3")
const PANEL_BG: Color = Color("#161B20")
const PANEL_RIM: Color = Color("#3A444D")
const INK: Color = Color("#12161A")
## Smallest tap target (px at the 540 px phone base = 46 pt).
const TAP: float = 64.0
const ROW_H: float = 56.0


# =============================================================================
# Marks
# =============================================================================

## A drawn mark: &"tick", &"cross", &"bang", &"lock", &"plus", &"minus".
class Mark extends Control:
	var kind: StringName = &"tick"
	var color: Color = Color.WHITE

	func _init(p_kind: StringName = &"tick", p_color: Color = Color.WHITE, px: float = 18.0) -> void:
		kind = p_kind
		color = p_color
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var o: Vector2 = (size - Vector2(s, s)) * 0.5
		var w: float = maxf(2.0, s * 0.16)
		match kind:
			&"tick":
				draw_polyline(PackedVector2Array([o + Vector2(s * 0.15, s * 0.55), o + Vector2(s * 0.42, s * 0.8), o + Vector2(s * 0.88, s * 0.22)]), color, w, true)
			&"cross":
				draw_line(o + Vector2(s * 0.2, s * 0.2), o + Vector2(s * 0.8, s * 0.8), color, w, true)
				draw_line(o + Vector2(s * 0.8, s * 0.2), o + Vector2(s * 0.2, s * 0.8), color, w, true)
			&"bang":
				var tri: PackedVector2Array = [o + Vector2(s * 0.5, s * 0.06), o + Vector2(s * 0.96, s * 0.92), o + Vector2(s * 0.04, s * 0.92)]
				draw_colored_polygon(tri, color)
				draw_line(o + Vector2(s * 0.5, s * 0.36), o + Vector2(s * 0.5, s * 0.64), INK, w, true)
				draw_circle(o + Vector2(s * 0.5, s * 0.78), w * 0.6, INK)
			&"lock":
				var tex: Texture2D = UiKit.piece(&"ico_ui_lock")
				if tex != null:
					draw_texture_rect(tex, Rect2(o, Vector2(s, s)), false, color)
					return
				draw_rect(Rect2(o + Vector2(s * 0.18, s * 0.45), Vector2(s * 0.64, s * 0.5)), color)
				draw_arc(o + Vector2(s * 0.5, s * 0.45), s * 0.22, PI, TAU, 12, color, w, true)
				draw_circle(o + Vector2(s * 0.5, s * 0.68), w * 0.55, INK)
			&"plus":
				draw_line(o + Vector2(s * 0.5, s * 0.15), o + Vector2(s * 0.5, s * 0.85), color, w, true)
				draw_line(o + Vector2(s * 0.15, s * 0.5), o + Vector2(s * 0.85, s * 0.5), color, w, true)
			&"minus":
				draw_line(o + Vector2(s * 0.15, s * 0.5), o + Vector2(s * 0.85, s * 0.5), color, w, true)


## A trait plate (the match's trait chip look). t = &"" draws a dashed "no trait" square.
class TraitPlate extends Control:
	var trait_id: StringName = &""

	func _init(t: StringName = &"", px: float = 26.0) -> void:
		trait_id = t
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_trait(t: StringName) -> void:
		trait_id = t
		queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var r: Rect2 = Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		if trait_id == &"":
			for i: int in 4:
				var a: Vector2 = r.position + [Vector2(0, 0), Vector2(s, 0), Vector2(s, s), Vector2(0, s)][i]
				var b: Vector2 = r.position + [Vector2(s, 0), Vector2(s, s), Vector2(0, s), Vector2(0, 0)][i]
				draw_dashed_line(a, b, Color(FOG, 0.5), 1.5, 4.0)
			return
		CardLook.draw_trait(self, r, trait_id, true)


## A cost hex with the number.
static func cost_hex(cost: int, px: float = 30.0) -> Control:
	var h: Control = CostHex.new()
	h.custom_minimum_size = Vector2(px, px)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.call(&"set_text", str(cost))
	return h


static func label(text: String, variation: StringName = &"", fs: int = 0, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l: Label = RunScreen.make_label(text, variation, wrap)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fs > 0:
		l.add_theme_font_size_override(&"font_size", fs)
	if color.a > 0.0:
		l.add_theme_color_override(&"font_color", color)
	return l


static func flat(bg: Color, rim: Color = Color(0, 0, 0, 0), border: int = 0, radius: int = 6, pad: float = 8.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rim
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func panel(bg: Color = PANEL_BG, rim: Color = PANEL_RIM, pad: float = 8.0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", flat(bg, rim, 1, 8, pad))
	return p


## READY (green, tick) / "2 PICKS TO GO" (amber, dash) / NEEDS ATTENTION (red, cross).
static func status_chip(text: String, ok: bool, bad: bool = false) -> PanelContainer:
	var c: Color = GREEN if ok else (RED if bad else AMBER)
	var p: PanelContainer = PanelContainer.new()
	p.name = "StatusChip"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override(&"panel", flat(GREEN_BG if ok else (RED_BG if bad else AMBER_BG), c, 2, 4, 3))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(Mark.new(&"tick" if ok else (&"cross" if bad else &"minus"), c, 16))
	var l: Label = label(text, &"HudTag", 16, c)
	l.name = "StatusText"
	row.add_child(l)
	return p


## One rule line: level &"error" (red, cross: blocks PLAY), &"warning" (amber, !), &"ok" (green tick).
## A Button so it can be tapped (filters the grid to the fix); the words carry the meaning.
static func rule_line(text: String, level: StringName) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.set_meta(&"level", level)
	b.custom_minimum_size = Vector2(0, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c: Color = RED if level == &"error" else (AMBER if level == &"warning" else GREEN)
	var bg: Color = RED_BG if level == &"error" else (AMBER_BG if level == &"warning" else GREEN_BG)
	var sb: StyleBoxFlat = flat(bg, Color(c, 0.6), 1, 4, 4)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb if st != "focus" else flat(Color(0, 0, 0, 0), Color.WHITE, 2, 4, 4))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.add_child(Mark.new(&"cross" if level == &"error" else (&"bang" if level == &"warning" else &"tick"), c, 18))
	var l: Label = label(text, &"", 16, c.lightened(0.2), true)
	l.name = "RuleText"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	b.tooltip_text = text
	# The button grows with its wrapped text.
	l.resized.connect(func() -> void: b.custom_minimum_size.y = maxf(40.0, l.get_combined_minimum_size().y + 10.0))
	return b


# =============================================================================
# The mana curve
# =============================================================================

## Copies per cost (1, 2, 3, 4, 5+) as bars with the count on top and a "Round 1: 1 Supply" marker
## over "1". Tap a bar: bar_tapped(i) (the builder filters the grid to that cost); long press / right
## click: bar_inspected(i). Each bar is its own hit area.
class CurveChart extends Control:
	signal bar_tapped(index: int)
	signal bar_inspected(index: int)
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var selected: int = -1
	var show_marker: bool = true
	var _hits: Array[Control] = []

	func _init(h: float = 96.0) -> void:
		custom_minimum_size = Vector2(200, h)
		mouse_filter = Control.MOUSE_FILTER_PASS
		for i: int in 5:
			var hit: Control = Control.new()
			hit.name = "Bar%d" % i
			hit.tooltip_text = "%s copies at cost %s" % ["0", DuelViews.CURVE_LABELS[i]]
			hit.focus_mode = Control.FOCUS_NONE
			add_child(hit)
			_hits.append(hit)
			RunScreen.wire_inspect_control(hit, func() -> void: bar_inspected.emit(i), false)
			var g: RefCounted = hit.get_meta(&"gesture")
			g.connect(&"tapped", func(_p: Vector2) -> void: bar_tapped.emit(i))
		resized.connect(_layout)

	func set_counts(c: Array[int]) -> void:
		counts = c
		for i: int in 5:
			_hits[i].tooltip_text = "%d copies at cost %s · tap: show these cards · hold: what the curve means" % [counts[i], DuelViews.CURVE_LABELS[i]]
		queue_redraw()

	func get_bar(i: int) -> Control:
		return _hits[i]

	func _layout() -> void:
		var w: float = size.x / 5.0
		for i: int in 5:
			_hits[i].position = Vector2(i * w, 0)
			_hits[i].size = Vector2(w, size.y)
		queue_redraw()

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var w: float = size.x / 5.0
		var label_h: float = 20.0
		var top: float = 20.0
		var bar_room: float = size.y - label_h - top
		var most: int = 6
		for n: int in counts:
			most = maxi(most, n)
		for i: int in 5:
			var x: float = i * w
			var h: float = bar_room * float(counts[i]) / float(most)
			var r: Rect2 = Rect2(x + w * 0.18, top + bar_room - h, w * 0.64, h)
			draw_rect(Rect2(x + w * 0.18, top, w * 0.64, bar_room), Color(1, 1, 1, 0.05))
			if h > 0.0:
				draw_rect(r, AMBER if i != selected else Color.WHITE)
			draw_string(font, Vector2(x, top + bar_room - h - 4.0), str(counts[i]), HORIZONTAL_ALIGNMENT_CENTER, w, 16, FOG)
			draw_string(font, Vector2(x, size.y - 3.0), DuelViews.CURVE_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(FOG, 0.8))
			if i == selected:
				draw_rect(Rect2(x + 2, 1, w - 4, size.y - 2), Color.WHITE, false, 2.0)
		if show_marker:
			# "Round 1: 1 Supply" over the first bar (a tick on the axis, the words above the chart).
			draw_line(Vector2(w * 0.1, top + bar_room + 1.0), Vector2(w * 0.9, top + bar_room + 1.0), GREEN, 3.0)
			draw_string(font, Vector2(2, 14), "R1: 1 SUPPLY", HORIZONTAL_ALIGNMENT_LEFT, w * 2.2, 13, Color(GREEN, 0.9))


## The curve's inspector text (duel-mode.md §6.3).
static func curve_info(counts: Array[int], i: int) -> Dictionary:
	return {"title": "Mana curve · cost %s" % DuelViews.CURVE_LABELS[i],
			"type": "%d copies in your deck" % counts[i],
			"text": "Round N gives N Supply (max 7). Cards that cost more than the round can't be played yet. Round 1 gives 1 Supply, so a couple of 1-cost picks make sure you have a play.",
			"keywords": [], "status": "Tap a bar to show only the cards at that cost."}


# =============================================================================
# Sheets
# =============================================================================

## A modal sheet over `parent`: dark scrim, a centred panel (full width on a phone), a title row
## with the title and a close button. Returns {root, body (VBox), title (Label), close (Button), panel}.
static func sheet(parent: Control, title: String, close_text: String = "CLOSE", max_w: float = 860.0) -> Dictionary:
	var root: Control = Control.new()
	root.name = "Sheet"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.05, 0.86)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: MarginContainer = MarginContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vr: Vector2 = parent.get_viewport_rect().size if parent.is_inside_tree() else Vector2(1280, 720)
	var side: float = maxf(12.0, (vr.x - max_w) * 0.5)
	for k: String in ["margin_left", "margin_right"]:
		center.add_theme_constant_override(k, int(side))
	for k: String in ["margin_top", "margin_bottom"]:
		center.add_theme_constant_override(k, 12)
	var p: PanelContainer = panel(Color("#12171C"), Color("#4A5560"), 12.0)
	center.add_child(p)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	p.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	col.add_child(head)
	var t: Label = RunScreen.make_label(title, &"TileName", true)
	t.name = "SheetTitle"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close: Button = RunScreen.make_button(close_text, &"HudButton", 120)
	close.name = "SheetClose"
	close.add_to_group(&"tap_target")
	head.add_child(close)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "SheetBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 8)
	scroll.add_child(body)
	close.pressed.connect(func() -> void: root.queue_free())
	close.grab_focus.call_deferred()
	return {"root": root, "body": body, "title": t, "close": close, "panel": p, "column": col, "head": head}


# =============================================================================
# Deck rows, hero strip
# =============================================================================

## One row of the deck list: cost hex · name · trait plate · "×2" · ✕ (remove). Empty pick = "— pick a
## card —". Returns the row (a PanelContainer) with metas: card (StringName). Callbacks: on_inspect
## (long press / right click on the row), on_remove (the ✕ button), on_trait (tap the trait plate;
## Callable() = not a choice).
static func deck_row(pick: Dictionary, on_inspect: Callable, on_remove: Callable, on_trait: Callable = Callable()) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(0, ROW_H)
	p.add_theme_stylebox_override(&"panel", flat(Color("#1B2228"), Color("#2C353D"), 1, 4, 4))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if pick.is_empty():
		p.name = "EmptyRow"
		var l: Label = label("— pick a card —", &"HudSubtle", 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return p
	var id: StringName = StringName(str(pick.get("card", "")))
	var c: CardData = DuelViews.card(id)
	p.name = "Row_%s" % id
	p.set_meta(&"card", id)
	row.add_child(cost_hex(c.cost if c != null else 0, 30))
	var nm: Label = label((c.display_name if c != null else String(id)) + (" ★" if c != null and c.is_elite else ""), &"UnitName", 16)
	nm.name = "RowName"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nm)
	if c != null and not DuelViews.is_owned(c):
		row.add_child(Mark.new(&"lock", RED, 18))
	if c != null and c.is_unit():
		var t: StringName = DuelViews.trait_of(pick)
		var tb: Button = Button.new()
		tb.name = "TraitButton"
		tb.flat = true
		tb.custom_minimum_size = Vector2(48, 48)
		tb.focus_mode = Control.FOCUS_ALL
		tb.add_to_group(&"tap_target")
		tb.tooltip_text = "%s · tap: choose the art (and so the trait)" % ArtTraits.trait_name(t)
		var plate: Control = TraitPlate.new(t, 28)
		plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tb.add_child(plate)
		plate.position = Vector2(10, 10)
		if on_trait.is_valid() and c.has_trait_choice():
			tb.pressed.connect(func() -> void: on_trait.call(id))
		else:
			tb.disabled = not on_trait.is_valid()
			tb.pressed.connect(func() -> void: on_inspect.call(id))
		RunScreen.wire_inspect_button(tb, func() -> void: on_inspect.call(id))
		row.add_child(tb)
	var x2: Label = label("×2", &"HudNumber", 18, AMBER)
	x2.name = "Copies"
	x2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(x2)
	if on_remove.is_valid():
		var rm: Button = Button.new()
		rm.name = "RemoveButton"
		rm.theme_type_variation = &"HudButton"
		rm.custom_minimum_size = Vector2(48, 48)
		rm.focus_mode = Control.FOCUS_ALL
		rm.add_to_group(&"tap_target")
		rm.tooltip_text = "Remove %s (both copies)" % (c.display_name if c != null else String(id))
		var m: Control = Mark.new(&"cross", RED, 20)
		rm.add_child(m)
		m.position = Vector2(14, 14)
		rm.pressed.connect(func() -> void: on_remove.call(id))
		row.add_child(rm)
	RunScreen.wire_inspect_control(p, func() -> void: on_inspect.call(id), true)
	p.tooltip_text = "%s ×2 · hold / right click: the full card" % (c.display_name if c != null else String(id))
	return p


## The hero strip: hero card art (BannerView via a small CardView), name, FP / Armor, passive in one
## line. A Button (tap = hero picker when on_tap is valid); hold / right click = the hero inspector.
static func hero_strip(h: Dictionary, on_tap: Callable, on_inspect: Callable, compact: bool = false) -> Button:
	var b: Button = Button.new()
	b.name = "HeroStrip"
	b.theme_type_variation = &"PickTile"
	b.focus_mode = Control.FOCUS_ALL
	b.add_to_group(&"tap_target")
	b.custom_minimum_size = Vector2(0, 64 if compact else 76)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	var tag: Label = label("HERO", &"HudTag", 16, AMBER)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	if h.is_empty():
		text.add_child(label("Pick a hero", &"UnitName", 18, RED))
	else:
		var nm: Label = label("%s · FP %d / Armor %d" % [h["name"], h["fp"], h["armor"]], &"UnitName", 18)
		nm.name = "HeroName"
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(nm)
		var ps: Label = label("%s · %s" % [h["passive_name"], h["ability_name"]], &"HudSubtle", 16)
		ps.name = "HeroKit"
		ps.clip_text = true
		ps.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(ps)
	if on_tap.is_valid():
		var arrow: Label = label("CHANGE", &"HudTag", 16, FOG)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(arrow)
		b.pressed.connect(func() -> void: on_tap.call())
	b.tooltip_text = "%s · tap: pick a hero · hold / right click: the full kit" % h.get("name", "Hero")
	RunScreen.wire_inspect_button(b, on_inspect)
	return b


## The hero's inspector info (the Operator, its passive and its once-per-match ability).
static func hero_info(h: Dictionary, status: String = "") -> Dictionary:
	if h.is_empty():
		return {}
	var item: LoadoutItem = h["item"]
	var kws: Array[Dictionary] = []
	kws.append({"name": "P · Passive · %s" % h["passive_name"], "text": String(h["passive_text"])})
	kws.append({"name": "Ability · %s (once per match, free)" % h["ability_name"], "text": String(h["ability_text"])})
	kws.append({"name": "Hero slot", "text": "Your hero is never drawn or shuffled. It waits in its own slot: place it from round 1 (free in round 1); after it goes down it comes back for 1 Supply."})
	var banner: Dictionary = {"name": item.display_name, "fp": item.operator_firepower, "armor": item.operator_armor,
			"armor_max": item.operator_armor, "operator": true, "camo": String(BannerArtDB.camo_for_tier(1)),
			"banner": String(BannerArtDB.operator_art_id(item.id, 1)), "keywords": [], "cls": "OPERATOR", "cost": ""}
	var st: String = status
	if st == "" and not bool(h.get("unlocked", true)):
		st = "LOCKED for your own decks: %s Presets and the AI can always use it." % h.get("unlock_text", "")
	return {"title": item.display_name, "type": "Hero · FP %d · Armor %d · %s" % [item.operator_firepower, item.operator_armor, h.get("plays_like", "")],
			"text": item.text, "keywords": kws, "banner": banner, "side": 0, "is_unit": true, "status": st}


## A card's inspector info in the builder (the codex's full card + "Adds 2 copies" + the lock line).
static func card_info(c: CardData, art: StringName = &"", status: String = "") -> Dictionary:
	var CodexView: GDScript = load("res://scripts/ui/codex/codex_view.gd")
	var e: Dictionary = {"key": String(c.id), "id": c.id, "kind": DuelViews.kind_of(c), "card": c, "cost": c.cost,
			"name": c.display_name, "art": c.id, "arts": CodexView.arts_by_trait(c, BannerArtDB.alt_arts(c.id))}
	var info: Dictionary = CodexView.inspector_info(e, art)
	var lines: PackedStringArray = []
	if status != "":
		lines.append(status)
	lines.append("A pick adds 2 copies to your deck.")
	if not DuelViews.is_owned(c):
		lines.append("LOCKED: %s. Presets can still use it." % DuelViews.unlock_line(c))
	if c.is_elite:
		lines.append("Elite ★: at most 1 Elite pick per deck.")
	if c.is_field():
		lines.append("Field: at most 3 Field picks per deck.")
	if c.is_unit() and c.has_trait_choice():
		var names: PackedStringArray = []
		for t: StringName in c.trait_choices():
			names.append(ArtTraits.trait_name(t))
		lines.append("Trait by art: %s (both copies wear the art you choose)." % " / ".join(names))
	info["status"] = "\n".join(lines)
	return info
