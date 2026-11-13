# banner_card.gd
# Purpose: kc-cards-impl: the X1 hand card (the head's H1 pick): the calling-card banner with its
#   badges and a name plate under it in the one title style (CardLook: Barlow Condensed Bold 16 px,
#   UPPERCASE, #F2F5F7). Rules text, the stat breakdown and the art credits are a tap (the docked Y2+
#   preview) or a long press (the inspector) away. Cards off the board (mulligan, rewards, deck lists,
#   Codex) are the Y2+ CardView. entry_for_card() builds the banner entry of a deck card.
#   kc-ipad-cards (the head: "make sure ability icons and trait are big too along with the stats";
#   "the landscape hand keeps the small banner cards ... fill the tray by making the X1 banners
#   bigger and/or adding columns"): the card takes any size the tray gives it. The banner is the
#   card minus the name plate (cover-cropped when it is taller or shorter than 4:1), and every badge
#   (trait, abilities, FP, Armor) is one size S on its own dark plate. layout_for() picks:
#     ROW   (a tall enough banner): cost top-left; trait bottom-left, abilities bottom-centre,
#           FP + Armor bottom-right, all on the banner; the name plate under it.
#     SPLIT (a short banner, e.g. the phone's 2 x 4 grid): cost + trait top-left, abilities top-right;
#           FP + Armor bottom-right across the banner and the name plate; the name left of them.
#     NARROW (when the top row would push the abilities under 22 px): SPLIT without the abilities
#           (they stay in the docked card and the inspector).
#   No level coin, no weapon pill (kc-no-training, the head: "leave out the gun type").
# Usage: var panel := BannerCard.build(entry, Vector2(177, 98))   # PanelContainer; resize it freely
#   entry: {name, cost? ("" hides the hex), fp?, armor?, armor_max?, cover?, fp_trend?, cls ("AR"...:
#   only picks a fallback art), keywords [{id}], bolt?, front_kw?, elite?, trait?, trait_tier?, kw?,
#   kw_active?, banner (art id), kind_word? ("TACTIC" / "FIELD" for cards without stats), operator?,
#   cant_pay?}
# Dependencies: BannerView, CardLook, hud_theme.tres (HandCard).
# Author: UI/UX Agent (kc-ui4; X1: kc-cards-impl; layouts: kc-ipad-cards)
class_name BannerCard
extends RefCounted

const SUB_COLOUR: Color = Color("#F3D36B")
const PLATE_COLOUR: Color = Color("#1E252B")
## kc-readability: the hand card's FP reticle / Armor plate size before kc-ipad-cards (kept for callers).
const STAT_PX: float = 32.0
const HAND_COST_SCALE: float = 1.5
## Kept for callers (kc-ipad-cards: abilities are the badge size now).
const HAND_ABILITY_PX: float = 14.0
## kc-ipad-cards: the name plate's height, badge size limits and the cost hex's largest size.
const PLATE_H: float = 24.0
const ROW_MAX: float = 40.0
const SPLIT_MAX: float = 32.0
const COST_MAX: float = 27.0
const GAP: float = 3.0
## Smallest ability icon before a SPLIT card drops them (NARROW).
const ABILITY_MIN: float = 22.0
## Smallest badge for 13 pt digits on the smallest phone (0.694 pt / px): the reticle's digit is
## round(S * 0.7) px (CardLook.draw_reticle).
const READABLE_PX: float = 27.0
## The banner never gets taller than w / BANNER_MAX_RATIO or flatter than w / BANNER_MIN_RATIO (cover crop).
const BANNER_MAX_RATIO: float = 2.4
const BANNER_MIN_RATIO: float = 6.0
## Name size: 16 px (11.6 pt on the phone; never smaller), then an ellipsis (the dock and the inspector
## show the whole name).
const NAME_PX: int = 16
## kc-deck-match: the type icon in a Tactic / Field card's kind badge.
const KIND_ICON_PX: float = 18.0
const NAME_MIN_PX: int = 16


