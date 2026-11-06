# card_view.gd
# Purpose: The full card face off the board (scenes/match/CardView.tscn). kc-cards-impl: the head's
#   Y2+ card (documentation/ux/card-design-options.html), used by the mulligan, the Supply Drop /
#   Salvage / Muster out picks, the deck views, the Codex, the hand's docked preview and the
#   inspector. Top to bottom:
#     title bar  cost hex + NAME (the one title style: Barlow Condensed Bold 16 px, UPPERCASE, #F2F5F7)
#     art        the calling card at 4:1 ((W - 8) / 4 tall), nothing over it
#     type line  OPERATOR / STANDARD ISSUE / TACTIC tag, the weapon by name, the level coin
#     text box   per keyword: its icon + bold name + a short rule; a Recruit's greyed "Trains: ...";
#                the effect text
#     stats bar  traits bottom-left (faint / lit), the FP reticle (team colour) + Armor plate
#                bottom-right
#   Tactics use the T1 "orders" frame: khaki paper, a chevron-cut top-right corner, no stats bar, the
#   text box takes its room. Fields / killstreaks: the steel frame without a stats bar.
#   The card lays out at its own width (set_card_width; height_for()); text sizes are fixed canvas px,
#   so a 172 px Codex card and a 250 px preview read the same. Callers that scale it still work.
#   Data keys (set_card_data): name, type (unit|tactic|equipment|killstreak|operator), weapon_class,
#   cost, firepower, armor, armor_max?, fp_trend?, keywords (ids or {id, value}), text, side
#   (friend|enemy), elite, threshold (killstreaks), id / banner / licensed_art / art_id (the 4:1 art),
#   level (-1 none), standard_issue, trait, trait_lit, locked (bool: the keywords are locked; or an
#   Array of locked keyword names), trains ("Trains: ..."), not_found (Codex), count (deck views:
#   "x5"), cant_pay (red cost hex), marked (amber frame: taken / selected).
#   kc-ui-hooks: the frame asks the UI kit first (frame_piece(): frm_y2_unit / frm_y2_operator /
#   frm_y2_standard_issue / frm_t1_orders, + tex_orders_paper on Tactics); the drawn frame is the fallback.
# Dependencies: CardLook, BannerArtDB, IconSheet, CardArt (fallback art), StandardIssueLook,
#   synergy_glyphs.gd, assets/ui/card_theme.tres, UiKit (optional kit frames).
# Author: Technical Artist Agent (p13); Y2+ rebuild: UI/UX Agent (kc-cards-impl)
class_name CardView
extends Control

signal card_changed

const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")
## The Y2+ card at 250 px (the inspector / dock size); height_for() gives other widths.
const BASE_SIZE: Vector2 = Vector2(250, 216)
const TITLE_H: float = 30.0
const TYPE_H: float = 22.0
const LINE_H: float = 19.0
const LINES: int = 3
const BAR_H: float = 32.0
## T1 orders frame: the chevron cut of the top-right corner.
const T1_CUT: float = 18.0
const COST_RECT: Rect2 = Rect2(5, 4, 24, 24)
## FP reticle and Armor plate at 250 px (bottom-right of the stats bar).
const FP_RECT: Rect2 = Rect2(185, 182, 28, 28)
const ARMOR_RECT: Rect2 = Rect2(217, 182, 27, 28)
const FRAME_UNIT: Color = Color("#4A5560")
const FACE_UNIT: Color = Color("#1B2126")
const FRAME_T1: Color = Color("#B8913A")
const FACE_T1: Color = Color("#2B2716")
const FRAME_OP: Color = Color("#C9A227")
const FACE_OP: Color = Color("#1E1A10")
const FRAME_STREAK: Color = Color("#5BC0EB")
## kc-ui-hooks: the T1 orders paper grain (UiKit piece, tiled).
const PAPER_PIECE: StringName = &"tex_orders_paper"
const AMBER: Color = Color("#FFB020")
const MUTED: Color = Color("#8C969E")

