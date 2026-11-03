# rival_data.gd
# Purpose: An AI rival (spec §7, plan cc06): name, level, AI tuning and a fixed themed lineup
#   that obeys the same lineup rules as the player (BalanceConfig.lineup_problems).
#   One rival = one .tres in res://data/rivals/.
# Dependencies: DataEnums, CardData, BalanceConfig (via DataValidator), DataValidator.
# Author: Mechanics Developer Agent
class_name RivalData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. archivist).
@export var id: StringName = &""
@export var display_name: String = ""
@export var difficulty: DataEnums.Difficulty = DataEnums.Difficulty.EASY
## One line shown on the Rivals screen.
@export var tagline: String = ""
## Portrait / banner key for the art kit.
@export var art_key: StringName = &""

@export_group("Lineup (spec §4.2)")
## Exactly lineup_size distinct cards; total Clearance within the cap; at most max_legends Legends.
@export var lineup: Array[CardData] = []
## One card of the lineup.
@export var signature: CardData = null

@export_group("AI tuning (plan cc06)")
## Chance (0-1) to take the best capture instead of a random legal move (Quartermaster 0.5).
@export_range(0.0, 1.0) var best_capture_chance: float = 1.0
## Look-ahead in plies: 0 random/greedy by best_capture_chance, 1 greedy, 2 Warden.
@export_range(0, 2) var lookahead_plies: int = 1
## Extra weight on keeping its own Signature safe (Warden). 0 = ignore.
@export_range(0.0, 10.0) var signature_safety_weight: float = 0.0


func total_clearance() -> int:
	var total: int = 0
	for card: CardData in lineup:
		if card != null:
			total += card.clearance
	return total


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_line("tagline", tagline, 80)
	v.check_enum("difficulty", difficulty, DataEnums.Difficulty)
	if String(art_key).is_empty():
		v.missing("art_key", "art_key is empty (the art kit needs it)")
	v.check_range_f("best_capture_chance", best_capture_chance, 0.0, 1.0)
	v.check_range("lookahead_plies", lookahead_plies, 0, 2)
	v.check_range_f("signature_safety_weight", signature_safety_weight, 0.0, 10.0)
	var refs_ok: bool = v.check_ref_array("lineup", lineup, CardData, 1, 99)
	if v.check_ref("signature", signature, CardData, true) and refs_ok:
		for problem: String in v.balance.lineup_problems(lineup, signature):
			v.add(DataValidator.LINEUP_RULE, "lineup", problem)
