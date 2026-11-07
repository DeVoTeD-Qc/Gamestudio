# test_run_flow.gd
# Purpose: p10 run flow (core-rules §3, §9, Rulings 1, 2, 11, 12; content-log gap 7):
#   a 5-match run from RunConfig, tickets and the draw rule, Supply Drop / weapon level /
#   Perk offers at the right matches, enemy bonuses, building both SideSetups, a
#   deterministic seed, save -> reload -> continue, corrupt saves, the RunState
#   autoload, and full runs played with real MatchStates and a simple policy.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Sim = preload("res://tests/mode_sim.gd")
const TEST_SAVE: String = "user://test_run_save.json"
const SEED: int = 4242

const SUPPLY: StringName = RewardOffers.KIND_SUPPLY_DROP
const ATTACH: StringName = RewardOffers.KIND_ATTACHMENT
const PERK: StringName = RewardOffers.KIND_PERK


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


## The offer schedule these tests pin is the classic one (Supply Drop / weapon level / Perk). The
## shipped config also queues the kc-syn offers (synergy_offers, kc-syn-ui); they are covered by
## test_shipped_schedule_adds_the_synergy_offers and test_run_synergy.gd.
func _classic_config() -> RunConfig:
	var cfg: RunConfig = _config().duplicate() as RunConfig
	cfg.synergy_offers = false
	# kc-onboard: the ladder's extra offers (2 picks of 4, Muster out, Salvage) are covered by
	# test_shipped_schedule_adds_the_synergy_offers and test_onboarding.gd.
	cfg.multi_pick_from_match = 0
	cfg.muster_out_from_match = 0
	cfg.salvage_after_loss = false
	return cfg


func _new_run(seed_value: int = SEED) -> RunProgress:
	var r: RunProgress = RunProgress.create(_classic_config(), seed_value)
	r.begin()
	return r


## kc-syn-ui / kc-onboard: with the shipped run_config.tres the drop after match 2 is 2 picks of 4
## followed by Muster out (kc-no-training: no Promotion), a loss gives Salvage (+ Muster out
## from match 2), and the Doctrine comes from the first calling card (no Doctrine offer).
func test_shipped_schedule_adds_the_synergy_offers() -> void:
	var r: RunProgress = RunProgress.create(_config(), SEED)
	r.begin()
	assert_true(r.config.synergy_offers, "synergy offers are on in run_config.tres")
	assert_eq(_play_forced(r, &"player"), [SUPPLY, ATTACH] as Array[StringName], "after match 1")
	assert_true(r.doctrine != &"", "the first calling card set the Doctrine")
	assert_eq(_play_forced(r, &"player"), [SUPPLY, SUPPLY, RewardOffers.KIND_MUSTER_OUT, PERK] as Array[StringName], "after match 2 (pick 2)")
	assert_eq(_play_forced(r, &"enemy"), [RewardOffers.KIND_SALVAGE, RewardOffers.KIND_MUSTER_OUT, ATTACH] as Array[StringName], "after a loss (match 3)")


## Records `match_result` and takes option 0 of every offer. Returns the offer kinds seen.
func _play_forced(r: RunProgress, match_result: StringName) -> Array[StringName]:
	var kinds: Array[StringName] = []
	var summary: Dictionary = r.record_result(match_result)
	assert_true(summary["ok"], "record_result failed: %s" % summary.get("reason", ""))
	while not r.current_offer().is_empty():
		kinds.append(r.current_offer()["kind"])
		assert_eq(r.choose_offer(0), "", "choose_offer")
	return kinds


## Plays the current match with real rules and the greedy policy on both sides.
func _play_real(r: RunProgress) -> MatchState:
	var m: MatchState = r.create_match()
	m.start_match()
	Sim.play_out(m, 12)
	return m


func _json(r: RunProgress) -> String:
	var d: Dictionary = r.to_dict()
	d.erase("play_time_s")
	return JSON.stringify(d)


# --- Run from RunConfig ----------------------------------------------------------------

