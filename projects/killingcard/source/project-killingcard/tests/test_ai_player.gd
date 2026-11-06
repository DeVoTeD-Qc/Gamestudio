# test_ai_player.gd
# Purpose: p07 enemy AI. Fairness (the AI only gets an AiView of public information,
#   never the MatchState, the player's hand or face-down plays: checked structurally
#   and behaviourally), red-dot intel (dots for AI deployments match its committed unit
#   deployments 100%, and nothing else, Ruling 13), determinism with the match seed,
#   mulligan, sensible use of Lethal / killstreaks, and the personalities' positions.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const Sim = preload("res://tests/mode_sim.gd")
const F = preload("res://tests/rules_fixtures.gd")
const P: int = MatchState.PLAYER
const E: int = MatchState.ENEMY
const ENGINE_CLASSES: Array[String] = ["MatchState", "RulesSide", "RulesCard", "RulesUnit", "MatchHooks", "SideSetup"]


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func _squad(id: String) -> SquadData:
	return load("res://data/squads/%s.tres" % id) as SquadData


## Run-config slot `index` (0 Rusher ZC, 1 Anchor ZC, 2 Rusher FF, 3 Anchor FF; modes since p19).
func _slot(index: int) -> RunMatchData:
	return _config().matches[index]


## Plays `rounds` full rounds (AI enemy first, greedy player), ending in the next Deploy.
func _advance(m: MatchState, ai: AiPlayer, rounds: int) -> void:
	for r: int in rounds:
		if m.phase == MatchState.Phase.ENDED:
			return
		ai.take_turn(m, E)
		Sim._greedy_deploy(m, P)
		m.set_ready(P)
		m.resolve_round()
		m.begin_round()


# =============================================================================
# Fairness
# =============================================================================

## Walks every script variable of the view: classes of the objects it holds, every
## card / unit uid it carries (fields named "uid"), every card id (StringName values).
func _scan(value: Variant, out: Dictionary) -> void:
	match typeof(value):
		TYPE_STRING_NAME:
			out["ids"][value] = true
		TYPE_ARRAY:
			for v: Variant in value:
				_scan(v, out)
		TYPE_DICTIONARY:
			for k: Variant in value:
				if String(k).ends_with("uid"):
					out["uids"][value[k]] = true
				_scan(value[k], out)
		TYPE_OBJECT:
			if value == null:
				return
			var o: Object = value
			var cls: String = o.get_class()
			var script: Script = o.get_script()
			if script != null and script.get_global_name() != &"":
				cls = script.get_global_name()
			out["classes"][cls] = true
			if o is AiView:
				for prop: Dictionary in o.get_property_list():
					if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
						_scan(o.get(prop["name"]), out)


func test_view_holds_only_public_data() -> void:
	for slot_index: int in [0, 1]:
		var slot: RunMatchData = _slot(slot_index)
		var m: MatchState = Sim.match_for(_config(), slot, 41 + slot_index)
		var ai: AiPlayer = AiPlayer.for_squad(slot.squad)
		_advance(m, ai, 3)
		# The player commits face-down plays first here (worst case for the AI's view).
		Sim._greedy_deploy(m, P)
		var secret: Dictionary = {}
		for c: RulesCard in m.sides[P].hand:
			secret[c.uid] = c.card.id
		for c: RulesCard in m.sides[P].deck:
			secret[c.uid] = c.card.id
		for play: Dictionary in m.sides[P].plays:
			if play["card"] != null and play["kind"] != &"unit":
				secret[(play["card"] as RulesCard).uid] = (play["card"] as RulesCard).card.id
		for z: int in 3:
			for entry: Dictionary in m.sides[P].equipment[z]:
				if (entry["card"] as RulesCard).card.hidden:
					secret[(entry["card"] as RulesCard).uid] = &"hidden equipment"
		var view: AiView = AiView.capture(m, E)
		var out: Dictionary = {"classes": {}, "uids": {}, "ids": {}}
		_scan(view, out)
		for cls: String in ENGINE_CLASSES:
			assert_false(out["classes"].has(cls), "view must not hold a %s" % cls)
		for cls: Variant in out["classes"]:
			assert_true(cls in ["AiView", "CardData", "LoadoutItem", "EffectData"], "unexpected object in view: %s" % cls)
		for uid: Variant in secret:
			assert_false(out["uids"].has(uid), "view leaks hidden player card uid %d (%s)" % [uid, secret[uid]])
		assert_false(out["ids"].has(&"tripwire_charge") and not _enemy_owns(m, &"tripwire_charge"), "hidden Tripwire id leaked")
		assert_eq(view.foe_hand_count, m.sides[P].hand.size(), "hand size is public")


