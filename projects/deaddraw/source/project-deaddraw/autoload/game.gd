# game.gd (autoload "Game")
# Purpose: Session glue between the UI and the pure rules: owns the saved DDProfile and the
#   current DDRun, and records district clears / run ends into the profile (meta unlocks).
# Dependencies: DDBalance, DDRun, DDProfile.
# Author: Mechanics Developer Agent
extends Node

signal run_started
signal run_finished(won: bool)

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
