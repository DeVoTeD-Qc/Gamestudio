# duel_profile.gd
# Purpose: kc-duel-impl (duel-mode.md §6.5, §7): the Duel part of the run profile (RunProfile v2):
#   up to 8 saved decks (duel_decks: DuelDeck.to_dict rows) and the records / cosmetics (duel_records).
#   Duel gives records and cosmetics only: never a card, ticket, REQ or campaign unlock.
#   Pure static functions over the profile Dictionary; DuelState saves the result in Settings.
#   API for the screens: documentation/technical/duel-api.md §4, §7.
# Dependencies: RunProfile, DuelDeck, DuelConfig.
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelProfile
extends RefCounted

const KIND_FRAME: StringName = &"duelist_frame"
const KIND_STAMP: StringName = &"veteran_stamp"
const KIND_ALL: StringName = &"veteran_all"


# =============================================================================
# Decks
# =============================================================================

## The saved decks, slot order (DuelDeck copies; preset = false).
static func decks(p: Dictionary) -> Array[DuelDeck]:
	var out: Array[DuelDeck] = []
	for row: Variant in RunProfile.normalised(p)["duel_decks"]:
		var d: DuelDeck = DuelDeck.from_dict(row)
		if d.id != &"":
			out.append(d)
	return out


static func find(p: Dictionary, id: StringName) -> DuelDeck:
	for d: DuelDeck in decks(p):
		if d.id == id:
			return d
	return null


## Saves `deck` (new: next free id; existing id: replaced in its slot). Returns {ok, id, reason, profile}.
static func save(p: Dictionary, deck: DuelDeck, max_decks: int = 8, name_max: int = DuelDeck.NAME_MAX) -> Dictionary:
	p = RunProfile.normalised(p)
	if deck == null:
		return {"ok": false, "id": &"", "reason": "No deck", "profile": p}
	if deck.preset:
		return {"ok": false, "id": &"", "reason": "Preset: copy to edit", "profile": p}
	var rows: Array = p["duel_decks"]
	var at: int = -1
	for i: int in rows.size():
		if typeof(rows[i]) == TYPE_DICTIONARY and StringName(str(rows[i].get("id", ""))) == deck.id and deck.id != &"":
			at = i
	if at < 0 and rows.size() >= max_decks:
		return {"ok": false, "id": &"", "reason": "%d decks saved: delete one first" % max_decks, "profile": p}
	var now: int = int(Time.get_unix_time_from_system())
	if at < 0:
		deck.id = _next_id(rows)
		deck.created = now
	deck.edited = now
	deck.display_name = deck.display_name.strip_edges().left(name_max)
	if deck.display_name.is_empty():
		deck.display_name = DuelRules.default_name(deck, name_max)
	if at < 0:
		rows.append(deck.to_dict())
	else:
		rows[at] = deck.to_dict()
	return {"ok": true, "id": deck.id, "reason": "", "profile": p}


static func delete(p: Dictionary, id: StringName) -> Dictionary:
	p = RunProfile.normalised(p)
	var rows: Array = p["duel_decks"]
	for i: int in rows.size():
		if typeof(rows[i]) == TYPE_DICTIONARY and StringName(str(rows[i].get("id", ""))) == id:
			rows.remove_at(i)
			return {"ok": true, "profile": p}
	return {"ok": false, "profile": p}


static func _next_id(rows: Array) -> StringName:
	var n: int = 1
	var used: Dictionary = {}
	for r: Variant in rows:
		if typeof(r) == TYPE_DICTIONARY:
			used[str(r.get("id", ""))] = true
	while used.has("deck_%d" % n):
		n += 1
	return StringName("deck_%d" % n)


# =============================================================================
# Records and cosmetics
# =============================================================================

static func blank_records() -> Dictionary:
	return {"heroes": {}, "vs_ai": {}, "hot_seat_games": 0, "duelist_frames": [], "veteran_stamps": []}


static func records(p: Dictionary) -> Dictionary:
	var r: Variant = RunProfile.normalised(p)["duel_records"]
	var out: Dictionary = blank_records()
	if typeof(r) == TYPE_DICTIONARY:
		for k: String in out.keys():
			if (r as Dictionary).has(k) and typeof(r[k]) == typeof(out[k]):
				out[k] = r[k]
			elif (r as Dictionary).has(k) and typeof(out[k]) == TYPE_INT and typeof(r[k]) == TYPE_FLOAT:
				out[k] = int(r[k])
	return out


## Records a finished DuelMatch result (DuelMatch.result()). Returns {profile, records, new_cosmetics}.
## `presets` = the preset ids (for "beat every preset on Veteran").
static func record(p: Dictionary, res: Dictionary, presets: Array = []) -> Dictionary:
	p = RunProfile.normalised(p)
	var rec: Dictionary = records(p)
	var new_cos: Array[Dictionary] = []
	var heroes: Array = res.get("heroes", [&"", &""])
	if StringName(res.get("kind", &"")) == &"hot_seat":
		rec["hot_seat_games"] = int(rec["hot_seat_games"]) + 1
		for h: Variant in heroes:
			if String(h) != "":
				var row: Dictionary = _wld(rec["heroes"], String(h))
				row["games"] = int(row.get("games", 0)) + 1
	else:
		var w: int = int(res.get("winner_side", -1))
		var key: String = "w" if w == 0 else ("l" if w == 1 else "d")
		var hero: String = String(heroes[0]) if heroes.size() > 0 else ""
		var opp: String = String((res.get("decks", ["", ""]) as Array)[1])
		var tier: String = String(res.get("tier", ""))
		if hero != "":
			var hr: Dictionary = _wld(rec["heroes"], hero)
			hr[key] = int(hr[key]) + 1
		if opp != "" and tier != "":
			if not (rec["vs_ai"] as Dictionary).has(opp):
				rec["vs_ai"][opp] = {}
			var tr: Dictionary = _wld(rec["vs_ai"][opp], tier)
			tr[key] = int(tr[key]) + 1
		if w == 0:
			if hero != "" and hero not in rec["duelist_frames"]:
				(rec["duelist_frames"] as Array).append(hero)
				new_cos.append({"kind": KIND_FRAME, "id": StringName(hero), "name": "Duelist frame",
						"text": "Won a duel with this hero: its Duelist banner frame."})
			if tier == "veteran" and opp != "" and opp not in rec["veteran_stamps"]:
				(rec["veteran_stamps"] as Array).append(opp)
				new_cos.append({"kind": KIND_STAMP, "id": StringName(opp), "name": "Veteran stamp",
						"text": "Beat this preset on Veteran."})
				var all: bool = not presets.is_empty()
				for pid: Variant in presets:
					all = all and String(pid) in rec["veteran_stamps"]
				if all:
					new_cos.append({"kind": KIND_ALL, "id": &"all", "name": "Every preset on Veteran",
							"text": "Beat every preset on Veteran."})
	p["duel_records"] = rec
	return {"profile": p, "records": rec, "new_cosmetics": new_cos}


static func _wld(parent: Dictionary, key: String) -> Dictionary:
	if not parent.has(key) or typeof(parent[key]) != TYPE_DICTIONARY:
		parent[key] = {"w": 0, "l": 0, "d": 0}
	return parent[key]
