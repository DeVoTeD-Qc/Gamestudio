# rules_fixtures.gd
# Purpose: Test fixtures for the rules engine, built in code (no res://data content),
#   mirroring core-rules §5 cards. Not a test file itself (no test_ prefix).
#   Use: const F = preload("res://tests/rules_fixtures.gd")
# Author: Mechanics Developer Agent
extends RefCounted

const PLAYER: int = 0
const ENEMY: int = 1
const LEFT: int = 0
const MID: int = 1
const RIGHT: int = 2

const K := DataEnums.EffectKind
const T := DataEnums.Target
const Z := DataEnums.ZoneScope
const TR := DataEnums.Trigger
const W := DataEnums.WeaponClass
const R := DataEnums.RangeTag


# --- Builders -------------------------------------------------------------------------

static func eff(trigger: int, kind: int, target: int, scope: int, amount: int = 0, extra: Dictionary = {}) -> EffectData:
	var e: EffectData = EffectData.new()
	e.trigger = trigger
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	for key: String in extra:
		e.set(key, extra[key])
	return e


## Unit card. kw sets any CardData field (first_shot, pick, cover, cost, effects...).
static func unit(id: String, fp: int, ar: int, cls: int = W.NONE, kw: Dictionary = {}) -> CardData:
	var c: CardData = CardData.new()
	c.id = StringName(id)
	c.display_name = id.capitalize()
	c.card_type = DataEnums.CardType.UNIT
	c.cost = 1
	c.weapon_class = cls
	c.firepower = fp
	c.armor = ar
	for key: String in kw:
		if key == "effects":
			c.effects.assign(kw[key])
		else:
			c.set(key, kw[key])
	return c


static func tactic(id: String, cost: int, effects: Array) -> CardData:
	var c: CardData = CardData.new()
	c.id = StringName(id)
	c.display_name = id.capitalize()
	c.card_type = DataEnums.CardType.TACTIC
	c.cost = cost
	c.effects.assign(effects)
	return c


static func equipment(id: String, cost: int, effects: Array, hidden: bool = false, consumed: bool = false) -> CardData:
	var c: CardData = tactic(id, cost, effects)
	c.card_type = DataEnums.CardType.EQUIPMENT
	c.hidden = hidden
	c.consumed_on_trigger = consumed
	return c


static func primary(id: String, fp: int, ar: int, cls: int = W.NONE, kw: Dictionary = {}) -> LoadoutItem:
	var p: LoadoutItem = LoadoutItem.new()
	p.id = StringName(id)
	p.display_name = id.capitalize()
	p.slot = DataEnums.LoadoutSlot.PRIMARY
	p.weapon_class = cls
	p.operator_firepower = fp
	p.operator_armor = ar
	for key: String in kw:
		p.set(key, kw[key])
	return p


static func item(id: String, slot: int, effects: Array, cost: int = 0) -> LoadoutItem:
	var it: LoadoutItem = LoadoutItem.new()
	it.id = StringName(id)
	it.display_name = id.capitalize()
	it.slot = slot
	it.supply_cost = cost
	it.effects.assign(effects)
	return it


static func map(ranges: Array = [R.CLOSE, R.LONG, R.MID]) -> MapData:
	var m: MapData = MapData.new()
	m.id = &"test_map"
	m.zone_ranges.assign(ranges)
	return m


## All-Mid map: classes NONE/LMG get no range bonus anywhere.
static func flat_map() -> MapData:
	return map([R.MID, R.MID, R.MID])


static func setup(deck: Array = [], prim: LoadoutItem = null) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.deck.assign(deck)
	s.primary = prim
	s.keep_deck_order = true
	return s


## Started match (Round 1 Deploy). Defaults: no decks, no Operators, flat map.
static func new_match(player: SideSetup = null, enemy: SideSetup = null, map_data: MapData = null,
		seed_value: int = 1, hooks: MatchHooks = null, config: RunConfig = null) -> MatchState:
	var m: MatchState = MatchState.new(config, map_data if map_data != null else flat_map(),
			player if player != null else setup(), enemy if enemy != null else setup(), seed_value, hooks)
	m.start_match()
	return m


## Puts a unit straight onto the board (back of the line, or front for arrives_front).
static func place(m: MatchState, side: int, card: CardData, zone: int) -> RulesUnit:
	var u: RulesUnit = m.create_unit(side, card)
	m.put_in_line(u, zone)
	return u


static func place_operator(m: MatchState, side: int, zone: int) -> RulesUnit:
	var op: RulesUnit = m.sides[side].operator_unit
	m.put_in_line(op, zone, false)
	m.sides[side].operator_can_deploy = false
	return op


