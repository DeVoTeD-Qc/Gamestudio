# run_v2_views.gd
# Purpose: The UI's one door to Run v2 (run-v2.md §11.1 "Hooks for the UI"; kc-v2-ui). Screens never
#   reach into RunProgress / MatchState fields for v2: they ask here, and this file asks the rules'
#   view functions when they exist (RunProgress.map_view / shop_view / event_view / rest_options,
#   MatchState.terrain_view / ability_view / boss_view) and normalises what comes back into the
#   shapes below. While a hook is missing (the rules are written in parallel, kc-v2-impl) the
#   screens fall back to the v1 flow, and the sample_* views (the spec's own content) drive the
#   previews, screenshots and UI tests.
#   Actions (choose a node, buy, pick an event option, rest) go through act(), which calls the
#   RunState autoload first (it saves and announces) and RunProgress second, and returns "" on
#   success or the refusal in words.
#
#   Shapes (every key optional unless noted; see board-layout-v2.md "kc-v2-ui" for the contract):
#     map   {steps, lanes, step, lane, req, tickets, tickets_max, threat, modifiers: [mod], boss: boss,
#            nodes: [node], links: [[from_id, to_id]], pending: &"" | &"event" | &"shop" | &"rest"}
#     node  {id, step (1..9), lane (0..2), type: fight|elite|event|shop|rest|boss, title, crew, mode,
#            terrain: [terrain], gives, risk, reachable, done, current, result: &"player"|&"enemy"|&"draw"|&"",
#            fight (1..4, 0 = none)}
#     terrain {id, name, text, zone (0..2), active_for: [sides]}
#     boss  {id, name, crew, mode, rule_name, rule_text, armor_bonus, deck: [card ids]}
#     mod   {id, name, threat, text, locked, unlock, on}
#     shop  {req, cards: [{index, card_id, kind, price, sold}], muster_price, discharge_price,
#            perk: {price, options: [ids]}, restock_price, deck_size, floor}
#     event {id, title, scene, options: [{index, label, result, odds, cost_req, cost_ticket, cards: [ids], ok, reason}]}
#     rest  [{id, title, result, ok, reason}]
#     ability {id, name, text, ready, used, needs_operator, operator_on_board, targets, reason}
# Dependencies: RunProgress, MatchState (optional hooks), RunState (autoload).
# Author: UI/UX Agent (kc-v2-ui)
extends RefCounted

const NODE_TYPES: Array[StringName] = [&"fight", &"elite", &"event", &"shop", &"rest", &"boss"]
const LANE_WORDS: Array[String] = ["LEFT", "MIDDLE", "RIGHT"]
const ZONE_LETTERS: Array[String] = ["A", "B", "C"]

## Node words when the rules give none: title, what it gives, what it risks.
const NODE_WORDS: Dictionary = {
	&"fight": ["FIGHT", "Win: a Supply Drop, +3 REQ.", "Lose: -1 ticket, Salvage, +1 REQ."],
	&"elite": ["ELITE", "Win: an Elite Cache (one rung ahead, pick 2 of 4), Muster out, +5 REQ.", "A tougher crew (+1 Armor, 2 Terrains). Lose: -1 ticket."],
	&"event": ["EVENT", "A short scene with 2-3 choices. Every result is printed on its button.", "Some options cost a ticket or REQ (shown)."],
	&"shop": ["SHOP", "Spend REQ: cards, Muster out, Discharge, a Perk.", "No risk."],
	&"rest": ["REST", "Pick one: +1 ticket, Drill (send 2 cards home) or Field-strip (a weapon level).", "No risk."],
	&"boss": ["BOSS", "Win: the run is won.", "Lose: the run ends."],
}

