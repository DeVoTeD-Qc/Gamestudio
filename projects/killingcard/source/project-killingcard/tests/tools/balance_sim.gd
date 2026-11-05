# balance_sim.gd
# Purpose: p19 headless balance harness. Plays logged matches and full runs with the
#   real rules engine, real data and the real enemy AI (AiPlayer per squad), with
#   up to three PLAYER proxies:
#     competent - AiPlanner on the player side (weights dealt 2 / taken 0.5 / zone 2 /
#                 deny 3, push 0.6, always the best plan, takes its mulligan): the best
#                 of ~20 planner settings swept in p19. A solid player who reads the board.
#     casual    - the same planner, less sharp (dealt 1.5 / taken 0.8 / deny 1), plays its
#                 second-best plan 60% of the time, values cards in hand more and holds
#                 Lethal / Tactical / killstreaks longer. A new or sloppy player.
#     greedy    - tests/mode_sim.gd's greedy policy (the old reference; weak).
#   Reports, per proxy: win rate per run slot x mode (both modes for every slot, with
#   the starter kit), rounds per match, end reasons, unspent Supply per round, streaks,
#   killstreak earn / use, Operator downs, card play rate and win-rate-when-played, and
#   full 5-match runs (RunProgress, offers taken by a fixed rule) with run win rate,
#   matches played and an estimated real-time run length.
#
#   Run (from the project folder):
#     godot --headless --path . -s res://tests/tools/balance_sim.gd -- [options]
#   Options (all optional):
#     seeds=N        matches per slot x mode per proxy (default 20)
#     runs=N         full runs per proxy (default 40)
#     proxies=a,b    competent,casual,greedy (default competent,casual)
#     slots=1,2      match block: only these run slots (1-based); modes=run: only each slot's own mode
#     json=PATH      also write the results as JSON (for before / after tables)
#     offers=fields  runs: Supply Drops prefer a Field (then the most expensive unit), to
#                    see Fields across a whole run (kc-field-impl snowball check)
#     proxy=NAME.FIELD=VALUE   player-proxy AiPersonality override (e.g. competent.weight_deny_streak=1.0;
#                    competent@1.FIELD=VALUE applies only in Firefight, @0 only in Zone Control)
#     set=TARGET.FIELD=VALUE   in-memory data override for what-if tuning (repeatable):
#        run.firefight_target=6 · slot3.enemy_armor_bonus=0 · squad_rusher.second_best_chance=0.3
#        breacher.cost=2 (any card / loadout / squad id under res://data) · squad_rusher.primary=@kestrel_ar7
#     synoffers=1    kc-syn: turn on the run's synergy offers (Doctrine, Promotion, Retire, Regroup)
#     aware=0|1      kc-syn: the player proxy plans links / sets (default 1)
#     squadaware=0|1 kc-syn: the squads' AI plans links / sets (default 1)
#     syn=0          kc-syn control: no links and no sets anywhere (SynergyRules.enabled = false)
#   Overrides never touch the files; edit the .tres (and gen_content.gd) to keep a change.
#
#   Real-time estimate (stated assumption, not measured): a round takes
#     ROUND_BASE_S (read the board, red dots, READY) + PLAY_S per player play (card, item,
#     Operator place / Rotate) + RESOLVE_S (Reveal + Firefight animations at normal speed),
#   Round 1 adds MULLIGAN_S; each match adds BETWEEN_MATCH_S (RunMap, result banner,
#   After-Action, offers) and a run adds RUN_SETUP_S (Title + Loadout).
# Author: Mid Game Designer Agent
extends SceneTree

const Sim = preload("res://tests/mode_sim.gd")

const ROUND_BASE_S: float = 12.0
const PLAY_S: float = 5.0
const RESOLVE_S: float = 10.0
const MULLIGAN_S: float = 10.0
const BETWEEN_MATCH_S: float = 45.0
const RUN_SETUP_S: float = 60.0

const PROXIES: Array[String] = ["competent", "casual", "greedy"]
const MODE_NAMES: Dictionary = {0: "ZC", 1: "FF", 2: "DET"}

