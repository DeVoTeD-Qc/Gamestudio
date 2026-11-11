# card_info.gd
# Purpose: Turns rules data (CardData, the Operator's RulesUnit / Primary) into what the match UI
#   shows: the hand chip Dictionary, the CardView Dictionary (p13 keys) and the inspector's
#   keyword explanations (core-rules.md section 1 "Keywords", plus triggers and special rules).
#   CardView.set_card(resource) cannot read CardData directly (card_type / weapon_class are enum
#   ints there and CardData has no `keywords` array), so the match screen always goes through here.
# Dependencies: DataEnums, CardData, EffectData, RulesUnit, LoadoutItem.
# Author: UI/UX Agent (p09)
extends RefCounted

const CLASS_WORDS: Dictionary = {
	DataEnums.WeaponClass.NONE: "", DataEnums.WeaponClass.SMG: "SMG",
	DataEnums.WeaponClass.SHOTGUN: "Shotgun", DataEnums.WeaponClass.AR: "AR",
	DataEnums.WeaponClass.SNIPER: "Sniper", DataEnums.WeaponClass.LMG: "LMG",
}
const TYPE_WORDS: Dictionary = {
	DataEnums.CardType.UNIT: "unit", DataEnums.CardType.TACTIC: "tactic",
	DataEnums.CardType.EQUIPMENT: "equipment",
}
## Keyword rules (core-rules.md section 1 and Rulings): [name, short rule, full rule].
## kc-text (text-and-icons.md): [1] is the inspector / tooltip line (one line: the rule and its
## number), [2] the full explanation, shown in the Codex glossary only.
const KEYWORD_RULES: Dictionary = {
	&"first_shot": ["First Shot", "Fires first. A target it eliminates doesn't fire back.",
			"Fires first in its exchange. A target it eliminates doesn't fire back."],
	&"pick": ["Pick", "Shoots the enemy with the lowest Armor.",
			"Shoots the enemy with the lowest current Armor (ties: the front-most)."],
	&"flank": ["Flank", "Shoots the back-most enemy.", "Shoots the back-most enemy in the column."],
	&"pierce": ["Pierce", "Extra damage carries to the next enemy behind.",
			"Damage beyond what its target needs carries to the next enemy behind it (that unit's Cover applies)."],
	&"cover": ["Cover %d", "Each hit on it deals %d less.", "Each hit on this unit deals %d less damage (minimum 0)."],
	&"suppress": ["Suppress %d", "The enemy front unit here gets -%d FP this round.",
			"At the start of the firefight, the enemy front unit here gets -%d FP this round. Suppress adds up."],
	&"patch": ["Patch %d", "After the firefight: +%d Armor to your most damaged other unit here.",
			"After the firefight, restores %d Armor to your most damaged other unit in this column."],
	&"holder": ["Holder", "Holds a contested column (unless the enemy has a Holder too).",
			"You control this column while it is contested, unless the enemy also has a Holder there."],
	&"on_deploy": ["On Deploy", "Triggers when it arrives.", "Triggers when this unit is revealed and arrives."],
	&"on_down": ["On Down", "Triggers when it is eliminated.", "Triggers when this unit is eliminated."],
	&"end_of_round": ["End of round", "Triggers at the end of each round.",
			"Triggers at the end of every round this unit is on the board (after the firefight, in the Score step)."],
	&"agile": ["Agile", "Once a round: move it to an adjacent column. Free.",
			"Once per round, in Deploy, tap it and then an adjacent column: it moves there at Reveal, to the back. Free. If that column is full by then, it stays."],
	&"beam": ["Beam", "Hits every unit in front of it, your own units too.",
			"Its shot hits every unit in front of it in its column, your own units included, for its FP each (Cover applies). At the front it only hits enemies."],
	&"arrives_front": ["Front line", "Arrives as the front unit of its column.",
			"Joins its column at the front and becomes the front unit."],
	&"immediate": ["Resolves immediately", "Takes effect when played. Can't be undone.",
			"Takes effect as soon as you play it in Deploy, so it can't be undone."],
	&"hidden": ["Hidden", "Stays face down until it goes off.", "Stays face down after Reveal; the enemy sees it only when it goes off."],
	&"no_control": ["Doesn't hold columns", "Doesn't count for column control.", "Doesn't count for column control."],
}