func test_new_run_reads_everything_from_run_config() -> void:
	var cfg: RunConfig = _config()
	var r: RunProgress = RunProgress.create(cfg, SEED)
	assert_eq(r.phase, RunProgress.PHASE_LOADOUT, "starts in the loadout phase")
	assert_eq(r.match_count(), 5, "5 matches")
	assert_eq(r.tickets, cfg.tickets, "tickets from config")
	assert_eq(r.tickets, 3, "3 tickets")
	assert_eq(r.deck.size(), 20, "starter deck")
	assert_eq(r.primary, &"kestrel_ar7", "starter primary")
	for gone: String in ["secondary", "lethal", "tactical"]:
		assert_false(gone in r, "kc-loadout-cut: no %s slot" % gone)
	assert_eq(r.killstreaks, [&"recon_drone", &"mortar_barrage", &"attack_helo"] as Array[StringName], "starter killstreaks")
	assert_true(r.perks.is_empty() and r.attachments.is_empty(), "no perks / attachments at start")
	var brackets: Array = []
	for md: RunMatchData in cfg.matches:
		brackets.append(md.bracket)
	assert_eq(brackets, [1, 1, 2, 2, 2], "Bracket 1 x2, Bracket 2 x2, Rival")
	assert_true(cfg.matches[4].is_rival, "match 5 is the Rival")


func test_killstreak_pick_rules() -> void:
	var r: RunProgress = RunProgress.create(_config(), SEED)
	assert_eq(r.set_killstreaks([&"sentry_turret", &"mortar_barrage", &"attack_helo"]), "", "valid pick")
	assert_eq(r.killstreaks[0], &"sentry_turret", "pick stored")
	assert_true(r.set_killstreaks([&"sentry_turret", &"mortar_barrage"]) != "", "needs exactly 3")
	assert_true(r.set_killstreaks([&"sentry_turret", &"sentry_turret", &"attack_helo"]) != "", "no duplicates")
	assert_true(r.set_killstreaks([&"grit", &"mortar_barrage", &"attack_helo"]) != "", "only killstreak pool")
	assert_eq(r.begin(), "", "begin")
	assert_true(r.set_killstreaks([&"recon_drone", &"mortar_barrage", &"attack_helo"]) != "", "locked after begin")
	assert_eq(r.player_setup().killstreaks.size(), 3, "picks go into the match")


# --- Win / lose end to end (forced results) ------------------------------------------------

func test_forced_winning_run_gets_all_offers_at_the_right_matches() -> void:
	var r: RunProgress = _new_run()
	assert_eq(_play_forced(r, &"player"), [SUPPLY, ATTACH] as Array[StringName], "after match 1")
	assert_eq(_play_forced(r, &"player"), [SUPPLY, PERK] as Array[StringName], "after match 2")
	assert_eq(_play_forced(r, &"player"), [SUPPLY, ATTACH] as Array[StringName], "after match 3")
	assert_eq(_play_forced(r, &"player"), [SUPPLY, ATTACH, PERK] as Array[StringName], "after match 4")
	assert_true(r.is_rival_match(), "match 5 is the Rival")
	assert_eq(_play_forced(r, &"player"), [] as Array[StringName], "no offers after the Rival")
	assert_true(r.is_over(), "run over")
	assert_eq(r.result, RunProgress.RESULT_VICTORY, "victory")
	assert_eq(r.end_reason, RunProgress.END_RIVAL_WON, "reason")
	assert_eq(r.tickets, 3, "no tickets lost")
	assert_eq(r.deck.size(), 24, "4 Supply Drop cards")
	assert_eq(r.attachments.size(), 3, "3 weapon levels")
	assert_eq(r.weapon_level, 3, "weapon level")
	assert_eq(r.perks.size(), 2, "2 perks")
	assert_eq(r.matches_played(), 5, "5 matches")
	assert_true(r.record_result(&"player")["ok"] == false, "no result after the run ended")