var seeds: int = 20
var runs: int = 40
var proxies: Array[String] = ["competent", "casual"]
var json_path: String = ""
## Match block filters: 1-based slot numbers, and "run" = only the slot's own mode.
var only_slots: Array[int] = []
var only_run_mode: bool = false
var config: RunConfig = null
var out: Dictionary = {}
## Proxy personality overrides from `proxy=NAME.FIELD=VALUE` (what-if on the player side).
var proxy_overrides: Dictionary = {}
## Run offer rule: "" (most expensive unit) or "fields" (prefer Fields).
var offer_rule: String = ""
## kc-syn: synergy-aware planning for the player proxy / the squads.
var proxy_aware: bool = true
var squad_aware: bool = true


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	var overrides: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"seeds": seeds = int(kv[1])
			"runs": runs = int(kv[1])
			"proxies":
				proxies.clear()
				for p: String in kv[1].split(","):
					proxies.append(p)
			"json": json_path = kv[1]
			"offers": offer_rule = kv[1]
			"synoffers": config.synergy_offers = kv[1] == "1"
			"aware": proxy_aware = kv[1] != "0"
			"squadaware": squad_aware = kv[1] != "0"
			"syn": SynergyRules.enabled = kv[1] != "0"
			"slots":
				for n: String in kv[1].split(","):
					only_slots.append(int(n))
			"modes": only_run_mode = kv[1] == "run"
			"set": overrides.append(kv[1])
			"swap": overrides.append("swap:" + kv[1])
			"proxy":
				var pv: PackedStringArray = kv[1].split("=", true, 1)
				var pf: PackedStringArray = pv[0].split(".", true, 1)
				proxy_overrides.get_or_add(pf[0], {})[pf[1]] = str_to_var(pv[1])
			_: push_error("balance_sim: unknown option " + arg)
	for o: String in overrides:
		_apply_override(o)
	out = {"seeds": seeds, "runs": runs, "overrides": overrides, "proxies": {}}
	var t0: int = Time.get_ticks_msec()
	out["proxy_overrides"] = proxy_overrides
	print("balance_sim: seeds=%d runs=%d proxies=%s overrides=%s proxy overrides=%s" % [seeds, runs, proxies, overrides, proxy_overrides])
	print("time model: round = %.0fs + %.0fs/play + %.0fs resolve (+%.0fs mulligan R1); +%.0fs per match; +%.0fs per run" % [
			ROUND_BASE_S, PLAY_S, RESOLVE_S, MULLIGAN_S, BETWEEN_MATCH_S, RUN_SETUP_S])
	for proxy: String in proxies:
		var res: Dictionary = {}
		res["matches"] = _match_block(proxy)
		res["runs"] = _run_block(proxy)
		out["proxies"][proxy] = res
	print("\nbalance_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if json_path != "":
		var f: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("wrote " + json_path)
	quit(0)


# =============================================================================
# Overrides (what-if, in memory)
# =============================================================================

func _find_data(id: String) -> Resource:
	for dir: String in ["cards", "loadout", "squads"]:
		var path: String = "res://data/%s/%s.tres" % [dir, id]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## swap=TARGET.LIST:old>new  replaces the first `old` entry of a resource list with `new`
## (old empty = append, new empty = remove), e.g. swap=squad_rusher.deck:breacher>rifleman,
## swap=run.starter_deck:callout>breacher, swap=squad_rusher.attachments:extended_mag>
func _apply_swap(o: String) -> void:
	var colon: int = o.find(":")
	var lhs: String = o.substr(0, colon)
	var pair: PackedStringArray = o.substr(colon + 1).split(">")
	var dot: int = lhs.rfind(".")
	var target: Resource = config if lhs.substr(0, dot) == "run" else _find_data(lhs.substr(0, dot))
	var list: Array = target.get(lhs.substr(dot + 1))
	var before: int = list.size()
	if pair[0] != "":
		for i: int in list.size():
			if String(list[i].id) == pair[0]:
				list.remove_at(i)
				break
	if pair[1] != "":
		list.append(_find_data(pair[1]))
	print("swap %s: %s -> %s (%d -> %d entries)" % [lhs, pair[0], pair[1], before, list.size()])


func _apply_override(o: String) -> void:
	if o.begins_with("swap:"):
		_apply_swap(o.substr(5))
		return
	var eq: int = o.find("=")
	var lhs: String = o.substr(0, eq)
	var raw: String = o.substr(eq + 1)
	var value: Variant = _find_data(raw.substr(1)) if raw.begins_with("@") else str_to_var(raw)
	var dot: int = lhs.rfind(".")
	var target_name: String = lhs.substr(0, dot)
	var field: String = lhs.substr(dot + 1)
	var target: Resource = null
	if target_name == "run":
		target = config
	elif target_name.begins_with("slot"):
		target = config.matches[int(target_name.substr(4)) - 1]
	else:
		for dir: String in ["cards", "loadout", "squads"]:
			var path: String = "res://data/%s/%s.tres" % [dir, target_name]
			if ResourceLoader.exists(path):
				target = load(path)
				break
	if target == null or not (field in target):
		push_error("balance_sim: bad override " + o)
		return
	var cur: Variant = target.get(field)
	if cur is PackedInt32Array and value is Array:
		value = PackedInt32Array(value)
	target.set(field, value)
	print("override %s.%s: %s -> %s" % [target_name, field, cur, target.get(field)])


# =============================================================================
# Player proxies
# =============================================================================

func _player_ai(proxy: String, mode: int = -1) -> AiPlayer:
	if proxy == "greedy":
		return null
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	# Competent: the best-performing planner settings found in the p19 sweep (see
	# balance-log.md): values its own damage over caution and pushes into held zones.
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	if proxy == "casual":
		# Casual: same instincts, less sharp; often the second-best line, holds cards,
		# grenades and killstreaks too long, ignores the enemy streak.
		p.weight_damage_dealt = 1.5
		p.weight_damage_taken = 0.8
		p.push_bonus = 0.3
		p.second_best_chance = 0.6
		p.card_keep_cost = 0.6
		p.cooldown_keep_cost = 1.0
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	for key: String in [proxy, "%s@%d" % [proxy, mode]]:
		var po: Dictionary = proxy_overrides.get(key, {})
		for f: String in po:
			p.set(f, po[f])
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = proxy_aware
	return ai


func _squad_ai(squad: SquadData) -> AiPlayer:
	var ai: AiPlayer = AiPlayer.for_squad(squad)
	ai.planner.synergy_aware = squad_aware
	return ai


## Plays m to the end. Returns the per-match log.
func _play(m: MatchState, enemy: AiPlayer, player: AiPlayer) -> Dictionary:
	var log: Dictionary = {"unspent": [], "plays": [], "enemy_unspent": []}
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		enemy.take_turn(m, MatchState.ENEMY)
		var before: int = m.sides[MatchState.PLAYER].plays.size()
		if player != null:
			player.take_turn(m, MatchState.PLAYER, false)
		else:
			Sim._greedy_deploy(m, MatchState.PLAYER)
		log["unspent"].append(m.sides[MatchState.PLAYER].supply)
		log["enemy_unspent"].append(m.sides[MatchState.ENEMY].supply)
		log["plays"].append(m.sides[MatchState.PLAYER].plays.size() - before)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	return _summarize(m, log)


func _summarize(m: MatchState, log: Dictionary) -> Dictionary:
	var player_ks: Array[StringName] = []
	for it: LoadoutItem in m.sides[0].setup.killstreaks:
		player_ks.append(it.id)
	var cards: Dictionary = {}
	var ks_earned: Dictionary = {}
	var ks_used: Dictionary = {}
	var max_streak: int = 0
	var op_downs: int = 0
	var enemy_op_downs: int = 0
	var reason: String = ""
	# kc-field-impl: visible Fields per side as [rounds standing, how it left], for the
	# snowball check (traps are left out: they are one-shot).
	var placed_at: Dictionary = {}
	var fields: Array = [[], []]
	## Sign of the player's score lead after Round 3 (snowball check: does the leader win more?).
	var lead3: int = 0
	for e: Dictionary in m.events:
		var side: StringName = StringName(str(e.get("side", "")))
		match e["type"]:
			RulesEvent.CARD_PLAYED:
				if side == &"player" and StringName(e["card_id"]) != m.sides[0].setup.primary.id:
					cards[String(e["card_id"])] = int(cards.get(String(e["card_id"]), 0)) + 1
			RulesEvent.STREAK_CHANGED:
				if side == &"player":
					max_streak = maxi(max_streak, int(e["streak"]))
			RulesEvent.KILLSTREAK_EARNED:
				if side == &"player":
					ks_earned[String(e["item_id"])] = int(ks_earned.get(String(e["item_id"]), 0)) + 1
			RulesEvent.ITEM_USED:
				if side == &"player" and StringName(e["item_id"]) in player_ks:
					ks_used[String(e["item_id"])] = int(ks_used.get(String(e["item_id"]), 0)) + 1
			RulesEvent.OPERATOR_DOWN:
				if side == &"player":
					op_downs += 1
				else:
					enemy_op_downs += 1
			RulesEvent.MATCH_ENDED:
				reason = str(e.get("reason", ""))
			RulesEvent.ROUND_ENDED:
				if int(e["round"]) == 3:
					lead3 = signi(int(e["player_score"]) - int(e["enemy_score"]))
			RulesEvent.EQUIPMENT_PLACED:
				if not bool(e.get("hidden", false)):
					placed_at[int(e["card_uid"])] = [side, int(e["round"])]
			RulesEvent.EQUIPMENT_DESTROYED:
				var uid: int = int(e["card_uid"])
				if placed_at.has(uid):
					var who: int = 0 if placed_at[uid][0] == &"player" else 1
					fields[who].append([int(e["round"]) - int(placed_at[uid][1]) + 1, str(e.get("reason", "destroyed"))])
					placed_at.erase(uid)
	for uid: int in placed_at:
		var who: int = 0 if placed_at[uid][0] == &"player" else 1
		fields[who].append([m.round_number - int(placed_at[uid][1]), "standing"])
	var plays: int = 0
	for n: int in log["plays"]:
		plays += n
	var rounds: int = log["unspent"].size()
	var seconds: float = rounds * (ROUND_BASE_S + RESOLVE_S) + plays * PLAY_S + MULLIGAN_S
	return {"result": String(m.result), "rounds": rounds, "reason": reason, "unspent": log["unspent"],
			"enemy_unspent": log["enemy_unspent"], "plays": plays, "cards": cards, "max_streak": max_streak,
			"ks_earned": ks_earned, "ks_used": ks_used, "op_downs": op_downs, "enemy_op_downs": enemy_op_downs,
			"score": [m.sides[0].score, m.sides[1].score], "seconds": seconds, "fields": fields, "lead3": lead3}


# =============================================================================
# Match block: every run slot in both modes, starter kit
# =============================================================================

func _match_block(proxy: String) -> Dictionary:
	print("\n================ %s proxy: matches (starter kit, %d seeds per slot x mode) ================" % [proxy.to_upper(), seeds])
	var rows: Dictionary = {}
	var all: Array[Dictionary] = []
	print("%-34s %6s %6s %5s %6s %8s %6s %6s %6s  %s" % ["slot / mode", "win%", "loss%", "draw", "rounds", "unspent", "ks>=1", "opDn%", "min", "end reasons"])
	for i: int in config.matches.size():
		var slot: RunMatchData = config.matches[i]
		if not only_slots.is_empty() and (i + 1) not in only_slots:
			continue
		for mode: int in [DataEnums.GameMode.ZONE_CONTROL, DataEnums.GameMode.FIREFIGHT]:
			if only_run_mode and mode != slot.mode:
				continue
			var logs: Array[Dictionary] = []
			for s: int in seeds:
				var seed_value: int = 50000 + i * 1000 + mode * 500 + s
				var m: MatchState = Sim.match_for(config, slot, seed_value, mode)
				logs.append(_play(m, _squad_ai(slot.squad), _player_ai(proxy, mode)))
			var label: String = "M%d B%d%s %s %s%s" % [i + 1, slot.bracket, " RIVAL" if slot.is_rival else "",
					slot.squad.id.trim_prefix("squad_"), MODE_NAMES[mode], " *" if mode == slot.mode else ""]
			var agg: Dictionary = _aggregate(logs)
			rows[label] = agg
			all.append_array(logs)
			print("%-34s %5.0f%% %5.0f%% %5d %6.2f %8.2f %5.0f%% %5.0f%% %6.1f  %s" % [label, agg["win"] * 100, agg["loss"] * 100,
					agg["draws"], agg["rounds"], agg["unspent"], agg["ks_used_match"] * 100, agg["op_down_match"] * 100,
					agg["minutes"], agg["reasons"]])
	print("(* = the mode this slot uses in the run)")
	var total: Dictionary = _aggregate(all)
	print("ALL: win %.0f%%  loss %.0f%%  rounds %.2f (min %d max %d)  unspent %.2f/round (median %.1f)  plays/round %.2f  match %.1f min" % [
			total["win"] * 100, total["loss"] * 100, total["rounds"], total["rounds_min"], total["rounds_max"],
			total["unspent"], total["unspent_median"], total["plays_round"], total["minutes"]])
	print("     max streak avg %.2f  killstreaks earned %.2f / used %.2f per match  matches with >=1 used %.0f%%  Operator down >=1 %.0f%%" % [
			total["max_streak"], total["ks_earned_match"], total["ks_used_hits"], total["ks_used_match"] * 100, total["op_down_match"] * 100])
	print("     enemy unspent %.2f/round  rounds histogram %s" % [total["enemy_unspent"], total["rounds_hist"]])
	print("     killstreaks earned %s  used %s" % [total["ks_earned"], total["ks_used"]])
	_print_cards(total)
	_print_fields(total)
	return {"rows": rows, "total": _strip(total)}


func _aggregate(logs: Array[Dictionary]) -> Dictionary:
	var n: int = logs.size()
	var a: Dictionary = {"n": n, "win": 0.0, "loss": 0.0, "draws": 0, "rounds": 0.0, "rounds_min": 99, "rounds_max": 0,
			"unspent": 0.0, "enemy_unspent": 0.0, "plays_round": 0.0, "max_streak": 0.0, "ks_earned_match": 0.0,
			"ks_used_hits": 0.0, "ks_used_match": 0.0, "op_down_match": 0.0, "minutes": 0.0, "reasons": {},
			"rounds_hist": {}, "ks_earned": {}, "ks_used": {}, "cards": {},
			"fields": {"player": 0, "enemy": 0, "rounds": [0, 0], "gone": {}, "more_n": 0, "more_win": 0, "fewer_n": 0, "fewer_win": 0,
				"any_n": 0, "any_win": 0}, "lead_n": 0, "lead_win": 0}
	var unspent_all: Array = []
	var enemy_unspent: Array = []
	var total_rounds: int = 0
	var total_plays: int = 0
	for l: Dictionary in logs:
		if l["result"] == "player":
			a["win"] += 1
		elif l["result"] == "enemy":
			a["loss"] += 1
		else:
			a["draws"] += 1
		a["rounds"] += l["rounds"]
		a["rounds_min"] = mini(a["rounds_min"], l["rounds"])
		a["rounds_max"] = maxi(a["rounds_max"], l["rounds"])
		a["rounds_hist"][l["rounds"]] = int(a["rounds_hist"].get(l["rounds"], 0)) + 1
		a["reasons"][l["reason"]] = int(a["reasons"].get(l["reason"], 0)) + 1
		unspent_all.append_array(l["unspent"])
		enemy_unspent.append_array(l["enemy_unspent"])
		total_rounds += l["rounds"]
		total_plays += l["plays"]
		a["max_streak"] += l["max_streak"]
		a["minutes"] += l["seconds"] / 60.0
		var earned: int = 0
		for k: String in l["ks_earned"]:
			earned += l["ks_earned"][k]
			a["ks_earned"][k] = int(a["ks_earned"].get(k, 0)) + l["ks_earned"][k]
		var used: int = 0
		for k: String in l["ks_used"]:
			used += l["ks_used"][k]
			a["ks_used"][k] = int(a["ks_used"].get(k, 0)) + l["ks_used"][k]
		a["ks_earned_match"] += earned
		a["ks_used_hits"] += used
		a["ks_used_match"] += 1.0 if used > 0 else 0.0
		a["op_down_match"] += 1.0 if l["op_downs"] > 0 else 0.0
		var fa: Dictionary = a["fields"]
		var fr: Array[int] = [0, 0]
		for who: int in 2:
			for f: Array in l.get("fields", [[], []])[who]:
				fa["player" if who == 0 else "enemy"] += 1
				fa["rounds"][who] += int(f[0])
				fr[who] += int(f[0])
				var key: String = ("P " if who == 0 else "E ") + str(f[1])
				fa["gone"][key] = int(fa["gone"].get(key, 0)) + 1
		var won: int = 1 if l["result"] == "player" else 0
		var lead: int = int(l.get("lead3", 0))
		if lead != 0 and l["rounds"] > 3:
			a["lead_n"] += 1
			a["lead_win"] += 1 if (lead > 0 and won == 1) or (lead < 0 and l["result"] == "enemy") else 0
		if fr[0] > 0:
			fa["any_n"] += 1
			fa["any_win"] += won
		if fr[0] > fr[1]:
			fa["more_n"] += 1
			fa["more_win"] += won
		elif fr[0] < fr[1]:
			fa["fewer_n"] += 1
			fa["fewer_win"] += won
		for c: String in l["cards"]:
			var row: Array = a["cards"].get(c, [0, 0, 0])
			row[0] += 1
			row[1] += 1 if l["result"] == "player" else 0
			row[2] += l["cards"][c]
			a["cards"][c] = row
	var fn: float = maxf(1.0, n)
	for k: String in ["win", "loss", "rounds", "max_streak", "ks_earned_match", "ks_used_hits", "ks_used_match", "op_down_match", "minutes"]:
		a[k] = a[k] / fn
	a["unspent"] = _mean(unspent_all)
	a["unspent_median"] = _median(unspent_all)
	a["enemy_unspent"] = _mean(enemy_unspent)
	a["plays_round"] = float(total_plays) / maxf(1.0, total_rounds)
	return a


## Field summary: placements, average rounds standing, how they left, and the player's win
## rate when it had more / fewer Field-rounds than the enemy (snowball check).
func _print_fields(a: Dictionary) -> void:
	var fa: Dictionary = a["fields"]
	print("     leader after Round 3 wins %.0f%% (n %d)" % [100.0 * a["lead_win"] / maxf(1, a["lead_n"]), a["lead_n"]])
	if int(fa["player"]) + int(fa["enemy"]) == 0:
		print("     fields: none placed")
		return
	print("     fields (visible): placed/match P %.2f E %.2f, avg rounds standing P %.2f E %.2f, gone %s" % [
			float(fa["player"]) / maxf(1, a["n"]), float(fa["enemy"]) / maxf(1, a["n"]),
			float(fa["rounds"][0]) / maxf(1, fa["player"]), float(fa["rounds"][1]) / maxf(1, fa["enemy"]), fa["gone"]])
	print("     player win%% with >=1 Field %.0f%% (n %d) | more Field-rounds than enemy %.0f%% (n %d) | fewer %.0f%% (n %d)" % [
			100.0 * fa["any_win"] / maxf(1, fa["any_n"]), fa["any_n"], 100.0 * fa["more_win"] / maxf(1, fa["more_n"]), fa["more_n"],
			100.0 * fa["fewer_win"] / maxf(1, fa["fewer_n"]), fa["fewer_n"]])


func _print_cards(a: Dictionary) -> void:
	var ids: Array = a["cards"].keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return a["cards"][x][0] > a["cards"][y][0])
	var line: String = "     card: played-in% (win%-when-played, copies/match):"
	var parts: Array[String] = []
	for c: String in ids:
		var row: Array = a["cards"][c]
		parts.append("%s %.0f%% (%.0f%%, %.2f)" % [c, 100.0 * row[0] / maxf(1, a["n"]), 100.0 * row[1] / maxf(1, row[0]), float(row[2]) / maxf(1, a["n"])])
	print(line)
	for i: int in range(0, parts.size(), 4):
		print("       " + ", ".join(parts.slice(i, i + 4)))


