# dd_text.gd
# Purpose: Every player-facing name and rules sentence for DeadDraw v3 "Kill Stacks": zombie /
#   medkit / cover names by number, gun rules and challenges, Patches, machines, survivors,
#   bosses, first-run hints. Numbers inside sentences come from DDBalance so a retune of
#   balance.json updates the text too. Points are always written as the player sees them (x10).
#   All machine / Patch / gun names are original to DeadDraw.
# Dependencies: DDBalance, DDCard, DDGun (DDRun is passed in as an Object, never referenced as a
#   type here, to avoid a cyclic dependency).
# Author: Mechanics Developer Agent
class_name DDText
extends RefCounted

const PATCH_NAMES: Dictionary = {
	"lookout": "Lookout", "thick_jacket": "Thick Jacket", "field_medic": "Field Medic", "brawler": "Brawler",
	"bounty": "Bounty Hunter", "loose_grip": "Loose Grip", "second_wind": "Second Wind", "trophy_belt": "Trophy Belt",
}

const PASSIVE_NAMES: Dictionary = {"steady_hands": "Steady Hands", "triage": "Triage", "slip_away": "Slip Away"}

const TRAIT_NAMES: Dictionary = {"shatter": "Shatter", "horde": "Horde", "phases": "Phases"}

const MACHINE_NAMES: Dictionary = {"bench": "Retrofit Bench", "patch": "Patch Press", "wall": "Wall Rack"}

const CHALLENGE_NAMES: Dictionary = {
	"mixed_bag": "Mixed Bag", "countdown": "Countdown", "staircase": "Staircase", "big_game": "Big Game",
	"wide_swing": "Wide Swing", "drift": "Drift", "full_spread": "Full Spread", "point_blank": "Point Blank", "trophy": "Trophy",
}

const RULE_ICONS: Dictionary = {
	"any": "ANY", "down": "DOWN", "up": "UP", "same": "SAME", "zigzag": "ZIG-ZAG", "close": "CLOSE",
	"parity": "ODD/EVEN", "spread": "SUM", "big": "BIG",
}


static func zombie_name(v: int) -> String:
	if v <= 3:
		return "Shambler"
	if v <= 6:
		return "Lurcher"
	if v <= 9:
		return "Bruiser"
	return "Hulk"


static func medkit_name(v: int) -> String:
	if v <= 3:
		return "Bandage"
	if v <= 5:
		return "First Aid Kit"
	return "Trauma Kit"


static func cover_name(v: int) -> String:
	match v:
		2:
			return "Plywood"
		3:
			return "Car Door"
		4:
			return "Dumpster"
	return "Barricade"


static func card_name(c: DDCard, bal: DDBalance = null) -> String:
	if c.boss_name != "":
		return c.boss_name
	match c.kind:
		DDCard.ZOMBIE:
			return zombie_name(c.value)
		DDCard.WEAPON:
			var b: DDBalance = bal if bal != null else DDBalance.get_default()
			return b.weapon_name(c.wid)
		DDCard.MEDKIT:
			return medkit_name(c.value)
		DDCard.COVER:
			return cover_name(c.value)
	return "Card"


static func kind_label(kind: String) -> String:
	match kind:
		DDCard.ZOMBIE:
			return "ZOMBIE"
		DDCard.WEAPON:
			return "GUN"
		DDCard.MEDKIT:
			return "MEDKIT"
		DDCard.COVER:
			return "COVER"
	return ""


static func zombie_list(zs: Array) -> String:
	var p: PackedStringArray = []
	for z: Variant in zs:
		p.append(str(int(z)))
	return ", ".join(p)


## "7 zombies (4-9)".
static func zombie_summary(zs: Array) -> String:
	if zs.is_empty():
		return "no zombies"
	var lo: int = 999
	var hi: int = -999
	for z: Variant in zs:
		lo = mini(lo, int(z))
		hi = maxi(hi, int(z))
	return "%d zombie%s (%s)" % [zs.size(), "" if zs.size() == 1 else "s", ("%d" % lo) if lo == hi else ("%d-%d" % [lo, hi])]


