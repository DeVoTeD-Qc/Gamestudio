# wall_state_codec.gd
# Purpose: Lossless, JSON-safe save codec for a WallState (cc09, Lobby Duel save and resume).
#   WallState.to_dict() is a display snapshot: it drops PlacedCard.placed_by, the RulesOptions
#   and the wall shape, and stores traits as names. This codec keeps every field the rules read,
#   so decode(encode(s)) plays on exactly like s (tests/test_save_codec.gd checks it move by move).
#   Not saved (they come from the current data on load): BalanceConfig, Triptych list, CardData.
#   Cards are saved by id and looked up again on decode; an unknown id fails the decode.
#   Only plain types (int, bool, String, Array, Dictionary, null) go into the output, and
#   decode() accepts JSON round-tripped input (ints may come back as floats, keys as Strings).
# Dependencies: SaveFile, WallState, PlacedCard, RulesOptions, WallTopology, BalanceConfig, CardData,
#   TriptychData, DataEnums. Reads scripts/rules only; never changes it.
# Author: Mechanics Developer Agent
class_name WallStateCodec
extends RefCounted

## Bump when the encoded shape changes; decode() refuses newer formats.
const FORMAT: int = 1

## Why the last decode() returned null (empty after a successful decode).
static var last_error: String = ""


## WallState -> plain Dictionary (JSON-safe).
static func encode(state: WallState) -> Dictionary:
	var cells: Array = []
	for slot: StringName in state.topology.slots:
		if not state.cells.has(slot):
			continue
		var pc: PlacedCard = state.cells[slot]
		cells.append({
			"slot": String(slot), "card": String(pc.card.id), "lineup": pc.lineup,
			"controller": pc.controller, "placed_by": pc.placed_by, "face_down": pc.face_down,
			"signature": pc.signature, "active_trait": _trait_key(pc.active_trait),
			"spring_pending": pc.spring_pending, "order": pc.order,
		})
	var hands: Array = []
	for h: Variant in state.hands:
		hands.append(null if h == null else (h as Array).map(func(c: CardData) -> String: return String(c.id)))
	var sigs: Array = []
	for c: Variant in state.signature_cards:
		sigs.append(null if c == null else String((c as CardData).id))
	var rows: Array = []
	for r: int in state.topology.rows:
		rows.append(r)
	return {
		"format": FORMAT, "rows": rows, "cells": cells,
		"first_player": state.first_player, "to_move": state.to_move,
		"placements": state.placements, "next_order": state.next_order,
		"hands": hands, "signatures": sigs,
		"options": {
			"showcase_set_link": state.options.showcase_set_link,
			"clutch_uses_full_score": state.options.clutch_uses_full_score,
			"cipher_copies_printed_trait": state.options.cipher_copies_printed_trait,
			"cancel_spring_if_lost": state.options.cancel_spring_if_lost,
		},
	}


