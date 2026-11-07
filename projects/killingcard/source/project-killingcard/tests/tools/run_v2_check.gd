# run_v2_check.gd
# Purpose: kc-v2-design (documentation/design/run-v2.md) what-if harness. Plays the Run v2 map
#   (path choice: fights, elites, events, shops, rests, 3 bosses), Terrain (map Fields dealt to
#   columns), Operator passives + once-per-match abilities and run modifiers on the REAL engine:
#   MatchState / FirefightResolver / RunProgress offers / AiPlanner. Everything new lives in this
#   file as subclasses and hooks (V2Match, V2Hooks, V2View, V2Ai); nothing in scripts/ is changed.
#     runs    run win, per-node win (the ramp), by Operator and boss; M5-equivalent decks kept
#     ops     Operator head to head on late decks (aware, seats and modes alternate)
#     swing   per Terrain: player late deck vs F3 / F4 / elite crews, paired seeds, with vs without
#     late    traits round robin, aware vs blind, seat 0 mirrors (late decks, random Terrain)
#   Options: exps=runs,ops,swing,late  runs=N  proxies=competent,casual  first=1 (the first-run map)
#     op=kestrel|longreach|wasp|bastion|rotate  boss=meridian|prime|choir|rotate
#     mods=hardcore,austerity,hot_ground,veterans,fog  terrain=0 (no Terrain anywhere)
#     k=var=value[;var=value]  (any script var below, e.g. k=boss_armor_prime=0;req_win=3)
#     tune=trait.tier.key=value[;...]  (SynergyRules.trait_bonus what-if, as tune_check)  set=card.prop=value
#     sn=N (swing matches per Terrain)  hn=N (head-to-head games per Operator pair)  late=N mirror=N tn=N
#   Run: godot --headless --path . -s res://tests/tools/run_v2_check.gd -- exps=runs runs=400 op=rotate
# Author: Sr Game Designer Agent (kc-v2-design), from tune_check.gd
extends SceneTree

# ---------------------------------------------------------------- knobs (k=name=value)
var runs: int = 100
var late_n: int = 80
var mirror_n: int = 400
var trait_n: int = 60
var swing_n: int = 240
var h2h_n: int = 240
var proxies: Array[String] = ["competent", "casual"]
var exps: Array[String] = ["runs"]
var first_run: bool = false
var op_mode: String = "rotate"
var boss_mode: String = "rotate"
var mods: Array[String] = []
var terrain_on: bool = true
var aware_terrain: bool = true

var req_start: int = 0
var req_win: int = 3
var req_loss: int = 1
var req_elite: int = 5
var price_unit: int = 4
var price_tactic: int = 3
var price_field: int = 3
var price_elite_card: int = 7
var price_remove: int = 3
var price_remove_si: int = 2
var elite_armor_1: int = 1
var elite_armor_2: int = 1
var boss_armor_meridian: int = 1
var boss_armor_prime: int = 1
var boss_armor_choir: int = 2
var choir_from_round: int = 2
var prime_pits: String = "0,1,2"
var meridian_extra_draw: int = 0
var meridian_supply: int = 1
var meridian_supply_from: int = 4
var boss_fp_meridian: int = 0
var tickets_v2: int = 3
var wasp_fp: int = 2
var wasp_armor: int = 7
var longreach_armor: int = 6
var bastion_suppress: bool = false
var bastion_cover: int = 1
var shambler_dodge: bool = true
var prime_mode: int = 1
var f_armor: String = "0,0,0,1"
var shambler_fp: int = 1
var shambler_armor: int = 2
## First-run map: the Operator's passive and ability switch on from this fight (1 = F1, 2 = F2).
var first_kit_from: int = 2
var ab_dig_in: int = 1
var ab_marked: int = 3
var ab_flash: int = 2
var ab_cover_fire: int = 1
var bastion_armor: int = 8
var bastion_fp: int = 2
var kestrel_hand: int = 1

