# test_collection.gd
# Purpose: cc09 Collection: demo start, every unlock goal kind driven through EventBus with its
#   count read from data/unlocks, the Long Watch split (first Legend-free Warden win unlocks City
#   Never Sleeps only, the second unlocks Long Watch), Dossier rewards, the Cipher Lock (code from
#   balance.tres), Triptychs, set completion, the saved lineup, and the binding rule that rewards
#   are cosmetic or ownership only: no unlock changes a card's stats or the rules.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_collection_fixtures.gd")


func _goal(id: StringName) -> UnlockGoal:
	return tree.root.get_node("CardDB").get_unlock_goal(id)


func test_demo_start() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("start")
	var db: Node = fx.db()
	assert_eq(c.load_status, c.STATUS_NEW, "no save -> demo start")
	assert_eq(c.card_totals(), {"owned": db.starting_cards().size(), "total": db.card_count()}, "owned / total")
	for card: CardData in db.all_cards():
		assert_eq(c.owns(card.id), card.starts_owned, "%s owned at start" % card.id)
	assert_true(c.titles().is_empty(), "no titles")
	assert_true(c.frames().is_empty(), "no frames")
	assert_false(c.is_set_complete(&"showcase"), "Showcase is never a completion set")
	assert_eq(c.goal_progress(&"unlock_win_streak_3"), {"current": 0, "target": _goal(&"unlock_win_streak_3").target_count, "done": false}, "streak 0/N")
	assert_false(c.has_saved_lineup(), "no lineup")
	assert_false(c.has_saved_lobby_duel(), "no Lobby Duel")
	fx.finish()


func test_long_watch_needs_second_legend_free_warden_win() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("long_watch")
	var goal: UnlockGoal = _goal(&"unlock_beat_warden_no_legend")
	assert_eq(goal.required_count(), 2, "data: Long Watch needs 2 Legend-free Warden wins")
	assert_eq(c.goal_for_card(&"long_watch"), goal, "Long Watch's goal")
	# First Warden win, loaner lineup (no Legend): City Never Sleeps only.
	fx.play(&"win", &"warden")
	assert_true(c.owns(&"city_never_sleeps"), "1st win: City Never Sleeps")
	assert_false(c.owns(&"long_watch"), "1st win: not Long Watch yet")
	assert_eq(fx.unlocked_cards(), [&"city_never_sleeps"], "1st win unlocks exactly one card")
	assert_eq(c.goal_progress(goal.id), {"current": 1, "target": 2, "done": false}, "1/2")
	assert_true(fx.events_named("unlock_progress").has(["unlock_progress", goal.id, 1, 2]), "progress 1/2 announced")
	# Wins that don't count: a lineup with a Legend, an unknown lineup, another rival, a loss.
	fx.play(&"win", &"warden", fx.legend_lineup_ids())
	fx.bus().duel_started.emit(&"rival", &"warden", &"player")
	fx.end_duel(&"win")
	fx.play(&"win", &"archivist")
	fx.play(&"loss", &"warden")
	assert_false(c.owns(&"long_watch"), "Legend lineup / unknown lineup / other rival / loss don't count")
	assert_eq(c.stats()["rival_wins"]["warden"], 3, "3 Warden wins in total")
	assert_eq(c.stats()["rival_wins_no_legend"]["warden"], 1, "1 Legend-free")
	# Second Legend-free win (not in a row: losses in between are fine): Long Watch.
	fx.play(&"win", &"warden")
	assert_true(c.owns(&"long_watch"), "2nd Legend-free win: Long Watch")
	var warden_cards: Array = fx.unlocked_cards().filter(func(id: StringName) -> bool:
		return id in [&"city_never_sleeps", &"long_watch"])
	assert_eq(warden_cards, [&"city_never_sleeps", &"long_watch"], "unlock order (other goals aside)")
	assert_true(c.goal_progress(goal.id)["done"], "goal done")
	fx.finish()


