# dd_run.gd
# Purpose: The whole DeadDraw v4 ("Kill Stacks", polish pass) rules engine for one run, with no
#   nodes or UI. Every rule mirrors projects/deaddraw/tools/sim_deaddraw_v4.py (core-rules-v4.md).
#   v4 on top of the v3 text below: Salvage (swapping out an unfinished gun pays salvage_per_kill
#   per kill on its stack); Safehouse Shop (points don't leave a district: 1 Patch at the Press
#   price + supplies at carry_heal_rate points per HP, the rest is lost); Bare Hands (power 1,
#   unlimited, no points) + melee weapon cards "K" with uses (Pipe Wrench / Fire Axe /
#   Sledgehammer, no points); Brawler boosts bare hands only (+1 use on melee weapons); 6 new
#   Patches (Lockpick, Iron Stomach, Adrenaline, Grudge, Show-Off, Whetstone); new guns
#   Stovepipe Launcher (one shot) and Alley Sweeper (6 or less); no medkit-per-street limit; Run
#   any time on a street that has cards, every street card goes to the BOTTOM of the pile.
#   v5 economy pass (economy-v5.md, sim legal_mod / fit_mod): GUN MODS. At each safehouse you see
#   mod_offer of the 4 Gun Mods and may fit 1 (free) to gun slot 1 or 2, for the rest of the run;
#   every gun in that slot gets it (Open Breech: kills 1-2 ignore the rule; Last Round: the kill
#   that fills the gun ignores the rule; Echo Chamber: a zombie equal to the top kill always fits;
#   Short Barrel: holds 1 fewer kill, at least 1).
#   v3 base (sim_deaddraw_v3.py, core-rules-v3.md):
#   3 districts; each has 3 WAVE decks (left) + a face-up boss, 3 ROOM decks with prices (right)
#   and one mixed DRAW PILE (middle). District start: Entrance + Wave 1 are shuffled into the pile;
#   when the pile runs dry while dealing, the next wave deck (+1 restock card per opened room) is
#   shuffled in. Opening a room (any time you can pay) shuffles its pack in and switches on its
#   machine (Retrofit Bench, Patch Press, Wall Rack; once per wave each). A street deals 4, you
#   resolve 3, 1 stays (Holdover). Run: shuffle the street back for 1 damage (Theo: free), not
#   twice in a row, never on a boss street. Two gun slots + always-on melee (power 2, no rule, no
#   stack, no points). Damage = zombie - power (min 0), Cover first. Every gun has a RULE on the
#   order of its kills and a CAPACITY; kills stack on it and each gun kill pays the zombie's number
#   at once (K1); a full stack FINISHES the gun: +finish bonus (+Bounty Hunter, Trophy Belt), its
#   CHALLENGE is checked (points / heal / cover / Encore) and the gun leaves (Encore: it stays with
#   an empty stack). Replacing an unfinished gun pays ditch_share of its stack (0). Patches are
#   permanent perks. Bosses: Shatter (the gun that kills it is finished, no challenge), Horde
#   (three at once), Phases (Patient Zero 8 -> 10 -> 12, each appears when the last dies; no Run,
#   no run-past). District bosses can be run past for 3 damage and no reward. Safehouse heals 8.
#   The UI only calls the public methods below and renders the returned event dictionaries.
# Dependencies: DDBalance, DDCard, DDGun, DDText.
# Author: Mechanics Developer Agent
class_name DDRun
extends RefCounted

## Emitted after every state change with an event dictionary (see _event()).
signal changed(ev: Dictionary)

enum Phase { STREET, SAFEHOUSE, DEAD, WON }

## Weapon indices: gun slot 1, gun slot 2, melee.
const SLOT1: int = 0
const SLOT2: int = 1
const MELEE: int = 2
## Choices for a gun card.
const EQUIP1: String = "slot1"
const EQUIP2: String = "slot2"
const SCRAP: String = "scrap"
const USE: String = "use"
## Choice for a melee weapon card (USE is accepted as the same thing).
const TAKE: String = "take"

var bal: DDBalance
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var survivor_id: String = ""
var passive: String = ""
var hp: int = 20
var max_hp: int = 20
var cover: int = 0
var points: int = 0                    # spendable (sim units)
var points_earned: int = 0             # every point gained this run (spending doesn't lower it)
var slots: Array = [null, null]        # DDGun or null
## The active weapon (SLOT1 / SLOT2 / MELEE): every tap on a zombie attacks with it.
var active: int = SLOT1
var patches: Array[String] = []
var second_wind_used: bool = false
var loose: bool = false                # Loose Grip available this wave
## v4 melee slot: {} = Bare Hands, else {"id", "power", "uses"} (uses left).
var melee: Dictionary = {}
## v4 "heavy" rule: the gun in that slot already killed this street.
var fired: Array[bool] = [false, false]
## v4 Safehouse Shop: the 2 Patches offered (empty until the boss Patch is picked), whether one
## was bought, HP bought, and the points left behind when you left the last safehouse.
var shop_offer: Array[String] = []
var shop_patch_bought: bool = false
var shop_hp_bought: int = 0
var left_behind: int = 0
## v5 Gun Mods: the mod fitted to each gun slot ("" = none), this safehouse's offer, and whether
## one was fitted here already.
var slot_mods: Array[String] = ["", ""]
var mod_offer: Array[String] = []
var mod_fitted_here: bool = false

var district_index: int = 0
var wave_index: int = 0                # the last wave deck shuffled into the pile
var pile: Array[DDCard] = []           # top of the pile is the back (pop_back), like the sim
var street: Array[DDCard] = []
var room_open: Array[bool] = []
var room_pack_i: Array[int] = []       # restock: next card of the room's pack
var machine_used: Array[bool] = []     # this wave
var boss_street: bool = false
var boss_queue: Array[DDCard] = []     # Patient Zero phases still to appear
var pz_next: int = 0
var resolved: int = 0                  # cards resolved on this street
var budget: int = 3                    # cards this street lets you resolve
var med_used: int = 0
var ran_last: bool = false
var lookout_used: bool = false
## Patch choice waiting: {"offer": [ids], "source": "press" | "boss", "room": i}.
var pending_patch: Dictionary = {}
var phase: Phase = Phase.STREET
var last_wave_info: Dictionary = {}
var last_rooms_opened: int = 0

var cleared_ids: Array[String] = []
var boss_results: Array[Dictionary] = []   # per district: {beaten, ran_past, hp}
var stats: Dictionary = {}
var log_lines: Array[String] = []
var _notes: Array[String] = []
var _collects: Array[Dictionary] = []
var _waves: Array[Dictionary] = []


func _init(balance: DDBalance = null) -> void:
	bal = balance if balance != null else DDBalance.get_default()


