# run_map.gd
# Purpose: The Run v2 map (run-v2.md §2): one act, 9 steps, 3 lanes. Plain data plus seeded
#   generation and movement; RunProgress owns one and resolves the nodes (fights, events, shops,
#   rests). Everything ahead is visible from the start: node types, each fight's crew and Terrain,
#   the boss; an event node shows its title (its options show on arrival).
#     step  1        2          3          4               5          6               7          8          9
#     L              [Event]    [Fight b]  [Elite I]                  [Shop]          [Fight b]  [Rest]
#     M     [F1]                [F2 a]     [Event|Shop]    [F3 a]     [Elite II]      [F4 a]                [BOSS]
#     R              [Shop]                [Rest]          [F3 b]     [Event|Rest]               [Shop]
#   (run 2+; step 4's Event is a Shop 30% of the time, step 6's Event a Rest 30%; the second fight node
#   of steps 3 / 5 / 7 has the same crew with different Terrain). From a node you may move to a node of
#   the next step in your lane or a neighbouring lane (if none is, to the nearest one).
#   The first run (§2.5) is a fixed short map with one fork:
#     [F1] -> [Event: Quartermaster's Audit] -> [F2] -> [Elite I | Rest] -> [F3] -> [Shop] -> [F4] -> [Rest] -> [Boss]
#   Node: {id, step, lane, type, links: [ids], event: id (event nodes), fight: FIGHT (fight / elite / boss)}
#   FIGHT: {slot (config.matches index, -1 = boss), ladder (1-4: the F number whose rung / offers it uses;
#     an elite = the next fight's), label ("F1".."F4", "Elite I", "Elite II", "Boss"), elite, boss,
#     armor (extra enemy Armor over the slot's), terrain: [3 ids], challenge (Old Rival's Message)}.
#   JSON-safe (to_dict / from_dict) for the run save.
# Dependencies: RunConfig, TerrainRules, RunModifiers, DataEnums.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name RunMap
extends RefCounted

const STEPS: int = 9
const LANES: int = 3
const TYPE_FIGHT: StringName = &"fight"
const TYPE_ELITE: StringName = &"elite"
const TYPE_EVENT: StringName = &"event"
const TYPE_SHOP: StringName = &"shop"
const TYPE_REST: StringName = &"rest"
const TYPE_BOSS: StringName = &"boss"
const TYPES: Array[StringName] = [TYPE_FIGHT, TYPE_ELITE, TYPE_EVENT, TYPE_SHOP, TYPE_REST, TYPE_BOSS]
const FIGHT_TYPES: Array[StringName] = [TYPE_FIGHT, TYPE_ELITE, TYPE_BOSS]
const TYPE_NAMES: Dictionary = {TYPE_FIGHT: "Fight", TYPE_ELITE: "Elite", TYPE_EVENT: "Event", TYPE_SHOP: "Shop",
		TYPE_REST: "Rest", TYPE_BOSS: "Boss"}
## The event fixed on the first run's step 2.
const FIRST_RUN_EVENT: StringName = &"audit"
## Event ids in Dossier order (data/events/<id>.tres).
const EVENTS: Array[StringName] = [&"supply_truck", &"audit", &"wounded_scout", &"fixer", &"radio_chatter",
		&"memorial", &"rival_message", &"range_day", &"night_drop"]
## Odds that step 4's Event is a Shop / step 6's Event a Rest (§2.1).
const SWAP_CHANCE: float = 0.3

var first_run: bool = false
var nodes: Array[Dictionary] = []
## Node the player is on (&"" before F1).
var current: StringName = &""
## Nodes stepped on, in order.
var visited: Array[StringName] = []
## Nodes resolved (fight played, event / shop / rest left).
var done: Array[StringName] = []


# =============================================================================
# Generation
# =============================================================================

