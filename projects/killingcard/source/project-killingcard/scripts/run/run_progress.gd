# run_progress.gd
# Purpose: The run layer's rules and state (p10): one "Deployment" of
#   RunConfig.matches (prototype: Bracket 1 x2, Bracket 2 x2, Rival) with
#   RunConfig.tickets Reinforcement Tickets. Node-free and deterministic: every
#   random choice (match seeds, offers) is derived from the run seed, so the same
#   seed and the same choices replay the same run. RunState (autoload) owns one of
#   these, saves it and emits EventBus signals; screens (p11) read it through RunState.
#
#   Flow (phase):
#     loadout  -> pick killstreaks (set_killstreaks), then begin()
#     match    -> build the match (create_match / player_setup / enemy_setup), play it,
#                 then record_match(m) or record_result(result)
#     rewards  -> pending offers in order: Supply Drop (after a win), weapon level
#                 (after weapon_level_after_matches), Perk offer (after
#                 perk_offer_after_matches); choose_offer(i) or skip_offer() each
#     ended    -> result &"victory" (Rival won) or &"defeat" (out of tickets, or the
#                 Rival lost / drawn), see end_reason
#   Results: a loss costs 1 ticket, a draw costs none and gives no Supply Drop
#   (Ruling 12). After any result the run goes on to the next match (no replays);
#   it ends at 0 tickets or after the Rival (the last match), with no offers then.
#
#   The save format is to_dict() / from_dict(): plain JSON-safe values, ids only,
#   versioned by SAVE_VERSION. Resources are resolved through the RunConfig's
#   own pools (starter kit, reward / perk / killstreak pools, the Primary's attachments).
# Dependencies: RunConfig, RunMatchData, CardData, LoadoutItem, SideSetup, MatchHooks,
#   ModeRules, MatchState, RewardOffers.
# Author: Mechanics Developer Agent
class_name RunProgress
extends RefCounted

const SAVE_VERSION: int = 1

const PHASE_LOADOUT: StringName = &"loadout"
const PHASE_MATCH: StringName = &"match"
const PHASE_REWARDS: StringName = &"rewards"
const PHASE_ENDED: StringName = &"ended"
const PHASES: Array[StringName] = [PHASE_LOADOUT, PHASE_MATCH, PHASE_REWARDS, PHASE_ENDED]

const RESULT_VICTORY: StringName = &"victory"
const RESULT_DEFEAT: StringName = &"defeat"

const END_RIVAL_WON: StringName = &"rival_won"
const END_RIVAL_LOST: StringName = &"rival_lost"
const END_RIVAL_DRAW: StringName = &"rival_draw"
const END_NO_TICKETS: StringName = &"no_tickets"

## Match results as MatchState / ModeRules report them.
const MATCH_RESULTS: Array[StringName] = [&"player", &"enemy", &"draw"]

var config: RunConfig = null
var seed_value: int = 0
var phase: StringName = PHASE_LOADOUT
## 0-based index into config.matches of the match to play next (or being played).
var match_index: int = 0
var tickets: int = 3
## Times the weapon levelled up so far (an offer that was skipped still counts).
var weapon_level: int = 0
## Card ids in deck order (copies repeat).
var deck: Array[StringName] = []
var primary: StringName = &""
var secondary: StringName = &""
var lethal: StringName = &""
var tactical: StringName = &""
var attachments: Array[StringName] = []
var perks: Array[StringName] = []
var killstreaks: Array[StringName] = []
## One entry per played match: {match, bracket, rival, mode, result, reason, rounds,
## player_score, enemy_score, ticket_lost}.
var history: Array[Dictionary] = []
## Offers still to resolve, first = current: {kind, match, options}.
var pending_offers: Array[Dictionary] = []
## &"" while the run goes on; RESULT_VICTORY / RESULT_DEFEAT once ended.
var result: StringName = &""
var end_reason: StringName = &""
## Seconds of play, summed across sessions (RunState adds to it).
var play_time_s: float = 0.0

## id -> Resource for everything a run can own (built from the config).
var _index: Dictionary = {}


# =============================================================================
# Creation
# =============================================================================

