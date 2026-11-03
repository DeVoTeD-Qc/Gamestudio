# art_samples.gd
# Purpose: The 20 demo cards of banner-wall-spec.md section 6 as plain dictionaries, for the art-kit
#   tests and the card sheet (cc14). PREVIEW FIXTURE ONLY: the real data is CardDB / data/cards (cc02, cc03).
#   Glyphs 1-4 sit on cards 1, 5, 9 and 13 (spec 5).
# Author: Technical Artist Agent (cc14)
extends RefCounted

const CARDS: Array[Dictionary] = [
	{"id": &"graveyard_shift", "name": "Graveyard Shift", "set": &"night_shift", "origin": &"challenge", "clearance": 1, "top": 5, "side": 4, "bottom": 4, "trait": &"steady", "art_seed": 1, "glyph": 1},
	{"id": &"neon_rain", "name": "Neon Rain", "set": &"night_shift", "origin": &"mastery", "clearance": 2, "top": 4, "side": 6, "bottom": 5, "trait": &"veteran", "art_seed": 2, "glyph": 0},
	{"id": &"last_train", "name": "Last Train", "set": &"night_shift", "origin": &"event", "clearance": 2, "top": 6, "side": 4, "bottom": 5, "trait": &"ambush", "art_seed": 3, "glyph": 0},
	{"id": &"city_never_sleeps", "name": "City Never Sleeps", "set": &"night_shift", "origin": &"prestige", "clearance": 4, "top": 7, "side": 5, "bottom": 7, "trait": &"reclaim", "art_seed": 4, "glyph": 0},
	{"id": &"frostbite", "name": "Frostbite", "set": &"whiteout", "origin": &"challenge", "clearance": 1, "top": 3, "side": 6, "bottom": 4, "trait": &"steady", "art_seed": 5, "glyph": 2},
	{"id": &"snow_blind", "name": "Snow Blind", "set": &"whiteout", "origin": &"event", "clearance": 3, "top": 6, "side": 5, "bottom": 6, "trait": &"ambush", "art_seed": 6, "glyph": 0},
	{"id": &"polar_night", "name": "Polar Night", "set": &"whiteout", "origin": &"ranked", "clearance": 3, "top": 5, "side": 7, "bottom": 5, "trait": &"clutch", "art_seed": 7, "glyph": 0},
	{"id": &"glacier", "name": "Glacier", "set": &"whiteout", "origin": &"mastery", "clearance": 2, "top": 7, "side": 2, "bottom": 6, "trait": &"veteran", "art_seed": 8, "glyph": 0},
	{"id": &"mayday", "name": "Mayday", "set": &"signal_fire", "origin": &"challenge", "clearance": 2, "top": 5, "side": 5, "bottom": 5, "trait": &"steady", "art_seed": 9, "glyph": 3},
	{"id": &"flare_up", "name": "Flare Up", "set": &"signal_fire", "origin": &"event", "clearance": 1, "top": 6, "side": 3, "bottom": 4, "trait": &"ambush", "art_seed": 10, "glyph": 0},
	{"id": &"dead_air", "name": "Dead Air", "set": &"signal_fire", "origin": &"mastery", "clearance": 3, "top": 4, "side": 8, "bottom": 5, "trait": &"veteran", "art_seed": 11, "glyph": 0},
	{"id": &"open_channel", "name": "Open Channel", "set": &"signal_fire", "origin": &"ranked", "clearance": 2, "top": 4, "side": 5, "bottom": 6, "trait": &"clutch", "art_seed": 12, "glyph": 0},
	{"id": &"brass_tacks", "name": "Brass Tacks", "set": &"old_guard", "origin": &"challenge", "clearance": 3, "top": 6, "side": 6, "bottom": 5, "trait": &"steady", "art_seed": 13, "glyph": 4},
	{"id": &"service_ribbon", "name": "Service Ribbon", "set": &"old_guard", "origin": &"mastery", "clearance": 1, "top": 4, "side": 5, "bottom": 4, "trait": &"veteran", "art_seed": 14, "glyph": 0},
	{"id": &"long_watch", "name": "Long Watch", "set": &"old_guard", "origin": &"ranked", "clearance": 4, "top": 6, "side": 7, "bottom": 6, "trait": &"clutch", "art_seed": 15, "glyph": 0},
	{"id": &"honor_roll", "name": "Honor Roll", "set": &"old_guard", "origin": &"prestige", "clearance": 3, "top": 5, "side": 6, "bottom": 6, "trait": &"reclaim", "art_seed": 16, "glyph": 0},
	{"id": &"null_glyph", "name": "Null Glyph", "set": &"cipher", "origin": &"secret", "clearance": 2, "top": 5, "side": 5, "bottom": 5, "trait": &"cipher", "art_seed": 17, "glyph": 0},
	{"id": &"key_fragment", "name": "Key Fragment", "set": &"cipher", "origin": &"secret", "clearance": 3, "top": 6, "side": 5, "bottom": 6, "trait": &"cipher", "art_seed": 18, "glyph": 0},
	{"id": &"chrome_tiger", "name": "Chrome Tiger", "set": &"showcase", "origin": &"showcase", "clearance": 1, "top": 5, "side": 4, "bottom": 4, "trait": &"none", "art_seed": 19, "glyph": 0},
	{"id": &"gold_leaf", "name": "Gold Leaf", "set": &"showcase", "origin": &"showcase", "clearance": 1, "top": 4, "side": 5, "bottom": 4, "trait": &"none", "art_seed": 20, "glyph": 0},
]
