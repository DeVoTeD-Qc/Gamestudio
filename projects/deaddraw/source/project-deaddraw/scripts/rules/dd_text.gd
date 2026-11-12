# dd_text.gd
# Purpose: Every player-facing name and rules sentence for DeadDraw v4 "Kill Stacks": zombie /
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
	# v4
	"lockpick": "Lockpick", "iron_stomach": "Iron Stomach", "adrenaline": "Adrenaline", "grudge": "Grudge",
	"show_off": "Show-Off", "whetstone": "Whetstone",
}

const PASSIVE_NAMES: Dictionary = {"steady_hands": "Steady Hands", "triage": "Triage", "slip_away": "Slip Away"}

const TRAIT_NAMES: Dictionary = {"shatter": "Shatter", "horde": "Horde", "phases": "Phases"}

const MACHINE_NAMES: Dictionary = {"bench": "Retrofit Bench", "patch": "Patch Press", "wall": "Wall Rack"}

const CHALLENGE_NAMES: Dictionary = {
	"mixed_bag": "Mixed Bag", "countdown": "Countdown", "staircase": "Staircase", "big_game": "Big Game",
	"wide_swing": "Wide Swing", "drift": "Drift", "full_spread": "Full Spread", "point_blank": "Point Blank", "trophy": "Trophy",
	"big_bang": "Big Bang", "pest_control": "Pest Control",
}


## dd-art-import45 (art pack 4): each zombie value's character name, the card title (the tier word,
## zombie_name(), stays the rules name). "" outside 1-12.
const ZOMBIE_TITLES: Array[String] = ["", "Slippers", "Librarian", "Postman", "Jogger", "Courier", "Night Cook",
	"Mover", "Road Crew", "Bouncer", "Trucker", "Strongman", "Titan"]


static func zombie_title(v: int) -> String:
	return ZOMBIE_TITLES[v] if v >= 1 and v < ZOMBIE_TITLES.size() else ""


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
		DDCard.MELEE:
			var b2: DDBalance = bal if bal != null else DDBalance.get_default()
			return b2.melee_name(c.wid)
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
		DDCard.MELEE:
			return "MELEE"
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
		if cc.kind == DDCard.WEAPON or cc.kind == DDCard.MELEE:
			p.append(card_name(cc, bal))
		else:
			p.append("%s %d" % [kind_label(cc.kind).capitalize(), cc.value])
	return ", ".join(p) if not p.is_empty() else "nothing"


## A pack spec entry ("W", "M4", "C2") as words.
static func pack_entry(spec: String) -> String:
	if spec == "W":
		return "a gun"
	if spec == "K":
		return "a melee weapon"
	if spec.begins_with("M"):
		return "medkit %s" % spec.substr(1)
	if spec.begins_with("C"):
		return "cover %s" % spec.substr(1)
	return spec


# ---------------------------------------------------------------- gun rules
# dd-ux-text: ONE notation per rule, used everywhere (gun tile, tooltips, Codex, Glossary, log, the
# zombie's lit / dark line and the blocked-tap toast):
#   - the rule itself, relative to the last kill: rule_tag() (tile, caps) and rule_short() (words);
#   - what the next kill needs right now, always as a number with the same symbols: need_tag()
#     for the small kill socket "≤5", "≥8", "=5", "4-6", "odd", "any"; need_words() for text
#     "≤5", "≥8", "exactly 5", "4-6", "an odd number", "any zombie";
#   - a zombie the gun can't take: "needs ≤5" (rule_block()), on the card, in its tooltip and in
#     the toast.
# A zombie-number threshold is always written ≤N / ≥N (never "at most", "or more", "<6", ">4").

## The short rule, after "Each kill:": "lower than the last kill".
static func rule_short(rule: String, rosa: bool = false) -> String:
	match rule:
		"any":
			return "any zombie"
		"down":
			return "lower than the last kill" if not rosa else "the last kill or lower"
		"up":
			return "higher than the last kill" if not rosa else "the last kill or higher"
		"same":
			return "the same number as the first kill"
		"zigzag":
			return "up, then down, then up (never equal)"
		"close":
			return "within 1 of the last kill"
		"parity":
			return "odd, then even, then odd"
		"spread":
			return "any, while the total stays ≤16"
		"big":
			return "≥6 only"
		"small":
			return "≤6 only"
		"heavy":
			return "any zombie; one kill fills it"
	return rule


