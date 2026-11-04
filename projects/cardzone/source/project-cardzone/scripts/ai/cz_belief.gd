# cz_belief.gd
# Purpose: The CardZone AI's fairness wall (spec §16.2 P18, cz09). The AI may see only
#   view(state, seat) plus its own cards. CzBelief.world(state, seat) returns the ONLY state the
#   AI reads: a copy of the match in which every private field of the opponent (loadout order and
#   contents, held card identities, hand identities, and which attachments sit under a private
#   weapon) is thrown away and rebuilt from public information:
#     1. The opponent's card multiset is worked out from public facts only: the Standard pack,
#        the starting piles minus the pile counts now, the supply drops that landed (the Zone deck
#        and route are public) minus those still on the map, the removed-from-game cards, the
#        AI's own cards and the opponent's public line. (A player may remember every public event,
#        P18; this is the same count, done without needing the event history.)
#     2. Counts come from the view: hand_count, held_count, loadout_count, Hits in the next draw
#        and in hand (hits_on_top_public), health, and the line.
#     3. The guess is deterministic: held cards = the highest-Brace cards (or the real held cards
#        when held_cards_public is on); the Hits in the next draw sit on top under them; the rest
#        of the loadout spreads its Brace cards evenly (the expected Brace density); the remaining
#        Hits go to the bottom; the hand takes the lowest-Brace cards.
#   Old private instance ids are erased (defs, owners, attachments) and the guess gets new ids, so
#   two states that differ only in the opponent's private cards give byte-identical worlds
#   (tests/test_ai.gd checks the fingerprints and the moves). The action log, undo snapshots and
#   origin are not copied (they hold the opponent's private hold ids).
#   Pure and deterministic: no randomness, no node access.
# Dependencies: LoadoutRules (view), MatchState, SeatState, RulesData, CzSim, CardData.
# Author: Mechanics Developer Agent
class_name CzBelief
extends RefCounted

## Filler when the public count is short (fixtures that do not start from the Standard pack).
const FILLER: StringName = &"scavenge"


## The belief world for `seat`. Never changes `state`.
static func world(state: MatchState, seat: int) -> MatchState:
	var v: Dictionary = public_view(state, seat)
	var w: MatchState = CzSim.clone(state)
	var opp: int = state.opponent_of(seat)
	var ost: SeatState = w.seats[opp]
	# 1. Forget every private instance of the opponent.
	var private_ids: Array[int] = []
	private_ids.append_array(ost.loadout)
	private_ids.append_array(ost.hand)
	for inst: int in private_ids.duplicate():
		for att: int in w.attachments_of(inst):
			private_ids.append(att)
	for inst: int in private_ids:
		w.defs.erase(inst)
		w.owners.erase(inst)
		w.attachments.erase(inst)
	ost.loadout.clear()
	ost.hand.clear()
	ost.held.clear()
	# 2. Rebuild them from public information.
	var guess: Dictionary = guess_private(w.data, v, state.seats[seat], state)
	var held: Array[int] = []
	for entry: Dictionary in guess["held"]:
		var inst: int = _make(w, entry, opp)
		ost.loadout.append(inst)
		held.append(inst)
	for i: int in int(guess["top_hits"]):
		ost.loadout.append(w.new_card(w.data.hit_id, opp))
	for entry: Dictionary in guess["loadout"]:
		ost.loadout.append(_make(w, entry, opp))
	for i: int in int(guess["bottom_hits"]):
		ost.loadout.append(w.new_card(w.data.hit_id, opp))
	for i: int in int(guess["hand_hits"]):
		ost.hand.append(w.new_card(w.data.hit_id, opp))
	for entry: Dictionary in guess["hand"]:
		ost.hand.append(_make(w, entry, opp))
	ost.held = held
	return w


## The parts of view(state, seat) (MatchView) the guess reads, built by MatchView's own
## builders: {opponent, removed, piles, drops, zone_card}. Equal to those keys of the full view;
## skips the seat's own card lists and the shot record, which the guess does not need (speed).
static func public_view(state: MatchState, seat: int) -> Dictionary:
	return {"opponent": MatchView._opponent(state, state.opponent_of(seat)),
			"removed": MatchView._cards(state, state.removed), "piles": state.pile_counts(),
			"drops": MatchView._drops(state), "zone_card": state.zone_card}


