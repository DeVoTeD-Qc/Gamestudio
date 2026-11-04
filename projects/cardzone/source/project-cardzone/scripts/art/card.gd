# card.gd
# Purpose: CzCard (cz16), the reusable CardZone card view for the hand, line, loadout strip, loot piles
#   and the long-press inspector. Adapted from CallingCard's BannerCard, laid out from art-direction.md
#   section 3: a paper plate with clipped corners (6 pt cut), 2 pt ink border, 4 pt rarity stripe on the
#   left edge; cost disc, type icon, rarity chip (letter; inspector adds word + ticks), name band, art
#   window (CzCardArt), Brace shield, DMG / RNG (items: main effects), inspector stat bar, effect text,
#   card id and attach strip. Hit and Bounty cards, Starter (dashed empty chip), card back (face_down),
#   Held outline + HOLD tag, attachment tabs, Down badge, and the Epic / Legendary rarity glint.
#   Two layouts: compact 84x118 pt and full (inspector) 220x308 pt. Every measure is in pt and scales
#   with the card width; text is drawn at its real pixel size, so it stays sharp on a 3x phone.
# Usage:
#   var card: CzCard = preload("res://scenes/card/CzCard.tscn").instantiate()
#   card.size = CzArtKit.compact_px(CzArtKit.PHONE_PT_PER_PX)   # or any 84:118 size; full is 220:308
#   card.configure(card_data)        # Dictionary or Resource (see scripts/art/README.md for fields)
#   card.layout_mode_override = &"full"  # &"auto" (default: full when >= 150 px wide) | &"compact" | &"full"
#   card.held = true; card.face_down = true; card.selected = true; card.dimmed = true
#   card.down = true                 # Down badge (hit_red chevron + "+1") on the card's top-left
#   card.attachments = ["+1 DMG", "+1 RNG"]   # tabs drawn under a weapon (outside its rect)
#   card.hold_enabled = true         # the 44x44 pt Hold hit area on the top edge toggles `held`
#   signals: tapped(card), inspect_requested(card) (right-click / long-press 0.45 s), hold_toggled(card, held)
#   card.layout_report()             # every box in px + font sizes (tests, cz10 layout checks)
# Dependencies: CzArtKit, CzIcons, CzCardArt, assets/shaders/rarity_glint.gdshader, Settings (optional)
# Author: Technical Artist Agent (cz16)
class_name CzCard
extends Control

signal tapped(card: CzCard)
signal inspect_requested(card: CzCard)
signal hold_toggled(card: CzCard, held: bool)

const GLINT_SHADER: String = "res://assets/shaders/rarity_glint.gdshader"
const LONG_PRESS_S: float = 0.45
## Auto layout switches to the inspector layout at this width (px). Compact is 84-117 px wide on the
## target screens, the inspector 220-305 px.
const FULL_MIN_WIDTH: float = 150.0
## Attachment tab under a weapon (pt): tall enough for its 12 pt text.
const ATTACH_TAB_PT: float = 16.0

@export_enum("auto", "compact", "full") var layout_mode_override: String = "auto" : set = _set_mode
@export var held: bool = false : set = _set_held
@export var face_down: bool = false : set = _set_redraw_face
@export var selected: bool = false : set = _set_selected
@export var dimmed: bool = false : set = _set_dimmed
@export var down: bool = false : set = _set_down
@export var hold_enabled: bool = false
## Glint on Epic / Legendary (turned off automatically with Settings.reduced_motion: static sheen).
@export var glint_enabled: bool = true : set = _set_glint_enabled

var info: Dictionary = CzCardArt.read({})
var attachments: Array = [] : set = _set_attachments

var _glint: ColorRect
var _glint_mat: ShaderMaterial
var _effect: RichTextLabel
var _press_t: float = -1.0
var _press_in_hold: bool = false
var _layout: Dictionary = {}


func _init() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_glint = get_node_or_null("%Glint") as ColorRect
	if _glint == null:
		_glint = ColorRect.new()
		_glint.name = "Glint"
		add_child(_glint)
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glint_mat = ShaderMaterial.new()
	_glint_mat.shader = load(GLINT_SHADER)
	_glint.material = _glint_mat
	_effect = get_node_or_null("%Effect") as RichTextLabel
	if _effect == null:
		_effect = RichTextLabel.new()
		_effect.name = "Effect"
		add_child(_effect)
	_effect.bbcode_enabled = true
	_effect.scroll_active = true
	_effect.fit_content = false
	_effect.mouse_filter = Control.MOUSE_FILTER_PASS
	_effect.add_theme_font_override("normal_font", CzArtKit.font_body())
	_effect.add_theme_font_override("bold_font", CzArtKit.font_display())
	_effect.add_theme_color_override("default_color", CzArtKit.INK)
	resized.connect(_relayout)
	_relayout()


## Fills the card from a Dictionary or a Resource (cz05 CardData). See CzCardArt.read for fields.
func configure(card: Variant) -> void:
	info = CzCardArt.read(card)
	_relayout()


func is_full() -> bool:
	if layout_mode_override == "full":
		return true
	if layout_mode_override == "compact":
		return false
	return size.x >= FULL_MIN_WIDTH