## A new run from the config's starter kit, in the loadout phase.
static func create(p_config: RunConfig, p_seed: int) -> RunProgress:
	var r: RunProgress = RunProgress.new()
	r._bind(p_config)
	r.seed_value = p_seed
	r.tickets = p_config.tickets
	for card: CardData in p_config.starter_deck:
		if card != null:
			r.deck.append(card.id)
	r.primary = _id_of(p_config.starter_primary)
	r.secondary = _id_of(p_config.starter_secondary)
	r.lethal = _id_of(p_config.starter_lethal)
	r.tactical = _id_of(p_config.starter_tactical)
	for ks: LoadoutItem in p_config.starter_killstreaks:
		if ks != null:
			r.killstreaks.append(ks.id)
	return r


## Seed for one purpose of this run (match seeds, offer rolls), stable across saves.
static func derive_seed(run_seed: int, tag: String, n: int) -> int:
	return ("%d|%s|%d" % [run_seed, tag, n]).hash()


# =============================================================================
# Loadout phase
# =============================================================================

## Replace the killstreak picks (exactly killstreak_slots different ones from
## killstreak_pool). Only before the first match. Returns "" or the reason.
func set_killstreaks(ids: Array) -> String:
	if phase != PHASE_LOADOUT:
		return "killstreaks are picked before the first match"
	if ids.size() != config.killstreak_slots:
		return "pick exactly %d killstreaks" % config.killstreak_slots
	var picks: Array[StringName] = []
	for raw: Variant in ids:
		var id: StringName = StringName(str(raw))
		if id in picks:
			return "'%s' is picked twice" % id
		var item: LoadoutItem = _index.get(id) as LoadoutItem
		if item == null or item not in config.killstreak_pool:
			return "'%s' is not in the killstreak pool" % id
		picks.append(id)
	killstreaks = picks
	return ""


## Ends the loadout phase; the first match is next.
func begin() -> String:
	if phase != PHASE_LOADOUT:
		return "the run has already begun"
	phase = PHASE_MATCH
	return ""


# =============================================================================
# Match phase: building the match
# =============================================================================

func match_count() -> int:
	return config.matches.size()


## 1-based number of the current match.
func match_number() -> int:
	return match_index + 1


## The current match slot (null once past the last match).
func current_match() -> RunMatchData:
	if match_index < 0 or match_index >= config.matches.size():
		return null
	return config.matches[match_index]


func is_rival_match() -> bool:
	var md: RunMatchData = current_match()
	return md != null and (md.is_rival or match_index == config.matches.size() - 1)


## Seed of the current match: replaying (e.g. after a reload mid-match) deals the same cards.
func match_seed() -> int:
	return derive_seed(seed_value, "match", match_number())


## The player's side for the current match: deck, Primary + attachments, Secondary /
## Lethal / Tactical, owned Perks and the picked killstreaks.
func player_setup() -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Player"
	for id: StringName in deck:
		s.deck.append(_index[id] as CardData)
	s.primary = _index.get(primary) as LoadoutItem
	s.secondary = _index.get(secondary) as LoadoutItem
	s.lethal = _index.get(lethal) as LoadoutItem
	s.tactical = _index.get(tactical) as LoadoutItem
	for id: StringName in attachments:
		s.attachments.append(_index[id] as LoadoutItem)
	for id: StringName in perks:
		s.perks.append(_index[id] as LoadoutItem)
	for id: StringName in killstreaks:
		s.killstreaks.append(_index[id] as LoadoutItem)
	return s


## The enemy side: the slot's squad with its bracket scaling (Bracket 2 and the
## Rival: +1 Armor to every unit and the Operator, Ruling 11; from RunMatchData).
func enemy_setup() -> SideSetup:
	var md: RunMatchData = current_match()
	return SideSetup.from_squad(md.squad, md)


## A MatchState for the current match, not started yet (call start_match()). Pass
## the hooks to use (a p05 subclass, say); its mode_rules are set from the slot's mode.
func create_match(hooks: MatchHooks = null) -> MatchState:
	var md: RunMatchData = current_match()
	if phase != PHASE_MATCH or md == null:
		push_warning("RunProgress: no match to play (phase %s)" % phase)
		return null
	var h: MatchHooks = hooks if hooks != null else MatchHooks.new()
	h.mode_rules = ModeRules.create(md.mode, config)
	return MatchState.new(config, md.map, player_setup(), enemy_setup(), match_seed(), h)


