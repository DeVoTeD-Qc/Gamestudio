# test_hotseat_save.gd
# Purpose: cz14 hot-seat saves (MatchStore, cz08): the save records the mode (meta.mode
#   "hotseat") and the pending cover (meta.cover_seat), and a resumed hot-seat match opens behind
#   the cover of the deciding seat, showing nothing private until the tap: at a pending turn cover,
#   at a pending Brace (the defender's prompt only after its cover), and through the shell's
#   CONTINUE path (SetupLaunch.request_resume -> MatchShell.begin). Also: the title's CONTINUE line
#   says "Hot-seat", and each test process has its own MatchStore save file.
# Author: Mechanics Developer Agent (cz14)
extends "res://tests/test_hotseat_kit.gd"

const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const TitleScript: GDScript = preload("res://scripts/ui/title.gd")


func test_save_records_hotseat_and_resumes_at_the_pending_cover() -> void:
	var m: Control = await _spawn_hotseat(null)
	var ctrl: Node = m.get_controller()
	await _tap_cover(m)
	await _touch_area(m, &"motel")
	await _touch_dock(m, &"drop")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "Player 2 dropped: cover for Player 1")
	var info: Dictionary = MatchStore.saved_info()
	assert_true(bool(info.get("has_match", false)), "saved")
	var meta: Dictionary = info.get("meta", {})
	assert_eq(String(meta.get("mode", "")), "hotseat", "the save records the mode")
	assert_eq(int(meta.get("cover_seat", -1)), MatchState.P1, "the save records the pending cover")
	assert_true("Hot-seat" in TitleScript.continue_text(info), "title CONTINUE line: %s" % TitleScript.continue_text(info))
	var print_before: String = ctrl.state.fingerprint()
	var resumed: Dictionary = MatchStore.resume()
	_despawn(m)
	await tree.process_frame
	covers.clear()
	m = await _spawn_hotseat(null, resumed)
	ctrl = m.get_controller()
	assert_eq(ctrl.state.fingerprint(), print_before, "the same match")
	assert_true(ctrl.hotseat and ctrl.is_covered(), "resumed behind the cover")
	assert_eq(ctrl.cover_seat, MatchState.P1, "for Player 1, who decides next")
	assert_eq(StringName(ctrl.cover_info()["reason"]), &"drop", "Player 1's drop")
	assert_true(m.get_cover().visible, "the cover is on screen")
	assert_true(m.get_cards(&"hand").is_empty() and m.get_cards(&"next").is_empty(), "no card under it")
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P1, &"drop"], "Player 1 drops after the tap")
	assert_eq(leaks, [] as Array[String], "no leaks")
	_despawn(m)


func test_resume_at_a_pending_brace_shows_the_prompt_only_after_its_cover() -> void:
	var m: Control = await _spawn_hotseat(null)
	var ctrl: Node = m.get_controller()
	# Both seats play by the controller (fast) until a shot leaves a Brace pending behind a cover.
	var guard: int = 0
	var n: int = 0
	var last: int = -1
	while guard < 800 and not ctrl.state.is_over():
		guard += 1
		if ctrl.is_covered():
			if ctrl.state.pending_brace_seat() == ctrl.cover_seat:
				break
			ctrl.reveal()
			continue
		if ctrl.human != last:
			last = ctrl.human
			n = 0
		var a: Dictionary = _pick(ctrl, ctrl.legal(), n)
		n += 1
		if a["type"] == "brace":
			a = {"type": "brace", "cards": a["cards"]}
		var why: String = ctrl.request(a)
		if why != "":
			failures.append("refused %s: %s" % [a, why])
			break
	var defender: int = ctrl.state.pending_brace_seat()
	assert_true(defender >= 0 and ctrl.is_covered() and ctrl.cover_seat == defender, "a Brace waits behind the defender's cover")
	var meta: Dictionary = MatchStore.saved_info().get("meta", {})
	assert_eq(String(meta.get("mode", "")), "hotseat", "mode saved")
	assert_eq(int(meta.get("cover_seat", -1)), defender, "the pending cover is the defender's")
	var print_before: String = ctrl.state.fingerprint()
	var resumed: Dictionary = MatchStore.resume()
	_despawn(m)
	await tree.process_frame
	m = await _spawn_hotseat(null, resumed)
	ctrl = m.get_controller()
	assert_eq(ctrl.state.fingerprint(), print_before, "the same match, Brace pending")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == defender, "resumed behind the defender's cover")
	assert_eq(StringName(ctrl.cover_info()["reason"]), &"brace", "a Brace cover")
	assert_false(ctrl.view().has("brace_prompt"), "no Brace prompt in the covered view")
	assert_false(m.get_brace_panel().visible, "no Brace panel under the cover")
	assert_true(ctrl.brace_suggestion().is_empty() and ctrl.brace_preview([]).is_empty(), "no advice behind the cover")
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [defender, &"brace"], "the defender's Brace step after the tap")
	assert_true(m.get_brace_panel().visible and ctrl.view().has("brace_prompt"), "the prompt is up")
	var sug: Array = ctrl.brace_suggestion().get("cards", [])
	await _brace_by_touch(m, {"type": "brace", "cards": sug, "via": "suggested"})
	assert_true(ctrl.is_covered() and ctrl.cover_seat == 1 - defender, "after the Brace: pass back to the shooter")
	assert_eq(leaks, [] as Array[String], "no leaks")
	_despawn(m)


func test_continue_from_the_shell_resumes_hotseat_behind_the_cover() -> void:
	var m: Control = await _spawn_hotseat(null)
	await _tap_cover(m)
	await _touch_area(m, &"farmstead")
	await _touch_dock(m, &"drop")
	var print_before: String = m.get_controller().state.fingerprint()
	assert_true(MatchStore.has_saved_match(), "saved")
	m.queue_free()  # leave without clearing the save
	await tree.process_frame
	MatchStore.refresh()
	SetupLaunch.request_resume()
	m = await _spawn_hotseat(null, {}, true)
	var ctrl: Node = m.get_controller()
	assert_not_null(m.shell, "the shell started it")
	assert_eq(String(m.shell.start_error), "", "resumed without error")
	assert_eq(ctrl.state.fingerprint(), print_before, "CONTINUE resumes the saved hot-seat match")
	assert_true(ctrl.hotseat and ctrl.opponent == null, "hot-seat: no AI opponent")
	assert_true(ctrl.is_covered() and ctrl.cover_seat == MatchState.P1, "behind Player 1's cover")
	assert_eq(m.get_cover().get_index(), m.get_child_count() - 1, "the cover is above the shell and every overlay")
	await _tap_cover(m)
	assert_eq([ctrl.human, ctrl.phase], [MatchState.P1, &"drop"], "Player 1's drop")
	assert_eq(leaks, [] as Array[String], "no leaks")
	_despawn(m)


func test_each_test_process_has_its_own_match_store_file() -> void:
	var p: String = MatchStore.path()
	assert_true(p.begins_with("user://test_match_store/"), "under the test folder: %s" % p)
	assert_true(("/%d/" % OS.get_process_id()) in p, "per process (pid %d): %s" % [OS.get_process_id(), p])
	assert_eq(p, MatchStore.test_save_path(), "the autoload uses test_save_path()")