## Plain Dictionary -> WallState, or null (see last_error). card_lookup: Callable(StringName) -> CardData
## (e.g. CardDB.get_card). balance / triptychs: the current data (BalanceConfig.new() / none if null).
## The wall shape must match the balance's wall_rows, or the decode fails.
static func decode(data: Variant, card_lookup: Callable, balance: BalanceConfig = null,
		triptychs: Array[TriptychData] = []) -> WallState:
	last_error = ""
	if not data is Dictionary:
		return _fail("not a Dictionary")
	var d: Dictionary = data
	var fmt: int = SaveFile.to_int(d.get("format"), -1)
	if fmt < 1 or fmt > FORMAT:
		return _fail("unknown format %s" % str(d.get("format")))
	var b: BalanceConfig = balance if balance != null else BalanceConfig.new()
	var rows: Variant = d.get("rows")
	if not rows is Array or (rows as Array).size() != b.wall_rows.size():
		return _fail("wall shape missing or changed")
	for i: int in b.wall_rows.size():
		if SaveFile.to_int(rows[i], -1) != b.wall_rows[i]:
			return _fail("wall shape changed (%s -> %s)" % [str(rows), str(b.wall_rows)])
	var opts: RulesOptions = RulesOptions.new()
	var od: Variant = d.get("options", {})
	if od is Dictionary:
		for key: String in ["showcase_set_link", "clutch_uses_full_score", "cipher_copies_printed_trait", "cancel_spring_if_lost"]:
			if (od as Dictionary).has(key):
				opts.set(key, bool(od[key]))
	var s: WallState = WallState.new()
	s.balance = b
	s.options = opts
	s.topology = WallTopology.get_for(b.wall_rows)
	s.triptychs = triptychs
	s.first_player = SaveFile.to_int(d.get("first_player"), -1)
	s.to_move = SaveFile.to_int(d.get("to_move"), -1)
	if not _is_player(s.first_player) or not _is_player(s.to_move):
		return _fail("bad first_player / to_move")
	s.placements = SaveFile.to_int(d.get("placements"), -1)
	s.next_order = SaveFile.to_int(d.get("next_order"), -1)
	if s.placements < 0 or s.next_order < 1:
		return _fail("bad placement counters")
	var cells: Variant = d.get("cells")
	if not cells is Array:
		return _fail("cells missing")
	for e: Variant in cells:
		if not e is Dictionary:
			return _fail("bad cell entry")
		var slot: StringName = StringName(str(e.get("slot", "")))
		if not s.topology.is_slot(slot) or s.cells.has(slot):
			return _fail("bad or repeated slot '%s'" % slot)
		var card: CardData = _card(card_lookup, e.get("card"))
		if card == null:
			return _fail("unknown card '%s'" % str(e.get("card")))
		var pc: PlacedCard = PlacedCard.new()
		pc.card = card
		pc.lineup = SaveFile.to_int(e.get("lineup"), -1)
		pc.controller = SaveFile.to_int(e.get("controller"), -1)
		pc.placed_by = SaveFile.to_int(e.get("placed_by"), -1)
		if not (_is_player(pc.lineup) and _is_player(pc.controller) and _is_player(pc.placed_by)):
			return _fail("bad owner in slot %s" % slot)
		pc.face_down = bool(e.get("face_down", false))
		pc.signature = bool(e.get("signature", false))
		var t: Variant = _trait_value(str(e.get("active_trait", "")))
		if t == null:
			return _fail("bad trait in slot %s" % slot)
		pc.active_trait = t
		pc.spring_pending = bool(e.get("spring_pending", false))
		pc.order = SaveFile.to_int(e.get("order"), -1)
		if pc.order < 1:
			return _fail("bad order in slot %s" % slot)
		s.cells[slot] = pc
	var hands: Variant = d.get("hands")
	var sigs: Variant = d.get("signatures")
	if not hands is Array or (hands as Array).size() != 2 or not sigs is Array or (sigs as Array).size() != 2:
		return _fail("hands / signatures missing")
	for p: int in 2:
		if hands[p] == null:
			s.hands[p] = null
		elif hands[p] is Array:
			var hand: Array[CardData] = []
			for id: Variant in hands[p]:
				var c: CardData = _card(card_lookup, id)
				if c == null:
					return _fail("unknown hand card '%s'" % str(id))
				hand.append(c)
			s.hands[p] = hand
		else:
			return _fail("bad hand")
		if sigs[p] == null:
			s.signature_cards[p] = null
		else:
			var sc: CardData = _card(card_lookup, sigs[p])
			if sc == null:
				return _fail("unknown Signature '%s'" % str(sigs[p]))
			s.signature_cards[p] = sc
	return s


## True when a and b hold the same rules state (every field encode() writes).
static func same_state(a: WallState, b: WallState) -> bool:
	return encode(a) == encode(b)


static func _fail(msg: String) -> WallState:
	last_error = msg
	return null


static func _card(lookup: Callable, id: Variant) -> CardData:
	if id == null or not lookup.is_valid():
		return null
	var c: Variant = lookup.call(StringName(str(id)))
	return c as CardData if c is CardData else null


static func _is_player(p: int) -> bool:
	return p == WallState.P1 or p == WallState.P2


static func _trait_key(t: DataEnums.CardTrait) -> String:
	return DataEnums.key_of(DataEnums.CardTrait, t).to_lower()


## "veteran" -> CardTrait.VETERAN, or null when unknown.
static func _trait_value(s: String) -> Variant:
	var key: String = s.to_upper()
	return DataEnums.CardTrait[key] if DataEnums.CardTrait.has(key) else null
