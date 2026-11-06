# banner_card.gd
# Purpose: kc-cards-impl: the X1 hand card (the head's H1 pick): the C1+ board banner at 4:1 with
#   everything shown (BannerView.full_info: cost hex -> level coin -> weapon top-left, abilities
#   top-right, traits bottom-left, FP reticle + Armor plate bottom-right) and a name plate under it in
#   the one title style (CardLook: Barlow Condensed Bold 16 px, UPPERCASE, #F2F5F7). Rules text, the
#   stat breakdown and the art credits are a tap (the docked Y2+ preview) or a long press (the
#   inspector) away. Cards off the board (mulligan, rewards, deck lists, Codex) are the Y2+ CardView.
#   entry_for_card() builds the banner entry of a deck card.
# Usage: var panel := BannerCard.build(entry, BoardMetrics.x1_size(177), 0.0)   # PanelContainer
#   entry: {name, cost? ("" hides the hex), fp?, armor?, armor_max?, cover?, fp_trend?, cls ("AR"...),
#   keywords [{id}], bolt?, front_kw?, elite?, trait?, trait_tier?, kw?, kw_active?, level?, locked?,
#   banner (art id), kind_word? ("TACTIC" / "FIELD" for cards without stats), operator?}
# Dependencies: BannerView, CardLook, BoardMetrics (X1_PLATE_H), hud_theme.tres (HandCard).
# Author: UI/UX Agent (kc-ui4; X1: kc-cards-impl)
class_name BannerCard
extends RefCounted

const SUB_COLOUR: Color = Color("#F3D36B")
const PLATE_COLOUR: Color = Color("#1E252B")
## kc-readability: hand card badge sizes (canvas px): the FP reticle / Armor plate, and the cost hex boost.
const STAT_PX: float = 32.0
const HAND_COST_SCALE: float = 1.5
## Ability icons on hand cards (the row above FP / Armor in the banner's right corner).
const HAND_ABILITY_PX: float = 14.0


## The X1 card panel (PanelContainer, theme variation HandCard): Face > Banner (BannerView, its art
## is the "Art" TextureRect, 4:1 at the top), NamePlate > NameLabel, SubLabel (hidden: kept for
## callers). metric_h is ignored (the banner's own height sets its icon sizes).
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
	# kc-readability (the head: hand cards "too hard to read"): a bigger cost hex, and FP / Armor drawn
	# big over the banner's bottom-right corner and the name plate (STAT_PX), on a dark backing.
	bv.cost_scale = HAND_COST_SCALE
	bv.draw_stats = false
	bv.ability_px = HAND_ABILITY_PX
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
	stats.visible = entry.has("fp")
	face.add_child(stats)
	stats.draw.connect(func() -> void:
		var e: Dictionary = bv.entry
		var r: Dictionary = stat_rects(stats.size)
		var fr: Rect2 = r["fp"]
		var ar: Rect2 = r["armor"]
		CardLook.draw_chip(stats, Rect2(fr.position - Vector2(2, 1), Vector2(ar.end.x - fr.position.x + 4.0, fr.size.y + 2.0)), 6.0)
		CardLook.draw_reticle(stats, fr, int(e.get("fp", 0)), bv.side, int(e.get("fp_trend", 0)))
		var armor: int = int(e.get("armor", 0))
		CardLook.draw_armor(stats, ar, armor, armor < int(e.get("armor_max", armor))))
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
		var bh: float = minf(roundf(face.size.x / 4.0), maxf(24.0, face.size.y - 18.0))
		bv.position = Vector2.ZERO
		bv.size = Vector2(face.size.x, bh)
		plate.position = Vector2(0, bh)
		plate.size = Vector2(face.size.x, face.size.y - bh)
		stats.position = Vector2.ZERO
		stats.size = face.size
		stats.queue_redraw()
		var name_w: float = plate.size.x - 12.0
		var sr: Dictionary = stat_rects(face.size, bh)
		var narrow: bool = bool(sr["narrow"])
		bv.show_abilities = not narrow
		bv.peek_extras = not narrow
		# Narrow plates (16:9 phones) wrap a long name onto a second line instead of cutting it.
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if narrow else TextServer.OVERRUN_TRIM_ELLIPSIS
		title.max_lines_visible = 2 if narrow else -1
		title.clip_text = not narrow
		# The cost hex: 27 px on the phone's 44 px banner, as big as a narrow banner allows.
		var want_cost: float = minf(27.0, bh - 4.0)
		bv.cost_scale = want_cost / (24.0 * bh / 57.0)
		title.add_theme_constant_override(&"line_spacing", -4 if narrow else 0)
		title.position = Vector2(6, 0)
		title.size = Vector2(maxf(8.0, name_w), plate.size.y)
	panel.sort_children.connect(place)
	bv.show_unit(entry, side, false)
	return panel


## kc-readability: the X1 card's FP reticle and Armor plate rects (face-local), bottom-right: inside the
## banner under the ability row when it is tall enough (the phone's 44 px banner: 26 px badges), else
## at the right of the name plate. bh = the banner's height.
static func stat_rects(face: Vector2, bh: float = -1.0) -> Dictionary:
	if bh < 0.0:
		bh = minf(roundf(face.x / 4.0), maxf(24.0, face.y - 18.0))
	# Narrow cards (a 26 px banner on a 16:9 phone): no ability row, the badges take the banner's height.
	var narrow: bool = bh - HAND_ABILITY_PX - 3.0 < 24.0
	var s: float = minf(STAT_PX, bh - 2.0) if narrow else minf(STAT_PX, bh - HAND_ABILITY_PX - 3.0)
	var bottom: float = bh - 1.0
	var ar: Rect2 = Rect2(face.x - 3.0 - s + 1.0, bottom - s, s - 1.0, s)
	var fr: Rect2 = Rect2(ar.position.x - 2.0 - s, bottom - s, s, s)
	return {"fp": fr, "armor": ar, "in_banner": true, "narrow": narrow}


## The BannerView inside a card built by build() (null for anything else).
static func banner_of(panel: Node) -> BannerView:
	return panel.get_node_or_null(^"Face/Banner") as BannerView if panel != null else null


## The board banner entry for a deck card (codex, starter list): printed stats, class, icon
## keywords, effect bolt / Protector / Elite, the trait and keyword (as a Trained copy), the art.
## kc-trait-ui: `chosen` = the copy's trait (TRAIT_DEFAULT: the trait the art gives, ArtTraits.trait_of,
## so an alternate art shows its own trait icon).
static func entry_for_card(card: CardData, art_id: StringName = &"", level: int = 1,
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
	var t: StringName = SynergyRules.trait_at(card, level, pick)
	if t != &"":
		e["trait"] = String(t)
	var kw: StringName = SynergyRules.keyword_at(card, level)
	if kw != &"":
		e["kw"] = String(kw)
	if level != SynergyRules.LEVEL_RECRUIT:
		e["band"] = String(SynergyRules.LEVEL_BANDS[clampi(level, 0, 3)])
	# kc-onboard-ui: Standard Issue frame / serial, a Recruit's locked keywords, the level badge.
	return StandardIssueLook.dress(e, card, level, art)


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
