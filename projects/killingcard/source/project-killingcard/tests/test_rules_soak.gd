# test_rules_soak.gd
# Purpose: p18 rules soak. Plays whole matches headless with the real AI (AiPlayer) on BOTH
#   sides and real data (run config, squads, Port Vasel), and checks engine invariants after
#   every Deploy and every round:
#   - no negative Supply, no unit below 0 Armor or above its max, no dead unit left on the board
#   - no zone line over capacity (4), each unit on the board once, Operator in at most one line
#   - hand <= 7, every card accounted for (deck + hand + discard + board + Equipment)
#   - streak >= 0; Streak Tray only holds the side's own killstreaks, with no duplicates;
#     every killstreak whose threshold the streak reaches was earned this life; a reset
#     clears the life
#   - red dots equal the AI's committed unit deployments (Ruling 13)
#   - the engine never refuses an AI intent; every match ends by round 10 (overtime cap)
#   Two sweeps: (A) every run slot x many seeds with a randomised player loadout (Perks,
#   attachments, all four killstreaks in rotation); (B) whole runs through RunProgress
#   (random killstreak picks, random reward choices) until the run ends.
# Author: QA Agent (p18)
extends "res://tests/test_case.gd"

const SEEDS_PER_SLOT: int = 30
const RUNS: int = 20
const ROUND_LIMIT: int = 10

var _violations: Array[String] = []
var _rounds_total: int = 0
var _matches: int = 0
var _max_round: int = 0
var _results: Dictionary = {}


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func _note(ok: bool, what: String) -> void:
	if not ok and _violations.size() < 40:
		_violations.append(what)


## Collectible cards one side owns right now (Deploy, nothing queued).
func _card_count(s: RulesSide) -> int:
	var n: int = s.deck.size() + s.hand.size() + s.discard.size()
	for u: RulesUnit in s.units_on_board():
		if not u.is_operator and u.card != null and u.card.collectible:
			n += 1
	for z: int in 3:
		n += (s.equipment[z] as Array).size()
	for play: Dictionary in s.plays:
		if play.has("card") and play["card"] != null:
			n += 1
	return n


func _check_board(m: MatchState, tag: String) -> void:
	var seen: Dictionary = {}
	for s: RulesSide in m.sides:
		var who: String = "%s %s r%d" % [tag, m.side_name(s.index), m.round_number]
		_note(s.supply >= 0, "%s: supply %d < 0" % [who, s.supply])
		_note(s.hand.size() <= m.config.hand_cap, "%s: hand %d > cap" % [who, s.hand.size()])
		_note(s.streak >= 0, "%s: streak %d < 0" % [who, s.streak])
		var ops: int = 0
		for z: int in 3:
			var line: Array = s.line(z)
			_note(line.size() <= m.config.zone_capacity, "%s: zone %d holds %d units" % [who, z, line.size()])
			for u: RulesUnit in line:
				_note(not seen.has(u.uid), "%s: unit %d in two places" % [who, u.uid])
				seen[u.uid] = true
				_note(u.zone == z, "%s: unit %s zone field %d != line %d" % [who, u.source_id, u.zone, z])
				_note(u.armor >= 0, "%s: %s armor %d < 0" % [who, u.source_id, u.armor])
				_note(u.armor <= u.max_armor(m.round_number), "%s: %s armor %d > max %d" % [who, u.source_id, u.armor, u.max_armor(m.round_number)])
				if m.phase == MatchState.Phase.DEPLOY:
					_note(u.armor >= 1, "%s: dead %s still on the board at Deploy" % [who, u.source_id])
				if u.is_operator:
					ops += 1
					_note(u == s.operator_unit, "%s: foreign Operator in line" % who)
		_note(ops <= 1, "%s: Operator in %d lines" % [who, ops])
		var ks_ids: Array[StringName] = []
		for ks: LoadoutItem in s.setup.killstreaks:
			ks_ids.append(ks.id)
		var tray_seen: Dictionary = {}
		for id: StringName in s.streak_tray:
			_note(id in ks_ids, "%s: tray holds foreign killstreak %s" % [who, id])
			_note(not tray_seen.has(id), "%s: tray holds %s twice" % [who, id])
			tray_seen[id] = true


