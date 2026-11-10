# duel_state.gd
# Purpose: DuelState autoload (kc-duel-impl): the one entry point the Duel screens call
#   (documentation/technical/duel-api.md). Thin: the rules are in DuelRules, the pool in DuelCollection,
#   the saves and records in DuelProfile (inside the run profile, Settings.run_profile v2), the match in
#   DuelMatch. Holds the match being played (`current`) for the match scene to take.
#   Duel never writes campaign progress: no cards, tickets, REQ or unlocks come out of it.
# Dependencies: Settings, CardDB, RunState (profile), DuelConfig, DuelDeck, DuelRules, DuelCollection,
#   DuelProfile, DuelMatch, RunProfile, RunConfig.
# Author: Mechanics Developer Agent (kc-duel-impl)
extends Node

## A saved deck was added, changed or deleted.
signal decks_changed
## A finished duel was recorded.
signal records_changed

const CONFIG_PATH: String = "res://data/duel/duel_config.tres"
const RUN_CONFIG_PATH: String = "res://data/run_config.tres"
const MAX_DECKS: int = 8
const TIERS: Array[StringName] = [&"recruit", &"regular", &"veteran"]
const RANDOM_OPPONENT: StringName = &"random"
const TIER_TEXT: Dictionary = {
	&"recruit": ["Recruit", "Recruit: its cards have −1 Armor and it makes mistakes"],
	&"regular": ["Regular", "Regular: plays well, ignores sets"],
	&"veteran": ["Veteran", "Veteran: plays its best, no handicap"],
}

## The match being played (start_vs_ai / start_hot_seat); the match scene takes it.
var current: DuelMatch = null
var last_error: String = ""
var _config: DuelConfig = null
var _profile_fallback: Dictionary = {}


# =============================================================================
# Config, pool, heroes, presets
# =============================================================================

func config() -> DuelConfig:
	if _config == null:
		var db: Node = get_node_or_null(^"/root/CardDB")
		if db != null and db.has_method(&"get_duel_config"):
			_config = db.get_duel_config()
		if _config == null:
			_config = load(CONFIG_PATH) as DuelConfig
	return _config


func _base_config() -> RunConfig:
	var db: Node = get_node_or_null(^"/root/CardDB")
	var c: RunConfig = db.get_run_config() if db != null and db.has_method(&"get_run_config") else null
	return c if c != null else load(RUN_CONFIG_PATH) as RunConfig


func card_pool(opts: Dictionary = {}) -> Array[Dictionary]:
	return DuelCollection.pool_view(_profile(), config(), opts)


func is_card_unlocked(card_id: StringName) -> bool:
	return DuelCollection.is_unlocked(DuelDeck.find_card(card_id), _profile())


func heroes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: LoadoutItem in config().heroes:
		if item == null:
			continue
		var ab: LoadoutItem = item.ability as LoadoutItem
		var kws: Array[String] = []
		if item.first_shot:
			kws.append("First Shot")
		if item.pick:
			kws.append("Pick")
		if item.flank:
			kws.append("Flank")
		if item.pierce or item.weapon_class == DataEnums.WeaponClass.LMG:
			kws.append("Pierce")
		if item.cover > 0:
			kws.append("Cover %d" % item.cover)
		if item.rotations_per_round > 1:
			kws.append("%d Rotations" % item.rotations_per_round)
		out.append({"id": item.id, "name": item.display_name,
				"weapon": String(DataEnums.key_of(DataEnums.WeaponClass, item.weapon_class)),
				"fp": item.operator_firepower, "armor": item.operator_armor, "keywords": kws,
				"passive_name": item.passive_name, "passive_text": item.passive_text,
				"ability_id": ab.id if ab != null else &"", "ability_name": ab.display_name if ab != null else "",
				"ability_text": ab.text if ab != null else "",
				"plays_like": String(config().hero_plays_like.get(String(item.id), "")), "unlocked": true})
	return out


func presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: DuelDeck in config().presets:
		if d != null:
			out.append(deck_view(d))
	return out


func preset(id: StringName) -> DuelDeck:
	return config().preset(id)


func tier_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: StringName in TIERS:
		out.append({"id": t, "name": TIER_TEXT[t][0], "text": TIER_TEXT[t][1]})
	return out


# =============================================================================
# Validation and views
# =============================================================================

func validate(deck: DuelDeck, opts: Dictionary = {}) -> Dictionary:
	return DuelRules.validate(deck, config(), DuelCollection.unlocked_set(_profile()), opts)


func default_name(deck: DuelDeck) -> String:
	return DuelRules.default_name(deck, config().name_max_length)


## A deck tile / list view (duel-api.md §4).
func deck_view(d: DuelDeck, opts: Dictionary = {}) -> Dictionary:
	var v: Dictionary = validate(d, opts)
	var rows: Array[Dictionary] = []
	for i: int in d.picks.size():
		var c: CardData = DuelDeck.find_card(d.card_id_at(i))
		rows.append({"card_id": d.card_id_at(i), "art_id": d.resolved_art(i), "trait": d.trait_of_pick(i),
				"name": c.display_name if c != null else String(d.card_id_at(i)), "cost": c.cost if c != null else 0,
				"type": DuelRules.type_key(c)})
	var hero: LoadoutItem = DuelDeck.find_hero(d.hero_id)
	return {"id": d.id, "name": d.display_name, "hero_id": d.hero_id, "hero_name": hero.display_name if hero != null else "",
			"preset": d.preset, "plan": d.plan, "picks": rows, "doctrine_trait": d.doctrine_trait,
			"trait": DuelRules.main_trait(d), "curve": v["summary"]["curve"], "status": v["status"],
			"status_text": v["status_text"], "ok": v["ok"], "created": d.created, "edited": d.edited}


# =============================================================================
# Saved decks
# =============================================================================

func decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: DuelDeck in DuelProfile.decks(_profile()):
		out.append(deck_view(d))
	return out


## A fresh, editable copy of a saved deck, or the preset itself (read-only: copy() it). Null = unknown.
func deck(id: StringName) -> DuelDeck:
	var p: DuelDeck = preset(id)
	if p != null:
		return p
	return DuelProfile.find(_profile(), id)


func new_deck(from_preset: StringName = &"", hero_id: StringName = &"") -> DuelDeck:
	var src: DuelDeck = preset(from_preset) if from_preset != &"" else null
	var d: DuelDeck = src.copy() if src != null else DuelDeck.new()
	if src != null:
		d.display_name = (src.display_name + " copy").left(config().name_max_length)
	if hero_id != &"":
		d.set_hero(hero_id)
	return d


func save_deck(d: DuelDeck) -> Dictionary:
	var r: Dictionary = DuelProfile.save(_profile(), d, mini(MAX_DECKS, config().max_saved_decks), config().name_max_length)
	if r["ok"]:
		_save_profile(r["profile"])
		decks_changed.emit()
	return {"ok": r["ok"], "id": r["id"], "reason": r["reason"]}


func copy_deck(id: StringName) -> Dictionary:
	var src: DuelDeck = deck(id)
	if src == null:
		return {"ok": false, "id": &"", "reason": "Unknown deck", "deck": null}
	var d: DuelDeck = src.copy()
	d.display_name = (src.display_name + " copy").left(config().name_max_length)
	var r: Dictionary = save_deck(d)
	r["deck"] = d if r["ok"] else null
	return r


func delete_deck(id: StringName) -> bool:
	var r: Dictionary = DuelProfile.delete(_profile(), id)
	if r["ok"]:
		_save_profile(r["profile"])
		decks_changed.emit()
	return r["ok"]


func slots_left() -> int:
	return maxi(0, mini(MAX_DECKS, config().max_saved_decks) - DuelProfile.decks(_profile()).size())


