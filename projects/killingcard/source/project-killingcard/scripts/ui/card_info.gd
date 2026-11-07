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
## Keyword rules, worded for the inspector (core-rules.md section 1 and Rulings).
const KEYWORD_RULES: Dictionary = {
	&"first_shot": ["First Shot", "Fires first in its exchange; a partner it kills doesn't fire back."],
	&"pick": ["Pick", "Shoots the enemy with the lowest current Armor (ties: front-most)."],
	&"flank": ["Flank", "Shoots the back-most enemy in the line."],
	# kc-fight-ui (firefight-order.md §3; head's O3: the LMG units).
	&"pierce": ["Pierce", "Damage beyond what its target needs carries on to the next enemy behind it (that unit's Cover applies)."],
	&"cover": ["Cover %d", "Each hit on this unit deals %d less damage (minimum 0)."],
	&"suppress": ["Suppress", "At the start of the firefight, the enemy point man here gets -2 Firepower."],
	&"patch": ["Patch %d", "After the firefight, restores %d Armor to the most damaged other friendly unit here."],
	&"holder": ["Holder", "You control this zone while it is contested, unless the enemy also has a Holder here."],
	&"on_deploy": ["On Deploy", "Happens when this unit is revealed and arrives."],
	&"on_down": ["On Down", "Happens when this unit is eliminated."],
	&"arrives_front": ["Arrives in front", "Joins the zone at the front of the line and becomes the point man."],
	&"immediate": ["Resolves immediately", "Takes effect as soon as you play it in Deploy, so it can't be undone."],
	&"hidden": ["Hidden", "Stays face-down after Reveal; the enemy only sees it when it goes off."],
	&"no_control": ["Doesn't hold zones", "Doesn't count for zone control."],
}


## Keyword / trigger ids that have an icon in IconSheet (the full CardView shows these).
## kc-fight-ui: Pierce has no sheet icon; it is drawn (SynergyGlyphs.draw_pierce_icon, an arrow
## through a chevron pointing down the enemy column) wherever keyword glyphs are drawn.
const ICON_KEYWORDS: Array[StringName] = [
	&"first_shot", &"pick", &"flank", &"pierce", &"cover", &"suppress", &"patch", &"holder", &"on_deploy", &"on_down",
]


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
			if k["id"] in [&"first_shot", &"pick", &"flank", &"pierce", &"cover", &"suppress", &"patch", &"holder"]:
				names.append(k["name"])
		if not names.is_empty():
			return ", ".join(names)
	return card.text


## CardView Dictionary (card_view.gd set_card_data keys).
static func view_dict(card: CardData, side: String = "friend") -> Dictionary:
	var kw: Array = []
	for k: Dictionary in keywords(card):
		if k["id"] in [&"first_shot", &"pick", &"flank", &"pierce", &"suppress", &"holder", &"on_deploy", &"on_down"]:
			kw.append(String(k["id"]))
		elif k["id"] in [&"cover", &"patch"]:
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
			out.append(_entry(&"suppress"))
		if card.patch > 0:
			out.append(_entry(&"patch", card.patch))
		if card.holder:
			out.append(_entry(&"holder"))
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
		"text": "Your Operator. If it goes down, your streak resets; it respawns at your next Deploy.",
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
		out.append(_entry(&"suppress"))
	if op.patch > 0:
		out.append(_entry(&"patch", op.patch))
	if op.holder:
		out.append(_entry(&"holder"))
	return out


