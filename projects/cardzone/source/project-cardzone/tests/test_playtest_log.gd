# test_playtest_log.gd
# Purpose: cz18 playtest logger (autoload/playtest_log.gd), consent prompt, survey screen and the
#   title's PLAYTEST button:
#   - schema: real matches on the rules engine through MatchController (CzAI on both seats, the
#     human's seat driven through request()), one of them stopped and resumed, plus a scripted
#     match for the rare events (Frag on two targets, the human's Brace, patch up, ditch, gas,
#     final circle, elimination, coach). Every plan section 8 event is logged and every line
#     matches SCHEMA (types, enums, no extra fields),
#   - privacy: the AI's turns never carry hand ids, the human's turn_start ids are exactly the
#     human's hand, and the logger never touches the match state (EventBus data only),
#   - consent off (the default) writes nothing; the prompt's NO keeps it off, YES starts the session,
#   - the survey screen saves its answers (log line + kept on the device) and fits phone and desktop,
#   - the download builds valid JSON (one document holding every line) and the file export works,
#   - the PLAYTEST corner button shows on the title only and opens the survey.
#   Every test points the logger at user://test_playtest/ and never touches a real log or save.
# Author: Data Scientist Agent
extends "res://tests/test_case.gd"

const MatchControllerScript: GDScript = preload("res://scripts/match/match_controller.gd")
const TEST_DIR: String = "user://test_playtest"
const SURVEY_SCENE: String = "res://scenes/survey/Survey.tscn"
const PROMPT_SCENE: String = "res://scenes/survey/ConsentPrompt.tscn"

## Plan section 8 "Logged events" -> the logged event that carries it.
const PLAN_EVENTS: Dictionary = {
	"session_start": "session_start", "match_start": "match_start", "round_start": "round_start",
	"turn_start": "turn_start", "card_play": "card_play", "move": "move", "loot": "loot", "shot": "shot",
	"brace": "brace", "patch_up": "patch_up", "ditch": "ditch", "gas_hit": "gas_hit", "pack": "pack",
	"turn_end": "turn_end", "elimination": "elimination", "match_end": "match_end",
	"match_resumed": "match_resumed", "coach_step": "coach_step", "survey": "survey", "quit": "quit",
}
## Events a headless run cannot produce (real input, mobile pause / web visibility).
const NOT_DRIVEN: Array[String] = ["input_type", "app_hidden", "app_visible"]

## Logical sizes (phone 844x390 pt @3x -> 1168x540; desktop 1280x720) and a notch safe rect.
const PHONE: Dictionary = {"name": "phone 1168x540", "size": Vector2i(1168, 540), "safe": Rect2(65, 0, 1038, 511)}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "size": Vector2i(1280, 720), "safe": Rect2()}

var _saved: Dictionary = {}
var _fake_ms: int = 0


func _plog() -> Node:
	return tree.root.get_node("PlaytestLog")


func _bus() -> Node:
	return tree.root.get_node("EventBus")


## Points the autoload at a fresh test file, fresh session, logging off, fake clock.
func _setup(tag: String) -> Node:
	var plog: Node = _plog()
	_saved = {"log_path": plog.log_path, "consent_path": plog.consent_path, "enabled": plog.enabled,
			"answered": plog.consent_answered, "answers": plog.survey_answers, "auto": plog.auto_prompt,
			"clock": plog.clock}
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	plog.log_path = TEST_DIR.path_join("%s.jsonl" % tag)
	plog.consent_path = TEST_DIR.path_join("%s_consent.cfg" % tag)
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	plog.enabled = false
	plog.consent_answered = false
	plog.auto_prompt = false
	plog.survey_answers = {}
	_fake_ms = 100000
	plog.clock = func() -> int: return _fake_ms
	plog.new_session()
	return plog


func _teardown() -> void:
	var plog: Node = _plog()
	plog.flush()
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(f))
	plog.enabled = _saved["enabled"]
	plog.consent_answered = _saved["answered"]
	plog.survey_answers = _saved["answers"]
	plog.auto_prompt = _saved["auto"]
	plog.log_path = _saved["log_path"]
	plog.consent_path = _saved["consent_path"]
	plog.clock = _saved["clock"]
	plog.new_session()
	_bus().screen_shown.emit(&"test")  # drops the title corner button if a test showed it


# --- Real matches ------------------------------------------------------------------------

func _controller(level: StringName) -> Node:
	var ctrl: Node = MatchControllerScript.new()
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	ctrl.save_enabled = false
	ctrl.opponent = CzAI.for_level(level, 7)
	ctrl.meta = {"mode": "ai", "ai_level": String(level), "ai_seed": 7, "human_seat": MatchState.P1}
	tree.root.add_child(ctrl)
	return ctrl


