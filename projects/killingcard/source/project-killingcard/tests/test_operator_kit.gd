# test_operator_kit.gd
# Purpose: kc-v2-impl Operator kits (run-v2.md §7, head V2): the four Operators' data, each passive,
#   each once-per-match ability (free, from round 1, needs the Operator where it says so, undo), the
#   kit off by default (enemies, old matches), ability_view() for the button, and the AI using it.
# Author: Mechanics Developer Agent (kc-v2-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


func _op(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


func _kit_match(op_id: String, deck: Array = [], enemy_deck: Array = [], kit: bool = true) -> MatchState:
	var ps: SideSetup = F.setup(deck, _op(op_id))
	ps.operator_kit = kit
	var es: SideSetup = F.setup(enemy_deck, F.kestrel())
	return F.new_match(ps, es)


func test_operator_data_head_v2() -> void:
	var k: LoadoutItem = _op("kestrel_ar7")
	var l: LoadoutItem = _op("longreach_338")
	var w: LoadoutItem = _op("wasp_9")
	var b: LoadoutItem = _op("bastion_60")
	assert_eq([k.operator_firepower, k.operator_armor], [3, 7], "Kestrel 3/7")
	assert_eq([l.operator_firepower, l.operator_armor, l.pick, l.pierce], [3, 6, true, true], "Longreach 3/6 Pick, Pierce passive")
	assert_eq([w.operator_firepower, w.operator_armor, w.first_shot, w.rotations_per_round], [2, 7, true, 2], "Wasp-9 2/7")
	assert_eq([b.operator_firepower, b.operator_armor, b.cover, b.weapon_class], [2, 8, 1, DataEnums.WeaponClass.LMG], "Bastion-60 LMG 2/8 Cover 1")
	var abs: Array = [k, l, w, b].map(func(o: LoadoutItem) -> StringName: return (o.ability as LoadoutItem).id)
	assert_eq(abs, [&"ab_dig_in", &"ab_marked_shot", &"ab_flashbang", &"ab_covering_fire"], "one ability each")
	for o: LoadoutItem in [k, l, w, b]:
		var ab: LoadoutItem = o.ability as LoadoutItem
		assert_eq([ab.slot, ab.supply_cost, ab.uses_per_match], [DataEnums.LoadoutSlot.ABILITY, 0, 1], "%s: free, once per match" % ab.id)
		assert_true(o.passive_name != "" and o.passive_text != "", "%s has a passive line" % o.id)
	assert_eq([k.unlock, l.unlock, w.unlock, b.unlock], [&"", &"first_run_done", &"boss_reached", &"first_win"], "unlocks (§7)")


func test_kit_off_by_default() -> void:
	var m: MatchState = _kit_match("kestrel_ar7", [], [], false)
	assert_eq(m.ability_view(P), {}, "no ability without the kit")
	assert_null_item(m)
	assert_eq(m.ability_view(E), {}, "the enemy never has one")


func assert_null_item(m: MatchState) -> void:
	assert_true(m.find_item(P, &"ab_dig_in") == null, "not usable")


func test_quartermaster_opening_hand_plus_one() -> void:
	var deck: Array = []
	for i: int in 12:
		deck.append(F.rifleman())
	var on: MatchState = _kit_match("kestrel_ar7", deck)
	var off: MatchState = _kit_match("kestrel_ar7", deck, [], false)
	assert_eq(on.sides[P].hand.size(), off.sides[P].hand.size() + 1, "Kestrel's opening hand has 1 more card")


func test_dig_in_cover_in_a_column_once_per_match_with_undo() -> void:
	var m: MatchState = _kit_match("kestrel_ar7")
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 5), F.MID)
	var v: Dictionary = m.ability_view(P)
	assert_eq([v["id"], v["ready"], v["target"], v["needs_operator"]], [&"ab_dig_in", true, &"zone", false], "button ready from round 1, no Operator needed")
	assert_eq(m.submit(P, RulesIntent.use_item(&"ab_dig_in", F.MID))["ok"], true, "free in round 1")
	assert_eq(m.sides[P].supply, m.config.supply_for_round(1), "costs 0 Supply")
	assert_eq(m.ability_view(P)["code"], &"no_uses_left", "queued = used")
	assert_eq(m.ability_view(P)["reason"], "Used this match", "the button says why")
	assert_eq(m.undo_last(P)["ok"], true, "undo")
	assert_true(m.ability_view(P)["ready"], "ready again after undo")
	m.submit(P, RulesIntent.use_item(&"ab_dig_in", F.MID))
	m.reveal()
	assert_eq(m.cover_of(a), 1, "Cover 1 this round")
	var used: Array[Dictionary] = F.events_of(m, RulesEvent.ITEM_REVEALED)
	assert_true(bool(used[0]["ability"]), "the event marks it an ability")
	m.firefight()
	m.score()
	m.begin_round()
	assert_eq(m.cover_of(a), 0, "this round only")
	assert_false(m.ability_view(P)["ready"], "once per match")


