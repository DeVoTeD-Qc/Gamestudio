# loadout_rules.gd
# Purpose: The CardZone Loadout Loop rules engine (spec loadout-loop-spec.md v0.2 + §16, the 1v1
#   prototype rules; ruling IDs D, P, S, U, R; tunables §16.8 read from BalanceConfig only).
#   Node-free and deterministic: no randomness anywhere, so a match is its setup plus its
#   action list (U1) and replay() reproduces it exactly. Every function is static and works on
#   a MatchState.
#
# Rules questions (QA rules-test-cases.md RQ-01..RQ-11): this engine implements QA's proposed
# answer to every one of them:
#   RQ-01 Damage before Brace > 0 and no Suppressor -> always a Brace step (a `brace` action,
#         which may be empty), even when the defender has nothing that can brace.
#   RQ-02 The held count is the number of held-marked cards in the loadout; a mark clears when
#         the card braces or is drawn/pulled.
#   RQ-03 A Frag never enters the line: frag(area) takes it from the hand straight out of the
#         game (face up, `removed`). play() on a Frag is illegal.
#   RQ-04 Setup action drop(area): P2 first, then P1, outer areas only, logged before round 1;
#         round 1 starts after P1's drop. Not undoable.
#   RQ-05 A 0-damage shot uses the weapon's shot and commits the turn (no Brace step).
#   RQ-06 A thrower eliminated by their own Frag doesn't claim the Bounty.
#   RQ-07 Actions carry card instance ids (QA codes are resolved by the test runner).
#   RQ-08 Every tunable is read on its own; the engine never pairs hand_size with drop cost.
#   RQ-09 An empty final_circle_hits is BalanceConfig's to reject; the engine treats it as 0.
#   RQ-10 view(state, seat) uses QA's field names (MatchView): opponent.{area, health, line,
#         fired, held_count, held_cards?, next_draw_hits?, hand_hits?, loadout_count?, down,
#         hand_count, eliminated}, `me`, the public table, shot_preview / brace_prompt. Hidden
#         fields are left out, never sent as null.
#   RQ-11 MatchState.from_fixture(setup) plus the test hooks auto_draw(), check (no action) and
#         view(seat).
#
# ACTIONS (Dictionaries; "seat" is 0 = P1, 1 = P2; cards are instance ids):
#   {type: "drop", seat, area}                     setup, RQ-04
#   {type: "play", seat, card, adrenaline?: "move"|"search"}   R6 (adrenaline only for a Hit)
#   {type: "move", seat, to}                       spend 1 Move, adjacent area
#   {type: "loot", seat, pile: card_id} | {type: "loot", seat, card: inst}  (drop or crate card)
#   {type: "shoot", seat, weapon, target}          R21-R30
#   {type: "frag", seat, area, card?}              R31-R35 (card defaults to the first Frag in hand)
#   {type: "attach", seat, attachment, weapon}     R11
#   {type: "patch_up", seat}                       R18
#   {type: "ditch", seat, card}                    R19
#   {type: "end_turn", seat, hold: [inst], rack_move?: {from, to}}   gas check, Pack, next turn
#   {type: "brace", seat, cards: [inst in order]}  defender, R25
#   {type: "undo", seat}                           U2 (never logged)
#   {type: "concede", seat}                        R49, any time
#
# FAST PATH (AI search, cz07b): apply_fast(state, action) -> bool runs the same checks and
#   effects as apply() with no undo snapshot, no log entry and no events. Public helpers the AI
#   shares with the engine: brace_candidates, subsets, cover_for, shooting_open, fire_limit, weapon_range,
#   shot_profile, blast_profile.
# BALANCE SWITCHES (BalanceConfig.SWITCHES, off by default): p2_start_health_bonus (P2 starts
#   and heals up to health + 1), no_shooting_round1 (ERR_NO_SHOOTING_ROUND1 on shoot and frag).
# EVENT TYPES (ActionResult.events, in order): dropped, round_started, bounty_changed,
#   zone_flipped, gas_closed, drop_landed, final_circle, turn_started, drew*, played, adrenaline,
#   healed, spent, pulled*, moved, looted, attached, patched_up, ditched, shot_declared,
#   frag_thrown, brace_requested, braced, hits_landed, bounty_claimed, gas_hit, packed*,
#   eliminated, crate_formed, match_ended, undone, conceded.  (* has a secret part for its owner)
# Dependencies: MatchState, SeatState, RulesData, ActionResult, MatchView, CardData, BalanceConfig.
# Author: Mechanics Developer Agent
class_name LoadoutRules
extends RefCounted

const ERR_OVER: StringName = &"match_over"
const ERR_PHASE: StringName = &"wrong_phase"
const ERR_NOT_YOUR_TURN: StringName = &"not_your_turn"
const ERR_PENDING_BRACE: StringName = &"brace_pending"
const ERR_NO_PENDING: StringName = &"no_brace_pending"
const ERR_UNKNOWN: StringName = &"unknown_action"
const ERR_NOT_IN_HAND: StringName = &"not_in_hand"
const ERR_NOT_IN_LINE: StringName = &"not_in_line"
const ERR_BAD_CARD: StringName = &"wrong_card"
const ERR_ADRENALINE: StringName = &"adrenaline_mode"
const ERR_ADRENALINE_CAP: StringName = &"adrenaline_cap"
const ERR_FRAG_PLAY: StringName = &"frag_is_thrown"
const ERR_NO_MOVE: StringName = &"no_move"
const ERR_NOT_ADJACENT: StringName = &"not_adjacent"
const ERR_GAS: StringName = &"gas_area"
const ERR_NO_SEARCH: StringName = &"no_search"
const ERR_NO_SOURCE: StringName = &"nothing_to_loot"
const ERR_NOT_READY: StringName = &"drop_not_ready"
const ERR_NO_SHOTS: StringName = &"no_shots_left"
const ERR_BAD_TARGET: StringName = &"bad_target"
const ERR_OUT_OF_RANGE: StringName = &"out_of_range"
const ERR_ATTACH: StringName = &"cant_attach"
const ERR_NO_HIT: StringName = &"nothing_to_heal"
const ERR_DITCH: StringName = &"cant_ditch"
const ERR_DITCH_LIMIT: StringName = &"ditch_limit"
const ERR_MIN_LOADOUT: StringName = &"min_loadout"
const ERR_HOLD: StringName = &"bad_hold"
const ERR_RACK: StringName = &"bad_rack_move"
const ERR_BRACE: StringName = &"bad_brace"
const ERR_UNDO: StringName = &"cant_undo"
const ERR_DROP: StringName = &"bad_drop"
## Balance switch no_shooting_round1 (cz07b, off by default): in round 1 no seat may shoot or
## throw a Frag. Returned by shoot and frag checks before any other shoot/frag reason, so
## legal_actions() lists no shoot or frag in round 1 while it is on.
const ERR_NO_SHOOTING_ROUND1: StringName = &"no_shooting_round1"