## Weapon class -> [close, mid, long] Firepower modifiers (core-rules.md §1).
const RANGE_MODS: Dictionary = {
	&"smg": [1, 0, 0], &"shotgun": [2, 0, -1], &"ar": [0, 1, 0], &"sniper": [-1, 0, 2], &"lmg": [0, 0, 0],
}
const RANGE_NAMES: PackedStringArray = ["CLOSE", "MID", "LONG"]
## The text box's keyword names and short rules (the inspector has the full ones, CardInfo.KEYWORD_RULES).
const KEYWORD_NAMES: Dictionary = {
	&"first_shot": "First Shot", &"pick": "Pick", &"flank": "Flank", &"suppress": "Suppress", &"pierce": "Pierce",
	&"patch": "Patch %d", &"cover": "Cover %d", &"holder": "Holder", &"on_deploy": "On Deploy", &"on_down": "On Down",
}
const SHORT_RULES: Dictionary = {
	&"first_shot": "fires first in its exchange", &"pick": "shoots the lowest-Armor enemy",
	&"flank": "shoots the back-most enemy", &"suppress": "their point man gets -2 FP",
	&"pierce": "extra damage carries on", &"patch": "restores %d Armor to a friend here",
	&"cover": "each hit deals %d less", &"holder": "holds a contested zone",
	&"on_deploy": "happens when it arrives", &"on_down": "happens when it goes down",
}

## Placeholder shown in the editor and when no data is set.
const PLACEHOLDER: Dictionary = {
	"name": "Breacher", "type": "unit", "weapon_class": "shotgun", "cost": 3, "firepower": 3,
	"armor": 4, "keywords": [{"id": "first_shot"}], "text": "", "side": "friend",
}

## "friend" or "enemy". Drives the FP reticle's team colour.
@export_enum("friend", "enemy") var side: String = "friend":
	set(value):
		side = value
		queue_redraw()

var data: Dictionary = {}
var _art_key: StringName = &""
var _art_scale: float = 0.0
var _width: float = BASE_SIZE.x
var _text_box: VBoxContainer = null
var _count_label: Label = null
var _not_found: Label = null
var _lore: Label = null
var _lines: Array[Control] = []

@onready var _cost_label: Label = %CostLabel
@onready var _elite_icon: TextureRect = %EliteIcon
@onready var _name_label: Label = %NameLabel
@onready var _type_icon: TextureRect = %TypeIcon
@onready var _type_label: Label = %TypeLabel
@onready var _art_icon: TextureRect = %ArtIcon
@onready var _scanlines: ColorRect = %Scanlines
@onready var _keyword_row: HBoxContainer = %KeywordRow
@onready var _body_label: Label = %BodyLabel
@onready var _range_row: HBoxContainer = %RangeRow
@onready var _fp_badge: Control = %FirepowerBadge
@onready var _fp_label: Label = %FirepowerLabel
@onready var _fp_icon: TextureRect = %FirepowerIcon
@onready var _armor_badge: Control = %ArmorBadge
@onready var _armor_label: Label = %ArmorLabel
@onready var _armor_icon: TextureRect = %ArmorIcon


## The Y2+ card's height at width w (tactics and units share it).
static func height_for(w: float) -> float:
	return 2.0 + TITLE_H + roundf((w - 8.0) / 4.0) + TYPE_H + LINES * LINE_H + 10.0 + BAR_H + 2.0


## The card's size at width w.
static func size_for(w: float) -> Vector2:
	return Vector2(w, height_for(w))


## kc-cards-impl: the Y2+ data of a deck card wearing `art` at copy `level` (the art's trait,
## the level coin, a Recruit's locks, Standard Issue).
static func view_for_card(card: CardData, art: StringName = &"", level: int = 1, chosen: StringName = SynergyRules.TRAIT_DEFAULT) -> Dictionary:
	var CardInfo: GDScript = load("res://scripts/ui/card_info.gd")
	var vd: Dictionary = CardInfo.view_dict(card)
	var a: StringName = art if art != &"" else card.id
	vd["banner"] = String(a)
	var e: Dictionary = BannerCard.entry_for_card(card, art, level, chosen)
	for k: String in ["standard_issue", "locked", "trains", "level", "trait"]:
		if e.has(k) and str(e[k]) != "":
			vd[k] = e[k]
	if e.has("locked"):
		vd["keywords"] = []
	if not card.is_unit():
		vd.erase("level")
	return vd


