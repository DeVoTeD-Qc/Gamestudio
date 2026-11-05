# test_smoke.gd
# Purpose: p01 smoke tests. Autoloads are registered and live, core scenes load
#   and instantiate, and key project settings match the web plan.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const AUTOLOADS: PackedStringArray = [
	"EventBus", "CardDB", "RunState", "PlaytestLog", "SceneRouter", "Settings",
]


func test_autoloads_registered_in_project() -> void:
	for autoload_name: String in AUTOLOADS:
		var key: String = "autoload/%s" % autoload_name
		assert_true(ProjectSettings.has_setting(key), "%s missing from project.godot" % key)


func test_autoloads_live_in_tree() -> void:
	for autoload_name: String in AUTOLOADS:
		var node: Node = tree.root.get_node_or_null(autoload_name)
		assert_not_null(node, "autoload %s not in /root" % autoload_name)
		if node != null:
			var expected: String = String(ProjectSettings.get_setting("autoload/%s" % autoload_name)).trim_prefix("*")
			assert_eq(node.get_script().resource_path, expected, "%s script" % autoload_name)


func test_event_bus_declares_core_signals() -> void:
	var bus: Node = tree.root.get_node_or_null("EventBus")
	assert_not_null(bus, "EventBus missing")
	if bus == null:
		return
	for sig: String in ["card_revealed", "shot_fired", "unit_eliminated", "streak_changed",
			"operator_down", "killstreak_earned", "match_started", "run_ended"]:
		assert_true(bus.has_signal(sig), "EventBus lacks signal %s" % sig)


func test_run_state_defaults() -> void:
	var run_state: Node = tree.root.get_node_or_null("RunState")
	assert_not_null(run_state, "RunState missing")
	if run_state != null:
		assert_eq(run_state.get("matches_total"), 5, "matches per run")
		assert_eq(run_state.get("tickets"), 3, "tickets")


func test_boot_scene_instantiates() -> void:
	_check_scene("res://scenes/Boot.tscn", "Boot")


func test_title_scene_instantiates() -> void:
	_check_scene("res://scenes/Title.tscn", "Title")
	var scene: PackedScene = load("res://scenes/Title.tscn")
	var node: Node = scene.instantiate()
	assert_not_null(node.get_node_or_null("%StartButton"), "Title has no StartButton")
	node.free()


func test_project_settings_for_web() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Boot.tscn", "main scene")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "renderer")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility", "mobile renderer")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "viewport width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "viewport height")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "mouse from touch")
	for action: String in ["confirm", "cancel", "inspect", "end_turn", "toggle_preview", "fast_forward"]:
		assert_true(InputMap.has_action(action), "input action %s" % action)
		assert_false(InputMap.action_get_events(action).is_empty(), "input action %s has no events" % action)


func _check_scene(path: String, root_name: String) -> void:
	assert_true(ResourceLoader.exists(path), "%s missing" % path)
	var scene: PackedScene = load(path) as PackedScene
	assert_not_null(scene, "%s did not load" % path)
	if scene == null:
		return
	var node: Node = scene.instantiate()
	assert_not_null(node, "%s did not instantiate" % path)
	if node != null:
		assert_eq(node.name, StringName(root_name), "%s root name" % path)
		node.free()


func test_boot_routes_to_title() -> void:
	var err: Error = tree.change_scene_to_file("res://scenes/Boot.tscn")
	assert_eq(err, OK, "change to Boot")
	# Boot waits one frame, then SceneRouter changes scene deferred; allow a few frames.
	for i: int in 6:
		await tree.process_frame
	assert_not_null(tree.current_scene, "no current scene after boot")
	if tree.current_scene != null:
		assert_eq(tree.current_scene.name, &"Title", "scene after Boot")
	var router: Node = tree.root.get_node_or_null("SceneRouter")
	if router != null:
		assert_eq(router.get("current_path"), "res://scenes/Title.tscn", "SceneRouter.current_path")
	tree.unload_current_scene()