## Terrain words when the rules give none (run-v2.md §6.1, the one line as printed).
const TERRAIN: Dictionary = {
	&"rooftops": ["Rooftops", "Whoever holds this column at the start of the round has First Shot here."],
	&"smoke": ["Smoke", "No Pick or Flank here: every shot hits the front unit."],
	&"dust_storm": ["Dust Storm", "No First Shot here."],
	&"breach_point": ["Breach Point", "Every unit here has Pierce."],
	&"floodlights": ["Floodlights", "Red dots here are shown face-up to both sides."],
	&"comms_tower": ["Comms Tower", "Hold this column at the end of the round: +1 streak."],
	&"supply_cache": ["Supply Cache", "Hold this column at the end of the round: +1 Supply next round."],
	&"hot_zone": ["Hot Zone", "Holding this column scores 1 extra point."],
	&"minefield": ["Minefield", "Each round, the first unit each side brings here takes 1 damage."],
	&"field_hospital": ["Field Hospital", "End of round: each side's most damaged unit here heals 1."],
}
## One example per Terrain for the inspector (the "what it makes you decide" column).
const TERRAIN_TIPS: Dictionary = {
	&"rooftops": "Take it early and keep it; arriving into a held Rooftops is expensive.",
	&"smoke": "Put your Marksman elsewhere; a wall in front is safe here.",
	&"dust_storm": "Breachers and Point Men lose their edge; plain bodies trade evenly.",
	&"breach_point": "Stack damage here; don't park fragile cards behind one wall.",
	&"floodlights": "No surprises here: commit where you have the better card.",
	&"comms_tower": "A streak race: holding it brings killstreaks sooner.",
	&"supply_cache": "Tempo: hold it early, spend it late.",
	&"hot_zone": "The match is decided here; the rival fights for it too.",
	&"minefield": "Lead with a cheap or sturdy card; never drop a 2-Armor Marksman in first.",
	&"field_hospital": "Long fights favour the side with the bigger Armor pool.",
}

## Operator kits when LoadoutItem has no passive / ability yet (run-v2.md §7, as printed).
const OPERATOR_KITS: Dictionary = {
	&"kestrel_ar7": {"passive_name": "Quartermaster", "passive": "Your opening hand has 1 more card.",
			"ability_id": &"ab_dig_in", "ability_name": "Dig In", "ability": "Your units in a column have Cover 1 this round.",
			"target": "a column", "needs_operator": false, "unlock": ""},
	&"longreach_338": {"passive_name": "Overpenetration", "passive": "The Operator has Pierce.",
			"ability_id": &"ab_marked_shot", "ability_name": "Marked Shot", "ability": "3 damage to an enemy unit in the Operator's column.",
			"target": "an enemy unit in the Operator's column", "needs_operator": true, "unlock": "Finish your first run (win or lose)."},
	&"wasp_9": {"passive_name": "Run and Gun", "passive": "May Rotate twice per round.",
			"ability_id": &"ab_flashbang", "ability_name": "Flashbang", "ability": "Enemies in the Operator's column lose First Shot and get -2 FP this round.",
			"target": "the Operator's column", "needs_operator": true, "unlock": "Reach the boss once."},
	&"bastion_60": {"passive_name": "Sandbagged", "passive": "The Operator has Cover 1.",
			"ability_id": &"ab_covering_fire", "ability_name": "Covering Fire", "ability": "Your units in the Operator's column get +1 FP this round.",
			"target": "the Operator's column", "needs_operator": true, "unlock": "Win a run."},
}

const BOSSES: Dictionary = {
	&"meridian_six": {"name": "Meridian_Six", "crew": "Black Meridian · Spec Ops", "mode": "Zone Control",
			"rule_name": "Reinforcements", "rule_text": "From round 4, gains 1 extra Supply every round.", "armor_bonus": 1,
			"tip": "Win the Supply race before round 4, or hold out."},
	&"bulwark_prime": {"name": "Bulwark Prime", "crew": "Anchor · Heavy", "mode": "Firefight",
			"rule_name": "Dug In", "rule_text": "Starts the match with a Mortar Pit in every column.", "armor_bonus": 1,
			"tip": "Take a column to tear its pit down (Overrun)."},
	&"hollow_choir": {"name": "The Hollow Choir", "crew": "Undead", "mode": "Zone Control",
			"rule_name": "Horde", "rule_text": "From round 2, a 1/2 Shambler joins the back of its emptiest column every round. Shamblers don't hold ground; Pick and Flank ignore them.",
			"armor_bonus": 2, "tip": "Fields and Pick still reach the real crew behind the Shamblers."},
}

const MODIFIERS: Array[Dictionary] = [
	{"id": &"hardcore", "name": "Hardcore", "threat": 3, "text": "Start with 2 tickets; you can never have more than 2.", "unlock": "Win a run."},
	{"id": &"austerity", "name": "Austerity", "threat": 1, "text": "Supply Drops: take 1 card instead of 2.", "unlock": "Win a run with any 2 Operators."},
	{"id": &"veteran_crews", "name": "Veteran Crews", "threat": 1, "text": "F4 and the elites get +1 Armor.", "unlock": "Beat all three bosses."},
	{"id": &"fog_of_war", "name": "Fog of War", "threat": 1, "text": "No red dots for either side.", "unlock": "Win a run with Hardcore."},
	{"id": &"hot_ground", "name": "Hot Ground", "threat": 0, "text": "Every fight has one more Terrain (max 2); the boss gets 1.", "unlock": "Play on all 10 Terrains."},
]

