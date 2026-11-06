# card_lore.gd
# Purpose: kc-hand-y2 (the head: "if a card has no effect, just put some lore text in italic and dark
#   gray at the bottom of the text box"). One short, original flavour line per card id; the Y2+ card
#   (CardView) shows it only when the card has no keyword, no Trains line and no effect text. Every
#   unit has a line so a card that loses its effect (a rules cut) still reads.
#   UI-owned table (no CardData field): the designer can move it into the data later.
# Usage: CardLore.line(&"si_grunt")  # "" when none
# Dependencies: none.
# Author: UI/UX Agent (kc-hand-y2)
class_name CardLore
extends RefCounted

const LINES: Dictionary = {
	# Standard Issue (the quartermaster's kit).
	&"si_grunt": "Signed for one rifle, one helmet, no questions.",
	&"si_trooper": "Third tour, same boots. The boots are holding up better.",
	&"si_armored": "The plate is older than he is. Both still stop rounds.",
	&"si_sergeant": "Counts heads before the drop and after. Hates the difference.",
	# Calling-card units.
	&"rifleman": "Point, breathe, squeeze. Everything else is noise.",
	&"brawler": "Swapped his manual for a shotgun and never looked back.",
	&"breacher": "Doors are just walls that haven't met him yet.",
	&"point_man": "First in, eyes open, mouth shut.",
	&"flanker": "If you can see him coming, he took the wrong route.",
	&"marksman": "Six hundred metres is a conversation, not a distance.",
	&"gunner": "Carries the noise so the squad can carry on.",
	&"combat_medic": "Patched more holes than the quartermaster.",
	&"demolitions_expert": "Measures twice. Wires once. Leaves early.",
	&"recon_specialist": "Knows the map better than the people who drew it.",
	&"sentry": "Bored, cold and awake. The job is the last one.",
	&"shieldman": "Walks into the fire so others can walk out of it.",
	&"halek_wren": "Wren doesn't miss. Wren just waits longer.",
	&"okafor_anvil": "When Anvil plants his feet, the line stops moving.",
}
## When a card has no line of its own.
const UNIT_FALLBACK: String = "Another name on the roster. Make it count."
const SI_FALLBACK: String = "Issued, signed for, expected back in one piece."


## The lore line of a card id ("" for none). standard_issue picks the quartermaster's fallback.
static func line(card_id: StringName, standard_issue: bool = false, unit: bool = true) -> String:
	if LINES.has(card_id):
		return String(LINES[card_id])
	if standard_issue:
		return SI_FALLBACK
	return UNIT_FALLBACK if unit else ""
