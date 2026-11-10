# duel_sim.gd
# Purpose: kc-duel-design balance harness for Duel mode (documentation/design/duel-mode.md). Plays the
#   REAL engine (MatchState, ModeRules, the Operator kits, SynergyRules, AiPlayer / AiPlanner on both
#   sides) with constructed decks: every pick = exactly 2 copies, one Operator (the "hero") per deck,
#   the kc-econ campaign economy unless an option changes it in memory. Nothing in data/ or scripts/
#   is changed; the hero-draw variants live in this file (DuelHooks).
#   Experiments (exps=...):
#     size     deck size: presets truncated / extended to picks=6,8,10,12 x draws per round 1 / 2
#     hero     hero placement: cmd (available from round 1, today's rule) / draw (shuffled in, must be
#              drawn; costs the respawn price after round 1) / drawfree (shuffled in, free the round it
#              is drawn) / top (always in the opening hand, takes one of its cards)
#     respawn  hero respawn cost 0 / 1 / 2
#     heroes   the 4 Operators head to head on the same deck (each preset mirrored, heroes differ)
#     presets  preset vs preset with their own heroes (round robin, both seats)
#     ai       player proxies (casual, competent) vs AI tiers (recruit, regular, veteran)
#     mode     Zone Control vs Firefight: rounds and seat
#     build    deckbuilding edge: each preset vs random legal decks (Kestrel both sides), by deck size
#     length   Zone Control target 6 / 7 / 8: rounds per match
#   Defaults = the spec's Duel rules: picks=10, draws=1, Zone Control, hero in the command zone, respawn 1,
#     no Terrain, no Doctrine, the Duel hero lines (DUEL_HERO_LINES, Marked Shot 2; heroline=campaign = shipped).
#   Options: exps=size,hero,...  n=N (games per pairing)  picks=10  draws=1  mode=zc|ff
#     hero=cmd|draw|drawfree|top  respawn=1  terrain=0|1  doctrine=0|1  heroline=duel|campaign
#     lset=loadout.prop=v;...  eset=loadout.effect_index.prop=v  tune=trait.tier.key=v|none  cfg=prop=v;...
#     pdeck=I:card@trait,...;...  phero=I:operator;...  only=0,2  rsb=0.8 rarmor=-1 (Recruit AI)
#   Run: godot --headless --path . -s res://tests/tools/duel_sim.gd -- exps=presets n=40
# Author: Sr Game Designer Agent (kc-duel-design)
extends SceneTree