## The human's next action from a bot (CzAI for the human's own seat; first legal one as a fallback).
func _human_action(ctrl: Node, bot: CzAI) -> Dictionary:
	var a: Dictionary = bot.choose_action(ctrl.state, ctrl.human)
	if a.is_empty() or not LoadoutRules.is_legal(ctrl.state, a):
		var legal: Array[Dictionary] = ctrl.legal()
		a = legal[0] if not legal.is_empty() else {}
	return a


## Plays the human's side until the match ends or max_actions human actions were sent. The fake
## clock moves 4 s per action and 7 s from the Pack step (first END TURN) to End turn.
func _play(ctrl: Node, bot: CzAI, max_actions: int = 100000) -> int:
	var sent: int = 0
	while not ctrl.state.is_over() and sent < max_actions:
		if not ctrl.is_human_turn():
			await tree.process_frame
			continue
		var a: Dictionary = _human_action(ctrl, bot)
		if a.is_empty():
			break
		_fake_ms += 4000
		if a["type"] == "end_turn":
			_plog().mark_pack_step()
			_fake_ms += 7000
		elif a["type"] == "brace":
			_fake_ms += 2000
		var why: String = ctrl.request(a)
		if why != "":
			push_warning("test bot action refused: %s (%s)" % [a, why])
			break
		sent += 1
	return sent