# =============================================================================
# Matches
# =============================================================================

## {ok, reason, match}. opponent: a preset id or &"random". seed -1 = from the clock.
func start_vs_ai(d: DuelDeck, opponent: StringName, tier: StringName, seed_value: int = -1) -> Dictionary:
	if d == null:
		return _fail("No deck")
	if tier not in TIERS:
		return _fail("Unknown difficulty")
	var why: String = DuelRules.first_error(d, config(), DuelCollection.unlocked_set(_profile()))
	if why != "":
		return _fail(why)
	var s: int = seed_value if seed_value >= 0 else int(Time.get_ticks_usec() % 2147483647)
	var opp: DuelDeck = preset(opponent)
	if opponent == RANDOM_OPPONENT or opp == null:
		if opponent != RANDOM_OPPONENT:
			return _fail("Unknown opponent")
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([s, 911])
		opp = config().presets[rng.randi_range(0, config().presets.size() - 1)]
	current = DuelMatch.vs_ai(d, opp, tier, config(), _base_config(), s)
	last_error = ""
	return {"ok": true, "reason": "", "match": current}


## {ok, reason, match}. opts: {open_pool: bool, seed: int}.
func start_hot_seat(deck_a: DuelDeck, deck_b: DuelDeck, names: Array = ["Player 1", "Player 2"], opts: Dictionary = {}) -> Dictionary:
	var n: Array = [String(names[0]) if names.size() > 0 and String(names[0]) != "" else "Player 1",
			String(names[1]) if names.size() > 1 and String(names[1]) != "" else "Player 2"]
	var coll: Dictionary = DuelCollection.unlocked_set(_profile())
	for i: int in 2:
		var d: DuelDeck = [deck_a, deck_b][i]
		if d == null:
			return _fail("%s: pick a deck" % n[i])
		var why: String = DuelRules.first_error(d, config(), coll, opts)
		if why != "":
			return _fail("%s: %s" % [n[i], why])
	var s: int = int(opts.get("seed", -1))
	if s < 0:
		s = int(Time.get_ticks_usec() % 2147483647)
	current = DuelMatch.hot_seat(deck_a, deck_b, n, config(), _base_config(), s)
	last_error = ""
	return {"ok": true, "reason": "", "match": current}


func take_current() -> DuelMatch:
	return current


## Records a finished duel (records and cosmetics only). {ok, reason, result, records, new_cosmetics}.
func finish(m: DuelMatch) -> Dictionary:
	if m == null or m.state == null or m.state.phase != MatchState.Phase.ENDED:
		return {"ok": false, "reason": "The duel isn't over", "result": {}, "records": records(), "new_cosmetics": []}
	var ids: Array = []
	for d: DuelDeck in config().presets:
		ids.append(String(d.id))
	var r: Dictionary = DuelProfile.record(_profile(), m.result(), ids)
	_save_profile(r["profile"])
	if current == m:
		current = null
	records_changed.emit()
	return {"ok": true, "reason": "", "result": m.result(), "records": r["records"], "new_cosmetics": r["new_cosmetics"]}


func records() -> Dictionary:
	return DuelProfile.records(_profile())


func _fail(why: String) -> Dictionary:
	last_error = why
	return {"ok": false, "reason": why, "match": null}


# =============================================================================
# Profile (RunState owns it; Settings.run_profile v2)
# =============================================================================

func _profile() -> Dictionary:
	var rs: Node = get_node_or_null(^"/root/RunState")
	if rs != null and rs.has_method(&"profile"):
		return rs.profile()
	return RunProfile.normalised(_profile_fallback)


func _save_profile(p: Dictionary) -> void:
	var st: Node = get_node_or_null(^"/root/Settings")
	if st != null and st.has_method(&"set_value"):
		st.set_value(&"run_profile", p)
	else:
		_profile_fallback = p
