# test_rules_cases.gd
# Pattern adapted from CallingCard tests/test_rules_cases.gd (JSON case runner, PASS/FAIL per id).
# Purpose: Runs all 120 cases of QA's rules-test-cases.json (cz04) headless against the rules
#   engine (scripts/rules). Each setup is built with MatchState.from_fixture (RQ-11); QA's card
#   codes are resolved to instance ids by RQ-07 (hand order for play/ditch/hold, line order for
#   shoot/attach, next-hand order for brace). Also checked on every case: an illegal step leaves
#   the state byte-identical, every shot's preview equals the declared shot, and replaying the
#   logged actions from the fixture reproduces the final state exactly.
#   Only selected cases: godot ... -s res://tests/run_tests.gd -- --only=rules_cases --case=RT-001,RT-064
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_rules_fixtures.gd")

var _content: RulesData
var _codes: Dictionary
var _ids: Dictionary
var _fail: Array[String] = []
var _preview_checks: int = 0
var _replay_checks: int = 0


func test_qa_rules_cases() -> void:
	var doc: Dictionary = Fx.load_cases()
	assert_false(doc.is_empty(), "rules-test-cases.json loads from %s" % Fx.json_path())
	if doc.is_empty():
		return
	_content = Fx.content(doc)
	_codes = Fx.code_map(doc)
	_ids = Fx.id_map(doc)
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=").split(",")
	var passed: int = 0
	var failed_ids: PackedStringArray = []
	var cases: Array = doc["cases"]
	for c: Dictionary in cases:
		if not only.is_empty() and not only.has(c["id"]):
			continue
		_fail.clear()
		_run_case(c)
		if _fail.is_empty():
			passed += 1
		else:
			failed_ids.append(c["id"])
			print("     FAIL %s %s" % [c["id"], c["title"]])
			for f: String in _fail:
				print("          - %s" % f)
	var total: int = passed + failed_ids.size()
	print("     rules cases: %d / %d passed (%d preview checks, %d replay checks)%s" % [passed, total,
			_preview_checks, _replay_checks, "" if failed_ids.is_empty() else ", failed: " + ", ".join(failed_ids)])
	assert_eq(failed_ids.size(), 0, "failed QA cases: %s" % ", ".join(failed_ids))
	if only.is_empty():
		assert_eq(total, cases.size(), "every case ran")
		assert_eq(total, 120, "120 cz04 cases")


func _run_case(c: Dictionary) -> void:
	var errors: Array = []
	var state: MatchState = MatchState.from_fixture(c["setup"], _content, _codes, errors)
	for e: Variant in errors:
		_fail.append("fixture: %s" % e)
	var done_steps: Array = []  # QA steps that ran (legal ones), replayed on setup_b
	var i: int = 0
	for step: Dictionary in c["steps"]:
		i += 1
		var where: String = "step %d %s" % [i, JSON.stringify(step["action"])]
		var act: Dictionary = step["action"]
		var expect: Dictionary = step.get("expect", {})
		var t: String = act["type"]
		if t == "check":
			pass
		elif t == "auto_draw":
			LoadoutRules.auto_draw(state)
			done_steps.append(act)
		elif t == "view":
			_check_view(c, state, act, expect, done_steps, where)
			continue
		else:
			var a: Dictionary = resolve_action(state, act)
			var before: String = state.fingerprint()
			var preview: Dictionary = {}
			if t == "shoot":
				preview = LoadoutRules.preview_shot(state, int(a["seat"]), int(a.get("weapon", 0)), int(a.get("target", -1)))
			var r: ActionResult = LoadoutRules.apply(state, a)
			if expect.get("legal", true) == false:
				if r.ok:
					_fail.append("%s: expected illegal, was accepted" % where)
				elif state.fingerprint() != before:
					_fail.append("%s: rejected but the state changed" % where)
				continue
			if not r.ok:
				_fail.append("%s: rejected (%s)" % [where, r.error])
				continue
			done_steps.append(act)
			if t == "shoot":
				_preview_checks += 1
				var rec: Dictionary = r.shot["targets"][int(a["target"])]
				if not preview["legal"] or int(preview["damage"]) != int(rec["damage_before_brace"]) \
						or int(preview["cover"]) != int(rec["cover"]) or int(preview["down"]) != int(rec["down"]):
					_fail.append("%s: preview %s != shot %s" % [where, preview, rec])
		_check_expect(state, expect, where)
	# U1: the fixture plus the logged actions replay to the same state.
	var replay_errors: Array = []
	var again: MatchState = LoadoutRules.replay_of(state, replay_errors)
	_replay_checks += 1
	for e: Variant in replay_errors:
		_fail.append("replay: %s" % e)
	if again.fingerprint() != state.fingerprint():
		_fail.append("replay differs from the played state")


