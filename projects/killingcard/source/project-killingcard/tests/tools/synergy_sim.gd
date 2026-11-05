# synergy_sim.gd
# Purpose: kc-syn design sim (no game code changed). Plays whole matches on the REAL rules engine
#   and the REAL AiPlanner with the PROPOSED synergy system of synergy-system.md layered on top:
#   - SynState (MatchState subclass, sim only) adds the neighbor keywords and trait set bonuses
#     (tests/tools/synergy_rules.gd) to firepower_of / cover_of / has_first_shot, and the Undead
#     end-of-round heal, exactly where the engine reads them (live, by position, like Field auras).
#   - Policies: "blind" = the stock AiPlanner (it sees current bonuses on units already on the
#     board, because records read firepower_of, but never plans for links or sets); "aware" =
#     SynPlanner, a subclass that re-computes every link and set bonus for each candidate plan
#     (all three columns, since left / right links cross columns) before scoring it.
#   Both use balance_sim's "competent" player settings, the same deck and the starter Operator.
#   Seats alternate: seat 0 is balance_sim's PLAYER (commits second, sees red dots, wins ties
#   for initiative), seat 1 commits first. Modes alternate ZC / FF on Port Vasel.
#
#   Run (from the project folder):
#     godot --headless --path . -s res://tests/tools/synergy_sim.gd -- [options]
#   Options:
#     exp=duel|mirror|traits|draft|growth|opcost|campaign   (default duel)
#       duel:     aware vs blind, same deck, per deck in decks=
#       mirror:   aware vs aware (and blind vs blind), same deck: seat balance
#       traits:   aware round robin between the trait decks (class balance)
#       draft:    trait deck (aware) vs a one-of-each "mixed" draft (blind, then aware)
#       growth:   each end-of-run deck (aware) vs the starter (aware)
#       opcost:   aware starter mirror at the current Operator cost (tempo, seats)
#       campaign: competent player (aware / blind) vs the real squads in every run slot
#     n=N          matches per pairing (default 40)
#     decks=a,b    starter,vanguard,specops,heavy,undead (default all; "mixed" also exists)
#     base=ks|plain  starter: Killstreak's list (default) or the proposed Recruit starter
#     plain=v1..v6   which Recruit list (default v3, the recommended one; v6 = today's list as Recruits)
#     retire=N promote=N   end-of-run decks: N cards Retired / N Recruits trained
#     squads=none|bracket|all   campaign: enemy squads play Recruit copies (bracket = slots 1-2)
#     opcost=N     Operator Supply cost to deploy / respawn (default 0 = today)
#     syn=0        synergy off (engine exactly as today) - control runs
#     future=W     aware planner: value per bonus point for later rounds (default 1.5)
#     tune=KEY=VAL synergy_rules.set_number (repeatable), e.g. tune=trait.specops.0.where=all,
#                  tune=tr.sniper_perch=specops, tune=kw.rifleman=none
#     pkg=TRAIT:a,b,c,d   replace a trait deck's 4 reward cards
#     card=ID.FIELD=N     in-memory card stat override (e.g. card=recon_specialist.armor=3)
#     json=PATH    write results
#   kc-syn-impl note: the engine now ships the synergy layer (scripts/rules/synergy_rules.gd) and
#   the Operator cost (RunConfig.operator_cost). This proposal model switches both OFF at start
#   (SynergyRules.enabled = false, operator_cost = 0) so it still measures exactly its own rules;
#   tests/tools/synergy_check.gd measures the shipped engine.
# Author: Sr Game Designer Agent (kc-syn)
extends SceneTree

const Sim = preload("res://tests/mode_sim.gd")
const Syn = preload("res://tests/tools/synergy_rules.gd")

const DECK_NAMES: Array[String] = ["starter", "vanguard", "specops", "heavy", "undead"]
## Mid-run decks: the starter minus 2 Riflemen and 2 Callouts, plus 4 cards of one trait
## (what ~3 Supply Drops + 1 removal / trait pick would give; see synergy-system.md §6).
var TRAIT_ADDS: Dictionary = {
	"vanguard": ["point_man", "breacher", "shieldman", "bulwark"],
	"specops": ["flanker", "recon_specialist", "marksman", "listening_post"],
	"heavy": ["gunner", "demolitions_expert", "demolitions_expert", "mortar_pit"],
	"undead": ["brawler", "brawler", "combat_medic", "war_standard"],
	## Control: the same number of reward cards, one per trait (a "blind" draft).
	"mixed": ["flanker", "demolitions_expert", "brawler", "mortar_pit"],
}
const TRAIT_REMOVES: Array[String] = ["rifleman", "rifleman", "callout", "callout"]


