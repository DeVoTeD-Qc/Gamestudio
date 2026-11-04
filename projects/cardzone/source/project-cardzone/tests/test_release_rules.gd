# test_release_rules.gd
# Purpose: cz19 release check, spec §16 spot-check by an independent oracle. AI-vs-AI games
#   (Rookie and Veteran, routes A/B/C, hand 5 and the hand-4 dev pairing, plus a short-deck
#   variant that reaches the hard end) are played on the real rules engine. Before every action
#   the oracle predicts the outcome from the spec text alone (it never calls shot_profile,
#   cover_for or the engine's private helpers) and compares it with the state and events after:
#   - R22-R24 shot damage = DMG + attachment DMG - Cover (other area, not ignores-cover) - Down;
#     D6 Down = Hits in the next draw; R24 no Brace step at 0; R27 Suppressor: no Brace step;
#   - R25 Hits = max(0, damage - Brace total); braced cards go to the bottom in the chosen order;
#     R26 a card braces once per turn; R29 Hits land on top of the loadout;
#   - R36 Bounty at round start to strictly more health (tie: set aside), R37 claim heal;
#   - R40 gas check: 1 Hit at End turn for a pawn in gas (none outside);
#   - R43/R38 final circle k: final_circle_hits[k-12] (+ bounty_final_circle_extra for the holder);
#   - R44/R48 hard end after card zone_hard_end_card: more health, then more non-Hit cards, else draw;
#   - R47 both out at once: more non-Hit cards wins, else draw.
# Dependencies: LoadoutRules, MatchState, CzAI, RulesData, CardDB.
# Author: QA Agent (cz19)
extends "res://tests/test_case.gd"

## Stays where it lands and only ends turns (so the gas check and gas eliminations get exercised).
class Camper extends RefCounted:
	func choose_action(state: MatchState, seat: int) -> Dictionary:
		for a: Dictionary in LoadoutRules.legal_actions(state):
			if int(a["seat"]) != seat:
				continue
			if a["type"] == "drop":
				return a
			if a["type"] == "brace":
				return {"type": "brace", "seat": seat, "cards": []}
		return {"type": "end_turn", "seat": seat, "hold": []}


var _n: Dictionary = {}
var _problems: Array[String] = []


func _count(k: String) -> void:
	_n[k] = int(_n.get(k, 0)) + 1


func _problem(s: String) -> void:
	if _problems.size() < 30:
		_problems.append(s)


func test_spec16_oracle_on_ai_games() -> void:
	var base: RulesData = RulesData.from_card_db(CardDB)
	var sets: Array = [
		[{}, 18],
		[{"hand_size": 4, "supply_drop_cost": 3}, 9],
		[{"final_circle_hits": [0, 0, 1], "zone_hard_end_card": 13}, 9],
		[{"final_circle_hits": [3, 3, 3]}, 6],
	]
	var games: int = 0
	for s: Array in sets:
		var errors: Array = []
		var content: RulesData = base.with_balance(s[0], errors)
		assert_true(errors.is_empty(), "balance overrides %s: %s" % [s[0], errors])
		for i: int in int(s[1]):
			var lv: Array = [["rookie", "veteran"], ["veteran", "rookie"], ["veteran", "veteran"], ["rookie", "rookie"]][i % 4]
			_play(content, [DataEnums.Route.A, DataEnums.Route.B, DataEnums.Route.C][i % 3],
					CzAI.for_level(StringName(lv[0]), 11 + i), CzAI.for_level(StringName(lv[1]), 29 + i))
			games += 1
	for i: int in 6:
		var c2: RulesData = base.with_balance({})
		var ai: Object = CzAI.for_level(&"rookie" if i % 2 == 0 else &"veteran", 5 + i)
		_play(c2, [DataEnums.Route.A, DataEnums.Route.B, DataEnums.Route.C][i % 3], Camper.new() if i < 3 else ai, ai if i < 3 else Camper.new())
		games += 1
	print("     release oracle: %d games, %s" % [games, JSON.stringify(_n)])
	for p: String in _problems:
		print("     PROBLEM ", p)
	assert_true(_problems.is_empty(), "%d spec mismatches (first: %s)" % [_problems.size(), _problems[0] if not _problems.is_empty() else ""])
	for k: String in ["shot", "brace", "down_shot", "cover_shot", "gas_hit", "end_gas", "bounty_round", "final_circle", "bounty_claim"]:
		assert_true(int(_n.get(k, 0)) > 0, "the games exercised %s" % k)
	assert_true(int(_n.get("end_hard_end", 0)) > 0, "a game reached the hard end")
	assert_eq(games, 48, "every game ran to the end")