# --- Action resolution (RQ-07) --------------------------------------------------------

## QA action ({type, player, card: "SCV", ...}) -> engine action with instance ids.
func resolve_action(state: MatchState, act: Dictionary) -> Dictionary:
	var seat: int = MatchState.seat_from_name(act.get("player", act.get("seat")))
	var a: Dictionary = {"type": act["type"], "seat": seat}
	if seat == MatchState.NO_SEAT:
		return a
	var st: SeatState = state.seats[seat]
	match String(act["type"]):
		"play":
			a["card"] = _find(state, String(act["card"]), [st.hand, st.line, st.loadout])
			if act.has("adrenaline"):
				a["adrenaline"] = act["adrenaline"]
		"ditch":
			a["card"] = _find(state, String(act["card"]), [st.hand, st.line, st.loadout])
		"move":
			a["to"] = act["to"]
		"drop":
			a["area"] = act["area"]
		"frag":
			a["area"] = act["area"]
		"shoot":
			a["weapon"] = _find(state, String(act["weapon"]), [st.line, st.hand, st.loadout])
			a["target"] = MatchState.seat_from_name(act["target"])
		"attach":
			a["attachment"] = _find(state, String(act["attachment"]), [st.hand, st.line])
			a["weapon"] = _find(state, String(act["weapon"]), [st.line, st.hand])
		"loot":
			var src: String = act["source"]
			if src.begins_with("drop:"):
				var lists: Array = [state.drops.get(st.area, [])]
				for area_id: Variant in state.drops.keys():
					lists.append(state.drops[area_id])
				a["card"] = _find(state, src.trim_prefix("drop:"), lists)
			elif src.begins_with("crate:"):
				var lists: Array = []
				for crate: Dictionary in state.crates:
					if crate["area"] == st.area:
						lists.push_front(crate["cards"])
					else:
						lists.append(crate["cards"])
				a["card"] = _find(state, src.trim_prefix("crate:"), lists)
			else:
				a["pile"] = String(_codes.get(src, src))
		"end_turn":
			var chosen: Array = []
			for code: Variant in act.get("hold", []):
				chosen.append(_find(state, String(code), [st.hand, st.line], chosen))
			a["hold"] = chosen
			if act.get("rack_move") is Dictionary:
				a["rack_move"] = {"from": int(act["rack_move"]["from"]), "to": int(act["rack_move"]["to"])}
		"brace":
			var chosen: Array = []
			for code: Variant in act.get("cards", []):
				chosen.append(_find(state, String(code), [state.next_hand(seat), st.loadout], chosen))
			a["cards"] = chosen
	return a


func _find(state: MatchState, code: String, lists: Array, exclude: Array = []) -> int:
	for list: Variant in lists:
		var inst: int = state.find_token(list, code, _codes, exclude)
		if inst > 0:
			return inst
	return 0


# --- Expectations ---------------------------------------------------------------------

