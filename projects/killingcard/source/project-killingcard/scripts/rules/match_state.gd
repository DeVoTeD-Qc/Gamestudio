# match_state.gd
# Purpose: The rules engine's match: full state plus the round loop
#   Briefing -> Deploy -> Reveal -> Firefight -> Score (core-rules §2 + Rulings).
#   Node-free and deterministic: all randomness comes from one seeded
#   RandomNumberGenerator, so the same seed + intents replay exactly. Player / AI
#   intents go in (submit), state changes come out as RulesEvent dictionaries in
#   `events` (scenes translate them to EventBus later; nothing here touches nodes).
#   Shared by the match scene, the AI look-ahead and the outcome preview (duplicate
#   the inputs, not the scene).
#
#   Usage:
#     var m := MatchState.new(run_config, map, player_setup, enemy_setup, seed)
#     m.start_match()                 # shuffles, Round 1 Briefing, phase = DEPLOY
#     m.submit(MatchState.ENEMY, RulesIntent.play_card(uid, 0))   # AI commits first
#     m.red_dots(MatchState.PLAYER)   # [n_left, n_mid, n_right]
#     m.submit(MatchState.PLAYER, ...); m.set_ready(...)
#     m.resolve_round()               # Reveal + Firefight + Score
#     m.begin_round()                 # next Briefing
#
# Dependencies: DataEnums, CardData, EffectData, LoadoutItem, MapData, RunConfig,
#   RulesCard, RulesUnit, RulesSide, SideSetup, RulesEvent, RulesIntent, MatchHooks,
#   EffectResolver, FirefightResolver.
# Author: Mechanics Developer Agent
class_name MatchState
extends RefCounted

const PLAYER: int = 0
const ENEMY: int = 1
const SIDE_NAMES: Array[StringName] = [&"player", &"enemy"]
const ZONE_COUNT: int = 3
const NO_ZONE: int = -1
## control_of() results besides PLAYER / ENEMY.
const CONTROL_EMPTY: int = -1
const CONTROL_CONTESTED: int = -2

enum Phase { SETUP, BRIEFING, DEPLOY, REVEAL, FIREFIGHT, SCORE, ENDED }
const PHASE_NAMES: Array[StringName] = [&"setup", &"briefing", &"deploy", &"reveal", &"firefight", &"score", &"ended"]

## Source kinds recorded on damage / eliminations (streak rules key off these).
const SRC_UNIT: StringName = &"unit"
const SRC_OPERATOR: StringName = &"operator"
const SRC_TACTIC: StringName = &"tactic"
const SRC_EQUIPMENT: StringName = &"equipment"
const SRC_KILLSTREAK: StringName = &"killstreak"
const SRC_PERK: StringName = &"perk"
## On Down triggers (Demolitions Expert); counts for the streak (StreakTracker rule).
const SRC_ON_DOWN: StringName = &"on_down"

var config: RunConfig = null
var zone_ranges: Array[int] = [DataEnums.RangeTag.CLOSE, DataEnums.RangeTag.MID, DataEnums.RangeTag.LONG]
var map_id: StringName = &""
var hooks: MatchHooks = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0
var sides: Array[RulesSide] = []

var round_number: int = 0
var phase: Phase = Phase.SETUP
## Side that resolves first at this round's Reveal.
var initiative: int = PLAYER
## False in modes without respawn (Detonator). Read by MatchHooks.operator_can_deploy.
var respawn_enabled: bool = true
## &"" while running; &"player" / &"enemy" / &"draw" once ended.
var result: StringName = &""

## Every event so far, in order.
var events: Array[Dictionary] = []
## UNIT_ELIMINATED records of the current round (the Score step counts these).
var round_eliminations: Array[Dictionary] = []
## Registered START_OF_FIREFIGHT effects: {side, effect, ctx, until_round}.
var firefight_effects: Array[Dictionary] = []
## Effects waiting for a later round (delay_rounds): {due_round, effect, ctx}.
var delayed_effects: Array[Dictionary] = []

## Display only (card-system §4.6, kc-cod2): card uid -> banner art id of that copy, filled from
## SideSetup.deck_arts. A unit keeps its card's uid, so board, killfeed and discard show the copy's
## art. The rules never read it (MatchClone copies it like every other variable).
var art_by_uid: Dictionary = {}

## kc-syn: synergy cache (SynergyRules.compute per side), rebuilt when the board signature changes
## (lines, unit order, visible Fields). Keyed by unit uid: {fp, cover, fs, heal, links, sets}.
var _syn_sig: PackedInt32Array = PackedInt32Array()
var _syn_units: Dictionary = {}
var _syn_sides: Array = [{}, {}]
## Last announced synergy summary per side (SYNERGY_CHANGED fires only when a link or tier flips).
var _syn_announced: Array = [SYN_EMPTY_KEY, SYN_EMPTY_KEY]
const SYN_EMPTY_KEY: String = "|vanguard0,specops0,heavy0,undead0"

var _next_uid: int = 1
var _play_counter: int = 0


func _init(p_config: RunConfig = null, p_map: MapData = null, player: SideSetup = null,
		enemy: SideSetup = null, p_seed: int = 0, p_hooks: MatchHooks = null) -> void:
	config = p_config if p_config != null else RunConfig.new()
	if p_map != null:
		map_id = p_map.id
		zone_ranges.clear()
		for r: int in p_map.zone_ranges:
			zone_ranges.append(r)
	hooks = p_hooks if p_hooks != null else MatchHooks.new()
	seed_value = p_seed
	rng.seed = p_seed
	for i: int in 2:
		var s: RulesSide = RulesSide.new()
		s.index = i
		s.setup = [player, enemy][i] if [player, enemy][i] != null else SideSetup.new()
		sides.append(s)


# =============================================================================
# Match flow
# =============================================================================

## Builds decks and Operators, shuffles (seeded) and runs Round 1 Briefing.
func start_match() -> void:
	for s: RulesSide in sides:
		for i: int in s.setup.deck.size():
			var rc: RulesCard = RulesCard.new(new_uid(), s.setup.deck[i], s.setup.trait_of(i))
			if i < s.setup.deck_arts.size() and s.setup.deck_arts[i] != &"":
				art_by_uid[rc.uid] = s.setup.deck_arts[i]
			s.deck.append(rc)
		if not s.setup.keep_deck_order:
			shuffle(s.deck)
		s.operator_unit = _build_operator(s.index, s.setup)
	emit_event(RulesEvent.MATCH_STARTED, {"seed": seed_value, "map": map_id})
	begin_round()


## Briefing of the next round: Supply, draws (Round 1: opening hand + 1, then a free
## mulligan), hooks (per-round uses, Grit), delayed effects. Ends in the Deploy phase.
func begin_round() -> void:
	if phase == Phase.ENDED:
		return
	round_number += 1
	round_eliminations.clear()
	emit_event(RulesEvent.ROUND_STARTED, {})
	_set_phase(Phase.BRIEFING)
	for s: RulesSide in sides:
		s.supply = config.supply_for_round(round_number)
		emit_event(RulesEvent.SUPPLY_GAINED, {"side": side_name(s.index), "supply": s.supply})
		var draws: int = config.draws_per_round
		if round_number == 1:
			draws = config.opening_hand + config.round1_extra_draw
		draw_cards(s.index, draws)
		s.plays.clear()
		s.ready = false
		s.rotations_used = 0
		s.arrival_buffs.clear()
		s.operator_down_this_round = false
		s.streak_bonus_this_round = 0
		s.mulligans_left = config.free_mulligans if round_number == 1 else 0
		s.operator_can_deploy = s.operator_unit != null and not s.operator_unit.is_on_board() \
				and hooks.operator_can_deploy(self, s.index)
		hooks.on_briefing(self, s.index)
	# Delayed effects that come due now (generic; REVEAL_RED_DOTS is stored as intel instead).
	var still_waiting: Array[Dictionary] = []
	for d: Dictionary in delayed_effects:
		if int(d["due_round"]) <= round_number:
			EffectResolver.resolve_effect(self, d["effect"], d["ctx"])
		else:
			still_waiting.append(d)
	delayed_effects = still_waiting
	process_eliminations()
	_set_phase(Phase.DEPLOY)


## Reveal + Firefight + Score. Returns the events of those steps.
func resolve_round() -> Array[Dictionary]:
	var start: int = events.size()
	if phase != Phase.DEPLOY:
		return []
	reveal()
	firefight()
	score()
	return events_since(start)


func set_ready(side: int, value: bool = true) -> void:
	sides[side].ready = value


func both_ready() -> bool:
	return sides[0].ready and sides[1].ready


# =============================================================================
# Deploy: intents
# =============================================================================

## Round 1 only, before any play: put back `card_uids`, shuffle them in, redraw that many.
## Returns {ok, code, reason, data} like submit() (codes: see can_mulligan()).
func mulligan(side: int, card_uids: Array) -> Dictionary:
	var check: Dictionary = can_mulligan(side, card_uids)
	if not check["ok"]:
		return check
	var s: RulesSide = sides[side]
	var back: Array[RulesCard] = []
	for uid: Variant in card_uids:
		var c: RulesCard = s.find_in_hand(int(uid))
		if c not in back:
			back.append(c)
	for c: RulesCard in back:
		s.hand.erase(c)
		s.deck.append(c)
	shuffle(s.deck)
	s.mulligans_left -= 1
	emit_event(RulesEvent.MULLIGAN, {"side": side_name(side), "count": back.size(), "private_to": side_name(side)})
	draw_cards(side, back.size())
	return _ok()


