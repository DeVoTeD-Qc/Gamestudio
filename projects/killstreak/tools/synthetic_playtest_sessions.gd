# synthetic_playtest_sessions.gd
# Purpose: p20 helper. Produces SYNTHETIC "Download log" files for testing tools/kpi_sheet.py.
#   It runs the real PlaytestLog autoload headless and drives it the way the game does: the
#   real RunState starts runs, records results and makes reward offers (so run_start, tickets,
#   offer_shown, reward_pick and run_end come from real code), and the match / round / card /
#   tutorial / screen signals are emitted on EventBus with the same arguments match_controller.gd,
#   tutorial_director.gd and the run screens use. Surveys go through record_pre_survey /
#   record_end_survey, and every export through PlaytestLog.export_log().
#
#   One persistent log on one simulated iPhone, four launches (the log on a device keeps every
#   session, so each export holds all sessions so far; the KPI tool must de-duplicate):
#     S1  first launch: consent, pre-survey (shooter + card weekly), full tutorial with one long
#         stall, a full 5-match run, end survey, Download log  -> export 1 (.jsonl, as downloaded)
#     S2  second launch: no tutorial, run lost on tickets (3 losses), outcome preview and pause
#         used, rounds with nothing played, end survey with one skipped statement, Download log
#         -> export 2, renamed to .json (the upload workaround in playtest-guide.md)
#     S3  third launch: two matches, then the tab is hidden mid-match (no run end, no survey,
#         no export: the game only offers Download log after a finished run)
#     S4  fourth launch: a new run won on the Rival, end survey, Download log -> export 3
#   These are NOT player data. Two things are simulated:
#     - time: the logger reads the engine clock, so the driver moves PlaytestLog's session start
#       back to fake minutes of play (t_ms), sets the run's play time, and recomputes
#       next_match_clicked.seconds_after_end from t_ms at export;
#     - device: a headless run reports a desktop with no browser, so each session_start's device
#       fields are patched to an iPhone in Safari, embedded in the claude.ai page, after export.
#   Files are named SYNTHETIC-*.jsonl / .json; tools/kpi_sheet.py leaves them out unless
#   --include-synthetic is passed.
#
# Usage (from source/project-killstreak; no game code change):
#   godot --headless --path . -s ../../tools/synthetic_playtest_sessions.gd -- --out=<dir>
# Writes nothing to a real log or run save: the logger and RunState are pointed at
#   user://synthetic_playtest/, which is deleted afterwards.
# Author: Data Scientist Agent
extends SceneTree

const WORK_DIR: String = "user://synthetic_playtest"
const MODES: Array[StringName] = [&"zone_control", &"firefight"]
const MAP: StringName = &"port_vasel"
const UNITS: Array[StringName] = [&"rifleman", &"breacher", &"marksman", &"gunner", &"flanker",
		&"shieldman", &"combat_medic", &"point_man", &"recon_specialist", &"sentry"]
const TACTICS: Array[StringName] = [&"suppressing_fire", &"flank_route", &"callout",
		&"hold_the_line", &"ammo_resupply", &"breach_and_clear", &"tripwire_charge", &"comms_relay"]
const ENEMY: Array[StringName] = [&"rifleman", &"gunner", &"breacher", &"sentry", &"demolitions_expert"]
const TUTORIAL_STEPS: int = 17
const IPHONE: Dictionary = {
	"platform": "Web", "os_family": "ios", "web": true, "browser": "safari", "standalone": false,
	"embedded": true, "mobile": true, "touchscreen": true, "device_class": "phone",
	"screen": {"window_px": [2532, 1170], "points": [844, 390], "pixel_ratio": 3.0,
		"base": [1280, 720], "logical": [1280, 591], "pt_per_px": 0.659, "ui_scale": 1.0,
		"compact": true, "orientation": "landscape"},
}

