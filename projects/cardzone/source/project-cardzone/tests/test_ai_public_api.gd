# test_ai_public_api.gd
# Purpose: The AI uses only the rules engine's public API (cz07b): no file under scripts/ai calls
#   an underscore function of LoadoutRules, MatchView, MatchState or RulesData. The public fast
#   path it uses instead behaves exactly like the logged path: apply_fast == apply on every legal
#   action of a match, MatchView.public_view equals those keys of the full view, the indexed
#   RulesData.zone_card equals a scan of zone_cards. And the AI copes with the balance switches:
#   with p2_start_health_bonus its belief world still matches the public counts (health, Hits),
#   with no_shooting_round1 it never tries a round-1 shot (no illegal actions).
# Dependencies: LoadoutRules, MatchView, MatchState, RulesData, CzAI, CzBelief, CzAiArena.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const AI_DIR: String = "res://scripts/ai"
## A call into an engine class's private function: `LoadoutRules._do(`, `MatchView._cards(` ...
const PRIVATE_CALL: String = "\\b(LoadoutRules|MatchView|MatchState|RulesData)\\._[A-Za-z0-9_]*"

var _content: RulesData = null


func _data() -> RulesData:
	if _content == null:
		_content = RulesData.from_card_db(tree.root.get_node_or_null("CardDB"))
	return _content


