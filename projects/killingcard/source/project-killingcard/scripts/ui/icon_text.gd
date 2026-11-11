# icon_text.gd
# Purpose: kc-text (the head: "When an icon means something, it should be used everywhere we talk
#   about that thing, like Supply"). One icon per game concept, shown inline wherever a text names
#   that concept: the card inspector, the glossary, card rules text, rail inspectors, tooltips and
#   the run / Duel screens. A text keeps its words; the concept's icon goes in front of the first
#   mention in each block (later mentions stay plain, so a line never turns into an icon row).
#   The table is documentation/design/text-and-icons.md; keep both in sync.
# Usage:
#   var l := IconText.make("Costs 2 Supply.", 18)        # a RichTextLabel with the icons inline
#   IconText.fill(rich_label, "Each hit deals 1 less (Cover).", 18, ink)
#   IconText.plain(node)   # the words of a Label or an IconText label (tests, accessibility)
#   IconText.texture(&"supply")  # the concept's icon as a Texture2D (buttons, chips)
# Dependencies: IconSheet / UiKit (the icon art), hud_theme.tres (fonts via the label's theme).
# Author: Mid Game Designer Agent (kc-text)
class_name IconText
extends RefCounted

## Concept id -> [regex alternatives, icon source, identity colour or null (= text colour)].
## Icon source: an IconSheet / UiKit name, or "svg:<id>" for the built-in glyphs below.
## Order matters: longer words first (killstreak before streak).
const CONCEPTS: Array = [
	[&"killstreak", "[Kk]illstreaks?|KILLSTREAKS?", &"type_killstreak", null],
	[&"streak", "[Ss]treak|STREAK", &"streak", Color("#FFB020")],
	[&"supply", "Supply|SUPPLY", "svg:hex", Color("#FFB020")],
	[&"fp", "FP|Firepower", &"stat_firepower", Color("#2EC4B6")],
	[&"armor", "Armor|ARMOR", &"stat_armor", Color("#B9C2C9")],
	[&"cover", "Cover|COVER", &"kw_cover", null],
	[&"req", "REQ|Requisition", "svg:req", Color("#C2A878")],
	[&"tickets", "Reinforcement Tickets?|[Tt]ickets?|TICKETS?", &"tickets", Color("#C2A878")],
	[&"first_shot", "First Shot", &"kw_first_shot", null],
	[&"pick", "Pick", &"kw_pick", null],
	[&"flank", "Flank", &"kw_flank", null],
	[&"pierce", "Pierce", &"kw_pierce", null],
	[&"suppress", "Suppress", &"kw_suppress", null],
	[&"patch", "Patch", &"kw_patch", null],
	[&"holder", "Holder", &"kw_holder", null],
	[&"on_deploy", "On Deploy", &"trig_on_deploy", null],
	[&"on_down", "On Down", &"trig_on_down", null],
	[&"hidden", "Hidden", &"kw_hidden", null],
	[&"front_line", "Front line", "svg:front", null],
	[&"overrun", "Overrun", &"overrun", null],
]

## Built-in glyphs (64 px, white; tinted at use) for concepts the icon sheet / kit has no art for.
## hex: the cards' cost hexagon (Supply). req: a requisition slip. front: Front line's chevron.
const SVGS: Dictionary = {
	"hex": """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M32 3L57 17.5V46.5L32 61L7 46.5V17.5Z" fill="#FFFFFF"/></svg>""",
	"req": """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"><path d="M12 8H44L54 18V56H12Z"/><path d="M44 8V18H54"/><path d="M21 28H45M21 37H45M21 46H34"/><circle cx="44" cy="47" r="5" fill="#FFFFFF" stroke="none"/></svg>""",
	"front": """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"><path d="M12 34L32 14L52 34"/><path d="M12 52H52"/></svg>""",
}

static var _regex: RegEx = null
static var _tex_cache: Dictionary = {}


## The icon of a concept id (&"supply", &"fp"...) as a Texture2D, or null when it has none.
static func texture(concept: StringName) -> Texture2D:
	if _tex_cache.has(concept):
		return _tex_cache[concept]
	var tex: Texture2D = null
	for row: Array in CONCEPTS:
		if row[0] != concept:
			continue
		var src: Variant = row[2]
		if src is String and String(src).begins_with("svg:"):
			tex = _svg(String(src).substr(4))
		elif IconSheet.has_icon(StringName(src)):
			tex = IconSheet.get_icon(StringName(src))
	_tex_cache[concept] = tex
	return tex


## The identity colour of a concept (the Supply hex is always amber), or `fallback`.
static func color(concept: StringName, fallback: Color) -> Color:
	for row: Array in CONCEPTS:
		if row[0] == concept and row[3] != null:
			return row[3]
	return fallback


