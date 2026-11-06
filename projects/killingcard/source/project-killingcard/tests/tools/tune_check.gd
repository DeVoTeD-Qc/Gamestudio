# tune_check.gd
# Purpose: kc-syn-tune (synergy-system.md §12) balance pass on the REAL build after the onboarding
#   ladder: one tool for every tuning target, on the same real runs as onboarding_check.gd (shipped
#   run_config.tres, real RunProgress offers, balance_sim's proxies and offer rule).
#     runs     competent / casual run win, per-match win (the ramp), M5 decks kept for the rest
#     traits   end-of-run decks grouped by main trait, aware round robin between groups (40-60% each)
#     duel     aware vs blind, same end-of-run deck (>= 55%)
#     mirror   aware mirror, seat 0 win rate on the starter and on end-of-run decks (45-55%), with
#              how often seat 0 holds initiative and how often initiative was a tie
#   What-ifs (all in memory, nothing is saved):
#     tiebreak=player|enemy|alt|other|coin|random   initiative tie rule (ModeRules.tiebreak)
#     set=card.prop=value[;card.prop=value]          edit CardData (e.g. set=breacher.armor=3)
#     slot=N.prop=value[;...]                        edit RunMatchData N (1-based)
#     sdeck=N:card*count,...                         set slot N's authored enemy_deck
#     cfg=prop=value[;...]                           edit RunConfig
#     tune=trait.tier.key=value[;...]                edit SynergyRules.trait_bonus
#   Run: godot --headless --path . -s res://tests/tools/tune_check.gd -- runs=400 late=160 mirror=400 exps=runs,traits,duel,mirror
# Author: Sr Game Designer Agent (kc-syn-tune), from onboarding_check.gd (Mechanics Developer Agent)
extends SceneTree