func test_count_goals_read_targets_from_data() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("counts")
	var streak: int = _goal(&"unlock_win_streak_3").target_count
	var wins: int = _goal(&"unlock_wins_5").target_count
	var caps: int = _goal(&"unlock_captures_20").target_count
	# Streak: a loss or draw resets it.
	for i: int in streak - 1:
		fx.play(&"win")
	fx.play(&"draw")
	assert_eq(c.goal_progress(&"unlock_win_streak_3")["current"], 0, "draw resets the streak")
	for i: int in streak - 1:
		fx.play(&"win")
	assert_false(c.owns(&"polar_night"), "streak not reached yet")
	fx.play(&"win")
	assert_true(c.owns(&"polar_night"), "win streak -> Polar Night")
	assert_eq(c.stats()["best_streak"], streak, "best streak")
	# Wins in total (a separate collection; alternating so no streak builds up).
	var w: Node = fx.make("counts_wins")
	for i: int in wins - 1:
		fx.play(&"win")
		fx.play(&"loss")
	assert_false(w.owns(&"honor_roll"), "one win short")
	assert_eq(w.goal_progress(&"unlock_wins_5"), {"current": wins - 1, "target": wins, "done": false}, "wins progress")
	fx.play(&"win")
	assert_true(w.owns(&"honor_roll"), "wins total -> Honor Roll")
	fx.drop(w)
	# Captures: only the player's, not in Dossiers.
	fx.start_duel(&"rival", &"archivist", fx.loaner_ids())
	for i: int in caps - 1:
		fx.bus().card_captured.emit(&"player", &"mayday", &"b2")
	fx.bus().card_captured.emit(&"rival", &"mayday", &"b2")
	fx.end_duel(&"loss")
	fx.start_duel(&"dossier", &"", [])
	fx.bus().card_captured.emit(&"player", &"mayday", &"b2")
	fx.end_duel(&"win")
	assert_eq(c.stats()["captures"], caps - 1, "rival and Dossier captures don't count")
	assert_false(c.owns(&"dead_air"), "one capture short")
	fx.play(&"loss", &"archivist", [], 1)
	assert_true(c.owns(&"dead_air"), "captures total -> Dead Air")
	assert_eq(c.stats()["duels"], c.stats()["wins"] + c.stats()["losses"] + c.stats()["draws"], "Dossier duel not counted")
	fx.finish()


func test_dossier_rewards() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("dossiers")
	fx.bus().dossier_cleared.emit(&"dossier_carded", 3, 95.0)
	assert_true(c.owns(&"null_glyph"), "D4 -> Null Glyph")
	assert_true(c.is_goal_done(&"unlock_dossier_carded"), "D4 goal done")
	assert_eq(c.dossier_record(&"dossier_carded"), {"attempts": 3, "best_s": 95.0}, "record")
	fx.bus().dossier_cleared.emit(&"dossier_carded", 1, 40.0)
	assert_eq(c.dossier_record(&"dossier_carded"), {"attempts": 3, "best_s": 40.0}, "best time improves, attempts kept")
	assert_eq(fx.unlocked_cards(), [&"null_glyph"], "Null Glyph granted once")
	# D1: Mayday is owned at start, so the fallback title.
	fx.bus().dossier_cleared.emit(&"dossier_first_contact", 1, 30.0)
	var d1: DossierData = fx.db().get_dossier(&"dossier_first_contact")
	assert_eq(c.titles().get(&"dossier_first_contact"), d1.reward_title, "D1 fallback title")
	fx.bus().dossier_cleared.emit(&"dossier_lights_out", 2, 50.0)
	assert_true(c.has_frame(fx.db().get_dossier(&"dossier_lights_out").reward_frame), "D3 frame")
	fx.bus().dossier_cleared.emit(&"dossier_clean_copy", 1, 50.0)
	assert_true(c.has_title(&"dossier_clean_copy"), "D5 title")
	assert_eq(c.cleared_dossier_count(), 4, "4 cleared")
	fx.finish()


func test_cipher_lock_uses_code_from_data() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("cipher")
	var code: Array = Array(fx.db().get_balance().cipher_code)
	assert_eq(c.cipher_length(), code.size(), "dial count from data")
	var wrong: Array = code.duplicate()
	wrong.reverse()
	assert_false(c.try_cipher_code(wrong), "reversed code is wrong")
	assert_false(c.try_cipher_code([1, 2]), "short code is wrong")
	assert_eq(c.cipher_attempts(), 2, "attempts counted")
	assert_false(c.owns(&"key_fragment"), "still locked")
	assert_true(c.try_cipher_code(code), "code from balance.tres opens it")
	assert_true(c.is_cipher_solved(), "solved")
	assert_true(c.owns(&"key_fragment"), "Key Fragment")
	assert_eq(fx.events_named("cipher_attempted").map(func(e: Array) -> bool: return e[1]), [false, false, true], "attempt signals")
	assert_eq(fx.events_named("cipher_solved").size(), 1, "solved once")
	assert_true(c.try_cipher_code(code), "still answers after solving")
	assert_eq(c.cipher_attempts(), 3, "no more attempts counted once solved")
	fx.finish()


func test_triptych_reveal_once_player_only() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("triptych")
	var t: TriptychData = fx.db().get_triptych(&"open_book")
	fx.bus().triptych_scored.emit(&"rival", t.id, true)
	assert_false(c.has_triptych(t.id), "the rival's Triptych doesn't count")
	fx.bus().triptych_scored.emit(&"player", t.id, true)
	fx.bus().triptych_scored.emit(&"player", t.id, false)
	assert_true(c.has_triptych(t.id), "revealed")
	assert_eq(fx.events_named("triptych_revealed").size(), 1, "revealed once")
	assert_eq(c.titles().get(t.id), t.reward_title, "title")
	assert_true(t.reward_frame == &"" or c.has_frame(t.reward_frame), "frame")
	fx.finish()