# ================================================================ run setup
func start(survivor: String, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	survivor_id = survivor
	var s: Dictionary = bal.survivor(survivor)
	passive = str(s.get("passive", ""))
	hp = bal.survivor_hp(survivor)
	max_hp = hp
	cover = 0
	points = bal.num("start_points")
	points_earned = 0
	slots = [null, null]
	var kit: Array = bal.list("start_kit")
	for i: int in mini(2, kit.size()):
		slots[i] = make_gun(str(kit[i]))
	active = SLOT1 if slots[0] != null else MELEE
	melee = {}
	fired = [false, false]
	slot_mods = ["", ""]
	mod_offer.clear()
	mod_fitted_here = false
	shop_offer.clear()
	shop_patch_bought = false
	shop_hp_bought = 0
	left_behind = 0
	patches.clear()
	second_wind_used = false
	district_index = 0
	cleared_ids.clear()
	boss_results.clear()
	stats = {"streets": 0, "kills": 0, "gun_kills": 0, "melee_kills": 0, "finished": 0, "challenges": 0,
		"runs": 0, "rooms": 0, "machines": 0, "damage": 0, "salvage": 0, "melee_weapon_kills": 0, "melee_broken": 0,
		"left_behind": 0, "shop_hp": 0, "shop_patches": 0, "mods": 0}
	log_lines.clear()
	pending_patch = {}
	phase = Phase.STREET
	_start_district()


func district() -> Dictionary:
	return bal.district(district_index)


func boss_def() -> Dictionary:
	return bal.boss(district_index)


func is_final_district() -> bool:
	return district_index >= bal.district_count() - 1


func wave_count() -> int:
	return bal.wave_count(district_index)


func make_gun(wid: String) -> DDGun:
	return DDGun.make(wid, bal.weapon_name(wid), bal.weapon_rule(wid), bal.weapon_power(wid), bal.weapon_cap(wid))


## sim put_gun(): a new gun goes into slot s; its capacity follows the slot's Gun Mod.
func _put_gun(s: int, wid: String) -> void:
	var g: DDGun = make_gun(wid)
	g.cap = mod_cap(g.cap, slot_mod(s))
	slots[s] = g
	fired[s] = false


## sim mod_cap(): Short Barrel holds 1 fewer kill (at least 1).
static func mod_cap(cap: int, mod: String) -> int:
	return maxi(1, cap - 1) if mod == "short_barrel" else cap


func slot_mod(s: int) -> String:
	return slot_mods[s] if s >= 0 and s < slot_mods.size() else ""


func _shuffle(a: Array) -> void:
	# Fisher-Yates with our own rng so runs are reproducible from a seed.
	for k: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var t: Variant = a[k]
		a[k] = a[j]
		a[j] = t


func _pick(a: Array) -> Variant:
	return a[rng.randi_range(0, a.size() - 1)] if not a.is_empty() else null


## Cards from a pack / wave spec: ints = zombies, "W" = a gun from the district's pool (+ pool_add),
## "K" = a melee weapon from the district's melee pool, "W:id" / "K:id" a fixed card, "M4" medkit
## 4, "C2" cover 2 (sim make_cards()).
func make_cards(spec: Array) -> Array[DDCard]:
	var out: Array[DDCard] = []
	for x: Variant in spec:
		if not x is String:
			out.append(DDCard.make(DDCard.ZOMBIE, int(x)))
		elif str(x) == "W":
			out.append(DDCard.gun(str(_pick(bal.district_pool(district_index)))))
		elif str(x) == "K":
			out.append(DDCard.melee(str(_pick(bal.melee_pool(district_index)))))
		elif str(x).begins_with("W:") or str(x).begins_with("K:"):
			out.append(DDCard.parse(str(x)))
		else:
			var s: String = str(x)
			out.append(DDCard.make(DDCard.COVER if s.begins_with("C") else DDCard.MEDKIT, int(s.substr(1))))
	return out


func _start_district() -> void:
	var d: Dictionary = district()
	room_open.clear()
	room_pack_i.clear()
	machine_used.clear()
	for r: Variant in bal.rooms(district_index):
		room_open.append(false)
		room_pack_i.append(0)
		machine_used.append(false)
	wave_index = 0
	boss_street = false
	boss_queue.clear()
	pz_next = 0
	street.clear()
	ran_last = false
	pile = make_cards(bal.entrance_spec(district_index))
	pile.append_array(make_cards(bal.wave_spec(district_index, 0)))
	_shuffle(pile)
	loose = has_patch("loose_grip")
	last_wave_info = _wave_info(0, 0)
	_log("%s: wave 1 is in the pile." % str(d.get("name", "the district")))
	_deal()


## Test / debug hook: replace the pile (first code = next card dealt) and the street, then deal.
func setup_street(pile_codes: Array, street_codes: Array = [], deal: bool = true) -> void:
	pile.clear()
	for k: int in range(pile_codes.size() - 1, -1, -1):
		pile.append(as_card(pile_codes[k]))
	street.clear()
	for c: Variant in street_codes:
		street.append(as_card(c))
	boss_street = false
	boss_queue.clear()
	pending_patch = {}
	phase = Phase.STREET
	if deal:
		_deal()


func as_card(c: Variant) -> DDCard:
	if c is DDCard:
		return c
	return DDCard.parse(str(c))


## Shuffles the next wave deck (+ restock from opened rooms) into the pile. False if none left.
func _next_wave() -> bool:
	if wave_index + 1 >= wave_count():
		return false
	wave_index += 1
	var add: Array[DDCard] = make_cards(bal.wave_spec(district_index, wave_index))
	var restock: int = 0
	var rs: Array = bal.rooms(district_index)
	for i: int in rs.size():
		if not room_open[i]:
			continue
		var pack: Array = bal.room_pack(district_index, i)
		for k: int in bal.num("restock_per_room"):
			if pack.is_empty():
				continue
			add.append_array(make_cards([pack[room_pack_i[i] % pack.size()]]))
			room_pack_i[i] += 1
			restock += 1
	pile.append_array(add)
	_shuffle(pile)
	for i: int in machine_used.size():
		machine_used[i] = false
	if has_patch("loose_grip"):
		loose = true
	last_wave_info = _wave_info(wave_index, restock)
	_waves.append(last_wave_info)
	_log("Wave %d joins the pile: %s%s." % [wave_index + 1, DDText.zombie_summary(bal.wave_zombies(district_index, wave_index)),
		(" + %d restock" % restock) if restock > 0 else ""])
	return true


func _wave_info(w: int, restock: int) -> Dictionary:
	var spec: Array = bal.wave_spec(district_index, w)
	return {"wave": w, "district": district_index, "zombies": bal.wave_zombies(district_index, w), "cards": spec.size(),
		"restock": restock}


## Tops the street up to street_size (wave decks shuffle in when the pile runs dry), then starts
## the boss street when every wave is spent and at most one card is left (sim play_district()).
func _deal(mark_holdover: bool = false) -> void:
	var size: int = bal.num("street_size")
	for c: DDCard in street:
		c.holdover = mark_holdover
	while street.size() < size:
		if pile.is_empty() and not _next_wave():
			break
		if pile.is_empty():
			continue
		var dealt: DDCard = pile.pop_back()
		dealt.holdover = false
		street.append(dealt)
	resolved = 0
	med_used = 0
	lookout_used = false
	fired = [false, false]
	if street.size() <= 1 and pile.is_empty():
		_start_boss_street()
		return
	stats["streets"] = int(stats["streets"]) + 1
	budget = bal.num("actions") if street.size() >= size else maxi(1, street.size() - 1)


func _start_boss_street() -> void:
	var b: Dictionary = boss_def()
	boss_street = true
	boss_queue.clear()
	pz_next = 0
	var zs: Array = b.get("zombies", [])
	var tr: String = str(b.get("trait", ""))
	for k: int in zs.size():
		var c: DDCard = DDCard.boss(int(zs[k]), tr, str(b.get("name", "Boss")), k + 1 if tr == "phases" else 0)
		if tr == "phases" and k > 0:
			boss_queue.append(c)
		else:
			street.append(c)
	if tr == "phases":
		pz_next = 1
	med_used = 0
	fired = [false, false]
	resolved = 0
	budget = street.size() + boss_queue.size()
	stats["streets"] = int(stats["streets"]) + 1
	_log("Boss: %s. Resolve every card%s." % [str(b.get("name", "")), "" if is_final_district() else " (or run past)"])


# ================================================================ queries
func has_patch(id: String) -> bool:
	return patches.has(id)


func slot(i: int) -> DDGun:
	return slots[i] if i >= 0 and i < 2 else null


func steady() -> bool:
	return passive == "steady_hands"


## v4 hands mode: true while you hold a melee weapon card (false = Bare Hands).
func has_melee_weapon() -> bool:
	return not melee.is_empty()


func hands_mode() -> bool:
	return bal.text("melee_mode") == "hands"


## sim melee_power(): the melee weapon's power or Bare Hands (v3 crowbar: melee_power), + Brawler
## (v4: on bare hands only), + Adrenaline / Grudge against zombie z (0 = no zombie in mind).
func melee_power(z: int = 0) -> int:
	var p: int = bal.num("melee_power")
	if hands_mode():
		p = int(melee.get("power", 0)) if has_melee_weapon() else bal.num("hands_power")
	if has_patch("brawler") and not (has_melee_weapon() and bal.text("brawler_mode") == "hands"):
		p += bal.num("brawler_bonus")
	if passive == "slip_away":
		p += bal.num("theo_melee_bonus")
	return p + patch_power(z)


## sim patch_power(): v4 Patches that add power to every weapon (Adrenaline at low HP, Grudge
## against big zombies).
func patch_power(z: int = 0) -> int:
	var p: int = 0
	if has_patch("adrenaline") and hp <= bal.num("adrenaline_hp"):
		p += 1
	if has_patch("grudge") and z >= bal.num("grudge_min"):
		p += 1
	return p


## Power of `weapon` against zombie z (0: no zombie in mind, so Grudge is not counted).
func power_of(weapon: int, z: int = 0) -> int:
	if weapon == MELEE:
		return melee_power(z)
	var g: DDGun = slot(weapon)
	return g.power + patch_power(z) if g != null else 0


## Name of what you melee with: "Bare Hands", "Pipe Wrench"... (v3 rules: "Crowbar").
func melee_name() -> String:
	if not hands_mode():
		return "Crowbar"
	return bal.melee_name(str(melee.get("id", ""))) if has_melee_weapon() else "Bare Hands"


func melee_uses() -> int:
	return int(melee.get("uses", 0))


## Uses a melee weapon card would have if you took it now (+ Whetstone, + Brawler in hands mode).
func melee_take_uses(mid: String) -> int:
	var u: int = bal.melee_uses(mid)
	if has_patch("whetstone"):
		u += bal.num("whetstone_dur")
	if has_patch("brawler") and bal.text("brawler_mode") == "hands":
		u += bal.num("brawler_dur")
	return u


## Points a melee kill of zombie z pays (v4: none, with bare hands or a melee weapon).
func melee_points(z: int) -> int:
	return int(z * bal.fnum("melee_weapon_points" if has_melee_weapon() else "melee_points"))


## v4 Salvage: what swapping out gun g (unfinished) pays.
func salvage_for(g: DDGun) -> int:
	if g == null or g.stack.is_empty():
		return 0
	if bal.text("swap_salvage") == "per_kill":
		return bal.num("salvage_per_kill") * g.stack.size()
	return 0


## sim legal(): may `z` go on top of `stack` under `rule_id`?
func legal(rule_id: String, stack: Array[int], z: int, rosa: bool = false) -> bool:
	var big_min: int = bal.num("big_min")
	if rule_id == "small":
		return z <= bal.num("small_max")
	if rule_id == "heavy":
		return z >= bal.num("heavy_min")
	if stack.is_empty():
		return z >= big_min if rule_id == "big" else true
	var t: int = stack[stack.size() - 1]
	match rule_id:
		"any":
			return true
		"down":
			return z <= t if rosa else z < t
		"up":
			return z >= t if rosa else z > t
		"same":
			return z == stack[0]
		"close":
			return absi(z - t) <= 1
		"parity":
			return posmod(z - t, 2) == 1
		"spread":
			var s: int = 0
			for v: int in stack:
				s += v
			return s + z <= bal.num("spread_cap")
		"big":
			return z >= big_min
		"zigzag":
			if z == t:
				return false
			if stack.size() == 1:
				return true
			var prev: int = t - stack[stack.size() - 2]
			if prev == 0:
				# a flat step (Open Breech / Echo let an equal kill in): any change restarts the zig-zag
				return true
			return (z - t) * prev < 0
	return true


func gun_allows(g: DDGun, z: int) -> bool:
	return g != null and legal(g.rule, g.stack, z, steady())


## v5 sim legal_mod(): legal() with a slot's Gun Mod (cap = the gun's capacity in that slot).
func legal_mod(rule_id: String, stack: Array[int], z: int, rosa: bool, mod: String, cap: int) -> bool:
	if mod == "open_breech" and stack.size() < 2:
		return true
	if mod == "last_round" and cap > 0 and stack.size() == cap - 1:
		return true
	if mod == "echo" and not stack.is_empty() and z == stack[stack.size() - 1]:
		return true
	return legal(rule_id, stack, z, rosa)


## The rule of the gun in slot s (with that slot's Gun Mod) lets z on top of its stack.
func slot_rule_ok(s: int, z: int) -> bool:
	var g: DDGun = slot(s)
	return g != null and legal_mod(g.rule, g.stack, z, steady(), slot_mod(s), g.cap)


## True when the slot's Gun Mod, not the gun's own rule, is what lets z in.
func mod_lets_in(s: int, z: int) -> bool:
	var g: DDGun = slot(s)
	return g != null and slot_mod(s) != "" and slot_rule_ok(s, z) and not gun_allows(g, z)


## sim zombie_opts(): the gun in slot s may take z now (its rule with the slot's Gun Mod, and the
## heavy rule's one kill per street).
func slot_allows(s: int, z: int) -> bool:
	var g: DDGun = slot(s)
	return slot_rule_ok(s, z) and not (g.rule == "heavy" and fired[s])


func is_full(g: DDGun) -> bool:
	if g.stack.size() >= g.cap:
		return true
	return g.rule == "spread" and g.total() >= bal.num("spread_cap")


## sim challenge_met() on a (finished) stack.
func challenge_met(wid: String, stack: Array[int]) -> bool:
	var n: int = stack.size()
	if n == 0:
		return false
	match bal.weapon_challenge(wid):
		"mixed_bag", "full_spread":
			var seen: Dictionary = {}
			for z: int in stack:
				seen[z] = true
			return seen.size() == n
		"countdown":
			return n >= 3 and stack[n - 2] == stack[n - 3] - 1 and stack[n - 1] == stack[n - 2] - 1
		"staircase":
			for i: int in n - 2:
				if stack[i + 1] == stack[i] + 1 and stack[i + 2] == stack[i] + 2:
					return true
			return false
		"big_game":
			return stack[0] >= 6
		"wide_swing":
			for i: int in n - 1:
				if absi(stack[i + 1] - stack[i]) < 2:
					return false
			return true
		"drift":
			return absi(stack[n - 1] - stack[0]) >= 3
		"point_blank":
			var s: int = 0
			for z: int in stack:
				s += z
			return s == bal.num("spread_cap")
		"trophy":
			for z: int in stack:
				if z < 8:
					return false
			return true
		"big_bang":
			return stack.max() >= bal.num("big_bang_min")
		"pest_control":
			var t: int = 0
			for z: int in stack:
				t += z
			return t <= bal.num("pest_total")
	return false


## How the challenge looks on the current stack: "met" (locked in: it pays when the gun is full,
## or the gun is full and it paid), "on_track" (holds so far), "broken" (can't be met any more),
## "open" (nothing decided yet). For the gun card's badge and the challenge line.
func challenge_state(g: DDGun) -> String:
	if g == null:
		return "open"
	return challenge_status(g.wid, g.stack, g.cap, g.rule)


## dd-challenge-rack: challenge_state() for any stack of gun `wid` with `cap` kills (a Gun Mod can
## change the capacity; the spread rule is also full at a total of spread_cap).
func challenge_status(wid: String, stack: Array[int], cap: int, rule: String = "") -> String:
	var n: int = stack.size()
	var tot: int = 0
	for z: int in stack:
		tot += z
	if rule == "":
		rule = bal.weapon_rule(wid)
	var left: int = cap - n
	if n > 0 and (left <= 0 or (rule == "spread" and tot >= bal.num("spread_cap"))):
		return "met" if challenge_met(wid, stack) else "broken"
	match bal.weapon_challenge(wid):
		"mixed_bag", "full_spread":
			if n == 0:
				return "open"
			return "on_track" if challenge_met(wid, stack) else "broken"
		"countdown":
			# only the last 3 kills count: those already in that window must step down by 1, and
			# the steps still to come must stay ≥1
			if cap < 3:
				return "broken"
			var ws: int = cap - 3
			if n <= ws:
				return "open"
			for i: int in range(ws + 1, n):
				if stack[i] != stack[i - 1] - 1:
					return "broken"
			return "on_track" if stack[n - 1] - (cap - n) >= 1 else "broken"
		"staircase":
			if n >= 3 and challenge_met(wid, stack):
				return "met"
			var r: int = trailing_run(stack)
			var need: int = 3 - r
			if left >= 3 or (left >= need and n > 0 and stack[n - 1] + need <= 12):
				return "on_track" if r >= 2 else "open"
			return "broken"
		"big_game":
			if n == 0:
				return "open"
			return "met" if stack[0] >= 6 else "broken"
		"wide_swing", "trophy":
			if n == 0:
				return "open"
			return "on_track" if challenge_met(wid, stack) else "broken"
		"drift":
			if n == 0:
				return "open"
			if challenge_met(wid, stack):
				return "on_track"
			# the close rule moves at most 1 a kill: too few kills left to get 3 away
			if rule == "close" and absi(stack[n - 1] - stack[0]) + left < 3:
				return "broken"
			return "open"
		"point_blank":
			var want: int = bal.num("spread_cap") - tot
			if want < 0 or want > 12 * maxi(0, left):
				return "broken"
			return "open" if n == 0 else "on_track"
		"big_bang":
			return "open"
		"pest_control":
			if n == 0:
				return "open"
			return "on_track" if challenge_met(wid, stack) else "broken"
	return "met" if n > 0 and challenge_met(wid, stack) else "open"


## How many kills at the top of the stack go up by 1 in a row (1 for a single kill, 0 empty).
static func trailing_run(stack: Array[int]) -> int:
	var n: int = stack.size()
	if n == 0:
		return 0
	var r: int = 1
	while r < n and stack[n - r] == stack[n - r - 1] + 1:
		r += 1
	return mini(r, 3)


## dd-challenge-rack: what killing zombie z with the gun in slot s does to its challenge:
## "meets" (the kill fills the gun and it pays, or locks it in), "keeps" (still possible),
## "breaks" (this kill makes it impossible), "" (no gun, or it was already missed).
func challenge_kill(s: int, z: int) -> String:
	var g: DDGun = slot(s)
	if g == null or bal.weapon_challenge(g.wid) == "":
		return ""
	var before: String = challenge_state(g)
	if before == "broken":
		return ""
	var after: Array[int] = g.stack.duplicate()
	after.append(z)
	var st: String = challenge_status(g.wid, after, g.cap, g.rule)
	if st == "broken":
		return "breaks"
	if st == "met" and before != "met":
		return "meets"
	return "keeps"


## dd-challenge-rack: the zombie numbers the gun in slot s can take next that keep its challenge
## ("keeps" or "meets") and those that meet it.
func challenge_next(s: int) -> Dictionary:
	var keep: Array[int] = []
	var meet: Array[int] = []
	for z: int in can_take_slot(s):
		var k: String = challenge_kill(s, z)
		if k == "keeps" or k == "meets":
			keep.append(z)
		if k == "meets":
			meet.append(z)
	return {"keep": keep, "meet": meet, "can": can_take_slot(s)}


## The zombie numbers (1-12) the gun in slot s can still take (its rule + the slot's Gun Mod).
func can_take_slot(s: int) -> Array[int]:
	var out: Array[int] = []
	var g: DDGun = slot(s)
	if g == null:
		return out
	for z: int in range(1, 13):
		if slot_rule_ok(s, z):
			out.append(z)
	return out


## The zombie numbers (1-12) a gun can still take on its current stack.
func can_take(g: DDGun) -> Array[int]:
	var out: Array[int] = []
	if g == null:
		return out
	for z: int in range(1, 13):
		if gun_allows(g, z):
			out.append(z)
	return out


func is_boss_card(c: DDCard) -> bool:
	return c != null and c.is_boss()


func medkit_heal(c: DDCard) -> int:
	var amt: int = c.value
	if has_patch("field_medic"):
		amt += bal.num("field_medic_bonus")
	if passive == "triage":
		amt += bal.num("triage_bonus")
	return amt


func cards_left_to_resolve() -> int:
	if boss_street:
		return street.size() + boss_queue.size()
	return maxi(0, mini(budget - resolved, street.size()))


func pile_zombies() -> int:
	var n: int = 0
	for c: DDCard in pile:
		if c.kind == DDCard.ZOMBIE:
			n += 1
	return n


## {"Z": {7: 2, ...}, "W": n, "M": n, "C": n} - what is in the pile (counts, not order).
func pile_counts() -> Dictionary:
	var z: Dictionary = {}
	var out: Dictionary = {"W": 0, "M": 0, "C": 0}
	for c: DDCard in pile:
		if c.kind == DDCard.ZOMBIE:
			z[c.value] = int(z.get(c.value, 0)) + 1
		else:
			out[c.kind] = int(out.get(c.kind, 0)) + 1
	out["Z"] = z
	return out


## Lookout: the pile's top card (null without the Patch or with an empty pile).
func lookout_card() -> DDCard:
	if not has_patch("lookout") or pile.is_empty():
		return null
	return pile[pile.size() - 1]


## "waiting" | "active" | "done" for the left column.
func wave_status(w: int) -> String:
	if boss_street or w < wave_index:
		return "done"
	if w == wave_index:
		return "active"
	return "waiting"


func _busy_reason() -> String:
	if phase != Phase.STREET:
		return "not on the street"
	if not pending_patch.is_empty():
		return "pick your Patch first"
	return ""


# ---------------------------------------------------------------- attack preview
## What attacking street card `index` with `weapon` would do. Keys: ok, reason, damage (before
## Cover), absorbed, hp_loss, uses_loose, gun (slot), stack_pos, finishes, challenge, points,
## shatter, dies; v4: power (with Adrenaline / Grudge), melee_weapon (id, "" = bare hands),
## uses_left (after this kill), breaks (the melee weapon breaks on this kill).
func preview(index: int, weapon: int) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "damage": 0, "absorbed": 0, "hp_loss": 0, "uses_loose": false,
		"stack_pos": -1, "finishes": false, "challenge": false, "points": 0, "shatter": false, "dies": false,
		"power": 0, "melee_weapon": "", "uses_left": 0, "breaks": false}
	var br: String = _busy_reason()
	if br != "":
		out["reason"] = br
		return out
	if index < 0 or index >= street.size():
		out["reason"] = "no such card"
		return out
	var c: DDCard = street[index]
	if c.kind != DDCard.ZOMBIE:
		out["reason"] = "not a zombie"
		return out
	if not boss_street and resolved >= budget:
		out["reason"] = "no resolves left this street"
		return out
	if c.phase > 0 and c.phase != pz_next:
		out["reason"] = "phase %d comes first" % pz_next
		return out
	var p: int = 0
	if weapon == MELEE:
		p = melee_power(c.value)
		out["points"] = melee_points(c.value)
		if has_melee_weapon():
			out["melee_weapon"] = str(melee.get("id", ""))
			out["uses_left"] = melee_uses() - 1
			out["breaks"] = melee_uses() <= 1
	else:
		var g: DDGun = slot(weapon)
		if g == null:
			out["reason"] = "slot %d is empty" % (weapon + 1)
			return out
		p = g.power + patch_power(c.value)
		if not slot_allows(weapon, c.value):
			if loose:
				out["uses_loose"] = true
			else:
				out["reason"] = "one kill per street" if slot_rule_ok(weapon, c.value) else DDText.rule_block(g, c.value, self)
				return out
		var after: Array[int] = g.stack.duplicate()
		after.append(c.value)
		out["stack_pos"] = g.stack.size()
		var shatter: bool = c.boss_trait == "shatter"
		var tmp: DDGun = g.copy()
		tmp.stack = after
		out["shatter"] = shatter
		out["finishes"] = shatter or is_full(tmp)
		out["challenge"] = bool(out["finishes"]) and not shatter and challenge_met(g.wid, after)
		if bal.flag("points_on_kill"):
			out["points"] = c.value
	var dmg: int = maxi(0, c.value - p)
	var ab: int = mini(cover, dmg)
	out["power"] = p
	out["damage"] = dmg
	out["absorbed"] = ab
	out["hp_loss"] = dmg - ab
	out["dies"] = hp - (dmg - ab) <= 0 and not (has_patch("second_wind") and not second_wind_used)
	out["ok"] = true
	return out