## Keyword / trigger ids that have an icon in IconSheet (the full CardView shows these).
## kc-fight-ui: Pierce has no sheet icon; it is drawn (SynergyGlyphs.draw_pierce_icon, an arrow
## through a chevron pointing down the enemy column) wherever keyword glyphs are drawn.
const ICON_KEYWORDS: Array[StringName] = [
	&"first_shot", &"pick", &"flank", &"pierce", &"cover", &"suppress", &"patch", &"holder", &"on_deploy", &"on_down",
]
## kc-wip-impl: keyword ids with a value (Cover N, Patch N, Suppress N).
const VALUE_KEYWORDS: Array[StringName] = [&"cover", &"patch", &"suppress"]


## Hand chip (hand_area.gd): {uid, id, name, type, card_type, weapon_class, keywords, cost, fp?,
## armor?, text, elite}. f04: card_type / weapon_class / keywords drive the chip's icons (the same
## icon language as CardView); keywords = icon_keywords().
static func chip(uid: int, card: CardData) -> Dictionary:
	var d: Dictionary = {
		"uid": uid, "id": card.id, "name": card.display_name, "cost": card.cost,
		"type": type_line(card), "text": short_text(card),
		"card_type": TYPE_WORDS.get(card.card_type, "unit"),
		"weapon_class": String(CLASS_WORDS.get(card.weapon_class, "")).to_lower(),
		"keywords": icon_keywords(keywords(card)), "elite": card.is_elite,
	}
	if card.is_unit():
		d["fp"] = card.firepower
		d["armor"] = card.armor
	return d


## The entries of keywords() / operator_keywords() that have an icon, as [{id, value, name}].
static func icon_keywords(entries: Array[Dictionary]) -> Array:
	var out: Array = []
	for k: Dictionary in entries:
		if k["id"] in ICON_KEYWORDS:
			out.append({"id": k["id"], "value": k["value"], "name": k["name"]})
	return out


## "Unit" for units (kc-ipad-cards: never the weapon class), "Tactic" / "Equip" otherwise.
static func type_line(card: CardData) -> String:
	if card.is_unit():
		return "Unit"
	if card.card_type == DataEnums.CardType.EQUIPMENT:
		return "Equip"  # "EQUIPMENT" does not fit the phone chip's type line
	return String(TYPE_WORDS.get(card.card_type, "card")).capitalize()


## One line for the hand chip: keywords for units (rules text if none), rules text otherwise.
static func short_text(card: CardData) -> String:
	if card.is_unit():
		var names: PackedStringArray = []
		for k: Dictionary in keywords(card):
			if k["id"] in [&"first_shot", &"pick", &"flank", &"pierce", &"cover", &"suppress", &"patch", &"holder", &"agile", &"beam"]:
				names.append(k["name"])
		if not names.is_empty():
			return ", ".join(names)
	return card.text


## CardView Dictionary (card_view.gd set_card_data keys).
static func view_dict(card: CardData, side: String = "friend") -> Dictionary:
	var kw: Array = []
	for k: Dictionary in keywords(card):
		if k["id"] in [&"first_shot", &"pick", &"flank", &"pierce", &"holder", &"on_deploy", &"on_down", &"agile", &"beam", &"end_of_round"]:
			kw.append(String(k["id"]))
		elif k["id"] in VALUE_KEYWORDS:
			kw.append({"id": String(k["id"]), "value": k["value"]})
	return {
		"id": String(card.id), "name": card.display_name, "type": TYPE_WORDS.get(card.card_type, "unit"),
		"weapon_class": String(CLASS_WORDS.get(card.weapon_class, "")).to_lower(),
		"cost": card.cost, "firepower": card.firepower, "armor": card.armor, "keywords": kw,
		"text": card.text, "side": side, "elite": card.is_elite,
	}


