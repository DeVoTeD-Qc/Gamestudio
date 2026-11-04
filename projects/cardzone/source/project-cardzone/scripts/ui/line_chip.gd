# line_chip.gd
# Purpose: One card in your LINE (played or looted this turn) as a compact chip under the map:
#   name on the first line, the main stat (and attachments) on the second. The line is a record of
#   this turn, so it gets chips, not full cards: three rows of 84x118 pt cards do not fit a 375 pt
#   tall phone (see the cz10 board doc). Tap = select (cz11: fire / attach), long-press / right-click
#   / INFO = inspector with the full card.
# Dependencies: tap_hold_button.gd.
# Author: UI/UX Agent (cz10)
extends "res://scripts/ui/tap_hold_button.gd"

var card: CardData
var card_id: StringName = &""
var attached: Array[CardData] = []
var index: int = 0
var selected: bool = false:
	set(v):
		selected = v
		# Selected: the pressed plate plus a thick outline (not colour alone).
		if v:
			var box: StyleBox = get_theme_stylebox(&"pressed").duplicate()
			if box is StyleBoxFlat:
				(box as StyleBoxFlat).set_border_width_all(4)
			add_theme_stylebox_override(&"normal", box)
		else:
			remove_theme_stylebox_override(&"normal")


func _init() -> void:
	super._init()
	theme_type_variation = &"LineChip"
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_to_group(&"tap_target")


func setup(c: CardData, att: Array[CardData], i: int) -> void:
	card = c
	card_id = c.id if c != null else &""
	attached = att
	index = i
	var line2: String = stat_line(c)
	if not att.is_empty():
		line2 += "  +%d att" % att.size()
	text = "%s\n%s" % [c.display_name if c != null else "?", line2]


## "DMG 2 · RNG 1", "Search 2", "Move 1 · Heal 1"... (cz16 icons may replace this text later).
static func stat_line(c: CardData) -> String:
	if c == null:
		return ""
	if c.is_weapon():
		return "DMG %d · RNG %d" % [c.dmg, c.rng]
	var parts: PackedStringArray = []
	for k: String in ["move", "search", "heal", "pull"]:
		if int(c.get(k)) > 0:
			parts.append("%s %d" % [k.capitalize(), int(c.get(k))])
	if c.brace > 0:
		parts.append("Brace %d" % c.brace)
	if c.is_attachment():
		parts.append("Attach")
	return " · ".join(parts)

