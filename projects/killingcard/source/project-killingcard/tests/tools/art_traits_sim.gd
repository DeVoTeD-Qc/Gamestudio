# art_traits_sim.gd
# Purpose: kc-art-traits sim (documentation/design/art-traits.md §6). "The trait comes from the art":
#   every Trained unit copy carries the trait of the art it wears, chosen from a per-chassis option
#   list (ART_OPTIONS), instead of the chassis' fixed trait. Stats, keywords and effects stay on the
#   chassis. Runs on the shipped engine (MatchState + SynergyRules + AiPlanner.synergy_aware) like
#   synergy_check.gd; a re-traited copy is a sim-only duplicate of the CardData with
#   `card_trait` changed and id "<chassis>~<trait>" (so the planner's per-design dedup keeps two
#   Marksmen with different traits apart). Fields keep their printed trait (doc §2.4).
#   kc-art-traits-impl: opts=game (the default) reads the shipped CardData.trait_options and plays
#   the per-copy trait through the real path (SideSetup.deck_traits -> RulesCard.chosen_trait, no
#   duplicates); squads use their shipped SquadData.identity_trait (squadtraits=identity by default).
#   opts=fixed|v1|v2|v3|all  the option table: fixed = today's chassis traits only (control);
#                            v1-v3 = limited options per chassis (v3 recommended, doc §4); all = any unit, any trait
#   opt=chassis:t1/t2,...    override rows of the table (e.g. opt=gunner:heavy/undead,rifleman:-)
#   ontrait=1                fixed mode: Promotions go to on-trait Recruits too (fair control)
#   pkg=heavy:a/b/c/d        replace a reward package; set=card.property=value edits a card in memory
#   Experiments (late decks = starter + 4 reward cards - 3 Retired + 2 Promoted, synergy-system §7):
#     traits    aware round robin of the four trait decks; in art mode the deckbuilder gives every
#               Trained copy that can carry the deck's trait that trait, and promotes on-trait
#               Recruits (target 40-60% each)
#     dominance for each reward package x each main trait the deckbuilder can stack, win rate
#               against the fixed-trait field (is one trait the best main for every package?)
#     draft     greedy drafts: 4 Supply Drops of 3 random reward-pool cards, the drafter keeps the
#               card that grows its best set, promotes 2 on-trait Recruits, retires 3 Riflemen;
#               random pairings; prints how often each main trait is chosen and its win rate
#     duel      aware vs blind, same art-trait deck (target >= 55%)
#     mirror    aware mirror, art-trait decks: seat 0 win rate (45-55%)
#     campaign  aware player with the Recruit starter vs the real squads; squadtraits=native|identity|undead3
#               (identity: each squad's arts are picked to one trait, SQUAD_TRAIT; undead3 = identity
#               with slot 3 (Rusher+) as an Undead squad; doc §7)
#   plus synergy_check's n=N opcost=N tune=trait.tier.key=value squads=aware|blind
#   Run: godot --headless --path . -s res://tests/tools/art_traits_sim.gd -- exp=traits n=160 opts=v1
# Author: Sr Game Designer Agent (kc-art-traits), from synergy_check.gd (Mechanics Developer Agent)
extends SceneTree

const Sim = preload("res://tests/mode_sim.gd")

const TRAITS: Array[String] = ["vanguard", "specops", "heavy", "undead"]
## Reward packages (synergy_check's TRAIT_ADDS) plus the blind "mixed" draft.
const PACKAGES: Dictionary = {
	"vanguard": ["point_man", "breacher", "shieldman", "bulwark"],
	"specops": ["flanker", "recon_specialist", "marksman", "sniper_perch"],
	"heavy": ["gunner", "demolitions_expert", "demolitions_expert", "mortar_pit"],
	"undead": ["brawler", "brawler", "combat_medic", "war_standard"],
	"mixed": ["flanker", "demolitions_expert", "brawler", "mortar_pit"],
}
const RETIRE_ORDER: Array[String] = ["rifleman", "rifleman", "rifleman", "ammo_resupply"]
## Fixed-mode promotion order (synergy_check's PROMOTE_ORDER).
const PROMOTE_ORDER: Array[String] = ["point_man", "breacher", "marksman", "combat_medic"]