func test_schema_real_matches_and_resume() -> void:
	var plog: Node = _setup("schema")
	plog.set_consent(true, false)
	var bus: Node = _bus()
	bus.screen_shown.emit(&"title")
	bus.screen_shown.emit(&"match")
	# Privacy probe: whenever the human's turn_start is logged, compare with the human's own hand.
	var ctrl: Node = _controller(&"rookie")
	var hand_checks: Array = [0, 0]
	var probe: Callable = func(e: Dictionary) -> void:
		if e["event"] == "turn_start" and e["seat"] == "human":
			var want: Array = (ctrl.view()["me"]["hand"] as Array).map(func(c: Dictionary) -> String: return str(c["card"]))
			hand_checks[0] += 1
			if want == e["hand_ids"]:
				hand_checks[1] += 1
	plog.event_logged.connect(probe)
	var bot: CzAI = CzAI.for_level(&"rookie", 3)
	ctrl.start_new()
	await _play(ctrl, bot)
	assert_true(ctrl.state.is_over(), "match 1 played to the end")
	# Match 2 (PLAY AGAIN: no title in between) vs the Veteran, stopped after 25 human actions and resumed.
	ctrl.opponent = CzAI.for_level(&"veteran", 9)
	ctrl.meta["ai_level"] = "veteran"
	ctrl.start_new(DataEnums.Route.B)
	await _play(ctrl, bot, 25)
	var saved: MatchState = ctrl.state.clone()
	ctrl.start_resumed({"state": saved, "meta": ctrl.meta.duplicate(), "saved_at": int(Time.get_unix_time_from_system()) - 90})
	await _play(ctrl, bot)
	assert_true(ctrl.state.is_over(), "resumed match played to the end")
	plog.event_logged.disconnect(probe)
	ctrl.queue_free()
	_scripted_match(plog)
	bus.screen_shown.emit(&"survey")
	plog.record_survey({"q1": 4, "q2": 5, "q3": 0, "q4": 3, "q5": 2, "open": "More\tmaps\nplease"})
	plog.export_log()
	plog._on_quit("close")
	plog.flush()

	var entries: Array[Dictionary] = plog.read_entries()
	assert_true(entries.size() > 200, "three matches log plenty of lines (%d)" % entries.size())
	var seen: Dictionary = {}
	var bad: PackedStringArray = []
	var sid: String = plog.session_id
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		seen[e["event"]] = int(seen.get(e["event"], 0)) + 1
		bad.append_array(plog.validate_entry(e))
		if e["sid"] != sid:
			bad.append("line %d has another session id" % i)
		if int(e["seq"]) != i:
			bad.append("line %d has seq %s" % [i, e["seq"]])
	assert_eq(Array(bad.slice(0, 10)), [], "every logged line matches SCHEMA (%d problems)" % bad.size())
	for plan_name: String in PLAN_EVENTS:
		assert_true(seen.has(PLAN_EVENTS[plan_name]), "plan event %s logged" % plan_name)
	for event_name: String in plog.SCHEMA:
		if not NOT_DRIVEN.has(event_name):
			assert_true(seen.has(event_name), "schema event %s produced" % event_name)
	assert_eq(entries[0]["event"], "session_start", "session_start comes first")
	var by: Dictionary = _by_event(entries)
	# Matches.
	var starts: Array = by["match_start"]
	assert_eq(starts.size(), 3, "three match_start lines (2 real + scripted; the resume has none)")
	assert_eq([starts[0]["play_again"], starts[1]["play_again"]], [false, true], "match 2 started without the title: play again")
	assert_eq([starts[0]["route"], starts[1]["route"]], ["A", "B"], "routes")
	assert_eq([starts[0]["ai_level"], starts[1]["ai_level"]], ["rookie", "veteran"], "AI levels")
	assert_true(str(starts[0]["drop_human"]) != "" and str(starts[0]["drop_ai"]) != "", "both drops in match_start")
	assert_eq(int(starts[0]["hand_size"]), 5, "hand size")
	assert_true((starts[0]["tunables"] as Dictionary).has("hold_limit"), "tunables snapshot")
	var resumed: Dictionary = by["match_resumed"][0]
	assert_true(float(resumed["age_s"]) >= 89.0, "resume age from saved_at (%s)" % resumed["age_s"])
	assert_true(int(resumed["actions"]) > 0 and int(resumed["round"]) >= 1, "resume knows actions and round")
	var ends: Array = by["match_end"]
	assert_eq(ends.size(), 3, "three match_end lines")
	assert_eq(ends[1]["resumed"], true, "the resumed match's end is flagged")
	for e: Dictionary in ends.slice(0, 2):
		assert_true(int(e["rounds"]) >= 1 and int(e["human_turns"]) >= 1, "rounds and turns counted")
	# Turns, packs and timings from the fake clock.
	var packs: Array = by["pack"]
	assert_true(packs.size() >= 5, "packs logged (%d)" % packs.size())
	var real_pack: Dictionary = packs[0]
	assert_eq(real_pack["pack_from"], "pack_step", "pack time from the Pack step")
	assert_eq(int(real_pack["pack_ms"]), 7000, "pack_ms = Pack step to End turn on the fake clock")
	assert_eq(int(real_pack["hold_count"]), (real_pack["hold_ids"] as Array).size(), "the human's held ids are named")
	assert_true(int(by["turn_end"][0]["turn_ms"]) >= 7000, "turn_ms covers the turn")
	assert_eq(by["turn_end"].size(), packs.size(), "one turn_end per pack")
	# Privacy.
	assert_true(hand_checks[0] > 5, "human turn starts checked (%d)" % hand_checks[0])
	assert_eq(hand_checks[1], hand_checks[0], "the human's turn_start ids are exactly the human's hand")
	for e: Dictionary in by["turn_start"]:
		if e["seat"] == "ai":
			assert_eq(e["hand_ids"], [], "an AI turn_start never names its cards")
	for e: Dictionary in by["shot"]:
		assert_true(int(e["raw"]) >= int(e["damage"]), "raw >= damage (%s)" % e)
	# Rounds carry health and the Bounty.
	var r1: Dictionary = by["round_start"][0]
	assert_eq([int(r1["round"]), int(r1["health_h"]), int(r1["health_ai"]), r1["bounty"]], [1, 5, 5, "none"], "round 1 start")
	# Scripted match spot checks.
	var frag_shots: Array = by["shot"].filter(func(e: Dictionary) -> bool: return e["kind"] == "frag")
	assert_eq(frag_shots.size(), 2, "a Frag on two targets logs two shot lines")
	var on_ai: Dictionary = frag_shots[0]
	assert_eq([on_ai["target"], int(on_ai["raw"]), int(on_ai["cover"]), int(on_ai["damage"]), int(on_ai["hits"]),
			on_ai["bounty_claim"], on_ai["brace_cards"]], ["ai", 2, 0, 2, 0, false, ["duck", "duck"]], "Frag on the AI fully braced")
	var on_me: Dictionary = frag_shots[1]
	assert_eq([on_me["target"], int(on_me["hits"]), on_me["eliminated"]], ["human", 1, false], "Frag on the thrower")
	var braces: Array = by["brace"]
	var brace: Dictionary = braces[braces.size() - 2]
	assert_eq([braces.back()["kind"], braces.back()["possible"], int(braces.back()["prompt_ms"])], ["shot", false, 0], "Brace with nothing to brace with")
	assert_eq([int(brace["prompt_ms"]), brace["cards"], int(brace["eligible"]), brace["possible"], brace["suggested_used"]],
			[5000, ["plate_vest"], 2, true, null], "the human's Brace (no suggestion shown yet -> null)")
	var sp: Dictionary = by["shot"].filter(func(e: Dictionary) -> bool: return e["weapon_id"] == "p9_sidearm" and e["shooter"] == "ai").back()
	assert_eq([sp["attachments"], int(sp["raw"]), int(sp["down"]), int(sp["hits"]), sp["bounty_claim"], sp["eliminated"]],
			[["red_dot_sight"], 2, 1, 1, true, true], "AI shot with an attachment, Down, Bounty claim, elimination")
	var last_end: Dictionary = ends.back()
	assert_eq([last_end["result"], last_end["cause"], int(last_end["rounds"]), int(last_end["health_h"])], ["loss", "shot", 6, 0], "scripted match end")
	assert_eq(by["elimination"].back()["by"], "shot", "elimination by a shot")
	var coach: Array = by["coach_step"]
	assert_eq([coach[0]["step"], coach[0]["skipped"], coach[1]["skipped"]], ["hold", false, true], "coach steps")
	var survey: Dictionary = by["survey"][0]
	assert_eq([survey["q1"], survey["q2"], survey["q3"], survey["q4"], survey["q5"]], [4.0, 5.0, null, 3.0, 2.0], "survey answers (0 = skipped)")
	assert_eq(survey["open"], "More maps please", "open answer cleaned")
	assert_eq(by["quit"][0]["screen"], "survey", "quit records the screen")
	assert_eq(plog.stats["matches"], 3, "three matches counted")
	_teardown()