func _check_streak_after_score(m: MatchState, tag: String) -> void:
	for s: RulesSide in m.sides:
		var who: String = "%s %s r%d" % [tag, m.side_name(s.index), m.round_number]
		if s.operator_down_this_round:
			_note(s.streak == 0, "%s: Operator down but streak %d" % [who, s.streak])
			_note(s.earned_this_life.is_empty(), "%s: Operator down but life keeps %s" % [who, s.earned_this_life])
		for ks: LoadoutItem in s.setup.killstreaks:
			if s.streak >= StreakTracker.threshold_for(m, s.index, ks):
				_note(ks.id in s.earned_this_life, "%s: streak %d reached %s but not earned" % [who, s.streak, ks.id])
		for id: StringName in s.earned_this_life:
			_note(s.streak > 0 or s.streak_bonus_this_round > 0, "%s: %s earned this life with streak 0" % [who, id])


## Plays `m` to the end with an AI on each side, checking invariants. Returns rounds played.
func _play(m: MatchState, enemy_ai: AiPlayer, player_ai: AiPlayer, tag: String) -> int:
	var counts: Array[int] = [_card_count(m.sides[0]), _card_count(m.sides[1])]
	while m.phase != MatchState.Phase.ENDED and m.round_number <= ROUND_LIMIT + 2:
		_check_board(m, tag + " briefing")
		for si: int in 2:
			_note(_card_count(m.sides[si]) == counts[si], "%s r%d %s: %d cards, started with %d" % [
					tag, m.round_number, m.side_name(si), _card_count(m.sides[si]), counts[si]])
		enemy_ai.take_turn(m, MatchState.ENEMY)
		_note(enemy_ai.last_rejected.is_empty(), "%s r%d enemy AI refused: %s (accepted %s)" % [tag, m.round_number, enemy_ai.last_rejected, enemy_ai.last_intents])
		# Red dots the player sees = the enemy's committed unit cards + Operator place/rotate.
		var expect: Array[int] = [0, 0, 0]
		for intent: Dictionary in enemy_ai.last_intents:
			if intent.get("type", &"") in [RulesIntent.PLACE_OPERATOR, RulesIntent.ROTATE]:
				expect[int(intent["zone"])] += 1
		for play: Dictionary in m.sides[1].plays:
			if play["kind"] == &"unit":
				expect[int(play["zone"])] += 1
		var dots: PackedInt32Array = m.red_dots(MatchState.PLAYER)
		_note(Array(dots) == expect, "%s r%d red dots %s != committed %s" % [tag, m.round_number, dots, expect])
		player_ai.take_turn(m, MatchState.PLAYER)
		_note(player_ai.last_rejected.is_empty(), "%s r%d player AI refused: %s" % [tag, m.round_number, player_ai.last_rejected])
		_check_board(m, tag + " deploy")
		for si: int in 2:
			_note(_card_count(m.sides[si]) == counts[si], "%s r%d %s after deploy: %d cards != %d" % [
					tag, m.round_number, m.side_name(si), _card_count(m.sides[si]), counts[si]])
		m.resolve_round()
		_check_board(m, tag + " score")
		_check_streak_after_score(m, tag)
		m.begin_round()
	_note(m.result != &"", "%s: no result after round %d" % [tag, m.round_number])
	_note(m.round_number <= ROUND_LIMIT, "%s: ended in round %d (> %d)" % [tag, m.round_number, ROUND_LIMIT])
	_matches += 1
	_rounds_total += m.round_number
	_max_round = maxi(_max_round, m.round_number)
	_results[m.result] = int(_results.get(m.result, 0)) + 1
	return m.round_number


func _intent_kinds_ok() -> bool:
	# Guard for the red-dot expectation above: the intent kinds it looks for must exist.
	var p: Dictionary = RulesIntent.place_operator(1)
	var r: Dictionary = RulesIntent.rotate(1)
	return p.get("type") == RulesIntent.PLACE_OPERATOR and r.get("type") == RulesIntent.ROTATE


func _player_ai(rng: RandomNumberGenerator) -> AiPlayer:
	var kinds: Array = [DataEnums.Personality.RUSHER, DataEnums.Personality.ANCHOR]
	return AiPlayer.new(AiPersonality.for_kind(kinds[rng.randi() % 2]))


func _report(label: String) -> void:
	print("     %s: %d matches, avg %.1f rounds, longest %d, results %s, %d invariant violations" % [
			label, _matches, float(_rounds_total) / maxf(1.0, _matches), _max_round, _results, _violations.size()])
	for v: String in _violations.slice(0, 15):
		print("       ! " + v)


