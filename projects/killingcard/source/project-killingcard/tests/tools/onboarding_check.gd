# onboarding_check.gd
# Purpose: kc-onboard-impl §8 step 8: re-measure the approved onboarding package on the REAL build
#   (shipped run_config.tres, real RunProgress offers: rungs, calling cards, 2 picks of 4,
#   Muster out with its pre-selection, Salvage, Doctrine from the first pick; kc-no-training: no
#   Promotion, no Recruits), unlike
#   onboarding_sim.gd, which reimplements the ladder with sim-only cards.
#   Proxies are balance_sim's (competent / casual); squads are AiPlayer.for_squad, synergy-aware.
#   Offer rule (balance_sim's): a drop / Salvage takes its on-trait slot 1 when it's a unit or Field,
#   else the most expensive unit, else option 0; a 2-of-4 drop asks twice; Muster out = option 0
#   (the pre-selection: most expensive Standard Issue first); every other offer option 0.
#   Reports per proxy: run win, per-match reach / win, cards added, Standard Issue sent home, and the
#   M5 deck (size, Standard Issue units, calling-card units). Then, on the first proxy's
#   decks that reached M5: growth (late deck vs the Standard Issue starter, same loadout), duel
#   (aware vs blind, same late deck) and the seat-0 mirror (starter, and late decks).
#   Run: godot --headless --path . -s res://tests/tools/onboarding_check.gd -- runs=400 late=120 proxies=competent,casual
# Author: Mechanics Developer Agent (kc-onboard-impl)
extends SceneTree