func can_attack(index: int, weapon: int) -> bool:
	return bool(preview(index, weapon)["ok"])


## The choices for a non-zombie card: gun -> slot1 / slot2 / scrap; melee weapon -> take / scrap
## (USE also takes it); medkit, cover -> use.
func choices_for(index: int) -> Array[String]:
	var out: Array[String] = []
	if index < 0 or index >= street.size():
		return out
	match street[index].kind:
		DDCard.WEAPON:
			out.append_array([EQUIP1, EQUIP2, SCRAP])
		DDCard.MELEE:
			out.append_array([TAKE, SCRAP])
		DDCard.MEDKIT, DDCard.COVER:
			out.append(USE)
	return out


## What resolving a non-zombie card with `choice` does: {ok, reason, heal, wasted, cover, points,
## replaces}; v4: salvage (points the replaced gun's stack pays, included in points), kills
## (kills on the replaced gun), overheal (medkit heal past max HP), uses (a melee weapon's uses
## once taken), replaces_uses (uses left on the melee weapon it replaces).
func card_preview(index: int, choice: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "heal": 0, "wasted": false, "cover": 0, "points": 0, "replaces": "",
		"salvage": 0, "kills": 0, "overheal": 0, "uses": 0, "replaces_uses": 0}
	var br: String = _busy_reason()
	if br != "":
		out["reason"] = br
		return out
	if index < 0 or index >= street.size():
		out["reason"] = "no such card"
		return out
	if not boss_street and resolved >= budget:
		out["reason"] = "no resolves left this street"
		return out
	var c: DDCard = street[index]
	if c.kind == DDCard.MELEE and choice == USE:
		choice = TAKE
	if not choices_for(index).has(choice):
		out["reason"] = "can't do that with this card"
		return out
	match c.kind:
		DDCard.MEDKIT:
			if med_used >= bal.num("medkits_per_street"):
				out["wasted"] = true
			else:
				out["heal"] = mini(medkit_heal(c), max_hp - hp)
				out["overheal"] = maxi(0, medkit_heal(c) - (max_hp - hp))
				if has_patch("iron_stomach"):
					out["cover"] = int(out["overheal"])
		DDCard.MELEE:
			if choice == SCRAP:
				out["points"] = bal.num("scrap_points")
			else:
				out["uses"] = melee_take_uses(c.wid)
				if has_melee_weapon():
					out["replaces"] = melee_name()
					out["replaces_uses"] = melee_uses()
		DDCard.COVER:
			out["cover"] = c.value
		DDCard.WEAPON:
			if choice == SCRAP:
				out["points"] = bal.num("scrap_points")
			else:
				var s: int = 0 if choice == EQUIP1 else 1
				var g: DDGun = slot(s)
				if g != null:
					out["replaces"] = g.name
					out["kills"] = g.stack.size()
					out["salvage"] = salvage_for(g)
					out["points"] = int(g.total() * bal.fnum("ditch_share")) + int(out["salvage"])
	out["ok"] = true
	return out


