# run_shop.gd
# Purpose: The Shop and the Rest of the run map (run-v2.md §2.2-§2.3). One currency, Requisition (REQ),
#   earned, never bought. Prices from RunConfig (head V5: Muster out 2 REQ).
#   Shop: 3 cards from the rung you are on (slot 1 on your main trait; an Elite card only at rung 4),
#   Muster out a Standard Issue card (any number, floor 15), Discharge any other card (floor 15), a
#   Perk (1 of 2, if a slot is free), restock the 3 cards. No tickets in the shop.
#   Rest: pick one: +1 ticket (up to the max), Drill: send 2 cards of your choice home (floor 15), or
#   Field-strip: a weapon level now (queued as the normal weapon-level offer).
#   The stock lives in RunProgress.shop (saved): {rung, cards: [{id, trait, art, sold}], perks: [ids],
#   restocks}. Static; RunProgress calls these.
# Dependencies: RunProgress, RewardOffers, RunConfig, CardData, LoadoutItem.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name RunShop
extends RefCounted

const REST_TICKET: StringName = &"ticket"
const REST_DRILL: StringName = &"drill"
const REST_FIELD_STRIP: StringName = &"field_strip"
const REST_OPTIONS: Array[StringName] = [REST_TICKET, REST_DRILL, REST_FIELD_STRIP]
const DRILL_COUNT: int = 2


# =============================================================================
# Shop
# =============================================================================

## Fills run.shop with a fresh stock (entering the shop, or a restock).
static func stock(run: RunProgress) -> void:
	var restocks: int = int(run.shop.get("restocks", 0))
	var rung: int = run.current_rung()
	var main: StringName = run.main_trait() if run.config.supply_drop_on_trait else &""
	var rng: RandomNumberGenerator = run.node_rng("shop_%d" % restocks)
	var ids: Array[StringName] = RewardOffers.supply_drop_on_trait(run.config, main, rng, rung, run.config.shop_cards)
	var drop: Dictionary = {"options": ids}
	var on: bool = main != &"" and not ids.is_empty() and (run.resource(ids[0]) as CardData).can_carry(main)
	run.dress_offer(drop, main if on else &"", run.node_rng("shop_art_%d" % restocks))
	var cards: Array = []
	for i: int in ids.size():
		cards.append({"id": ids[i], "trait": drop["traits"][i], "art": drop["arts"][i], "sold": false})
	var perks: Array = run.shop.get("perks", [])
	if restocks == 0:
		perks = []
		for p: StringName in RewardOffers.perks(run.config, run.perks, run.node_rng("shop_perk")):
			if perks.size() < run.config.shop_perks:
				perks.append(p)
	run.shop = {"rung": rung, "cards": cards, "perks": perks, "restocks": restocks}


static func price_of(cfg: RunConfig, c: CardData) -> int:
	if c == null:
		return 0
	if c.is_elite:
		return cfg.price_elite_card
	if c.is_unit():
		return cfg.price_unit
	if c.card_type == DataEnums.CardType.TACTIC:
		return cfg.price_tactic
	return cfg.price_field