const DocMatch: GDScript = preload("res://tests/tools/doctrine_match.gd")
var docrule: String = ""
const OPS: Array[StringName] = [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"]

## The four preset decks of duel-mode.md §5. Picks in priority order: the first `picks` are used
## (6, 8, 10), and 11-12 come from the tail. Each pick = 2 copies with the given trait (&"~default" = the
## chassis default).
var PRESETS: Array[Dictionary] = [
	{"name": "Spearhead", "trait": &"vanguard", "hero": &"kestrel_ar7", "picks": [
		[&"point_man", &"vanguard"], [&"rifleman", &""], [&"breacher", &"vanguard"], [&"shieldman", &"vanguard"],
		[&"flank_route", &""], [&"hold_the_line", &""], [&"brawler", &"undead"], [&"bulwark", &"vanguard"],
		[&"blackout", &""], [&"ammo_resupply", &""], [&"gunner", &"heavy"], [&"suppressing_fire", &""]]},
	{"name": "Overwatch", "trait": &"specops", "hero": &"longreach_338", "picks": [
		[&"rifleman", &"specops"], [&"recon_specialist", &"specops"], [&"marksman", &"specops"], [&"brawler", &"specops"],
		[&"flanker", &"specops"], [&"smoke_screen", &""], [&"sniper_perch", &"specops"], [&"halek_wren", &"specops"],
		[&"breach_and_clear", &""], [&"combat_medic", &"specops"], [&"callout", &""], [&"listening_post", &""]]},
	{"name": "Iron Wall", "trait": &"heavy", "hero": &"bastion_60", "picks": [
		[&"rifleman", &""], [&"breacher", &"heavy"], [&"gunner", &"heavy"], [&"marksman", &"heavy"],
		[&"demolitions_expert", &"heavy"], [&"ammo_resupply", &""], [&"suppressing_fire", &""], [&"mortar_pit", &"heavy"],
		[&"okafor_anvil", &"heavy"], [&"hold_the_line", &""], [&"point_man", &"vanguard"], [&"comms_relay", &""]]},
	{"name": "Hollow Ranks", "trait": &"undead", "hero": &"wasp_9", "picks": [
		[&"rifleman", &"undead"], [&"brawler", &"undead"], [&"point_man", &"undead"], [&"shieldman", &"undead"],
		[&"recon_specialist", &"undead"], [&"flanker", &"undead"], [&"war_standard", &"undead"], [&"breach_and_clear", &""],
		[&"tripwire_charge", &""], [&"sabotage", &""], [&"combat_medic", &"undead"], [&"aid_station", &"undead"]]},
]
## duel-mode.md §3.3: the Duel hero lines, applied in memory unless heroline=campaign (shipped kc-econ data).
const DUEL_HERO_LINES: Dictionary = {&"kestrel_ar7": 7, &"longreach_338": 6, &"wasp_9": 8, &"bastion_60": 7}
const DUEL_MARKED_SHOT: int = 2
var heroline: String = "duel"
var search_iters: int = 60
var search_games: int = 12
var search_traits: PackedStringArray = PackedStringArray(["vanguard", "specops", "heavy", "undead"])

var n: int = 40
var picks: int = 10
var draws: int = 1
var mode_opt: String = "zc"
var hero_mode: String = "cmd"
var respawn_cost: int = 1
var terrain_on: bool = false
var exps: Array[String] = ["presets"]
var recruit_sb: float = 0.6
## Recruit AI: Armor added to its units and Operator (the campaign's "green squad" lever, SideSetup.armor_bonus).
var recruit_armor: int = -1
## Regular AI: the competent planner, synergy-blind, picks its second-best play this often.
var regular_sb: float = 0.6
## Doctrine (campaign: from the first calling card) = the deck's main trait; doctrine=0 plays without it.
var doctrine_on: bool = false
var cfg_over: Dictionary = {}
var config: RunConfig = null
var dummy: CardData = null
## Per batch: [games, rounds sum, seat0 wins, draws, reshuffles, hero first-arrival round sum, hero arrivals,
##   hero never arrived, earlier-hero side wins, earlier-hero decided games]
var stats: Array = []


class DuelHooks extends MatchHooks:
	## hero_mode "cmd": today's rule. "draw"/"drawfree"/"top": the hero is a card in the deck (`dummy`); the
	## Operator may be placed once that card is drawn (it leaves the hand at once: it cost a draw, not a slot).
	var hero_mode: String = "cmd"
	var dummy: CardData = null
	var drawn: Array[bool] = [false, false]
	var drawn_round: Array[int] = [0, 0]
	var refund: Array[bool] = [false, false]

	func operator_can_deploy(state, side: int) -> bool:
		if hero_mode == "cmd":
			return super.operator_can_deploy(state, side)
		if hero_mode == "top" and not drawn[side]:
			# top: the hero is always in the opening hand and takes one of its cards (back to the bottom).
			var st = state.sides[side]
			if not st.hand.is_empty():
				st.deck.append(st.hand.pop_back())
			drawn[side] = true
			drawn_round[side] = state.round_number
		if not drawn[side]:
			var s = state.sides[side]
			for pile: Array in [s.hand, s.discard]:
				for i: int in pile.size():
					if pile[i].card == dummy:
						pile.remove_at(i)
						drawn[side] = true
						drawn_round[side] = state.round_number
						refund[side] = hero_mode == "drawfree" and state.round_number > 1
						break
				if drawn[side]:
					break
		return drawn[side] and state.respawn_enabled

	func on_briefing(state, side: int) -> void:
		super.on_briefing(state, side)
		# drawfree: the first placement is free whatever the round (approximated as a Supply refund).
		if refund[side]:
			refund[side] = false
			state.sides[side].supply += int(state.operator_cost())


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = (load("res://data/run_config.tres") as RunConfig).duplicate(false) as RunConfig
	dummy = CardData.new()
	dummy.id = &"duel_hero_card"
	dummy.display_name = "Hero"
	dummy.card_type = DataEnums.CardType.TACTIC
	dummy.cost = 10
	dummy.collectible = false
	if not "heroline=campaign" in OS.get_cmdline_user_args():
		for op: StringName in DUEL_HERO_LINES:
			(load("res://data/loadout/%s.tres" % op) as LoadoutItem).operator_armor = int(DUEL_HERO_LINES[op])
		((load("res://data/loadout/ab_marked_shot.tres") as LoadoutItem).effects[0] as EffectData).amount = DUEL_MARKED_SHOT
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"n": n = int(kv[1])
			"picks": picks = int(kv[1])
			"draws": draws = int(kv[1])
			"mode": mode_opt = kv[1]
			"hero": hero_mode = kv[1]
			"respawn": respawn_cost = int(kv[1])
			"terrain": terrain_on = kv[1] == "1"
			"rsb": recruit_sb = float(kv[1])
			"rarmor": recruit_armor = int(kv[1])
			"gsb": regular_sb = float(kv[1])
			"doctrine": doctrine_on = kv[1] != "0"
			"heroline": heroline = kv[1]
			"iters": search_iters = int(kv[1])
			"docrule": docrule = kv[1]
			"sg": search_games = int(kv[1])
			"strait": search_traits = kv[1].split(",")
			"only":
				# only=0,2: keep these presets (by index) in the preset experiments.
				var keep_p: Array[Dictionary] = []
				for ix: String in kv[1].split(","):
					keep_p.append(PRESETS[int(ix)])
				PRESETS = keep_p
			"tune":
				# tune=trait.tier.key=value[;...] (tier 0 = the 2-set, 1 = the 3-set; value none = remove)
				for item: String in kv[1].split(";"):
					var tv: PackedStringArray = item.split("=", true, 1)
					var tk: PackedStringArray = tv[0].split(".")
					var tiers: Array = SynergyRules.trait_bonus[StringName(tk[0])]
					if tv[1] == "none":
						(tiers[int(tk[1])] as Dictionary).erase(tk[2])
					else:
						(tiers[int(tk[1])] as Dictionary)[tk[2]] = int(tv[1])
			"pdeck":
				# pdeck=I:card@trait,card,...[;I:...] replaces preset I's pick list (0-based); hero=I.op via phero.
				for item: String in kv[1].split(";"):
					var pa: PackedStringArray = item.split(":", true, 1)
					var lst: Array = []
					for part: String in pa[1].split(","):
						var pt: PackedStringArray = part.split("@")
						lst.append([StringName(pt[0]), StringName(pt[1]) if pt.size() > 1 else SynergyRules.TRAIT_DEFAULT])
					PRESETS[int(pa[0])]["picks"] = lst
			"phero":
				for item: String in kv[1].split(";"):
					var ph: PackedStringArray = item.split(":", true, 1)
					PRESETS[int(ph[0])]["hero"] = StringName(ph[1])
			"cfg":
				for item: String in kv[1].split(";"):
					var p2: PackedStringArray = item.split("=", true, 1)
					cfg_over[p2[0]] = p2[1]
			"lset":
				# lset=loadout_id.prop=value[;...] edits an Operator (or ability) in memory.
				for item: String in kv[1].split(";"):
					var la: PackedStringArray = item.split(".", true, 1)
					var lb: PackedStringArray = la[1].split("=", true, 1)
					_assign(load("res://data/loadout/%s.tres" % la[0]), lb[0], lb[1])
			"eset":
				# eset=loadout_id.index.prop=value: edits effect `index` of a loadout item (an ability's amount).
				for item: String in kv[1].split(";"):
					var ea: PackedStringArray = item.split(".", true, 2)
					var eb: PackedStringArray = ea[2].split("=", true, 1)
					var li: LoadoutItem = load("res://data/loadout/%s.tres" % ea[0]) as LoadoutItem
					_assign(li.effects[int(ea[1])], eb[0], eb[1])
			"exps":
				exps.clear()
				for e: String in kv[1].split(","):
					exps.append(e)
			_: push_error("duel_sim: unknown option " + arg)
	var t0: int = Time.get_ticks_msec()
	# kc-duel-tune sanity line: the Operator numbers this run really uses.
	var ops_line: Array[String] = []
	for opid: String in ["kestrel_ar7", "longreach_338", "wasp_9", "bastion_60"]:
		var li: LoadoutItem = load("res://data/loadout/%s.tres" % opid) as LoadoutItem
		ops_line.append("%s %d/%d qm%d" % [opid, li.operator_firepower, li.operator_armor, li.opening_hand_bonus])
	var ms: LoadoutItem = load("res://data/loadout/ab_marked_shot.tres") as LoadoutItem
	print("  operators: %s · marked shot %d" % [", ".join(ops_line), (ms.effects[0] as EffectData).amount])
	print("  trait bonus: %s" % SynergyRules.trait_bonus)
	print("duel_sim: n=%d picks=%d draws=%d mode=%s hero=%s respawn=%d terrain=%s doctrine=%s heroline=%s" % [n, picks,
			draws, mode_opt, hero_mode, respawn_cost, terrain_on, doctrine_on, heroline])
	_apply_cfg()
	if "size" in exps:
		_exp_size()
	if "hero" in exps:
		_exp_hero()
	if "respawn" in exps:
		_exp_respawn()
	if "heroes" in exps:
		_exp_heroes()
	if "presets" in exps:
		_exp_presets(true)
	if "ai" in exps:
		_exp_ai()
	if "mode" in exps:
		_exp_mode()
	if "build" in exps:
		_exp_build()
	if "length" in exps:
		_exp_length()
	if "search" in exps:
		_exp_search()
	print("\nduel_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _apply_cfg() -> void:
	config.draws_per_round = draws
	config.operator_cost = respawn_cost
	config.deck_size = picks * 2
	for k: String in cfg_over:
		_assign(config, k, cfg_over[k])


func _assign(obj: Object, prop: String, raw: String) -> void:
	var cur: Variant = obj.get(prop)
	var val: Variant = raw
	match typeof(cur):
		TYPE_INT: val = int(raw)
		TYPE_FLOAT: val = float(raw)
		TYPE_BOOL: val = raw == "true" or raw == "1"
		TYPE_STRING_NAME: val = StringName(raw)
		TYPE_NIL: push_error("duel_sim: %s has no property %s" % [obj, prop])
	obj.set(prop, val)


# =============================================================================
# Decks and AI
# =============================================================================

func _deck(p: int, op: StringName = &"", k: int = -1) -> SideSetup:
	var pr: Dictionary = PRESETS[p]
	var s: SideSetup = SideSetup.new()
	s.display_name = pr["name"]
	var count: int = picks if k < 0 else k
	for i: int in mini(count, (pr["picks"] as Array).size()):
		var pk: Array = pr["picks"][i]
		var c: CardData = load("res://data/cards/%s.tres" % pk[0]) as CardData
		var t: StringName = pk[1]
		if not c.can_carry(t):
			t = SynergyRules.TRAIT_DEFAULT
		for j: int in 2:
			s.deck.append(c)
			s.deck_traits.append(t)
	s.doctrine = pr["trait"] if doctrine_on else &""
	s.primary = load("res://data/loadout/%s.tres" % (op if op != &"" else pr["hero"])) as LoadoutItem
	s.operator_kit = true
	s.killstreaks.assign(config.starter_killstreaks)
	if hero_mode == "draw" or hero_mode == "drawfree":
		s.deck.append(dummy)
		s.deck_traits.append(SynergyRules.TRAIT_DEFAULT)
	return s


func _ai(tier: String) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	var aware: bool = true
	match tier:
		"casual", "recruit":
			p.weight_damage_dealt = 1.5
			p.weight_damage_taken = 0.8
			p.push_bonus = 0.3
			p.second_best_chance = 0.6 if tier == "casual" else recruit_sb
			p.card_keep_cost = 0.6
			p.killstreak_keep_cost = 1.2
			p.weight_deny_streak = 1.0
			aware = false
		"regular":
			p.second_best_chance = regular_sb
			aware = false
		_:
			pass  # competent / veteran: the run_v2_check competent proxy, synergy-aware
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	return ai


# =============================================================================
# One game
# =============================================================================

## Plays sa (seat 0) vs sb (seat 1). Returns 0 / 1 (winner seat) or -1 (draw); fills `stats`.
func _game(sa: SideSetup, sb: SideSetup, seed_value: int, ta: String = "competent", tb: String = "competent",
		mode: int = -1) -> int:
	var md: RunMatchData = config.matches[0]
	var h: DuelHooks = DuelHooks.new()
	h.hero_mode = hero_mode
	h.dummy = dummy
	var gm: int = mode
	if gm < 0:
		gm = DataEnums.GameMode.FIREFIGHT if mode_opt == "ff" else DataEnums.GameMode.ZONE_CONTROL
	h.mode_rules = ModeRules.create(gm, config)
	var m: MatchState = DocMatch.new(config, md.map, sa, sb, seed_value, h)
	m.set("rule", docrule)
	if terrain_on:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		m.terrain = TerrainRules.deal(rng, 1, gm)
	m.start_match()
	var a: AiPlayer = _ai(ta)
	var b: AiPlayer = _ai(tb)
	var arrive: Array[int] = [0, 0]
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		b.take_turn(m, MatchState.ENEMY)
		a.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		for si: int in 2:
			if arrive[si] == 0 and m.sides[si].operator_unit != null and m.sides[si].operator_unit.is_on_board():
				arrive[si] = m.round_number
		m.begin_round()
	var reshuffles: Array[int] = [0]
	for e: Dictionary in m.events:
		if StringName(e.get("type", &"")) == RulesEvent.DECK_RESHUFFLED:
			reshuffles[0] += 1
	var w: int = 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)
	stats[0] += 1
	stats[1] += m.round_number
	stats[2] += int(w == 0)
	stats[3] += int(w == -1)
	stats[4] += reshuffles[0]
	for si: int in 2:
		if arrive[si] > 0:
			stats[5] += arrive[si]
			stats[6] += 1
		else:
			stats[7] += 1
	var ea: int = arrive[0] if arrive[0] > 0 else 99
	var eb: int = arrive[1] if arrive[1] > 0 else 99
	if ea != eb and w >= 0:
		stats[9] += 1
		stats[8] += int((ea < eb and w == 0) or (eb < ea and w == 1))
	return w


func _reset() -> void:
	stats = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]


