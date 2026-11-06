# mode_sim.gd
# Purpose: Test helper (not a test file): plays whole matches with real game data
#   (res://data run config, starter kit, squads, maps) and a simple greedy policy on
#   both sides, under the match slot's mode. Used to check that typical matches of
#   both modes finish within the round cap.
#   Use: const Sim = preload("res://tests/mode_sim.gd")
# Author: Mechanics Developer Agent
extends RefCounted


## Player side from the run config's starter kit.
static func player_setup(config: RunConfig) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Player"
	s.deck = config.starter_deck.duplicate()
	s.deck_levels = config.starter_levels()  # kc-syn: the starter plays Recruit copies
	s.primary = config.starter_primary
	s.killstreaks = config.starter_killstreaks.duplicate()
	return s


## New started match for one RunMatchData slot, optionally forcing a mode.
static func match_for(config: RunConfig, slot: RunMatchData, seed_value: int, mode: int = -1) -> MatchState:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(slot.mode if mode < 0 else mode, config)
	var m: MatchState = MatchState.new(config, slot.map, player_setup(config),
			SideSetup.from_squad(slot.squad, slot), seed_value, hooks)
	m.start_match()
	return m


## Plays until the match ends (or `max_rounds` as a safety stop). Returns the rounds played.
static func play_out(m: MatchState, max_rounds: int = 20) -> int:
	while m.phase != MatchState.Phase.ENDED and m.round_number <= max_rounds:
		for side: int in [MatchState.ENEMY, MatchState.PLAYER]:
			_greedy_deploy(m, side)
			m.set_ready(side)
		m.resolve_round()
		m.begin_round()
	return m.round_number


## Greedy policy: (re)place the Operator in the weakest zone, then play the most
## expensive affordable units into zones the side doesn't control yet (most enemy
## pressure first), then damage tactics / items on the zone with most enemies.
static func _greedy_deploy(m: MatchState, side: int) -> void:
	var s: RulesSide = m.sides[side]
	if s.operator_can_deploy:
		m.submit(side, RulesIntent.place_operator(_zone_order(m, side)[0]))
	var hand: Array[RulesCard] = s.hand.duplicate()
	hand.sort_custom(func(a: RulesCard, b: RulesCard) -> bool: return a.card.cost > b.card.cost)
	for c: RulesCard in hand:
		if c.card.cost > s.supply:
			continue
		if c.card.card_type == DataEnums.CardType.UNIT:
			for z: int in _zone_order(m, side):
				if m.submit(side, RulesIntent.play_card(c.uid, z))["ok"]:
					break
		else:
			var hot: int = _hottest_zone(m, side)
			if not m.submit(side, RulesIntent.play_card(c.uid, hot))["ok"]:
				var own: int = _own_zone(m, side)
				if own >= 0:
					var target: RulesUnit = s.line(own)[0]
					m.submit(side, RulesIntent.play_card(c.uid, own, target.uid, (own + 1) % 3 if own != 1 else 0))


## Zones ordered: contested-by-enemy first, then empty, then already ours.
static func _zone_order(m: MatchState, side: int) -> Array[int]:
	var zones: Array[int] = [0, 1, 2]
	var foe: RulesSide = m.sides[1 - side]
	var me: RulesSide = m.sides[side]
	zones.sort_custom(func(a: int, b: int) -> bool:
		var pa: int = foe.line(a).size() * 2 - me.line(a).size() - m.projected_occupancy(side, a)
		var pb: int = foe.line(b).size() * 2 - me.line(b).size() - m.projected_occupancy(side, b)
		return pa > pb if pa != pb else a < b)
	return zones


static func _hottest_zone(m: MatchState, side: int) -> int:
	var best: int = 1
	for z: int in 3:
		if m.sides[1 - side].line(z).size() > m.sides[1 - side].line(best).size():
			best = z
	return best


static func _own_zone(m: MatchState, side: int) -> int:
	for z: int in 3:
		if not m.sides[side].line(z).is_empty():
			return z
	return -1
