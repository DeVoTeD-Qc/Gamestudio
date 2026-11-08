# dd_card.gd
# Purpose: One DeadDraw v3 card in the pile / on the street: a zombie (maybe a boss card, maybe a
#   Patient Zero phase), a gun (by weapon id), a medkit or a cover card. Mirrors Card in
#   tools/sim_deaddraw_v3.py.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DDCard
extends RefCounted

const ZOMBIE: String = "Z"
const WEAPON: String = "W"
const MEDKIT: String = "M"
const COVER: String = "C"

var kind: String = ZOMBIE
## Zombie number (strength and point value), medkit heal, cover amount; 0 for guns.
var value: int = 0
## Weapon id ("rifle") for gun cards.
var wid: String = ""
## Boss trait ("shatter", "horde", "phases") and display name; empty for normal cards.
var boss_trait: String = ""
var boss_name: String = ""
## Patient Zero: 1, 2, 3 (each phase appears when the previous one is dead); 0 otherwise.
var phase: int = 0
## True while the card sits on the street as last street's Holdover.
var holdover: bool = false


static func make(k: String, v: int) -> DDCard:
	var c: DDCard = DDCard.new()
	c.kind = k
	c.value = v
	return c


static func gun(id: String) -> DDCard:
	var c: DDCard = make(WEAPON, 0)
	c.wid = id
	return c


static func boss(v: int, trait_id: String, display_name: String, phase_no: int = 0) -> DDCard:
	var c: DDCard = make(ZOMBIE, v)
	c.boss_trait = trait_id
	c.boss_name = display_name
	c.phase = phase_no
	return c


## Test / debug codes: "Z9", "W:rifle", "M5", "C2".
static func parse(s: String) -> DDCard:
	if s.begins_with("W:"):
		return gun(s.substr(2))
	return make(s.substr(0, 1), int(s.substr(1)))


func is_boss() -> bool:
	return boss_trait != ""


func code() -> String:
	if kind == WEAPON:
		return "W:" + wid
	return "%s%d" % [kind, value]


func to_dict() -> Dictionary:
	var d: Dictionary = {"k": kind, "v": value}
	if wid != "":
		d["w"] = wid
	if boss_trait != "":
		d["t"] = boss_trait
		d["n"] = boss_name
	if phase != 0:
		d["p"] = phase
	if holdover:
		d["h"] = true
	return d


static func from_dict(d: Dictionary) -> DDCard:
	var c: DDCard = make(str(d.get("k", "Z")), int(d.get("v", 0)))
	c.wid = str(d.get("w", ""))
	c.boss_trait = str(d.get("t", ""))
	c.boss_name = str(d.get("n", ""))
	c.phase = int(d.get("p", 0))
	c.holdover = bool(d.get("h", false))
	return c