func _summary() -> String:
	var g: float = maxf(1, stats[0])
	return "games %d  rounds %.2f  seat0 %.1f%%  draws %.1f%%  reshuffles/game %.2f  hero arrives r%.2f (never %.1f%%)  earlier hero wins %s" % [
			stats[0], stats[1] / g, 100.0 * stats[2] / maxf(1, stats[0] - stats[3]), 100.0 * stats[3] / g, stats[4] / g,
			stats[5] / maxf(1, stats[6]), 100.0 * stats[7] / (2.0 * g),
			("%.1f%% (n=%d)" % [100.0 * stats[8] / stats[9], stats[9]]) if stats[9] > 0 else "-"]


## Round robin of setups (an Array of Callables returning a fresh SideSetup): each pair `n` games, seats
## alternate. Returns per-index [wins, decided].
func _round_robin(makers: Array, names: Array, salt: int, print_pairs: bool = true, ta: String = "competent",
		tb: String = "competent") -> Array:
	var tot: Array = []
	for i: int in makers.size():
		tot.append([0, 0])
	for a: int in makers.size():
		for b: int in range(a + 1, makers.size()):
			var aw: int = 0
			var dec: int = 0
			for k: int in n:
				var a_seat: int = k % 2
				var sa: SideSetup = (makers[a] as Callable).call() if a_seat == 0 else (makers[b] as Callable).call()
				var sb: SideSetup = (makers[b] as Callable).call() if a_seat == 0 else (makers[a] as Callable).call()
				var w: int = _game(sa, sb, 7001 + salt * 131 + a * 977 + b * 9173 + k * 7919, ta, tb)
				if w >= 0:
					dec += 1
					aw += int(w == a_seat)
			if print_pairs:
				print("    %-14s vs %-14s %5.1f%% (n=%d)" % [names[a], names[b], 100.0 * aw / maxf(1, dec), dec])
			tot[a][0] += aw
			tot[a][1] += dec
			tot[b][0] += dec - aw
			tot[b][1] += dec
	return tot


