# dossier_data.gd
# Purpose: A handcrafted puzzle (spec §5, §5.2; plan cc12): a fixed wall, a fixed hand, optional
#   scripted rival replies, a goal, a known solution (for the solvability test) and a cosmetic
#   reward. One Dossier = one .tres in res://data/dossiers/ (placements are sub-resources).
#   Data-only checks live here; whether the solution really meets the goal is cc12's rules test.
# Dependencies: DataEnums, CardData, DossierPlacement, BalanceConfig (via DataValidator), DataValidator.
# Author: Mechanics Developer Agent
class_name DossierData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. dossier_first_contact).
@export var id: StringName = &""
## Menu order and label (D1..D5). Unique across Dossiers.
@export_range(1, 9) var number: int = 0
@export var display_name: String = ""
## The rule this puzzle teaches, one line (e.g. "Capture, facing values").
@export var teaches: String = ""
## Briefing shown before the puzzle.
@export_multiline var briefing: String = ""
## Hint button text, one line.
@export var hint: String = ""

@export_group("Setup")
## Cards already on the wall (any side). Slots must be distinct.
@export var board: Array[DossierPlacement] = []
## The player's fixed hand, distinct cards.
@export var player_hand: Array[CardData] = []
## Optional: the hand card that is the player's Signature (counts double).
@export var hand_signature: CardData = null
## Optional scripted rival placements, made in order after each player placement (side RIVAL).
@export var rival_replies: Array[DossierPlacement] = []

@export_group("Goal")
@export var goal: DataEnums.DossierGoal = DataEnums.DossierGoal.CAPTURE_N
## CAPTURE_N / CAPTURE_N_WITH_SPRING: captures needed. Other goals: 0.
@export_range(0, 9) var goal_count: int = 0
## Placements the player may make (WIN_IN_PLACEMENTS: exactly this many).
@export_range(1, 5) var max_placements: int = 1
## A known solution: the player's placements in order (side PLAYER, cards from player_hand).
@export var solution: Array[DossierPlacement] = []

@export_group("Reward (cosmetic only)")
## Card granted on clear (e.g. null_glyph). Optional when a title or frame is set.
@export var reward_card: CardData = null
## Title granted on clear (or instead of reward_card when it is already owned).
@export var reward_title: String = ""
## Frame id granted on clear (e.g. service_ribbon_frame).
@export var reward_frame: StringName = &""


func needs_count() -> bool:
	return goal in [DataEnums.DossierGoal.CAPTURE_N, DataEnums.DossierGoal.CAPTURE_N_WITH_SPRING]


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.check_range("number", number, 1, 9)
	v.require_text("display_name", display_name)
	v.require_text("teaches", teaches)
	v.check_line("teaches", teaches, 60)
	v.check_line("hint", hint, 100)
	var goal_ok: bool = v.check_enum("goal", goal, DataEnums.DossierGoal)
	var used_slots: Dictionary = {}
	var signatures: Dictionary = {}  # Side -> count
	# Board.
	for i: int in board.size():
		_check_placement(v, "board[%d]" % i, board[i], -1, used_slots, signatures)
	# Hand.
	var hand_ok: bool = v.check_ref_array("player_hand", player_hand, CardData, 1, v.balance.lineup_size)
	if hand_signature != null:
		if not player_hand.has(hand_signature):
			v.invalid("hand_signature", "'%s' is not in player_hand" % hand_signature.id)
		signatures[DataEnums.Side.PLAYER] = signatures.get(DataEnums.Side.PLAYER, 0) + 1
	v.check_range("max_placements", max_placements, 1, maxi(1, player_hand.size()))
	# Rival replies.
	for i: int in rival_replies.size():
		_check_placement(v, "rival_replies[%d]" % i, rival_replies[i], DataEnums.Side.RIVAL, used_slots, signatures)
	for s: int in signatures.keys():
		if signatures[s] > 1:
			v.invalid("is_signature", "%s has %d Signatures (max 1)" % [DataEnums.key_of(DataEnums.Side, s), signatures[s]])
	# Solution: player placements from the hand, into free slots.
	if solution.is_empty():
		v.missing("solution", "a Dossier needs a known solution (solvability test)")
	elif solution.size() > max_placements:
		v.out_of_range("solution", "%d placements, max_placements is %d" % [solution.size(), max_placements])
	var solution_cards: Array = []
	for i: int in solution.size():
		var step: DossierPlacement = solution[i]
		_check_placement(v, "solution[%d]" % i, step, DataEnums.Side.PLAYER, used_slots, {})
		if step != null and step.card != null:
			if hand_ok and not player_hand.has(step.card):
				v.invalid("solution[%d].card" % i, "'%s' is not in player_hand" % step.card.id)
			if solution_cards.has(step.card):
				v.invalid("solution[%d].card" % i, "'%s' is placed twice" % step.card.id)
			solution_cards.append(step.card)
	if used_slots.size() > v.balance.slot_count():
		v.out_of_range("board", "uses %d slots; the wall has %d" % [used_slots.size(), v.balance.slot_count()])
	# Goal-specific needs.
	if goal_ok:
		if needs_count():
			v.check_range("goal_count", goal_count, 1, 9)
		elif goal_count != 0:
			v.invalid("goal_count", "%s doesn't use goal_count" % DataEnums.key_of(DataEnums.DossierGoal, goal))
		match goal:
			DataEnums.DossierGoal.CAPTURE_SIGNATURE_AND_WIN:
				if not _has_rival_signature():
					v.invalid("goal", "CAPTURE_SIGNATURE_AND_WIN needs a rival card with is_signature on the board or in rival_replies")
			DataEnums.DossierGoal.CAPTURE_N_WITH_SPRING:
				if not _hand_has_trait(DataEnums.CardTrait.AMBUSH):
					v.invalid("goal", "CAPTURE_N_WITH_SPRING needs an Ambush card in player_hand")
			DataEnums.DossierGoal.WIN_BY_COPYING_TRAIT:
				if not _hand_has_trait(DataEnums.CardTrait.CIPHER):
					v.invalid("goal", "WIN_BY_COPYING_TRAIT needs a Cipher card in player_hand")
	# Reward.
	v.check_line("reward_title", reward_title, 32)
	if reward_card != null:
		v.check_ref("reward_card", reward_card, CardData, false)
	elif reward_title.strip_edges().is_empty() and String(reward_frame).is_empty():
		v.missing("reward_card", "a Dossier needs a reward: reward_card, reward_title or reward_frame")


func _check_placement(v: DataValidator, field: String, p: DossierPlacement, required_side: int,
		used_slots: Dictionary, signatures: Dictionary) -> void:
	if p == null:
		v.broken_reference(field, "empty slot")
		return
	p.validate(v, field)
	if required_side >= 0 and p.side != required_side:
		v.invalid(field + ".side", "must be %s" % DataEnums.key_of(DataEnums.Side, required_side))
	if used_slots.has(p.slot):
		v.invalid(field + ".slot", "slot %s is already used by %s" % [p.slot, used_slots[p.slot]])
	else:
		used_slots[p.slot] = field
	if p.is_signature:
		signatures[p.side] = signatures.get(p.side, 0) + 1


func _has_rival_signature() -> bool:
	for p: DossierPlacement in board + rival_replies:
		if p != null and p.side == DataEnums.Side.RIVAL and p.is_signature:
			return true
	return false


func _hand_has_trait(t: DataEnums.CardTrait) -> bool:
	for c: CardData in player_hand:
		if c != null and c.card_trait() == t:
			return true
	return false