## A unit on the board (live keyword fields, plus its card's On Deploy / On Down triggers).
static func unit_keywords(u: RulesUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = operator_keywords(u)
	if u.card != null:
		for k: Dictionary in keywords(u.card):
			if k["id"] in [&"on_deploy", &"on_down"]:
				out.append(k)
	return out


static func _entry(id: StringName, value: int = 0) -> Dictionary:
	var row: Array = KEYWORD_RULES[id]
	var title: String = row[0]
	var text: String = row[1]
	if value > 0:
		title = title % value
		text = text % value
	return {"id": id, "name": title, "text": text, "value": value}


## kc-ui4 GLOSSARY: the plain-words entries that are not card keywords (KEYWORD_RULES holds those;
## SynergyRules holds the traits). [name, text]. The Codex glossary
## (scripts/ui/codex/glossary.gd) reads these three tables only, so the wording lives in one place.
const GLOSSARY_EXTRA: Dictionary = {
	&"firepower": ["Firepower (FP)", "Damage this unit deals when it shoots: the number in the reticle ring, bottom-right (teal ring yours, red the rival's; a green number is buffed). It is the RESULT now (effects, links and sets included); the inspector lists the sum."],
	&"armor": ["Armor", "Health: the number on the grey ballistic plate at the bottom-right corner (both sides). Each hit takes Armor away and the plate shows what is left; at 0 the unit is eliminated. Amber plate = damaged."],
	&"card_peek": ["Card at rest / peek", "On the board a card shows its trait (bottom-left), its ability icons (bottom-centre) and FP and Armor (bottom-right), all the same size. Hover it (touch: hold it) to peek at its cost (top-left). Hand cards always show everything; Settings > ALL CARD INFO shows it on the board too. Long press (or right click) any card for what each icon does."],
	&"damaged": ["Damaged", "A thin amber line along the bottom edge, a crack in the top-left corner and an amber Armor plate: the unit has lost Armor."],
	&"card_frames": ["Card frames", "Off the board every card is a classic card: cost and name on top, the calling card, its type line (UNIT, TACTIC, FIELD, OPERATOR or STANDARD ISSUE), each ability as its icon and name, then its trait, ability icons and FP / Armor. Tactics are orders: khaki paper with a cut top-right corner, their rules and no stats."],
	&"trait_chip": ["Trait chip", "Bottom-left on every card (a card has one trait at most): faint while its set bonus is off, lit with a glow while it is on (2 or 3 in play)."],
	&"rail_highlight": ["Sets rail highlight", "Hover, focus or tap a row of the SETS rail to pin it: every card shows that trait, the matching cards glow and the rest dim. Tap it again to unpin."],
	&"cover_stat": ["Cover (chip)", "The Cover this unit has now (printed + effects + links + sets): each hit on it deals that much less."],
	&"supply": ["Supply", "What you spend in Deploy. The hex on a card is its cost; you get more Supply each round."],
	&"stat_colours": ["Green up / red down", "A green number with an up triangle is raised by something right now; red with a down triangle is lowered. White = the printed value."],
	&"tactic": ["Tactic", "A one-time order (its icon: an orders sheet with a bolt). Play it in Deploy; it resolves at Reveal and goes to the discard."],
	&"field": ["Field / Overrun", "A Field stays in its column and keeps working. Overrun: at the end of each round, if the enemy controls this column, the Field is destroyed (hidden traps are exempt)."],
	&"control": ["Column control", "After the firefight, a side with units left in a column and the rival with none controls it. Both sides there: EVEN (contested), unless only one side has a Holder."],
	&"objective": ["Objective tile", "The middle row: the column's letter (A, B, C) in its control mark (teal circle yours, red diamond the rival's, dashed square even, grey ring open) and the Fields there (the rival's on top, yours below). Long press or right click it for both sides' Firepower and the details."],
	&"operator": ["Operator", "Your hero card (brass frame): never drawn or discarded. It costs Supply to place and comes back after it goes down."],
	&"killstreak": ["Killstreak", "Eliminations build your streak; at its number a killstreak is ready (amber glow) and you tap it to call it in."],
	&"incoming": ["Incoming", "A rival card played face-down this Deploy: it lands here at Reveal."],
	&"set_callout": ["Set callout", "When a trait set switches on (2 or 3 in play) its bonus is announced beside the trait rail, then folds into it. A red crack: a set switched off."],
	&"doctrine": ["Doctrine", "A run pick: one trait whose set count is +1 all run while you have at least one member in play."],
}