## Could `side` mulligan these cards now? Never changes the state.
## Codes: bad_side, wrong_phase, no_mulligan, already_played, not_in_hand.
func can_mulligan(side: int, card_uids: Array = []) -> Dictionary:
	if side != PLAYER and side != ENEMY:
		return _fail("no such side", &"bad_side")
	var s: RulesSide = sides[side]
	if phase != Phase.DEPLOY:
		return _fail("no mulligan available", &"wrong_phase")
	if s.mulligans_left <= 0:
		return _fail("no mulligan available", &"no_mulligan")
	if not s.plays.is_empty():
		return _fail("mulligan only before playing cards", &"already_played")
	for uid: Variant in card_uids:
		if s.find_in_hand(int(uid)) == null:
			return _fail("card %d is not in hand" % int(uid), &"not_in_hand", {"card_uid": int(uid)})
	return _ok()


## Validates an intent (RulesIntent) and queues it face-down. "Resolves immediately"
## effects resolve now. Runs exactly the checks of can_submit() first and returns the same
## {ok, code, reason, data} when it refuses; {ok: true, code: &"ok", ...} when accepted.
func submit(side: int, intent: Dictionary) -> Dictionary:
	var check: Dictionary = _check_intent(side, intent)
	if not check["ok"]:
		return _public(check)
	var play: Dictionary = check["play"]
	_play_counter += 1
	play["order"] = _play_counter
	match play["kind"]:
		&"place":
			_commit_place(side, play)
		&"rotate":
			_commit_rotate(side, play)
		&"item":
			_commit_item(side, play)
		_:
			_commit_card(side, play)
	return _ok()


## Would submit(side, intent) accept this intent right now? Runs the same checks and never
## changes the state. Returns {ok: bool, code: StringName, reason: String, data: Dictionary}.
## `code` is stable (UI text, AI, logs key off it; `reason` is a short English fallback):
##   ok
##   bad_side, wrong_phase, already_ready, unknown_intent        (any intent)
##   not_in_hand, not_enough_supply {cost, supply}               (cards / items)
##   no_zone, zone_full {zone, capacity}                         (where it goes)
##   operator_not_placed, out_of_range {operator_zone}           (Operator-zone effects)
##   no_target {want: &"enemy"|&"friendly"}, target_out_of_range {operator_zone}
##   same_zone, not_adjacent {from_zone}                         (moves, Rotations)
##   not_in_loadout, not_in_tray,
##   no_uses_left {per: &"round"|&"match"}                       (loadout items)
##   no_operator, cant_place, already_placed, no_rotations_left {allowed}   (Operator)
##   item_blocked (a MatchHooks subclass refused the item with its own reason)
## An accepted intent may carry data.warnings: [&"dest_full"] = a move into a zone that is
## full right now (it fizzles at Reveal unless a slot frees up).
func can_submit(side: int, intent: Dictionary) -> Dictionary:
	return _public(_check_intent(side, intent))