## The full rule for the Codex / a zoom body: "Each kill: lower than the last kill. The first is free."
static func rule_text(rule: String, bal: DDBalance, rosa: bool = false) -> String:
	match rule:
		"any":
			return "Each kill: any zombie."
		"down", "up", "close", "zigzag", "parity":
			return "Each kill: %s. The first kill can be anything." % rule_short(rule, rosa)
		"same":
			return "Each kill: the same number as the first kill."
		"spread":
			return "Each kill: any, while the total stays ≤%d. Full at its capacity or at a total of %d." % [bal.num("spread_cap"), bal.num("spread_cap")]
		"big":
			return "Each kill: ≥%d only." % bal.num("big_min")
		"small":
			return "Each kill: ≤%d only." % bal.num("small_max")
		"heavy":
			if bal.num("heavy_min") > 0:
				return "One shot: ≥%d, one kill per street." % bal.num("heavy_min")
			return "One shot: any zombie. One kill fills it."
	return ""


## What the next kill needs, from the legal numbers (1-12), for text: "≤5", "≥8", "exactly 5",
## "4-6", "an odd number", "any zombie" (the socket's symbols, a word where a symbol alone is bare).
static func need_words(zs: Array[int]) -> String:
	var t: String = need_tag(zs)
	if t == "any":
		return "any zombie"
	if t == "none":
		return "nothing (use melee)"
	if t.begins_with("="):
		return "exactly %s" % t.substr(1)
	if t == "odd" or t == "even":
		return "an %s number" % t
	return t


## The same for the small kill socket: "≤5", "≥8", "=5", "4-6", "odd", "even", "any", "none".
static func need_tag(zs: Array[int]) -> String:
	if zs.is_empty():
		return "none"
	if zs.size() >= 12:
		return "any"
	var contiguous: bool = zs[zs.size() - 1] - zs[0] == zs.size() - 1
	if zs.size() == 1:
		return "=%d" % zs[0]
	if contiguous and zs[0] == 1:
		return "≤%d" % zs[zs.size() - 1]
	if contiguous and zs[zs.size() - 1] == 12:
		return "≥%d" % zs[0]
	if contiguous:
		return "%d-%d" % [zs[0], zs[zs.size() - 1]]
	var odd: bool = true
	var even: bool = true
	for z: int in zs:
		odd = odd and z % 2 == 1
		even = even and z % 2 == 0
	if odd:
		return "odd"
	if even:
		return "even"
	return "≥%d" % zs[0] if zs.size() > 3 else ",".join(PackedStringArray(zs.map(func(z: int) -> String: return str(z))))


## Why a gun can't take zombie z right now: "needs ≤5" (the same notation as everywhere).
static func rule_block(g: DDGun, z: int, run: Object) -> String:
	if g == null:
		return "empty slot"
	if run != null and run.has_method("can_take"):
		var zs: Array[int] = run.call("can_take", g)
		# v5: a gun in a slot takes what its rule AND the slot's Gun Mod allow
		var si: int = (run.get("slots") as Array).find(g) if run.get("slots") is Array else -1
		if si >= 0 and run.has_method("can_take_slot"):
			zs = run.call("can_take_slot", si)
		if zs.has(z):
			return "one kill per street"
		return "needs " + need_words(zs)
	return "needs " + rule_short(g.rule)


static func challenge_name(id: String) -> String:
	return str(CHALLENGE_NAMES.get(id, id.capitalize()))