func _ready() -> void:
	_elite_icon.texture = IconSheet.get_icon(&"elite")
	_type_icon.visible = false
	_fp_icon.visible = false
	_armor_icon.visible = false
	_range_row.visible = false
	_keyword_row.visible = false
	var chip: Control = _type_label.get_parent() as Control
	if chip is PanelContainer:
		(chip as PanelContainer).add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	(get_node("ArtPanel") as PanelContainer).add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_text_box = VBoxContainer.new()
	_text_box.name = "TextBox"
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_theme_constant_override(&"separation", 0)
	_text_box.clip_contents = true
	add_child(_text_box)
	remove_child(_body_label)
	_text_box.add_child(_body_label)
	_body_label.owner = self
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_override(&"font", CardLook.NUM_FONT)
	_count_label.add_theme_font_size_override(&"font_size", 16)
	_count_label.add_theme_color_override(&"font_color", Color.WHITE)
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(0.04, 0.05, 0.055, 0.9)
	cb.border_color = MUTED
	cb.set_border_width_all(1)
	cb.set_corner_radius_all(3)
	cb.content_margin_left = 4
	cb.content_margin_right = 4
	_count_label.add_theme_stylebox_override(&"normal", cb)
	add_child(_count_label)
	# kc-hand-y2: the lore line (cards with no effect), bottom of the text box.
	_lore = Label.new()
	_lore.name = "LoreLabel"
	_lore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lore.add_theme_font_override(&"font", CardLook.LORE_FONT)
	_lore.add_theme_font_size_override(&"font_size", 16)
	_lore.add_theme_color_override(&"font_color", CardLook.LORE_COLOR)
	_lore.add_theme_constant_override(&"line_spacing", -3)
	_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_lore.max_lines_visible = 3  # bounds the autowrap minimum height (lore is one or two lines)
	_lore.visible = false
	add_child(_lore)
	_not_found = Label.new()
	_not_found.name = "NotFoundLabel"
	_not_found.text = "NOT FOUND YET"
	_not_found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_not_found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_not_found.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_not_found.add_theme_font_override(&"font", CardLook.TITLE_FONT)
	_not_found.add_theme_font_size_override(&"font_size", 16)
	_not_found.add_theme_color_override(&"font_color", Color("#C2C9CF"))
	var veil := StyleBoxFlat.new()
	veil.bg_color = Color(0.04, 0.05, 0.055, 0.78)
	_not_found.add_theme_stylebox_override(&"normal", veil)
	add_child(_not_found)
	for l: Label in [_name_label, _cost_label, _type_label]:
		l.add_theme_constant_override(&"outline_size", 0)
	# The one title style (CardLook.title_label's spec) on the card's name.
	_name_label.theme_type_variation = &""
	_name_label.add_theme_font_override(&"font", CardLook.TITLE_FONT)
	_name_label.add_theme_font_size_override(&"font_size", CardLook.TITLE_PX)
	_name_label.add_theme_color_override(&"font_color", CardLook.TITLE_COLOR)
	_name_label.uppercase = true
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.set_meta(&"title_style", true)
	_cost_label.add_theme_font_override(&"font", CardLook.NUM_FONT)
	_cost_label.add_theme_font_size_override(&"font_size", 17)
	for l: Label in [_fp_label, _armor_label]:
		l.add_theme_font_override(&"font", CardLook.NUM_FONT)
		l.add_theme_font_size_override(&"font_size", 17)
		l.add_theme_constant_override(&"outline_size", 4)
		l.add_theme_color_override(&"font_outline_color", CardLook.INK)
	_type_label.theme_type_variation = &""
	_type_label.add_theme_font_override(&"font", CardLook.TITLE_FONT)
	_type_label.add_theme_font_size_override(&"font_size", 16)
	_type_label.add_theme_color_override(&"font_color", Color("#B9C2C9"))
	_type_label.uppercase = true
	_body_label.theme_type_variation = &""
	_body_label.add_theme_font_override(&"font", CardLook.RULE_FONT)
	_body_label.add_theme_font_size_override(&"font_size", 16)
	_body_label.add_theme_color_override(&"font_color", CardLook.RULE_COLOR)
	_body_label.add_theme_constant_override(&"line_spacing", -3)
	if data.is_empty():
		data = PLACEHOLDER.duplicate(true)
	set_notify_transform(true)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_update_art_texture()


## Lays the card out at width w (height = height_for(w)); the card is not scaled.
func set_card_width(w: float) -> void:
	_width = maxf(120.0, roundf(w))
	custom_minimum_size = size_for(_width)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	if is_node_ready():
		_refresh()


func get_card_width() -> float:
	return _width


## Shows a card from a plain Dictionary (keys: see the header).
func set_card_data(card: Dictionary) -> void:
	data = card.duplicate(true)
	side = String(data.get("side", side))
	if is_node_ready():
		_refresh()


## Shows a card Resource (p02 data classes). Reads fields by name, so it does not depend on the class.
func set_card(card: Resource, card_side: String = "friend") -> void:
	var d: Dictionary = _from_resource(card)
	d["side"] = card_side
	set_card_data(d)