## Every choice that makes `what` legal right now, as [{zone, target_uid}] (zone -1 = no zone
## needed, target_uid -1 = no unit needed). `what` = a hand card uid (int), a loadout item id
## (StringName / String) or &"operator" (placement or Rotation, whichever applies).
## Built by running can_submit() on every candidate, so it can never disagree with submit().
func legal_targets(side: int, what: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cand: Dictionary in _candidates(side, what):
		if _check_intent(side, cand["intent"])["ok"]:
			out.append({"zone": cand["zone"], "target_uid": cand["target_uid"]})
	return out


## Can `what` (as in legal_targets) be used at all right now? {ok, code, reason, data}: ok when
## some target is legal; otherwise the refusal every candidate shares (e.g. not_in_tray,
## not_enough_supply, operator_not_placed), else &"no_legal_target". For buttons / hand dimming.
func check_use(side: int, what: Variant) -> Dictionary:
	var codes: Dictionary = {}  # code -> first result with it
	for cand: Dictionary in _candidates(side, what):
		var r: Dictionary = _public(_check_intent(side, cand["intent"]))
		if r["ok"]:
			return r
		if not codes.has(r["code"]):
			codes[r["code"]] = r
	if codes.is_empty():
		return _fail("nothing to use", &"unknown_intent")
	# "Choose something" refusals only matter when nothing else went wrong.
	var telling: Array = codes.keys().filter(func(c: StringName) -> bool: return c not in [&"no_zone", &"no_target"])
	if telling.size() == 1:
		return codes[telling[0]]
	if telling.is_empty() and codes.size() == 1:
		return codes.values()[0]
	return _fail("no legal target", &"no_legal_target")


## &"enemy" / &"friendly" when `what` (as in legal_targets) needs a chosen unit, else &"".
func needs_unit_target(side: int, what: Variant) -> StringName:
	for e: EffectData in _effects_of(side, what):
		if e == null:
			continue
		if e.target == DataEnums.Target.CHOSEN_FRIENDLY:
			return &"friendly"
		if e.target == DataEnums.Target.CHOSEN_ENEMY:
			return &"enemy"
	return &""


## Undo the last play of this Deploy (not possible once it resolved something immediately).
func undo_last(side: int) -> Dictionary:
	var s: RulesSide = sides[side]
	if phase != Phase.DEPLOY or s.ready or s.plays.is_empty():
		return _fail("nothing to undo", &"nothing_to_undo")
	var play: Dictionary = s.plays.back()
	if play["immediate_done"]:
		return _fail("it already resolved", &"already_resolved")
	s.plays.pop_back()
	s.supply += int(play["cost"])
	match play["kind"]:
		&"rotate":
			s.rotations_used -= 1
		&"place":
			pass
		&"item":
			hooks.on_item_undone(self, side, play["item"])
		_:
			s.hand.append(play["card"])
	emit_event(RulesEvent.PLAY_UNDONE, {"side": side_name(side), "order": play["order"], "private_to": side_name(side)})
	return _ok()


# --- Checks (no state changes) ------------------------------------------------------------

## The single validator behind submit() / can_submit(). On success "play" holds the draft
## play (no order yet) that submit() commits.
func _check_intent(side: int, intent: Dictionary) -> Dictionary:
	if side != PLAYER and side != ENEMY:
		return _fail("no such side", &"bad_side")
	var s: RulesSide = sides[side]
	if phase != Phase.DEPLOY:
		return _fail("not in Deploy", &"wrong_phase")
	if s.ready:
		return _fail("already READY", &"already_ready")
	match intent.get("type", &""):
		RulesIntent.PLAY_CARD:
			return _check_card(side, intent)
		RulesIntent.PLACE_OPERATOR:
			return _check_place(side, int(intent.get("zone", NO_ZONE)))
		RulesIntent.ROTATE:
			return _check_rotate(side, int(intent.get("zone", NO_ZONE)))
		RulesIntent.USE_ITEM:
			return _check_item(side, intent)
	return _fail("unknown intent", &"unknown_intent")


func _check_card(side: int, intent: Dictionary) -> Dictionary:
	var s: RulesSide = sides[side]
	var rc: RulesCard = s.find_in_hand(int(intent.get("card_uid", -1)))
	if rc == null:
		return _fail("card not in hand", &"not_in_hand")
	var card: CardData = rc.card
	if card.cost > s.supply:
		return _fail("not enough Supply", &"not_enough_supply", {"cost": card.cost, "supply": s.supply})
	var zone: int = int(intent.get("zone", NO_ZONE))
	var kind: StringName = &"unit"
	match card.card_type:
		DataEnums.CardType.UNIT:
			if not is_zone(zone):
				return _fail("pick a zone", &"no_zone")
			if projected_occupancy(side, zone) >= config.zone_capacity:
				return _zone_full(zone)
		DataEnums.CardType.EQUIPMENT:  # a Field
			kind = &"equipment"
			if not is_zone(zone):
				return _fail("pick a zone", &"no_zone")
			# One visible Field per side per column: a new one replaces the standing one at
			# Reveal, but two in the same column in one Deploy would just waste the first.
			if card.is_visible_field() and _field_planned(side, zone):
				return _fail("you already play a Field in this column", &"field_already_planned", {"zone": zone})
		DataEnums.CardType.TACTIC:
			kind = &"tactic"
	var play: Dictionary = _draft_play(kind, zone, intent)
	play["card"] = rc
	play["cost"] = card.cost
	var why: Dictionary = _check_targets(side, card.effects, play, card.card_type == DataEnums.CardType.TACTIC)
	if not why.is_empty():
		return why
	return _ok_play(play)


func _check_item(side: int, intent: Dictionary) -> Dictionary:
	var s: RulesSide = sides[side]
	var item: LoadoutItem = find_item(side, StringName(intent.get("item_id", &"")))
	if item == null:
		return _fail("item not in loadout", &"not_in_loadout")
	if item.supply_cost > s.supply:
		return _fail("not enough Supply", &"not_enough_supply", {"cost": item.supply_cost, "supply": s.supply})
	var blocked: Dictionary = hooks.check_item(self, side, item)
	if not blocked.is_empty():
		return _fail(String(blocked.get("reason", "")), StringName(blocked.get("code", &"item_blocked")), blocked.get("data", {}))
	var play: Dictionary = _draft_play(&"item", int(intent.get("zone", NO_ZONE)), intent)
	play["item"] = item
	play["cost"] = item.supply_cost
	var why: Dictionary = _check_targets(side, item.effects, play, true)
	if not why.is_empty():
		return why
	return _ok_play(play)


func _check_place(side: int, zone: int) -> Dictionary:
	var s: RulesSide = sides[side]
	if s.operator_unit == null:
		return _fail("Operator can't be placed now", &"no_operator")
	if _has_play(side, &"place"):
		return _fail("Operator can't be placed now", &"already_placed")
	if not s.operator_can_deploy:
		return _fail("Operator can't be placed now", &"cant_place")
	if not is_zone(zone):
		return _fail("pick a zone", &"no_zone")
	if projected_occupancy(side, zone) >= config.zone_capacity:
		return _zone_full(zone)
	# kc-syn §6.3: placing the Operator (round 1 and every respawn) costs Supply.
	var cost: int = operator_cost()
	if cost > s.supply:
		return _fail("not enough Supply", &"not_enough_supply", {"cost": cost, "supply": s.supply})
	var play: Dictionary = _draft_play(&"place", zone, {})
	play["cost"] = cost
	return _ok_play(play)


func _check_rotate(side: int, zone: int) -> Dictionary:
	var s: RulesSide = sides[side]
	if s.operator_unit == null:
		return _fail("no Operator", &"no_operator")
	var from: int = projected_operator_zone(side)
	if from == NO_ZONE:
		return _fail("Operator is not on the board", &"operator_not_placed")
	var allowed: int = s.setup.primary.rotations_per_round if s.setup.primary != null else 1
	if s.rotations_used >= allowed:
		return _fail("no Rotations left this round", &"no_rotations_left", {"allowed": allowed})
	if zone == from:
		return _fail("Rotate only to an adjacent zone", &"same_zone", {"from_zone": from})
	if not is_zone(zone) or not are_adjacent(from, zone):
		return _fail("Rotate only to an adjacent zone", &"not_adjacent", {"from_zone": from})
	if projected_occupancy(side, zone) >= config.zone_capacity:
		return _zone_full(zone)
	var play: Dictionary = _draft_play(&"rotate", zone, {})
	play["from_zone"] = from
	return _ok_play(play)


## Checks zone / target choices the effects need. Returns {} when fine, else a refusal.
## May fill play["dest_zone"] (MOVE_UNIT without an explicit destination: the chosen zone).
## Non-blocking findings go to play["warnings"] (dest_full: a move into a full zone fizzles).
func _check_targets(side: int, effects: Array[EffectData], play: Dictionary, zone_from_effects: bool) -> Dictionary:
	var zone: int = play["zone"]
	var warnings: Array[StringName] = []
	play["warnings"] = warnings
	for e: EffectData in effects:
		if e == null:
			continue
		if zone_from_effects:
			match e.zone_scope:
				DataEnums.ZoneScope.CHOSEN_ZONE:
					if not is_zone(zone):
						return _fail("pick a zone", &"no_zone")
				DataEnums.ZoneScope.OPERATOR_OR_ADJACENT:
					var op_zone: int = projected_operator_zone(side)
					if op_zone == NO_ZONE:
						return _fail("Operator is not on the board", &"operator_not_placed")
					if not is_zone(zone):
						return _fail("pick a zone", &"no_zone")
					if absi(zone - op_zone) > 1:
						return _fail("pick your Operator's zone or an adjacent one", &"out_of_range", {"operator_zone": op_zone})
				DataEnums.ZoneScope.OPERATOR_ZONE:
					if projected_operator_zone(side) == NO_ZONE:
						return _fail("Operator is not on the board", &"operator_not_placed")
		var target_uid: int = play["target_uid"]
		match e.target:
			DataEnums.Target.CHOSEN_ENEMY:
				var foe_unit: RulesUnit = sides[1 - side].find_unit(target_uid)
				if foe_unit == null:
					return _fail("pick an enemy unit", &"no_target", {"want": &"enemy"})
				# An OPERATOR_ZONE shot only lands on an enemy in the Operator's zone.
				if zone_from_effects and e.zone_scope == DataEnums.ZoneScope.OPERATOR_ZONE \
						and foe_unit.zone != projected_operator_zone(side):
					return _fail("pick an enemy in your Operator's zone", &"target_out_of_range",
							{"operator_zone": projected_operator_zone(side)})
			DataEnums.Target.CHOSEN_FRIENDLY:
				var friendly_zone: int = _friendly_zone_for_uid(side, target_uid)
				if friendly_zone == NO_ZONE:
					return _fail("pick one of your units", &"no_target", {"want": &"friendly"})
				if e.kind == DataEnums.EffectKind.MOVE_UNIT:
					var dest: int = play["dest_zone"] if is_zone(play["dest_zone"]) else zone
					if dest == friendly_zone:
						return _fail("move only to an adjacent zone", &"same_zone", {"from_zone": friendly_zone})
					if not is_zone(dest) or not are_adjacent(friendly_zone, dest):
						return _fail("move only to an adjacent zone", &"not_adjacent", {"from_zone": friendly_zone})
					play["dest_zone"] = dest
					# Legal, but it fizzles at Reveal if the zone is still full (Rulings): flag it.
					if projected_occupancy(side, dest) >= config.zone_capacity:
						warnings.append(&"dest_full")
	return {}


## Zone of a friendly unit on the board, or of a unit card played earlier this Deploy.
func _friendly_zone_for_uid(side: int, uid: int) -> int:
	var u: RulesUnit = sides[side].find_unit(uid)
	if u != null:
		return u.zone
	for p: Dictionary in sides[side].plays:
		if p["kind"] == &"unit" and (p["card"] as RulesCard).uid == uid:
			return p["zone"]
	return NO_ZONE


## Intents to try for legal_targets() / check_use(): [{intent, zone, target_uid}].
func _candidates(side: int, what: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if side != PLAYER and side != ENEMY:
		return out
	var unit_kind: StringName = needs_unit_target(side, what)
	var uids: Array[int] = [-1]
	if unit_kind == &"enemy":
		uids.assign(sides[1 - side].units_on_board().map(func(u: RulesUnit) -> int: return u.uid))
	elif unit_kind == &"friendly":
		uids.assign(sides[side].units_on_board().map(func(u: RulesUnit) -> int: return u.uid))
		for p: Dictionary in sides[side].plays:
			if p["kind"] == &"unit":
				uids.append((p["card"] as RulesCard).uid)
	if uids.is_empty():
		uids = [-1]  # nothing to pick: the -1 candidate reports no_target
	for zone: int in [NO_ZONE, 0, 1, 2]:
		for uid: int in uids:
			var intent: Dictionary = {}
			if typeof(what) == TYPE_INT:
				intent = RulesIntent.play_card(int(what), zone, uid, zone if unit_kind == &"friendly" else -1)
			elif StringName(what) == &"operator":
				var s: RulesSide = sides[side]
				var placing: bool = s.operator_unit != null and s.operator_can_deploy and not _has_play(side, &"place")
				intent = RulesIntent.place_operator(zone) if placing else RulesIntent.rotate(zone)
			else:
				intent = RulesIntent.use_item(StringName(what), zone, uid)
			out.append({"intent": intent, "zone": zone, "target_uid": uid})
	return out


func _effects_of(side: int, what: Variant) -> Array[EffectData]:
	if side != PLAYER and side != ENEMY:
		return []
	if typeof(what) == TYPE_INT:
		var rc: RulesCard = sides[side].find_in_hand(int(what))
		if rc != null:
			return rc.card.effects
	elif StringName(what) != &"operator":
		var item: LoadoutItem = find_item(side, StringName(what))
		if item != null:
			return item.effects
	var none: Array[EffectData] = []
	return none


func _draft_play(kind: StringName, zone: int, intent: Dictionary) -> Dictionary:
	return {
		"order": 0, "kind": kind, "card": null, "item": null, "zone": zone,
		"from_zone": NO_ZONE, "target_uid": int(intent.get("target_uid", -1)),
		"dest_zone": int(intent.get("dest_zone", -1)), "cost": 0, "immediate_done": false,
	}


func _zone_full(zone: int) -> Dictionary:
	return _fail("zone full", &"zone_full", {"zone": zone, "capacity": config.zone_capacity})


# --- Commits (submit() after a passed check) -------------------------------------------------

func _commit_card(side: int, play: Dictionary) -> void:
	var s: RulesSide = sides[side]
	var rc: RulesCard = play["card"]
	var card: CardData = rc.card
	s.hand.erase(rc)
	s.supply -= card.cost
	s.plays.append(play)
	emit_event(RulesEvent.CARD_PLAYED, {
		"side": side_name(side), "card_uid": rc.uid, "card_id": card.id,
		"zone": zone_name(play["zone"]), "private_to": side_name(side),
	})
	_resolve_immediate(side, card.effects, play, _source_kind_for_card(card), card.id, rc.uid)


func _commit_item(side: int, play: Dictionary) -> void:
	var s: RulesSide = sides[side]
	var item: LoadoutItem = play["item"]
	s.supply -= item.supply_cost
	s.plays.append(play)
	hooks.on_item_used(self, side, item)
	emit_event(RulesEvent.ITEM_USED, {
		"side": side_name(side), "item_id": item.id, "zone": zone_name(play["zone"]),
		"private_to": side_name(side),
	})
	_resolve_immediate(side, item.effects, play, source_kind_for_item(item), item.id, -1)


func _commit_place(side: int, play: Dictionary) -> void:
	var s: RulesSide = sides[side]
	s.supply -= int(play["cost"])
	s.plays.append(play)
	emit_event(RulesEvent.CARD_PLAYED, {"side": side_name(side), "card_uid": s.operator_unit.uid,
			"card_id": s.operator_unit.source_id, "zone": zone_name(play["zone"]), "private_to": side_name(side)})


func _commit_rotate(side: int, play: Dictionary) -> void:
	var s: RulesSide = sides[side]
	s.rotations_used += 1
	s.plays.append(play)

func _resolve_immediate(side: int, effects: Array[EffectData], play: Dictionary,
		source_kind: StringName, source_id: StringName, source_uid: int) -> void:
	var ctx: Dictionary = make_ctx(side, source_kind, source_id, source_uid, play["zone"], play["target_uid"], play["dest_zone"])
	for e: EffectData in effects:
		if e != null and e.trigger == DataEnums.Trigger.IMMEDIATE:
			play["immediate_done"] = true
			EffectResolver.resolve_effect(self, e, ctx)


# =============================================================================
# Reveal
# =============================================================================

func reveal() -> void:
	_set_phase(Phase.REVEAL)
	initiative = hooks.initiative_side(self)
	emit_event(RulesEvent.INITIATIVE, {"side": side_name(initiative)})
	var order: Array[int] = side_order()
	# Callout-style buffs played with ON_PLAY also catch arrivals of this Reveal (Ruling 7).
	for si: int in order:
		for play: Dictionary in sides[si].plays:
			var effects: Array[EffectData] = _play_effects(play)
			for e: EffectData in effects:
				if e != null and e.trigger == DataEnums.Trigger.ON_PLAY and e.target == DataEnums.Target.NEXT_FRIENDLY_ARRIVING:
					var src: Array = _play_source(play)
					EffectResolver.resolve_effect(self, e, make_ctx(si, src[0], src[1], src[2], play["zone"], -1, -1))
	# Rulings part 2 #2: Equipment played this Deploy is placed and armed before step a
	# (initiative side first), so a Tripwire catches units arriving this Reveal.
	for si: int in order:
		for play: Dictionary in sides[si].plays:
			if play["kind"] == &"equipment":
				_reveal_equipment(si, play)
	# a. Units (and Operator placements / Rotations) arrive in play order.
	for si: int in order:
		var waiting: Array[Dictionary] = []
		for play: Dictionary in sides[si].plays:
			if play["kind"] in [&"unit", &"place", &"rotate"]:
				if not _arrive(si, play):
					waiting.append(play)
		for play: Dictionary in waiting:  # a slot freed later in play order
			if not _arrive(si, play):
				_waste_arrival(si, play)
	# b. Tactics and loadout items in play order (Equipment was placed before step a).
	for si: int in order:
		for play: Dictionary in sides[si].plays:
			match play["kind"]:
				&"tactic":
					_reveal_tactic(si, play)
				&"item":
					_reveal_item(si, play)
	for s: RulesSide in sides:
		for buff: Dictionary in s.arrival_buffs:
			emit_event(RulesEvent.EFFECT_WASTED, {"side": side_name(s.index), "source_id": buff["source_id"],
					"kind": DataEnums.key_of(DataEnums.EffectKind, (buff["effect"] as EffectData).kind),
					"reason": "no unit arrived"})
		s.arrival_buffs.clear()
		s.plays.clear()
	announce_synergy()


## Places the unit / Operator of an arrival play. False if its zone is full right now.
func _arrive(si: int, play: Dictionary) -> bool:
	var s: RulesSide = sides[si]
	var zone: int = play["zone"]
	match play["kind"]:
		&"unit":
			if s.line(zone).size() >= config.zone_capacity:
				return false
			var rc: RulesCard = play["card"]
			emit_event(RulesEvent.CARD_REVEALED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id, "zone": zone_name(zone)})
			var u: RulesUnit = create_unit(si, rc.card, rc.uid, rc.chosen_trait)
			put_in_line(u, zone)
			_apply_arrival_buff(si, u)
			var ctx: Dictionary = make_ctx(si, SRC_UNIT, u.source_id, u.uid, zone, play["target_uid"], play["dest_zone"])
			ctx["source_unit"] = u
			for e: EffectData in u.effects:
				if e != null and e.trigger == DataEnums.Trigger.ON_DEPLOY:
					EffectResolver.resolve_effect(self, e, ctx)
			trigger_traps(si, u)
		&"place":
			var op: RulesUnit = s.operator_unit
			if op.is_on_board():
				return true
			if s.line(zone).size() >= config.zone_capacity:
				return false
			op.armor = op.max_armor(round_number)
			op.lethal_source = {}
			put_in_line(op, zone, false)
			s.operator_can_deploy = false
			emit_event(RulesEvent.OPERATOR_PLACED, {"side": side_name(si), "uid": op.uid, "zone": zone_name(zone)})
			trigger_traps(si, op)
		&"rotate":
			var op: RulesUnit = s.operator_unit
			if not op.is_on_board() or op.zone == zone:
				_waste_arrival(si, play)
				return true
			if s.line(zone).size() >= config.zone_capacity:
				return false
			var from: int = op.zone
			s.line(from).erase(op)
			put_in_line(op, zone, false)
			emit_event(RulesEvent.OPERATOR_ROTATED, {"side": side_name(si), "uid": op.uid, "from_zone": zone_name(from), "zone": zone_name(zone)})
			trigger_traps(si, op)
	process_eliminations()
	return true


## Rulings part 2 #9: a unit card whose zone is still full after the retry returns to
## hand (Supply is not refunded); with a full hand it is discarded instead.
func _waste_arrival(si: int, play: Dictionary) -> void:
	if play["kind"] == &"unit":
		var rc: RulesCard = play["card"]
		var s: RulesSide = sides[si]
		var fields: Dictionary = {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id,
				"zone": zone_name(play["zone"]), "reason": "zone full"}
		if s.hand.size() < config.hand_cap:
			s.hand.append(rc)
			emit_event(RulesEvent.CARD_RETURNED, fields)
		else:
			s.discard.append(rc)
			emit_event(RulesEvent.CARD_DISCARDED, fields)
	emit_event(RulesEvent.EFFECT_WASTED, {"side": side_name(si), "source_id": play["kind"], "kind": "ARRIVE", "reason": "zone full or Operator gone"})


func _apply_arrival_buff(si: int, u: RulesUnit) -> void:
	var s: RulesSide = sides[si]
	for i: int in s.arrival_buffs.size():
		var buff: Dictionary = s.arrival_buffs[i]
		if int(buff["zone"]) == u.zone:
			s.arrival_buffs.remove_at(i)
			var ctx: Dictionary = (buff["ctx"] as Dictionary).duplicate()
			ctx["override_target"] = u
			EffectResolver.resolve_effect(self, buff["effect"], ctx, true)
			return


func _reveal_tactic(si: int, play: Dictionary) -> void:
	var rc: RulesCard = play["card"]
	emit_event(RulesEvent.CARD_REVEALED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id, "zone": zone_name(play["zone"])})
	var ctx: Dictionary = make_ctx(si, SRC_TACTIC, rc.card.id, rc.uid, play["zone"], play["target_uid"], play["dest_zone"])
	EffectResolver.resolve_play(self, rc.card.effects, ctx)
	sides[si].discard.append(rc)
	emit_event(RulesEvent.CARD_DISCARDED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id})