## Tests and previews: non-null = use this instead of asking the run (e.g. sample_map_view()).
static var override_map: Dictionary = {}
static var override_shop: Dictionary = {}
static var override_event: Dictionary = {}
static var override_rest: Array = []
## Calls made through act() while an override is on (tests read them): [[method, args]].
static var act_log: Array = []


## Preview / test setters (a const preload can't assign a static var from outside in 4.4).
static func preview_map(v: Dictionary) -> void:
	override_map = v


static func preview_shop(v: Dictionary) -> void:
	override_shop = v


static func preview_event(v: Dictionary) -> void:
	override_event = v


static func preview_rest(v: Array) -> void:
	override_rest = v


static func clear_overrides() -> void:
	override_map = {}
	override_shop = {}
	override_event = {}
	override_rest = []
	act_log = []


# =============================================================================
# Run views
# =============================================================================

## True when the run plays the v2 map (the rules' map_view exists and has nodes, or a preview).
static func is_v2(run: Object) -> bool:
	return not (map_view(run).get("nodes", []) as Array).is_empty()


static func map_view(run: Object) -> Dictionary:
	if not override_map.is_empty():
		return override_map
	var v: Variant = _call(run, &"map_view")
	return normalise_map(v) if v is Dictionary else {}


static func shop_view(run: Object) -> Dictionary:
	if not override_shop.is_empty():
		return override_shop
	var v: Variant = _call(run, &"shop_view")
	return v if v is Dictionary else {}


static func event_view(run: Object) -> Dictionary:
	if not override_event.is_empty():
		return override_event
	var v: Variant = _call(run, &"event_view")
	return v if v is Dictionary else {}


static func rest_options(run: Object) -> Array:
	if not override_rest.is_empty():
		return override_rest
	var v: Variant = _call(run, &"rest_options")
	return v if v is Array else []


## REQ held (0 when the run has none).
static func req(run: Object) -> int:
	if not override_map.is_empty():
		return int(override_map.get("req", 0))
	if run != null and &"req" in run:
		return int(run.get("req"))
	return int(map_view(run).get("req", 0))


## The screen a v2 run wants now (&"" = the v1 router decides): &"event", &"shop", &"rest".
static func pending_screen(run: Object) -> StringName:
	return StringName(str(map_view(run).get("pending", "")))


## Fills the defaults a screen relies on (ids, words, links) so a partial rules view still draws.
static func normalise_map(v: Dictionary) -> Dictionary:
	var m: Dictionary = v.duplicate(true)
	m["steps"] = int(m.get("steps", 9))
	m["lanes"] = int(m.get("lanes", 3))
	var nodes: Array = m.get("nodes", [])
	for n: Dictionary in nodes:
		var t: StringName = StringName(str(n.get("type", "fight")))
		n["type"] = t
		if not n.has("id"):
			n["id"] = "s%dl%d" % [int(n.get("step", 0)), int(n.get("lane", 0))]
		n["id"] = String(n["id"])
		var words: Array = NODE_WORDS.get(t, ["", "", ""])
		if String(n.get("title", "")) == "":
			n["title"] = words[0]
		if String(n.get("gives", "")) == "":
			n["gives"] = words[1]
		if String(n.get("risk", "")) == "":
			n["risk"] = words[2]
		var ts: Array = []
		for tv: Variant in n.get("terrain", []):
			ts.append(terrain_entry(tv))
		n["terrain"] = ts
	m["nodes"] = nodes
	if not m.has("links"):
		m["links"] = auto_links(nodes)
	if m.get("boss", {}) is Dictionary and not (m.get("boss", {}) as Dictionary).is_empty():
		m["boss"] = boss_entry(m["boss"])
	var mods: Array = []
	for mv: Variant in m.get("modifiers", []):
		mods.append(modifier_entry(mv))
	m["modifiers"] = mods
	return m