func _preset_makers(k: int = -1) -> Array:
	var out: Array = []
	for p: int in PRESETS.size():
		out.append(func() -> SideSetup: return _deck(p, &"", k))
	return out


func _preset_names() -> Array:
	var out: Array = []
	for p: Dictionary in PRESETS:
		out.append(p["name"])
	return out


func _print_totals(tot: Array, names: Array) -> void:
	var lo: float = 100.0
	var hi: float = 0.0
	for i: int in tot.size():
		var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
		lo = minf(lo, pct)
		hi = maxf(hi, pct)
		print("    %-14s overall %5.1f%% (n=%d)" % [names[i], pct, tot[i][1]])
	print("    spread %.1f-%.1f" % [lo, hi])


# =============================================================================
# Experiments
# =============================================================================

func _exp_presets(print_pairs: bool) -> void:
	print("\n---- presets: round robin, own heroes, %d games per pair (picks=%d draws=%d hero=%s) ----" % [n, picks, draws, hero_mode])
	_reset()
	var tot: Array = _round_robin(_preset_makers(), _preset_names(), 1, print_pairs)
	_print_totals(tot, _preset_names())
	print("  " + _summary())


func _exp_size() -> void:
	var keep_p: int = picks
	var keep_d: int = draws
	for d: int in [1, 2]:
		for k: int in [6, 8, 10, 12]:
			picks = k
			draws = d
			_apply_cfg()
			_reset()
			var tot: Array = _round_robin(_preset_makers(), _preset_names(), 2, false)
			var lo: float = 100.0
			var hi: float = 0.0
			for i: int in tot.size():
				var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
				lo = minf(lo, pct)
				hi = maxf(hi, pct)
			print("  size picks=%2d (%2d cards) draws=%d | preset spread %.1f-%.1f | %s" % [k, k * 2, d, lo, hi, _summary()])
	picks = keep_p
	draws = keep_d
	_apply_cfg()


