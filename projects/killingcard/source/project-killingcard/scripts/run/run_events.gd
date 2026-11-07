# run_events.gd
# Purpose: The rules of the 9 run-map Events (run-v2.md §3). The text lives in res://data/events/
#   (EventData: title, scene, options {label, detail, effect, amount, cost_req, needs, card}); this
#   applies an option's `effect`. Every option says exactly what it does, odds printed, and an option
#   that can't be taken right now is shown unavailable with the reason.
#   Effects: req (+amount REQ), add_card (card), nothing, muster_out (queue a Muster out of amount),
#   ticket (+1 ticket, pay cost_req), swap_card (remove a card, gain a random unit of the full pool),
#   sell_card (remove a card, +amount REQ), jam_terrain (next fight: no Terrain), pick_terrain (next
#   fight: one Terrain chosen from amount), copy_card (copy a calling card, same trait), challenge (next
#   fight +amount enemy Armor, pays like an elite), weapon_level (queue a weapon level), drills (next
#   Supply Drop shows +amount cards), gamble_elite (amount%: an Elite card, else lose 1 ticket).
#   Static; RunProgress calls view() / choose() for the current event node.
# Dependencies: RunProgress, RunMap, EventData, RewardOffers, TerrainRules, CardData.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name RunEvents
extends RefCounted

const EFFECTS: Array[String] = ["req", "add_card", "nothing", "muster_out", "ticket", "swap_card", "sell_card",
		"jam_terrain", "pick_terrain", "copy_card", "challenge", "weapon_level", "drills", "gamble_elite"]
const DATA_DIR: String = "res://data/events"

static var _cache: Dictionary = {}


static func data(id: StringName) -> EventData:
	if id == &"":
		return null
	if not _cache.has(id):
		_cache[id] = load("%s/%s.tres" % [DATA_DIR, id]) as EventData if ResourceLoader.exists("%s/%s.tres" % [DATA_DIR, id]) else null
	return _cache[id]


## The current event: {id, title, scene, options: [{index, id, label, detail, available, reason, needs,
## choices}]}. {} when the run is not on an event.
static func view(run: RunProgress) -> Dictionary:
	var ev: EventData = data(run.current_event_id())
	if ev == null or run.phase != RunProgress.PHASE_EVENT:
		return {}
	var opts: Array[Dictionary] = []
	for i: int in ev.options.size():
		var o: Dictionary = ev.options[i]
		var why: String = _unavailable(run, o)
		opts.append({"index": i, "id": StringName(String(o.get("id", ""))), "label": String(o.get("label", "")),
				"detail": String(o.get("detail", "")), "available": why == "", "reason": why,
				"needs": StringName(String(o.get("needs", ""))), "choices": _choices(run, o)})
	return {"id": ev.id, "title": ev.title, "scene": ev.scene, "options": opts}


static func _unavailable(run: RunProgress, o: Dictionary) -> String:
	var cost: int = int(o.get("cost_req", 0))
	if cost > run.req:
		return "Needs %d REQ" % cost
	match String(o.get("effect", "")):
		"ticket":
			if run.tickets >= run.max_tickets():
				return "Your tickets are full"
		"muster_out":
			if run.standard_issue_count() == 0:
				return "No Standard Issue cards left"
			if run.deck.size() <= run.config.deck_floor:
				return "Your deck is at %d cards" % run.config.deck_floor
		"sell_card":
			if run.deck.size() <= run.config.deck_floor:
				return "Your deck is at %d cards" % run.config.deck_floor
		"copy_card":
			if _calling_cards(run).is_empty():
				return "No calling card to copy"
		"jam_terrain", "pick_terrain", "challenge":
			if run.map == null or run.map.next_fight_nodes().is_empty():
				return "No fight ahead"
		"weapon_level":
			if RewardOffers.attachments(run.config, run.resource(run.primary) as LoadoutItem, run.attachments,
					RandomNumberGenerator.new()).is_empty():
				return "Your weapon is fully kitted"
		"gamble_elite":
			if run.tickets <= 1:
				return "You can't risk your last ticket"
	return ""


