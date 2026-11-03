# scene_router.gd
# Adapted from Killstreak autoload/scene_router.gd (generic part only; no match hand-off).
# Purpose: SceneRouter autoload. All scene changes go through here so a loading screen can
#   sit in front of them later. Use the SCENE_* constants, not raw paths. Add a constant when
#   a scene lands (Hub, LobbyDuel, Duel, LineupBuilder, Album, Dossier, Survey: plan section 6).
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

const SCENE_BOOT: String = "res://scenes/Boot.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"

var current_path: String = ""
## Tests: goto_scene only records the path and emits scene_change_started (no scene change).
var dry_run: bool = false
## Last path passed to goto_scene (also in dry_run).
var last_requested: String = ""


## Switches to the scene at path on the next idle frame. Returns false if it does not exist.
func goto_scene(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return false
	last_requested = path
	scene_change_started.emit(path)
	if dry_run:
		return true
	_change.call_deferred(path)
	return true


func _change(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change to %s failed (%s)" % [path, error_string(err)])
		return
	current_path = path
	scene_change_finished.emit(path)
