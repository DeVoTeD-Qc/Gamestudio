# ai_view.gd
# Purpose: The fairness wall between the rules engine and the enemy AI (core-rules §7:
#   "the AI commits its plan before the player deploys and never reads the player's
#   face-down cards"). capture() copies ONLY what the AI's side may know into plain
#   values: the board (both sides' units on it, with their current stats), its own
#   hand / Supply / loadout / Streak Tray, public counters (scores, streaks, hand and
#   deck sizes), the opponent's face-up Equipment, and the intel its side is allowed
#   (red_dots / revealed_red_dots: Ruling 13). It never copies the opponent's hand,
#   deck order, face-down plays or hidden Equipment, and it keeps no reference to
#   MatchState, RulesSide, RulesCard or RulesUnit, so AiPlanner (which only gets this
#   object) cannot reach them. tests/test_ai_player.gd checks both properties.
#   Frame: "me" = the AI's side, "foe" = the other side. Zones 0 = left, 1 = mid, 2 = right.
#   Unit records are Dictionaries (see _unit_record); the planner clones what it changes.
#   Fields (CardType.EQUIPMENT, kc-field-impl): my_fields / foe_fields hold the Field cards per
#   column (the foe's hidden traps are left out). Unit records leave Field auras OUT of fp /
#   cover, because "your frontline unit" auras follow the line; the planner re-applies them to
#   whoever stands in front in its estimate (AiPlanner._field_aura).
# Dependencies: DataEnums, CardData, LoadoutItem, EffectData, LoadoutRules, StreakTracker,
#   ModeRules (MatchState passed in to capture() only).
# Author: Mechanics Developer Agent
class_name AiView
extends RefCounted

const ZONES: int = 3
const ME: int = 0
const FOE: int = 1

## Which MatchState side this view belongs to (0 player, 1 enemy).
var side: int = 1
var seed_value: int = 0
var round_number: int = 0
## DataEnums.GameMode of the match (ZONE_CONTROL / FIREFIGHT); scoring target.
var mode: int = DataEnums.GameMode.ZONE_CONTROL
var target: int = 6
var round_cap: int = 8
var zone_ranges: Array[int] = [0, 1, 2]
var zone_capacity: int = 4
var hand_cap: int = 7
## range_bonus[weapon_class][zone] = Firepower bonus of that class in that zone on this map.
var range_bonus: Array = []

# --- my side ------------------------------------------------------------------------------
var supply: int = 0
## [{uid: int, card: CardData, level: int}] in hand order (level: kc-syn copy level, 0 = Recruit).
var hand: Array[Dictionary] = []
var mulligans_left: int = 0
var my_score: int = 0
var my_streak: int = 0
var my_deck_count: int = 0
## Stat scaling of my new units (bracket bonus).
var my_firepower_bonus: int = 0
var my_armor_bonus: int = 0
## True while the foe's side-wide Cover removal (Recon Drone) also strips my new units.
var my_cover_removed: bool = false
## True while my side-wide Cover removal (Recon Drone) strips the foe's Cover.
var foe_cover_removed: bool = false
## A START_OF_FIREFIGHT effect of mine is active this round (Attack Helo): damage per zone.
var my_firefight_damage: int = 0
var foe_firefight_damage: int = 0
## [{item: LoadoutItem, ready: bool}] for the killstreaks in the tray.
var items: Array[Dictionary] = []
var tray: Array[StringName] = []
## Card ids of my Equipment (Fields) per zone.
var my_equipment: Array = [[], [], []]
## My Field cards per zone (CardData, placement order; hidden traps included).
var my_fields: Array = [[], [], []]
## kc-syn: traits of my visible Trained Fields per zone (they count for my sets).
var my_field_traits: Array = [[], [], []]
## kc-syn: my Doctrine trait (+1 to that set count), and the Operator's Supply cost to place.
var my_doctrine: StringName = &""
var operator_cost: int = 0

# --- my Operator --------------------------------------------------------------------------
var op_exists: bool = false
var op_uid: int = -1
## Zone now (-1 = off the board).
var op_zone: int = -1
var op_can_deploy: bool = false
var op_rotations_left: int = 0
## Operator record as it would be in each zone (fp / first_shot differ by zone).
var op_by_zone: Array[Dictionary] = []

