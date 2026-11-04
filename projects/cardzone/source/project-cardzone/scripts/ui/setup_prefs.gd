# setup_prefs.gd
# Pattern adapted from Killstreak scripts/ui/tutorial/tutorial_progress.gd (static ConfigFile
#   record, read on every call, so nothing depends on a script's static state surviving a scene
#   change).
# Purpose: This device's CardZone shell preferences (cz13), in user://cardzone_prefs.cfg:
#   [setup]    last choices (opponent, first, route), last_human_seat (S1 Alternate),
#              next_route (S2 "Pick for me" rotation), matches_started
#   [coach]    one bool per first-match tip already shown
#   [settings] reduced_motion, event_speed (pause menu)
#   [dev]      hidden dev panel overrides {tunable: value}
#   ConfigFile keeps value types (ints, bools, arrays), so balance overrides pass
#   BalanceConfig.is_allowed() unchanged after a reload.
#   Under the headless test runner the file is user://test_shell/cardzone_prefs_<pid>.cfg and the
#   tests wipe it (reset_all), so they never touch a player's preferences.
# Usage: const SetupPrefs := preload("res://scripts/ui/setup_prefs.gd")
#        SetupPrefs.get_value("setup", "route", "rotate"); SetupPrefs.set_value("coach", "hold", true)
# Dependencies: none.
# Author: UI/UX Agent (cz13)
extends RefCounted

const DEFAULT_PATH: String = "user://cardzone_prefs.cfg"
const TEST_PATH: String = "user://test_shell/cardzone_prefs.cfg"

## "" = the default (or the test file under the test runner). Tests may point it elsewhere.
static var path_override: String = ""


static func path() -> String:
	if path_override != "":
		return path_override
	# Per process under the test runner: several agents may run the suite at once on this machine.
	return TEST_PATH.get_basename() + "_%d.cfg" % OS.get_process_id() if is_test_run() else DEFAULT_PATH


static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var cfg: ConfigFile = _load()
	return cfg.get_value(section, key) if cfg.has_section_key(section, key) else default


static func set_value(section: String, key: String, value: Variant) -> void:
	var cfg: ConfigFile = _load()
	cfg.set_value(section, key, value)
	_save(cfg)


## Every key of a section as {key: value}.
static func section(name: String) -> Dictionary:
	var cfg: ConfigFile = _load()
	var out: Dictionary = {}
	if cfg.has_section(name):
		for key: String in cfg.get_section_keys(name):
			out[key] = cfg.get_value(name, key)
	return out


static func clear_section(name: String) -> void:
	var cfg: ConfigFile = _load()
	if cfg.has_section(name):
		cfg.erase_section(name)
	_save(cfg)


## Forgets every preference (tests).
static func reset_all() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())


static func is_test_run() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var script: Script = loop.get_script() if loop != null else null
	return script != null and script.resource_path.begins_with("res://tests/")


static func _load() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(path()):
		cfg.load(path())
	return cfg


static func _save(cfg: ConfigFile) -> void:
	var dir: String = path().get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err: Error = cfg.save(path())
	if err != OK:
		push_warning("SetupPrefs: could not save %s (%s)" % [path(), error_string(err)])
