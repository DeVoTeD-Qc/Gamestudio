# scene_router.gd
# Purpose: SceneRouter autoload. All scene changes go through here so the loading
#   screen (p17) can sit in front of them. Use the SCENE_* constants, not raw paths.
#   It also carries the run's match hand-off (p11, see "Run match hand-off" below).
# Dependencies: scripts/ui/run/run_flow.gd (match hand-off only).
# Author: Mechanics Developer Agent (run match hand-off: UI/UX Agent, p11)
extends Node

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")

const SCENE_BOOT: String = "res://scenes/Boot.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"
const SCENE_LOADOUT: String = "res://scenes/run/Loadout.tscn"
const SCENE_RUN_MAP: String = "res://scenes/run/RunMap.tscn"
const SCENE_MATCH: String = "res://scenes/Match.tscn"
const SCENE_AFTER_ACTION: String = "res://scenes/run/AfterAction.tscn"
const SCENE_REWARD: String = "res://scenes/run/Reward.tscn"
const SCENE_RUN_END: String = "res://scenes/run/RunEnd.tscn"
const SCENE_TUTORIAL: String = "res://scenes/tutorial/Tutorial.tscn"

var current_path: String = ""
## Tests: goto_scene only records the path and emits scene_change_started (no scene change).
var dry_run: bool = false
## Last path passed to goto_scene (also in dry_run).
var last_requested: String = ""


## Switches to the scene at path on the next idle frame.
func goto_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return
	last_requested = path
	scene_change_started.emit(path)
	if dry_run:
		return
	_change.call_deferred(path)


func _change(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change to %s failed (%s)" % [path, error_string(err)])
		return
	current_path = path
	scene_change_finished.emit(path)


# =============================================================================
# Run match hand-off (p11)
# =============================================================================
# RunMap -> Match -> AfterAction. The contract for scenes/Match.tscn (MatchController):
#   1. On load, call SceneRouter.take_pending_match(). If it returns a MatchState, play THAT
#      match (do not build the local test match): it was made by RunState.create_match() from
#      the run (deck, loadout, perks, killstreaks, squad + bracket scaling, mode, map, seed) and
#      is NOT started yet, so call m.start_match() once the screen is wired to it.
#      null = no run match (scene opened on its own): keep the local test match.
#   2. When the match has ended (m.phase == MatchState.Phase.ENDED, m.result set and
#      m.hooks.mode_rules.outcome filled) and the player has seen the result, call
#      SceneRouter.finish_run_match(m) exactly once. It records the result on the run
#      (RunState.finish_match), keeps the After-Action report in last_match_report and routes
#      to AfterAction. is_run_match(m) tells the controller whether to do this.
#   3. Emitting EventBus.match_started / match_ended stays with the match controller.

## The run's next match, created by RunMap and waiting for Match.tscn to take it.
var pending_match: MatchState = null
## The run match Match.tscn is playing (set by take_pending_match, cleared by finish_run_match).
var active_match: MatchState = null
## After-Action report of the last finished run match (RunFlow.record_match).
var last_match_report: Dictionary = {}


## RunMap: create the current run match and open Match.tscn with it. Returns the MatchState
## (null when the run has no match to play).
func start_run_match(hooks: MatchHooks = null) -> MatchState:
	var rs: Node = get_node_or_null("/root/RunState")
	var m: MatchState = rs.create_match(hooks) if rs != null else null
	if m == null:
		return null
	pending_match = m
	goto_scene(SCENE_MATCH)
	return m


## Match.tscn: takes the pending run match (once). null = not a run match.
func take_pending_match() -> MatchState:
	var m: MatchState = pending_match
	pending_match = null
	if m != null:
		active_match = m
	return m


## True when m is the run match handed to Match.tscn (so it must call finish_run_match).
func is_run_match(m: MatchState) -> bool:
	return m != null and m == active_match


## Match.tscn: the run match is over. Records it on the run and opens AfterAction.
func finish_run_match(m: MatchState) -> Dictionary:
	if m == null or m != active_match:
		push_warning("SceneRouter: finish_run_match called for a match that is not the run's")
		return {"ok": false, "reason": "not the run match"}
	active_match = null
	last_match_report = RunFlow.record_match(m)
	if last_match_report.get("ok", false):
		goto_scene(SCENE_AFTER_ACTION)
	return last_match_report


## Forced result (debug menu, tests): records it like a finished match and opens AfterAction.
func finish_run_match_forced(result: StringName, outcome: Dictionary = {}, stats: Dictionary = {}) -> Dictionary:
	pending_match = null
	active_match = null
	last_match_report = RunFlow.record_forced(result, outcome, stats)
	if last_match_report.get("ok", false):
		goto_scene(SCENE_AFTER_ACTION)
	return last_match_report