## "4-9".
static func zombie_range(zs: Array) -> String:
	if zs.is_empty():
		return "-"
	var lo: int = 999
	var hi: int = -999
	for z: Variant in zs:
		lo = mini(lo, int(z))
		hi = maxi(hi, int(z))
	return ("%d" % lo) if lo == hi else ("%d-%d" % [lo, hi])


static func cards_text(cards: Array, bal: DDBalance) -> String:
	var p: PackedStringArray = []
	for c: Variant in cards:
		var cc: DDCard = c
		if cc.kind == DDCard.WEAPON:
			p.append(card_name(cc, bal))
		else:
			p.append("%s %d" % [kind_label(cc.kind).capitalize(), cc.value])
	return ", ".join(p) if not p.is_empty() else "nothing"


## A pack spec entry ("W", "M4", "C2") as words.
static func pack_entry(spec: String) -> String:
	if spec == "W":
		return "a gun"
	if spec.begins_with("M"):
		return "medkit %s" % spec.substr(1)
	if spec.begins_with("C"):
		return "cover %s" % spec.substr(1)
	return spec


# ---------------------------------------------------------------- gun rules
## The short rule a gun card shows: "lower than the top kill".
static func rule_short(rule: String, rosa: bool = false) -> String:
	match rule:
		"any":
			return "anything"
		"down":
			return "lower than the top kill" if not rosa else "lower or equal to the top kill"
		"up":
			return "higher than the top kill" if not rosa else "higher or equal to the top kill"
		"same":
			return "the same number as the first kill"
		"zigzag":
			return "zig-zag: up after down, down after up"
		"close":
			return "within 1 of the top kill"
		"parity":
			return "odd after even, even after odd"
		"spread":
			return "anything while the total stays at 16 or less"
		"big":
			return "6 or more only"
	return rule


## The full rule for a zoom.
static func rule_text(rule: String, bal: DDBalance, rosa: bool = false) -> String:
	match rule:
		"any":
			return "No rule: every zombie is a legal kill."
		"down":
			return "Each new kill must be LOWER than the top kill%s (the first kill can be anything)." % (" or equal (Steady Hands)" if rosa else "")
		"up":
			return "Each new kill must be HIGHER than the top kill%s (the first kill can be anything)." % (" or equal (Steady Hands)" if rosa else "")
		"same":
			return "Every kill must be the SAME number as the first kill."
		"zigzag":
			return "Zig-zag: if the last step went up, this one must go down (and vice versa). Never equal."
		"close":
			return "Each new kill must be within 1 of the top kill (equal is fine)."
		"parity":
			return "Odd after even, even after odd."
		"spread":
			return "Anything, as long as the stack total stays at %d or less. Finished at its capacity or at a total of %d." % [bal.num("spread_cap"), bal.num("spread_cap")]
		"big":
			return "Only zombies of %d or more." % bal.num("big_min")
	return ""


## Why a gun can't take zombie z right now ("needs lower than 4").
static func rule_block(g: DDGun, z: int, run: Object) -> String:
	if g == null:
		return "empty slot"
	var rosa: bool = run != null and bool(run.call("steady"))
	var t: int = g.top()
	match g.rule:
		"down":
			return "rule: needs %s %d" % ["at most" if rosa else "lower than", t]
		"up":
			return "rule: needs %s %d" % ["at least" if rosa else "higher than", t]
		"same":
			return "rule: needs a %d" % g.stack[0]
		"close":
			return "rule: needs %d-%d" % [t - 1, t + 1]
		"parity":
			return "rule: needs an %s number" % ("even" if t % 2 == 1 else "odd")
		"spread":
			return "rule: total would be %d (max 16)" % (g.total() + z)
		"big":
			return "rule: needs 6 or more"
		"zigzag":
			if z == t:
				return "rule: never equal"
			var up: bool = g.stack.size() > 1 and t > g.stack[g.stack.size() - 2]
			return "rule: must go %s from %d" % ["down" if up else "up", t]
	return "rule forbids it"