func _by_event(entries: Array[Dictionary]) -> Dictionary:
	var by: Dictionary = {}
	for e: Dictionary in entries:
		if not by.has(e["event"]):
			by[e["event"]] = []
		by[e["event"]].append(e)
	return by


func _card(inst: int, id: String, atts: Array = []) -> Dictionary:
	return {"id": inst, "card": id, "attachments": atts}


## A short scripted match through EventBus only, in the shape the controller sends (the human's
## view, then that action's events filtered for the human): the rare events a bot match may skip.
func _scripted_match(plog: Node) -> void:
	var bus: Node = _bus()
	bus.match_context.emit({"resumed": false, "age_s": -1.0, "mode": "ai", "ai_level": "veteran", "human_seat": 0,
			"first_seat": 0, "route": "C", "hand_size": 5, "tunables_hash": "abc123", "tunables": {"hand_size": 5},
			"actions": 0, "round": 0})
	var me: Dictionary = {"health": 5, "hand": [], "line": [], "loadout": [], "next_hand": []}
	var opp: Dictionary = {"health": 5, "line": []}
	var view: Dictionary = {"round": 0, "zone_card": 0, "bounty": -1, "me": me, "opponent": opp, "removed": [],
			"drops": {}, "last_shot": {}}
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "dropped", "seat": 1, "area": "motel"})
	bus.rules_event.emit({"type": "dropped", "seat": 0, "area": "rail_yard"})
	for r: int in range(1, 6):
		bus.rules_event.emit({"type": "round_started", "round": r})
		bus.rules_event.emit({"type": "zone_flipped", "card": r, "zone_id": "z%d" % r, "route": "C"})
	# Round 5: final circle step 1; the human's turn: Frag on an area with both seats.
	bus.rules_event.emit({"type": "final_circle", "step": 1, "hits": 1, "taken": {0: 1, 1: 1}, "health": [4, 4]})
	me["hand"] = [_card(11, "frag_grenade"), _card(12, "hit"), _card(13, "scavenge"), _card(14, "bandage"), _card(15, "dash")]
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "turn_started", "seat": 0, "round": 5})
	bus.rules_event.emit({"type": "drew", "seat": 0, "count": 5, "hits": 1, "cards": [11, 12, 13, 14, 15]})
	_fake_ms += 3000
	view["last_shot"] = {"kind": "frag", "shooter": 0, "card": _card(11, "frag_grenade"),
			"targets": {1: {"damage_before_brace": 2, "cover": 0, "down": 0, "suppressed": false},
				0: {"damage_before_brace": 2, "cover": 0, "down": 0, "suppressed": false}}}
	me["hand"] = [_card(12, "hit"), _card(13, "scavenge"), _card(14, "bandage"), _card(15, "dash")]
	me["next_hand"] = [_card(21, "plate_vest"), _card(22, "duck")]
	view["brace_prompt"] = {"damage": 2, "next_hand": me["next_hand"], "eligible": [21, 22], "kind": "frag"}
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "frag_thrown", "seat": 0, "card": 11, "area": "rail_yard",
			"targets": {1: {"damage": 2, "down": 0}, 0: {"damage": 2, "down": 0}}})
	bus.rules_event.emit({"type": "spent", "seat": 0, "card": 11, "card_id": "frag_grenade"})
	bus.rules_event.emit({"type": "brace_requested", "seat": 1, "damage": 2})
	bus.rules_event.emit({"type": "braced", "seat": 1, "cards": [31, 32], "card_ids": ["duck", "duck"], "total": 2, "hits": 0})
	bus.rules_event.emit({"type": "brace_requested", "seat": 0, "damage": 2})
	_fake_ms += 5000
	view.erase("brace_prompt")
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "braced", "seat": 0, "cards": [21], "card_ids": ["plate_vest"], "total": 1, "hits": 1})
	bus.rules_event.emit({"type": "hits_landed", "seat": 0, "count": 1, "source": "frag", "health": 3, "down": false})
	# Adrenaline, patch up, ditch, loot, move.
	me["line"] = [_card(12, "hit")]
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "adrenaline", "seat": 0, "card": 12, "mode": "search"})
	bus.rules_event.emit({"type": "patched_up", "seat": 0, "healed": 1, "health": 4})
	bus.rules_event.emit({"type": "ditched", "seat": 0, "card": 14, "card_id": "bandage"})
	bus.rules_event.emit({"type": "played", "seat": 0, "card": 15, "card_id": "dash", "move": 1, "search": 0})
	bus.rules_event.emit({"type": "moved", "seat": 0, "from": "rail_yard", "to": "motel"})
	bus.rules_event.emit({"type": "looted", "seat": 0, "card": 40, "card_id": "red_dot_sight", "source": "drop", "area": "motel", "cost": 4})
	bus.rules_event.emit({"type": "attached", "seat": 0, "attachment": 40, "weapon": 41, "attachment_id": "red_dot_sight", "weapon_id": "p9_sidearm"})
	bus.rules_event.emit({"type": "undone", "seat": 0, "action": {}})
	_fake_ms += 2000
	plog.mark_pack_step()
	_fake_ms += 6000
	bus.rules_event.emit({"type": "gas_hit", "seat": 0, "count": 1, "area": "motel", "health": 3})
	me["loadout"] = [_card(13, "scavenge"), _card(21, "plate_vest")]
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "packed", "seat": 0, "held_count": 1, "line_stowed": [12], "hand_stowed_count": 1, "held": [13], "hand_stowed": [13]})
	# The AI's turn (round 6): its shot with a Red Dot on a Down human claims the Bounty and eliminates.
	bus.rules_event.emit({"type": "turn_started", "seat": 1, "round": 6})
	bus.rules_event.emit({"type": "drew", "seat": 1, "count": 5, "hits": 0})
	bus.coach_step.emit(&"hold", false)
	bus.coach_step.emit(&"brace", true)
	view["last_shot"] = {"kind": "shot", "shooter": 1, "weapon": _card(50, "p9_sidearm", ["red_dot_sight"]),
			"targets": {0: {"damage_before_brace": 1, "cover": 0, "down": 1, "suppressed": false}}}
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "shot_declared", "seat": 1, "weapon": 50, "weapon_id": "p9_sidearm", "target": 0,
			"damage": 1, "cover": 0, "down": 1, "suppressed": false})
	bus.rules_event.emit({"type": "brace_requested", "seat": 0, "damage": 1})
	bus.rules_event.emit({"type": "braced", "seat": 0, "cards": [], "card_ids": [], "total": 0, "hits": 1})
	bus.rules_event.emit({"type": "hits_landed", "seat": 0, "count": 1, "source": "shot", "health": 0, "down": true})
	bus.rules_event.emit({"type": "bounty_claimed", "seat": 1, "from": 0, "healed": 1, "health": 5})
	bus.rules_event.emit({"type": "eliminated", "seat": 0, "cause": "shot", "nonhit_count": 4})
	bus.rules_event.emit({"type": "crate_formed", "owner": 0, "area": "motel", "cards": [13], "free_picks": 1})
	me["health"] = 0
	opp["health"] = 5
	bus.match_view_changed.emit(view)
	bus.rules_event.emit({"type": "match_ended", "result": "win", "winner": 1, "cause": "shot", "nonhit_count": [4, 9]})
	bus.match_ended.emit(1, &"shot", 6, 300.0)


