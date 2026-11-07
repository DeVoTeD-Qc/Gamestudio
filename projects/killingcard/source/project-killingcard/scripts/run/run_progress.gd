# run_progress.gd
# Purpose: The run layer's rules and state (p10): one "Deployment" of
#   RunConfig.matches (prototype: Bracket 1 x2, Bracket 2 x2, Rival) with
#   RunConfig.tickets Reinforcement Tickets. Node-free and deterministic: every
#   random choice (match seeds, offers) is derived from the run seed, so the same
#   seed and the same choices replay the same run. RunState (autoload) owns one of
#   these, saves it and emits EventBus signals; screens (p11) read it through RunState.
#
#   Flow (phase):
#     loadout  -> pick killstreaks (set_killstreaks), kc-ui4: optionally the starting Operator
#                 (set_primary, one of operator_options), then begin()
#     match    -> build the match (create_match / player_setup / enemy_setup), play it,
#                 then record_match(m) or record_result(result)
#     rewards  -> pending offers in order: Supply Drop (after a win), weapon level
#                 (after weapon_level_after_matches), Perk offer (after
#                 perk_offer_after_matches); choose_offer(i) or skip_offer() each
#     ended    -> result &"victory" (Rival won) or &"defeat" (out of tickets, or the
#                 Rival lost / drawn), see end_reason
#   kc-syn (synergy-system.md §5, approved): Supply Drop slot 1 is on the deck's main trait
#   (supply_drop_on_trait). With RunConfig.synergy_offers: Doctrine after doctrine_after_matches (pick a
#   trait: its set count +1 in matches), Retire as the Supply Drop's 4th option (retire_card) and
#   Regroup (a free Retire) after a loss. Retire never takes the deck below RunConfig.deck_floor.
#   Retired cards go to the Honor Roll (honor_roll).
#   kc-art-traits (art-traits.md, approved T1-T4): every copy has ONE trait and an art (deck_traits /
#   deck_arts, parallel to deck). The art gives the trait (ArtTraits): Supply Drop offers carry a trait
#   + art per card (slot 1 on the main trait, slots 2-3 home 60% / alternate 40%); same-trait art swaps
#   are free (set_copy_art) outside random_copy_arts runs.
#   kc-trait-ui (head): with random_copy_arts (the default) a run's copies keep the art they were
#   found with: the starter and Supply Drop cards each draw a RANDOM art of the copy's trait (own RNG
#   stream "copy_art", art_draws counter), art swaps are refused and Codex EQUIP does not reach the run.
#   kc-onboard (onboarding-progression.md, approved N1-N4): the starter is 20 Standard Issue cards
#   (CardData.standard_issue: plain, one fixed Standard Issue art). The run ladder: the drop after
#   match n draws from rung RunConfig.rung_after(n) (units -> + tactics -> + Fields -> full pool); from
#   multi_pick_from_match on a drop shows 4 and you take 2 (offer `picks` / `taken`); a loss gives
#   Salvage (salvage_after_loss: a 2-card drop, pick 1) instead of Regroup; from muster_out_from_match
#   on each drop / Salvage is followed by Muster out (one Standard Issue card home per card taken +
#   muster_out_extra, most expensive pre-selected, never below deck_floor); the first calling card
#   taken sets the Doctrine (doctrine_from_first_pick).
#   kc-no-training (head, iPad playtest): the card level system is removed. No Recruit / Trained /
#   Veteran / Elite copies, no Promotion, no locked keywords: every copy has its keywords and effects
#   from the start, and carries at most one trait.
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
## (every copy Trained, as they were). 3 = kc-art-traits (deck_traits, deck_arts, offer traits /
## arts, reissue); version 2 saves load with every copy on its default trait and art.
## 4 = kc-onboard (offer picks / taken / level / count, Salvage, Muster out, mustered_out; Recruits
## mean "trait on, keywords locked"): v1-v3 Recruit copies load as Trained (their old meaning had the
## keywords on), Re-issue flags are dropped.
## 5 = kc-loadout-cut: no loadout.secondary / lethal / tactical (the Sidearm, Frag Grenade and
## Flashbang are gone). v1-v4 saves load with those three fields dropped; nothing else changes.
## 6 = kc-no-training: no copy levels. v1-v5 saves load with deck_levels, offer level / levels and
## honor roll levels dropped, open Promotion offers removed and a Regroup rebuilt from the deck; every
## copy plays with its full keywords. A trait that is not one single trait makes the save invalid.
## 7 = kc-v2-impl (Run v2): the map (nodes, current, visited, done), REQ, modifiers, the boss, the first-run
## flag, the open shop's stock, offers' ladder / elite_cache. v1-v6 saves load unchanged as old-ladder runs,
## or, with from_dict(..., {map = true}) (RunState does), continue on a first-run-shaped map at their fight.
const SAVE_VERSION: int = 7
const OLDEST_SAVE_VERSION: int = 1

const PHASE_LOADOUT: StringName = &"loadout"
const PHASE_MATCH: StringName = &"match"
const PHASE_REWARDS: StringName = &"rewards"
const PHASE_ENDED: StringName = &"ended"
## kc-v2-impl map phases: choosing the next node, and on an event / shop / rest node.
const PHASE_MAP: StringName = &"map"
const PHASE_EVENT: StringName = &"event"
const PHASE_SHOP: StringName = &"shop"
const PHASE_REST: StringName = &"rest"
const PHASES: Array[StringName] = [PHASE_LOADOUT, PHASE_MATCH, PHASE_REWARDS, PHASE_ENDED, PHASE_MAP, PHASE_EVENT,
		PHASE_SHOP, PHASE_REST]

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
## kc-art-traits: each copy's ONE trait, parallel to `deck` (from its art; &"" = a plain art).
## The rules check it against the chassis' options.
var deck_traits: Array[StringName] = []
## kc-art-traits: each copy's art id, parallel to `deck` (display; see ArtTraits for the id forms).
var deck_arts: Array[StringName] = []
## kc-art-traits: Codex EQUIP per chassis (chassis id -> art id), from Settings (not saved here).
var equipped_arts: Dictionary = {}
## kc-trait-ui (head): copies keep the art they were found with, drawn at random from their trait's
## arts; no art swaps, no Codex EQUIP in runs. False = the kc-art-traits behaviour (tests, tools).
var random_copy_arts: bool = true
## kc-trait-ui: random arts drawn so far (the "copy_art" RNG stream's position; saved).
var art_draws: int = 0
## Odds that a Supply Drop slot 2-3 card comes in an alternate option's art (§2.2: 60 / 40).
const ALT_OFFER_CHANCE: float = 0.4
## kc-syn Doctrine trait of this run (&"" until picked).
var doctrine: StringName = &""
## kc-syn: trait of the last card taken from a Supply Drop (main-trait tie-break).
var last_pick_trait: StringName = &""
## kc-onboard: Standard Issue copies sent home by Muster out so far (stats / After-Action).
var mustered_out: int = 0
## kc-syn Honor Roll: retired copies in order {id, match, trait, art}.
var honor_roll: Array[Dictionary] = []
var primary: StringName = &""
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

# --- kc-v2-impl: the Run v2 map (null map = the old linear ladder of config.matches) ---------------
var map: RunMap = null
## Requisition: the one run currency (shops; events).
var req: int = 0
## RunModifiers ids picked for this run.
var modifiers: Array[StringName] = []
## The run's boss (RunMatchData.boss_id in config.bosses), shown from step 1.
var boss: StringName = &""
## The fixed first-run map (progressive reveal).
var first_run: bool = false
## The open shop's stock (RunShop): {rung, cards: [{id, trait, art, sold}], perks: [ids], restocks}.
var shop: Dictionary = {}
## Range Day "Drills": extra cards on the next Supply Drop.
var next_drop_extra: int = 0

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
	for i: int in p_config.starter_deck.size():
		var card: CardData = p_config.starter_deck[i]
		if card != null:
			r.deck.append(card.id)
			r.deck_traits.append(card.card_trait)
			# kc-onboard (head Z2): starter cards wear their one Standard Issue art, never a random one.
			r.deck_arts.append(ArtTraits.starter_art(card))
	r.primary = _id_of(p_config.starter_primary)
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