# =============================================================================
# Match phase: recording the result
# =============================================================================

## Records a finished MatchState (m.result plus the ModeRules outcome).
func record_match(m: MatchState) -> Dictionary:
	var outcome: Dictionary = {}
	if m.hooks != null and m.hooks.mode_rules != null:
		outcome = m.hooks.mode_rules.outcome
	return record_result(m.result, outcome)


## Records the current match's result (&"player", &"enemy" or &"draw") and moves on:
## tickets, run end, then the offers. `outcome` = the ModeRules outcome (optional;
## kept in the history). Returns {ok, reason, ticket_lost, run_ended, offers}.
func record_result(match_result: StringName, outcome: Dictionary = {}) -> Dictionary:
	if phase != PHASE_MATCH:
		return {"ok": false, "reason": "no match in progress"}
	if match_result not in MATCH_RESULTS:
		return {"ok": false, "reason": "unknown match result '%s'" % match_result}
	var md: RunMatchData = current_match()
	var n: int = match_number()
	var rival: bool = is_rival_match()
	var lost: bool = match_result == &"enemy"
	if lost:
		tickets = maxi(0, tickets - 1)
	history.append({
		"match": n,
		"bracket": md.bracket,
		"rival": rival,
		"mode": String(DataEnums.key_of(DataEnums.GameMode, md.mode)).to_lower(),
		"result": String(match_result),
		"reason": String(outcome.get("reason", &"")),
		"rounds": int(outcome.get("rounds", 0)),
		"player_score": int(outcome.get("player_score", 0)),
		"enemy_score": int(outcome.get("enemy_score", 0)),
		"ticket_lost": lost,
	})
	match_index += 1
	pending_offers.clear()
	if tickets <= 0:
		_end(RESULT_DEFEAT, END_NO_TICKETS)
	elif rival or match_index >= config.matches.size():
		match match_result:
			&"player":
				_end(RESULT_VICTORY, END_RIVAL_WON)
			&"enemy":
				_end(RESULT_DEFEAT, END_RIVAL_LOST)
			_:
				_end(RESULT_DEFEAT, END_RIVAL_DRAW)
	else:
		_queue_offers(n, match_result == &"player")
		phase = PHASE_REWARDS if not pending_offers.is_empty() else PHASE_MATCH
	return {
		"ok": true, "reason": "", "ticket_lost": lost, "run_ended": is_over(),
		"offers": pending_offers.duplicate(true),
	}


func _queue_offers(n: int, won: bool) -> void:
	if won:
		_add_offer(RewardOffers.KIND_SUPPLY_DROP, n,
				RewardOffers.supply_drop(config, _rng("supply_drop", n)))
	if n in config.weapon_level_after_matches:
		weapon_level += 1
		_add_offer(RewardOffers.KIND_ATTACHMENT, n,
				RewardOffers.attachments(config, _index.get(primary) as LoadoutItem, attachments, _rng("attachment", n)))
	if n in config.perk_offer_after_matches:
		_add_offer(RewardOffers.KIND_PERK, n, RewardOffers.perks(config, perks, _rng("perk", n)))


func _add_offer(kind: StringName, n: int, options: Array[StringName]) -> void:
	if not options.is_empty():
		pending_offers.append({"kind": kind, "match": n, "options": options})


# =============================================================================
# Rewards phase
# =============================================================================

## The offer to show now ({} if none).
func current_offer() -> Dictionary:
	return pending_offers[0] if not pending_offers.is_empty() else {}


## Takes option `index` of the current offer. Returns "" or the reason.
func choose_offer(index: int) -> String:
	if phase != PHASE_REWARDS or pending_offers.is_empty():
		return "no offer to choose from"
	var offer: Dictionary = pending_offers[0]
	var options: Array = offer["options"]
	if index < 0 or index >= options.size():
		return "no option %d" % index
	var id: StringName = options[index]
	match offer["kind"]:
		RewardOffers.KIND_SUPPLY_DROP:
			deck.append(id)
		RewardOffers.KIND_ATTACHMENT:
			attachments.append(id)
		RewardOffers.KIND_PERK:
			perks.append(id)
	_pop_offer()
	return ""


