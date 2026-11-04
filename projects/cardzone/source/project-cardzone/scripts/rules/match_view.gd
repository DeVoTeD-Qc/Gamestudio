# match_view.gd
# Purpose: view(state, seat): everything one seat may see (spec §16.2, P1-P20; field names from
#   QA's RQ-10). The UI, the AI (AiView) and hot-seat read only this. Fairness rule (P18): for
#   any two states that differ only in the opponent's private fields (loadout order and
#   contents, held card identities, hand identities), the view is identical. So every field is
#   either public or derived from public data, and a hidden field is left out, never null.
# Dependencies: MatchState, SeatState, LoadoutRules, BalanceConfig.
# Author: Mechanics Developer Agent
class_name MatchView
extends RefCounted


static func build(state: MatchState, seat: int) -> Dictionary:
	var b: BalanceConfig = state.data.balance
	var opp: int = state.opponent_of(seat)
	var v: Dictionary = {
		"seat": seat,
		"phase": String(state.phase),
		"round": state.round_number,
		"zone_card": state.zone_card,
		"zone_hard_end_card": b.zone_hard_end_card,
		"route": MatchState.route_letter(state.route),
		"active": state.active,
		"first_player": MatchState.P1,
		"gas": _strings(state.gas),
		"piles": state.pile_counts(),
		"drops": drops_view(state),
		"crates": _crates(state),
		"bounty": state.bounty,
		"removed": cards_view(state, state.removed),
		"pending_brace": state.pending_brace_seat(),
		"last_shot": _public_shot(state),
		"match_end": state.match_end.duplicate(true),
		"me": _me(state, seat),
		"opponent": opponent_view(state, opp),
	}
	var defender: int = state.pending_brace_seat()
	if defender != MatchState.NO_SEAT:
		var rec: Dictionary = state.last_shot["targets"][defender]
		if defender == seat:
			# P20: the defender sees the damage and their own next hand.
			var eligible: Array = []
			for inst: int in LoadoutRules.brace_candidates(state, seat):
				eligible.append(inst)
			v["brace_prompt"] = {"damage": rec["damage_before_brace"], "cover": rec["cover"],
					"down": rec["down"], "next_hand": cards_view(state, state.next_hand(seat)),
					"eligible": eligible, "kind": state.last_shot["kind"]}
		elif int(state.last_shot["shooter"]) == seat:
			# P19: damage after Cover and Down, and "they may Brace"; never the target's hand.
			v["shot_preview"] = {"damage": rec["damage_before_brace"], "cover": rec["cover"],
					"down": rec["down"], "may_brace": true, "target": defender}
	return v


## The public part of build(state, seat) that the AI belief model reads (cz07b fast path):
## {opponent, removed, piles, drops, zone_card}, each equal to the same key of the full view.
## Skips the seat's own card lists, the crates and the shot record (speed: the AI calls this
## once per decision). Holds nothing the seat may not see (P18).
static func public_view(state: MatchState, seat: int) -> Dictionary:
	return {"opponent": opponent_view(state, state.opponent_of(seat)),
			"removed": cards_view(state, state.removed), "piles": state.pile_counts(),
			"drops": drops_view(state), "zone_card": state.zone_card}


## One card as the views show it: instance id, card id, tucked attachments (card ids, in order).
static func card_view(state: MatchState, inst: int) -> Dictionary:
	var atts: Array = []
	for a: int in state.attachments_of(inst):
		atts.append(state.card_id(a))
	return {"id": inst, "card": state.card_id(inst), "attachments": atts}


static func _me(state: MatchState, seat: int) -> Dictionary:
	var st: SeatState = state.seats[seat]
	return {
		"area": st.area, "health": st.health.size(), "eliminated": st.eliminated,
		"loadout": cards_view(state, st.loadout), "held": st.held.duplicate(), "held_count": st.held.size(),
		"next_draw": cards_view(state, state.next_draw(seat)), "next_hand": cards_view(state, state.next_hand(seat)),
		"next_draw_hits": state.next_draw_hits(seat), "down": state.is_down(seat),
		"hand": cards_view(state, st.hand), "hand_count": st.hand.size(), "line": cards_view(state, st.line),
		"fired": st.fired.duplicate(), "move": st.move, "search": st.search,
		"adrenaline_played": st.adrenaline_played, "ditched": st.ditched, "braced": st.braced.duplicate(),
		"looted": st.looted.duplicate(), "loadout_count": st.loadout.size(),
		"nonhit_count": state.nonhit_count(seat),
	}