## kc-ui4 (head: "maybe choose a starting operator/gun"): the Primary weapons a run can start with
## (each defines the Operator): the config's starter Primary first, then every other Primary in
## CardDB (when the autoload is there), by name. The rival's side is not touched.
static func operator_options(cfg: RunConfig) -> Array[LoadoutItem]:
	var out: Array[LoadoutItem] = []
	if cfg != null and cfg.starter_primary != null:
		out.append(cfg.starter_primary)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null(^"/root/CardDB") if tree != null else null
	if db == null:
		return out
	var more: Array[LoadoutItem] = db.loadout_items_by_slot(DataEnums.LoadoutSlot.PRIMARY)
	more.sort_custom(func(a: LoadoutItem, b: LoadoutItem) -> bool: return a.display_name < b.display_name)
	for item: LoadoutItem in more:
		if item != null and not item.crew_only and not out.any(func(o: LoadoutItem) -> bool: return o.id == item.id):
			out.append(item)
	return out


## kc-ui4: start the run with another Operator (a Primary from operator_options). Only before the
## first match; the Primary's attachments are earned during the run as before. "" or the reason.
func set_primary(id: StringName) -> String:
	if phase != PHASE_LOADOUT:
		return "the Operator is picked before the first match"
	var item: LoadoutItem = _index.get(id) as LoadoutItem
	if item == null or item.slot != DataEnums.LoadoutSlot.PRIMARY:
		return "'%s' is not an Operator you can start with" % id
	primary = id
	attachments.clear()
	return ""


## Ends the loadout phase; the first match is next.
func begin() -> String:
	if phase != PHASE_LOADOUT:
		return "the run has already begun"
	phase = _idle_phase()
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
	if map != null:
		return node_match_data(current_map_node())
	if match_index < 0 or match_index >= config.matches.size():
		return null
	return config.matches[match_index]


func is_rival_match() -> bool:
	if map != null:
		return current_map_node().get("type", &"") == RunMap.TYPE_BOSS
	var md: RunMatchData = current_match()
	return md != null and (md.is_rival or match_index == config.matches.size() - 1)


## Seed of the current match: replaying (e.g. after a reload mid-match) deals the same cards.
func match_seed() -> int:
	return derive_seed(seed_value, "match", match_number())


## The player's side for the current match: deck, Primary + attachments, owned Perks and
## the picked killstreaks.
func player_setup() -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Player"
	for i: int in deck.size():
		s.deck.append(_index[deck[i]] as CardData)
		s.deck_traits.append(trait_choice(i))
		s.deck_arts.append(art_of(i))
	s.doctrine = doctrine
	s.primary = _index.get(primary) as LoadoutItem
	s.operator_kit = operator_kit_on()  # kc-v2-impl
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
	var m: MatchState = MatchState.new(config, md.map, player_setup(), enemy_setup(), match_seed(), h)
	configure_match(m)  # kc-v2-impl: Terrain, boss rule, modifiers
	return m


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
	if map != null:
		return _record_map_result(match_result, outcome)
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
		phase = PHASE_REWARDS if not pending_offers.is_empty() else _idle_phase()
	return {
		"ok": true, "reason": "", "ticket_lost": lost, "run_ended": is_over(),
		"offers": pending_offers.duplicate(true),
	}


## Order after a match: Salvage or Regroup (after a loss), Supply Drop (after a win), Muster out
## (after either, from muster_out_from_match), Doctrine, weapon level, Perk offer.
## kc-v2-impl: `ladder` = the fight number whose rung / drop size / Muster out / weapon level / Perk
## the offers follow (-1 = n, the old ladder); an `elite` win is an Elite Cache (its ladder is already
## one rung ahead) with Muster out and no weapon level / Perk. Map runs: Range Day's Drills add cards to
## the drop; Austerity takes 1 card instead of 2.
func _queue_offers(n: int, won: bool, ladder: int = -1, elite: bool = false) -> void:
	var syn: bool = config.synergy_offers
	var lost: bool = not won and _last_result() == &"enemy"
	var dropped: bool = false
	var L: int = n if ladder < 0 else ladder
	if lost and config.salvage_after_loss:
		dropped = _add_drop(RewardOffers.KIND_SALVAGE, n, config.salvage_choices, 1, "salvage", config.rung_after(L))
	elif syn and lost and can_retire():
		_add_synergy_offer(RewardOffers.KIND_REGROUP, n)
	if won:
		var size: Vector2i = config.drop_size_after(L)
		if map != null:
			size.x += next_drop_extra
			next_drop_extra = 0
			if RunModifiers.AUSTERITY in modifiers:
				size.y = mini(size.y, 1)
		dropped = _add_drop(RewardOffers.KIND_SUPPLY_DROP, n, size.x, size.y, "supply", config.rung_after(L))
		if dropped and syn:
			pending_offers.back()["retire"] = true
		if dropped and elite:
			pending_offers.back()["elite_cache"] = true
	if dropped and map != null:
		pending_offers.back()["ladder"] = L
	if dropped and config.muster_out_after(L):
		pending_offers.append({"kind": RewardOffers.KIND_MUSTER_OUT, "match": n,
				"options": standard_issue_ids(), "count": config.muster_out_extra})
	if syn and n in config.doctrine_after_matches and doctrine == &"":
		_add_offer(RewardOffers.KIND_DOCTRINE, n,
				RewardOffers.doctrine(_doctrine_best(), config.doctrine_choices, _rng("doctrine", n)))
	if elite:
		_refresh_current()
		return
	n = L if map != null else n
	if n in config.weapon_level_after_matches:
		weapon_level += 1
		_add_offer(RewardOffers.KIND_ATTACHMENT, n,
				RewardOffers.attachments(config, _index.get(primary) as LoadoutItem, attachments, _rng("attachment", n)))
	if n in config.perk_offer_after_matches:
		_add_offer(RewardOffers.KIND_PERK, n, RewardOffers.perks(config, perks, _rng("perk", n)))
	_refresh_current()


## kc-onboard: a card drop (Supply Drop or Salvage) of `choices` cards from the rung after match n,
## `picks` to take; slot 1 on the main trait (supply_drop_on_trait). The RNG
## streams are "<tag>_drop" / "<tag>_art" ("supply_drop" / "supply_art" as before). True if added.
func _add_drop(kind: StringName, n: int, choices: int, picks: int, tag: String, rung: int = -1) -> bool:
	var main: StringName = main_trait() if config.supply_drop_on_trait else &""
	var r: int = config.rung_after(n) if rung < 0 else rung
	var cards: Array[StringName] = RewardOffers.supply_drop_on_trait(config, main, _rng(tag + "_drop", n), r, choices)
	if cards.is_empty():
		return false
	var drop: Dictionary = {"kind": kind, "match": n, "options": cards, "picks": mini(picks, cards.size()),
			"taken": [] as Array[Dictionary], "rung": r}
	var on: bool = main != &"" and (_index.get(cards[0]) as CardData).can_carry(main)
	if on:
		drop["on_trait"] = main
	_dress_drop(drop, main if on else &"", _rng(tag + "_art", n))
	pending_offers.append(drop)
	return true


## kc-art-traits §2.2: a trait and an art per Supply Drop card. Slot 1 on `on_trait` (when set),
## the others in the home option (60%) or a random alternate (40%); arts = the option's default
## (the equipped art when it gives that trait).
func _dress_drop(drop: Dictionary, on_trait: StringName, rng: RandomNumberGenerator) -> void:
	var traits: Array[StringName] = []
	var arts: Array[StringName] = []
	var opts: Array = drop["options"]
	for k: int in opts.size():
		var c: CardData = _index.get(opts[k]) as CardData
		var t: StringName = c.card_trait if c != null else &""
		var roll: float = rng.randf()
		if c != null and c.has_trait_choice():
			if k == 0 and on_trait != &"":
				t = on_trait
			elif roll < ALT_OFFER_CHANCE:
				var alts: Array[StringName] = c.trait_choices()
				alts.erase(c.card_trait)
				t = alts[rng.randi() % alts.size()]
		traits.append(t)
		arts.append(_random_art(c, t) if random_copy_arts else ArtTraits.default_art(c, t, _equipped(c)))
	drop["traits"] = traits
	drop["arts"] = arts


func _add_offer(kind: StringName, n: int, options: Array[StringName]) -> void:
	if not options.is_empty():
		pending_offers.append({"kind": kind, "match": n, "options": options})


