# dd_gun.gd
# Purpose: A gun in one of the two slots (sim tuple: wid, rule, power, cap, stack, honed). Kills
#   stack on it; the rule checks each new kill against the stack; when the stack is full the gun
#   is finished. `flipped`: the Retrofit Bench reversed its rule (down <-> up).
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DDGun
extends RefCounted

var wid: String = ""
var name: String = ""
var rule: String = "any"
var power: int = 0
var cap: int = 0
## Zombie numbers in kill order (the top kill is the back).
var stack: Array[int] = []
## Retrofit Bench: Hone (+1 power, once per gun) and Flip (rule reversed).
var honed: bool = false
var flipped: bool = false


static func make(id: String, display_name: String, rule_id: String, p: int, capacity: int) -> DDGun:
	var g: DDGun = DDGun.new()
	g.wid = id
	g.name = display_name
	g.rule = rule_id
	g.power = p
	g.cap = capacity
	return g


func top() -> int:
	return stack[stack.size() - 1] if not stack.is_empty() else 0


func total() -> int:
	var t: int = 0
	for z: int in stack:
		t += z
	return t


func kills_left() -> int:
	return maxi(0, cap - stack.size())


func copy() -> DDGun:
	var g: DDGun = make(wid, name, rule, power, cap)
	g.stack = stack.duplicate()
	g.honed = honed
	g.flipped = flipped
	return g


func to_dict() -> Dictionary:
	return {"wid": wid, "name": name, "rule": rule, "power": power, "cap": cap, "stack": stack.duplicate(),
		"honed": honed, "flipped": flipped}


static func from_dict(d: Variant) -> DDGun:
	if not d is Dictionary:
		return null
	var g: DDGun = make(str(d.get("wid", "")), str(d.get("name", "")), str(d.get("rule", "any")), int(d.get("power", 0)), int(d.get("cap", 0)))
	for z: Variant in d.get("stack", []):
		g.stack.append(int(z))
	g.honed = bool(d.get("honed", false))
	g.flipped = bool(d.get("flipped", false))
	return g