## Names of labels whose text does not fit inside its slot (empty = everything fits). Labels that
## end in an ellipsis by design (name, rules lines) are left out.
func get_overflowing_labels() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in [_cost_label, _fp_label, _armor_label]:
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var slot: Vector2 = label.get_meta(&"slot_size", label.size)
		var need: Vector2 = _text_size(label)
		if need.x > slot.x + 0.5 or need.y > slot.y + 0.5:
			out.append("%s (%s needs %s, slot %s)" % [label.name, label.text, need, slot])
	return out


## Smallest effective on-screen font size of the given role labels, after this card's scale.
func get_min_effective_font_size(label_names: PackedStringArray) -> float:
	var smallest: float = INF
	for label: Label in _text_labels():
		if label_names.has(label.name) and label.is_visible_in_tree() and not label.text.is_empty():
			smallest = minf(smallest, label.get_theme_font_size(&"font_size") * get_global_transform().get_scale().y)
	return smallest


func _from_resource(card: Resource) -> Dictionary:
	var d: Dictionary = {}
	var props: Array = []
	for p: Dictionary in card.get_property_list():
		props.append(p["name"])
	var pick := func(names: Array, fallback: Variant) -> Variant:
		for n: String in names:
			if props.has(n) and card.get(n) != null:
				return card.get(n)
		return fallback
	d["name"] = str(pick.call(["display_name", "name", "title", "id"], "Card"))
	d["type"] = str(pick.call(["card_type", "type"], "unit")).to_lower()
	d["weapon_class"] = str(pick.call(["weapon_class", "class_tag", "klass"], "")).to_lower()
	d["cost"] = int(pick.call(["cost"], 0))
	d["firepower"] = int(pick.call(["firepower", "fp"], 0))
	d["armor"] = int(pick.call(["armor", "max_armor"], 0))
	d["keywords"] = pick.call(["keywords"], [])
	d["text"] = str(pick.call(["rules_text", "text"], ""))
	d["elite"] = bool(pick.call(["elite", "is_elite"], false))
	d["threshold"] = int(pick.call(["threshold"], 0))
	return d


func _card_type() -> String:
	return String(data.get("type", "unit"))


## Tactics wear the T1 orders frame.
func is_tactic() -> bool:
	return _card_type() == "tactic"


## kc-loadout-cut (head): the Operator shows its Supply cost in the same hex badge as every other
## card (none when it is free); every other type always has its cost / threshold badge.
func _has_cost_badge() -> bool:
	return _card_type() != "operator" or int(data.get("cost", 0)) > 0


func has_stats_bar() -> bool:
	return _card_type() in ["unit", "operator"]


func _art_h() -> float:
	return roundf((_width - 8.0) / 4.0)


## Rects of every region at the current width (tests / layout): title, cost, art, type, text, bar,
## fp, armor, traits.
func regions() -> Dictionary:
	var w: float = _width
	var art: Rect2 = Rect2(4, 2.0 + TITLE_H, w - 8.0, _art_h())
	var ty: float = art.end.y + 3.0
	var by: float = ty + TYPE_H
	var stats: bool = has_stats_bar()
	var box_h: float = LINES * LINE_H + 8.0 + (0.0 if stats else BAR_H + 2.0)
	var sy: float = by + LINES * LINE_H + 10.0
	return {
		"title": Rect2(0, 0, w, 2.0 + TITLE_H), "cost": COST_RECT, "art": art,
		"type": Rect2(6, ty, w - 12.0, TYPE_H), "text": Rect2(4, by, w - 8.0, box_h),
		"bar": Rect2(4, sy, w - 8.0, BAR_H) if stats else Rect2(),
		"fp": Rect2(w - 6.0 - 27.0 - 4.0 - 28.0, sy, 28, 28), "armor": Rect2(w - 6.0 - 27.0, sy, 27, 28),
		"traits": Rect2(6, sy + 4.0, 22, 22),
	}