# --- foe (public information only) --------------------------------------------------------
var foe_score: int = 0
var foe_streak: int = 0
var foe_hand_count: int = 0
var foe_deck_count: int = 0
var foe_tray_count: int = 0
var foe_op_on_board: bool = false
## Card ids of the foe's face-up Equipment per zone (hidden Equipment such as Tripwire is left out).
var foe_equipment: Array = [[], [], []]
## The foe's face-up Field cards per zone (CardData; hidden traps left out).
var foe_fields: Array = [[], [], []]
## What my side's minimap shows: foe unit deployments per zone (count only, Ruling 13).
var red_dots: PackedInt32Array = PackedInt32Array([0, 0, 0])
## Card ids behind the red dots of zones my side has revealed this round.
var revealed: Array = [[], [], []]

# --- board ----------------------------------------------------------------------------------
## lines[ME or FOE][zone] = Array of unit records, front (point man) first.
var lines: Array = [[[], [], []], [[], [], []]]


## Snapshot of what `p_side` may know right now. The only code of the AI that reads MatchState.
static func capture(state, p_side: int) -> AiView:
	var v: AiView = AiView.new()
	var me = state.sides[p_side]
	var foe = state.sides[1 - p_side]
	var cfg = state.config
	v.side = p_side
	v.seed_value = int(state.seed_value)
	v.round_number = int(state.round_number)
	var rules = state.hooks.mode_rules if state.hooks != null else null
	if rules != null:
		v.mode = int(rules.mode)
		v.target = int(rules.target)
		v.round_cap = int(rules.round_cap)
	v.zone_ranges.clear()
	for r: int in state.zone_ranges:
		v.zone_ranges.append(r)
	v.zone_capacity = int(cfg.zone_capacity)
	v.hand_cap = int(cfg.hand_cap)
	v.range_bonus.clear()
	for wc: int in DataEnums.WeaponClass.size():
		var row: Array[int] = []
		for z: int in ZONES:
			row.append(cfg.range_bonus(wc, v.zone_ranges[z]))
		v.range_bonus.append(row)

	v.supply = int(me.supply)
	for c in me.hand:
		v.hand.append({"uid": int(c.uid), "card": c.card, "level": int(c.level), "trait": c.chosen_trait})
	v.my_doctrine = me.setup.doctrine
	v.operator_cost = int(state.operator_cost())
	v.mulligans_left = int(me.mulligans_left)
	v.my_score = int(me.score)
	v.my_streak = int(me.streak)
	v.my_deck_count = me.deck.size()
	v.my_firepower_bonus = int(me.setup.firepower_bonus)
	v.my_armor_bonus = int(me.setup.armor_bonus)
	v.my_cover_removed = foe.has_flag(DataEnums.EffectKind.REMOVE_COVER, state.round_number)
	v.foe_cover_removed = me.has_flag(DataEnums.EffectKind.REMOVE_COVER, state.round_number)
	for f: Dictionary in state.firefight_effects:
		if int(f["until_round"]) < state.round_number:
			continue
		var e: EffectData = f["effect"]
		if e.kind != DataEnums.EffectKind.DAMAGE:
			continue
		if int(f["ctx"]["side"]) == p_side:
			v.my_firefight_damage += e.amount
		else:
			v.foe_firefight_damage += e.amount
	var setup = me.setup
	for ks: LoadoutItem in setup.killstreaks:
		if ks != null and ks.id in me.streak_tray:
			v.items.append({"item": ks, "ready": LoadoutRules.can_use_item(state, p_side, ks) == ""})
	for id: StringName in me.streak_tray:
		v.tray.append(id)
	for z: int in ZONES:
		for entry: Dictionary in me.equipment[z]:
			v.my_equipment[z].append(entry["card"].card.id)
			v.my_fields[z].append(entry["card"].card)
			if entry["card"].card.is_visible_field() and entry["card"].card_trait() != &"":
				v.my_field_traits[z].append(entry["card"].card_trait())
		for entry: Dictionary in foe.equipment[z]:
			if not entry["card"].card.hidden:
				v.foe_equipment[z].append(entry["card"].card.id)
				v.foe_fields[z].append(entry["card"].card)

	# Board: units on it are public (both sides see each other's lines and stats).
	for si: int in 2:
		var s = me if si == ME else foe
		for z: int in ZONES:
			for u in s.line(z):
				v.lines[si][z].append(_unit_record(state, u))

	var op = me.operator_unit
	v.op_exists = op != null
	if op != null:
		v.op_uid = int(op.uid)
		v.op_zone = int(op.zone)
		v.op_can_deploy = bool(me.operator_can_deploy)
		var allowed: int = setup.primary.rotations_per_round if setup.primary != null else 1
		v.op_rotations_left = maxi(0, allowed - int(me.rotations_used))
		for z: int in ZONES:
			v.op_by_zone.append(_operator_in_zone(state, op, z, v))

	v.foe_score = int(foe.score)
	v.foe_streak = int(foe.streak)
	v.foe_hand_count = foe.hand.size()
	v.foe_deck_count = foe.deck.size()
	v.foe_tray_count = foe.streak_tray.size()
	v.foe_op_on_board = foe.operator_unit != null and foe.operator_unit.is_on_board()
	# Intel: exactly what the side's own minimap shows (MatchState's red-dot rules).
	v.red_dots = state.red_dots(p_side)
	for z: int in ZONES:
		for id: StringName in state.revealed_red_dots(p_side, z):
			v.revealed[z].append(id)
	return v


