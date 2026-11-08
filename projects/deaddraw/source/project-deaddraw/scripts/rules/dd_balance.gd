# dd_balance.gd
# Purpose: Loads every tunable number from res://data/balance.json, which mirrors CONFIG in
#   projects/deaddraw/tools/sim_deaddraw_v2.py (DeadDraw v2). The file may be strict JSON or a
#   pasted Python dict (True/False/None, # comments, trailing commas, a leading "CONFIG =" are all
#   accepted). Numbers the sim hard-codes outside CONFIG live in "extra_rules"; a missing key falls
#   back to the sim's value (DEFAULT_EXTRA / DEFAULT_TOP), so pasting the bare CONFIG dict never
#   breaks the game. Points are kept in sim units; the UI shows them x points_display_mult (10).
# Dependencies: none (pure data, safe in headless tests).
# Author: Mechanics Developer Agent
class_name DDBalance
extends RefCounted

const DEFAULT_PATH: String = "res://data/balance.json"

# Values the sim hard-codes in apply() / take_damage() / play_run() (sim_deaddraw_v2.py), plus
# display-only survivor info and the meta unlocks.
const DEFAULT_EXTRA: Dictionary = {
	"medkits_per_street": 1,
	"triage_medkits_per_street": 2,
	"field_kit_bonus": 1,
	"knuckle_wraps_reduction": 2,
	"thick_jacket_hp": 4,
	"tripwire_cover": 2,
	"second_wind_hp": 1,
	"steady_aim_power": 2,
	"thick_skin_reduction": 1,
	"sugar_rush_heal": 5,
	"payday_mult": 2,
	"empty_pool_ammo": 3,
	"points_display_mult": 10,
	"score_hp_mult": 1,
	"survivor_info": {
		"rosa": {"role": "Mechanic", "unlocked": true},
		"imani": {"role": "Medic", "unlocked": true},
		"theo": {"role": "Courier", "unlocked": false},
	},
	"unlocks": {
		"maple_row": ["perk:second_wind"],
		"downtown": ["survivor:theo"],
		"win": ["perk:tripwire", "badge"],
	},
}

# CONFIG keys the rules read, with the sim's values as the fallback.
const DEFAULT_TOP: Dictionary = {
	"structure": "mixed", "model": "notch", "street_size": 4, "actions_per_street": 3,
	"reloads_per_street": 1, "reload_mode": "drop", "allow_retreat": true, "safehouse_heal": 12,
	"perk_choices": 3, "triage_heal_bonus": 1, "start_kit": ["pistol"], "start_reserve": 6,
	"reserve_cap": 24, "start_points": 5,
	"points": {"kill": 0.5, "up_close": 1, "scrap": 1, "boss": 8, "wave": 3},
	"melee_wave_reset": true, "melee_power_bonus": 0, "restock_per_room": 1, "entrance_restock": 0,
	"z_add": [0, 0, 0], "boss_wave_add": [0, 0, 0], "drops": ["full_load", "payday", "boards"],
	"full_load_reserve": 4, "boards_cover": 4, "bandolier_reserve": 2, "fire_axe_power": 6,
	"fixtures": {"retrofit": {"cost": 30, "power": 2, "mag_mult": 1.5}, "grin": {"cost": 12, "step": 6},
		"locker": {"cost": 18}, "wallrack": {"ammo_cost": 6}},
	"weapons": {}, "locker_pool": [], "grin_effects": [], "districts": [], "survivors": {},
	"starter_perks": [], "perks": [],
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


## Points table entry (sim units, may be fractional: "kill" is points per strength).
func points(key: String) -> float:
	var p: Dictionary = dict("points")
	return float(p.get(key, (DEFAULT_TOP["points"] as Dictionary).get(key, 0)))


## Points as the player sees them (sim units x 10).
func shown(units: int) -> int:
	return units * rule("points_display_mult")


func fixture(kind: String) -> Dictionary:
	var f: Variant = dict("fixtures").get(kind, (DEFAULT_TOP["fixtures"] as Dictionary).get(kind, {}))
	return f if f is Dictionary else {}


func fixture_num(kind: String, key: String) -> float:
	return float(fixture(kind).get(key, 0))


func weapons() -> Dictionary:
	return dict("weapons")


func weapon_def(wid: String) -> Dictionary:
	var w: Variant = weapons().get(wid, {})
	return w if w is Dictionary else {}


func weapon_name(wid: String) -> String:
	return str(weapon_def(wid).get("name", wid.capitalize()))


func is_gun(wid: String) -> bool:
	return int(weapon_def(wid).get("mag", 0)) > 0


## A weapon's power as dealt (melee gets melee_power_bonus, as in the sim's mkweapon()).
func weapon_power(wid: String) -> int:
	var d: Dictionary = weapon_def(wid)
	var p: int = int(d.get("p", 0))
	if int(d.get("mag", 0)) == 0:
		p += num("melee_power_bonus")
	return p


func weapon_mag(wid: String) -> int:
	return int(weapon_def(wid).get("mag", 0))


## Wall Rack price of a gun (sim units), 0 if it has none.
func weapon_price(wid: String) -> int:
	return int(weapon_def(wid).get("price", 0))


func districts() -> Array:
	return list("districts")


func district(index: int) -> Dictionary:
	var d: Array = districts()
	return d[index] if index >= 0 and index < d.size() else {}


func district_count() -> int:
	return districts().size()


func wave_count(di: int) -> int:
	return (district(di).get("waves", []) as Array).size()


## The effective zombie strengths of a wave pack (base + z_add + boss_wave_add on the last wave).
func wave_zombies(di: int, w: int) -> Array[int]:
	var out: Array[int] = []
	var waves: Array = district(di).get("waves", [])
	if w < 0 or w >= waves.size():
		return out
	var za: Array = list("z_add")
	var add: int = int(za[di]) if di < za.size() else 0
	if w == waves.size() - 1:
		var bw: Array = list("boss_wave_add")
		add += int(bw[di]) if di < bw.size() else 0
	for z: Variant in waves[w]:
		out.append(int(z) + add)
	return out


func rooms(di: int) -> Array:
	return district(di).get("rooms", [])


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


func all_perks() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in list("perks"):
		out.append(str(p))
	return out


func starter_perks() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in list("starter_perks"):
		out.append(str(p))
	return out


func unlocks_for(milestone: String) -> Array[String]:
	var out: Array[String] = []
	var u: Variant = extra.get("unlocks", {})
	if u is Dictionary:
		for v: Variant in u.get(milestone, []):
			out.append(str(v))
	return out
