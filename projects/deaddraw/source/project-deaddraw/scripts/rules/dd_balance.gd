# dd_balance.gd
# Purpose: Loads every tunable number from res://data/balance.json, which mirrors CONFIG in
#   projects/deaddraw/tools/sim_deaddraw_v4.py (DeadDraw v4, core-rules-v4.md; regenerate it with
#   tools/regen_balance.py). The file may be strict JSON or a pasted Python dict (True/False/None,
#   # comments, trailing commas, a leading "CONFIG =" are all accepted). Display-only info and the
#   meta unlocks live in "extra_rules"; a missing key falls back to DEFAULT_EXTRA / DEFAULT_TOP, so
#   pasting the bare CONFIG dict never breaks the game. Points are kept in sim units; the UI shows
#   them x points_display_mult (10).
# Dependencies: none (pure data, safe in headless tests).
# Author: Mechanics Developer Agent
class_name DDBalance
extends RefCounted

const DEFAULT_PATH: String = "res://data/balance.json"

# Display-only survivor info and the meta unlocks (the sim does not model them).
const DEFAULT_EXTRA: Dictionary = {
	"points_display_mult": 10,
	"score_hp_mult": 1,
	"survivor_info": {
		"rosa": {"role": "Mechanic", "unlocked": true},
		"imani": {"role": "Medic", "unlocked": true},
		"theo": {"role": "Courier", "unlocked": false},
	},
	"unlocks": {
		"downtown": ["survivor:theo"],
		"win": ["badge"],
	},
}

# CONFIG keys the rules read, with the v4 sim's values as the fallback.
const DEFAULT_TOP: Dictionary = {
	"street_size": 4, "actions": 3, "medkits_per_street": 99, "allow_run": true, "run_damage": 1,
	"boss_runpast_damage": 3, "boss_reward_points": 10, "safehouse_heal": 8, "points_on_kill": true,
	"ditch_share": 0.0, "finish_bonus": 5, "scrap_points": 2, "melee_power": 2, "melee_points": 0.0,
	"start_points": 0, "start_kit": ["pistol"], "restock_per_room": 1, "room_cost_mult": 1.0,
	"z_add": [0, 0, 0], "patch_costs": [15, 25, 35, 45, 55, 65, 75, 85], "patch_offer": 2,
	"boss_patch_offer": 3, "bench": {"trim": 5, "flip": 8, "hone": 12}, "brawler_bonus": 2,
	"field_medic_bonus": 2, "thick_jacket_hp": 4, "second_wind_hp": 6, "trophy_belt_heal": 2,
	"spread_cap": 16, "big_min": 6, "triage_bonus": 1, "theo_melee_bonus": 0,
	"weapons": {}, "districts": [], "survivors": {}, "patches": [],
	# v4 (core-rules-v4.md section 9.1)
	"swap_salvage": "per_kill", "salvage_per_kill": 1, "carry_mode": "shop", "carry_heal_rate": 3,
	"melee_mode": "hands", "hands_power": 1, "brawler_mode": "hands", "brawler_dur": 1,
	"melee_weapon_points": 0.0, "melee_weapons": {}, "melee_pool": {}, "card_add": {}, "pool_add": {},
	"run_mode": "anytime", "run_return": "bottom", "lockpick_off": 5, "adrenaline_hp": 6, "grudge_min": 9,
	"show_off_points": 4, "whetstone_dur": 2, "small_max": 6, "heavy_min": 0, "big_bang_min": 9,
	"pest_total": 15,
	# v5 economy pass (economy-v5.md)
	"room_free_use": false, "room_cost_add": [0, 0, 0], "room_free_kinds": ["wall", "bench", "patch"], "mods_mode": "safehouse",
	"mod_offer": 2, "mod_price": 5, "mods": ["open_breech", "last_round", "echo", "short_barrel"],
}

static var _cached: DDBalance = null

var config: Dictionary = {}
var extra: Dictionary = {}
var load_error: String = ""