## The opponent's private cards as public information sees them:
## {held: [entry], loadout: [entry], hand: [entry], top_hits, bottom_hits, hand_hits},
## entry = {id: StringName, atts: Array[StringName]}. Reads `v` (the view) and `me` (own seat);
## `state` is used only to name the AI's own card instances (its own private data).
static func guess_private(data: RulesData, v: Dictionary, me: SeatState, state: MatchState) -> Dictionary:
	var b: BalanceConfig = data.balance
	var o: Dictionary = v["opponent"]
	var counts: Dictionary = public_counts(data, v, me, state)
	# Entries (weapon + tucked attachments = one card).
	var held: Array[Dictionary] = []
	if o.has("held_cards"):
		for cv: Dictionary in o["held_cards"]:
			var e: Dictionary = {"id": StringName(cv["card"]), "atts": _names(cv["attachments"])}
			held.append(e)
			_take(counts, e["id"])
			for a: Variant in e["atts"]:
				_take(counts, a)
	var loose: Array[Dictionary] = []
	var ids: Array = counts.keys()
	ids.sort_custom(func(x: Variant, y: Variant) -> bool: return String(x) < String(y))
	for id: Variant in ids:
		for i: int in int(counts[id]):
			loose.append({"id": StringName(id), "atts": []})
	# Sizes from the view.
	var hand_hits: int = int(o.get("hand_hits", 0))
	var hand_nonhits: int = maxi(0, int(o["hand_count"]) - hand_hits)
	var line_hits: int = 0
	for cv: Dictionary in o["line"]:
		if StringName(cv["card"]) == data.hit_id:
			line_hits += 1
	var loadout_hits: int = maxi(0, b.health - int(o["health"]) - line_hits - hand_hits)
	var next_hits: int = int(o.get("next_draw_hits", 1 if bool(o["down"]) else 0))
	next_hits = mini(next_hits, loadout_hits)
	var want_total: int
	if o.has("loadout_count"):
		want_total = maxi(0, int(o["loadout_count"]) - loadout_hits) + hand_nonhits
	else:
		want_total = loose.size() + held.size()
	var want_loose: int = maxi(0, want_total - held.size())
	_fit(data, loose, want_loose)
	# Group equal entries (sorting a few groups is much cheaper than sorting every card).
	var groups: Dictionary = {}
	for e: Dictionary in loose:
		var k: String = _entry_key(e)
		if groups.has(k):
			groups[k]["n"] = int(groups[k]["n"]) + 1
		else:
			groups[k] = {"e": e, "n": 1, "brace": _brace(data, e)}
	var keys: Array = groups.keys()
	# Held: the real ones when public, else the highest-Brace cards (then by id).
	var held_count: int = int(o["held_count"])
	if held.size() < held_count:
		keys.sort_custom(func(x: Variant, y: Variant) -> bool:
			var bx: int = groups[x]["brace"]
			var by: int = groups[y]["brace"]
			return bx > by if bx != by else String(x) < String(y))
		for k: Variant in keys:
			while held.size() < held_count and int(groups[k]["n"]) > 0:
				held.append((groups[k]["e"] as Dictionary).duplicate(true))
				groups[k]["n"] = int(groups[k]["n"]) - 1
	# Hand: the lowest-Brace cards (then by id); the rest in the same order, spread.
	keys.sort_custom(func(x: Variant, y: Variant) -> bool:
		var bx: int = groups[x]["brace"]
		var by: int = groups[y]["brace"]
		return bx < by if bx != by else String(x) < String(y))
	var hand: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for k: Variant in keys:
		for i: int in int(groups[k]["n"]):
			var copy: Dictionary = (groups[k]["e"] as Dictionary).duplicate(true)
			if hand.size() < hand_nonhits:
				hand.append(copy)
			else:
				rest.append(copy)
	return {"held": held, "loadout": _spread(data, rest), "hand": hand, "top_hits": next_hits,
			"bottom_hits": loadout_hits - next_hits, "hand_hits": hand_hits}


static func _entry_key(e: Dictionary) -> String:
	var k: String = String(e["id"])
	for a: Variant in e["atts"]:
		k += "+" + String(a)
	return k


