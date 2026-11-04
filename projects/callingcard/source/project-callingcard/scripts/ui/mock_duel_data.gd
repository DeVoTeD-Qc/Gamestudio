# mock_duel_data.gd
# Purpose: Mock cards and duel states for building and testing the duel layout (cc07) before
#   cc02 (CardDB) and cc05 (rules) land. Card values are the spec §6 table; the duel states
#   are hand-made snapshots, NOT rules output.
#   UI card Dictionary: {id, name, set, origin, trait, clearance, top, side, bottom, earned, art_seed}
#     (set/origin/trait are StringName ids; see card_text.gd for their words).
#   Duel state Dictionary (DuelScreen.show_state):
#     {first_player, turn_side, turn_index, turns_total,
#      player: {name, score, signature_id, signature_carded_by, hand: [card ids], lineup: [card ids]},
#      rival:  {same; hand holds ids but the UI shows only how many are left},
#      wall: {slot_id: {card_id, owner, face_down}}}
# Dependencies: none.
# Author: UI/UX Agent (cc07)
extends RefCounted

const SLOTS: Array[StringName] = [&"a1", &"a2", &"a3", &"b1", &"b2", &"b3", &"b4", &"c1", &"c2", &"c3"]

## Spec §6 (20 original cards). [id, name, set, origin, trait, clearance, T, S, B, how it's earned]
const CARD_ROWS: Array = [
	[&"graveyard_shift", "Graveyard Shift", &"night_shift", &"challenge", &"steady", 1, 5, 4, 4, "Win 10 matches on night maps"],
	[&"neon_rain", "Neon Rain", &"night_shift", &"mastery", &"veteran", 2, 4, 6, 5, "Reach tier 2 mastery on any SMG"],
	[&"last_train", "Last Train", &"night_shift", &"event", &"ambush", 2, 6, 4, 5, "Night-event reward"],
	[&"city_never_sleeps", "City Never Sleeps", &"night_shift", &"prestige", &"reclaim", 4, 7, 5, 7, "Reach prestige 3"],
	[&"frostbite", "Frostbite", &"whiteout", &"challenge", &"steady", 1, 3, 6, 4, "25 eliminations on snow maps"],
	[&"snow_blind", "Snow Blind", &"whiteout", &"event", &"ambush", 3, 6, 5, 6, "Winter event reward"],
	[&"polar_night", "Polar Night", &"whiteout", &"ranked", &"clutch", 3, 5, 7, 5, "Reach the 3rd ranked tier"],
	[&"glacier", "Glacier", &"whiteout", &"mastery", &"veteran", 2, 7, 2, 6, "Tier 2 mastery on any sniper rifle"],
	[&"mayday", "Mayday", &"signal_fire", &"challenge", &"steady", 2, 5, 5, 5, "Revive 50 squadmates"],
	[&"flare_up", "Flare Up", &"signal_fire", &"event", &"ambush", 1, 6, 3, 4, "Summer event reward"],
	[&"dead_air", "Dead Air", &"signal_fire", &"mastery", &"veteran", 3, 4, 8, 5, "Top mastery on any marksman rifle"],
	[&"open_channel", "Open Channel", &"signal_fire", &"ranked", &"clutch", 2, 4, 5, 6, "Win 10 ranked matches"],
	[&"brass_tacks", "Brass Tacks", &"old_guard", &"challenge", &"steady", 3, 6, 6, 5, "100 eliminations without dying across matches"],
	[&"service_ribbon", "Service Ribbon", &"old_guard", &"mastery", &"veteran", 1, 4, 5, 4, "Level any weapon to max"],
	[&"long_watch", "Long Watch", &"old_guard", &"ranked", &"clutch", 4, 6, 7, 6, "Finish a ranked season at the top tier"],
	[&"honor_roll", "Honor Roll", &"old_guard", &"prestige", &"reclaim", 3, 5, 6, 6, "Reach prestige 1"],
	[&"null_glyph", "Null Glyph", &"cipher", &"secret", &"cipher", 2, 5, 5, 5, "Hidden challenge (secret)"],
	[&"key_fragment", "Key Fragment", &"cipher", &"secret", &"cipher", 3, 6, 5, 6, "Solve the Cipher Lock"],
	[&"chrome_tiger", "Chrome Tiger", &"showcase", &"showcase", &"none", 1, 5, 4, 4, "Store bundle (simulated, free in demo)"],
	[&"gold_leaf", "Gold Leaf", &"showcase", &"showcase", &"none", 1, 4, 5, 4, "Store bundle (simulated, free in demo)"],
]

