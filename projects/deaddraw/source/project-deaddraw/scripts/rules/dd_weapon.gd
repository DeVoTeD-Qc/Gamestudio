# dd_weapon.gd
# Purpose: A weapon in one of the two slots (sim slot tuple: power, mag_cap, ammo, notch,
#   upgraded, wid). mag_cap 0 = melee (unlimited uses). Every weapon has the notch: after a kill it
#   only hits zombies weaker than that kill (equal too for Rosa, or a Retrofit "Keen" melee).
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DDWeapon
extends RefCounted

const NO_NOTCH: int = 99

var wid: String = ""
var name: String = ""
var power: int = 0
var cap: int = 0
var ammo: int = 0
var notch: int = NO_NOTCH
## Retrofit Bench upgrade (once per weapon). Melee: "Keen" (notch also allows equal strength).
var upgraded: bool = false


static func make(id: String, display_name: String, p: int, mag: int) -> DDWeapon:
	var w: DDWeapon = DDWeapon.new()
	w.wid = id
	w.name = display_name
	w.power = p
	w.cap = mag
	w.ammo = mag
	return w


func is_gun() -> bool:
	return cap > 0


func is_fresh() -> bool:
	return notch >= NO_NOTCH


func display_name() -> String:
	return ("Retrofit " + name) if upgraded else name


func copy() -> DDWeapon:
	var w: DDWeapon = DDWeapon.new()
	w.wid = wid
	w.name = name
	w.power = power
	w.cap = cap
	w.ammo = ammo
	w.notch = notch
	w.upgraded = upgraded
	return w


func to_dict() -> Dictionary:
	return {"wid": wid, "name": name, "power": power, "cap": cap, "ammo": ammo, "notch": notch, "upgraded": upgraded}