func _exp_hero() -> void:
	var keep: String = hero_mode
	for hm: String in ["cmd", "top", "draw", "drawfree"]:
		hero_mode = hm
		_reset()
		var tot: Array = _round_robin(_preset_makers(), _preset_names(), 3, false)
		var lo: float = 100.0
		var hi: float = 0.0
		for i: int in tot.size():
			var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
			lo = minf(lo, pct)
			hi = maxf(hi, pct)
		print("  hero=%-8s | preset spread %.1f-%.1f | %s" % [hm, lo, hi, _summary()])
	hero_mode = keep


func _exp_respawn() -> void:
	var keep: int = respawn_cost
	for rc: int in [0, 1, 2]:
		respawn_cost = rc
		_apply_cfg()
		_reset()
		var tot: Array = _round_robin(_preset_makers(), _preset_names(), 4, false)
		var lo: float = 100.0
		var hi: float = 0.0
		for i: int in tot.size():
			var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
			lo = minf(lo, pct)
			hi = maxf(hi, pct)
		print("  respawn=%d | preset spread %.1f-%.1f | %s" % [rc, lo, hi, _summary()])
	respawn_cost = keep
	_apply_cfg()


func _exp_heroes() -> void:
	print("\n---- heroes: each preset deck mirrored, heroes differ, %d games per pair per deck ----" % n)
	_reset()
	var grand: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]
	for p: int in PRESETS.size():
		var makers: Array = []
		for o: StringName in OPS:
			makers.append(func() -> SideSetup: return _deck(p, o))
		print("  deck %s:" % PRESETS[p]["name"])
		var tot: Array = _round_robin(makers, OPS, 10 + p, true)
		for i: int in 4:
			grand[i][0] += tot[i][0]
			grand[i][1] += tot[i][1]
	print("  all decks:")
	_print_totals(grand, OPS)
	print("  " + _summary())


