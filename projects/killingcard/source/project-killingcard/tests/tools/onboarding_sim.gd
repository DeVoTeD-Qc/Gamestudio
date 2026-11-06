# onboarding_sim.gd
# Purpose: kc-onboard sim (documentation/design/onboarding-progression.md). A vanilla "Standard
#   Issue" starter (units with cost / FP / Armor only: no keyword, no trait, no weapon class) and a
#   discovery ladder through the 5-match run:
#     after M1  Supply Drop of CALLING CARDS: reward-pool units with a trait (from the art) but no
#               keyword yet ("Recruit" calling cards: stats + trait; printed keywords, the neighbor
#               keyword, effects and the LMG Pierce stay off until the copy trains)
#     after M2  Trained cards (keywords) + simple tactics, 2 picks of 4 (picks=2); each pick can REPLACE
#               a Standard Issue card (replace=1, replace_order); Promotion trains a Recruit calling card
#     after M3  + Fields
#     after M4  + Elites (the full pool)
#   After a loss: SALVAGE, a Supply Drop of loss_drop cards (pick 1); loss_drop=0 = the old Regroup
#   (a free Retire of a Standard Issue card). The first calling card picked sets the Doctrine.
#   Runs on the shipped engine (MatchState + SynergyRules + AiPlanner) like synergy_check.gd and
#   art_traits_sim.gd. Standard Issue cards and Recruit calling cards are sim-only CardData objects
#   (ids "si_<name>" and "<chassis>~cc"); a copy's trait goes through SideSetup.deck_traits.
#   Full runs are this file's own 5-match loop (3 tickets; weapon level / Perk / Promotion on the
#   run_config schedule; the pick rule is balance_sim's: the on-trait unit, else the most expensive unit).
#   Experiments:
#     slots   the starter kit vs every slot's squad in the slot's mode (n per slot), both proxies
#     runs    full 5-match runs with the ladder (runs=N): run win, per-match reach / win, end decks;
#             then, on the decks that reached M5: growth (late deck vs the starter, same loadout),
#             duel (aware vs blind, same late deck) and mirror (seat 0, starter and late decks)
#     mirror  seat 0 win rate of the starter mirror (n matches)
#     all     slots + runs
#   Options: exp=slots|runs|mirror|all n=N runs=N proxy=competent|casual|both base=si|recruit slots=1,2
#            deck=grunt*5,trooper*6,... (si names from si_stats or card ids) si=grunt:1/2/2,...
#            enemy=si,si+cc,cc,shipped,shipped (per slot: si | si+cc | cc (Recruit calling cards) |
#            trained | shipped) rusher=<spec> anchor=<spec> (the Standard Issue squad decks)
#            slotset=3.enemy_armor_bonus=0 (RunMatchData field, 1-based slot) squadswap=squad_id:from>to
#            squad_ai=P (second-best chance of the slot 1-2 squads) picks=N picks_from=N replace=0|1
#            replace_from=N replace_min=N replace_order=armored,sergeant,trooper,grunt loss_drop=N
#            thin=N thin_from=N (free Retires of Standard Issue cards per drop) kit=0|1 retire=never|bonus|always
#            retire_min=N cc=0|1 (M1 rewards as Recruit calling cards) lite=1 (slots 1-2: no Lethal / Tactical,
#            Recon Drone only, both sides) opcost=N set=card.prop=value (in memory)
#   Recommended package (onboarding-progression.md §6):
#     exp=runs runs=400 n=80 slotset=1.enemy_armor_bonus=-1 slotset=4.enemy_armor_bonus=0 picks=2 thin=1
#     enemy=si,si+cc,cc,shipped,shipped replace_order=armored,sergeant,trooper,grunt
#   Run: godot --headless --path . -s res://tests/tools/onboarding_sim.gd -- exp=all n=80 runs=200
# Author: Sr Game Designer Agent (kc-onboard)
extends SceneTree

const Sim = preload("res://tests/mode_sim.gd")

