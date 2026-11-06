# fight_sim.gd
# Purpose: kc-fight sim (documentation/design/firefight-order.md §6). The experiments and decks of
#   synergy_check.gd (the shipped engine), but the match is a FightState and both AIs plan with
#   FightPlanner, so the firefight runs in the prototype activation order of fight_order.gd:
#     order=now|seq|front   now = the shipped resolver (control); seq = front to back beats
#                           (recommended); front = front duel (only the front unit fires)
#     fs=pass|exchange      First Shot as its own pass of beats, or "fires first in its beat"
#     pierce=gunner,marksman  card ids that get the prototype keyword Pierce
#   plus synergy_check's exp=duel|mirror|traits|campaign n=N stage=... opcost=N syn=0 tune=...
#   Each experiment also prints pace stats: rounds per match, shots / beats / line advances per
#   round (both sides, all columns), for the playback-time estimate.
#   Run: godot --headless --path . -s res://tests/tools/fight_sim.gd -- exp=mirror n=200 order=seq
# Author: Sr Game Designer Agent (kc-fight), from synergy_check.gd (Mechanics Developer Agent)
extends SceneTree

const Sim = preload("res://tests/mode_sim.gd")
const FightOrder = preload("res://tests/tools/fight_order.gd")
const FightState = preload("res://tests/tools/fight_state.gd")
const FightPlanner = preload("res://tests/tools/fight_planner.gd")

const TRAIT_ADDS: Dictionary = {
	"vanguard": ["point_man", "breacher", "shieldman", "bulwark"],
	"specops": ["flanker", "recon_specialist", "marksman", "sniper_perch"],
	"heavy": ["gunner", "demolitions_expert", "demolitions_expert", "mortar_pit"],
	"undead": ["brawler", "brawler", "combat_medic", "war_standard"],
}
const RETIRE_ORDER: Array[String] = ["rifleman", "rifleman", "rifleman", "ammo_resupply"]
const PROMOTE_ORDER: Array[String] = ["point_man", "breacher", "marksman", "combat_medic"]