## Concept ids, in table order (tests, the doc table).
static func concepts() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Array in CONCEPTS:
		out.append(row[0])
	return out


## The concept a matched word belongs to (&"" when none).
static func concept_of(word: String) -> StringName:
	for row: Array in CONCEPTS:
		var r: RegEx = RegEx.create_from_string("^(?:%s)$" % row[1])
		if r.search(word) != null:
			return row[0]
	return &""


## The first concept a text names (&"" when none): a row titled "Cover N" already shows Cover's icon.
static func first_concept(text: String) -> StringName:
	var m: RegExMatch = _words().search(text)
	return concept_of(m.get_string()) if m != null else &""


## Fills `rtl` with `text`, the concepts' icons inline (first mention per concept). `px` = icon
## size (0: the label's font size); `ink` tints keyword icons (stat icons keep their colour, darkened
## on paper when `paper`). `skip` = concept ids to leave without an icon (a line that already
## shows that icon). The words stay readable in IconText.plain(rtl).
static func fill(rtl: RichTextLabel, text: String, px: int = 0, ink: Color = Color.WHITE, paper: bool = false,
		skip: Array = []) -> void:
	rtl.clear()
	rtl.set_meta(&"plain", text)
	var size: int = px if px > 0 else int(rtl.get_theme_font_size(&"normal_font_size") * 1.05)
	var seen: Array[StringName] = []
	var pos: int = 0
	for m: RegExMatch in _words().search_all(text):
		var word: String = m.get_string()
		var concept: StringName = concept_of(word)
		if concept == &"" or seen.has(concept) or skip.has(concept):
			continue
		var tex: Texture2D = texture(concept)
		if tex == null:
			continue
		seen.append(concept)
		rtl.add_text(text.substr(pos, m.get_start() - pos))
		var tint: Color = color(concept, ink)
		if paper and tint != ink:
			tint = tint.darkened(0.35)
		rtl.add_image(tex, size, size, tint, INLINE_ALIGNMENT_CENTER)
		rtl.add_text(" " + word)
		pos = m.get_end()
	rtl.add_text(text.substr(pos))


## A new wrapped, auto-height RichTextLabel showing `text` with its icons (see fill()).
static func make(text: String, px: int = 0, ink: Color = Color.WHITE, paper: bool = false) -> RichTextLabel:
	var r: RichTextLabel = RichTextLabel.new()
	setup(r)
	r.add_theme_color_override(&"default_color", ink)
	fill(r, text, px, ink, paper)
	return r


## Makes a RichTextLabel behave like a wrapped Label (auto height, no scroll, no selection).
static func setup(r: RichTextLabel) -> void:
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	r.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())


## A custom tooltip body (for a Control's _make_custom_tooltip): the text with its icons.
static func tooltip(for_text: String) -> Control:
	if for_text == "":
		return null
	var r: RichTextLabel = make(for_text, 18, Color("#E6EBEF"))
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF if for_text.length() < 48 else TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(0 if for_text.length() < 48 else 360, 0)
	return r


## kc-text: a Button whose text names one concept with an icon ("BUY · 4 REQ", "NEED 2 SUPPLY")
## gets that icon in front of its words. Returns the concept (&"" when none / the button has an icon).
static func tag_button(b: Button, px: int = 20) -> StringName:
	if b == null or b.icon != null:
		return &""
	var c: StringName = first_concept(b.text)
	var tex: Texture2D = texture(c) if c != &"" else null
	if tex == null:
		return &""
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override(&"icon_max_width", px)
	var tint: Color = color(c, Color.WHITE)
	for st: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color", &"icon_hover_pressed_color"]:
		b.add_theme_color_override(st, tint)
	return c


## A small TextureRect of a concept's icon (chips, counters), tinted with its colour.
static func icon_rect(concept: StringName, px: float = 20.0) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.name = "Icon_%s" % concept
	r.texture = texture(concept)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = color(concept, Color.WHITE)
	return r


## The words of a Label, Button or IconText label ("" for anything else).
static func plain(n: Node) -> String:
	if n == null:
		return ""
	if n.has_meta(&"plain"):
		return String(n.get_meta(&"plain"))
	if n is Label:
		return (n as Label).text
	if n is RichTextLabel:
		return (n as RichTextLabel).get_parsed_text()
	if n is Button:
		return (n as Button).text
	return ""


static func _words() -> RegEx:
	if _regex == null:
		var alts: PackedStringArray = []
		for row: Array in CONCEPTS:
			alts.append(String(row[1]))
		_regex = RegEx.create_from_string("\\b(?:%s)\\b" % "|".join(alts))
	return _regex


static func _svg(id: String) -> Texture2D:
	var img: Image = Image.new()
	img.load_svg_from_string(String(SVGS.get(id, "")), 1.0)
	return ImageTexture.create_from_image(img)