var plog: Node
var bus: Node
var rs: Node
var out_dir: String = ""
var sim_s: float = 0.0
var _uid: int = 100
var _run_start_s: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir == "":
		push_error("pass -- --out=<directory>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_rng.seed = 20
	plog = root.get_node("PlaytestLog")
	bus = root.get_node("EventBus")
	rs = root.get_node("RunState")
	rs.autosave = false
	rs.save_path = WORK_DIR.path_join("run_save.json")
	plog.log_path = WORK_DIR.path_join("playtest_log.jsonl")
	plog.consent_path = WORK_DIR.path_join("consent.cfg")
	plog.delete_log()
	plog.enabled = false
	plog.consent_answered = false
	plog.pre_survey = {}
	var written: Array[String] = []
	_launch(9200)
	_session_1()
	written.append(_export("SYNTHETIC-1-iphone-first-session.jsonl"))
	_launch(4100)
	_session_2()
	written.append(_export("SYNTHETIC-2-iphone-renamed-to-json.json"))
	_launch(3800)
	_session_3()
	_launch(3900)
	_session_4()
	written.append(_export("SYNTHETIC-3-iphone-sessions-1-to-4.jsonl"))
	plog.delete_log()
	plog.enabled = false
	for f: String in DirAccess.get_files_at(WORK_DIR):
		DirAccess.remove_absolute(WORK_DIR.path_join(f))
	DirAccess.remove_absolute(WORK_DIR)
	for p: String in written:
		print("wrote %s" % p)
	quit(0)


# =============================================================================
# Plumbing
# =============================================================================

## A page load: a new anonymous session; consent is either asked (first launch) or loaded.
func _launch(load_ms: int) -> void:
	plog.flush()
	plog.enabled = false
	plog.new_session()
	plog.set("_load_ms", load_ms)
	sim_s = 0.0
	_at(load_ms / 1000.0)
	if not plog.consent_answered:
		bus.screen_shown.emit(&"consent")
		_wait(14.0)
		plog.set_consent(true)
	else:
		plog.set_consent(true, false)   # load_consent() on a later launch
	plog.log_event(&"input_type", {"kind": "touch"})


## Exports through the real export_log() (log_exported line + file) and copies the file into
## out_dir under `name`. Lines are kept byte for byte except two simulated-value patches:
##   - session_start gets the iPhone device fields (headless reports a desktop);
##   - next_match_clicked.seconds_after_end is recomputed from t_ms (the logger measures it with
##     the real engine clock, which a headless run cannot move back far enough).
func _export(name: String) -> String:
	_wait(6.0)
	var result: Dictionary = plog.export_log()
	if not result["ok"]:
		push_error("export failed: %s" % result["error"])
	var lines: PackedStringArray = []
	var last_end_ms: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(String(result["path"])).split("\n", false):
		var e: Dictionary = JSON.parse_string(line)
		var sid: String = e["sid"]
		if e["event"] == "match_end":
			last_end_ms[sid] = int(e["t_ms"])
		elif e["event"] == "session_start":
			for key: String in IPHONE:
				e[key] = IPHONE[key]
			line = _restringify(e, ["schema", "consent_version", "load_ms"])
		elif e["event"] == "next_match_clicked" and last_end_ms.has(sid):
			e["seconds_after_end"] = snappedf((int(e["t_ms"]) - int(last_end_ms[sid])) / 1000.0, 0.1)
			line = _restringify(e, [])
		lines.append(line)
	DirAccess.remove_absolute(String(result["path"]))
	var f: FileAccess = FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return name


## JSON.parse_string turns every number into a float; put the logger's ints back before writing.
func _restringify(e: Dictionary, int_keys: Array) -> String:
	for key: String in ["v", "seq", "t_ms"] + int_keys:
		e[key] = int(e[key])
	return JSON.stringify(e)


## Moves the simulated clock to `s` seconds into the session.
func _at(s: float) -> void:
	sim_s = s
	plog.session_started_ms = Time.get_ticks_msec() - int(s * 1000.0)


func _wait(s: float) -> void:
	_at(sim_s + s)


func _screen(name: StringName, dwell: float = 3.0) -> void:
	bus.screen_shown.emit(name)
	_wait(dwell)


func _tutorial(stall_step: int, stall_s: float) -> void:
	_screen(&"title", 5.0)
	_screen(&"tutorial", 2.0)
	for step: int in range(1, TUTORIAL_STEPS + 1):
		bus.tutorial_step.emit(step)
		_wait(stall_s if step == stall_step else _rng.randf_range(8.0, 22.0))
	_screen(&"title", 4.0)


func _start_run(killstreaks: Array) -> void:
	_screen(&"loadout", 25.0)
	rs.start_run(_rng.randi() % 100000)
	rs.set_killstreaks(killstreaks)
	rs.begin_run()
	_run_start_s = sim_s
	_screen(&"run_map", 6.0)


## One match. plan: per round [player_cards, unspent_supply, player_score, enemy_score].
## ks: killstreak id used in round ks_round ("" = none). op_down: rounds the Operator went down.
func _match(result: StringName, plan: Array, round_s: float, ks: StringName = &"",
		ks_round: int = 0, op_down: Array = [], preview: bool = false, pause: bool = false) -> void:
	var run: Object = rs.run
	var md: Resource = run.current_match()
	var mode: StringName = MODES[int(md.get("mode"))]
	var start_s: float = sim_s
	bus.screen_shown.emit(&"match")
	bus.match_started.emit(mode, MAP, int(run.match_index))
	_screen(&"mulligan", 9.0)
	bus.screen_shown.emit(&"match")
	var streak: int = 0
	var ps: int = 0
	var es: int = 0
	var hand: int = 5
	for i: int in plan.size():
		var r: int = i + 1
		var row: Array = plan[i]
		bus.round_started.emit(r)
		if preview and r == 1:
			bus.preview_toggled.emit(true)
		if pause and r == 2:
			bus.screen_shown.emit(&"pause")
			_wait(20.0)
			bus.screen_shown.emit(&"match")
		for c: int in int(row[0]):
			var pool: Array[StringName] = TACTICS if c == 2 else UNITS
			bus.card_deployed.emit(&"player", pool[_rng.randi() % pool.size()], [&"left", &"mid", &"right"][c % 3])
		hand = clampi(hand + 2 - int(row[0]), 1, 8)
		bus.card_deployed.emit(&"enemy", ENEMY[_rng.randi() % ENEMY.size()], [&"left", &"mid", &"right"][_rng.randi() % 3])
		_wait(round_s * _rng.randf_range(0.8, 1.2))
		var kills: int = maxi(0, int(row[2]) - ps)
		for k: int in kills:
			streak += 1
			bus.streak_changed.emit(streak)
			bus.unit_eliminated.emit(_next_uid(), _next_uid(), &"mid", false)
			if streak == 2:
				bus.killstreak_earned.emit(ks if ks != &"" else &"recon_drone", r)
		if ks != &"" and r == ks_round:
			bus.killstreak_used.emit(ks, r)
			bus.unit_eliminated.emit(_next_uid(), -1, &"right", true)
		if r in op_down:
			bus.unit_eliminated.emit(_next_uid(), _next_uid(), &"left", false)
			bus.operator_down.emit(&"player", r)
			streak = 0
			bus.streak_changed.emit(0)
		ps = int(row[2])
		es = int(row[3])
		bus.round_summary.emit(r, int(row[1]), hand)
		bus.round_ended.emit(r, ps, es)
	if preview:
		bus.preview_toggled.emit(false)
	bus.screen_shown.emit(&"match_end")
	bus.match_ended.emit(result, plan.size(), sim_s - start_s)
	_wait(5.0)
	rs.run.play_time_s = sim_s - _run_start_s   # RunState times the run with the real clock
	rs.record_result({&"win": &"player", &"loss": &"enemy"}.get(result, &"draw"),
			{"rounds": plan.size(), "player_score": ps, "enemy_score": es})
	_screen(&"after_action", 12.0)


## Takes every pending offer (index, or -1 to skip), then goes on to the next match after `gap` s.
func _offers_then_next(picks: Array, gap: float) -> void:
	var i: int = 0
	while not rs.current_offer().is_empty():
		bus.screen_shown.emit(&"reward")
		_wait(10.0)
		var pick: int = int(picks[i]) if i < picks.size() else 0
		if pick < 0:
			rs.skip_offer()
		else:
			rs.choose_offer(pick)
		i += 1
	if rs.run.is_over():
		return
	_screen(&"run_map", 2.0)
	_wait(maxf(0.0, gap - 14.0))
	bus.next_match_requested.emit()


func _run_end_and_survey(q: Array, open: String) -> void:
	_screen(&"run_end", 18.0)
	rs.abandon_run()
	_screen(&"end_survey", 4.0)
	var answers: Dictionary = {"open": open}
	for i: int in q.size():
		if q[i] != null:
			answers["q%d" % (i + 1)] = q[i]
		_wait(4.0)
	_wait(30.0)
	plog.record_end_survey(answers)


func _next_uid() -> int:
	_uid += 1
	return _uid


# =============================================================================
# Sessions
# =============================================================================

func _session_1() -> void:
	_screen(&"pre_survey", 10.0)
	plog.record_pre_survey(true, true, false)
	_tutorial(9, 78.0)
	_start_run([&"recon_drone", &"mortar_barrage", &"attack_helo"])
	_match(&"win", [[2, 1, 1, 0], [3, 0, 2, 1], [2, 0, 3, 1], [3, 0, 4, 2]], 48.0, &"recon_drone", 3, [2])
	_offers_then_next([1], 22.0)
	_match(&"win", [[2, 2, 0, 1], [3, 0, 2, 1], [3, 1, 3, 2], [2, 0, 4, 2]], 52.0, &"mortar_barrage", 4)
	_offers_then_next([0, 2], 31.0)
	_match(&"loss", [[2, 1, 1, 1], [1, 3, 1, 3], [2, 1, 2, 4], [3, 0, 2, 5]], 61.0, &"", 0, [2, 3])
	_offers_then_next([2], 95.0)
	_match(&"win", [[3, 0, 1, 0], [2, 1, 3, 1], [3, 0, 4, 1]], 50.0, &"attack_helo", 2)
	_offers_then_next([0, 1], 12.0)
	_match(&"win", [[2, 1, 1, 1], [3, 0, 2, 2], [3, 0, 3, 2], [2, 1, 3, 3], [3, 0, 5, 3]], 58.0, &"attack_helo", 4, [3])
	_offers_then_next([], 0.0)
	_run_end_and_survey([4, 4, 4, 5, 4], "Would like a kill-cam replay of the last firefight.")


func _session_2() -> void:
	_screen(&"title", 6.0)
	_start_run([&"recon_drone", &"sentry_turret", &"attack_helo"])
	_match(&"loss", [[1, 3, 0, 1], [0, 4, 1, 2], [2, 1, 1, 3], [2, 0, 1, 4]], 74.0, &"", 0, [1, 3], true, true)
	_offers_then_next([-1], 48.0)
	_match(&"win", [[2, 1, 1, 0], [3, 0, 2, 1], [2, 1, 3, 2], [3, 0, 4, 2]], 55.0, &"recon_drone", 3, [], true)
	_offers_then_next([0], 18.0)
	_match(&"loss", [[2, 2, 0, 1], [0, 3, 0, 2], [2, 1, 1, 3], [3, 0, 2, 4]], 66.0, &"", 0, [2])
	_offers_then_next([1, 0], 140.0)
	_match(&"loss", [[2, 1, 1, 1], [2, 1, 1, 2], [1, 2, 2, 3], [2, 0, 2, 4]], 63.0, &"sentry_turret", 3, [2, 4])
	_offers_then_next([], 0.0)
	_run_end_and_survey([3, 2, 4, null, 3], "I did not see why my rifleman lost the mid lane.")


func _session_3() -> void:
	_screen(&"title", 5.0)
	_start_run([&"recon_drone", &"mortar_barrage", &"attack_helo"])
	_match(&"win", [[3, 0, 1, 0], [2, 1, 2, 1], [3, 0, 4, 1]], 46.0, &"recon_drone", 2)
	_offers_then_next([0], 9.0)
	_match(&"draw", [[2, 1, 1, 1], [3, 0, 2, 2], [2, 1, 3, 3], [2, 0, 4, 4], [3, 0, 4, 4]], 52.0, &"mortar_barrage", 4, [3])
	_offers_then_next([1], 26.0)
	bus.screen_shown.emit(&"match")
	bus.match_started.emit(&"zone_control", MAP, int(rs.run.match_index))
	bus.round_started.emit(1)
	bus.card_deployed.emit(&"player", &"rifleman", &"mid")
	_wait(40.0)
	plog.log_event(&"app_hidden", {"screen": "match", "session_s": sim_s})
	plog.flush()
	rs.abandon_run()


func _session_4() -> void:
	_screen(&"title", 4.0)
	_start_run([&"recon_drone", &"mortar_barrage", &"attack_helo"])
	_match(&"win", [[3, 0, 1, 0], [3, 0, 3, 0], [2, 1, 4, 1]], 40.0, &"recon_drone", 2)
	_offers_then_next([0], 8.0)
	_match(&"win", [[2, 1, 1, 0], [3, 0, 2, 1], [3, 0, 4, 1]], 44.0, &"mortar_barrage", 3)
	_offers_then_next([1, 1], 11.0)
	_match(&"win", [[3, 0, 1, 1], [2, 0, 3, 1], [3, 0, 4, 2]], 47.0, &"attack_helo", 3, [2])
	_offers_then_next([0], 7.0)
	_match(&"loss", [[2, 1, 0, 1], [3, 0, 1, 2], [2, 2, 2, 3], [3, 0, 3, 4]], 57.0, &"recon_drone", 2, [1])
	_offers_then_next([2, 0], 15.0)
	_match(&"win", [[3, 0, 1, 0], [3, 0, 2, 1], [2, 1, 3, 2], [3, 0, 5, 2]], 55.0, &"attack_helo", 3)
	_offers_then_next([], 0.0)
	_run_end_and_survey([5, 4, 4, 5, 5], "")