var config: RunConfig = null
var n: int = 40
var experiment: String = "duel"
var stage: String = "late"
var squads_aware: bool = true
var future_weight: float = 1.5
var decks: Array[String] = ["vanguard", "specops", "heavy", "undead"]
## Pace counters over every match played: rounds, firefights, shots, steps, eliminations, columns.
var pace: Dictionary = {}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"exp": experiment = kv[1]
			"n": n = int(kv[1])
			"stage": stage = kv[1]
			"squads": squads_aware = kv[1] == "aware"
			"decks":
				decks.clear()
				for d: String in kv[1].split(","):
					decks.append(d)
			"opcost": config.operator_cost = int(kv[1])
			"future": future_weight = float(kv[1])
			"trained": config.starter_recruits = kv[1] != "1"
			"syn": SynergyRules.enabled = kv[1] != "0"
			"tune":  # tune=vanguard.1.where=front (trait.tier_index.key=value, in memory)
				var tv: PackedStringArray = kv[1].split("=", true, 1)
				var tk: PackedStringArray = tv[0].split(".")
				var val: Variant = str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1]
				(SynergyRules.trait_bonus[StringName(tk[0])][int(tk[1])] as Dictionary)[tk[2]] = val
			"order": FightOrder.order = StringName(kv[1])
			"fs": FightOrder.fs_mode = StringName(kv[1])
			"pierce":
				for id: String in kv[1].split(",", false):
					FightOrder.pierce[id] = true
			_: push_error("fight_sim: unknown option " + arg)
	var t0: int = Time.get_ticks_msec()
	print("fight_sim exp=%s n=%d stage=%s opcost=%d order=%s fs=%s pierce=%s" % [experiment, n, stage, config.operator_cost,
			FightOrder.order, FightOrder.fs_mode, FightOrder.pierce.keys()])
	match experiment:
		"duel": _duel()
		"mirror": _mirror()
		"traits": _traits()
		"campaign": _campaign()
	_pace()
	print("fight_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## [cards, levels] for a deck name at the current stage.
func deck_for(name: String) -> Array:
	var cards: Array[CardData] = config.starter_deck.duplicate()
	var levels: Array[int] = config.starter_levels()
	if name == "starter" or stage == "starter":
		return [cards, levels]
	if stage == "late":
		for id: String in RETIRE_ORDER.slice(0, 3):
			for i: int in cards.size():
				if String(cards[i].id) == id:
					cards.remove_at(i)
					levels.remove_at(i)
					break
	for id: String in TRAIT_ADDS[name]:
		cards.append(_card(id))
		levels.append(1)
	if stage == "late":
		var promoted: int = 0
		for id: String in PROMOTE_ORDER:
			for i: int in cards.size():
				if promoted < 2 and String(cards[i].id) == id and levels[i] == 0:
					levels[i] = 1
					promoted += 1
					break
	return [cards, levels]


func _ai(aware: bool) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner = FightPlanner.new(p)
	ai.planner.synergy_aware = aware
	ai.planner.synergy_future_weight = future_weight
	return ai


func _setup(d: Array, name: String) -> SideSetup:
	var s: SideSetup = Sim.player_setup(config)
	s.display_name = name
	s.deck.assign(d[0])
	s.deck_levels.assign(d[1])
	return s


## One match: {winner: 0/1/-1, rounds, links: [per seat active links per unit-round], ms: [per seat]}.
func play(seat_decks: Array, seat_aware: Array, seed_value: int, mode: int) -> Dictionary:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = FightState.new(config, config.matches[0].map, _setup(seat_decks[0], "seat0"), _setup(seat_decks[1], "seat1"), seed_value, hooks)
	m.start_match()
	var ais: Array[AiPlayer] = [_ai(seat_aware[0]), _ai(seat_aware[1])]
	var link_stats: Array = [[0, 0], [0, 0]]
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		ais[1].take_turn(m, MatchState.ENEMY)
		ais[0].take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.reveal()
		for si: int in 2:
			link_stats[si][0] += m.sides[si].units_on_board().size()
			link_stats[si][1] += (m.synergy_side(si)["links"] as Array).size()
		var ev0: int = m.events.size()
		m.firefight()
		_count_events(m, ev0)
		m.score()
		m.begin_round()
	var w: int = -1
	if m.result == &"player":
		w = 0
	elif m.result == &"enemy":
		w = 1
	var ms: Array = []
	for ai: AiPlayer in ais:
		var t: int = 0
		for x: int in ai.turn_usecs:
			t += x
		ms.append(float(t) / 1000.0 / maxf(1, ai.turn_usecs.size()))
	pace["matches"] = int(pace.get("matches", 0)) + 1
	pace["match_rounds"] = int(pace.get("match_rounds", 0)) + m.round_number
	return {"winner": w, "rounds": m.round_number, "links": link_stats, "ms": ms}


func pairing(da: Array, aware_a: bool, db: Array, aware_b: bool, count: int, salt: int) -> Dictionary:
	var r: Dictionary = {"a": 0, "b": 0, "draw": 0, "seat0": 0, "rounds": 0, "la": [0, 0], "lb": [0, 0], "msa": 0.0, "msb": 0.0}
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var res: Dictionary = play([da, db] if a_seat == 0 else [db, da], [aware_a, aware_b] if a_seat == 0 else [aware_b, aware_a],
				9000 + k * 7919 + salt, mode)
		var w: int = res["winner"]
		if w == 0:
			r["seat0"] += 1
		if w < 0:
			r["draw"] += 1
		elif w == a_seat:
			r["a"] += 1
		else:
			r["b"] += 1
		r["rounds"] += int(res["rounds"])
		for j: int in 2:
			r["la"][j] += int(res["links"][a_seat][j])
			r["lb"][j] += int(res["links"][1 - a_seat][j])
		r["msa"] += float(res["ms"][a_seat]) / count
		r["msb"] += float(res["ms"][1 - a_seat]) / count
	r["n"] = count
	return r


func _fmt(r: Dictionary) -> String:
	var c: float = float(r["n"])
	return "A %5.1f%%  B %5.1f%%  draw %4.1f%%  seat0 %5.1f%%  rounds %.2f  links/unit A %.2f B %.2f  ms/turn A %.1f B %.1f" % [
			100.0 * r["a"] / c, 100.0 * r["b"] / c, 100.0 * r["draw"] / c, 100.0 * r["seat0"] / c, float(r["rounds"]) / c,
			float(r["la"][1]) / maxf(1, r["la"][0]), float(r["lb"][1]) / maxf(1, r["lb"][0]), r["msa"], r["msb"]]


func _duel() -> void:
	print("\n== aware (A) vs blind (B), same %s deck ==" % stage)
	var tot: Array = [0, 0]
	for d: String in decks:
		var deck: Array = deck_for(d)
		var r: Dictionary = pairing(deck, true, deck, false, n, hash(d) % 1000)
		tot[0] += int(r["a"])
		tot[1] += int(r["n"])
		print("%-9s %s" % [d, _fmt(r)])
	print("pooled aware win %.1f%% (n=%d)" % [100.0 * tot[0] / maxf(1, tot[1]), tot[1]])


func _mirror() -> void:
	print("\n== aware mirror, %s decks: seat 0 win rate ==" % stage)
	var tot: Array = [0, 0]
	for d: String in ["starter"] + decks:
		var deck: Array = deck_for(d)
		var r: Dictionary = pairing(deck, true, deck, true, n, 31 + hash(d) % 1000)
		tot[0] += int(r["seat0"])
		tot[1] += int(r["n"])
		print("%-9s %s" % [d, _fmt(r)])
	print("pooled seat 0 win %.1f%% (n=%d)" % [100.0 * tot[0] / maxf(1, tot[1]), tot[1]])


func _traits() -> void:
	print("\n== %s trait decks, aware round robin ==" % stage)
	var total: Dictionary = {}
	for i: int in decks.size():
		for j: int in range(i + 1, decks.size()):
			var r: Dictionary = pairing(deck_for(decks[i]), true, deck_for(decks[j]), true, n, i * 10 + j)
			print("%-9s vs %-9s %s" % [decks[i], decks[j], _fmt(r)])
			for pair: Array in [[decks[i], r["a"]], [decks[j], r["b"]]]:
				var t: Array = total.get(pair[0], [0, 0])
				t[0] += int(pair[1])
				t[1] += int(r["n"])
				total[pair[0]] = t
	for k: String in total:
		print("  %-9s overall %5.1f%%" % [k, 100.0 * total[k][0] / maxf(1, total[k][1])])


func _campaign() -> void:
	print("\n== campaign: aware player with the Recruit starter vs the real squads (%s) ==" % ("aware" if squads_aware else "blind"))
	var tot: Array = [0, 0]
	for i: int in config.matches.size():
		var slot: RunMatchData = config.matches[i]
		var w: int = 0
		for k: int in n:
			var mode: int = DataEnums.GameMode.ZONE_CONTROL if k % 2 == 0 else DataEnums.GameMode.FIREFIGHT
			var hooks: MatchHooks = MatchHooks.new()
			hooks.mode_rules = ModeRules.create(mode, config)
			var m: MatchState = FightState.new(config, slot.map, _setup(deck_for("starter"), "Player"),
					SideSetup.from_squad(slot.squad, slot), 5000 + k * 104729 + i, hooks)
			m.start_match()
			var enemy: AiPlayer = AiPlayer.for_squad(slot.squad)
			enemy.planner = FightPlanner.new(enemy.personality)
			enemy.planner.synergy_aware = squads_aware
			var player: AiPlayer = _ai(true)
			while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
				enemy.take_turn(m, MatchState.ENEMY)
				player.take_turn(m, MatchState.PLAYER, false)
				m.set_ready(MatchState.PLAYER)
				m.reveal()
				var ev0: int = m.events.size()
				m.firefight()
				_count_events(m, ev0)
				m.score()
				m.begin_round()
			pace["matches"] = int(pace.get("matches", 0)) + 1
			pace["match_rounds"] = int(pace.get("match_rounds", 0)) + m.round_number
			if m.result == &"player":
				w += 1
		tot[0] += w
		tot[1] += n
		print("slot %d (%s%s) win %5.1f%%" % [i + 1, slot.squad.id, ", Recruits" if slot.enemy_recruits else "", 100.0 * w / n])
	print("all slots win %5.1f%% (n=%d)" % [100.0 * tot[0] / tot[1], tot[1]])


func _count_events(m: MatchState, from: int) -> void:
	pace["ff_rounds"] = int(pace.get("ff_rounds", 0)) + 1
	for i: int in range(from, m.events.size()):
		var t: StringName = m.events[i]["type"]
		if t == RulesEvent.SHOT_FIRED:
			pace["shots"] = int(pace.get("shots", 0)) + 1
			if int(m.events[i].get("target_uid", -1)) >= 0:
				pace["hits"] = int(pace.get("hits", 0)) + 1
		elif t == RulesEvent.FIREFIGHT_STEP:
			pace["steps"] = int(pace.get("steps", 0)) + 1
		elif t == RulesEvent.FIREFIGHT_BEAT:  # kc-fight-impl: the shipped order's beats
			pace["beats"] = int(pace.get("beats", 0)) + 1
		elif t == RulesEvent.LINE_ADVANCED:
			pace["advances"] = int(pace.get("advances", 0)) + 1
		elif t == RulesEvent.FIREFIGHT_STARTED:
			pace["columns"] = int(pace.get("columns", 0)) + 1
		elif t == RulesEvent.UNIT_ELIMINATED:
			pace["elims"] = int(pace.get("elims", 0)) + 1


func _pace() -> void:
	var r: float = maxf(1, int(pace.get("ff_rounds", 0)))
	var fo: Dictionary = FightOrder.stats
	print("pace: matches %d  rounds/match %.2f  per round: columns fought %.2f  shots %.2f (hit %.2f)  eliminations %.2f  | beats %.2f  advances %.2f  (old-resolver steps %.2f)" % [
			int(pace.get("matches", 0)), float(pace.get("match_rounds", 0)) / maxf(1, int(pace.get("matches", 0))),
			float(pace.get("columns", 0)) / r, float(pace.get("shots", 0)) / r, float(pace.get("hits", 0)) / r,
			float(pace.get("elims", 0)) / r, float(fo.get("beats", 0)) / r, float(fo.get("advances", 0)) / r,
			float(pace.get("steps", 0)) / r])
	if int(pace.get("beats", 0)) > 0:
		var secs: float = FirefightResolver.PLAYBACK_COLUMN_S * float(pace.get("columns", 0)) \
				+ FirefightResolver.PLAYBACK_BEAT_S * float(pace.get("beats", 0)) + FirefightResolver.PLAYBACK_ADVANCE_S * float(pace.get("advances", 0))
		print("shipped order: beats %.2f  advances %.2f per round  playback at x1 %.1f s per round (x2 %.1f s)" % [
				float(pace["beats"]) / r, float(pace.get("advances", 0)) / r, secs / r, secs / r / 2.0])
	if int(fo.get("rounds", 0)) > 0:
		var hist: Array = []
		var cum: int = 0
		var p50: int = -1
		var p90: int = -1
		for sec: int in 13:
			var c: int = int(fo.get("t_hist:%d" % sec, 0))
			cum += c
			if p50 < 0 and cum * 2 >= int(fo["rounds"]):
				p50 = sec + 1
			if p90 < 0 and cum * 10 >= int(fo["rounds"]) * 9:
				p90 = sec + 1
			hist.append(c)
		print("playback at x1: mean %.1f s per round, median < %d s, p90 < %d s, histogram by whole seconds %s" % [
				float(fo["t_ms"]) / 1000.0 / float(fo["rounds"]), p50, p90, hist])
	if int(fo.get("excess", 0)) > 0:
		var parts: Array = []
		for k: String in fo:
			if k.begins_with("excess:"):
				var id: String = k.substr(7)
				parts.append([int(fo[k]), "%s %.3f/round (%.2f per shot)" % [id, float(fo[k]) / r, float(fo[k]) / maxf(1, int(fo.get("shots:" + id, 0)))]])
		parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		print("overkill (damage over the target's Armor, lost without Pierce) %.2f/round: %s" % [float(fo["excess"]) / r,
				", ".join(parts.slice(0, 10).map(func(x: Array) -> String: return x[1]))])
	if int(fo.get("pierce_damage", 0)) > 0:
		print("pierce damage per round %.2f" % (float(fo["pierce_damage"]) / r))