## Regroup: the options depend on the deck, so they are (re)built when the offer becomes the
## current one (_refresh_current) as well.
func _add_synergy_offer(kind: StringName, n: int) -> void:
	var offer: Dictionary = {"kind": kind, "match": n, "options": [] as Array[StringName],
			"traits": [] as Array[StringName]}
	_fill_copy_options(offer)
	if not (offer["options"] as Array).is_empty():
		pending_offers.append(offer)


func _fill_copy_options(offer: Dictionary) -> void:
	var ids: Array[StringName] = []
	var traits: Array[StringName] = []
	for o: Dictionary in retire_options():
		ids.append(o["id"])
		traits.append(StringName(o["trait_choice"]))
	offer["options"] = ids
	offer["traits"] = traits


func _last_result() -> StringName:
	return StringName(history.back()["result"]) if not history.is_empty() else &""


# =============================================================================
# Rewards phase
# =============================================================================

## The offer to show now ({} if none).
func current_offer() -> Dictionary:
	return pending_offers[0] if not pending_offers.is_empty() else {}


## Takes option `index` of the current offer. Returns "" or the reason (head Z1: a card's trait
## comes only from its art).
## kc-onboard: a multi-pick drop stays current until its `picks` are used (or skip_offer()); the
## taken card leaves `options` (see _use_pick), so choose_offer(0) twice takes two different cards;
## Muster out's choose_offer(0) sends the pre-selected cards home (muster_out() picks others).
func choose_offer(index: int) -> String:
	if phase != PHASE_REWARDS or pending_offers.is_empty():
		return "no offer to choose from"
	var offer: Dictionary = pending_offers[0]
	var options: Array = offer["options"]
	if index < 0 or index >= options.size():
		return "no option %d" % index
	var id: StringName = options[index]
	match offer["kind"]:
		RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_SALVAGE:
			var c: CardData = _index.get(id) as CardData
			var traits: Array = offer.get("traits", [])
			var arts: Array = offer.get("arts", [])
			var pick_t: StringName = StringName(traits[index]) if index < traits.size() else c.card_trait
			var pick_a: StringName = StringName(arts[index]) if index < arts.size() else ArtTraits.default_art(c, pick_t, _equipped(c))
			_append_copy(id, pick_t, pick_a)
			var t: StringName = copy_trait(deck.size() - 1)
			if t != &"":
				last_pick_trait = t
				if config.doctrine_from_first_pick and doctrine == &"":
					doctrine = t  # kc-onboard §4.1: the first calling card sets the Doctrine
			_bump_muster_out()
			if _use_pick(offer, index):
				return ""
		RewardOffers.KIND_MUSTER_OUT:
			var pre: Array[int] = []
			for row: Dictionary in muster_out_options():
				if row["preselected"]:
					pre.append(int(row["index"]))
			return muster_out(pre)
		RewardOffers.KIND_ATTACHMENT:
			attachments.append(id)
		RewardOffers.KIND_PERK:
			perks.append(id)
		RewardOffers.KIND_DOCTRINE:
			doctrine = id
		RewardOffers.KIND_REGROUP:
			var err: String = _retire_copy(id, _offer_trait(offer, index))
			if err != "":
				return err
	_pop_offer()
	return ""


## kc-onboard: a card drop used one pick (option `index` taken, -1 = a Retire). A taken card leaves
## `options` (and `traits` / `arts`, kept parallel) and is listed in `taken` ({id, trait, art}), so
## the indices of the cards still on offer stay 0..n-1. True while the drop stays current.
func _use_pick(offer: Dictionary, index: int) -> bool:
	var taken: Array = offer.get("taken", [])
	if index >= 0:
		var row: Dictionary = {"id": offer["options"][index], "trait": &"", "art": &""}
		for key: String in ["traits", "arts"]:
			if offer.has(key) and index < (offer[key] as Array).size():
				row[key.trim_suffix("s")] = (offer[key] as Array)[index]
				(offer[key] as Array).remove_at(index)
		(offer["options"] as Array).remove_at(index)
		taken.append(row)
	offer["taken"] = taken
	offer["picks"] = int(offer.get("picks", 1)) - 1
	return int(offer["picks"]) > 0 and not (offer["options"] as Array).is_empty()


## kc-onboard: a card taken from the current drop sends one more Standard Issue card home.
func _bump_muster_out() -> void:
	if pending_offers.size() > 1 and pending_offers[1]["kind"] == RewardOffers.KIND_MUSTER_OUT:
		pending_offers[1]["count"] = int(pending_offers[1].get("count", 0)) + 1


## kc-onboard: ids of the Standard Issue designs in the deck (deck order, one each).
func standard_issue_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c != null and c.standard_issue and deck[i] not in out:
			out.append(deck[i])
	return out


## kc-onboard: Standard Issue copies in the deck.
func standard_issue_count() -> int:
	var n: int = 0
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c != null and c.standard_issue:
			n += 1
	return n


## kc-onboard §4.3: how many Standard Issue cards the current Muster out sends home at most:
## its count (cards taken + extra), capped by the Standard Issue copies and the deck floor.
func muster_out_count() -> int:
	var offer: Dictionary = current_offer()
	if offer.is_empty() or offer["kind"] != RewardOffers.KIND_MUSTER_OUT:
		return 0
	return maxi(0, mini(int(offer.get("count", 0)), mini(standard_issue_count(), deck.size() - config.deck_floor)))


## kc-onboard §4.3 UI hook (Muster out screen): one row per Standard Issue copy, most expensive
## first (deck order on ties): {index, id, name, cost, firepower, armor, art, serial ("SI-01" ..),
## preselected: bool (the first muster_out_count() rows)}. [] when no Muster out is current.
func muster_out_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = muster_out_count()
	if n <= 0:
		return out
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c != null and c.standard_issue:
			out.append({"index": i, "id": deck[i], "name": c.display_name, "cost": c.cost, "firepower": c.firepower,
					"armor": c.armor, "art": art_of(i), "serial": standard_issue_serial(c), "preselected": false})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["cost"]) > int(b["cost"]) or (int(a["cost"]) == int(b["cost"]) and int(a["index"]) < int(b["index"])))
	for k: int in mini(n, out.size()):
		out[k]["preselected"] = true
	return out


## kc-onboard §2.2: the serial plate of a Standard Issue design ("SI-01" Grunt ... "SI-04" by cost).
static func standard_issue_serial(c: CardData) -> String:
	return "SI-%02d" % clampi(c.cost, 1, 99) if c != null and c.standard_issue else ""


## kc-onboard §4.3: sends Standard Issue copies `indices` (deck indices) home as the current Muster
## out's choice: at most muster_out_count(), Standard Issue cards only; fewer (or none) keeps the
## rest. Ends the offer. Returns "" or the reason.
func muster_out(indices: Array) -> String:
	var offer: Dictionary = current_offer()
	if phase != PHASE_REWARDS or offer.is_empty() or offer["kind"] != RewardOffers.KIND_MUSTER_OUT:
		return "no Muster out to choose"
	var seen: Dictionary = {}
	for raw: Variant in indices:
		var i: int = int(raw)
		if i < 0 or i >= deck.size() or not _card(i).standard_issue:
			return "only Standard Issue cards can be mustered out"
		if seen.has(i):
			return "copy %d is listed twice" % i
		seen[i] = true
	if seen.size() > muster_out_count():
		return "you can send at most %d Standard Issue cards home" % muster_out_count()
	var order: Array = seen.keys()
	order.sort()
	order.reverse()
	for i: Variant in order:
		_remove_copy(int(i))
		mustered_out += 1
	_pop_offer()
	return ""

## kc-syn §5.4: Retire option `index` of retire_options() as this offer's choice: the 4th option
## of a Supply Drop (instead of a card; kc-onboard: it uses one of the drop's picks) or the Regroup
## offer. Returns "" or the reason.
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
	var err: String = _retire_copy(list[index]["id"], StringName(list[index]["trait_choice"]))
	if err != "":
		return err
	if kind == RewardOffers.KIND_SUPPLY_DROP and _use_pick(offer, -1):
		return ""
	_pop_offer()
	return ""


