# ai_sweep.gd: the cz09 AI-vs-AI balance sweep (headless).
#   Plays every drop pair (P1 on each of the 6 outer areas x P2 on each) on each route and hand
#   size, AI vs AI on the real rules engine (CzAiArena), with the content from res://data (CardDB).
#   godot --headless --path . -s res://tests/tools/ai_sweep.gd -- [options]
#     --p1=veteran|rookie --p2=veteran|rookie   levels (default veteran vs veteran)
#     --hands=4,5            hand sizes (default 4,5)
#     --routes=A,B,C         routes (default A,B,C)
#     --cost4=3 --cost5=4    supply_drop_cost per hand size (default 3 at hand 4, 4 at hand 5:
#                            the pairing spec §16.4a asks the dev panel to switch together)
#     --wv=key:val,...       Veteran evaluation weights to try (CzVeteranAI.WEIGHTS keys)
#     --cap=N                Veteran node cap to try (CzVeteranAI.NODE_CAP)
#     --out=/abs/rows.json   also write every game as JSON (one array)
#     --merge=/a.json,/b.json  print the tables for earlier --out files instead of playing
#     --retime=10            re-time the N slowest turns 5 times each (median), since one timing
#                            on a shared machine can catch a pause from another process
#   Prints a markdown table per (hand, route), pooled rows per hand, and the AI turn timings.
#   Deterministic: the same options always give the same games.
# Author: Mechanics Developer Agent (cz09)
extends SceneTree

const OUTER: Array[String] = ["docks", "farmstead", "quarry", "radio_hill", "motel", "rail_yard"]
const LABEL: Dictionary = {"docks": "Docks", "farmstead": "Farmstead", "quarry": "Quarry",
		"radio_hill": "Radio Hill", "motel": "Motel", "rail_yard": "Rail Yard"}

var _opts: Dictionary = {"p1": "veteran", "p2": "veteran", "hands": "4,5", "routes": "A,B,C",
		"cost4": "3", "cost5": "4", "out": "", "merge": "", "wv": "", "cap": "", "retime": "0"}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv: PackedStringArray = arg.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rows: Array = []
	if String(_opts["merge"]) != "":
		for path: String in String(_opts["merge"]).split(","):
			var f: FileAccess = FileAccess.open(path, FileAccess.READ)
			if f == null:
				printerr("cannot read %s" % path)
				quit(1)
				return
			rows.append_array(JSON.parse_string(f.get_as_text()))
	else:
		var db: Node = root.get_node_or_null("CardDB")
		if db == null or not db.call("is_valid"):
			printerr("CardDB did not load")
			quit(1)
			return
		var base: RulesData = RulesData.from_card_db(db)
		var started: int = Time.get_ticks_msec()
		for hand_text: String in String(_opts["hands"]).split(","):
			var hand: int = int(hand_text)
			var errors: Array = []
			var content: RulesData = base.with_balance({"hand_size": hand,
					"supply_drop_cost": int(_opts["cost%d" % hand])}, errors)
			if not errors.is_empty():
				printerr(errors)
				quit(1)
				return
			for route_text: String in String(_opts["routes"]).split(","):
				var route: int = MatchState.route_from_letter(route_text)
				for a: String in OUTER:
					for b: String in OUTER:
						rows.append(_game(content, hand, route_text, route, a, b))
		print("played %d games in %.1f s" % [rows.size(), float(Time.get_ticks_msec() - started) / 1000.0])
		if String(_opts["out"]) != "":
			var f: FileAccess = FileAccess.open(String(_opts["out"]), FileAccess.WRITE)
			f.store_string(JSON.stringify(rows))
			f.close()
	_report(rows)
	if int(_opts["retime"]) > 0 and String(_opts["merge"]) == "":
		_retime(rows, int(_opts["retime"]))
	quit(0)


## Replays the games with the slowest turns and times those turns again (5 runs each).
func _retime(rows: Array, count: int) -> void:
	var turns: Array = []
	for gi: int in rows.size():
		var g: Dictionary = rows[gi]
		for ti: int in (g["turn_ms"] as Array).size():
			turns.append([float(g["turn_ms"][ti]), gi, ti])
	turns.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var base: RulesData = RulesData.from_card_db(root.get_node("CardDB"))
	print("\nSlowest %d turns re-timed (5 runs each, fresh AIs):" % count)
	print("| Game | Turn (round, seat) | First timing ms | Re-timed median ms | min | max |")
	print("|---|---|---|---|---|---|")
	var worst_median: float = 0.0
	for k: int in mini(count, turns.size()):
		var g: Dictionary = rows[turns[k][1]]
		var ti: int = turns[k][2]
		var content: RulesData = base.with_balance({"hand_size": int(g["hand"]),
				"supply_drop_cost": int(_opts["cost%d" % int(g["hand"])])})
		var full: Dictionary = CzAiArena.play(content, MatchState.route_from_letter(g["route"]),
				CzAI.for_level(StringName(g["p1"]), 1), CzAI.for_level(StringName(g["p2"]), 2), {0: g["a"], 1: g["b"]})
		var end: MatchState = full["state"]
		var start: int = int(g["turn_start"][ti])
		var errors: Array = []
		var at: MatchState = LoadoutRules.replay(end.origin, end.actions.slice(0, start), content, errors)
		var seat: int = int(g["turn_seat"][ti])
		var times: Array = []
		for rep: int in 5:
			var ai: CzAI = CzAI.for_level(StringName(g["p%d" % (seat + 1)]), 1)
			var other: CzAI = CzAI.for_level(StringName(g["p%d" % (2 - seat)]), 2)
			times.append(CzAiArena.time_turn(at, ai, other))
		times.sort()
		worst_median = maxf(worst_median, float(times[2]))
		print("| hand %d %s %s/%s | round %d, P%d | %.1f | %.1f | %.1f | %.1f |" % [g["hand"], g["route"], g["a"], g["b"],
				at.round_number, seat + 1, turns[k][0], times[2], times[0], times[4]])
	print("Worst re-timed turn (median of 5): %.1f ms" % worst_median)


