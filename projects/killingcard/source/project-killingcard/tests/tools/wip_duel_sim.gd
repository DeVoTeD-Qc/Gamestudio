# wip_duel_sim.gd
# Purpose: kc-wip-design balance harness for the head's Wip set (documentation/design/wip-set.md §4), on top of
#   duel_sim.gd (the shipped Duel rules, presets, Operators and AI). The 19 Wip cards are built in memory
#   (wip_cards.gd) and the matches run in wip_match.gd (a sim-only MatchState with Suppress N, Agile, the
#   Hacker's Supply and the Laser Gunner's Beam). Nothing in data/ or scripts/ changes.
#   Experiments (WIP_EXPS environment variable, comma list; duel_sim's own exps are off):
#     swap   card value: each Wip card replaces the closest-cost pick of the same type in each preset
#            (non-Elite; a unit wears the trait of the pick it replaces). The changed preset plays the 3 other
#            presets, n games per pair, seats alternate, the same seeds as the unchanged baseline. Delta = win
#            rate change in points, averaged over the 4 presets (+ = stronger than the card it replaced).
#     deck   the export's 20-card list as one deck (Kestrel, no Doctrine) vs each preset.
#     starter the campaign starter shapes as Duel decks vs each preset (cheap context; the campaign test is
#            wip_run_check.gd).
#   Options: duel_sim's (n=N ...); WIP_CARDS=id,id (swap subset); WIP_SET (wip_cards.gd what-ifs).
#   Run: WIP_EXPS=swap godot --headless --path . -s res://tests/tools/wip_duel_sim.gd -- exps=none n=40
# Author: Sr Game Designer Agent (kc-wip-design)
extends "res://tests/tools/duel_sim.gd"

const WC: GDScript = preload("res://tests/tools/wip_cards.gd")
const WM: GDScript = preload("res://tests/tools/wip_match.gd")

var wip: Dictionary = {}
## Reveals of Wip cards (all games), [beam enemy dmg, beam friendly dmg, beam friendly downs, agile moves, hacker supply].
var reveals: Dictionary = {}
var wip_totals: Array[int] = [0, 0, 0, 0, 0]


func _main() -> void:
	wip = WC.register(true)
	await super._main()
	var wexps: PackedStringArray = OS.get_environment("WIP_EXPS").split(",", false)
	if wexps.is_empty():
		wexps = PackedStringArray(["swap", "deck"])
	_reset()
	var t0: int = Time.get_ticks_msec()
	print("wip_duel_sim: WIP_EXPS=%s n=%d WIP_SET=%s" % [",".join(wexps), n, OS.get_environment("WIP_SET")])
	if "deck" in wexps:
		_exp_wip_deck()
	if "swap" in wexps:
		_exp_swap()
	print("\nwip_duel_sim done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


## duel_sim._game on wip_match.gd (no Doctrine what-if rules, no Terrain).
func _game(sa: SideSetup, sb: SideSetup, seed_value: int, ta: String = "competent", tb: String = "competent",
		mode: int = -1) -> int:
	var h: DuelHooks = DuelHooks.new()
	h.hero_mode = hero_mode
	h.dummy = dummy
	var gm: int = mode
	if gm < 0:
		gm = DataEnums.GameMode.FIREFIGHT if mode_opt == "ff" else DataEnums.GameMode.ZONE_CONTROL
	h.mode_rules = ModeRules.create(gm, config)
	for st: SideSetup in [sa, sb]:
		st.doctrine_starts_only = true
	var m = WM.new(config, duel_config.map, sa, sb, seed_value, h)
	m.start_match()
	var a: AiPlayer = _ai(ta)
	var b: AiPlayer = _ai(tb)
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		b.take_turn(m, MatchState.ENEMY)
		a.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		m.resolve_round()
		m.begin_round()
	for e: Dictionary in m.events:
		if StringName(e.get("type", &"")) == RulesEvent.CARD_REVEALED:
			var cid: StringName = e.get("card_id", &"")
			if wip.has(cid):
				reveals[cid] = int(reveals.get(cid, 0)) + 1
	for i: int in 5:
		wip_totals[i] += int(m.wip_stats[i])
	var w: int = 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)
	stats[0] += 1
	stats[1] += m.round_number
	stats[2] += int(w == 0)
	stats[3] += int(w == -1)
	return w


## duel_sim._deck from a preset dictionary (picks may hold Wip ids).
func _deck_from(pr: Dictionary) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = pr["name"]
	for ix: int in mini(picks, (pr["picks"] as Array).size()):  # picks 11-12 are duel_sim's size-test spares
		var pk: Array = pr["picks"][ix]
		var c: CardData = load("res://data/cards/%s.tres" % pk[0]) as CardData
		var t: StringName = pk[1]
		if not c.can_carry(t):
			t = SynergyRules.TRAIT_DEFAULT
		for j: int in 2:
			s.deck.append(c)
			s.deck_traits.append(t)
	s.doctrine = pr["trait"] if doctrine_on else &""
	s.primary = load("res://data/loadout/%s.tres" % pr["hero"]) as LoadoutItem
	s.operator_kit = true
	s.killstreaks.assign(config.starter_killstreaks)
	return s


