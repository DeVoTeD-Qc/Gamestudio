# dd_balance.gd
# Purpose: Loads every tunable number from res://data/balance.json, which mirrors CONFIG in
#   projects/deaddraw/tools/sim_deaddraw.py. The file may be strict JSON or a pasted Python dict
#   (True/False/None, # comments, trailing commas, a leading "CONFIG =" are all accepted).
#   Numbers the sim hard-codes outside CONFIG live in "extra_rules"; a missing key falls back
#   to the sim's value (DEFAULT_EXTRA), so pasting the bare CONFIG dict never breaks the game.
# Dependencies: none (pure data, safe in headless tests).
# Author: Mechanics Developer Agent
class_name DDBalance
extends RefCounted

const DEFAULT_PATH: String = "res://data/balance.json"

# Values the sim hard-codes in apply()/play_district()/play_run() (sim_deaddraw.py).
const DEFAULT_EXTRA: Dictionary = {
	"medkits_per_street": 1,
	"triage_medkits_per_street": 2,
	"field_kit_bonus": 1,
	"knuckle_wraps_reduction": 2,
	"sandbags_bonus": 2,
	"thick_jacket_hp": 4,
	"scrounger_heal": 1,
	"tripwire_cover": 2,
	"second_wind_hp": 1,
	"score_per_district": 10,
	"unlocks": {
		"maple_row": ["perk:second_wind"],
		"downtown": ["survivor:theo"],
		"win": ["perk:tripwire", "badge"],
	},
}

const DEFAULT_TOP: Dictionary = {
	"start_hp": 20, "max_hp": 20, "street_size": 4, "resolve_per_street": 3,
	"safehouse_heal": 12, "perk_choices": 3, "fire_axe_power": 7,
	"weapon_scrap": true, "retreat_mode": "bottom",
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
			b.config[k] = DEFAULT_TOP[k]
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


func rule(key: String) -> int:
	return int(extra.get(key, DEFAULT_EXTRA.get(key, 0)))


func weapon_scrap() -> bool:
	return bool(config.get("weapon_scrap", true))


func retreat_mode() -> String:
	return str(config.get("retreat_mode", "bottom"))


func districts() -> Array:
	return config.get("districts", [])


func district(index: int) -> Dictionary:
	var d: Array = districts()
	return d[index] if index >= 0 and index < d.size() else {}


func district_count() -> int:
	return districts().size()


func survivors() -> Dictionary:
	return config.get("survivors", {})


func survivor(id: String) -> Dictionary:
	return survivors().get(id, {})


func survivor_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in survivors().keys():
		out.append(str(k))
	return out


func survivor_hp(id: String) -> int:
	var s: Dictionary = survivor(id)
	return int(s.get("hp", num("start_hp")))


func survivor_max_hp(id: String) -> int:
	var s: Dictionary = survivor(id)
	return int(s.get("hp", num("max_hp")))


func all_perks() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in config.get("perks", []):
		out.append(str(p))
	return out


func starter_perks() -> Array[String]:
	var out: Array[String] = []
	for p: Variant in config.get("starter_perks", []):
		out.append(str(p))
	return out


func unlocks_for(milestone: String) -> Array[String]:
	var out: Array[String] = []
	var u: Variant = extra.get("unlocks", {})
	if u is Dictionary:
		for v: Variant in u.get(milestone, []):
			out.append(str(v))
	return out