func _check_expect(state: MatchState, expect: Dictionary, where: String) -> void:
	for key: String in expect.keys():
		var want: Variant = expect[key]
		match key:
			"legal":
				pass
			"P1", "P2":
				var seat: int = MatchState.seat_from_name(key)
				for field: String in (want as Dictionary).keys():
					_cmp(_player_field(state, seat, field), want[field], "%s %s.%s" % [where, key, field])
			"shot":
				_cmp(_shot(state), want, "%s shot" % where)
			"pending_brace":
				_cmp(_seat(state.pending_brace_seat()), want, "%s pending_brace" % where)
			"active":
				_cmp(_seat(state.active), want, "%s active" % where)
			"bounty":
				_cmp(_seat(state.bounty), want, "%s bounty" % where)
			"round":
				_cmp(state.round_number, want, "%s round" % where)
			"zone_card":
				_cmp(state.zone_card, want, "%s zone_card" % where)
			"gas":
				var have: Array = []
				for g: StringName in state.gas:
					have.append(String(g))
				have.sort()
				var exp_gas: Array = (want as Array).duplicate()
				exp_gas.sort()
				_cmp(have, exp_gas, "%s gas" % where)
			"drops":
				var have: Dictionary = {}
				for area_id: Variant in state.drops.keys():
					have[String(area_id)] = Fx.tokens(state, state.drops[area_id], _ids)
				_cmp(have, want, "%s drops" % where)
			"piles":
				var have: Dictionary = {}
				var counts: Dictionary = state.pile_counts()
				for area_id: Variant in counts.keys():
					var per: Dictionary = {}
					for cid: Variant in counts[area_id].keys():
						per[_ids.get(StringName(cid), String(cid))] = counts[area_id][cid]
					have[String(area_id)] = per
				_cmp(have, want, "%s piles" % where)
			"removed":
				_cmp(Fx.tokens(state, state.removed, _ids), want, "%s removed" % where)
			"match_end":
				_cmp(_match_end(state), want, "%s match_end" % where)
			"crate":
				var have: Array = []
				for crate: Dictionary in state.crates:
					have.append({"owner": _seat(int(crate["owner"])), "area": String(crate["area"]),
							"cards": Fx.tokens(state, crate["cards"], _ids), "free_picks": crate["free_picks"]})
				_cmp(have, want, "%s crate" % where)
			"action_count":
				_cmp(state.actions.size(), want, "%s action_count" % where)
			_:
				_fail.append("%s: unknown expectation key %s" % [where, key])


func _player_field(state: MatchState, seat: int, field: String) -> Variant:
	var st: SeatState = state.seats[seat]
	match field:
		"area":
			return String(st.area)
		"health":
			return st.health.size()
		"loadout":
			return Fx.tokens(state, st.loadout, _ids)
		"hand":
			return Fx.tokens(state, st.hand, _ids)
		"line":
			return Fx.tokens(state, st.line, _ids)
		"next_draw":
			return Fx.tokens(state, state.next_draw(seat), _ids)
		"move":
			return st.move
		"search":
			return st.search
		"down":
			return state.is_down(seat)
		"eliminated":
			return st.eliminated
		"held_count":
			return st.held.size()
		"nonhit_count":
			return state.nonhit_count(seat)
	return "<unknown field %s>" % field


## The last shot in QA's shape: a shot's target fields at the top; a Frag's per seat under frag.
func _shot(state: MatchState) -> Dictionary:
	var ls: Dictionary = state.last_shot
	if ls.is_empty():
		return {}
	var out: Dictionary = {"bounty_heal": ls["bounty_heal"]}
	if ls["kind"] == "frag":
		var per: Dictionary = {}
		for t: Variant in ls["targets"].keys():
			per[_seat(int(t))] = _shot_rec(state, ls["targets"][t])
		out["frag"] = per
	else:
		out.merge(_shot_rec(state, ls["targets"][int(ls["target"])]))
	return out


func _shot_rec(state: MatchState, rec: Dictionary) -> Dictionary:
	return {"damage_before_brace": rec["damage_before_brace"], "cover": rec["cover"], "down": rec["down"],
			"hits": rec["hits"], "braced": Fx.tokens(state, rec["braced"], _ids)}


func _match_end(state: MatchState) -> Variant:
	if state.match_end.is_empty():
		return null
	var out: Dictionary = state.match_end.duplicate()
	if out.has("winner"):
		out["winner"] = _seat(int(out["winner"]))
	return out


