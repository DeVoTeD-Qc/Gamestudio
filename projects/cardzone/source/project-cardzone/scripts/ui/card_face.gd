# card_face.gd
# Purpose: THIN PLACEHOLDER card face for the cz10 match layout. It is not the card renderer:
#   cz16 (Technical Artist) builds the real card scene (scenes/card/**, scripts/art/**). To swap,
#   give MatchCardButton.FACE_SCRIPT a script/scene with the same three members:
#     configure(card: Dictionary, size_class: StringName)  # &"hand" | &"mini" | &"big"
#     layout_report() -> Dictionary                         # {"numeral_px": int} for the layout tests
#     mouse_filter = MOUSE_FILTER_IGNORE                    # the button owns input
#   Content follows art-direction.md §3 (compact card): cost top-left, rarity letter top-right,
#   name, Brace shield bottom-left, main stat bottom-right. Hits get the red band + ADRENALINE,
#   card backs (the rival's hidden cards) show HIDDEN. Starters show no rarity chip.
# Dependencies: match_theme.gd (variations CardFace*, Card*, TagBrace).
# Author: UI/UX Agent (cz10)
extends PanelContainer

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")

## Font sizes per size class: [cost/brace numerals, name, stat].
const SIZES: Dictionary = {&"mini": [24, 16, 16], &"hand": [24, 16, 18], &"big": [40, 24, 28]}

var card: Dictionary = {}
var size_class: StringName = &"hand"
var _numeral_px: int = 24

var _cost: Label
var _rarity: Label
var _name: Label
var _sub: Label
var _brace: Label
var _stat: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_cost = _label(top, &"CardNumber")
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	_rarity = _label(top, &"TagChip")
	_name = _label(col, &"CardName")
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# No autowrap: a wrapping label measured before it has a width reports a huge height.
	_sub = _label(col, &"CardText")
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	_brace = _label(bottom, &"TagBrace")
	var gap2: Control = Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap2)
	_stat = _label(bottom, &"CardText")


func configure(c: Dictionary, size_cls: StringName = &"hand") -> void:
	card = c
	size_class = size_cls
	var s: Array = SIZES.get(size_cls, SIZES[&"hand"])
	_numeral_px = s[0]
	for l: Label in [_cost, _brace]:
		l.add_theme_font_size_override(&"font_size", s[0])
	_name.add_theme_font_size_override(&"font_size", s[1])
	_stat.add_theme_font_size_override(&"font_size", s[2])
	_rarity.add_theme_font_size_override(&"font_size", 16 if size_cls != &"big" else 24)
	var type: StringName = c.get("type", &"")
	var hidden: bool = c.get("hidden", false)
	queue_redraw()
	theme_type_variation = &"CardFaceBack" if hidden else (&"CardFaceHit" if type == &"hit" else &"CardFace")
	_name.text = ""
	_sub.text = ""
	_cost.text = ""
	_stat.text = ""
	_brace.visible = false
	_rarity.visible = false
	# Mini cards: one-line name (the inspector has the full name).
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF if size_cls == &"mini" else TextServer.AUTOWRAP_WORD_SMART
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if size_cls == &"mini" else TextServer.OVERRUN_NO_TRIMMING
	_name.add_theme_color_override(&"font_color", MatchTheme.PAPER if hidden else MatchTheme.INK)
	if hidden:
		_name.text = "HIDDEN"
		_sub.text = "" if size_cls == &"mini" else "Held card"
		_sub.add_theme_color_override(&"font_color", MatchTheme.PAPER)
		_sub.visible = _sub.text != ""
		return
	_sub.remove_theme_color_override(&"font_color")
	if type == &"hit":
		_name.text = "HIT"
		_sub.text = "" if size_cls == &"mini" else ("Adrenaline" if size_cls == &"hand" else "ADRENALINE\nMove 1 or Search 1")
		_stat.text = "M1/S1"
		_sub.visible = _sub.text != ""
		return
	var cost: int = int(c.get("cost", -1))
	_cost.text = str(cost) if cost >= 0 else ""
	var rarity: StringName = c.get("rarity", &"S")
	if rarity != &"S":
		_rarity.visible = true
		_rarity.text = String(rarity)
		var cols: Array = MatchTheme.rarity_colors(rarity)
		var chip: StyleBoxFlat = StyleBoxFlat.new()
		chip.bg_color = cols[0]
		chip.border_color = MatchTheme.INK
		chip.set_border_width_all(2)
		chip.set_corner_radius_all(3)
		chip.content_margin_left = 5
		chip.content_margin_right = 5
		chip.content_margin_top = 0
		chip.content_margin_bottom = 0
		_rarity.add_theme_stylebox_override(&"normal", chip)
		_rarity.add_theme_color_override(&"font_color", cols[1])
	var nm: String = String(c.get("short", c.get("name", ""))) if size_cls != &"big" else String(c.get("name", ""))
	# Mini cards use the mixed-case short name: caps of the default font run ~25 % wider and
	# web text at 3x oversampling can draw a little wider than it measures.
	_name.text = nm if size_cls == &"mini" else nm.to_upper()
	var brace: int = int(c.get("brace", 0))
	if brace > 0:
		_brace.visible = true
		_brace.text = str(brace)
	_stat.text = main_stat(c)
	# Mini cards with a Brace shield keep only the first effect (the inspector lists all).
	if size_cls == &"mini" and brace > 0 and " " in _stat.text and c.get("type", &"") != &"weapon":
		_stat.text = _stat.text.get_slice(" ", 0)
	if size_cls != &"mini":
		var att: Array = c.get("attached", [])
		if not att.is_empty():
			_sub.text = "+ %s" % "\n+ ".join(att)
		elif type == &"attachment":
			_sub.text = String(c.get("bonus", ""))
	# Empty labels still take a line; hide them so small cards keep their room.
	_sub.visible = _sub.text != ""


## Short main effect for the bottom-right corner (icons replace this in cz16).
static func main_stat(c: Dictionary) -> String:
	match c.get("type", &""):
		&"weapon":
			return "D%d R%d" % [int(c.get("dmg", 0)), int(c.get("rng", 0))]
		&"attachment":
			return String(c.get("bonus", ""))
	var parts: PackedStringArray = []
	if c.has("move"):
		parts.append("M%d" % int(c["move"]))
	if c.has("search"):
		parts.append("S%d" % int(c["search"]))
	if c.has("heal"):
		parts.append("H%d" % int(c["heal"]))
	if c.has("dmg"):
		parts.append("D%d" % int(c["dmg"]))
	return " ".join(parts)


## Rarity stripe on the left edge: still shows when a fanned card's right side is covered.
func _draw() -> void:
	var r: StringName = card.get("rarity", &"S")
	if card.get("hidden", false) or r == &"S" or card.get("type", &"") == &"hit":
		return
	draw_rect(Rect2(2, 2, 5, size.y - 4), MatchTheme.rarity_colors(r)[0])


func layout_report() -> Dictionary:
	return {"numeral_px": _numeral_px}


func get_labels() -> Array[Label]:
	return [_cost, _rarity, _name, _sub, _brace, _stat]


func _label(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