static func get_default() -> DDBalance:
	if _cached == null:
		_cached = DDBalance.from_file(DEFAULT_PATH)
	return _cached


static func from_file(path: String) -> DDBalance:
	var text: String = FileAccess.get_file_as_string(path)
	var b: DDBalance = DDBalance.from_text(text)
	if text == "":
		b.load_error = "could not read %s" % path
	return b


static func from_text(text: String) -> DDBalance:
	var b: DDBalance = DDBalance.new()
	var parsed: Variant = JSON.parse_string(normalize(text))
	if parsed is Dictionary:
		b.config = parsed
	else:
		b.load_error = "balance data is not a JSON object"
		b.config = {}
	for k: String in DEFAULT_TOP:
		if not b.config.has(k):
			b.config[k] = DEFAULT_TOP[k].duplicate(true) if (DEFAULT_TOP[k] is Dictionary or DEFAULT_TOP[k] is Array) else DEFAULT_TOP[k]
	var ex: Variant = b.config.get("extra_rules", {})
	b.extra = DEFAULT_EXTRA.duplicate(true)
	if ex is Dictionary:
		for k: String in ex:
			b.extra[k] = ex[k]
	if b.load_error != "":
		push_warning("DDBalance: " + b.load_error)
	return b


## Turns a pasted Python dict literal into strict JSON. Strings are left untouched.
static func normalize(src: String) -> String:
	var s: String = src.strip_edges()
	var brace: int = s.find("{")
	if brace > 0:
		s = s.substr(brace)
	var out: String = ""
	var i: int = 0
	var in_str: bool = false
	var quote: String = ""
	while i < s.length():
		var ch: String = s[i]
		if in_str:
			if ch == "\\" and i + 1 < s.length():
				out += ch + s[i + 1]
				i += 2
				continue
			if ch == quote:
				in_str = false
				out += "\""
			elif ch == "\"" and quote == "'":
				out += "\\\""
			else:
				out += ch
			i += 1
			continue
		if ch == "\"" or ch == "'":
			in_str = true
			quote = ch
			out += "\""
			i += 1
			continue
		if ch == "#":
			while i < s.length() and s[i] != "\n":
				i += 1
			continue
		# Python tuples ("points", 5) -> JSON arrays
		if ch == "(":
			out += "["
			i += 1
			continue
		if ch == ")":
			out += "]"
			i += 1
			continue
		if _word_at(s, i, "True"):
			out += "true"
			i += 4
			continue
		if _word_at(s, i, "False"):
			out += "false"
			i += 5
			continue
		if _word_at(s, i, "None"):
			out += "null"
			i += 4
			continue
		if ch == ",":
			# drop trailing commas before } or ]
			var j: int = i + 1
			while j < s.length() and s[j] in [" ", "\t", "\n", "\r"]:
				j += 1
			while j < s.length() and s[j] == "#":
				while j < s.length() and s[j] != "\n":
					j += 1
				while j < s.length() and s[j] in [" ", "\t", "\n", "\r"]:
					j += 1
			if j < s.length() and (s[j] == "}" or s[j] == "]"):
				i += 1
				continue
		out += ch
		i += 1
	# cut anything after the closing brace of the top-level object
	var depth: int = 0
	var in_s: bool = false
	var k: int = 0
	while k < out.length():
		var c: String = out[k]
		if in_s:
			if c == "\\":
				k += 2
				continue
			if c == "\"":
				in_s = false
		elif c == "\"":
			in_s = true
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return out.substr(0, k + 1)
		k += 1
	return out


static func _word_at(s: String, i: int, w: String) -> bool:
	if s.substr(i, w.length()) != w:
		return false
	var before: String = s[i - 1] if i > 0 else " "
	var after: String = s[i + w.length()] if i + w.length() < s.length() else " "
	return not (_is_ident(before) or _is_ident(after))


