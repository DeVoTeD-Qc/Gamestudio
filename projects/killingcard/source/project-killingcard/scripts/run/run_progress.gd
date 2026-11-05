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
#   kc-syn (synergy-system.md §5, approved): every deck copy has a level (deck_levels, parallel
#   to deck: 0 Recruit, 1 Trained, 2 Veteran, 3 Elite); the starter is Recruits
#   (RunConfig.starter_recruits), reward cards come Trained. Supply Drop slot 1 is on the deck's
#   main trait (supply_drop_on_trait). With RunConfig.synergy_offers: Doctrine after
#   doctrine_after_matches (pick a trait: its set count +1 in matches), Promotion after
#   promotion_after_matches (one copy goes up a level), Retire as the Supply Drop's 4th option
#   (retire_card) and Regroup (a free Retire) after a loss. Retiring a Recruit while a second
#   Recruit of that chassis is in the deck trains the twin ("two become one"). Retire never
#   takes the deck below RunConfig.deck_floor. Retired cards go to the Honor Roll (honor_roll).
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

## 2 = kc-syn (deck_levels, doctrine, honor roll, synergy offers). Version 1 saves still load
## (every copy Trained, as they were).
const SAVE_VERSION: int = 2
const OLDEST_SAVE_VERSION: int = 1

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
## kc-syn: level of each copy, parallel to `deck` (SynergyRules.LEVEL_*).
var deck_levels: Array[int] = []
## kc-syn Doctrine trait of this run (&"" until picked).
var doctrine: StringName = &""
## kc-syn: trait of the last card taken from a Supply Drop (main-trait tie-break).
var last_pick_trait: StringName = &""
## kc-syn Honor Roll: retired copies in order {id, level, match, trained_twin: bool}.
var honor_roll: Array[Dictionary] = []
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
	var levels: Array[int] = p_config.starter_levels()
	for i: int in p_config.starter_deck.size():
		var card: CardData = p_config.starter_deck[i]
		if card != null:
			r.deck.append(card.id)
			r.deck_levels.append(levels[i])
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
	for i: int in deck.size():
		s.deck.append(_index[deck[i]] as CardData)
		s.deck_levels.append(level_of(i))
	s.doctrine = doctrine
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


## Order after a match: Regroup (after a loss), Supply Drop (after a win), Doctrine, weapon level,
## Promotion, Perk offer.
func _queue_offers(n: int, won: bool) -> void:
	var syn: bool = config.synergy_offers
	if syn and not won and _last_result() == &"enemy" and can_retire():
		_add_synergy_offer(RewardOffers.KIND_REGROUP, n)
	if won:
		var main: StringName = main_trait() if config.supply_drop_on_trait else &""
		var cards: Array[StringName] = RewardOffers.supply_drop_on_trait(config, main, _rng("supply_drop", n))
		_add_offer(RewardOffers.KIND_SUPPLY_DROP, n, cards)
		if not pending_offers.is_empty() and pending_offers.back()["kind"] == RewardOffers.KIND_SUPPLY_DROP:
			var drop: Dictionary = pending_offers.back()
			if main != &"" and not cards.is_empty() and (_index.get(cards[0]) as CardData).card_trait == main:
				drop["on_trait"] = main
			if syn:
				drop["retire"] = true
	if syn and n in config.doctrine_after_matches and doctrine == &"":
		_add_offer(RewardOffers.KIND_DOCTRINE, n,
				RewardOffers.doctrine(_doctrine_best(), config.doctrine_choices, _rng("doctrine", n)))
	if n in config.weapon_level_after_matches:
		weapon_level += 1
		_add_offer(RewardOffers.KIND_ATTACHMENT, n,
				RewardOffers.attachments(config, _index.get(primary) as LoadoutItem, attachments, _rng("attachment", n)))
	if syn and n in config.promotion_after_matches:
		_add_synergy_offer(RewardOffers.KIND_PROMOTION, n)
	if n in config.perk_offer_after_matches:
		_add_offer(RewardOffers.KIND_PERK, n, RewardOffers.perks(config, perks, _rng("perk", n)))


func _add_offer(kind: StringName, n: int, options: Array[StringName]) -> void:
	if not options.is_empty():
		pending_offers.append({"kind": kind, "match": n, "options": options})