func test_forced_losing_run_ends_at_zero_tickets() -> void:
	var r: RunProgress = _new_run()
	assert_eq(_play_forced(r, &"enemy"), [ATTACH] as Array[StringName], "loss: no Supply Drop, weapon still levels")
	assert_eq(r.tickets, 2, "lost a ticket")
	assert_eq(r.match_index, 1, "the run goes on to match 2")
	assert_eq(_play_forced(r, &"enemy"), [PERK] as Array[StringName], "loss after match 2: perk offer only")
	assert_eq(r.tickets, 1, "1 ticket left")
	assert_eq(_play_forced(r, &"enemy"), [] as Array[StringName], "out of tickets: no offers")
	assert_eq(r.tickets, 0, "0 tickets")
	assert_true(r.is_over(), "run over")
	assert_eq(r.result, RunProgress.RESULT_DEFEAT, "defeat")
	assert_eq(r.end_reason, RunProgress.END_NO_TICKETS, "reason")
	assert_eq(r.matches_played(), 3, "ended after match 3")
	assert_eq(r.deck.size(), 20, "no cards gained")
	assert_true(r.create_match() == null, "no match after the end")


func test_draw_costs_no_ticket_and_gives_no_supply_drop() -> void:
	var r: RunProgress = _new_run()
	assert_eq(_play_forced(r, &"draw"), [ATTACH] as Array[StringName], "draw: no Supply Drop")
	assert_eq(r.tickets, 3, "draw keeps the ticket")
	assert_eq(r.match_index, 1, "draw goes on to the next match")
	assert_eq(_play_forced(r, &"draw"), [PERK] as Array[StringName], "draw after match 2")
	assert_eq(r.count_results(&"draw"), 2, "history counts draws")
	assert_false(r.history[0]["ticket_lost"], "history: no ticket lost")


func test_mixed_run_can_still_win_the_rival_with_tickets_left() -> void:
	var r: RunProgress = _new_run()
	for res: StringName in [&"enemy", &"player", &"draw", &"enemy"]:
		_play_forced(r, res)
	assert_eq(r.tickets, 1, "two losses")
	assert_false(r.is_over(), "still going")
	_play_forced(r, &"player")
	assert_eq(r.result, RunProgress.RESULT_VICTORY, "won the Rival")


func test_rival_loss_or_draw_ends_the_run_as_defeat() -> void:
	for pair: Array in [[&"enemy", RunProgress.END_RIVAL_LOST, 2], [&"draw", RunProgress.END_RIVAL_DRAW, 3]]:
		var r: RunProgress = _new_run()
		for i: int in 4:
			_play_forced(r, &"player")
		_play_forced(r, pair[0])
		assert_true(r.is_over(), "run ends after the Rival (%s)" % pair[0])
		assert_eq(r.result, RunProgress.RESULT_DEFEAT, "defeat (%s)" % pair[0])
		assert_eq(r.end_reason, pair[1], "reason (%s)" % pair[0])
		assert_eq(r.tickets, pair[2], "tickets (%s)" % pair[0])


func test_offers_must_be_resolved_before_the_next_match() -> void:
	var r: RunProgress = _new_run()
	r.record_result(&"player")
	assert_eq(r.phase, RunProgress.PHASE_REWARDS, "rewards phase")
	assert_true(r.create_match() == null, "no match while offers are pending")
	assert_false(r.record_result(&"player")["ok"], "no result while offers are pending")
	assert_true(r.choose_offer(7) != "", "bad index")
	assert_eq(r.skip_offer(), "", "skip the Supply Drop")
	assert_eq(r.deck.size(), 20, "skipping adds nothing")
	assert_eq(r.current_offer()["kind"], ATTACH, "weapon level next")
	assert_eq(r.choose_offer(1), "", "take option 1")
	assert_eq(r.phase, RunProgress.PHASE_MATCH, "back to the match phase")
	assert_eq(r.match_number(), 2, "match 2 next")


# --- Offers ------------------------------------------------------------------------------

