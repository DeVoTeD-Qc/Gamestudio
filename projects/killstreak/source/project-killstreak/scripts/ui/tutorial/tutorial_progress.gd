# tutorial_progress.gd
# Purpose: Remembers whether this player has finished or skipped the tutorial (p15), so the
#   Title screen can auto-offer it on first launch only. Stored in user://tutorial.cfg
#   (section "tutorial": completed, skipped, last_step). Static, no autoload needed:
#     const TutorialProgress := preload("res://scripts/ui/tutorial/tutorial_progress.gd")
#     if TutorialProgress.should_offer(): ...show the "Play the tutorial?" prompt...
# Dependencies: none.
# Author: UI/UX Agent (p15)
extends RefCounted

const DEFAULT_PATH: String = "user://tutorial.cfg"
const SECTION: String = "tutorial"

static var path: String = DEFAULT_PATH


## Tests point the record at a scratch file ("" = the default).
static func use_path(p_path: String) -> void:
	path = p_path if p_path != "" else DEFAULT_PATH


## True until the tutorial was completed or skipped once (first launch).
static func should_offer() -> bool:
	var cfg: ConfigFile = _load()
	return not bool(cfg.get_value(SECTION, "completed", false)) and not bool(cfg.get_value(SECTION, "skipped", false))


static func is_completed() -> bool:
	return bool(_load().get_value(SECTION, "completed", false))


static func is_skipped() -> bool:
	return bool(_load().get_value(SECTION, "skipped", false))


## Records the end of a tutorial attempt. completed = played to the end (else skipped).
static func record(completed: bool, last_step: int) -> void:
	var cfg: ConfigFile = _load()
	if completed:
		cfg.set_value(SECTION, "completed", true)
	else:
		cfg.set_value(SECTION, "skipped", true)
	cfg.set_value(SECTION, "last_step", last_step)
	var err: Error = cfg.save(path)
	if err != OK:
		push_warning("TutorialProgress: could not save %s (%s)" % [path, error_string(err)])


## Forgets the record (tests, a future "replay tutorial" option).
static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _load() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	return cfg
