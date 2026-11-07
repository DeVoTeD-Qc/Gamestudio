# game.gd (autoload "Game")
# Purpose: Session glue between the UI and the pure rules: owns the saved DDProfile and the
#   current DDRun, and records district clears / run ends into the profile (meta unlocks).
#   dd-feel: owns the sound bank (/root/Game/Sfx, scripts/fx/dd_sfx.gd) and applies the profile's
#   Settings (volumes to the Master / SFX buses; screen shake and reduce motion read by the UI).
# Dependencies: DDBalance, DDRun, DDProfile, scripts/fx/dd_sfx.gd.
# Author: Mechanics Developer Agent
extends Node

signal run_started
signal run_finished(won: bool)
## dd-feel: a Settings value changed (key, new value).
signal settings_changed(key: String, value: Variant)

const SfxBank: GDScript = preload("res://scripts/fx/dd_sfx.gd")

var bal: DDBalance
var profile: DDProfile
var run: DDRun = null
var survivor_id: String = "rosa"
## Unlock keys earned during the current run ("perk:x", "survivor:x", "badge:x").
var new_unlocks: Array[String] = []
var _recorded_clears: int = 0
var _run_recorded: bool = false


func _ready() -> void:
	bal = DDBalance.get_default()
	profile = DDProfile.new(bal)
	profile.load_profile()
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
	run.start(survivor, profile.perk_pool(), seed_value)
	run_started.emit()


## Called after every run event: saves first clears and the run result exactly once.
func _on_run_changed(_ev: Dictionary) -> void:
	sync_profile()


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