## Places a Field (CardType.EQUIPMENT). A visible Field replaces the side's standing visible
## Field in that column (one per side per column, field-cards.md F1); hidden traps don't count.
func _reveal_equipment(si: int, play: Dictionary) -> void:
	var rc: RulesCard = play["card"]
	var zone: int = play["zone"]
	var fields: Dictionary = {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id, "zone": zone_name(zone), "hidden": rc.card.hidden}
	if rc.card.hidden:
		fields["private_to"] = side_name(si)
	emit_event(RulesEvent.CARD_REVEALED, fields)
	if rc.card.is_visible_field():
		for entry: Dictionary in sides[si].equipment[zone].duplicate():
			if (entry["card"] as RulesCard).card.is_visible_field():
				remove_field(si, zone, entry, RulesEvent.FIELD_GONE_REPLACED)
	sides[si].equipment[zone].append({"card": rc, "round": round_number})
	emit_event(RulesEvent.EQUIPMENT_PLACED, fields)
	var ctx: Dictionary = make_ctx(si, SRC_EQUIPMENT, rc.card.id, rc.uid, zone, play["target_uid"], play["dest_zone"])
	EffectResolver.resolve_play(self, rc.card.effects, ctx)


func _reveal_item(si: int, play: Dictionary) -> void:
	var item: LoadoutItem = play["item"]
	emit_event(RulesEvent.ITEM_REVEALED, {"side": side_name(si), "item_id": item.id, "zone": zone_name(play["zone"])})
	var ctx: Dictionary = make_ctx(si, source_kind_for_item(item), item.id, -1, play["zone"], play["target_uid"], play["dest_zone"])
	EffectResolver.resolve_play(self, item.effects, ctx)
	hooks.on_item_resolved(self, si, item)


## The arriving unit sets off the first enemy ON_ENEMY_ARRIVE equipment in its zone.
func trigger_traps(arriving_side: int, u: RulesUnit) -> void:
	var foe: RulesSide = sides[1 - arriving_side]
	var list: Array = foe.equipment[u.zone]
	for i: int in list.size():
		var rc: RulesCard = list[i]["card"]
		var trap_effects: Array[EffectData] = []
		for e: EffectData in rc.card.effects:
			if e != null and e.trigger == DataEnums.Trigger.ON_ENEMY_ARRIVE:
				trap_effects.append(e)
		if trap_effects.is_empty():
			continue
		emit_event(RulesEvent.EQUIPMENT_TRIGGERED, {"side": side_name(foe.index), "card_uid": rc.uid,
				"card_id": rc.card.id, "zone": zone_name(u.zone), "target_uid": u.uid})
		var ctx: Dictionary = make_ctx(foe.index, SRC_EQUIPMENT, rc.card.id, rc.uid, u.zone, -1, -1)
		ctx["arriving_uid"] = u.uid
		for e: EffectData in trap_effects:
			EffectResolver.resolve_effect(self, e, ctx)
		if rc.card.consumed_on_trigger:
			list.remove_at(i)
			foe.discard.append(rc)
			emit_event(RulesEvent.CARD_DISCARDED, {"side": side_name(foe.index), "card_uid": rc.uid, "card_id": rc.card.id})
		return