## px per pt for the current size and layout.
func px_per_pt() -> float:
	var design: Vector2 = CzArtKit.FULL_PT if is_full() else CzArtKit.COMPACT_PT
	return minf(size.x / design.x, size.y / design.y)


## Every element box (local px), font sizes (px) and flags for the current size. Keys:
##   mode, k, boxes {name: Rect2}, numerals {name: px}, texts {name: px}, name_text, name_fits, glint
func layout_report() -> Dictionary:
	return _compute_layout().duplicate(true)


## The 44x44 pt Hold hit area, centred on the card's top edge (half above it). Local px.
func hold_hit_rect() -> Rect2:
	var k: float = px_per_pt()
	var s: float = CzArtKit.TAP_PT * k
	return Rect2(Vector2(size.x * 0.5 - s * 0.5, -s * 0.5), Vector2(s, s))


## Height (px) the attachment tabs add under the card.
func attachment_tabs_height() -> float:
	return float(attachments.size()) * ATTACH_TAB_PT * px_per_pt()


func _has_point(point: Vector2) -> bool:
	if Rect2(Vector2.ZERO, size).has_point(point):
		return true
	return hold_enabled and hold_hit_rect().has_point(point)


# --- Setters ---------------------------------------------------------------------------------------
func _set_mode(v: String) -> void:
	layout_mode_override = v
	_relayout()


func _set_held(v: bool) -> void:
	held = v
	queue_redraw()


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _set_dimmed(v: bool) -> void:
	dimmed = v
	queue_redraw()


func _set_down(v: bool) -> void:
	down = v
	queue_redraw()


func _set_redraw_face(v: bool) -> void:
	face_down = v
	_relayout()


func _set_glint_enabled(v: bool) -> void:
	glint_enabled = v
	_relayout()


func _set_attachments(v: Array) -> void:
	attachments = v
	queue_redraw()


# --- Layout ----------------------------------------------------------------------------------------
func _relayout() -> void:
	_layout = {}
	if not is_node_ready():
		return
	var lay: Dictionary = _compute_layout()
	# Glint overlay (Epic / Legendary): masked to the frame band, the rarity stripe and the chip.
	var g: Dictionary = lay["glint"]
	_glint.position = Vector2.ZERO
	_glint.size = size
	_glint.visible = bool(g["on"])
	if bool(g["on"]):
		var k: float = lay["k"]
		_glint_mat.set_shader_parameter("card_size", size)
		_glint_mat.set_shader_parameter("cut", CzArtKit.CARD_CUT_PT * k)
		_glint_mat.set_shader_parameter("band", (CzArtKit.CARD_BORDER_PT + 1.0) * k)
		_glint_mat.set_shader_parameter("stripe", (CzArtKit.CARD_BORDER_PT + CzArtKit.CARD_STRIPE_PT) * k)
		var chip: Rect2 = lay["boxes"].get("chip", Rect2())
		_glint_mat.set_shader_parameter("chip_rect", Vector4(chip.position.x, chip.position.y, chip.end.x, chip.end.y))
		_glint_mat.set_shader_parameter("glint_color", (g["color"] as Color).lightened(0.55))
		_glint_mat.set_shader_parameter("strength", float(g["strength"]))
		_glint_mat.set_shader_parameter("speed", float(g["speed"]))
		_glint_mat.set_shader_parameter("phase", float(absi(hash(str(info.get("id", "")))) % 1000) / 1000.0)
	# Effect text (inspector only).
	var eb: Rect2 = lay["boxes"].get("effect", Rect2())
	_effect.visible = eb.size.x > 0.0
	if _effect.visible:
		_effect.position = eb.position
		_effect.size = eb.size
		var fs: int = lay["texts"]["effect"]
		_effect.add_theme_font_size_override("normal_font_size", fs)
		_effect.add_theme_font_size_override("bold_font_size", fs)
		_effect.text = effect_bbcode(_effect_text())
	queue_redraw()


func _reduced_motion() -> bool:
	if not is_inside_tree():
		return false
	var s: Node = get_node_or_null("/root/Settings")
	return s != null and bool(s.get("reduced_motion"))


## Effect text with keywords in SemiBold (section 3: "keywords in SemiBold").
static func effect_bbcode(text: String) -> String:
	var t: String = text.replace("[", "(").replace("]", ")")
	t = t.replace("**", "")
	for kw: String in CzCardArt.KEYWORDS:
		var re := RegEx.new()
		re.compile("\\b(" + kw.replace(" ", "\\s") + ")\\b")
		t = re.sub(t, "[b]$1[/b]", true)
	return t


func _effect_text() -> String:
	var e: String = str(info.get("effect", ""))
	match info.get("type", &"item"):
		&"hit":
			if e == "":
				e = "Free draw. Adrenaline: play for Move 1 or Search 1. Down: +1 Brace per shot while in your next draw."
		&"bounty":
			if e == "":
				e = "Goes to the player with the most health. Hit the holder: Heal 1. Final circle: the holder takes 1 extra Hit."
	return e


## Font px for a size in pt (rounded up so floors hold).
static func _fpx(pt: float, k: float) -> int:
	return maxi(1, int(ceilf(pt * k - 0.001)))


