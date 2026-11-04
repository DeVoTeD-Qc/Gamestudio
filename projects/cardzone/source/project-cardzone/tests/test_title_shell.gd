# test_title_shell.gd
# Purpose: cz13 Title: CONTINUE only with a saved match (and its line), the status text for a
#   damaged save, SETTINGS (settings page of the pause menu), the phone layout, and the hidden dev
#   panel: a 2 s hold on the logo opens it (1 s does not), every row offers exactly
#   BalanceConfig's allowed values, hand size 4 also sets supply drop cost 3 (§16.4a), the
#   "DEV SETTINGS ACTIVE" tag, and changes reach new matches only (a saved match keeps its rules).
# Author: UI/UX Agent (cz13)
extends "res://tests/test_setup_helpers.gd"

const TITLE: String = "res://scenes/Title.tscn"
const MATCH: String = "res://scenes/match/Match.tscn"


func test_title_names_and_layout_on_phone() -> void:
	await phone_begin()
	var t: Control = await spawn(TITLE)
	assert_eq((t.get_node("%TitleLabel") as Label).text, "CardZone", "title")
	assert_eq((t.get_node("%SubtitleLabel") as Label).text, "Prototype build", "subtitle")
	check_buttons(t.get_buttons().values(), "title")
	check_labels(t.find_children("*", "Label", true, false), "title")
	assert_false((t.get_node("%DevTag") as Label).visible, "no dev tag with shipped rules")
	assert_false((t.get_node("%StatusLabel") as Label).visible, "no status without a bad save")
	await phone_end(t)


func test_continue_line_and_damaged_save_status() -> void:
	await phone_begin()
	# A saved match: CONTINUE with its line.
	var content: RulesData = RulesData.from_card_db(CardDB)
	var s: MatchState = MatchState.new_match(content, DataEnums.Route.A)
	LoadoutRules.apply(s, {"type": "drop", "seat": 1, "area": "docks"})
	LoadoutRules.apply(s, {"type": "drop", "seat": 0, "area": "motel"})
	MatchStore.save(s, {"mode": "ai", "ai_level": "veteran", "ai_seed": 7, "human_seat": 0})
	var t: Control = await spawn(TITLE)
	var c: Button = t.get_buttons()[&"continue"]
	assert_true(c.is_visible_in_tree(), "CONTINUE with a saved match")
	var line: String = (t.get_node("%ContinueInfo") as Label).text
	assert_true(line.begins_with("Round 1 · vs Veteran AI · saved"), "continue line: %s" % line)
	assert_eq((t.get_buttons()[&"new_match"] as Button).theme_type_variation, &"Button", "NEW MATCH is secondary then")
	await touch(c)
	assert_eq(SceneRouter.last_requested, MATCH, "CONTINUE goes to the match")
	assert_eq(String(SetupLaunch.pending().get("kind", "")), "resume", "a resume request")
	t.queue_free()
	SetupLaunch.clear_pending()
	# A damaged save: no CONTINUE, the status text says why.
	var f: FileAccess = FileAccess.open(MatchStore.path(), FileAccess.WRITE)
	f.store_string("CZSAVE garbage\n{not json")
	f.close()
	MatchStore.refresh()
	t = await spawn(TITLE)
	assert_false((t.get_buttons()[&"continue"] as Button).visible, "no CONTINUE for a damaged save")
	var status: Label = t.get_node("%StatusLabel")
	assert_true(status.visible and "can't be resumed" in status.text, "status shown: '%s'" % status.text)
	check_labels([status], "status")
	await phone_end(t)


func test_title_settings_page() -> void:
	await phone_begin()
	var t: Control = await spawn(TITLE)
	await touch(t.get_buttons()[&"settings"])
	var sm: Control = t.get_settings_menu()
	assert_true(sm != null and sm.visible, "SETTINGS opens")
	assert_eq(sm.get_title_text(), "SETTINGS", "settings page only")
	await touch(sm.get_button(&"speed_normal"))
	assert_eq(String(SetupPrefs.get_value("settings", "event_speed", "")), "normal", "speed saved")
	await touch(sm.get_button(&"back"))
	assert_false(sm.visible, "CLOSE closes it")
	await phone_end(t)