# ================================================================ actions
## Makes `weapon` (SLOT1 / SLOT2 / MELEE) the active weapon. Free, any time.
func set_active(weapon: int) -> Dictionary:
	if weapon < SLOT1 or weapon > MELEE:
		return {"ok": false, "reason": "no such weapon"}
	if weapon != MELEE and slot(weapon) == null:
		return {"ok": false, "reason": "slot %d is empty" % (weapon + 1)}
	active = weapon
	return {"ok": true, "kind": "active", "active": active}


## Attacks street zombie `index` with the active weapon (or `weapon` when given).
func attack(index: int, weapon: int = -1) -> Dictionary:
	var w: int = active if weapon < 0 else weapon
	var pr: Dictionary = preview(index, w)
	if not bool(pr["ok"]):
		return {"ok": false, "reason": str(pr["reason"]), "kind": "blocked", "index": index}
	_begin()
	var c: DDCard = street[index]
	street.remove_at(index)
	var hp0: int = hp
	var pts0: int = points
	var cname: String = DDText.card_name(c)
	var line: String
	if w == MELEE:
		var mname: String = melee_name()
		_hurt(c.value - int(pr["power"]))
		var mp: int = melee_points(c.value)
		if mp > 0:
			_earn(mp)
		stats["melee_kills"] = int(stats["melee_kills"]) + 1
		line = "%s %d: %s (strength %d), %s." % [cname, c.value, mname, int(pr["power"]), _dmg_text(int(pr["damage"]), int(pr["absorbed"]))]
		if has_melee_weapon():
			stats["melee_weapon_kills"] = int(stats["melee_weapon_kills"]) + 1
			melee["uses"] = melee_uses() - 1
			if melee_uses() <= 0:
				melee = {}
				stats["melee_broken"] = int(stats["melee_broken"]) + 1
				_log(line)
				line = "%s breaks: back to Bare Hands." % mname
	else:
		var g: DDGun = slot(w)
		if bool(pr["uses_loose"]):
			loose = false
			_log("Loose Grip: this kill breaks the %s's rule." % g.name)
		_hurt(c.value - int(pr["power"]))
		if bal.flag("points_on_kill"):
			_earn(c.value)
		if g.rule == "heavy":
			fired[w] = true
		g.stack.append(c.value)
		stats["gun_kills"] = int(stats["gun_kills"]) + 1
		# r2 (playtest: the log said "(1/4)" while the banner said the gun is full at once): a
		# Shatter kill names no socket count; the collect line says the gun is destroyed
		var kill_pts: String = (", +%d pts" % bal.shown(c.value)) if bal.flag("points_on_kill") else ""
		if c.boss_trait == "shatter":
			line = "%s %d: %s%s, %s." % [cname, c.value, g.name, kill_pts, _dmg_text(int(pr["damage"]), int(pr["absorbed"]))]
		else:
			line = "%s %d: %s (%d/%d)%s, %s." % [cname, c.value, g.name, g.stack.size(), g.cap, kill_pts, _dmg_text(int(pr["damage"]), int(pr["absorbed"]))]
		_log(line)
		line = ""
		if c.boss_trait == "shatter" or is_full(g):
			_collect(w, true, c.boss_trait == "shatter", c.value if bal.flag("points_on_kill") else 0)
	if line != "":
		_log(line)
	stats["kills"] = int(stats["kills"]) + 1
	if c.phase > 0:
		pz_next = c.phase + 1
		if not boss_queue.is_empty():
			var nxt: DDCard = boss_queue.pop_front()
			street.append(nxt)
			_log("%s rises again: phase %d (%d)." % [nxt.boss_name, nxt.phase, nxt.value])
	var ev: Dictionary = _event("attack", _notes[0] if not _notes.is_empty() else "", hp - hp0, points - pts0)
	ev["card"] = c
	ev["weapon"] = w
	ev["slot"] = w if w != MELEE else -1
	ev["preview"] = pr
	ev["melee_broke"] = bool(pr["breaks"])
	return _after_resolve(ev)


## Resolves a gun / medkit / cover card: EQUIP1 / EQUIP2 / SCRAP, or USE.
func resolve(index: int, choice: String) -> Dictionary:
	var pr: Dictionary = card_preview(index, choice)
	if not bool(pr["ok"]):
		return {"ok": false, "reason": str(pr["reason"]), "kind": "blocked", "index": index}
	_begin()
	var c: DDCard = street[index]
	street.remove_at(index)
	var hp0: int = hp
	var pts0: int = points
	var slot_i: int = -1
	if c.kind == DDCard.MELEE and choice == USE:
		choice = TAKE
	match c.kind:
		DDCard.MEDKIT:
			if med_used >= bal.num("medkits_per_street"):
				_log("%s %d: one medkit per street, discarded." % [DDText.card_name(c), c.value])
			else:
				med_used += 1
				var cv0: int = cover
				_heal(medkit_heal(c), true)
				_log("%s: +%d HP%s." % [DDText.card_name(c), hp - hp0, (", +%d Cover (Iron Stomach)" % (cover - cv0)) if cover > cv0 else ""])
		DDCard.MELEE:
			if choice == SCRAP:
				_earn(bal.num("scrap_points"))
				_log("Scrapped the %s: +%d pts." % [bal.melee_name(c.wid), bal.shown(bal.num("scrap_points"))])
			else:
				var old: String = melee_name() if has_melee_weapon() else ""
				melee = {"id": c.wid, "power": bal.melee_power(c.wid), "uses": melee_take_uses(c.wid)}
				_log("You take the %s (power %d, %d uses)%s." % [bal.melee_name(c.wid), bal.melee_power(c.wid), melee_uses(),
					(" - it replaces your " + old) if old != "" else ""])
		DDCard.COVER:
			cover += c.value
			_log("%s: +%d Cover." % [DDText.card_name(c), c.value])
		DDCard.WEAPON:
			if choice == SCRAP:
				_earn(bal.num("scrap_points"))
				_log("Scrapped the %s: +%d pts." % [bal.weapon_name(c.wid), bal.shown(bal.num("scrap_points"))])
			else:
				slot_i = 0 if choice == EQUIP1 else 1
				if slot(slot_i) != null:
					_collect(slot_i, false, false)
				_put_gun(slot_i, c.wid)
				_log("%s into slot %d." % [bal.weapon_name(c.wid), slot_i + 1])
	var ev: Dictionary = _event(c.kind, _notes[_notes.size() - 1] if not _notes.is_empty() else "", hp - hp0, points - pts0)
	ev["card"] = c
	ev["choice"] = choice
	ev["slot"] = slot_i
	ev["preview"] = pr
	ev["salvage"] = int(pr.get("salvage", 0))
	return _after_resolve(ev)


