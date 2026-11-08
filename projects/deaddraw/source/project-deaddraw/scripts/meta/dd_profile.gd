# dd_profile.gd
# Purpose: Meta progression saved to user:// (IndexedDB on the Web export): first clears,
#   unlocked survivors and perks, best score and Survivor's Mark badges per survivor.
#   Milestones and what they unlock come from balance.json extra_rules.unlocks:
#     "maple_row" / "downtown" / ... = first clear of that district id, "win" = win a run.
#     Values: "perk:<id>", "survivor:<id>", "badge" (Survivor's Mark on the survivor played).
#   dd-feel: also the player's Settings (data.settings, see SETTING_DEFAULTS): master / SFX volume
#   (linear 0..1), screen shake, reduce motion (+ whether the player chose it, else it follows the
#   browser's prefers-reduced-motion).
#   v3 (K5): first-run hints. data.hints_seen lists the hint ids already shown; hints only show
#   while no run has ended yet (data.runs == 0), each one once.
#   v2 (save version 2): DeadDraw v2 scores are points (x10 on screen), so a version-1 save keeps
#   every clear, unlock, badge, run count and setting, but its best scores move to "best_v1"
#   (shown as the old record) and v2 bests start fresh.
# Dependencies: DDBalance.
# Author: Mechanics Developer Agent
class_name DDProfile
extends RefCounted

const DEFAULT_PATH: String = "user://deaddraw_profile.json"
const VERSION: int = 2
## dd-feel: Settings keys and their defaults (types are enforced on load and on set).
const SETTING_DEFAULTS: Dictionary = {"master_volume": 0.8, "sfx_volume": 0.8, "screen_shake": true,
	"reduce_motion": false, "motion_chosen": false}

var path: String = DEFAULT_PATH
var bal: DDBalance
var data: Dictionary = {}


func _init(balance: DDBalance = null, save_path: String = DEFAULT_PATH) -> void:
	bal = balance if balance != null else DDBalance.get_default()
	path = save_path
	reset()


func reset() -> void:
	data = {"version": VERSION, "cleared": [], "unlocked_perks": [], "unlocked_survivors": [],
		"best": {}, "best_v1": {}, "badges": {}, "runs": 0, "wins": 0, "hints_seen": [], "settings": SETTING_DEFAULTS.duplicate()}


func load_profile() -> bool:
	reset()
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var from_version: int = int((parsed as Dictionary).get("version", 1))
	for k: String in data:
		if k == "settings" or k == "version":
			continue
		if (parsed as Dictionary).has(k):
			data[k] = parsed[k]
	if from_version < 2:
		# v1 run scores (10 + HP per district) are not comparable with v2 points
		data["best_v1"] = data["best"] if data["best"] is Dictionary else {}
		data["best"] = {}
	for k: String in ["cleared", "unlocked_perks", "unlocked_survivors", "hints_seen"]:
		if not data[k] is Array:
			data[k] = []
	for k: String in ["best", "best_v1", "badges"]:
		if not data[k] is Dictionary:
			data[k] = {}
	data["version"] = VERSION
	var saved: Variant = (parsed as Dictionary).get("settings", {})
	if saved is Dictionary:
		for k: String in SETTING_DEFAULTS:
			if (saved as Dictionary).has(k):
				_put_setting(k, saved[k])
	return true


# ---------------------------------------------------------------- settings (dd-feel)
## A setting's value (its default when unknown or never set).
func setting(key: String) -> Variant:
	return (data["settings"] as Dictionary).get(key, SETTING_DEFAULTS.get(key))


## Sets a setting (volumes clamped to 0..1, bools coerced) and saves. False for an unknown key.
func set_setting(key: String, value: Variant) -> bool:
	if not SETTING_DEFAULTS.has(key):
		push_warning("DDProfile: unknown setting %s" % key)
		return false
	_put_setting(key, value)
	if key == "reduce_motion":
		(data["settings"] as Dictionary)["motion_chosen"] = true
	save()
	return true


func _put_setting(key: String, value: Variant) -> void:
	var d: Variant = SETTING_DEFAULTS[key]
	var v: Variant
	if d is bool:
		v = bool(value)
	else:
		v = clampf(float(value), 0.0, 1.0)
	(data["settings"] as Dictionary)[key] = v


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


## The best score from a version-1 (DeadDraw v1) save, 0 if none.
func best_v1(survivor: String) -> int:
	return int((data["best_v1"] as Dictionary).get(survivor, 0))


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


# ---------------------------------------------------------------- first-run hints (K5)
## True while this is the player's first run (no run has ended yet).
func first_run() -> bool:
	return int(data.get("runs", 0)) == 0


## Should hint `id` show now? (first run only, each hint once)
func hint_due(id: String) -> bool:
	return first_run() and not (data["hints_seen"] as Array).has(id)


func mark_hint(id: String) -> void:
	if not (data["hints_seen"] as Array).has(id):
		(data["hints_seen"] as Array).append(id)
		save()


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