## Declines the current offer (nothing is added). Returns "" or the reason.
func skip_offer() -> String:
	if phase != PHASE_REWARDS or pending_offers.is_empty():
		return "no offer to skip"
	_pop_offer()
	return ""


func _pop_offer() -> void:
	pending_offers.remove_at(0)
	if pending_offers.is_empty():
		phase = PHASE_MATCH


# =============================================================================
# Queries
# =============================================================================

func is_over() -> bool:
	return phase == PHASE_ENDED


func is_victory() -> bool:
	return result == RESULT_VICTORY


func matches_played() -> int:
	return history.size()


func count_results(match_result: StringName) -> int:
	var n: int = 0
	for h: Dictionary in history:
		if StringName(h["result"]) == match_result:
			n += 1
	return n


## The resource behind an id this run can own (card, loadout item), or null.
func resource(id: StringName) -> Resource:
	return _index.get(id)


# =============================================================================
# Save format
# =============================================================================

func to_dict() -> Dictionary:
	var offers: Array = []
	for o: Dictionary in pending_offers:
		offers.append({"kind": String(o["kind"]), "match": int(o["match"]), "options": _strings(o["options"])})
	return {
		"version": SAVE_VERSION,
		"config_id": String(config.id),
		# A string, so 64-bit seeds survive JSON's doubles.
		"seed": str(seed_value),
		"phase": String(phase),
		"match_index": match_index,
		"tickets": tickets,
		"weapon_level": weapon_level,
		"deck": _strings(deck),
		"loadout": {
			"primary": String(primary), "secondary": String(secondary),
			"lethal": String(lethal), "tactical": String(tactical),
			"attachments": _strings(attachments), "perks": _strings(perks),
			"killstreaks": _strings(killstreaks),
		},
		"history": history.duplicate(true),
		"pending_offers": offers,
		"result": String(result),
		"end_reason": String(end_reason),
		"play_time_s": play_time_s,
	}


## Rebuilds a run from to_dict() data (e.g. parsed JSON). Returns {run, error}:
## run = null and error = why, if the data is not a valid save for this config.
static func from_dict(p_config: RunConfig, d: Variant) -> Dictionary:
	var r: RunProgress = RunProgress.new()
	var err: String = r._load(p_config, d)
	return {"run": null if err != "" else r, "error": err}