## dd-challenge-rack (head: "I have no idea what to do to complete them"): the rule in plain words
## with an example that pays and one that misses, in the ≤5 / ≥8 notation of the rules.
static func challenge_text(id: String, bal: DDBalance) -> String:
	match id:
		"mixed_bag":
			return "no number twice: every kill a different number (3, 9, 5, 11 pays; 3, 9, 3 misses)"
		"countdown":
			return "the last 3 kills step down by 1 (8, 6, 5, 4 pays: it ends 6-5-4; 8, 6, 4, 3 misses)"
		"staircase":
			return "3 kills in a row step up by 1, anywhere on the gun (2, 4, 5, 6 pays: 4-5-6; 2, 4, 6, 8 misses)"
		"big_game":
			return "the first kill is ≥6 (7, 7, 7 pays; 4, 4, 4 misses)"
		"wide_swing":
			return "every kill is 2+ away from the one before (3, 7, 4, 9, 2 pays; 3, 7, 6 misses)"
		"drift":
			return "the last kill is 3+ away from the first (4, 5, 6, 7, 7 pays: 7 is 3 from 4; 4, 5, 4, 5, 6 misses)"
		"full_spread":
			# the same check as Mixed Bag; on the Nail Driver the odd / even rule shapes the numbers
			return "no number twice, while the kills go odd, even, odd (3, 8, 5, 10 pays; 3, 8, 3 misses)"
		"point_blank":
			var cap: int = bal.num("spread_cap")
			return "the kills total exactly %d (5, 4, 7 = %d pays; 5, 4, 3, 2 = 14 misses)" % [cap, cap]
		"trophy":
			return "both kills ≥8 (9, 11 pays; 9, 6 misses)"
		"big_bang":
			var bb: int = bal.num("big_bang_min")
			return "the one kill is ≥%d (%d pays; %d misses)" % [bb, mini(12, bb + 1), bb - 2]
		"pest_control":
			var pt: int = bal.num("pest_total")
			return "the kills total ≤%d (2, 5, 3, 4 = 14 pays; 6, 6, 5 = 17 misses)" % pt
	return ""


## dd-challenge-rack: the goal in a few words, for the gun tile's challenge line ("end 6-5-4").
static func challenge_goal(id: String, bal: DDBalance) -> String:
	match id:
		"mixed_bag", "full_spread":
			return "no number twice"
		"countdown":
			return "end going 6-5-4"
		"staircase":
			return "3 in a row: 4-5-6"
		"big_game":
			return "1st kill ≥6"
		"wide_swing":
			return "each 2+ from the last"
		"drift":
			return "end 3+ from the 1st"
		"point_blank":
			return "total exactly %d" % bal.num("spread_cap")
		"trophy":
			return "both kills ≥8"
		"big_bang":
			return "the kill ≥%d" % bal.num("big_bang_min")
		"pest_control":
			return "total ≤%d" % bal.num("pest_total")
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
			return "Encore: the gun stays, its kills reset"
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
	return "Hits %d, holds %d. Each kill: %s." % [bal.weapon_power(wid), bal.weapon_cap(wid), rule_short(bal.weapon_rule(wid))]


static func gun_card_text(wid: String, bal: DDBalance, rosa: bool = false) -> String:
	var rw: Array = bal.weapon_reward(wid)
	var cap: String = "%d kills" % bal.weapon_cap(wid)
	if bal.weapon_rule(wid) == "spread":
		cap += " (or a total of %d)" % bal.num("spread_cap")
	return "Hits %d. Full at %s: +%d.\n%s\nChallenge %s: %s -> %s.\nEach kill pays its number." % [
		bal.weapon_power(wid), cap, bal.shown(bal.num("finish_bonus")), rule_text(bal.weapon_rule(wid), bal, rosa), challenge_name(bal.weapon_challenge(wid)),
		challenge_text(bal.weapon_challenge(wid), bal), reward_text(str(rw[0]), int(rw[1]), bal)]


# ---------------------------------------------------------------- patches, machines, people
static func patch_name(id: String) -> String:
	return str(PATCH_NAMES.get(id, id.capitalize()))


static func patch_text(id: String, bal: DDBalance) -> String:
	match id:
		"lookout":
			return "See the top card of the pile. Once per street, send it to the bottom."
		"thick_jacket":
			return "+%d max HP (and heal %d now)." % [bal.num("thick_jacket_hp"), bal.num("thick_jacket_hp")]
		"field_medic":
			return "Medkits heal +%d." % bal.num("field_medic_bonus")
		"brawler":
			if bal.text("brawler_mode") == "hands":
				return "Bare Hands hit %d harder. Melee weapons you pick up get +%d use." % [bal.num("brawler_bonus"), bal.num("brawler_dur")]
			return "Melee hits %d harder." % bal.num("brawler_bonus")
		"bounty":
			return "Finishing a gun pays +%d per zombie in its stack." % bal.shown(1)
		"loose_grip":
			return "Once per wave, one gun kill may break its rule."
		"second_wind":
			return "Once per run, at 0 HP you go to %d HP instead." % bal.num("second_wind_hp")
		"trophy_belt":
			return "Heal %d whenever you finish a gun." % bal.num("trophy_belt_heal")
		"lockpick":
			return "Rooms cost %d less." % bal.shown(bal.num("lockpick_off"))
		"iron_stomach":
			return "Healing above your max HP becomes Cover."
		"adrenaline":
			return "At %d HP or less, every weapon hits 1 harder." % bal.num("adrenaline_hp")
		"grudge":
			return "Hit 1 harder against zombies ≥%d (bosses too)." % bal.num("grudge_min")
		"show_off":
			return "Every challenge you meet pays +%d more." % bal.shown(bal.num("show_off_points"))
		"whetstone":
			return "Melee weapons you pick up get +%d uses." % bal.num("whetstone_dur")
	return ""