func test_supply_drop_offers_three_different_designs_weighted_by_copies() -> void:
	var cfg: RunConfig = _config()
	var pool: Dictionary = {}
	for c: CardData in cfg.reward_pool:
		pool[c.id] = int(pool.get(c.id, 0)) + 1
	var seen: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var all_ok: bool = true
	for i: int in 3000:
		rng.seed = i
		var opts: Array[StringName] = RewardOffers.supply_drop(cfg, rng)
		var distinct: Dictionary = {}
		for id: StringName in opts:
			distinct[id] = true
			seen[id] = int(seen.get(id, 0)) + 1
			if not pool.has(id):
				all_ok = false
		if opts.size() != 3 or distinct.size() != 3:
			all_ok = false
	assert_true(all_ok, "every offer = 3 different designs from the reward pool")
	assert_eq(seen.size(), pool.size(), "every design in the pool shows up")
	# Two-copy designs (Flanker) should appear clearly more often than one-copy ones (Anvil).
	assert_true(int(seen[&"flanker"]) > int(seen[&"okafor_anvil"]) * 1.4,
			"weights: flanker %d vs anvil %d" % [seen[&"flanker"], seen[&"okafor_anvil"]])
	assert_false(seen.has(&"rifleman"), "Rifleman is not in the reward pool")


func test_weighted_distinct_handles_small_pools() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var ids: Array[StringName] = [&"a", &"a", &"b"]
	var picks: Array[StringName] = RewardOffers.weighted_distinct(ids, 3, rng)
	assert_eq(picks.size(), 2, "only 2 designs")
	assert_true(&"a" in picks and &"b" in picks, "both designs")
	assert_eq(RewardOffers.weighted_distinct([] as Array[StringName], 3, rng).size(), 0, "empty pool")


func test_weapon_levels_offer_unowned_attachments() -> void:
	var r: RunProgress = _new_run()
	var owned: Array[StringName] = []
	for n: int in 4:
		r.record_result(&"draw")
		var offer: Dictionary = r.current_offer()
		if n + 1 in [1, 3, 4]:
			assert_eq(offer["kind"], ATTACH, "weapon level after match %d" % (n + 1))
			assert_eq(offer["options"].size(), 2, "2 choices after match %d" % (n + 1))
			for id: StringName in offer["options"]:
				assert_false(id in owned, "%s already owned" % id)
				assert_true(r.resource(id) is LoadoutItem and r.resource(id).slot == DataEnums.LoadoutSlot.ATTACHMENT, "%s is an attachment" % id)
			owned.append(offer["options"][0])
			r.choose_offer(0)
		while not r.current_offer().is_empty():
			assert_true(r.current_offer()["kind"] != ATTACH, "only one weapon level per match")
			r.skip_offer()
	assert_eq(r.attachments, owned, "attachments owned")


func test_perk_offers_after_matches_2_and_4_show_two_unowned() -> void:
	var r: RunProgress = _new_run()
	var perk_matches: Array[int] = []
	for n: int in 4:
		r.record_result(&"draw")
		while not r.current_offer().is_empty():
			var offer: Dictionary = r.current_offer()
			if offer["kind"] == PERK:
				perk_matches.append(n + 1)
				assert_eq(offer["options"].size(), 2, "2 perks")
				for id: StringName in offer["options"]:
					assert_false(id in r.perks, "unowned perk")
					assert_true(r.resource(id) in r.config.perk_pool, "from the perk pool")
				r.choose_offer(1)
			else:
				r.skip_offer()
	assert_eq(perk_matches, [2, 4] as Array[int], "perk offers after 2 and 4")
	assert_eq(r.perks.size(), 2, "2 perks owned")
	var s: SideSetup = r.player_setup()
	assert_eq(s.perks.size(), 2, "owned perks go into the match")


func test_attachment_pool_exhausted_gives_no_offer() -> void:
	var cfg: RunConfig = _config()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var all: Array[StringName] = []
	for att: LoadoutItem in cfg.starter_primary.attachments:
		all.append(att.id)
	assert_eq(RewardOffers.attachments(cfg, cfg.starter_primary, all, rng).size(), 0, "nothing left")
	var full: Array[StringName] = [&"grit", &"field_salvage", &"objective_focus"]
	assert_eq(RewardOffers.perks(cfg, full, rng).size(), 0, "perk slots full")


# --- Building the match --------------------------------------------------------------------