func _play(content: RulesData, route: int, a1: Object, a2: Object) -> void:
	var st: MatchState = MatchState.new_match(content, route)
	var ais: Array = [a1, a2]
	var guard: int = 0
	while not st.is_over() and guard < 3000:
		guard += 1
		var seat: int = st.deciding_seat()
		var a: Dictionary = ais[seat].choose_action(st, seat)
		var pre: MatchState = st.clone()
		var r: ActionResult = LoadoutRules.apply(st, a)
		if not r.ok:
			r = LoadoutRules.apply(st, {"type": "end_turn", "seat": seat, "hold": []} if st.pending_brace_seat() != seat else {"type": "brace", "seat": seat, "cards": []})
			if not r.ok:
				_problem("stalled: %s" % a)
				return
			continue
		_check(pre, a, st, r.events)
	_count("end_" + String(st.match_end.get("cause", "?")))
	_n["games_done"] = int(_n.get("games_done", 0)) + 1


func _health(s: MatchState, seat: int) -> int:
	return s.seats[seat].health.size()


func _nonhit(s: MatchState, seat: int) -> int:
	var n: int = 0
	for list: Array in [s.seats[seat].loadout, s.seats[seat].hand, s.seats[seat].line]:
		for inst: int in list:
			if not s.def_of(inst).is_hit():
				n += 1
	return n


func _next_draw_hits(s: MatchState, seat: int) -> int:
	var hs: int = s.data.balance.hand_size
	var non: int = 0
	var hits: int = 0
	for inst: int in s.seats[seat].loadout:
		if non >= hs:
			break
		if s.def_of(inst).is_hit():
			hits += 1
		else:
			non += 1
	return hits


func _ev(events: Array, t: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == t)


func _check(pre: MatchState, a: Dictionary, post: MatchState, events: Array) -> void:
	var b: BalanceConfig = pre.data.balance
	var t: String = String(a["type"])
	if t == "shoot":
		_count("shot")
		var shooter: int = int(a["seat"])
		var target: int = int(a["target"])
		var w: CardData = pre.def_of(int(a["weapon"]))
		var dmg: int = w.dmg
		var supp: bool = false
		for att: int in pre.attachments_of(int(a["weapon"])):
			dmg += pre.def_of(att).attach_dmg
			supp = supp or pre.def_of(att).attach_no_brace
		var from: StringName = pre.seats[shooter].area
		var to: StringName = pre.seats[target].area
		var cover: int = 0
		if from != to and not w.ignores_cover and not (b.bounty_holder_loses_cover and pre.bounty == target):
			cover = pre.data.area(to).cover
		var down: int = b.down_value if (b.down_enabled and _next_draw_hits(pre, target) >= 1) else 0
		if down > 0:
			_count("down_shot")
		if cover > 0:
			_count("cover_shot")
		var expect: int = maxi(0, dmg - cover - down)
		var rec: Dictionary = post.last_shot.get("targets", {}).get(target, {})
		if int(rec.get("damage_before_brace", -1)) != expect:
			_problem("R24 damage %s: expected %d (dmg %d cover %d down %d), got %s" % [w.id, expect, dmg, cover, down, rec.get("damage_before_brace")])
		var asked: bool = not _ev(events, "brace_requested").is_empty()
		if asked != (expect > 0 and not supp):
			_problem("R24/R27 brace step %s for damage %d suppressed %s" % [asked, expect, supp])
		if not asked:
			_check_landing(pre, post, target, expect, events, shooter)
	elif t == "brace":
		_count("brace")
		var seat: int = int(a["seat"])
		var cards: Array = a.get("cards", [])
		var total: int = 0
		for x: Variant in cards:
			total += pre.def_of(int(x)).brace
			if pre.seats[seat].braced.has(int(x)):
				_problem("R26 card %d braced twice in a turn" % int(x))
		var dmg2: int = int(pre.last_shot["targets"][seat]["damage_before_brace"])
		var hits: int = maxi(0, dmg2 - total)
		var rec2: Dictionary = post.last_shot["targets"][seat]
		if int(rec2["hits"]) != hits:
			_problem("R25 hits expected %d got %d" % [hits, int(rec2["hits"])])
		# Braced cards (not Spent on Brace) sit at the bottom in the chosen order, under any Hits.
		var kept: Array = cards.filter(func(x: Variant) -> bool: return pre.def_of(int(x)).spent != DataEnums.SpentMode.ON_BRACE)
		var lo: Array = post.seats[seat].loadout
		if not kept.is_empty() and lo.slice(lo.size() - kept.size()) != kept:
			_problem("R25 braced %s not at the bottom (loadout tail %s)" % [kept, lo.slice(maxi(0, lo.size() - kept.size()))])
		if post.last_shot.get("resolved", false):
			_check_landing(pre, post, seat, hits, events, int(pre.last_shot["shooter"]))
	elif t == "end_turn":
		var seat3: int = int(a["seat"])
		var in_gas: bool = pre.gas.has(pre.seats[seat3].area)
		var gh: Array = _ev(events, "gas_hit")
		if in_gas:
			_count("gas_hit")
		if in_gas != (gh.size() == 1 and int(gh[0]["seat"]) == seat3):
			_problem("R40 gas check: in gas %s, gas_hit events %s" % [in_gas, gh])
		if in_gas and _health(pre, seat3) > 0 and post.seats[seat3].health.size() != _health(pre, seat3) - 1 and not post.is_over():
			_problem("R40 gas Hit did not land")
		if not _ev(events, "round_started").is_empty():
			_check_round_start(pre, seat3, post, events)
		elif post.is_over() and String(post.match_end.get("cause", "")) == "hard_end":
			_check_hard_end(post)
	if post.is_over() and _ev(events, "eliminated").size() >= 2:
		_count("both_out")
		var w2: int = _more(post)
		var res: Dictionary = post.match_end
		if (w2 < 0 and String(res["result"]) != "draw") or (w2 >= 0 and int(res.get("winner", -1)) != w2):
			_problem("R47 both out: expected winner %d, got %s" % [w2, res])


