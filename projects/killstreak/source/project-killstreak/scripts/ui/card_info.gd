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
	&"first_shot": ["First Shot", "Fires in the First Shot step, before other units."],
	&"pick": ["Pick", "Shoots the enemy with the lowest current Armor (ties: front-most)."],
	&"flank": ["Flank", "Shoots the back-most enemy in the line."],
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


## Hand chip (hand_area.gd): {uid, id, name, type, cost, fp?, armor?, text}.
static func chip(uid: int, card: CardData) -> Dictionary:
	var d: Dictionary = {
		"uid": uid, "id": card.id, "name": card.display_name, "cost": card.cost,
		"type": type_line(card), "text": short_text(card),
	}
	if card.is_unit():
		d["fp"] = card.firepower
		d["armor"] = card.armor
	return d


## "Shotgun" for units (class word, or "Unit"), "Tactic" / "Equip" otherwise.
static func type_line(card: CardData) -> String:
	if card.is_unit():
		var word: String = CLASS_WORDS.get(card.weapon_class, "")
		return word if word != "" else "Unit"
	if card.card_type == DataEnums.CardType.EQUIPMENT:
		return "Equip"  # "EQUIPMENT" does not fit the phone chip's type line
	return String(TYPE_WORDS.get(card.card_type, "card")).capitalize()


## One line for the hand chip: keywords for units (rules text if none), rules text otherwise.
static func short_text(card: CardData) -> String:
	if card.is_unit():
		var names: PackedStringArray = []
		for k: Dictionary in keywords(card):
			if k["id"] in [&"first_shot", &"pick", &"flank", &"cover", &"suppress", &"patch", &"holder"]:
				names.append(k["name"])
		if not names.is_empty():
			return ", ".join(names)
	return card.text


## CardView Dictionary (card_view.gd set_card_data keys).
static func view_dict(card: CardData, side: String = "friend") -> Dictionary:
	var kw: Array = []
	for k: Dictionary in keywords(card):
		if k["id"] in [&"first_shot", &"pick", &"flank", &"suppress", &"holder", &"on_deploy", &"on_down"]:
			kw.append(String(k["id"]))
		elif k["id"] in [&"cover", &"patch"]:
			kw.append({"id": String(k["id"]), "value": k["value"]})
	return {
		"name": card.display_name, "type": TYPE_WORDS.get(card.card_type, "unit"),
		"weapon_class": String(CLASS_WORDS.get(card.weapon_class, "")).to_lower(),
		"cost": card.cost, "firepower": card.firepower, "armor": card.armor, "keywords": kw,
		"text": card.text, "side": side, "elite": card.is_elite,
	}


## Keyword / trigger / special-rule explanations of a card: [{id, name, text, value}].
static func keywords(card: CardData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if card.is_unit():
		for id: StringName in [&"first_shot", &"pick", &"flank"]:
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
	for id: StringName in [&"first_shot", &"pick", &"flank"]:
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


static func _entry(id: StringName, value: int = 0) -> Dictionary:
	var row: Array = KEYWORD_RULES[id]
	var title: String = row[0]
	var text: String = row[1]
	if value > 0:
		title = title % value
		text = text % value
	return {"id": id, "name": title, "text": text, "value": value}