## The X1 card panel (PanelContainer, theme variation HandCard): Face > Banner (BannerView, its art
## is the "Art" TextureRect), NamePlate > NameLabel, Stats (the drawn badges), SubLabel (hidden: kept
## for callers). metric_h is ignored. The layout follows the panel's size (layout_for()).
static func build(entry: Dictionary, card_size: Vector2, _metric_h: float = 0.0, side: StringName = &"player") -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HandCard"
	panel.custom_minimum_size = card_size
	panel.set_meta(&"banner_card", true)
	var face: Control = Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	panel.add_child(face)
	var bv: BannerView = BannerView.new()
	bv.name = "Banner"
	bv.show_name = false
	bv.dim_back = false
	bv.full_info = true
	# kc-ipad-cards: the card draws its own cost, trait, abilities and stats (layout_for()).
	bv.draw_peek = false
	bv.draw_stats = false
	bv.show_abilities = false
	bv.show_trait = false
	face.add_child(bv)
	var plate: Panel = Panel.new()
	plate.name = "NamePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = PLATE_COLOUR
	plate.add_theme_stylebox_override(&"panel", psb)
	face.add_child(plate)
	var title: Label = CardLook.title_label(String(entry.get("name", "")))
	title.name = "NameLabel"
	plate.add_child(title)
	var stats: Control = Control.new()
	stats.name = "Stats"
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(stats)
	stats.draw.connect(func() -> void:
		var e: Dictionary = bv.entry
		var lay: Dictionary = layout_for(stats.size, e)
		draw_badges(stats, lay, e, bv.side, panel.get_theme_color(&"accent", &"Hud")))
	# kc-layout-a (the head's L2): the rule line under the name plate (mid face: 1 line, full face: 2
	# lines; compact: hidden, the rule is a long press away). IconText puts the keyword's icon in front.
	var rule_plate: Panel = Panel.new()
	rule_plate.name = "RulePlate"
	rule_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = PLATE_COLOUR.darkened(0.25)
	rule_plate.add_theme_stylebox_override(&"panel", rsb)
	rule_plate.visible = false
	face.add_child(rule_plate)
	var rule: RichTextLabel = RichTextLabel.new()
	rule.name = "RuleLine"
	IconText.setup(rule)
	rule.fit_content = false
	rule.clip_contents = true
	rule.add_theme_font_override(&"normal_font", CardLook.RULE_FONT)
	rule.add_theme_font_size_override(&"normal_font_size", RULE_PX)
	rule.add_theme_color_override(&"default_color", CardLook.RULE_COLOR)
	rule.add_theme_constant_override(&"line_separation", -2)
	var rule_text: String = String(entry.get("rule", ""))
	if rule_text == "":
		# A unit with no ability says so, dimmed (the lore is in the inspector).
		rule_text = "No ability" if entry.has("fp") else ""
		rule.add_theme_color_override(&"default_color", Color("#A3ADB5"))
	IconText.fill(rule, rule_text, RULE_PX, CardLook.RULE_COLOR if String(entry.get("rule", "")) != "" else Color("#A3ADB5"))
	rule_plate.add_child(rule)
	var sub: Label = Label.new()
	sub.name = "SubLabel"
	sub.visible = false
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(sub)
	var place: Callable = func() -> void:
		var sb: StyleBox = panel.get_theme_stylebox(&"panel")
		var inset: float = 2.0
		if sb is StyleBoxFlat:
			inset = float((sb as StyleBoxFlat).border_width_left)
		face.position = Vector2(inset, inset)
		face.size = panel.size - Vector2(inset, inset) * 2.0
		# kc-layout-a: the rule lines take the bottom of the face; the X1 card is the rest.
		var lines: int = int(panel.get_meta(&"rule_lines", 0)) if IconText.plain(rule) != "" else 0
		var rule_h: float = minf(lines * RULE_LINE_H, maxf(0.0, face.size.y - 40.0))
		if rule_h < RULE_LINE_H:
			rule_h = 0.0
		var core: Vector2 = Vector2(face.size.x, face.size.y - rule_h)
		rule_plate.visible = rule_h > 0.0
		rule_plate.position = Vector2(0, core.y)
		rule_plate.size = Vector2(face.size.x, rule_h)
		rule.position = Vector2(5, 1)
		rule.size = Vector2(maxf(8.0, face.size.x - 8.0), maxf(0.0, rule_h - 2.0))
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if rule_h >= 2.0 * RULE_LINE_H else TextServer.AUTOWRAP_OFF
		var lay: Dictionary = layout_for(core, bv.entry)
		var br: Rect2 = lay["banner"]
		bv.position = br.position
		bv.size = br.size
		plate.position = (lay["plate"] as Rect2).position
		plate.size = (lay["plate"] as Rect2).size
		stats.position = Vector2.ZERO
		stats.size = core
		stats.queue_redraw()
		var nr: Rect2 = lay["name"]
		title.position = nr.position - plate.position
		title.size = nr.size
		fit_name(title, nr.size.x)
	panel.sort_children.connect(place)
	bv.show_unit(entry, side, false)
	return panel