func _compute_layout() -> Dictionary:
	var full: bool = is_full()
	var k: float = px_per_pt()
	var lay: Dictionary = {"mode": "full" if full else "compact", "k": k, "boxes": {}, "numerals": {}, "texts": {},
			"name_text": "", "name_fits": true, "stats": [], "glint": {"on": false}}
	if full:
		_layout_full(lay, k)
	else:
		_layout_compact(lay, k)
	var rk: StringName = info.get("rarity", &"")
	var g: Dictionary = CzArtKit.GLINT.get(rk, {})
	if glint_enabled and not face_down and not g.is_empty():
		var reduced: bool = _reduced_motion()
		lay["glint"] = {"on": true, "color": CzArtKit.rarity_color(rk), "strength": float(g["strength"]) * (0.5 if reduced else 1.0),
				"speed": 0.0 if reduced else float(g["speed"])}
	_layout = lay
	return lay


func _r(x: float, y: float, w: float, h: float, k: float) -> Rect2:
	return Rect2(Vector2(x, y) * k, Vector2(w, h) * k)


## Text box (cap-height band) for a string drawn with its baseline at y_base (px).
static func _text_box(font: Font, text: String, px: int, left: float, y_base: float) -> Rect2:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var cap: float = float(px) * 0.72
	return Rect2(Vector2(left, y_base - cap), Vector2(w, cap))