## Links between neighbouring lanes at consecutive steps (the spec's movement rule, §2.1).
static func auto_links(nodes: Array) -> Array:
	var out: Array = []
	for a: Dictionary in nodes:
		for b: Dictionary in nodes:
			if int(b["step"]) == int(a["step"]) + 1 and absi(int(b["lane"]) - int(a["lane"])) <= 1:
				out.append([String(a["id"]), String(b["id"])])
	return out


static func node_by_id(map: Dictionary, id: String) -> Dictionary:
	for n: Dictionary in map.get("nodes", []):
		if String(n["id"]) == id:
			return n
	return {}


## A terrain entry from an id, or a partial dictionary from the rules.
static func terrain_entry(v: Variant) -> Dictionary:
	var e: Dictionary = {}
	if v is Dictionary:
		e = (v as Dictionary).duplicate()
	else:
		e = {"id": StringName(str(v))}
	var id: StringName = StringName(str(e.get("id", "")))
	e["id"] = id
	var w: Array = TERRAIN.get(id, [String(id).capitalize(), ""])
	if String(e.get("name", "")) == "":
		e["name"] = w[0]
	if String(e.get("text", "")) == "":
		e["text"] = w[1]
	e["zone"] = int(e.get("zone", -1))
	return e


static func boss_entry(v: Variant) -> Dictionary:
	var e: Dictionary = (v as Dictionary).duplicate() if v is Dictionary else {"id": StringName(str(v))}
	var id: StringName = StringName(str(e.get("id", "")))
	var base: Dictionary = BOSSES.get(id, {})
	for k: String in base:
		if not e.has(k) or str(e[k]) == "":
			e[k] = base[k]
	return e


static func modifier_entry(v: Variant) -> Dictionary:
	var e: Dictionary = (v as Dictionary).duplicate() if v is Dictionary else {"id": StringName(str(v)), "on": true}
	for m: Dictionary in MODIFIERS:
		if m["id"] == StringName(str(e.get("id", ""))):
			for k: String in m:
				if not e.has(k):
					e[k] = m[k]
	return e


## Modifier rows for the Loadout picker: the rules' list (RunProgress / RunState
## modifier_options()) or the spec's five, all locked except the ones the profile has unlocked.
static func modifier_options(run: Object) -> Array:
	var v: Variant = _call(run, &"modifier_options")
	if v == null:
		v = _call(_run_state(), &"modifier_options")
	if v is Array and not (v as Array).is_empty():
		var out: Array = []
		for e: Variant in v:
			out.append(modifier_entry(e))
		return out
	var rows: Array = []
	var on: Array = []
	if run != null and &"modifiers" in run:
		on = run.get("modifiers")
	for m: Dictionary in MODIFIERS:
		var e: Dictionary = m.duplicate()
		e["on"] = on.has(m["id"])
		e["locked"] = not e["on"]
		rows.append(e)
	return rows


static func threat_of(mods: Array) -> int:
	var t: int = 0
	for m: Dictionary in mods:
		if bool(m.get("on", true)) and not bool(m.get("locked", false)):
			t += int(m.get("threat", 0))
	return t


## The Operator kit of a Primary: passive and ability lines (LoadoutItem fields when they exist,
## else the spec's text), locked state and its unlock condition.
static func operator_kit(item: Resource) -> Dictionary:
	if item == null:
		return {}
	var id: StringName = StringName(str(item.get("id")))
	var k: Dictionary = (OPERATOR_KITS.get(id, {}) as Dictionary).duplicate()
	if &"passive_text" in item and str(item.get("passive_text")) != "":
		k["passive"] = str(item.get("passive_text"))
		if &"passive_name" in item and str(item.get("passive_name")) != "":
			k["passive_name"] = str(item.get("passive_name"))
	if &"ability" in item and item.get("ability") != null:
		var ab: Resource = item.get("ability")
		k["ability_id"] = StringName(str(ab.get("id")))
		k["ability_name"] = str(ab.get("display_name"))
		k["ability"] = str(ab.get("text"))
	var rs: Node = _run_state()
	var locked: Variant = _call(rs, &"is_operator_locked", [id])
	if locked == null:
		locked = _call(_settings(), &"is_operator_locked", [id])
	k["locked"] = bool(locked) if locked != null else false
	return k


# =============================================================================
# Match views
# =============================================================================

## Terrain per column ([] when the match has none or the rules have no terrain_view yet).
static func terrain_view(state: Object) -> Array:
	var v: Variant = _call(state, &"terrain_view")
	if not v is Array:
		return []
	var out: Array = []
	for t: Variant in v:
		out.append(terrain_entry(t))
	return out