## Card id -> how many of it the opponent holds privately (loadout + hand, attachments loose),
## from public facts and the AI's own cards. Never negative.
static func public_counts(data: RulesData, v: Dictionary, me: SeatState, state: MatchState) -> Dictionary:
	var b: BalanceConfig = data.balance
	var mine: Dictionary = {}
	for list: Array[int] in [me.loadout, me.hand, me.line]:
		for inst: int in list:
			var id: StringName = state.defs.get(inst, &"")
			mine[id] = int(mine.get(id, 0)) + 1
			if state.attachments.has(inst):
				for att: Variant in state.attachments[inst]:
					var aid: StringName = state.defs.get(int(att), &"")
					mine[aid] = int(mine.get(aid, 0)) + 1
	var removed: Dictionary = {}
	for cv: Dictionary in v["removed"]:
		_add(removed, StringName(cv["card"]), 1)
		for a: Variant in cv["attachments"]:
			_add(removed, StringName(a), 1)
	var out: Dictionary = {}
	# Starters: the Standard pack, minus the opponent's share of the removed starters.
	var pack: Dictionary = {}
	for id: StringName in data.start_pack():
		_add(pack, id, 1)
	for id: Variant in pack.keys():
		var p: int = int(pack[id])
		var my_removed: int = maxi(0, p - int(mine.get(id, 0)))
		var opp_removed: int = maxi(0, int(removed.get(id, 0)) - my_removed)
		_add(out, id, p - opp_removed)
	# Loot: taken from the piles and drops, minus the AI's and the removed ones.
	var taken: Dictionary = {}
	var piles_now: Dictionary = v["piles"]
	for area_id: StringName in data.area_order:
		var area: AreaData = data.area(area_id)
		var now: Dictionary = piles_now.get(area_id, {})
		for c: CardData in area.piles:
			_add(taken, c.id, maxi(0, area.pile_size(b) - int(now.get(c.id, 0))))
	var flipped: int = mini(int(v["zone_card"]), b.zone_hard_end_card)
	for z: ZoneCardData in data.zone_cards:
		if z.number <= flipped and z.drop_card != null and z.drop_area_for(state.route) != null:
			_add(taken, z.drop_card.id, 1)
	for area_id: Variant in v["drops"].keys():
		for cv: Dictionary in v["drops"][area_id]:
			_add(taken, StringName(cv["card"]), -1)
	for id: Variant in taken.keys():
		if pack.has(id):
			continue
		_add(out, id, int(taken[id]) - int(mine.get(id, 0)) - int(removed.get(id, 0)))
	# Minus the opponent's public line.
	for cv: Dictionary in v["opponent"]["line"]:
		_add(out, StringName(cv["card"]), -1)
		for a: Variant in cv["attachments"]:
			_add(out, StringName(a), -1)
	for id: Variant in out.keys():
		if int(out[id]) <= 0 or StringName(id) == data.hit_id:
			out.erase(id)
	return out


# --- Internals --------------------------------------------------------------------------

static func _make(w: MatchState, entry: Dictionary, owner: int) -> int:
	var inst: int = w.new_card(entry["id"], owner)
	var atts: Array = []
	for a: Variant in entry["atts"]:
		atts.append(w.new_card(a, owner))
	if not atts.is_empty():
		w.attachments[inst] = atts
	return inst


## Makes `loose` exactly `n` cards: tucks attachments under weapons first (a weapon with its
## attachments is one card, D2), then drops Starters (then anything) from the end, or pads with
## FILLER.
static func _fit(data: RulesData, loose: Array[Dictionary], n: int) -> void:
	if loose.size() > n:
		var weapons: Array[Dictionary] = []
		for e: Dictionary in loose:
			var c: CardData = data.card(e["id"])
			if c != null and c.is_weapon():
				weapons.append(e)
		weapons.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			var cx: CardData = data.card(x["id"])
			var cy: CardData = data.card(y["id"])
			if cx.dmg * cx.fires_per_turn != cy.dmg * cy.fires_per_turn:
				return cx.dmg * cx.fires_per_turn > cy.dmg * cy.fires_per_turn
			return String(x["id"]) < String(y["id"]))
		var i: int = loose.size() - 1
		while loose.size() > n and i >= 0:
			var e: Dictionary = loose[i]
			var c: CardData = data.card(e["id"])
			if c != null and c.is_attachment():
				for wpn: Dictionary in weapons:
					var atts: Array = wpn["atts"]
					if atts.size() < 2 and not atts.has(e["id"]):
						atts.append(e["id"])
						loose.remove_at(i)
						break
			i -= 1
	var j: int = loose.size() - 1
	while loose.size() > n and j >= 0:
		var c: CardData = data.card(loose[j]["id"])
		if c == null or c.is_starter():
			loose.remove_at(j)
		j -= 1
	while loose.size() > n:
		loose.pop_back()
	while loose.size() < n:
		loose.append({"id": FILLER, "atts": []})


## Brace cards spread evenly through the rest (the expected next hand), others in id order.
static func _spread(data: RulesData, cards: Array[Dictionary]) -> Array[Dictionary]:
	var braces: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for e: Dictionary in cards:
		if _brace(data, e) > 0:
			braces.append(e)
		else:
			others.append(e)
	var n: int = cards.size()
	var out: Array[Dictionary] = []
	out.resize(n)
	var used: Array[bool] = []
	used.resize(n)
	for j: int in braces.size():
		var pos: int = mini(n - 1, int((float(j) + 0.5) * float(n) / float(braces.size())))
		while used[pos]:
			pos = (pos + 1) % n
		out[pos] = braces[j]
		used[pos] = true
	var k: int = 0
	for pos: int in n:
		if not used[pos]:
			out[pos] = others[k]
			k += 1
	return out


static func _brace(data: RulesData, e: Dictionary) -> int:
	var c: CardData = data.card(e["id"])
	return c.brace if c != null else 0


static func _names(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x: Variant in list:
		out.append(StringName(x))
	return out


static func _add(d: Dictionary, key: StringName, n: int) -> void:
	d[key] = int(d.get(key, 0)) + n


static func _take(d: Dictionary, key: StringName) -> void:
	if int(d.get(key, 0)) > 0:
		d[key] = int(d[key]) - 1