func _layout_compact(lay: Dictionary, k: float) -> void:
	var boxes: Dictionary = lay["boxes"]
	var type: StringName = info.get("type", &"item")
	if face_down:
		return
	var disp: Font = CzArtKit.font_display()
	var num: Font = CzArtKit.font_numeral()
	if type == &"hit" or type == &"bounty":
		boxes["band"] = _r(6, 4, 76, 40, k)
		boxes["art"] = _r(8, 46, 72, 40, k)
		var lines: PackedStringArray = ["ADRENALINE", "MOVE 1 / SEARCH 1"] if type == &"hit" else ["HIT HOLDER: HEAL 1", "FINAL: +1 HIT"]
		var lp: int = _fpx(10.0, k)
		lay["texts"]["band_word"] = _fpx(18.0, k)
		lay["texts"]["lines"] = lp
		lay["lines"] = lines
		for i: int in lines.size():
			var w: float = disp.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lp).x
			var base: float = (100.0 + 13.0 * float(i)) * k
			boxes["line%d" % i] = _text_box(disp, lines[i], lp, size.x * 0.5 + 1.0 * k - w * 0.5, base)
		return
	# Cost disc (top-left), type icon (top-centre), rarity chip (top-right).
	if int(info.get("cost", -1)) >= 0:
		boxes["cost"] = _r(7, 4, 22, 22, k)
		lay["numerals"]["cost"] = _fpx(14.0, k)
	boxes["type_icon"] = _r(36, 7, 16, 16, k)
	boxes["chip"] = _r(60, 4, 20, 22, k)
	if info.get("rarity", &"") != &"":
		lay["numerals"]["rarity_letter"] = _fpx(13.0, k)
	# Name band y 26-44: 10 pt caps, one line; short_name if it does not fit; never below 9 pt.
	boxes["band"] = _r(6, 27, 76, 17, k)
	_fit_name(lay, disp, 10.0, 9.0, 72.0, k, 27.0 + 17.0 * 0.5)
	boxes["art"] = _r(8, 46, 72, 40, k)
	if info.get("type", &"item") == &"weapon" and bool(info.get("fires_twice", false)):
		boxes["twice_badge"] = _r(63, 48, 15, 11, k)
	# Brace shield, bottom-left.
	boxes["brace"] = _r(9, 89, 22, 26, k)
	lay["numerals"]["brace"] = _fpx(15.0, k)
	# Right stats: right-aligned, baseline y 109.
	var groups: Array = _stat_groups(false)
	var x: float = 79.0 * k
	var base_y: float = 109.0 * k
	var stats: Array = []
	for i: int in range(groups.size() - 1, -1, -1):
		var g: Dictionary = groups[i]
		var npx: int = _fpx(float(g["pt"]), k)
		var tw: float = num.get_string_size(str(g["value"]), HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x if str(g["value"]) != "" else 0.0
		var pre_w: float = 0.0
		var pre_px: int = 0
		if str(g.get("prefix", "")) != "":
			pre_px = _fpx(float(g["pt"]), k)
			pre_w = disp.get_string_size(str(g["prefix"]), HORIZONTAL_ALIGNMENT_LEFT, -1, pre_px).x + 1.0 * k
		var icon_pt: float = float(g.get("icon_pt", 12.0))
		var iw: float = (icon_pt * k + 2.0 * k) if g.get("icon", &"") != &"" else 0.0
		var gw: float = iw + pre_w + tw
		var left: float = x - gw
		var entry: Dictionary = g.duplicate()
		entry["px"] = npx
		entry["pre_px"] = pre_px
		entry["left"] = left
		entry["base"] = base_y
		entry["icon_rect"] = Rect2(Vector2(left, base_y - npx * 0.36 - icon_pt * k * 0.5), Vector2(icon_pt, icon_pt) * k) if iw > 0.0 else Rect2()
		entry["text_left"] = left + iw
		stats.push_front(entry)
		boxes["stat%d" % i] = Rect2(Vector2(left, base_y - maxf(npx * 0.72, icon_pt * k * 0.5 + npx * 0.36)),
				Vector2(gw, maxf(npx * 0.72, icon_pt * k * 0.5 + npx * 0.36)))
		lay["numerals"]["stat%d_%s" % [i, g["id"]]] = npx
		x = left - 4.0 * k
	lay["stats"] = stats


func _layout_full(lay: Dictionary, k: float) -> void:
	var boxes: Dictionary = lay["boxes"]
	var texts: Dictionary = lay["texts"]
	var type: StringName = info.get("type", &"item")
	if face_down:
		return
	var disp: Font = CzArtKit.font_display()
	var num: Font = CzArtKit.font_numeral()
	var mono: Font = CzArtKit.font_mono()
	if type == &"hit" or type == &"bounty":
		boxes["band"] = _r(6, 4, 212, 66, k)
		texts["band_word"] = _fpx(36.0, k)
	else:
		if int(info.get("cost", -1)) >= 0:
			boxes["cost"] = _r(8, 4, 36, 36, k)
			lay["numerals"]["cost"] = _fpx(24.0, k)
			var cp: int = _fpx(9.0, k)
			texts["cost_caption"] = cp
			boxes["cost_caption"] = _text_box(disp, "SEARCH", cp, 48.0 * k, 26.0 * k)
		boxes["type_icon"] = _r(98, 5, 24, 24, k)
		var tp: int = _fpx(11.0, k)
		texts["type_word"] = tp
		var tw: String = CzArtKit.TYPE_WORDS.get(type, "ITEM")
		var tww: float = disp.get_string_size(tw, HORIZONTAL_ALIGNMENT_LEFT, -1, tp).x
		boxes["type_word"] = _text_box(disp, tw, tp, 110.0 * k - tww * 0.5, 41.0 * k)
		boxes["chip"] = _r(174, 4, 40, 36, k)
		var rar: Dictionary = CzArtKit.rarity(info.get("rarity", &""))
		if not rar.is_empty():
			lay["numerals"]["rarity_letter"] = _fpx(22.0, k)
			var wp: int = _fpx(9.0, k)
			texts["rarity_word"] = wp
			var ww: float = disp.get_string_size(str(rar["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, wp).x
			boxes["rarity_word"] = _text_box(disp, str(rar["name"]), wp, 169.0 * k - ww, 16.0 * k)
			boxes["ticks"] = _r(169.0 - 5.0 * 7.0 + 2.0, 21, 5.0 * 7.0 - 2.0, 4, k)
		else:
			texts["rarity_word"] = 0
		boxes["band"] = _r(6, 45, 212, 25, k)
		_fit_name(lay, disp, 18.0, 14.0, 204.0, k, 45.0 + 25.0 * 0.5)
	boxes["art"] = _r(8, 72, 204, 120, k)
	# Stat bar under the art: Brace shield (left) + groups right-aligned.
	if type != &"hit" and type != &"bounty":
		boxes["brace"] = _r(10, 197, 28, 32, k)
		lay["numerals"]["brace"] = _fpx(24.0, k)
		var bc: int = _fpx(9.0, k)
		texts["brace_caption"] = bc
		boxes["brace_caption"] = _text_box(disp, "BRACE", bc, 42.0 * k, 222.0 * k)
	var groups: Array = _stat_groups(true)
	var x: float = 212.0 * k
	var base_y: float = 222.0 * k
	var stats: Array = []
	var cap_px: int = _fpx(9.0, k)
	texts["stat_caption"] = cap_px
	for i: int in range(groups.size() - 1, -1, -1):
		var g: Dictionary = groups[i]
		var npx: int = _fpx(float(g["pt"]), k)
		var value: String = str(g["value"])
		var tw2: float = num.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x if value != "" else 0.0
		var cw: float = disp.get_string_size(str(g["caption"]), HORIZONTAL_ALIGNMENT_LEFT, -1, cap_px).x
		var iw: float = 20.0 * k
		var top_w: float = iw + tw2
		var gw: float = maxf(top_w, cw)
		var left: float = x - gw
		var entry: Dictionary = g.duplicate()
		entry["px"] = npx
		entry["left"] = left
		entry["base"] = base_y
		entry["icon_rect"] = Rect2(Vector2(left, base_y - npx * 0.36 - 9.0 * k), Vector2(18, 18) * k)
		entry["text_left"] = left + iw
		entry["caption_left"] = left
		entry["caption_px"] = cap_px
		entry["caption_base"] = base_y + 11.0 * k
		stats.push_front(entry)
		boxes["stat%d" % i] = Rect2(Vector2(left, base_y - npx * 0.72), Vector2(gw, npx * 0.72 + 11.0 * k))
		lay["numerals"]["stat%d_%s" % [i, g["id"]]] = npx
		x = left - 10.0 * k
	lay["stats"] = stats
	# Effect text, id, attach strip.
	texts["effect"] = _fpx(12.0, k)
	boxes["effect"] = _r(10, 235, 200, 54, k)
	var ip: int = _fpx(9.0, k)
	texts["card_id"] = ip
	var cid: String = str(info.get("id", ""))
	if cid != "":
		boxes["card_id"] = _text_box(mono, cid, ip, 10.0 * k, 300.0 * k)
	if type == &"attachment" or type == &"weapon":
		boxes["attach_strip"] = _r(128, 289, 80, 15, k)
		texts["attach_strip"] = _fpx(10.0, k)


## Name fitting: start at pt_max, try short_name, shrink to pt_min, then ellipsize.
func _fit_name(lay: Dictionary, font: Font, pt_max: float, pt_min: float, avail_pt: float, k: float, centre_y_pt: float) -> void:
	var avail: float = avail_pt * k
	var name: String = str(info.get("name", "")).to_upper()
	var short: String = str(info.get("short_name", "")).to_upper()
	var px: int = _fpx(pt_max, k)
	var shown: String = name
	if font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > avail and short != "":
		shown = short
	var min_px: int = _fpx(pt_min, k)
	while px > min_px and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > avail:
		px -= 1
	var fits: bool = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= avail
	if not fits:
		while shown.length() > 1 and font.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > avail:
			shown = shown.substr(0, shown.length() - 1)
		shown += "…"
	var w: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base: float = centre_y_pt * k + float(px) * 0.36
	lay["name_text"] = shown
	lay["name_fits"] = fits
	lay["texts"]["name"] = px
	lay["boxes"]["name"] = _text_box(font, shown, px, size.x * 0.5 + 1.0 * k - w * 0.5, base)


## Stat groups shown bottom-right (compact) / in the stat bar (full):
##   {id, icon, value, pt, prefix?, caption}
func _stat_groups(full: bool) -> Array:
	var out: Array = []
	var type: StringName = info.get("type", &"item")
	var big: float = 24.0 if full else 15.0
	if type == &"weapon":
		out.append({"id": "dmg", "icon": &"damage", "value": str(maxi(0, int(info["dmg"]))), "pt": big, "caption": "DMG", "icon_pt": 13.0})
		var rng: String = str(maxi(0, int(info["rng"])))
		if full:
			out.append({"id": "rng", "icon": &"range", "value": rng, "pt": big, "caption": "RNG"})
		else:
			out.append({"id": "rng", "icon": &"", "prefix": "R", "value": rng, "pt": 12.0, "caption": "RNG"})
		# Compact: "fires twice" is a badge on the art window (no room in the stat row).
		if bool(info.get("fires_twice", false)) and full:
			out.append({"id": "twice", "icon": &"fires_twice", "value": "2", "pt": big, "caption": "SHOTS"})
		return out
	if type == &"attachment":
		var a: Dictionary = info.get("attach", {})
		if int(a.get("dmg", 0)) != 0:
			out.append({"id": "dmg", "icon": &"damage", "value": "%+d" % int(a["dmg"]), "pt": big, "caption": "DMG"})
		if int(a.get("rng", 0)) != 0:
			out.append({"id": "rng", "icon": &"range", "value": "%+d" % int(a["rng"]), "pt": big, "caption": "RNG"})
		if bool(a.get("extra_shot", false)):
			out.append({"id": "twice", "icon": &"fires_twice", "value": "+1", "pt": big, "caption": "SHOT"})
		if bool(a.get("no_brace", false)):
			out.append({"id": "nobrace", "icon": &"spent", "value": "0", "pt": big, "caption": "BRACE"})
		if out.is_empty():
			out.append({"id": "attach", "icon": &"attach", "value": "", "pt": big, "caption": "ATTACH"})
		return out
	if type == &"hit":
		if full:
			out.append({"id": "move", "icon": &"move", "value": "1", "pt": big, "caption": "MOVE"})
			out.append({"id": "search", "icon": &"search", "value": "1", "pt": big, "caption": "OR SEARCH"})
			out.append({"id": "down", "icon": &"down", "value": "+1", "pt": big, "caption": "DOWN"})
		return out
	if type == &"bounty":
		if full:
			out.append({"id": "heal", "icon": &"heal", "value": "1", "pt": big, "caption": "HEAL"})
			out.append({"id": "final", "icon": &"final_circle", "value": "+1", "pt": big, "caption": "FINAL HIT"})
		return out
	# Items: main effects in priority order, two on compact, three on the inspector.
	for spec: Array in [["blast", &"damage", "BLAST"], ["heal", &"heal", "HEAL"], ["move", &"move", "MOVE"], ["search", &"search", "SEARCH"], ["pull", &"pull", "PULL"]]:
		var v: int = int(info.get(spec[0], 0))
		if v > 0:
			out.append({"id": spec[0], "icon": spec[1], "value": str(v), "pt": big, "caption": spec[2]})
	var cap: int = 3 if full else 2
	if out.size() > cap:
		out.resize(cap)
	return out


# --- Drawing ---------------------------------------------------------------------------------------
func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var xf: Transform2D = get_viewport().get_screen_transform() * get_global_transform_with_canvas()
	return maxf(1.0, maxf(absf(xf.get_scale().x), absf(xf.get_scale().y)))


func _icon(name: StringName, rect: Rect2, col: Color) -> void:
	var tex: Texture2D = CzIcons.get_icon(name, maxf(rect.size.x, rect.size.y) * _screen_scale())
	if tex != null:
		draw_texture_rect(tex, rect, false, col)


func _text_centred(font: Font, text: String, px: int, centre: Vector2, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(centre.x - w * 0.5, centre.y + float(px) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	var lay: Dictionary = _layout if not _layout.is_empty() else _compute_layout()
	var k: float = lay["k"]
	var full: bool = lay["mode"] == "full"
	var rect := Rect2(Vector2.ZERO, size)
	var cut: float = CzArtKit.CARD_CUT_PT * k
	var bw: float = CzArtKit.CARD_BORDER_PT * k
	var type: StringName = info.get("type", &"item")
	_draw_attach_tabs(k)
	# Selection / held outlines sit outside the plate.
	if selected:
		CzArtKit.draw_tag(self, rect.grow(4.0 * k), cut + 2.0 * k, Color(0, 0, 0, 0), CzArtKit.PAPER, 2.0 * k)
	if held:
		CzArtKit.draw_tag(self, rect.grow(2.0 * k), cut + 1.0 * k, Color(0, 0, 0, 0), CzArtKit.ZONE_EDGE, 2.0 * k)
	# Plate, then face content, then the border on top.
	var pts: PackedVector2Array = CzArtKit.tag_points(rect, cut)
	draw_colored_polygon(pts, CzArtKit.PAPER)
	if face_down:
		CzCardArt.draw_back(self, rect.grow(-bw), k, _screen_scale())
		CzArtKit.draw_tag(self, rect, cut, Color(0, 0, 0, 0), CzArtKit.INK, bw)
		_draw_held_tag(k)
		return
	var stripe_col: Color = CzArtKit.HIT_RED if type == &"hit" else (CzArtKit.INK if type == &"bounty" else CzArtKit.rarity_color(info.get("rarity", &"")))
	var stripe := Rect2(Vector2(bw, cut), Vector2(CzArtKit.CARD_STRIPE_PT * k, size.y - cut - bw - 1.0))
	draw_rect(stripe, stripe_col)
	var boxes: Dictionary = lay["boxes"]
	if boxes.has("art"):
		CzCardArt.draw_art(self, boxes["art"], info, full, k, _screen_scale())
	if type == &"hit" or type == &"bounty":
		_draw_special(lay, k, full)
	else:
		_draw_header(lay, k, full)
		_draw_bottom(lay, k, full)
	CzArtKit.draw_tag(self, rect, cut, Color(0, 0, 0, 0), CzArtKit.INK, bw)
	if dimmed:
		draw_colored_polygon(pts, Color(CzArtKit.ZONE_VIOLET, 0.55))
	if down:
		draw_down_badge(self, Rect2(Vector2(-6.0, -6.0) * k, Vector2(26.0, 20.0) * k), k)
	_draw_held_tag(k)


func _draw_held_tag(k: float) -> void:
	if not held:
		return
	var r := Rect2(Vector2(size.x * 0.5 - 15.0 * k, -9.0 * k), Vector2(30.0, 13.0) * k)
	CzArtKit.draw_tag(self, r, 3.0 * k, CzArtKit.ZONE_EDGE, CzArtKit.INK, maxf(1.0, 1.0 * k))
	_text_centred(CzArtKit.font_display(), "HOLD", _fpx(9.0, k), r.get_center(), CzArtKit.INK)


## Attachment tabs under a weapon: clipped tags with "+1 DMG" at 12 pt.
func _draw_attach_tabs(k: float) -> void:
	if attachments.is_empty():
		return
	var font: Font = CzArtKit.font_display()
	for i: int in attachments.size():
		var a: Variant = attachments[i]
		var label: String = str(a) if not (a is Dictionary) else CzCardArt.attach_text((a as Dictionary).get("attach", a))
		var y: float = size.y - 4.0 * k + float(i) * ATTACH_TAB_PT * k
		var r := Rect2(Vector2(8.0 * k, y), Vector2(size.x - 16.0 * k, ATTACH_TAB_PT * k + 4.0 * k))
		CzArtKit.draw_tag(self, r, 3.0 * k, CzArtKit.BRACE_STEEL, CzArtKit.INK, maxf(1.0, 1.5 * k))
		_text_centred(font, label.to_upper(), _fpx(12.0, k), r.get_center() + Vector2(0, 2.0 * k), CzArtKit.INK)


func _draw_header(lay: Dictionary, k: float, full: bool) -> void:
	var boxes: Dictionary = lay["boxes"]
	var num: Font = CzArtKit.font_numeral()
	var disp: Font = CzArtKit.font_display()
	var type: StringName = info.get("type", &"item")
	if boxes.has("cost"):
		var cr: Rect2 = boxes["cost"]
		draw_circle(cr.get_center(), cr.size.x * 0.5, CzArtKit.INK)
		if bool(info.get("drop", false)):
			draw_arc(cr.get_center(), cr.size.x * 0.5 - 2.5 * k, 0.0, TAU, 32, Color(CzArtKit.PAPER, 0.7), maxf(1.0, 1.0 * k), true)
		_text_centred(num, str(info["cost"]), lay["numerals"]["cost"], cr.get_center(), CzArtKit.PAPER)
		if full and boxes.has("cost_caption"):
			var cb: Rect2 = boxes["cost_caption"]
			draw_string(disp, Vector2(cb.position.x, cb.end.y), "SEARCH", HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["cost_caption"], CzArtKit.INK)
	_icon(type, boxes["type_icon"], CzArtKit.INK)
	if full and boxes.has("type_word"):
		var tb: Rect2 = boxes["type_word"]
		draw_string(disp, Vector2(tb.position.x, tb.end.y), CzArtKit.TYPE_WORDS.get(type, "ITEM"), HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["type_word"], CzArtKit.INK)
	# Rarity chip: clipped tag, 1.5 pt ink outline, letter. Starter: empty dashed outline.
	var chip: Rect2 = boxes["chip"]
	var rar: Dictionary = CzArtKit.rarity(info.get("rarity", &""))
	var ccut: float = (5.0 if not full else 8.0) * k
	if rar.is_empty():
		CzArtKit.draw_tag(self, chip.grow(-1.0 * k), ccut, Color(0, 0, 0, 0), Color(CzArtKit.INK, 0.55), maxf(1.0, 1.5 * k), true, 3.0 * k)
	else:
		CzArtKit.draw_tag(self, chip, ccut, rar["color"], CzArtKit.INK, maxf(1.0, 1.5 * k))
		_text_centred(disp, rar["letter"], lay["numerals"]["rarity_letter"], chip.get_center() + Vector2(0, 0.5 * k), rar["text"])
		if full:
			var wb: Rect2 = boxes["rarity_word"]
			draw_string(disp, Vector2(wb.position.x, wb.end.y), rar["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["rarity_word"], CzArtKit.INK)
			var tb2: Rect2 = boxes["ticks"]
			for i: int in 5:
				var t := Rect2(Vector2(tb2.position.x + float(i) * 7.0 * k, tb2.position.y), Vector2(5.0, 4.0) * k)
				if i < int(rar["ticks"]):
					draw_rect(t, CzArtKit.INK)
				else:
					draw_rect(t, Color(CzArtKit.INK, 0.18))
	# Name band.
	var band: Rect2 = boxes["band"]
	draw_rect(band, CzArtKit.INK)
	var nb: Rect2 = boxes["name"]
	draw_string(disp, Vector2(nb.position.x, nb.end.y), lay["name_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["name"], CzArtKit.PAPER)


func _draw_bottom(lay: Dictionary, k: float, full: bool) -> void:
	var boxes: Dictionary = lay["boxes"]
	var num: Font = CzArtKit.font_numeral()
	var disp: Font = CzArtKit.font_display()
	# Brace shield: steel with the value; no Brace = 30 % ghost with "-".
	var br: Rect2 = boxes["brace"]
	var bv: int = int(info.get("brace", -1))
	var has_brace: bool = bv > 0
	var spts: PackedVector2Array = CzArtKit.shield_points(br)
	var alpha: float = 1.0 if has_brace else 0.3
	draw_colored_polygon(spts, Color(CzArtKit.BRACE_STEEL, alpha))
	var closed: PackedVector2Array = spts.duplicate()
	closed.append(spts[0])
	draw_polyline(closed, Color(CzArtKit.INK, 0.9 * alpha + 0.1), maxf(1.0, 1.5 * k), true)
	var ctr: Vector2 = br.get_center() - Vector2(0, br.size.y * 0.06)
	_text_centred(num, str(bv) if has_brace else "–", lay["numerals"]["brace"], ctr, Color(CzArtKit.INK, 1.0 if has_brace else 0.45))
	if full and boxes.has("brace_caption"):
		var bc: Rect2 = boxes["brace_caption"]
		draw_string(disp, Vector2(bc.position.x, bc.end.y), "BRACE", HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["brace_caption"], Color(CzArtKit.INK, 0.8))
	_draw_stats(lay, k, full)
	if boxes.has("twice_badge"):
		var tb: Rect2 = boxes["twice_badge"]
		CzArtKit.draw_tag(self, tb, 3.0 * k, CzArtKit.INK)
		_icon(&"fires_twice", Rect2(tb.get_center() - Vector2(4.5, 4.5) * k, Vector2(9, 9) * k), CzArtKit.PAPER)
	if full:
		_draw_inspector_footer(lay, k)


func _draw_stats(lay: Dictionary, k: float, full: bool) -> void:
	var num: Font = CzArtKit.font_numeral()
	var disp: Font = CzArtKit.font_display()
	for g: Dictionary in lay["stats"]:
		var icon: StringName = g.get("icon", &"")
		var col: Color = CzArtKit.HIT_RED if g["id"] == "dmg" or g["id"] == "blast" else CzArtKit.INK
		if icon != &"":
			_icon(icon, g["icon_rect"], col)
		var x: float = g["text_left"]
		if str(g.get("prefix", "")) != "":
			draw_string(disp, Vector2(x, g["base"]), g["prefix"], HORIZONTAL_ALIGNMENT_LEFT, -1, g["pre_px"], CzArtKit.INK)
			x += disp.get_string_size(g["prefix"], HORIZONTAL_ALIGNMENT_LEFT, -1, g["pre_px"]).x + 1.0 * k
		if str(g["value"]) != "":
			draw_string(num, Vector2(x, g["base"]), str(g["value"]), HORIZONTAL_ALIGNMENT_LEFT, -1, g["px"], CzArtKit.INK)
		if full:
			draw_string(disp, Vector2(g["caption_left"], g["caption_base"]), str(g["caption"]), HORIZONTAL_ALIGNMENT_LEFT, -1, g["caption_px"], Color(CzArtKit.INK, 0.75))


func _draw_inspector_footer(lay: Dictionary, k: float) -> void:
	var boxes: Dictionary = lay["boxes"]
	if boxes.has("card_id"):
		var ib: Rect2 = boxes["card_id"]
		draw_string(CzArtKit.font_mono(), Vector2(ib.position.x, ib.end.y), str(info.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["card_id"], Color(CzArtKit.INK, 0.7))
	if boxes.has("attach_strip"):
		var ar: Rect2 = boxes["attach_strip"]
		var type: StringName = info.get("type", &"item")
		var text: String = str(info.get("attach_text", "")) if type == &"attachment" else "ATTACH ▼"
		if text == "":
			text = "ATTACH ▼"
		CzArtKit.draw_tag(self, ar, 3.0 * k, CzArtKit.BRACE_STEEL if type == &"attachment" else Color(0, 0, 0, 0), Color(CzArtKit.INK, 0.6), maxf(1.0, 1.0 * k), type != &"attachment", 3.0 * k)
		_text_centred(CzArtKit.font_display(), text.to_upper(), lay["texts"]["attach_strip"], ar.get_center(), CzArtKit.INK)


## Hit (hit_red band, broken shield, HIT, Adrenaline) and Bounty (ink band, target tag).
func _draw_special(lay: Dictionary, k: float, full: bool) -> void:
	var boxes: Dictionary = lay["boxes"]
	var type: StringName = info.get("type", &"hit")
	var band: Rect2 = boxes["band"]
	var hit: bool = type == &"hit"
	draw_rect(band, CzArtKit.HIT_RED if hit else CzArtKit.INK)
	var disp: Font = CzArtKit.font_display()
	var word: String = "HIT" if hit else "BOUNTY"
	var wp: int = lay["texts"]["band_word"]
	var ww: float = disp.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wp).x
	var ip: float = float(wp) * 0.95
	var total: float = ip + 4.0 * k + ww
	var x0: float = band.get_center().x - total * 0.5
	var col: Color = CzArtKit.PAPER
	_icon(type, Rect2(Vector2(x0, band.get_center().y - ip * 0.5), Vector2(ip, ip)), col)
	draw_string(disp, Vector2(x0 + ip + 4.0 * k, band.get_center().y + float(wp) * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, wp, col)
	if not full:
		var lines: PackedStringArray = lay["lines"]
		for i: int in lines.size():
			var lb: Rect2 = boxes["line%d" % i]
			draw_string(disp, Vector2(lb.position.x, lb.end.y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lay["texts"]["lines"], CzArtKit.INK if i == 1 else Color(CzArtKit.INK, 0.75))
		return
	_draw_stats(lay, k, true)
	_draw_inspector_footer(lay, k)


## Down badge (section 3): a hit_red downward chevron plus "+1". Usable anywhere (player panels too).
static func draw_down_badge(ci: CanvasItem, r: Rect2, k: float) -> void:
	CzArtKit.draw_tag(ci, r, 4.0 * k, CzArtKit.HIT_RED, CzArtKit.INK, maxf(1.0, 1.2 * k))
	var h: float = r.size.y
	var c := Vector2(r.position.x + h * 0.55, r.get_center().y)
	var chev := PackedVector2Array([c + Vector2(-h * 0.3, -h * 0.22), c + Vector2(0, h * 0.06), c + Vector2(h * 0.3, -h * 0.22),
			c + Vector2(h * 0.3, h * 0.0), c + Vector2(0, h * 0.28), c + Vector2(-h * 0.3, h * 0.0)])
	ci.draw_colored_polygon(chev, CzArtKit.PAPER)
	var px: int = maxi(1, int(ceilf(h * 0.6)))
	ci.draw_string(CzArtKit.font_numeral(), Vector2(r.position.x + h * 0.95, r.get_center().y + px * 0.36), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, px, CzArtKit.PAPER)


# --- Input -----------------------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			inspect_requested.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_t = Time.get_ticks_msec() / 1000.0
				_press_in_hold = hold_enabled and hold_hit_rect().has_point(mb.position)
			elif _press_t >= 0.0:
				var held_s: float = Time.get_ticks_msec() / 1000.0 - _press_t
				_press_t = -1.0
				if held_s >= LONG_PRESS_S:
					inspect_requested.emit(self)
				elif _press_in_hold:
					held = not held
					hold_toggled.emit(self, held)
				else:
					tapped.emit(self)
				accept_event()