func _exp_ai() -> void:
	print("\n---- AI tiers: player proxy (seat alternates) with each preset vs the AI with each preset, %d games per cell ----" % n)
	for proxy: String in ["casual", "competent"]:
		for tier: String in ["recruit", "regular", "veteran"]:
			_reset()
			var pw: int = 0
			var dec: int = 0
			for a: int in PRESETS.size():
				for b: int in PRESETS.size():
					for k: int in n / 4:
						var p_seat: int = k % 2
						var sp: SideSetup = _deck(a)
						var se: SideSetup = _deck(b)
						if tier == "recruit":
							se.armor_bonus = recruit_armor
						var w: int = _game(sp if p_seat == 0 else se, se if p_seat == 0 else sp,
								3301 + a * 71 + b * 911 + k * 7919, proxy if p_seat == 0 else tier, tier if p_seat == 0 else proxy)
						if w >= 0:
							dec += 1
							pw += int(w == p_seat)
			print("  %-9s vs %-8s %5.1f%% (n=%d)  rounds %.2f" % [proxy, tier, 100.0 * pw / maxf(1, dec), dec, stats[1] / maxf(1, stats[0])])


func _exp_mode() -> void:
	var keep: String = mode_opt
	for mo: String in ["zc", "ff"]:
		mode_opt = mo
		_reset()
		var tot: Array = _round_robin(_preset_makers(), _preset_names(), 5, false)
		var lo: float = 100.0
		var hi: float = 0.0
		for i: int in tot.size():
			var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
			lo = minf(lo, pct)
			hi = maxf(hi, pct)
		print("  mode=%s | preset spread %.1f-%.1f | %s" % [mo, lo, hi, _summary()])
	mode_opt = keep