func _refresh() -> void:
	if _text_box == null:
		return
	custom_minimum_size = size_for(_width)
	size = custom_minimum_size
	var type_name: String = _card_type()
	var weapon: StringName = StringName(String(data.get("weapon_class", "")).to_lower())
	var rg: Dictionary = regions()
	var tac: bool = is_tactic()
	# Title bar: cost hex (or killstreak threshold) + the name.
	_cost_label.text = str(int(data.get("threshold", 0))) if type_name == "killstreak" else str(int(data.get("cost", 0)))
	_cost_label.visible = _has_cost_badge()
	_cost_label.add_theme_color_override(&"font_color", Color("#FF9A9A") if bool(data.get("cant_pay", false)) else CardLook.INK)
	_set_slot(_cost_label, COST_RECT)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.text = String(data.get("name", "")).replace("★", "").strip_edges()
	var name_left: float = (COST_RECT.end.x + 4.0) if _has_cost_badge() else 8.0
	var count: int = int(data.get("count", 0))
	_count_label.visible = count > 0
	_count_label.text = "×%d" % count
	var right: float = _width - 8.0 - (T1_CUT + 2.0 if tac else 0.0)
	if count > 0:
		var cw: float = _count_label.get_combined_minimum_size().x
		_count_label.size = Vector2(cw, 22)
		_count_label.position = Vector2(right - cw, 6)
		right -= cw + 4.0
	_elite_icon.visible = bool(data.get("elite", false))
	if _elite_icon.visible:
		_elite_icon.position = Vector2(right - 18.0, 8)
		_elite_icon.size = Vector2(18, 18)
		right -= 20.0
	_set_slot(_name_label, Rect2(name_left, 2, right - name_left, TITLE_H))
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Art (4:1, nothing over it).
	var art_panel: Control = get_node("ArtPanel") as Control
	art_panel.position = (rg["art"] as Rect2).position
	art_panel.size = (rg["art"] as Rect2).size
	_set_art()
	_scanlines.visible = type_name == "killstreak"
	_not_found.visible = bool(data.get("not_found", false))
	_not_found.position = (rg["art"] as Rect2).position
	_not_found.size = (rg["art"] as Rect2).size
	# Type line.
	var bits: PackedStringArray = []
	if type_name == "operator":
		bits.append("OPERATOR")
	if bool(data.get("standard_issue", false)):
		bits.append("STANDARD ISSUE")
	if tac:
		bits.append("TACTIC")
	elif type_name == "equipment":
		bits.append("FIELD")
	elif type_name == "killstreak":
		bits.append("STREAK %d" % int(data.get("threshold", 0)))
	if weapon != &"":
		bits.append(String(weapon).to_upper())
	if bits.is_empty():
		bits.append("UNIT")
	_type_label.text = "  ".join(bits)
	var chip: Control = _type_label.get_parent() as Control
	chip.position = (rg["type"] as Rect2).position
	chip.size = Vector2(0, TYPE_H)
	_type_label.set_meta(&"slot_size", Vector2((rg["type"] as Rect2).size.x - 22.0, TYPE_H))
	# Text box: keyword lines, the Trains line, the effect text.
	_rebuild_text(rg["text"])
	# Stats (the reticle and plate are drawn; the numbers are the labels).
	var stats: bool = has_stats_bar()
	_fp_badge.visible = stats
	_armor_badge.visible = stats
	_fp_badge.position = (rg["fp"] as Rect2).position
	_fp_badge.size = (rg["fp"] as Rect2).size
	_armor_badge.position = (rg["armor"] as Rect2).position
	_armor_badge.size = (rg["armor"] as Rect2).size
	for pair: Array in [[_fp_label, rg["fp"]], [_armor_label, rg["armor"]]]:
		var l: Label = pair[0]
		l.position = Vector2.ZERO
		l.size = (pair[1] as Rect2).size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_meta(&"slot_size", l.size)
	_fp_label.text = str(int(data.get("firepower", 0)))
	_fp_label.add_theme_color_override(&"font_color", CardLook.trend_color(int(data.get("fp_trend", 0))))
	_armor_label.text = str(int(data.get("armor", 0)))
	_armor_label.add_theme_color_override(&"font_color", CardLook.AR_DMG_NUM if _damaged() else Color.WHITE)
	queue_redraw()
	card_changed.emit()


func _damaged() -> bool:
	return int(data.get("armor", 0)) < int(data.get("armor_max", data.get("armor", 0)))


## The 4:1 calling card: licensed art, the copy's art, the card's own banner, else the illustration.
func _set_art() -> void:
	_art_key = &""
	_art_scale = 0.0
	_art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_icon.modulate = Color.WHITE
	var hint: Dictionary = {"cls": String(data.get("weapon_class", "")).to_upper(), "type": _card_type()}
	var tex: Texture2D = null
	for key: String in ["licensed_art", "art_id", "banner", "id"]:
		if String(data.get(key, "")) != "":
			tex = BannerArtDB.banner_texture(StringName(String(data[key])), hint)
			if tex != null:
				break
	if tex == null:
		_art_key = CardArt.card_key(data)
		if CardArt.has_card(_art_key):
			_update_art_texture()
			return
		_art_key = &""
		var weapon: String = String(data.get("weapon_class", ""))
		tex = IconSheet.get_icon(StringName("class_" + weapon) if weapon != "" else StringName("type_" + _card_type()))
		_art_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_icon.modulate = Color(0.6, 0.65, 0.7, 0.55)
	_art_icon.texture = tex
	_art_icon.flip_h = side == "enemy"