# --- Privacy by construction ---------------------------------------------------------------

func test_logger_reads_eventbus_data_only() -> void:
	var src: String = ""
	for line: String in FileAccess.get_file_as_string("res://autoload/playtest_log.gd").split("\n"):
		if not line.strip_edges().begins_with("#"):
			src += line.split("#")[0] + "\n"  # code only (comments may name these things)
	assert_true(src.length() > 1000, "logger source read")
	for forbidden: String in [".state", "seats", "MatchState", "LoadoutRules", "MatchStore", "secret"]:
		assert_false(src.contains(forbidden), "the logger never touches %s (match state / hidden cards)" % forbidden)


# --- Validator -----------------------------------------------------------------------------

func test_validator_catches_bad_lines() -> void:
	var plog: Node = _plog()
	var good: Dictionary = {"v": 1, "sid": "ab", "seq": 0, "t_ms": 5, "event": "ditch", "seat": "human", "card_id": "x", "round": 2}
	assert_eq(Array(plog.validate_entry(good)), [], "good line passes")
	var extra: Dictionary = good.duplicate()
	extra["name"] = "someone"
	assert_true(plog.validate_entry(extra).size() > 0, "extra field rejected")
	var wrong_seat: Dictionary = good.duplicate()
	wrong_seat["seat"] = "player"
	assert_true(plog.validate_entry(wrong_seat).size() > 0, "seat outside human/ai rejected")
	var missing: Dictionary = good.duplicate()
	missing.erase("round")
	assert_true(plog.validate_entry(missing).size() > 0, "missing field rejected")
	assert_true(plog.validate_entry({"event": "nope"}).size() > 0, "unknown event rejected")
	var ids: Dictionary = {"v": 1, "sid": "ab", "seq": 0, "t_ms": 5, "event": "turn_start", "seat": "ai", "round": 1,
			"turn": 2, "hand_ids": [17], "hits_drawn": 0}
	assert_true(plog.validate_entry(ids).size() > 0, "instance ids instead of card ids rejected")
	var survey: Dictionary = {"v": 1, "sid": "ab", "seq": 0, "t_ms": 5, "event": "survey", "q1": 6, "q2": null,
			"q3": null, "q4": null, "q5": null, "open": "", "answered": 1}
	assert_true(plog.validate_entry(survey).size() > 0, "survey answer outside 1-5 rejected")