const PLAYER_LINEUP: Array[StringName] = [&"graveyard_shift", &"neon_rain", &"last_train", &"snow_blind", &"open_channel"]
const RIVAL_LINEUP: Array[StringName] = [&"glacier", &"mayday", &"frostbite", &"brass_tacks", &"flare_up"]


static func card(card_id: StringName) -> Dictionary:
	for i: int in CARD_ROWS.size():
		var r: Array = CARD_ROWS[i]
		if r[0] == card_id:
			return {"id": r[0], "name": r[1], "set": r[2], "origin": r[3], "trait": r[4], "clearance": r[5],
					"top": r[6], "side": r[7], "bottom": r[8], "earned": r[9], "art_seed": 1000 + i * 37}
	return {}


static func all_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Array in CARD_ROWS:
		out.append(card(r[0]))
	return out


## Turn 1, nothing placed, full hands.
static func start_state() -> Dictionary:
	return {
		"first_player": &"player", "turn_side": &"player", "turn_index": 1, "turns_total": 10,
		"rival_name": "Archivist",
		"player": {"name": "You", "score": 0, "signature_id": &"snow_blind", "signature_carded_by": &"",
				"hand": PLAYER_LINEUP.duplicate(), "lineup": PLAYER_LINEUP.duplicate()},
		"rival": {"name": "Archivist", "score": 0, "signature_id": &"brass_tacks", "signature_carded_by": &"",
				"hand": RIVAL_LINEUP.duplicate(), "lineup": RIVAL_LINEUP.duplicate()},
		"wall": {},
	}


## Turn 6 (rival went first): 5 cards placed, one Ambush face-down, player to move.
static func mid_state() -> Dictionary:
	var s: Dictionary = start_state()
	s["first_player"] = &"rival"
	s["turn_index"] = 6
	s["wall"] = {
		&"a1": {"card_id": &"graveyard_shift", "owner": &"player", "face_down": false},
		&"b2": {"card_id": &"brass_tacks", "owner": &"rival", "face_down": false},
		&"b3": {"card_id": &"flare_up", "owner": &"rival", "face_down": true},
		&"c1": {"card_id": &"open_channel", "owner": &"player", "face_down": false},
		&"c2": {"card_id": &"frostbite", "owner": &"player", "face_down": false},
	}
	s["player"]["hand"] = [&"neon_rain", &"last_train", &"snow_blind"]
	s["rival"]["hand"] = [&"glacier", &"mayday"]
	s["player"]["score"] = 3
	s["rival"]["score"] = 3
	return s


## Wall full, rival Signature captured by the player ("Carded!").
static func full_state() -> Dictionary:
	var s: Dictionary = start_state()
	s["turn_index"] = 10
	s["turn_side"] = &"rival"
	s["wall"] = {
		&"a1": {"card_id": &"graveyard_shift", "owner": &"player", "face_down": false},
		&"a2": {"card_id": &"glacier", "owner": &"rival", "face_down": false},
		&"a3": {"card_id": &"snow_blind", "owner": &"player", "face_down": false},
		&"b1": {"card_id": &"mayday", "owner": &"rival", "face_down": false},
		&"b2": {"card_id": &"brass_tacks", "owner": &"player", "face_down": false},
		&"b3": {"card_id": &"neon_rain", "owner": &"player", "face_down": false},
		&"b4": {"card_id": &"flare_up", "owner": &"rival", "face_down": false},
		&"c1": {"card_id": &"open_channel", "owner": &"player", "face_down": false},
		&"c2": {"card_id": &"frostbite", "owner": &"rival", "face_down": false},
		&"c3": {"card_id": &"last_train", "owner": &"player", "face_down": true},
	}
	s["player"]["hand"] = []
	s["rival"]["hand"] = []
	s["rival"]["signature_carded_by"] = &"player"
	s["player"]["score"] = 8
	s["rival"]["score"] = 4
	return s
