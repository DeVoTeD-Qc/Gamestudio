# banner_card.gd
# Purpose: kc-ui4 (head: "the cards in hand and on the codex should be closer to their form on the
#   board"). One card face for the hand tray, the Codex grid and the starter-deck list: the board's
#   banner (BannerView: the same art band, spine, plate row, FP bottom-left / Armor bottom-right with
#   the resulting-stat colours, keyword / trait icons, level band), plus what a card off the board
#   needs: the cost hex in the top-left corner (the plate row starts after it), and the card name
#   (always the chassis) over the art's subname in the free space between the stat badges.
#   The banner keeps the board's icon sizes (metric_h = the board's banner height) whatever the
#   card's own height. Rules text, the stat breakdown and the art credits are one long-press /
#   right-click / hover away (the callers wire the inspector).
# Usage: var panel := BannerCard.build(entry, Vector2(177, 88), 57.0)   # PanelContainer, HandCard style
#   entry: {name, subname?, cost? ("" hides the hex), fp?, armor?, armor_max?, cover?, fp_trend?,
#   cls ("AR"...), keywords [{id}], bolt?, front_kw?, elite?, trait?, kw?, kw_active?, band?,
#   banner (art id), kind_word? ("TACTIC" / "FIELD" for cards without stats), operator?, camo?}
# Dependencies: BannerView, cost_hex.gd, hud_theme.tres (HandCard, UnitName, HudTag).
# Author: UI/UX Agent (kc-ui4)
class_name BannerCard
extends RefCounted

const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")
const SUB_COLOUR: Color = Color("#F3D36B")