## Public record of a unit on the board, with board-dependent stats already applied.
static func _unit_record(state, u) -> Dictionary:
	var r: Dictionary = new_record()
	r["uid"] = int(u.uid)
	r["id"] = u.source_id
	r["is_op"] = bool(u.is_operator)
	r["class"] = int(u.weapon_class)
	# Field auras are left out here (see the header); the planner applies them per position.
	r["fp"] = maxi(0, int(state.firepower_of(u)) - int(state.field_passive_total(u, DataEnums.EffectKind.MODIFY_FIREPOWER)))
	r["armor"] = int(u.armor)
	r["armor0"] = int(u.armor)
	r["max_armor"] = int(u.max_armor(state.round_number))
	r["cover"] = maxi(0, int(state.cover_of(u)) - int(state.field_passive_total(u, DataEnums.EffectKind.GRANT_COVER)))
	r["first_shot"] = bool(state.has_first_shot(u))
	r["pick"] = bool(u.pick)
	r["flank"] = bool(u.flank)
	r["suppress"] = bool(u.suppress)
	r["pierce"] = bool(u.pierce)
	r["patch"] = int(u.patch)
	r["holder"] = bool(u.holder)
	r["control"] = bool(u.counts_for_control)
	r["credit"] = bool(u.grants_elimination_credit)
	r["untargetable"] = bool(state.is_untargetable_by_pick_flank(u))
	r["survive"] = int(u.survive_lethal)
	# kc-syn: what the unit carries, and the synergy part of fp / cover / first_shot (the
	# synergy-aware planner swaps it for the bonus at the unit's projected position).
	r["kw"] = u.neighbor_keyword
	r["trait"] = u.synergy_trait
	r["level"] = int(u.level)
	var syn: Dictionary = state.synergy_of(u)
	r["syn_fp"] = mini(int(syn.get("fp", 0)), int(r["fp"]))
	var cover_removed: bool = int(state.cover_of(u)) == 0
	r["syn_cover"] = 0 if cover_removed else mini(int(syn.get("cover", 0)), int(r["cover"]))
	r["syn_fs"] = bool(syn.get("fs", false))
	r["fs_native"] = bool(state.has_first_shot(u, false))
	_read_effects(r, u.effects)
	return r


## The Operator as it would stand in zone z (range bonus / zone-conditional passives).
static func _operator_in_zone(state, op, z: int, v: AiView) -> Dictionary:
	var r: Dictionary = _unit_record(state, op)
	var fp: int = int(op.base_firepower) + int(op.mod_total(DataEnums.EffectKind.MODIFY_FIREPOWER, state.round_number))
	fp += int(v.range_bonus[int(op.weapon_class)][z])
	var first_shot: bool = bool(op.first_shot)
	for e: EffectData in op.effects:
		if e == null or e.trigger != DataEnums.Trigger.PASSIVE:
			continue
		if e.condition != DataEnums.Condition.ALWAYS and not EffectResolver.condition_holds(state, e.condition, op.side, z):
			continue
		if e.kind == DataEnums.EffectKind.GRANT_FIRST_SHOT:
			first_shot = true
		elif e.kind == DataEnums.EffectKind.MODIFY_FIREPOWER and e.target in [DataEnums.Target.OPERATOR, DataEnums.Target.SELF]:
			fp += e.amount
	r["fp"] = maxi(0, fp)
	r["first_shot"] = first_shot
	# Synergy at the current spot doesn't travel with it (the planner adds it per position).
	r["cover"] = maxi(0, int(r["cover"]) - int(r["syn_cover"]))
	r["syn_fp"] = 0
	r["syn_cover"] = 0
	r["syn_fs"] = false
	r["fs_native"] = first_shot
	if not op.is_on_board():
		r["armor"] = int(op.max_armor(state.round_number))
		r["armor0"] = r["armor"]
		r["new"] = true
	return r