static func view(run: RunProgress) -> Dictionary:
	if run.phase != RunProgress.PHASE_SHOP:
		return {}
	var cfg: RunConfig = run.config
	var cards: Array[Dictionary] = []
	var list: Array = run.shop.get("cards", [])
	for i: int in list.size():
		var row: Dictionary = list[i]
		var c: CardData = run.resource(StringName(row["id"])) as CardData
		var price: int = price_of(cfg, c)
		var why: String = ""
		if bool(row["sold"]):
			why = "Sold"
		elif price > run.req:
			why = "Needs %d REQ" % price
		var kind: StringName = &"unit" if c.is_unit() else (&"tactic" if c.card_type == DataEnums.CardType.TACTIC else &"field")
		cards.append({"slot": i, "id": row["id"], "name": c.display_name, "kind": kind, "elite": c.is_elite,
				"trait": row["trait"], "art": row["art"], "price": price, "sold": bool(row["sold"]),
				"can_buy": why == "", "reason": why})
	var perks: Array[Dictionary] = []
	var pl: Array = run.shop.get("perks", [])
	for i: int in pl.size():
		var p: LoadoutItem = run.resource(StringName(pl[i])) as LoadoutItem
		var why2: String = ""
		if run.perks.size() >= cfg.perk_slots:
			why2 = "Your Perk slots are full"
		elif cfg.price_perk > run.req:
			why2 = "Needs %d REQ" % cfg.price_perk
		perks.append({"index": i, "id": pl[i], "name": p.display_name if p != null else "", "text": p.text if p != null else "",
				"price": cfg.price_perk, "can_buy": why2 == "", "reason": why2})
	var si_rows: Array[Dictionary] = []
	var other_rows: Array[Dictionary] = []
	for i: int in run.deck.size():
		var c2: CardData = run.resource(run.deck[i]) as CardData
		if c2 == null:
			continue
		if c2.standard_issue:
			si_rows.append(run.copy_row(i))
		else:
			other_rows.append(run.copy_row(i))
	var floor_why: String = "Your deck is at %d cards" % cfg.deck_floor if run.deck.size() <= cfg.deck_floor else ""
	return {"req": run.req, "rung": int(run.shop.get("rung", 1)), "cards": cards, "perks": perks,
			"muster_out": {"price": cfg.price_muster_out, "rows": si_rows,
					"can": floor_why == "" and not si_rows.is_empty() and run.req >= cfg.price_muster_out,
					"reason": floor_why if floor_why != "" else ("No Standard Issue cards left" if si_rows.is_empty() else
							("Needs %d REQ" % cfg.price_muster_out if run.req < cfg.price_muster_out else ""))},
			"discharge": {"price": cfg.price_discharge, "rows": other_rows,
					"can": floor_why == "" and not other_rows.is_empty() and run.req >= cfg.price_discharge,
					"reason": floor_why if floor_why != "" else ("Needs %d REQ" % cfg.price_discharge if run.req < cfg.price_discharge else "")},
			"restock": {"price": cfg.price_restock, "can": run.req >= cfg.price_restock,
					"reason": "" if run.req >= cfg.price_restock else "Needs %d REQ" % cfg.price_restock},
			"deck_size": run.deck.size(), "floor": cfg.deck_floor}


static func buy(run: RunProgress, slot: int) -> String:
	if run.phase != RunProgress.PHASE_SHOP:
		return "not in a shop"
	var list: Array = run.shop.get("cards", [])
	if slot < 0 or slot >= list.size():
		return "no card %d" % slot
	var row: Dictionary = list[slot]
	if bool(row["sold"]):
		return "already bought"
	var c: CardData = run.resource(StringName(row["id"])) as CardData
	var price: int = price_of(run.config, c)
	if price > run.req:
		return "needs %d REQ" % price
	run.req -= price
	run.gain_card(StringName(row["id"]), StringName(row["trait"]), StringName(row["art"]))
	row["sold"] = true
	return ""


static func buy_perk(run: RunProgress, index: int) -> String:
	if run.phase != RunProgress.PHASE_SHOP:
		return "not in a shop"
	var pl: Array = run.shop.get("perks", [])
	if index < 0 or index >= pl.size():
		return "no Perk %d" % index
	if run.perks.size() >= run.config.perk_slots:
		return "your Perk slots are full"
	if run.config.price_perk > run.req:
		return "needs %d REQ" % run.config.price_perk
	run.req -= run.config.price_perk
	run.perks.append(StringName(pl[index]))
	run.shop["perks"] = []  # 1 of 2
	return ""


static func muster_out(run: RunProgress, deck_index: int) -> String:
	if run.phase != RunProgress.PHASE_SHOP:
		return "not in a shop"
	if deck_index < 0 or deck_index >= run.deck.size():
		return "no deck card %d" % deck_index
	var c: CardData = run.resource(run.deck[deck_index]) as CardData
	if c == null or not c.standard_issue:
		return "only Standard Issue cards can be mustered out"
	if run.deck.size() <= run.config.deck_floor:
		return "the deck can't go below %d cards" % run.config.deck_floor
	if run.config.price_muster_out > run.req:
		return "needs %d REQ" % run.config.price_muster_out
	run.req -= run.config.price_muster_out
	run.remove_copy(deck_index)
	run.mustered_out += 1
	return ""


