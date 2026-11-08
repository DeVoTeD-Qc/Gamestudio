# game.gd (autoload "Game")
# Purpose: Session glue between the UI and the pure rules: owns the saved DDProfile and the
#   current DDRun, and records district clears / run ends into the profile (meta unlocks).
#   dd-feel: owns the sound bank (/root/Game/Sfx, scripts/fx/dd_sfx.gd) and applies the profile's
#   Settings (volumes to the Master / SFX buses; screen shake and reduce motion read by the UI).
#   dd-save: owns the mid-run save (DDRunSave, user://deaddraw_run.json): written after every run
#   event and on screen changes, cleared when the run ends; resume_run() / abandon_run().
# Dependencies: DDBalance, DDRun, DDProfile, DDRunSave, scripts/fx/dd_sfx.gd.
# Author: Mechanics Developer Agent
extends Node

signal run_started
signal run_finished(won: bool)
## dd-feel: a Settings value changed (key, new value).
signal settings_changed(key: String, value: Variant)

const SfxBank: GDScript = preload("res://scripts/fx/dd_sfx.gd")

var bal: DDBalance
var profile: DDProfile
## dd-save: the mid-run save file and the screen the UI last reported for it.
var run_save: DDRunSave = DDRunSave.new()
var save_screen: String = "STREET"
var run: DDRun = null
var survivor_id: String = "rosa"
## Unlock keys earned during the current run ("perk:x", "survivor:x", "badge:x").
var new_unlocks: Array[String] = []
var _recorded_clears: int = 0
var _run_recorded: bool = false


## v3: a v2 mid-run save was found and discarded at startup (the title shows a note once).
var discarded_old_run: bool = false


func _ready() -> void:
	bal = DDBalance.get_default()
	profile = DDProfile.new(bal)
	profile.load_profile()
	discarded_old_run = run_save.discard_old()
	var bank: Node = SfxBank.new()
	bank.name = "Sfx"
	add_child(bank)
	apply_settings()


# ---------------------------------------------------------------- settings (dd-feel)
## Pushes the profile's volumes to the audio buses.
func apply_settings() -> void:
	if profile == null:
		return
	SfxBank.apply_volumes(float(profile.setting("master_volume")), float(profile.setting("sfx_volume")))


## Changes a setting, saves the profile and applies it.
func set_setting(key: String, value: Variant) -> void:
	if profile == null or not profile.set_setting(key, value):
		return
	apply_settings()
	settings_changed.emit(key, profile.setting(key))


## Reduce motion: the player's choice, else the browser's prefers-reduced-motion (web only).
func reduce_motion() -> bool:
	if profile != null and bool(profile.setting("motion_chosen")):
		return bool(profile.setting("reduce_motion"))
	if profile != null and bool(profile.setting("reduce_motion")):
		return true
	return _browser_reduced_motion()


## Screen shake on (and not suppressed by reduce motion).
func screen_shake() -> bool:
	return profile != null and bool(profile.setting("screen_shake")) and not reduce_motion()


var _browser_rm: int = -1


func _browser_reduced_motion() -> bool:
	if _browser_rm < 0:
		_browser_rm = 0
		if OS.has_feature("web"):
			var m: Variant = JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches", true)
			_browser_rm = 1 if m == true else 0
	return _browser_rm == 1


func start_run(survivor: String, seed_value: int = -1) -> void:
	survivor_id = survivor
	new_unlocks.clear()
	_recorded_clears = 0
	_run_recorded = false
	run = DDRun.new(bal)
	run.changed.connect(_on_run_changed)
	run.start(survivor, seed_value)
	save_screen = "MAP"
	save_run()
	run_started.emit()


## dd-save: writes the run in progress (or clears the file when it is over).
func save_run(screen_hint: String = "") -> void:
	if screen_hint != "":
		save_screen = screen_hint
	if run_save != null and run != null:
		run_save.save(run, save_screen)


func has_saved_run() -> bool:
	return run_save != null and not run_save.load_run(bal).is_empty()


## dd-save: resumes the saved run. Returns the screen to show ("" when there is nothing to resume).
func resume_run() -> String:
	var s: Dictionary = run_save.load_run(bal) if run_save != null else {}
	if s.is_empty():
		return ""
	run = s["run"]
	survivor_id = run.survivor_id
	new_unlocks.clear()
	_recorded_clears = run.cleared_ids.size()   # those clears were recorded when they happened
	_run_recorded = false
	run.changed.connect(_on_run_changed)
	save_screen = str(s["screen"])
	run_started.emit()
	return save_screen


## dd-save: drops the saved run (the title's Abandon run, after confirmation).
func abandon_run() -> void:
	if run_save != null:
		run_save.clear()
	run = null


## Called after every run event: saves first clears and the run result exactly once.
func _on_run_changed(_ev: Dictionary) -> void:
	sync_profile()
	if run != null and run.phase == DDRun.Phase.SAFEHOUSE:
		save_screen = "SAFEHOUSE"
	elif save_screen == "SAFEHOUSE" and run != null and run.phase == DDRun.Phase.STREET:
		save_screen = "MAP"
	save_run()


func sync_profile() -> void:
	if run == null:
		return
	while _recorded_clears < run.cleared_ids.size():
		new_unlocks.append_array(profile.record_district_clear(run.cleared_ids[_recorded_clears]))
		_recorded_clears += 1
	if not _run_recorded and (run.phase == DDRun.Phase.DEAD or run.phase == DDRun.Phase.WON):
		_run_recorded = true
		var won: bool = run.phase == DDRun.Phase.WON
		new_unlocks.append_array(profile.record_run_end(survivor_id, run.run_score(), won))
		run_finished.emit(won)