func _begin() -> void:
	_notes.clear()
	_collects.clear()
	_waves.clear()
	last_rooms_opened = 0


func _dmg_text(dmg: int, ab: int) -> String:
	if dmg <= 0:
		return "no damage"
	if ab >= dmg:
		return "Cover takes %d" % ab
	if ab > 0:
		return "Cover takes %d, -%d HP" % [ab, dmg - ab]
	return "-%d HP" % dmg


func _after_resolve(ev: Dictionary) -> Dictionary:
	resolved += 1
	if hp <= 0:
		_die()
		ev["dead"] = true
	elif boss_street:
		if street.is_empty() and boss_queue.is_empty():
			_clear_district(false)
			ev["district_cleared"] = true
	elif resolved >= budget or street.size() <= 1:
		_end_street(ev)
	ev["collects"] = _collects.duplicate(true)
	ev["waves"] = _waves.duplicate(true)
	ev["hp"] = hp
	ev["max_hp"] = max_hp
	ev["hp_delta"] = int(ev.get("hp_delta", 0))
	return _emit(ev)


func _end_street(ev: Dictionary) -> void:
	ev["street_ended"] = true
	# "not twice in a row" (sim ran_last): a street you played to its end clears it
	ran_last = false
	_deal(true)
	if boss_street:
		ev["boss_street"] = true


## Banks the stack of the gun in slot i. Finished: finish bonus (+Bounty), Trophy Belt, then the
## challenge (unless shattered; + Show-Off); the gun leaves (Encore: it stays with an empty
## stack). Unfinished (swapped out): v4 Salvage pays per kill on its stack.
func _collect(i: int, finished: bool, shatter: bool, kill_units: int = 0) -> void:
	var g: DDGun = slot(i)
	if g == null:
		return
	var st: Array[int] = g.stack.duplicate()
	# sim collect(): with points_on_kill the kills were paid already; otherwise a finished stack
	# pays its sum. An early replace pays ditch_share of the stack either way.
	var pts: int = int(g.total() * bal.fnum("ditch_share"))
	if finished:
		pts = 0 if bal.flag("points_on_kill") else g.total()
	var info: Dictionary = {"slot": i, "wid": g.wid, "name": g.name, "stack": st, "finished": finished, "shatter": shatter,
		"bonus": 0, "bounty": 0, "challenge": false, "challenge_id": bal.weapon_challenge(g.wid), "reward": "", "reward_amount": 0,
		"encore": false, "heal": 0, "points": 0, "salvage": 0, "show_off": 0}
	var keep: bool = false
	var hp0: int = hp
	if not finished:
		var sv: int = salvage_for(g)
		info["salvage"] = sv
		pts += sv
		stats["salvage"] = int(stats["salvage"]) + sv
	if finished:
		info["bonus"] = bal.num("finish_bonus")
		pts += bal.num("finish_bonus")
		if has_patch("bounty"):
			info["bounty"] = st.size()
			pts += st.size()
		if has_patch("trophy_belt"):
			_heal(bal.num("trophy_belt_heal"))
		stats["finished"] = int(stats["finished"]) + 1
		if not shatter and challenge_met(g.wid, st):
			var rw: Array = bal.weapon_reward(g.wid)
			var kind: String = str(rw[0])
			var amt: int = int(rw[1])
			info["challenge"] = true
			info["reward"] = kind
			info["reward_amount"] = amt
			stats["challenges"] = int(stats["challenges"]) + 1
			if has_patch("show_off"):
				info["show_off"] = bal.num("show_off_points")
				pts += bal.num("show_off_points")
			match kind:
				"points":
					pts += amt
				"heal":
					_heal(amt)
				"cover":
					cover += amt
				"encore":
					keep = true
					info["encore"] = true
	info["heal"] = hp - hp0
	info["points"] = pts
	_earn(pts)
	if keep:
		g.stack.clear()
	else:
		slots[i] = null
		if active == i:
			active = (1 - i) if slot(1 - i) != null else MELEE
	_collects.append(info)
	if finished and shatter:
		# kill_units: the kill's own points (logged with the kill), so the line says the whole pay
		_log("Shatter: the %s is destroyed (+%d pts, no challenge)." % [g.name, bal.shown(kill_units + pts)])
	elif finished:
		var t: String = "%s full: +%d" % [g.name, bal.shown(bal.num("finish_bonus"))]
		if int(info["bounty"]) > 0:
			t += ", +%d Bounty Hunter" % bal.shown(int(info["bounty"]))
		if bool(info["challenge"]):
			t += ". %s! %s" % [DDText.challenge_name(str(info["challenge_id"])).to_upper(), DDText.reward_text(str(info["reward"]), int(info["reward_amount"]), bal)]
			if int(info["show_off"]) > 0:
				t += ", +%d Show-Off" % bal.shown(int(info["show_off"]))
		_log(t + ".")
	elif int(info["salvage"]) > 0:
		_log("%s swapped out: salvage +%d (%d kill%s)." % [g.name, bal.shown(pts), st.size(), "" if st.size() == 1 else "s"])
	elif not st.is_empty() or pts > 0:
		_log("%s replaced before it was full%s." % [g.name, (": +%d" % bal.shown(pts)) if pts > 0 else " (no bonus)"])


func _hurt(d: int) -> void:
	if d <= 0:
		return
	var a: int = mini(cover, d)
	cover -= a
	d -= a
	hp -= d
	stats["damage"] = int(stats["damage"]) + d
	if hp <= 0 and has_patch("second_wind") and not second_wind_used:
		second_wind_used = true
		hp = bal.num("second_wind_hp")
		_log("Second Wind: you get back up with %d HP." % hp)


## sim heal(): up to max HP; with overflow_cover (medkits) Iron Stomach turns the rest into Cover.
func _heal(n: int, overflow_cover: bool = false) -> void:
	var over: int = hp + n - max_hp
	hp = mini(max_hp, hp + n)
	if overflow_cover and over > 0 and has_patch("iron_stomach"):
		cover += over


# ---------------------------------------------------------------- Run
func can_run() -> bool:
	return run_block_reason() == ""


func run_cost() -> int:
	return 0 if passive == "slip_away" else bal.num("run_damage")


func run_block_reason() -> String:
	var br: String = _busy_reason()
	if br != "":
		return br
	if not bal.flag("allow_run"):
		return "Run is off"
	if boss_street:
		return "no escape from this boss" if is_final_district() else "boss street: use Run past"
	if ran_last:
		return "you ran last street"
	if street.is_empty():
		return "nothing on the street"
	if resolved > 0 and bal.text("run_mode") != "anytime":
		return "only before your first card"
	if pile.is_empty():
		return "the pile is empty"
	if hp <= run_cost():
		return "not enough HP"
	return ""


## Run: every card still on the street (zombies, guns, melee weapons, medkits, cover, the
## Holdover) goes back to the pile, you take run_damage (Theo: none), a new street is dealt. v4
## (run_mode "anytime"): allowed whenever the street has cards, even after resolving some or with
## no zombie on it; run_return "bottom": the cards go UNDER the pile in street order, unshuffled
## (v3 "shuffle": shuffled in). Not twice in a row (the street after a Run must be played to its
## end first), never on a boss street.
func run_street() -> Dictionary:
	var why: String = run_block_reason()
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var hp0: int = hp
	var back: Array[DDCard] = street.duplicate()
	_hurt(run_cost())
	for c: DDCard in street:
		c.holdover = false
	var bottom: bool = bal.text("run_return") == "bottom"
	if bottom:
		# sim: b.pile[:0] = back (the pile pops from the back, so index 0 is the bottom)
		var np: Array[DDCard] = street.duplicate()
		np.append_array(pile)
		pile = np
	else:
		pile.append_array(street)
		_shuffle(pile)
	street.clear()
	stats["runs"] = int(stats["runs"]) + 1
	_log("You run%s: %s go%s %s." % [(", -%d HP" % (hp0 - hp)) if hp0 > hp else " (free)", DDText.run_cards_text(back, bal), "es" if back.size() == 1 else "",
		"to the bottom of the pile" if bottom else "back into the pile"])
	_deal()
	ran_last = true
	var ev: Dictionary = _event("run", _notes[0], hp - hp0, 0)
	ev["returned"] = back
	ev["to_bottom"] = bottom
	ev["street_ended"] = true
	ev["waves"] = _waves.duplicate(true)
	if boss_street:
		ev["boss_street"] = true
	if hp <= 0:
		_die()
		ev["dead"] = true
	return _emit(ev)


## District bosses only, before the boss street's first card: take 3 damage, lose the reward.
func can_run_past() -> bool:
	return run_past_block_reason() == ""


func run_past_block_reason() -> String:
	var br: String = _busy_reason()
	if br != "":
		return br
	if not boss_street:
		return "not a boss street"
	if is_final_district():
		return "NO ESCAPE: you can't run from %s" % str(boss_def().get("name", ""))
	if resolved > 0:
		return "you already started the fight"
	return ""


func run_past() -> Dictionary:
	var why: String = run_past_block_reason()
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var hp0: int = hp
	_hurt(bal.num("boss_runpast_damage"))
	_log("You run past %s: -%d HP, no reward." % [str(boss_def().get("name", "")), hp0 - hp])
	var ev: Dictionary = _event("run_past", _notes[0], hp - hp0, 0)
	if hp <= 0:
		_die()
		ev["dead"] = true
	else:
		_clear_district(true)
		ev["district_cleared"] = true
	return _emit(ev)


# ---------------------------------------------------------------- Lookout
func can_bury() -> bool:
	return _busy_reason() == "" and lookout_card() != null and not lookout_used and pile.size() > 1


## Lookout: send the pile's top card to the bottom (once per street, before the next deal).
func bury_top() -> Dictionary:
	if not can_bury():
		return {"ok": false, "reason": "Lookout: once per street, with 2+ cards in the pile", "kind": "blocked"}
	_begin()
	var c: DDCard = pile.pop_back()
	pile.insert(0, c)
	lookout_used = true
	_log("Lookout: %s %d goes to the bottom of the pile." % [DDText.card_name(c), c.value])
	return _emit(_event("lookout", _notes[0], 0, 0))


# ================================================================ rooms and machines
func room_count() -> int:
	return bal.rooms(district_index).size()


func room(i: int) -> Dictionary:
	var rs: Array = bal.rooms(district_index)
	return rs[i] if i >= 0 and i < rs.size() else {}


