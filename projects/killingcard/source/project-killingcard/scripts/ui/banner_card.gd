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
		title.position = Vector2(6, 0)
		title.size = Vector2(maxf(8.0, plate.size.x - 12.0), plate.size.y)
	panel.sort_children.connect(place)
	bv.show_unit(entry, side, false)
	return panel


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