func test_set_completion() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("sets")
	var ns: SetData = fx.db().get_set(&"night_shift")
	var p: Dictionary = c.set_progress(ns.id)
	assert_eq(p["owned"], p["total"] - 1, "Night Shift one short at start")
	assert_eq(c.card_frame(&"neon_rain"), &"", "standard frame before completion")
	fx.play(&"win", &"warden")  # City Never Sleeps
	assert_true(c.is_set_complete(ns.id), "Night Shift complete")
	assert_eq(fx.events_named("set_completed"), [["set_completed", ns.id]], "set_completed once")
	assert_eq(c.titles().get(StringName("set_%s" % ns.id)), ns.completion_title, "completion title from data")
	assert_eq(c.card_frame(&"neon_rain"), c.set_frame_id(ns.id), "animated set frame")
	fx.finish()


func test_saved_lineup_rules_and_signal() -> void:
	var fx: RefCounted = Fx.new(tree)
	var c: Node = fx.make("lineup")
	var bad: Dictionary = c.save_lineup(fx.legend_lineup_ids(), &"city_never_sleeps")
	assert_false(bad["valid"], "unowned Legend rejected")
	assert_true(bad["errors"].has(LineupRules.NOT_OWNED), "NOT_OWNED")
	assert_false(c.has_saved_lineup(), "nothing saved")
	var ids: Array = fx.loaner_ids()
	var ok: Dictionary = c.save_lineup(ids, ids[2])
	assert_true(ok["valid"], "loaner cards are owned: valid")
	assert_eq(c.get_saved_lineup_ids()["cards"], ids, "ids saved")
	assert_eq(c.get_saved_lineup()["signature"].id, ids[2], "Signature saved")
	assert_eq(fx.events_named("lineup_saved").size(), 1, "lineup_saved emitted")
	fx.finish()


## Binding rule (spec §3, design review decision 3): rewards are cosmetic or ownership only.
func test_unlocks_never_change_stats_or_rules() -> void:
	var fx: RefCounted = Fx.new(tree)
	var db: Node = fx.db()
	var before: Dictionary = _data_snapshot(db)
	var duel_before: Dictionary = _reference_duel(db)
	var c: Node = fx.make("cosmetic")
	# Earn everything the demo offers.
	for i: int in 6:
		fx.play(&"win", &"warden", [], 4)
	for d: DossierData in db.all_dossiers():
		fx.bus().dossier_cleared.emit(d.id, 1, 10.0)
	c.try_cipher_code(Array(db.get_balance().cipher_code))
	for t: TriptychData in db.all_triptychs():
		fx.bus().triptych_scored.emit(&"player", t.id, true)
	assert_eq(c.card_totals()["owned"], db.card_count(), "everything unlocked")
	assert_eq(_data_snapshot(db), before, "no card value, Clearance, trait, store flag or balance number changed")
	assert_eq(_reference_duel(db), duel_before, "the same duel plays out identically")
	for e: Array in fx.events_named("unlocked"):
		assert_true(e[1] in [&"card", &"title", &"frame"], "reward kind %s is cosmetic / ownership" % e[1])
	var save: Dictionary = c.to_save_dict()
	var allowed: Array = ["schema", "game", "saved_at", "cards", "titles", "frames", "goals_done", "sets_done",
			"triptychs", "dossiers", "stats", "cipher", "lineup", "lobby_duel"]
	for key: String in save.keys():
		assert_true(allowed.has(key), "save field '%s' is a known non-power field" % key)
	var text: String = JSON.stringify(save).to_lower()
	for word: String in ["\"xp\"", "level", "power", "bonus", "boost", "\"top\"", "\"side\"", "\"bottom\"", "clearance"]:
		assert_false(text.contains(word), "save holds no '%s'" % word)
	fx.finish()


func _data_snapshot(db: Node) -> Dictionary:
	var out: Dictionary = {}
	for card: CardData in db.all_cards():
		out[card.id] = [card.top, card.side, card.bottom, card.clearance, card.origin, card.card_trait(),
				card.is_store, card.signature_eligible, card.card_set.id]
	var b: BalanceConfig = db.get_balance()
	out["balance"] = [b.wall_rows, b.lineup_size, b.clearance_cap, b.max_legends, b.stat_budgets, b.set_link_bonus,
			b.clutch_bonus, b.ambush_spring_bonus, b.signature_value, b.triptych_bonus, b.tie_winner, b.chain_captures]
	return out


## A seeded full duel (loaner vs Warden) through WallRules: placements, flips and the result.
func _reference_duel(db: Node) -> Dictionary:
	var b: BalanceConfig = db.get_balance()
	var rival: RivalData = db.get_rival(&"warden")
	var p1: Array[CardData] = []
	p1.assign(b.loaner_lineup)
	var p2: Array[CardData] = []
	p2.assign(rival.lineup)
	var trips: Array[TriptychData] = []
	trips.assign(db.all_triptychs())
	var s: WallState = WallState.new_match(p1, b.loaner_signature, p2, rival.signature, WallState.P1, b, null, trips)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var log: Array = []
	while not s.is_game_over():
		var moves: Array[Dictionary] = WallRules.legal_moves(s)
		var m: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
		log.append(WallRules.place(s, s.to_move, m["card"], m["slot"], m["copy_from"]).to_dict())
	return {"log": log, "result": WallRules.final_result(s)}