# =============================================================================
# Firefight & Score
# =============================================================================

func firefight() -> void:
	_set_phase(Phase.FIREFIGHT)
	FirefightResolver.resolve(self)
	announce_synergy()


## Score & Streak: control, END_OF_ROUND effects, streak (hook), mode score (hook),
## modifier expiry, match end check (hook).
func score() -> void:
	_set_phase(Phase.SCORE)
	var control: Array[int] = []
	for z: int in ZONE_COUNT:
		var c: int = control_of(z)
		control.append(c)
		emit_event(RulesEvent.ZONE_CONTROL, {"zone": zone_name(z), "owner": control_name(c)})
	_synergy_heal()  # kc-syn: Undead tier 2, before the END_OF_ROUND effects
	for si: int in side_order():
		var s: RulesSide = sides[si]
		for z: int in ZONE_COUNT:
			for entry: Dictionary in s.equipment[z].duplicate():
				var rc: RulesCard = entry["card"]
				var ctx: Dictionary = make_ctx(si, SRC_EQUIPMENT, rc.card.id, rc.uid, z, -1, -1)
				EffectResolver.resolve_triggered(self, rc.card.effects, DataEnums.Trigger.END_OF_ROUND, ctx)
		for u: RulesUnit in s.units_on_board():
			var uctx: Dictionary = unit_ctx(u)
			EffectResolver.resolve_triggered(self, u.effects, DataEnums.Trigger.END_OF_ROUND, uctx)
		for perk: LoadoutItem in s.setup.perks:
			var pctx: Dictionary = make_ctx(si, SRC_PERK, perk.id, -1, NO_ZONE, -1, -1)
			EffectResolver.resolve_triggered(self, perk.effects, DataEnums.Trigger.END_OF_ROUND, pctx)
	process_eliminations()
	_overrun()
	announce_synergy()
	for si: int in side_order():
		hooks.apply_streak(self, si)
	hooks.score_round(self, control)
	for s: RulesSide in sides:
		for u: RulesUnit in s.units_on_board():
			u.expire_mods(round_number)
	var kept: Array[Dictionary] = []
	for f: Dictionary in firefight_effects:
		if int(f["until_round"]) > round_number:
			kept.append(f)
	firefight_effects = kept
	emit_event(RulesEvent.ROUND_ENDED, {"player_score": sides[0].score, "enemy_score": sides[1].score})
	var outcome: StringName = hooks.check_match_end(self)
	if outcome != &"":
		result = outcome
		_set_phase(Phase.ENDED)
		var details: Dictionary = hooks.match_end_details(self)
		details["result"] = outcome
		emit_event(RulesEvent.MATCH_ENDED, details)


## Overrun (field-cards.md F1): after the END_OF_ROUND effects, each visible Field standing
## in a column the enemy controls (control as it is now, after those effects) is torn down
## to its owner's discard. Hidden traps are exempt.
func _overrun() -> void:
	for si: int in side_order():
		for z: int in ZONE_COUNT:
			if control_of(z) != 1 - si:
				continue
			for entry: Dictionary in sides[si].equipment[z].duplicate():
				if (entry["card"] as RulesCard).card.is_visible_field():
					remove_field(si, z, entry, RulesEvent.FIELD_GONE_OVERRUN)


## Takes one Field entry ({card, round}) off the board into its owner's discard.
func remove_field(si: int, zone: int, entry: Dictionary, reason: StringName) -> void:
	var s: RulesSide = sides[si]
	s.equipment[zone].erase(entry)
	var rc: RulesCard = entry["card"]
	s.discard.append(rc)
	emit_event(RulesEvent.EQUIPMENT_DESTROYED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id,
			"zone": zone_name(zone), "reason": reason})


## Removes every unit at 0 Armor (initiative side first, zone and line order),
## records eliminations, then resolves On Down / On Eliminate triggers, repeating
## until nothing else dies.
func process_eliminations() -> void:
	var guard: int = 0
	while guard < 64:
		guard += 1
		var dead: Array[RulesUnit] = []
		for si: int in side_order():
			for z: int in ZONE_COUNT:
				for u: RulesUnit in sides[si].lines[z]:
					if not u.is_alive():
						dead.append(u)
		if dead.is_empty():
			return
		var follow_ups: Array[Dictionary] = []
		for u: RulesUnit in dead:
			var zone: int = u.zone
			sides[u.side].line(zone).erase(u)
			u.zone = NO_ZONE
			var rec: Dictionary = _record_elimination(u, zone)
			follow_ups.append({"unit": u, "zone": zone, "rec": rec})
		for f: Dictionary in follow_ups:
			var u: RulesUnit = f["unit"]
			var ctx: Dictionary = make_ctx(u.side, SRC_ON_DOWN, u.source_id, u.uid, f["zone"], -1, -1)
			ctx["source_unit"] = u
			EffectResolver.resolve_triggered(self, u.effects, DataEnums.Trigger.ON_DOWN, ctx)
			var rec: Dictionary = f["rec"]
			if rec["credit"] and int(rec["by_uid"]) >= 0:
				var killer: RulesUnit = _find_unit_anywhere(int(rec["by_uid"]), dead)
				if killer != null:
					var kctx: Dictionary = unit_ctx(killer)
					if killer.zone == NO_ZONE:
						kctx["zone"] = f["zone"]
					EffectResolver.resolve_triggered(self, killer.effects, DataEnums.Trigger.ON_ELIMINATE, kctx)


func _record_elimination(u: RulesUnit, zone: int) -> Dictionary:
	var src: Dictionary = u.lethal_source
	var by_side: int = int(src.get("side", 1 - u.side))
	var source_kind: StringName = src.get("source_kind", &"")
	var credit: bool = u.grants_elimination_credit and by_side != u.side
	var rec: Dictionary = RulesEvent.make(RulesEvent.UNIT_ELIMINATED, round_number, {
		"victim_uid": u.uid, "victim_side": side_name(u.side), "victim_id": u.source_id,
		"is_operator": u.is_operator, "by_uid": int(src.get("uid", -1)), "by_side": side_name(by_side),
		"by_id": src.get("source_id", &""), "zone": zone_name(zone), "source_kind": source_kind,
		"by_killstreak": source_kind == SRC_KILLSTREAK, "credit": credit,
	})
	events.append(rec)
	round_eliminations.append(rec)
	if credit:
		sides[by_side].eliminations += 1
	var s: RulesSide = sides[u.side]
	if u.is_operator:
		s.operator_down_this_round = true
		u.mods.clear()
		u.survive_lethal = 0
		emit_event(RulesEvent.OPERATOR_DOWN, {"side": side_name(u.side), "uid": u.uid})
		hooks.on_operator_down(self, u.side)
	elif u.card != null and not u.card.is_token():
		s.discard.append(RulesCard.new(u.uid, u.card, u.chosen_trait))
		emit_event(RulesEvent.CARD_DISCARDED, {"side": side_name(u.side), "card_uid": u.uid, "card_id": u.card.id})
	hooks.on_elimination(self, rec)
	return rec


func _find_unit_anywhere(uid: int, extra: Array[RulesUnit]) -> RulesUnit:
	for s: RulesSide in sides:
		var u: RulesUnit = s.find_unit(uid)
		if u != null:
			return u
	for u: RulesUnit in extra:
		if u.uid == uid:
			return u
	return null


# =============================================================================
# Board operations (used by the resolvers)
# =============================================================================

