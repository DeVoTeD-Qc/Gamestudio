# lineup_rules.gd
# Purpose: Lineup validation with machine-readable error codes (spec §4.2, Decisions 3 and 7,
#   RQ-15) and the loaner-lineup check (RQ-16). The lineup builder shows `messages`; rules, AI and
#   tests read `errors`. BalanceConfig.lineup_problems() stays the data-side check for rival and
#   loaner lineups; this adds codes, the collection check and the multi-Signature case.
# Dependencies: BalanceConfig, CardData, DataEnums.
# Author: Mechanics Developer Agent
class_name LineupRules
extends RefCounted

const SIZE: StringName = &"SIZE"
const EMPTY_SLOT: StringName = &"EMPTY_SLOT"
const DUPLICATE: StringName = &"DUPLICATE"
const CLEARANCE_CAP: StringName = &"CLEARANCE_CAP"
const LEGEND_LIMIT: StringName = &"LEGEND_LIMIT"
const SIGNATURE_COUNT: StringName = &"SIGNATURE_COUNT"
const SIGNATURE_NOT_IN_LINEUP: StringName = &"SIGNATURE_NOT_IN_LINEUP"
const SIGNATURE_INELIGIBLE: StringName = &"SIGNATURE_INELIGIBLE"
const NOT_OWNED: StringName = &"NOT_OWNED"


## {valid: bool, errors: Array[StringName] (each code once), messages: PackedStringArray}.
## `signatures`: the cards marked Signature (exactly one is legal). `collection`: null = skip the
## ownership check, else the owned cards (CardData or ids).
static func validate(cards: Array, signatures: Array, collection: Variant = null,
		balance: BalanceConfig = null) -> Dictionary:
	var b: BalanceConfig = balance if balance != null else BalanceConfig.new()
	var errors: Array[StringName] = []
	var messages: PackedStringArray = []
	var add: Callable = func(code: StringName, msg: String) -> void:
		if not errors.has(code):
			errors.append(code)
		messages.append(msg)
	if cards.size() != b.lineup_size:
		add.call(SIZE, "A lineup needs exactly %d cards (has %d)." % [b.lineup_size, cards.size()])
	var total: int = 0
	var legends: int = 0
	var seen: Dictionary = {}
	var owned: Dictionary = {}
	if collection != null:
		for c: Variant in collection:
			owned[c.id if c is CardData else StringName(str(c))] = true
	for v: Variant in cards:
		if not v is CardData:
			add.call(EMPTY_SLOT, "A lineup slot is empty.")
			continue
		var c: CardData = v
		if seen.has(c.id):
			add.call(DUPLICATE, "%s is in the lineup twice." % c.display_name)
		seen[c.id] = true
		total += c.clearance
		if c.clearance >= DataEnums.LEGEND_CLEARANCE:
			legends += 1
		if collection != null and not owned.has(c.id):
			add.call(NOT_OWNED, "You don't own %s yet." % c.display_name)
	if total > b.clearance_cap:
		add.call(CLEARANCE_CAP, "Total Clearance is %d; the cap is %d." % [total, b.clearance_cap])
	if legends > b.max_legends:
		add.call(LEGEND_LIMIT, "%d Legends; at most %d allowed." % [legends, b.max_legends])
	if signatures.size() != 1:
		add.call(SIGNATURE_COUNT, "Mark exactly one card as your Signature (%d marked)." % signatures.size())
	for s: Variant in signatures:
		if not s is CardData:
			continue
		var sig: CardData = s
		if not seen.has(sig.id):
			add.call(SIGNATURE_NOT_IN_LINEUP, "The Signature (%s) is not in the lineup." % sig.display_name)
		elif not sig.signature_eligible:
			add.call(SIGNATURE_INELIGIBLE, "%s can't be a Signature." % sig.display_name)
	return {"valid": errors.is_empty(), "errors": errors, "messages": messages}


## A legal lineup (cards + Signature) from `collection`, or {} when none exists (RQ-16).
## Prefers the highest total Clearance, then collection order. Brute force; a collection of 20
## cards is 15,504 combinations of 5.
static func find_legal_lineup(collection: Array, balance: BalanceConfig = null) -> Dictionary:
	var b: BalanceConfig = balance if balance != null else BalanceConfig.new()
	var pool: Array[CardData] = []
	var ids: Dictionary = {}
	for v: Variant in collection:
		if v is CardData and not ids.has((v as CardData).id):
			ids[(v as CardData).id] = true
			pool.append(v)
	var best: Array = _search(pool, 0, [], 0, 0, b, [], [-1])
	if best.is_empty():
		return {}
	var sig: CardData = null
	for c: CardData in best:
		if c.signature_eligible and (sig == null or c.clearance > sig.clearance):
			sig = c
	return {"cards": best, "signature": sig}


## RQ-16: offer the loaner lineup when the collection can't form any legal lineup.
static func should_offer_loaner(collection: Array, balance: BalanceConfig = null) -> bool:
	return find_legal_lineup(collection, balance).is_empty()


static func _search(pool: Array[CardData], start: int, combo: Array, total: int, legends: int,
		b: BalanceConfig, best: Array, best_total: Array) -> Array:
	if combo.size() == b.lineup_size:
		var eligible: bool = combo.any(func(c: CardData) -> bool: return c.signature_eligible)
		if eligible and total > best_total[0]:
			best_total[0] = total
			return combo.duplicate()
		return best
	for i: int in range(start, pool.size()):
		var c: CardData = pool[i]
		var leg: int = legends + (1 if c.clearance >= DataEnums.LEGEND_CLEARANCE else 0)
		if total + c.clearance > b.clearance_cap or leg > b.max_legends:
			continue
		combo.append(c)
		best = _search(pool, i + 1, combo, total + c.clearance, leg, b, best, best_total)
		combo.pop_back()
	return best