## Room price (sim room_price()): the listed price, Lockpick 50 less (shown x10).
func room_cost(i: int) -> int:
	var c: int = bal.room_cost(district_index, i)
	if has_patch("lockpick"):
		c = maxi(0, c - bal.num("lockpick_off"))
	return c


func machine(i: int) -> Dictionary:
	return room(i).get("machine", {})


func room_block_reason(i: int) -> String:
	var br: String = _busy_reason()
	if br != "":
		return br
	if i < 0 or i >= room_count():
		return "no such room"
	if room_open[i]:
		return "already open"
	if points < room_cost(i):
		return "need %d pts" % bal.shown(room_cost(i))
	return ""


## v5 (economy-v5.md): the cheapest use of room i's machine right now (Wall Rack: its gun; Patch
## Press: the next Patch; Retrofit Bench: its cheapest job), so the door can show what is inside.
func machine_min_price(i: int) -> int:
	var m: Dictionary = machine(i)
	match str(m.get("kind", "")):
		"wall":
			return bal.weapon_price(str(m.get("wid", "")))
		"patch":
			return bal.patch_price(patches.size())
		"bench":
			var lo: int = 1 << 30
			for sv: String in ["trim", "flip", "hone"]:
				lo = mini(lo, bal.bench_price(sv))
			return lo if lo < (1 << 30) else 0
	return 0


## v5: the door plus one use of what is inside (what you need to open AND use it this wave).
func room_total_cost(i: int) -> int:
	return room_cost(i) + machine_min_price(i)


## v5: opening room i now leaves too few points to use its machine this wave.
func room_machine_short(i: int) -> bool:
	return not room_open[i] and points >= room_cost(i) and points - room_cost(i) < machine_min_price(i)


func can_open_room(i: int) -> bool:
	return room_block_reason(i) == ""


## Opens room i: pay its price, its pack is shuffled into the pile, its machine switches on.
func open_room(i: int) -> Dictionary:
	var why: String = room_block_reason(i)
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var cost: int = room_cost(i)
	points -= cost
	room_open[i] = true
	var cards: Array[DDCard] = make_cards(bal.room_pack(district_index, i))
	pile.append_array(cards)
	_shuffle(pile)
	stats["rooms"] = int(stats["rooms"]) + 1
	_log("%s open (-%d): %d cards in, %s on." % [str(room(i).get("name", "")), bal.shown(cost), cards.size(),
		DDText.machine_name(str(machine(i).get("kind", "")))])
	var ev: Dictionary = _event("room", _notes[0], 0, -cost)
	ev["room"] = i
	ev["cards"] = cards
	return _emit(ev)


func _machine_block(i: int) -> String:
	var br: String = _busy_reason()
	if br != "":
		return br
	if i < 0 or i >= room_count() or not room_open[i]:
		return "room is closed"
	if machine_used[i]:
		return "used this wave"
	return ""