func test_player_setup_carries_deck_loadout_and_rewards() -> void:
	var r: RunProgress = _new_run()
	_play_forced(r, &"player")  # Supply Drop + attachment
	var s: SideSetup = r.player_setup()
	assert_eq(s.deck.size(), 21, "deck + Supply Drop card")
	assert_eq(s.deck[20].id, r.deck[20], "reward card last")
	assert_eq(s.primary.id, &"kestrel_ar7", "primary")
	assert_eq(s.attachments.size(), 1, "attachment")
	assert_eq(s.attachments[0].id, r.attachments[0], "attachment id")
	assert_false("lethal" in s, "kc-loadout-cut: no Secondary / Lethal / Tactical in the side setup")
	assert_eq(s.firepower_bonus + s.armor_bonus, 0, "no bonus for the player")
	var m: MatchState = r.create_match()
	m.start_match()
	var op: RulesUnit = m.sides[0].operator_unit
	var att: LoadoutItem = s.attachments[0]
	assert_eq(op.base_max_armor, 7 + att.armor_bonus, "Operator armor includes the attachment")
	assert_eq(op.base_firepower, 3 + att.firepower_bonus, "Operator firepower includes the attachment")


func test_enemy_bonuses_by_bracket() -> void:
	var r: RunProgress = _new_run()
	# kc-fight-impl: match 3 (Rusher+) Armor bonus 1 -> 0; kc-onboard N4: match 1 "green squad" -1,
	# match 4 (Anchor+) 1 -> 0.
	var expect: Array[int] = [-1, 0, 0, 0, 1]
	for i: int in 5:
		var md: RunMatchData = r.current_match()
		var e: SideSetup = r.enemy_setup()
		assert_eq(e.display_name, md.squad.display_name, "squad %d" % (i + 1))
		assert_eq(e.armor_bonus, expect[i], "enemy armor bonus match %d" % (i + 1))
		assert_eq(e.firepower_bonus, 0, "enemy firepower bonus match %d" % (i + 1))
		var m: MatchState = r.create_match()
		assert_eq(m.hooks.mode_rules.mode, md.mode, "mode from the slot, match %d" % (i + 1))
		m.start_match()
		var op: RulesUnit = m.sides[1].operator_unit
		var base_ar: int = md.squad.primary.operator_armor
		for att: LoadoutItem in md.squad.attachments:
			base_ar += att.armor_bonus
		assert_eq(op.base_max_armor, base_ar + expect[i], "enemy Operator armor, match %d" % (i + 1))
		var card: CardData = md.squad.deck[0]
		var u: RulesUnit = m.create_unit(1, card)
		assert_eq(u.base_max_armor, card.armor + expect[i], "enemy unit armor, match %d" % (i + 1))
		var pu: RulesUnit = m.create_unit(0, card)
		assert_eq(pu.base_max_armor, card.armor, "player unit unchanged, match %d" % (i + 1))
		_play_forced(r, &"draw")


func test_seed_is_deterministic() -> void:
	var a: RunProgress = _new_run(77)
	var b: RunProgress = _new_run(77)
	var c: RunProgress = _new_run(78)
	assert_eq(a.match_seed(), b.match_seed(), "same match seed")
	assert_true(a.match_seed() != c.match_seed(), "different run seed -> different match seed")
	a.record_result(&"player")
	b.record_result(&"player")
	assert_eq(a.current_offer(), b.current_offer(), "same Supply Drop")
	var ma: MatchState = null
	var mb: MatchState = null
	a.skip_offer(); a.skip_offer()
	b.skip_offer(); b.skip_offer()
	ma = _play_real(a)
	mb = _play_real(b)
	assert_eq(ma.result, mb.result, "same match result")
	assert_eq(ma.events.size(), mb.events.size(), "same match events")
	assert_true(a.match_seed() != RunProgress.derive_seed(77, "match", 1), "each match has its own seed")


# --- Save / load -------------------------------------------------------------------------

