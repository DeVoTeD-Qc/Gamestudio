# dd_card.gd
# Purpose: One DeadDraw card (zombie, weapon, medkit or barricade). Mirrors Card in the sim.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DDCard
extends RefCounted

const ZOMBIE: String = "Z"
const WEAPON: String = "W"
const MEDKIT: String = "M"
const BARRICADE: String = "B"

var kind: String = ZOMBIE
var value: int = 0
## Finale trait ("shatter", "horde", "quarantine"); empty for normal cards.
var boss_trait: String = ""
## Display name for finale cards (e.g. "The Groundskeeper").
var finale_name: String = ""
## True while the card sits on the street as last street's Holdover.
var holdover: bool = false
## True while the card sits in the deck after a Retreat sent it to the bottom (known information).
var retreated: bool = false


static func make(k: String, v: int, t: String = "", fname: String = "") -> DDCard:
	var c: DDCard = DDCard.new()
	c.kind = k
	c.value = v
	c.boss_trait = t
	c.finale_name = fname
	return c


## "Z9" -> zombie 9, "W6" -> weapon 6, "M4", "B3". Used by tests and debug tools.
static func parse(s: String) -> DDCard:
	return DDCard.make(s.substr(0, 1), int(s.substr(1)))


func is_finale() -> bool:
	return boss_trait != ""


func code() -> String:
	return "%s%d" % [kind, value]