## Every service of the machine in room i: [{id, label, price, enabled, reason, result}].
func machine_options(i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: Dictionary = machine(i)
	var block: String = _machine_block(i)
	match str(m.get("kind", "")):
		"patch":
			var price: int = bal.patch_price(patches.size())
			var avail: int = _patch_pool().size()
			var reason: String = block
			if reason == "" and avail == 0:
				reason = "you own every Patch"
			elif reason == "" and points < price:
				reason = "need %d pts" % bal.shown(price)
			out.append({"id": "press", "label": "PRESS A PATCH", "price": price, "enabled": reason == "", "reason": reason,
				"result": "See %d Patches, keep 1 for the run." % mini(bal.num("patch_offer"), avail)})
		"wall":
			var wid: String = str(m.get("wid", ""))
			var price2: int = bal.weapon_price(wid)
			for s: int in 2:
				var r2: String = block
				if r2 == "" and points < price2:
					r2 = "need %d pts" % bal.shown(price2)
				var g: DDGun = slot(s)
				out.append({"id": "slot%d" % (s + 1), "label": "BUY INTO SLOT %d" % (s + 1), "price": price2, "enabled": r2 == "", "reason": r2,
					"result": (("replaces %s%s" % [g.name, (" · salvage +%d" % bal.shown(salvage_for(g))) if salvage_for(g) > 0 else ""]) if g != null else "empty slot"), "salvage": salvage_for(g)})
		"bench":
			for s: int in 2:
				var g2: DDGun = slot(s)
				var name: String = g2.name if g2 != null else "empty slot"
				for sv: String in ["trim", "flip", "hone"]:
					var price3: int = bal.bench_price(sv)
					var r3: String = block
					var res: String = ""
					if r3 == "" and g2 == null:
						r3 = "slot %d is empty" % (s + 1)
					if r3 == "":
						match sv:
							"trim":
								if g2.stack.is_empty():
									r3 = "no kills yet"
								else:
									res = "Removes the last kill (%d); %s." % [g2.top(),
										("the next is checked against %d" % g2.stack[g2.stack.size() - 2]) if g2.stack.size() > 1 else "the next can be anything"]
							"flip":
								if g2.rule != "up" and g2.rule != "down":
									r3 = "only LOWER / HIGHER rules"
								else:
									res = "Each kill: %s." % DDText.rule_short("up" if g2.rule == "down" else "down")
							"hone":
								if g2.honed:
									r3 = "already Honed"
								else:
									res = "Strength %d -> %d for good." % [g2.power, g2.power + 1]
					if r3 == "" and points < price3:
						r3 = "need %d pts" % bal.shown(price3)
					out.append({"id": "%s%d" % [sv, s + 1], "label": "%s %s" % [sv.to_upper(), name], "price": price3, "enabled": r3 == "",
						"reason": r3, "result": res, "slot": s, "service": sv})
	return out


func _patch_pool() -> Array[String]:
	var out: Array[String] = []
	for p: String in bal.patches():
		if not patches.has(p):
			out.append(p)
	return out


func use_machine(i: int, option_id: String) -> Dictionary:
	var opt: Dictionary = {}
	for o: Dictionary in machine_options(i):
		if str(o["id"]) == option_id:
			opt = o
	if opt.is_empty():
		return {"ok": false, "reason": "no such service", "kind": "blocked"}
	if not bool(opt["enabled"]):
		return {"ok": false, "reason": str(opt["reason"]), "kind": "blocked"}
	_begin()
	var price: int = int(opt["price"])
	var kind: String = str(machine(i).get("kind", ""))
	var hp0: int = hp
	var pts0: int = points
	points -= price
	machine_used[i] = true
	stats["machines"] = int(stats["machines"]) + 1
	var result: Dictionary = {"machine": kind, "room": i, "option": option_id}
	match kind:
		"patch":
			var pool: Array[String] = _patch_pool()
			_shuffle(pool)
			pending_patch = {"offer": pool.slice(0, mini(bal.num("patch_offer"), pool.size())), "source": "press", "room": i}
			_log("Patch Press (-%d): pick 1 of %d Patches." % [bal.shown(price), (pending_patch["offer"] as Array).size()])
		"wall":
			var s: int = 0 if option_id == "slot1" else 1
			var wid: String = str(machine(i).get("wid", ""))
			if slot(s) != null:
				_collect(s, false, false)
			_put_gun(s, wid)
			result["slot"] = s
			result["gun"] = slots[s]
			_log("Wall Rack (-%d): the %s goes into slot %d." % [bal.shown(price), bal.weapon_name(wid), s + 1])
		"bench":
			var s2: int = int(opt["slot"])
			var g: DDGun = slot(s2)
			result["slot"] = s2
			result["service"] = str(opt["service"])
			match str(opt["service"]):
				"trim":
					# the removed kill already paid when it was made (K1): Trim banks nothing
					var z: int = g.stack.pop_back()
					result["trimmed"] = z
					_log("Trim (-%d): the %d comes off the %s." % [bal.shown(price), z, g.name])
				"flip":
					g.rule = "up" if g.rule == "down" else "down"
					g.flipped = not g.flipped
					_log("Flip (-%d): %s, each kill: %s." % [bal.shown(price), g.name, DDText.rule_short(g.rule)])
				"hone":
					g.power += 1
					g.honed = true
					_log("Hone (-%d): the %s has strength %d now." % [bal.shown(price), g.name, g.power])
			result["gun"] = g
	var ev: Dictionary = _event("machine", _notes[_notes.size() - 1], hp - hp0, points - pts0)
	ev["result"] = result
	ev["collects"] = _collects.duplicate(true)
	return _emit(ev)


## Takes a Patch from the pending offer (Patch Press or boss reward).
func take_patch(id: String) -> Dictionary:
	if pending_patch.is_empty():
		return {"ok": false, "reason": "no Patch to pick", "kind": "blocked"}
	if not (pending_patch["offer"] as Array).has(id):
		return {"ok": false, "reason": "not offered", "kind": "blocked"}
	_begin()
	var hp0: int = hp
	_add_patch(id)
	var src: String = str(pending_patch.get("source", ""))
	pending_patch = {}
	_log("Patch sewn on: %s." % DDText.patch_name(id))
	if src == "boss" and phase == Phase.SAFEHOUSE:
		_make_shop_offer()
	var ev: Dictionary = _event("patch", _notes[_notes.size() - 1], hp - hp0, 0)
	ev["patch"] = id
	ev["source"] = src
	return _emit(ev)


func _add_patch(id: String) -> void:
	patches.append(id)
	if id == "thick_jacket":
		max_hp += bal.num("thick_jacket_hp")
		hp += bal.num("thick_jacket_hp")
	elif id == "loose_grip":
		loose = true


# ================================================================ district end
func _clear_district(ran_past: bool) -> void:
	street.clear()
	pile.clear()
	boss_street = false
	boss_queue.clear()
	cleared_ids.append(str(district().get("id", "")))
	var b: Dictionary = boss_def()
	boss_results.append({"beaten": not ran_past, "ran_past": ran_past, "hp": hp, "name": str(b.get("name", ""))})
	if not ran_past:
		_earn(bal.num("boss_reward_points"))
		_log("%s beaten: +%d pts." % [str(b.get("name", "")), bal.shown(bal.num("boss_reward_points"))])
	if is_final_district():
		phase = Phase.WON
		_log("You made it out of the city. Run score %d." % bal.shown(run_score()))
		return
	phase = Phase.SAFEHOUSE
	shop_offer.clear()
	shop_patch_bought = false
	shop_hp_bought = 0
	_make_mod_offer()
	if not ran_past:
		var pool: Array[String] = _patch_pool()
		_shuffle(pool)
		if not pool.is_empty():
			pending_patch = {"offer": pool.slice(0, mini(bal.num("boss_patch_offer"), pool.size())), "source": "boss", "room": -1}
	if pending_patch.is_empty():
		_make_shop_offer()


# ---------------------------------------------------------------- v5 Gun Mods
func mods_enabled() -> bool:
	return bal.text("mods_mode") == "safehouse"


func _make_mod_offer() -> void:
	mod_offer.clear()
	mod_fitted_here = false
	if not mods_enabled():
		return
	var pool: Array[String] = []
	for m: Variant in bal.list("mods"):
		if not slot_mods.has(str(m)):
			pool.append(str(m))
	_shuffle(pool)
	mod_offer = pool.slice(0, mini(bal.num("mod_offer"), pool.size()))


## The safehouse's Gun Mod step is open: the boss Patch is picked and the offer is still up.
func mod_step_open() -> bool:
	return phase == Phase.SAFEHOUSE and pending_patch.is_empty() and not mod_offer.is_empty()


## Passes on this safehouse's Gun Mods (the shop opens next).
func skip_mod() -> Dictionary:
	if not mod_step_open():
		return {"ok": false, "reason": "no Gun Mod to skip", "kind": "blocked"}
	mod_offer.clear()
	_log("No Gun Mod this time.")
	return {"ok": true, "kind": "mod_skip"}


func mod_price() -> int:
	return bal.num("mod_price")


## Why Gun Mod `id` can't go on slot s now ("" = it can).
func mod_block_reason(id: String, s: int) -> String:
	if phase != Phase.SAFEHOUSE or not mods_enabled():
		return "Gun Mods are fitted at a safehouse"
	if not pending_patch.is_empty():
		return "pick your free Patch first"
	if mod_fitted_here:
		return "one Gun Mod per safehouse"
	if not mod_offer.has(id):
		return "not offered"
	if s < 0 or s > 1:
		return "no such slot"
	if slot_mod(s) == id:
		return "slot %d has it already" % (s + 1)
	if points < mod_price():
		return "need %d pts" % bal.shown(mod_price())
	return ""


## What fitting `id` to slot s does: {ok, reason, replaces (the slot's old mod), cap (the gun's
## new capacity, 0 = no gun), finishes (Short Barrel fills the gun's stack: it finishes now)}.
func mod_preview(id: String, s: int) -> Dictionary:
	var why: String = mod_block_reason(id, s)
	var out: Dictionary = {"ok": why == "", "reason": why, "replaces": slot_mod(s), "cap": 0, "finishes": false}
	var g: DDGun = slot(s)
	if g != null:
		var cap: int = mod_cap(bal.weapon_cap(g.wid), id)
		out["cap"] = cap
		out["finishes"] = not g.stack.is_empty() and (g.stack.size() >= cap)
	return out


## sim fit_mod_to(): fits Gun Mod `id` to slot s (replacing that slot's mod) for the rest of the
## run. The gun in the slot gets it at once; Short Barrel can fill its stack: it finishes now
## (finish bonus + challenge).
func fit_mod(id: String, s: int) -> Dictionary:
	var why: String = mod_block_reason(id, s)
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var hp0: int = hp
	var pts0: int = points
	points -= mod_price()
	var old: String = slot_mod(s)
	slot_mods[s] = id
	mod_fitted_here = true
	mod_offer.clear()
	stats["mods"] = int(stats.get("mods", 0)) + 1
	_log("Gun Mod: %s on slot %d%s." % [DDText.mod_name(id), s + 1, (" (replaces %s)" % DDText.mod_name(old)) if old != "" else ""])
	var g: DDGun = slot(s)
	if g != null:
		g.cap = mod_cap(bal.weapon_cap(g.wid), id)
		if not g.stack.is_empty() and is_full(g):
			_collect(s, true, false)
	var ev: Dictionary = _event("mod", _notes[0], hp - hp0, points - pts0)
	ev["mod"] = id
	ev["slot"] = s
	ev["collects"] = _collects.duplicate(true)
	return _emit(ev)


func safehouse_heal() -> int:
	return bal.num("safehouse_heal")


# ---------------------------------------------------------------- v4 Safehouse Shop
## sim carry_over(): points don't leave a district. At the safehouse (after the boss Patch is
## picked with take_patch()) you may buy ONE Patch at the Patch Press price (pick 1 of 2) and
## supplies at carry_heal_rate points per HP; whatever is left is lost on leave_safehouse().
func shop_enabled() -> bool:
	var m: String = bal.text("carry_mode")
	return m == "shop" or m == "patch"


## True when unspent points are lost on leaving a safehouse (v3 "all": they carry over).
func points_stay_behind() -> bool:
	return bal.text("carry_mode") != "all"


func _make_shop_offer() -> void:
	shop_offer.clear()
	if not shop_enabled():
		return
	var pool: Array[String] = _patch_pool()
	_shuffle(pool)
	shop_offer = pool.slice(0, mini(bal.num("patch_offer"), pool.size()))


## The 2 Patches the shop offers ([] before the boss Patch is picked, or once one was bought).
func shop_patch_offer() -> Array[String]:
	if phase != Phase.SAFEHOUSE or not pending_patch.is_empty() or shop_patch_bought:
		return [] as Array[String]
	return shop_offer.duplicate()


func shop_patch_price() -> int:
	return bal.patch_price(patches.size())


func shop_patch_block_reason(id: String = "") -> String:
	if phase != Phase.SAFEHOUSE or not shop_enabled():
		return "no shop here"
	if not pending_patch.is_empty():
		return "pick your free Patch first"
	if shop_patch_bought:
		return "one Patch per safehouse"
	if shop_offer.is_empty():
		return "you own every Patch"
	if id != "" and not shop_offer.has(id):
		return "not offered"
	if points < shop_patch_price():
		return "need %d pts" % bal.shown(shop_patch_price())
	return ""


func buy_shop_patch(id: String) -> Dictionary:
	var why: String = shop_patch_block_reason(id)
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var hp0: int = hp
	var price: int = shop_patch_price()
	points -= price
	_add_patch(id)
	shop_patch_bought = true
	stats["shop_patches"] = int(stats["shop_patches"]) + 1
	_log("Safehouse Shop (-%d): %s sewn on." % [bal.shown(price), DDText.patch_name(id)])
	var ev: Dictionary = _event("shop_patch", _notes[_notes.size() - 1], hp - hp0, -price)
	ev["patch"] = id
	return _emit(ev)


## Points per 1 HP of supplies (sim units; 3 = 30 on screen).
func supplies_rate() -> int:
	return maxi(1, bal.num("carry_heal_rate"))


## HP you could still buy: limited by your points and by max HP after the free safehouse heal.
func supplies_max() -> int:
	if phase != Phase.SAFEHOUSE or bal.text("carry_mode") != "shop" or not pending_patch.is_empty():
		return 0
	var room: int = max_hp - mini(max_hp, hp + safehouse_heal())
	return maxi(0, mini(points / supplies_rate(), room))


func supplies_block_reason(n: int = 1) -> String:
	if phase != Phase.SAFEHOUSE or bal.text("carry_mode") != "shop":
		return "no shop here"
	if not pending_patch.is_empty():
		return "pick your free Patch first"
	if n <= 0:
		return "buy at least 1"
	if max_hp - mini(max_hp, hp + safehouse_heal()) < n:
		return "the rest heals you to full" if max_hp - mini(max_hp, hp + safehouse_heal()) == 0 else "only %d HP to heal" % (max_hp - mini(max_hp, hp + safehouse_heal()))
	if points < n * supplies_rate():
		return "need %d pts" % bal.shown(n * supplies_rate())
	return ""


## Buys n HP of supplies (healed now; the free safehouse heal still comes on leaving).
func buy_supplies(n: int) -> Dictionary:
	var why: String = supplies_block_reason(n)
	if why != "":
		return {"ok": false, "reason": why, "kind": "blocked"}
	_begin()
	var hp0: int = hp
	var cost: int = n * supplies_rate()
	points -= cost
	_heal(n)
	shop_hp_bought += n
	stats["shop_hp"] = int(stats["shop_hp"]) + n
	_log("Safehouse Shop (-%d): supplies, +%d HP." % [bal.shown(cost), hp - hp0])
	var ev: Dictionary = _event("supplies", _notes[_notes.size() - 1], hp - hp0, -cost)
	ev["bought"] = n
	return _emit(ev)


## Everything the shop panel needs in one dictionary (all points in sim units; DDBalance.shown()
## for the screen): enabled, points, left_behind (what leaving now loses), patch_offer, patch_price,
## patch_reason, patch_bought, supplies_rate, supplies_max, supplies_bought, heal_on_leave.
func shop_state() -> Dictionary:
	return {"enabled": shop_enabled() and phase == Phase.SAFEHOUSE, "points": points,
		"left_behind": points if points_stay_behind() else 0, "patch_offer": shop_patch_offer(), "patch_price": shop_patch_price(),
		"patch_reason": shop_patch_block_reason(), "patch_bought": shop_patch_bought, "waiting_for_boss_patch": not pending_patch.is_empty(),
		"supplies": bal.text("carry_mode") == "shop", "supplies_rate": supplies_rate(), "supplies_max": supplies_max(),
		"supplies_bought": shop_hp_bought, "heal_on_leave": mini(safehouse_heal(), max_hp - hp)}


## Leaves the safehouse: takes the boss-reward Patch (if one is offered), heals and enters the
## next district. v4: unspent points stay behind (points = 0; the score keeps them).
func leave_safehouse(patch_id: String = "") -> Dictionary:
	if phase != Phase.SAFEHOUSE:
		return {"ok": false, "reason": "not at a safehouse", "kind": "blocked"}
	if not pending_patch.is_empty():
		if patch_id == "":
			return {"ok": false, "reason": "pick your free Patch", "kind": "blocked"}
		if not (pending_patch["offer"] as Array).has(patch_id):
			return {"ok": false, "reason": "not offered", "kind": "blocked"}
	_begin()
	var hp0: int = hp
	if patch_id != "":
		_add_patch(patch_id)
		_log("Boss reward: %s." % DDText.patch_name(patch_id))
	pending_patch = {}
	_heal(safehouse_heal())
	_log("Safehouse: you rest, +%d HP." % (hp - hp0))
	var lost: int = 0
	if points_stay_behind():
		lost = points
		points = 0
		left_behind = lost
		stats["left_behind"] = int(stats["left_behind"]) + lost
		if lost > 0:
			_log("You leave %d pts behind." % bal.shown(lost))
	shop_offer.clear()
	mod_offer.clear()
	mod_fitted_here = false
	district_index += 1
	phase = Phase.STREET
	_start_district()
	var ev: Dictionary = _event("safehouse", _notes[0], hp - hp0, -lost)
	ev["patch"] = patch_id
	ev["left_behind"] = lost
	return _emit(ev)


func _die() -> void:
	phase = Phase.DEAD
	_log("You were overrun in %s. Run score %d." % [str(district().get("name", "")), bal.shown(run_score())])


## Score (sim units, shown x10): every point earned, + HP left on a win.
func run_score() -> int:
	return points_earned + (hp * bal.rule("score_hp_mult") if phase == Phase.WON else 0)


# ================================================================ helpers
func _earn(n: int) -> void:
	points += n
	points_earned += n


func _event(kind: String, text: String, hp_delta: int, points_delta: int) -> Dictionary:
	return {"ok": true, "kind": kind, "text": text, "hp_delta": hp_delta, "points_delta": points_delta, "hp": hp,
		"max_hp": max_hp, "street_ended": false, "district_cleared": false, "dead": false}


func _emit(ev: Dictionary) -> Dictionary:
	ev["phase"] = phase
	ev["notes"] = _notes.duplicate()
	changed.emit(ev)
	return ev


func _log(t: String) -> void:
	log_lines.append(t)
	_notes.append(t)
	if log_lines.size() > 200:
		log_lines.remove_at(0)


## Plain-data snapshot (debug / QA / tests).
func summary() -> Dictionary:
	var gs: Array = []
	for g: Variant in slots:
		gs.append((g as DDGun).to_dict() if g != null else null)
	return {"district": district_index, "wave": wave_index, "hp": hp, "cover": cover, "points": points, "earned": points_earned,
		"slots": gs, "active": active, "pile": pile.size(), "street": street.size(), "phase": Phase.keys()[phase],
		"boss_street": boss_street, "patches": patches.duplicate(), "rooms": room_open.duplicate(), "melee": melee.duplicate()}


# ================================================================ mid-run save
static func _cards_to(a: Array[DDCard]) -> Array:
	var out: Array = []
	for c: DDCard in a:
		out.append(c.to_dict())
	return out


static func _cards_from(a: Variant) -> Array[DDCard]:
	var out: Array[DDCard] = []
	if a is Array:
		for d: Variant in a:
			if d is Dictionary:
				out.append(DDCard.from_dict(d))
	return out


static func _strs(a: Variant) -> Array[String]:
	var out: Array[String] = []
	if a is Array:
		for v: Variant in a:
			out.append(str(v))
	return out


static func _bools(a: Variant) -> Array[bool]:
	var out: Array[bool] = []
	if a is Array:
		for v: Variant in a:
			out.append(bool(v))
	return out


static func _ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v: Variant in a:
			out.append(int(v))
	return out


## The whole run as JSON-safe data (64-bit RNG seed / state as strings). from_dict() restores it
## exactly: a resumed run plays identically to the uninterrupted one.
func to_dict() -> Dictionary:
	var gs: Array = []
	for g: Variant in slots:
		gs.append((g as DDGun).to_dict() if g != null else null)
	var br: Array = []
	for b: Dictionary in boss_results:
		br.append(b.duplicate())
	return {"v": 4, "slot_mods": slot_mods.duplicate(), "mod_offer": mod_offer.duplicate(), "mod_fitted_here": mod_fitted_here,
		"melee": melee.duplicate(), "fired": fired.duplicate(), "shop_offer": shop_offer.duplicate(),
		"shop_patch_bought": shop_patch_bought, "shop_hp_bought": shop_hp_bought, "left_behind": left_behind, "survivor_id": survivor_id, "passive": passive, "hp": hp, "max_hp": max_hp, "cover": cover, "points": points,
		"points_earned": points_earned, "slots": gs, "active": active, "patches": patches.duplicate(), "second_wind_used": second_wind_used,
		"loose": loose, "district_index": district_index, "wave_index": wave_index, "pile": _cards_to(pile), "street": _cards_to(street),
		"room_open": room_open.duplicate(), "room_pack_i": room_pack_i.duplicate(), "machine_used": machine_used.duplicate(),
		"boss_street": boss_street, "boss_queue": _cards_to(boss_queue), "pz_next": pz_next, "resolved": resolved, "budget": budget,
		"med_used": med_used, "ran_last": ran_last, "lookout_used": lookout_used, "pending_patch": pending_patch.duplicate(true),
		"phase": int(phase), "last_wave_info": last_wave_info.duplicate(true), "cleared_ids": cleared_ids.duplicate(), "boss_results": br,
		"stats": stats.duplicate(), "log_lines": log_lines.slice(maxi(0, log_lines.size() - 40)),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state)}


