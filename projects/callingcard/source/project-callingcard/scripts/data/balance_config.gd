# balance_config.gd
# Purpose: Every tunable Banner Wall number in one file (spec §3, §4, §9; plan cc13 lobby wait):
#   wall layout, lineup rules, stat budgets, bonuses, scoring flags, Cipher Lock code and
#   the loaner lineup. Lives at res://data/balance.tres (id `balance`).
#   lineup_problems() is the single lineup check (rivals here, the lineup builder and rules later).
# Dependencies: DataEnums, CardData, DataValidator.
# Author: Mechanics Developer Agent
class_name BalanceConfig
extends Resource

## The id the game looks up (CardDB.get_balance()).
const DEFAULT_ID: StringName = &"balance"
## Row letters, top to bottom (spec §4.1: a1 a2 a3 / b1..b4 / c1 c2 c3).
const ROW_LETTERS: String = "abc"

@export_group("Identity")
@export var id: StringName = DEFAULT_ID

@export_group("Wall and lineup (spec §4.1, §4.2)")
## Bricks per row, top to bottom. Brick layout: outer rows equal, middle row one longer (3/4/3).
@export var wall_rows: PackedInt32Array = PackedInt32Array([3, 4, 3])
## Cards per lineup (range to test 4-5).
@export_range(1, 10) var lineup_size: int = 5
## Max total Clearance of a lineup (range to test 10-14).
@export_range(1, 40) var clearance_cap: int = 12
## Max Legend (Clearance 4) cards per lineup.
@export_range(0, 5) var max_legends: int = 1

@export_group("Card stats (spec §3)")
## Top + Side + Bottom budget for Clearance 1..4 (13/15/17/19; range to test +-1).
@export var stat_budgets: PackedInt32Array = PackedInt32Array([13, 15, 17, 19])
@export_range(0, 9) var stat_min: int = 1
@export_range(1, 20) var stat_max: int = 9
## Cards per set (spec §3: a themed series of 2-6 cards).
@export_range(1, 10) var set_size_min: int = 2
@export_range(1, 10) var set_size_max: int = 6

@export_group("Bonuses (spec §4.4, §9)")
@export_range(0, 3) var set_link_bonus: int = 1
@export_range(0, 3) var clutch_bonus: int = 2
@export_range(0, 3) var ambush_spring_bonus: int = 1

@export_group("Scoring (spec §4.5, §9)")
@export_range(1, 3) var signature_value: int = 2
@export_range(0, 2) var triptych_bonus: int = 1
@export var tie_winner: DataEnums.TieWinner = DataEnums.TieWinner.FIRST_PLAYER
## Captured cards re-check their neighbors (off in the base rules).
@export var chain_captures: bool = false

@export_group("Album (spec §5)")
## Cipher Lock code: glyph numbers (1-4, as set in CardData.cipher_glyph), in entry order.
@export var cipher_code: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])
## Loaner lineup for players whose collection can't make a full lineup (spec §4.2). Empty until cc03.
@export var loaner_lineup: Array[CardData] = []
## The loaner lineup's Signature (one of loaner_lineup).
@export var loaner_signature: CardData = null

@export_group("Lobby Duel (plan cc13)")
## Simulated matchmaking wait, picked at random per session, seconds.
@export_range(5, 600) var lobby_wait_min_s: int = 60
@export_range(5, 600) var lobby_wait_max_s: int = 150


## Stat budget for a Clearance (1-4); -1 when out of range.
func budget_for(clearance: int) -> int:
	if clearance < 1 or clearance > stat_budgets.size():
		return -1
	return stat_budgets[clearance - 1]


func slot_count() -> int:
	var total: int = 0
	for n: int in wall_rows:
		total += n
	return total


## Every slot id, row by row: a1 a2 a3 b1 b2 b3 b4 c1 c2 c3.
func slot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for row: int in mini(wall_rows.size(), ROW_LETTERS.length()):
		for col: int in wall_rows[row]:
			result.append(StringName("%s%d" % [ROW_LETTERS[row], col + 1]))
	return result


func is_slot(slot: StringName) -> bool:
	return slot_ids().has(slot)