# --- Consent -------------------------------------------------------------------------------

func test_consent_off_logs_nothing() -> void:
	var plog: Node = _setup("off")
	assert_false(plog.enabled, "logging is off by default")
	var lines: Array = []
	var grab: Callable = func(e: Dictionary) -> void: lines.append(e)
	plog.event_logged.connect(grab)
	_scripted_match(plog)
	plog.record_survey({"q1": 3})
	plog.event_logged.disconnect(grab)
	assert_eq(lines.size(), 0, "no line produced while consent is off")
	assert_false(FileAccess.file_exists(plog.log_path), "no log file written")
	assert_eq(plog.read_all_text(), "", "log empty")
	var result: Dictionary = plog.export_log()
	assert_false(result["ok"], "nothing to download")
	# The consent prompt: NO keeps it off (and is remembered), YES starts the session.
	var prompt: CanvasLayer = (load(PROMPT_SCENE) as PackedScene).instantiate()
	prompt.plog = plog
	tree.root.add_child(prompt)
	await tree.process_frame
	assert_not_null(prompt.get_button(true), "YES button")
	prompt.get_button(false).pressed.emit()
	assert_false(plog.enabled, "NO keeps logging off")
	assert_true(plog.consent_answered, "NO is an answer (no prompt next launch)")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(plog.consent_path), OK, "answer saved")
	assert_eq(cfg.get_value("consent", "given", true), false, "saved as no")
	_bus().screen_shown.emit(&"match")
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "still nothing after NO")
	await tree.process_frame
	plog.consent_answered = false
	var prompt2: CanvasLayer = (load(PROMPT_SCENE) as PackedScene).instantiate()
	prompt2.plog = plog
	tree.root.add_child(prompt2)
	await tree.process_frame
	prompt2.get_button(true).pressed.emit()
	await tree.process_frame
	assert_true(plog.enabled, "YES turns logging on")
	var events: Array = plog.read_entries().map(func(e: Dictionary) -> String: return e["event"])
	assert_eq(events.slice(0, 3), ["session_start", "consent", "screen"], "YES starts the session (and names the screen)")
	# Withdraw: off again and the file is gone.
	plog.withdraw()
	assert_false(plog.enabled, "withdraw turns logging off")
	assert_false(FileAccess.file_exists(plog.log_path), "withdraw deletes the log")
	_teardown()


# --- Survey screen -------------------------------------------------------------------------

func _spawn_survey(plog: Node, screen_def: Dictionary) -> Array:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = screen_def["size"]
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var screen: Control = (load(SURVEY_SCENE) as PackedScene).instantiate()
	screen.plog = plog
	screen.safe_area_override = screen_def["safe"]
	viewport.add_child(screen)
	for i: int in 3:
		await tree.process_frame
	return [viewport, screen]


