# run_profile.gd
# Purpose: The between-runs profile of run-v2.md §7-§8 as a plain Dictionary (stored in
#   Settings.run_profile, saved with the settings): runs finished / won, the boss reached, bosses beaten,
#   Operators won with, Hardcore wins, best Threat, the Terrains / events / bosses seen (Dossier), the
#   last boss (V3: never the same twice in a row). Pure static functions; RunState feeds them.
#   kc-duel-impl: versioned (PROFILE_VERSION 2). v2 adds the Duel keys: found_cards (card ids met in a
#   campaign run: the Duel collection, D3), duel_decks (up to 8 saved DuelDeck dicts) and duel_records
#   (DuelProfile). A v1 profile (no "version") migrates by keeping every value and adding the new keys.
#   Unlock ids (LoadoutItem.unlock, RunMatchData.unlock, RunModifiers.TABLE[].unlock):
#     ""                  from the start (Kestrel, Meridian_Six)
#     first_run_done      a run ended (win or lose): Longreach .338, Bulwark Prime
#     boss_reached        the boss reached once: Wasp-9
#     first_win           a run won: Bastion-60, Hardcore
#     first_boss_win      = first_win (the boss is the last fight): The Hollow Choir
#     two_operator_wins   runs won with 2 different Operators: Austerity
#     all_bosses_beaten   Meridian, Prime and the Choir beaten: Veteran Crews
#     hardcore_win        a run won with Hardcore: Fog of War
#     all_terrains_seen   all 10 Terrains played on: Hot Ground
# Dependencies: TerrainRules, RunModifiers.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name RunProfile
extends RefCounted

const UNLOCK_TEXTS: Dictionary = {
	&"": "", &"first_run_done": "Finish a run", &"boss_reached": "Reach the boss once", &"first_win": "Win a run",
	&"first_boss_win": "Beat a boss", &"two_operator_wins": "Win a run with 2 different Operators",
	&"all_bosses_beaten": "Beat all three bosses", &"hardcore_win": "Win a run with Hardcore",
	&"all_terrains_seen": "Play on all 10 Terrains",
}
const BOSS_IDS: Array[StringName] = [&"meridian", &"prime", &"choir"]
## kc-duel-impl: profile save version (1 = the unversioned kc-v2-impl profile).
const PROFILE_VERSION: int = 2


## A blank profile with every key (missing keys of an older profile read as these).
static func blank() -> Dictionary:
	return {"runs_finished": 0, "run_wins": 0, "boss_reached": 0, "boss_wins": {}, "operator_wins": [],
			"hardcore_wins": 0, "best_threat": -1, "terrains_seen": [], "events_seen": [], "bosses_seen": [],
			"last_boss": "", "version": PROFILE_VERSION, "found_cards": [], "duel_decks": [], "duel_records": {}}


## kc-duel-impl: the version a stored profile was written with (1 when it has none).
static func version_of(p: Variant) -> int:
	if typeof(p) != TYPE_DICTIONARY or not (p as Dictionary).has("version"):
		return 1
	return int(p["version"]) if typeof(p["version"]) in [TYPE_INT, TYPE_FLOAT] else 1


## kc-duel-impl: true when `p` predates PROFILE_VERSION (RunState back-fills found_cards once).
static func needs_migration(p: Variant) -> bool:
	return typeof(p) == TYPE_DICTIONARY and not (p as Dictionary).is_empty() and version_of(p) < PROFILE_VERSION


static func normalised(p: Variant) -> Dictionary:
	var out: Dictionary = blank()
	if typeof(p) != TYPE_DICTIONARY:
		return out
	for k: String in out.keys():
		if p.has(k) and typeof(p[k]) == typeof(out[k]):
			out[k] = p[k]
		elif p.has(k) and typeof(out[k]) == TYPE_INT and typeof(p[k]) == TYPE_FLOAT:
			out[k] = int(p[k])
	# v1 -> v2 (kc-duel-impl): the old values stay, the Duel keys start empty; the result is v2.
	out["version"] = PROFILE_VERSION
	# kc-ui-bands: retired level-band ids (the old camo-ladder names, MasteryBands.LEGACY) load as the
	# new ones (gold_leaf / machined / prism / starfield) wherever a band is stored.
	MasteryBands.migrate(out)
	return out


## kc-duel-impl: adds card ids to found_cards (the Duel collection). Returns the profile.
static func add_found_cards(p: Dictionary, ids: Array) -> Dictionary:
	p = normalised(p)
	var found: Array = p["found_cards"]
	for id: Variant in ids:
		var s: String = String(id)
		if s != "" and s not in found:
			found.append(s)
	return p