## Reasons (plain words, for the lineup builder too) why cards + signature isn't a legal lineup.
## Empty when legal. Checks spec §4.2: size, distinct cards, Clearance cap, Legends, Signature.
func lineup_problems(cards: Array, signature: CardData) -> PackedStringArray:
	var problems: PackedStringArray = []
	if cards.size() != lineup_size:
		problems.append("A lineup needs exactly %d cards (has %d)." % [lineup_size, cards.size()])
	var total: int = 0
	var legends: int = 0
	var seen: Dictionary = {}
	for card: Variant in cards:
		if not card is CardData:
			problems.append("A lineup slot is empty.")
			continue
		var c: CardData = card
		if seen.has(c):
			problems.append("%s is in the lineup twice." % c.display_name)
		seen[c] = true
		total += c.clearance
		if c.clearance >= DataEnums.LEGEND_CLEARANCE:
			legends += 1
	if total > clearance_cap:
		problems.append("Total Clearance is %d; the cap is %d." % [total, clearance_cap])
	if legends > max_legends:
		problems.append("%d Legends; at most %d allowed." % [legends, max_legends])
	if signature == null:
		problems.append("Mark one card as your Signature.")
	elif not cards.has(signature):
		problems.append("The Signature (%s) is not in the lineup." % signature.display_name)
	elif not signature.signature_eligible:
		problems.append("%s can't be a Signature." % signature.display_name)
	return problems


func validate(v: DataValidator) -> void:
	v.require_id(id)
	if id != DEFAULT_ID:
		v.invalid("id", "the balance config must have id '%s' (got '%s')" % [DEFAULT_ID, id])
	# Wall: brick layout needs 3 rows, outer rows equal, middle row one longer (spec §4.1).
	if wall_rows.size() != 3:
		v.out_of_range("wall_rows", "needs 3 rows (got %d)" % wall_rows.size())
	elif wall_rows[0] < 1 or wall_rows[0] != wall_rows[2] or wall_rows[1] != wall_rows[0] + 1:
		v.invalid("wall_rows", "%s is not a brick layout (outer rows equal, middle row one longer, e.g. 3/4/3)" % str(wall_rows))
	v.check_range("lineup_size", lineup_size, 1, 10)
	if lineup_size * 2 > slot_count():
		v.out_of_range("lineup_size", "two lineups of %d don't fit a %d-slot wall" % [lineup_size, slot_count()])
	v.check_range("clearance_cap", clearance_cap, lineup_size, lineup_size * DataEnums.MAX_CLEARANCE)
	v.check_range("max_legends", max_legends, 0, lineup_size)
	# Stats.
	v.check_range("stat_min", stat_min, 0, 9)
	v.check_range("stat_max", stat_max, maxi(stat_min, 1), 20)
	if stat_budgets.size() != DataEnums.MAX_CLEARANCE:
		v.out_of_range("stat_budgets", "needs %d budgets (Clearance 1-4), got %d" % [DataEnums.MAX_CLEARANCE, stat_budgets.size()])
	else:
		for i: int in stat_budgets.size():
			v.check_range("stat_budgets[%d]" % i, stat_budgets[i], stat_min * 3, stat_max * 3)
			if i > 0 and stat_budgets[i] <= stat_budgets[i - 1]:
				v.invalid("stat_budgets[%d]" % i, "budgets must rise with Clearance (%d after %d)" % [stat_budgets[i], stat_budgets[i - 1]])
	v.check_range("set_size_min", set_size_min, 1, 10)
	v.check_range("set_size_max", set_size_max, set_size_min, 10)
	# Bonuses and scoring (spec §9 ranges, with a little headroom).
	v.check_range("set_link_bonus", set_link_bonus, 0, 3)
	v.check_range("clutch_bonus", clutch_bonus, 0, 3)
	v.check_range("ambush_spring_bonus", ambush_spring_bonus, 0, 3)
	v.check_range("signature_value", signature_value, 1, 3)
	v.check_range("triptych_bonus", triptych_bonus, 0, 2)
	v.check_enum("tie_winner", tie_winner, DataEnums.TieWinner)
	# Cipher Lock: 4 distinct glyph numbers 1-4.
	if cipher_code.size() != 4:
		v.out_of_range("cipher_code", "needs 4 glyphs, got %d" % cipher_code.size())
	var glyphs_seen: Dictionary = {}
	for i: int in cipher_code.size():
		v.check_range("cipher_code[%d]" % i, cipher_code[i], 1, 4)
		if glyphs_seen.has(cipher_code[i]):
			v.invalid("cipher_code", "glyph %d is used twice" % cipher_code[i])
		glyphs_seen[cipher_code[i]] = true
	# Lobby wait.
	v.check_range("lobby_wait_min_s", lobby_wait_min_s, 5, 600)
	v.check_range("lobby_wait_max_s", lobby_wait_max_s, lobby_wait_min_s, 600)
	# Loaner lineup: optional until cc03, legal when set.
	if loaner_lineup.is_empty() and loaner_signature == null:
		v.warn(DataValidator.MISSING_FIELD, "loaner_lineup", "no loaner lineup yet (spec §4.2; cc03 adds it)")
	elif v.check_ref_array("loaner_lineup", loaner_lineup, CardData, 0, 99) \
			and (loaner_signature == null or v.check_ref("loaner_signature", loaner_signature, CardData, true)):
		for problem: String in lineup_problems(loaner_lineup, loaner_signature):
			v.add(DataValidator.LINEUP_RULE, "loaner_lineup", problem)