const OPS: Array[StringName] = [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"]
const BOSSES: Array[StringName] = [&"meridian", &"prime", &"choir"]
const TERRAINS: Array[StringName] = [&"rooftops", &"smoke", &"dust_storm", &"breach_point", &"floodlights",
		&"comms_tower", &"supply_cache", &"hot_zone", &"minefield", &"field_hospital"]
const NODE_FIGHT: StringName = &"fight"
const NODE_ELITE: StringName = &"elite"
const NODE_EVENT: StringName = &"event"
const NODE_SHOP: StringName = &"shop"
const NODE_REST: StringName = &"rest"
const NODE_BOSS: StringName = &"boss"
const EVENTS: Array[StringName] = [&"supply_truck", &"audit", &"wounded_scout", &"fixer", &"radio_chatter",
		&"memorial", &"rival_message", &"range_day", &"night_drop"]

var config: RunConfig = null
var op_items: Dictionary = {}
var abilities: Dictionary = {}
var late: Array[SideSetup] = []
var late_trait: Array[StringName] = []
var late_op: Array[StringName] = []
var shambler: CardData = null
var mortar_pit: CardData = null
var init_stats: Array[int] = [0, 0, 0]
var extra_seed: int = 0


# =============================================================================
# Rules what-ifs (subclasses of the real engine)
# =============================================================================

class V2Match extends MatchState:
	var terrain: Array[StringName] = [&"", &"", &""]
	var boss: StringName = &""
	var held: Array[int] = [-1, -1, -1]
	var cache_bonus: Array[int] = [0, 0]
	var opening_bonus: Array[int] = [0, 0]
	var pierce_op: Array[bool] = [false, false]
	var ability: Array = [null, null]
	var fog: bool = false
	var shambler_card: CardData = null
	var pit_card: CardData = null
	var pit_zones: Array[int] = []
	var choir_from: int = 2
	var extra_draw: int = 1
	var extra_supply: int = 0
	var supply_from: int = 1

	func _init(p_config: RunConfig = null, p_map: MapData = null, player: SideSetup = null,
			enemy: SideSetup = null, p_seed: int = 0, p_hooks: MatchHooks = null) -> void:
		super(p_config, p_map, player, enemy, p_seed, p_hooks)

	func start_match() -> void:
		super.start_match()
		for si: int in 2:
			if pierce_op[si] and sides[si].operator_unit != null:
				sides[si].operator_unit.pierce = true
			if ability[si] != null:
				StreakTracker.grant(self, si, (ability[si] as LoadoutItem).id)
		if boss == &"prime" and pit_card != null:
			for z: int in pit_zones:
				sides[ENEMY].equipment[z].append({"card": RulesCard.new(new_uid(), pit_card, SynergyRules.TRAIT_DEFAULT), "round": 1})

	func begin_round() -> void:
		if phase == Phase.ENDED:
			return
		if round_number >= 1:
			_hospital()
		super.begin_round()
		if phase == Phase.ENDED:
			return
		for z: int in ZONE_COUNT:
			held[z] = control_of(z)
		for si: int in 2:
			if round_number == 1 and opening_bonus[si] > 0:
				draw_cards(si, opening_bonus[si])
			if cache_bonus[si] > 0:
				sides[si].supply += cache_bonus[si]
			cache_bonus[si] = 0
		if boss == &"meridian" and extra_draw > 0:
			draw_cards(ENEMY, extra_draw)
		if boss == &"meridian" and round_number >= supply_from:
			sides[ENEMY].supply += extra_supply
		if boss == &"choir" and round_number >= choir_from and shambler_card != null:
			var best: int = -1
			var best_n: int = 99
			for z: int in ZONE_COUNT:
				var n: int = sides[ENEMY].line(z).size()
				if n < config.zone_capacity and n < best_n:
					best = z
					best_n = n
			if best >= 0:
				var u: RulesUnit = create_unit(ENEMY, shambler_card)
				put_in_line(u, best, false)

	func _hospital() -> void:
		for z: int in ZONE_COUNT:
			if terrain[z] != &"field_hospital":
				continue
			for si: int in 2:
				var worst: RulesUnit = null
				var lost: int = 0
				for u: RulesUnit in sides[si].line(z):
					var miss: int = u.max_armor(round_number) - u.armor
					if u.is_alive() and miss > lost:
						worst = u
						lost = miss
				if worst != null:
					worst.armor += 1

	func has_first_shot(u: RulesUnit, with_synergy: bool = true) -> bool:
		if u.zone >= 0:
			var t: StringName = terrain[u.zone]
			if t == &"dust_storm":
				return false
			if t == &"rooftops" and held[u.zone] == u.side:
				return true
		return super.has_first_shot(u, with_synergy)

	func firefight() -> void:
		var stash: Array = []
		for si: int in 2:
			for z: int in ZONE_COUNT:
				if terrain[z] != &"smoke" and terrain[z] != &"breach_point":
					continue
				for u: RulesUnit in sides[si].line(z):
					stash.append([u, u.pick, u.flank, u.pierce])
					if terrain[z] == &"smoke":
						u.pick = false
						u.flank = false
					else:
						u.pierce = true
		super.firefight()
		for e: Array in stash:
			var u: RulesUnit = e[0]
			u.pick = e[1]
			u.flank = e[2]
			u.pierce = e[3]

	func reveal() -> void:
		var start: int = events.size()
		super.reveal()
		if not terrain.has(&"minefield"):
			return
		var hit: Dictionary = {}
		for i: int in range(start, events.size()):
			var ev: Dictionary = events[i]
			if ev["type"] != RulesEvent.UNIT_ARRIVED:
				continue
			var u: RulesUnit = find_unit(int(ev["uid"]))
			if u == null or u.zone < 0 or terrain[u.zone] != &"minefield":
				continue
			var key: String = "%d:%d" % [u.side, u.zone]
			if hit.has(key):
				continue
			hit[key] = true
			deal_damage(u, 1, {"side": u.side, "uid": -1, "source_id": &"minefield", "source_kind": &"terrain"}, false)
		process_eliminations()

	func revealed_red_dots(viewer: int, zone: int) -> Array[StringName]:
		if fog:
			var none: Array[StringName] = []
			return none
		if terrain[zone] != &"floodlights":
			return super.revealed_red_dots(viewer, zone)
		var out: Array[StringName] = []
		var foe: RulesSide = sides[1 - viewer]
		for play: Dictionary in foe.plays:
			if int(play["zone"]) != zone:
				continue
			if play["kind"] == &"unit":
				out.append((play["card"] as RulesCard).card.id)
			elif play["kind"] in [&"place", &"rotate"]:
				out.append(foe.operator_unit.source_id)
		return out

	func red_dots(viewer: int) -> PackedInt32Array:
		if fog:
			return PackedInt32Array([0, 0, 0])
		return super.red_dots(viewer)


class V2Hooks extends MatchHooks:
	func apply_streak(state, side: int) -> void:
		for z: int in 3:
			if state.terrain[z] == &"comms_tower" and state.control_of(z) == side:
				state.sides[side].streak_bonus_this_round += 1
		super.apply_streak(state, side)

	func score_round(state, control: Array) -> void:
		super.score_round(state, control)
		for z: int in 3:
			var c: int = int(control[z])
			if c != 0 and c != 1:
				continue
			if state.terrain[z] == &"hot_zone" and mode_rules != null and mode_rules.mode == DataEnums.GameMode.ZONE_CONTROL:
				state.sides[c].score += 1
			elif state.terrain[z] == &"supply_cache":
				state.cache_bonus[c] += 1


## The AI's view with Terrain applied to the records the planner builds (aware of Terrain).
class V2View extends AiView:
	var terrain: Array[StringName] = [&"", &"", &""]
	var held: Array[int] = [-1, -1, -1]

	func record_for_card(card: CardData, uid: int, z: int,
			chosen_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> Dictionary:
		var r: Dictionary = super.record_for_card(card, uid, z, chosen_trait)
		apply(r, z, true)
		return r

	func apply(r: Dictionary, z: int, arriving: bool) -> void:
		if z < 0 or z > 2:
			return
		match terrain[z]:
			&"dust_storm":
				r["first_shot"] = false
				r["fs_native"] = false
			&"rooftops":
				if held[z] == side:
					r["first_shot"] = true
			&"smoke":
				r["pick"] = false
				r["flank"] = false
			&"breach_point":
				r["pierce"] = true
			&"minefield":
				if arriving:
					r["armor"] = maxi(1, int(r["armor"]) - 1)
					r["armor0"] = r["armor"]


class V2Ai extends AiPlayer:
	var aware: bool = true

	func _init(p: AiPersonality = null) -> void:
		super(p)

	func take_turn(state, side: int, set_ready: bool = true) -> Array[Dictionary]:
		last_intents.clear()
		last_rejected.clear()
		mulligan(state, side)
		for i: int in MAX_REPLANS + 1:
			var view: AiView = AiView.capture(state, side)
			if aware and state is V2Match:
				view = _wrap(view, state)
			last_plan = planner.plan(view)
			for intent: Dictionary in last_plan["intents"]:
				var r: Dictionary = state.submit(side, intent)
				if r["ok"]:
					last_intents.append(intent)
				else:
					last_rejected.append(intent)
			if not last_plan["replan"]:
				break
		if set_ready:
			state.set_ready(side)
		return last_intents

	func _wrap(v: AiView, state) -> V2View:
		var w: V2View = V2View.new()
		for p: Dictionary in v.get_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				w.set(p["name"], v.get(p["name"]))
		w.terrain = state.terrain.duplicate()
		w.held = state.held.duplicate()
		for si: int in 2:
			for z: int in 3:
				for r: Dictionary in w.lines[si][z]:
					w.apply(r, z, false)
		var opu = state.sides[v.side].operator_unit
		for z: int in w.op_by_zone.size():
			w.apply(w.op_by_zone[z], z, opu == null or not opu.is_on_board())
		return w


# =============================================================================
# Setup
# =============================================================================

func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = load("res://data/run_config.tres") as RunConfig
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"runs": runs = int(kv[1])
			"late": late_n = int(kv[1])
			"mirror": mirror_n = int(kv[1])
			"tn": trait_n = int(kv[1])
			"sn": swing_n = int(kv[1])
			"hn": h2h_n = int(kv[1])
			"first": first_run = kv[1] == "1"
			"op": op_mode = kv[1]
			"boss": boss_mode = kv[1]
			"terrain": terrain_on = kv[1] != "0"
			"taware": aware_terrain = kv[1] != "0"
			"proxies":
				proxies.clear()
				for p: String in kv[1].split(","):
					proxies.append(p)
			"exps":
				exps.clear()
				for e: String in kv[1].split(","):
					exps.append(e)
			"mods":
				mods.clear()
				for m: String in kv[1].split(","):
					if m != "":
						mods.append(m)
			"k":
				for item: String in kv[1].split(";"):
					var p: PackedStringArray = item.split("=", true, 1)
					_assign(self, p[0], p[1])
			"set":
				for item: String in kv[1].split(";"):
					var a: PackedStringArray = item.split(".", true, 1)
					var b: PackedStringArray = a[1].split("=", true, 1)
					_assign(load("res://data/cards/%s.tres" % a[0]), b[0], b[1])
			"tune":  # tune=trait.tier.key=value[;...] edits SynergyRules.trait_bonus in memory (as tune_check)
				for item: String in kv[1].split(";"):
					var tv: PackedStringArray = item.split("=", true, 1)
					var tk: PackedStringArray = tv[0].split(".")
					var val: Variant = str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1]
					var tiers: Array = SynergyRules.trait_bonus[StringName(tk[0])]
					if val is String and val == "none":
						(tiers[int(tk[1])] as Dictionary).erase(tk[2])
					else:
						(tiers[int(tk[1])] as Dictionary)[tk[2]] = val
			_: push_error("run_v2_check: unknown option " + arg)
	_build_content()
	var t0: int = Time.get_ticks_msec()
	print("run_v2_check: runs=%d first=%s op=%s boss=%s mods=%s terrain=%s args=%s" % [runs, first_run, op_mode,
			boss_mode, mods, terrain_on, OS.get_cmdline_user_args()])
	if "runs" in exps or "ops" in exps or "swing" in exps or "late" in exps:
		for k: int in proxies.size():
			_runs(proxies[k], k == 0)
	if "ops" in exps:
		_ops_h2h()
	if "swing" in exps:
		_swing()
	if "late" in exps:
		_traits()
		_duel_late()
		_mirrors()
	print("\nrun_v2_check done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _assign(obj: Object, prop: String, raw: String) -> void:
	var cur: Variant = obj.get(prop)
	var val: Variant = raw
	match typeof(cur):
		TYPE_INT: val = int(raw)
		TYPE_FLOAT: val = float(raw)
		TYPE_BOOL: val = raw == "true" or raw == "1"
		TYPE_STRING: val = raw
		TYPE_STRING_NAME: val = StringName(raw)
		TYPE_NIL: push_error("run_v2_check: %s has no property %s" % [obj, prop])
	obj.set(prop, val)


func _fx(kind: int, target: int, scope: int, amount: int) -> EffectData:
	var e: EffectData = EffectData.new()
	e.trigger = DataEnums.Trigger.ON_PLAY
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	e.duration_rounds = 1
	return e


func _ability(id: StringName, name: String, fx: Array) -> LoadoutItem:
	var it: LoadoutItem = LoadoutItem.new()
	it.id = id
	it.display_name = name
	it.slot = DataEnums.LoadoutSlot.KILLSTREAK
	it.streak_threshold = 99
	it.uses_per_match = 1
	for e: EffectData in fx:
		it.effects.append(e)
	return it


func _build_content() -> void:
	var K := DataEnums.EffectKind
	var T := DataEnums.Target
	var Z := DataEnums.ZoneScope
	var kestrel: LoadoutItem = load("res://data/loadout/kestrel_ar7.tres")
	op_items[&"kestrel_ar7"] = kestrel
	var lr: LoadoutItem = (load("res://data/loadout/longreach_338.tres") as LoadoutItem).duplicate() as LoadoutItem
	lr.operator_armor = longreach_armor
	op_items[&"longreach_338"] = lr
	var wasp: LoadoutItem = (load("res://data/loadout/wasp_9.tres") as LoadoutItem).duplicate() as LoadoutItem
	wasp.operator_firepower = wasp_fp
	wasp.operator_armor = wasp_armor
	op_items[&"wasp_9"] = wasp
	var bastion: LoadoutItem = LoadoutItem.new()
	bastion.id = &"bastion_60"
	bastion.display_name = "Bastion-60"
	bastion.slot = DataEnums.LoadoutSlot.PRIMARY
	bastion.weapon_class = DataEnums.WeaponClass.LMG
	bastion.operator_firepower = bastion_fp
	bastion.operator_armor = bastion_armor
	bastion.suppress = bastion_suppress
	bastion.cover = bastion_cover
	bastion.attachments = kestrel.attachments.duplicate()
	op_items[&"bastion_60"] = bastion
	abilities[&"kestrel_ar7"] = _ability(&"ab_dig_in", "Dig In", [_fx(K.GRANT_COVER, T.ALL_FRIENDLIES, Z.CHOSEN_ZONE, ab_dig_in)])
	abilities[&"longreach_338"] = _ability(&"ab_marked_shot", "Marked Shot", [_fx(K.DAMAGE, T.CHOSEN_ENEMY, Z.OPERATOR_ZONE, ab_marked)])
	abilities[&"wasp_9"] = _ability(&"ab_flashbang", "Flashbang", [_fx(K.REMOVE_FIRST_SHOT, T.ALL_ENEMIES, Z.OPERATOR_ZONE, 0),
			_fx(K.MODIFY_FIREPOWER, T.ALL_ENEMIES, Z.OPERATOR_ZONE, -ab_flash)])
	abilities[&"bastion_60"] = _ability(&"ab_covering_fire", "Covering Fire", [_fx(K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.OPERATOR_ZONE, ab_cover_fire)])
	shambler = CardData.new()
	shambler.id = &"shambler"
	shambler.display_name = "Shambler"
	shambler.card_type = DataEnums.CardType.UNIT
	shambler.firepower = shambler_fp
	shambler.armor = shambler_armor
	shambler.counts_for_control = false
	shambler.grants_elimination_credit = true
	shambler.collectible = false
	if shambler_dodge:
		var dodge: EffectData = EffectData.new()
		dodge.trigger = DataEnums.Trigger.PASSIVE
		dodge.kind = DataEnums.EffectKind.UNTARGETABLE_BY_PICK_FLANK
		dodge.target = DataEnums.Target.SELF
		dodge.zone_scope = DataEnums.ZoneScope.THIS_ZONE
		shambler.effects.append(dodge)
	mortar_pit = load("res://data/cards/mortar_pit.tres")


# =============================================================================
# The map
# =============================================================================

func _md(slot: int, armor_delta: int = 0) -> RunMatchData:
	var md: RunMatchData = config.matches[slot].duplicate() as RunMatchData
	md.enemy_armor_bonus = config.matches[slot].enemy_armor_bonus + armor_delta
	return md


func _boss_md(boss: StringName) -> RunMatchData:
	var md: RunMatchData
	match boss:
		&"prime":
			md = config.matches[3].duplicate() as RunMatchData
			var anchor: SquadData = load("res://data/squads/squad_anchor.tres")
			md.enemy_deck = anchor.deck.duplicate()
			md.mode = prime_mode
			md.enemy_armor_bonus = boss_armor_prime
			md.crew_label = "Bulwark Prime"
		&"choir":
			md = config.matches[4].duplicate() as RunMatchData
			var sq: SquadData = (load("res://data/squads/squad_rusher.tres") as SquadData).duplicate() as SquadData
			sq.display_name = "The Hollow Choir"
			sq.identity_trait = &"undead"
			md.squad = sq
			var deck: Array[CardData] = []
			for e: Array in [["brawler", 4], ["point_man", 3], ["combat_medic", 2], ["flanker", 2], ["shieldman", 2],
					["demolitions_expert", 2], ["recon_specialist", 1], ["aid_station", 1], ["war_standard", 1],
					["hold_the_line", 1], ["ammo_resupply", 1]]:
				for i: int in int(e[1]):
					deck.append(load("res://data/cards/%s.tres" % e[0]) as CardData)
			md.enemy_deck = deck
			md.mode = DataEnums.GameMode.ZONE_CONTROL
			md.enemy_armor_bonus = boss_armor_choir
			md.crew_label = "The Hollow Choir"
		_:
			md = config.matches[4].duplicate() as RunMatchData
			md.enemy_armor_bonus = boss_armor_meridian
			md.enemy_firepower_bonus = boss_fp_meridian
	md.is_rival = true
	return md


## Terrain for one fight: `count` distinct Terrains on distinct columns.
func _deal(rng: RandomNumberGenerator, count: int, mode: int) -> Array[StringName]:
	var out: Array[StringName] = [&"", &"", &""]
	if not terrain_on or count <= 0:
		return out
	var pool: Array[StringName] = TERRAINS.duplicate()
	if mode != DataEnums.GameMode.ZONE_CONTROL:
		pool.erase(&"hot_zone")
	var cols: Array[int] = [0, 1, 2]
	for i: int in mini(count, 3):
		var t: StringName = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(t)
		var c: int = cols[rng.randi_range(0, cols.size() - 1)]
		cols.erase(c)
		out[c] = t
	return out


## Steps of the map: each an array of node types to choose from (fight steps carry their fight).
func _map(first: bool, rng: RandomNumberGenerator) -> Array:
	if first:
		return [[NODE_FIGHT], [NODE_EVENT], [NODE_FIGHT], [NODE_REST, NODE_ELITE], [NODE_FIGHT], [NODE_SHOP],
				[NODE_FIGHT], [NODE_REST], [NODE_BOSS]]
	var s2: Array = [NODE_EVENT, NODE_SHOP]
	var s4: Array = [NODE_ELITE, NODE_EVENT, NODE_REST]
	var s6: Array = [NODE_SHOP, NODE_ELITE, NODE_EVENT]
	var s8: Array = [NODE_REST, NODE_SHOP]
	# Variety: one of the three options on steps 4 and 6 is sometimes swapped for another type.
	if rng.randf() < 0.3:
		s4[1] = NODE_SHOP
	if rng.randf() < 0.3:
		s6[2] = NODE_REST
	return [[NODE_FIGHT], s2, [NODE_FIGHT], s4, [NODE_FIGHT], s6, [NODE_FIGHT], s8, [NODE_BOSS]]


func _terrain_count(first: bool, fight_no: int, elite: bool, boss: bool) -> int:
	var n: int
	if boss:
		n = 0
	elif first:
		n = [0, 0, 1, 1, 1][fight_no] if not elite else 1
	else:
		n = [1, 1, 1 + (fight_no * 7919 + extra_seed) % 2, 2, 2][fight_no] if not elite else 2
	if "hot_ground" in mods and not first:
		n = mini(2, n + 1)
	return n


# =============================================================================
# Runs
# =============================================================================

func _ai(proxy: String, aware: bool = true) -> V2Ai:
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
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	var ai: V2Ai = V2Ai.new(p)
	ai.planner.synergy_aware = aware
	ai.aware = aware_terrain
	return ai


func _squad_ai(squad: SquadData) -> V2Ai:
	var ai: V2Ai = V2Ai.new(AiPersonality.from_squad(squad))
	ai.planner.synergy_aware = true
	ai.aware = aware_terrain
	return ai


func _play(m: MatchState, a: AiPlayer, b: AiPlayer, track: bool = false) -> void:
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		b.take_turn(m, MatchState.ENEMY)
		a.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		if track:
			init_stats[0] += 1
		m.resolve_round()
		if track and m.initiative == 0:
			init_stats[1] += 1
		m.begin_round()


func _with_op(s: SideSetup, op: StringName) -> SideSetup:
	s.primary = op_items[op]
	if abilities.has(op):
		s.killstreaks.append(abilities[op])
	return s


func _new_match(cfg: RunConfig, md: RunMatchData, ps: SideSetup, es: SideSetup, seed_v: int, op: StringName,
		terrain: Array[StringName], boss: StringName, enemy_op: StringName = &"") -> V2Match:
	var h: V2Hooks = V2Hooks.new()
	h.mode_rules = ModeRules.create(md.mode, cfg)
	var m: V2Match = V2Match.new(cfg, md.map, ps, es, seed_v, h)
	m.terrain = terrain.duplicate()
	m.boss = boss
	m.fog = "fog" in mods
	m.shambler_card = shambler
	m.pit_card = mortar_pit
	m.choir_from = choir_from_round
	m.extra_draw = meridian_extra_draw
	m.extra_supply = meridian_supply
	m.supply_from = meridian_supply_from
	for z: String in prime_pits.split(","):
		if z != "":
			m.pit_zones.append(int(z))
	for si: int in 2:
		var o: StringName = op if si == 0 else enemy_op
		if o == &"":
			continue
		if o == &"kestrel_ar7":
			m.opening_bonus[si] = kestrel_hand
		if o == &"longreach_338":
			m.pierce_op[si] = true
		m.ability[si] = abilities.get(o)
	return m


func _choose(r: RunProgress) -> int:
	var offer: Dictionary = r.current_offer()
	if offer["kind"] not in RewardOffers.CARD_DROPS:
		return 0
	if offer.has("on_trait"):
		var c0: CardData = r.resource(offer["options"][0]) as CardData
		if c0 != null and c0.card_type != DataEnums.CardType.TACTIC:
			return 0
	var best: int = 0
	var best_cost: int = -1
	for i: int in offer["options"].size():
		var c: CardData = r.resource(offer["options"][i]) as CardData
		if c != null and c.is_unit() and c.cost > best_cost:
			best = i
			best_cost = c.cost
	return best


func _price(c: CardData) -> int:
	if c.is_elite:
		return price_elite_card
	if c.is_unit():
		return price_unit
	if c.card_type == DataEnums.CardType.TACTIC:
		return price_tactic
	return price_field


## Removes up to n Standard Issue cards (Armored, Sergeant, Trooper, Grunt), floor 15. Returns removed.
func _remove_si(r: RunProgress, n: int) -> int:
	var done: int = 0
	for id: StringName in [&"si_armored", &"si_sergeant", &"si_trooper", &"si_grunt"]:
		while done < n and r.deck.size() > config.deck_floor:
			var at: int = r.deck.find(id)
			if at < 0:
				break
			r._remove_copy(at)
			r.mustered_out += 1
			done += 1
	return done


func _add_card(r: RunProgress, id: StringName, on_trait: StringName = &"") -> void:
	var c: CardData = r.resource(id) as CardData
	if c == null:
		return
	var t: StringName = on_trait if on_trait != &"" and c.can_carry(on_trait) else c.card_trait
	r._append_copy(id, t, &"")
	var ct: StringName = r.copy_trait(r.deck.size() - 1)
	if ct != &"":
		r.last_pick_trait = ct
		if r.doctrine == &"":
			r.doctrine = ct


func _weapon_level(r: RunProgress, rng: RandomNumberGenerator) -> void:
	var opts: Array[StringName] = RewardOffers.attachments(r.config, r._index.get(r.primary) as LoadoutItem, r.attachments, rng)
	if not opts.is_empty():
		r.weapon_level += 1
		r.attachments.append(opts[0])


func _shop(r: RunProgress, st: Dictionary, rng: RandomNumberGenerator, competent: bool) -> void:
	var rung: int = mini(4, int(st["rung"]))
	var main: StringName = r.main_trait()
	var cards: Array[StringName] = RewardOffers.supply_drop_on_trait(r.config, main, rng, rung, 3)
	st["shops"] += 1
	var bought: int = 0
	var order: Array = range(cards.size())
	if competent:
		order.sort_custom(func(a: int, b: int) -> bool:
			var ca: CardData = r.resource(cards[a]) as CardData
			var cb: CardData = r.resource(cards[b]) as CardData
			var va: int = (10 if a == 0 and main != &"" and ca.can_carry(main) else 0) + (ca.cost if ca.is_unit() else 0)
			var vb: int = (10 if b == 0 and main != &"" and cb.can_carry(main) else 0) + (cb.cost if cb.is_unit() else 0)
			return va > vb)
	else:
		var o2: Array = []
		while not order.is_empty():
			o2.append(order.pop_at(rng.randi_range(0, order.size() - 1)))
		order = o2
	for i: int in order:
		var c: CardData = r.resource(cards[i]) as CardData
		if c == null or _price(c) > int(st["req"]):
			continue
		if competent and not c.is_unit() and bought > 0:
			continue
		st["req"] -= _price(c)
		_add_card(r, cards[i], main if i == 0 else &"")
		bought += 1
		st["bought"] += 1
		if not competent:
			break
	while competent and int(st["req"]) >= price_remove_si and r.standard_issue_count() > 0 and r.deck.size() > config.deck_floor:
		st["req"] -= price_remove_si
		_remove_si(r, 1)


func _rest(r: RunProgress, st: Dictionary, rng: RandomNumberGenerator, competent: bool) -> void:
	st["rests"] += 1
	if r.tickets < r.config.tickets:
		r.tickets += 1
		return
	if competent and r.standard_issue_count() > 0 and r.deck.size() > config.deck_floor:
		_remove_si(r, 2)
	else:
		_weapon_level(r, rng)


func _event(r: RunProgress, st: Dictionary, rng: RandomNumberGenerator, competent: bool, ev: StringName) -> void:
	st["events"] += 1
	var pick: int = 0
	match ev:
		&"supply_truck":
			pick = 0 if competent else rng.randi_range(0, 1)
			if pick == 0:
				st["req"] += 3
			else:
				_add_card(r, &"comms_relay")
		&"audit":
			pick = 0 if (r.standard_issue_count() >= 4 or not competent) else 1
			if pick == 0:
				_remove_si(r, 2)
			else:
				st["req"] += 2
		&"wounded_scout":
			if r.tickets < r.config.tickets and int(st["req"]) >= 2 and (competent or rng.randf() < 0.5):
				st["req"] -= 2
				r.tickets += 1
			else:
				_add_card(r, &"recon_specialist")
		&"fixer":
			var at: int = r.deck.find(&"si_armored")
			if at < 0:
				at = r.deck.find(&"si_sergeant")
			if at >= 0 and (competent or rng.randf() < 0.5):
				r._remove_copy(at)
				var pool: Array[StringName] = []
				for c: CardData in r.config.reward_pool:
					if c.is_unit():
						pool.append(c.id)
				_add_card(r, pool[rng.randi_range(0, pool.size() - 1)])
		&"radio_chatter":
			st["req"] += 2
		&"memorial":
			if r.tickets < r.config.tickets:
				r.tickets += 1
			else:
				var ids: Array[int] = []
				for i: int in r.deck.size():
					var c: CardData = r.resource(r.deck[i]) as CardData
					if c != null and c.is_unit() and not c.standard_issue and not c.is_elite:
						ids.append(i)
				if not ids.is_empty():
					var i: int = ids[rng.randi_range(0, ids.size() - 1)]
					r._append_copy(r.deck[i], r.copy_trait(i), &"")
		&"rival_message":
			if r.tickets >= r.config.tickets and (competent or rng.randf() < 0.5):
				st["next_elite"] = true
			else:
				st["req"] += 1
		&"range_day":
			_weapon_level(r, rng)
		&"night_drop":
			if r.tickets >= r.config.tickets and (competent or rng.randf() < 0.5):
				if rng.randf() < 0.5:
					var elites: Array[StringName] = []
					for c: CardData in r.config.reward_pool:
						if c.is_elite:
							elites.append(c.id)
					if not elites.is_empty():
						_add_card(r, elites[rng.randi_range(0, elites.size() - 1)])
				else:
					r.tickets -= 1


func _pick_node(opts: Array, r: RunProgress, st: Dictionary, competent: bool, rng: RandomNumberGenerator) -> StringName:
	if opts.size() == 1:
		return opts[0]
	if not competent:
		return opts[rng.randi_range(0, opts.size() - 1)]
	var full: bool = r.tickets >= r.config.tickets
	var prio: Array = []
	if full:
		prio = [NODE_ELITE, NODE_SHOP, NODE_EVENT, NODE_REST] if int(st["req"]) >= price_unit else [NODE_ELITE, NODE_EVENT, NODE_SHOP, NODE_REST]
	elif r.tickets == 1:
		prio = [NODE_REST, NODE_EVENT, NODE_SHOP, NODE_ELITE]
	else:
		prio = [NODE_REST, NODE_SHOP, NODE_EVENT, NODE_ELITE] if int(st["req"]) < price_unit else [NODE_SHOP, NODE_REST, NODE_EVENT, NODE_ELITE]
	for t: StringName in prio:
		if t in opts:
			return t
	return opts[0]


func _runs(proxy: String, keep_late: bool) -> void:
	var competent: bool = proxy == "competent"
	var wins: int = 0
	var keys: Array[String] = ["F1", "F2", "E1", "F3", "E2", "F4", "BOSS"]
	var reach: Dictionary = {}
	var won: Dictionary = {}
	for k: String in keys:
		reach[k] = 0
		won[k] = 0
	var by_op: Dictionary = {}
	var by_boss: Dictionary = {}
	var boss_fight: Dictionary = {}
	var nodes: Dictionary = {}
	var totals: Dictionary = {"req_spent": 0, "bought": 0, "si_out": 0, "deck": 0, "fights": 0, "end": 0, "events": 0, "shops": 0, "rests": 0}
	var t0: int = Time.get_ticks_msec()
	for s: int in runs:
		var seed_v: int = 900000 + s
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_v * 31 + 7
		var op: StringName = OPS[s % OPS.size()] if op_mode == "rotate" else StringName(op_mode)
		if first_run:
			op = &"kestrel_ar7"
		var boss: StringName = BOSSES[(s / OPS.size()) % BOSSES.size()] if boss_mode == "rotate" else StringName(boss_mode)
		if first_run:
			boss = &"meridian"
		var cfg: RunConfig = config.duplicate(false) as RunConfig
		var fa: PackedStringArray = f_armor.split(",")
		var ml: Array[RunMatchData] = [_md(0, int(fa[0])), _md(1, int(fa[1])), _md(2, int(fa[2])), _md(3, int(fa[3])), _boss_md(boss)]
		cfg.matches = ml
		if "veterans" in mods:
			for i: int in [2, 3, 4]:
				cfg.matches[i].enemy_armor_bonus += 1
		if "veterans_lite" in mods:
			cfg.matches[4].enemy_armor_bonus += 1
		if "veterans_v3" in mods:
			cfg.matches[3].enemy_armor_bonus += 1
		cfg.reward_rungs = PackedInt32Array()
		cfg.weapon_level_after_matches = PackedInt32Array()
		cfg.perk_offer_after_matches = PackedInt32Array()
		cfg.tickets = tickets_v2 - (1 if "hardcore" in mods else 0)
		if "austerity" in mods:
			cfg.multi_pick_choices = 3
		if "austerity2" in mods:
			cfg.multi_picks = 1
		var r: RunProgress = RunProgress.create(cfg, seed_v)
		r._index[op] = op_items[op]
		for att: Resource in (op_items[op] as LoadoutItem).attachments:
			r._index[att.get("id")] = att
		r.primary = op
		r.begin()
		var st: Dictionary = {"req": req_start, "rung": 1, "shops": 0, "bought": 0, "events": 0, "rests": 0, "next_elite": false}
		var ev_deck: Array[StringName] = EVENTS.duplicate()
		for i: int in range(ev_deck.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: StringName = ev_deck[i]
			ev_deck[i] = ev_deck[j]
			ev_deck[j] = tmp
		var steps: Array = _map(first_run, rng)
		var fight_no: int = 0
		var started: int = r.deck.size()
		var si0: int = r.standard_issue_count()
		var req_seen: int = req_start
		for step: int in steps.size():
			if r.is_over():
				break
			var node: StringName = _pick_node(steps[step], r, st, competent, rng)
			nodes[node] = int(nodes.get(node, 0)) + 1
			match node:
				NODE_EVENT:
					var ev: StringName = &"audit" if first_run else ev_deck.pop_back()
					var before: int = int(st["req"])
					_event(r, st, rng, competent, ev)
					req_seen += maxi(0, int(st["req"]) - before)
				NODE_SHOP:
					var before2: int = int(st["req"])
					_shop(r, st, rng, competent)
					totals["req_spent"] += before2 - int(st["req"])
				NODE_REST:
					_rest(r, st, rng, competent)
				_:
					var elite: bool = node == NODE_ELITE
					var is_boss: bool = node == NODE_BOSS
					var key: String
					var md: RunMatchData
					var rung: int
					if is_boss:
						key = "BOSS"
						md = cfg.matches[cfg.matches.size() - 1]
					elif elite:
						key = "E1" if fight_no <= 2 else "E2"
						md = _md(2, elite_armor_1) if key == "E1" else _md(3, elite_armor_2)
						if "veterans" in mods or "veterans_lite" in mods or "veterans_v3" in mods:
							md.enemy_armor_bonus += 1
						cfg.matches.insert(r.match_index, md)
						rung = mini(4, fight_no + 1)
					else:
						key = "F%d" % (fight_no + 1)
						md = cfg.matches[r.match_index]
						rung = fight_no + 1
						if bool(st["next_elite"]):
							# Old Rival's Message: this fight is fought as an elite (+1 Armor, elite pay)
							st["next_elite"] = false
							md = md.duplicate() as RunMatchData
							md.enemy_armor_bonus += 1
							cfg.matches[r.match_index] = md
							st["challenge"] = true
					var n: int = r.match_number()
					var rr: PackedInt32Array = cfg.reward_rungs
					while rr.size() < n:
						rr.append(4)
					if not is_boss:
						rr[n - 1] = rung
						if not elite and fight_no + 1 in [1, 3, 4]:
							var wl: PackedInt32Array = cfg.weapon_level_after_matches
							wl.append(n)
							cfg.weapon_level_after_matches = wl
						if not elite and fight_no + 1 in [2, 4]:
							var pl: PackedInt32Array = cfg.perk_offer_after_matches
							pl.append(n)
							cfg.perk_offer_after_matches = pl
					cfg.reward_rungs = rr
					extra_seed = s
					var ter: Array[StringName] = _deal(rng, _terrain_count(first_run, mini(fight_no, 4), elite, is_boss), md.mode)
					if keep_late and is_boss:
						late.append(_with_op(r.player_setup(), op))
						late_trait.append(r.main_trait())
						late_op.append(op)
					reach[key] += 1
					var kit: bool = not first_run or fight_no + 1 >= first_kit_from or elite
					var ps: SideSetup = _with_op(r.player_setup(), op) if kit else r.player_setup()
					if not kit:
						ps.primary = op_items[op]
					var es: SideSetup = SideSetup.from_squad(md.squad, md)
					var m: V2Match = _new_match(cfg, md, ps, es, r.match_seed(), op if kit else &"", ter, boss if is_boss else &"")
					m.start_match()
					_play(m, _ai(proxy), _squad_ai(md.squad))
					var w: bool = m.result == &"player"
					if w:
						won[key] += 1
					if is_boss:
						var bf: Array = boss_fight.get(boss, [0, 0])
						bf[0] += 1
						bf[1] += int(w)
						boss_fight[boss] = bf
					r.record_match(m)
					var gain: int = (req_elite if (elite or bool(st.get("challenge", false))) else req_win) if w else req_loss
					st["challenge"] = false
					st["req"] += gain
					req_seen += gain
					if not elite and not is_boss:
						fight_no += 1
					st["rung"] = mini(4, fight_no + 1)
					var guard: int = 0
					while not r.current_offer().is_empty() and guard < 40:
						guard += 1
						if r.choose_offer(_choose(r)) != "":
							r.skip_offer()
		var v: bool = r.is_victory()
		if v:
			wins += 1
		var bo: Array = by_op.get(op, [0, 0])
		bo[0] += 1
		bo[1] += int(v)
		by_op[op] = bo
		var bb: Array = by_boss.get(boss, [0, 0])
		bb[0] += 1
		bb[1] += int(v)
		by_boss[boss] = bb
		totals["bought"] += int(st["bought"])
		totals["si_out"] += si0 - r.standard_issue_count()
		totals["deck"] += r.deck.size()
		totals["end"] += 1
		totals["events"] += int(st["events"])
		totals["shops"] += int(st["shops"])
		totals["rests"] += int(st["rests"])
	print("\n---- %s: %d v2 runs%s (%.1f s) ----" % [proxy.to_upper(), runs, " (first-run map)" if first_run else "",
			(Time.get_ticks_msec() - t0) / 1000.0])
	print("  RUN WIN %.1f%% (%d/%d)" % [100.0 * wins / maxf(1, runs), wins, runs])
	var line: String = "  per node (reached -> win%%):"
	for k: String in keys:
		if int(reach[k]) > 0:
			line += "  %s %d -> %.1f%%" % [k, reach[k], 100.0 * won[k] / maxf(1, reach[k])]
	print(line)
	var lo: String = "  run win by Operator:"
	for k: StringName in by_op:
		lo += "  %s %.1f%% (n=%d)" % [k, 100.0 * by_op[k][1] / maxf(1, by_op[k][0]), by_op[k][0]]
	print(lo)
	var lb: String = "  run win by boss:"
	for k: StringName in by_boss:
		var bf: Array = boss_fight.get(k, [0, 0])
		lb += "  %s %.1f%% (n=%d; boss fight %.1f%% of %d)" % [k, 100.0 * by_boss[k][1] / maxf(1, by_boss[k][0]), by_boss[k][0],
				100.0 * bf[1] / maxf(1, bf[0]), bf[0]]
	print(lb)
	var n_end: float = maxf(1, totals["end"])
	print("  nodes taken: %s" % nodes)
	print("  per run: shop cards %.2f, REQ spent %.1f, SI sent home %.2f, end deck %.1f, events %.2f, shops %.2f, rests %.2f" % [
			totals["bought"] / n_end, totals["req_spent"] / n_end, totals["si_out"] / n_end, totals["deck"] / n_end,
			totals["events"] / n_end, totals["shops"] / n_end, totals["rests"] / n_end])


# =============================================================================
# Late-deck checks
# =============================================================================

func _copy(s: SideSetup) -> SideSetup:
	var c: SideSetup = SideSetup.new()
	for f: String in ["display_name", "primary", "doctrine"]:
		c.set(f, s.get(f))
	c.deck = s.deck.duplicate()
	c.deck_traits = s.deck_traits.duplicate()
	c.deck_arts = s.deck_arts.duplicate()
	c.attachments = s.attachments.duplicate()
	c.perks = s.perks.duplicate()
	c.killstreaks = s.killstreaks.duplicate()
	return c


func _strip_op(s: SideSetup, op: StringName) -> SideSetup:
	var c: SideSetup = _copy(s)
	var keep: Array[LoadoutItem] = []
	for k: LoadoutItem in c.killstreaks:
		if not String(k.id).begins_with("ab_"):
			keep.append(k)
	c.killstreaks = keep
	return _with_op(c, op)


func _duel(sa: SideSetup, aware_a: bool, sb: SideSetup, aware_b: bool, seed_value: int, mode: int,
		ter: Array[StringName], op_a: StringName, op_b: StringName, track: bool = false) -> int:
	var md: RunMatchData = config.matches[0].duplicate() as RunMatchData
	md.mode = mode
	var m: V2Match = _new_match(config, md, _copy(sa), _copy(sb), seed_value, op_a, ter, &"", op_b)
	m.start_match()
	_play(m, _ai("competent", aware_a), _ai("competent", aware_b), track)
	return 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)


func _rand_terrain(k: int, mode: int) -> Array[StringName]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242 + k * 977
	return _deal(rng, 1 + (k % 2), mode)


func _pair(a: SideSetup, aware_a: bool, b: SideSetup, aware_b: bool, count: int, salt: int, op_a: StringName,
		op_b: StringName, track: bool = false) -> Array:
	var aw: int = 0
	var s0: int = 0
	var s1: int = 0
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var ter: Array[StringName] = _rand_terrain(salt + k / 2, mode)
		var w: int = _duel(a if a_seat == 0 else b, aware_a if a_seat == 0 else aware_b,
				b if a_seat == 0 else a, aware_b if a_seat == 0 else aware_a, 9000 + k * 7919 + salt, mode, ter,
				op_a if a_seat == 0 else op_b, op_b if a_seat == 0 else op_a, track)
		if w == 0:
			s0 += 1
		elif w == 1:
			s1 += 1
		if w == a_seat:
			aw += 1
	return [aw, s0, count, s1]


func _ops_h2h() -> void:
	print("\n---- Operators head to head: late decks, aware, seats / modes / Terrain alternate (%d per pair) ----" % h2h_n)
	var total: Dictionary = {}
	for a: int in OPS.size():
		for b: int in range(a + 1, OPS.size()):
			var aw: int = 0
			var games: int = 0
			for k: int in h2h_n / 2:
				var da: SideSetup = _strip_op(late[(k * 3) % late.size()], OPS[a])
				var db: SideSetup = _strip_op(late[(k * 3) % late.size()], OPS[b])
				var r: Array = _pair(da, true, db, true, 2, a * 1000 + b * 100 + k * 13, OPS[a], OPS[b])
				aw += int(r[0])
				games += int(r[2])
			print("  %-14s vs %-14s %5.1f%% (n=%d)" % [OPS[a], OPS[b], 100.0 * aw / maxf(1, games), games])
			for pr: Array in [[OPS[a], aw], [OPS[b], games - aw]]:
				var t: Array = total.get(pr[0], [0, 0])
				t[0] += int(pr[1])
				t[1] += games
				total[pr[0]] = t
	for k: StringName in total:
		print("  %-14s overall %5.1f%% (n=%d)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), total[k][1]])


## Per Terrain: the same matches (late deck vs F3 / F4 / E2 crews, same seeds) with the Terrain in a
## random column vs no Terrain. Also the seat-0 mirror with and without it.
func _swing() -> void:
	print("\n---- Terrain swing: player late deck vs F3 / F4 / E2 crews, paired seeds (%d per Terrain) ----" % swing_n)
	var base: Array = _swing_row(&"", -1)
	print("  %-15s player %5.1f%%   mirror seat 0 %5.1f%%" % ["(none)", base[0], base[1]])
	for t: StringName in TERRAINS:
		var row: Array = _swing_row(t, -1)
		print("  %-15s player %5.1f%% (%+5.1f)   mirror seat 0 %5.1f%% (%+5.1f)   by column A/B/C %s" % [t, row[0], row[0] - base[0],
				row[1], row[1] - base[1], row[2]])


func _swing_row(t: StringName, _col: int) -> Array:
	var w: int = 0
	var n: int = 0
	var cols: Array = [[0, 0], [0, 0], [0, 0]]
	var slots: Array = [[2, 0], [3, 0], [3, 1]]
	for k: int in swing_n:
		var sl: Array = slots[k % 3]
		var md: RunMatchData = _md(sl[0], sl[1])
		if t == &"hot_zone":
			md.mode = DataEnums.GameMode.ZONE_CONTROL
		var ter: Array[StringName] = [&"", &"", &""]
		var col: int = (k / 3) % 3
		if t != &"":
			ter[col] = t
		var op: StringName = late_op[k % late.size()]
		var ps: SideSetup = _copy(late[k % late.size()])
		var es: SideSetup = SideSetup.from_squad(md.squad, md)
		var m: V2Match = _new_match(config, md, ps, es, 7000 + k * 104729, op, ter, &"")
		m.start_match()
		_play(m, _ai("competent"), _squad_ai(md.squad))
		var won: bool = m.result == &"player"
		w += int(won)
		n += 1
		cols[col][0] += int(won)
		cols[col][1] += 1
	# mirror: same late deck both sides, the Terrain in a rotating column
	var s0: int = 0
	var mn: int = 0
	for k: int in swing_n:
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if k % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		if t == &"hot_zone":
			mode = DataEnums.GameMode.ZONE_CONTROL
		var ter2: Array[StringName] = [&"", &"", &""]
		if t != &"":
			ter2[k % 3] = t
		var d: SideSetup = late[(k * 7) % late.size()]
		var op2: StringName = late_op[(k * 7) % late.size()]
		var res: int = _duel(d, true, d, true, 5000 + k * 7919, mode, ter2, op2, op2)
		s0 += int(res == 0)
		mn += 1
	var cs: String = "%.0f/%.0f/%.0f" % [100.0 * cols[0][0] / maxf(1, cols[0][1]), 100.0 * cols[1][0] / maxf(1, cols[1][1]),
			100.0 * cols[2][0] / maxf(1, cols[2][1])]
	return [100.0 * w / maxf(1, n), 100.0 * s0 / maxf(1, mn), cs]


func _traits() -> void:
	var groups: Dictionary = {}
	for i: int in late.size():
		var t: StringName = late_trait[i]
		if t == &"":
			continue
		if not groups.has(t):
			groups[t] = []
		(groups[t] as Array).append(i)
	var keys: Array = groups.keys()
	var total: Dictionary = {}
	print("\n---- traits: v2 end-of-run decks by main trait, aware round robin (%d per pairing), random Terrain ----" % trait_n)
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			var ga: Array = groups[keys[a]]
			var gb: Array = groups[keys[b]]
			var aw: int = 0
			var games: int = 0
			for k: int in trait_n / 2:
				var ia: int = ga[k % ga.size()]
				var ib: int = gb[(k * 7 + 3) % gb.size()]
				# Same Operator on both sides (Kestrel), so the trait is the only difference (as in tune_check).
				var r: Array = _pair(_strip_op(late[ia], &"kestrel_ar7"), true, _strip_op(late[ib], &"kestrel_ar7"), true, 2,
						a * 1000 + b * 100 + k * 13, &"kestrel_ar7", &"kestrel_ar7")
				aw += int(r[0])
				games += int(r[2])
			print("  %-9s vs %-9s %5.1f%% (n=%d)" % [keys[a], keys[b], 100.0 * aw / maxf(1, games), games])
			for pr: Array in [[keys[a], aw], [keys[b], games - aw]]:
				var t: Array = total.get(pr[0], [0, 0])
				t[0] += int(pr[1])
				t[1] += games
				total[pr[0]] = t
	for k: StringName in total:
		print("  %-9s overall %5.1f%% (n=%d, decks %d)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), total[k][1], (groups[k] as Array).size()])


func _duel_late() -> void:
	var k: int = mini(late.size(), late_n)
	var d: Array = [0, 0]
	var dt: Array = [0, 0]
	for i: int in k:
		var r: Array = _pair(late[i], true, late[i], false, 4, i * 17 + 5, late_op[i], late_op[i])
		d[0] += r[0]
		d[1] += r[2]
	print("\n  duel:   synergy-aware vs blind, same late deck   %5.1f%% (n=%d)" % [100.0 * d[0] / maxf(1, d[1]), d[1]])
	# Terrain-aware vs Terrain-blind (both synergy-aware): the V2View on one side only.
	for i: int in k:
		for j: int in 4:
			var mode: int = DataEnums.GameMode.ZONE_CONTROL if j < 2 else DataEnums.GameMode.FIREFIGHT
			var ter: Array[StringName] = _rand_terrain(i * 4 + j + 1, mode)
			var md: RunMatchData = config.matches[0].duplicate() as RunMatchData
			md.mode = mode
			var m: V2Match = _new_match(config, md, _copy(late[i]), _copy(late[i]), 3100 + i * 911 + j, late_op[i], ter, &"", late_op[i])
			m.start_match()
			var a: V2Ai = _ai("competent")
			var b: V2Ai = _ai("competent")
			var aware_seat: int = j % 2
			a.aware = aware_seat == 0
			b.aware = aware_seat == 1
			_play(m, a, b)
			var winner: int = 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)
			dt[0] += int(winner == aware_seat)
			dt[1] += 1
	print("  duel:   Terrain-aware vs Terrain-blind, same deck  %5.1f%% (n=%d)" % [100.0 * dt[0] / maxf(1, dt[1]), dt[1]])


func _mirrors() -> void:
	var k: int = mini(late.size(), late_n)
	var ml: Array = [0, 0, 0]
	init_stats = [0, 0, 0]
	var reps: int = maxi(2, mirror_n / maxi(1, k))
	reps += reps % 2
	for i: int in k:
		var r3: Array = _pair(late[i], true, late[i], true, reps, i * 17 + 9, late_op[i], late_op[i], true)
		ml[0] += r3[1]
		ml[1] += r3[2]
		ml[2] += r3[3]
	var starter: SideSetup = _with_op(RunProgress.create(config, 1).player_setup(), &"kestrel_ar7")
	var r4: Array = _pair(starter, true, starter, true, mirror_n, 77, &"kestrel_ar7", &"kestrel_ar7", true)
	print("  mirror: seat 0, late decks (Terrain random)       %5.1f%% (n=%d)" % [100.0 * ml[0] / maxf(1, ml[1]), ml[1]])
	print("  mirror: seat 0, Standard Issue starter            %5.1f%% (n=%d)" % [100.0 * r4[1] / maxf(1, r4[2]), r4[2]])
