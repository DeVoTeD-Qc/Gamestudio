# test_da_ui3.gd
# Purpose: kc-da-ui3 (head D2): the prototype's demo collection (RunConfig.demo_collection,
#   scripts/run/demo_collection.gd, RunState.apply_demo_collection): every starter card plus a few
#   dozen cards and alt arts spread across traits and rarities, merged once, never removing real
#   progress, old profiles migrate; Duel-usable cards count as owned in the Codex.
# Author: UI/UX Agent (kc-da-ui3)
extends "res://tests/test_case.gd"

const Demo: GDScript = preload("res://scripts/run/demo_collection.gd")


func _cards() -> Array:
	return tree.root.get_node("CardDB").all_cards()


func test_demo_pick_is_spread_and_stable() -> void:
	var cfg: RunConfig = tree.root.get_node("RunState").call(&"_config")
	assert_true(cfg != null and cfg.demo_collection, "the switch is on by default")
	var a: Dictionary = Demo.pick(cfg, _cards())
	var b: Dictionary = Demo.pick(cfg, _cards())
	assert_eq(a, b, "deterministic")
	var cards: Array = a["cards"]
	for c: CardData in cfg.starter_deck:
		assert_true(String(c.id) in cards, "starter %s included" % c.id)
	var extra: int = 0
	var groups: Dictionary = {}
	var db: Node = tree.root.get_node("CardDB")
	var starter: Array = cfg.starter_deck.map(func(c: CardData) -> String: return String(c.id))
	for id: String in cards:
		if id in starter:
			continue
		extra += 1
		groups[Demo.group_of(db.get_card(StringName(id)))] = true
	assert_eq(extra, Demo.DEMO_CARDS, "a few dozen cards on top of the starter")
	assert_true(groups.has("elite") and groups.has("field") and groups.has("tactic"), "rarities and types spread: %s" % str(groups.keys()))
	var unit_traits: int = groups.keys().filter(func(k: String) -> bool: return k.begins_with("unit:")).size()
	assert_true(unit_traits >= 3, "units across traits (%d)" % unit_traits)
	assert_true((a["arts"] as Array).size() >= 8, "alt arts found too (%d)" % (a["arts"] as Array).size())
	for art: Variant in a["arts"]:
		assert_false(BannerArtDB.get_art(StringName(String(art))).licensed, "%s: public art only" % art)


func test_apply_merges_once_keeps_progress_and_migrates() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var st: Node = tree.root.get_node("Settings")
	var saved: Dictionary = {"profile": st.run_profile, "arts": st.found_arts, "persist": st.persist}
	st.persist = false
	# An old v2 save with real progress and no demo key.
	st.run_profile = {"version": 2, "runs_finished": 3, "found_cards": ["mortar_pit"], "duel_decks": [], "duel_records": {}}
	st.found_arts = {"x_real_art": true}
	assert_true(rs.apply_demo_collection(), "merged into an older save")
	var p: Dictionary = rs.profile()
	assert_true("mortar_pit" in p["found_cards"], "real progress kept")
	assert_eq(int(p["runs_finished"]), 3, "other progress kept")
	assert_eq(int(p["demo_seeded"]), Demo.DEMO_VERSION, "marked as seeded")
	assert_true((p["found_cards"] as Array).size() >= Demo.DEMO_CARDS, "the demo cards are in")
	assert_true(st.found_arts.has("x_real_art") and st.found_arts.size() > 1, "found arts added on top")
	var n: int = (p["found_cards"] as Array).size()
	assert_false(rs.apply_demo_collection(), "only once")
	rs.call(&"_save_profile", RunProfile.add_found_cards(rs.profile(), ["a_new_find"]))
	assert_true("a_new_find" in rs.profile()["found_cards"] and (rs.profile()["found_cards"] as Array).size() == n + 1, "new finds add on top")
	# Switch off: nothing merged.
	var cfg: RunConfig = rs.call(&"_config")
	st.run_profile = RunProfile.blank()
	cfg.demo_collection = false
	assert_false(rs.apply_demo_collection(), "switch off: no demo")
	assert_eq(rs.profile()["found_cards"], [], "switch off: blank stays blank")
	cfg.demo_collection = true
	st.run_profile = saved["profile"]
	st.found_arts = saved["arts"]
	st.persist = saved["persist"]


func test_duel_usable_cards_are_owned_in_the_codex() -> void:
	var st: Node = tree.root.get_node("Settings")
	var saved: Dictionary = st.run_profile
	st.run_profile = RunProfile.blank()
	var CodexView: GDScript = load("res://scripts/ui/codex/codex_view.gd")
	var checked: int = 0
	for e: Dictionary in CodexView.build_entries():
		var c: CardData = e.get("card") as CardData
		if c != null and DuelCollection.is_unlocked(c, RunProfile.blank()):
			assert_true(CodexView.is_owned(e), "%s usable in a Duel = owned" % c.id)
			checked += 1
	assert_true(checked > 10, "checked %d" % checked)
	st.run_profile = saved