## kc-art-traits §2.2: swap copy i's art. Only to an art that keeps the copy's trait (head Z1: the
## trait never changes after the card is found), and never in a run with random_copy_arts.
func set_copy_art(i: int, art: StringName) -> String:
	if i < 0 or i >= deck.size():
		return "no deck copy %d" % i
	_pad()
	var c: CardData = _card(i)
	if not ArtTraits.belongs(art, c):
		return "'%s' is not an art of %s" % [art, c.display_name]
	if random_copy_arts and art != art_of(i):
		return "in a run, each copy keeps the art it was found with"
	var t: StringName = ArtTraits.trait_of(art, c)
	if c.has_trait_choice() and t != trait_choice(i):
		return "that art gives %s: a card keeps the trait it was found with" % ArtTraits.trait_name(t)
	deck_arts[i] = art
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
		phase = _idle_phase()


## A Regroup / Muster out that became current lists the deck as it is now (an earlier
## offer may have changed it); one with nothing left to pick is dropped.
func _refresh_current() -> void:
	while not pending_offers.is_empty():
		var offer: Dictionary = pending_offers[0]
		if offer["kind"] == RewardOffers.KIND_MUSTER_OUT:
			offer["options"] = standard_issue_ids()
			if muster_out_count() > 0:
				return
			pending_offers.remove_at(0)
			continue
		if offer["kind"] != RewardOffers.KIND_REGROUP:
			return
		_fill_copy_options(offer)
		if not (offer["options"] as Array).is_empty():
			return
		pending_offers.remove_at(0)
	if pending_offers.is_empty() and phase == PHASE_REWARDS:
		phase = _idle_phase()


# =============================================================================
# kc-syn: copy traits, Retire (deck view for the UI)
# =============================================================================

func _card(i: int) -> CardData:
	return _index.get(deck[i]) as CardData


## kc-art-traits: copy i's trait (from the art it was found with; head Z1: it never changes).
## Default trait when unknown.
func trait_choice(i: int) -> StringName:
	if i >= 0 and i < deck_traits.size():
		return deck_traits[i]
	var c: CardData = _card(i) if i >= 0 and i < deck.size() else null
	return c.card_trait if c != null else &""


## kc-art-traits: the ONE trait copy i carries in a match (plain if not an option; none on Standard
## Issue cards).
func copy_trait(i: int) -> StringName:
	return SynergyRules.trait_at(_card(i), trait_choice(i))


## kc-art-traits: copy i's art id. A stored art that is no longer available (the licensed folder is
## absent) shows the option's default art instead; the trait never changes with it.
func art_of(i: int) -> StringName:
	var c: CardData = _card(i)
	var a: StringName = deck_arts[i] if i >= 0 and i < deck_arts.size() else &""
	if a != &"" and ArtTraits.belongs(a, c):
		return a
	return ArtTraits.default_art(c, trait_choice(i) if c != null and c.can_carry(trait_choice(i)) else (c.card_trait if c != null else &""), _equipped(c))


## kc-art-traits: Codex EQUIP (chassis id -> art id, Settings.equipped_arts). Copies keep their
## arts; new copies are pre-selected in the equipped art when it gives their trait.
func set_equipped_arts(equipped: Dictionary) -> void:
	equipped_arts = {}
	if random_copy_arts:
		return  # kc-trait-ui (head): Codex EQUIP never reaches a run
	for k: Variant in equipped:
		equipped_arts[StringName(String(k))] = StringName(String(equipped[k]))


func _equipped(c: CardData) -> StringName:
	if c == null:
		return &""
	var eq: StringName = StringName(String(equipped_arts.get(c.id, equipped_arts.get(String(c.id), ""))))
	return eq if ArtTraits.belongs(eq, c) else &""


## Pads deck_traits / deck_arts to the deck (tests and old code append to deck only).
func _pad() -> void:
	while deck_traits.size() < deck.size():
		var c: CardData = _card(deck_traits.size())
		deck_traits.append(c.card_trait if c != null else &"")
	while deck_arts.size() < deck.size():
		deck_arts.append(&"")
	for list: Array in [deck_traits, deck_arts]:
		if list.size() > deck.size():
			list.resize(deck.size())


## kc-no-training: one trait per copy; a value that is not a single trait makes the copy plain.
func _append_copy(id: StringName, t: StringName, art: StringName) -> void:
	_pad()
	deck.append(id)
	deck_traits.append(t if SynergyRules.is_single_trait(t) else &"")
	deck_arts.append(art)


func _remove_copy(at: int) -> void:
	deck.remove_at(at)
	if at < deck_traits.size():
		deck_traits.remove_at(at)
	if at < deck_arts.size():
		deck_arts.remove_at(at)


## kc-trait-ui: a random art of option `t` of `c` (any of its arts for a printed card), drawn from
## the run's "copy_art" stream (deterministic per run seed and draw count).
func _random_art(c: CardData, t: StringName) -> StringName:
	if c == null:
		return &""
	var pool: Array[StringName] = ArtTraits.arts_with_trait(c, t) if c.has_trait_choice() else ArtTraits.arts_for(c)
	if pool.is_empty():
		return ArtTraits.default_art(c, t)
	var rng: RandomNumberGenerator = _rng("copy_art", art_draws)
	art_draws += 1
	return pool[rng.randi() % pool.size()]


func _offer_trait(offer: Dictionary, index: int) -> StringName:
	var traits: Array = offer.get("traits", [])
	return StringName(traits[index]) if index < traits.size() else SynergyRules.TRAIT_DEFAULT


## UI hook: the arts deck copy i may swap to for free (`same`: same trait, or any art for a
## printed card) and the ones of another trait (`other`, greyed: a copy keeps its trait).
## {same: Array[StringName], other: Array[StringName]}.
func art_choices(i: int) -> Dictionary:
	var same: Array[StringName] = []
	var other: Array[StringName] = []
	if i < 0 or i >= deck.size():
		return {"same": same, "other": other}
	var c: CardData = _card(i)
	var locked: bool = c.has_trait_choice()  # head Z1: never another trait
	for a: StringName in ArtTraits.arts_for(c):
		if not locked or ArtTraits.trait_of(a, c) == trait_choice(i):
			same.append(a)
		else:
			other.append(a)
	return {"same": same, "other": other}


## UI hook: every trait option of a card design with its arts ({trait, name, family, family_name,
## default_art, arts}, ArtTraits.options), the equipped art pre-selected.
func trait_options_of(id: StringName) -> Array[Dictionary]:
	var c: CardData = _index.get(id) as CardData
	return ArtTraits.options(c, _equipped(c)) if c != null else [] as Array[Dictionary]


## Copies per trait in the deck (units and Fields): {trait: n}. kc-art-traits: per copy (two
## Marksmen can count for different traits; each copy counts for its one trait only).
func trait_counts() -> Dictionary:
	var counts: Dictionary = {}
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null:
			continue
		var t: StringName = copy_trait(i)
		if t == &"":
			continue
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


## The deck's main trait (§5.2): most cards; ties -> the trait of the last pick (if tied),
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
	var counts: Dictionary = trait_counts()
	var best: StringName = &""
	for t: StringName in SynergyRules.TRAITS:
		if int(counts.get(t, 0)) > int(counts.get(best, 0)):
			best = t
	return best


## Engine panel (§5.2): {traits: {trait: n}, keywords: {kw: n}, standard_issue: n, main_trait,
## doctrine, deck_size, floor}.
func engine_summary() -> Dictionary:
	var kws: Dictionary = {}
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null:
			continue
		var kw: StringName = SynergyRules.keyword_at(c)
		if kw != &"":
			kws[kw] = int(kws.get(kw, 0)) + 1
	return {"traits": trait_counts(), "keywords": kws, "standard_issue": standard_issue_count(),
			"main_trait": main_trait(),
			"doctrine": doctrine, "deck_size": deck.size(), "floor": config.deck_floor}


## One row per deck copy: {index, id, keyword, trait (the ONE trait it carries in a match),
## trait_choice (= its art's trait), art, subname, trait_options, standard_issue, serial ("SI-02")}.
func deck_view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in deck.size():
		var c: CardData = _card(i)
		var art: StringName = art_of(i)
		out.append({"index": i, "id": deck[i], "keyword": SynergyRules.keyword_at(c),
				"trait": copy_trait(i), "trait_choice": trait_choice(i), "art": art, "subname": ArtTraits.subname(art),
				"trait_options": c.trait_choices(), "standard_issue": c.standard_issue,
				"serial": standard_issue_serial(c)})
	return out


## True while a Retire would keep the deck at or above RunConfig.deck_floor.
func can_retire() -> bool:
	return deck.size() > config.deck_floor