# =============================================================================
# Rules with synergy (sim only)
# =============================================================================

class SynState extends MatchState:
	## Supply the Operator costs to place (round 1 and every respawn); 0 = today's rule.
	static var op_cost: int = 0
	## Operator placements per side (tempo stats).
	var op_places: Array[int] = [0, 0]

	func _check_place(side: int, zone: int) -> Dictionary:
		var r: Dictionary = super(side, zone)
		if r["ok"] and sides[side].supply < op_cost:
			return _fail("not enough Supply", &"not_enough_supply", {"cost": op_cost, "supply": sides[side].supply})
		if r["ok"]:
			r["play"]["cost"] = op_cost
		return r

	func _commit_place(side: int, play: Dictionary) -> void:
		sides[side].supply -= op_cost
		op_places[side] += 1
		super(side, play)

	## Per policy seat: [unit-rounds on board at firefight, links active, set bonuses active].
	var link_stats: Array = [[0, 0, 0], [0, 0, 0]]

	func _ids(si: int) -> Array:
		var ids: Array = [[], [], []]
		for z: int in 3:
			for u: RulesUnit in sides[si].line(z):
				ids[z].append(u.card.id if u.card != null and not u.is_operator else &"")
		return ids

	func _field_ids(si: int) -> Array:
		var out: Array = []
		for z: int in 3:
			for entry: Dictionary in sides[si].equipment[z]:
				var c: CardData = (entry["card"] as RulesCard).card
				if not c.hidden:
					out.append(c.id)
		return out

	func syn_of(u: RulesUnit) -> Dictionary:
		if u.zone < 0:
			return {}
		var i: int = sides[u.side].line(u.zone).find(u)
		if i < 0:
			return {}
		var all: Array = Syn.compute(_ids(u.side), _field_ids(u.side))
		return all[u.zone][i]

	func firepower_of(u: RulesUnit) -> int:
		var fp: int = super(u)
		var s: Dictionary = syn_of(u)
		return maxi(0, fp + int(s.get("fp", 0)))

	func cover_of(u: RulesUnit) -> int:
		var c: int = super(u)
		if u.has_mod(DataEnums.EffectKind.REMOVE_COVER, round_number) or passive_has(u, DataEnums.EffectKind.REMOVE_COVER) \
				or sides[1 - u.side].has_flag(DataEnums.EffectKind.REMOVE_COVER, round_number):
			return c
		return c + int(syn_of(u).get("cover", 0))

	func has_first_shot(u: RulesUnit, with_synergy: bool = true) -> bool:
		if u.has_mod(DataEnums.EffectKind.REMOVE_FIRST_SHOT, round_number) or passive_has(u, DataEnums.EffectKind.REMOVE_FIRST_SHOT):
			return false
		return super(u, with_synergy) or bool(syn_of(u).get("fs", false))

	func resolve_round() -> Array[Dictionary]:
		var start: int = events.size()
		if phase != Phase.DEPLOY:
			return []
		reveal()
		for si: int in 2:
			var all: Array = Syn.compute(_ids(si), _field_ids(si))
			for z: int in 3:
				for r: Dictionary in all[z]:
					link_stats[si][0] += 1
					for l: String in r["links"]:
						if l in ["spotter", "guard", "fireteam", "overwatch"]:
							link_stats[si][1] += 1
						else:
							link_stats[si][2] += 1
		firefight()
		_heal()
		score()
		return events_since(start)

	## Undead tier 2: at the end of the round (before END_OF_ROUND effects), each damaged
	## Undead unit heals its heal amount (never above max Armor).
	func _heal() -> void:
		for si: int in 2:
			var all: Array = Syn.compute(_ids(si), _field_ids(si))
			for z: int in 3:
				var line: Array = sides[si].line(z)
				for i: int in line.size():
					var u: RulesUnit = line[i]
					var h: int = int(all[z][i]["heal"])
					if h > 0 and u.is_alive():
						u.armor = mini(u.max_armor(round_number), u.armor + h)