## Promotion / Regroup: the options depend on the deck, so they are (re)built when the offer
## becomes the current one (_refresh_current) as well.
func _add_synergy_offer(kind: StringName, n: int) -> void:
	var offer: Dictionary = {"kind": kind, "match": n, "options": [] as Array[StringName], "levels": [] as Array[int]}
	_fill_copy_options(offer)
	if not (offer["options"] as Array).is_empty():
		pending_offers.append(offer)


func _fill_copy_options(offer: Dictionary) -> void:
	var list: Array[Dictionary] = promotion_options() if offer["kind"] == RewardOffers.KIND_PROMOTION else retire_options()
	var ids: Array[StringName] = []
	var levels: Array[int] = []
	for o: Dictionary in list:
		ids.append(o["id"])
		levels.append(int(o["level"]))
	offer["options"] = ids
	offer["levels"] = levels


func _last_result() -> StringName:
	return StringName(history.back()["result"]) if not history.is_empty() else &""


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
			deck_levels.append(SynergyRules.LEVEL_TRAINED)  # reward cards come Trained
			var t: StringName = (_index.get(id) as CardData).card_trait
			if t != &"":
				last_pick_trait = t
		RewardOffers.KIND_ATTACHMENT:
			attachments.append(id)
		RewardOffers.KIND_PERK:
			perks.append(id)
		RewardOffers.KIND_DOCTRINE:
			doctrine = id
		RewardOffers.KIND_PROMOTION:
			var at: int = _find_copy(id, int(offer["levels"][index]))
			if at < 0:
				return "that copy is no longer in the deck"
			deck_levels[at] = mini(SynergyRules.LEVEL_MAX, level_of(at) + 1)
		RewardOffers.KIND_REGROUP:
			var err: String = _retire_copy(id, int(offer["levels"][index]))
			if err != "":
				return err
	_pop_offer()
	return ""


## kc-syn §5.4: Retire option `index` of retire_options() as this offer's choice: the 4th option
## of a Supply Drop (instead of a card) or the Regroup offer. Returns "" or the reason.
func retire_card(index: int) -> String:
	if phase != PHASE_REWARDS or pending_offers.is_empty():
		return "no offer to choose from"
	var offer: Dictionary = pending_offers[0]
	var kind: StringName = offer["kind"]
	if not (kind == RewardOffers.KIND_REGROUP or (kind == RewardOffers.KIND_SUPPLY_DROP and offer.get("retire", false))):
		return "this offer has no Retire option"
	var list: Array[Dictionary] = retire_options()
	if index < 0 or index >= list.size():
		return "no Retire option %d" % index
	var err: String = _retire_copy(list[index]["id"], int(list[index]["level"]))
	if err != "":
		return err
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
	_refresh_current()
	if pending_offers.is_empty():
		phase = PHASE_MATCH


## A Promotion / Regroup that became current lists the deck as it is now (an earlier offer may
## have changed it); one with nothing left to pick is dropped.
func _refresh_current() -> void:
	while not pending_offers.is_empty():
		var offer: Dictionary = pending_offers[0]
		if offer["kind"] not in [RewardOffers.KIND_PROMOTION, RewardOffers.KIND_REGROUP]:
			return
		_fill_copy_options(offer)
		if not (offer["options"] as Array).is_empty():
			return
		pending_offers.remove_at(0)


# =============================================================================
# kc-syn: copy levels, traits, Retire, Promotion (deck view for the UI)
# =============================================================================

## Level of deck copy i (Trained if unknown).
func level_of(i: int) -> int:
	return clampi(deck_levels[i], SynergyRules.LEVEL_RECRUIT, SynergyRules.LEVEL_MAX) \
			if i >= 0 and i < deck_levels.size() else SynergyRules.LEVEL_TRAINED


func _card(i: int) -> CardData:
	return _index.get(deck[i]) as CardData


## Trained copies per trait in the deck (units and Fields): {trait: n}.
func trait_counts(trained_only: bool = true) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null or c.card_trait == &"" or (trained_only and level_of(i) < SynergyRules.LEVEL_TRAINED):
			continue
		counts[c.card_trait] = int(counts.get(c.card_trait, 0)) + 1
	return counts


## The deck's main trait (§5.2): most Trained cards; ties -> the trait of the last pick (if tied),
## else TRAITS order; none -> the Doctrine trait; none -> &"".
func main_trait() -> StringName:
	var counts: Dictionary = trait_counts()
	var best: int = 0
	var tied: Array[StringName] = []
	for t: StringName in SynergyRules.TRAITS:
		var n: int = int(counts.get(t, 0))
		if n > best:
			best = n
			tied = [t]
		elif n == best and n > 0:
			tied.append(t)
	if tied.is_empty():
		return doctrine
	if last_pick_trait in tied:
		return last_pick_trait
	return tied[0]


