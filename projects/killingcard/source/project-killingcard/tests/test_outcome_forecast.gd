# test_outcome_forecast.gd
# Purpose: p12 outcome preview, rules side. OutcomeForecast runs the real engine on a MatchClone
#   copy, so with no hidden enemy plays its per-zone numbers must equal the real resolve_round()
#   exactly (damage dealt / taken, eliminations both ways, zone control). Also: the live state is
#   never changed (purity + same events as an untouched twin), the copy is independent, and the
#   enemy's face-down plan (plays, hidden Equipment) never reaches the preview (red dots only).
# Author: UI/UX Agent (p12)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const KEYS: Array[String] = ["dealt", "taken", "kills", "losses", "kill_uids", "loss_uids", "fight"]


# --- helpers ----------------------------------------------------------------------------

## Resolves the round on `m` (enemy passes) and returns the real numbers in forecast shape.
func _resolve_real(m: MatchState) -> Array:
	var zones_before: Dictionary = OutcomeForecast.unit_zones(m)
	m.set_ready(P)
	m.set_ready(E)
	var events: Array[Dictionary] = m.resolve_round()
	var until_score: Array = []
	for e: Dictionary in events:
		if e["type"] == RulesEvent.PHASE_CHANGED and e["phase"] == &"score":
			break
		until_score.append(e)
	var real: Array = OutcomeForecast.summarize(until_score, zones_before, P)
	var control: Array[StringName] = OutcomeForecast.control_from_events(events, P)
	for z: int in 3:
		real[z]["control"] = control[z]
	return real


## Forecast, then the real round; asserts every zone matches. Returns [forecast zones, real].
func _check_matches(m: MatchState, label: String) -> Array:
	var fc: Dictionary = OutcomeForecast.forecast(m, P)
	assert_true(fc["ok"], "%s: forecast available in Deploy" % label)
	var real: Array = _resolve_real(m)
	for z: int in 3:
		for k: String in KEYS + ["control"]:
			assert_eq(fc["zones"][z][k], real[z][k], "%s zone %d %s" % [label, z, k])
	return [fc["zones"], real]


func _supply(m: MatchState, n: int = 10) -> void:
	m.sides[P].supply = n
	m.sides[E].supply = n


## Everything about the live state the preview could disturb.
func _fingerprint(m: MatchState) -> String:
	var parts: Array = [m.events.size(), m.rng.state, m.phase, m.round_number, m.initiative,
			m.firefight_effects.size(), m.round_eliminations.size(), m._next_uid, m._play_counter]
	for s: RulesSide in m.sides:
		parts.append([s.supply, s.score, s.streak, s.eliminations, s.plays.size(), s.ready, s.rotations_used,
				s.hand.map(func(c: RulesCard) -> int: return c.uid), s.discard.size(), s.deck.size(),
				s.arrival_buffs.size(), s.equipment.map(func(l: Array) -> int: return l.size()),
				s.uses_this_round.duplicate(), s.streak_tray.duplicate()])
		var units: Array = s.units_on_board()
		if s.operator_unit != null and not s.operator_unit.is_on_board():
			units.append(s.operator_unit)
		for u: RulesUnit in units:
			parts.append([u.uid, u.zone, u.armor, u.mods.size(), u.fired, u.survive_lethal, u.lethal_source.size()])
	if m.hooks.mode_rules != null:
		parts.append([m.hooks.mode_rules.last_gain.duplicate(), m.hooks.mode_rules.outcome.size()])
	return var_to_str(parts)


# --- matches the real resolver ----------------------------------------------------------

func test_simple_trade_matches_hand_count_and_real_round() -> void:
	# Grunt 2/3 on the board vs a queued Hitter 3/2 in Mid: both shoot in the Main step and
	# both die (dealt 3, taken 2, one kill each way, the zone ends empty).
	var m: MatchState = F.new_match(F.setup([F.unit("hitter", 3, 2)]))
	F.place(m, E, F.unit("grunt", 2, 3), F.MID)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "hitter"), F.MID))["ok"], "queue hitter")
	var res: Array = _check_matches(m, "trade")
	var mid: Dictionary = res[0][F.MID]
	assert_eq([mid["dealt"], mid["taken"], mid["kills"], mid["losses"], mid["fight"], mid["control"]],
			[3, 2, 1, 1, true, &"empty"], "hand-counted Mid")
	assert_eq(res[0][F.LEFT]["fight"], false, "no fight on the Left")


