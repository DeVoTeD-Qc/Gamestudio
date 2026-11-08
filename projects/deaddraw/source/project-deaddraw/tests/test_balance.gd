# balance.json mirrors the v2 sim's CONFIG (tools/sim_deaddraw_v2.py); the loader accepts a
# pasted Python dict; the rules read the v2 numbers (melee bonus, boss-wave strength, prices).
extends "res://tests/dd_test_case.gd"


func _sim_path() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	for rel: String in ["../../tools/sim_deaddraw_v2.py", "../../../tools/sim_deaddraw_v2.py"]:
		var p: String = root.path_join(rel).simplify_path()
		if FileAccess.file_exists(p):
			return p
	return ""


func _sim_config_text() -> String:
	var p: String = _sim_path()
	if p == "":
		return ""
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
	for di: int in 3:
		eq(b.wave_count(di), 3, "3 waves in district %d" % di)
		eq(b.rooms(di).size(), 3, "3 rooms in district %d" % di)
	eq(b.text("structure"), "mixed", "mixed deck")
	eq(b.text("model"), "notch", "hybrid notch model")
	eq(b.text("reload_mode"), "drop", "reload drops the magazine")
	check(b.weapons().has("pistol") and b.is_gun("pistol"), "pistol is a gun")
	check(not b.is_gun("machete"), "machete is melee")
	eq(b.shown(5), 50, "points shown x10")


func test_python_dict_paste_is_accepted() -> void:
	var src: String = "CONFIG = {\n  \"street_size\": 5,  # comment, with: punctuation\n  \"allow_retreat\": False,\n  'reload_mode': 'top',\n  \"perks\": [\"a\", \"b\",],\n  \"x\": None,\n}\n"
	var b: DDBalance = DDBalance.from_text(src)
	eq(b.load_error, "", "parsed")
	eq(b.num("street_size"), 5, "number")
	check(not b.flag("allow_retreat"), "False -> false")
	eq(b.text("reload_mode"), "top", "single quotes")
	eq(b.config["perks"], ["a", "b"], "trailing comma dropped")
	eq(b.rule("tripwire_cover"), 2, "missing extra_rules fall back to sim values")
	eq(b.num("actions_per_street"), 3, "missing CONFIG keys fall back to sim defaults")


func test_balance_json_matches_sim_config() -> void:
	var text: String = _sim_config_text()
	check(text != "", "found tools/sim_deaddraw_v2.py CONFIG next to the project")
	if text == "":
		return
	var sim: DDBalance = DDBalance.from_text(text)
	eq(sim.load_error, "", "sim CONFIG parses")
	var ours: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	for k: String in sim.config:
		if k == "extra_rules" or not text.contains("\"%s\"" % k):
			continue
		check(ours.config.has(k), "balance.json has " + k)
		eq(JSON.stringify(ours.config.get(k)), JSON.stringify(sim.config[k]), "CONFIG[%s] mirrors the sim" % k)


func test_rules_use_the_tuned_numbers() -> void:
	var b: DDBalance = bal()
	var bonus: int = b.num("melee_power_bonus")
	eq(b.weapon_power("machete"), int(b.weapon_def("machete")["p"]) + bonus, "melee gets the melee bonus")
	eq(b.weapon_power("pistol"), int(b.weapon_def("pistol")["p"]), "guns don't")
	# wave zombies = base + z_add (+ boss_wave_add on wave 3)
	for di: int in 3:
		var za: int = int(b.list("z_add")[di])
		var bw: int = int(b.list("boss_wave_add")[di])
		var base1: Array = b.district(di)["waves"][0]
		var base3: Array = b.district(di)["waves"][2]
		eq(b.wave_zombies(di, 0)[0], int(base1[0]) + za, "wave 1 strength, district %d" % di)
		eq(b.wave_zombies(di, 2)[0], int(base3[0]) + za + bw, "boss wave strength, district %d" % di)
	var r: DDRun = make_run("rosa")
	r.wave_index = 2
	var pack: Array[DDCard] = r.wave_pack(2)
	eq(pack[0].value, b.wave_zombies(0, 2)[0], "the run deals those strengths")
	eq(b.survivor_hp("theo"), int(b.survivors()["theo"]["hp"]), "Theo HP from CONFIG")
	eq(str(b.survivor("theo").get("role", "")), "Courier", "display info merged from extra_rules")
