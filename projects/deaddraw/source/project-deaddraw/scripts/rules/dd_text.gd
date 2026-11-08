# dd_text.gd
# Purpose: Every player-facing name and rules sentence for DeadDraw v2 (zombie / medkit /
#   barricade names by number, weapons by id, machines, Jawbreakers, Carrier drops, perks,
#   survivors, bosses). Numbers inside sentences come from DDBalance so a retune of balance.json
#   updates the text too. Points are always written as the player sees them (x10).
# Dependencies: DDBalance, DDCard, DDWeapon (DDRun is passed in as an Object, never referenced as
#   a type here, to avoid a cyclic dependency).
# Author: Mechanics Developer Agent
class_name DDText
extends RefCounted

const PERK_NAMES: Dictionary = {
	"thick_jacket": "Thick Jacket", "fire_axe": "Axe in the Trunk", "field_kit": "Field Kit",
	"knuckle_wraps": "Knuckle Wraps", "bandolier": "Bandolier", "fast_hands": "Fast Hands",
	"second_wind": "Second Wind", "tripwire": "Tripwire",
}

const PASSIVE_NAMES: Dictionary = {
	"steady_hands": "Steady Hands", "triage": "Triage", "slip_away": "Slip Away",
}

const TRAIT_NAMES: Dictionary = {
	"shatter": "Shatter", "horde": "Horde", "quarantine": "Quarantine",
}

const MACHINE_NAMES: Dictionary = {
	"retrofit": "Retrofit Bench", "grin": "Grin Machine", "locker": "Lucky Locker", "wallrack": "Wall Rack",
}

const BUFF_NAMES: Dictionary = {
	"thick_skin": "Thick Skin", "steady_aim": "Steady Aim", "sleight": "Sleight of Hand",
	"payday": "Payday", "sugar_rush": "Sugar Rush", "light_step": "Light Step",
}

const DROP_NAMES: Dictionary = {"full_load": "Full Load", "payday": "Payday", "boards": "Boards"}


static func zombie_name(v: int) -> String:
	if v <= 4:
		return "Shambler"
	if v <= 7:
		return "Lurcher"
	if v <= 10:
		return "Bruiser"
	return "Hulk"


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


static func ammo_name(v: int) -> String:
	if v <= 3:
		return "Loose Rounds"
	if v <= 4:
		return "Ammo Box"
	return "Ammo Crate"


static func card_name(c: DDCard, bal: DDBalance = null) -> String:
	if c.finale_name != "":
		return c.finale_name
	match c.kind:
		DDCard.ZOMBIE:
			return zombie_name(c.value)
		DDCard.WEAPON:
			var b: DDBalance = bal if bal != null else DDBalance.get_default()
			return b.weapon_name(c.wid)
		DDCard.AMMO:
			return ammo_name(c.value)
		DDCard.MEDKIT:
			return medkit_name(c.value)
		DDCard.BARRICADE:
			return barricade_name(c.value)
	return "Card"


## "Revolver (gun, power 5, mag 4)" / "Machete (melee, power 6)".
static func weapon_card_label(c: DDCard, bal: DDBalance) -> String:
	var mag: int = bal.weapon_mag(c.wid)
	if mag > 0:
		return "%s (gun %d, mag %d)" % [bal.weapon_name(c.wid), c.value, mag]
	return "%s (melee %d)" % [bal.weapon_name(c.wid), c.value]


## "P5 mag 4/4" / "P6 melee"; with a run, Steady Aim's bonus is included.
static func weapon_stats(w: DDWeapon, run: Object = null) -> String:
	if w == null:
		return "empty"
	var p: int = int(run.call("power_of", w)) if run != null else w.power
	if w.is_gun():
		return "%s P%d mag %d/%d" % [w.display_name(), p, w.ammo, w.cap]
	return "%s P%d melee%s" % [w.display_name(), p, " Keen" if w.upgraded else ""]


static func kind_label(kind: String) -> String:
	match kind:
		DDCard.ZOMBIE:
			return "ZOMBIE"
		DDCard.WEAPON:
			return "WEAPON"
		DDCard.AMMO:
			return "AMMO"
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
		DDCard.AMMO:
			return "Rounds"
		DDCard.MEDKIT:
			return "Heal"
		DDCard.BARRICADE:
			return "Cover"
	return ""


## Tag shown on a weapon slot: which zombies it can still hit.
static func notch_tag(notch: int, equal_ok: bool) -> String:
	if notch >= 99:
		return "fresh: hits anything"
	if equal_ok:
		return "hits %d or less" % notch
	return "hits under %d" % notch


static func zombie_list(zs: Array) -> String:
	var p: PackedStringArray = []
	for z: Variant in zs:
		p.append(str(int(z)))
	return ", ".join(p)


