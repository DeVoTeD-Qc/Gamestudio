# test_smoke.gd
# Adapted from CallingCard tests/test_smoke.gd (CardZone screens and signals).
# Purpose: cz03 smoke tests: project settings, autoloads, scenes load and instance, Title text,
#   Boot route, SceneRouter, Settings and the screen profile, web export preset.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const AUTOLOADS: Array[String] = ["EventBus", "Settings", "SceneRouter"]


func test_project_settings() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "CardZone", "name")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "renderer")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility", "mobile renderer")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "height")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "sensor landscape")
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Boot.tscn", "main scene")
	assert_false(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), "no touch from mouse")
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "touch -> mouse")
	for action: String in ["confirm", "cancel", "inspect"]:
		assert_true(InputMap.has_action(action), "input action %s" % action)


func test_autoloads_present_in_order() -> void:
	var root: Window = tree.root
	var last_index: int = -1
	for autoload_name: String in AUTOLOADS:
		var node: Node = root.get_node_or_null(autoload_name)
		assert_not_null(node, "autoload %s" % autoload_name)
		if node != null:
			assert_true(node.get_index() > last_index, "autoload order at %s" % autoload_name)
			last_index = node.get_index()


func test_event_bus_declares_match_signals() -> void:
	var bus: Node = tree.root.get_node("EventBus")
	for sig: String in ["screen_shown", "match_started", "round_started", "turn_started", "rules_event",
			"shot_resolved", "brace_requested", "match_ended"]:
		assert_true(bus.has_signal(sig), "EventBus.%s" % sig)


func test_scenes_load_and_instance() -> void:
	for path: String in ["res://scenes/Boot.tscn", "res://scenes/Title.tscn"]:
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, "load %s" % path)
		if packed != null:
			var inst: Node = packed.instantiate()
			assert_not_null(inst, "instance %s" % path)
			if inst != null:
				inst.free()


func test_title_shows_name_and_prototype_line() -> void:
	var title: Control = (load("res://scenes/Title.tscn") as PackedScene).instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	assert_eq((title.get_node("%TitleLabel") as Label).text, "CardZone", "title")
	assert_eq((title.get_node("%SubtitleLabel") as Label).text, "Prototype build", "subtitle")
	title.queue_free()
	await tree.process_frame


func test_boot_routes_to_title() -> void:
	var boot_script: GDScript = load("res://scripts/ui/boot.gd")
	assert_eq(boot_script.first_scene(), "res://scenes/Title.tscn", "boot target")


func test_scene_router_dry_run() -> void:
	var router: Node = tree.root.get_node("SceneRouter")
	router.dry_run = true
	assert_true(router.goto_scene(router.SCENE_TITLE), "known scene accepted")
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "last requested")
	assert_false(router.goto_scene("res://scenes/DoesNotExist.tscn"), "missing scene refused")
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "missing scene not recorded")
	assert_true(router.has_route(&"title"), "title route")
	assert_false(router.goto_route(&"no_such_route"), "unknown route refused")
	router.dry_run = false


func test_settings_values() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var seen: Array[int] = [0]
	var on_changed: Callable = func() -> void: seen[0] += 1
	settings.settings_changed.connect(on_changed)
	assert_true(settings.set_value(&"fast_animations", true), "known key")
	assert_true(settings.fast_animations, "value applied")
	assert_eq(seen[0], 1, "settings_changed emitted")
	assert_false(settings.set_value(&"no_such_key", 1), "unknown key refused")
	settings.set_value(&"fast_animations", false)
	settings.settings_changed.disconnect(on_changed)
	assert_eq(settings.ui_scale, 1.0, "default ui scale")


func test_screen_profile_desktop_and_phone() -> void:
	assert_eq(ScreenProfile.base_size(Vector2(1280, 720), 1.0), Vector2(1280, 720), "desktop base")
	# iPhone 844x390 pt landscape at @3x.
	var phone_px: Vector2 = Vector2(2532, 1170)
	var base: Vector2 = ScreenProfile.base_size(phone_px, 3.0)
	assert_eq(base, Vector2(960, 540), "phone base")
	assert_true(ScreenProfile.logical_size(phone_px, base).y < ScreenProfile.COMPACT_HEIGHT, "phone is compact")
	assert_true(ScreenProfile.points_per_px(phone_px, 3.0) >= 0.72, "phone px >= 0.72 pt")


func test_web_export_preset() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg parses")
	assert_eq(cfg.get_value("preset.0", "platform", ""), "Web", "web preset")
	assert_true(String(cfg.get_value("preset.0", "include_filter", "")).contains("assets/fonts/*.txt"), "font licence included")
	assert_false(cfg.get_value("preset.0.options", "variant/thread_support", true), "single-threaded")
	assert_eq(cfg.get_value("preset.0.options", "html/custom_html_shell", ""), "res://web/shell.html", "custom shell")
	assert_true(FileAccess.file_exists("res://web/shell.html"), "shell present")