func test_keywords_and_three_zones_match_real_round() -> void:
	# First Shot, Pick, Cover, Patch, Suppress, Holder in all three zones, damage persisting
	# from earlier (wounded enemy), the player's Operator placed this Deploy.
	var deck: Array = [F.point_man(), F.marksman(), F.combat_medic(), F.anvil(), F.rifleman()]
	var m: MatchState = F.new_match(F.setup(deck, F.kestrel()), F.setup([], F.kestrel()))
	_supply(m, 20)
	F.place(m, E, F.shieldman(), F.LEFT)
	F.place(m, E, F.rifleman(), F.LEFT)
	var wounded: RulesUnit = F.place(m, E, F.gunner(), F.MID)
	wounded.armor = 3
	F.place(m, E, F.breacher(), F.MID)
	F.place(m, E, F.flanker(), F.RIGHT)
	F.place(m, P, F.rifleman(), F.RIGHT)
	for play: Array in [["point_man", F.LEFT], ["marksman", F.LEFT], ["combat_medic", F.MID],
			["anvil", F.MID], ["rifleman", F.RIGHT]]:
		assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, play[0]), play[1]))["ok"], "queue %s" % play[0])
	assert_true(m.submit(P, RulesIntent.place_operator(F.RIGHT))["ok"], "place Operator")
	var res: Array = _check_matches(m, "three zones")
	var fights: int = 0
	var total: int = 0
	for z: int in 3:
		fights += 1 if res[1][z]["fight"] else 0
		total += int(res[1][z]["dealt"]) + int(res[1][z]["taken"]) + int(res[1][z]["kills"]) + int(res[1][z]["losses"])
	assert_eq(fights, 3, "a firefight in every zone")
	assert_true(total > 10, "the scenario does real work (%d)" % total)


func test_tactics_items_and_moves_match_real_round() -> void:
	# Reveal-step effects count too: Breach and Clear damage, an Operator-range strike (point_strike), and
	# Flank Route moving a unit into another zone before the firefight.
	var p: SideSetup = F.setup([F.breach_and_clear(), F.flank_route(), F.rifleman()], F.kestrel())
	var m: MatchState = F.new_match(p, F.setup([], F.kestrel()), F.map())
	F.grant(m, P, F.point_strike())
	_supply(m)
	F.place_operator(m, P, F.MID)
	var mover: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)
	F.place(m, E, F.rifleman(), F.LEFT)
	F.place(m, E, F.point_man(), F.LEFT)
	F.place(m, E, F.gunner(), F.MID)
	F.place(m, E, F.marksman(), F.MID)
	F.place(m, E, F.combat_medic(), F.RIGHT)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "breach_and_clear"), F.LEFT))["ok"], "breach")
	assert_true(m.submit(P, RulesIntent.use_item(&"point_strike", F.MID))["ok"], "point strike")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "flank_route"), F.MID, mover.uid, F.MID))["ok"], "flank route")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "rifleman"), F.RIGHT))["ok"], "rifleman")
	var res: Array = _check_matches(m, "reveal effects")
	assert_true(int(res[1][F.LEFT]["dealt"]) >= 4, "Breach and Clear hit the Left")


func test_attack_helo_and_own_tripwire_match_real_round() -> void:
	# Effects registered in an earlier round (Attack Helo) and the player's own hidden Tripwire
	# are known to the player, so they are simulated.
	var p: SideSetup = F.setup([F.tripwire()], F.kestrel())
	p.killstreaks.assign([F.attack_helo()])
	var m: MatchState = F.new_match(p, F.setup([F.rifleman(), F.rifleman()], F.kestrel()))
	_supply(m)
	F.place_operator(m, P, F.MID)
	F.place(m, E, F.gunner(), F.MID)
	m.sides[P].streak_tray.append(&"attack_helo")
	assert_true(m.submit(P, RulesIntent.use_item(&"attack_helo"))["ok"], "helo")
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), F.RIGHT))["ok"], "tripwire")
	_check_matches(m, "round 1")
	m.begin_round()
	_supply(m)
	# Round 2: the helo is still registered; the enemy's Rifleman walks into the player's Tripwire.
	var wire_victim: RulesUnit = m.create_unit(E, F.rifleman())
	m.put_in_line(wire_victim, F.RIGHT)
	m.trigger_traps(E, wire_victim)
	m.process_eliminations()
	F.place(m, E, F.rifleman(), F.LEFT)
	var res: Array = _check_matches(m, "round 2")
	assert_true(int(res[1][F.LEFT]["dealt"]) > 0, "helo still firing in round 2")


# --- purity / independence ------------------------------------------------------------------

func test_forecast_never_changes_the_live_match() -> void:
	var make: Callable = func() -> MatchState:
		var hooks: MatchHooks = MatchHooks.new()
		hooks.mode_rules = ModeRules.create(DataEnums.GameMode.ZONE_CONTROL)
		var p: SideSetup = F.setup([F.breach_and_clear(), F.point_man(), F.combat_medic(), F.rifleman(), F.marksman(), F.anvil()], F.kestrel())
		var m: MatchState = F.new_match(p, F.setup([F.rifleman(), F.gunner(), F.breacher(), F.flanker(), F.rifleman()], F.kestrel()), F.map(), 77, hooks)
		F.grant(m, P, F.point_strike())
		_supply(m)
		F.place_operator(m, P, F.LEFT)
		F.place(m, E, F.gunner(), F.LEFT)
		F.place(m, E, F.rifleman(), F.MID)
		m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "point_man"), F.LEFT))
		m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "breach_and_clear"), F.MID))
		m.submit(P, RulesIntent.use_item(&"point_strike", F.LEFT))
		m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "breacher"), F.LEFT))
		m.submit(E, RulesIntent.place_operator(F.MID))
		return m
	var live: MatchState = make.call()
	var twin: MatchState = make.call()
	var before: String = _fingerprint(live)
	assert_eq(before, _fingerprint(twin), "twins start identical")
	for i: int in 3:
		OutcomeForecast.forecast(live, P)
	assert_eq(_fingerprint(live), before, "live state untouched by three forecasts")
	live.set_ready(P)
	live.set_ready(E)
	twin.set_ready(P)
	twin.set_ready(E)
	var a: Array = live.resolve_round()
	var b: Array = twin.resolve_round()
	assert_eq(var_to_str(a), var_to_str(b), "the round resolves exactly as in the twin that was never previewed")
	assert_eq(var_to_str(live.hooks.mode_rules.last_gain), var_to_str(twin.hooks.mode_rules.last_gain), "mode score untouched")


