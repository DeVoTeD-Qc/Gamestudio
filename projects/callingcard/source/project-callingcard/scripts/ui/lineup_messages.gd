# lineup_messages.gd
# Purpose: Plain-words text for the lineup builder (cc10). LineupRules.validate() returns error
#   codes; this turns every code into one short sentence that says what is wrong AND what to do,
#   using the card names in the lineup. The builder never shows a raw code or the rules' own
#   developer-facing message.
#   Every LineupRules code constant must have a sentence here (tests/test_lineup_flow.gd checks
#   the script's constant map, so a new rules code without words fails the suite).
# Usage: LineupMessages.reasons(result, cards, signatures, owned_ids, balance) -> PackedStringArray
# Dependencies: LineupRules, BalanceConfig, CardData, DataEnums.
# Author: UI/UX Agent (cc10)
extends RefCounted

## Code -> handled. Kept in the order the builder lists them (most basic problem first).
const ORDER: Array[StringName] = [
	LineupRules.SIZE, LineupRules.EMPTY_SLOT, LineupRules.DUPLICATE, LineupRules.NOT_OWNED,
	LineupRules.CLEARANCE_CAP, LineupRules.LEGEND_LIMIT, LineupRules.SIGNATURE_COUNT,
	LineupRules.SIGNATURE_NOT_IN_LINEUP, LineupRules.SIGNATURE_INELIGIBLE,
]


## One plain sentence per error code in `result` (LineupRules.validate output), in ORDER.
## cards: the lineup as CardData (nulls allowed); signatures: the cards marked Signature;
## owned_ids: the player's cards (null = ownership not checked).
static func reasons(result: Dictionary, cards: Array, signatures: Array, owned_ids: Variant = null,
		balance: BalanceConfig = null) -> PackedStringArray:
	var out: PackedStringArray = []
	var errors: Array = result.get("errors", [])
	for code: StringName in ORDER:
		if errors.has(code):
			out.append(describe(code, cards, signatures, owned_ids, balance))
	for code: Variant in errors:  # a code added to LineupRules later still gets words
		if not ORDER.has(StringName(str(code))):
			out.append(describe(StringName(str(code)), cards, signatures, owned_ids, balance))
	return out


## The sentence for one code.
static func describe(code: StringName, cards: Array, signatures: Array, owned_ids: Variant = null,
		balance: BalanceConfig = null) -> String:
	var b: BalanceConfig = balance if balance != null else BalanceConfig.new()
	var real: Array[CardData] = _cards_only(cards)
	match code:
		LineupRules.SIZE:
			var missing: int = b.lineup_size - real.size()
			if missing > 0:
				if real.is_empty():
					return "Pick %d cards from your collection to make a lineup." % b.lineup_size
				return "Pick %d more %s: a lineup has exactly %d." % [missing, _plural(missing, "card", "cards"), b.lineup_size]
			return "Too many cards: a lineup has exactly %d. Take %d out." % [b.lineup_size, -missing]
		LineupRules.EMPTY_SLOT:
			return "One lineup slot is empty. Fill all %d slots." % b.lineup_size
		LineupRules.DUPLICATE:
			var twice: PackedStringArray = []
			var seen: Dictionary = {}
			for c: CardData in real:
				if seen.has(c.id) and not twice.has(c.display_name):
					twice.append(c.display_name)
				seen[c.id] = true
			return "%s is in your lineup twice. Each card can go in only once." % _names(twice)
		LineupRules.NOT_OWNED:
			var missing_names: PackedStringArray = []
			var owned: Dictionary = {}
			if owned_ids != null:
				for v: Variant in owned_ids:
					owned[v.id if v is CardData else StringName(str(v))] = true
			for c: CardData in real:
				if owned_ids != null and not owned.has(c.id) and not missing_names.has(c.display_name):
					missing_names.append(c.display_name)
			return "You don't own %s yet, so %s can't go in your lineup. Take %s out." % [
					_names(missing_names), "it" if missing_names.size() < 2 else "they",
					"it" if missing_names.size() < 2 else "them"]
		LineupRules.CLEARANCE_CAP:
			var total: int = total_clearance(real)
			var over: int = total - b.clearance_cap
			return "Clearance is %d of %d: %d too high. Swap a card for one with lower Clearance." % [
					total, b.clearance_cap, over]
		LineupRules.LEGEND_LIMIT:
			var legends: PackedStringArray = []
			for c: CardData in real:
				if c.clearance >= DataEnums.LEGEND_CLEARANCE:
					legends.append(c.display_name)
			if b.max_legends == 1:
				return "%s are both Legends. Only one Legend fits in a lineup: take one out." % _names(legends) \
						if legends.size() == 2 else \
						"%s are Legends. Only one Legend fits in a lineup." % _names(legends)
			return "%s are Legends. At most %d Legends fit in a lineup." % [_names(legends), b.max_legends]
		LineupRules.SIGNATURE_COUNT:
			var n: int = _cards_only(signatures).size() if not signatures.is_empty() else 0
			if n == 0:
				return "No Signature yet. Tap SIGNATURE next to the card you want to count double."
			return "You marked %d Signatures, but only one card can be your Signature. Unmark the others." % n
		LineupRules.SIGNATURE_NOT_IN_LINEUP:
			var outside: PackedStringArray = []
			var ids: Dictionary = {}
			for c: CardData in real:
				ids[c.id] = true
			for s: CardData in _cards_only(signatures):
				if not ids.has(s.id):
					outside.append(s.display_name)
			return "Your Signature, %s, isn't in the lineup. Mark a card that is." % _names(outside)
		LineupRules.SIGNATURE_INELIGIBLE:
			var bad: PackedStringArray = []
			for s: CardData in _cards_only(signatures):
				if not s.signature_eligible:
					bad.append(s.display_name)
			return "%s can't be a Signature. Mark another card in your lineup." % _names(bad)
	return "This lineup can't be used yet. Check the cards and your Signature."


static func total_clearance(cards: Array) -> int:
	var total: int = 0
	for c: CardData in _cards_only(cards):
		total += c.clearance
	return total


static func legend_count(cards: Array) -> int:
	var n: int = 0
	for c: CardData in _cards_only(cards):
		if c.clearance >= DataEnums.LEGEND_CLEARANCE:
			n += 1
	return n


## "A", "A and B", "A, B and C".
static func _names(names: PackedStringArray) -> String:
	if names.is_empty():
		return "That card"
	if names.size() == 1:
		return names[0]
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


static func _plural(n: int, one: String, many: String) -> String:
	return one if n == 1 else many


static func _cards_only(cards: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for v: Variant in cards:
		if v is CardData:
			out.append(v)
	return out