## Doctrine's first emblem: the main trait, else the trait most of the deck's chassis carry.
func _doctrine_best() -> StringName:
	var main: StringName = main_trait()
	if main != &"":
		return main
	var counts: Dictionary = trait_counts(false)
	var best: StringName = &""
	for t: StringName in SynergyRules.TRAITS:
		if int(counts.get(t, 0)) > int(counts.get(best, 0)):
			best = t
	return best


## Engine panel (§5.2): {traits: {trait: Trained n}, keywords: {kw: Trained n}, recruits: n,
## main_trait, doctrine, next: [{trait, count, tier_next}]}.
func engine_summary() -> Dictionary:
	var kws: Dictionary = {}
	var recruits: int = 0
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null:
			continue
		if level_of(i) == SynergyRules.LEVEL_RECRUIT and (c.neighbor_keyword != &"" or c.card_trait != &""):
			recruits += 1
		var kw: StringName = SynergyRules.keyword_at(c, level_of(i))
		if kw != &"":
			kws[kw] = int(kws.get(kw, 0)) + 1
	return {"traits": trait_counts(), "keywords": kws, "recruits": recruits, "main_trait": main_trait(),
			"doctrine": doctrine, "deck_size": deck.size(), "floor": config.deck_floor}


## One row per deck copy: {index, id, level, level_name, band, keyword, trait}.
func deck_view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in deck.size():
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		out.append({"index": i, "id": deck[i], "level": lv, "level_name": SynergyRules.LEVEL_NAMES[lv],
				"band": SynergyRules.LEVEL_BANDS[lv], "keyword": SynergyRules.keyword_at(c, lv),
				"trait": SynergyRules.trait_at(c, lv)})
	return out


## True while a Retire would keep the deck at or above RunConfig.deck_floor.
func can_retire() -> bool:
	return deck.size() > config.deck_floor


## Retire choices (§5.4), one per design and level: Recruits first, then 1-cost cards, then the
## rest (deck order inside each group). Each: {index (first copy), id, level, cost, trait,
## twin_index (the Recruit twin that would be trained, -1 = none)}. Empty at the deck floor.
func retire_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_retire():
		return out
	var seen: Dictionary = {}
	var groups: Array = [[], [], []]
	for i: int in deck.size():
		var key: String = "%s@%d" % [deck[i], level_of(i)]
		if seen.has(key):
			continue
		seen[key] = true
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		var row: Dictionary = {"index": i, "id": deck[i], "level": lv, "cost": c.cost, "trait": c.card_trait,
				"twin_index": _twin_of(i)}
		groups[0 if lv == SynergyRules.LEVEL_RECRUIT else (1 if c.cost <= 1 else 2)].append(row)
	for g: Array in groups:
		out.append_array(g)
	return out


## Promotion choices (§5.2), one per design and level below Elite: units at any level, Fields only
## as Recruits (Veteran / Elite give stats, Fields have none); tactics never. Recruits first.
## Each: {index (first copy), id, level, next_level}.
func promotion_options() -> Array[Dictionary]:
	var seen: Dictionary = {}
	var groups: Array = [[], [], []]
	for i: int in deck.size():
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		if c == null or lv >= SynergyRules.LEVEL_MAX or c.card_type == DataEnums.CardType.TACTIC:
			continue
		if c.is_field() and (lv >= SynergyRules.LEVEL_TRAINED or c.card_trait == &""):
			continue
		var key: String = "%s@%d" % [deck[i], lv]
		if seen.has(key):
			continue
		seen[key] = true
		groups[mini(lv, 2)].append({"index": i, "id": deck[i], "level": lv, "next_level": lv + 1})
	var out: Array[Dictionary] = []
	for g: Array in groups:
		out.append_array(g)
	return out


## Another Recruit copy of the same chassis that retiring copy i would train ("two become one"),
## or -1. Only for chassis that have something to train (a neighbor keyword or a trait).
func _twin_of(i: int) -> int:
	var c: CardData = _card(i)
	if level_of(i) != SynergyRules.LEVEL_RECRUIT or c == null or (c.neighbor_keyword == &"" and c.card_trait == &""):
		return -1
	for j: int in deck.size():
		if j != i and deck[j] == deck[i] and level_of(j) == SynergyRules.LEVEL_RECRUIT:
			return j
	return -1