func _ai_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(AI_DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(AI_DIR.path_join(f))
	return out


func test_ai_calls_no_private_engine_function() -> void:
	var re: RegEx = RegEx.create_from_string(PRIVATE_CALL)
	var files: PackedStringArray = _ai_files()
	assert_true(files.size() >= 6, "found the AI scripts (%d)" % files.size())
	var hits: Array[String] = []
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			for m: RegExMatch in re.search_all(lines[i]):
				hits.append("%s:%d %s" % [path.get_file(), i + 1, m.get_string()])
	assert_eq(hits, [], "AI files call engine internals")
	# The pattern itself catches the forms cz09 used to have.
	assert_true(re.search("	LoadoutRules._do(state, a, ev)") != null, "pattern sees LoadoutRules._do")
	assert_true(re.search("MatchView._opponent(s, 1)") != null, "pattern sees MatchView._opponent")
	assert_true(re.search("LoadoutRules.apply_fast(s, a)") == null, "pattern skips public calls")


func test_apply_fast_equals_apply_on_every_legal_action() -> void:
	var s: MatchState = MatchState.new_match(_data().with_balance({"hand_size": 5}), DataEnums.Route.B)
	var ais: Array[CzAI] = [CzAI.for_level(&"rookie", 1), CzAI.for_level(&"rookie", 2)]
	var checked: int = 0
	var bad: Array[String] = []
	var n: int = 0
	while not s.is_over() and n < 400:
		n += 1
		if n % 2 == 0:
			for a: Dictionary in LoadoutRules.legal_actions(s):
				var slow: MatchState = s.clone()
				var fast: MatchState = s.clone()
				var r: ActionResult = LoadoutRules.apply(slow, a)
				var ok: bool = LoadoutRules.apply_fast(fast, a)
				checked += 1
				if not (r.ok and ok and slow.fingerprint() == fast.fingerprint()):
					bad.append("action %d %s" % [n, a])
				# No log entry and no new undo snapshot (a turn start may still clear old ones).
				if fast.actions.size() != s.actions.size() or fast.undo_stack.size() > s.undo_stack.size():
					bad.append("fast path logged %s" % [a])
		var seat: int = s.deciding_seat()
		LoadoutRules.apply(s, ais[seat].choose_action(s, seat))
		if bad.size() > 3:
			break
	assert_true(checked > 300, "compared %d legal actions" % checked)
	assert_eq(bad, [], "apply_fast differs from apply")
	# Illegal and undo: refused, state untouched.
	var before: String = s.fingerprint()
	assert_false(LoadoutRules.apply_fast(s, {"type": "move", "seat": 0, "to": "nowhere"}), "illegal refused")
	assert_false(LoadoutRules.apply_fast(s, {"type": "undo", "seat": s.active}), "undo refused")
	assert_eq(s.fingerprint(), before, "state untouched")


func test_public_view_and_helpers_match_the_full_view() -> void:
	var s: MatchState = MatchState.new_match(_data(), DataEnums.Route.C)
	var ais: Array[CzAI] = [CzAI.for_level(&"veteran", 1), CzAI.for_level(&"rookie", 2)]
	var checked: int = 0
	var n: int = 0
	while not s.is_over() and n < 300:
		n += 1
		if n % 7 == 0:
			for seat: int in 2:
				var full: Dictionary = MatchView.build(s, seat)
				var part: Dictionary = MatchView.public_view(s, seat)
				for key: String in part.keys():
					assert_eq(JSON.stringify(part[key], "", true), JSON.stringify(full[key], "", true), "public_view %s" % key)
				checked += 1
			var d: int = s.pending_brace_seat()
			if d != MatchState.NO_SEAT:
				var eligible: Array = MatchView.build(s, d)["brace_prompt"]["eligible"]
				assert_eq(eligible, Array(LoadoutRules.brace_candidates(s, d)), "brace_candidates == brace_prompt.eligible")
		var who: int = s.deciding_seat()
		LoadoutRules.apply(s, ais[who].choose_action(s, who))
	assert_true(checked > 20, "checked %d views" % checked)


func test_indexed_zone_card_equals_a_scan() -> void:
	for data: RulesData in [_data(), _data().with_balance({"zone_hard_end_card": 12})]:
		for k: int in range(-1, 17):
			var scan: ZoneCardData = null
			if k <= data.balance.zone_hard_end_card:
				for z: ZoneCardData in data.zone_cards:
					if z.number == k:
						scan = z
						break
			assert_true(data.zone_card(k) == scan, "zone_card(%d) hard end %d" % [k, data.balance.zone_hard_end_card])
	# A replaced deck is re-indexed.
	var d: RulesData = _data().with_balance()
	var deck: Array[ZoneCardData] = []
	deck.assign(d.zone_cards.slice(0, 3))
	d.zone_cards = deck
	assert_true(d.zone_card(2) == deck[1] and d.zone_card(5) == null, "re-indexed after zone_cards changes")
	assert_true(_data().zone_card(5) != null, "the shared content keeps its own index")


func test_belief_counts_hold_with_the_p2_health_bonus() -> void:
	var s: MatchState = MatchState.new_match(_data().with_balance({"p2_start_health_bonus": 1}), DataEnums.Route.A)
	assert_eq(s.health_of(1), s.data.balance.health + 1, "P2 starts one up")
	var ais: Array[CzAI] = [CzAI.for_level(&"rookie", 1), CzAI.for_level(&"rookie", 2)]
	var problems: Array[String] = []
	var checked: int = 0
	var n: int = 0
	while not s.is_over() and n < 500:
		n += 1
		var seat: int = s.deciding_seat()
		if n % 3 == 0:
			checked += 1
			var opp: int = 1 - seat
			var w: MatchState = CzBelief.world(s, seat)
			var real: SeatState = s.seats[opp]
			var guess: SeatState = w.seats[opp]
			for pair: Array in [[s.hits_in(real.loadout), w.hits_in(guess.loadout), "loadout Hits"],
					[real.loadout.size(), guess.loadout.size(), "loadout"], [real.hand.size(), guess.hand.size(), "hand"],
					[s.health_of(opp), w.health_of(opp), "health"], [s.next_draw_hits(opp), w.next_draw_hits(opp), "next draw Hits"]]:
				if pair[0] != pair[1]:
					problems.append("action %d seat %d: %s %s vs %s" % [n, seat, pair[2], pair[0], pair[1]])
		LoadoutRules.apply(s, ais[seat].choose_action(s, seat))
		if problems.size() > 5:
			break
	assert_true(checked > 30, "checked %d states" % checked)
	assert_eq(problems, [], "belief counts with the bonus")


func test_ai_never_shoots_in_round1_with_the_switch() -> void:
	var content: RulesData = _data().with_balance({"no_shooting_round1": true, "hand_size": 5})
	for levels: Array in [[&"veteran", &"veteran"], [&"rookie", &"rookie"]]:
		# Hot drop: both in the same area, so round 1 would otherwise have shots.
		var r: Dictionary = CzAiArena.play(content, DataEnums.Route.A, CzAI.for_level(levels[0], 1),
				CzAI.for_level(levels[1], 2), {0: "quarry", 1: "quarry"})
		assert_eq(r["illegal"], 0, "%s: no illegal actions" % [levels])
		var end: MatchState = r["state"]
		var replay: MatchState = MatchState.new()
		replay.data = end.data
		replay.load_dict(end.origin)
		var round1_shots: int = 0
		for act: Dictionary in end.actions:
			if replay.round_number <= 1 and String(act["type"]) in ["shoot", "frag"]:
				round1_shots += 1
			LoadoutRules.apply(replay, act)
		assert_eq(round1_shots, 0, "%s: no round-1 shot" % [levels])
		assert_true(end.round_number > 1, "%s: the match went past round 1" % [levels])
