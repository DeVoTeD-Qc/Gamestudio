# sim_duels.gd
# Purpose: Headless balance simulation (plan cc06). Plays seeded AI-vs-AI duels with the real
#   rules engine and the real rival data, and prints a Markdown report: win rate per rival
#   pairing, first-player win rate, average score, tie rate, and Warden move timings.
#   godot --headless --path . -s res://tests/tools/sim_duels.gd -- [options]
#     --duels=1000         duels in total, split evenly over the pairings
#     --seed=1             base seed (duel i uses seed + i for the coin flip and both brains)
#     --tie=first|draw     tie rule override (default: data/balance.tres)
#     --second_bonus=N     knob test: +N points to the second player at the end (sim only)
#     --first_bonus=N      knob test: +N points to the first player at the end (sim only)
#     --first_sig_bonus=N  knob test: +N to the first player if they control their own Signature
#                          at the end (sim only)
#     --knobs=a:1,b:0      BalanceConfig overrides, e.g. chain_captures:1,ambush_spring_bonus:2
#     --pairs=all|mixed|mirror  which pairings (default all: 3 mirrors + 3 mixed)
#     --warden_nodes=N     WardenAI.max_nodes override
#   Never writes data/; knob overrides only change an in-memory copy of the balance.
# Dependencies: RivalAI, WallRules, WallState, RivalData, BalanceConfig, TriptychData.
# Author: Mechanics Developer Agent
extends SceneTree