func _find_copy(id: StringName, level: int) -> int:
	for i: int in deck.size():
		if deck[i] == id and level_of(i) == level:
			return i
	return -1


func _retire_copy(id: StringName, level: int) -> String:
	if not can_retire():
		return "the deck can't go below %d cards" % config.deck_floor
	var at: int = _find_copy(id, level)
	if at < 0:
		return "that copy is no longer in the deck"
	var twin: int = _twin_of(at)
	if twin >= 0:
		deck_levels[twin] = SynergyRules.LEVEL_TRAINED
	honor_roll.append({"id": id, "level": level, "match": match_index, "trained_twin": twin >= 0})
	deck.remove_at(at)
	deck_levels.remove_at(at)
	return ""


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
		var od: Dictionary = {"kind": String(o["kind"]), "match": int(o["match"]), "options": _strings(o["options"])}
		if o.has("levels"):
			od["levels"] = (o["levels"] as Array).duplicate()
		if o.has("on_trait"):
			od["on_trait"] = String(o["on_trait"])
		if o.get("retire", false):
			od["retire"] = true
		offers.append(od)
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
		"deck_levels": deck_levels.duplicate(),
		"doctrine": String(doctrine),
		"last_pick_trait": String(last_pick_trait),
		"honor_roll": honor_roll.map(func(h: Dictionary) -> Dictionary:
			return {"id": String(h["id"]), "level": int(h["level"]), "match": int(h["match"]), "trained_twin": bool(h["trained_twin"])}),
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
	if int(v) < OLDEST_SAVE_VERSION or int(v) > SAVE_VERSION:
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
	# kc-syn (v2): per-copy levels; v1 decks were all Trained.
	var raw_levels: Variant = d.get("deck_levels", null)
	if raw_levels == null:
		for i: int in deck.size():
			deck_levels.append(SynergyRules.LEVEL_TRAINED)
	else:
		if typeof(raw_levels) != TYPE_ARRAY or (raw_levels as Array).size() != deck.size():
			return "deck_levels don't match the deck"
		for lv: Variant in raw_levels:
			if typeof(lv) not in [TYPE_INT, TYPE_FLOAT] or int(lv) < 0 or int(lv) > SynergyRules.LEVEL_MAX:
				return "bad deck level"
			deck_levels.append(int(lv))
	doctrine = StringName(str(d.get("doctrine", "")))
	if doctrine != &"" and doctrine not in SynergyRules.TRAITS:
		return "unknown doctrine '%s'" % doctrine
	last_pick_trait = StringName(str(d.get("last_pick_trait", "")))
	var roll: Variant = d.get("honor_roll", [])
	if typeof(roll) != TYPE_ARRAY:
		return "bad honor_roll"
	for entry: Variant in roll:
		if typeof(entry) != TYPE_DICTIONARY:
			return "bad honor_roll entry"
		honor_roll.append({"id": StringName(str(entry.get("id", ""))), "level": int(entry.get("level", 0)),
				"match": int(entry.get("match", 0)), "trained_twin": bool(entry.get("trained_twin", false))})
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
		var kind: StringName = StringName(str(o["kind"]))
		var opts: Array[StringName] = []
		if kind == RewardOffers.KIND_DOCTRINE:
			if typeof(o.get("options")) != TYPE_ARRAY:
				return "offer options is not a list"
			for t: Variant in o["options"]:
				if StringName(str(t)) not in SynergyRules.TRAITS:
					return "unknown trait '%s' in doctrine offer" % str(t)
				opts.append(StringName(str(t)))
		else:
			e = _read_ids(o.get("options"), opts, Resource, "offer options")
		if e != "" or opts.is_empty():
			return e if e != "" else "offer without options"
		var offer: Dictionary = {"kind": kind, "match": int(o.get("match", 0)), "options": opts}
		if kind in [RewardOffers.KIND_PROMOTION, RewardOffers.KIND_REGROUP]:
			var lv_raw: Variant = o.get("levels")
			if typeof(lv_raw) != TYPE_ARRAY or (lv_raw as Array).size() != opts.size():
				return "offer levels don't match its options"
			var lvs: Array[int] = []
			for lv: Variant in lv_raw:
				lvs.append(int(lv))
			offer["levels"] = lvs
		if o.has("on_trait"):
			offer["on_trait"] = StringName(str(o["on_trait"]))
		if bool(o.get("retire", false)):
			offer["retire"] = true
		pending_offers.append(offer)
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