## Key controls visible, inside the safe area, at least 64 px tall when tappable, no overlaps.
func _layout_failures(screen: Control, screen_def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var safe: Rect2 = screen_def["safe"] if (screen_def["safe"] as Rect2).has_area() else Rect2(Vector2.ZERO, Vector2(screen_def["size"]))
	safe = safe.grow(0.5)
	var rects: Dictionary = {}
	var controls: Dictionary = screen.get_key_controls()
	for key: String in controls:
		var c: Control = controls[key]
		if c == null or not c.is_visible_in_tree():
			out.append("%s not visible" % key)
			continue
		var r: Rect2 = c.get_global_rect()
		if not safe.encloses(r):
			out.append("%s %s outside %s" % [key, r, safe])
		if (c is Button or c is LineEdit) and r.size.y < 63.5:
			out.append("%s only %.0f px tall" % [key, r.size.y])
		if c is Button or c is LineEdit:
			rects[key] = r
	var keys: Array = rects.keys()
	for i: int in keys.size():
		for j: int in range(i + 1, keys.size()):
			if (rects[keys[i]] as Rect2).grow(-0.5).intersects((rects[keys[j]] as Rect2).grow(-0.5)):
				out.append("%s overlaps %s" % [keys[i], keys[j]])
	return out


func test_survey_saves_answers() -> void:
	var plog: Node = _setup("survey")
	var setup: Array = await _spawn_survey(plog, PHONE)
	var screen: Control = setup[1]
	assert_eq(screen.get_page_name(), "OFF", "logging off -> the opt-in page")
	assert_false(plog.enabled, "opening the survey does not opt in")
	screen.get_button("ConsentButton").pressed.emit()
	assert_true(plog.enabled, "TURN ON LOGGING opts in")
	assert_eq(screen.get_page_name(), "QUESTION", "first statement")
	assert_eq(screen._statement.text, "I want to play another match.", "q1 is the play-again statement")
	screen.get_scale_button(4).pressed.emit()
	screen.get_button("SkipButton").pressed.emit()
	screen.get_scale_button(5).pressed.emit()
	screen.get_scale_button(2).pressed.emit()
	assert_eq(screen._statement.text, "The AI played fair.", "q5 is the AI fairness statement")
	screen.get_scale_button(3).pressed.emit()
	assert_eq(screen.get_page_name(), "OPEN", "open question after the five statements")
	screen.get_open_answer().text = "Holding felt good"
	screen.get_button("SubmitButton").pressed.emit()
	assert_eq(screen.get_page_name(), "DONE", "done page")
	var surveys: Array = plog.read_entries().filter(func(e: Dictionary) -> bool: return e["event"] == "survey")
	assert_eq(surveys.size(), 1, "one survey line")
	if surveys.size() == 1:
		var s: Dictionary = surveys[0]
		assert_eq([s["q1"], s["q2"], s["q3"], s["q4"], s["q5"], s["open"], s["answered"]],
				[4.0, null, 5.0, 2.0, 3.0, "Holding felt good", 4.0], "answers logged")
		assert_eq(Array(plog.validate_entry(s)), [], "survey line matches SCHEMA")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(plog.consent_path), OK, "answers saved on the device")
	assert_eq((cfg.get_value("survey", "answers", {}) as Dictionary).get("q3"), 5, "saved q3")
	await tree.process_frame
	assert_eq(_layout_failures(screen, PHONE), [] as Array[String], "done page fits the phone")
	var result: Dictionary = screen.download_log()
	assert_true(result.get("ok", false), "download from the survey screen")
	assert_true(str(screen._status.text).begins_with("Saved to"), "status says where the file went")
	(setup[0] as Node).queue_free()
	var again_setup: Array = await _spawn_survey(plog, DESKTOP)
	var again: Control = again_setup[1]
	assert_eq(again.get_page_name(), "DONE", "answered -> DONE")
	again.get_button("AgainButton").pressed.emit()
	assert_eq(again.get_page_name(), "QUESTION", "ANSWER AGAIN")
	var router: Node = tree.root.get_node("SceneRouter")
	router.last_requested = ""
	again.get_button("BackTitleButton").pressed.emit()
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "TITLE goes back to the title")
	(again_setup[0] as Node).queue_free()
	_teardown()


