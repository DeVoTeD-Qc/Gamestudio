# dd_run_save.gd
# Purpose: dd-save. The mid-run save: the whole DDRun (DDRun.to_dict(), RNG state included) plus
#   which screen the player was on, in its own file next to the profile (user://, IndexedDB on the
#   Web). Save version 5 (DeadDraw v4 rules, run data "v": 4). Written after every run event and on
#   screen changes; cleared when the run ends (death / win) or is abandoned. A missing, corrupt or
#   unusable file reads as "no saved run" and never crashes. An older version (save 4 = a v3 run:
#   crowbar melee, points carried between districts; save 3 and older = v2 runs) can't be played
#   under the v4 rules: discard_old() removes it and the title says so once.
# Dependencies: DDRun, DDBalance, DDText.
# Author: Mechanics Developer Agent
class_name DDRunSave
extends RefCounted

const DEFAULT_PATH: String = "user://deaddraw_run.json"
const VERSION: int = 5

var path: String = DEFAULT_PATH


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


## Saves a run in progress. screen: the UI screen to come back to ("STREET", "MAP", "SAFEHOUSE").
## A finished run (dead / won) clears the file instead.
func save(run: DDRun, screen: String = "STREET") -> bool:
	if run == null or run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON:
		clear()
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("DDRunSave: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify({"version": VERSION, "screen": screen, "saved_at": Time.get_unix_time_from_system(), "run": run.to_dict()}))
	f.close()
	return true


func exists() -> bool:
	return FileAccess.file_exists(path)


## {run: DDRun, screen: String} or {} when there is no usable saved run.
func load_run(bal: DDBalance = null) -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	var d: Variant = (parsed as Dictionary).get("run", null)
	if not d is Dictionary:
		return {}
	var run: DDRun = DDRun.from_dict(d, bal)
	if run == null or run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON:
		return {}
	return {"run": run, "screen": str((parsed as Dictionary).get("screen", "STREET"))}


## One line for the title's Continue button: survivor, district, wave, HP.
func summary(bal: DDBalance = null) -> String:
	var s: Dictionary = load_run(bal)
	if s.is_empty():
		return ""
	var run: DDRun = s["run"]
	var where: String = "safehouse after %s" % str(run.district().get("name", "")) if run.phase == DDRun.Phase.SAFEHOUSE \
		else ("%s, boss" % str(run.district().get("name", "")) if run.boss_street else "%s, wave %d" % [str(run.district().get("name", "")), run.wave_index + 1])
	return "%s - %s - HP %d/%d - %d pts" % [str(run.bal.survivor(run.survivor_id).get("name", run.survivor_id)), where, run.hp, run.max_hp, run.bal.shown(run.points)]


## True when the file holds a run from an older version of the game (not resumable).
func is_old() -> bool:
	if not exists():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and int((parsed as Dictionary).get("version", 0)) > 0 and int((parsed as Dictionary).get("version", 0)) < VERSION


## Deletes an older-version run. Returns true when one was discarded.
func discard_old() -> bool:
	if not is_old():
		return false
	clear()
	return true


func clear() -> void:
	if exists():
		DirAccess.remove_absolute(path)