## The Terrain of one column (zone 0..2), or {}.
static func terrain_at(terrains: Array, zone: int) -> Dictionary:
	for t: Dictionary in terrains:
		if int(t.get("zone", -1)) == zone:
			return t
	return {}


## The side's Operator ability, normalised; {} when the side has none.
static func ability_view(state: Object, side: int) -> Dictionary:
	var v: Variant = _call(state, &"ability_view", [side])
	if not v is Dictionary or (v as Dictionary).is_empty():
		return {}
	var a: Dictionary = (v as Dictionary).duplicate()
	a["id"] = StringName(str(a.get("id", "")))
	a["used"] = bool(a.get("used", not bool(a.get("ready", false)) and String(a.get("reason", "")) == ""))
	a["ready"] = bool(a.get("ready", false)) and not a["used"]
	return a


static func boss_view(state: Object) -> Dictionary:
	var v: Variant = _call(state, &"boss_view")
	if not v is Dictionary or (v as Dictionary).is_empty():
		return {}
	return boss_entry(v)


# =============================================================================
# Actions
# =============================================================================

## Calls `method` on RunState (preferred: it saves and announces), else on the run. "" = done,
## else the refusal in words. With a preview override on, the call is only logged.
static func act(run: Object, method: StringName, args: Array = []) -> String:
	if not override_map.is_empty() or not override_shop.is_empty() or not override_event.is_empty() or not override_rest.is_empty():
		act_log.append([method, args])
		return ""
	var rs: Node = _run_state()
	var target: Object = rs if rs != null and rs.has_method(method) else run
	if target == null or not target.has_method(method):
		return "This needs the Run v2 rules (%s)." % method
	var res: Variant = target.callv(method, args)
	if res is String:
		return res
	if res is Dictionary:
		var d: Dictionary = res
		return "" if bool(d.get("ok", true)) else String(d.get("reason", "Not possible."))
	if res is bool:
		return "" if res else "Not possible."
	return ""


static func _call(obj: Object, method: StringName, args: Array = []) -> Variant:
	if obj == null or not is_instance_valid(obj) or not obj.has_method(method):
		return null
	return obj.callv(method, args)


static func _run_state() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunState") if tree != null else null


static func _settings() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null


# =============================================================================
# Words
# =============================================================================

static func node_title(n: Dictionary) -> String:
	return String(n.get("title", NODE_WORDS.get(n.get("type", &"fight"), [""])[0]))


## "A · Smoke" lines for a node's terrain, or "No Terrain".
static func terrain_line(ts: Array) -> String:
	if ts.is_empty():
		return "No Terrain"
	var parts: PackedStringArray = []
	for t: Dictionary in ts:
		var z: int = int(t.get("zone", -1))
		parts.append(("%s %s" % [ZONE_LETTERS[z], t["name"]]) if z >= 0 and z < 3 else String(t["name"]))
	return " · ".join(parts)


# =============================================================================
# Samples (the spec's content: previews, screenshots, UI tests)
# =============================================================================