## Keyword / trigger / special-rule explanations of a card: [{id, name, text, value}].
static func keywords(card: CardData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if card.is_unit():
		for id: StringName in [&"first_shot", &"pick", &"flank", &"pierce"]:
			if card.get(id):
				out.append(_entry(id))
		if card.cover > 0:
			out.append(_entry(&"cover", card.cover))
		if card.suppress:
			out.append(_entry(&"suppress", card.suppress_amount))
		if card.patch > 0:
			out.append(_entry(&"patch", card.patch))
		if card.holder:
			out.append(_entry(&"holder"))
		if card.agile:
			out.append(_entry(&"agile"))
		if card.beam:
			out.append(_entry(&"beam"))
		if card.arrives_front:
			out.append(_entry(&"arrives_front"))
	var triggers: Array[int] = []
	for e: EffectData in card.effects:
		if e != null and not triggers.has(e.trigger):
			triggers.append(e.trigger)
	if triggers.has(DataEnums.Trigger.ON_DEPLOY):
		out.append(_entry(&"on_deploy"))
	if triggers.has(DataEnums.Trigger.ON_DOWN):
		out.append(_entry(&"on_down"))
	if card.is_unit() and triggers.has(DataEnums.Trigger.END_OF_ROUND):
		out.append(_entry(&"end_of_round"))
	if triggers.has(DataEnums.Trigger.IMMEDIATE):
		out.append(_entry(&"immediate"))
	if card.hidden:
		out.append(_entry(&"hidden"))
	if not card.counts_for_control:
		out.append(_entry(&"no_control"))
	return out


## Operator (RulesUnit) as a CardView Dictionary.
static func operator_view_dict(op: RulesUnit, display_name: String) -> Dictionary:
	var kw: Array = []
	for k: Dictionary in operator_keywords(op):
		kw.append({"id": String(k["id"]), "value": k["value"]} if k["value"] > 0 else String(k["id"]))
	return {
		"name": display_name, "type": "operator",
		"weapon_class": String(CLASS_WORDS.get(op.weapon_class, "")).to_lower(),
		"firepower": op.base_firepower, "armor": op.base_max_armor, "keywords": kw,
		"text": "If it goes down, your streak resets. Respawns next Deploy.",
		"side": "friend",
	}


static func operator_keywords(op: RulesUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in [&"first_shot", &"pick", &"flank", &"pierce"]:
		if op.get(id):
			out.append(_entry(id))
	if op.cover > 0:
		out.append(_entry(&"cover", op.cover))
	if op.suppress:
		out.append(_entry(&"suppress", op.suppress_amount))
	if op.patch > 0:
		out.append(_entry(&"patch", op.patch))
	if op.holder:
		out.append(_entry(&"holder"))
	if op.agile:
		out.append(_entry(&"agile"))
	if op.beam:
		out.append(_entry(&"beam"))
	return out


## A unit on the board (live keyword fields, plus its card's On Deploy / On Down triggers).
static func unit_keywords(u: RulesUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = operator_keywords(u)
	if u.card != null:
		for k: Dictionary in keywords(u.card):
			if k["id"] in [&"on_deploy", &"on_down", &"end_of_round"]:
				out.append(k)
	return out


static func _entry(id: StringName, value: int = 0) -> Dictionary:
	var row: Array = KEYWORD_RULES[id]
	var title: String = row[0]
	var text: String = row[1]
	var full: String = row[2]
	if value > 0:
		title = title % value
		text = text % value
		full = full % value
	return {"id": id, "name": title, "text": text, "full": full, "value": value}


## kc-ui4 GLOSSARY: the plain-words entries that are not card keywords (KEYWORD_RULES holds those;
## SynergyRules holds the traits). [name, text]. The Codex glossary
## (scripts/ui/codex/glossary.gd) reads these three tables only, so the wording lives in one place.
const GLOSSARY_EXTRA: Dictionary = {
	&"firepower": ["Firepower (FP)", "Damage it deals per shot: the number in the ring, bottom-right (teal yours, red the rival's). Green = buffed. The inspector shows the sum."],
	&"armor": ["Armor", "Health: the number on the plate, bottom-right. Each hit takes Armor away; at 0 the unit is eliminated. Amber plate = damaged."],
	&"card_peek": ["Card at rest / peek", "On the board a card shows its trait, ability icons, FP and Armor. Hover (touch: hold) to see its cost. Settings > ALL CARD INFO shows everything. Right click or long press for the rules."],
	&"damaged": ["Damaged", "Amber line along the bottom, a crack top-left and an amber Armor plate: it has lost Armor."],
	&"card_frames": ["Card frames", "Cost and name on top, the art, the type (UNIT, TACTIC, FIELD, OPERATOR, STANDARD ISSUE), the abilities, then trait, FP and Armor. Tactics are khaki orders with a cut corner and no stats."],
	&"trait_chip": ["Trait chip", "Bottom-left on a card (one trait at most). Faint while its set is off, lit while on (2 or 3 in play)."],
	&"rail_highlight": ["Sets rail highlight", "Tap a row of the SETS rail to pin it: matching cards glow, the rest dim. Tap again to unpin."],
	&"cover_stat": ["Cover (chip)", "This unit's Cover now (printed + effects + sets): each hit on it deals that much less."],
	&"supply": ["Supply", "Spent in Deploy to play cards. A card's hex is its cost. Round N gives N Supply (max 7)."],
	&"stat_colours": ["Green up / red down", "Green with an up triangle: raised right now. Red with a down triangle: lowered. White: printed value."],
	&"tactic": ["Tactic", "A one-time order. Play it in Deploy; it resolves at Reveal, then goes to the discard."],
	&"field": ["Field / Overrun", "A Field stays in its column and keeps working. Overrun: at the end of a round, if the enemy controls its column, the Field is destroyed (hidden traps are exempt)."],
	&"control": ["Column control", "After the firefight, the side with units left in a column (and the rival with none) controls it. Both sides: EVEN, unless only one has a Holder."],
	&"objective": ["Objective tile", "The middle row: the column letter in its control mark (teal circle yours, red diamond the rival's, dashed square even, grey ring open) and the Fields there."],
	&"operator": ["Operator", "Your hero card: never drawn or discarded. Free to place in round 1; costs Supply to place again after it goes down."],
	&"killstreak": ["Killstreak", "Eliminations build your streak. At a killstreak's number it is ready (amber glow): tap to call it in."],
	&"incoming": ["Incoming", "A rival card played face down this Deploy. It lands here at Reveal."],
	&"set_callout": ["Set callout", "A set switching on is announced beside the trait rail. A red crack: a set switched off."],
	&"doctrine": ["Doctrine", "A run pick: one trait whose set count is +1 all run while one of its members is in play. In Duel it only starts a set."],
}


# --- kc-text: the inspector sheet's lines (match and Codex) ---------------------------------

## kc-text: the Overrun rule in one line (the head asked "What is overrun again?"), on every Field.
const FIELD_RULE: String = "Overrun: destroyed at end of round if the enemy controls this column."


## kc-text: "2 Supply · 3 FP · 4 Armor" (a tactic: "1 Supply"); IconText adds the icons.
static func stats_line(card: CardData) -> String:
	var parts: PackedStringArray = ["%d Supply" % card.cost]
	if card.is_unit():
		parts.append("%d FP" % card.firepower)
		parts.append("%d Armor" % card.armor)
	return " · ".join(parts)


## kc-text: the rules text minus sentences that only name a keyword already on its own line.
static func rules_without_keywords(text: String, names: PackedStringArray) -> String:
	var kept: PackedStringArray = []
	for sentence: String in text.split(". ", false):
		var bare: String = sentence.strip_edges().trim_suffix(".")
		if names.has(bare.to_lower()):
			continue
		kept.append(bare)
	if kept.is_empty():
		return ""
	return ". ".join(kept) + "."