var runs: int = 100
var late_n: int = 80
var mirror_n: int = 400
var proxies: Array[String] = ["competent", "casual"]
var config: RunConfig = null
var late: Array[SideSetup] = []


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
			"proxies":
				proxies.clear()
				for p: String in kv[1].split(","):
					proxies.append(p)
	var t0: int = Time.get_ticks_msec()
	print("onboarding_check: runs=%d late=%d mirror=%d proxies=%s (real RunProgress, shipped data)" % [runs, late_n, mirror_n, proxies])
	for k: int in proxies.size():
		_runs(proxies[k], k == 0)
	_late_checks()
	print("\nonboarding_check done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


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
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	return ai


func _play(m: MatchState, a: AiPlayer, b: AiPlayer) -> void:
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		b.take_turn(m, MatchState.ENEMY)
		a.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
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
	var added: int = 0
	var home: int = 0
	var m5: Array = [0, 0, 0, 0]  # decks, size, SI units, calling-card units
	var t0: int = Time.get_ticks_msec()
	for s: int in runs:
		var r: RunProgress = RunProgress.create(config, 900000 + s)
		r.begin()
		var start: int = r.deck.size()
		var taken: int = 0
		while not r.is_over():
			var idx: int = r.match_index
			if idx == 4:
				var ps: SideSetup = r.player_setup()
				m5[0] += 1
				m5[1] += r.deck.size()
				for i: int in r.deck.size():
					var c: CardData = r.resource(r.deck[i]) as CardData
					if c.standard_issue:
						m5[2] += 1
					elif c.is_unit():
						m5[3] += 1
				if keep_late:
					late.append(ps)
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
				var kind: StringName = r.current_offer()["kind"]
				var before: int = r.deck.size()
				if r.choose_offer(_choose(r)) != "":
					r.skip_offer()
				if kind in RewardOffers.CARD_DROPS and r.deck.size() > before:
					taken += 1
		if r.is_victory():
			wins += 1
		added += taken
		home += r.mustered_out
	print("\n---- %s: %d real runs (%.1f s) ----" % [proxy.to_upper(), runs, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  RUN WIN %.1f%% (%d/%d)" % [100.0 * wins / maxf(1, runs), wins, runs])
	var line: String = "  per match (reached -> win%%):"
	for i: int in 5:
		line += "  M%d %d -> %.1f%%" % [i + 1, reach[i], 100.0 * won[i] / maxf(1, reach[i])]
	print(line)
	print("  cards added / run %.2f, Standard Issue sent home / run %.2f" % [float(added) / runs, float(home) / runs])
	if m5[0] > 0:
		print("  deck at M5 (n=%d): size %.1f, Standard Issue units %.1f, calling-card units %.1f" % [
				m5[0], float(m5[1]) / m5[0], float(m5[2]) / m5[0], float(m5[3]) / m5[0]])


## Late deck vs late deck (or starter): A on seat a_seat. Returns 0 if seat 0 won, 1 if seat 1, -1 draw.
func _duel(sa: SideSetup, aware_a: bool, sb: SideSetup, aware_b: bool, seed_value: int, mode: int) -> int:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = MatchState.new(config, config.matches[0].map, _copy(sa), _copy(sb), seed_value, hooks)
	m.start_match()
	_play(m, _ai("competent", aware_a), _ai("competent", aware_b))
	return 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)


func _copy(s: SideSetup) -> SideSetup:
	var c: SideSetup = SideSetup.new()
	for f: String in ["display_name", "primary", "doctrine"]:
		c.set(f, s.get(f))
	c.deck = s.deck.duplicate()
	c.deck_traits = s.deck_traits.duplicate()
	c.deck_arts = s.deck_arts.duplicate()
	c.attachments = s.attachments.duplicate()
	c.perks = s.perks.duplicate()
	c.killstreaks = s.killstreaks.duplicate()
	return c


## A vs B, seats and modes alternating. Returns [A wins, seat-0 wins, decided-or-not count].
func _pair(a: SideSetup, aware_a: bool, b: SideSetup, aware_b: bool, count: int, salt: int) -> Array:
	var aw: int = 0
	var s0: int = 0
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var w: int = _duel(a if a_seat == 0 else b, aware_a if a_seat == 0 else aware_b,
				b if a_seat == 0 else a, aware_b if a_seat == 0 else aware_a, 9000 + k * 7919 + salt, mode)
		if w == 0:
			s0 += 1
		if w == a_seat:
			aw += 1
	return [aw, s0, count]


func _late_checks() -> void:
	var starter: SideSetup = RunProgress.create(config, 1).player_setup()
	var k: int = mini(late.size(), late_n)
	var g: Array = [0, 0]
	var d: Array = [0, 0]
	var ml: Array = [0, 0]
	for i: int in k:
		var ld: SideSetup = late[i]
		var st: SideSetup = _copy(ld)  # same loadout, the starter deck
		st.deck = starter.deck.duplicate()
		st.deck_traits = starter.deck_traits.duplicate()
		st.deck_arts = starter.deck_arts.duplicate()
		st.doctrine = &""
		var r1: Array = _pair(ld, true, st, true, 4, i * 17)
		g[0] += r1[0]
		g[1] += r1[2]
		var r2: Array = _pair(ld, true, ld, false, 4, i * 17 + 5)
		d[0] += r2[0]
		d[1] += r2[2]
		var r3: Array = _pair(ld, true, ld, true, 2, i * 17 + 9)
		ml[0] += r3[1]
		ml[1] += r3[2]
	var r4: Array = _pair(starter, true, starter, true, mirror_n, 77)
	print("\n---- late decks (first proxy's decks that reached M5: %d of %d) ----" % [k, late.size()])
	if g[1] > 0:
		print("  growth: late deck vs the starter, same loadout %5.1f%% (n=%d)" % [100.0 * g[0] / g[1], g[1]])
		print("  duel:   aware vs blind, same late deck          %5.1f%% (n=%d)" % [100.0 * d[0] / d[1], d[1]])
		print("  mirror: seat 0, late decks                      %5.1f%% (n=%d)" % [100.0 * ml[0] / ml[1], ml[1]])
	print("  mirror: seat 0, Standard Issue starter          %5.1f%% (n=%d)" % [100.0 * r4[1] / r4[2], r4[2]])
