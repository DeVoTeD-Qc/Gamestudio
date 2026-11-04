# brace_advisor.gd
# Purpose: The suggested Brace for the human's Brace prompt (cz12). Reads only the human's own view
#   (LoadoutRules.view(state, human): brace_prompt, me.loadout / next_hand / health, the public
#   last_shot) and printed card text (CardDB), so it can never use the rival's private cards.
# The suggestion: of every subset of the eligible cards, the one that
#   1. lets the fewest Hits through (blocks the most damage),
#   2. uses the fewest cards,
#   3. gives up the least next-turn value (keep_value: your best cards stay in your next hand;
#      a card that is Spent when it braces counts extra, it leaves the game),
#   4. overshoots the damage the least,
#   5. ties: the earlier cards in the next hand.
#   explain() says why in one short line.
# preview(view, cards) is the live result for any choice: total Brace, Hits, health after, out?, and
#   which cards come up into the next hand instead of the braced ones (braced cards go to the
#   bottom of the loadout, R25; Hits go on top and are free draws).
# Dependencies: CardData (via the lookup Callable: card id -> CardData), DataEnums.
# Author: UI/UX Agent (cz12)
extends RefCounted

## Extra keep value for a card that is Spent when it braces (it leaves the game).
const SPENT_PENALTY: int = 3


## The suggestion for a view that has a brace_prompt: {cards (inst, next-hand order), card_ids,
## total, damage, hits, blocked, value_lost, eliminated, reason}. {} without a prompt.
static func suggest(view: Dictionary, lookup: Callable) -> Dictionary:
	var bp: Dictionary = view.get("brace_prompt", {})
	if bp.is_empty():
		return {}
	var damage: int = int(bp.get("damage", 0))
	var eligible: Array[int] = []
	for x: Variant in bp.get("eligible", []):
		eligible.append(int(x))
	var ids: Dictionary = _ids(view)
	var best: Array[int] = []
	var best_key: Array = []
	var n: int = eligible.size()
	for mask: int in range(1 << n):
		var pick: Array[int] = []
		for i: int in n:
			if mask & (1 << i):
				pick.append(eligible[i])
		var key: Array = _key(pick, damage, ids, lookup, eligible)
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			best = pick
	var out: Dictionary = preview(view, best, lookup)
	out["cards"] = best
	out["value_lost"] = int(best_key[2])
	out["reason"] = explain(view, out, lookup)
	return out


## The result of bracing with `cards` (inst ids): {cards, card_ids, total, damage, hits, blocked,
## health, health_after, eliminated, comes_up (card ids that enter the next hand instead)}.
static func preview(view: Dictionary, cards: Array, lookup: Callable) -> Dictionary:
	var bp: Dictionary = view.get("brace_prompt", {})
	var me: Dictionary = view.get("me", {})
	var ids: Dictionary = _ids(view)
	var damage: int = int(bp.get("damage", 0))
	var total: int = 0
	var card_ids: Array = []
	for x: Variant in cards:
		var c: CardData = _card(ids, int(x), lookup)
		card_ids.append(StringName(ids.get(int(x), &"")))
		total += c.brace if c != null else 0
	var hits: int = maxi(0, damage - total)
	var health: int = int(me.get("health", 0))
	return {"cards": cards.duplicate(), "card_ids": card_ids, "total": total, "damage": damage, "hits": hits,
			"blocked": mini(total, damage), "health": health, "health_after": maxi(0, health - hits),
			"eliminated": hits > health, "comes_up": _comes_up(view, cards, ids, lookup)}