func _load(p_config: RunConfig, d: Variant) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "save is not an object"
	var v: Variant = d.get("version")
	if typeof(v) not in [TYPE_INT, TYPE_FLOAT]:
		return "save has no version"
	if int(v) != SAVE_VERSION:
		return "save version %s is not supported (expected %d)" % [str(v), SAVE_VERSION]
	if p_config == null:
		return "no run config"
	if str(d.get("config_id", "")) != String(p_config.id):
		return "save is for run config '%s', not '%s'" % [str(d.get("config_id", "")), p_config.id]
	_bind(p_config)
	var seed_text: String = str(d.get("seed", ""))
	if not seed_text.is_valid_int():
		return "bad seed"
	seed_value = seed_text.to_int()
	phase = StringName(str(d.get("phase", "")))
	if phase not in PHASES:
		return "bad phase '%s'" % phase
	for key: String in ["match_index", "tickets", "weapon_level"]:
		if typeof(d.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return "bad %s" % key
	match_index = int(d["match_index"])
	tickets = int(d["tickets"])
	weapon_level = int(d["weapon_level"])
	if match_index < 0 or match_index > config.matches.size():
		return "match_index %d out of range" % match_index
	if tickets < 0 or tickets > config.tickets:
		return "tickets %d out of range" % tickets
	if phase in [PHASE_MATCH, PHASE_REWARDS] and (match_index >= config.matches.size() or tickets == 0):
		return "phase %s but the run is over" % phase
	var e: String = _read_ids(d.get("deck"), deck, CardData, "deck")
	if e != "":
		return e
	if deck.is_empty():
		return "empty deck"
	var lo: Variant = d.get("loadout")
	if typeof(lo) != TYPE_DICTIONARY:
		return "no loadout"
	for slot: String in ["primary", "secondary", "lethal", "tactical"]:
		var id: StringName = StringName(str(lo.get(slot, "")))
		if not (_index.get(id) is LoadoutItem):
			return "unknown %s '%s'" % [slot, id]
		set(slot, id)
	for field: String in ["attachments", "perks", "killstreaks"]:
		var list: Array[StringName] = get(field)
		e = _read_ids(lo.get(field), list, LoadoutItem, "loadout." + field)
		if e != "":
			return e
	var h: Variant = d.get("history")
	if typeof(h) != TYPE_ARRAY:
		return "no history"
	for entry: Variant in h:
		if typeof(entry) != TYPE_DICTIONARY or str(entry.get("result", "")) not in ["player", "enemy", "draw"]:
			return "bad history entry"
		history.append(_normalise_history(entry))
	var offers: Variant = d.get("pending_offers")
	if typeof(offers) != TYPE_ARRAY:
		return "no pending_offers"
	for o: Variant in offers:
		if typeof(o) != TYPE_DICTIONARY or StringName(str(o.get("kind", ""))) not in RewardOffers.KINDS:
			return "bad offer"
		var opts: Array[StringName] = []
		e = _read_ids(o.get("options"), opts, Resource, "offer options")
		if e != "" or opts.is_empty():
			return e if e != "" else "offer without options"
		pending_offers.append({"kind": StringName(str(o["kind"])), "match": int(o.get("match", 0)), "options": opts})
	if (phase == PHASE_REWARDS) != (not pending_offers.is_empty()):
		return "pending offers don't match phase %s" % phase
	result = StringName(str(d.get("result", "")))
	end_reason = StringName(str(d.get("end_reason", "")))
	if (phase == PHASE_ENDED) != (result in [RESULT_VICTORY, RESULT_DEFEAT]):
		return "result '%s' doesn't match phase %s" % [result, phase]
	play_time_s = float(d.get("play_time_s", 0.0))
	return ""


func _read_ids(raw: Variant, into: Array[StringName], type: Variant, what: String) -> String:
	if typeof(raw) != TYPE_ARRAY:
		return "%s is not a list" % what
	for item: Variant in raw:
		var id: StringName = StringName(str(item))
		var res: Resource = _index.get(id)
		if res == null or not is_instance_of(res, type):
			return "unknown id '%s' in %s" % [id, what]
		into.append(id)
	return ""


static func _normalise_history(entry: Dictionary) -> Dictionary:
	return {
		"match": int(entry.get("match", 0)),
		"bracket": int(entry.get("bracket", 0)),
		"rival": bool(entry.get("rival", false)),
		"mode": str(entry.get("mode", "")),
		"result": str(entry.get("result", "")),
		"reason": str(entry.get("reason", "")),
		"rounds": int(entry.get("rounds", 0)),
		"player_score": int(entry.get("player_score", 0)),
		"enemy_score": int(entry.get("enemy_score", 0)),
		"ticket_lost": bool(entry.get("ticket_lost", false)),
	}


# =============================================================================
# Internals
# =============================================================================

func _bind(p_config: RunConfig) -> void:
	config = p_config
	_index = build_index(p_config)


## id -> Resource of every card and loadout item a run with this config can own.
static func build_index(cfg: RunConfig) -> Dictionary:
	var idx: Dictionary = {}
	var add: Callable = func(res: Resource) -> void:
		if res != null and not idx.has(res.get("id")):
			idx[res.get("id")] = res
	for c: CardData in cfg.starter_deck:
		add.call(c)
	for c: CardData in cfg.reward_pool:
		add.call(c)
	for item: LoadoutItem in [cfg.starter_primary, cfg.starter_secondary, cfg.starter_lethal, cfg.starter_tactical]:
		add.call(item)
	if cfg.starter_primary != null:
		for att: LoadoutItem in cfg.starter_primary.attachments:
			add.call(att)
	for list: Array in [cfg.starter_killstreaks, cfg.killstreak_pool, cfg.perk_pool]:
		for item: LoadoutItem in list:
			add.call(item)
	return idx


func _end(p_result: StringName, reason: StringName) -> void:
	result = p_result
	end_reason = reason
	phase = PHASE_ENDED
	pending_offers.clear()


func _rng(tag: String, n: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = derive_seed(seed_value, tag, n)
	return rng


static func _id_of(res: Resource) -> StringName:
	return res.get("id") if res != null else &""


static func _strings(ids: Array) -> Array:
	var out: Array = []
	for id: Variant in ids:
		out.append(String(id))
	return out