## Option tables: chassis -> trait options (first = the chassis' default art family). "" = an art
## with no trait. Units only; Fields keep their printed trait.
const TABLES: Dictionary = {
	"fixed": {
		"point_man": ["vanguard"], "breacher": ["vanguard"], "shieldman": ["vanguard"],
		"flanker": ["specops"], "recon_specialist": ["specops"], "marksman": ["specops"], "halek_wren": ["specops"],
		"gunner": ["heavy"], "demolitions_expert": ["heavy"], "okafor_anvil": ["heavy"],
		"brawler": ["undead"], "combat_medic": ["undead"],
	},
	# v1: native + one alternate each; Rifleman gains Spec Ops / Undead (doc §4.2, first proposal).
	"v1": {
		"rifleman": ["", "specops", "undead"],
		"point_man": ["vanguard", "undead"], "breacher": ["vanguard", "heavy"], "shieldman": ["vanguard", "undead"],
		"flanker": ["specops", "undead"], "recon_specialist": ["specops", "vanguard"], "marksman": ["specops", "heavy"],
		"halek_wren": ["specops"],
		"gunner": ["heavy", "specops"], "demolitions_expert": ["heavy", "undead"], "okafor_anvil": ["heavy", "specops"],
		"brawler": ["undead", "heavy"], "combat_medic": ["undead", "vanguard"],
	},
	# v2: v1 with no alternate INTO Vanguard (Recon -> Undead, Medic -> Spec Ops).
	"v2": {
		"rifleman": ["", "specops", "undead"],
		"point_man": ["vanguard", "undead"], "breacher": ["vanguard", "heavy"], "shieldman": ["vanguard", "undead"],
		"flanker": ["specops", "undead"], "recon_specialist": ["specops", "undead"], "marksman": ["specops", "heavy"],
		"halek_wren": ["specops"],
		"gunner": ["heavy", "specops"], "demolitions_expert": ["heavy", "undead"], "okafor_anvil": ["heavy", "specops"],
		"brawler": ["undead", "heavy"], "combat_medic": ["undead", "specops"],
	},
	# v3 (recommended): v2 with the Brawler's alternate on Spec Ops (operator-bundle melee arts), so
	# Undead's own units can't all leave for Heavy; Heavy gains only Breacher and Marksman.
	"v3": {
		"rifleman": ["", "specops", "undead"],
		"point_man": ["vanguard", "undead"], "breacher": ["vanguard", "heavy"], "shieldman": ["vanguard", "undead"],
		"flanker": ["specops", "undead"], "recon_specialist": ["specops", "undead"], "marksman": ["specops", "heavy"],
		"halek_wren": ["specops"],
		"gunner": ["heavy", "specops"], "demolitions_expert": ["heavy", "undead"], "okafor_anvil": ["heavy", "specops"],
		"brawler": ["undead", "specops"], "combat_medic": ["undead", "specops"],
	},
}