## Standard Issue chassis: [cost, FP, Armor]. All vanilla.
var si_stats: Dictionary = {
	"grunt": [1, 2, 2],
	"trooper": [2, 2, 3],
	"sergeant": [3, 3, 3],
	"armored": [4, 2, 5],
}
var starter_spec: String = "grunt*5,trooper*6,sergeant*4,armored*3,ammo_resupply*2"
var squad_specs: Dictionary = {
	"squad_rusher": "grunt*5,trooper*7,sergeant*3,armored*1,ammo_resupply*2",
	"squad_anchor": "grunt*4,trooper*4,sergeant*3,armored*4,ammo_resupply*1,hold_the_line*2",
}
var enemy_modes: Array[String] = ["si", "si", "shipped", "shipped", "shipped"]
var config: RunConfig = null
var n: int = 80
var runs: int = 100
var experiment: String = "all"
var proxies: Array[String] = ["competent", "casual"]
var base: String = "si"
var kit_bonus: bool = true
var retire_mode: String = "never"
var retire_min: int = 18
var cc_first: bool = true
var lite: bool = false
var cache: Dictionary = {}
var late_decks: Array = []
var only_slots: Array[int] = []
## Supply Drop picks can Replace a Standard Issue card (from match replace_from, at deck >= replace_min).
var replace: bool = true
var replace_from: int = 2
var replace_min: int = 18
## Choices of the Supply Drop after a loss (0 = the old Regroup: a free Retire only).
var loss_drop: int = 2
## Picks per Supply Drop after a win from match picks_from on (the drop then shows choices + picks - 1).
var picks: int = 1
var picks_from: int = 2
## thin=N: after every Supply Drop from match 2 on, N more Standard Issue cards are retired for free (floor applies).
var thin: int = 0
var thin_from: int = 2
## squadswap=squad_id:from>to (repeatable, each replaces one copy) for what-if squad decks.
var squad_swaps: Array = []
## replace_order=armored,sergeant,... : which Standard Issue design Replace / Retire sends home first.
var replace_order: Array[String] = []
## Squad AI: second-best plan chance for slots 1-2 (squad_ai=0.3), -1 = the squad's own.
var early_squad_sloppy: float = -1.0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"exp": experiment = kv[1]
			"n": n = int(kv[1])
			"runs": runs = int(kv[1])
			"proxy":
				proxies.clear()
				for p: String in (["competent", "casual"] if kv[1] == "both" else kv[1].split(",")):
					proxies.append(p)
			"base": base = kv[1]
			"deck": starter_spec = kv[1]
			"si":
				for part: String in kv[1].split(","):
					var nv: PackedStringArray = part.split(":")
					var st: PackedStringArray = nv[1].split("/")
					si_stats[nv[0]] = [int(st[0]), int(st[1]), int(st[2])]
			"enemy":
				enemy_modes.clear()
				for e: String in kv[1].split(","):
					enemy_modes.append(e)
			"rusher": squad_specs["squad_rusher"] = kv[1]
			"anchor": squad_specs["squad_anchor"] = kv[1]
			"kit": kit_bonus = kv[1] == "1"
			"replace": replace = kv[1] == "1"
			"replace_from": replace_from = int(kv[1])
			"replace_min": replace_min = int(kv[1])
			"loss_drop": loss_drop = int(kv[1])
			"picks": picks = int(kv[1])
			"picks_from": picks_from = int(kv[1])
			"thin": thin = int(kv[1])
			"thin_from": thin_from = int(kv[1])
			"replace_order":
				for x: String in kv[1].split(","):
					replace_order.append(x)
			"squadswap":
				var sw: PackedStringArray = kv[1].split(":")
				var ft: PackedStringArray = sw[1].split(">")
				squad_swaps.append([sw[0], ft[0], ft[1]])
			"retire": retire_mode = kv[1]
			"retire_min": retire_min = int(kv[1])
			"cc": cc_first = kv[1] == "1"
			"lite": lite = kv[1] == "1"
			"opcost": config.operator_cost = int(kv[1])
			"slots":
				for x: String in kv[1].split(","):
					only_slots.append(int(x))
			"squad_ai": early_squad_sloppy = float(kv[1])
			"slotset":  # slotset=3.enemy_armor_bonus=0 (1-based slot, RunMatchData field)
				var ss: PackedStringArray = kv[1].split("=", true, 1)
				var sk2: PackedStringArray = ss[0].split(".")
				config.matches[int(sk2[0]) - 1].set(sk2[1], str_to_var(ss[1]))
			"set":
				var sv: PackedStringArray = kv[1].split("=", true, 1)
				var sk: PackedStringArray = sv[0].split(".")
				_card(sk[0]).set(sk[1], str_to_var(sv[1]))
			_: push_error("onboarding_sim: unknown option " + arg)
	var t0: int = Time.get_ticks_msec()
	print("onboarding_sim exp=%s base=%s n=%d runs=%d deck=%s si=%s enemy=%s kit=%s retire=%s/%d cc=%s lite=%s" % [
			experiment, base, n, runs, starter_spec, si_stats, enemy_modes, kit_bonus, retire_mode, retire_min, cc_first, lite])
	if experiment in ["slots", "all"]:
		for p: String in proxies:
			_slots(p)
	if experiment == "mirror":
		var st0: Array = [starter(), {"doctrine": &"", "atts": [] as Array[LoadoutItem], "perks": [] as Array[LoadoutItem]}]
		var r: Array = _pair(st0, true, st0, true, n, 12345)
		print("starter mirror: seat 0 %5.1f%% (n=%d)" % [100.0 * r[1] / r[2], r[2]])
	if experiment in ["runs", "all"]:
		for p: String in proxies:
			_runs(p)
		_late_checks()
	print("onboarding_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


# =============================================================================
# Cards
# =============================================================================

func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


## A Standard Issue card (sim-only): vanilla unit, no weapon class, never a trait.
func si_card(name: String) -> CardData:
	var key: String = "si_" + name
	if not cache.has(key):
		var st: Array = si_stats[name]
		var c: CardData = CardData.new()
		c.id = StringName(key)
		c.display_name = name.capitalize()
		c.card_type = DataEnums.CardType.UNIT
		c.cost = int(st[0])
		c.firepower = int(st[1])
		c.armor = int(st[2])
		c.weapon_class = DataEnums.WeaponClass.NONE
		cache[key] = c
	return cache[key]


## A Recruit calling card (sim-only): the chassis' cost / FP / Armor and its trait options, but no
## printed keyword, no neighbor keyword, no effect and no LMG Pierce until it trains.
func cc_card(base_card: CardData) -> CardData:
	var key: String = String(base_card.id) + "~cc"
	if not cache.has(key):
		var v: CardData = base_card.duplicate() as CardData
		v.id = StringName(key)
		v.first_shot = false
		v.pick = false
		v.flank = false
		v.cover = 0
		v.suppress = false
		v.pierce = false
		v.patch = 0
		v.holder = false
		v.arrives_front = false
		v.neighbor_keyword = &""
		if v.weapon_class == DataEnums.WeaponClass.LMG:
			v.weapon_class = DataEnums.WeaponClass.NONE
		var none: Array[EffectData] = []
		v.effects = none
		cache[key] = v
	return cache[key]


func is_si(e: Dictionary) -> bool:
	return String(e["c"].id).begins_with("si_")


func is_cc(e: Dictionary) -> bool:
	return String(e["c"].id).ends_with("~cc")


func base_of(e: Dictionary) -> CardData:
	return _card(String(e["c"].id).get_slice("~", 0)) if is_cc(e) else e["c"]


## Deck entries from a spec "grunt*5,ammo_resupply*2".
func deck_from(spec: String) -> Array:
	var out: Array = []
	for part: String in spec.split(","):
		var nc: PackedStringArray = part.split("*")
		var count: int = int(nc[1]) if nc.size() > 1 else 1
		for k: int in count:
			var c: CardData = si_card(nc[0]) if si_stats.has(nc[0]) else _card(nc[0])
			out.append({"c": c, "lv": SynergyRules.LEVEL_TRAINED, "t": SynergyRules.TRAIT_DEFAULT})
	return out


func starter() -> Array:
	if base == "recruit":
		var out: Array = []
		var lv: Array[int] = config.starter_levels()
		for i: int in config.starter_deck.size():
			out.append({"c": config.starter_deck[i], "lv": lv[i], "t": SynergyRules.TRAIT_DEFAULT})
		return out
	return deck_from(starter_spec)


func trait_of(e: Dictionary) -> StringName:
	if is_si(e) or int(e["lv"]) < SynergyRules.LEVEL_TRAINED:
		return &""
	var c: CardData = e["c"]
	if e["t"] == SynergyRules.TRAIT_DEFAULT or not c.has_trait_choice():
		return c.card_trait
	return e["t"]


# =============================================================================
# Setups and AI
# =============================================================================

func _apply(s: SideSetup, deck: Array) -> void:
	s.deck.clear()
	s.deck_levels.clear()
	s.deck_traits.clear()
	for e: Dictionary in deck:
		s.deck.append(e["c"])
		s.deck_levels.append(int(e["lv"]))
		s.deck_traits.append(e["t"])


func player_setup(deck: Array, st: Dictionary = {}, slot: int = -1) -> SideSetup:
	var s: SideSetup = Sim.player_setup(config)
	s.display_name = "Player"
	_apply(s, deck)
	s.doctrine = st.get("doctrine", &"")
	for a: LoadoutItem in st.get("atts", []):
		s.attachments.append(a)
	for p: LoadoutItem in st.get("perks", []):
		s.perks.append(p)
	if lite and slot >= 0 and slot <= 1:
		_lite(s)
	return s


func _lite(s: SideSetup) -> void:
	s.lethal = null
	s.tactical = null
	var ks: Array[LoadoutItem] = []
	for k: LoadoutItem in s.killstreaks:
		if k != null and k.id == &"recon_drone":
			ks.append(k)
	s.killstreaks = ks


func enemy_setup(idx: int) -> SideSetup:
	var md: RunMatchData = config.matches[idx]
	var s: SideSetup = SideSetup.from_squad(md.squad, md)
	var mode: String = enemy_modes[idx] if idx < enemy_modes.size() else "shipped"
	if base == "recruit":
		mode = "shipped"
	var ident: StringName = md.squad.identity_trait
	for sw: Array in squad_swaps:
		if String(md.squad.id) == sw[0]:
			for i: int in s.deck.size():
				if String(s.deck[i].id) == sw[1]:
					s.deck[i] = _card(sw[2])
					break
	match mode:
		"si":
			_apply(s, deck_from(squad_specs[String(md.squad.id)]))
		"si+cc":
			# Standard Issue squad with three Recruit calling cards of its identity (a first look at traits).
			var d: Array = deck_from(squad_specs[String(md.squad.id)])
			var adds: Array = []
			for c: CardData in s.deck:
				if c.is_unit() and not c.is_elite and c.can_carry(ident) and adds.size() < 3 and c.cost >= 2:
					adds.append({"c": cc_card(c), "lv": SynergyRules.LEVEL_TRAINED, "t": ident})
			for k: int in adds.size():
				d[k] = adds[k]  # replaces Grunts (the spec lists them first)
			_apply(s, d)
		"cc":
			var d2: Array = []
			var tr: Array[StringName] = SideSetup.identity_traits(s.deck, ident)
			for i: int in s.deck.size():
				var c2: CardData = s.deck[i]
				if c2.is_unit() and not c2.is_elite:
					d2.append({"c": cc_card(c2), "lv": SynergyRules.LEVEL_TRAINED, "t": tr[i]})
				else:
					d2.append({"c": c2, "lv": SynergyRules.LEVEL_TRAINED, "t": tr[i]})
			_apply(s, d2)
		"trained":
			s.deck_levels.clear()
		_:
			pass
	if lite and idx <= 1:
		_lite(s)
	return s


func _ai(proxy: String, aware: bool = true) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	if proxy == "casual":
		p.weight_damage_dealt = 1.5
		p.weight_damage_taken = 0.8
		p.push_bonus = 0.3
		p.second_best_chance = 0.6
		p.card_keep_cost = 0.6
		p.cooldown_keep_cost = 1.0
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	return ai


## One match of the run's slot idx. Returns {result, rounds}.
func play_slot(ps: SideSetup, idx: int, seed_value: int, proxy: String) -> Dictionary:
	var md: RunMatchData = config.matches[idx]
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(md.mode, config)
	var m: MatchState = MatchState.new(config, md.map, ps, enemy_setup(idx), seed_value, hooks)
	m.start_match()
	var enemy: AiPlayer = AiPlayer.for_squad(md.squad)
	enemy.planner.synergy_aware = true
	if early_squad_sloppy >= 0.0 and idx <= 1:
		enemy.personality.second_best_chance = early_squad_sloppy
	var player: AiPlayer = _ai(proxy)
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		enemy.take_turn(m, MatchState.ENEMY)
		player.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	return {"result": m.result, "rounds": m.round_number}


# =============================================================================
# slots: the starter kit vs each slot
# =============================================================================

func _slots(proxy: String) -> void:
	print("\n== %s: starter kit (%s) vs each slot, slot mode, n=%d ==" % [proxy, base, n])
	var tot: Array = [0, 0]
	var line: String = ""
	for i: int in config.matches.size():
		if not only_slots.is_empty() and (i + 1) not in only_slots:
			continue
		var w: int = 0
		var rounds: int = 0
		for k: int in n:
			var r: Dictionary = play_slot(player_setup(starter(), {}, i), i, 7000 + k * 104729 + i * 13, proxy)
			if r["result"] == &"player":
				w += 1
			rounds += int(r["rounds"])
		tot[0] += w
		tot[1] += n
		var md: RunMatchData = config.matches[i]
		print("  slot %d %-22s (%s) win %5.1f%%  rounds %.2f" % [i + 1, md.squad.id, enemy_modes[i] if base == "si" else "shipped", 100.0 * w / n, float(rounds) / n])
		line += "%.0f / " % (100.0 * w / n)
	print("  all slots %5.1f%%   [%s]" % [100.0 * tot[0] / tot[1], line.trim_suffix(" / ")])


# =============================================================================
# runs: the ladder
# =============================================================================

func _rung(n_match: int) -> int:
	return clampi(n_match, 1, 4)


## Pool ids (with copy weights) for a rung.
func _pool(rung: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for c: CardData in config.reward_pool:
		if c == null or not c.collectible:
			continue
		var ok: bool = false
		match rung:
			1: ok = c.is_unit() and not c.is_elite
			2: ok = (c.is_unit() and not c.is_elite) or c.card_type == DataEnums.CardType.TACTIC
			3: ok = not (c.is_unit() and c.is_elite)
			_: ok = true
		if ok:
			ids.append(c.id)
	return ids


func main_trait(deck: Array, st: Dictionary) -> StringName:
	var counts: Dictionary = {}
	for e: Dictionary in deck:
		var t: StringName = trait_of(e)
		if t != &"":
			counts[t] = int(counts.get(t, 0)) + 1
	var best: StringName = st.get("doctrine", &"")
	var best_n: int = int(counts.get(best, 0))
	for t: StringName in SynergyRules.TRAITS:
		if int(counts.get(t, 0)) > best_n:
			best = t
			best_n = int(counts[t])
	return best if best_n > 0 or best != &"" else &""


func _drop(n_match: int, main: StringName, rng: RandomNumberGenerator) -> Array:
	var pool: Array[StringName] = _pool(_rung(n_match))
	var picks: Array[StringName] = []
	if main != &"":
		var on: Array[StringName] = []
		for id: StringName in pool:
			var c: CardData = _card(String(id))
			if c.is_unit() and c.can_carry(main):
				on.append(id)
		if not on.is_empty():
			picks = RewardOffers.weighted_distinct(on, 1, rng)
	var rest: Array[StringName] = []
	for id: StringName in pool:
		if id not in picks:
			rest.append(id)
	picks.append_array(RewardOffers.weighted_distinct(rest, config.supply_drop_choices - picks.size(), rng))
	var out: Array = []
	for k: int in picks.size():
		var c: CardData = _card(String(picks[k]))
		var t: StringName = SynergyRules.TRAIT_DEFAULT
		var roll: float = rng.randf()
		if c.has_trait_choice():
			if k == 0 and main != &"" and c.can_carry(main):
				t = main
			elif roll < 0.4:
				var alts: Array[StringName] = c.trait_choices()
				alts.erase(c.card_trait)
				t = alts[rng.randi() % alts.size()]
			else:
				t = c.card_trait
		var played: CardData = c
		if n_match == 1 and cc_first and c.is_unit():
			played = cc_card(c)
		out.append({"c": played, "lv": SynergyRules.LEVEL_TRAINED, "t": t, "on": k == 0 and main != &""})
	return out


func _best(opts: Array) -> int:
	if not opts.is_empty() and opts[0]["on"] and (opts[0]["c"] as CardData).is_unit():
		return 0
	var best: int = 0
	var best_cost: int = -1
	for i: int in opts.size():
		var c: CardData = opts[i]["c"]
		if c.is_unit() and c.cost > best_cost:
			best = i
			best_cost = c.cost
	return best


func _si_count(deck: Array) -> int:
	var k: int = 0
	for e: Dictionary in deck:
		if is_si(e):
			k += 1
	return k


func _cc_index(deck: Array, main: StringName) -> int:
	var best: int = -1
	var score: int = -1
	for i: int in deck.size():
		var e: Dictionary = deck[i]
		if is_cc(e):
			var s: int = (10 if trait_of(e) == main else 0) + (e["c"] as CardData).cost
			if s > score:
				score = s
				best = i
	return best


func _train(deck: Array, i: int) -> void:
	var e: Dictionary = deck[i]
	deck[i] = {"c": base_of(e), "lv": SynergyRules.LEVEL_TRAINED, "t": e["t"]}


## Retires the weakest Standard Issue card (cheapest first). Returns false at the floor / with none.
func _retire_si(deck: Array, main: StringName, bonus: bool) -> bool:
	if deck.size() <= config.deck_floor:
		return false
	var at: int = -1
	var cost: int = 99
	for i: int in deck.size():
		var e: Dictionary = deck[i]
		if not is_si(e) or not (e["c"] as CardData).is_unit():
			continue
		# replace_order (si names, first = sent home first); otherwise the cheapest.
		var key: int = replace_order.find(String(e["c"].id).trim_prefix("si_")) if not replace_order.is_empty() else (e["c"] as CardData).cost
		if key < 0:
			key = 50
		if key < cost:
			cost = key
			at = i
	if at < 0:
		return false
	deck.remove_at(at)
	if bonus:
		var ci: int = _cc_index(deck, main)
		if ci >= 0:
			_train(deck, ci)
	return true


func _should_retire(deck: Array, main: StringName, n_match: int) -> bool:
	if n_match < 2 or _si_count(deck) == 0 or deck.size() <= config.deck_floor:
		return false
	match retire_mode:
		"never": return false
		"always": return deck.size() >= retire_min
		_: return deck.size() >= retire_min and (not kit_bonus or _cc_index(deck, main) >= 0)


func _promote(deck: Array, main: StringName) -> void:
	var ci: int = _cc_index(deck, main)
	if ci >= 0:
		_train(deck, ci)
		return
	var best: int = -1
	var score: int = -1
	for i: int in deck.size():
		var e: Dictionary = deck[i]
		var c: CardData = e["c"]
		if is_si(e) or not c.is_unit() or int(e["lv"]) >= SynergyRules.LEVEL_ELITE:
			continue
		var s: int = (10 if trait_of(e) == main else 0) + c.cost
		if s > score:
			score = s
			best = i
	if best >= 0:
		deck[best]["lv"] = int(deck[best]["lv"]) + 1


func _offers(n_match: int, won: bool, lost: bool, deck: Array, st: Dictionary, rng: RandomNumberGenerator, log: Dictionary) -> void:
	var main: StringName = main_trait(deck, st)
	var choices: int = config.supply_drop_choices if won else (loss_drop if lost else 0)
	if lost and loss_drop <= 0:
		if _retire_si(deck, main, kit_bonus):
			log["retired"] += 1
	if choices > 0:
		var k_picks: int = picks if won and n_match >= picks_from else 1
		var keep: int = config.supply_drop_choices
		config.supply_drop_choices = choices + k_picks - 1
		var opts: Array = _drop(n_match, main, rng)
		config.supply_drop_choices = keep
		if _should_retire(deck, main, n_match):
			if _retire_si(deck, main, kit_bonus):
				log["retired"] += 1
		else:
			for kp: int in k_picks:
				if opts.is_empty():
					break
				var bi: int = _best(opts)
				var pick: Dictionary = opts[bi]
				opts.remove_at(bi)
				if not opts.is_empty():
					opts[0]["on"] = false
				# Replace (n_match >= replace_from): the new card takes the place of a Standard Issue card.
				if replace and n_match >= replace_from and deck.size() >= replace_min and _si_count(deck) > 0:
					if _retire_si(deck, main, false):
						log["replaced"] += 1
				deck.append(pick)
				log["added"] += 1
				if st.get("doctrine", &"") == &"" and trait_of(pick) != &"":
					st["doctrine"] = trait_of(pick)  # the first calling card sets the Doctrine
			if n_match >= thin_from:
				for kt: int in thin:
					if _retire_si(deck, main, false):
						log["retired"] += 1
	main = main_trait(deck, st)
	if n_match in config.weapon_level_after_matches:
		var owned: Array[StringName] = []
		for a: LoadoutItem in st["atts"]:
			owned.append(a.id)
		var ids: Array[StringName] = RewardOffers.attachments(config, config.starter_primary, owned, rng)
		for a: LoadoutItem in config.starter_primary.attachments:
			if not ids.is_empty() and a.id == ids[0]:
				st["atts"].append(a)
	if n_match in config.promotion_after_matches:
		_promote(deck, main)
	if n_match in config.perk_offer_after_matches:
		var owned_p: Array[StringName] = []
		for p: LoadoutItem in st["perks"]:
			owned_p.append(p.id)
		var pids: Array[StringName] = RewardOffers.perks(config, owned_p, rng)
		for p: LoadoutItem in config.perk_pool:
			if not pids.is_empty() and p.id == pids[0]:
				st["perks"].append(p)


func _runs(proxy: String) -> void:
	var reach: Array = [0, 0, 0, 0, 0]
	var wins: Array = [0, 0, 0, 0, 0]
	var victories: int = 0
	var log: Dictionary = {"retired": 0, "added": 0, "replaced": 0}
	var end_stats: Array = [0, 0, 0, 0, 0]  # decks reaching M5: size, SI, cc, trained, sets
	var reached5: int = 0
	for s: int in runs:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 424242 + s * 7919
		var deck: Array = starter()
		var st: Dictionary = {"doctrine": &"", "atts": [] as Array[LoadoutItem], "perks": [] as Array[LoadoutItem]}
		var tickets: int = config.tickets
		for idx: int in config.matches.size():
			reach[idx] += 1
			if idx == config.matches.size() - 1:
				reached5 += 1
				end_stats[0] += deck.size()
				end_stats[1] += _si_count(deck)
				for e: Dictionary in deck:
					if is_cc(e):
						end_stats[2] += 1
					elif not is_si(e) and (e["c"] as CardData).is_unit():
						end_stats[3] += 1
				if proxy == proxies[0] and late_decks.size() < 400:
					late_decks.append([deck.duplicate(true), st.duplicate(true)])
			var r: Dictionary = play_slot(player_setup(deck, st, idx), idx, 900000 + s * 31 + idx, proxy)
			var won: bool = r["result"] == &"player"
			var lost: bool = r["result"] == &"enemy"
			if won:
				wins[idx] += 1
			if idx == config.matches.size() - 1:
				if won:
					victories += 1
				break
			if lost:
				tickets -= 1
				if tickets <= 0:
					break
			_offers(idx + 1, won, lost, deck, st, rng, log)
	print("\n== %s: %d full runs (%s, ladder) ==" % [proxy, runs, base])
	var line: String = ""
	for i: int in 5:
		print("  M%d reached %3d  win %5.1f%%" % [i + 1, reach[i], 100.0 * wins[i] / maxf(1, reach[i])])
		line += "%.0f / " % (100.0 * wins[i] / maxf(1, reach[i]))
	print("  RUN WIN %5.1f%%  (per match %s)  per run: cards added %.2f (of them replacing a Standard Issue card %.2f), retired %.2f" % [
			100.0 * victories / runs, line.trim_suffix(" / "), float(log["added"]) / runs, float(log["replaced"]) / runs, float(log["retired"]) / runs])
	var r5: float = maxf(1, reached5)
	print("  decks at M5 (n=%d): size %.1f, Standard Issue %.1f, Recruit calling cards %.1f, Trained+ units %.1f" % [reached5,
			end_stats[0] / r5, end_stats[1] / r5, end_stats[2] / r5, end_stats[3] / r5])


# =============================================================================
# Late-deck checks: growth, duel, mirror
# =============================================================================

func _mplay(decks: Array, aware: Array, seed_value: int, mode: int) -> int:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = MatchState.new(config, config.matches[0].map, player_setup(decks[0][0], decks[0][1]),
			player_setup(decks[1][0], decks[1][1]), seed_value, hooks)
	m.start_match()
	var ais: Array[AiPlayer] = [_ai("competent", aware[0]), _ai("competent", aware[1])]
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		ais[1].take_turn(m, MatchState.ENEMY)
		ais[0].take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	if m.result == &"player":
		return 0
	if m.result == &"enemy":
		return 1
	return -1


## A vs B over `count` matches, seats and modes alternating. Returns [A wins, seat-0 wins, count].
func _pair(da: Array, aware_a: bool, db: Array, aware_b: bool, count: int, salt: int) -> Array:
	var a: int = 0
	var s0: int = 0
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var w: int = _mplay([da, db] if a_seat == 0 else [db, da], [aware_a, aware_b] if a_seat == 0 else [aware_b, aware_a],
				9000 + k * 7919 + salt, mode)
		if w == 0:
			s0 += 1
		if w == a_seat:
			a += 1
	return [a, s0, count]


func _late_checks() -> void:
	if late_decks.is_empty():
		return
	var st0: Array = [starter(), {"doctrine": &"", "atts": [] as Array[LoadoutItem], "perks": [] as Array[LoadoutItem]}]
	var k: int = mini(late_decks.size(), maxi(20, n))
	var g: Array = [0, 0]
	var d: Array = [0, 0]
	var m0: Array = [0, 0]
	var ms: Array = [0, 0]
	for i: int in k:
		var ld: Array = late_decks[i]
		var r: Array = _pair(ld, true, [st0[0], ld[1]], true, 4, i * 17)
		g[0] += r[0]
		g[1] += r[2]
		var r2: Array = _pair(ld, true, ld, false, 4, i * 17 + 5)
		d[0] += r2[0]
		d[1] += r2[2]
		var r3: Array = _pair(ld, true, ld, true, 2, i * 17 + 9)
		m0[0] += r3[1]
		m0[1] += r3[2]
	var r4: Array = _pair(st0, true, st0, true, 4 * k, 77)
	ms[0] += r4[1]
	ms[1] += r4[2]
	print("\n== late decks (decks that reached M5, first proxy, %d decks) ==" % k)
	print("  growth: late deck vs the starter, same loadout %5.1f%% (n=%d)" % [100.0 * g[0] / g[1], g[1]])
	print("  duel:   aware vs blind, same late deck          %5.1f%% (n=%d)" % [100.0 * d[0] / d[1], d[1]])
	print("  mirror: seat 0, late decks                      %5.1f%% (n=%d)" % [100.0 * m0[0] / m0[1], m0[1]])
	print("  mirror: seat 0, starter                         %5.1f%% (n=%d)" % [100.0 * ms[0] / ms[1], ms[1]])
