# card_lore.gd
# Purpose: kc-hand-y2 (the head: "if a card has no effect, just put some lore text in italic and dark
#   gray at the bottom of the text box"). One short, original flavour line per card id; the Y2+ card
#   (CardView) shows it only when the card has no keyword and no effect text. Every
#   unit has a line so a card that loses its effect (a rules cut) still reads.
#   UI-owned table (no CardData field): the designer can move it into the data later.
# Usage: CardLore.line(&"si_grunt")  # "" when none
# Dependencies: none.
# Author: UI/UX Agent (kc-hand-y2)
class_name CardLore
extends RefCounted

const LINES: Dictionary = {
	# kc-text (the head: "a different lore for each" vanilla card): every card with no keyword and no
	# effect has its own line, at most 12 words, gritty military humour, original (no franchise names).
	# Standard Issue (the quartermaster's kit).
	&"si_grunt": "Signed for one rifle, one helmet and zero questions.",
	&"si_trooper": "Third tour, same boots. The boots are holding up better.",
	&"si_armored": "The plate is older than he is. Both still stop rounds.",
	&"si_sergeant": "Counts heads before the drop and after. Hates the subtraction.",
	&"kc_wip_private_1": "First day. Still thinks the chin strap is optional.",
	&"kc_wip_private_2": "Learned to dig before he learned to shoot. Digs beautifully.",
	&"kc_wip_private_3": "Survived three ambushes and the mess hall. The mess hall was worse.",
	&"kc_wip_private_4": "Promoted twice, busted twice. Net result: still the new guy.",
	# Calling-card units (vanilla first, then the rest: shown in the inspector only).
	&"rifleman": "Point, breathe, squeeze. Everything else is somebody else's problem.",
	&"brawler": "Ran dry once. The other guy ran out of teeth.",
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


## kc-text: the flavour line for the inspector sheet: the card's own line, but "" for a vanilla card
## (its face already shows the line) and for a card without one (no fallback filler there).
static func flavour(card_id: StringName, vanilla: bool, _standard_issue: bool = false) -> String:
	if vanilla or not LINES.has(card_id):
		return ""
	return String(LINES[card_id])