static func discharge(run: RunProgress, deck_index: int) -> String:
	if run.phase != RunProgress.PHASE_SHOP:
		return "not in a shop"
	if deck_index < 0 or deck_index >= run.deck.size():
		return "no deck card %d" % deck_index
	var c: CardData = run.resource(run.deck[deck_index]) as CardData
	if c == null or c.standard_issue:
		return "Standard Issue cards are mustered out, not discharged"
	if run.deck.size() <= run.config.deck_floor:
		return "the deck can't go below %d cards" % run.config.deck_floor
	if run.config.price_discharge > run.req:
		return "needs %d REQ" % run.config.price_discharge
	run.req -= run.config.price_discharge
	run.retire_copy_at(deck_index)
	return ""


static func restock(run: RunProgress) -> String:
	if run.phase != RunProgress.PHASE_SHOP:
		return "not in a shop"
	if run.config.price_restock > run.req:
		return "needs %d REQ" % run.config.price_restock
	run.req -= run.config.price_restock
	run.shop["restocks"] = int(run.shop.get("restocks", 0)) + 1
	stock(run)
	return ""


# =============================================================================
# Rest
# =============================================================================

static func rest_view(run: RunProgress) -> Dictionary:
	if run.phase != RunProgress.PHASE_REST:
		return {}
	var cfg: RunConfig = run.config
	var opts: Array[Dictionary] = []
	var full: bool = run.tickets >= run.max_tickets()
	opts.append({"id": REST_TICKET, "label": "Rest up", "detail": "+1 ticket (max %d)." % run.max_tickets(),
			"available": not full, "reason": "Your tickets are full" if full else ""})
	var room: int = run.deck.size() - cfg.deck_floor
	opts.append({"id": REST_DRILL, "label": "Drill", "detail": "Send up to %d cards of your choice home (deck floor %d)." % [DRILL_COUNT, cfg.deck_floor],
			"available": room > 0, "reason": "" if room > 0 else "Your deck is at %d cards" % cfg.deck_floor})
	var atts: bool = not RewardOffers.attachments(cfg, run.resource(run.primary) as LoadoutItem, run.attachments,
			RandomNumberGenerator.new()).is_empty()
	opts.append({"id": REST_FIELD_STRIP, "label": "Field-strip", "detail": "A weapon level now (pick 1 of %d)." % cfg.attachment_choices,
			"available": atts, "reason": "" if atts else "Your weapon is fully kitted"})
	var rows: Array[Dictionary] = []
	for i: int in run.deck.size():
		rows.append(run.copy_row(i))
	return {"options": opts, "drill": {"count": mini(DRILL_COUNT, maxi(0, room)), "rows": rows}}


static func rest_choose(run: RunProgress, id: StringName, args: Dictionary = {}) -> String:
	if run.phase != RunProgress.PHASE_REST:
		return "not at a rest"
	var queued: bool = false
	match id:
		REST_TICKET:
			if run.tickets >= run.max_tickets():
				return "your tickets are full"
			run.tickets += 1
		REST_DRILL:
			var raw: Variant = args.get("deck_indices", [])
			if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
				return "pick up to %d cards" % DRILL_COUNT
			var seen: Array[int] = []
			for x: Variant in raw:
				var i: int = int(x)
				if i < 0 or i >= run.deck.size() or i in seen:
					return "bad card choice"
				seen.append(i)
			if seen.size() > DRILL_COUNT:
				return "at most %d cards" % DRILL_COUNT
			if run.deck.size() - seen.size() < run.config.deck_floor:
				return "the deck can't go below %d cards" % run.config.deck_floor
			seen.sort()
			seen.reverse()
			for i: int in seen:
				var c: CardData = run.resource(run.deck[i]) as CardData
				if c != null and c.standard_issue:
					run.mustered_out += 1
					run.remove_copy(i)
				else:
					run.retire_copy_at(i)
		REST_FIELD_STRIP:
			if not run.queue_weapon_level():
				return "your weapon is fully kitted"
			queued = true
		_:
			return "unknown rest option '%s'" % id
	run.finish_node(queued)
	return ""