func test_dev_panel_long_press_values_coupling_and_new_matches_only() -> void:
	await phone_begin()
	var t: Control = await spawn(TITLE)
	var logo: Label = t.get_node("%TitleLabel")
	await long_press(logo, 1.0)
	assert_true(t.get_dev_panel() == null or not t.get_dev_panel().visible, "a 1 s hold does not open the dev panel")
	await long_press(logo, 2.1)
	var dp: Control = t.get_dev_panel()
	assert_true(dp != null and dp.visible, "a 2 s hold on the logo opens the dev panel")
	assert_true("NEW matches only" in dp.get_note(), "says changes apply to new matches only")
	# Every row offers exactly BalanceConfig's allowed values.
	for key: StringName in DevOverrides.keys():
		var opts: Array = DevOverrides.options(key)
		assert_true(not opts.is_empty(), "%s has options" % key)
		for v: Variant in opts:
			assert_true(BalanceConfig.is_allowed(key, v), "%s option %s allowed" % [key, v])
		if key != &"final_circle_hits":
			assert_eq(opts, BalanceConfig.allowed_values(key), "%s offers the allowed values" % key)
		assert_not_null(dp.get_option_button(key, 0), "%s row on the panel" % key)
	for key: StringName in [&"hand_size", &"packing_rule", &"hold_limit", &"hold_looted", &"adrenaline_mode",
			&"adrenaline_cap_per_turn", &"down_enabled", &"bounty_heal", &"bounty_final_circle_extra",
			&"bounty_holder_loses_cover", &"final_circle_hits", &"zone_hard_end_card", &"standard_pack",
			&"held_cards_public", &"hits_on_top_public", &"loadout_count_public"]:
		assert_true(DevOverrides.keys().has(key), "panel has %s" % key)
	assert_false(dp.is_tag_shown(), "no tag with shipped values")
	assert_false(DevOverrides.set_value(&"hand_size", 3), "a value outside the allowed set is refused")
	# Hand size 4 by touch: supply drop cost 3 with it.
	await touch(dp.get_option_button(&"hand_size", BalanceConfig.allowed_values(&"hand_size").find(4)))
	assert_eq(DevOverrides.value(&"hand_size"), 4, "hand size 4")
	assert_eq(DevOverrides.value(&"supply_drop_cost"), 3, "supply drop cost 3 with hand 4 (§16.4a)")
	assert_true("Supply drop cost set to 3" in dp.get_note(), "the panel says so: %s" % dp.get_note())
	assert_true(dp.is_tag_shown(), "DEV SETTINGS ACTIVE in the panel")
	await tree.process_frame
	dp.reveal(&"held_cards_public")
	await tree.process_frame
	await touch(dp.get_option_button(&"held_cards_public", 1))
	assert_eq(DevOverrides.value(&"held_cards_public"), true, "visibility switch by touch")
	await touch(dp.get_button(&"close"))
	assert_true((t.get_node("%DevTag") as Label).is_visible_in_tree(), "DEV SETTINGS ACTIVE on the title")
	t.queue_free()
	# A new match uses them.
	SetupLaunch.request_new({"opponent": "rookie", "first": "me", "route": "A"})
	var m: Control = await spawn(MATCH)
	var b: BalanceConfig = m.get_controller().state.data.balance
	assert_eq([b.hand_size, b.supply_drop_cost, b.held_cards_public], [4, 3, true], "the new match plays the dev values")
	assert_eq(CardDB.get_balance().hand_size, 5, "the shipped config is untouched")
	await touch(m.get_area_touch(&"motel"))
	await touch(m.get_dock_button(&"drop"))
	assert_true(MatchStore.has_saved_match(), "saved")
	m.queue_free()
	await tree.process_frame
	# Back to hand 5: the coupled cost goes back too. A saved match keeps its own rules.
	DevOverrides.set_value(&"hand_size", 5)
	assert_eq(DevOverrides.value(&"supply_drop_cost"), 4, "cost back to the shipped 4")
	DevOverrides.reset()
	assert_false(DevOverrides.is_active(), "reset")
	SetupLaunch.request_resume()
	m = await spawn(MATCH)
	b = m.get_controller().state.data.balance
	assert_eq([b.hand_size, b.supply_drop_cost], [4, 3], "CONTINUE keeps the saved match's rules")
	await phone_end(m)