func _strip(a: Dictionary) -> Dictionary:
	var c: Dictionary = a.duplicate(true)
	return c


func _mean(list: Array) -> float:
	var s: float = 0.0
	for v: Variant in list:
		s += float(v)
	return s / maxf(1.0, list.size())


func _median(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var l: Array = list.duplicate()
	l.sort()
	return float(l[l.size() / 2])


# =============================================================================
# Run block: full 5-match runs
# =============================================================================

## Offer rule: Supply Drop = the most expensive offered unit (ties: first), else option 0;
## weapon level and Perk = option 0. Same rule for every proxy (offers are seeded).
## kc-syn: the Supply Drop takes its on-trait slot 1 when that is a unit or a Field; Doctrine takes
## the deck's best trait (option 0), Promotion and Regroup their first option (Recruits first).
func _choose(r: RunProgress) -> int:
	var offer: Dictionary = r.current_offer()
	if offer["kind"] != RewardOffers.KIND_SUPPLY_DROP:
		return 0
	if offer.has("on_trait"):
		var c0: CardData = r.resource(offer["options"][0]) as CardData
		if c0 != null and c0.card_type != DataEnums.CardType.TACTIC:
			return 0
	var best: int = 0
	var best_cost: int = -1
	if offer_rule == "fields":
		for i: int in offer["options"].size():
			var f: CardData = r.resource(offer["options"][i]) as CardData
			if f != null and f.is_visible_field():
				return i
	for i: int in offer["options"].size():
		var c: CardData = r.resource(offer["options"][i]) as CardData
		if c != null and c.card_type == DataEnums.CardType.UNIT and c.cost > best_cost:
			best = i
			best_cost = c.cost
	return best


func _run_block(proxy: String) -> Dictionary:
	var victories: int = 0
	var played_hist: Dictionary = {}
	var slot_logs: Array = []
	for i: int in config.matches.size():
		slot_logs.append([])
	var all: Array[Dictionary] = []
	var run_minutes: Array = []
	var win_minutes: Array = []
	var tickets_left: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	for s: int in runs:
		var r: RunProgress = RunProgress.create(config, 900000 + s)
		r.begin()
		var seconds: float = RUN_SETUP_S
		while not r.is_over():
			var idx: int = r.match_index
			var md: RunMatchData = r.current_match()
			var m: MatchState = r.create_match()
			m.start_match()
			var l: Dictionary = _play(m, _squad_ai(md.squad), _player_ai(proxy, md.mode))
			slot_logs[idx].append(l)
			all.append(l)
			seconds += l["seconds"] + BETWEEN_MATCH_S
			r.record_match(m)
			while not r.current_offer().is_empty():
				# kc-syn: Retire a Recruit with a twin instead of a card once the deck has 22+ cards.
				var off: Dictionary = r.current_offer()
				if off.get("retire", false) and r.deck.size() >= 22 and not r.retire_options().is_empty() \
						and int(r.retire_options()[0]["twin_index"]) >= 0:
					r.retire_card(0)
					continue
				r.choose_offer(_choose(r))
		if r.is_victory():
			victories += 1
			win_minutes.append(seconds / 60.0)
			tickets_left[r.tickets] = int(tickets_left.get(r.tickets, 0)) + 1
		played_hist[r.matches_played()] = int(played_hist.get(r.matches_played(), 0)) + 1
		run_minutes.append(seconds / 60.0)
	print("\n---------------- %s proxy: %d full runs (%.1f s) ----------------" % [proxy.to_upper(), runs, (Time.get_ticks_msec() - t0) / 1000.0])
	var slots: Array = []
	for i: int in slot_logs.size():
		var logs: Array[Dictionary] = []
		logs.assign(slot_logs[i])
		var agg: Dictionary = _aggregate(logs)
		var md: RunMatchData = config.matches[i]
		print("  M%d B%d %s %s: reached %d, win %.0f%% loss %.0f%% draw %d, rounds %.2f, unspent %.2f" % [i + 1, md.bracket,
				md.squad.id.trim_prefix("squad_"), MODE_NAMES[md.mode], agg["n"], agg["win"] * 100, agg["loss"] * 100, agg["draws"],
				agg["rounds"], agg["unspent"]])
		slots.append({"reached": agg["n"], "win": agg["win"], "loss": agg["loss"], "draws": agg["draws"], "rounds": agg["rounds"]})
	var total: Dictionary = _aggregate(all)
	run_minutes.sort()
	var full_minutes: Array = []
	print("  RUN WIN %d/%d (%.0f%%)  matches played %s  tickets left on wins %s" % [victories, runs, 100.0 * victories / maxf(1, runs), played_hist, tickets_left])
	print("  in-run matches: win %.0f%%  rounds %.2f  unspent %.2f/round  ks>=1 used %.0f%%  Operator down >=1 %.0f%%" % [
			total["win"] * 100, total["rounds"], total["unspent"], total["ks_used_match"] * 100, total["op_down_match"] * 100])
	print("  est. run length: median %.1f min (all runs), winning runs avg %.1f min, avg match %.1f min" % [
			_median(run_minutes), _mean(win_minutes), total["minutes"]])
	print("  5-match run at this pace: %.1f min" % (RUN_SETUP_S / 60.0 + 5 * (total["minutes"] + BETWEEN_MATCH_S / 60.0)))
	_print_cards(total)
	_print_fields(total)
	return {"run_win": float(victories) / maxf(1, runs), "played": played_hist, "slots": slots,
			"median_run_min": _median(run_minutes), "win_run_min": _mean(win_minutes),
			"five_match_min": RUN_SETUP_S / 60.0 + 5 * (total["minutes"] + BETWEEN_MATCH_S / 60.0), "total": total}