func _seat(i: int) -> Variant:
	return MatchState.seat_name(i) if i != MatchState.NO_SEAT else null


# --- Views (RQ-10, P18) -------------------------------------------------------------

func _check_view(c: Dictionary, state: MatchState, act: Dictionary, expect: Dictionary, done_steps: Array,
		where: String) -> void:
	var seat: int = MatchState.seat_from_name(act["seat"])
	var v: Dictionary = LoadoutRules.view(state, seat)
	var shown: Variant = normalize_view(state, v)
	if expect.has("view"):
		_cmp(shown, expect["view"], "%s view" % where)
	for path: Variant in expect.get("view_absent", []):
		if _has_path(v, String(path)):
			_fail.append("%s: view has %s (must be absent)" % [where, path])
	if expect.get("view_equal_b", false):
		if not c.has("setup_b"):
			_fail.append("%s: view_equal_b without setup_b" % where)
			return
		var errors: Array = []
		var b_state: MatchState = MatchState.from_fixture(c["setup_b"], _content, _codes, errors)
		for step_act: Dictionary in done_steps:
			if step_act["type"] == "auto_draw":
				LoadoutRules.auto_draw(b_state)
				continue
			var r: ActionResult = LoadoutRules.apply(b_state, resolve_action(b_state, step_act))
			if not r.ok:
				errors.append("setup_b step %s rejected: %s" % [step_act, r.error])
		for e: Variant in errors:
			_fail.append("%s: %s" % [where, e])
		var vb: Dictionary = LoadoutRules.view(b_state, seat)
		if JSON.stringify(v, "", true) != JSON.stringify(vb, "", true):
			_fail.append("%s: view differs between setup and setup_b (fairness, P18):\n%s\n%s"
					% [where, JSON.stringify(v, "", true), JSON.stringify(vb, "", true)])


## Card views ({id, card, attachments}) become QA tokens; seats stay as given.
func normalize_view(state: MatchState, value: Variant) -> Variant:
	if value is Dictionary:
		var d: Dictionary = value
		if d.has("id") and d.has("card") and d.has("attachments"):
			return Fx.token(state, int(d["id"]), _ids)
		var out: Dictionary = {}
		for k: Variant in d.keys():
			out[str(k)] = normalize_view(state, d[k])
		return out
	if value is Array:
		var out: Array = []
		for x: Variant in value:
			out.append(normalize_view(state, x))
		return out
	if value is StringName:
		return String(value)
	return value


func _has_path(d: Dictionary, path: String) -> bool:
	var cur: Variant = d
	for part: String in path.split("."):
		if not (cur is Dictionary) or not (cur as Dictionary).has(part):
			return false
		cur = cur[part]
	return true


# --- Comparison ---------------------------------------------------------------------

## Expected dicts are subsets (only the listed keys matter); lists must match exactly; numbers
## compare by value (JSON gives floats).
func _cmp(have: Variant, want: Variant, where: String) -> void:
	if not _match(have, want):
		_fail.append("%s: expected %s, got %s" % [where, JSON.stringify(want), JSON.stringify(have)])


func _match(have: Variant, want: Variant) -> bool:
	if want == null:
		return have == null
	if want is Dictionary:
		if not (have is Dictionary):
			return false
		for k: Variant in want.keys():
			var hk: Variant = null
			if have.has(k):
				hk = have[k]
			elif have.has(String(k)):
				hk = have[String(k)]
			else:
				return false
			if not _match(hk, want[k]):
				return false
		return true
	if want is Array:
		if not (have is Array) or have.size() != want.size():
			return false
		for i: int in want.size():
			if not _match(have[i], want[i]):
				return false
		return true
	if want is float or want is int:
		return (have is float or have is int) and is_equal_approx(float(have), float(want))
	if want is bool:
		return have is bool and have == want
	if want is String or want is StringName:
		return (have is String or have is StringName) and String(have) == String(want)
	return have == want