func test_ai_vs_ai_every_slot_many_seeds_keeps_invariants() -> void:
	assert_true(_intent_kinds_ok(), "intent kinds for red-dot check")
	var cfg: RunConfig = _config()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1818
	var all_ks: Array[LoadoutItem] = cfg.killstreak_pool.duplicate()
	for slot_index: int in cfg.matches.size():
		var slot: RunMatchData = cfg.matches[slot_index]
		for s: int in SEEDS_PER_SLOT:
			var setup: SideSetup = SideSetup.new()
			setup.display_name = "Player"
			setup.deck = cfg.starter_deck.duplicate()
			# Supply Drop extras so reward cards (Anvil, Wren, Comms Relay...) see play too.
			for i: int in s % 4:
				setup.deck.append(cfg.reward_pool[rng.randi() % cfg.reward_pool.size()])
			setup.primary = cfg.starter_primary
			setup.secondary = cfg.starter_secondary
			setup.lethal = cfg.starter_lethal
			setup.tactical = cfg.starter_tactical
			var pool: Array[LoadoutItem] = all_ks.duplicate()
			pool.remove_at(s % pool.size())
			setup.killstreaks = pool.slice(0, cfg.killstreak_slots)
			var perks: Array[LoadoutItem] = cfg.perk_pool.duplicate()
			for i: int in mini(s % 3, perks.size()):
				setup.perks.append(perks[(s + i) % perks.size()])
			for i: int in mini(s % 4, cfg.starter_primary.attachments.size()):
				setup.attachments.append(cfg.starter_primary.attachments[i] as LoadoutItem)
			var hooks: MatchHooks = MatchHooks.new()
			hooks.mode_rules = ModeRules.create(slot.mode, cfg)
			var m: MatchState = MatchState.new(cfg, slot.map, setup, SideSetup.from_squad(slot.squad, slot),
					20000 + slot_index * 100 + s, hooks)
			m.start_match()
			_play(m, AiPlayer.for_squad(slot.squad), _player_ai(rng), "slot%d seed%d" % [slot_index, s])
	_report("AI vs AI per slot")
	assert_eq(_matches, cfg.matches.size() * SEEDS_PER_SLOT, "matches played")
	assert_eq(_violations.size(), 0, "invariant violations: %s" % [_violations.slice(0, 5)])


func test_whole_runs_ai_vs_ai_end_and_keep_invariants() -> void:
	var cfg: RunConfig = _config()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1819
	var victories: int = 0
	var slots_played: Dictionary = {}
	for r: int in RUNS:
		var run: RunProgress = RunProgress.create(cfg, 7000 + r)
		var ks: Array = []
		for item: LoadoutItem in cfg.killstreak_pool:
			ks.append(item.id)
		ks.remove_at(r % ks.size())
		assert_eq(run.set_killstreaks(ks.slice(0, cfg.killstreak_slots)), "", "run %d killstreaks" % r)
		assert_eq(run.begin(), "", "run %d begins" % r)
		var guard: int = 0
		while not run.is_over() and guard < 40:
			guard += 1
			if run.phase == RunProgress.PHASE_REWARDS:
				var offer: Dictionary = run.current_offer()
				if rng.randf() < 0.15:
					assert_eq(run.skip_offer(), "", "skip offer")
				else:
					assert_eq(run.choose_offer(rng.randi() % (offer["options"] as Array).size()), "", "choose offer")
				continue
			slots_played[run.match_index] = true
			var m: MatchState = run.create_match()
			m.start_match()
			_play(m, AiPlayer.for_squad(run.current_match().squad), _player_ai(rng), "run%d m%d" % [r, run.match_number()])
			var rec: Dictionary = run.record_match(m)
			assert_true(rec["ok"], "run %d recorded" % r)
		assert_true(run.is_over(), "run %d ended (guard %d)" % [r, guard])
		_note(run.tickets >= 0, "run %d tickets %d" % [r, run.tickets])
		_note(run.history.size() <= cfg.matches.size(), "run %d played %d matches" % [r, run.history.size()])
		if run.is_victory():
			victories += 1
		print("       run %d: %s (%s) after %d matches, tickets %d, deck %d, perks %s, attachments %s" % [
				r, run.result, run.end_reason, run.history.size(), run.tickets, run.deck.size(), run.perks, run.attachments])
	_report("AI vs AI whole runs (%d victories of %d)" % [victories, RUNS])
	assert_true(slots_played.size() >= 2, "runs reached %d slots" % slots_played.size())
	assert_eq(_violations.size(), 0, "invariant violations: %s" % [_violations.slice(0, 5)])
