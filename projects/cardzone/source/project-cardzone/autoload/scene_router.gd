# scene_router.gd
# Adapted from CallingCard autoload/scene_router.gd (generic part only; no hub redirect).
# Purpose: SceneRouter autoload. All scene changes go through here so a loading screen can
#   sit in front of them later. Use the SCENE_* constants, not raw paths. Routes for scenes
#   that are not built yet (match setup, match, end) are listed so has_route() can report them.
#   last_requested records what was asked (tests check it).
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

const SCENE_BOOT: String = "res://scenes/Boot.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"
const SCENE_MATCH_SETUP: String = "res://scenes/MatchSetup.tscn"
const SCENE_MATCH: String = "res://scenes/Match.tscn"
const SCENE_MATCH_END: String = "res://scenes/MatchEnd.tscn"

## Short route ids (buttons, tests) -> scene paths.
const ROUTES: Dictionary = {
	&"title": SCENE_TITLE, &"match_setup": SCENE_MATCH_SETUP, &"match": SCENE_MATCH,
	&"match_end": SCENE_MATCH_END,
}

var current_path: String = ""
## Tests: goto_scene only records the path and emits scene_change_started (no scene change).
var dry_run: bool = false
## Last path passed to goto_scene (also in dry_run).
var last_requested: String = ""
## Under the headless test runner a request is recorded but the scene is not changed (a stray
## button press in a test must not swap the runner's root). Tests that need a real change set it.
var change_in_tests: bool = false


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


## Route by id (ROUTES). Returns false for an unknown id or a scene that isn't there.
func goto_route(route: StringName) -> bool:
	return ROUTES.has(route) and goto_scene(ROUTES[route])


## True when the route's scene exists (screens disable buttons for scenes not built yet).
func has_route(route: StringName) -> bool:
	return ROUTES.has(route) and ResourceLoader.exists(ROUTES[route])


func _change(path: String) -> void:
	if not change_in_tests and _is_test_run():
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change to %s failed (%s)" % [path, error_string(err)])
		return
	current_path = path
	scene_change_finished.emit(path)


static func _is_test_run() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var script: Script = loop.get_script() if loop != null else null
	return script != null and script.resource_path.begins_with("res://tests/")