func test_save_reload_continue_produces_the_same_state() -> void:
	var cfg: RunConfig = _classic_config()
	var r: RunProgress = _new_run(9001)
	_play_forced(r, &"player")
	r.record_result(&"enemy")  # leaves the Perk offer pending
	assert_eq(r.phase, RunProgress.PHASE_REWARDS, "saved mid-rewards")
	assert_eq(RunSave.write(TEST_SAVE, r), OK, "write")
	var loaded: Dictionary = RunSave.read(TEST_SAVE, cfg)
	assert_eq(loaded["error"], "", "read error")
	var r2: RunProgress = loaded["run"]
	assert_not_null(r2, "loaded")
	if r2 == null:
		return
	assert_eq(_json(r2), _json(r), "same state after reload")
	assert_eq(r2.current_offer(), r.current_offer(), "same pending offer")
	assert_eq(r2.match_seed(), r.match_seed(), "same match seed")
	# Continue both identically, with real matches, to the end of the run.
	for run: RunProgress in [r, r2]:
		while not run.is_over():
			while not run.current_offer().is_empty():
				run.choose_offer(0)
			if run.is_over():
				break
			run.record_match(_play_real(run))
			while not run.current_offer().is_empty():
				run.choose_offer(0)
	assert_eq(_json(r2), _json(r), "same state after continuing")
	assert_true(r.is_over(), "run finished")
	RunSave.delete(TEST_SAVE)


func test_save_round_trips_every_phase() -> void:
	var cfg: RunConfig = _config()
	var r: RunProgress = RunProgress.create(cfg, 1 << 40)  # large seed survives JSON
	for step: StringName in [&"", &"begin", &"player", &"pick", &"enemy", &"enemy", &"enemy"]:
		match step:
			&"begin":
				r.begin()
			&"pick":
				while not r.current_offer().is_empty():
					r.choose_offer(0)
			&"player", &"enemy":
				if r.phase == RunProgress.PHASE_REWARDS:
					while not r.current_offer().is_empty():
						r.skip_offer()
				r.record_result(step)
		var back: Dictionary = RunProgress.from_dict(cfg, JSON.parse_string(JSON.stringify(r.to_dict())))
		assert_eq(back["error"], "", "phase %s loads" % r.phase)
		if back["run"] != null:
			assert_eq(_json(back["run"]), _json(r), "phase %s round trip" % r.phase)
	assert_eq(r.phase, RunProgress.PHASE_ENDED, "ended")
	assert_eq(r.seed_value, 1 << 40, "seed kept")


func test_bad_saves_are_rejected() -> void:
	var cfg: RunConfig = _config()
	var good: Dictionary = _new_run().to_dict()
	var cases: Dictionary = {
		"not an object": [1, 2],
		"no version": _without(good, "version"),
		"future version": _with(good, "version", 99),
		"other config": _with(good, "config_id", "run_other"),
		"unknown card": _with(good, "deck", ["rifleman", "no_such_card"]),
		"bad phase": _with(good, "phase", "lunch"),
		"bad seed": _with(good, "seed", "abc"),
		"too many tickets": _with(good, "tickets", 9),
		"rewards phase without offers": _with(good, "phase", "rewards"),
	}
	for label: String in cases:
		var res: Dictionary = RunProgress.from_dict(cfg, cases[label])
		assert_true(res["run"] == null and res["error"] != "", "%s is rejected" % label)
	assert_eq(RunProgress.from_dict(cfg, good)["error"], "", "the good save loads")


## kc-loadout-cut: a v4 save still carries loadout.secondary / lethal / tactical (Sidearm, Frag
## Grenade, Flashbang); it loads with those fields dropped, and the next save is v5 without them.
func test_v4_save_with_the_removed_loadout_slots_loads() -> void:
	var cfg: RunConfig = _config()
	var r: RunProgress = _new_run()
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_eq(int(d["version"]), RunProgress.SAVE_VERSION, "saves are the current version (v6 since kc-no-training)")
	assert_false((d["loadout"] as Dictionary).has("lethal"), "no lethal field any more")
	var old: Dictionary = d.duplicate(true)
	old["version"] = 4
	old["loadout"]["secondary"] = "p12_sidearm"
	old["loadout"]["lethal"] = "frag_grenade"
	old["loadout"]["tactical"] = "flashbang"
	var back: Dictionary = RunProgress.from_dict(cfg, old)
	assert_eq(back["error"], "", "the v4 save loads")
	if back["run"] != null:
		var again: Dictionary = (back["run"] as RunProgress).to_dict()
		assert_eq(int(again["version"]), RunProgress.SAVE_VERSION, "saved again as the current version")
		assert_eq((again["loadout"] as Dictionary).keys(), ["primary", "attachments", "perks", "killstreaks"],
				"the removed slots are dropped")
		assert_eq(String(again["loadout"]["primary"]), String(r.primary), "the Operator is kept")
	var bad: Dictionary = old.duplicate(true)
	bad["loadout"]["primary"] = "frag_grenade"
	assert_true(RunProgress.from_dict(cfg, bad)["run"] == null, "an unknown primary is still rejected")


