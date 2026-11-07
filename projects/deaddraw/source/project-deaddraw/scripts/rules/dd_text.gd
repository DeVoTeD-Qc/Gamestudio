# dd_text.gd
# Purpose: Every player-facing name and rules sentence (flavor names by number, perk,
#   survivor and finale text). Numbers inside sentences come from DDBalance so a retune of
#   balance.json updates the text too.
# Dependencies: DDBalance, DDCard (DDRun is passed in, never referenced as a type here to
#   avoid a cyclic dependency).
# Author: Mechanics Developer Agent
class_name DDText
extends RefCounted

const WEAPON_NAMES: Dictionary = {
	2: "Broken Bottle", 3: "Claw Hammer", 4: "Crowbar", 5: "Cricket Bat",
	6: "Machete", 7: "Fire Axe", 8: "Sledgehammer", 9: "Chainsaw",
}

const PERK_NAMES: Dictionary = {
	"thick_jacket": "Thick Jacket", "fire_axe": "Axe in the Trunk", "field_kit": "Field Kit",
	"knuckle_wraps": "Knuckle Wraps", "sandbags": "Sandbags", "scrounger": "Scrounger",
	"second_wind": "Second Wind", "tripwire": "Tripwire",
}

const PASSIVE_NAMES: Dictionary = {
	"steady_hands": "Steady Hands", "triage": "Triage", "slip_away": "Slip Away",
}

const TRAIT_NAMES: Dictionary = {
	"shatter": "Shatter", "horde": "Horde", "quarantine": "Quarantine",
}


static func zombie_name(v: int) -> String:
	if v <= 4:
		return "Shambler"
	if v <= 7:
		return "Lurcher"
	if v <= 10:
		return "Bruiser"
	return "Hulk"


static func weapon_name(v: int) -> String:
	if v <= 0:
		return "Bare hands"
	return str(WEAPON_NAMES.get(v, "Weapon %d" % v))


static func medkit_name(v: int) -> String:
	if v <= 3:
		return "Bandage"
	if v <= 6:
		return "First Aid Kit"
	return "Trauma Kit"


static func barricade_name(v: int) -> String:
	match v:
		2:
			return "Plywood"
		3:
			return "Car Door"
		4:
			return "Dumpster"
	return "Barricade"


static func card_name(c: DDCard) -> String:
	if c.finale_name != "":
		return c.finale_name
	match c.kind:
		DDCard.ZOMBIE:
			return zombie_name(c.value)
		DDCard.WEAPON:
			return weapon_name(c.value)
		DDCard.MEDKIT:
			return medkit_name(c.value)
		DDCard.BARRICADE:
			return barricade_name(c.value)
	return "Card"


static func kind_label(kind: String) -> String:
	match kind:
		DDCard.ZOMBIE:
			return "ZOMBIE"
		DDCard.WEAPON:
			return "WEAPON"
		DDCard.MEDKIT:
			return "MEDKIT"
		DDCard.BARRICADE:
			return "BARRICADE"
	return ""


static func number_label(kind: String) -> String:
	match kind:
		DDCard.ZOMBIE:
			return "Strength"
		DDCard.WEAPON:
			return "Power"
		DDCard.MEDKIT:
			return "Heal"
		DDCard.BARRICADE:
			return "Cover"
	return ""


## Tag shown on the weapon slot: which zombies the weapon can still hit.
static func notch_tag(notch: int, passive: String) -> String:
	if notch >= 99:
		return "fresh: hits anything"
	if passive == "steady_hands":
		return "hits %d or less" % notch
	return "hits under %d" % notch


static func perk_name(id: String) -> String:
	return str(PERK_NAMES.get(id, id))