## One short line: why this brace.
static func explain(view: Dictionary, s: Dictionary, lookup: Callable) -> String:
	var bp: Dictionary = view.get("brace_prompt", {})
	var damage: int = int(s.get("damage", 0))
	var cards: Array = s.get("cards", [])
	var hits: int = int(s.get("hits", 0))
	if (bp.get("eligible", []) as Array).is_empty():
		return "Nothing in your next hand can brace: %s." % _hits_text(hits)
	if cards.is_empty():
		return "Nothing to block."
	var ids: Dictionary = _ids(view)
	var used: String = "%d card%s" % [cards.size(), "" if cards.size() == 1 else "s"]
	var line: String = ""
	if hits == 0:
		line = "Blocks all %d damage with %s" % [damage, used] if cards.size() > 1 or damage > 1 else "Blocks the damage with %s" % used
	else:
		line = "Your best block: stops %d of %d, %s" % [int(s.get("blocked", 0)), damage, _hits_text(hits)]
	# Name the best card it keeps when that card could have braced too.
	var kept: int = 0
	var kept_v: int = -1
	for x: Variant in bp.get("eligible", []):
		var inst: int = int(x)
		if cards.has(inst):
			continue
		var c: CardData = _card(ids, inst, lookup)
		var v: int = keep_value(c)
		if c != null and v > kept_v:
			kept_v = v
			kept = inst
	if kept != 0 and hits == 0:
		line += ", keeping %s for your turn" % _card(ids, kept, lookup).display_name
	for x: Variant in cards:
		var c: CardData = _card(ids, int(x), lookup)
		if c != null and c.spent == DataEnums.SpentMode.ON_BRACE:
			line += " (%s is spent)" % c.display_name
			break
	line += "."
	if bool(s.get("eliminated", false)):
		line += " Not enough armour to survive."
	return line


## How much a card is worth in your next hand (higher = keep it). Printed card text only.
static func keep_value(c: CardData) -> int:
	if c == null:
		return 0
	var v: int = c.cost
	if c.supply_drop:
		v += 8
	if c.is_weapon():
		v += 3 + c.dmg * c.fires_per_turn
	elif c.is_attachment():
		v += 3
	v += c.heal * 2 + c.pull
	if c.spent == DataEnums.SpentMode.ON_BRACE:
		v += SPENT_PENALTY
	return v


# --- Internals ------------------------------------------------------------------------

## [hits, cards, value lost, overshoot, next-hand positions]: smaller is better.
static func _key(pick: Array[int], damage: int, ids: Dictionary, lookup: Callable, order: Array[int]) -> Array:
	var total: int = 0
	var lost: int = 0
	var pos: Array = []
	for inst: int in pick:
		var c: CardData = _card(ids, inst, lookup)
		total += c.brace if c != null else 0
		lost += keep_value(c)
		pos.append(order.find(inst))
	return [maxi(0, damage - total), pick.size(), lost, maxi(0, total - damage), pos]


static func _less(a: Array, b: Array) -> bool:
	for i: int in 4:
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	var pa: Array = a[4]
	var pb: Array = b[4]
	for i: int in mini(pa.size(), pb.size()):
		if int(pa[i]) != int(pb[i]):
			return int(pa[i]) < int(pb[i])
	return pa.size() < pb.size()


## inst -> card id for every card of the human's the view shows (loadout, next hand).
static func _ids(view: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var me: Dictionary = view.get("me", {})
	var bp: Dictionary = view.get("brace_prompt", {})
	for list: Variant in [me.get("loadout", []), me.get("next_hand", []), bp.get("next_hand", [])]:
		for cv: Variant in list:
			out[int(cv["id"])] = StringName(str(cv["card"]))
	return out


static func _card(ids: Dictionary, inst: int, lookup: Callable) -> CardData:
	var id: StringName = ids.get(inst, &"")
	return lookup.call(id) if id != &"" else null


## Card ids that would come up into the next hand: the loadout without the braced cards (they go
## to the bottom, or out of the game when Spent), first hand_size non-Hit cards, minus the old ones.
static func _comes_up(view: Dictionary, cards: Array, ids: Dictionary, lookup: Callable) -> Array:
	var me: Dictionary = view.get("me", {})
	var bp: Dictionary = view.get("brace_prompt", {})
	var hand_size: int = int(bp.get("hand_size", (me.get("next_hand", []) as Array).size()))
	var before: Array = []
	for cv: Variant in me.get("next_hand", []):
		before.append(int(cv["id"]))
	var order: Array = []
	for cv: Variant in me.get("loadout", []):
		if not cards.has(int(cv["id"])):
			order.append(int(cv["id"]))
	var out: Array = []
	var real: int = 0
	for inst: Variant in order:
		if real >= hand_size:
			break
		var c: CardData = _card(ids, int(inst), lookup)
		if c == null or c.is_hit():
			continue
		real += 1
		if not before.has(int(inst)):
			out.append(StringName(ids[int(inst)]))
	return out


static func _hits_text(hits: int) -> String:
	return "%d Hit%s land%s" % [hits, "" if hits == 1 else "s", "s" if hits == 1 else ""]