## Search to Patch up (spec §5, R18) and to Ditch (R19): printed rules, not §16.8 tunables.
const PATCH_UP_COST: int = 2
const DITCH_COST: int = 1

## Actions that can be undone (U2-U4); shots, Brace and End turn commit (U3).
const UNDOABLE: Array[String] = ["play", "move", "loot", "attach", "patch_up", "ditch"]
const PLAYER_ACTIONS: Array[String] = ["play", "move", "loot", "shoot", "frag", "attach",
		"patch_up", "ditch", "end_turn"]


# === Public API ==========================================================================

## apply_fast()'s throwaway event list (never read).
static var _fast_events: Array[Dictionary] = []

## Applies one action. On success the state changes, the action is logged (except undo) and the
## result carries the ordered events. On failure the state is untouched.
static func apply(state: MatchState, action: Dictionary) -> ActionResult:
	var a: Dictionary = normalize(state, action)
	var err: StringName = check(state, a)
	if err != &"":
		return ActionResult.rejected(err, a)
	var r: ActionResult = ActionResult.new()
	r.ok = true
	r.action = a
	var t: String = a["type"]
	if t == "undo":
		_do_undo(state, r.events)
		return r
	if t in UNDOABLE:
		state.undo_stack.append({"state": state.to_dict(), "log_size": state.actions.size()})
	_do(state, a, r.events)
	state.actions.append(a)
	if not (t in UNDOABLE):
		state.undo_stack.clear()
	if t in ["shoot", "frag", "brace"]:
		r.shot = state.last_shot.duplicate(true)
	return r


## The search fast path (cz07b): runs `action` with exactly apply()'s checks and effects, but
## keeps no undo snapshot, adds nothing to the action log and collects no events (it reuses one
## scratch event list). Returns false and leaves the state untouched when the action is illegal.
## For AI search on throwaway copies only: a state stepped this way can't be undone or replayed
## from its log. Undo is refused (it needs the snapshots this path never takes).
static func apply_fast(state: MatchState, action: Dictionary) -> bool:
	return apply_fast_normalized(state, normalize(state, action))


## apply_fast() for an action already in normal form (normalize(): ints for ids and seats, a
## String type, card lists as Arrays of ints, the Frag card given).
static func apply_fast_normalized(state: MatchState, a: Dictionary) -> bool:
	if String(a.get("type", "")) == "undo" or check(state, a) != &"":
		return false
	_fast_events.clear()
	_do(state, a, _fast_events)
	return true


## Runs the action on a copy (the same code as apply) and returns what it would do.
static func preview(state: MatchState, action: Dictionary) -> ActionResult:
	var copy: MatchState = state.clone()
	var r: ActionResult = apply(copy, action)
	r.is_preview = true
	return r


## True when apply() would accept the action.
static func is_legal(state: MatchState, action: Dictionary) -> bool:
	return check(state, normalize(state, action)) == &""


## Why apply() would reject the action (&"" when it is legal). Expects a normalised action.
static func check(state: MatchState, a: Dictionary) -> StringName:
	var t: String = String(a.get("type", ""))
	var seat: int = int(a.get("seat", -1))
	if seat != MatchState.P1 and seat != MatchState.P2:
		return ERR_NOT_YOUR_TURN
	if state.is_over():
		return ERR_OVER
	if t == "concede":
		return &""
	if state.phase == MatchState.PHASE_DROP:
		return _check_drop(state, a) if t == "drop" else ERR_PHASE
	match t:
		"drop":
			return ERR_PHASE
		"brace":
			return _check_brace(state, a)
		"undo":
			if not state.pending.is_empty() or seat != state.active or state.undo_stack.is_empty():
				return ERR_UNDO
			return &""
	if not (t in PLAYER_ACTIONS):
		return ERR_UNKNOWN
	if not state.pending.is_empty():
		return ERR_PENDING_BRACE
	if seat != state.active:
		return ERR_NOT_YOUR_TURN
	match t:
		"play":
			return _check_play(state, a)
		"move":
			return _check_move(state, a)
		"loot":
			return _check_loot(state, a)
		"shoot":
			return _check_shoot(state, a)
		"frag":
			return _check_frag(state, a)
		"attach":
			return _check_attach(state, a)
		"patch_up":
			return _check_patch_up(state, a)
		"ditch":
			return _check_ditch(state, a)
		"end_turn":
			return _check_end_turn(state, a)
	return ERR_UNKNOWN


## A copy of the action with typed values (ints for ids and seats, text for the type) and the
## Frag card filled in when it was left out.
static func normalize(state: MatchState, action: Dictionary) -> Dictionary:
	var a: Dictionary = {}
	for k: Variant in action.keys():
		a[String(k)] = action[k]
	a["type"] = String(a.get("type", ""))
	a["seat"] = int(a.get("seat", -1)) if (a.get("seat") is int or a.get("seat") is float) else -1
	for key: String in ["card", "weapon", "attachment", "target"]:
		if a.has(key) and (a[key] is int or a[key] is float):
			a[key] = int(a[key])
	for key: String in ["to", "area", "pile", "adrenaline"]:
		if a.has(key) and a[key] != null:
			a[key] = String(a[key])
	if a["type"] == "brace" or a["type"] == "end_turn":
		var key: String = "cards" if a["type"] == "brace" else "hold"
		var ids: Array = []
		for x: Variant in a.get(key, []):
			ids.append(int(x))
		a[key] = ids
		if a["type"] == "end_turn":
			var rack: Variant = a.get("rack_move", null)
			if rack is Dictionary and not (rack as Dictionary).is_empty():
				a["rack_move"] = {"from": int(rack.get("from", -1)), "to": int(rack.get("to", -1))}
			else:
				a.erase("rack_move")
	if a["type"] == "frag" and int(a.get("card", 0)) == 0 and a["seat"] >= 0:
		a["card"] = _first_frag(state, a["seat"])
	return a