## A seeded map. `modifiers` = RunModifiers ids (Hot Ground adds Terrain, Veteran Crews adds Armor).
static func generate(cfg: RunConfig, seed_value: int, p_first_run: bool, modifiers: Array = []) -> RunMap:
	var m: RunMap = RunMap.new()
	m.first_run = p_first_run
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ("%d|map" % seed_value).hash()
	var layout: Array = _first_run_layout() if p_first_run else _layout(rng)
	# Events drawn without repeats (the first run's step 2 is always the Audit).
	var deck: Array[StringName] = EVENTS.duplicate()
	for i: int in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: StringName = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	var terrain_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	terrain_rng.seed = ("%d|terrain" % seed_value).hash()
	var f3_two: bool = terrain_rng.randf() < cfg.terrain_f3_extra_chance
	for step: int in layout.size():
		for entry: Array in layout[step]:
			var lane: int = entry[0]
			var type: StringName = entry[1]
			var node: Dictionary = {"id": node_id(step, lane), "step": step, "lane": lane, "type": type,
					"links": [] as Array[StringName], "event": &"", "fight": {}}
			if type == TYPE_EVENT:
				node["event"] = FIRST_RUN_EVENT if p_first_run else (deck.pop_back() if not deck.is_empty() else FIRST_RUN_EVENT)
			elif type in FIGHT_TYPES:
				node["fight"] = _fight(cfg, step, type, p_first_run, modifiers, f3_two, terrain_rng)
			m.nodes.append(node)
	m._link()
	return m


static func node_id(step: int, lane: int) -> StringName:
	return StringName("s%d_%s" % [step + 1, "lmr"[lane]])


## Run 2+ layout: per step, [[lane, type], ...].
static func _layout(rng: RandomNumberGenerator) -> Array:
	var s4_mid: StringName = TYPE_SHOP if rng.randf() < SWAP_CHANCE else TYPE_EVENT
	var s6_right: StringName = TYPE_REST if rng.randf() < SWAP_CHANCE else TYPE_EVENT
	return [
		[[1, TYPE_FIGHT]],
		[[0, TYPE_EVENT], [2, TYPE_SHOP]],
		[[0, TYPE_FIGHT], [1, TYPE_FIGHT]],
		[[0, TYPE_ELITE], [1, s4_mid], [2, TYPE_REST]],
		[[1, TYPE_FIGHT], [2, TYPE_FIGHT]],
		[[0, TYPE_SHOP], [1, TYPE_ELITE], [2, s6_right]],
		[[0, TYPE_FIGHT], [1, TYPE_FIGHT]],
		[[0, TYPE_REST], [2, TYPE_SHOP]],
		[[1, TYPE_BOSS]],
	]


static func _first_run_layout() -> Array:
	return [
		[[1, TYPE_FIGHT]],
		[[1, TYPE_EVENT]],
		[[1, TYPE_FIGHT]],
		[[0, TYPE_ELITE], [2, TYPE_REST]],
		[[1, TYPE_FIGHT]],
		[[1, TYPE_SHOP]],
		[[1, TYPE_FIGHT]],
		[[1, TYPE_REST]],
		[[1, TYPE_BOSS]],
	]


