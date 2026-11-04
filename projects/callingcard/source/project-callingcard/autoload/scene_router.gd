# scene_router.gd
# Adapted from Killstreak autoload/scene_router.gd (generic part only; no match hand-off).
# Purpose: SceneRouter autoload. All scene changes go through here so a loading screen can
#   sit in front of them later. Use the SCENE_* constants, not raw paths (plan section 6).
#   cc13: routes for the hub and its screens. Once the player has entered the hub this session
#   (hub_entered), a request for the Title lands on the hub instead: the duel, lineup, album and
#   Dossier screens send "back" to SCENE_TITLE, and the Title is only the cold-start screen.
#   last_requested still records what was asked (tests check it); only the real change resolves.
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

const SCENE_BOOT: String = "res://scenes/Boot.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"
const SCENE_HUB: String = "res://scenes/Hub.tscn"
const SCENE_DUEL: String = "res://scenes/Duel.tscn"
const SCENE_LINEUP: String = "res://scenes/LineupBuilder.tscn"
const SCENE_ALBUM: String = "res://scenes/Album.tscn"
const SCENE_DOSSIER: String = "res://scenes/Dossier.tscn"
const SCENE_LOBBY: String = "res://scenes/LobbyDuel.tscn"
const SCENE_MATCH_STARTING: String = "res://scenes/LobbyMatchStarting.tscn"

## Short route ids (hub buttons, tests) -> scene paths.
const ROUTES: Dictionary = {
	&"title": SCENE_TITLE, &"hub": SCENE_HUB, &"duel": SCENE_DUEL, &"lineup": SCENE_LINEUP,
	&"album": SCENE_ALBUM, &"dossier": SCENE_DOSSIER, &"lobby": SCENE_LOBBY,
	&"match_starting": SCENE_MATCH_STARTING,
}

var current_path: String = ""
## Tests: goto_scene only records the path and emits scene_change_started (no scene change).
var dry_run: bool = false
## Last path passed to goto_scene (also in dry_run).
var last_requested: String = ""
## True once the hub was shown this session: "back to the Title" then lands on the hub.
var hub_entered: bool = false
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
	_change.call_deferred(resolve(path))
	return true


## Route by id (ROUTES). Returns false for an unknown id or a scene that isn't there.
func goto_route(route: StringName) -> bool:
	return ROUTES.has(route) and goto_scene(ROUTES[route])


## True when the route's scene exists (the hub disables buttons for screens not built yet).
func has_route(route: StringName) -> bool:
	return ROUTES.has(route) and ResourceLoader.exists(ROUTES[route])


## The scene a request really opens (the Title becomes the hub after the hub was entered).
func resolve(path: String) -> String:
	if path == SCENE_TITLE and hub_entered and ResourceLoader.exists(SCENE_HUB):
		return SCENE_HUB
	return path


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