func test_marked_shot_needs_the_operator_and_hits_its_column() -> void:
	var m: MatchState = _kit_match("longreach_338")
	var foe: RulesUnit = F.place(m, E, F.unit("foe", 0, 5), F.LEFT)
	var other: RulesUnit = F.place(m, E, F.unit("other", 0, 5), F.MID)
	var v: Dictionary = m.ability_view(P)
	assert_eq([v["ready"], v["code"], v["reason"]], [false, &"operator_not_placed", "Deploy your Operator first"], "needs the Operator")
	assert_true(m.sides[P].operator_unit.pierce, "Overpenetration: the Operator has Pierce")
	m.submit(P, RulesIntent.place_operator(F.LEFT))
	v = m.ability_view(P)
	assert_true(v["ready"], "arriving this Deploy is enough")
	assert_eq(v["target"], &"enemy", "picks an enemy")
	var uids: Array = (v["targets"] as Array).map(func(t: Dictionary) -> int: return int(t["target_uid"]))
	assert_true(foe.uid in uids and other.uid not in uids, "only enemies in the Operator's column")
	assert_true(m.submit(P, RulesIntent.use_item(&"ab_marked_shot", -1, foe.uid))["ok"], "Marked Shot")
	m.reveal()
	assert_eq(foe.armor, 2, "3 damage")
	var off: MatchState = _kit_match("longreach_338", [], [], false)
	assert_false(off.sides[P].operator_unit.pierce, "no Pierce with the kit off")


func test_flashbang_and_covering_fire() -> void:
	var m: MatchState = _kit_match("wasp_9")
	var pm: RulesUnit = F.place(m, E, F.point_man(), F.MID)
	F.place_operator(m, P, F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"ab_flashbang"))["ok"], "Flashbang")
	m.reveal()
	assert_false(m.has_first_shot(pm), "loses First Shot")
	assert_eq(m.firepower_of(pm), 0, "-2 FP")
	var b: MatchState = _kit_match("bastion_60")
	var op: RulesUnit = F.place_operator(b, P, F.RIGHT)
	var buddy: RulesUnit = F.place(b, P, F.unit("buddy", 2, 4), F.RIGHT)
	assert_eq([b.cover_of(op), op.pierce], [1, true], "Sandbagged Cover 1, LMG Pierce")
	assert_true(b.submit(P, RulesIntent.use_item(&"ab_covering_fire"))["ok"], "Covering Fire")
	b.reveal()
	assert_eq([b.firepower_of(op), b.firepower_of(buddy)], [3, 3], "+1 FP in the Operator's column")


func test_operator_kit_view() -> void:
	var m: MatchState = _kit_match("bastion_60")
	var kv: Dictionary = m.operator_kit_view(P)
	assert_eq([kv["passive_name"], kv["ability_name"], kv["kit_on"]], ["Sandbagged", "Covering Fire", true], "kit view")


func test_ai_uses_its_ability() -> void:
	var cfg: RunConfig = load("res://data/run_config.tres")
	var uses: int = 0
	for s: int in 6:
		var slot: RunMatchData = cfg.matches[s % 4]
		var ps: SideSetup = SideSetup.new()
		ps.deck = cfg.starter_deck.duplicate()
		ps.primary = _op(["longreach_338", "kestrel_ar7", "bastion_60"][s % 3])
		ps.operator_kit = true
		var h: MatchHooks = MatchHooks.new()
		h.mode_rules = ModeRules.create(slot.mode, cfg)
		var m: MatchState = MatchState.new(cfg, slot.map, ps, SideSetup.from_squad(slot.squad, slot), 500 + s, h)
		m.start_match()
		var a: AiPlayer = AiPlayer.new(AiPersonality.new())
		var b: AiPlayer = AiPlayer.for_squad(slot.squad)
		while m.phase != MatchState.Phase.ENDED and m.round_number <= 12:
			b.take_turn(m, E)
			a.take_turn(m, P)
			assert_eq(a.last_rejected.size(), 0, "no refused intents")
			m.resolve_round()
			m.begin_round()
		for ev: Dictionary in F.events_of(m, RulesEvent.ITEM_USED):
			if ev["side"] == &"player" and bool(ev.get("ability", false)):
				uses += 1
		assert_true(m.sides[P].ability_used() or m.phase == MatchState.Phase.ENDED, "match %d ran" % s)
	assert_true(uses >= 3, "the AI uses its Operator ability (%d uses in 6 matches)" % uses)