## Fight data of a node at `step` (fights on steps 0/2/4/6 = F1-F4; elites on 3 / 5).
static func _fight(cfg: RunConfig, step: int, type: StringName, p_first_run: bool, modifiers: Array,
		f3_two: bool, rng: RandomNumberGenerator) -> Dictionary:
	var f: Dictionary = {"slot": -1, "ladder": 0, "label": "", "elite": type == TYPE_ELITE, "boss": type == TYPE_BOSS,
			"armor": 0, "terrain": [&"", &"", &""] as Array[StringName], "challenge": false}
	var count: int = 0
	var veterans: bool = RunModifiers.VETERANS in modifiers
	match type:
		TYPE_BOSS:
			f["label"] = "Boss"
			count = 0 if p_first_run else (1 if RunModifiers.HOT_GROUND in modifiers else 0)
		TYPE_ELITE:
			var k: int = 3 if step <= 3 else 4  # Elite I: the F3 crew; Elite II: the F4 crew
			f["slot"] = k - 1
			f["ladder"] = k
			f["label"] = "Elite I" if k == 3 else "Elite II"
			# The crew's slot Armor + the elite bonus (as the kc-v2-design sim: not F4's map bonus).
			f["armor"] = cfg.elite_armor_bonus + (1 if veterans else 0)
			count = cfg.first_run_elite_terrain if p_first_run else cfg.elite_terrain
		_:
			var k2: int = step / 2 + 1
			f["slot"] = k2 - 1
			f["ladder"] = k2
			f["label"] = "F%d" % k2
			f["armor"] = _fight_armor(cfg, k2) + (1 if veterans and k2 == 4 else 0)
			var table: PackedInt32Array = cfg.first_run_terrain if p_first_run else cfg.terrain_per_fight
			count = table[k2 - 1] if k2 - 1 < table.size() else 0
			if not p_first_run and k2 == 3 and f3_two:
				count += 1
	if RunModifiers.HOT_GROUND in modifiers and not p_first_run and type != TYPE_BOSS:
		count += 1
	count = mini(2, count)
	var mode: int = DataEnums.GameMode.ZONE_CONTROL
	if int(f["slot"]) >= 0 and int(f["slot"]) < cfg.matches.size():
		mode = cfg.matches[int(f["slot"])].mode
	f["mode"] = mode
	f["terrain"] = TerrainRules.deal(rng, count, mode)
	return f


## Extra Armor of fight F(k) on the map (RunConfig.fight_armor_bonus).
static func _fight_armor(cfg: RunConfig, k: int) -> int:
	return cfg.fight_armor_bonus[k - 1] if k >= 1 and k <= cfg.fight_armor_bonus.size() else 0


## Links: each node to the next step's nodes in its lane or a neighbouring one (none: the nearest).
func _link() -> void:
	for n: Dictionary in nodes:
		var nxt: Array[Dictionary] = step_nodes(int(n["step"]) + 1)
		var links: Array[StringName] = []
		for o: Dictionary in nxt:
			if absi(int(o["lane"]) - int(n["lane"])) <= 1:
				links.append(o["id"])
		if links.is_empty() and not nxt.is_empty():
			var best: Dictionary = nxt[0]
			for o: Dictionary in nxt:
				if absi(int(o["lane"]) - int(n["lane"])) < absi(int(best["lane"]) - int(n["lane"])):
					best = o
			links.append(best["id"])
		n["links"] = links


# =============================================================================
# Queries and movement
# =============================================================================

func node(id: StringName) -> Dictionary:
	for n: Dictionary in nodes:
		if n["id"] == id:
			return n
	return {}