## A run restored from to_dict() data, or null when the data is unusable: a v2 or v3 run (v3:
## crowbar melee and points that carried between districts) can't continue under the v4 rules.
static func from_dict(d: Dictionary, balance: DDBalance = null) -> DDRun:
	var r: DDRun = DDRun.new(balance)
	if int(d.get("v", 0)) != 4:
		return null
	for k: String in ["survivor_id", "hp", "max_hp", "slots", "pile", "street", "phase", "district_index", "rng_state", "room_open"]:
		if not d.has(k):
			return null
	r.survivor_id = str(d["survivor_id"])
	if r.bal.survivor(r.survivor_id).is_empty() or int(d["district_index"]) < 0 or int(d["district_index"]) >= r.bal.district_count():
		return null
	r.passive = str(d.get("passive", ""))
	r.hp = int(d["hp"])
	r.max_hp = int(d["max_hp"])
	r.cover = int(d.get("cover", 0))
	r.points = int(d.get("points", 0))
	r.points_earned = int(d.get("points_earned", 0))
	var sl: Array = d["slots"] if d["slots"] is Array else []
	r.slots = [DDGun.from_dict(sl[0]) if sl.size() > 0 else null, DDGun.from_dict(sl[1]) if sl.size() > 1 else null]
	r.active = clampi(int(d.get("active", 0)), 0, 2)
	r.patches = _strs(d.get("patches", []))
	r.second_wind_used = bool(d.get("second_wind_used", false))
	var mv: Variant = d.get("melee", {})
	r.melee = {}
	if mv is Dictionary and (mv as Dictionary).has("id") and int((mv as Dictionary).get("uses", 0)) > 0:
		r.melee = {"id": str(mv["id"]), "power": int((mv as Dictionary).get("power", 0)), "uses": int(mv["uses"])}
	var fv: Array[bool] = _bools(d.get("fired", []))
	r.fired = [fv.size() > 0 and fv[0], fv.size() > 1 and fv[1]]
	var sm: Array[String] = _strs(d.get("slot_mods", []))
	r.slot_mods = [sm[0] if sm.size() > 0 else "", sm[1] if sm.size() > 1 else ""]
	r.mod_offer = _strs(d.get("mod_offer", []))
	r.mod_fitted_here = bool(d.get("mod_fitted_here", false))
	r.shop_offer = _strs(d.get("shop_offer", []))
	r.shop_patch_bought = bool(d.get("shop_patch_bought", false))
	r.shop_hp_bought = int(d.get("shop_hp_bought", 0))
	r.left_behind = int(d.get("left_behind", 0))
	r.loose = bool(d.get("loose", false))
	r.district_index = int(d["district_index"])
	r.wave_index = int(d.get("wave_index", 0))
	r.pile = _cards_from(d["pile"])
	r.street = _cards_from(d["street"])
	r.room_open = _bools(d["room_open"])
	r.room_pack_i = _ints(d.get("room_pack_i", []))
	r.machine_used = _bools(d.get("machine_used", []))
	while r.room_open.size() < r.room_count():
		r.room_open.append(false)
	while r.room_pack_i.size() < r.room_count():
		r.room_pack_i.append(0)
	while r.machine_used.size() < r.room_count():
		r.machine_used.append(false)
	r.boss_street = bool(d.get("boss_street", false))
	r.boss_queue = _cards_from(d.get("boss_queue", []))
	r.pz_next = int(d.get("pz_next", 0))
	r.resolved = int(d.get("resolved", 0))
	r.budget = int(d.get("budget", 3))
	r.med_used = int(d.get("med_used", 0))
	r.ran_last = bool(d.get("ran_last", false))
	r.lookout_used = bool(d.get("lookout_used", false))
	var pp: Variant = d.get("pending_patch", {})
	r.pending_patch = {}
	if pp is Dictionary and not (pp as Dictionary).is_empty():
		r.pending_patch = {"offer": _strs((pp as Dictionary).get("offer", [])), "source": str((pp as Dictionary).get("source", "")),
			"room": int((pp as Dictionary).get("room", -1))}
	r.phase = clampi(int(d["phase"]), 0, Phase.size() - 1) as Phase
	var lw: Variant = d.get("last_wave_info", {})
	if lw is Dictionary:
		r.last_wave_info = {"wave": int(lw.get("wave", 0)), "district": int(lw.get("district", 0)), "zombies": _ints(lw.get("zombies", [])),
			"cards": int(lw.get("cards", 0)), "restock": int(lw.get("restock", 0))}
	r.cleared_ids = _strs(d.get("cleared_ids", []))
	r.boss_results.clear()
	for b: Variant in d.get("boss_results", []):
		if b is Dictionary:
			r.boss_results.append({"beaten": bool(b.get("beaten", false)), "ran_past": bool(b.get("ran_past", false)),
				"hp": int(b.get("hp", 0)), "name": str(b.get("name", ""))})
	var stv: Variant = d.get("stats", {})
	r.stats = (stv as Dictionary).duplicate() if stv is Dictionary else {}
	for k: String in ["streets", "kills", "gun_kills", "melee_kills", "finished", "challenges", "runs", "rooms", "machines", "damage",
			"salvage", "melee_weapon_kills", "melee_broken", "left_behind", "shop_hp", "shop_patches", "mods"]:
		r.stats[k] = int(r.stats.get(k, 0))
	r.log_lines = _strs(d.get("log_lines", []))
	r.rng.seed = str(d.get("rng_seed", "0")).to_int()
	r.rng.state = str(d["rng_state"]).to_int()
	if r.phase == Phase.STREET and r.street.is_empty():
		return null
	return r