static func hand_uid(m: MatchState, side: int, id: String) -> int:
	for c: RulesCard in m.sides[side].hand:
		if c.card.id == StringName(id):
			return c.uid
	return -1


static func events_of(m: MatchState, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in m.events:
		if e["type"] == type:
			out.append(e)
	return out


static func line_ids(m: MatchState, side: int, zone: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for u: RulesUnit in m.sides[side].line(zone):
		out.append(u.source_id)
	return out


# --- core-rules §5 cards ----------------------------------------------------------------

static func rifleman() -> CardData:
	return unit("rifleman", 2, 2, W.AR)

static func point_man() -> CardData:
	return unit("point_man", 2, 3, W.SMG, {"first_shot": true, "cost": 2})

static func combat_medic() -> CardData:
	return unit("combat_medic", 1, 3, W.AR, {"patch": 2, "cost": 2})

static func breacher() -> CardData:
	return unit("breacher", 3, 4, W.SHOTGUN, {"first_shot": true, "cost": 3})

static func marksman() -> CardData:
	return unit("marksman", 2, 2, W.SNIPER, {"pick": true, "cost": 3})

static func flanker() -> CardData:
	return unit("flanker", 2, 3, W.SMG, {"flank": true, "cost": 3})

static func shieldman() -> CardData:
	return unit("shieldman", 1, 5, W.NONE, {"cover": 1, "arrives_front": true, "cost": 3})

static func gunner() -> CardData:
	return unit("gunner", 2, 6, W.LMG, {"suppress": true, "cost": 4})

static func demolitions() -> CardData:
	return unit("demolitions_expert", 2, 4, W.LMG, {"cost": 4, "effects": [
		eff(TR.ON_DOWN, K.DAMAGE, T.ENEMY_POINT_MAN, Z.THIS_ZONE, 3)]})

static func anvil() -> CardData:
	return unit("anvil", 3, 6, W.AR, {"holder": true, "is_elite": true, "cost": 5, "effects": [
		eff(TR.PASSIVE, K.MODIFY_FIREPOWER, T.OTHER_FRIENDLIES, Z.THIS_ZONE, 1)]})

static func wren() -> CardData:
	return unit("wren", 4, 3, W.SNIPER, {"pick": true, "is_elite": true, "cost": 5, "effects": [
		eff(TR.ON_ELIMINATE, K.STREAK_BONUS, T.OWNER, Z.ANY, 1)]})

static func recon_specialist() -> CardData:
	return unit("recon_specialist", 1, 2, W.AR, {"cost": 2, "effects": [
		eff(TR.ON_DEPLOY, K.REVEAL_RED_DOTS, T.OWNER, Z.THIS_ZONE, 0, {"delay_rounds": 1})]})

static func callout() -> CardData:
	return tactic("callout", 0, [
		eff(TR.IMMEDIATE, K.REVEAL_RED_DOTS, T.OWNER, Z.CHOSEN_ZONE),
		eff(TR.IMMEDIATE, K.MODIFY_FIREPOWER, T.NEXT_FRIENDLY_ARRIVING, Z.CHOSEN_ZONE, 1, {"duration_rounds": 1})])

static func ammo_resupply() -> CardData:
	return tactic("ammo_resupply", 1, [eff(TR.IMMEDIATE, K.DRAW, T.OWNER, Z.ANY, 2)])

static func flank_route() -> CardData:
	return tactic("flank_route", 1, [
		eff(TR.ON_PLAY, K.MOVE_UNIT, T.CHOSEN_FRIENDLY, Z.ADJACENT_ZONE),
		eff(TR.ON_PLAY, K.GRANT_FIRST_SHOT, T.CHOSEN_FRIENDLY, Z.ANY, 0, {"duration_rounds": 1})])

static func suppressing_fire() -> CardData:
	return tactic("suppressing_fire", 2, [
		eff(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.ALL_ENEMIES, Z.CHOSEN_ZONE, -1, {"duration_rounds": 1})])

static func hold_the_line() -> CardData:
	return tactic("hold_the_line", 2, [
		eff(TR.ON_PLAY, K.GRANT_COVER, T.ALL_FRIENDLIES, Z.CHOSEN_ZONE, 1, {"duration_rounds": 1})])

static func breach_and_clear() -> CardData:
	return tactic("breach_and_clear", 3, [
		eff(TR.ON_PLAY, K.DAMAGE, T.ALL_ENEMIES, Z.CHOSEN_ZONE, 2,
			{"bonus_amount": 1, "bonus_condition": DataEnums.Condition.ZONE_IS_CLOSE})])

static func tripwire() -> CardData:
	return equipment("tripwire_charge", 2, [
		eff(TR.ON_ENEMY_ARRIVE, K.DAMAGE, T.ARRIVING_ENEMY, Z.THIS_ZONE, 3)], true, true)

static func comms_relay() -> CardData:
	return equipment("comms_relay", 2, [
		eff(TR.END_OF_ROUND, K.STREAK_BONUS, T.OWNER, Z.THIS_ZONE, 1,
			{"condition": DataEnums.Condition.YOU_CONTROL_ZONE})])

# --- Fields (KillingCard field-cards.md §4; CardType.EQUIPMENT) ----------------------------

static func listening_post() -> CardData:
	return equipment("listening_post", 1, [
		eff(TR.END_OF_ROUND, K.REVEAL_RED_DOTS, T.OWNER, Z.THIS_ZONE, 0, {"delay_rounds": 1, "duration_rounds": 1})])

static func mortar_pit() -> CardData:
	return equipment("mortar_pit", 3, [eff(TR.END_OF_ROUND, K.DAMAGE, T.ENEMY_POINT_MAN, Z.THIS_ZONE, 1)])

static func bulwark() -> CardData:
	return equipment("bulwark", 3, [eff(TR.PASSIVE, K.GRANT_COVER, T.FRIENDLY_POINT_MAN, Z.THIS_ZONE, 1)])

static func war_standard() -> CardData:
	return equipment("war_standard", 3, [eff(TR.PASSIVE, K.MODIFY_FIREPOWER, T.FRIENDLY_POINT_MAN, Z.THIS_ZONE, 1)])

static func sniper_perch() -> CardData:
	return equipment("sniper_perch", 2, [
		eff(TR.PASSIVE, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.THIS_ZONE, 1, {"target_class": W.SNIPER})])

static func aid_station() -> CardData:
	return equipment("aid_station", 2, [eff(TR.END_OF_ROUND, K.HEAL, T.MOST_DAMAGED_FRIENDLY, Z.THIS_ZONE, 1)])

static func sabotage() -> CardData:
	return tactic("sabotage", 2, [eff(TR.ON_PLAY, K.DESTROY_EQUIPMENT, T.ENEMY_EQUIPMENT, Z.CHOSEN_ZONE, 1)])

## Puts a Field straight onto the board (as if revealed in an earlier round).
static func place_field(m: MatchState, side: int, card: CardData, zone: int, placed_round: int = 0) -> RulesCard:
	var rc: RulesCard = RulesCard.new(m.new_uid(), card)
	m.sides[side].equipment[zone].append({"card": rc, "round": placed_round})
	return rc

static func sentry() -> CardData:
	return unit("sentry", 2, 4, W.NONE, {"cover": 1, "collectible": false,
		"counts_for_control": false, "grants_elimination_credit": false})

static func kestrel() -> LoadoutItem:
	return primary("kestrel_ar7", 3, 7, W.AR)

static func frag() -> LoadoutItem:
	return item("frag_grenade", DataEnums.LoadoutSlot.LETHAL, [
		eff(TR.ON_PLAY, K.DAMAGE, T.ENEMY_POINT_MAN, Z.OPERATOR_OR_ADJACENT, 2),
		eff(TR.ON_PLAY, K.DAMAGE, T.ENEMY_SECOND_IN_LINE, Z.OPERATOR_OR_ADJACENT, 1)])

static func flashbang() -> LoadoutItem:
	return item("flashbang", DataEnums.LoadoutSlot.TACTICAL, [
		eff(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.ALL_ENEMIES, Z.OPERATOR_OR_ADJACENT, -2, {"duration_rounds": 1}),
		eff(TR.ON_PLAY, K.REMOVE_FIRST_SHOT, T.ALL_ENEMIES, Z.OPERATOR_OR_ADJACENT, 0, {"duration_rounds": 1})])

static func mortar() -> LoadoutItem:
	return item("mortar_barrage", DataEnums.LoadoutSlot.KILLSTREAK, [
		eff(TR.ON_PLAY, K.DAMAGE, T.ALL_ENEMIES, Z.CHOSEN_ZONE, 2)])

static func attack_helo() -> LoadoutItem:
	return item("attack_helo", DataEnums.LoadoutSlot.KILLSTREAK, [
		eff(TR.START_OF_FIREFIGHT, K.DAMAGE, T.ENEMY_POINT_MAN, Z.ALL_ZONES, 2, {"duration_rounds": 2})])

static func sentry_turret() -> LoadoutItem:
	return item("sentry_turret", DataEnums.LoadoutSlot.KILLSTREAK, [
		eff(TR.ON_PLAY, K.SUMMON_UNIT, T.OWNER, Z.CHOSEN_ZONE, 0, {"summon_card": sentry()})])