func test_survey_layout_phone_and_desktop() -> void:
	var plog: Node = _setup("survey_layout")
	plog.set_consent(true, false)
	for screen_def: Dictionary in [PHONE, DESKTOP]:
		var setup: Array = await _spawn_survey(plog, screen_def)
		var screen: Control = setup[1]
		for step: int in 3:
			assert_eq(_layout_failures(screen, screen_def), [] as Array[String],
					"%s page fits %s" % [screen.get_page_name(), screen_def["name"]])
			if step == 0:
				for i: int in 5:
					screen.choose(3)
			elif step == 1:
				screen.submit()
			for f: int in 2:
				await tree.process_frame
		(setup[0] as Node).queue_free()
		plog.survey_answers = {}
	plog.enabled = false
	var off_setup: Array = await _spawn_survey(plog, PHONE)
	var off: Control = off_setup[1]
	assert_eq(off.get_page_name(), "OFF", "off page")
	assert_eq(_layout_failures(off, PHONE), [] as Array[String], "OFF page fits the phone")
	(off_setup[0] as Node).queue_free()
	# The consent prompt fits the phone too.
	var vp: SubViewport = SubViewport.new()
	vp.size = PHONE["size"]
	tree.root.add_child(vp)
	var prompt: CanvasLayer = (load(PROMPT_SCENE) as PackedScene).instantiate()
	prompt.plog = plog
	vp.add_child(prompt)
	for f: int in 3:
		await tree.process_frame
	var panel: Control = prompt.get_root().find_child("ConsentPanel", true, false)
	assert_true(Rect2(Vector2.ZERO, Vector2(PHONE["size"])).encloses(panel.get_global_rect()), "consent panel fits the phone (%s)" % panel.get_global_rect())
	assert_true(prompt.get_button(true).get_global_rect().size.y >= 63.5, "YES is a full tap target")
	vp.queue_free()
	_teardown()


# --- Export --------------------------------------------------------------------------------

func test_download_builds_valid_json() -> void:
	var plog: Node = _setup("export")
	plog.set_consent(true, false)
	_bus().screen_shown.emit(&"title")
	_bus().coach_step.emit(&"brace", false)
	plog.record_survey({"q1": 5, "open": "quote \" and \\ backslash, é"})
	var text: String = plog.build_export()
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the download is one valid JSON document")
	if not parsed is Dictionary:
		_teardown()
		return
	var doc: Dictionary = parsed
	assert_eq(doc["format"], "cardzone-playtest-log", "format tag")
	assert_eq(int(doc["schema_version"]), plog.SCHEMA_VERSION, "schema version")
	assert_eq(doc["session_ids"], [plog.session_id], "one anonymous session id")
	assert_eq(int(doc["event_count"]), (doc["events"] as Array).size(), "event count")
	var bad: PackedStringArray = []
	for e: Variant in doc["events"]:
		bad.append_array(plog.validate_entry(e))
	assert_eq(Array(bad), [], "every exported event matches SCHEMA")
	var survey: Array = (doc["events"] as Array).filter(func(e: Dictionary) -> bool: return e["event"] == "survey")
	assert_eq(survey[0]["open"], "quote \" and \\ backslash, é", "free text survives the round trip")
	var result: Dictionary = plog.export_log()
	assert_true(result["ok"], "export ok")
	assert_eq(result["method"], "file", "desktop export writes a file")
	var file_text: String = FileAccess.get_file_as_string(TEST_DIR.path_join(plog.export_file_name()))
	var from_file: Variant = JSON.parse_string(file_text)
	assert_true(from_file is Dictionary and (from_file["events"] as Array).back()["event"] == "log_exported",
			"exported file parses and ends with log_exported")
	assert_true(plog.export_file_name().begins_with("cardzone-playtest-") and plog.export_file_name().ends_with(".json"), "download name")
	assert_eq(plog.session_id.length(), 12, "session id is 6 random bytes in hex")
	_teardown()


# --- Title button --------------------------------------------------------------------------

func test_title_corner_button_opens_survey() -> void:
	var plog: Node = _setup("title")
	_bus().screen_shown.emit(&"title")
	var b: Button = plog.get_title_button()
	assert_not_null(b, "PLAYTEST button on the title")
	if b != null:
		await tree.process_frame
		var vp: Rect2 = Rect2(Vector2.ZERO, b.get_viewport_rect().size)
		assert_true(vp.encloses(b.get_global_rect()), "button on screen (%s)" % b.get_global_rect())
		assert_true(b.get_global_rect().size.y >= 63.5, "full tap target")
		var router: Node = tree.root.get_node("SceneRouter")
		router.last_requested = ""
		b.pressed.emit()
		assert_eq(router.last_requested, SURVEY_SCENE, "PLAYTEST opens the survey")
	_bus().screen_shown.emit(&"match")
	await tree.process_frame
	assert_eq(plog.get_title_button(), null, "the button is only on the title")
	_teardown()