## chosen_trait (kc-art-traits): the ONE trait the copy's art gives it (SynergyRules.trait_at checks
## it against the card's options; TRAIT_DEFAULT = the default). kc-no-training: there are no copy
## levels; every copy has its full keywords and effects.
func create_unit(side: int, card: CardData, uid: int = -1,
		chosen_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> RulesUnit:
	var u: RulesUnit = RulesUnit.new()
	u.uid = uid if uid >= 0 else new_uid()
	u.side = side
	u.card = card
	u.source_id = card.id
	u.weapon_class = card.weapon_class
	u.neighbor_keyword = SynergyRules.keyword_at(card)
	u.chosen_trait = chosen_trait
	u.synergy_trait = SynergyRules.trait_at(card, chosen_trait)
	var setup: SideSetup = sides[side].setup
	u.base_firepower = card.firepower + setup.firepower_bonus
	u.base_max_armor = maxi(1, card.armor + setup.armor_bonus)
	u.armor = u.base_max_armor
	u.counts_for_control = card.counts_for_control
	u.grants_elimination_credit = card.grants_elimination_credit
	u.first_shot = card.first_shot
	u.pick = card.pick
	u.flank = card.flank
	u.cover = card.cover
	u.suppress = card.suppress
	# kc-art-traits / head F2: every LMG has Pierce (printed on the Gunner and the Demolitions Expert).
	u.pierce = card.pierce or card.weapon_class == DataEnums.WeaponClass.LMG
	u.patch = card.patch
	u.holder = card.holder
	u.arrives_front = card.arrives_front
	u.effects = card.effects.duplicate()
	return u


func _build_operator(side: int, setup: SideSetup) -> RulesUnit:
	var primary: LoadoutItem = setup.primary
	if primary == null:
		return null
	var u: RulesUnit = RulesUnit.new()
	u.uid = new_uid()
	u.side = side
	u.is_operator = true
	u.source_id = primary.id
	u.weapon_class = primary.weapon_class
	var fp: int = primary.operator_firepower + setup.firepower_bonus
	var ar: int = primary.operator_armor + setup.armor_bonus
	var parts: Array[LoadoutItem] = [primary]
	for att: LoadoutItem in setup.attachments:
		if att != null:
			parts.append(att)
			fp += att.firepower_bonus
			ar += att.armor_bonus
	for p: LoadoutItem in parts:
		u.first_shot = u.first_shot or p.first_shot
		u.pick = u.pick or p.pick
		u.flank = u.flank or p.flank
		u.cover += p.cover
		u.suppress = u.suppress or p.suppress
		u.patch += p.patch
		u.holder = u.holder or p.holder
		u.effects.append_array(p.effects)
	# Head F2 (kc-fight-impl answers): any LMG weapon has Pierce, an Operator's LMG primary too.
	u.pierce = primary.weapon_class == DataEnums.WeaponClass.LMG
	u.base_firepower = maxi(0, fp)
	u.base_max_armor = maxi(1, ar)
	u.armor = u.base_max_armor
	return u


## Puts a unit into its side's line: front if it arrives_front (Shieldman, Ruling 6), else back.
func put_in_line(u: RulesUnit, zone: int, allow_front: bool = true) -> void:
	var line: Array = sides[u.side].line(zone)
	var index: int = line.size()
	if allow_front and u.arrives_front:
		index = 0
	line.insert(index, u)
	u.zone = zone
	emit_event(RulesEvent.UNIT_ARRIVED, {"side": side_name(u.side), "uid": u.uid, "card_id": u.source_id,
			"zone": zone_name(zone), "index": index, "is_operator": u.is_operator})


## Deals `raw` damage (Cover reduces it unless apply_cover is false). `src` =
## {side, uid, source_id, source_kind}. Returns the damage actually dealt.
func deal_damage(target: RulesUnit, raw: int, src: Dictionary, apply_cover: bool = true) -> int:
	if target == null or not target.is_alive():
		return 0
	var dmg: int = maxi(0, raw - (cover_of(target) if apply_cover else 0))
	target.armor -= dmg
	if target.armor <= 0:
		if target.survive_lethal > 0:
			target.armor = target.survive_lethal
			target.survive_lethal = 0
			emit_event(RulesEvent.SURVIVED_LETHAL, {"side": side_name(target.side), "uid": target.uid, "armor": target.armor})
		else:
			target.armor = 0
			if target.lethal_source.is_empty():
				target.lethal_source = src.duplicate()
	emit_event(RulesEvent.DAMAGE_DEALT, {"target_uid": target.uid, "side": side_name(target.side), "amount": dmg,
			"remaining": target.armor, "source_id": src.get("source_id", &""), "by_side": side_name(int(src.get("side", 0)))})
	return dmg


## Draws n cards; a card drawn with a full hand is discarded (core-rules §9);
## an empty deck reshuffles the discard pile (seeded).
func draw_cards(side: int, n: int) -> void:
	var s: RulesSide = sides[side]
	for i: int in n:
		if s.deck.is_empty():
			if s.discard.is_empty():
				return
			s.deck = s.discard.duplicate()
			s.discard.clear()
			shuffle(s.deck)
			emit_event(RulesEvent.DECK_RESHUFFLED, {"side": side_name(side), "count": s.deck.size()})
		var c: RulesCard = s.deck.pop_front()
		if s.hand.size() >= config.hand_cap:
			s.discard.append(c)
			emit_event(RulesEvent.CARD_BURNED, {"side": side_name(side), "card_uid": c.uid, "card_id": c.id()})
		else:
			s.hand.append(c)
			emit_event(RulesEvent.CARD_DRAWN, {"side": side_name(side), "card_uid": c.uid, "card_id": c.id(), "private_to": side_name(side)})


## Seeded Fisher-Yates shuffle (never the global RNG).
func shuffle(list: Array) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


# =============================================================================
# Queries (board-dependent stats, control, intel)
# =============================================================================

## Firepower now: printed + modifiers + passives + set bonus, never below 0 (kc-pos-cut: no range
## bonus by column any more).
func firepower_of(u: RulesUnit) -> int:
	var fp: int = u.base_firepower + u.mod_total(DataEnums.EffectKind.MODIFY_FIREPOWER, round_number)
	if u.zone >= 0:
		fp += passive_total(u, DataEnums.EffectKind.MODIFY_FIREPOWER)
		fp += int(synergy_of(u).get("fp", 0))  # kc-syn links and set bonuses
	return maxi(0, fp)


## Cover now. Link / set Cover (kc-syn) is removed with the rest by REMOVE_COVER (Recon Drone).
func cover_of(u: RulesUnit) -> int:
	if u.has_mod(DataEnums.EffectKind.REMOVE_COVER, round_number) or passive_has(u, DataEnums.EffectKind.REMOVE_COVER) \
			or sides[1 - u.side].has_flag(DataEnums.EffectKind.REMOVE_COVER, round_number):  # Recon Drone (p05)
		return 0
	return maxi(0, u.cover + u.mod_total(DataEnums.EffectKind.GRANT_COVER, round_number)
			+ passive_total(u, DataEnums.EffectKind.GRANT_COVER) + int(synergy_of(u).get("cover", 0)))


## First Shot now. Blackout-style REMOVE_FIRST_SHOT also removes a set-bonus First Shot (none since kc-specops3).
func has_first_shot(u: RulesUnit, with_synergy: bool = true) -> bool:
	if u.has_mod(DataEnums.EffectKind.REMOVE_FIRST_SHOT, round_number) or passive_has(u, DataEnums.EffectKind.REMOVE_FIRST_SHOT):
		return false
	return u.first_shot or u.has_mod(DataEnums.EffectKind.GRANT_FIRST_SHOT, round_number) \
			or passive_has(u, DataEnums.EffectKind.GRANT_FIRST_SHOT) or (with_synergy and bool(synergy_of(u).get("fs", false)))


func is_untargetable_by_pick_flank(u: RulesUnit) -> bool:
	return u.has_mod(DataEnums.EffectKind.UNTARGETABLE_BY_PICK_FLANK, round_number) \
			or passive_has(u, DataEnums.EffectKind.UNTARGETABLE_BY_PICK_FLANK)


## Sum of PASSIVE effects of `kind` that apply to u: effects of units on the board
## (auras like Anvil's), of the Operator's loadout, of the side's perks, and of the Fields
## standing in u's column (Bulwark, War Standard, Sniper Perch; either side's).
func passive_total(u: RulesUnit, kind: int) -> int:
	var total: int = 0
	for entry: Array in _passives_for(u, kind):
		total += int(entry[1])
	return total


func passive_has(u: RulesUnit, kind: int) -> bool:
	return not _passives_for(u, kind).is_empty()


func _passives_for(u: RulesUnit, kind: int) -> Array:
	var out: Array = []
	if u.zone < 0:
		return out
	for s: RulesSide in sides:
		var friendly: bool = s.index == u.side
		for src: RulesUnit in s.units_on_board():
			for e: EffectData in src.effects:
				if e == null or e.trigger != DataEnums.Trigger.PASSIVE or e.kind != kind:
					continue
				if EffectResolver.passive_applies(self, e, friendly, src, u, src.zone):
					out.append([e, EffectResolver.amount_for(self, e, u.side, u.zone)])
		for entry: Dictionary in s.equipment[u.zone]:
			for e: EffectData in (entry["card"] as RulesCard).card.effects:
				if e != null and e.trigger == DataEnums.Trigger.PASSIVE and e.kind == kind \
						and EffectResolver.field_passive_applies(self, e, s.index, u.zone, u):
					out.append([e, EffectResolver.amount_for(self, e, s.index, u.zone)])
		if friendly:
			for perk: LoadoutItem in s.setup.perks:
				for e: EffectData in perk.effects:
					if e != null and e.trigger == DataEnums.Trigger.PASSIVE and e.kind == kind \
							and EffectResolver.passive_applies(self, e, true, null, u, NO_ZONE):
						out.append([e, EffectResolver.amount_for(self, e, u.side, u.zone)])
	return out


## Field-aura part of passive_total (the AI's records leave it out and re-apply it to
## whoever is at the front in its estimate).
func field_passive_total(u: RulesUnit, kind: int) -> int:
	var total: int = 0
	if u.zone < 0:
		return total
	for s: RulesSide in sides:
		for entry: Dictionary in s.equipment[u.zone]:
			for e: EffectData in (entry["card"] as RulesCard).card.effects:
				if e != null and e.trigger == DataEnums.Trigger.PASSIVE and e.kind == kind \
						and EffectResolver.field_passive_applies(self, e, s.index, u.zone, u):
					total += EffectResolver.amount_for(self, e, s.index, u.zone)
	return total


# =============================================================================
# Synergy (kc-syn: neighbor keywords, trait sets, Operator cost; SynergyRules)
# =============================================================================

## Supply the Operator costs to place (round 1 and every respawn; RunConfig.operator_cost).
func operator_cost() -> int:
	return maxi(0, config.operator_cost)


## This unit's synergy right now: {fp, cover, fs, heal, links: [{kind, from_uid}], sets: [[trait, tier]]}
## ({} off the board). Read live from the lines (cached until the board changes).
func synergy_of(u: RulesUnit) -> Dictionary:
	if u == null or u.zone < 0:
		return {}
	_syn_refresh()
	return _syn_units.get(u.uid, {})


## Side-level synergy: {counts: {trait: n}, tiers: {trait: 0/2/3}, links: [{kind, from_uid, to_uid}]}.
func synergy_side(side: int) -> Dictionary:
	_syn_refresh()
	return _syn_sides[side]


## Slots of one side's board for SynergyRules (Operator / tokens: no keyword, no trait).
func synergy_lines(side: int) -> Array:
	var lines: Array = [[], [], []]
	for z: int in ZONE_COUNT:
		for u: RulesUnit in sides[side].line(z):
			lines[z].append(SynergyRules.slot(u.uid, u.neighbor_keyword, u.synergy_trait))
	return lines


## Traits of `side`'s visible Fields (traps never count).
func synergy_field_traits(side: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for z: int in ZONE_COUNT:
		for entry: Dictionary in sides[side].equipment[z]:
			var rc: RulesCard = entry["card"]
			if rc.card.is_visible_field() and rc.card_trait() != &"":
				out.append(rc.card_trait())
	return out


func _syn_signature() -> PackedInt32Array:
	var sig: PackedInt32Array = PackedInt32Array()
	for s: RulesSide in sides:
		for z: int in ZONE_COUNT:
			for u: RulesUnit in s.lines[z]:
				sig.append(u.uid)
			sig.append(-1)
			for entry: Dictionary in s.equipment[z]:
				sig.append((entry["card"] as RulesCard).uid)
			sig.append(-2)
	return sig


func _syn_refresh() -> void:
	var sig: PackedInt32Array = _syn_signature()
	if sig == _syn_sig and _syn_sig.size() > 0:
		return
	_syn_sig = sig
	_syn_units = {}
	for si: int in 2:
		var lines: Array = synergy_lines(si)
		var res: Dictionary = SynergyRules.compute(lines, synergy_field_traits(si), sides[si].setup.doctrine)
		for z: int in ZONE_COUNT:
			for i: int in (lines[z] as Array).size():
				_syn_units[int(lines[z][i]["uid"])] = res["zones"][z][i]
		_syn_sides[si] = {"counts": res["counts"], "tiers": res["tiers"], "links": res["links"]}


## kc-syn §4.4 Undead tier 2: in the Score step, before the END_OF_ROUND effects, each damaged
## unit with a trait heal heals that much (never above max Armor). Logged as UNIT_HEALED with
## source_id &"trait_undead".
func _synergy_heal() -> void:
	for si: int in side_order():
		for u: RulesUnit in sides[si].units_on_board():
			var h: int = int(synergy_of(u).get("heal", 0))
			if h <= 0 or not u.is_alive():
				continue
			var healed: int = mini(h, u.damage_taken(round_number))
			if healed <= 0:
				continue
			u.armor += healed
			emit_event(RulesEvent.UNIT_HEALED, {"side": side_name(si), "source_id": &"trait_undead", "source_uid": -1,
					"target_uid": u.uid, "amount": healed, "remaining": u.armor, "zone": zone_name(u.zone)})


## Emits SYNERGY_CHANGED for each side whose active links or set tiers changed since the last call.
func announce_synergy() -> void:
	for si: int in 2:
		var view: Dictionary = synergy_side(si)
		var parts: Array[String] = []
		for l: Dictionary in view["links"]:
			parts.append("%s:%d>%d" % [l["kind"], l["from_uid"], l["to_uid"]])
		parts.sort()
		var tiers: Array[String] = []
		for t: StringName in SynergyRules.TRAITS:
			tiers.append("%s%d" % [t, int(view["tiers"].get(t, 0))])
		var key: String = ",".join(parts) + "|" + ",".join(tiers)
		if key == _syn_announced[si]:
			continue
		_syn_announced[si] = key
		var sets: Dictionary = {}
		for t: StringName in view["tiers"]:
			sets[t] = int(view["tiers"][t])
		emit_event(RulesEvent.SYNERGY_CHANGED, {"side": side_name(si), "links": view["links"].duplicate(true),
				"counts": view["counts"].duplicate(), "sets": sets})


## UI hook (kc-syn §9): everything the board needs to draw links, the trait rail and set callouts.
## Public information (both sides' boards are visible). Returns
##   {player: SIDE, enemy: SIDE, units: {uid: UNIT}} with
##   SIDE = {counts: {trait: n}, tiers: {trait: 0/2/3}, doctrine: trait, links: [{kind, from_uid, to_uid}],
##           rail: [{trait, name, count, tier, next, doctrine}] (traits with count > 0, TRAITS order)}
##   UNIT = {uid, side, keyword, trait, fp, cover, fs, heal, links: [{kind, from_uid}],
##           sets: [[trait, tier]]}
## (fp / cover / fs / heal are the synergy part only; firepower_of etc. already include them.)
func synergy_view(_viewer: int = PLAYER) -> Dictionary:
	_syn_refresh()
	var out: Dictionary = {"units": {}}
	for si: int in 2:
		var sv: Dictionary = _syn_sides[si]
		var rail: Array[Dictionary] = []
		for t: StringName in SynergyRules.TRAITS:
			var n: int = int(sv["counts"].get(t, 0))
			if n > 0:
				var tier: int = int(sv["tiers"].get(t, 0))
				rail.append({"trait": t, "name": SynergyRules.TRAIT_NAMES[t], "count": n, "tier": tier,
						"next": SynergyRules.next_tier(t, tier),
						"doctrine": t == sides[si].setup.doctrine})
		out[side_name(si)] = {"counts": sv["counts"].duplicate(), "tiers": sv["tiers"].duplicate(),
				"doctrine": sides[si].setup.doctrine, "links": sv["links"].duplicate(true), "rail": rail}
		for u: RulesUnit in sides[si].units_on_board():
			var r: Dictionary = _syn_units.get(u.uid, {})
			out["units"][u.uid] = {"uid": u.uid, "side": side_name(si), "keyword": u.neighbor_keyword,
					"trait": u.synergy_trait,
					"fp": int(r.get("fp", 0)), "cover": int(r.get("cover", 0)), "fs": bool(r.get("fs", false)),
					"heal": int(r.get("heal", 0)), "links": (r.get("links", []) as Array).duplicate(true),
					"sets": (r.get("sets", []) as Array).duplicate(true)}
	return out


## Placement preview (kc-syn §9): what `side`'s synergy would be if hand card `card_uid` arrived in
## `zone` after this Deploy's queued unit plays. Works for units and visible Fields. Returns
## {ok, links: [{kind, from_uid, to_uid}] (all active links after it), new_links: [...] (links that
## appear), card: {fp, cover, fs, links, sets} (the arriving unit's own bonus), tiers_before: {trait: tier},
## tiers_after: {trait: tier}, counts_before, counts_after}. The arriving card uses uid = card_uid.
func preview_synergy(side: int, card_uid: int, zone: int) -> Dictionary:
	var s: RulesSide = sides[side]
	var rc: RulesCard = s.find_in_hand(card_uid)
	if rc == null or not is_zone(zone) or rc.card.card_type == DataEnums.CardType.TACTIC:
		return {"ok": false}
	var lines: Array = synergy_lines(side)
	var fields: Array[StringName] = synergy_field_traits(side)
	for p: Dictionary in s.plays:  # queued arrivals (play order; capacity as at Reveal)
		if p["kind"] == &"unit":
			var prc: RulesCard = p["card"]
			_preview_insert(lines[int(p["zone"])], SynergyRules.slot(prc.uid, prc.neighbor_keyword(), prc.card_trait()), prc.arrives_front())
		elif p["kind"] == &"place" and s.operator_unit != null:
			_preview_insert(lines[int(p["zone"])], SynergyRules.slot(s.operator_unit.uid), false)
		elif p["kind"] == &"equipment" and (p["card"] as RulesCard).card.is_visible_field():
			var t0: StringName = (p["card"] as RulesCard).card_trait()
			if t0 != &"":
				fields.append(t0)
	var before: Dictionary = SynergyRules.compute(lines, fields, s.setup.doctrine)
	var after_lines: Array = [(lines[0] as Array).duplicate(), (lines[1] as Array).duplicate(), (lines[2] as Array).duplicate()]
	var after_fields: Array[StringName] = fields.duplicate()
	if rc.card.is_unit():
		_preview_insert(after_lines[zone], SynergyRules.slot(rc.uid, rc.neighbor_keyword(), rc.card_trait()), rc.arrives_front())
	elif rc.card.is_visible_field() and rc.card_trait() != &"":
		var standing: RulesCard = visible_field(side, zone)
		if standing != null and standing.card_trait() != &"":
			after_fields.erase(standing.card_trait())
		after_fields.append(rc.card_trait())
	var after: Dictionary = SynergyRules.compute(after_lines, after_fields, s.setup.doctrine)
	var seen: Dictionary = {}
	for l: Dictionary in before["links"]:
		seen["%s:%d>%d" % [l["kind"], l["from_uid"], l["to_uid"]]] = true
	var fresh: Array[Dictionary] = []
	for l: Dictionary in after["links"]:
		if not seen.has("%s:%d>%d" % [l["kind"], l["from_uid"], l["to_uid"]]):
			fresh.append(l)
	var own: Dictionary = {}
	for z: int in ZONE_COUNT:
		for i: int in (after_lines[z] as Array).size():
			if int(after_lines[z][i]["uid"]) == rc.uid:
				own = after["zones"][z][i]
	return {"ok": true, "links": after["links"], "new_links": fresh, "card": own,
			"tiers_before": before["tiers"], "tiers_after": after["tiers"],
			"counts_before": before["counts"], "counts_after": after["counts"]}


func _preview_insert(line: Array, slot_data: Dictionary, front: bool) -> void:
	if line.size() >= config.zone_capacity:
		return
	if front:
		line.insert(0, slot_data)
	else:
		line.append(slot_data)


# =============================================================================
# Fields (CardType.EQUIPMENT; kc-field-impl)
# =============================================================================

## Field entries ({card: RulesCard, round: int}) of `side` in `zone`, placement order.
## include_hidden = false leaves out traps (what the other side may see).
func fields_in(side: int, zone: int, include_hidden: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_zone(zone):
		return out
	for entry: Dictionary in sides[side].equipment[zone]:
		if include_hidden or not (entry["card"] as RulesCard).card.hidden:
			out.append(entry)
	return out


## The visible Field `side` has standing in `zone` (at most one), or null.
func visible_field(side: int, zone: int) -> RulesCard:
	for entry: Dictionary in sides[side].equipment[zone]:
		var rc: RulesCard = entry["card"]
		if rc.card.is_visible_field():
			return rc
	return null


## UI hook for the vertical column board (kc-board): per column, what `viewer` may see of
## both sides' Fields. [{zone: &"left", player: [entry...], enemy: [entry...]}, ...] where an
## entry is {card_uid, card_id, name, text, hidden, placed_round, overrun_risk}. The viewer's
## own hidden traps are listed (hidden = true, draw them dashed); the other side's are not.
## overrun_risk = the other side controls the column right now (the Field falls at the end
## of this round's Score step if that still holds), false for traps.
func field_view(viewer: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for z: int in ZONE_COUNT:
		var row: Dictionary = {"zone": zone_name(z)}
		var control: int = control_of(z)
		for si: int in 2:
			var list: Array[Dictionary] = []
			for entry: Dictionary in fields_in(si, z, si == viewer):
				var rc: RulesCard = entry["card"]
				list.append({"card_uid": rc.uid, "card_id": rc.card.id, "name": rc.card.display_name,
						"text": rc.card.text, "hidden": rc.card.hidden, "placed_round": int(entry["round"]),
						"overrun_risk": rc.card.is_visible_field() and control == 1 - si})
			row[side_name(si)] = list
		out.append(row)
	return out


func _field_planned(side: int, zone: int) -> bool:
	for p: Dictionary in sides[side].plays:
		if p["kind"] == &"equipment" and int(p["zone"]) == zone and (p["card"] as RulesCard).card.is_visible_field():
			return true
	return false


## PLAYER / ENEMY, CONTROL_CONTESTED or CONTROL_EMPTY (core-rules §2.5, Holder, Ruling 5).
func control_of(zone: int) -> int:
	var present: Array[bool] = [false, false]
	var holder: Array[bool] = [false, false]
	for si: int in 2:
		for u: RulesUnit in sides[si].line(zone):
			if u.is_alive() and u.counts_for_control:
				present[si] = true
				holder[si] = holder[si] or u.holder
	if not present[0] and not present[1]:
		return CONTROL_EMPTY
	if not present[1]:
		return PLAYER
	if not present[0]:
		return ENEMY
	if holder[0] and not holder[1]:
		return PLAYER
	if holder[1] and not holder[0]:
		return ENEMY
	return CONTROL_CONTESTED


func zones_controlled(side: int) -> int:
	var n: int = 0
	for z: int in ZONE_COUNT:
		if control_of(z) == side:
			n += 1
	return n


## Red dots `viewer` sees: the other side's committed unit deployments per zone
## (unit cards + Operator placement / Rotation; Ruling 13).
func red_dots(viewer: int) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var foe: RulesSide = sides[1 - viewer]
	var op_hidden: bool = foe.has_flag(DataEnums.EffectKind.HIDE_FROM_INTEL, round_number)
	for play: Dictionary in foe.plays:
		var kind: StringName = play["kind"]
		if kind == &"unit" or (kind in [&"place", &"rotate"] and not op_hidden):
			counts[int(play["zone"])] += 1
	return counts


## Card ids behind the red dots of `zone`, if `viewer` revealed that zone this round
## (Callout, Recon Specialist) or sees all enemy deployments (Recon Drone); otherwise empty.
func revealed_red_dots(viewer: int, zone: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var zones: Array = sides[viewer].intel_reveals.get(round_number, [])
	if zone not in zones and not sides[viewer].has_flag(DataEnums.EffectKind.REVEAL_DEPLOYMENTS, round_number):
		return out
	var foe: RulesSide = sides[1 - viewer]
	for play: Dictionary in foe.plays:
		if int(play["zone"]) != zone:
			continue
		if play["kind"] == &"unit":
			out.append((play["card"] as RulesCard).card.id)
		elif play["kind"] in [&"place", &"rotate"] and not foe.has_flag(DataEnums.EffectKind.HIDE_FROM_INTEL, round_number):
			out.append(foe.operator_unit.source_id)
	return out


## Units this side would have in `zone` after its queued plays resolve.
func projected_occupancy(side: int, zone: int) -> int:
	var n: int = sides[side].line(zone).size()
	for play: Dictionary in sides[side].plays:
		if play["kind"] in [&"unit", &"place", &"rotate"] and int(play["zone"]) == zone:
			n += 1
		if play["kind"] == &"rotate" and int(play["from_zone"]) == zone:
			n -= 1
	return n


## Where the Operator will be after this Deploy's placement / Rotations (NO_ZONE = off board).
func projected_operator_zone(side: int) -> int:
	var op: RulesUnit = sides[side].operator_unit
	if op == null:
		return NO_ZONE
	var zone: int = op.zone
	for play: Dictionary in sides[side].plays:
		if play["kind"] in [&"place", &"rotate"]:
			zone = play["zone"]
	return zone


func find_item(side: int, item_id: StringName) -> LoadoutItem:
	var setup: SideSetup = sides[side].setup
	for item: LoadoutItem in setup.killstreaks:
		if item != null and item.id == item_id:
			return item
	return null


func find_unit(uid: int) -> RulesUnit:
	for s: RulesSide in sides:
		var u: RulesUnit = s.find_unit(uid)
		if u != null:
			return u
	return null


# =============================================================================
# Helpers
# =============================================================================

func new_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


func emit_event(type: StringName, fields: Dictionary = {}) -> void:
	events.append(RulesEvent.make(type, round_number, fields))


func events_since(index: int) -> Array[Dictionary]:
	return events.slice(index)


## [initiative side, other side].
func side_order() -> Array[int]:
	return [initiative, 1 - initiative]


func side_name(side: int) -> StringName:
	return SIDE_NAMES[side] if side >= 0 and side < 2 else &""


func zone_name(zone: int) -> StringName:
	return MapData.ZONE_IDS[zone] if is_zone(zone) else &""


func control_name(c: int) -> StringName:
	match c:
		PLAYER, ENEMY:
			return side_name(c)
		CONTROL_CONTESTED:
			return &"contested"
	return &"empty"


func is_zone(zone: int) -> bool:
	return zone >= 0 and zone < ZONE_COUNT


## Left-Mid and Mid-Right are adjacent; the flanks are not.
func are_adjacent(a: int, b: int) -> bool:
	return is_zone(a) and is_zone(b) and absi(a - b) == 1


## Effect context: who resolves it, from what, with which player choices.
func make_ctx(side: int, source_kind: StringName, source_id: StringName, source_uid: int,
		zone: int, target_uid: int, dest_zone: int) -> Dictionary:
	return {
		"side": side, "source_kind": source_kind, "source_id": source_id, "source_uid": source_uid,
		"zone": zone, "target_uid": target_uid, "dest_zone": dest_zone, "source_unit": null,
	}


func unit_ctx(u: RulesUnit) -> Dictionary:
	var ctx: Dictionary = make_ctx(u.side, SRC_OPERATOR if u.is_operator else SRC_UNIT, u.source_id, u.uid, u.zone, -1, -1)
	ctx["source_unit"] = u
	return ctx


func source_kind_for_item(item: LoadoutItem) -> StringName:
	match item.slot:
		DataEnums.LoadoutSlot.KILLSTREAK:
			return SRC_KILLSTREAK
		DataEnums.LoadoutSlot.PERK:
			return SRC_PERK
	return SRC_OPERATOR


func _source_kind_for_card(card: CardData) -> StringName:
	match card.card_type:
		DataEnums.CardType.TACTIC:
			return SRC_TACTIC
		DataEnums.CardType.EQUIPMENT:
			return SRC_EQUIPMENT
	return SRC_UNIT


func _play_effects(play: Dictionary) -> Array[EffectData]:
	if play["card"] != null and play["kind"] != &"unit":
		return (play["card"] as RulesCard).card.effects
	if play["item"] != null:
		return (play["item"] as LoadoutItem).effects
	return []


## [source_kind, source_id, source_uid] of a tactic / equipment / item play.
func _play_source(play: Dictionary) -> Array:
	if play["item"] != null:
		var item: LoadoutItem = play["item"]
		return [source_kind_for_item(item), item.id, -1]
	var rc: RulesCard = play["card"]
	return [_source_kind_for_card(rc.card), rc.card.id, rc.uid]


func _has_play(side: int, kind: StringName) -> bool:
	for p: Dictionary in sides[side].plays:
		if p["kind"] == kind:
			return true
	return false


func _set_phase(p: Phase) -> void:
	phase = p
	emit_event(RulesEvent.PHASE_CHANGED, {"phase": PHASE_NAMES[p]})


func _ok() -> Dictionary:
	return {"ok": true, "code": &"ok", "reason": "", "data": {}}


func _ok_play(play: Dictionary) -> Dictionary:
	var data: Dictionary = {}
	if not play.get("warnings", []).is_empty():
		data["warnings"] = play["warnings"]
	play.erase("warnings")
	return {"ok": true, "code": &"ok", "reason": "", "data": data, "play": play}


func _fail(reason: String, code: StringName = &"refused", data: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason, "data": data}


## A check result without the internal draft play.
func _public(check: Dictionary) -> Dictionary:
	return {"ok": check["ok"], "code": check["code"], "reason": check["reason"], "data": check["data"]}