static func machine_name(kind: String) -> String:
	return str(MACHINE_NAMES.get(kind, kind.capitalize()))


static func machine_text(m: Dictionary, bal: DDBalance) -> String:
	match str(m.get("kind", "")):
		"bench":
			return "Once per wave, one service on a gun you hold:\nTRIM %d: remove the last kill (it stays paid); the gun gets a kill back.\nFLIP %d: LOWER becomes HIGHER (or back).\nHONE %d: the gun hits 1 harder (once per gun)." % [
				bal.shown(bal.bench_price("trim")), bal.shown(bal.bench_price("flip")), bal.shown(bal.bench_price("hone"))]
		"patch":
			return "Once per wave: pay, see %d Patches, keep 1 for the run. The price rises with each Patch you own (%s)." % [
				bal.num("patch_offer"), ", ".join(PackedStringArray(bal.list("patch_costs").slice(0, 4).map(func(x: Variant) -> String: return str(bal.shown(int(x))))))]
		"wall":
			var wid: String = str(m.get("wid", ""))
			return "Once per wave: buy the %s into a slot for %d.\n%s" % [bal.weapon_name(wid), bal.shown(bal.weapon_price(wid)), gun_card_text(wid, bal)]
	return ""


static func passive_name(passive: String) -> String:
	return str(PASSIVE_NAMES.get(passive, passive))


static func passive_text(passive: String, bal: DDBalance) -> String:
	match passive:
		"steady_hands":
			return "Hunting Rifle and Ratchet Crossbow also take an equal number."
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
			return "The gun that kills it is full at once (bonus, no challenge). Melee is fine."
		"horde":
			return "All three arrive at once."
		"phases":
			return "8, then 10, then 12: each comes when the one before dies. No Run."
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
		return "%s: each kill %s. %d kills fill it." % [bal.weapon_name(wid), rule_short(bal.weapon_rule(wid)), bal.weapon_cap(wid)]
	match id:
		"weapon":
			return "Tap a weapon below, then a zombie. The red chip is the HP you lose."
		"points":
			return "Gun kills pay points. Melee pays nothing."
		"finish":
			return "One more kill fills this gun: +%d, then equip the next one." % bal.shown(bal.num("finish_bonus"))
		"challenge":
			return "Challenge met! Long press a gun to read it."
		"rooms":
			return "You can afford a room: tap its gold OPEN plate."
		"run":
			if bal.text("run_return") == "bottom":
				return "Bad street? RUN: -%d HP, its cards go to the bottom of the pile." % bal.num("run_damage")
			return "Bad street? RUN: -%d HP, its cards go back into the pile." % bal.num("run_damage")
		"melee":
			return "Bare Hands hit %d. A melee weapon hits harder until its uses run out." % bal.num("hands_power")
	return ""


## dd-ux-clean: the rule as a short label for the gun tile (icon + label; full text on inspect).
static func rule_tag(rule: String, rosa: bool = false) -> String:
	match rule:
		"any":
			return "ANY ZOMBIE"
		"down":
			return "LOWER THAN LAST" if not rosa else "LAST OR LOWER"
		"up":
			return "HIGHER THAN LAST" if not rosa else "LAST OR HIGHER"
		"same":
			return "SAME AS FIRST"
		"zigzag":
			return "ZIG-ZAG"
		"close":
			return "WITHIN 1 OF LAST"
		"parity":
			return "ODD / EVEN"
		"spread":
			return "TOTAL ≤16"
		"big":
			return "≥6 ONLY"
		"small":
			return "≤6 ONLY"
		"heavy":
			return "ONE SHOT"
	return rule.to_upper()