## Blank unit record (also used by the planner for units it plans to deploy).
static func new_record() -> Dictionary:
	return {
		"uid": -1, "id": &"", "class": 0, "is_op": false, "new": false, "card_unit": false,
		"fp": 0, "armor": 1, "armor0": 1, "max_armor": 1, "cover": 0,
		"first_shot": false, "pick": false, "flank": false, "suppress": false, "pierce": false, "patch": 0,
		"holder": false, "control": true, "credit": true, "untargetable": false, "survive": 0,
		"aura": 0, "on_down_damage": 0, "arrives_front": false,
		"kw": &"", "trait": &"", "level": 1, "syn_fp": 0, "syn_cover": 0, "syn_fs": false, "fs_native": false,
	}


## Copies the effect-driven traits the estimator models: Anvil-style auras and On Down damage.
static func _read_effects(r: Dictionary, effects: Array) -> void:
	for e: EffectData in effects:
		if e == null:
			continue
		if e.trigger == DataEnums.Trigger.PASSIVE and e.kind == DataEnums.EffectKind.MODIFY_FIREPOWER \
				and e.target == DataEnums.Target.OTHER_FRIENDLIES and e.zone_scope == DataEnums.ZoneScope.THIS_ZONE:
			r["aura"] = int(r["aura"]) + e.amount
		elif e.trigger == DataEnums.Trigger.ON_DOWN and e.kind == DataEnums.EffectKind.DAMAGE \
				and e.target == DataEnums.Target.ENEMY_POINT_MAN:
			r["on_down_damage"] = int(r["on_down_damage"]) + e.amount


## Record for a unit card I would deploy into zone z (stats as the engine would build it,
## including the copy's level: kc-onboard Recruits carry their trait but no keyword).
func record_for_card(card: CardData, uid: int, z: int, level: int = SynergyRules.LEVEL_TRAINED,
		chosen_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> Dictionary:
	var r: Dictionary = new_record()
	var lv: Dictionary = SynergyRules.level_stats(level)
	r["uid"] = uid
	r["id"] = card.id
	r["new"] = true
	r["card_unit"] = true
	r["class"] = int(card.weapon_class)
	r["kw"] = SynergyRules.keyword_at(card, level)
	r["trait"] = SynergyRules.trait_at(card, level, chosen_trait)
	r["level"] = level
	# kc-onboard §3: a Recruit's rules text is locked (SynergyRules.keywords_on), as in create_unit.
	var kw_on: bool = SynergyRules.keywords_on(card, level)
	r["fs_native"] = card.first_shot and kw_on
	r["fp"] = maxi(0, card.firepower + my_firepower_bonus + int(lv["fp"]) + int(range_bonus[int(card.weapon_class)][z]))
	var armor: int = maxi(1, card.armor + my_armor_bonus + int(lv["armor"]))
	r["armor"] = armor
	r["armor0"] = armor
	r["max_armor"] = armor
	r["cover"] = 0 if my_cover_removed or not kw_on else card.cover
	r["first_shot"] = card.first_shot and kw_on
	r["pick"] = card.pick and kw_on
	r["flank"] = card.flank and kw_on
	r["suppress"] = card.suppress and kw_on
	r["pierce"] = (card.pierce or card.weapon_class == DataEnums.WeaponClass.LMG) and kw_on
	r["patch"] = card.patch if kw_on else 0
	r["holder"] = card.holder and kw_on
	r["control"] = card.counts_for_control
	r["credit"] = card.grants_elimination_credit
	r["arrives_front"] = card.arrives_front and kw_on
	_read_effects(r, SynergyRules.effects_at(card, level))
	return r


## My visible (non-hidden) Field standing in zone z, or null (one per column).
func my_visible_field(z: int) -> CardData:
	for c: CardData in my_fields[z]:
		if c.is_visible_field():
			return c
	return null


## Level of the hand card with this uid (Trained if unknown).
func hand_level(uid: int) -> int:
	for h: Dictionary in hand:
		if int(h["uid"]) == uid:
			return int(h.get("level", SynergyRules.LEVEL_TRAINED))
	return SynergyRules.LEVEL_TRAINED


## Units of `who` (ME / FOE) in zone z right now.
func count_in(who: int, z: int) -> int:
	return (lines[who][z] as Array).size()


## The LoadoutItem with this id among my usable items, or null.
func find_item(id: StringName) -> LoadoutItem:
	for entry: Dictionary in items:
		if (entry["item"] as LoadoutItem).id == id:
			return entry["item"]
	return null
