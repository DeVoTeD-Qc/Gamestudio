# mini_icons.gd
# Purpose: The full CardView's icon language at small sizes (f04), shared by the hand chips
#   (hand_area.gd) and the board's unit slots (unit_slot.gd): card-type and weapon-class icons,
#   keyword icons in amber with their Cover / Patch value, FP / Armor icons beside the numbers.
#   Words are optional extras: a "word" label only shows when the whole row fits its width
#   (fit_words), so a tight chip drops words before icons.
# Dependencies: icon_sheet.gd (IconSheet), hud_theme.tres (Hud colors, HudTag).
# Author: UI/UX Agent (f04)
extends RefCounted

const CLASSES: PackedStringArray = ["smg", "shotgun", "ar", "sniper", "lmg"]
## Same words as CardView's keyword labels.
const KEYWORD_WORDS: Dictionary = {
	&"first_shot": "FIRST SHOT", &"pick": "PICK", &"flank": "FLANK", &"cover": "COVER",
	&"suppress": "SUPPRESS", &"patch": "PATCH", &"holder": "HOLDER",
	&"on_deploy": "ON DEPLOY", &"on_down": "ON DOWN",
}


## A tinted, mouse-transparent icon from the sheet (null texture = unknown name, still sized).
static func icon(icon_name: StringName, px: float, tint: Color) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = IconSheet.get_icon(icon_name) if IconSheet.has_icon(icon_name) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	r.set_meta(&"icon", icon_name)
	return r


## Card type for a chip Dictionary: "unit" | "tactic" | "equipment". Falls back to the type word
## (mock data: "Sniper", "Tactic", "Equip").
static func card_type(card: Dictionary) -> String:
	if card.has("card_type"):
		return String(card["card_type"])
	var word: String = String(card.get("type", "")).to_lower()
	if word == "tactic":
		return "tactic"
	if word.begins_with("equip"):
		return "equipment"
	return "unit"


## Weapon class ("shotgun"...) or "" for a chip Dictionary.
static func weapon_class(card: Dictionary) -> String:
	var w: String = String(card.get("weapon_class", "")).to_lower()
	if w == "" and not card.has("weapon_class"):
		w = String(card.get("type", "")).to_lower()
	return w if CLASSES.has(w) else ""


## A word label that fit_words() shows only when its whole row fits.
static func word(text: String, variation: StringName = &"HudTag") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.clip_text = true  # no minimum width: fit_words decides
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta(&"word", true)
	return l


## Keyword icons (amber, like CardView), each followed by its word (optional) and value.
## keywords: [{id, value?}] or ids. Returns an HBox; call fit_words(row) once it has a width.
static func keyword_row(keywords: Array, px: float, tint: Color, with_words: bool = true) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Variant in keywords:
		var id: StringName = StringName(String(entry.get("id", "")) if entry is Dictionary else String(entry))
		var value: int = int(entry.get("value", 0)) if entry is Dictionary else 0
		var tex: AtlasTexture = IconSheet.get_keyword_icon(id)
		if tex == null:
			continue
		var ic: TextureRect = icon(IconSheet.KEYWORD_ICONS[id], px, tint)
		ic.tooltip_text = String(KEYWORD_WORDS.get(id, String(id)))
		row.add_child(ic)
		var text: String = String(KEYWORD_WORDS.get(id, String(id).to_upper()))
		if with_words:
			# The word carries the value ("PATCH 2"); the bare number shows only without words.
			row.add_child(word(text + (" %d" % value if value > 0 else "")))
		if value > 0:
			var v: Label = Label.new()
			v.text = str(value)
			v.theme_type_variation = &"HudTag"
			v.add_theme_color_override(&"font_color", tint)
			v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.set_meta(&"important", true)
			v.set_meta(&"value", with_words)
			row.add_child(v)
	return row


## Shows the row's word labels only if everything (icons, numbers and words) fits the row's
## width; otherwise hides them all, so icons always stay.
static func fit_words(row: BoxContainer) -> void:
	if row == null or not row.is_inside_tree() or row.size.x <= 0.0:
		return
	var sep: int = row.get_theme_constant(&"separation")
	var need: float = 0.0
	var count: int = 0
	var words: Array[Label] = []
	var values: Array[Label] = []
	for child: Node in row.get_children():
		var c: Control = child as Control
		if c == null:
			continue
		if c.has_meta(&"word"):
			words.append(c as Label)
			need += text_width(c as Label)
			count += 1
		elif bool(c.get_meta(&"value", false)):
			values.append(c as Label)  # replaced by its word ("PATCH 2") when words show
		else:
			need += c.get_combined_minimum_size().x
			count += 1
	need += sep * maxi(0, count - 1)
	var show: bool = need <= row.size.x + 0.5
	for l: Label in words:
		l.visible = show
		l.custom_minimum_size.x = ceilf(text_width(l)) if show else 0.0
	for l: Label in values:
		l.visible = not show


static func text_width(l: Label) -> float:
	var font: Font = l.get_theme_font(&"font")
	return font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x \
			+ l.get_theme_stylebox(&"normal").get_minimum_size().x
