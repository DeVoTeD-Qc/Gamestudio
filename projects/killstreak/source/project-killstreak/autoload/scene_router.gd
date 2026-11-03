# scene_router.gd
# Purpose: SceneRouter autoload. All scene changes go through here so the loading
#   screen (p17) can sit in front of them. Use the SCENE_* constants, not raw paths.
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

const SCENE_BOOT: String = "res://scenes/Boot.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"

var current_path: String = ""


## Switches to the scene at path on the next idle frame.
func goto_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return
	scene_change_started.emit(path)
	_change.call_deferred(path)


func _change(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change to %s failed (%s)" % [path, error_string(err)])
		return
	current_path = path
	scene_change_finished.emit(path)
