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
#   kc-syn (synergy-system.md §5, approved): every deck copy has a level (deck_levels, parallel
#   to deck: 0 Recruit, 1 Trained, 2 Veteran, 3 Elite); the starter is Recruits
#   (RunConfig.starter_recruits), reward cards come Trained. Supply Drop slot 1 is on the deck's
#   main trait (supply_drop_on_trait). With RunConfig.synergy_offers: Doctrine after
#   doctrine_after_matches (pick a trait: its set count +1 in matches), Promotion after
#   promotion_after_matches (one copy goes up a level), Retire as the Supply Drop's 4th option
#   (retire_card) and Regroup (a free Retire) after a loss. Retiring a Recruit while a second
#   Recruit of that chassis is in the deck trains the twin ("two become one"). Retire never
#   takes the deck below RunConfig.deck_floor. Retired cards go to the Honor Roll (honor_roll).
#   kc-art-traits (art-traits.md, approved T1-T4): every copy also has a trait choice and an art
#   (deck_traits / deck_arts, parallel to deck). The art gives the trait (ArtTraits), chosen from the
#   chassis' options when the copy trains: Supply Drop offers carry a trait + art per card (slot 1
#   on the main trait, slots 2-3 home 60% / alternate 40%), Promotion and twin training take a trait
#   (choose_offer(i, trait) / retire_card(i, twin_trait); default = the copy's pre-selected art),
#   Re-issue (reissue_card) changes a Trained copy's trait as a Supply Drop option next to Retire, or on
#   Regroup, and same-trait art swaps are free (set_copy_art). Codex EQUIP (equipped_arts, from
#   Settings via RunState) dresses the starter's Recruits and pre-selects new copies' arts.
#   kc-trait-ui (head): with random_copy_arts (the default) a run's copies keep the art they were
#   found with: the starter, Supply Drop cards, training into another trait and Re-issue each draw a
#   RANDOM art of the copy's trait (own RNG stream "copy_art", art_draws counter), art swaps are
#   refused and Codex EQUIP does not reach the run (set_equipped_arts is ignored).
#   kc-onboard (onboarding-progression.md, approved N1-N4; head Z1/Z2 of kc-trait-ui): the starter is
#   20 Standard Issue cards (CardData.standard_issue: plain, never train, one fixed Standard Issue art).
#   A copy keeps the trait of the art it was found with: there is no trait choice at training and no
#   Re-issue any more (train_choices has one row, reissue_* are no-ops kept for old callers). A
#   Recruit (level 0) has its trait on and its keywords locked; Promotion trains it (keywords on).
#   The run ladder: the drop after match n draws from rung RunConfig.rung_after(n) (units ->
#   + tactics -> + Fields -> + Elites) at level reward_level_after(n) (Recruits after match 1);
#   from multi_pick_from_match on a drop shows 4 and you take 2 (offer `picks` / `taken`); a loss
#   gives Salvage (salvage_after_loss: a 2-card drop, pick 1) instead of Regroup; from
#   muster_out_from_match on each drop / Salvage is followed by Muster out (one Standard Issue card
#   home per card taken + muster_out_extra, most expensive pre-selected, never below deck_floor);
#   the first calling card taken sets the Doctrine (doctrine_from_first_pick). Twin training is gone.
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
const SAVE_VERSION: int = 5
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
## kc-art-traits: each copy's trait choice, parallel to `deck` (a Recruit's = the trait it will
## train into, pre-selected from its art; &"" = a plain art). The rules apply level and options.
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
## kc-syn Honor Roll: retired copies in order {id, level, match, trained_twin: bool}.
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
		if item != null and not out.any(func(o: LoadoutItem) -> bool: return o.id == item.id):
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


## The player's side for the current match: deck, Primary + attachments, owned Perks and
## the picked killstreaks.
func player_setup() -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = "Player"
	for i: int in deck.size():
		s.deck.append(_index[deck[i]] as CardData)
		s.deck_levels.append(level_of(i))
		s.deck_traits.append(trait_choice(i))
		s.deck_arts.append(art_of(i))
	s.doctrine = doctrine
	s.primary = _index.get(primary) as LoadoutItem
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


