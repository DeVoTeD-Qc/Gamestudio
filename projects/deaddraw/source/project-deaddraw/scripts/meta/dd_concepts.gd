# dd_concepts.gd
# Purpose: ui-pass-3 "explain once": the concept registry (data/concepts.json) - every idea a new
#   player meets (each gun rule, zombies, damage, guns filling up, points, rooms and machines,
#   Patches, Gun Mods, bosses, Run, the safehouse...) with a short title and 1-2 plain sentences.
#   main.gd lists the concepts that are on screen and matter right now (concept_candidates); the
#   first one the player hasn't seen yet is shown once as a callout (scripts/ui/dd_callout.gd) and
#   marked seen in the profile (DDProfile.concepts_seen). The Guide (dd_codex.gd) lists every
#   concept in full, and an inspect (long press / right click) shows the concepts of the thing.
#   Text placeholders: {n:key} a balance number, {pts:key} balance points as shown, {run_where}.
# Dependencies: DDBalance, DDProfile.
# Author: UI/UX Agent (ui-pass-3)
class_name DDConcepts
extends RefCounted

const PATH: String = "res://data/concepts.json"
## At most this many callouts in a row before the player acts again (the rest wait their turn).
const PER_MOMENT: int = 3

## The parsed registry (one small JSON file, loaded once).
static var _reg: Dictionary = {}
static var _by_id: Dictionary = {}


static func registry() -> Dictionary:
	if _reg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_reg = parsed if parsed is Dictionary else {"groups": [], "concepts": []}
		_by_id = {}
		for c: Variant in _reg.get("concepts", []):
			_by_id[str((c as Dictionary).get("id", ""))] = c
	return _reg


static func ids() -> Array[String]:
	registry()
	var out: Array[String] = []
	for c: Variant in _reg.get("concepts", []):
		out.append(str((c as Dictionary).get("id", "")))
	return out


static func groups() -> Array[String]:
	var out: Array[String] = []
	for g: Variant in registry().get("groups", []):
		out.append(str(g))
	return out


static func has(id: String) -> bool:
	registry()
	return _by_id.has(id)


static func raw(id: String) -> Dictionary:
	registry()
	return _by_id.get(id, {})


static func title(id: String, bal: DDBalance = null) -> String:
	return fill(str(raw(id).get("title", id)), bal)


static func text(id: String, bal: DDBalance = null) -> String:
	return fill(str(raw(id).get("text", "")), bal)


static func icon(id: String) -> String:
	return str(raw(id).get("icon", "text:?"))


static func group(id: String) -> String:
	return str(raw(id).get("group", ""))


## The concept ids of one Guide section, in registry order.
static func in_group(g: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		if group(id) == g:
			out.append(id)
	return out


## Fills {n:key}, {pts:key} and {run_where} from the balance.
static func fill(s: String, bal: DDBalance = null) -> String:
	if not s.contains("{"):
		return s
	var b: DDBalance = bal if bal != null else DDBalance.get_default()
	var out: String = s.replace("{run_where}", "go to the bottom of the pile" if b.text("run_return") == "bottom" else "go back into the pile")
	var guard: int = 0
	while out.contains("{") and guard < 20:
		guard += 1
		var a: int = out.find("{")
		var e: int = out.find("}", a)
		if e < 0:
			break
		var tok: String = out.substr(a + 1, e - a - 1)
		var val: String = tok
		if tok.begins_with("n:"):
			val = str(b.num(tok.trim_prefix("n:")))
		elif tok.begins_with("pts:"):
			val = str(b.shown(b.num(tok.trim_prefix("pts:"))))
		out = out.substr(0, a) + val + out.substr(e + 1)
	return out


## The inspect payload for one concept (the Guide rows, a callout's "more").
static func payload(id: String, bal: DDBalance = null) -> Dictionary:
	return {"kind": "D", "tag": group(id).to_upper(), "title": title(id, bal), "t1": title(id, bal), "t2": text(id, bal), "concept": id}


## The concept for a gun rule ("down" -> "rule_down").
static func rule_id(rule: String) -> String:
	return "rule_" + rule


## The first candidate the player hasn't seen, or -1. candidates: [[id, anchor], ...] or [id, ...].
## shown_now: callouts already shown in this moment (none past PER_MOMENT).
static func pick(candidates: Array, profile: DDProfile, shown_now: int = 0) -> int:
	if profile == null or not profile.tips_on() or shown_now >= PER_MOMENT:
		return -1
	for k: int in candidates.size():
		var c: Variant = candidates[k]
		var id: String = str((c as Array)[0]) if c is Array else str(c)
		if has(id) and not profile.concept_seen(id):
			return k
	return -1
