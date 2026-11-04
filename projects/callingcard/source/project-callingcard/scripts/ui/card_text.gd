# card_text.gd
# Purpose: Player-facing words for a card (spec §3, §4.4): Clearance names, origin and trait
#   labels, trait rule text, value captions. Used by the card view and the inspector.
#   Works on the UI card Dictionary (see mock_duel_data.gd for the fields). When cc02's
#   CardData lands, cc08 converts CardData to this Dictionary (or extends these helpers);
#   the rule text here is the spec wording and must stay in sync with it.
# Dependencies: none.
# Author: UI/UX Agent (cc07)
extends RefCounted

const CLEARANCE_NAMES: Array[String] = ["", "Issue", "Merit", "Distinction", "Legend"]

const ORIGIN_NAMES: Dictionary = {
	&"challenge": "Challenge", &"mastery": "Mastery", &"event": "Event", &"prestige": "Prestige",
	&"ranked": "Ranked", &"secret": "Secret", &"showcase": "Showcase (store)",
}

const TRAIT_NAMES: Dictionary = {
	&"steady": "Steady", &"veteran": "Veteran", &"ambush": "Ambush", &"reclaim": "Reclaim",
	&"clutch": "Clutch", &"cipher": "Cipher", &"none": "No trait",
}

## Rule text exactly as shown on the card (spec §4.4).
const TRAIT_RULES: Dictionary = {
	&"steady": "Can't be captured by a card with lower Clearance.",
	&"veteran": "Also captures on ties.",
	&"ambush": "Placed face-down: it captures nothing and can't be captured. At the start of your next turn it flips face-up and captures with +1 to all values. If the wall fills first, it flips before scoring.",
	&"reclaim": "On placement, takes back every adjacent card from your own lineup, whatever the values.",
	&"clutch": "If you're behind on score when you place it, +2 to all values for this placement.",
	&"cipher": "On placement, copies the trait of one adjacent card (your pick).",
	&"none": "Store card: premium frame, Clearance 1, no trait.",
}

## Two-letter fallback marks (not "S", which reads as Side) for trait icons until cc14's icons are wired in (card_view.gd).
const TRAIT_MARKS: Dictionary = {
	&"steady": "St", &"veteran": "Vt", &"ambush": "Am", &"reclaim": "Rc", &"clutch": "Cl", &"cipher": "Ci", &"none": "",
}

const SET_NAMES: Dictionary = {
	&"night_shift": "Night Shift", &"whiteout": "Whiteout", &"signal_fire": "Signal Fire",
	&"old_guard": "Old Guard", &"cipher": "Cipher", &"showcase": "Showcase",
}


static func clearance_line(card: Dictionary) -> String:
	var c: int = int(card.get("clearance", 1))
	return "Clearance %d · %s" % [c, CLEARANCE_NAMES[clampi(c, 1, 4)]]


static func set_origin_line(card: Dictionary) -> String:
	return "%s · %s" % [SET_NAMES.get(card.get("set", &""), "?"), ORIGIN_NAMES.get(card.get("origin", &""), "?")]


static func trait_name(card: Dictionary) -> String:
	return TRAIT_NAMES.get(card.get("trait", &"none"), "No trait")


static func trait_rule(card: Dictionary) -> String:
	return TRAIT_RULES.get(card.get("trait", &"none"), "")


static func earned_line(card: Dictionary) -> String:
	return String(card.get("earned", ""))