func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c[key] = value
	return c


func _without(d: Dictionary, key: String) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c.erase(key)
	return c


# --- RunState autoload -------------------------------------------------------------------

func _run_state() -> Node:
	return tree.root.get_node("RunState")


func test_run_state_flow_saves_and_continues() -> void:
	var rs: Node = _run_state()
	var old_path: String = rs.save_path
	rs.save_path = TEST_SAVE
	RunSave.delete(TEST_SAVE)
	var bus: Node = tree.root.get_node("EventBus")
	var seen: Array = []
	var on_tickets: Callable = func(t: int) -> void: seen.append(["tickets", t])
	var on_offer: Callable = func(kind: StringName, ids: Array[StringName]) -> void: seen.append(["offer", kind, ids.size()])
	var on_end: Callable = func(res: StringName, n: int, _d: float) -> void: seen.append(["end", res, n])
	bus.tickets_changed.connect(on_tickets)
	bus.reward_offered.connect(on_offer)
	bus.run_ended.connect(on_end)

	rs.start_run(555)
	assert_true(rs.has_save(), "saved on start")
	assert_eq(rs.tickets, 3, "tickets")
	assert_eq(rs.matches_total, 5, "matches")
	assert_eq(rs.set_killstreaks([&"recon_drone", &"sentry_turret", &"attack_helo"]), "", "killstreaks")
	assert_eq(rs.begin_run(), "", "begin")
	var m: MatchState = rs.create_match()
	assert_not_null(m, "match built")
	rs.record_result(&"enemy")
	assert_eq(rs.tickets, 2, "ticket lost")
	# kc-onboard: the shipped schedule puts Salvage (replacing Regroup) before the weapon level.
	assert_eq(rs.current_offer()["kind"], RewardOffers.KIND_SALVAGE, "Salvage after a loss")
	while not rs.current_offer().is_empty() and rs.current_offer()["kind"] != ATTACH:
		rs.skip_offer()
	assert_eq(rs.current_offer()["kind"], ATTACH, "weapon level offer")
	var before: String = _json(rs.run)
	rs.reset()
	assert_false(rs.active, "cleared")
	assert_true(rs.continue_run(), "continue")
	assert_eq(_json(rs.run), before, "same run after continue")
	assert_eq(rs.run.killstreaks[1], &"sentry_turret", "killstreak pick kept")
	assert_eq(rs.choose_offer(0), "", "pick attachment")
	for res: StringName in [&"enemy", &"enemy"]:
		while not rs.current_offer().is_empty():
			rs.skip_offer()
		rs.record_result(res)
	assert_false(rs.active, "run over")
	assert_true(rs.run.is_over(), "ended")
	assert_true(["tickets", 0] in seen, "tickets_changed to 0")
	assert_true(["offer", ATTACH, 2] in seen, "reward_offered")
	assert_true(["end", &"loss", 3] in seen, "run_ended loss after 3 matches")

	bus.tickets_changed.disconnect(on_tickets)
	bus.reward_offered.disconnect(on_offer)
	bus.run_ended.disconnect(on_end)
	rs.abandon_run()
	assert_false(rs.has_save(), "abandon deletes the save")
	rs.save_path = old_path