static func _is_ident(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_"


# ---------------------------------------------------------------- accessors
func num(key: String) -> int:
	return int(config.get(key, DEFAULT_TOP.get(key, 0)))


func fnum(key: String) -> float:
	return float(config.get(key, DEFAULT_TOP.get(key, 0.0)))


func flag(key: String) -> bool:
	return bool(config.get(key, DEFAULT_TOP.get(key, false)))


func text(key: String) -> String:
	return str(config.get(key, DEFAULT_TOP.get(key, "")))


func list(key: String) -> Array:
	var v: Variant = config.get(key, DEFAULT_TOP.get(key, []))
	return v if v is Array else []


func dict(key: String) -> Dictionary:
	var v: Variant = config.get(key, DEFAULT_TOP.get(key, {}))
	return v if v is Dictionary else {}


func rule(key: String) -> int:
	return int(extra.get(key, DEFAULT_EXTRA.get(key, 0)))


## Points as the player sees them (sim units x 10).
func shown(units: int) -> int:
	return units * rule("points_display_mult")


## Retrofit Bench service price (trim / flip / hone), sim units.
func bench_price(service: String) -> int:
	return int(dict("bench").get(service, (DEFAULT_TOP["bench"] as Dictionary).get(service, 0)))


## Patch Press price for the next Patch when you own `owned` of them (15, 25, 35...).
func patch_price(owned: int) -> int:
	var c: Array = list("patch_costs")
	if c.is_empty():
		return 0
	return int(c[mini(owned, c.size() - 1)])


func patches() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in list("patches"):
		out.append(str(p))
	return out


func weapons() -> Dictionary:
	return dict("weapons")


func weapon_def(wid: String) -> Dictionary:
	var w: Variant = weapons().get(wid, {})
	return w if w is Dictionary else {}


func weapon_name(wid: String) -> String:
	return str(weapon_def(wid).get("name", wid.capitalize()))


func is_gun(wid: String) -> bool:
	return weapons().has(wid)


func weapon_power(wid: String) -> int:
	return int(weapon_def(wid).get("p", 0))


func weapon_cap(wid: String) -> int:
	return int(weapon_def(wid).get("cap", 0))


func weapon_rule(wid: String) -> String:
	return str(weapon_def(wid).get("rule", "any"))


func weapon_challenge(wid: String) -> String:
	return str(weapon_def(wid).get("chal", ""))


## [kind, amount]: "points" / "heal" / "cover" / "encore".
func weapon_reward(wid: String) -> Array:
	var r: Variant = weapon_def(wid).get("reward", ["points", 0])
	return r if r is Array and (r as Array).size() >= 2 else ["points", 0]


## Wall Rack price of a gun (sim units), 0 if it has none.
func weapon_price(wid: String) -> int:
	return int(weapon_def(wid).get("price", 0))


## v4 melee weapon cards ("K"): {"name", "p", "dur"}.
func melee_def(mid: String) -> Dictionary:
	var m: Variant = dict("melee_weapons").get(mid, {})
	return m if m is Dictionary else {}


func melee_name(mid: String) -> String:
	return str(melee_def(mid).get("name", mid.capitalize()))


func melee_power(mid: String) -> int:
	return int(melee_def(mid).get("p", 0))


func melee_uses(mid: String) -> int:
	return int(melee_def(mid).get("dur", 0))


func is_melee(mid: String) -> bool:
	return dict("melee_weapons").has(mid)


func _district_id(di: int) -> String:
	return str(district(di).get("id", ""))


## Melee weapon ids a "K" card of district di can be (sim Board.mpool; wrench if none listed).
func melee_pool(di: int) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in dict("melee_pool").get(_district_id(di), ["wrench"]):
		out.append(str(v))
	return out


## Gun ids a "W" card of district di can be: the district's list + pool_add (sim Board.pool).
func district_pool(di: int) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in district(di).get("weapons", ["pistol"]):
		out.append(str(v))
	for v: Variant in dict("pool_add").get(_district_id(di), []):
		out.append(str(v))
	return out


## Extra cards per district: {"entrance": [...], "waves": [[...], ...], "rooms": [[...], ...]}.
func district_card_add(di: int) -> Dictionary:
	var a: Variant = dict("card_add").get(_district_id(di), {})
	return a if a is Dictionary else {}


## The Entrance pack of district di with its card_add entries appended.
func entrance_spec(di: int) -> Array:
	var out: Array = (district(di).get("entrance", []) as Array).duplicate()
	out.append_array(district_card_add(di).get("entrance", []))
	return out


## A room's pack with its card_add entries appended.
func room_pack(di: int, ri: int) -> Array:
	var r: Array = rooms(di)
	if ri < 0 or ri >= r.size():
		return []
	var out: Array = ((r[ri] as Dictionary).get("pack", []) as Array).duplicate()
	var ra: Array = district_card_add(di).get("rooms", [])
	if ri < ra.size() and ra[ri] is Array:
		out.append_array(ra[ri])
	return out


func districts() -> Array:
	return list("districts")


func district(index: int) -> Dictionary:
	var d: Array = districts()
	return d[index] if index >= 0 and index < d.size() else {}


func district_count() -> int:
	return districts().size()


func wave_count(di: int) -> int:
	return (district(di).get("waves", []) as Array).size()


## A wave deck spec with z_add applied to its zombies (ints); "W" / "K" entries stay as they
## are; the district's card_add entries for that wave are appended (sim Board.__init__).
func wave_spec(di: int, w: int) -> Array:
	var out: Array = []
	var waves: Array = district(di).get("waves", [])
	if w < 0 or w >= waves.size():
		return out
	var za: Array = list("z_add")
	var add: int = int(za[di]) if di < za.size() else 0
	for x: Variant in waves[w]:
		if x is String:
			out.append(x)
		else:
			out.append(int(x) + add)
	var wa: Array = district_card_add(di).get("waves", [])
	if w < wa.size() and wa[w] is Array:
		out.append_array(wa[w])
	return out


## The zombie numbers of a wave deck (sorted as listed).
func wave_zombies(di: int, w: int) -> Array[int]:
	var out: Array[int] = []
	for x: Variant in wave_spec(di, w):
		if not x is String:
			out.append(int(x))
	return out


func rooms(di: int) -> Array:
	return district(di).get("rooms", [])


func room_cost(di: int, ri: int) -> int:
	var r: Array = rooms(di)
	if ri < 0 or ri >= r.size():
		return 0
	return int(round(float((r[ri] as Dictionary).get("cost", 0)) * fnum("room_cost_mult")))


func boss(di: int) -> Dictionary:
	return district(di).get("boss", {})


func survivors() -> Dictionary:
	return dict("survivors")


## Survivor entry from CONFIG merged with its display info (role, unlocked) from extra_rules.
func survivor(id: String) -> Dictionary:
	var s: Dictionary = (survivors().get(id, {}) as Dictionary).duplicate()
	var info: Variant = (extra.get("survivor_info", {}) as Dictionary).get(id, {})
	if info is Dictionary:
		for k: String in info:
			if not s.has(k):
				s[k] = info[k]
	return s


func survivor_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in survivors().keys():
		out.append(str(k))
	return out


func survivor_hp(id: String) -> int:
	return int(survivor(id).get("hp", 20))


func survivor_max_hp(id: String) -> int:
	return survivor_hp(id)


## v2 compatibility for the profile: v3 has no perk pool (Patches come from the Patch Press).
func all_perks() -> Array[String]:
	return patches()


func starter_perks() -> Array[String]:
	return patches()


func unlocks_for(milestone: String) -> Array[String]:
	var out: Array[String] = []
	var u: Variant = extra.get("unlocks", {})
	if u is Dictionary:
		for v: Variant in u.get(milestone, []):
			out.append(str(v))
	return out
