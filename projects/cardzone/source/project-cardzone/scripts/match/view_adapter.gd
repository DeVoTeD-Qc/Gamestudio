# view_adapter.gd
# Purpose: Turns LoadoutRules.view(state, seat) (MatchView, spec §16.2) into the match screen's
#   state shape (mock_match_data.gd's, plus instance ids so taps map back to engine cards).
#   Reads only the view: whatever the view leaves out (the rival's hand, held cards and loadout
#   order) can't reach the screen.
# Extra keys over the cz10 shape:
#   you.hand_ids / next_ids / held_ids (instance ids, same order as hand / next), you.line[i].id,
#   you.move / search / fired (weapon inst -> times) / braced, you.next_hand_ids,
#   rival.line ([{card, attached, id}]) and rival.move / search during its turn,
#   phase, active, me (seat), pending_brace, brace_prompt?, shot_preview?, match_end, drops/crates.
# Dependencies: CardDB (areas, balance), DataEnums.
# Author: UI/UX Agent (cz11)
extends RefCounted


static func _db() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("CardDB") if loop != null else null


## v: MatchView. rival_kind: shown in the rival panel. rival_last_line: card ids of the rival's
## last packed line (public, remembered by the controller).
static func to_screen(v: Dictionary, rival_kind: String = "AI", rival_last_line: Array = []) -> Dictionary:
	var db: Node = _db()
	var bal: BalanceConfig = db.get_balance()
	var me: Dictionary = v["me"]
	var opp: Dictionary = v["opponent"]
	var seat: int = int(v["seat"])
	var max_health: int = bal.health
	var out: Dictionary = {
		"round": maxi(1, int(v["round"])), "zone_index": maxi(1, int(v["zone_card"])),
		"route": route_enum(String(v.get("route", "A"))), "hand_size": bal.hand_size,
		"phase": String(v["phase"]), "active": int(v["active"]), "me": seat,
		"pending_brace": int(v.get("pending_brace", -1)), "match_end": v.get("match_end", {}),
		"areas": _areas(v),
	}
	if v.has("brace_prompt"):
		out["brace_prompt"] = v["brace_prompt"]
	if v.has("shot_preview"):
		out["shot_preview"] = v["shot_preview"]
	var hand: Array = []
	var hand_ids: Array = []
	for c: Dictionary in me["hand"]:
		hand.append(StringName(c["card"]))
		hand_ids.append(int(c["id"]))
	var next: Array = []
	var next_ids: Array = []
	for c: Dictionary in me["next_draw"]:
		next.append(StringName(c["card"]))
		next_ids.append(int(c["id"]))
	var next_hand_ids: Array = []
	for c: Dictionary in me["next_hand"]:
		next_hand_ids.append(int(c["id"]))
	var held: Array = []
	var held_ids: Array = []
	for c: Dictionary in me["loadout"]:
		if (me["held"] as Array).has(int(c["id"])):
			held.append(StringName(c["card"]))
			held_ids.append(int(c["id"]))
	out["you"] = {
		"name": "You", "area": StringName(me["area"]), "health": int(me["health"]), "max_health": max_health,
		"bounty": int(v["bounty"]) == seat, "down": bool(me["down"]), "hand": hand, "hand_ids": hand_ids,
		"line": _line(me["line"]), "held": held, "held_ids": held_ids, "next": next, "next_ids": next_ids,
		"next_hand_ids": next_hand_ids,
		"loadout_rest": maxi(0, int(me["loadout_count"]) - next.size()), "move": int(me["move"]),
		"search": int(me["search"]), "fired": me["fired"], "braced": me["braced"], "eliminated": bool(me["eliminated"]),
		"adrenaline_played": int(me["adrenaline_played"]), "ditched": int(me["ditched"]),
	}
	var last: Array = []
	for id: Variant in rival_last_line:
		last.append(StringName(str(id)))
	out["rival"] = {
		"name": "Rival", "kind": rival_kind, "area": StringName(opp["area"]), "health": int(opp["health"]),
		"max_health": max_health, "bounty": int(v["bounty"]) == 1 - seat, "down": bool(opp["down"]),
		"loadout_count": int(opp.get("loadout_count", 0)), "held_count": int(opp["held_count"]),
		"hand_count": int(opp["hand_count"]), "line": _line(opp["line"]), "last_line": last,
		"move": int(opp["move"]), "search": int(opp["search"]), "eliminated": bool(opp["eliminated"]),
		"next_draw_hits": int(opp.get("next_draw_hits", 0)),
	}
	return out


static func route_enum(letter: String) -> int:
	return clampi("ABC".find(letter.to_upper()), 0, 2)


static func _line(cards: Array) -> Array:
	var out: Array = []
	for c: Dictionary in cards:
		var att: Array = []
		for a: Variant in c.get("attachments", []):
			att.append(StringName(str(a)))
		out.append({"card": StringName(c["card"]), "attached": att, "id": int(c["id"])})
	return out


## Map state: piles (card + count), the first ready drop, crates, gas.
static func _areas(v: Dictionary) -> Dictionary:
	var db: Node = _db()
	var out: Dictionary = {}
	var gas: Array = v.get("gas", [])
	var piles: Dictionary = v.get("piles", {})
	var drops: Dictionary = v.get("drops", {})
	for a: AreaData in db.all_areas():
		var list: Array = []
		var here: Dictionary = piles.get(a.id, piles.get(String(a.id), {}))
		for cid: Variant in here.keys():
			if int(here[cid]) > 0:
				list.append({"card": StringName(str(cid)), "count": int(here[cid])})
		var drop: StringName = &""
		var drop_list: Array = drops.get(a.id, drops.get(String(a.id), []))
		if not drop_list.is_empty():
			drop = StringName(drop_list[0]["card"])
		var crates: Array = []
		for cr: Dictionary in v.get("crates", []):
			if StringName(str(cr["area"])) == a.id:
				for c: Dictionary in cr["cards"]:
					crates.append(StringName(c["card"]))
		out[a.id] = {"gas": gas.has(String(a.id)) or gas.has(a.id), "piles": list, "drop": drop, "crate": crates}
	return out