static func challenge_name(id: String) -> String:
	return str(CHALLENGE_NAMES.get(id, id.capitalize()))


static func challenge_text(id: String, bal: DDBalance) -> String:
	match id:
		"mixed_bag":
			return "every kill a different number"
		"countdown":
			return "the last 3 kills go down by exactly 1 (6-5-4)"
		"staircase":
			return "3 consecutive numbers in a row going up (4-5-6)"
		"big_game":
			return "the number is 6 or more"
		"wide_swing":
			return "every step is 2 or more apart"
		"drift":
			return "the last kill is 3+ away from the first"
		"full_spread":
			return "every kill a different number"
		"point_blank":
			return "the total is exactly %d" % bal.num("spread_cap")
		"trophy":
			return "both kills 8 or more"
	return ""


static func reward_text(kind: String, amount: int, bal: DDBalance) -> String:
	match kind:
		"points":
			return "+%d points" % bal.shown(amount)
		"heal":
			return "heal %d" % amount
		"cover":
			return "+%d Cover" % amount
		"encore":
			return "Encore: the gun stays, its stack resets"
	return ""


static func reward_short(kind: String, amount: int, bal: DDBalance) -> String:
	match kind:
		"points":
			return "+%d pts" % bal.shown(amount)
		"heal":
			return "+%d HP" % amount
		"cover":
			return "+%d Cover" % amount
		"encore":
			return "ENCORE"
	return ""


## "P4 - cap 4 - lower than the top kill".
static func gun_stats(wid: String, bal: DDBalance) -> String:
	return "Power %d, capacity %d. Rule: %s." % [bal.weapon_power(wid), bal.weapon_cap(wid), rule_short(bal.weapon_rule(wid))]


static func gun_card_text(wid: String, bal: DDBalance, rosa: bool = false) -> String:
	var rw: Array = bal.weapon_reward(wid)
	var cap: String = "%d kills" % bal.weapon_cap(wid)
	if bal.weapon_rule(wid) == "spread":
		cap += " or a total of %d" % bal.num("spread_cap")
	return "Power %d - finished at %s.\nRule: %s\nChallenge %s: %s -> %s.\nEvery kill pays its number now; finishing pays +%d more." % [
		bal.weapon_power(wid), cap, rule_text(bal.weapon_rule(wid), bal, rosa), challenge_name(bal.weapon_challenge(wid)),
		challenge_text(bal.weapon_challenge(wid), bal), reward_text(str(rw[0]), int(rw[1]), bal), bal.shown(bal.num("finish_bonus"))]


# ---------------------------------------------------------------- patches, machines, people
static func patch_name(id: String) -> String:
	return str(PATCH_NAMES.get(id, id.capitalize()))


static func patch_text(id: String, bal: DDBalance) -> String:
	match id:
		"lookout":
			return "You always see the top card of the pile. Once per street you may send it to the bottom."
		"thick_jacket":
			return "+%d max HP (and heal %d now)." % [bal.num("thick_jacket_hp"), bal.num("thick_jacket_hp")]
		"field_medic":
			return "Medkits heal +%d." % bal.num("field_medic_bonus")
		"brawler":
			return "Melee +%d power." % bal.num("brawler_bonus")
		"bounty":
			return "Finishing a gun pays +%d per zombie in its stack." % bal.shown(1)
		"loose_grip":
			return "Once per wave, one gun kill may ignore its rule."
		"second_wind":
			return "Once per run, when you would drop to 0 HP, you go to %d instead." % bal.num("second_wind_hp")
		"trophy_belt":
			return "Heal %d whenever you finish a gun." % bal.num("trophy_belt_heal")
	return ""


static func machine_name(kind: String) -> String:
	return str(MACHINE_NAMES.get(kind, kind.capitalize()))