var runs: int = 100
var late_n: int = 80
var mirror_n: int = 400
var trait_n: int = 60
var proxies: Array[String] = ["competent", "casual"]
var exps: Array[String] = ["runs", "traits", "duel", "mirror"]
var config: RunConfig = null
var late: Array[SideSetup] = []
var late_trait: Array[StringName] = []
var init_stats: Array[int] = [0, 0, 0]  # rounds, seat 0 held initiative, initiative was a tie
## Mirror / duel only: the player-seat AI commits first (the game: the enemy AI commits first).
var player_first: bool = false
## Tie rule used only in the late checks (traits / duel / mirror), so the runs and their decks stay the same.
var mirror_tie: StringName = &""


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"runs": runs = int(kv[1])
			"late": late_n = int(kv[1])
			"mirror": mirror_n = int(kv[1])
			"tn": trait_n = int(kv[1])
			"proxies":
				proxies.clear()
				for p: String in kv[1].split(","):
					proxies.append(p)
			"exps":
				exps.clear()
				for e: String in kv[1].split(","):
					exps.append(e)
			"tiebreak": ModeRules.tiebreak = StringName(kv[1])
			"pfirst": player_first = kv[1] == "1"
			"mtie": mirror_tie = StringName(kv[1])
			"set":
				for item: String in kv[1].split(";"):
					var p: PackedStringArray = _split3(item)
					_assign(load("res://data/cards/%s.tres" % p[0]), p[1], p[2])
			"slot":
				for item: String in kv[1].split(";"):
					var p: PackedStringArray = _split3(item)
					_assign(config.matches[int(p[0]) - 1], p[1], p[2])
			"sdeck":  # sdeck=3:point_man*3,breacher*3,si_trooper*2 (the slot's authored enemy_deck)
				var sp: PackedStringArray = kv[1].split(":", true, 1)
				var deck: Array[CardData] = []
				for entry: String in sp[1].split(","):
					var ec: PackedStringArray = entry.split("*")
					for i: int in (int(ec[1]) if ec.size() > 1 else 1):
						deck.append(load("res://data/cards/%s.tres" % ec[0]) as CardData)
				config.matches[int(sp[0]) - 1].enemy_deck = deck
			"cfg":
				for item: String in kv[1].split(";"):
					var p: PackedStringArray = item.split("=", true, 1)
					_assign(config, p[0], p[1])
			"tune":
				for item: String in kv[1].split(";"):
					var tv: PackedStringArray = item.split("=", true, 1)
					var tk: PackedStringArray = tv[0].split(".")
					var val: Variant = str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1]
					var tiers: Array = SynergyRules.trait_bonus[StringName(tk[0])]
					if val is String and val == "none":
						(tiers[int(tk[1])] as Dictionary).erase(tk[2])
					else:
						(tiers[int(tk[1])] as Dictionary)[tk[2]] = val
			_: push_error("tune_check: unknown option " + arg)
	var t0: int = Time.get_ticks_msec()
	print("tune_check: runs=%d late=%d mirror=%d tn=%d tiebreak=%s args=%s" % [runs, late_n, mirror_n, trait_n,
			ModeRules.tiebreak, OS.get_cmdline_user_args()])
	if "runs" in exps or "traits" in exps or "duel" in exps or "mirror" in exps:
		for k: int in proxies.size():
			_runs(proxies[k], k == 0)
	if mirror_tie != &"":
		ModeRules.tiebreak = mirror_tie
		print("late checks use tiebreak=%s" % mirror_tie)
	if "traits" in exps:
		_traits()
	if "duel" in exps:
		_duel_late()
	if "mirror" in exps:
		_mirrors()
	print("\ntune_check done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _split3(item: String) -> PackedStringArray:
	var a: PackedStringArray = item.split(".", true, 1)
	var b: PackedStringArray = a[1].split("=", true, 1)
	return PackedStringArray([a[0], b[0], b[1]])


func _assign(obj: Object, prop: String, raw: String) -> void:
	var cur: Variant = obj.get(prop)
	var val: Variant = raw
	match typeof(cur):
		TYPE_INT: val = int(raw)
		TYPE_FLOAT: val = float(raw)
		TYPE_BOOL: val = raw == "true" or raw == "1"
		TYPE_STRING_NAME: val = StringName(raw)
		TYPE_NIL: push_error("tune_check: %s has no property %s" % [obj, prop])
		_:
			var parsed: Variant = str_to_var(raw)
			if parsed != null:
				val = parsed
	obj.set(prop, val)


func _ai(proxy: String, aware: bool = true) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	if proxy == "casual":
		p.weight_damage_dealt = 1.5
		p.weight_damage_taken = 0.8
		p.push_bonus = 0.3
		p.second_best_chance = 0.6
		p.card_keep_cost = 0.6
		p.cooldown_keep_cost = 1.0
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	return ai


func _play(m: MatchState, a: AiPlayer, b: AiPlayer, track: bool = false) -> void:
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		if player_first and track:
			a.take_turn(m, MatchState.PLAYER)
			b.take_turn(m, MatchState.ENEMY)
		else:
			b.take_turn(m, MatchState.ENEMY)
			a.take_turn(m, MatchState.PLAYER, false)
			m.set_ready(MatchState.PLAYER)
		if track:
			init_stats[0] += 1
			if m.sides[0].score == m.sides[1].score:
				init_stats[2] += 1
		m.resolve_round()
		if track and m.initiative == 0:
			init_stats[1] += 1
		m.begin_round()


func _choose(r: RunProgress) -> int:
	var offer: Dictionary = r.current_offer()
	if offer["kind"] not in RewardOffers.CARD_DROPS:
		return 0
	if offer.has("on_trait"):
		var c0: CardData = r.resource(offer["options"][0]) as CardData
		if c0 != null and c0.card_type != DataEnums.CardType.TACTIC:
			return 0
	var best: int = 0
	var best_cost: int = -1
	for i: int in offer["options"].size():
		var c: CardData = r.resource(offer["options"][i]) as CardData
		if c != null and c.is_unit() and c.cost > best_cost:
			best = i
			best_cost = c.cost
	return best


func _runs(proxy: String, keep_late: bool) -> void:
	var wins: int = 0
	var reach: Array[int] = [0, 0, 0, 0, 0]
	var won: Array[int] = [0, 0, 0, 0, 0]
	var t0: int = Time.get_ticks_msec()
	for s: int in runs:
		var r: RunProgress = RunProgress.create(config, 900000 + s)
		r.begin()
		while not r.is_over():
			var idx: int = r.match_index
			if idx == 4 and keep_late:
				late.append(r.player_setup())
				late_trait.append(r.main_trait())
			reach[idx] += 1
			var m: MatchState = r.create_match()
			m.start_match()
			var squad_ai: AiPlayer = AiPlayer.for_squad(r.current_match().squad)
			squad_ai.planner.synergy_aware = true
			_play(m, _ai(proxy), squad_ai)
			if m.result == &"player":
				won[idx] += 1
			r.record_match(m)
			var guard: int = 0
			while not r.current_offer().is_empty() and guard < 40:
				guard += 1
				if r.choose_offer(_choose(r)) != "":
					r.skip_offer()
		if r.is_victory():
			wins += 1
	print("\n---- %s: %d real runs (%.1f s) ----" % [proxy.to_upper(), runs, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  RUN WIN %.1f%% (%d/%d)" % [100.0 * wins / maxf(1, runs), wins, runs])
	var line: String = "  per match (reached -> win%%):"
	for i: int in 5:
		line += "  M%d %d -> %.1f%%" % [i + 1, reach[i], 100.0 * won[i] / maxf(1, reach[i])]
	print(line)
	if keep_late:
		var tc: Dictionary = {}
		for t: StringName in late_trait:
			tc[t] = int(tc.get(t, 0)) + 1
		print("  M5 decks by main trait: %s" % tc)


## Returns 0 if seat 0 won, 1 if seat 1, -1 draw.
func _duel(sa: SideSetup, aware_a: bool, sb: SideSetup, aware_b: bool, seed_value: int, mode: int, track: bool = false) -> int:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = MatchState.new(config, config.matches[0].map, _copy(sa), _copy(sb), seed_value, hooks)
	m.start_match()
	_play(m, _ai("competent", aware_a), _ai("competent", aware_b), track)
	return 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)


func _copy(s: SideSetup) -> SideSetup:
	var c: SideSetup = SideSetup.new()
	for f: String in ["display_name", "primary", "secondary", "lethal", "tactical", "doctrine"]:
		c.set(f, s.get(f))
	c.deck = s.deck.duplicate()
	c.deck_levels = s.deck_levels.duplicate()
	c.deck_traits = s.deck_traits.duplicate()
	c.deck_arts = s.deck_arts.duplicate()
	c.attachments = s.attachments.duplicate()
	c.perks = s.perks.duplicate()
	c.killstreaks = s.killstreaks.duplicate()
	return c


## A vs B, seats and modes alternating. Returns [A wins, seat-0 wins, games, seat-1 wins].
func _pair(a: SideSetup, aware_a: bool, b: SideSetup, aware_b: bool, count: int, salt: int, track: bool = false) -> Array:
	var aw: int = 0
	var s0: int = 0
	var s1: int = 0
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var w: int = _duel(a if a_seat == 0 else b, aware_a if a_seat == 0 else aware_b,
				b if a_seat == 0 else a, aware_b if a_seat == 0 else aware_a, 9000 + k * 7919 + salt, mode, track)
		if w == 0:
			s0 += 1
		elif w == 1:
			s1 += 1
		if w == a_seat:
			aw += 1
	return [aw, s0, count, s1]


func _traits() -> void:
	var groups: Dictionary = {}
	for i: int in late.size():
		var t: StringName = late_trait[i]
		if t == &"":
			continue
		if not groups.has(t):
			groups[t] = []
		(groups[t] as Array).append(i)
	var keys: Array = groups.keys()
	var total: Dictionary = {}
	print("\n---- traits: end-of-run decks by main trait, aware round robin (%d games per pairing) ----" % trait_n)
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			var ga: Array = groups[keys[a]]
			var gb: Array = groups[keys[b]]
			var aw: int = 0
			var games: int = 0
			for k: int in trait_n / 2:
				var da: SideSetup = late[ga[k % ga.size()]]
				var db: SideSetup = late[gb[(k * 7 + 3) % gb.size()]]
				var r: Array = _pair(da, true, db, true, 2, a * 1000 + b * 100 + k * 13)
				aw += int(r[0])
				games += int(r[2])
			print("  %-9s vs %-9s %5.1f%% (n=%d)" % [keys[a], keys[b], 100.0 * aw / maxf(1, games), games])
			for pair: Array in [[keys[a], aw], [keys[b], games - aw]]:
				var t: Array = total.get(pair[0], [0, 0])
				t[0] += int(pair[1])
				t[1] += games
				total[pair[0]] = t
	for k: StringName in total:
		print("  %-9s overall %5.1f%% (n=%d, decks %d)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), total[k][1], (groups[k] as Array).size()])


func _duel_late() -> void:
	var k: int = mini(late.size(), late_n)
	var d: Array = [0, 0]
	for i: int in k:
		var r: Array = _pair(late[i], true, late[i], false, 4, i * 17 + 5)
		d[0] += r[0]
		d[1] += r[2]
	print("\n  duel:   aware vs blind, same late deck          %5.1f%% (n=%d)" % [100.0 * d[0] / maxf(1, d[1]), d[1]])


func _mirrors() -> void:
	var k: int = mini(late.size(), late_n)
	var ml: Array = [0, 0, 0]
	init_stats = [0, 0, 0]
	var reps: int = maxi(2, mirror_n / maxi(1, k))
	reps += reps % 2
	for i: int in k:
		var r3: Array = _pair(late[i], true, late[i], true, reps, i * 17 + 9, true)
		ml[0] += r3[1]
		ml[1] += r3[2]
		ml[2] += r3[3]
	var li: Array[int] = init_stats.duplicate()
	init_stats = [0, 0, 0]
	var starter: SideSetup = RunProgress.create(config, 1).player_setup()
	var r4: Array = _pair(starter, true, starter, true, mirror_n, 77, true)
	print("  mirror: seat 0, late decks                      %5.1f%% (n=%d)  seat 0 of decided %.1f%%  seat 0 initiative %.1f%% of rounds, ties %.1f%%" % [
			100.0 * ml[0] / maxf(1, ml[1]), ml[1], 100.0 * ml[0] / maxf(1, ml[0] + ml[2]), 100.0 * li[1] / maxf(1, li[0]), 100.0 * li[2] / maxf(1, li[0])])
	print("  mirror: seat 0, Standard Issue starter          %5.1f%% (n=%d)  seat 0 of decided %.1f%%  seat 0 initiative %.1f%% of rounds, ties %.1f%%" % [
			100.0 * r4[1] / maxf(1, r4[2]), r4[2], 100.0 * r4[1] / maxf(1, r4[1] + r4[3]), 100.0 * init_stats[1] / maxf(1, init_stats[0]), 100.0 * init_stats[2] / maxf(1, init_stats[0])])