const RIVALS: Array[String] = ["quartermaster", "archivist", "warden"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var duels: int = int(args.get("duels", "1000"))
	var base_seed: int = int(args.get("seed", "1"))
	var second_bonus: int = int(args.get("second_bonus", "0")) - int(args.get("first_bonus", "0"))
	var warden_nodes: int = int(args.get("warden_nodes", "0"))
	var first_sig_bonus: int = int(args.get("first_sig_bonus", "0"))
	var balance: BalanceConfig = (load("res://data/balance.tres") as BalanceConfig).duplicate()
	if args.has("tie"):
		balance.tie_winner = DataEnums.TieWinner.DRAW if args["tie"] == "draw" else DataEnums.TieWinner.FIRST_PLAYER
	for kv: String in str(args.get("knobs", "")).split(",", false):
		var parts: PackedStringArray = kv.split(":")
		if parts.size() != 2 or not parts[0] in balance:
			push_error("sim: unknown knob '%s'" % kv)
			continue
		var cur: Variant = balance.get(parts[0])
		balance.set(parts[0], bool(int(parts[1])) if cur is bool else int(parts[1]))
		print("knob %s = %s" % [parts[0], str(balance.get(parts[0]))])
	var triptychs: Array[TriptychData] = []
	for f: String in ["cold_signal", "midnight_run", "open_book"]:
		triptychs.append(load("res://data/triptychs/%s.tres" % f))
	var rivals: Dictionary = {}
	for id: String in RIVALS:
		rivals[id] = load("res://data/rivals/%s.tres" % id)
	var pairs: Array = []
	var mode: String = args.get("pairs", "all")
	for i: int in RIVALS.size():
		for j: int in range(i, RIVALS.size()):
			if (i == j and mode == "mixed") or (i != j and mode == "mirror"):
				continue
			pairs.append([RIVALS[i], RIVALS[j]])

	var total: Dictionary = _new_bucket()
	var per_pair: Array = []
	var warden_us: Array[int] = []
	var warden_nodes_seen: Array[int] = []
	var t0: int = Time.get_ticks_msec()
	var n: int = 0
	for p: int in pairs.size():
		var bucket: Dictionary = _new_bucket()
		bucket["pair"] = pairs[p]
		var count: int = duels / pairs.size() + (1 if p < duels % pairs.size() else 0)
		for k: int in count:
			var seed_value: int = base_seed + n
			n += 1
			var a: RivalData = rivals[pairs[p][0]]
			var b: RivalData = rivals[pairs[p][1]]
			var first: int = WallState.coin_flip(seed_value)
			var state: WallState = WallState.new_match(a.lineup, a.signature, b.lineup, b.signature, first,
					balance, RulesOptions.new(), triptychs)
			var brains: Array[RivalAI] = [RivalAI.for_rival(a, seed_value * 2 + 1), RivalAI.for_rival(b, seed_value * 2 + 2)]
			for br: RivalAI in brains:
				if br is WardenAI and warden_nodes > 0:
					(br as WardenAI).max_nodes = warden_nodes
			while not state.is_game_over():
				var me: int = state.to_move
				var brain: RivalAI = brains[me]
				var start: int = Time.get_ticks_usec()
				var move: Dictionary = brain.choose_move(state.copy(), me)
				var took: int = Time.get_ticks_usec() - start
				if brain is WardenAI:
					warden_us.append(took)
					warden_nodes_seen.append(brain.last_nodes)
				if move.is_empty():
					push_error("sim: %s had no move" % brain.brain_name())
					break
				var r: PlacementResult = WallRules.place(state, me, move["card"], move["slot"], move["copy_from"])
				if not r.ok:
					push_error("sim: illegal move %s" % r.error)
					break
			var res: Dictionary = _result(state, second_bonus, first_sig_bonus)
			for bk: Dictionary in [bucket, total]:
				_add(bk, res, first, pairs[p])
		per_pair.append(bucket)
	var secs: float = (Time.get_ticks_msec() - t0) / 1000.0
	_report(per_pair, total, warden_us, warden_nodes_seen, balance, second_bonus, base_seed, secs)
	quit(0)


## Final result with the sim-only bonuses applied.
func _result(state: WallState, second_bonus: int, first_sig_bonus: int = 0) -> Dictionary:
	var s: Array[int] = WallRules.scores(state)
	var second: int = WallState.other(state.first_player)
	s[second] += second_bonus  # Negative = a first-player bonus.
	if first_sig_bonus != 0:
		for slot: StringName in state.cells:
			var pc: PlacedCard = state.cells[slot]
			if pc.signature and pc.lineup == state.first_player and pc.controller == state.first_player:
				s[state.first_player] += first_sig_bonus
	var winner: int = WallState.NO_PLAYER
	var tie: bool = s[0] == s[1]
	if not tie:
		winner = WallState.P1 if s[0] > s[1] else WallState.P2
	elif state.balance.tie_winner == DataEnums.TieWinner.FIRST_PLAYER:
		winner = state.first_player
	return {"score": s, "winner": winner, "tie": tie, "first": state.first_player}


func _new_bucket() -> Dictionary:
	return {"n": 0, "first_wins": 0, "second_wins": 0, "draws": 0, "ties": 0, "p1_wins": 0, "p2_wins": 0,
		"score_sum": 0, "first_score": 0, "second_score": 0, "margin_sum": 0}


func _add(bk: Dictionary, res: Dictionary, first: int, _pair: Array) -> void:
	bk["n"] += 1
	var s: Array = res["score"]
	bk["score_sum"] += s[0] + s[1]
	bk["first_score"] += s[first]
	bk["second_score"] += s[WallState.other(first)]
	bk["margin_sum"] += absi(s[0] - s[1])
	if res["tie"]:
		bk["ties"] += 1
	if res["winner"] == WallState.NO_PLAYER:
		bk["draws"] += 1
	elif res["winner"] == first:
		bk["first_wins"] += 1
	else:
		bk["second_wins"] += 1
	if res["winner"] == WallState.P1:
		bk["p1_wins"] += 1
	elif res["winner"] == WallState.P2:
		bk["p2_wins"] += 1


func _pct(a: int, b: int) -> String:
	return "%.1f%%" % (100.0 * a / maxf(b, 1))


func _report(per_pair: Array, total: Dictionary, warden_us: Array[int], warden_nodes: Array[int],
		balance: BalanceConfig, second_bonus: int, base_seed: int, secs: float) -> void:
	print("## Sim: %d duels, seed %d, tie rule %s, second-player bonus %d (negative: first-player bonus) (%.1f s)" % [total["n"], base_seed,
			"first player" if balance.tie_winner == DataEnums.TieWinner.FIRST_PLAYER else "draw", second_bonus, secs])
	print("")
	print("| Pairing (A vs B) | Duels | A wins | B wins | Draws | First-player wins | Ties | Avg score (A+B) | Avg first / second |")
	print("|---|---|---|---|---|---|---|---|---|")
	for bk: Dictionary in per_pair + [total]:
		var name: String = "**All**" if not bk.has("pair") else "%s vs %s" % bk["pair"]
		var nn: int = bk["n"]
		print("| %s | %d | %s | %s | %s | %s | %s | %.2f | %.2f / %.2f |" % [name, nn, _pct(bk["p1_wins"], nn),
				_pct(bk["p2_wins"], nn), _pct(bk["draws"], nn), _pct(bk["first_wins"], nn), _pct(bk["ties"], nn),
				float(bk["score_sum"]) / maxf(nn, 1), float(bk["first_score"]) / maxf(nn, 1),
				float(bk["second_score"]) / maxf(nn, 1)])
	print("")
	var fw: int = total["first_wins"]
	var decided: int = total["n"] - total["draws"]
	print("FIRST_PLAYER_RATE %.4f (of all duels), %.4f (of decided duels); TIE_RATE %.4f" % [
			float(fw) / maxf(total["n"], 1), float(fw) / maxf(decided, 1), float(total["ties"]) / maxf(total["n"], 1)])
	if not warden_us.is_empty():
		var sorted: Array[int] = warden_us.duplicate()
		sorted.sort()
		var sum: int = 0
		for u: int in sorted:
			sum += u
		var nodes_sorted: Array[int] = warden_nodes.duplicate()
		nodes_sorted.sort()
		print("WARDEN_MOVE_MS moves=%d mean=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f nodes_p95=%d nodes_max=%d" % [
				sorted.size(), sum / 1000.0 / sorted.size(), sorted[sorted.size() / 2] / 1000.0,
				sorted[int(sorted.size() * 0.95)] / 1000.0, sorted[int(sorted.size() * 0.99)] / 1000.0, sorted[-1] / 1000.0,
				nodes_sorted[int(nodes_sorted.size() * 0.95)], nodes_sorted[-1]])