## The card panel (PanelContainer, theme variation HandCard): Face > Banner (BannerView, its art is
## the "Art" TextureRect), CostHex, NameLabel, SubLabel. Positions follow the panel's size.
static func build(entry: Dictionary, card_size: Vector2, metric_h: float, side: StringName = &"player") -> PanelContainer:
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
	bv.metric_h = metric_h
	face.add_child(bv)
	var m: Dictionary = BannerView.metrics(minf(card_size.y, metric_h))
	var has_cost: bool = entry.has("cost") and str(entry.get("cost", "")) != ""
	var hex: Control = CostHex.new()
	hex.name = "CostHex"
	var hs: Vector2 = Vector2(roundf(m["plate"] * 1.15), roundf(m["plate"] * 1.3))
	# A short card (desktop tray, 64 px): the hex shrinks to the plate row so it clears the FP badge.
	var room_h: float = card_size.y - 4.0 - m["badge"] - 2.0 * m["pad"] - 1.0
	if hs.y > room_h:
		hs = Vector2(roundf(maxf(20.0, room_h) * 0.9), roundf(maxf(20.0, room_h)))
	hex.custom_minimum_size = hs
	hex.size = hs
	hex.label.add_theme_font_size_override(&"font_size", maxi(16, int(roundf(hs.y * 0.62))))
	hex.set_text(str(entry.get("cost", "")))
	hex.label.set_meta(&"important", true)
	hex.visible = has_cost
	hex.tooltip_text = "Cost"
	face.add_child(hex)
	bv.lead = hs.x + 2.0 if has_cost else 0.0
	var fs: Vector2i = BannerView.name_sizes(metric_h)
	var title: Label = _label(String(entry.get("name", "")).replace("★", "").strip_edges(), &"UnitName", fs.x)
	title.name = "NameLabel"
	face.add_child(title)
	var sub_text: String = String(entry.get("subname", ""))
	var is_art_name: bool = sub_text != ""
	if sub_text == "" and not entry.has("fp"):
		sub_text = String(entry.get("kind_word", ""))
	var sub: Label = _label(sub_text.to_upper(), &"HudTag", fs.y)
	sub.name = "SubLabel"
	sub.add_theme_color_override(&"font_color", SUB_COLOUR if is_art_name else Color("#B9C2C9"))
	sub.visible = sub_text != ""
	face.add_child(sub)
	var stats: bool = entry.has("fp")
	var place: Callable = func() -> void:
		var sb: StyleBox = panel.get_theme_stylebox(&"panel")
		var inset: float = 2.0
		if sb is StyleBoxFlat:
			inset = float((sb as StyleBoxFlat).border_width_left)
		face.position = Vector2(inset, inset)
		face.size = panel.size - Vector2(inset, inset) * 2.0
		bv.position = Vector2.ZERO
		bv.size = face.size
		var mm: Dictionary = BannerView.metrics(minf(face.size.y, metric_h))
		var top_band: float = 4.0 if String(entry.get("band", "")) != "" and not bool(entry.get("operator", false)) else 0.0
		hex.position = Vector2(mm["spine"] + 1.0, mm["pad"] + top_band)
		var lay: Dictionary = BannerView.layout(face.size, mm, bool(entry.get("operator", false)), top_band, bv.lead)
		var x0: float = mm["spine"] + mm["pad"]
		var x1: float = face.size.x - mm["pad"]
		if stats:
			x0 = (lay["fp"] as Rect2).end.x + 3.0
			x1 = (lay["armor"] as Rect2).position.x - 3.0
			if int(entry.get("cover", 0)) > 0:
				x1 -= roundf(mm["badge"] * 0.78) + 3.0
		var w: float = maxf(8.0, x1 - x0)
		var th: float = title.get_combined_minimum_size().y
		var sh: float = sub.get_combined_minimum_size().y if sub.visible else 0.0
		var block: float = th + sh - (4.0 if sub.visible else 0.0)
		var row_h: float = mm["badge"]
		var bottom: float = face.size.y - mm["pad"]
		var top: float = bottom - maxf(block, row_h) + maxf(0.0, (row_h - block) * 0.5)
		# A narrow card (16:9 phone tray): no room between the badges, so the name takes the band
		# between the plate row and the stat row, full width.
		var mid_top: float = float(lay["plate_y"]) + mm["plate"]
		var mid_h: float = (lay["fp"] as Rect2).position.y - mid_top if stats else 0.0
		if stats and w < 72.0 and mid_h >= th - 6.0:
			x0 = mm["spine"] + mm["pad"]
			w = face.size.x - x0 - mm["pad"]
			top = mid_top + maxf(-4.0, (mid_h - block) * 0.5)
		if not stats and hex.visible and top < hex.position.y + hex.size.y:
			# No stat row (tactics, Fields): the name block starts right of the cost hex.
			var shift: float = hex.position.x + hex.size.x + 4.0 - x0
			x0 += shift
			w -= shift
		title.position = Vector2(x0, top)
		title.size = Vector2(w, th)
		sub.position = Vector2(x0, top + th - 4.0)
		sub.size = Vector2(w, sh)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if stats else HORIZONTAL_ALIGNMENT_LEFT
		sub.horizontal_alignment = title.horizontal_alignment
	panel.sort_children.connect(place)
	bv.show_unit(entry, side, false)
	return panel


## The BannerView inside a card built by build() (null for anything else).
static func banner_of(panel: Node) -> BannerView:
	return panel.get_node_or_null(^"Face/Banner") as BannerView if panel != null else null


## The board banner entry for a deck card (codex, starter list): printed stats, class, icon
## keywords, effect bolt / Protector / Elite, the trait and keyword (as a Trained copy), the art.
static func entry_for_card(card: CardData, art_id: StringName = &"", level: int = 1) -> Dictionary:
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
	var t: StringName = SynergyRules.trait_at(card, level)
	if t != &"":
		e["trait"] = String(t)
	var kw: StringName = SynergyRules.keyword_at(card, level)
	if kw != &"":
		e["kw"] = String(kw)
	if level != SynergyRules.LEVEL_RECRUIT:
		e["band"] = String(SynergyRules.LEVEL_BANDS[clampi(level, 0, 3)])
	return e


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