## Sub-choices of an option: deck rows for deck_card / calling_card, Terrain rows for terrain.
static func _choices(run: RunProgress, o: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match String(o.get("needs", "")):
		"deck_card":
			for i: int in run.deck.size():
				out.append(run.copy_row(i))
		"calling_card":
			for i: int in _calling_cards(run):
				out.append(run.copy_row(i))
		"terrain":
			for t: StringName in terrain_choices(run, int(o.get("amount", 3))):
				var td: TerrainData = TerrainRules.data(t)
				out.append({"id": t, "name": td.display_name if td != null else "", "text": td.text if td != null else ""})
	return out


## Deck indices of calling cards (units with a trait; not Standard Issue, not Elite).
static func _calling_cards(run: RunProgress) -> Array[int]:
	var out: Array[int] = []
	for i: int in run.deck.size():
		var c: CardData = run.resource(run.deck[i]) as CardData
		if c != null and c.is_unit() and not c.standard_issue and not c.is_elite and run.copy_trait(i) != &"":
			out.append(i)
	return out


## Radio Chatter's "Pick the ground": `n` Terrains for the next fight (seeded per node; Hot Zone only
## when that fight is Zone Control).
static func terrain_choices(run: RunProgress, n: int) -> Array[StringName]:
	var nxt: Array[Dictionary] = run.map.next_fight_nodes() if run.map != null else [] as Array[Dictionary]
	var mode: int = int(nxt[0]["fight"].get("mode", 0)) if not nxt.is_empty() else DataEnums.GameMode.ZONE_CONTROL
	var pool: Array[StringName] = []
	for t: StringName in TerrainRules.ALL:
		if t in TerrainRules.ZONE_CONTROL_ONLY and mode != DataEnums.GameMode.ZONE_CONTROL:
			continue
		pool.append(t)
	var rng: RandomNumberGenerator = run.node_rng("radio")
	var out: Array[StringName] = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## Applies option `index` of the current event. args: {deck_index} / {terrain}. Returns
## {ok, reason, text, changes: {req, tickets, added: [ids], removed: [ids]}}.
static func choose(run: RunProgress, index: int, args: Dictionary = {}) -> Dictionary:
	var ev: EventData = data(run.current_event_id())
	if ev == null or run.phase != RunProgress.PHASE_EVENT:
		return _fail("no event to choose from")
	if index < 0 or index >= ev.options.size():
		return _fail("no option %d" % index)
	var o: Dictionary = ev.options[index]
	var why: String = _unavailable(run, o)
	if why != "":
		return _fail(why)
	var amount: int = int(o.get("amount", 0))
	var req0: int = run.req
	var t0: int = run.tickets
	var added: Array[StringName] = []
	var removed: Array[StringName] = []
	var text: String = ""
	var queued: bool = false
	var di: int = int(args.get("deck_index", -1))
	var effect: String = String(o.get("effect", ""))
	# Validate sub-choices before anything changes.
	match effect:
		"swap_card", "sell_card":
			if di < 0 or di >= run.deck.size():
				return _fail("pick a card")
		"copy_card":
			if di not in _calling_cards(run):
				return _fail("pick a calling card")
		"pick_terrain":
			if StringName(args.get("terrain", &"")) not in terrain_choices(run, amount):
				return _fail("pick one of the offered Terrains")
	run.req -= int(o.get("cost_req", 0))
	match effect:
		"req":
			run.req += amount
			text = "+%d REQ" % amount
		"add_card":
			var id: StringName = StringName(String(o.get("card", "")))
			if run.gain_card(id) >= 0:
				added.append(id)
			text = "%s added to your deck" % _card_name(run, id)
		"nothing":
			text = "You move on"
		"muster_out":
			run.queue_offer({"kind": RewardOffers.KIND_MUSTER_OUT, "options": run.standard_issue_ids(), "count": amount})
			queued = true
			text = "Muster out %d Standard Issue cards" % amount
		"ticket":
			run.tickets = mini(run.max_tickets(), run.tickets + amount)
			text = "+1 ticket"
		"swap_card", "sell_card":
			removed.append(run.deck[di])
			run.remove_copy(di)
			if effect == "sell_card":
				run.req += amount
				text = "%s sold: +%d REQ" % [_card_name(run, removed[0]), amount]
			else:
				var pool: Array[StringName] = []
				for c: CardData in run.config.reward_pool:
					if c != null and c.is_unit() and c.collectible and c.id not in pool:
						pool.append(c.id)
				var got: StringName = pool[run.node_rng("fixer").randi_range(0, pool.size() - 1)] if not pool.is_empty() else &""
				if got != &"" and run.gain_card(got) >= 0:
					added.append(got)
				text = "%s swapped for %s" % [_card_name(run, removed[0]), _card_name(run, got)]
		"jam_terrain":
			for n: Dictionary in run.map.next_fight_nodes():
				n["fight"]["terrain"] = [&"", &"", &""] as Array[StringName]
			text = "Your next fight has no Terrain"
		"pick_terrain":
			var t: StringName = StringName(args["terrain"])
			for n: Dictionary in run.map.next_fight_nodes():
				var ter: Array[StringName] = [&"", &"", &""]
				ter[run.node_rng("radio_col").randi_range(0, 2)] = t
				n["fight"]["terrain"] = ter
			text = "Your next fight is on %s" % TerrainRules.name_of(t)
		"copy_card":
			var cid: StringName = run.deck[di]
			if run.copy_deck_card(di) >= 0:
				added.append(cid)
			text = "%s copied" % _card_name(run, cid)
		"challenge":
			for n: Dictionary in run.map.next_fight_nodes():
				n["fight"]["challenge"] = true
			text = "Your next fight: enemy +%d Armor, pays %d REQ" % [amount, run.config.req_elite]
		"weapon_level":
			run.queue_weapon_level()
			queued = true
			text = "A weapon level"
		"drills":
			run.next_drop_extra += amount
			text = "Your next Supply Drop shows %d more card" % amount
		"gamble_elite":
			if run.node_rng("night_drop").randi_range(1, 100) <= amount:
				var elites: Array[StringName] = []
				for c: CardData in run.config.reward_pool:
					if c != null and c.is_elite and c.id not in elites:
						elites.append(c.id)
				var e: StringName = elites[run.node_rng("night_drop_card").randi_range(0, elites.size() - 1)] if not elites.is_empty() else &""
				if e != &"" and run.gain_card(e) >= 0:
					added.append(e)
				text = "You found %s" % _card_name(run, e)
			else:
				run.tickets = maxi(0, run.tickets - 1)
				text = "It was a trap: -1 ticket"
	run.finish_node(queued)
	return {"ok": true, "reason": "", "text": text,
			"changes": {"req": run.req - req0, "tickets": run.tickets - t0, "added": added, "removed": removed}}


static func _card_name(run: RunProgress, id: StringName) -> String:
	var c: CardData = run.resource(id) as CardData
	return c.display_name if c != null else String(id)


static func _fail(why: String) -> Dictionary:
	return {"ok": false, "reason": why, "text": "", "changes": {}}
