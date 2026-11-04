# wall_state.gd
# Purpose: The complete, node-free state of one Banner Wall duel: the cards on the wall, whose
#   turn it is, the first player (tie-break), each player's remaining hand and Signature card,
#   plus the balance config, rules options and Triptych list the rules read.
#   WallRules reads and changes it; copy() gives an independent state for previews and AI search.
#   new_match() starts a real duel; from_setup() builds any fixture board (RQ-18, QA cases).
# Dependencies: PlacedCard, WallTopology, RulesOptions, BalanceConfig, CardData, TriptychData.
# Author: Mechanics Developer Agent
class_name WallState
extends RefCounted

const P1: int = 0
const P2: int = 1
const NO_PLAYER: int = -1

var balance: BalanceConfig
var options: RulesOptions
var topology: WallTopology
## Triptychs that score (spec §5.1). Matched by card id.
var triptychs: Array[TriptychData] = []

## slot (StringName) -> PlacedCard. Empty slots are absent.
var cells: Dictionary = {}
var first_player: int = P1
var to_move: int = P1
## Placements made so far (fixtures start at the number of cards on the board).
var placements: int = 0
## Order stamp for the next placed card.
var next_order: int = 1
## Per player: null = any card may be placed (fixtures), or the Array[CardData] still in hand.
var hands: Array = [null, null]
## Per player: the lineup's Signature card (null = Signature comes from the place() call).
var signature_cards: Array = [null, null]


static func other(player: int) -> int:
	return P2 if player == P1 else P1


## "P1" / "P2" (QA JSON) -> P1 / P2. Unknown -> NO_PLAYER.
static func player_from_string(s: String) -> int:
	match s.to_upper():
		"P1":
			return P1
		"P2":
			return P2
	return NO_PLAYER


static func player_name(player: int) -> String:
	return "P1" if player == P1 else ("P2" if player == P2 else "none")