func test_clone_is_independent_and_keeps_rng_position() -> void:
	var m: MatchState = F.new_match(F.setup([F.rifleman(), F.rifleman(), F.rifleman()], F.kestrel()))
	var u: RulesUnit = F.place(m, E, F.gunner(), F.MID)
	u.add_mod(DataEnums.EffectKind.MODIFY_FIREPOWER, 1, 1)
	m.rng.randi()
	var c: MatchState = MatchClone.copy(m)
	assert_true(c != m and c.sides[E] != m.sides[E], "new state and sides")
	var cu: RulesUnit = c.sides[E].find_unit(u.uid)
	assert_true(cu != null and cu != u, "unit copied, same uid")
	assert_eq(c.rng.randi(), m.rng.randi(), "same RNG position")
	cu.armor = 1
	cu.mods.clear()
	c.sides[P].hand.clear()
	c.submit(E, RulesIntent.place_operator(F.LEFT))
	assert_eq(u.armor, 6, "original armor kept")
	assert_eq(u.mods.size(), 1, "original mods kept")
	assert_eq(m.sides[P].hand.size(), 3, "original hand kept")
	assert_eq(m.sides[E].plays.size(), 0, "original plays kept")
	assert_eq(c.config, m.config, "config shared (immutable)")


# --- fairness: only what the player sees -----------------------------------------------------

func test_enemy_plan_never_reaches_the_forecast() -> void:
	# The enemy queues a Breacher, its Operator and Breach and Clear on Mid, and has a hidden
	# Tripwire on the Left from an earlier round. The forecast must equal the one for the same
	# board without any of that, and report the red dots as unknown arrivals.
	var build: Callable = func(with_plan: bool) -> MatchState:
		var m: MatchState = F.new_match(F.setup([F.rifleman(), F.point_man(), F.combat_medic()], F.kestrel()),
				F.setup([F.breacher(), F.breach_and_clear(), F.tripwire()], F.kestrel()))
		_supply(m)
		F.place(m, E, F.rifleman(), F.MID)
		if with_plan:
			m.sides[E].equipment[F.LEFT].append({"card": RulesCard.new(m.new_uid(), F.tripwire()), "round": 0})
			m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "breacher"), F.MID))
			m.submit(E, RulesIntent.place_operator(F.MID))
			m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "breach_and_clear"), F.MID))
		m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "rifleman"), F.LEFT))
		m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "point_man"), F.MID))
		return m
	var with_plan: Dictionary = OutcomeForecast.forecast(build.call(true), P)
	var without: Dictionary = OutcomeForecast.forecast(build.call(false), P)
	for z: int in 3:
		for k: String in KEYS + ["control"]:
			assert_eq(with_plan["zones"][z][k], without["zones"][z][k], "zone %d %s ignores the hidden plan" % [z, k])
	assert_eq([with_plan["zones"][0]["unknown"], with_plan["zones"][1]["unknown"], with_plan["zones"][2]["unknown"]],
			[0, 2, 0], "Breacher + Operator show as 2 unknown arrivals on Mid")
	assert_eq(with_plan["zones"][F.LEFT]["taken"], 0, "the hidden Tripwire is not used")
	assert_eq(with_plan["zones"][F.MID]["revealed"], [] as Array[StringName], "no ids without intel")


func test_forecast_follows_plays_and_undo() -> void:
	var m: MatchState = F.new_match(F.setup([F.breacher(), F.rifleman()]))
	_supply(m)
	F.place(m, E, F.rifleman(), F.MID)
	var empty: Dictionary = OutcomeForecast.forecast(m, P)
	assert_eq(empty["zones"][F.MID]["control"], &"enemy", "enemy holds Mid with nothing played")
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "breacher"), F.MID))
	var played: Dictionary = OutcomeForecast.forecast(m, P)
	assert_eq([played["zones"][F.MID]["kills"], played["zones"][F.MID]["control"]], [1, &"player"], "Breacher takes Mid")
	m.undo_last(P)
	assert_eq(var_to_str(OutcomeForecast.forecast(m, P)), var_to_str(empty), "undo restores the preview")
	m.set_ready(P)
	assert_false(OutcomeForecast.forecast(m, P)["ok"], "no preview once READY")