# =============================================================================
# Synergy-aware planner (sim only)
# =============================================================================

## Stock planner + the Operator's Supply cost (the "blind" policy and the squads' AI).
class OpPlanner extends AiPlanner:
	func _candidates(p: AiPlanner.Plan) -> Array[Dictionary]:
		var raw: Array[Dictionary] = super(p)
		var out: Array[Dictionary] = []
		for a: Dictionary in raw:
			if a["kind"] == &"place" and p.supply < SynState.op_cost:
				continue
			out.append(a)
		return out

	func _apply(p: AiPlanner.Plan, a: Dictionary) -> void:
		super(p, a)
		if a["kind"] == &"place":
			p.supply -= SynState.op_cost


class SynPlanner extends OpPlanner:
	const EXPAND: Array[StringName] = [&"unit", &"place", &"rotate", &"equipment"]
	var card_cache: Dictionary = {}
	## Value per point of link / set bonus for the rounds after this one (x share of rounds left).
	var future_weight: float = 1.5

	func _candidates(p: AiPlanner.Plan) -> Array[Dictionary]:
		var out: Array[Dictionary] = super(p)
		for a: Dictionary in out:
			if a["kind"] in EXPAND:
				a["zones"] = [0, 1, 2]
		return out

	func _root_plan() -> AiPlanner.Plan:
		var p: AiPlanner.Plan = super()
		_syn_resync(p, true)
		return p

	func _apply(p: AiPlanner.Plan, a: Dictionary) -> void:
		super(p, a)
		if a["kind"] in EXPAND:
			_syn_resync(p, false)

	func _native_fs(id0: StringName) -> bool:
		var id: StringName = Syn.base_id(id0)
		if not card_cache.has(id):
			var path: String = "res://data/cards/%s.tres" % id
			card_cache[id] = load(path) if ResourceLoader.exists(path) else null
		var c: CardData = card_cache[id]
		return c != null and c.first_shot

	## Re-applies links and set bonuses to my records. At the root the records already hold
	## the engine's current bonuses (they were read through firepower_of), so it only stores them.
	func _syn_resync(p: AiPlanner.Plan, root: bool) -> void:
		var ids: Array = [[], [], []]
		for z: int in 3:
			for rec: Dictionary in p.lines[ME][z]:
				ids[z].append(StringName(rec["id"]) if not rec["is_op"] else &"")
		var fields: Array = []
		for z: int in 3:
			if not p.field_replaced[z]:
				for c: CardData in _view.my_fields[z]:
					if not c.hidden:
						fields.append(c.id)
			for c: CardData in p.equip_new[z]:
				if not c.hidden:
					fields.append(c.id)
		var all: Array = Syn.compute(ids, fields)
		if OS.has_environment("SYN_DEBUG") and not root:
			print("resync ids=", ids, " syn=", all)
		# Future value: links and set bonuses last while the board stands, so the aware planner
		# also values them for later rounds (like the stock planner's Field future value).
		var total: float = 0.0
		for z: int in 3:
			for s2: Dictionary in all[z]:
				total += float(s2["fp"]) + float(s2["cover"]) + (1.0 if s2["fs"] else 0.0) + 0.5 * float(s2["heal"])
		if root:
			p.used_items[&"__syn_total"] = total
		else:
			var left: float = clampf(float(_view.round_cap - _view.round_number) / maxf(1.0, _view.round_cap), 0.0, 1.0)
			p.flat += future_weight * left * (total - float(p.used_items.get(&"__syn_total", 0.0)))
			p.used_items[&"__syn_total"] = total
		for z: int in 3:
			var line: Array = p.lines[ME][z]
			for i: int in line.size():
				var rec: Dictionary = line[i]
				var s: Dictionary = all[z][i]
				var fp_new: int = int(s["fp"])
				var cov_new: int = 0 if _view.my_cover_removed else int(s["cover"])
				var fs_new: bool = bool(s["fs"])
				if root or not rec.has("syn_fp"):
					var old_fp: int = fp_new if root else 0
					var old_cov: int = cov_new if root else 0
					var old_fs: bool = fs_new if root else false
					rec["syn_fp"] = old_fp
					rec["syn_cover"] = old_cov
					rec["syn_fs"] = old_fs
					rec["fs_native"] = _native_fs(StringName(rec["id"])) if old_fs else bool(rec["first_shot"])
					if root:
						continue
				rec["fp"] = maxi(0, int(rec["fp"]) + fp_new - int(rec["syn_fp"]))
				rec["cover"] = maxi(0, int(rec["cover"]) + cov_new - int(rec["syn_cover"]))
				rec["first_shot"] = bool(rec["fs_native"]) or fs_new
				rec["syn_fp"] = fp_new
				rec["syn_cover"] = cov_new
				rec["syn_fs"] = fs_new