## Hits landed on `target` (R29: on top), Bounty claim (R37), elimination (R45).
func _check_landing(pre: MatchState, post: MatchState, target: int, hits: int, events: Array, shooter: int) -> void:
	var h0: int = _health(pre, target)
	var landed: int = mini(hits, h0)
	if not post.is_over() and _health(post, target) != h0 - landed + (0 if target != shooter else 0):
		_problem("R29 health %d -> %d for %d Hits" % [h0, _health(post, target), hits])
	if landed > 0 and not post.is_over():
		var top: Array = post.seats[target].loadout.slice(0, landed)
		for inst: int in top:
			if not post.def_of(inst).is_hit():
				_problem("R29 Hits not on top of the loadout")
				break
	if hits > h0 and not post.is_over():
		_problem("R45 lethal shot did not end the match")
	if pre.bounty == target and landed >= 1 and not post.seats[shooter].eliminated:
		_count("bounty_claim")
		if _ev(events, "bounty_claimed").is_empty():
			_problem("R37 no Bounty claim on a Hit on the holder")


func _more(s: MatchState) -> int:
	var c1: int = _nonhit(s, 0)
	var c2: int = _nonhit(s, 1)
	return -1 if c1 == c2 else (0 if c1 > c2 else 1)


func _check_round_start(pre: MatchState, seat: int, post: MatchState, events: Array) -> void:
	var b: BalanceConfig = pre.data.balance
	_count("bounty_round")
	# Health at round start = health after this End turn's gas check (events before round_started).
	var h: Array = [_health(pre, 0), _health(pre, 1)]
	for e: Dictionary in events:
		if String(e["type"]) == "round_started":
			break
		if String(e["type"]) == "gas_hit":
			h[int(e["seat"])] -= int(e["count"])
	var holder: int = 0 if h[0] > h[1] else (1 if h[1] > h[0] else -1)
	if post.bounty != holder:
		_problem("R36 Bounty: health %s, holder %d, expected %d" % [h, post.bounty, holder])
	var z: int = post.zone_card
	if z >= 12 and z <= 14:
		_count("final_circle")
		var fc: Array = _ev(events, "final_circle")
		var n: int = b.final_circle_hits[mini(z - 12, b.final_circle_hits.size() - 1)]
		if fc.size() != 1 or int(fc[0]["hits"]) != n:
			_problem("R43 final circle card %d: expected %d Hits, events %s" % [z, n, fc])
		else:
			for s2: int in [0, 1]:
				var want: int = mini(n + (b.bounty_final_circle_extra if holder == s2 else 0), h[s2])
				if int((fc[0]["taken"] as Dictionary)[s2]) != want:
					_problem("R43/R38 seat %d took %s, expected %d (holder %d)" % [s2, fc[0]["taken"][s2], want, holder])
	elif not _ev(events, "final_circle").is_empty():
		_problem("final circle on card %d" % z)


func _check_hard_end(post: MatchState) -> void:
	_count("hard_end_checked")
	if post.zone_card < post.data.balance.zone_hard_end_card:
		_problem("R44 hard end before card %d (at %d)" % [post.data.balance.zone_hard_end_card, post.zone_card])
	var h1: int = _health(post, 0)
	var h2: int = _health(post, 1)
	var w: int = (0 if h1 > h2 else 1) if h1 != h2 else _more(post)
	var res: Dictionary = post.match_end
	if (w < 0 and String(res["result"]) != "draw") or (w >= 0 and int(res.get("winner", -1)) != w):
		_problem("R48 hard end: health %d/%d cards %d/%d expected %d got %s" % [h1, h2, _nonhit(post, 0), _nonhit(post, 1), w, res])