## Deterministic coin flip for the first player (spec §4.3), so a seeded duel replays exactly.
static func coin_flip(seed_value: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return P1 if rng.randi_range(0, 1) == 0 else P2


## A new duel: both lineups in hand, empty wall, `first` to move.
static func new_match(lineup_p1: Array[CardData], signature_p1: CardData,
		lineup_p2: Array[CardData], signature_p2: CardData, first: int,
		p_balance: BalanceConfig = null, p_options: RulesOptions = null,
		p_triptychs: Array[TriptychData] = []) -> WallState:
	var s: WallState = WallState._base(p_balance, p_options, p_triptychs)
	s.first_player = first
	s.to_move = first
	s.hands = [lineup_p1.duplicate(), lineup_p2.duplicate()]
	s.signature_cards = [signature_p1, signature_p2]
	return s


## Test / Dossier helper (RQ-18): any board, valid or not.
## setup = {first_player: "P1", to_move: "P2", board: [{slot, card, lineup, controller, face_down,
##   signature, active_trait?, spring_pending?}], hands?: {P2: [ids]}, lineups?: {P1: {cards, signature}}}
## `cards` maps card id (String or StringName) -> CardData. Face-down cards are pending springs,
## in board order. Unknown card ids are skipped and reported by push_error.
static func from_setup(setup: Dictionary, cards: Dictionary, p_balance: BalanceConfig = null,
		p_options: RulesOptions = null, p_triptychs: Array[TriptychData] = []) -> WallState:
	var s: WallState = WallState._base(p_balance, p_options, p_triptychs)
	s.first_player = maxi(player_from_string(str(setup.get("first_player", "P1"))), P1)
	s.to_move = maxi(player_from_string(str(setup.get("to_move", "P1"))), P1)
	for entry: Dictionary in setup.get("board", []):
		var card: CardData = _lookup(cards, entry.get("card", ""))
		if card == null:
			push_error("WallState.from_setup: unknown card '%s'" % entry.get("card", ""))
			continue
		var lineup: int = player_from_string(str(entry.get("lineup", "P1")))
		var pc: PlacedCard = PlacedCard.create(card, lineup, player_from_string(str(entry.get("controller", entry.get("lineup", "P1")))))
		pc.placed_by = pc.controller
		pc.face_down = bool(entry.get("face_down", false))
		pc.signature = bool(entry.get("signature", false))
		if entry.has("active_trait"):
			pc.active_trait = trait_from_string(str(entry["active_trait"]))
		pc.spring_pending = bool(entry.get("spring_pending", pc.face_down))
		pc.order = s.next_order
		s.next_order += 1
		s.cells[StringName(str(entry["slot"]))] = pc
		s.placements += 1
	var hands: Dictionary = setup.get("hands", {})
	for key: String in hands.keys():
		var hand: Array[CardData] = []
		for id: Variant in hands[key]:
			var c: CardData = _lookup(cards, id)
			if c != null:
				hand.append(c)
		s.hands[player_from_string(key)] = hand
	var lineups: Dictionary = setup.get("lineups", {})
	for key: String in lineups.keys():
		var p: int = player_from_string(key)
		var hand: Array[CardData] = []
		for id: Variant in lineups[key].get("cards", []):
			var c: CardData = _lookup(cards, id)
			if c != null:
				hand.append(c)
		s.hands[p] = hand
		s.signature_cards[p] = _lookup(cards, lineups[key].get("signature", ""))
	return s


## "veteran" -> DataEnums.CardTrait.VETERAN ("none" and unknown -> NONE).
static func trait_from_string(s: String) -> DataEnums.CardTrait:
	var key: Variant = s.to_upper()
	if DataEnums.CardTrait.has(key):
		return DataEnums.CardTrait[key]
	return DataEnums.CardTrait.NONE


static func _base(p_balance: BalanceConfig, p_options: RulesOptions, p_triptychs: Array[TriptychData]) -> WallState:
	var s: WallState = WallState.new()
	s.balance = p_balance if p_balance != null else BalanceConfig.new()
	s.options = p_options if p_options != null else RulesOptions.new()
	s.topology = WallTopology.get_for(s.balance.wall_rows)
	s.triptychs = p_triptychs
	return s


static func _lookup(cards: Dictionary, id: Variant) -> CardData:
	if id == null:
		return null
	if cards.has(id):
		return cards[id]
	if cards.has(StringName(str(id))):
		return cards[StringName(str(id))]
	if cards.has(str(id)):
		return cards[str(id)]
	return null


## Independent copy (cards on the wall are copied; CardData and config are shared, read-only).
func copy() -> WallState:
	var s: WallState = WallState.new()
	s.balance = balance
	s.options = options
	s.topology = topology
	s.triptychs = triptychs
	for slot: StringName in cells:
		s.cells[slot] = (cells[slot] as PlacedCard).copy()
	s.first_player = first_player
	s.to_move = to_move
	s.placements = placements
	s.next_order = next_order
	s.hands = [_copy_hand(hands[0]), _copy_hand(hands[1])]
	s.signature_cards = signature_cards.duplicate()
	return s


func get_card(slot: StringName) -> PlacedCard:
	return cells.get(slot, null)


func is_empty(slot: StringName) -> bool:
	return not cells.has(slot)


func controller_of(slot: StringName) -> int:
	var pc: PlacedCard = get_card(slot)
	return pc.controller if pc != null else NO_PLAYER


func is_full() -> bool:
	return cells.size() >= topology.slot_count()


func is_game_over() -> bool:
	return is_full()


func empty_slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot: StringName in topology.slots:
		if not cells.has(slot):
			out.append(slot)
	return out


## Cards `player` may still place: their hand, or null when unrestricted (fixtures).
func hand_of(player: int) -> Variant:
	return hands[player]


## Is `card` the Signature of `player`'s lineup?
func is_signature_card(player: int, card: CardData) -> bool:
	return signature_cards[player] != null and signature_cards[player] == card


## {slot: controller} for every occupied slot.
func controllers() -> Dictionary:
	var out: Dictionary = {}
	for slot: StringName in cells:
		out[slot] = (cells[slot] as PlacedCard).controller
	return out


## Plain snapshot (for equality checks, saves and debugging). See PlacedCard.to_dict for `viewer`.
func to_dict(viewer: int = -1) -> Dictionary:
	var wall: Dictionary = {}
	for slot: StringName in topology.slots:
		if cells.has(slot):
			wall[slot] = (cells[slot] as PlacedCard).to_dict(viewer)
	var hand_ids: Array = []
	for h: Variant in hands:
		hand_ids.append(null if h == null else (h as Array).map(func(c: CardData) -> StringName: return c.id))
	return {
		"wall": wall, "first_player": first_player, "to_move": to_move, "placements": placements,
		"next_order": next_order, "hands": hand_ids,
		"signatures": signature_cards.map(func(c: Variant) -> Variant: return null if c == null else (c as CardData).id),
	}


func _copy_hand(h: Variant) -> Variant:
	return null if h == null else (h as Array).duplicate()
