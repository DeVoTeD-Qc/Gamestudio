# playtest_log.gd
# Purpose: PlaytestLog autoload. Listens to EventBus and appends one JSON object per
#   line to user://playtest_log.jsonl. Stub for p01; event hooks land in p16.
# Dependencies: EventBus.
# Author: Mechanics Developer Agent
extends Node

const LOG_PATH: String = "user://playtest_log.jsonl"

## Off by default so tests and editor runs do not write files.
var enabled: bool = false
var session_started_ms: int = 0


func _ready() -> void:
	session_started_ms = Time.get_ticks_msec()


## Appends one event line. No-op while disabled.
func log_event(event_name: StringName, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry: Dictionary = data.duplicate()
	entry["event"] = String(event_name)
	entry["t_ms"] = Time.get_ticks_msec() - session_started_ms
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file == null:
		push_warning("PlaytestLog: cannot open %s" % LOG_PATH)
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