## What the opponent of `seat`'s viewer sees of `seat` (the view's "opponent" key): public
## fields only, plus held_cards / next_draw_hits / hand_hits / loadout_count when the
## information tunables make them public.
static func opponent_view(state: MatchState, seat: int) -> Dictionary:
	var b: BalanceConfig = state.data.balance
	var st: SeatState = state.seats[seat]
	var o: Dictionary = {
		"area": st.area, "health": st.health.size(), "eliminated": st.eliminated,
		"line": cards_view(state, st.line), "fired": st.fired.duplicate(),
		"held_count": st.held.size(), "down": state.is_down(seat), "hand_count": st.hand.size(),
		"move": st.move, "search": st.search, "adrenaline_played": st.adrenaline_played,
		"ditched": st.ditched, "braced": st.braced.duplicate(),
	}
	if b.held_cards_public:
		o["held_cards"] = cards_view(state, st.loadout.filter(func(i: int) -> bool: return st.held.has(i)))
	if b.hits_on_top_public:
		o["next_draw_hits"] = state.next_draw_hits(seat)
		o["hand_hits"] = state.hits_in(st.hand)
	if b.loadout_count_public:
		o["loadout_count"] = st.loadout.size()
	return o


static func _public_shot(state: MatchState) -> Dictionary:
	var ls: Dictionary = state.last_shot
	if ls.is_empty():
		return {}
	var targets: Dictionary = {}
	for t: Variant in ls["targets"].keys():
		var rec: Dictionary = ls["targets"][t]
		targets[int(t)] = {"damage_before_brace": rec["damage_before_brace"], "cover": rec["cover"],
				"down": rec["down"], "suppressed": rec["suppressed"],
				"braced": (rec["braced_cards"] as Array).duplicate(true), "brace_total": rec["brace_total"],
				"hits": rec["hits"], "hits_landed": rec["hits_landed"], "eliminated": rec["eliminated"]}
	var out: Dictionary = {"kind": ls["kind"], "shooter": ls["shooter"], "area": ls["area"],
			"order": (ls["order"] as Array).duplicate(), "targets": targets,
			"bounty_heal": ls["bounty_heal"], "resolved": ls["resolved"]}
	# Snapshots taken when the shot was declared: the weapon may be private again by now.
	if ls.has("weapon_card"):
		out["weapon"] = (ls["weapon_card"] as Dictionary).duplicate(true)
	if ls.has("thrown_card"):
		out["card"] = (ls["thrown_card"] as Dictionary).duplicate(true)
	return out


## The supply drops on the map (the view's "drops" key): area -> [card_view + landed, ready].
static func drops_view(state: MatchState) -> Dictionary:
	var out: Dictionary = {}
	var delay: int = state.data.balance.supply_drop_ready_delay
	for area_id: Variant in state.drops.keys():
		var list: Array = []
		for inst: Variant in state.drops[area_id]:
			var cv: Dictionary = card_view(state, int(inst))
			cv["landed"] = int(state.drop_round.get(int(inst), 0))
			cv["ready"] = state.round_number >= int(cv["landed"]) + delay
			list.append(cv)
		out[area_id] = list
	return out


static func _crates(state: MatchState) -> Array:
	var out: Array = []
	for crate: Dictionary in state.crates:
		out.append({"owner": crate["owner"], "area": crate["area"], "cards": cards_view(state, crate["cards"]),
				"free_picks": crate["free_picks"], "picker": crate["picker"]})
	return out


## card_view() of each instance in `list`, in order.
static func cards_view(state: MatchState, list: Array) -> Array:
	var out: Array = []
	for inst: Variant in list:
		out.append(card_view(state, int(inst)))
	return out


static func _strings(list: Array) -> Array:
	var out: Array = []
	for x: Variant in list:
		out.append(String(x))
	return out