## Rasterises the illustration fallback for the scale the card is shown at (bucketed, cached).
func _update_art_texture() -> void:
	if _art_key == &"" or _art_icon == null:
		return
	var s: float = CardArt.bucket(CardArt.screen_scale(_art_icon))
	if is_equal_approx(s, _art_scale):
		return
	_art_scale = s
	_art_icon.texture = CardArt.card_texture(_art_key, s)


## Keyword entries as [id, value].
func _keyword_entries() -> Array:
	var out: Array = []
	for entry: Variant in data.get("keywords", []):
		if entry is Dictionary:
			out.append([StringName(String(entry.get("id", ""))), int(entry.get("value", 0))])
		else:
			out.append([StringName(String(entry)), 0])
	return out


func _locked_names() -> Array:
	var l: Variant = data.get("locked", false)
	return l if l is Array else []


## The lore line shown now ("" when the card has an effect).
func get_lore_text() -> String:
	return _lore.text if _lore != null and _lore.visible else ""


## The text box's lines now (tests): [{id, name, rule, locked}], then the effect text.
func get_text_lines() -> Array:
	var out: Array = []
	for row: Control in _lines:
		out.append({"id": row.get_meta(&"kw"), "name": (row.get_node("KeywordName") as Label).text,
				"rule": (row.get_node("KeywordRule") as Label).text, "locked": bool(row.get_meta(&"locked"))})
	return out


func _rebuild_text(box: Rect2) -> void:
	for c: Control in _lines:
		_text_box.remove_child(c)
		c.queue_free()
	_lines.clear()
	# Release the old width first, or the box keeps a wider card's minimum (a later set_card_width).
	_body_label.custom_minimum_size = Vector2.ZERO
	_text_box.position = box.position + Vector2(4, 4)
	_text_box.size = box.size - Vector2(8, 8)
	var lock_all: bool = data.get("locked", false) is bool and bool(data.get("locked", false))
	var rows: int = 0
	var names_seen: PackedStringArray = []
	for kw: Array in _keyword_entries():
		var id: StringName = kw[0]
		var value: int = kw[1]
		var nm: String = String(KEYWORD_NAMES.get(id, String(id).capitalize()))
		var rule: String = String(SHORT_RULES.get(id, ""))
		if nm.contains("%d"):
			nm = nm % maxi(1, value)
		if rule.contains("%d"):
			rule = rule % maxi(1, value)
		_add_line(id, nm, rule, lock_all)
		names_seen.append(nm.to_lower())
		rows += 1
	var locked: Array = _locked_names()
	for ln: Variant in locked:
		names_seen.append(String(ln).to_lower())
	var trains: String = String(data.get("trains", ""))
	if not locked.is_empty() or trains != "":
		var names: String = trains.trim_prefix("Trains:").strip_edges() if trains != "" else " · ".join(PackedStringArray(locked))
		_add_line(&"lock", "Trains:", names, true)
		rows += 1
	var text: String = _effect_text(names_seen)
	# kc-hand-y2: no effect at all: a lore line, italic dark grey, at the bottom of the box.
	var lore: String = ""
	if text == "" and rows == 0:
		lore = String(data.get("lore", ""))
		if lore == "":
			lore = CardLore.line(StringName(String(data.get("id", ""))), bool(data.get("standard_issue", false)), has_stats_bar())
	_lore.text = lore
	_lore.visible = lore != ""
	_lore.position = box.position + Vector2(6, 4)
	# Width first: an autowrap Label measured at a narrower width keeps a huge minimum height.
	_lore.custom_minimum_size = Vector2(box.size.x - 12.0, 0)
	_lore.size = Vector2(box.size.x - 12.0, 0)
	_lore.size = box.size - Vector2(12, 8)
	# Bottom-aligned text: keep the label's bottom on the box's bottom whatever its minimum height.
	_lore.position.y = box.end.y - 4.0 - _lore.size.y
	_body_label.text = text
	_body_label.visible = text != ""
	_body_label.modulate = Color(0.62, 0.66, 0.7, 0.7) if lock_all else Color.WHITE
	_text_box.move_child(_body_label, -1)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Autowrap + an ellipsis collapses a Label to one line: no trimming; the text box clips.
	_body_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var room: float = _text_box.size.y - rows * LINE_H
	_body_label.max_lines_visible = maxi(1, int(floorf(room / LINE_H)))
	_body_label.custom_minimum_size = Vector2(_text_box.size.x, maxf(LINE_H, floorf(room / LINE_H) * LINE_H))
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.set_meta(&"slot_size", Vector2(_text_box.size.x, maxf(LINE_H, room)))


