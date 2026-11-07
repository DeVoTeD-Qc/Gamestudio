# dd_profile.gd
# Purpose: Meta progression saved to user:// (IndexedDB on the Web export): first clears,
#   unlocked survivors and perks, best score and Survivor's Mark badges per survivor.
#   Milestones and what they unlock come from balance.json extra_rules.unlocks:
#     "maple_row" / "downtown" / ... = first clear of that district id, "win" = win a run.
#     Values: "perk:<id>", "survivor:<id>", "badge" (Survivor's Mark on the survivor played).
# Dependencies: DDBalance.
# Author: Mechanics Developer Agent
class_name DDProfile
extends RefCounted

const DEFAULT_PATH: String = "user://deaddraw_profile.json"
const VERSION: int = 1

var path: String = DEFAULT_PATH
var bal: DDBalance
var data: Dictionary = {}


func _init(balance: DDBalance = null, save_path: String = DEFAULT_PATH) -> void:
	bal = balance if balance != null else DDBalance.get_default()
	path = save_path
	reset()


func reset() -> void:
	data = {"version": VERSION, "cleared": [], "unlocked_perks": [], "unlocked_survivors": [],
		"best": {}, "badges": {}, "runs": 0, "wins": 0}


func load_profile() -> bool:
	reset()
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	for k: String in data:
		if (parsed as Dictionary).has(k):
			data[k] = parsed[k]
	return true


func save() -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("DDProfile: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


# ---------------------------------------------------------------- queries
func survivor_unlocked(id: String) -> bool:
	if bool(bal.survivor(id).get("unlocked", false)):
		return true
	return (data["unlocked_survivors"] as Array).has(id)


func perk_unlocked(id: String) -> bool:
	return bal.starter_perks().has(id) or (data["unlocked_perks"] as Array).has(id)


## The perks a new run may offer, in balance.json "perks" order.
func perk_pool() -> Array[String]:
	var out: Array[String] = []
	for p: String in bal.all_perks():
		if perk_unlocked(p):
			out.append(p)
	return out


func has_cleared(district_id: String) -> bool:
	return (data["cleared"] as Array).has(district_id)


func best_score(survivor: String) -> int:
	return int((data["best"] as Dictionary).get(survivor, 0))


func badges(survivor: String) -> int:
	return int((data["badges"] as Dictionary).get(survivor, 0))


## Which milestone unlocks a survivor ("" if starting / unknown). For locked-card text.
func unlock_milestone_for(kind_id: String) -> String:
	var u: Variant = bal.extra.get("unlocks", {})
	if u is Dictionary:
		for m: Variant in (u as Dictionary).keys():
			if (u[m] as Array).has(kind_id):
				return str(m)
	return ""


# ---------------------------------------------------------------- recording
## Call when a district is cleared. Returns the unlock keys that are new.
func record_district_clear(district_id: String) -> Array[String]:
	var fresh: Array[String] = []
	if has_cleared(district_id):
		return fresh
	(data["cleared"] as Array).append(district_id)
	fresh.append_array(_grant(bal.unlocks_for(district_id), ""))
	save()
	return fresh


## Call once when a run ends. Returns new unlock keys ("badge" included on a win).
func record_run_end(survivor: String, score: int, won: bool) -> Array[String]:
	var fresh: Array[String] = []
	data["runs"] = int(data["runs"]) + 1
	if score > best_score(survivor):
		(data["best"] as Dictionary)[survivor] = score
	if won:
		data["wins"] = int(data["wins"]) + 1
		fresh.append_array(_grant(bal.unlocks_for("win"), survivor))
	save()
	return fresh


func _grant(keys: Array[String], survivor: String) -> Array[String]:
	var fresh: Array[String] = []
	for key: String in keys:
		if key.begins_with("perk:"):
			var p: String = key.trim_prefix("perk:")
			if not perk_unlocked(p):
				(data["unlocked_perks"] as Array).append(p)
				fresh.append(key)
		elif key.begins_with("survivor:"):
			var s: String = key.trim_prefix("survivor:")
			if not survivor_unlocked(s):
				(data["unlocked_survivors"] as Array).append(s)
				fresh.append(key)
		elif key == "badge" and survivor != "":
			var b: Dictionary = data["badges"]
			var first: bool = int(b.get(survivor, 0)) == 0
			b[survivor] = int(b.get(survivor, 0)) + 1
			if first:
				fresh.append("badge:" + survivor)
	return fresh