func test_corrupt_save_starts_fresh_with_a_warning() -> void:
	var rs: Node = _run_state()
	var old_path: String = rs.save_path
	rs.save_path = TEST_SAVE
	for text: String in ["{not json", "{\"version\": 1, \"deck\": 5}", ""]:
		var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		assert_false(rs.continue_run(), "corrupt save '%s' does not load" % text)
		assert_true(rs.last_load_warning != "", "warning for '%s'" % text)
		assert_true(rs.run == null, "no run")
		assert_false(rs.has_save(), "corrupt save moved aside")
		assert_true(FileAccess.file_exists(TEST_SAVE + RunSave.CORRUPT_SUFFIX), "kept as .corrupt")
	assert_eq(rs.tickets, 3, "defaults from config without a run")
	rs.start_run(1)
	assert_eq(rs.last_load_warning, "", "fresh run clears the warning")
	rs.abandon_run()
	RunSave.delete(TEST_SAVE + RunSave.CORRUPT_SUFFIX)
	assert_false(rs.continue_run(), "no save: nothing to continue")
	assert_eq(rs.last_load_warning, "", "a missing save is not a warning")
	rs.save_path = old_path


# --- Full runs with real matches ------------------------------------------------------------

func test_full_runs_with_real_matches_and_a_simple_policy() -> void:
	var outcomes: Dictionary = {}
	var results: Dictionary = {}
	for seed_value: int in [1, 2, 3, 4, 5, 6]:
		var r: RunProgress = _new_run(seed_value)
		var guard: int = 0
		while not r.is_over() and guard < 10:
			guard += 1
			var m: MatchState = _play_real(r)
			assert_eq(m.phase, MatchState.Phase.ENDED, "match ended (seed %d, match %d)" % [seed_value, r.match_number()])
			var tickets_before: int = r.tickets
			r.record_match(m)
			var h: Dictionary = r.history.back()
			results[h["result"]] = int(results.get(h["result"], 0)) + 1
			assert_eq(h["result"], String(m.result), "history keeps the result")
			assert_eq(h["rounds"], m.round_number, "history keeps the rounds")
			assert_eq(r.tickets, tickets_before - (1 if m.result == &"enemy" else 0), "ticket rule")
			while not r.current_offer().is_empty():
				r.choose_offer(0)
		assert_true(r.is_over(), "run %d finished" % seed_value)
		assert_true(r.matches_played() >= 3 and r.matches_played() <= 5, "3-5 matches")
		assert_true(r.result == RunProgress.RESULT_VICTORY or r.result == RunProgress.RESULT_DEFEAT, "result")
		if r.result == RunProgress.RESULT_VICTORY:
			assert_eq(r.matches_played(), 5, "a victory plays all 5")
		var key: String = "%s/%s" % [r.result, r.end_reason]
		outcomes[key] = int(outcomes.get(key, 0)) + 1
	print("     run outcomes: %s, match results: %s" % [outcomes, results])


## Real matches decide whole runs both ways. With the greedy policy on both sides the
## player wins about 1 run in 20 (balance data for p19), so this scans seeds from 30
## (seed 33 wins with the current data) until it has seen a victory and a defeat.
func test_real_matches_can_win_and_lose_a_run() -> void:
	var victory: int = -1
	var defeat: int = -1
	for seed_value: int in range(30, 180):
		var r: RunProgress = _new_run(seed_value)
		while not r.is_over():
			r.record_match(_play_real(r))
			while not r.current_offer().is_empty():
				r.choose_offer(0)
		if r.is_victory() and victory < 0:
			victory = seed_value
			assert_eq(r.matches_played(), 5, "victory after the Rival")
			assert_true(r.history.back()["rival"] and r.history.back()["result"] == "player", "won the Rival")
			assert_eq(r.deck.size(), 20 + r.count_results(&"player") - 1, "a Supply Drop card per win before the Rival")
		elif not r.is_victory() and defeat < 0:
			defeat = seed_value
		if victory >= 0 and defeat >= 0:
			break
	assert_true(victory >= 0, "some seed wins a run with real matches")
	assert_true(defeat >= 0, "some seed loses a run with real matches")
	print("     real-match run: victory with seed %d, defeat with seed %d" % [victory, defeat])
