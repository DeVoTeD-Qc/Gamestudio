# cz_sim.gd
# Purpose: Fast, node-free simulation helpers for the CardZone AI (cz09). The AI searches on
#   copies of a belief world (CzBelief), never on the real match, so it does not need the action
#   log or the undo snapshots that LoadoutRules.apply() keeps for the UI. These helpers:
#     clone(state)        a deep copy of the state fields only (about 3x cheaper than
#                         MatchState.clone(), which round-trips through to_dict/load_dict and
#                         also copies the log and undo snapshots).
#     step(state, action) runs one action with the SAME checks and effects as apply()
#                         (LoadoutRules.normalize -> check -> _do), minus the undo snapshot and
#                         the log. Returns false (state untouched) when the action is illegal.
#   Plus small read-only card and map helpers shared by both AI levels.
# Dependencies: LoadoutRules, MatchState, SeatState, RulesData, CardData, DataEnums.
# Author: Mechanics Developer Agent
class_name CzSim
extends RefCounted

## Loot priorities, from the sim bots (tools/loadout_sim.py VALUE), keyed by card id.
const VALUE: Dictionary = {
	&"longshot_50": 12, &"assault_rifle": 10, &"twin_drum_lmg": 10, &"marksman_rifle": 9,
	&"phantom_suit": 9, &"heavy_plate": 8, &"pump_shotgun": 7, &"hunting_rifle": 7,
	&"extended_mag": 6, &"suppressor": 5, &"red_dot_sight": 6, &"recon_drone": 6,
	&"medkit": 5, &"plate_vest": 5, &"scrap_smg": 5, &"crowbar": 5, &"backpack": 4,
	&"long_scope": 3, &"smoke_grenade": 4, &"trail_boots": 3, &"bandage": 3,
}

static var _no_events: Array[Dictionary] = []


## Deep copy of every state field (not the log, undo snapshots or origin). Shares `data`.
## share_ids (search clones only): share `defs` and `owners` with `src` instead of copying them.
## The engine only ever adds to them (new_card, for the supply drop a round start lands), and
## every rollout of one search adds the same card under the same id, so sharing is safe there;
## owners is never read by the rules. Never use it for a state that outlives the search.
static func clone(src: MatchState, share_ids: bool = false) -> MatchState:
	var s: MatchState = MatchState.new()
	s.data = src.data
	s.phase = src.phase
	s.round_number = src.round_number
	s.zone_card = src.zone_card
	s.route = src.route
	s.active = src.active
	s.defs = src.defs if share_ids else src.defs.duplicate()
	s.owners = src.owners if share_ids else src.owners.duplicate()
	s.attachments = src.attachments.duplicate(true)
	s.next_id = src.next_id
	s.gas = src.gas.duplicate()
	s.drops = src.drops.duplicate(true)
	s.drop_round = src.drop_round.duplicate()
	s.piles = src.piles.duplicate(true)
	s.crates = src.crates.duplicate(true)
	s.bounty = src.bounty
	s.removed = src.removed.duplicate()
	s.pending = src.pending.duplicate(true)
	s.last_shot = src.last_shot.duplicate(true)
	s.match_end = src.match_end.duplicate(true)
	for i: int in 2:
		var a: SeatState = src.seats[i]
		var b: SeatState = s.seats[i]
		b.area = a.area
		b.health = a.health.duplicate()
		b.loadout = a.loadout.duplicate()
		b.held = a.held.duplicate()
		b.hand = a.hand.duplicate()
		b.line = a.line.duplicate()
		b.move = a.move
		b.search = a.search
		b.fired = a.fired.duplicate()
		b.looted = a.looted.duplicate()
		b.touched = a.touched.duplicate()
		b.adrenaline_played = a.adrenaline_played
		b.ditched = a.ditched
		b.braced = a.braced.duplicate()
		b.eliminated = a.eliminated
	return s


## Applies `action` with apply()'s checks and effects but no undo snapshot and no log entry.
static func step(state: MatchState, action: Dictionary) -> bool:
	return step_normalized(state, LoadoutRules.normalize(state, action))


## step() for an action that is already in normal form (ints for ids and seats, a String type,
## card lists as Arrays of ints, the Frag card given): the AI's own executor builds them so.
static func step_normalized(state: MatchState, a: Dictionary) -> bool:
	if LoadoutRules.check(state, a) != &"":
		return false
	_no_events.clear()
	LoadoutRules._do(state, a, _no_events)
	return true


# --- Cards ---------------------------------------------------------------------------

static func value_of(id: StringName) -> int:
	return int(VALUE.get(id, 0))


## Damage of one shot before Cover/Down/Brace (printed DMG + attachments).
static func weapon_dmg(state: MatchState, weapon: int) -> int:
	var c: CardData = state.def_of(weapon)
	if c == null:
		return 0
	var d: int = c.dmg
	for att: int in state.attachments_of(weapon):
		d += state.def_of(att).attach_dmg
	return d