## "5 zombies (6-11)".
static func zombie_summary(zs: Array) -> String:
	if zs.is_empty():
		return "no zombies"
	var lo: int = 999
	var hi: int = -999
	for z: Variant in zs:
		lo = mini(lo, int(z))
		hi = maxi(hi, int(z))
	return "%d zombie%s (%s)" % [zs.size(), "" if zs.size() == 1 else "s", ("%d" % lo) if lo == hi else ("%d-%d" % [lo, hi])]


static func cards_text(cards: Array, bal: DDBalance) -> String:
	var p: PackedStringArray = []
	for c: Variant in cards:
		var cc: DDCard = c
		if cc.kind == DDCard.WEAPON:
			p.append(card_name(cc, bal))
		else:
			p.append("%s %d" % [card_name(cc, bal), cc.value])
	return ", ".join(p) if not p.is_empty() else "nothing"


static func perk_name(id: String) -> String:
	return str(PERK_NAMES.get(id, id))


static func perk_text(id: String, bal: DDBalance) -> String:
	match id:
		"thick_jacket":
			return "+%d max HP and heal %d now." % [bal.rule("thick_jacket_hp"), bal.rule("thick_jacket_hp")]
		"fire_axe":
			return "At the start of each later district, a fresh Fire Axe (%d) goes into your weaker slot if it is better." % bal.num("fire_axe_power")
		"field_kit":
			return "Medkits heal +%d." % bal.rule("field_kit_bonus")
		"knuckle_wraps":
			return "Bare-handed fights deal %d less damage (minimum 0)." % bal.rule("knuckle_wraps_reduction")
		"bandolier":
			return "+%d reserve ammo at the start of every wave." % bal.num("bandolier_reserve")
		"fast_hands":
			return "The first reload of every wave costs no action."
		"second_wind":
			return "Once per run, when you would drop to 0 HP, you stay at %d HP instead." % bal.rule("second_wind_hp")
		"tripwire":
			return "The street right after a Skip starts with %d Cover." % bal.rule("tripwire_cover")
	return ""


static func passive_name(passive: String) -> String:
	return str(PASSIVE_NAMES.get(passive, passive))


static func passive_text(passive: String, bal: DDBalance) -> String:
	match passive:
		"steady_hands":
			return "Her weapons can also hit zombies EQUAL to their last notch, not only weaker ones."
		"triage":
			var t: String = "%d medkits can heal per street instead of %d" % [bal.rule("triage_medkits_per_street"), bal.rule("medkits_per_street")]
			if bal.num("triage_heal_bonus") > 0:
				t += ", and every medkit heals +%d" % bal.num("triage_heal_bonus")
			return t + "."
		"slip_away":
			return "May Skip after resolving 1 card of a full street (the other 3 go onto the Skipped pile). Still no two skips in a row."
	return ""


static func trait_name(t: String) -> String:
	return str(TRAIT_NAMES.get(t, t.capitalize()))


static func trait_text(t: String) -> String:
	match t:
		"shatter":
			return "A weapon used on it is destroyed after the fight (it still reduces the damage)."
		"horde":
			return "All of them arrive at once. Fight the strongest first: one weapon can take them all under the notch rule."
		"quarantine":
			return "Medkits don't heal on the boss street."
	return ""


static func finale_summary(fin: Dictionary) -> String:
	var zs: Array = fin.get("zombies", [])
	var parts: PackedStringArray = []
	for z: Variant in zs:
		parts.append(str(int(z)))
	return "%s %s" % [str(fin.get("name", "")), " / ".join(parts)]


static func machine_name(kind: String) -> String:
	return str(MACHINE_NAMES.get(kind, kind.capitalize()))


static func machine_text(m: Dictionary, bal: DDBalance) -> String:
	var kind: String = str(m.get("kind", ""))
	match kind:
		"retrofit":
			return "A grimy workbench with a hand-cranked lathe. %d points: upgrade one weapon you hold, once per weapon: +%d power; guns get +50%% magazine and a free full reload; melee becomes Keen (its notch also allows equal strength). Once per wave." % [bal.shown(int(bal.fixture_num("retrofit", "cost"))), int(bal.fixture_num("retrofit", "power"))]
		"grin":
			var lines: PackedStringArray = []
			var effects: Array = bal.list("grin_effects")
			for e: Variant in effects:
				lines.append("- %s: %s" % [buff_name(str(e)), buff_text(str(e), bal)])
			return "A grinning gumball dispenser. Each turn of the crank drops 1 Jawbreaker, chosen at random (each 1 in %d), lasting until the end of the wave. Price %d, +%d per purchase in this district. Once per wave.\n%s" % [effects.size(),
				bal.shown(int(bal.fixture_num("grin", "cost"))), bal.shown(int(bal.fixture_num("grin", "step"))), "\n".join(lines)]
		"locker":
			return "A dented school locker. %d points: it rolls one weapon. Take it into a slot or leave it (+%d). Once per wave.\nOdds: %s" % [bal.shown(int(bal.fixture_num("locker", "cost"))), bal.shown(int(bal.points("scrap"))), locker_odds(bal)]
		"wallrack":
			var wid: String = str(m.get("wid", ""))
			return "A chalk-outlined %s on hooks. Buy it for %d into a slot (full magazine). If you hold one: ammo refill for %d (full magazine, notch clears, a magazine's worth into the reserve). Once per wave." % [bal.weapon_name(wid), bal.shown(bal.weapon_price(wid)), bal.shown(int(bal.fixture_num("wallrack", "ammo_cost")))]
	return ""