## Win rate of `pr` (playing preset slot p) against the other presets: [wins, decided].
func _gauntlet(pr: Dictionary, p: int) -> Array[int]:
	var wins: int = 0
	var dec: int = 0
	for q: int in PRESETS.size():
		if q == p:
			continue
		for k: int in n:
			var seat: int = k % 2
			var mine: SideSetup = _deck_from(pr)
			var theirs: SideSetup = _deck_from(PRESETS[q])
			var w: int = _game(mine if seat == 0 else theirs, theirs if seat == 0 else mine,
					91001 + p * 7919 + q * 977 + k * 131)
			if w >= 0:
				dec += 1
				wins += int(w == seat)
	return [wins, dec]


## The preset pick a Wip card replaces: same kind (unit / non-unit), not Elite, closest cost (ties: first).
func _replace_index(pr: Dictionary, c: CardData) -> int:
	var best: int = -1
	var best_d: int = 99
	for i: int in mini(picks, (pr["picks"] as Array).size()):
		var pc: CardData = load("res://data/cards/%s.tres" % pr["picks"][i][0]) as CardData
		if pc.is_elite or pc.is_unit() != c.is_unit():
			continue
		if not c.is_unit() and pc.card_type != c.card_type:
			continue
		var d: int = absi(pc.cost - c.cost)
		if d < best_d:
			best_d = d
			best = i
	return best


func _exp_swap() -> void:
	var only: PackedStringArray = OS.get_environment("WIP_CARDS").split(",", false)
	print("\n---- swap: each Wip card in place of the closest-cost pick, %d games per pair, 3 pairs per preset ----" % n)
	var base: Array = []
	for p: int in PRESETS.size():
		var g: Array[int] = _gauntlet(PRESETS[p], p)
		base.append(100.0 * g[0] / maxf(1, g[1]))
	print("  baseline: %s" % ", ".join(PackedStringArray(range(PRESETS.size()).map(func(p: int) -> String:
			return "%s %.1f%%" % [PRESETS[p]["name"], base[p]]))))
	print("  %-16s %4s | %-60s | %s" % ["card", "cost", "replaces (per preset) -> win% (delta)", "mean delta / AI plays per game"])
	for row: Array in WC.LIST:
		var id: StringName = row[0]
		if not only.is_empty() and String(id) not in only:
			continue
		var c: CardData = wip[id]
		var parts: Array[String] = []
		var sum_d: float = 0.0
		var cnt: int = 0
		reveals.erase(id)
		var games0: int = stats[0]
		for p: int in PRESETS.size():
			var pr: Dictionary = PRESETS[p].duplicate(true)
			var ix: int = _replace_index(pr, c)
			if ix < 0:
				parts.append("%s -" % String(PRESETS[p]["id"]).left(4))
				continue
			var old: Array = pr["picks"][ix]
			pr["picks"][ix] = [id, old[1] if c.is_unit() else SynergyRules.TRAIT_DEFAULT]
			var g: Array[int] = _gauntlet(pr, p)
			var rate: float = 100.0 * g[0] / maxf(1, g[1])
			sum_d += rate - float(base[p])
			cnt += 1
			parts.append("%s>%s %.0f(%+.0f)" % [String(old[0]).left(8), String(PRESETS[p]["id"]).left(4), rate, rate - float(base[p])])
		var games: int = stats[0] - games0
		print("  %-16s %4d | %-60s | %+5.1f / %.2f" % [row[1], c.cost, "  ".join(PackedStringArray(parts)),
				sum_d / maxf(1, cnt), float(reveals.get(id, 0)) / maxf(1, games)])
	print("  beam: enemy dmg %d, friendly dmg %d, friendly downs %d · agile moves %d · hacker supply %d (all games)" % wip_totals)


func _exp_wip_deck() -> void:
	print("\n---- deck: the export's 20-card list (Kestrel, no Doctrine) vs each preset, %d games each ----" % n)
	var pr: Dictionary = {"name": "Wip", "trait": &"", "hero": &"kestrel_ar7", "picks": []}
	var tot: Array[int] = [0, 0]
	for p: int in PRESETS.size():
		var wins: int = 0
		var dec: int = 0
		for k: int in n:
			var seat: int = k % 2
			var mine: SideSetup = _wip_side()
			var theirs: SideSetup = _deck_from(PRESETS[p])
			var w: int = _game(mine if seat == 0 else theirs, theirs if seat == 0 else mine, 72001 + p * 977 + k * 131)
			if w >= 0:
				dec += 1
				wins += int(w == seat)
		tot[0] += wins
		tot[1] += dec
		print("    Wip deck vs %-14s %5.1f%% (n=%d)" % [PRESETS[p]["name"], 100.0 * wins / maxf(1, dec), dec])
	print("    Wip deck overall %5.1f%% (n=%d)" % [100.0 * tot[0] / maxf(1, tot[1]), tot[1]])
	var per: Array[String] = []
	for row: Array in WC.LIST:
		per.append("%s %.2f" % [row[0], float(reveals.get(row[0], 0)) / maxf(1, stats[0])])
	print("    Wip reveals per game: %s" % ", ".join(PackedStringArray(per)))


func _wip_side() -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Wip"
	s.deck.assign(WC.export_deck(wip))
	for c: CardData in s.deck:
		s.deck_traits.append(SynergyRules.TRAIT_DEFAULT)
	s.doctrine = &""
	s.primary = load("res://data/loadout/kestrel_ar7.tres") as LoadoutItem
	s.operator_kit = true
	s.killstreaks.assign(config.starter_killstreaks)
	return s
