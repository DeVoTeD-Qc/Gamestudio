# dd_card.gd
# Purpose: One DeadDraw v2 card: a zombie (maybe a Carrier with a drop, maybe a boss), a weapon
#   (by weapon id), an ammo, medkit or barricade card. Mirrors Card in sim_deaddraw_v2.py.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DDCard
extends RefCounted

const ZOMBIE: String = "Z"
const WEAPON: String = "W"
const AMMO: String = "A"
const MEDKIT: String = "M"
const BARRICADE: String = "B"

var kind: String = ZOMBIE
## Zombie strength, ammo rounds, medkit heal, barricade cover; for weapons the power as dealt.
var value: int = 0
## Weapon id ("revolver") for weapon cards.
var wid: String = ""
## Carrier drop ("full_load", "payday", "boards"); empty for normal zombies.
var drop: String = ""
## Boss trait ("shatter", "horde", "quarantine"); empty for normal cards.
var boss_trait: String = ""
## Display name for boss cards (e.g. "The Groundskeeper").
var finale_name: String = ""
## True while the card sits on the street as last street's Holdover.
var holdover: bool = false
## True while the card is back from the Skipped pile (known information, shown as a badge).
var skipped: bool = false


static func make(k: String, v: int, t: String = "", fname: String = "") -> DDCard:
	var c: DDCard = DDCard.new()
	c.kind = k
	c.value = v
	c.boss_trait = t
	c.finale_name = fname
	return c


static func weapon(id: String, power: int) -> DDCard:
	var c: DDCard = make(WEAPON, power)
	c.wid = id
	return c


## Test/debug codes: "Z9", "Z9!payday" (Carrier), "W:revolver", "A4", "M5", "B2".
## A weapon's power is filled in by DDRun (it depends on balance data).
static func parse(s: String) -> DDCard:
	if s.begins_with("W:"):
		return weapon(s.substr(2), 0)
	var drop_at: int = s.find("!")
	var body: String = s if drop_at < 0 else s.substr(0, drop_at)
	var c: DDCard = make(body.substr(0, 1), int(body.substr(1)))
	if drop_at >= 0:
		c.drop = s.substr(drop_at + 1)
	return c


func is_finale() -> bool:
	return boss_trait != ""


func is_boss() -> bool:
	return boss_trait != ""


func code() -> String:
	if kind == WEAPON:
		return "W:" + wid
	if drop != "":
		return "%s%d!%s" % [kind, value, drop]
	return "%s%d" % [kind, value]