static func locker_odds(bal: DDBalance) -> String:
	var pool: Array = bal.list("locker_pool")
	var counts: Dictionary = {}
	var order: Array[String] = []
	for w: Variant in pool:
		var k: String = str(w)
		if not counts.has(k):
			counts[k] = 0
			order.append(k)
		counts[k] = int(counts[k]) + 1
	var p: PackedStringArray = []
	for k: String in order:
		p.append("%s %d in %d" % [bal.weapon_name(k), int(counts[k]), pool.size()])
	return ", ".join(p)


static func buff_name(id: String) -> String:
	return str(BUFF_NAMES.get(id, id.capitalize()))


static func buff_text(id: String, bal: DDBalance) -> String:
	match id:
		"thick_skin":
			return "zombies deal %d less damage this wave." % bal.rule("thick_skin_reduction")
		"steady_aim":
			return "your guns get +%d power this wave." % bal.rule("steady_aim_power")
		"sleight":
			return "reloading doesn't use an action this wave."
		"payday":
			return "kills give double points this wave."
		"sugar_rush":
			return "heal %d now." % bal.rule("sugar_rush_heal")
		"light_step":
			return "you may Skip two streets in a row this wave."
	return ""


static func drop_name(d: String) -> String:
	return str(DROP_NAMES.get(d, d.capitalize()))


static func drop_text(d: String, bal: DDBalance) -> String:
	match d:
		"full_load":
			return "every gun's magazine is refilled and its notch cleared; +%d reserve ammo." % bal.num("full_load_reserve")
		"payday":
			return "double kill points for the rest of the wave."
		"boards":
			return "gain %d Cover now." % bal.num("boards_cover")
	return ""


## Full rules text for a card in the context of a run (run may be null on menus).
static func card_rules(c: DDCard, run: Object, bal: DDBalance) -> String:
	var lines: PackedStringArray = []
	match c.kind:
		DDCard.ZOMBIE:
			lines.append("Zombie, strength %d. No zombie survives a fight: the question is what it costs you." % c.value)
			lines.append("Bare-handed: you take %d damage, +%d points up close." % [c.value, bal.shown(int(bal.points("up_close")))])
			lines.append("With a weapon: you take strength - power (minimum 0) and the weapon is notched at %d. A gun spends 1 round." % c.value)
			lines.append("Kill: +%d points (half its strength x10)%s." % [bal.shown(int(c.value * bal.points("kill"))), (", +%d boss" % bal.shown(int(bal.points("boss")))) if c.is_boss() else ""])
			if c.drop != "":
				lines.append("CARRIER: killing it drops %s - %s" % [drop_name(c.drop), drop_text(c.drop, bal)])
			if c.boss_trait != "":
				lines.append("%s: %s" % [trait_name(c.boss_trait), trait_text(c.boss_trait)])
			if run != null:
				for s: int in 2:
					var w: Variant = run.call("slot", s)
					if w == null:
						continue
					var why: String = str(run.call("slot_block_reason", s, c.value))
					if why == "":
						lines.append("Slot %d %s can hit it: you would take %d." % [s + 1, (w as DDWeapon).display_name(), maxi(0, c.value - int(run.call("power_of", w)))])
					else:
						lines.append("Slot %d %s can't (%s)." % [s + 1, (w as DDWeapon).display_name(), why])
		DDCard.WEAPON:
			var mag: int = bal.weapon_mag(c.wid)
			if mag > 0:
				lines.append("Gun, power %d, magazine %d. Each kill spends 1 round; when the magazine is empty, reload from your reserve." % [c.value, mag])
			else:
				lines.append("Melee, power %d. Never runs out; +%d points for every kill up close. Its notch clears at the start of every wave." % [c.value, bal.shown(int(bal.points("up_close")))])
			lines.append("Into slot 1 or slot 2 (the weapon there is scrapped, +%d), or scrap it (+%d). It arrives fresh%s." % [bal.shown(int(bal.points("scrap"))), bal.shown(int(bal.points("scrap"))), " with a full magazine" if mag > 0 else ""])
			lines.append("Notch rule: after each kill it can only hit zombies weaker than that kill.")
		DDCard.AMMO:
			lines.append("Ammo: +%d rounds into your shared reserve (max %d). Reloading moves rounds from the reserve into a gun." % [c.value, bal.num("reserve_cap")])
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
	if c.skipped:
		lines.append("Skipped earlier: it came back with this wave.")
	return "\n".join(lines)