## Retire choices (§5.4), one per design (and trait): Standard Issue cards first (kc-onboard), then
## 1-cost cards, then the rest (deck order inside each group). Each: {index (first copy), id, cost,
## trait, trait_choice, art, standard_issue}. Empty at the deck floor.
func retire_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_retire():
		return out
	var seen: Dictionary = {}
	var groups: Array = [[], [], []]
	for i: int in deck.size():
		var key: String = _copy_key(i)
		if seen.has(key):
			continue
		seen[key] = true
		var c: CardData = _card(i)
		var row: Dictionary = {"index": i, "id": deck[i], "cost": c.cost, "trait": copy_trait(i),
				"trait_choice": trait_choice(i), "art": art_of(i), "standard_issue": c.standard_issue}
		groups[0 if c.standard_issue else (1 if c.cost <= 1 else 2)].append(row)
	for g: Array in groups:
		out.append_array(g)
	return out


## Grouping key of copy i in the Retire list: the design, plus the trait for chassis with options
## (two Marksmen with different traits are two choices).
func _copy_key(i: int) -> String:
	var c: CardData = _card(i)
	if c != null and c.has_trait_choice():
		return "%s@%s" % [deck[i], trait_choice(i)]
	return String(deck[i])


## First copy of `id` (and, for chassis with options, of trait `t`; TRAIT_DEFAULT = any trait).
func _find_copy(id: StringName, t: StringName = SynergyRules.TRAIT_DEFAULT) -> int:
	for i: int in deck.size():
		if deck[i] == id:
			var c: CardData = _card(i)
			if t == SynergyRules.TRAIT_DEFAULT or not c.has_trait_choice() or trait_choice(i) == t:
				return i
	return -1


func _retire_copy(id: StringName, t: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	if not can_retire():
		return "the deck can't go below %d cards" % config.deck_floor
	var at: int = _find_copy(id, t)
	if at < 0:
		return "that copy is no longer in the deck"
	honor_roll.append({"id": id, "match": match_index, "trait": copy_trait(at), "art": art_of(at)})
	_remove_copy(at)
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
	_pad()
	var offers: Array = []
	for o: Dictionary in pending_offers:
		var od: Dictionary = {"kind": String(o["kind"]), "match": int(o["match"]), "options": _strings(o["options"])}
		if o.has("on_trait"):
			od["on_trait"] = String(o["on_trait"])
		if o.get("retire", false):
			od["retire"] = true
		if o.get("elite_cache", false):
			od["elite_cache"] = true
		for key: String in ["picks", "rung", "count", "ladder"]:
			if o.has(key):
				od[key] = int(o[key])
		if o.has("taken"):
			od["taken"] = (o["taken"] as Array).map(func(t: Dictionary) -> Dictionary:
				return {"id": String(t.get("id", "")), "trait": String(t.get("trait", "")), "art": String(t.get("art", ""))})
		for key: String in ["traits", "arts"]:
			if o.has(key):
				od[key] = _strings(o[key])
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
		"deck_traits": _strings(deck_traits),
		"deck_arts": _strings(deck_arts),
		"doctrine": String(doctrine),
		"last_pick_trait": String(last_pick_trait),
		"honor_roll": honor_roll.map(func(h: Dictionary) -> Dictionary:
			return {"id": String(h["id"]), "match": int(h["match"]),
					"trait": String(h.get("trait", "")), "art": String(h.get("art", ""))}),
		"loadout": {
			"primary": String(primary),
			"attachments": _strings(attachments), "perks": _strings(perks),
			"killstreaks": _strings(killstreaks),
		},
		"history": history.duplicate(true),
		"pending_offers": offers,
		"result": String(result),
		"end_reason": String(end_reason),
		"play_time_s": play_time_s,
		"art_draws": art_draws,
		"mustered_out": mustered_out,
		"v2": _map_to_dict(),
	}


## Rebuilds a run from to_dict() data (e.g. parsed JSON). Returns {run, error}:
## run = null and error = why, if the data is not a valid save for this config.
## opts: {map: bool} = a v1-v6 save continues on a first-run-shaped map (RunState passes it).
static func from_dict(p_config: RunConfig, d: Variant, opts: Dictionary = {}) -> Dictionary:
	var r: RunProgress = RunProgress.new()
	var err: String = r._load(p_config, d, bool(opts.get("map", false)))
	return {"run": null if err != "" else r, "error": err}