## Order after a match: Salvage or Regroup (after a loss), Supply Drop (after a win), Muster out
## (after either, from muster_out_from_match), Doctrine, weapon level, Promotion, Perk offer.
func _queue_offers(n: int, won: bool) -> void:
	var syn: bool = config.synergy_offers
	var lost: bool = not won and _last_result() == &"enemy"
	var dropped: bool = false
	if lost and config.salvage_after_loss:
		dropped = _add_drop(RewardOffers.KIND_SALVAGE, n, config.salvage_choices, 1, "salvage")
	elif syn and lost and can_retire():
		_add_synergy_offer(RewardOffers.KIND_REGROUP, n)
	if won:
		var size: Vector2i = config.drop_size_after(n)
		dropped = _add_drop(RewardOffers.KIND_SUPPLY_DROP, n, size.x, size.y, "supply")
		if dropped and syn:
			pending_offers.back()["retire"] = true
	if dropped and config.muster_out_after(n):
		pending_offers.append({"kind": RewardOffers.KIND_MUSTER_OUT, "match": n,
				"options": standard_issue_ids(), "count": config.muster_out_extra})
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
	_refresh_current()


## kc-onboard: a card drop (Supply Drop or Salvage) of `choices` cards from the rung after match n,
## `picks` to take, at the rung's level; slot 1 on the main trait (supply_drop_on_trait). The RNG
## streams are "<tag>_drop" / "<tag>_art" ("supply_drop" / "supply_art" as before). True if added.
func _add_drop(kind: StringName, n: int, choices: int, picks: int, tag: String) -> bool:
	var main: StringName = main_trait() if config.supply_drop_on_trait else &""
	var cards: Array[StringName] = RewardOffers.supply_drop_on_trait(config, main, _rng(tag + "_drop", n),
			config.rung_after(n), choices)
	if cards.is_empty():
		return false
	var drop: Dictionary = {"kind": kind, "match": n, "options": cards, "picks": mini(picks, cards.size()),
			"taken": [] as Array[Dictionary], "level": config.reward_level_after(n), "rung": config.rung_after(n)}
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


## Promotion / Regroup: the options depend on the deck, so they are (re)built when the offer
## becomes the current one (_refresh_current) as well.
func _add_synergy_offer(kind: StringName, n: int) -> void:
	var offer: Dictionary = {"kind": kind, "match": n, "options": [] as Array[StringName], "levels": [] as Array[int],
			"traits": [] as Array[StringName]}
	_fill_copy_options(offer)
	if not (offer["options"] as Array).is_empty():
		pending_offers.append(offer)


func _fill_copy_options(offer: Dictionary) -> void:
	var list: Array[Dictionary] = promotion_options() if offer["kind"] == RewardOffers.KIND_PROMOTION else retire_options()
	var ids: Array[StringName] = []
	var levels: Array[int] = []
	var traits: Array[StringName] = []
	for o: Dictionary in list:
		ids.append(o["id"])
		levels.append(int(o["level"]))
		traits.append(StringName(o["trait_choice"]))
	offer["options"] = ids
	offer["levels"] = levels
	offer["traits"] = traits


func _last_result() -> StringName:
	return StringName(history.back()["result"]) if not history.is_empty() else &""


# =============================================================================
# Rewards phase
# =============================================================================

## The offer to show now ({} if none).
func current_offer() -> Dictionary:
	return pending_offers[0] if not pending_offers.is_empty() else {}