static func machine_text(m: Dictionary, bal: DDBalance) -> String:
	match str(m.get("kind", "")):
		"bench":
			return "A grimy workbench with a hand-cranked lathe. Once per wave, one service on an equipped gun:\nTRIM %d: take the top kill off the stack (it already paid); the rule checks the kill below and the gun gets one capacity back.\nFLIP %d: a Rifle-style DOWN rule becomes UP (or back).\nHONE %d: +1 power for that gun (once per gun)." % [
				bal.shown(bal.bench_price("trim")), bal.shown(bal.bench_price("flip")), bal.shown(bal.bench_price("hone"))]
		"patch":
			return "A rusty heat press. Once per wave: pay, it shows %d random Patches, you take 1 for the rest of the run. Price rises with every Patch you own (%s)." % [
				bal.num("patch_offer"), ", ".join(PackedStringArray(bal.list("patch_costs").slice(0, 4).map(func(x: Variant) -> String: return str(bal.shown(int(x))))))]
		"wall":
			var wid: String = str(m.get("wid", ""))
			return "A chalk-outlined %s on hooks. Once per wave: buy it into a slot for %d.\n%s" % [bal.weapon_name(wid), bal.shown(bal.weapon_price(wid)), gun_card_text(wid, bal)]
	return ""


static func passive_name(passive: String) -> String:
	return str(PASSIVE_NAMES.get(passive, passive))


static func passive_text(passive: String, bal: DDBalance) -> String:
	match passive:
		"steady_hands":
			return "Hunting Rifle and Ratchet Crossbow rules also accept an EQUAL number."
		"triage":
			return "Medkits heal +%d." % bal.num("triage_bonus")
		"slip_away":
			return "Run costs no HP."
	return ""


static func trait_name(t: String) -> String:
	return str(TRAIT_NAMES.get(t, t.capitalize()))


static func trait_text(t: String) -> String:
	match t:
		"shatter":
			return "The gun that kills it is finished at once (collected with the bonus, no challenge). Melee is not affected."
		"horde":
			return "All three arrive at once."
		"phases":
			return "8, then 10, then 12: each phase appears only when the one before is dead. You cannot Run from Patient Zero."
	return ""


static func boss_summary(b: Dictionary) -> String:
	var zs: Array = b.get("zombies", [])
	var parts: PackedStringArray = []
	for z: Variant in zs:
		parts.append(str(int(z)))
	return " -> ".join(parts) if str(b.get("trait", "")) == "phases" else " / ".join(parts)


# ---------------------------------------------------------------- first-run hints (K5)
static func hint_text(id: String, bal: DDBalance) -> String:
	# dd-ux-clean: first-run hints, one short sentence each
	if id.begins_with("rule_"):
		var wid: String = id.trim_prefix("rule_")
		return "%s: each kill must be %s. %d kills finish it." % [bal.weapon_name(wid), rule_short(bal.weapon_rule(wid)), bal.weapon_cap(wid)]
	match id:
		"weapon":
			return "Tap a weapon below, then tap a zombie. The red chip is the damage you'd take."
		"points":
			return "Gun kills pay points (melee pays nothing)."
		"finish":
			return "One more kill finishes this gun: +%d bonus, then equip the next one." % bal.shown(bal.num("finish_bonus"))
		"challenge":
			return "Challenge met! Long press a gun to read its challenge."
		"rooms":
			return "You can afford a room: tap OPEN. Its machine switches on."
		"run":
			return "Bad street? RUN puts it back for %d HP." % bal.num("run_damage")
	return ""


## dd-ux-clean: the rule as a short label for the gun tile (icon + label; full text on inspect).
static func rule_tag(rule: String, rosa: bool = false) -> String:
	match rule:
		"any":
			return "ANY ZOMBIE"
		"down":
			return "LOWER THAN TOP" if not rosa else "LOWER OR EQUAL"
		"up":
			return "HIGHER THAN TOP" if not rosa else "HIGHER OR EQUAL"
		"same":
			return "SAME NUMBER"
		"zigzag":
			return "ZIG-ZAG"
		"close":
			return "WITHIN 1 OF TOP"
		"parity":
			return "ODD / EVEN"
		"spread":
			return "TOTAL 16 MAX"
		"big":
			return "6 OR MORE"
	return rule.to_upper()