func _load(p_config: RunConfig, d: Variant, migrate_to_map: bool = false) -> String:
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
	var v2_data: Variant = d.get("v2", {})
	var has_map: bool = int(v) >= 7 and typeof(v2_data) == TYPE_DICTIONARY and not (v2_data as Dictionary).is_empty()
	if phase in [PHASE_MAP, PHASE_EVENT, PHASE_SHOP, PHASE_REST] and not has_map:
		return "phase %s needs a map" % phase
	if match_index < 0 or match_index > (16 if has_map else config.matches.size()):
		return "match_index %d out of range" % match_index
	if tickets < 0 or tickets > config.tickets:
		return "tickets %d out of range" % tickets
	if phase in [PHASE_MATCH, PHASE_REWARDS] and ((match_index >= config.matches.size() and not has_map) or tickets == 0):
		return "phase %s but the run is over" % phase
	var e: String = _read_ids(d.get("deck"), deck, CardData, "deck")
	if e != "":
		return e
	if deck.is_empty():
		return "empty deck"
	# kc-no-training (v6): v2-v5 saves hold deck_levels (copy levels); they are ignored (every copy
	# plays with its full keywords now).
	# kc-art-traits (v3): per-copy trait choice and art; v1 / v2 copies take their defaults.
	var raw_traits: Variant = d.get("deck_traits", null)
	var raw_arts: Variant = d.get("deck_arts", null)
	if raw_traits == null:
		for id: StringName in deck:
			deck_traits.append((_index[id] as CardData).card_trait)
	else:
		if typeof(raw_traits) != TYPE_ARRAY or (raw_traits as Array).size() != deck.size():
			return "deck_traits don't match the deck"
		for t: Variant in raw_traits:
			if typeof(t) not in [TYPE_STRING, TYPE_STRING_NAME] or not SynergyRules.is_single_trait(StringName(str(t))):
				return "deck_traits entry '%s' is not one trait (a copy has at most one)" % str(t)
			deck_traits.append(StringName(str(t)))
	if raw_arts == null:
		for i: int in deck.size():
			var c: CardData = _index[deck[i]] as CardData
			deck_arts.append(ArtTraits.default_art(c, deck_traits[i] if c.can_carry(deck_traits[i]) else c.card_trait))
	else:
		if typeof(raw_arts) != TYPE_ARRAY or (raw_arts as Array).size() != deck.size():
			return "deck_arts don't match the deck"
		for a: Variant in raw_arts:
			deck_arts.append(StringName(str(a)))
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
		# kc-no-training (v6): v2-v5 entries' level / trained_twin are dropped.
		honor_roll.append({"id": StringName(str(entry.get("id", ""))),
				"match": int(entry.get("match", 0)),
				"trait": StringName(str(entry.get("trait", ""))), "art": StringName(str(entry.get("art", "")))})
	var lo: Variant = d.get("loadout")
	if typeof(lo) != TYPE_DICTIONARY:
		return "no loadout"
	# kc-loadout-cut: v1-v4 saves also hold loadout.secondary / lethal / tactical; they are ignored.
	var prim: StringName = StringName(str(lo.get("primary", "")))
	if not (_index.get(prim) is LoadoutItem):
		return "unknown primary '%s'" % prim
	primary = prim
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
		# kc-no-training (v6): an open Promotion of a v2-v5 save is dropped (Promotion is removed).
		if int(v) < 6 and typeof(o) == TYPE_DICTIONARY and str(o.get("kind", "")) == LEGACY_KIND_PROMOTION:
			continue
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
		if o.has("on_trait"):
			offer["on_trait"] = StringName(str(o["on_trait"]))
		if bool(o.get("retire", false)):
			offer["retire"] = true
		# kc-onboard (v4): drop picks / taken / rung, Muster out count. Older saves: 1 pick. (Re-issue
		# flags of v3 saves and the v4-v5 drop `level` are dropped: head Z1, kc-no-training.)
		for key: String in ["picks", "rung", "count", "ladder"]:
			if typeof(o.get(key)) in [TYPE_INT, TYPE_FLOAT]:
				offer[key] = int(o[key])
		if bool(o.get("elite_cache", false)):
			offer["elite_cache"] = true
		if kind in RewardOffers.CARD_DROPS:
			if not offer.has("picks"):
				offer["picks"] = 1
			var taken: Array[Dictionary] = []
			if typeof(o.get("taken")) == TYPE_ARRAY:
				for t: Variant in o["taken"]:
					if typeof(t) == TYPE_DICTIONARY and _index.get(StringName(str(t.get("id", "")))) is CardData:
						taken.append({"id": StringName(str(t["id"])), "trait": StringName(str(t.get("trait", ""))),
								"art": StringName(str(t.get("art", "")))})
			offer["taken"] = taken
		if kind == RewardOffers.KIND_MUSTER_OUT and not offer.has("count"):
			offer["count"] = 0
		for key: String in ["traits", "arts"]:
			if o.has(key):
				var raw: Variant = o[key]
				if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != opts.size():
					return "offer %s don't match its options" % key
				var list: Array[StringName] = []
				for v2: Variant in raw:
					if key == "traits" and not SynergyRules.is_single_trait(StringName(str(v2))):
						return "offer trait '%s' is not one trait (a copy has at most one)" % str(v2)
					list.append(StringName(str(v2)))
				offer[key] = list
		if kind == RewardOffers.KIND_SUPPLY_DROP and not offer.has("traits"):
			_dress_drop(offer, StringName(offer.get("on_trait", &"")), _rng("supply_art", int(offer["match"])))
		pending_offers.append(offer)
	if int(v) < 6:
		_migrate_v5()
	if (phase == PHASE_REWARDS) != (not pending_offers.is_empty()):
		return "pending offers don't match phase %s" % phase
	result = StringName(str(d.get("result", "")))
	end_reason = StringName(str(d.get("end_reason", "")))
	if (phase == PHASE_ENDED) != (result in [RESULT_VICTORY, RESULT_DEFEAT]):
		return "result '%s' doesn't match phase %s" % [result, phase]
	if has_map:
		var me: String = _map_from_dict(v2_data)
		if me != "":
			return me
	elif migrate_to_map and not config.bosses.is_empty() and config.matches.size() >= 4:
		_migrate_to_map()
	play_time_s = float(d.get("play_time_s", 0.0))
	art_draws = int(d.get("art_draws", 0)) if typeof(d.get("art_draws", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	mustered_out = int(d.get("mustered_out", 0)) if typeof(d.get("mustered_out", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	return ""


## kc-no-training: the kind id Promotion offers had in v2-v5 saves (dropped on load).
const LEGACY_KIND_PROMOTION: String = "promotion"


## kc-no-training: a v1-v5 save after its levels were dropped. An open Regroup is rebuilt from the
## deck as it is now (one row per design and trait); a rewards phase whose only offers were
## Promotions goes on to the next match.
func _migrate_v5() -> void:
	if phase == PHASE_REWARDS and pending_offers.is_empty():
		phase = PHASE_MATCH
		return
	_refresh_current()


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

# =============================================================================
# kc-v2-impl: the Run v2 map (run-v2.md; API: documentation/technical/run-v2-api.md)
# =============================================================================

## A new v2 map run (loadout phase). opts: {first_run: bool, boss: StringName (&"" = the first boss),
## modifiers: Array}. The map is generated now (the Loadout screen shows the boss) and rebuilt by
## set_modifiers().
static func create_map_run(p_config: RunConfig, p_seed: int, opts: Dictionary = {}) -> RunProgress:
	var r: RunProgress = create(p_config, p_seed)
	r.first_run = bool(opts.get("first_run", false))
	r.boss = StringName(opts.get("boss", &""))
	if r.boss == &"" and not p_config.bosses.is_empty():
		r.boss = p_config.bosses[0].boss_id
	if r.first_run:
		r.boss = p_config.bosses[0].boss_id if not p_config.bosses.is_empty() else r.boss
	r.req = p_config.req_start
	for m: Variant in opts.get("modifiers", []):
		if StringName(m) in RunModifiers.ALL and not r.first_run:
			r.modifiers.append(StringName(m))
	r.tickets = r.max_tickets()
	r.map = RunMap.generate(p_config, p_seed, r.first_run, r.modifiers)
	return r


func is_map_run() -> bool:
	return map != null


## Tickets you can have at most (Hardcore: 2).
func max_tickets() -> int:
	return mini(config.tickets, 2) if RunModifiers.HARDCORE in modifiers else config.tickets


func threat() -> int:
	return RunModifiers.threat_of(modifiers)


## Loadout only: the run's modifiers (RunModifiers ids). `allowed` = ids the profile has unlocked
## (null = all). Rebuilds the map (Hot Ground / Veteran Crews change it). "" or the reason.
func set_modifiers(ids: Array, allowed: Variant = null) -> String:
	if phase != PHASE_LOADOUT:
		return "modifiers are picked before the run"
	if map == null:
		return "this run has no map"
	if first_run and not ids.is_empty():
		return "the first run has no modifiers"
	var list: Array[StringName] = []
	for raw: Variant in ids:
		var id: StringName = StringName(raw)
		if id not in RunModifiers.ALL:
			return "unknown modifier '%s'" % id
		if allowed != null and id not in allowed:
			return "%s is locked" % RunModifiers.name_of(id)
		if id not in list:
			list.append(id)
	modifiers = list
	tickets = max_tickets()
	map = RunMap.generate(config, seed_value, first_run, modifiers)
	return ""


## The boss slot of this run (a RunMatchData from config.bosses), or null.
func boss_data() -> RunMatchData:
	for b: RunMatchData in config.bosses:
		if b != null and b.boss_id == boss:
			return b
	return null


## {id, name, rule_id, rule_name, rule_text, crew, mode, mode_name, armor_bonus, deck: [ids]} ({} if none).
func boss_view() -> Dictionary:
	var b: RunMatchData = boss_data()
	if b == null:
		return {}
	var deck_ids: Array[StringName] = []
	for c: CardData in b.deck_for_squad():
		deck_ids.append(c.id)
	return {"id": b.boss_id, "name": b.squad.display_name if b.squad != null else "", "rule_id": b.boss_rule,
			"rule_name": b.boss_rule_name, "rule_text": b.boss_rule_text,
			"crew": b.squad.display_name if b.squad != null else "", "mode": _mode_id(b.mode), "mode_name": _mode_name(b.mode),
			"armor_bonus": b.enemy_armor_bonus, "deck": deck_ids}


static func _mode_id(mode: int) -> StringName:
	return &"firefight" if mode == DataEnums.GameMode.FIREFIGHT else &"zone_control"


static func _mode_name(mode: int) -> String:
	return "Firefight" if mode == DataEnums.GameMode.FIREFIGHT else "Zone Control"


## The RunMatchData a fight / elite / boss node is played with (a copy of its slot with the node's
## Armor; the boss slot for the boss). Null for other nodes.
func node_match_data(n: Dictionary) -> RunMatchData:
	if n.is_empty() or n["type"] not in RunMap.FIGHT_TYPES:
		return null
	var f: Dictionary = n["fight"]
	if bool(f["boss"]):
		return boss_data()
	var slot: int = int(f["slot"])
	if slot < 0 or slot >= config.matches.size():
		return null
	var md: RunMatchData = config.matches[slot].duplicate() as RunMatchData
	md.enemy_armor_bonus = config.matches[slot].enemy_armor_bonus + int(f["armor"]) + (1 if bool(f.get("challenge", false)) else 0)
	md.is_rival = false
	return md


## The node the run is on ({} before F1).
func current_map_node() -> Dictionary:
	return map.current_node() if map != null else {}


func current_event_id() -> StringName:
	var n: Dictionary = current_map_node()
	return StringName(n.get("event", &"")) if n.get("type", &"") == RunMap.TYPE_EVENT else &""


## Fights F1-F4 played so far (elites don't count).
func fights_done() -> int:
	return map.fights_done() if map != null else mini(match_index, 4)


## The reward rung you are on (the next fight's): shops and Salvage read it.
func current_rung() -> int:
	return config.rung_after(mini(4, fights_done() + 1))


## Seeded RNG for a purpose at the current node (stable across reloads).
func node_rng(tag: String) -> RandomNumberGenerator:
	return _rng("%s@%s" % [tag, String(map.current) if map != null else ""], match_index)


## Moves to a reachable node (phase map). Fight / elite / boss -> match; event / shop / rest -> their
## phase. "" or the reason.
func move_to(id: StringName) -> String:
	if map == null:
		return "this run has no map"
	if phase != PHASE_MAP:
		return "finish this step first"
	if not map.can_move_to(id):
		return "you can't reach that node from here"
	map.move_to(id)
	var n: Dictionary = map.node(id)
	match n["type"]:
		RunMap.TYPE_EVENT:
			phase = PHASE_EVENT
		RunMap.TYPE_SHOP:
			phase = PHASE_SHOP
			shop = {}
			RunShop.stock(self)
		RunMap.TYPE_REST:
			phase = PHASE_REST
		_:
			phase = PHASE_MATCH
	return ""


## Leaves a shop, or a rest / event without taking an option (always allowed at a rest; at an event
## only when none of its options is available, e.g. Memorial Wall with full tickets and no calling
## card). "" or the reason.
func leave_node() -> String:
	if phase == PHASE_EVENT:
		for o: Dictionary in RunEvents.view(self).get("options", []):
			if o["available"]:
				return "pick one of the options"
	elif phase != PHASE_SHOP and phase != PHASE_REST:
		return "nothing to leave"
	shop = {}
	finish_node(false)
	return ""


## An event / shop / rest node is resolved: back to the map, or to the offers it queued.
func finish_node(queued: bool) -> void:
	if map != null and map.current != &"":
		map.mark_done(map.current)
	if tickets <= 0:
		_end(RESULT_DEFEAT, END_NO_TICKETS)
		return
	_refresh_current()
	phase = PHASE_REWARDS if queued and not pending_offers.is_empty() else PHASE_MAP


## Puts an offer at the end of the queue (events / rests: Muster out, weapon level).
func queue_offer(offer: Dictionary) -> void:
	var o: Dictionary = offer.duplicate()
	if not o.has("match"):
		o["match"] = match_index
	if o["kind"] == RewardOffers.KIND_MUSTER_OUT and not o.has("count"):
		o["count"] = 0
	pending_offers.append(o)


## Queues a weapon level (Range Day, Field-strip). False when the weapon is fully kitted.
func queue_weapon_level() -> bool:
	var opts: Array[StringName] = RewardOffers.attachments(config, _index.get(primary) as LoadoutItem, attachments,
			node_rng("attachment"))
	if opts.is_empty():
		return false
	weapon_level += 1
	queue_offer({"kind": RewardOffers.KIND_ATTACHMENT, "options": opts})
	return true


## A deck row for the UI: {index, id, name, trait, art, standard_issue, cost, elite}.
func copy_row(i: int) -> Dictionary:
	var c: CardData = _card(i)
	return {"index": i, "id": deck[i], "name": c.display_name if c != null else String(deck[i]), "trait": copy_trait(i),
			"art": art_of(i), "standard_issue": c != null and c.standard_issue, "cost": c.cost if c != null else 0,
			"elite": c != null and c.is_elite, "serial": standard_issue_serial(c)}


## Adds a copy of card `id` (event / shop): the trait (TRAIT_DEFAULT = the card's default; an on-trait
## slot passes its trait) and art (&"" = a random art of that trait). Like a pick: the first calling
## card sets the Doctrine. Returns the deck index or -1.
func gain_card(id: StringName, t: StringName = SynergyRules.TRAIT_DEFAULT, art: StringName = &"") -> int:
	var c: CardData = _index.get(id) as CardData
	if c == null:
		return -1
	var tr: StringName = c.card_trait if t == SynergyRules.TRAIT_DEFAULT or not c.can_carry(t) else t
	var a: StringName = art
	if a == &"":
		a = _random_art(c, tr) if random_copy_arts else ArtTraits.default_art(c, tr, _equipped(c))
	_append_copy(id, tr, a)
	var ct: StringName = copy_trait(deck.size() - 1)
	if ct != &"":
		last_pick_trait = ct
		if config.doctrine_from_first_pick and doctrine == &"":
			doctrine = ct
	return deck.size() - 1


## Memorial Wall: a copy of deck card i with the same trait and art. Returns the new index or -1.
func copy_deck_card(i: int) -> int:
	if i < 0 or i >= deck.size():
		return -1
	_pad()
	_append_copy(deck[i], deck_traits[i], deck_arts[i])
	return deck.size() - 1


func remove_copy(i: int) -> void:
	if i >= 0 and i < deck.size():
		_remove_copy(i)


## Discharge / Drill: copy i leaves the deck for the Honor Roll.
func retire_copy_at(i: int) -> void:
	if i < 0 or i >= deck.size():
		return
	honor_roll.append({"id": deck[i], "match": match_index, "trait": copy_trait(i), "art": art_of(i)})
	_remove_copy(i)


## Dresses an offer-like dict {options} with traits / arts (as a Supply Drop).
func dress_offer(drop: Dictionary, on_trait: StringName, rng: RandomNumberGenerator) -> void:
	_dress_drop(drop, on_trait, rng)


## The kit (passive + ability) is on for the current node: always from run 2; in the first run from
## RunConfig.first_run_kit_from_fight (F2) and on elites.
func operator_kit_on() -> bool:
	if map == null:
		return false
	if not first_run:
		return true
	var f: Dictionary = current_map_node().get("fight", {})
	return bool(f.get("elite", false)) or bool(f.get("boss", false)) or int(f.get("ladder", 0)) >= config.first_run_kit_from_fight


## Puts the node's Terrain, the boss rule and the modifiers on a MatchState built for the current node
## (create_match does it; a screen that builds its own match calls it before start_match()).
func configure_match(m: MatchState) -> void:
	if map == null or m == null:
		return
	var n: Dictionary = current_map_node()
	var f: Dictionary = n.get("fight", {})
	if not f.is_empty():
		var ter: Array = f.get("terrain", [])
		for z: int in mini(3, ter.size()):
			m.terrain[z] = StringName(ter[z])
	m.fog_of_war = RunModifiers.FOG in modifiers
	if bool(f.get("boss", false)):
		var b: RunMatchData = boss_data()
		if b != null:
			m.boss_id = b.boss_id
			m.boss_rule = b.boss_rule
			m.boss_rule_name = b.boss_rule_name
			m.boss_rule_text = b.boss_rule_text
			m.boss_card = b.boss_card
			m.boss_name = b.squad.display_name if b.squad != null else ""


## The whole map for the Run Map screen (run-v2-api.md §3).
func map_view() -> Dictionary:
	if map == null:
		return {}
	var reach: Array[StringName] = []
	if phase == PHASE_MAP:
		reach = map.reachable()
	var rows: Array[Dictionary] = []
	for n: Dictionary in map.nodes:
		rows.append(_node_view(n, reach))
	return {"steps": RunMap.STEPS, "lanes": RunMap.LANES, "step": map.current_step(), "current": map.current,
			"first_run": first_run, "req": req, "tickets": tickets, "max_tickets": max_tickets(),
			"threat": threat(), "modifiers": modifiers.duplicate(), "boss": boss_view(), "nodes": rows}


## One node row of map_view() ({} for an unknown id).
func node_view(id: StringName) -> Dictionary:
	if map == null or map.node(id).is_empty():
		return {}
	var reach: Array[StringName] = []
	if phase == PHASE_MAP:
		reach = map.reachable()
	return _node_view(map.node(id), reach)


func _node_view(n: Dictionary, reach: Array[StringName]) -> Dictionary:
	var type: StringName = n["type"]
	var row: Dictionary = {"id": n["id"], "step": n["step"], "lane": n["lane"], "type": type,
			"name": RunMap.TYPE_NAMES.get(type, ""), "links": (n["links"] as Array).duplicate(),
			"reachable": n["id"] in reach, "visited": n["id"] in map.visited, "current": n["id"] == map.current,
			"done": n["id"] in map.done, "fight": {}, "event": {}}
	var gives: String = ""
	var risk: String = ""
	match type:
		RunMap.TYPE_EVENT:
			var ev: EventData = RunEvents.data(StringName(n["event"]))
			row["event"] = {"id": n["event"], "title": ev.title if ev != null else ""}
			gives = "A choice: REQ, a card, a ticket, card removal or intel"
			risk = "Some options cost a ticket or REQ (shown)"
		RunMap.TYPE_SHOP:
			gives = "Spend REQ: cards, Muster out, Discharge, a Perk"
			risk = "None"
		RunMap.TYPE_REST:
			gives = "Pick one: +1 ticket, Drill (2 cards home) or Field-strip (a weapon level)"
			risk = "None"
		_:
			var f: Dictionary = n["fight"]
			var md: RunMatchData = node_match_data(n)
			var deck_ids: Array[StringName] = []
			if md != null:
				for c: CardData in md.deck_for_squad():
					deck_ids.append(c.id)
			var ter: Array[Dictionary] = []
			for z: int in 3:
				ter.append(TerrainRules.row(z, StringName((f["terrain"] as Array)[z])))
			row["fight"] = {"label": f["label"], "crew": md.squad.display_name if md != null and md.squad != null else "",
					"crew_label": md.crew_label if md != null else "", "mode": _mode_id(md.mode if md != null else 0),
					"mode_name": _mode_name(md.mode if md != null else 0), "armor_bonus": md.enemy_armor_bonus if md != null else 0,
					"green": md != null and md.is_green_squad(), "elite": bool(f["elite"]), "boss": bool(f["boss"]),
					"challenge": bool(f.get("challenge", false)), "deck": deck_ids, "terrain": ter}
			if bool(f["boss"]):
				gives = "Win the run"
				risk = "The run"
			elif bool(f["elite"]):
				gives = "Win: an Elite Cache (a Supply Drop one rung ahead), Muster out, +%d REQ" % config.req_elite
				risk = "Lose: Salvage, +%d REQ, -1 ticket. A tougher crew (+%d Armor)" % [config.req_loss, int(f["armor"])]
			else:
				gives = "Win: a Supply Drop, +%d REQ" % (config.req_elite if bool(f.get("challenge", false)) else config.req_win)
				risk = "Lose: Salvage, +%d REQ, -1 ticket" % config.req_loss
	row["gives"] = gives
	row["risk"] = risk
	return row


## The v2 part of a finished match: REQ, the node done, offers (rung of the fight; an elite's cache one
## rung ahead with Muster out; weapon level / Perk after F1/F3/F4 and F2/F4 as today), run end.
func _record_map_result(match_result: StringName, outcome: Dictionary) -> Dictionary:
	var n: Dictionary = current_map_node()
	var f: Dictionary = n.get("fight", {})
	var md: RunMatchData = current_match()
	var num: int = match_number()
	var lost: bool = match_result == &"enemy"
	var won: bool = match_result == &"player"
	var elite: bool = bool(f.get("elite", false))
	var is_boss: bool = bool(f.get("boss", false))
	if lost:
		tickets = maxi(0, tickets - 1)
	var gain: int = config.req_draw
	if won:
		gain = config.req_elite if elite or bool(f.get("challenge", false)) else config.req_win
	elif lost:
		gain = config.req_loss
	if is_boss:
		gain = 0
	req += gain
	history.append({
		"match": num, "bracket": md.bracket if md != null else 0, "rival": is_boss,
		"mode": String(DataEnums.key_of(DataEnums.GameMode, md.mode if md != null else 0)).to_lower(),
		"result": String(match_result), "reason": String(outcome.get("reason", &"")),
		"rounds": int(outcome.get("rounds", 0)), "player_score": int(outcome.get("player_score", 0)),
		"enemy_score": int(outcome.get("enemy_score", 0)), "ticket_lost": lost,
		"node": String(n.get("id", "")), "label": String(f.get("label", "")), "elite": elite,
		"terrain": (f.get("terrain", []) as Array).map(func(x: Variant) -> String: return String(x)),
		"req_gained": gain,
	})
	match_index += 1
	pending_offers.clear()
	map.mark_done(map.current)
	if tickets <= 0:
		_end(RESULT_DEFEAT, END_NO_TICKETS)
	elif is_boss:
		match match_result:
			&"player":
				_end(RESULT_VICTORY, END_RIVAL_WON)
			&"enemy":
				_end(RESULT_DEFEAT, END_RIVAL_LOST)
			_:
				_end(RESULT_DEFEAT, END_RIVAL_DRAW)
	else:
		_queue_offers(num, won, int(f.get("ladder", num)), elite)
		phase = PHASE_REWARDS if not pending_offers.is_empty() else PHASE_MAP
	return {"ok": true, "reason": "", "ticket_lost": lost, "run_ended": is_over(),
			"offers": pending_offers.duplicate(true), "req_gained": gain, "elite": elite}


## Phase when no offer is pending: the map (map runs) or the next match (the old ladder).
func _idle_phase() -> StringName:
	return PHASE_MAP if map != null else PHASE_MATCH


## kc-v2-impl save part (v7): {} for a run without a map.
func _map_to_dict() -> Dictionary:
	if map == null:
		return {}
	var sh: Dictionary = {}
	if not shop.is_empty():
		var cards: Array = []
		for c: Dictionary in shop.get("cards", []):
			cards.append({"id": String(c["id"]), "trait": String(c["trait"]), "art": String(c["art"]), "sold": bool(c["sold"])})
		sh = {"rung": int(shop.get("rung", 1)), "cards": cards, "restocks": int(shop.get("restocks", 0)),
				"perks": (shop.get("perks", []) as Array).map(func(x: Variant) -> String: return String(x))}
	return {"map": map.to_dict(), "req": req, "modifiers": _strings(modifiers), "boss": String(boss),
			"first_run": first_run, "shop": sh, "next_drop_extra": next_drop_extra}


func _map_from_dict(d: Dictionary) -> String:
	var res: Dictionary = RunMap.from_dict(d.get("map"))
	if res["map"] == null:
		return String(res["error"])
	map = res["map"]
	req = int(d.get("req", 0))
	first_run = bool(d.get("first_run", false))
	boss = StringName(str(d.get("boss", "")))
	if boss_data() == null:
		return "unknown boss '%s'" % boss
	modifiers.clear()
	for m: Variant in d.get("modifiers", []):
		if StringName(str(m)) not in RunModifiers.ALL:
			return "unknown modifier '%s'" % str(m)
		modifiers.append(StringName(str(m)))
	next_drop_extra = int(d.get("next_drop_extra", 0))
	shop = {}
	var sh: Variant = d.get("shop", {})
	if typeof(sh) == TYPE_DICTIONARY and not (sh as Dictionary).is_empty():
		var cards: Array = []
		for c: Variant in sh.get("cards", []):
			var id: StringName = StringName(str(c.get("id", "")))
			if not (_index.get(id) is CardData):
				return "unknown shop card '%s'" % id
			cards.append({"id": id, "trait": StringName(str(c.get("trait", ""))), "art": StringName(str(c.get("art", ""))),
					"sold": bool(c.get("sold", false))})
		var perks: Array = []
		for p: Variant in sh.get("perks", []):
			if not (_index.get(StringName(str(p))) is LoadoutItem):
				return "unknown shop Perk '%s'" % str(p)
			perks.append(StringName(str(p)))
		shop = {"rung": int(sh.get("rung", 1)), "cards": cards, "perks": perks, "restocks": int(sh.get("restocks", 0))}
	if phase == PHASE_SHOP and shop.is_empty():
		RunShop.stock(self)
	return ""


## v1-v6 saves (head: no run lost): the run continues on a first-run-shaped map, standing on the fight
## it was on (match_index 0-3 = F1-F4, 4 = the boss), the fights before it done.
func _migrate_to_map() -> void:
	first_run = true
	boss = config.bosses[0].boss_id if not config.bosses.is_empty() else &""
	req = config.req_start
	map = RunMap.generate(config, seed_value, true, [])
	var fight_steps: Array[int] = [0, 2, 4, 6, 8]
	var k: int = clampi(match_index, 0, 4)
	if phase == PHASE_LOADOUT:
		return
	for i: int in fight_steps.size():
		var step: int = fight_steps[i]
		var target: int = k if phase == PHASE_MATCH else k - 1
		if i > target:
			break
		var node: Dictionary = map.step_nodes(step)[0]
		map.move_to(node["id"])
		if i < target or phase != PHASE_MATCH:
			map.mark_done(node["id"])
	if phase == PHASE_REWARDS and pending_offers.is_empty():
		phase = PHASE_MAP


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
	# kc-onboard: cards only older saves hold (the kc-syn starter's Rifleman).
	for c: CardData in cfg.legacy_cards:
		add.call(c)
	add.call(cfg.starter_primary)
	# kc-ui4: every Operator a run can start with, and its attachments.
	for prim: LoadoutItem in operator_options(cfg):
		add.call(prim)
		for att: LoadoutItem in prim.attachments:
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
