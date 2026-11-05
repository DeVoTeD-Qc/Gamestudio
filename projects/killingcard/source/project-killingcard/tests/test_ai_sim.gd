# test_ai_sim.gd
# Purpose: p07 whole-match simulation: the AiPlayer (Rusher, Anchor) replaces
#   mode_sim's greedy enemy and plays ~30 matches per personality (the run's own
#   match slots for that squad: Zone Control and Firefight, real data) against the
#   greedy player policy. Prints win rates next to the old greedy-enemy baseline on
#   the same seeds, and the AI's turn times. Asserts: every match ends by the
#   overtime round, the engine never refuses an AI intent, and an AI turn stays
#   under the desktop budget (40 ms headless, the proxy for < 200 ms on a phone).
#   Balance itself is p19; the numbers are reported, not asserted.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Sim = preload("res://tests/mode_sim.gd")
const SEEDS_PER_SLOT: int = 15
const TURN_BUDGET_USEC: int = 40000


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


## Plays one match; `ai` null = greedy enemy (the p06 baseline). Returns [result, rounds, rejected].
func _play(slot: RunMatchData, seed_value: int, ai: AiPlayer) -> Array:
	var m: MatchState = Sim.match_for(_config(), slot, seed_value)
	var rejected: int = 0
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 12:
		if ai != null:
			ai.take_turn(m, MatchState.ENEMY)
			rejected += ai.last_rejected.size()
		else:
			Sim._greedy_deploy(m, MatchState.ENEMY)
			m.set_ready(MatchState.ENEMY)
		Sim._greedy_deploy(m, MatchState.PLAYER)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	return [m.result, m.round_number, rejected]


func _rate(n: int, total: int) -> String:
	return "%d/%d (%d%%)" % [n, total, roundi(100.0 * n / maxf(1.0, total))]


func test_ai_vs_greedy_player() -> void:
	var cfg: RunConfig = _config()
	var by_squad: Dictionary = {}
	for i: int in cfg.matches.size():
		var slot: RunMatchData = cfg.matches[i]
		if slot.squad.personality in [DataEnums.Personality.RUSHER, DataEnums.Personality.ANCHOR]:
			by_squad.get_or_add(slot.squad.id, []).append(i)
	var all_turns: Array[int] = []
	for squad_id: Variant in by_squad:
		var ai_tally: Dictionary = {&"enemy": 0, &"player": 0, &"draw": 0}
		var base_tally: Dictionary = {&"enemy": 0, &"player": 0, &"draw": 0}
		var turns: Array[int] = []
		var rounds: int = 0
		var total: int = 0
		for slot_index: int in by_squad[squad_id]:
			var slot: RunMatchData = cfg.matches[slot_index]
			for s: int in SEEDS_PER_SLOT:
				var seed_value: int = 10000 + slot_index * 100 + s
				var ai: AiPlayer = AiPlayer.for_squad(slot.squad)
				var r: Array = _play(slot, seed_value, ai)
				assert_true(r[0] != &"", "%s slot %d seed %d ended (round %d)" % [squad_id, slot_index, seed_value, r[1]])
				assert_eq(r[2], 0, "%s seed %d: intents refused" % [squad_id, seed_value])
				ai_tally[r[0]] = int(ai_tally.get(r[0], 0)) + 1
				rounds += int(r[1])
				total += 1
				turns.append_array(ai.turn_usecs)
				var b: Array = _play(slot, seed_value, null)
				base_tally[b[0]] = int(base_tally.get(b[0], 0)) + 1
		turns.sort()
		all_turns.append_array(turns)
		var sum: int = 0
		for t: int in turns:
			sum += t
		print("     %s vs greedy player (%d matches, slots %s): AI wins %s, player wins %s, draws %d, avg %.1f rounds" % [
				squad_id, total, str(by_squad[squad_id]), _rate(ai_tally[&"enemy"], total),
				_rate(ai_tally[&"player"], total), ai_tally[&"draw"], float(rounds) / total])
		print("       baseline greedy enemy on the same seeds: enemy wins %s" % _rate(base_tally[&"enemy"], total))
		print("       AI turn: avg %.1f ms, p95 %.1f ms, max %.1f ms (%d turns)" % [
				sum / 1000.0 / turns.size(), turns[int(turns.size() * 0.95)] / 1000.0, turns.back() / 1000.0, turns.size()])
	all_turns.sort()
	assert_true(all_turns.size() > 200, "%d AI turns measured" % all_turns.size())
	var p95: int = all_turns[int(all_turns.size() * 0.95)]
	assert_true(p95 < TURN_BUDGET_USEC, "p95 AI turn %.1f ms < 40 ms" % (p95 / 1000.0))
	# Max with a little slack for CI noise (first-call warm-up, GC).
	assert_true(all_turns.back() < TURN_BUDGET_USEC * 2, "max AI turn %.1f ms" % (all_turns.back() / 1000.0))