## A run-2 map (run-v2.md §2.1) with the player on the step-2 Event (left lane): step 3 offers
## two fights with different Terrain. done_to: steps up to this one are played.
static func sample_map_view(done_to: int = 2, current_lane: int = 0) -> Dictionary:
	var layout: Array = [
		[1, 1, &"fight", "[SV7] SandViper_07", "Zone Control", [{"id": &"rooftops", "zone": 1}], 1],
		[2, 0, &"event", "Abandoned Supply Truck", "", [], 0],
		[2, 2, &"shop", "", "", [], 0],
		[3, 0, &"fight", "[BN9] Bulwark_Nine", "Zone Control", [{"id": &"smoke", "zone": 0}], 2],
		[3, 1, &"fight", "[BN9] Bulwark_Nine", "Zone Control", [{"id": &"supply_cache", "zone": 2}], 2],
		[4, 0, &"elite", "[RSH] Rusher Honors +1 Armor", "Firefight", [{"id": &"breach_point", "zone": 0}, {"id": &"minefield", "zone": 2}], 0],
		[4, 1, &"event", "Radio Chatter", "", [], 0],
		[4, 2, &"rest", "", "", [], 0],
		[5, 1, &"fight", "[SV7] SandViper_07 Honors", "Firefight", [{"id": &"dust_storm", "zone": 1}], 3],
		[5, 2, &"fight", "[SV7] SandViper_07 Honors", "Firefight", [{"id": &"comms_tower", "zone": 0}, {"id": &"floodlights", "zone": 2}], 3],
		[6, 0, &"shop", "", "", [], 0],
		[6, 1, &"elite", "[BN9] Bulwark_Nine Mastery +1 Armor", "Firefight", [{"id": &"field_hospital", "zone": 1}, {"id": &"smoke", "zone": 2}], 0],
		[6, 2, &"event", "Range Day", "", [], 0],
		[7, 0, &"fight", "[BN9] Bulwark_Nine Mastery", "Firefight", [{"id": &"rooftops", "zone": 0}, {"id": &"minefield", "zone": 1}], 4],
		[7, 1, &"fight", "[BN9] Bulwark_Nine Mastery", "Firefight", [{"id": &"breach_point", "zone": 1}, {"id": &"supply_cache", "zone": 2}], 4],
		[8, 0, &"rest", "", "", [], 0],
		[8, 2, &"shop", "", "", [], 0],
		[9, 1, &"boss", "Meridian_Six", "Zone Control", [], 0],
	]
	var nodes: Array = []
	for row: Array in layout:
		var step: int = row[0]
		var n: Dictionary = {"id": "s%dl%d" % [step, row[1]], "step": step, "lane": row[1], "type": row[2],
				"crew": row[3], "mode": row[4], "terrain": row[5], "fight": row[6]}
		if row[2] == &"event":
			n["title"] = "EVENT"
			n["event"] = row[3]
			n["crew"] = ""
		n["done"] = step <= done_to and (step == 1 or (step == done_to and row[1] == current_lane))
		n["current"] = step == done_to and row[1] == current_lane
		if step == 1:
			n["result"] = &"player"
			n["current"] = done_to == 1
			n["done"] = true
		nodes.append(n)
	var m: Dictionary = {"steps": 9, "lanes": 3, "step": done_to, "lane": current_lane, "req": 7, "tickets": 3, "tickets_max": 3,
			"nodes": nodes, "boss": {"id": &"meridian_six"},
			"modifiers": [{"id": &"veteran_crews", "on": true}, {"id": &"hot_ground", "on": true}]}
	m = normalise_map(m)
	for n: Dictionary in m["nodes"]:
		n["reachable"] = false
	var cur: String = "s%dl%d" % [done_to, current_lane]
	for l: Array in m["links"]:
		if l[0] == cur:
			node_by_id(m, l[1])["reachable"] = true
	m["threat"] = threat_of(m["modifiers"])
	return m


static func sample_shop_view() -> Dictionary:
	return {"req": 7, "cards": [
				{"index": 0, "card_id": &"marksman", "kind": &"unit", "price": 4, "sold": false},
				{"index": 1, "card_id": &"suppressing_fire", "kind": &"tactic", "price": 3, "sold": false},
				{"index": 2, "card_id": &"sniper_perch", "kind": &"field", "price": 3, "sold": false}],
			"muster_price": 2, "discharge_price": 3, "restock_price": 1,
			"perk": {"price": 6, "options": [&"grit", &"field_salvage"]}, "deck_size": 20, "floor": 15}


static func sample_event_view() -> Dictionary:
	return {"id": &"abandoned_supply_truck", "title": "Abandoned Supply Truck",
			"scene": "A truck on its rims in a ditch, the tarp still lashed down.",
			"options": [
				{"index": 0, "label": "CRACK THE CRATES", "result": "+3 REQ.", "ok": true},
				{"index": 1, "label": "STRIP THE RADIO", "result": "Add a Comms Relay (Field) to your deck.", "cards": [&"comms_relay"], "ok": true},
				{"index": 2, "label": "DRIVE ON", "result": "Nothing happens.", "ok": true}]}


static func sample_rest_options() -> Array:
	return [
		{"id": &"ticket", "title": "+1 TICKET", "result": "Get a Reinforcement Ticket back (2 -> 3, max 3).", "ok": true},
		{"id": &"drill", "title": "DRILL", "result": "Send 2 cards of your choice home (the deck never goes under 15).", "ok": true},
		{"id": &"field_strip", "title": "FIELD-STRIP", "result": "A weapon level now: pick 1 of 2 upgrades for your Operator.", "ok": true}]