## kc-layout-a: a hand card's rule line height and font size (16 px on the canvas = 11.5 pt on the
## phone; never under 10 pt).
const RULE_LINE_H: float = 20.0
const RULE_PX: int = 17  # kc-r2-fixes: >= 12 pt on an 844x390 phone (0.72 pt per px)


## kc-layout-a (the head's L2): how many rule lines the card shows (0 compact, 1 mid, 2 full); the
## card re-lays itself out.
static func set_rule_lines(panel: Control, lines: int) -> void:
	if int(panel.get_meta(&"rule_lines", 0)) == lines:
		return
	panel.set_meta(&"rule_lines", lines)
	panel.queue_sort()


## The rule line's RichTextLabel (null when the card has none).
static func rule_of(panel: Node) -> RichTextLabel:
	return panel.get_node_or_null(^"Face/RulePlate/RuleLine") as RichTextLabel if panel != null else null


## The name label at 16 px, or smaller (down to 13 px) when the whole name then fits `width`.
static func fit_name(title: Label, width: float) -> void:
	var t: String = title.text
	var fs: int = NAME_PX
	while fs > NAME_MIN_PX and CardLook.TITLE_FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	title.add_theme_font_size_override(&"font_size", fs)


## kc-ipad-cards: where everything goes on an X1 face of size `face` (face-local rects):
## {mode: &"row" / &"split" / &"narrow", s (badge px), banner, plate, name, cost, trait (Rect2() =
## none), abilities [[kind, rect]], fp, armor, kind_word (statless cards), stats: bool}.
static func layout_for(face: Vector2, e: Dictionary) -> Dictionary:
	var w: float = face.x
	var stats: bool = e.has("fp")
	var has_t: bool = String(e.get("trait", "")) != "" or bool(e.get("operator", false))
	var kinds: Array = BannerView.ability_kinds(e)
	var n: int = kinds.size()
	var has_cost: bool = str(e.get("cost", "")) != "" and not bool(e.get("operator", false))
	# kc-deck-match: the kind badge is the type icon (Tactic / Field) + the word.
	var kind_w: float = 0.0 if stats else CardLook.TITLE_FONT.get_string_size(String(e.get("kind_word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0 + KIND_ICON_PX + 4.0
	var plate_h: float = minf(PLATE_H, maxf(16.0, face.y * 0.4))
	var banner: Rect2 = Rect2(0, 0, w, maxf(8.0, face.y - plate_h))
	var plate: Rect2 = Rect2(0, banner.end.y, w, face.y - banner.end.y)
	var stat_units: float = 2.0 if stats else 0.0
	# ROW: one row along the banner's bottom: trait, abilities, stats.
	var row_units: float = (1.0 if has_t else 0.0) + n + stat_units
	var row_fixed: float = 8.0 + (6.0 if has_t else 0.0) + ((n - 1) * GAP + 6.0 if n > 0 else 0.0) + (GAP if stats else kind_w)
	var s_row: float = floorf((w - row_fixed) / maxf(1.0, row_units))
	var cost_row: float = minf(COST_MAX, maxf(24.0, banner.size.y * 0.32))
	s_row = minf(minf(s_row, ROW_MAX), banner.size.y - (cost_row if has_cost else 0.0) - 6.0)
	# SPLIT: cost + trait + abilities on top, stats bottom-right across the name plate.
	var cost_split: float = 24.0 if has_cost else 0.0
	var top_fixed: float = 8.0 + (cost_split + 4.0 if has_cost else 0.0) + (6.0 if has_t else 0.0) + ((n - 1) * GAP + 6.0 if n > 0 else 0.0)
	var top_units: float = (1.0 if has_t else 0.0) + n
	var s_split: float = minf(SPLIT_MAX, floorf((face.y - 6.0) / 2.0))
	if stats:
		s_split = minf(s_split, floorf((w - 8.0 - GAP) / 2.0))
	var s_top: float = floorf((w - top_fixed) / maxf(1.0, top_units)) if top_units > 0.0 else s_split
	var narrow: bool = n > 0 and minf(s_split, s_top) < ABILITY_MIN
	if narrow:
		kinds = []
		n = 0
		top_units = 1.0 if has_t else 0.0
		top_fixed = 8.0 + (cost_split + 4.0 if has_cost else 0.0) + (6.0 if has_t else 0.0)
		s_top = floorf((w - top_fixed) / maxf(1.0, top_units)) if top_units > 0.0 else s_split
	s_split = minf(s_split, s_top)
	var out: Dictionary = {"banner": banner, "plate": plate, "stats": stats, "trait": Rect2(), "abilities": [],
			"fp": Rect2(), "armor": Rect2(), "kind_word": Rect2()}
	var use_row: bool = not narrow and s_row >= 28.0 and s_row >= s_split - 3.0
	if use_row:
		var s: float = s_row
		var bottom: float = banner.end.y - 3.0
		out["mode"] = &"row"
		out["s"] = s
		out["cost"] = Rect2(3, 3, cost_row, cost_row) if has_cost else Rect2()
		var x: float = 4.0
		if has_t:
			out["trait"] = Rect2(x, bottom - s, s, s)
			x += s + 6.0
		var right: float = w - 4.0
		if stats:
			var aw: float = roundf(s * 29.0 / 30.0)
			out["armor"] = Rect2(right - aw, bottom - s, aw, s)
			out["fp"] = Rect2(right - aw - GAP - s, bottom - s, s, s)
			right = (out["fp"] as Rect2).position.x - 6.0
		else:
			out["kind_word"] = Rect2(right - kind_w, bottom - s, kind_w, s)
			right -= kind_w + 6.0
		var total: float = n * s + maxf(0, n - 1) * GAP
		var x0: float = x + maxf(0.0, (right - x - total) * 0.5)
		var ab: Array = []
		for i: int in n:
			ab.append([kinds[i], Rect2(x0 + i * (s + GAP), bottom - s, s, s)])
		out["abilities"] = ab
		out["name"] = Rect2(6, plate.position.y, w - 12.0, plate.size.y)
		return out
	var s2: float = s_split
	out["mode"] = &"narrow" if narrow else &"split"
	out["s"] = s2
	var c: float = minf(cost_split, s2)
	out["cost"] = Rect2(3, 3, c, c) if has_cost else Rect2()
	var tx: float = 4.0 + (c + 4.0 if has_cost else 0.0)
	if has_t:
		out["trait"] = Rect2(tx, 2, s2, s2)
	var ab2: Array = []
	var kx: float = w - 4.0 - s2
	for i: int in n:
		ab2.push_front([kinds[n - 1 - i], Rect2(kx, 2, s2, s2)])
		kx -= s2 + GAP
	out["abilities"] = ab2
	var bottom2: float = face.y - 2.0
	var name_right: float = w - 6.0
	if stats:
		var aw2: float = roundf(s2 * 29.0 / 30.0)
		out["armor"] = Rect2(w - 4.0 - aw2, bottom2 - s2, aw2, s2)
		out["fp"] = Rect2((out["armor"] as Rect2).position.x - GAP - s2, bottom2 - s2, s2, s2)
		name_right = (out["fp"] as Rect2).position.x - 6.0
	else:
		out["kind_word"] = Rect2(w - 4.0 - kind_w, plate.position.y, kind_w, plate.size.y)
		name_right = (out["kind_word"] as Rect2).position.x - 4.0
	out["name"] = Rect2(6, plate.position.y, maxf(8.0, name_right - 6.0), plate.size.y)
	return out


## The badge size (px) an X1 card of this panel size gets for a typical calling card (a trait, two
## abilities, FP and Armor): what BoardMetrics.hand_fit() maximises.
static func badge_px(card: Vector2, e: Dictionary = {}) -> float:
	var probe: Dictionary = e if not e.is_empty() else {"fp": 1, "armor": 1, "cost": 1, "trait": "vanguard",
			"keywords": [{"id": &"first_shot"}, {"id": &"cover"}]}
	return float(layout_for(card - Vector2(4, 4), probe)["s"])


## kc-ipad-cards: how good an X1 card of this size is for BoardMetrics.hand_fit(): its badge size,
## minus a penalty when the abilities must leave the card (NARROW) or the name gets under 60 px.
static func fit_score(card: Vector2) -> float:
	var probe: Dictionary = {"fp": 1, "armor": 1, "cost": 1, "trait": "vanguard", "name": "ARMORED TROOPER",
			"keywords": [{"id": &"first_shot"}, {"id": &"cover"}]}
	var lay: Dictionary = layout_for(card - Vector2(4, 4), probe)
	var score: float = float(lay["s"])
	if lay["mode"] == &"narrow":
		score -= 8.0
	if (lay["name"] as Rect2).size.x < 60.0:
		score -= 6.0
	return score


## Draws the badges of a layout on ci: the cost hex, the trait chip, the abilities, FP / Armor (or the
## kind word), each group on its own dark plate (CardLook.draw_chip).
static func draw_badges(ci: CanvasItem, lay: Dictionary, e: Dictionary, side: StringName, accent: Color) -> void:
	var cr: Rect2 = lay["cost"]
	if cr.has_area():
		CardLook.draw_chip(ci, cr.grow(2.0), 5.0)
		CardLook.draw_cost(ci, cr, str(e.get("cost", "")), bool(e.get("cant_pay", false)))
	var tr: Rect2 = lay["trait"]
	if tr.has_area() and String(e.get("trait", "")) != "":
		CardLook.draw_chip(ci, tr.grow(2.0), 4.0)
		CardLook.draw_trait(ci, tr, StringName(String(e["trait"])), int(e.get("trait_tier", 0)) >= 2)
	var ab: Array = lay["abilities"]
	if not ab.is_empty():
		var grp: Rect2 = ab[0][1]
		for a: Array in ab:
			grp = grp.merge(a[1])
		CardLook.draw_chip(ci, grp.grow(2.0), 4.0)
		for a: Array in ab:
			CardLook.draw_ability(ci, a[1], a[0], accent, side != &"enemy", bool(e.get("kw_active", false)))
	if bool(lay["stats"]):
		var fr: Rect2 = lay["fp"]
		var ar: Rect2 = lay["armor"]
		CardLook.draw_chip(ci, Rect2(fr.position - Vector2(2, 2), Vector2(ar.end.x - fr.position.x + 4.0, fr.size.y + 4.0)), 6.0)
		CardLook.draw_reticle(ci, fr, int(e.get("fp", 0)), side, int(e.get("fp_trend", 0)))
		var armor: int = int(e.get("armor", 0))
		CardLook.draw_armor(ci, ar, armor, armor < int(e.get("armor_max", armor)))
	else:
		var kr: Rect2 = lay["kind_word"]
		var word: String = String(e.get("kind_word", ""))
		if kr.has_area() and word != "":
			CardLook.draw_chip(ci, kr, 4.0)
			var kind: StringName = CardLook.type_kind(word)
			var ir: Rect2 = Rect2(kr.position.x + 5.0, kr.get_center().y - KIND_ICON_PX * 0.5, KIND_ICON_PX, KIND_ICON_PX)
			CardLook.draw_type_icon(ci, ir, kind, CardView.FRAME_T1.lightened(0.25) if kind == &"tactic" else CardView.FIELD_TINT)
			var f: Font = CardLook.TITLE_FONT
			var tx: float = ir.end.x + 3.0
			var base: Vector2 = Vector2(tx, kr.get_center().y + (f.get_ascent(16) - f.get_descent(16)) * 0.5)
			ci.draw_string(f, base, word, HORIZONTAL_ALIGNMENT_CENTER, kr.end.x - tx - 4.0, 16, Color("#B9C2C9"))


## The X1 card's FP reticle and Armor plate rects (face-local) and its layout mode (tests).
## narrow: true when the abilities are left to the docked card (NARROW).
static func stat_rects(face: Vector2, _bh: float = -1.0, e: Dictionary = {}) -> Dictionary:
	var probe: Dictionary = e if not e.is_empty() else {"fp": 1, "armor": 1, "cost": 1, "trait": "vanguard", "keywords": [{"id": &"first_shot"}]}
	var lay: Dictionary = layout_for(face, probe)
	return {"fp": lay["fp"], "armor": lay["armor"], "in_banner": lay["mode"] == &"row", "narrow": lay["mode"] == &"narrow", "mode": lay["mode"]}


## The BannerView inside a card built by build() (null for anything else).
static func banner_of(panel: Node) -> BannerView:
	return panel.get_node_or_null(^"Face/Banner") as BannerView if panel != null else null


## The board banner entry for a deck card (codex, starter list): printed stats, class, icon
## keywords, effect bolt / Protector / Elite, the trait, the art.
## kc-trait-ui: `chosen` = the copy's trait (TRAIT_DEFAULT: the trait the art gives, ArtTraits.trait_of,
## so an alternate art shows its own trait icon). kc-ipad-cards: no copy level (kc-no-training).
static func entry_for_card(card: CardData, art_id: StringName = &"",
		chosen: StringName = SynergyRules.TRAIT_DEFAULT) -> Dictionary:
	var CardInfo: GDScript = load("res://scripts/ui/card_info.gd")
	var keywords: Array[Dictionary] = CardInfo.keywords(card)
	var e: Dictionary = {"name": card.display_name, "cost": card.cost,
			"cls": String(CardInfo.CLASS_WORDS.get(card.weapon_class, "")).to_upper(),
			"keywords": CardInfo.icon_keywords(keywords), "elite": card.is_elite,
			"bolt": not card.effects.is_empty(), "front_kw": card.arrives_front}
	if card.is_unit():
		e["fp"] = card.firepower
		e["armor"] = card.armor
		e["armor_max"] = card.armor
	else:
		e["kind_word"] = "FIELD" if card.is_field() else "TACTIC"
	var art: StringName = art_id if art_id != &"" else card.id
	e["banner"] = String(art)
	var sub: String = BannerArtDB.subname(art)
	if sub != "":
		e["subname"] = sub
	var pick: StringName = chosen
	if pick == SynergyRules.TRAIT_DEFAULT and art_id != &"" and card.has_trait_choice():
		pick = ArtTraits.trait_of(art_id, card)
	var t: StringName = SynergyRules.trait_at(card, pick)
	if t != &"":
		e["trait"] = String(t)
	var kw: StringName = SynergyRules.keyword_at(card)
	if kw != &"":
		e["kw"] = String(kw)
	# kc-onboard-ui: the Standard Issue frame / serial.
	return StandardIssueLook.dress(e, card, art)


static func _label(text: String, variation: StringName, font_size: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_constant_override(&"outline_size", 4)
	l.add_theme_color_override(&"font_outline_color", Color(0.05, 0.06, 0.07, 1.0))
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l