var config: RunConfig = null
var n: int = 40
var experiment: String = "traits"
var squads_aware: bool = true
var squad_traits: String = "identity"
var future_weight: float = 1.5
var opts_name: String = "game"
var options: Dictionary = {}
var variants: Dictionary = {}
var decks: Array[String] = ["vanguard", "specops", "heavy", "undead"]
var drafts: int = 200
## Fixed mode: promote on-trait Recruits too (a fairer control than PROMOTE_ORDER).
var ontrait: bool = false
## pkg= overrides of PACKAGES.
var pkg_overrides: Dictionary = {}
## swap= / slots= (campaign tuning).
var swapped: Dictionary = {}
var only_slots: Array[int] = []
## Set-activity counters for the last pairing set: side-rounds with tier 2 / tier 3 active.
var activity: Dictionary = {}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	var overrides: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"exp": experiment = kv[1]
			"n": n = int(kv[1])
			"opts": opts_name = kv[1]
			"opt": overrides.append(kv[1])
			"squads": squads_aware = kv[1] == "aware"
			"squadtraits": squad_traits = kv[1]
			"drafts": drafts = int(kv[1])
			"ontrait": ontrait = kv[1] == "1"
			"pkg":  # pkg=heavy:gunner/demolitions_expert/brawler/mortar_pit (replace a reward package)
				var pv: PackedStringArray = kv[1].split(":")
				var ids: Array = []
				for id: String in pv[1].split("/"):
					ids.append(id)
				pkg_overrides[pv[0]] = ids
			"set":  # set=demolitions_expert.pierce=false (a card property, in memory, every copy)
				var sv: PackedStringArray = kv[1].split("=", true, 1)
				var sk: PackedStringArray = sv[0].split(".")
				_card(sk[0]).set(sk[1], str_to_var(sv[1]))
			"decks":
				decks.clear()
				for d: String in kv[1].split(","):
					decks.append(d)
			"opcost": config.operator_cost = int(kv[1])
			"future": future_weight = float(kv[1])
			"syn": SynergyRules.enabled = kv[1] != "0"
			"tune":  # tune=vanguard.1.where=front (trait.tier_index.key=value, in memory)
				var tv: PackedStringArray = kv[1].split("=", true, 1)
				var tk: PackedStringArray = tv[0].split(".")
				var val: Variant = str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1]
				(SynergyRules.trait_bonus[StringName(tk[0])][int(tk[1])] as Dictionary)[tk[2]] = val
			"swap":  # swap=squad_anchor:gunner/rifleman (one copy, in memory; kc-art-traits-impl F1 tuning)
				var sw: PackedStringArray = kv[1].split(":")
				var ab: PackedStringArray = sw[1].split("/")
				for md: RunMatchData in config.matches:
					if String(md.squad.id) == sw[0] and not swapped.has(sw[0] + sw[1]):
						swapped[sw[0] + sw[1]] = true
						var dk: Array[CardData] = md.squad.deck
						var at: int = dk.find(_card(ab[0]))
						if at >= 0:
							dk[at] = _card(ab[1])
			"armor":  # armor=4:0 (slot 4's enemy Armor bonus, in memory)
				var av: PackedStringArray = kv[1].split(":")
				config.matches[int(av[0]) - 1].enemy_armor_bonus = int(av[1])
			"slots":
				for sl: String in kv[1].split(","):
					only_slots.append(int(sl))
			_: push_error("art_traits_sim: unknown option " + arg)
	_build_options(overrides)
	var t0: int = Time.get_ticks_msec()
	print("art_traits_sim exp=%s n=%d opts=%s %s opcost=%d" % [experiment, n, opts_name, overrides, config.operator_cost])
	match experiment:
		"traits": _traits()
		"dominance": _dominance()
		"draft": _draft()
		"duel": _duel()
		"mirror": _mirror()
		"campaign": _campaign()
		"table": _print_table()
	print("art_traits_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _build_options(overrides: Array[String]) -> void:
	if opts_name == "all":
		for id: String in (TABLES["v1"] as Dictionary):
			var native: Array = (TABLES["v1"][id] as Array)
			var row: Array = [native[0]]
			for t: String in TRAITS:
				if t not in row:
					row.append(t)
			options[id] = row
	elif opts_name == "game":
		for c: CardData in _all_cards():
			if c.is_unit() and not c.trait_choices().is_empty():
				var row: Array = []
				for t: StringName in c.trait_choices():
					row.append(String(t))
				options[String(c.id)] = row
	else:
		options = (TABLES[opts_name] as Dictionary).duplicate(true)
	for o: String in overrides:
		for part: String in o.split(","):
			var kv: PackedStringArray = part.split(":")
			var row: Array = []
			for t: String in kv[1].split("/"):
				row.append("" if t == "-" else t)
			options[kv[0]] = row


func _print_table() -> void:
	for id: String in options:
		print("%-20s %s" % [id, options[id]])


func _all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for f: String in DirAccess.get_files_at("res://data/cards/"):
		if f.ends_with(".tres"):
			out.append(load("res://data/cards/" + f) as CardData)
	return out


## opts=game: per-copy traits go through SideSetup.deck_traits (d[2]); other tables use duplicates.
func _real() -> bool:
	return opts_name == "game"


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _base_id(c: CardData) -> String:
	return String(c.id).get_slice("~", 0)


## Traits this copy may carry (Trained units only; Fields and untraited chassis: their own).
func opts_for(c: CardData) -> Array:
	var id: String = _base_id(c)
	if c.is_unit() and options.has(id):
		return options[id]
	return [String(_card(id).card_trait)]


## The CardData a copy plays as when its art carries trait `t` (sim-only duplicate when it differs).
func variant(c: CardData, t: String) -> CardData:
	var base: CardData = _card(_base_id(c))
	if String(base.card_trait) == t or not base.is_unit():
		return base
	var key: String = "%s~%s" % [base.id, t]
	if not variants.has(key):
		var v: CardData = base.duplicate() as CardData
		v.id = StringName(key)
		v.card_trait = StringName(t)
		variants[key] = v
	return variants[key]


## Start from the starter; Retire 3 Riflemen when late.
func _late_base() -> Array:
	var cards: Array[CardData] = config.starter_deck.duplicate()
	var levels: Array[int] = _flat_levels(config.starter_deck.size())
	for id: String in RETIRE_ORDER.slice(0, 3):
		for i: int in cards.size():
			if _base_id(cards[i]) == id:
				cards.remove_at(i)
				levels.remove_at(i)
				break
	return [cards, levels, _default_traits(cards)]


func _default_traits(cards: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CardData in cards:
		out.append(SynergyRules.TRAIT_DEFAULT)
	return out


## Promote `count` Recruits: fixed mode uses PROMOTE_ORDER; art mode prefers Recruits that can
## carry `main` (most expensive first), then PROMOTE_ORDER.
func _promote(d: Array, main: String, count: int) -> void:
	var promoted: int = 0
	if (opts_name != "fixed" or ontrait) and main != "":
		var cands: Array[int] = []
		for i: int in d[0].size():
			if d[1][i] == 0 and main in opts_for(d[0][i]):
				cands.append(i)
		cands.sort_custom(func(a: int, b: int) -> bool: return (d[0][a] as CardData).cost > (d[0][b] as CardData).cost)
		var used: Dictionary = {}
		for pass_i: int in 2:  # spread over designs first (one per design), like a player would
			for i: int in cands:
				if promoted < count and d[1][i] == 0 and (pass_i == 1 or not used.has(_base_id(d[0][i]))):
					d[1][i] = 1
					used[_base_id(d[0][i])] = true
					promoted += 1
	for id: String in PROMOTE_ORDER:
		for i: int in d[0].size():
			if promoted < count and _base_id(d[0][i]) == id and d[1][i] == 0:
				d[1][i] = 1
				promoted += 1
				break


## Deckbuilder: give each Trained copy a trait. `main` forced, or "" = stack the trait the most
## copies can reach (Fields count), then a second trait for the rest. Returns the main trait.
func assign(d: Array, main: String = "") -> String:
	var cards: Array = d[0]
	var levels: Array = d[1]
	var free: Array[int] = []
	for i: int in cards.size():
		if levels[i] >= 1 and (cards[i] as CardData).is_unit() and opts_for(cards[i]).size() > 0:
			free.append(i)
		elif (cards[i] as CardData).is_unit() and not _real():
			cards[i] = _card(_base_id(cards[i]))
	var fields: Dictionary = {}
	for i: int in cards.size():
		var c: CardData = cards[i]
		if c.is_field() and c.card_trait != &"":
			fields[String(c.card_trait)] = int(fields.get(String(c.card_trait), 0)) + 1
	var chosen: String = main
	for round_i: int in 2:
		var pick: String = chosen if round_i == 0 else ""
		if pick == "":
			var best: float = -1.0
			for t: String in TRAITS:
				var cnt: float = float(fields.get(t, 0)) * 0.9
				for i: int in free:
					if t in opts_for(cards[i]):
						cnt += 1.0 + 0.01 * (cards[i] as CardData).cost
				if cnt > best:
					best = cnt
					pick = t
		if round_i == 0:
			chosen = pick
		var rest: Array[int] = []
		for i: int in free:
			if pick in opts_for(cards[i]):
				_put(d, i, pick)
			else:
				rest.append(i)
		free = rest
	for i: int in free:  # nothing fits: the chassis' default art
		_put(d, i, opts_for(cards[i])[0])
	return chosen


## Copy i wears an art of trait t: the real path (deck_traits) or a sim-only duplicate.
func _put(d: Array, i: int, t: String) -> void:
	if _real():
		while d.size() < 3:
			d.append(_default_traits(d[0]))
		d[2][i] = StringName(t)
	else:
		d[0][i] = variant(d[0][i], t)


## [cards, levels] of the late deck for a package; art mode: on-trait promotions + deckbuilder.
func deck_for(pkg: String, main: String = "") -> Array:
	var d: Array = _late_base()
	if pkg == "starter":
		return [config.starter_deck.duplicate(), _flat_levels(config.starter_deck.size()), _default_traits(config.starter_deck)]
	for id: String in pkg_overrides.get(pkg, PACKAGES[pkg]):
		d[0].append(_card(id))
		d[1].append(1)
		d[2].append(SynergyRules.TRAIT_DEFAULT)
	var target: String = main if main != "" else (pkg if pkg in TRAITS else "")
	if opts_name == "fixed":
		_promote(d, target if ontrait else "", 2)
		return d
	_promote(d, target, 2)
	assign(d, target)
	return d


func _ai(aware: bool) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	ai.planner.synergy_future_weight = future_weight
	return ai


func _setup(d: Array, name: String) -> SideSetup:
	var s: SideSetup = Sim.player_setup(config)
	s.display_name = name
	s.deck.assign(d[0])
	pass  # kc-no-training: copy levels are gone (sim-only data now)
	if d.size() > 2:
		s.deck_traits.assign(d[2])
	return s


func play(seat_decks: Array, seat_aware: Array, seed_value: int, mode: int) -> Dictionary:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = MatchState.new(config, config.matches[0].map, _setup(seat_decks[0], "seat0"), _setup(seat_decks[1], "seat1"), seed_value, hooks)
	m.start_match()
	var ais: Array[AiPlayer] = [_ai(seat_aware[0]), _ai(seat_aware[1])]
	var act: Array = [[0, 0, 0], [0, 0, 0]]  # side-rounds, with a tier 2+, with a tier 3
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		ais[1].take_turn(m, MatchState.ENEMY)
		ais[0].take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.reveal()
		for si: int in 2:
			var tiers: Dictionary = m.synergy_side(si)["tiers"]
			act[si][0] += 1
			var hi: int = 0
			for t: Variant in tiers:
				hi = maxi(hi, int(tiers[t]))
			if hi >= 2:
				act[si][1] += 1
			if hi >= 3:
				act[si][2] += 1
		m.firefight()
		m.score()
		m.begin_round()
	var w: int = -1
	if m.result == &"player":
		w = 0
	elif m.result == &"enemy":
		w = 1
	return {"winner": w, "rounds": m.round_number, "act": act}


func pairing(da: Array, aware_a: bool, db: Array, aware_b: bool, count: int, salt: int, start: int = 0) -> Dictionary:
	var r: Dictionary = {"a": 0, "b": 0, "draw": 0, "seat0": 0, "rounds": 0, "acta": [0, 0, 0], "actb": [0, 0, 0]}
	for k: int in range(start, start + count):
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var res: Dictionary = play([da, db] if a_seat == 0 else [db, da], [aware_a, aware_b] if a_seat == 0 else [aware_b, aware_a],
				9000 + k * 7919 + salt, mode)
		var w: int = res["winner"]
		if w == 0:
			r["seat0"] += 1
		if w < 0:
			r["draw"] += 1
		elif w == a_seat:
			r["a"] += 1
		else:
			r["b"] += 1
		r["rounds"] += int(res["rounds"])
		for j: int in 3:
			r["acta"][j] += int(res["act"][a_seat][j])
			r["actb"][j] += int(res["act"][1 - a_seat][j])
	r["n"] = count
	return r


func _fmt(r: Dictionary) -> String:
	var c: float = float(r["n"])
	return "A %5.1f%%  B %5.1f%%  draw %4.1f%%  seat0 %5.1f%%  rounds %.2f  tier2+ A %2.0f%% B %2.0f%%" % [
			100.0 * r["a"] / c, 100.0 * r["b"] / c, 100.0 * r["draw"] / c, 100.0 * r["seat0"] / c, float(r["rounds"]) / c,
			100.0 * r["acta"][1] / maxf(1, r["acta"][0]), 100.0 * r["actb"][1] / maxf(1, r["actb"][0])]


func _describe(d: Array) -> String:
	var counts: Dictionary = {}
	for i: int in d[0].size():
		var c: CardData = d[0][i]
		var t: StringName = SynergyRules.trait_at(c, d[1][i], d[2][i] if d.size() > 2 and i < (d[2] as Array).size() else SynergyRules.TRAIT_DEFAULT)
		if t != &"":
			counts[String(t)] = int(counts.get(String(t), 0)) + 1
	return str(counts)


func _traits() -> void:
	print("\n== late trait decks, aware round robin (opts=%s) ==" % opts_name)
	var built: Dictionary = {}
	for d: String in decks:
		built[d] = deck_for(d)
		print("  %-9s traited: %s" % [d, _describe(built[d])])
	var total: Dictionary = {}
	for i: int in decks.size():
		for j: int in range(i + 1, decks.size()):
			var r: Dictionary = pairing(built[decks[i]], true, built[decks[j]], true, n, i * 10 + j)
			print("%-9s vs %-9s %s" % [decks[i], decks[j], _fmt(r)])
			for pair: Array in [[decks[i], r["a"], r["acta"]], [decks[j], r["b"], r["actb"]]]:
				var t: Array = total.get(pair[0], [0, 0, 0, 0])
				t[0] += int(pair[1])
				t[1] += int(r["n"])
				t[2] += int(pair[2][1])
				t[3] += int(pair[2][0])
				total[pair[0]] = t
	for k: String in total:
		print("  %-9s overall %5.1f%%  (tier 2+ active %2.0f%% of side-rounds)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), 100.0 * total[k][2] / maxf(1, total[k][3])])


## Package x main trait vs the fixed-trait field (the four fixed late trait decks).
func _dominance() -> void:
	print("\n== dominance: package x stacked main trait vs the fixed field (opts=%s) ==" % opts_name)
	var saved: String = opts_name
	var saved_opts: Dictionary = options
	opts_name = "fixed"
	options = (TABLES["fixed"] as Dictionary).duplicate(true)
	var field: Array = []
	for d: String in TRAITS:
		field.append(deck_for(d))
	opts_name = saved
	options = saved_opts
	var pkgs: Array = decks.duplicate()
	if "mixed" not in pkgs:
		pkgs.append("mixed")
	var by_trait: Dictionary = {}
	for pi: int in pkgs.size():
		var line: String = "%-9s" % pkgs[pi]
		for ti: int in TRAITS.size():
			var t: String = TRAITS[ti]
			var d: Array = deck_for(pkgs[pi], t)
			var w: int = 0
			var tot: int = 0
			for fi: int in field.size():
				var r: Dictionary = pairing(d, true, field[fi], true, n, 500 + pi * 100 + ti * 10 + fi)
				w += int(r["a"])
				tot += int(r["n"])
			var pct: float = 100.0 * w / maxf(1, tot)
			var bt: Array = by_trait.get(t, [0, 0])
			bt[0] += w
			bt[1] += tot
			by_trait[t] = bt
			line += "  %s %5.1f%% %s" % [t.substr(0, 3), pct, _describe(d)]
		print(line)
	for t: String in by_trait:
		print("  main %-9s pooled %5.1f%%" % [t, 100.0 * by_trait[t][0] / maxf(1, by_trait[t][1])])


## Greedy drafts; random pairings; main-trait pick rate and win rate.
func _draft() -> void:
	print("\n== greedy drafts (opts=%s), %d decks, %d matches each ==" % [opts_name, drafts, n])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var pool: Array[CardData] = []
	for c: CardData in config.reward_pool:
		if c != null:
			pool.append(c)
	var built: Array = []
	var mains: Array = []
	for k: int in drafts:
		var d: Array = _late_base()
		for drop: int in 4:
			var offer: Array[CardData] = []
			for o: int in 3:
				offer.append(pool[rng.randi() % pool.size()])
			var best_c: CardData = offer[0]
			var best_s: float = -1.0
			for c: CardData in offer:
				var trial: Array = [d[0].duplicate(), d[1].duplicate(), d[2].duplicate()]
				trial[0].append(c)
				trial[1].append(1)
				trial[2].append(SynergyRules.TRAIT_DEFAULT)
				var s: float = _set_score(trial) + rng.randf() * 0.05 + (0.3 if c.is_unit() else 0.0)
				if s > best_s:
					best_s = s
					best_c = c
			d[0].append(best_c)
			d[1].append(1)
			d[2].append(SynergyRules.TRAIT_DEFAULT)
		var main: String = _best_trait(d)
		_promote(d, main, 2)
		main = assign(d, "") if opts_name != "fixed" else _best_trait(d)
		built.append(d)
		mains.append(main)
	var pick: Dictionary = {}
	var wins: Dictionary = {}
	for m: String in mains:
		pick[m] = int(pick.get(m, 0)) + 1
	for k: int in drafts:
		for rep: int in n:
			var j: int = (k + 1 + rng.randi() % (drafts - 1)) % drafts
			var r: Dictionary = pairing(built[k], true, built[j], true, 1, k * 1000, rep)
			for pair: Array in [[mains[k], r["a"]], [mains[j], r["b"]]]:
				var t: Array = wins.get(pair[0], [0, 0])
				t[0] += int(pair[1])
				t[1] += 1
				wins[pair[0]] = t
	for t: String in TRAITS:
		var wv: Array = wins.get(t, [0, 0])
		print("  main %-9s chosen %5.1f%% of decks   win %5.1f%% (n=%d)" % [t, 100.0 * int(pick.get(t, 0)) / drafts, 100.0 * wv[0] / maxf(1, wv[1]), wv[1]])


## Size of the best set this deck can form (Trained units + Fields), with the current options.
func _set_score(d: Array) -> float:
	var best: float = 0.0
	for t: String in TRAITS:
		var cnt: float = 0.0
		for i: int in d[0].size():
			var c: CardData = d[0][i]
			if c.is_field() and String(c.card_trait) == t:
				cnt += 0.9
			elif c.is_unit() and d[1][i] >= 1 and t in (opts_for(c) if opts_name != "fixed" else [String(c.card_trait)]):
				cnt += 1.0
			elif c.is_unit() and d[1][i] == 0 and t in (opts_for(c) if opts_name != "fixed" else [String(c.card_trait)]):
				cnt += 0.25  # a Recruit that a Promotion could put on this trait
		best = maxf(best, cnt)
	return best


func _best_trait(d: Array) -> String:
	var best: float = -1.0
	var pick: String = ""
	for t: String in TRAITS:
		var cnt: float = 0.0
		for i: int in d[0].size():
			var c: CardData = d[0][i]
			var o: Array = opts_for(c) if opts_name != "fixed" else [String(c.card_trait)]
			if (c.is_field() or d[1][i] >= 1) and t in o:
				cnt += 1.0
		if cnt > best:
			best = cnt
			pick = t
	return pick


func _duel() -> void:
	print("\n== aware (A) vs blind (B), same late art-trait deck (opts=%s) ==" % opts_name)
	var tot: Array = [0, 0]
	for d: String in decks:
		var deck: Array = deck_for(d)
		var r: Dictionary = pairing(deck, true, deck, false, n, hash(d) % 1000)
		tot[0] += int(r["a"])
		tot[1] += int(r["n"])
		print("%-9s %s" % [d, _fmt(r)])
	print("pooled aware win %.1f%% (n=%d)" % [100.0 * tot[0] / maxf(1, tot[1]), tot[1]])


func _mirror() -> void:
	print("\n== aware mirror, late art-trait decks: seat 0 win rate (opts=%s) ==" % opts_name)
	var tot: Array = [0, 0]
	for d: String in ["starter"] + decks:
		var deck: Array = deck_for(d)
		var r: Dictionary = pairing(deck, true, deck, true, n, 31 + hash(d) % 1000)
		tot[0] += int(r["seat0"])
		tot[1] += int(r["n"])
		print("%-9s %s" % [d, _fmt(r)])
	print("pooled seat 0 win %.1f%% (n=%d)" % [100.0 * tot[0] / maxf(1, tot[1]), tot[1]])


## Squad identity (doc §7): the trait every traited copy of the squad's deck is put on.
const SQUAD_TRAIT: Dictionary = {"squad_rusher": "vanguard", "squad_anchor": "heavy", "squad_black_meridian": "specops"}


func _squad_setup(slot: RunMatchData, idx: int) -> SideSetup:
	var s: SideSetup = SideSetup.from_squad(slot.squad, slot)  # applies the shipped identity_trait
	if squad_traits == "native":
		s.deck_traits.clear()
		return s
	if squad_traits == "identity" and _real():
		return s
	var levels: Array[int] = []
	for i: int in s.deck.size():
		levels.append(1)
	var d: Array = [s.deck.duplicate(), levels, _default_traits(s.deck)]
	var main: String = String(SQUAD_TRAIT.get(String(slot.squad.id), ""))
	if squad_traits == "undead3" and idx == 2:
		main = "undead"
	assign(d, main)
	s.deck.assign(d[0])
	s.deck_traits.assign(d[2])
	return s


func _campaign() -> void:
	print("\n== campaign: aware player, Recruit starter, vs squads (%s, traits %s, opts=%s) ==" % ["aware" if squads_aware else "blind", squad_traits, opts_name])
	var tot: Array = [0, 0]
	for i: int in config.matches.size():
		if not only_slots.is_empty() and (i + 1) not in only_slots:
			continue
		var slot: RunMatchData = config.matches[i]
		var w: int = 0
		var sq: SideSetup = _squad_setup(slot, i)
		var desc: Array = [sq.deck, [], []]
		for k2: int in sq.deck.size():
			desc[1].append(1)
			desc[2].append(sq.trait_of(k2))
		for k: int in n:
			var mode: int = DataEnums.GameMode.ZONE_CONTROL if k % 2 == 0 else DataEnums.GameMode.FIREFIGHT
			var hooks: MatchHooks = MatchHooks.new()
			hooks.mode_rules = ModeRules.create(mode, config)
			var m: MatchState = MatchState.new(config, slot.map, _setup(deck_for("starter"), "Player"),
					_squad_setup(slot, i), 5000 + k * 104729 + i, hooks)
			m.start_match()
			var enemy: AiPlayer = AiPlayer.for_squad(slot.squad)
			enemy.planner.synergy_aware = squads_aware
			var player: AiPlayer = _ai(true)
			while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
				enemy.take_turn(m, MatchState.ENEMY)
				player.take_turn(m, MatchState.PLAYER, false)
				m.set_ready(MatchState.PLAYER)
				m.resolve_round()
				m.begin_round()
			if m.result == &"player":
				w += 1
		tot[0] += w
		tot[1] += n
		print("slot %d (%s%s) win %5.1f%%  squad traits %s" % [i + 1, slot.squad.id, "", 100.0 * w / n, _describe(desc)])
	print("all slots win %5.1f%% (n=%d)" % [100.0 * tot[0] / tot[1], tot[1]])


## kc-no-training: copy levels were removed from the engine; this historical sim keeps its own
## level arrays as data only (every copy plays its full chassis).
static func _flat_levels(n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		out.append(1)
	return out