func step_nodes(step: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Dictionary in nodes:
		if int(n["step"]) == step:
			out.append(n)
	return out


func current_node() -> Dictionary:
	return node(current) if current != &"" else {}


## Step index of the current node (-1 before F1).
func current_step() -> int:
	var n: Dictionary = current_node()
	return int(n["step"]) if not n.is_empty() else -1


## Node ids you may move to now: step 1's nodes before the run's first move, else the current node's
## links once it is resolved (none while it is not).
func reachable() -> Array[StringName]:
	var out: Array[StringName] = []
	if current == &"":
		for n: Dictionary in step_nodes(0):
			out.append(n["id"])
		return out
	if current not in done:
		return out
	for id: StringName in current_node().get("links", []):
		out.append(id)
	return out


func can_move_to(id: StringName) -> bool:
	return id in reachable()


func move_to(id: StringName) -> void:
	current = id
	visited.append(id)


func mark_done(id: StringName) -> void:
	if id not in done:
		done.append(id)


func is_last_step() -> bool:
	return current_step() >= STEPS - 1


## The next fight step's fight nodes after the current one (Radio Chatter, Old Rival's Message): the
## nodes of the first step ahead that has a fight / elite node (never the boss).
func next_fight_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for step: int in range(current_step() + 1, STEPS):
		for n: Dictionary in step_nodes(step):
			if n["type"] == TYPE_FIGHT:
				out.append(n)
		if not out.is_empty():
			return out
	return out


## Fights F1-F4 already played (elites don't count): the ladder position.
func fights_done() -> int:
	var n: int = 0
	for id: StringName in done:
		if node(id).get("type", &"") == TYPE_FIGHT:
			n += 1
	return n


# =============================================================================
# Save
# =============================================================================

func to_dict() -> Dictionary:
	var ns: Array = []
	for n: Dictionary in nodes:
		var d: Dictionary = {"id": String(n["id"]), "step": int(n["step"]), "lane": int(n["lane"]),
				"type": String(n["type"]), "links": (n["links"] as Array).map(func(x: Variant) -> String: return String(x)),
				"event": String(n.get("event", ""))}
		var f: Dictionary = n.get("fight", {})
		if not f.is_empty():
			d["fight"] = {"slot": int(f["slot"]), "ladder": int(f["ladder"]), "label": String(f["label"]),
					"elite": bool(f["elite"]), "boss": bool(f["boss"]), "armor": int(f["armor"]), "mode": int(f.get("mode", 0)),
					"terrain": (f["terrain"] as Array).map(func(x: Variant) -> String: return String(x)),
					"challenge": bool(f.get("challenge", false))}
		ns.append(d)
	return {"first_run": first_run, "nodes": ns, "current": String(current),
			"visited": visited.map(func(x: StringName) -> String: return String(x)),
			"done": done.map(func(x: StringName) -> String: return String(x))}


## Rebuilds a map from to_dict() data. {map, error}.
static func from_dict(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("nodes")) != TYPE_ARRAY:
		return {"map": null, "error": "bad map"}
	var m: RunMap = RunMap.new()
	m.first_run = bool(d.get("first_run", false))
	var ids: Array[StringName] = []
	for raw: Variant in d["nodes"]:
		if typeof(raw) != TYPE_DICTIONARY:
			return {"map": null, "error": "bad map node"}
		var type: StringName = StringName(str(raw.get("type", "")))
		if type not in TYPES:
			return {"map": null, "error": "unknown map node type '%s'" % type}
		var n: Dictionary = {"id": StringName(str(raw.get("id", ""))), "step": int(raw.get("step", 0)),
				"lane": int(raw.get("lane", 0)), "type": type, "links": [] as Array[StringName],
				"event": StringName(str(raw.get("event", ""))), "fight": {}}
		for l: Variant in raw.get("links", []):
			(n["links"] as Array[StringName]).append(StringName(str(l)))
		if type in FIGHT_TYPES:
			var f: Variant = raw.get("fight")
			if typeof(f) != TYPE_DICTIONARY:
				return {"map": null, "error": "fight node without fight data"}
			var ter: Array[StringName] = [&"", &"", &""]
			var rt: Variant = f.get("terrain", [])
			if typeof(rt) == TYPE_ARRAY:
				for i: int in mini(3, (rt as Array).size()):
					var t: StringName = StringName(str(rt[i]))
					if t != &"" and t not in TerrainRules.ALL:
						return {"map": null, "error": "unknown Terrain '%s'" % t}
					ter[i] = t
			n["fight"] = {"slot": int(f.get("slot", -1)), "ladder": int(f.get("ladder", 0)), "label": str(f.get("label", "")),
					"elite": bool(f.get("elite", false)), "boss": bool(f.get("boss", false)), "armor": int(f.get("armor", 0)),
					"mode": int(f.get("mode", 0)), "terrain": ter, "challenge": bool(f.get("challenge", false))}
		if type == TYPE_EVENT and StringName(n["event"]) not in EVENTS:
			return {"map": null, "error": "unknown event '%s'" % n["event"]}
		ids.append(n["id"])
		m.nodes.append(n)
	m.current = StringName(str(d.get("current", "")))
	if m.current != &"" and m.current not in ids:
		return {"map": null, "error": "current node '%s' is not on the map" % m.current}
	for key: String in ["visited", "done"]:
		var list: Array[StringName] = m.get(key)
		for x: Variant in d.get(key, []):
			if StringName(str(x)) not in ids:
				return {"map": null, "error": "%s node '%s' is not on the map" % [key, str(x)]}
			list.append(StringName(str(x)))
	return {"map": m, "error": ""}