## The effect text, minus a rules text that only lists keywords already on their own lines
## ("Patch 2", "First Shot, Pick").
func _effect_text(names: PackedStringArray) -> String:
	var text: String = String(data.get("text", "")).strip_edges()
	if text == "":
		return ""
	var only_names: bool = true
	for part: String in text.trim_suffix(".").split(","):
		var p: String = part.strip_edges().to_lower()
		if p != "" and not names.has(p):
			only_names = false
	return "" if only_names else text


## One text-box line: the keyword's icon, its bold name, the short rule (greyed + padlock when locked).
func _add_line(id: StringName, nm: String, rule: String, locked: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Line%d" % _lines.size()
	row.set_meta(&"kw", id)
	row.set_meta(&"locked", locked)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	row.custom_minimum_size = Vector2(0, LINE_H)
	var icon: Control = Control.new()
	icon.custom_minimum_size = Vector2(16, LINE_H)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = MUTED if locked else AMBER
	icon.draw.connect(func() -> void:
		var r: Rect2 = Rect2(0, (LINE_H - 16.0) * 0.5, 16, 16)
		if id == &"lock":
			StandardIssueLook.draw_lock(icon, r.grow(-1.0), MUTED)
		elif id == &"pick":
			CardLook.draw_pick_icon(icon, r, tint)
		elif id == &"pierce":
			SynergyGlyphs.draw_pierce_icon(icon, r, tint)
		else:
			var tex: Texture2D = IconSheet.get_keyword_icon(id)
			if tex != null:
				icon.draw_texture_rect(tex, r, false, tint))
	row.add_child(icon)
	var b: Label = CardLook.rule_label(nm, true)
	b.name = "KeywordName"
	if locked:
		b.add_theme_color_override(&"font_color", MUTED)
	row.add_child(b)
	var t: Label = CardLook.rule_label(rule, false, MUTED if locked else CardLook.RULE_COLOR)
	t.name = "KeywordRule"
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	_text_box.add_child(row)
	_lines.append(row)


# --- Text sizes ---------------------------------------------------------------------------

func _set_slot(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size
	label.set_meta(&"slot_size", rect.size)


func _text_labels() -> Array[Label]:
	var out: Array[Label] = [_cost_label, _name_label, _type_label, _body_label, _fp_label, _armor_label]
	for row: Control in _lines:
		for l: Node in row.get_children():
			if l is Label:
				out.append(l)
	return out


func _text_size(label: Label) -> Vector2:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var text: String = label.text.to_upper() if label.uppercase else label.text
	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, font.get_height(font_size))


# --- Frame drawing ------------------------------------------------------------------------

func _frame_colors() -> Array:
	var type_name: String = _card_type()
	var frame: Color = FRAME_UNIT
	var face: Color = FACE_UNIT
	if type_name == "operator":
		frame = FRAME_OP
		face = FACE_OP
	elif is_tactic():
		frame = FRAME_T1
		face = FACE_T1
	elif type_name == "killstreak":
		frame = FRAME_STREAK
	elif bool(data.get("standard_issue", false)):
		frame = StandardIssueLook.FRAME
	if bool(data.get("elite", false)) and type_name != "operator":
		frame = Color("#C9A227")
	if bool(data.get("marked", false)):
		frame = AMBER
	return [frame, face]


## kc-ui-hooks: the UI kit frame for this card (prompt pack §7.4b): frm_t1_orders (Tactics),
## frm_y2_operator, frm_y2_standard_issue, else frm_y2_unit (units, fields, killstreaks).
func frame_piece() -> StringName:
	if is_tactic():
		return &"frm_t1_orders"
	if _card_type() == "operator":
		return &"frm_y2_operator"
	if bool(data.get("standard_issue", false)):
		return &"frm_y2_standard_issue"
	return &"frm_y2_unit"


## The frame colour of the card's kind without its state (marked / Elite / killstreak tint).
func _base_frame_color() -> Color:
	if _card_type() == "operator":
		return FRAME_OP
	if is_tactic():
		return FRAME_T1
	if bool(data.get("standard_issue", false)):
		return StandardIssueLook.FRAME
	return FRAME_UNIT


## The card's outline in rect r: rounded corners; `cut` > 0 chevron-cuts the top-right corner (T1).
static func outline(r: Rect2, cut: float) -> PackedVector2Array:
	var rad: float = 6.0
	var pts: PackedVector2Array = []
	var corners: Array = [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
			[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for i: int in 4:
		if i == 1 and cut > 0.0:
			pts.append(Vector2(r.end.x - cut, r.position.y))
			pts.append(Vector2(r.end.x, r.position.y + cut))
			continue
		for s: int in 5:
			pts.append((corners[i][0] as Vector2) + Vector2.from_angle(float(corners[i][1]) + s * PI * 0.5 / 4.0) * rad)
	return pts


func _draw() -> void:
	var w: float = _width
	var h: float = height_for(w)
	var cols: Array = _frame_colors()
	var tac: bool = is_tactic()
	var cut: float = T1_CUT if tac else 0.0
	var outer: PackedVector2Array = outline(Rect2(0, 0, w, h), cut)
	if bool(data.get("marked", false)):
		var glow: PackedVector2Array = outline(Rect2(-2, -2, w + 4, h + 4), cut + 1.0)
		glow.append(glow[0])
		draw_polyline(glow, Color(AMBER, 0.45), 3.0, true)
	# kc-ui-hooks: the painted Y2+ / T1 frame (frame_piece()) replaces the outline polygons and the
	# khaki band; a state colour (marked amber, Elite gold, killstreak cyan) still rings its rim.
	var kit_frame: bool = UiKit.draw_piece(self, frame_piece(), Rect2(0, 0, w, h))
	if kit_frame:
		if cols[0] != _base_frame_color():
			var rim: PackedVector2Array = outline(Rect2(0.75, 0.75, w - 1.5, h - 1.5), maxf(0.0, cut - 0.5))
			rim.append(rim[0])
			draw_polyline(rim, cols[0], 1.5, true)
	else:
		draw_colored_polygon(outer, cols[0])
		draw_colored_polygon(outline(Rect2(1.5, 1.5, w - 3.0, h - 3.0), maxf(0.0, cut - 1.0)), cols[1])
	var rg: Dictionary = regions()
	if tac:
		# The orders paper grain (tex_orders_paper, tiled at 60%) over the face under the title.
		UiKit.draw_tiled(self, PAPER_PIECE, Rect2(3, TITLE_H, w - 6.0, h - TITLE_H - 3.0), Color(1, 1, 1, 0.6))
	if tac and not kit_frame:
		# The orders paper: a khaki band behind the title.
		var band: PackedVector2Array = [Vector2(1.5, 1.5), Vector2(w - 1.5 - (cut - 1.0), 1.5), Vector2(w - 1.5, cut + 0.5),
				Vector2(w - 1.5, TITLE_H), Vector2(1.5, TITLE_H)]
		draw_polygon(band, PackedColorArray([Color(FRAME_T1, 0.35), Color(FRAME_T1, 0.08), Color(FRAME_T1, 0.08),
				Color(FRAME_T1, 0.08), Color(FRAME_T1, 0.35)]))
	# Cost hex (the number is CostLabel).
	if _has_cost_badge():
		CardLook.draw_cost(self, COST_RECT, "", bool(data.get("cant_pay", false)))
	draw_rect(rg["art"], Color("#0C0F11"))
	# Type line: the level coin after the words.
	var lv: int = int(data.get("level", -1))
	if lv >= 0 and has_stats_bar() and _card_type() != "operator" and not bool(data.get("standard_issue", false)):
		var tw: float = CardLook.TITLE_FONT.get_string_size(_type_label.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var tr: Rect2 = rg["type"]
		CardLook.draw_level_coin(self, Rect2(tr.position.x + tw + 8.0, tr.position.y + 3.0, 16, 16), lv)
	# Text box.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.03, 0.6) if tac else Color(0.04, 0.05, 0.055, 0.55)
	sb.set_corner_radius_all(2)
	draw_style_box(sb, rg["text"])
	# Stats bar: traits bottom-left, FP reticle + Armor plate bottom-right.
	if has_stats_bar():
		var t: String = String(data.get("trait", ""))
		if t != "":
			CardLook.draw_trait(self, rg["traits"], StringName(t), bool(data.get("trait_lit", false)))
		CardLook.draw_reticle(self, rg["fp"], 0, &"enemy" if side == "enemy" else &"player", 0, false)
		CardLook.draw_armor(self, rg["armor"], 0, _damaged(), false)


## The level coin's rect on the type line (tests).
func level_coin_rect() -> Rect2:
	var tw: float = CardLook.TITLE_FONT.get_string_size(_type_label.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var tr: Rect2 = regions()["type"]
	return Rect2(tr.position.x + tw + 8.0, tr.position.y + 3.0, 16, 16)