func _game(content: RulesData, hand: int, route_text: String, route: int, a: String, b: String) -> Dictionary:
	var p1: CzAI = CzAI.for_level(StringName(_opts["p1"]), 1)
	var p2: CzAI = CzAI.for_level(StringName(_opts["p2"]), 2)
	for ai: CzAI in [p1, p2]:
		if ai is CzVeteranAI and String(_opts["cap"]) != "":
			(ai as CzVeteranAI).cap_base = int(_opts["cap"])
		if ai is CzVeteranAI and String(_opts["wv"]) != "":
			for kv: String in String(_opts["wv"]).split(","):
				var parts: PackedStringArray = kv.split(":")
				(ai as CzVeteranAI).weights[parts[0]] = float(parts[1])
	var r: Dictionary = CzAiArena.play(content, route, p1, p2, {0: a, 1: b})
	var st: MatchState = r["state"]
	var both: bool = st.seats[0].eliminated and st.seats[1].eliminated
	var how: String = String(r["cause"])
	if both:
		how = "both_out"
	return {"hand": hand, "route": route_text, "a": a, "b": b, "p1": _opts["p1"], "p2": _opts["p2"],
			"result": r["result"], "winner": r["winner"], "how": how, "rounds": r["rounds"],
			"hp": r["health"], "illegal": r["illegal"], "max_turn_ms": r["max_turn_ms"],
			"brace_ms_max": r["brace_ms_max"], "turn_ms": r["turn_ms"], "turn_start": r["turn_start"],
			"turn_seat": r["turn_seat"], "actions": r["actions"]}


func _report(rows: Array) -> void:
	if rows.is_empty():
		print("no games")
		return
	var p1: String = rows[0]["p1"]
	var p2: String = rows[0]["p2"]
	print("\n## %s (P1) vs %s (P2): %d games\n" % [p1, p2, rows.size()])
	print("| Hand | Route | P1 wins | P2 wins | Draws | Shot / gas / final circle / both out / hard end | Median last round (range) | Earliest elimination |")
	print("|---|---|---|---|---|---|---|---|")
	var hands: Array = []
	var routes: Array = []
	for g: Dictionary in rows:
		if not hands.has(int(g["hand"])):
			hands.append(int(g["hand"]))
		if not routes.has(String(g["route"])):
			routes.append(String(g["route"]))
	for hand: int in hands:
		for route: String in routes:
			var sub: Array = rows.filter(func(g: Dictionary) -> bool: return int(g["hand"]) == hand and String(g["route"]) == route)
			if not sub.is_empty():
				print(_row("%d | %s" % [hand, route], sub))
	for hand: int in hands:
		var sub: Array = rows.filter(func(g: Dictionary) -> bool: return int(g["hand"]) == hand)
		print(_row("%d | **all**" % hand, sub))
	# Timings.
	var all_ms: Array = []
	var illegal: int = 0
	for g: Dictionary in rows:
		all_ms.append_array(g["turn_ms"])
		illegal += int(g["illegal"])
	all_ms.sort()
	var n: int = all_ms.size()
	print("\nAI turns: %d; per turn median %.1f ms, p95 %.1f, p99 %.1f, max %.1f; illegal actions: %d" % [
			n, all_ms[n / 2], all_ms[int(n * 0.95)], all_ms[int(n * 0.99)], all_ms[n - 1], illegal])
	# Drop-pair detail for each hand and route: first-player wins by P1 drop.
	print("\nP1 wins by P1 drop (rows) and P2 drop (columns), all routes:")
	for hand: int in hands:
		print("\nHand %d | %s |" % [hand, " | ".join(OUTER.map(func(x: String) -> String: return LABEL[x]))])
		for a: String in OUTER:
			var cells: Array = []
			for b: String in OUTER:
				var w: int = 0
				var t: int = 0
				for g: Dictionary in rows:
					if int(g["hand"]) == hand and g["a"] == a and g["b"] == b:
						t += 1
						if int(g["winner"]) == 0:
							w += 1
				cells.append("%d/%d" % [w, t])
			print("%s | %s" % [LABEL[a], " | ".join(cells)])


func _row(label: String, sub: Array) -> String:
	var n: int = sub.size()
	var w1: int = 0
	var w2: int = 0
	var hows: Dictionary = {"shot": 0, "frag": 0, "gas": 0, "final_circle": 0, "both_out": 0, "hard_end": 0}
	var rounds: Array = []
	var earliest: int = 99
	for g: Dictionary in sub:
		if int(g["winner"]) == 0:
			w1 += 1
		elif int(g["winner"]) == 1:
			w2 += 1
		var how: String = g["how"]
		hows[how] = int(hows.get(how, 0)) + 1
		rounds.append(int(g["rounds"]))
		if how != "hard_end":
			earliest = mini(earliest, int(g["rounds"]))
	rounds.sort()
	var med: float = float(rounds[n / 2]) if n % 2 == 1 else (rounds[n / 2 - 1] + rounds[n / 2]) / 2.0
	return "| %s | %d/%d (%d%%) | %d | %d | %d / %d / %d / %d / %d | %s (%d-%d) | %s |" % [label, w1, n,
			roundi(100.0 * w1 / n), w2, n - w1 - w2, hows["shot"] + hows["frag"], hows["gas"], hows["final_circle"],
			hows["both_out"], hows["hard_end"], str(med), rounds[0], rounds[n - 1],
			"round %d" % earliest if earliest < 99 else "-"]