# =============================================================================
# Deckbuilding edge and match length
# =============================================================================

## A random legal deck (duel-mode.md §2 rules): `k` picks, at least half units, at most 1 Elite, at most
## 3 Fields, at least 2 picks of cost 1 or less... drawn from the collectible pool, chassis-default traits.
func _random_deck(k: int, seed_value: int, op: StringName) -> SideSetup:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[CardData] = []
	for f: String in DirAccess.get_files_at("res://data/cards"):
		if f.ends_with(".tres"):
			var c: CardData = load("res://data/cards/" + f) as CardData
			if c != null and c.collectible:
				pool.append(c)
	var chosen: Array[CardData] = []
	for attempt: int in 400:
		chosen.clear()
		var bag: Array[CardData] = pool.duplicate()
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: CardData = bag[i]
			bag[i] = bag[j]
			bag[j] = t
		for c: CardData in bag:
			if chosen.size() < k:
				chosen.append(c)
		if _legal(chosen, k):
			break
	var s: SideSetup = SideSetup.new()
	s.display_name = "Random"
	var counts: Dictionary = {}
	for c: CardData in chosen:
		for j: int in 2:
			s.deck.append(c)
			s.deck_traits.append(SynergyRules.TRAIT_DEFAULT)
		if c.card_trait != &"":
			counts[c.card_trait] = int(counts.get(c.card_trait, 0)) + 1
	var best: StringName = &""
	for t: StringName in counts:
		if best == &"" or int(counts[t]) > int(counts[best]):
			best = t
	s.doctrine = best if doctrine_on else &""
	s.primary = load("res://data/loadout/%s.tres" % op) as LoadoutItem
	s.operator_kit = true
	s.killstreaks.assign(config.starter_killstreaks)
	return s


func _legal(chosen: Array[CardData], k: int) -> bool:
	var units: int = 0
	var elites: int = 0
	var fields: int = 0
	var cheap: int = 0
	for c: CardData in chosen:
		units += int(c.is_unit())
		elites += int(c.is_elite)
		fields += int(c.card_type == DataEnums.CARD_TYPE_FIELD)
		cheap += int(c.cost <= 1)
	return units * 2 >= k and elites <= 1 and fields <= 3 and cheap >= 2


## Deckbuilding edge: each preset (Kestrel on both sides) vs random legal decks, by deck size.
func _exp_build() -> void:
	var keep: int = picks
	print("\n---- deckbuilding edge: preset vs a random legal deck, Kestrel both sides, %d games per preset ----" % n)
	for k: int in [6, 8, 10, 12]:
		picks = k
		_apply_cfg()
		_reset()
		var pw: int = 0
		var dec: int = 0
		for p: int in PRESETS.size():
			for g: int in n:
				var seat: int = g % 2
				var sp: SideSetup = _deck(p, &"kestrel_ar7")
				var sr: SideSetup = _random_deck(k, 50000 + p * 1000 + g, &"kestrel_ar7")
				var w: int = _game(sp if seat == 0 else sr, sr if seat == 0 else sp, 6100 + p * 313 + g * 7919)
				if w >= 0:
					dec += 1
					pw += int(w == seat)
		print("  picks=%2d (%2d cards) preset wins %5.1f%% (n=%d) | %s" % [k, k * 2, 100.0 * pw / maxf(1, dec), dec, _summary()])
	picks = keep
	_apply_cfg()


## Match length by Zone Control target (presets round robin).
func _exp_length() -> void:
	for tgt: int in [6, 7, 8]:
		config.zone_control_target = tgt
		_reset()
		var tot: Array = _round_robin(_preset_makers(), _preset_names(), 6, false)
		var lo: float = 100.0
		var hi: float = 0.0
		for i: int in tot.size():
			var pct: float = 100.0 * tot[i][0] / maxf(1, tot[i][1])
			lo = minf(lo, pct)
			hi = maxf(hi, pct)
		print("  zone_control_target=%d | preset spread %.1f-%.1f | %s" % [tgt, lo, hi, _summary()])
	_apply_cfg()


# =============================================================================
# Strongest custom decks (kc-duel-tune): hill-climb against the 4 presets
# =============================================================================