## True when the profile meets unlock `id` (&"" = always).
static func is_unlocked(p: Dictionary, id: StringName) -> bool:
	p = normalised(p)
	match id:
		&"":
			return true
		&"first_run_done":
			return int(p["runs_finished"]) >= 1
		&"boss_reached":
			return int(p["boss_reached"]) >= 1
		&"first_win", &"first_boss_win":
			return int(p["run_wins"]) >= 1
		&"two_operator_wins":
			return (p["operator_wins"] as Array).size() >= 2
		&"all_bosses_beaten":
			for b: StringName in BOSS_IDS:
				if int((p["boss_wins"] as Dictionary).get(String(b), 0)) <= 0:
					return false
			return true
		&"hardcore_win":
			return int(p["hardcore_wins"]) >= 1
		&"all_terrains_seen":
			for t: StringName in TerrainRules.ALL:
				if String(t) not in p["terrains_seen"]:
					return false
			return true
	return false


static func unlock_text(id: StringName) -> String:
	return String(UNLOCK_TEXTS.get(id, ""))


## The first run (fixed map, Kestrel, Meridian, no modifiers) until a run has ended.
static func is_first_run(p: Dictionary) -> bool:
	return int(normalised(p)["runs_finished"]) == 0


## V3: the run's boss, drawn (seeded) from the unlocked bosses, never the last run's (unless it is the
## only one). The first run is always Meridian_Six.
static func pick_boss(p: Dictionary, cfg: RunConfig, rng: RandomNumberGenerator) -> StringName:
	p = normalised(p)
	if is_first_run(p) or cfg.bosses.is_empty():
		return cfg.bosses[0].boss_id if not cfg.bosses.is_empty() else &""
	var pool: Array[StringName] = []
	for b: RunMatchData in cfg.bosses:
		if b != null and is_unlocked(p, b.unlock):
			pool.append(b.boss_id)
	if pool.size() > 1:
		pool.erase(StringName(String(p["last_boss"])))
	if pool.is_empty():
		return cfg.bosses[0].boss_id
	return pool[rng.randi_range(0, pool.size() - 1)]


## Records what a played match showed (Terrains, the boss) for the Dossier. Returns the profile.
static func record_match(p: Dictionary, terrain: Array, boss_id: StringName) -> Dictionary:
	p = normalised(p)
	for t: Variant in terrain:
		if String(t) != "" and String(t) not in p["terrains_seen"]:
			(p["terrains_seen"] as Array).append(String(t))
	if boss_id != &"":
		if String(boss_id) not in p["bosses_seen"]:
			(p["bosses_seen"] as Array).append(String(boss_id))
	return p


static func record_event(p: Dictionary, event_id: StringName) -> Dictionary:
	p = normalised(p)
	if event_id != &"" and String(event_id) not in p["events_seen"]:
		(p["events_seen"] as Array).append(String(event_id))
	return p


## A run ended: counts, the boss, Operator / Hardcore wins, best Threat. Returns {profile, unlocked:
## [{kind, id, name, text}]} (what this run unlocked; `operators` / `bosses` / `modifiers` are the
## candidates: [{id, name, unlock}]).
static func record_run_end(p: Dictionary, run: RunProgress, operators: Array, bosses: Array) -> Dictionary:
	p = normalised(p)
	var before: Dictionary = p.duplicate(true)
	p["runs_finished"] = int(p["runs_finished"]) + 1
	var reached: bool = false
	for h: Dictionary in run.history:
		if bool(h.get("rival", false)):
			reached = true
	if reached:
		p["boss_reached"] = int(p["boss_reached"]) + 1
	if run.boss != &"":
		p["last_boss"] = String(run.boss)
	if run.is_victory():
		p["run_wins"] = int(p["run_wins"]) + 1
		var bw: Dictionary = p["boss_wins"]
		bw[String(run.boss)] = int(bw.get(String(run.boss), 0)) + 1
		if String(run.primary) not in p["operator_wins"]:
			(p["operator_wins"] as Array).append(String(run.primary))
		if RunModifiers.HARDCORE in run.modifiers:
			p["hardcore_wins"] = int(p["hardcore_wins"]) + 1
		p["best_threat"] = maxi(int(p["best_threat"]), run.threat())
	var unlocked: Array[Dictionary] = []
	for row: Dictionary in operators:
		_note_unlock(unlocked, before, p, &"operator", row)
	for row: Dictionary in bosses:
		_note_unlock(unlocked, before, p, &"boss", row)
	for id: StringName in RunModifiers.ALL:
		var t: Dictionary = RunModifiers.TABLE[id]
		_note_unlock(unlocked, before, p, &"modifier", {"id": id, "name": t["name"], "unlock": t["unlock"], "text": t["text"]})
	return {"profile": p, "unlocked": unlocked}


static func _note_unlock(out: Array[Dictionary], before: Dictionary, after: Dictionary, kind: StringName, row: Dictionary) -> void:
	var u: StringName = StringName(row.get("unlock", &""))
	if u != &"" and not is_unlocked(before, u) and is_unlocked(after, u):
		out.append({"kind": kind, "id": StringName(row["id"]), "name": String(row.get("name", "")), "text": String(row.get("text", ""))})
