# test_release_unlocks.gd
# Purpose: cc17 release check: every unlock is reachable in normal play, proved on a fresh demo
#   Collection driven only through real duels and Dossiers on the real screens (scenes/Duel.tscn,
#   scenes/Dossier.tscn, the duel controller and the rules), plus the Cipher Lock code:
#     - the 5 Dossiers cleared by their solutions (all 5 rewards paid, D4 unlocks Null Glyph),
#     - the 7 unlock goals: 3-win streak, 20 captures, 5 wins, beat the Warden, beat the Warden twice
#       with no Legend (Long Watch), Dossier D4, Cipher Lock,
#     - every non-Showcase set complete, all 3 Triptychs scored by the player in a duel,
#   and the Tempo rule in the live duel: the first player's score is the board count + 2 and a
#   level score ends as a draw (end screen, duel_ended "draw"); a draw keeps the win streak.
#   The player's moves are chosen by a scripted policy (the Warden's 2-ply search, or a Triptych
#   chaser) and entered through the duel screen's own signals (card_picked, slot_chosen,
#   target_tapped, place_confirmed): the same path a tap takes. Uses its own save file
#   (test_collection_fixtures.gd), so the real save is never touched.
# Author: QA Agent (cc17)
extends "res://tests/test_case.gd"

const Fixtures: GDScript = preload("res://tests/test_collection_fixtures.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DossierControllerScript: GDScript = preload("res://scripts/dossier/dossier_controller.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"
const DOSSIER_SCENE: String = "res://scenes/Dossier.tscn"
const P1: int = WallState.P1
const P2: int = WallState.P2

var _fx: RefCounted = null
var _col: Node = null
var _saved_root_size: Vector2i
var _log: Array[String] = []
var _ties: int = 0
var _tempo_checked: int = 0


func test_all_unlocks_reachable_in_normal_play() -> void:
	_fx = Fixtures.new(tree)
	_col = _fx.make("release_unlocks")
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var db: Node = tree.root.get_node("CardDB")
	var start_owned: int = _col.owned_ids().size()
	# 1) Dossiers D1-D5 by their solutions.
	for d: DossierData in DossierControllerScript.load_dossiers():
		var ok: bool = await _dossier(d.id)
		assert_true(ok, "%s cleared" % d.id)
	assert_eq(_col.cleared_dossier_count(), 5, "5 Dossiers cleared")
	assert_true(_col.has_title(&"dossier_dossier_first_contact") or _col.titles().values().has("Contact Made"), "D1 title Contact Made")
	assert_true(_col.titles().values().has("Copycat"), "D5 title Copycat")
	assert_true(_col.has_frame(&"flare_up_gold"), "D3 frame flare_up_gold")
	assert_true(_col.has_frame(&"service_ribbon_frame"), "D2 frame service_ribbon_frame")
	assert_true(_col.owns(&"null_glyph"), "D4: Null Glyph")
	# 2) Cipher Lock (the album's dials call this with the dial values).
	assert_false(_col.try_cipher_code([1, 1, 1, 1]), "wrong code refused")
	assert_true(_col.try_cipher_code(Array(db.get_balance().cipher_code)), "Cipher Lock opens with the data code")
	assert_true(_col.owns(&"key_fragment"), "Cipher Lock: Key Fragment")
	# 3) Rival duels with a starter lineup until 5 wins, a 3-win streak and 20 captures.
	var starters: Array = [&"brass_tacks", &"neon_rain", &"last_train", &"snow_blind", &"mayday"]
	var seed_value: int = 100
	while not (_col.owns(&"honor_roll") and _col.owns(&"polar_night") and _col.owns(&"dead_air")) and seed_value < 160:
		seed_value += 1
		await _duel(&"archivist", starters, &"snow_blind", seed_value, &"warden")
	assert_true(_col.owns(&"honor_roll"), "5 wins: Honor Roll")
	assert_true(_col.owns(&"polar_night"), "3-win streak: Polar Night")
	assert_true(_col.owns(&"dead_air"), "20 captures: Dead Air")
	# 4) The Warden with no Legend: first win -> City Never Sleeps, second -> Long Watch.
	var no_legend: Array = [&"brass_tacks", &"snow_blind", &"polar_night", &"neon_rain", &"graveyard_shift"]
	var warden_wins: int = 0
	seed_value = 200
	while warden_wins < 2 and seed_value < 290:
		seed_value += 1
		if await _duel(&"warden", no_legend, &"polar_night", seed_value, &"warden") == &"win":
			warden_wins += 1
			if warden_wins == 1:
				assert_true(_col.owns(&"city_never_sleeps"), "first Warden win: City Never Sleeps")
				assert_false(_col.owns(&"long_watch"), "one no-Legend win is not enough for Long Watch")
	assert_eq(warden_wins, 2, "two Warden wins with no Legend (tried to seed %d)" % seed_value)
	assert_true(_col.owns(&"long_watch"), "second no-Legend Warden win: Long Watch")
	# 5) Triptychs: each scored by the player in a real duel.
	var trips: Dictionary = {
		&"midnight_run": [[&"graveyard_shift", &"neon_rain", &"last_train", &"snow_blind", &"brass_tacks"], &"snow_blind"],
		&"cold_signal": [[&"frostbite", &"mayday", &"dead_air", &"snow_blind", &"brass_tacks"], &"snow_blind"],
		&"open_book": [[&"null_glyph", &"key_fragment", &"honor_roll", &"graveyard_shift", &"service_ribbon"], &"honor_roll"],
	}
	for tid: StringName in trips:
		var t: TriptychData = _triptych(tid)
		seed_value = 300
		while not _col.has_triptych(tid) and seed_value < 360:
			seed_value += 1
			await _duel(&"quartermaster", trips[tid][0], trips[tid][1], seed_value, &"triptych", t)
		assert_true(_col.has_triptych(tid), "Triptych %s scored in a duel" % tid)
	# 6) Goals, cards and sets.
	for goal: UnlockGoal in db.all_unlock_goals():
		assert_true(_col.is_goal_done(goal.id), "goal %s done" % goal.id)
	assert_eq(_col.owned_ids().size(), db.all_cards().size(), "all %d cards owned (started with %d)" % [db.all_cards().size(), start_owned])
	for s: SetData in db.all_sets():
		if s.kind != DataEnums.SetKind.SHOWCASE:
			assert_true(_col.is_set_complete(s.id), "set %s complete" % s.id)
	assert_true(_tempo_checked > 0, "Tempo checked on the live end screen")
	print("     release unlocks: %d duels logged, %d Tempo checks, %d ties; stats %s" % [_log.size(), _tempo_checked, _ties, _col.stats()])
	for line: String in _log:
		print("       " + line)
	tree.root.size = _saved_root_size
	_fx.finish()


## Draws keep the win streak (Collection on the EventBus, as a duel reports them).
func test_draw_keeps_win_streak() -> void:
	var fx: RefCounted = Fixtures.new(tree)
	var col: Node = fx.make("release_draw_streak")
	var bus: Node = fx.bus()
	for r: StringName in [&"win", &"draw", &"win", &"draw", &"win"]:
		bus.duel_started.emit(&"rival", &"quartermaster", &"player")
		bus.duel_ended.emit(r, 5, 5, 10, 60.0)
	assert_eq(col.stats()["streak"], 3, "win, draw, win, draw, win = streak 3")
	assert_eq(col.stats()["draws"], 2, "two draws counted")
	assert_true(col.owns(&"polar_night"), "3-win streak goal met across draws")
	bus.duel_started.emit(&"rival", &"quartermaster", &"player")
	bus.duel_ended.emit(&"loss", 4, 6, 10, 60.0)
	assert_eq(col.stats()["streak"], 0, "a loss resets the streak")
	fx.finish()


func _triptych(tid: StringName) -> TriptychData:
	for t: TriptychData in DuelSetup.triptychs():
		if t.id == tid:
			return t
	return null


# --- Dossier ------------------------------------------------------------------------------

func _dossier(id: StringName) -> bool:
	DossierControllerScript.set_next_dossier(id)
	var screen: Control = (load(DOSSIER_SCENE) as PackedScene).instantiate()
	var ctrl: Node = screen.get_node("%DuelController")
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	ctrl.collection = _col
	tree.root.add_child(screen)
	for i: int in 4:
		await tree.process_frame
	DossierControllerScript.set_next_dossier(&"")
	screen.get_overlay().get_button(&"start").pressed.emit()
	await tree.process_frame
	for step: DossierPlacement in ctrl.dossier.solution:
		await _enter(screen, step.card.id, step.slot, step.copy_from)
	var ok: bool = ctrl.phase == &"result" and ctrl.last_result.get("success", false)
	_log.append("dossier %s: %s" % [id, "cleared" if ok else "NOT cleared"])
	screen.queue_free()
	await tree.process_frame
	return ok


# --- Duel ---------------------------------------------------------------------------------

## One full duel through the duel screen. policy: &"warden" (2-ply search for the player) or
## &"triptych" (place the Triptych's cards in one row of three, else the greedy move).
func _duel(rival_id: StringName, lineup: Array, sig: StringName, seed_value: int, policy: StringName,
		trip: TriptychData = null) -> StringName:
	var cards: Array = lineup.map(func(id: StringName) -> CardData: return DuelSetup.get_card(id))
	DuelControllerScript.set_next_duel(rival_id, cards, sig)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.seed_value = seed_value
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	tree.root.add_child(duel)
	for i: int in 4:
		await tree.process_frame
	DuelControllerScript.set_next_duel(&"", [])
	var ids: Array = ctrl.player_lineup.map(func(c: CardData) -> StringName: return c.id)
	assert_eq(ids, lineup, "duel %s/%d uses the asked lineup (not the loaner)" % [rival_id, seed_value])
	var brain: RivalAI = RivalAI.for_rival(_rival_data(&"warden"), seed_value)
	var result: Array = []
	var on_end: Callable = func(r: StringName, _p: int, _a: int, _t: int, _d: float) -> void: result.append(r)
	EventBus.duel_ended.connect(on_end)
	duel.get_overlay().get_button(&"start").pressed.emit()
	await tree.process_frame
	duel.get_overlay().get_button(&"begin").pressed.emit()
	await tree.process_frame
	var guard: int = 0
	while ctrl.phase != &"over" and guard < 400:
		guard += 1
		if ctrl.phase == &"player":
			var m: Dictionary = _pick_triptych(ctrl.state, trip) if policy == &"triptych" else brain.choose_move(ctrl.state, P1)
			if m.is_empty():
				m = _greedy(ctrl.state)
			await _enter(duel, m["card"].id, m["slot"], m["copy_from"])
		await tree.process_frame
	EventBus.duel_ended.disconnect(on_end)
	var word: StringName = result[0] if result.size() == 1 else &"?"
	assert_eq(result.size(), 1, "duel %s/%d ended once" % [rival_id, seed_value])
	_check_tempo(duel, ctrl, word)
	_log.append("%s seed %d (%s): %s %s, first %s" % [rival_id, seed_value, policy, word,
			str(ctrl.last_result.get("score", [])), "you" if ctrl.state.first_player == P1 else "rival"])
	duel.queue_free()
	await tree.process_frame
	return word


func _rival_data(id: StringName) -> RivalData:
	for r: Dictionary in DuelSetup.rivals():
		if r["id"] == id:
			return r["data"]
	return null


## Independent score: 1 per controlled card, Signature counts signature_value, +triptych_bonus per
## Triptych, +first_player_bonus (Tempo) for the first player. Must match the end screen.
func _check_tempo(duel: Control, ctrl: Node, word: StringName) -> void:
	var st: WallState = ctrl.state
	var b: BalanceConfig = st.balance
	var want: Array[int] = [0, 0]
	for slot: StringName in st.cells:
		var pc: PlacedCard = st.cells[slot]
		want[pc.controller] += b.signature_value if pc.signature else 1
	for p: int in [P1, P2]:
		want[p] += b.triptych_bonus * (ctrl.last_result["triptychs"] as Array)[p].size()
	want[st.first_player] += 2
	assert_eq(b.first_player_bonus, 2, "Tempo is +2")
	assert_eq(Array(ctrl.last_result["score"]), Array(want), "end score = board + Tempo +2 for the first player")
	var label: Label = duel.get_overlay().get_content().get_node_or_null("EndScore")
	assert_true(label != null and label.text == "%d  –  %d" % [want[0], want[1]], "end screen shows %s" % str(want))
	var expect: StringName = &"draw" if want[0] == want[1] else (&"win" if want[0] > want[1] else &"loss")
	assert_eq(word, expect, "result word from the score (ties are draws)")
	if want[0] == want[1]:
		_ties += 1
		var title: Label = duel.get_overlay().get_node("%OverlayTitle")
		assert_eq(title.text, "DRAW", "a level score shows DRAW")
	_tempo_checked += 1


## Enters one placement through the duel screen's signals (what the taps emit).
func _enter(screen: Control, card_id: StringName, slot: StringName, copy_from: StringName) -> void:
	screen.card_picked.emit(card_id)
	await tree.process_frame
	screen.slot_chosen.emit(slot)
	await tree.process_frame
	if copy_from != &"":
		screen.target_tapped.emit(copy_from)
		await tree.process_frame
	screen.place_confirmed.emit(card_id, slot)
	for i: int in 3:
		await tree.process_frame


func _greedy(state: WallState) -> Dictionary:
	var best: Dictionary = {}
	var best_v: float = -INF
	for m: Dictionary in WallRules.legal_moves(state):
		var r: PlacementResult = WallRules.preview(state, P1, m["card"], m["slot"], m["copy_from"])
		var v: float = float(r.all_flipped().size()) if r.ok else -1.0
		if v > best_v:
			best_v = v
			best = m
	return best


## Puts the Triptych's cards into one run of three (the run with the most of them already held by
## the player and no rival card), else plays the greedy move with a non-Triptych card.
func _pick_triptych(state: WallState, trip: TriptychData) -> Dictionary:
	var want: Array = trip.cards.map(func(c: CardData) -> StringName: return c.id)
	var moves: Array[Dictionary] = WallRules.legal_moves(state)
	var best_run: Array = []
	var best_have: int = -1
	for run: Array in state.topology.runs_of_three:
		var have: int = 0
		var blocked: bool = false
		for s: StringName in run:
			var pc: PlacedCard = state.get_card(s)
			if pc == null:
				continue
			if pc.controller == P1 and want.has(pc.card.id):
				have += 1
			else:
				blocked = true
		if not blocked and have > best_have:
			best_have = have
			best_run = run
	if not best_run.is_empty():
		var best: Dictionary = {}
		var best_v: float = -INF
		for m: Dictionary in moves:
			if want.has(m["card"].id) and best_run.has(m["slot"]):
				var r: PlacementResult = WallRules.preview(state, P1, m["card"], m["slot"], m["copy_from"])
				var v: float = float(r.all_flipped().size()) if r.ok else -1.0
				if v > best_v:
					best_v = v
					best = m
		if not best.is_empty():
			return best
	var best2: Dictionary = {}
	var best_v2: float = -INF
	for m: Dictionary in moves:
		var r: PlacementResult = WallRules.preview(state, P1, m["card"], m["slot"], m["copy_from"])
		var v: float = float(r.all_flipped().size()) if r.ok else -1.0
		if want.has(m["card"].id):
			v -= 10.0
		if best_run.has(m["slot"]):
			v -= 5.0
		if v > best_v2:
			best_v2 = v
			best2 = m
	return best2