func _pool() -> Array[CardData]:
	var pool: Array[CardData] = []
	for f: String in DirAccess.get_files_at("res://data/cards"):
		if f.ends_with(".tres"):
			var c: CardData = load("res://data/cards/" + f) as CardData
			if c != null and c.collectible:
				pool.append(c)
	return pool


## A custom deck: picks [[id, trait]], hero, Doctrine trait (the player's pick when doctrine_on).
func _custom(picks_list: Array, hero: StringName, doct: StringName) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Custom"
	for pk: Array in picks_list:
		var c: CardData = load("res://data/cards/%s.tres" % pk[0]) as CardData
		var t: StringName = pk[1] if c.can_carry(pk[1]) else SynergyRules.TRAIT_DEFAULT
		for j: int in 2:
			s.deck.append(c)
			s.deck_traits.append(t)
	s.doctrine = doct if doctrine_on else &""
	s.primary = load("res://data/loadout/%s.tres" % hero) as LoadoutItem
	s.operator_kit = true
	s.killstreaks.assign(config.starter_killstreaks)
	return s


func _legal_list(lst: Array) -> bool:
	var cards: Array[CardData] = []
	for pk: Array in lst:
		cards.append(load("res://data/cards/%s.tres" % pk[0]) as CardData)
	var units: int = 0
	var elites: int = 0
	var fields: int = 0
	for c: CardData in cards:
		units += int(c.is_unit())
		elites += int(c.is_elite)
		fields += int(c.card_type == DataEnums.CARD_TYPE_FIELD)
	return units >= 5 and elites <= 1 and fields <= 3


## Win rate of a custom deck against every preset (own heroes), seats alternate, fixed seeds.
func _score(lst: Array, hero: StringName, doct: StringName, games: int, salt: int) -> float:
	var w: int = 0
	var dec: int = 0
	for p: int in PRESETS.size():
		for g: int in games:
			var seat: int = g % 2
			var sc: SideSetup = _custom(lst, hero, doct)
			var sp: SideSetup = _deck(p)
			var r: int = _game(sc if seat == 0 else sp, sp if seat == 0 else sc, 880000 + salt + p * 7717 + g * 7919)
			if r >= 0:
				dec += 1
				w += int(r == seat)
	return float(w) / maxf(1.0, float(dec))


func _exp_search() -> void:
	print("\n---- strongest custom decks: hill-climb vs the 4 presets (iters %d, %d games per preset per step, doctrine %s) ----" % [search_iters, search_games, doctrine_on])
	var pool: Array[CardData] = _pool()
	for tr: String in search_traits:
		var t: StringName = StringName(tr)
		var start: int = 0
		for p: int in PRESETS.size():
			if PRESETS[p]["trait"] == t:
				start = p
		var cur: Array = []
		for i: int in mini(picks, (PRESETS[start]["picks"] as Array).size()):
			cur.append((PRESETS[start]["picks"][i] as Array).duplicate())
		var hero: StringName = PRESETS[start]["hero"]
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 4040 + start
		_reset()
		var best: float = _score(cur, hero, t, search_games, 1)
		for it: int in search_iters:
			var cand: Array = cur.duplicate(true)
			var ch: StringName = hero
			if rng.randf() < 0.15:
				ch = OPS[rng.randi_range(0, OPS.size() - 1)]
			else:
				var c: CardData = pool[rng.randi_range(0, pool.size() - 1)]
				var dup: bool = false
				for pk: Array in cand:
					dup = dup or pk[0] == c.id
				if dup:
					continue
				var tr2: StringName = t if c.can_carry(t) else SynergyRules.TRAIT_DEFAULT
				cand[rng.randi_range(0, cand.size() - 1)] = [c.id, tr2]
				if not _legal_list(cand):
					continue
			var sc: float = _score(cand, ch, t, search_games, 1)
			if sc >= best:
				best = sc
				cur = cand
				hero = ch
		_reset()
		var val: float = _score(cur, hero, t, 50, 777)
		var names: Array[String] = []
		for pk: Array in cur:
			names.append("%s%s" % [pk[0], ("@" + String(pk[1])) if pk[1] != SynergyRules.TRAIT_DEFAULT and pk[1] != &"" else ""])
		print("  %-8s best %s  climb %.1f%%  validate vs presets %.1f%% (n=%d)" % [t, hero, 100.0 * best, 100.0 * val, stats[0]])
		print("    picks: %s" % ",".join(names))