## Takes option `index` of the current offer. Returns "" or the reason. `trait_pick` is ignored
## (head Z1: the trait comes only from the art; kept so old callers still compile).
## kc-onboard: a multi-pick drop stays current until its `picks` are used (or skip_offer()); the
## taken card leaves `options` (see _use_pick), so choose_offer(0) twice takes two different cards;
## Muster out's choose_offer(0) sends the pre-selected cards home (muster_out() picks others).
func choose_offer(index: int, trait_pick: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
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
			var lv: int = int(offer.get("level", SynergyRules.LEVEL_TRAINED))
			_append_copy(id, lv if c.is_unit() else SynergyRules.LEVEL_TRAINED, pick_t, pick_a)
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
		RewardOffers.KIND_PROMOTION:
			var at: int = _find_copy(id, int(offer["levels"][index]), _offer_trait(offer, index))
			if at < 0:
				return "that copy is no longer in the deck"
			if level_of(at) == SynergyRules.LEVEL_RECRUIT:
				_train(at)
			else:
				deck_levels[at] = mini(SynergyRules.LEVEL_MAX, level_of(at) + 1)
		RewardOffers.KIND_REGROUP:
			var err: String = _retire_copy(id, int(offer["levels"][index]), _offer_trait(offer, index))
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
## offer. Returns "" or the reason. `twin_trait` is ignored (twin training and the trait choice
## are gone: head Z1 / kc-onboard §4.3).
func retire_card(index: int, twin_trait: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	if phase != PHASE_REWARDS or pending_offers.is_empty():
		return "no offer to choose from"
	var offer: Dictionary = pending_offers[0]
	var kind: StringName = offer["kind"]
	if not (kind == RewardOffers.KIND_REGROUP or (kind == RewardOffers.KIND_SUPPLY_DROP and offer.get("retire", false))):
		return "this offer has no Retire option"
	var list: Array[Dictionary] = retire_options()
	if index < 0 or index >= list.size():
		return "no Retire option %d" % index
	var err: String = _retire_copy(list[index]["id"], int(list[index]["level"]), StringName(list[index]["trait_choice"]))
	if err != "":
		return err
	if kind == RewardOffers.KIND_SUPPLY_DROP and _use_pick(offer, -1):
		return ""
	_pop_offer()
	return ""


## Removed (head Z1, kc-trait-ui answers: "No choice at all: the trait comes only from the art you
## find"). Kept as a refusing no-op so old callers still compile. Always returns the reason.
func reissue_card(_index: int, _new_trait: StringName) -> String:
	return "Re-issue was removed: a card keeps the trait of the art it was found with"


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
		phase = PHASE_MATCH


## A Promotion / Regroup / Muster out that became current lists the deck as it is now (an earlier
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
		if offer["kind"] not in [RewardOffers.KIND_PROMOTION, RewardOffers.KIND_REGROUP]:
			return
		_fill_copy_options(offer)
		if not (offer["options"] as Array).is_empty():
			return
		pending_offers.remove_at(0)
	if pending_offers.is_empty() and phase == PHASE_REWARDS:
		phase = PHASE_MATCH


# =============================================================================
# kc-syn: copy levels, traits, Retire, Promotion (deck view for the UI)
# =============================================================================

## Level of deck copy i (Trained if unknown).
func level_of(i: int) -> int:
	return clampi(deck_levels[i], SynergyRules.LEVEL_RECRUIT, SynergyRules.LEVEL_MAX) \
			if i >= 0 and i < deck_levels.size() else SynergyRules.LEVEL_TRAINED


func _card(i: int) -> CardData:
	return _index.get(deck[i]) as CardData


## kc-art-traits: copy i's trait (from the art it was found with; head Z1: it never changes).
## Default trait when unknown.
func trait_choice(i: int) -> StringName:
	if i >= 0 and i < deck_traits.size():
		return deck_traits[i]
	var c: CardData = _card(i) if i >= 0 and i < deck.size() else null
	return c.card_trait if c != null else &""


## kc-art-traits: the trait copy i carries in a match (kc-onboard: Recruits too; plain if not an
## option; none on Standard Issue cards).
func copy_trait(i: int) -> StringName:
	return SynergyRules.trait_at(_card(i), level_of(i), trait_choice(i))


## kc-art-traits: copy i's art id. A stored art that is no longer available (the licensed folder is
## absent) shows the option's default art instead; the trait never changes with it.
func art_of(i: int) -> StringName:
	var c: CardData = _card(i)
	var a: StringName = deck_arts[i] if i >= 0 and i < deck_arts.size() else &""
	if a != &"" and ArtTraits.belongs(a, c):
		return a
	return ArtTraits.default_art(c, trait_choice(i) if c != null and c.can_carry(trait_choice(i)) else (c.card_trait if c != null else &""), _equipped(c))


## kc-art-traits: Codex EQUIP (chassis id -> art id, Settings.equipped_arts). The starter's Recruits
## still in the deck put the equipped art on (pre-selecting the trait they train into); Trained
## copies keep theirs. New copies are pre-selected in the equipped art when it gives their trait.
func set_equipped_arts(equipped: Dictionary) -> void:
	equipped_arts = {}
	if random_copy_arts:
		return  # kc-trait-ui (head): Codex EQUIP never reaches a run
	for k: Variant in equipped:
		equipped_arts[StringName(String(k))] = StringName(String(equipped[k]))
	for i: int in deck.size():
		var c: CardData = _card(i)
		var eq: StringName = _equipped(c)
		if eq != &"" and level_of(i) == SynergyRules.LEVEL_RECRUIT:
			set_copy_art(i, eq)


func _equipped(c: CardData) -> StringName:
	if c == null:
		return &""
	var eq: StringName = StringName(String(equipped_arts.get(c.id, equipped_arts.get(String(c.id), ""))))
	return eq if ArtTraits.belongs(eq, c) else &""


## Pads deck_levels / deck_traits / deck_arts to the deck (tests and old code append to deck only).
func _pad() -> void:
	while deck_levels.size() < deck.size():
		deck_levels.append(SynergyRules.LEVEL_TRAINED)
	while deck_traits.size() < deck.size():
		var c: CardData = _card(deck_traits.size())
		deck_traits.append(c.card_trait if c != null else &"")
	while deck_arts.size() < deck.size():
		deck_arts.append(&"")
	for list: Array in [deck_levels, deck_traits, deck_arts]:
		if list.size() > deck.size():
			list.resize(deck.size())


func _append_copy(id: StringName, level: int, t: StringName, art: StringName) -> void:
	_pad()
	deck.append(id)
	deck_levels.append(level)
	deck_traits.append(t)
	deck_arts.append(art)


func _remove_copy(at: int) -> void:
	deck.remove_at(at)
	deck_levels.remove_at(at)
	if at < deck_traits.size():
		deck_traits.remove_at(at)
	if at < deck_arts.size():
		deck_arts.remove_at(at)


## Trains Recruit copy i (Recruit -> Trained: its keywords unlock). Head Z1: the copy keeps its
## trait and its art. Standard Issue cards never train. `_t` is ignored (old callers).
func _train(i: int, _t: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	_pad()
	var c: CardData = _card(i)
	if c == null or c.standard_issue:
		return "Standard Issue cards never train"
	deck_levels[i] = SynergyRules.LEVEL_TRAINED
	return ""


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


## Head Z1: the TRAIN AS picker is gone. Kept for old callers: one row, the copy's own trait
## {trait, name, art, subname, random: false, preselected: true, count_from, count_to (= count_from:
## the copy already counts for its trait)}. [] for a bad index.
func train_choices(i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if i < 0 or i >= deck.size():
		return out
	var t: StringName = copy_trait(i)
	var now: int = int(trait_counts().get(t, 0)) if t != &"" else 0
	out.append({"trait": t, "name": ArtTraits.trait_name(t), "art": art_of(i), "subname": ArtTraits.subname(art_of(i)),
			"random": false, "preselected": true, "count_from": now, "count_to": now})
	return out


## UI hook: the arts deck copy i may swap to for free (`same`: same trait, or any art for a
## Recruit / printed card) and the ones that need a Re-issue (`other`, greyed: "change trait with
## Re-issue"). {same: Array[StringName], other: Array[StringName]}.
func art_choices(i: int) -> Dictionary:
	var same: Array[StringName] = []
	var other: Array[StringName] = []
	if i < 0 or i >= deck.size():
		return {"same": same, "other": other}
	var c: CardData = _card(i)
	var locked: bool = c.has_trait_choice()  # head Z1: never another trait, at any level
	for a: StringName in ArtTraits.arts_for(c):
		if not locked or ArtTraits.trait_of(a, c) == trait_choice(i):
			same.append(a)
		else:
			other.append(a)
	return {"same": same, "other": other}


## Removed (head Z1): always []. Kept for old callers.
func reissue_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## UI hook: every trait option of a card design with its arts ({trait, name, family, family_name,
## default_art, arts}, ArtTraits.options), the equipped art pre-selected.
func trait_options_of(id: StringName) -> Array[Dictionary]:
	var c: CardData = _index.get(id) as CardData
	return ArtTraits.options(c, _equipped(c)) if c != null else [] as Array[Dictionary]


## Trained copies per trait in the deck (units and Fields): {trait: n}. kc-art-traits: per copy
## (two Marksmen can count for different traits). trained_only = false also counts the trait each
## Recruit is pre-selected to train into.
func trait_counts(trained_only: bool = true) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null:
			continue
		var t: StringName = copy_trait(i)  # kc-onboard: Recruits count too (trained_only kept for callers)
		if t == &"":
			continue
		counts[t] = int(counts.get(t, 0)) + 1
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


## Engine panel (§5.2): {traits: {trait: n}, keywords: {kw: Trained n}, recruits: n (calling cards
## with locked keywords), standard_issue: n, main_trait, doctrine, deck_size, floor}.
func engine_summary() -> Dictionary:
	var kws: Dictionary = {}
	var recruits: int = 0
	for i: int in deck.size():
		var c: CardData = _card(i)
		if c == null:
			continue
		if not SynergyRules.locked_keywords(c, level_of(i)).is_empty():
			recruits += 1
		var kw: StringName = SynergyRules.keyword_at(c, level_of(i))
		if kw != &"":
			kws[kw] = int(kws.get(kw, 0)) + 1
	return {"traits": trait_counts(), "keywords": kws, "recruits": recruits, "standard_issue": standard_issue_count(),
			"main_trait": main_trait(),
			"doctrine": doctrine, "deck_size": deck.size(), "floor": config.deck_floor}


## One row per deck copy: {index, id, level, level_name ("Standard Issue" for those), band, keyword,
## trait (what it carries in a match: Recruits too), trait_choice (= its art's trait), art, subname,
## trait_options, can_reissue (always false: head Z1), standard_issue, serial ("SI-02"), trains
## ("Trains: First Shot · Guard" on a Recruit, else ""), locked_keywords (["First Shot", "Guard"])}.
func deck_view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in deck.size():
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		var art: StringName = art_of(i)
		out.append({"index": i, "id": deck[i], "level": lv,
				"level_name": "Standard Issue" if c.standard_issue else SynergyRules.LEVEL_NAMES[lv],
				"band": &"" if c.standard_issue else SynergyRules.LEVEL_BANDS[lv], "keyword": SynergyRules.keyword_at(c, lv),
				"trait": copy_trait(i), "trait_choice": trait_choice(i), "art": art, "subname": ArtTraits.subname(art),
				"trait_options": c.trait_choices(), "can_reissue": false, "standard_issue": c.standard_issue,
				"serial": standard_issue_serial(c), "trains": SynergyRules.trains_text(c, lv),
				"locked_keywords": SynergyRules.locked_keywords(c, lv)})
	return out


## True while a Retire would keep the deck at or above RunConfig.deck_floor.
func can_retire() -> bool:
	return deck.size() > config.deck_floor


## Retire choices (§5.4), one per design and level: Standard Issue cards first (kc-onboard), then
## Recruits, then 1-cost cards, then the rest (deck order inside each group). Each: {index (first copy), id, level, cost, trait,
## twin_index (the Recruit twin that would be trained, -1 = none)}. Empty at the deck floor.
func retire_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_retire():
		return out
	var seen: Dictionary = {}
	var groups: Array = [[], [], [], []]
	for i: int in deck.size():
		var key: String = _copy_key(i)
		if seen.has(key):
			continue
		seen[key] = true
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		var row: Dictionary = {"index": i, "id": deck[i], "level": lv, "cost": c.cost, "trait": copy_trait(i),
				"trait_choice": trait_choice(i), "art": art_of(i), "twin_index": _twin_of(i), "standard_issue": c.standard_issue}
		groups[0 if c.standard_issue else (1 if lv == SynergyRules.LEVEL_RECRUIT else (2 if c.cost <= 1 else 3))].append(row)
	for g: Array in groups:
		out.append_array(g)
	return out


## Promotion choices (§5.2), one per design and level below Elite: units at any level, Fields only
## as Recruits (Veteran / Elite give stats, Fields have none); tactics and Standard Issue cards never.
## Recruits first. Each: {index (first copy), id, level, next_level, trait, trait_choice, art, trains
## (kept: a Recruit with trait options), unlocks (keywords a Recruit gets: ["First Shot", "Guard"])}.
func promotion_options() -> Array[Dictionary]:
	var seen: Dictionary = {}
	var groups: Array = [[], [], []]
	for i: int in deck.size():
		var c: CardData = _card(i)
		var lv: int = level_of(i)
		if c == null or lv >= SynergyRules.LEVEL_MAX or c.card_type == DataEnums.CardType.TACTIC or c.standard_issue:
			continue
		if c.is_field() and (lv >= SynergyRules.LEVEL_TRAINED or c.card_trait == &""):
			continue
		var key: String = _copy_key(i)
		if seen.has(key):
			continue
		seen[key] = true
		groups[mini(lv, 2)].append({"index": i, "id": deck[i], "level": lv, "next_level": lv + 1,
				"trait": copy_trait(i), "trait_choice": trait_choice(i), "art": art_of(i),
				"trains": lv == SynergyRules.LEVEL_RECRUIT and c.has_trait_choice(),
				"unlocks": SynergyRules.locked_keywords(c, lv)})
	var out: Array[Dictionary] = []
	for g: Array in groups:
		out.append_array(g)
	return out


## Grouping key of copy i in the Retire / Promotion lists: design and level, plus the trait for
## Trained copies of chassis with options (two Marksmen with different traits are two choices).
func _copy_key(i: int) -> String:
	var c: CardData = _card(i)
	if c != null and c.has_trait_choice():
		return "%s@%d@%s" % [deck[i], level_of(i), trait_choice(i)]
	return "%s@%d" % [deck[i], level_of(i)]


## kc-onboard §4.3: twin training ("two become one") is retired: the starter has no Recruit twins
## any more. Always -1; kept for the Retire rows' `twin_index`.
func _twin_of(_i: int) -> int:
	return -1


## First copy of `id` at `level` (and, for Trained copies of chassis with options, trait choice
## `t`; TRAIT_DEFAULT = any trait).
func _find_copy(id: StringName, level: int, t: StringName = SynergyRules.TRAIT_DEFAULT) -> int:
	for i: int in deck.size():
		if deck[i] == id and level_of(i) == level:
			var c: CardData = _card(i)
			if t == SynergyRules.TRAIT_DEFAULT or not c.has_trait_choice() or trait_choice(i) == t:
				return i
	return -1


func _retire_copy(id: StringName, level: int, t: StringName = SynergyRules.TRAIT_DEFAULT) -> String:
	if not can_retire():
		return "the deck can't go below %d cards" % config.deck_floor
	var at: int = _find_copy(id, level, t)
	if at < 0:
		return "that copy is no longer in the deck"
	honor_roll.append({"id": id, "level": level, "match": match_index, "trained_twin": false,
			"trait": copy_trait(at), "art": art_of(at)})
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
		if o.has("levels"):
			od["levels"] = (o["levels"] as Array).duplicate()
		if o.has("on_trait"):
			od["on_trait"] = String(o["on_trait"])
		if o.get("retire", false):
			od["retire"] = true
		for key: String in ["picks", "level", "rung", "count"]:
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
		"deck_levels": deck_levels.duplicate(),
		"deck_traits": _strings(deck_traits),
		"deck_arts": _strings(deck_arts),
		"doctrine": String(doctrine),
		"last_pick_trait": String(last_pick_trait),
		"honor_roll": honor_roll.map(func(h: Dictionary) -> Dictionary:
			return {"id": String(h["id"]), "level": int(h["level"]), "match": int(h["match"]), "trained_twin": bool(h["trained_twin"]),
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
			if StringName(str(t)) != &"" and StringName(str(t)) not in SynergyRules.TRAITS:
				return "unknown trait '%s' in deck_traits" % str(t)
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
		honor_roll.append({"id": StringName(str(entry.get("id", ""))), "level": int(entry.get("level", 0)),
				"match": int(entry.get("match", 0)), "trained_twin": bool(entry.get("trained_twin", false)),
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
		# kc-onboard (v4): drop picks / taken / level / rung, Muster out count. Older saves: 1 pick, Trained.
		# (Re-issue flags of v3 saves are dropped: head Z1.)
		for key: String in ["picks", "level", "rung", "count"]:
			if typeof(o.get(key)) in [TYPE_INT, TYPE_FLOAT]:
				offer[key] = int(o[key])
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
					list.append(StringName(str(v2)))
				offer[key] = list
		if kind == RewardOffers.KIND_SUPPLY_DROP and not offer.has("traits"):
			_dress_drop(offer, StringName(offer.get("on_trait", &"")), _rng("supply_art", int(offer["match"])))
		pending_offers.append(offer)
	if (phase == PHASE_REWARDS) != (not pending_offers.is_empty()):
		return "pending offers don't match phase %s" % phase
	result = StringName(str(d.get("result", "")))
	end_reason = StringName(str(d.get("end_reason", "")))
	if (phase == PHASE_ENDED) != (result in [RESULT_VICTORY, RESULT_DEFEAT]):
		return "result '%s' doesn't match phase %s" % [result, phase]
	play_time_s = float(d.get("play_time_s", 0.0))
	art_draws = int(d.get("art_draws", 0)) if typeof(d.get("art_draws", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	mustered_out = int(d.get("mustered_out", 0)) if typeof(d.get("mustered_out", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	if int(v) < 4:
		_migrate_v3()
	return ""


## kc-onboard: a v1-v3 Recruit had its keywords but no trait; the new Recruit is the opposite. Old
## Recruit copies (the kc-syn starter) load as Trained, the full chassis, and an open Promotion /
## Regroup is rebuilt from the deck as it is now.
func _migrate_v3() -> void:
	for i: int in deck_levels.size():
		var c: CardData = _card(i)
		if deck_levels[i] == SynergyRules.LEVEL_RECRUIT and c != null and not c.standard_issue:
			deck_levels[i] = SynergyRules.LEVEL_TRAINED
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
