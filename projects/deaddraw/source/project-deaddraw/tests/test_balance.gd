# balance.json mirrors the sim's CONFIG; the loader accepts a pasted Python dict.
extends "res://tests/dd_test_case.gd"


func _sim_config_text() -> String:
	var p: String = ProjectSettings.globalize_path("res://").path_join("../../../tools/sim_deaddraw.py").simplify_path()
	var src: String = FileAccess.get_file_as_string(p)
	var a: int = src.find("CONFIG = {")
	if a < 0:
		return ""
	var b: int = src.find("\n}\n", a)
	return src.substr(a, b - a + 2)


func test_balance_loads() -> void:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	eq(b.load_error, "", "no load error")
	eq(b.district_count(), 3, "3 districts")
	eq(b.num("safehouse_heal"), 12, "safehouse heal 12")
	eq(b.retreat_mode(), "bottom", "bottom retreat")
	eq(b.num("triage_heal_bonus"), 1, "triage bonus")
	eq(b.survivor_hp("theo"), 24, "Theo 24")


func test_python_dict_paste_is_accepted() -> void:
	var src: String = "CONFIG = {\n  \"start_hp\": 18,  # comment, with: punctuation\n  \"weapon_scrap\": False,\n  'retreat_mode': 'shuffle',\n  \"perks\": [\"a\", \"b\",],\n  \"x\": None,\n}\n"
	var b: DDBalance = DDBalance.from_text(src)
	eq(b.load_error, "", "parsed")
	eq(b.num("start_hp"), 18, "number")
	check(not b.weapon_scrap(), "False -> false")
	eq(b.retreat_mode(), "shuffle", "single quotes")
	eq(b.config["perks"], ["a", "b"], "trailing comma dropped")
	eq(b.rule("tripwire_cover"), 2, "missing extra_rules fall back to sim values")


func test_balance_json_matches_sim_config() -> void:
	var text: String = _sim_config_text()
	if text == "":
		check(true, "sim not found next to the project; skipped")
		return
	var sim: DDBalance = DDBalance.from_text(text)
	eq(sim.load_error, "", "sim CONFIG parses")
	var ours: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	for k: String in sim.config:
		if k == "extra_rules":
			continue
		check(ours.config.has(k), "balance.json has " + k)
		eq(JSON.stringify(ours.config.get(k)), JSON.stringify(sim.config[k]), "CONFIG[%s] mirrors the sim" % k)