## Damage per turn of a weapon if every shot lands (DMG x fires), the sim's weapon key.
static func weapon_power(state: MatchState, weapon: int) -> int:
	return weapon_dmg(state, weapon) * LoadoutRules.fire_limit(state, weapon)


static func is_item(state: MatchState, inst: int) -> bool:
	var c: CardData = state.data.cards.get(state.defs.get(inst, &""))
	return c != null and c.type == DataEnums.CardType.ITEM and c.blast_dmg <= 0


static func is_frag(state: MatchState, inst: int) -> bool:
	var c: CardData = state.data.cards.get(state.defs.get(inst, &""))
	return c != null and c.blast_dmg > 0


## Every card of a seat (loadout, hand, line), weapons counted once with their attachments.
static func all_cards(state: MatchState, seat: int) -> Array[int]:
	var st: SeatState = state.seats[seat]
	var out: Array[int] = []
	out.append_array(st.loadout)
	out.append_array(st.hand)
	out.append_array(st.line)
	return out


## The strongest weapon among `cards` by (power, range), or 0.
static func best_weapon(state: MatchState, cards: Array[int], skip_sidearm: bool = false) -> int:
	var best: int = 0
	var best_key: Vector2i = Vector2i(-1, -1)
	for inst: int in cards:
		var c: CardData = state.def_of(inst)
		if c == null or not c.is_weapon():
			continue
		if skip_sidearm and c.is_starter():
			continue
		var key: Vector2i = Vector2i(weapon_power(state, inst), LoadoutRules.weapon_range(state, inst))
		if key > best_key:
			best_key = key
			best = inst
	return best


## Hits in a seat's hand and line (what Patch up and Heal can return).
static func healable_hits(state: MatchState, seat: int) -> int:
	var st: SeatState = state.seats[seat]
	var hit_id: StringName = state.data.hit_id
	var n: int = 0
	for inst: int in st.hand:
		if state.defs.get(inst, &"") == hit_id:
			n += 1
	for inst: int in st.line:
		if state.defs.get(inst, &"") == hit_id:
			n += 1
	return n


# --- Map -------------------------------------------------------------------------------

## The area the next Zone card closes (or &"" when it closes none / there is none).
static func closing_next(state: MatchState) -> StringName:
	var z: ZoneCardData = state.data.zone_card(state.zone_card + 1)
	if z == null:
		return &""
	var a: AreaData = z.close_for(state.route)
	return a.id if a != null else &""


## Areas in the sim's order: the Core first, then the outer ring 1..6 (tools/loadout_sim.py AREAS).
static func sim_area_order(data: RulesData) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in data.area_order:
		if not data.is_outer(id):
			out.append(id)
	for id: StringName in data.area_order:
		if data.is_outer(id):
			out.append(id)
	return out


## The next step from `from` toward `to`: the first adjacent area (area_order) one step closer.
static func step_toward(data: RulesData, from: StringName, to: StringName) -> StringName:
	if from == to:
		return from
	var d: int = data.distance(from, to)
	for id: StringName in data.area_order:
		if data.is_adjacent(from, id) and data.distance(id, to) == d - 1:
			return id
	return from


## Search needed to loot a source in `area` and its card id: [{key: {pile|card}, id, cost}].
## Respects gas (nothing to loot) and the supply-drop ready delay.
static func loot_options(state: MatchState, seat: int, area: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.gas.has(area):
		return out
	var b: BalanceConfig = state.data.balance
	var here: Dictionary = state.piles.get(area, {})
	for cid: Variant in here.keys():
		if not (here[cid] as Array).is_empty():
			out.append({"pile": String(cid), "id": StringName(cid), "cost": state.data.card(StringName(cid)).cost})
	for inst: Variant in state.drops.get(area, []):
		var landed: int = int(state.drop_round.get(int(inst), 0))
		if state.round_number >= landed + b.supply_drop_ready_delay:
			out.append({"card": int(inst), "id": state.card_id(int(inst)), "cost": b.supply_drop_cost})
	for crate: Dictionary in state.crates:
		if crate["area"] == area:
			var free: bool = int(crate["free_picks"]) > 0 and int(crate["picker"]) == seat
			for inst: Variant in crate["cards"]:
				out.append({"card": int(inst), "id": state.card_id(int(inst)), "cost": 0 if free else b.crate_cost})
	return out


## A loot action for an option from loot_options().
static func loot_action(seat: int, opt: Dictionary) -> Dictionary:
	if opt.has("pile"):
		return {"type": "loot", "seat": seat, "pile": opt["pile"]}
	return {"type": "loot", "seat": seat, "card": opt["card"]}