func _enemy_owns(m: MatchState, id: StringName) -> bool:
	for c: RulesCard in m.sides[E].hand:
		if c.card.id == id:
			return true
	for z: int in 3:
		for entry: Dictionary in m.sides[E].equipment[z]:
			if (entry["card"] as RulesCard).card.id == id:
				return true
	return false


func test_planner_never_sees_the_match() -> void:
	for path: String in ["res://scripts/ai/ai_planner.gd", "res://scripts/ai/ai_personality.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_true(src.length() > 0, "%s readable" % path)
		for word: String in ENGINE_CLASSES + [".sides", "state.", "hooks"]:
			# Comments may name the engine; code may not.
			var code_lines: Array = Array(src.split("\n")).filter(func(l: String) -> bool:
				return not l.strip_edges().begins_with("#") and not l.strip_edges().begins_with("##"))
			var hit: bool = code_lines.any(func(l: String) -> bool: return l.split("#")[0].contains(word))
			assert_false(hit, "%s code mentions %s" % [path.get_file(), word])
	# plan() / plan_mulligan() take an AiView, nothing else.
	for method: Dictionary in (AiPlanner as Script).get_script_method_list():
		if method["name"] in ["plan", "plan_mulligan"]:
			assert_eq(method["args"].size(), 1, "%s takes one argument" % method["name"])
			assert_eq(String(method["args"][0]["class_name"]), "AiView", "%s takes an AiView" % method["name"])


## The same public situation with a different hidden player hand, deck, face-down
## non-unit plays and hidden Equipment gives exactly the same AI plan.
func test_plan_ignores_hidden_information() -> void:
	var tripwire: CardData = load("res://data/cards/tripwire_charge.tres")
	var breach: CardData = load("res://data/cards/breach_and_clear.tres")
	var gunner: CardData = load("res://data/cards/gunner.tres")
	var compared: int = 0
	for slot_index: int in [0, 1, 2, 3]:
		var slot: RunMatchData = _slot(slot_index)
		for rounds: int in [0, 2, 4]:
			var a: MatchState = Sim.match_for(_config(), slot, 900 + rounds)
			var b: MatchState = Sim.match_for(_config(), slot, 900 + rounds)
			_advance(a, AiPlayer.for_squad(slot.squad), rounds)
			_advance(b, AiPlayer.for_squad(slot.squad), rounds)
			if a.phase == MatchState.Phase.ENDED:
				continue
			# Match b: other hidden cards and face-down plays the AI must not notice.
			var pb: RulesSide = b.sides[P]
			var hand_size: int = a.sides[P].hand.size() + 2  # two go face-down below
			pb.hand.clear()
			for i: int in hand_size:
				pb.hand.append(RulesCard.new(b.new_uid(), [tripwire, breach, gunner][i % 3]))
			pb.deck.reverse()
			pb.supply = 10
			assert_true(b.submit(P, RulesIntent.play_card(F.hand_uid(b, P, "tripwire_charge"), 1))["ok"], "player trap")
			if not b.sides[E].units_on_board().is_empty():
				var z: int = b.sides[E].units_on_board()[0].zone
				assert_true(b.submit(P, RulesIntent.play_card(F.hand_uid(b, P, "breach_and_clear"), z))["ok"], "player tactic")
			pb.equipment[0].append({"card": RulesCard.new(b.new_uid(), tripwire), "round": b.round_number})
			var ai_a: AiPlayer = AiPlayer.for_squad(slot.squad)
			var ai_b: AiPlayer = AiPlayer.for_squad(slot.squad)
			var plan_a: Dictionary = ai_a.planner.plan(AiView.capture(a, E))
			var plan_b: Dictionary = ai_b.planner.plan(AiView.capture(b, E))
			assert_eq(str(plan_b["intents"]), str(plan_a["intents"]), "slot %d round %d: plan changed with hidden info" % [slot_index, a.round_number])
			compared += 1
	assert_true(compared >= 10, "compared %d situations" % compared)


# =============================================================================
# Red dots (Ruling 13)
# =============================================================================

func test_red_dots_match_ai_deployments_exactly() -> void:
	var rounds: int = 0
	var non_unit_plays: int = 0
	var dots_shown: int = 0
	for slot_index: int in [0, 1, 2, 3]:
		var slot: RunMatchData = _slot(slot_index)
		for s: int in 4:
			var m: MatchState = Sim.match_for(_config(), slot, 300 + s * 7 + slot_index)
			var ai: AiPlayer = AiPlayer.for_squad(slot.squad)
			while m.phase != MatchState.Phase.ENDED and m.round_number <= 12:
				ai.take_turn(m, E)
				assert_true(ai.last_rejected.is_empty(), "engine refused AI intents: %s" % str(ai.last_rejected))
				# Card identity by uid (cards drawn mid-turn by Ammo Resupply included).
				var card_of: Dictionary = {}
				for play: Dictionary in m.sides[E].plays:
					if play["card"] != null:
						card_of[(play["card"] as RulesCard).uid] = (play["card"] as RulesCard).card
				var expected: PackedInt32Array = PackedInt32Array([0, 0, 0])
				var expected_ids: Array = [[], [], []]
				for it: Dictionary in ai.last_intents:
					var z: int = int(it.get("zone", -1))
					match it["type"]:
						RulesIntent.PLACE_OPERATOR, RulesIntent.ROTATE:
							expected[z] += 1
							expected_ids[z].append(m.sides[E].operator_unit.source_id)
						RulesIntent.PLAY_CARD:
							var card: CardData = card_of[int(it["card_uid"])]
							if card.card_type == DataEnums.CardType.UNIT:
								expected[z] += 1
								expected_ids[z].append(card.id)
							else:
								non_unit_plays += 1
						RulesIntent.USE_ITEM:
							non_unit_plays += 1
				assert_eq(m.red_dots(P), expected, "round %d red dots" % m.round_number)
				# Recon-style full reveal shows the same deployments by name (and nothing else).
				m.sides[P].flags[DataEnums.EffectKind.REVEAL_DEPLOYMENTS] = m.round_number
				for z: int in 3:
					var shown: Array = Array(m.revealed_red_dots(P, z))
					shown.sort()
					var want: Array = expected_ids[z].duplicate()
					want.sort()
					assert_eq(str(shown), str(want), "round %d zone %d revealed dots" % [m.round_number, z])
					dots_shown += expected[z]
				m.sides[P].flags.erase(DataEnums.EffectKind.REVEAL_DEPLOYMENTS)
				rounds += 1
				Sim._greedy_deploy(m, P)
				m.set_ready(P)
				m.resolve_round()
				m.begin_round()
	assert_true(rounds >= 80, "checked %d rounds" % rounds)
	assert_true(non_unit_plays >= 20, "AI also played %d tactics / equipment / items (never dots)" % non_unit_plays)
	assert_true(dots_shown >= 100, "%d dots checked" % dots_shown)


# =============================================================================
# Determinism
# =============================================================================

func _transcript(slot: RunMatchData, seed_value: int) -> String:
	var m: MatchState = Sim.match_for(_config(), slot, seed_value)
	var ai: AiPlayer = AiPlayer.for_squad(slot.squad)
	var log: Array = []
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 12:
		ai.take_turn(m, E)
		log.append(str(ai.last_intents))
		Sim._greedy_deploy(m, P)
		m.set_ready(P)
		m.resolve_round()
		m.begin_round()
	log.append(String(m.result))
	return "\n".join(log)


func test_same_seed_same_ai_play() -> void:
	for slot_index: int in [0, 1]:
		var slot: RunMatchData = _slot(slot_index)
		var first: String = _transcript(slot, 77)
		assert_eq(_transcript(slot, 77), first, "slot %d replays exactly" % slot_index)
		var differs: bool = false
		for s: int in [78, 79, 80]:
			differs = differs or _transcript(slot, s) != first
		assert_true(differs, "other seeds give other matches")


# =============================================================================
# Decisions
# =============================================================================

func test_mulligan_puts_back_expensive_cards() -> void:
	var v: AiView = AiView.new()
	v.mulligans_left = 1
	var ids: Array[String] = ["point_man", "breacher", "demolitions_expert", "okafor_anvil", "rifleman"]
	for i: int in ids.size():
		v.hand.append({"uid": 10 + i, "card": load("res://data/cards/%s.tres" % ids[i])})
	var rusher: AiPlanner = AiPlanner.new(AiPersonality.from_squad(_squad("squad_rusher")))
	assert_eq(str(rusher.plan_mulligan(v)), str([12, 13]), "Rusher returns the 4- and 5-cost cards")
	var anchor: AiPlanner = AiPlanner.new(AiPersonality.from_squad(_squad("squad_anchor")))
	assert_eq(str(anchor.plan_mulligan(v)), str([13]), "Anchor keeps one 4-cost card")
	v.mulligans_left = 0
	assert_true(rusher.plan_mulligan(v).is_empty(), "no mulligan left")
	# In a real Round 1 the AI's mulligan goes through the engine.
	var slot: RunMatchData = _slot(0)
	var m: MatchState = Sim.match_for(_config(), slot, 5)
	AiPlayer.for_squad(slot.squad).take_turn(m, E)
	assert_eq(m.sides[E].mulligans_left, 0, "mulligan used or given up in Round 1")


## A real match at Round 1 Deploy with an empty AI hand and a hand-built board.
func _staged(squad_id: String) -> MatchState:
	var cfg: RunConfig = _config()
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(DataEnums.GameMode.ZONE_CONTROL, cfg)
	var m: MatchState = MatchState.new(cfg, _slot(0).map, Sim.player_setup(cfg),
			SideSetup.from_squad(_squad(squad_id)), 11, hooks)
	m.start_match()
	m.sides[E].hand.clear()
	m.sides[E].mulligans_left = 0
	m.sides[P].operator_can_deploy = false
	return m


func _used(ai: AiPlayer, item_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in ai.last_intents:
		if it["type"] == RulesIntent.USE_ITEM and it["item_id"] == item_id:
			out.append(it)
	return out


func test_killstreak_from_tray_hits_the_crowded_zone() -> void:
	# The Rival carries Mortar Barrage (p19 moved the Rusher to Recon Drone + Sentry Turret).
	var m: MatchState = _staged("squad_black_meridian")
	F.place_operator(m, E, 0)
	for i: int in 3:
		F.place(m, P, load("res://data/cards/rifleman.tres"), 2)
	StreakTracker.grant(m, E, &"mortar_barrage")
	var ai: AiPlayer = AiPlayer.for_squad(_squad("squad_black_meridian"))
	ai.take_turn(m, E)
	var mortar: Array[Dictionary] = _used(ai, &"mortar_barrage")
	assert_eq(mortar.size(), 1, "Mortar used: %s" % str(ai.last_intents))
	if mortar.size() == 1:
		assert_eq(int(mortar[0]["zone"]), 2, "on the zone with three 2-Armor Riflemen")
	m.set_ready(P)
	m.resolve_round()
	assert_eq(m.sides[P].line(2).size(), 0, "all three eliminated")


func test_personalities_keep_their_positions() -> void:
	var counts: Dictionary = {}
	for slot_index: int in [1, 2]:  # Anchor (slot 1, Zone Control since p19), Rusher (slot 2, Firefight)
		var slot: RunMatchData = _slot(slot_index)
		var zones: Array[int] = [0, 0, 0]
		var op_zones: Array[int] = [0, 0, 0]
		for s: int in 16:  # kc-syn: 12 seeds (5 was too noisy); kc-fight-impl: 16 (the beat order evens the zone shares out)
			var m: MatchState = Sim.match_for(_config(), slot, 500 + s)
			var ai: AiPlayer = AiPlayer.for_squad(slot.squad)
			while m.phase != MatchState.Phase.ENDED and m.round_number <= 12:
				ai.take_turn(m, E)
				for play: Dictionary in m.sides[E].plays:
					if play["kind"] == &"unit":
						zones[int(play["zone"])] += 1
				Sim._greedy_deploy(m, P)
				m.set_ready(P)
				m.resolve_round()
				var op: RulesUnit = m.sides[E].operator_unit
				if op.is_on_board():
					op_zones[op.zone] += 1
				m.begin_round()
		counts[slot.squad.id] = [zones, op_zones]
	var close_zone: int = _slot(0).map.zone_ranges.find(DataEnums.RangeTag.CLOSE)
	var rusher: Array = counts[&"squad_rusher"][0]
	var anchor: Array = counts[&"squad_anchor"][0]
	print("     unit deployments per zone: Rusher %s, Anchor %s (Close zone = %d)" % [rusher, anchor, close_zone])
	for z: int in 3:
		if z != close_zone:
			assert_true(rusher[close_zone] > rusher[z], "Rusher deploys mostly to the Close zone: %s" % str(rusher))
	assert_true(anchor[1] > anchor[0] and anchor[1] > anchor[2], "Anchor contests the centre zone: %s" % str(anchor))
	var anchor_op: Array = counts[&"squad_anchor"][1]
	assert_true(anchor_op[1] >= anchor_op[0] + anchor_op[2], "Anchor's Operator holds Mid: %s" % str(anchor_op))