## Every legal action for the seat that must act now (the pending defender, else the active
## seat; the drop seat during setup). Undo and concede are not listed (meta actions).
## Brace options are listed in next-hand order (any order is legal; order only sets where the
## cards go at the bottom). end_turn lists every hold choice (or every rack move).
## With the no_shooting_round1 switch on, round 1 lists no shoot and no frag (check() returns
## ERR_NO_SHOOTING_ROUND1 for them).
static func legal_actions(state: MatchState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.is_over():
		return out
	if state.phase == MatchState.PHASE_DROP:
		for area_id: StringName in state.data.area_order:
			_add_if_legal(state, out, {"type": "drop", "seat": state.active, "area": String(area_id)})
		return out
	var defender: int = state.pending_brace_seat()
	if defender != MatchState.NO_SEAT:
		var eligible: Array[int] = brace_candidates(state, defender)
		for subset: Array in subsets(eligible, eligible.size()):
			out.append({"type": "brace", "seat": defender, "cards": subset})
		return out
	var seat: int = state.active
	var st: SeatState = state.seats[seat]
	var b: BalanceConfig = state.data.balance
	for inst: int in st.hand:
		var c: CardData = state.def_of(inst)
		if c.is_hit():
			_add_if_legal(state, out, {"type": "play", "seat": seat, "card": inst, "adrenaline": "move"})
			_add_if_legal(state, out, {"type": "play", "seat": seat, "card": inst, "adrenaline": "search"})
		elif c.blast_dmg > 0:
			for area_id: StringName in state.data.area_order:
				_add_if_legal(state, out, {"type": "frag", "seat": seat, "card": inst, "area": String(area_id)})
		else:
			_add_if_legal(state, out, {"type": "play", "seat": seat, "card": inst})
	for area_id: StringName in state.data.area_order:
		_add_if_legal(state, out, {"type": "move", "seat": seat, "to": String(area_id)})
	var here: Dictionary = state.piles.get(st.area, {})
	for cid: Variant in here.keys():
		_add_if_legal(state, out, {"type": "loot", "seat": seat, "pile": String(cid)})
	for inst: Variant in state.drops.get(st.area, []):
		_add_if_legal(state, out, {"type": "loot", "seat": seat, "card": int(inst)})
	for crate: Dictionary in state.crates:
		if crate["area"] == st.area:
			for inst: Variant in crate["cards"]:
				_add_if_legal(state, out, {"type": "loot", "seat": seat, "card": int(inst)})
	var opp: int = state.opponent_of(seat)
	for inst: int in st.line:
		if state.def_of(inst).is_weapon():
			_add_if_legal(state, out, {"type": "shoot", "seat": seat, "weapon": inst, "target": opp})
	var mine: Array[int] = _concat([st.hand, st.line])
	for att: int in mine:
		if not state.def_of(att).is_attachment():
			continue
		for w: int in mine:
			if state.def_of(w).is_weapon():
				_add_if_legal(state, out, {"type": "attach", "seat": seat, "attachment": att, "weapon": w})
	_add_if_legal(state, out, {"type": "patch_up", "seat": seat})
	for inst: int in st.hand:
		_add_if_legal(state, out, {"type": "ditch", "seat": seat, "card": inst})
	if b.packing_rule == DataEnums.PackingRule.RACK_SWAP:
		out.append({"type": "end_turn", "seat": seat, "hold": []})
		var row: int = st.line.size() + st.hand.size()
		for from: int in row:
			for to: int in row:
				if from != to:
					out.append({"type": "end_turn", "seat": seat, "hold": [], "rack_move": {"from": from, "to": to}})
	else:
		var candidates: Array[int] = []
		for inst: int in _concat([st.hand, st.line]):
			if _can_hold(state, seat, inst):
				candidates.append(inst)
		for subset: Array in subsets(candidates, b.hold_limit):
			out.append({"type": "end_turn", "seat": seat, "hold": subset})
	return out


## The shot as the shooter would see it before declaring (P19): the same function shoot() uses.
## {legal, error, damage, cover, down, suppressed, may_brace}.
static func preview_shot(state: MatchState, seat: int, weapon: int, target: int) -> Dictionary:
	var a: Dictionary = {"type": "shoot", "seat": seat, "weapon": weapon, "target": target}
	var err: StringName = check(state, a)
	var p: Dictionary = shot_profile(state, seat, weapon, target)
	p["legal"] = err == &""
	p["error"] = err
	p["may_brace"] = p["damage"] > 0 and not p["suppressed"]
	return p


## Damage before Brace for a weapon shot (R22-R24, R27): {damage, cover, down, suppressed, dmg}.
## shoot() and preview_shot() both use it, so the preview always equals the shot.
static func shot_profile(state: MatchState, shooter: int, weapon: int, target: int) -> Dictionary:
	var b: BalanceConfig = state.data.balance
	var w: CardData = state.def_of(weapon)
	var dmg: int = w.dmg if w != null else 0
	var ignores: bool = w != null and w.ignores_cover
	var suppressed: bool = false
	for att: int in state.attachments_of(weapon):
		var ac: CardData = state.def_of(att)
		dmg += ac.attach_dmg
		suppressed = suppressed or ac.attach_no_brace
	var cover: int = cover_for(state, state.seats[shooter].area, target, ignores)
	var down: int = b.down_value if state.is_down(target) else 0
	return {"damage": maxi(0, dmg - cover - down), "cover": cover, "down": down,
			"suppressed": suppressed, "dmg": dmg}


## Damage before Brace for a blast (Frag) at one target (R32, R33).
static func blast_profile(state: MatchState, thrower: int, card: int, area_id: StringName, target: int) -> Dictionary:
	var b: BalanceConfig = state.data.balance
	var c: CardData = state.def_of(card)
	var cover: int = 0
	if not c.ignores_cover and state.seats[thrower].area != area_id:
		cover = cover_for(state, state.seats[thrower].area, target, false)
	var down: int = b.down_value if state.is_down(target) else 0
	return {"damage": maxi(0, c.blast_dmg - cover - down), "cover": cover, "down": down,
			"suppressed": false, "dmg": c.blast_dmg}


## False while the no_shooting_round1 switch keeps shots and Frags closed (round 1 only).
static func shooting_open(state: MatchState) -> bool:
	return not (state.data.balance.no_shooting_round1 and state.round_number <= 1)


## Shots per turn for a weapon (R12): printed fires + Extended Mags, checked at declare.
static func fire_limit(state: MatchState, weapon: int) -> int:
	var n: int = state.def_of(weapon).fires_per_turn
	for att: int in state.attachments_of(weapon):
		n += state.def_of(att).attach_extra_fire
	return n


## Weapon RNG with Long Scopes, capped at DataEnums.MAX_RANGE (R13).
static func weapon_range(state: MatchState, weapon: int) -> int:
	var r: int = state.def_of(weapon).rng
	for att: int in state.attachments_of(weapon):
		r += state.def_of(att).attach_rng
	return mini(r, DataEnums.MAX_RANGE)


## Test hook (RQ-11): the active seat's start-of-turn draw. When nothing has been logged yet the
## replay origin moves here (the hook is not an action).
static func auto_draw(state: MatchState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.is_over() or state.phase != MatchState.PHASE_PLAY:
		return events
	_start_turn(state, state.active, events)
	if state.actions.is_empty():
		state.mark_origin()
	return events


## What `seat` may see (spec §16.2). See MatchView.
static func view(state: MatchState, seat: int) -> Dictionary:
	return MatchView.build(state, seat)


## Replays a match from its origin and action list (U1). The result's fingerprint equals the
## original's when the engine is deterministic.
static func replay(origin: Dictionary, actions: Array, content: RulesData, errors: Array = []) -> MatchState:
	var s: MatchState = MatchState.new()
	s.data = content
	s.load_dict(origin)
	s.origin = origin
	for act: Variant in actions:
		var r: ActionResult = apply(s, act)
		if not r.ok:
			errors.append("replay rejected %s: %s" % [act, r.error])
			break
	return s


static func replay_of(state: MatchState, errors: Array = []) -> MatchState:
	return replay(state.origin, state.actions, state.data, errors)


## Events as `seat` may see them: an event's `secret` is merged in for its owner (`secret_for`)
## and dropped for everyone else.
static func events_for(events: Array, seat: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		var copy: Dictionary = e.duplicate(true)
		var secret: Dictionary = copy.get("secret", {})
		var owner: int = int(copy.get("secret_for", -1))
		copy.erase("secret")
		copy.erase("secret_for")
		if owner == seat:
			copy.merge(secret, true)
		out.append(copy)
	return out


# === Checks ==============================================================================

static func _check_drop(state: MatchState, a: Dictionary) -> StringName:
	if int(a["seat"]) != state.active:
		return ERR_NOT_YOUR_TURN
	var area_id: StringName = StringName(a.get("area", ""))
	if not state.data.is_outer(area_id):
		return ERR_DROP
	return &""


static func _check_play(state: MatchState, a: Dictionary) -> StringName:
	var st: SeatState = state.seats[a["seat"]]
	var inst: int = int(a.get("card", 0))
	if not st.hand.has(inst):
		return ERR_NOT_IN_HAND
	var c: CardData = state.def_of(inst)
	var b: BalanceConfig = state.data.balance
	if c.is_hit():
		var mode: String = String(a.get("adrenaline", ""))
		if mode != "move" and mode != "search":
			return ERR_ADRENALINE
		if mode == "search" and b.adrenaline_mode == DataEnums.AdrenalineMode.MOVE_ONLY:
			return ERR_ADRENALINE
		if b.adrenaline_cap_per_turn > 0 and st.adrenaline_played >= b.adrenaline_cap_per_turn:
			return ERR_ADRENALINE_CAP
		return &""
	if c.blast_dmg > 0:
		return ERR_FRAG_PLAY
	if c.type == DataEnums.CardType.MARKER:
		return ERR_BAD_CARD
	return &""


static func _check_move(state: MatchState, a: Dictionary) -> StringName:
	var st: SeatState = state.seats[a["seat"]]
	if st.move < 1:
		return ERR_NO_MOVE
	if not state.data.is_adjacent(st.area, StringName(a.get("to", ""))):
		return ERR_NOT_ADJACENT
	return &""


static func _check_loot(state: MatchState, a: Dictionary) -> StringName:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	if state.gas.has(st.area):
		return ERR_GAS
	var src: Dictionary = _loot_source(state, seat, a)
	if src.is_empty():
		return ERR_NO_SOURCE
	if st.search < int(src["cost"]):
		return ERR_NO_SEARCH
	if src["kind"] == "drop":
		var landed: int = int(state.drop_round.get(int(src["card"]), 0))
		if state.round_number < landed + state.data.balance.supply_drop_ready_delay:
			return ERR_NOT_READY
	return &""


static func _check_shoot(state: MatchState, a: Dictionary) -> StringName:
	if not shooting_open(state):
		return ERR_NO_SHOOTING_ROUND1
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var weapon: int = int(a.get("weapon", 0))
	if not st.line.has(weapon):
		return ERR_NOT_IN_LINE
	if not state.def_of(weapon).is_weapon():
		return ERR_BAD_CARD
	if int(st.fired.get(weapon, 0)) >= fire_limit(state, weapon):
		return ERR_NO_SHOTS
	var target: int = int(a.get("target", -1))
	if target != state.opponent_of(seat) or state.seats[target].eliminated:
		return ERR_BAD_TARGET
	if state.data.distance(st.area, state.seats[target].area) > weapon_range(state, weapon):
		return ERR_OUT_OF_RANGE
	return &""


static func _check_frag(state: MatchState, a: Dictionary) -> StringName:
	if not shooting_open(state):
		return ERR_NO_SHOOTING_ROUND1
	var st: SeatState = state.seats[a["seat"]]
	var inst: int = int(a.get("card", 0))
	if not st.hand.has(inst):
		return ERR_NOT_IN_HAND
	var c: CardData = state.def_of(inst)
	if c.blast_dmg <= 0:
		return ERR_BAD_CARD
	var area_id: StringName = StringName(a.get("area", ""))
	if not state.data.has_area(area_id):
		return ERR_OUT_OF_RANGE
	if state.data.distance(st.area, area_id) > maxi(c.blast_rng, 0):
		return ERR_OUT_OF_RANGE
	return &""


static func _check_attach(state: MatchState, a: Dictionary) -> StringName:
	var st: SeatState = state.seats[a["seat"]]
	var att: int = int(a.get("attachment", 0))
	var weapon: int = int(a.get("weapon", 0))
	if not (st.hand.has(att) or st.line.has(att)) or not (st.hand.has(weapon) or st.line.has(weapon)):
		return ERR_ATTACH
	if att == weapon or not state.def_of(att).is_attachment() or not state.def_of(weapon).is_weapon():
		return ERR_ATTACH
	var current: Array[int] = state.attachments_of(weapon)
	if current.size() >= 2:
		return ERR_ATTACH
	for other: int in current:
		if state.card_id(other) == state.card_id(att):
			return ERR_ATTACH
	return &""


static func _check_patch_up(state: MatchState, a: Dictionary) -> StringName:
	var st: SeatState = state.seats[a["seat"]]
	if st.search < PATCH_UP_COST:
		return ERR_NO_SEARCH
	if state.hits_in(st.line) + state.hits_in(st.hand) == 0:
		return ERR_NO_HIT
	return &""


static func _check_ditch(state: MatchState, a: Dictionary) -> StringName:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var inst: int = int(a.get("card", 0))
	var b: BalanceConfig = state.data.balance
	if not st.hand.has(inst):
		return ERR_NOT_IN_HAND
	var c: CardData = state.def_of(inst)
	if c.is_hit() or not c.is_starter() or not state.attachments_of(inst).is_empty():
		return ERR_DITCH
	if b.ditch_limit() >= 0 and st.ditched >= b.ditch_limit():
		return ERR_DITCH_LIMIT
	if st.search < DITCH_COST:
		return ERR_NO_SEARCH
	if state.nonhit_count(seat) - 1 < b.min_loadout:
		return ERR_MIN_LOADOUT
	return &""


static func _check_end_turn(state: MatchState, a: Dictionary) -> StringName:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var b: BalanceConfig = state.data.balance
	var hold: Array = a.get("hold", [])
	if b.packing_rule == DataEnums.PackingRule.RACK_SWAP:
		if not hold.is_empty():
			return ERR_HOLD
		if a.has("rack_move"):
			var row: int = st.line.size() + st.hand.size()
			var from: int = int(a["rack_move"]["from"])
			var to: int = int(a["rack_move"]["to"])
			if from < 0 or from >= row or to < 0 or to >= row:
				return ERR_RACK
		return &""
	if a.has("rack_move"):
		return ERR_RACK
	if hold.size() > b.hold_limit:
		return ERR_HOLD
	var seen: Array[int] = []
	for x: Variant in hold:
		var inst: int = int(x)
		if seen.has(inst) or not _can_hold(state, seat, inst):
			return ERR_HOLD
		seen.append(inst)
	return &""


static func _check_brace(state: MatchState, a: Dictionary) -> StringName:
	var defender: int = state.pending_brace_seat()
	if defender == MatchState.NO_SEAT:
		return ERR_NO_PENDING
	if int(a["seat"]) != defender:
		return ERR_NOT_YOUR_TURN
	var eligible: Array[int] = brace_candidates(state, defender)
	var seen: Array[int] = []
	for x: Variant in a.get("cards", []):
		var inst: int = int(x)
		if seen.has(inst) or not eligible.has(inst):
			return ERR_BRACE
		seen.append(inst)
	return &""


## R50: a non-Hit hand card, or (hold_looted) an unused card looted this turn still in the line.
static func _can_hold(state: MatchState, seat: int, inst: int) -> bool:
	var st: SeatState = state.seats[seat]
	if st.hand.has(inst):
		return not state.is_hit(inst)
	if st.line.has(inst) and state.data.balance.hold_looted:
		return st.looted.has(inst) and not st.fired.has(inst) and not st.touched.has(inst)
	return false


## R25, R26: cards in the defender's next hand with a Brace value that haven't braced this turn
## (the cards a `brace` action may use; MatchView's brace_prompt.eligible).
static func brace_candidates(state: MatchState, defender: int) -> Array[int]:
	var out: Array[int] = []
	var st: SeatState = state.seats[defender]
	for inst: int in state.next_hand(defender):
		if state.def_of(inst).brace > 0 and not st.braced.has(inst):
			out.append(inst)
	return out


## {kind: pile|drop|crate, card (inst), cost, crate (index)} for a loot action, or {}.
static func _loot_source(state: MatchState, seat: int, a: Dictionary) -> Dictionary:
	var st: SeatState = state.seats[seat]
	var b: BalanceConfig = state.data.balance
	if a.has("pile"):
		var cid: StringName = StringName(a["pile"])
		var stack: Array = (state.piles.get(st.area, {}) as Dictionary).get(cid, [])
		if stack.is_empty():
			return {}
		return {"kind": "pile", "card": int(stack.back()), "cost": state.data.card(cid).cost, "pile": cid}
	var inst: int = int(a.get("card", 0))
	if inst <= 0:
		return {}
	if (state.drops.get(st.area, []) as Array).has(inst):
		return {"kind": "drop", "card": inst, "cost": b.supply_drop_cost}
	for i: int in state.crates.size():
		var crate: Dictionary = state.crates[i]
		if crate["area"] == st.area and (crate["cards"] as Array).has(inst):
			var free: bool = int(crate["free_picks"]) > 0 and int(crate["picker"]) == seat
			return {"kind": "crate", "card": inst, "cost": 0 if free else b.crate_cost, "crate": i, "free": free}
	return {}


# === Effects =============================================================================

static func _do(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	match String(a["type"]):
		"drop":
			_do_drop(state, a, events)
		"play":
			_do_play(state, a, events)
		"move":
			var st: SeatState = state.seats[a["seat"]]
			var from: StringName = st.area
			st.move -= 1
			st.area = StringName(a["to"])
			events.append({"type": "moved", "seat": a["seat"], "from": from, "to": st.area})
		"loot":
			_do_loot(state, a, events)
		"shoot":
			_do_shoot(state, a, events)
		"frag":
			_do_frag(state, a, events)
		"attach":
			var st: SeatState = state.seats[a["seat"]]
			var att: int = int(a["attachment"])
			var weapon: int = int(a["weapon"])
			st.hand.erase(att)
			st.line.erase(att)
			var list: Array = state.attachments.get(weapon, [])
			list.append(att)
			state.attachments[weapon] = list
			for inst: int in [att, weapon]:
				if not st.touched.has(inst):
					st.touched.append(inst)
			events.append({"type": "attached", "seat": a["seat"], "attachment": att, "weapon": weapon,
					"attachment_id": state.card_id(att), "weapon_id": state.card_id(weapon)})
		"patch_up":
			var seat: int = a["seat"]
			state.seats[seat].search -= PATCH_UP_COST
			var healed: int = _heal(state, seat, 1)
			events.append({"type": "patched_up", "seat": seat, "healed": healed, "health": state.health_of(seat)})
		"ditch":
			var st: SeatState = state.seats[a["seat"]]
			var inst: int = int(a["card"])
			st.hand.erase(inst)
			st.search -= DITCH_COST
			st.ditched += 1
			state.removed.append(inst)
			events.append({"type": "ditched", "seat": a["seat"], "card": inst, "card_id": state.card_id(inst)})
		"end_turn":
			_do_end_turn(state, a, events)
		"brace":
			_do_brace(state, a, events)
		"concede":
			var seat: int = a["seat"]
			events.append({"type": "conceded", "seat": seat})
			state.pending = {}
			_end_match(state, {"result": "win", "winner": state.opponent_of(seat), "cause": "concede"}, events)


static func _do_drop(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	state.seats[seat].area = StringName(a["area"])
	events.append({"type": "dropped", "seat": seat, "area": state.seats[seat].area})
	if seat == MatchState.P2:
		state.active = MatchState.P1
		return
	state.phase = MatchState.PHASE_PLAY
	_round_start(state, events)
	if not state.is_over():
		state.active = MatchState.P1
		_start_turn(state, MatchState.P1, events)


static func _do_play(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var inst: int = int(a["card"])
	var c: CardData = state.def_of(inst)
	st.hand.erase(inst)
	if c.is_hit():
		st.line.append(inst)
		st.adrenaline_played += 1
		var mode: String = a["adrenaline"]
		if mode == "move":
			st.move += 1
		else:
			st.search += 1
		events.append({"type": "adrenaline", "seat": seat, "card": inst, "mode": mode})
		return
	var spent_now: bool = c.spent == DataEnums.SpentMode.ON_PLAY
	if not spent_now:
		st.line.append(inst)
	st.move += c.move
	st.search += c.search
	events.append({"type": "played", "seat": seat, "card": inst, "card_id": c.id, "move": c.move,
			"search": c.search})
	if c.heal > 0:
		var healed: int = _heal(state, seat, c.heal)
		events.append({"type": "healed", "seat": seat, "healed": healed, "health": state.health_of(seat)})
	if spent_now:
		state.removed.append(inst)
		events.append({"type": "spent", "seat": seat, "card": inst, "card_id": c.id})
	if c.pull > 0:
		var pulled: Array[int] = _take_from_top(state, seat, c.pull)
		st.hand.append_array(pulled)
		events.append({"type": "pulled", "seat": seat, "count": pulled.size(), "hits": state.hits_in(pulled),
				"secret_for": seat, "secret": {"cards": pulled}})


static func _do_loot(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var src: Dictionary = _loot_source(state, seat, a)
	var inst: int = int(src["card"])
	match String(src["kind"]):
		"pile":
			(state.piles[st.area][src["pile"]] as Array).pop_back()
		"drop":
			(state.drops[st.area] as Array).erase(inst)
		"crate":
			var crate: Dictionary = state.crates[int(src["crate"])]
			(crate["cards"] as Array).erase(inst)
			if src.get("free", false):
				crate["free_picks"] = int(crate["free_picks"]) - 1
			if (crate["cards"] as Array).is_empty():
				state.crates.remove_at(int(src["crate"]))
	st.search -= int(src["cost"])
	st.line.append(inst)
	st.looted.append(inst)
	events.append({"type": "looted", "seat": seat, "card": inst, "card_id": state.card_id(inst),
			"source": src["kind"], "area": st.area, "cost": src["cost"]})


static func _do_shoot(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var weapon: int = int(a["weapon"])
	var target: int = int(a["target"])
	st.fired[weapon] = int(st.fired.get(weapon, 0)) + 1
	var p: Dictionary = shot_profile(state, seat, weapon, target)
	var rec: Dictionary = _target_record(p)
	state.last_shot = {"kind": "shot", "shooter": seat, "weapon": weapon, "weapon_id": state.card_id(weapon),
			"weapon_card": MatchView.card_view(state, weapon),
			"target": target, "area": state.seats[target].area, "order": [target], "targets": {target: rec},
			"bounty_heal": 0, "resolved": false}
	events.append({"type": "shot_declared", "seat": seat, "weapon": weapon, "weapon_id": state.card_id(weapon),
			"target": target, "damage": p["damage"], "cover": p["cover"], "down": p["down"],
			"suppressed": p["suppressed"]})
	var queue: Array = []
	if int(p["damage"]) > 0 and not p["suppressed"]:
		queue.append(target)
	_start_resolution(state, "shot", seat, queue, events)


static func _do_frag(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var inst: int = int(a["card"])
	var area_id: StringName = StringName(a["area"])
	st.hand.erase(inst)
	state.removed.append(inst)  # RQ-03: straight out of the game, never in the line
	var order: Array = []
	var opp: int = state.opponent_of(seat)
	if state.seats[opp].area == area_id and not state.seats[opp].eliminated:
		order.append(opp)
	if st.area == area_id:
		order.append(seat)
	var targets: Dictionary = {}
	var queue: Array = []
	for t: Variant in order:
		var p: Dictionary = blast_profile(state, seat, inst, area_id, int(t))
		targets[int(t)] = _target_record(p)
		if int(p["damage"]) > 0:
			queue.append(int(t))
	state.last_shot = {"kind": "frag", "shooter": seat, "card": inst, "card_id": state.card_id(inst),
			"thrown_card": MatchView.card_view(state, inst),
			"area": area_id, "order": order, "targets": targets, "bounty_heal": 0, "resolved": false}
	var shown: Dictionary = {}
	for t: Variant in order:
		shown[t] = {"damage": targets[t]["damage_before_brace"], "down": targets[t]["down"]}
	events.append({"type": "frag_thrown", "seat": seat, "card": inst, "area": area_id, "targets": shown})
	events.append({"type": "spent", "seat": seat, "card": inst, "card_id": state.card_id(inst)})
	_start_resolution(state, "frag", seat, queue, events)


static func _target_record(p: Dictionary) -> Dictionary:
	return {"damage_before_brace": p["damage"], "cover": p["cover"], "down": p["down"],
			"suppressed": p["suppressed"], "braced": [], "braced_cards": [], "brace_total": 0, "hits": p["damage"],
			"hits_landed": 0, "eliminated": false}


## Waits for the first Brace in `queue`, or resolves at once when nobody braces.
static func _start_resolution(state: MatchState, kind: String, shooter: int, queue: Array,
		events: Array[Dictionary]) -> void:
	if queue.is_empty():
		_resolve(state, events)
		return
	state.pending = {"kind": kind, "shooter": shooter, "queue": queue, "index": 0}
	_request_brace(state, events)


static func _request_brace(state: MatchState, events: Array[Dictionary]) -> void:
	var defender: int = state.pending_brace_seat()
	var rec: Dictionary = state.last_shot["targets"][defender]
	events.append({"type": "brace_requested", "seat": defender, "damage": rec["damage_before_brace"]})


static func _do_brace(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var rec: Dictionary = state.last_shot["targets"][seat]
	var total: int = 0
	var cards: Array = a.get("cards", [])
	var card_ids: Array = []
	for x: Variant in cards:
		var inst: int = int(x)
		var c: CardData = state.def_of(inst)
		st.loadout.erase(inst)
		st.held.erase(inst)
		st.braced.append(inst)
		total += c.brace
		card_ids.append(c.id)
		if c.spent == DataEnums.SpentMode.ON_BRACE:
			state.removed.append(inst)
		else:
			st.loadout.append(inst)
	rec["braced"] = cards.duplicate()
	var shown: Array = []
	for x: Variant in cards:
		shown.append(MatchView.card_view(state, int(x)))
	rec["braced_cards"] = shown  # P11: revealed now; the view shows this snapshot, not the live card
	rec["brace_total"] = total
	rec["hits"] = maxi(0, int(rec["damage_before_brace"]) - total)
	events.append({"type": "braced", "seat": seat, "cards": cards.duplicate(), "card_ids": card_ids,
			"total": total, "hits": rec["hits"]})
	state.pending["index"] = int(state.pending["index"]) + 1
	if state.pending_brace_seat() != MatchState.NO_SEAT:
		_request_brace(state, events)
	else:
		_resolve(state, events)


## R29, R34, R37, R45-R47: every Hit lands (all targets together), then the Bounty claim, then
## eliminations.
static func _resolve(state: MatchState, events: Array[Dictionary]) -> void:
	var ls: Dictionary = state.last_shot
	var shooter: int = int(ls["shooter"])
	var out: Array[int] = []
	for t: Variant in ls["order"]:
		var target: int = int(t)
		var rec: Dictionary = ls["targets"][target]
		var landed: int = _take_hits(state, target, int(rec["hits"]))
		rec["hits_landed"] = landed
		if state.seats[target].eliminated:
			rec["eliminated"] = true
			out.append(target)
		if int(rec["hits"]) > 0 or landed > 0:
			events.append({"type": "hits_landed", "seat": target, "count": landed, "source": ls["kind"],
					"health": state.health_of(target), "down": state.is_down(target)})
	# Bounty claim (R35, R37; RQ-06: an eliminated shooter never claims).
	var b: BalanceConfig = state.data.balance
	if not out.has(shooter):
		for t: Variant in ls["order"]:
			var target: int = int(t)
			if target != shooter and target == state.bounty and int(ls["targets"][target]["hits_landed"]) >= 1:
				var healed: int = _heal(state, shooter, b.bounty_heal)
				ls["bounty_heal"] = int(ls["bounty_heal"]) + healed
				events.append({"type": "bounty_claimed", "seat": shooter, "from": target, "healed": healed,
						"health": state.health_of(shooter)})
	ls["resolved"] = true
	state.pending = {}
	if not out.is_empty():
		var killer: int = shooter if not out.has(shooter) else MatchState.NO_SEAT
		_eliminate(state, out, String(ls["kind"]), killer, events)


static func _do_end_turn(state: MatchState, a: Dictionary, events: Array[Dictionary]) -> void:
	var seat: int = a["seat"]
	var st: SeatState = state.seats[seat]
	var b: BalanceConfig = state.data.balance
	# R40 gas check: after Act, before Pack. No Brace, no Down, no Bounty claim.
	if state.gas.has(st.area):
		var landed: int = _take_hits(state, seat, 1)
		events.append({"type": "gas_hit", "seat": seat, "count": landed, "area": st.area,
				"health": state.health_of(seat)})
		if st.eliminated:
			_eliminate(state, [seat], "gas", MatchState.NO_SEAT, events)
			return
	var held_now: Array[int] = []
	var stowed_hand: Array[int] = []
	var line_stowed: Array[int] = []
	if b.packing_rule == DataEnums.PackingRule.RACK_SWAP:
		# R51: line then hand, one card moved within the row, under the loadout. No Hold.
		var row: Array[int] = _concat([st.line, st.hand])
		line_stowed = st.line.duplicate()
		stowed_hand = st.hand.duplicate()
		if a.has("rack_move"):
			var from: int = int(a["rack_move"]["from"])
			var to: int = int(a["rack_move"]["to"])
			var moved: int = row[from]
			row.remove_at(from)
			row.insert(to, moved)
		st.loadout.append_array(row)
		st.held.clear()
	else:
		# R50: held (hand order, then line order) · rest of loadout · line · unheld hand.
		var hold: Array = a.get("hold", [])
		for inst: int in st.hand:
			if hold.has(inst):
				held_now.append(inst)
		for inst: int in st.line:
			if hold.has(inst):
				held_now.append(inst)
		for inst: int in st.line:
			if not hold.has(inst):
				line_stowed.append(inst)
		for inst: int in st.hand:
			if not hold.has(inst):
				stowed_hand.append(inst)
		var new_loadout: Array[int] = _concat([held_now, st.loadout, line_stowed, stowed_hand])
		st.loadout = new_loadout
		st.held = held_now.duplicate()
	st.hand.clear()
	st.line.clear()
	events.append({"type": "packed", "seat": seat, "held_count": held_now.size(),
			"line_stowed": line_stowed, "hand_stowed_count": stowed_hand.size(),
			"secret_for": seat, "secret": {"held": held_now, "hand_stowed": stowed_hand}})
	st.reset_turn()
	if seat == MatchState.P1:
		state.active = MatchState.P2
		_start_turn(state, MatchState.P2, events)
		return
	# End of the round (P2's turn).
	if state.zone_card >= b.zone_hard_end_card:
		_hard_end(state, events)
		return
	_round_start(state, events)
	if not state.is_over():
		state.active = MatchState.P1
		_start_turn(state, MatchState.P1, events)


static func _do_undo(state: MatchState, events: Array[Dictionary]) -> void:
	var snap: Dictionary = state.undo_stack.pop_back()
	var removed_action: Dictionary = state.actions.back() if not state.actions.is_empty() else {}
	state.load_dict(snap["state"])
	state.actions.resize(int(snap["log_size"]))
	events.append({"type": "undone", "seat": state.active, "action": removed_action})


# === Turn and round flow =================================================================

## R1: the whole next draw into the hand (Hits free). Per-turn pools and Brace memory reset.
static func _start_turn(state: MatchState, seat: int, events: Array[Dictionary]) -> void:
	state.seats[MatchState.P1].reset_turn()
	state.seats[MatchState.P2].reset_turn()
	state.undo_stack.clear()
	var st: SeatState = state.seats[seat]
	var drawn: Array[int] = _take_from_top(state, seat, state.data.balance.hand_size)
	st.hand.append_array(drawn)
	events.append({"type": "turn_started", "seat": seat, "round": state.round_number})
	events.append({"type": "drew", "seat": seat, "count": drawn.size(), "hits": state.hits_in(drawn),
			"secret_for": seat, "secret": {"cards": drawn}})


## R39: Bounty, Zone card (gas, then drop, then final circle).
static func _round_start(state: MatchState, events: Array[Dictionary]) -> void:
	var b: BalanceConfig = state.data.balance
	state.round_number += 1
	events.append({"type": "round_started", "round": state.round_number})
	var h1: int = state.health_of(MatchState.P1)
	var h2: int = state.health_of(MatchState.P2)
	var holder: int = MatchState.P1 if h1 > h2 else (MatchState.P2 if h2 > h1 else MatchState.NO_SEAT)
	if holder != state.bounty:
		events.append({"type": "bounty_changed", "from": state.bounty, "to": holder})
	state.bounty = holder
	state.zone_card += 1
	var z: ZoneCardData = state.data.zone_card(state.zone_card)
	events.append({"type": "zone_flipped", "card": state.zone_card,
			"zone_id": z.id if z != null else &"", "route": MatchState.route_letter(state.route)})
	if z == null:
		return
	var closes: AreaData = z.close_for(state.route)
	if closes != null and not state.gas.has(closes.id):
		state.gas.append(closes.id)
		state.gas.sort()
		events.append({"type": "gas_closed", "area": closes.id})
	var lands: AreaData = z.drop_area_for(state.route)
	if z.drop_card != null and lands != null:
		var inst: int = state.new_card(z.drop_card.id, MatchState.NO_SEAT)
		var list: Array = state.drops.get(lands.id, [])
		list.append(inst)
		state.drops[lands.id] = list
		state.drop_round[inst] = state.round_number
		events.append({"type": "drop_landed", "card": inst, "card_id": z.drop_card.id, "area": lands.id})
	if z.final_circle_step > 0:
		var n: int = b.final_circle_hits_for(z.final_circle_step)
		var out: Array[int] = []
		var taken: Dictionary = {}
		for seat: int in [MatchState.P1, MatchState.P2]:
			var count: int = n + (b.bounty_final_circle_extra if state.bounty == seat else 0)
			taken[seat] = _take_hits(state, seat, count)
			if state.seats[seat].eliminated:
				out.append(seat)
		events.append({"type": "final_circle", "step": z.final_circle_step, "hits": n, "taken": taken,
				"health": [state.health_of(MatchState.P1), state.health_of(MatchState.P2)]})
		if not out.is_empty():
			_eliminate(state, out, "final_circle", MatchState.NO_SEAT, events)


## R44, R48: more health; then more non-Hit cards; then a draw.
static func _hard_end(state: MatchState, events: Array[Dictionary]) -> void:
	var h1: int = state.health_of(MatchState.P1)
	var h2: int = state.health_of(MatchState.P2)
	var winner: int = MatchState.NO_SEAT
	if h1 != h2:
		winner = MatchState.P1 if h1 > h2 else MatchState.P2
	else:
		winner = _more_cards(state)
	var result: Dictionary = {"result": "draw", "cause": "hard_end"}
	if winner != MatchState.NO_SEAT:
		result = {"result": "win", "winner": winner, "cause": "hard_end"}
	_end_match(state, result, events)


## R45-R47: decide the result (before any crate leaves), then form each crate (R46).
static func _eliminate(state: MatchState, out: Array, cause: String, killer: int, events: Array[Dictionary]) -> void:
	var b: BalanceConfig = state.data.balance
	var result: Dictionary
	if out.size() >= 2:
		var w: int = _more_cards(state)
		result = {"result": "draw", "cause": cause} if w == MatchState.NO_SEAT \
				else {"result": "win", "winner": w, "cause": cause}
	else:
		result = {"result": "win", "winner": state.opponent_of(int(out[0])), "cause": cause}
	var counts: Array[int] = [state.nonhit_count(MatchState.P1), state.nonhit_count(MatchState.P2)]
	for x: Variant in out:
		var seat: int = int(x)
		var st: SeatState = state.seats[seat]
		st.eliminated = true
		events.append({"type": "eliminated", "seat": seat, "cause": cause, "nonhit_count": counts[seat]})
		var crate_cards: Array[int] = []
		for list: Array[int] in [st.loadout, st.hand, st.line]:
			for inst: int in list.duplicate():
				var c: CardData = state.def_of(inst)
				if c.is_hit() or c.is_starter():
					continue
				list.erase(inst)
				crate_cards.append(inst)
		st.held.clear()
		var picks: int = b.crate_free_picks if (killer != MatchState.NO_SEAT and cause != "gas" and cause != "final_circle") else 0
		state.crates.append({"owner": seat, "area": st.area, "cards": crate_cards, "free_picks": picks,
				"picker": killer})
		events.append({"type": "crate_formed", "owner": seat, "area": st.area, "cards": crate_cards.duplicate(),
				"free_picks": picks})
	_end_match(state, result, events)


static func _end_match(state: MatchState, result: Dictionary, events: Array[Dictionary]) -> void:
	state.match_end = result
	state.phase = MatchState.PHASE_OVER
	state.pending = {}
	state.undo_stack.clear()
	var e: Dictionary = {"type": "match_ended"}
	e.merge(result)
	e["nonhit_count"] = [state.nonhit_count(MatchState.P1), state.nonhit_count(MatchState.P2)]
	events.append(e)


## The seat with more non-Hit cards (D1, D2: loadout + hand + line), or -1 when tied.
static func _more_cards(state: MatchState) -> int:
	var c1: int = state.nonhit_count(MatchState.P1)
	var c2: int = state.nonhit_count(MatchState.P2)
	if c1 == c2:
		return MatchState.NO_SEAT
	return MatchState.P1 if c1 > c2 else MatchState.P2


# === Helpers =============================================================================

## Moves `count` Hits from the health stack to the top of the loadout (R29). Returns how many
## landed; marks the seat eliminated when a Hit is due and the stack is empty (R45).
static func _take_hits(state: MatchState, seat: int, count: int) -> int:
	var st: SeatState = state.seats[seat]
	var landed: int = 0
	for i: int in count:
		if st.health.is_empty():
			st.eliminated = true
			break
		st.loadout.push_front(st.health.pop_back())
		landed += 1
	return landed


## R15: return up to n Hits from the line (last first), then the hand (last first). Health never
## exceeds the seat's starting health (the `health` tunable, + p2_start_health_bonus for P2).
## Returns how many were healed.
static func _heal(state: MatchState, seat: int, n: int) -> int:
	var st: SeatState = state.seats[seat]
	var healed: int = 0
	for i: int in n:
		if st.health.size() >= state.data.balance.start_health(seat):
			break
		var inst: int = _last_hit(state, st.line)
		var from: Array[int] = st.line
		if inst == 0:
			inst = _last_hit(state, st.hand)
			from = st.hand
		if inst == 0:
			break
		from.erase(inst)
		st.health.append(inst)
		healed += 1
	return healed


static func _last_hit(state: MatchState, list: Array[int]) -> int:
	for i: int in range(list.size() - 1, -1, -1):
		if state.is_hit(list[i]):
			return list[i]
	return 0


## D4 / R3: takes cards from the top until `count` non-Hit cards (Hits free) or the end;
## clears held marks on what it takes.
static func _take_from_top(state: MatchState, seat: int, count: int) -> Array[int]:
	var st: SeatState = state.seats[seat]
	var taken: Array[int] = state.draw_from(st.loadout, count)
	for inst: int in taken:
		st.loadout.pop_front()
		st.held.erase(inst)
	return taken


## R22: the Cover the target gets against a shot from `from_area` (0 in the same area, for a
## weapon that ignores Cover, and for the Bounty holder when bounty_holder_loses_cover).
static func cover_for(state: MatchState, from_area: StringName, target: int, ignores: bool) -> int:
	var b: BalanceConfig = state.data.balance
	var to_area: StringName = state.seats[target].area
	if ignores or from_area == to_area:
		return 0
	if b.bounty_holder_loses_cover and state.bounty == target:
		return 0
	return state.data.cover_of(to_area)


static func _first_frag(state: MatchState, seat: int) -> int:
	for inst: int in state.seats[seat].hand:
		var c: CardData = state.def_of(inst)
		if c != null and c.blast_dmg > 0:
			return inst
	return 0


static func _add_if_legal(state: MatchState, out: Array[Dictionary], a: Dictionary) -> void:
	if check(state, a) == &"":
		out.append(a)


## The lists joined into one typed list.
static func _concat(lists: Array) -> Array[int]:
	var out: Array[int] = []
	for list: Variant in lists:
		for x: Variant in list:
			out.append(int(x))
	return out


## Every subset of `items` with at most max_size elements, each in the items' order.
static func subsets(items: Array, max_size: int) -> Array:
	var result: Array = [[]]
	for item: Variant in items:
		var more: Array = []
		for s: Array in result:
			if s.size() < max_size:
				var bigger: Array = s.duplicate()
				bigger.append(item)
				more.append(bigger)
		result.append_array(more)
	return result