# ---------------------------------------------------------------- v4: melee, salvage, Run, shop
## Melee weapon card text: "Power 3 - 4 uses. No rule, no points; breaks at 0 uses."
static func melee_card_text(mid: String, bal: DDBalance, uses: int = -1) -> String:
	var u: int = bal.melee_uses(mid) if uses < 0 else uses
	return "Hits %d, %s. Any zombie, no points. Each kill uses 1; at 0 it breaks (back to Bare Hands)." % [
		bal.melee_power(mid), uses_text(u)]


static func uses_text(n: int) -> String:
	return "%d use%s" % [n, "" if n == 1 else "s"]


static func bare_hands_text(bal: DDBalance) -> String:
	return "Hits %d. Any zombie, no points, never breaks." % bal.num("hands_power")


## "SALVAGE +30" (points as shown).
static func salvage_text(units: int, bal: DDBalance) -> String:
	return "SALVAGE +%d" % bal.shown(units)


## "4 cards (2 zombies, a medkit, a gun)" for the Run log line.
static func run_cards_text(cards: Array, _bal: DDBalance = null) -> String:
	var n: Dictionary = {}
	for c: Variant in cards:
		var k: String = (c as DDCard).kind
		n[k] = int(n.get(k, 0)) + 1
	var parts: PackedStringArray = []
	for k: String in [DDCard.ZOMBIE, DDCard.WEAPON, DDCard.MELEE, DDCard.MEDKIT, DDCard.COVER]:
		var m: int = int(n.get(k, 0))
		if m == 0:
			continue
		var word: String = {DDCard.ZOMBIE: "zombie", DDCard.WEAPON: "gun", DDCard.MELEE: "melee weapon", DDCard.MEDKIT: "medkit", DDCard.COVER: "cover"}[k]
		parts.append(("a %s" % word) if m == 1 else ("%d %ss" % [m, word]))
	var total: String = "%d card%s" % [cards.size(), "" if cards.size() == 1 else "s"]
	return total + (" (%s)" % ", ".join(parts) if not parts.is_empty() else "")


## The Run rule in one sentence (zoom / how to play).
static func run_rule_text(bal: DDBalance) -> String:
	var when: String = "any time on a street" if bal.text("run_mode") == "anytime" else "before you resolve a card"
	var where: String = "go to the bottom of the pile" if bal.text("run_return") == "bottom" else "go back into the pile"
	return "RUN costs %d HP (Theo: free), %s: the street's cards %s. Not twice in a row, not on a boss street." % [bal.num("run_damage"), when, where]


## Safehouse Shop: one line for the panel head.
static func shop_text(bal: DDBalance) -> String:
	return "Spend here: 1 Patch, or HP at %d pts each. Points don't come with you; your score keeps them." % bal.shown(bal.num("carry_heal_rate"))


## The Leave button: "LEAVE - 40 left behind".
static func leave_text(units: int, bal: DDBalance) -> String:
	return "LEAVE" if units <= 0 else "LEAVE - %d pts stay here (score keeps them)" % bal.shown(units)


# ---------------------------------------------------------------- v5 economy pass (economy-v5.md)
const MOD_NAMES: Dictionary = {"open_breech": "Open Breech", "last_round": "Last Round", "echo": "Echo Chamber",
	"short_barrel": "Short Barrel"}


static func mod_name(id: String) -> String:
	return str(MOD_NAMES.get(id, id.capitalize()))


## A Gun Mod's one-line rule (it works on every gun in its slot).
static func mod_text(id: String) -> String:
	match id:
		"open_breech":
			return "Kills 1 and 2 ignore the gun's rule."
		"last_round":
			return "The kill that fills the gun ignores its rule."
		"echo":
			return "A zombie equal to the top kill always fits."
		"short_barrel":
			return "The gun holds 1 fewer kill (at least 1): it fills sooner."
	return ""


## A short chip label for the gun tile: "MOD: LAST ROUND".
static func mod_chip(id: String) -> String:
	return "MOD · " + mod_name(id).to_upper()


## The safehouse line about points (head: points "went to 0 and I didn't understand why").
static func points_rule_text(bal: DDBalance) -> String:
	return "Points are for spending in this district. Unspent points stay here when you leave; your SCORE already counts every point you earned."


## The HUD score line.
static func score_text(units: int, bal: DDBalance) -> String:
	return "SCORE %d" % bal.shown(units)