# =============================================================================
# Driver
# =============================================================================

var config: RunConfig = null
var n: int = 40
var experiment: String = "duel"
var decks: Array[String] = []
var json_path: String = ""
var future_weight: float = 1.5
## Deck base: "ks" = Killstreak's starter (today), "plain" = the proposed Recruit starter.
var base: String = "ks"
## Retire: how many Recruit / starter cards the end-of-run decks have removed.
var retire: int = 0
## Promotions applied to the end-of-run decks (Recruits trained).
var promote: int = 0
var out: Dictionary = {}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	SynergyRules.enabled = false  # kc-syn-impl: this model adds its own synergy (see the header)
	config.operator_cost = 0
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"exp": experiment = kv[1]
			"n": n = int(kv[1])
			"decks":
				for d: String in kv[1].split(","):
					decks.append(d)
			"syn": Syn.enabled = kv[1] != "0"
			"json": json_path = kv[1]
			"future": future_weight = float(kv[1])
			"base": base = kv[1]
			"retire": retire = int(kv[1])
			"promote": promote = int(kv[1])
			"plain": plain_version = kv[1]
			"squads": squad_recruits = kv[1]
			"card":
				# card=ID.FIELD=VALUE: in-memory stat override (also hits Recruit copies made later)
				var cv: PackedStringArray = kv[1].split("=", true, 1)
				var cf: PackedStringArray = cv[0].split(".", true, 1)
				_card(cf[0]).set(cf[1], int(cv[1]))
			"opcost": SynState.op_cost = int(kv[1])
			"pkg":
				var pv: PackedStringArray = kv[1].split(":", true, 1)
				TRAIT_ADDS[pv[0]] = Array(pv[1].split(","))
			"tune":
				var tv: PackedStringArray = kv[1].split("=", true, 1)
				Syn.set_number(tv[0], str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1])
			_: push_error("synergy_sim: unknown option " + arg)
	if decks.is_empty():
		decks.assign(DECK_NAMES)
	var t0: int = Time.get_ticks_msec()
	print("synergy_sim exp=%s n=%d decks=%s synergy=%s" % [experiment, n, decks, Syn.enabled])
	match experiment:
		"duel": _duel()
		"mirror": _mirror()
		"traits": _traits()
		"campaign": _campaign()
		"draft": _draft()
		"growth": _growth()
		"opcost": _opcost()
	print("synergy_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if json_path != "":
		var f: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	quit(0)


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## Proposed plain starter (§5.1): 7 designs, Recruit copies (no keyword, no trait).
const PLAIN_V1: Array = [["rifleman", 6], ["point_man", 4], ["marksman", 2], ["combat_medic", 2],
		["ammo_resupply", 2], ["suppressing_fire", 2], ["hold_the_line", 2]]
## v2 (recommended): 8 designs, every unit has at most one familiar keyword (First Shot, Pick,
## Patch, Suppress); 15 of 20 cards come in 3-4 copies.
const PLAIN_V2: Array = [["rifleman", 4], ["point_man", 4], ["breacher", 3], ["marksman", 2],
		["combat_medic", 2], ["gunner", 1], ["ammo_resupply", 2], ["hold_the_line", 2]]
const PLAIN_V3: Array = [["rifleman", 3], ["point_man", 4], ["breacher", 3], ["marksman", 2],
		["combat_medic", 2], ["gunner", 1], ["shieldman", 1], ["ammo_resupply", 2], ["hold_the_line", 2]]
const PLAIN_V4: Array = [["rifleman", 3], ["point_man", 3], ["breacher", 2], ["marksman", 2],
		["combat_medic", 2], ["gunner", 1], ["shieldman", 1], ["callout", 2], ["suppressing_fire", 2], ["hold_the_line", 2]]
const PLAIN_V5: Array = [["rifleman", 4], ["point_man", 3], ["breacher", 2], ["marksman", 2],
		["combat_medic", 2], ["gunner", 1], ["shieldman", 1], ["callout", 3], ["suppressing_fire", 2]]
## v6 = today's starter list as Recruits (control: are Recruit ids neutral?).
const PLAIN_V6: Array = [["rifleman", 3], ["point_man", 2], ["marksman", 2], ["combat_medic", 2], ["callout", 2],
		["breacher", 2], ["gunner", 1], ["shieldman", 1], ["ammo_resupply", 1], ["flank_route", 1],
		["suppressing_fire", 1], ["hold_the_line", 1], ["tripwire_charge", 1]]
var plain_version: String = "v3"
## Campaign: enemy squads play Recruit copies in "all" slots, slots 1-2 ("bracket") or none.
var squad_recruits: String = "none"
## Retire order: plain cards first.
const RETIRE_ORDER: Array[String] = ["rifleman_r", "rifleman_r", "rifleman_r", "ammo_resupply_r", "rifleman_r", "callout", "rifleman", "rifleman", "callout"]
var _recruits: Dictionary = {}
var op_total: int = 0


func recruit(id: String) -> CardData:
	if not _recruits.has(id):
		var c: CardData = _card(id).duplicate() as CardData
		c.id = StringName(id + Syn.RECRUIT_SUFFIX)
		_recruits[id] = c
	return _recruits[id]


func starter_deck() -> Array[CardData]:
	if base == "ks":
		return config.starter_deck.duplicate()
	var d: Array[CardData] = []
	for entry: Array in ({"v1": PLAIN_V1, "v2": PLAIN_V2, "v3": PLAIN_V3, "v4": PLAIN_V4, "v5": PLAIN_V5, "v6": PLAIN_V6}[plain_version]):
		for k: int in int(entry[1]):
			d.append(recruit(entry[0]))
	return d


func deck_for(name: String) -> Array[CardData]:
	var d: Array[CardData] = starter_deck()
	if name == "starter":
		return d
	if base == "ks":
		for id: String in TRAIT_REMOVES:
			for i: int in d.size():
				if String(d[i].id) == id:
					d.remove_at(i)
					break
	var removed: int = 0
	for id: String in RETIRE_ORDER:
		if removed >= retire:
			break
		for i: int in d.size():
			if String(d[i].id) == id:
				d.remove_at(i)
				removed += 1
				break
	for id: String in TRAIT_ADDS[name]:
		d.append(_card(id))
	# Promotions (level 1 trains a Recruit: it gains its chassis' keyword and trait).
	var promoted: int = 0
	for i: int in d.size():
		if promoted >= promote:
			break
		if Syn.is_recruit(d[i].id) and String(d[i].id) in ["point_man_r", "marksman_r", "combat_medic_r", "breacher_r"]:
			d[i] = _card(String(Syn.base_id(d[i].id)))
			promoted += 1
	return d


func _personality() -> AiPersonality:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	return p


func _ai(policy: String) -> AiPlayer:
	var p: AiPersonality = _personality()
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner = OpPlanner.new(p)
	if policy == "aware":
		ai.planner = SynPlanner.new(p)
		ai.planner.future_weight = future_weight
	return ai


func _setup(deck: Array[CardData], name: String) -> SideSetup:
	var s: SideSetup = Sim.player_setup(config)
	s.display_name = name
	s.deck = deck
	return s


## One match. Returns {winner_seat: 0/1/-1, rounds, links: [[unit_rounds, links, sets] per seat]}.
func play(seat_decks: Array, seat_policies: Array, seed_value: int, mode: int) -> Dictionary:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var map: MapData = config.matches[0].map
	var m: SynState = SynState.new(config, map, _setup(seat_decks[0], "seat0"), _setup(seat_decks[1], "seat1"), seed_value, hooks)
	m.start_match()
	var ais: Array[AiPlayer] = [_ai(seat_policies[0]), _ai(seat_policies[1])]
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		ais[1].take_turn(m, MatchState.ENEMY)
		ais[0].take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	var w: int = -1
	if m.result == &"player":
		w = 0
	elif m.result == &"enemy":
		w = 1
	var us: Array = []
	for ai: AiPlayer in ais:
		var t: int = 0
		for x: int in ai.turn_usecs:
			t += x
		us.append([t, ai.turn_usecs.size()])
	op_total += m.op_places[0] + m.op_places[1]
	return {"winner": w, "rounds": m.round_number, "links": m.link_stats, "us": us}


## n matches of A vs B, seats and modes alternating. Returns stats from A's point of view.
func pairing(deck_a: String, pol_a: String, deck_b: String, pol_b: String, count: int) -> Dictionary:
	var r: Dictionary = {"a_win": 0, "b_win": 0, "draw": 0, "seat0_win": 0, "rounds": 0,
			"a_links": [0, 0, 0], "b_links": [0, 0, 0], "a_win_seat0": 0, "a_win_seat1": 0,
			"a_us": [0, 0], "b_us": [0, 0]}
	var da: Array[CardData] = deck_for(deck_a)
	var db: Array[CardData] = deck_for(deck_b)
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var seat_decks: Array = [da, db] if a_seat == 0 else [db, da]
		var seat_pols: Array = [pol_a, pol_b] if a_seat == 0 else [pol_b, pol_a]
		var res: Dictionary = play(seat_decks, seat_pols, 9000 + k * 7919 + hash(deck_a + deck_b) % 1000, mode)
		var w: int = res["winner"]
		if w == 0:
			r["seat0_win"] += 1
		if w < 0:
			r["draw"] += 1
		elif w == a_seat:
			r["a_win"] += 1
			r["a_win_seat%d" % a_seat] += 1
		else:
			r["b_win"] += 1
		r["rounds"] += int(res["rounds"])
		for j: int in 2:
			r["a_us"][j] += int(res["us"][a_seat][j])
			r["b_us"][j] += int(res["us"][1 - a_seat][j])
		for j: int in 3:
			r["a_links"][j] += int(res["links"][a_seat][j])
			r["b_links"][j] += int(res["links"][1 - a_seat][j])
	r["n"] = count
	return r


func _fmt(r: Dictionary) -> String:
	var c: float = float(r["n"])
	var decisive: float = maxf(1.0, float(r["a_win"] + r["b_win"]))
	var al: Array = r["a_links"]
	var bl: Array = r["b_links"]
	var ms: String = "  ms/turn A %.1f B %.1f" % [r["a_us"][0] / 1000.0 / maxf(1, r["a_us"][1]), r["b_us"][0] / 1000.0 / maxf(1, r["b_us"][1])]
	return ms + "  A %5.1f%% (of decisive %5.1f%%)  B %5.1f%%  draw %4.1f%%  seat0 %5.1f%%  rounds %.1f  links/unit A %.2f B %.2f  sets/unit A %.2f B %.2f" % [
			100.0 * r["a_win"] / c, 100.0 * r["a_win"] / decisive, 100.0 * r["b_win"] / c, 100.0 * r["draw"] / c,
			100.0 * r["seat0_win"] / c, float(r["rounds"]) / c,
			float(al[1]) / maxf(1, al[0]), float(bl[1]) / maxf(1, bl[0]),
			float(al[2]) / maxf(1, al[0]), float(bl[2]) / maxf(1, bl[0])]


func _duel() -> void:
	print("\n== aware (A) vs blind (B), same deck ==")
	for d: String in decks:
		var r: Dictionary = pairing(d, "aware", d, "blind", n)
		out[d] = r
		print("%-9s %s" % [d, _fmt(r)])


func _mirror() -> void:
	print("\n== mirror: seat balance (seat 0 = commits second, initiative on ties) ==")
	for pol: String in ["aware", "blind"]:
		for d: String in decks:
			var r: Dictionary = pairing(d, pol, d, pol, n)
			out["%s_%s" % [pol, d]] = r
			print("%-6s %-9s %s" % [pol, d, _fmt(r)])


func _traits() -> void:
	print("\n== trait decks, aware vs aware round robin (A = row deck) ==")
	var names: Array[String] = []
	for d: String in decks:
		if d != "starter":
			names.append(d)
	var total: Dictionary = {}
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var r: Dictionary = pairing(names[i], "aware", names[j], "aware", n)
			out["%s_vs_%s" % [names[i], names[j]]] = r
			print("%-9s vs %-9s %s" % [names[i], names[j], _fmt(r)])
			total[names[i]] = (total.get(names[i], [0, 0]) as Array)
			total[names[j]] = (total.get(names[j], [0, 0]) as Array)
			total[names[i]][0] += int(r["a_win"])
			total[names[i]][1] += int(r["n"])
			total[names[j]][0] += int(r["b_win"])
			total[names[j]][1] += int(r["n"])
	for k: String in total:
		print("  %-9s overall win %5.1f%%" % [k, 100.0 * total[k][0] / maxf(1, total[k][1])])
	out["overall"] = total


func _campaign() -> void:
	print("\n== campaign slots: competent player (policy) vs the real squad AI (stock, blind) ==")
	for pol: String in ["aware", "blind"]:
		var tot: Array = [0, 0]
		for i: int in config.matches.size():
			var slot: RunMatchData = config.matches[i]
			var w: int = 0
			for k: int in n:
				var mode: int = DataEnums.GameMode.ZONE_CONTROL if k % 2 == 0 else DataEnums.GameMode.FIREFIGHT
				var hooks: MatchHooks = MatchHooks.new()
				hooks.mode_rules = ModeRules.create(mode, config)
				var es: SideSetup = SideSetup.from_squad(slot.squad, slot)
				if squad_recruits == "all" or (squad_recruits == "bracket" and i < 2):
					var rd: Array[CardData] = []
					for c: CardData in es.deck:
						rd.append(recruit(String(c.id)) if c.card_type != DataEnums.CardType.EQUIPMENT else c)
					es.deck = rd
				var m: SynState = SynState.new(config, slot.map, _setup(starter_deck(), "Player"),
						es, 5000 + k * 104729 + i, hooks)
				m.start_match()
				var enemy: AiPlayer = AiPlayer.for_squad(slot.squad)
				enemy.planner = OpPlanner.new(enemy.personality)
				var player: AiPlayer = _ai(pol)
				while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
					enemy.take_turn(m, MatchState.ENEMY)
					player.take_turn(m, MatchState.PLAYER, false)
					m.set_ready(MatchState.PLAYER)
					m.resolve_round()
					m.begin_round()
				if m.result == &"player":
					w += 1
			tot[0] += w
			tot[1] += n
			out["%s_slot%d" % [pol, i + 1]] = 100.0 * w / n
			print("%-6s slot %d (%s) win %5.1f%%" % [pol, i + 1, slot.squad.id, 100.0 * w / n])
		out["%s_all" % pol] = 100.0 * tot[0] / tot[1]
		print("%-6s all slots win %5.1f%%" % [pol, 100.0 * tot[0] / tot[1]])


## Deck building: a trait deck played aware vs the mixed (one-of-each) draft, played blind
## (the full "synergy player vs blind player" gap) and played aware (the deck-only gap).
func _draft() -> void:
	print("\n== draft: trait deck (A, aware) vs mixed draft (B) ==")
	for d: String in decks:
		if d in ["starter", "mixed"]:
			continue
		for pol_b: String in ["blind", "aware"]:
			var r: Dictionary = pairing(d, "aware", "mixed", pol_b, n)
			out["%s_vs_mixed_%s" % [d, pol_b]] = r
			print("%-9s vs mixed/%-5s %s" % [d, pol_b, _fmt(r)])
	var r2: Dictionary = pairing("mixed", "aware", "starter", "aware", n)
	out["mixed_vs_starter"] = r2
	print("mixed/aware vs starter/aware %s" % _fmt(r2))


## Does the end-of-run deck beat the starter? Trait decks and the mixed draft, aware, vs the
## starter, aware (run with syn=0 for the same decks without synergy).
func _growth() -> void:
	print("\n== growth: deck (A, aware) vs starter (B, aware) ==")
	for d: String in ["vanguard", "specops", "heavy", "undead", "mixed"]:
		var r: Dictionary = pairing(d, "aware", "starter", "aware", n)
		out["%s_vs_starter" % d] = r
		print("%-9s %s" % [d, _fmt(r)])


## Operator Supply cost: aware mirror on the starter (seat balance, tempo) at the current
## SynState.op_cost. Run once per cost (opcost=0/1/2) and compare.
func _opcost() -> void:
	print("\n== Operator cost %d: aware mirror on the %s starter ==" % [SynState.op_cost, base])
	var r: Dictionary = pairing("starter", "aware", "starter", "aware", n)
	out["mirror"] = r
	print("mirror  %s" % _fmt(r))
	print("op placements per match: %.2f   rounds %.2f" % [float(op_total) / maxf(1, r["n"]), float(r["rounds"]) / r["n"]])