static func perk_text(id: String, bal: DDBalance) -> String:
	match id:
		"thick_jacket":
			return "+%d max HP and heal %d now." % [bal.rule("thick_jacket_hp"), bal.rule("thick_jacket_hp")]
		"fire_axe":
			return "At the start of each later district, equip a fresh Fire Axe (%d) if your weapon is weaker or notched." % bal.num("fire_axe_power")
		"field_kit":
			return "Medkits heal +%d." % bal.rule("field_kit_bonus")
		"knuckle_wraps":
			return "Bare-handed fights deal %d less damage (minimum 0)." % bal.rule("knuckle_wraps_reduction")
		"sandbags":
			return "Barricades give +%d Cover." % bal.rule("sandbags_bonus")
		"scrounger":
			return "Heal %d every time you Retreat." % bal.rule("scrounger_heal")
		"second_wind":
			return "Once per run, when you would drop to 0 HP, you stay at %d HP instead." % bal.rule("second_wind_hp")
		"tripwire":
			return "The street right after a Retreat starts with %d Cover." % bal.rule("tripwire_cover")
	return ""


static func passive_name(passive: String) -> String:
	return str(PASSIVE_NAMES.get(passive, passive))


static func passive_text(passive: String, bal: DDBalance) -> String:
	match passive:
		"steady_hands":
			return "Her weapons can also hit zombies EQUAL to the last notch, not only weaker ones."
		"triage":
			return "%d medkits can heal per street instead of %d, and every medkit heals +%d." % [bal.rule("triage_medkits_per_street"), bal.rule("medkits_per_street"), bal.num("triage_heal_bonus")]
		"slip_away":
			return "May Retreat after resolving 1 card of a street (the other 3 go to the bottom of the deck). Still no two retreats in a row."
	return ""


static func trait_name(t: String) -> String:
	return str(TRAIT_NAMES.get(t, t.capitalize()))


static func trait_text(t: String) -> String:
	match t:
		"shatter":
			return "A weapon used on it breaks after the fight (it still reduces the damage)."
		"horde":
			return "All of them arrive at once. Fight the strongest first and one weapon can handle them all under the Notch rule."
		"quarantine":
			return "Medkits don't heal on the Finale street."
	return ""


static func finale_summary(fin: Dictionary) -> String:
	var zs: Array = fin.get("zombies", [])
	var parts: PackedStringArray = []
	for z: Variant in zs:
		parts.append(str(int(z)))
	return "%s - Zombie%s %s" % [str(fin.get("name", "")), "s" if zs.size() > 1 else "", " / ".join(parts)]


## Full rules text for a card in the context of a run (run may be null on menus).
static func card_rules(c: DDCard, run: Object, bal: DDBalance) -> String:
	var lines: PackedStringArray = []
	match c.kind:
		DDCard.ZOMBIE:
			lines.append("Zombie, strength %d. No zombie survives a fight: the question is what it costs you." % c.value)
			lines.append("Bare-handed: you take %d damage." % c.value)
			lines.append("With a weapon: you take strength - power (minimum 0), and the weapon gets a notch at %d." % c.value)
			if c.boss_trait != "":
				lines.append("%s: %s" % [trait_name(c.boss_trait), trait_text(c.boss_trait)])
			if run != null:
				var w: int = int(run.get("weapon"))
				if w > 0:
					var why: String = str(run.call("weapon_block_reason", c.value))
					if why == "":
						lines.append("Your %s (%d) can hit it: you would take %d." % [weapon_name(w), w, maxi(0, c.value - w)])
					else:
						lines.append("Your %s can't hit it (%s)." % [weapon_name(w), why])
		DDCard.WEAPON:
			lines.append("Weapon, power %d." % c.value)
			lines.append("Equip: it replaces your current weapon (discarded) and starts fresh, no notch.")
			if bal.weapon_scrap():
				lines.append("Scrap: discard it, no effect.")
			lines.append("Notch rule: after each kill it can only hit zombies weaker than that kill.")
		DDCard.MEDKIT:
			lines.append("Medkit: restore %d HP, up to your max." % c.value)
			lines.append("Only %d medkit heals per street (Imani: %d). Extra medkits are used up for nothing." % [bal.rule("medkits_per_street"), bal.rule("triage_medkits_per_street")])
			if run != null and not bool(run.call("medkit_would_heal")):
				lines.append("Right now it WON'T heal.")
		DDCard.BARRICADE:
			lines.append("Barricade: gain %d Cover." % c.value)
			lines.append("Cover soaks up damage before your HP and goes away at the end of the street.")
	if c.holdover:
		lines.append("Holdover: this card was left from the last street.")
	return "\n".join(lines)
