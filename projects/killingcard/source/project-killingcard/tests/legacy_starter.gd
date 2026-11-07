# legacy_starter.gd
# Purpose: Test helper. The shipped run config with the kc-onboard ladder switched off and the
#   kc-syn Recruit starter put back (Rifleman 3, Point Man 4, Breacher 3, Marksman 2, Combat Medic 2,
#   Gunner, Protector, Ammo Resupply 2, Hold the Line 2; Doctrine after match 1, Regroup after a
#   loss, 1 pick of 3 from the full pool). The kc-syn / kc-art-traits run tests use it to keep
#   testing those mechanics on a deck of real chassis. kc-no-training: no copy levels any more.
# Author: Mechanics Developer Agent (kc-onboard-impl)
extends RefCounted


static func config(offers: bool = true) -> RunConfig:
	var c: RunConfig = (load("res://data/run_config.tres") as RunConfig).duplicate() as RunConfig
	c.synergy_offers = offers
	var deck: Array[CardData] = []
	for pair: Array in [["rifleman", 3], ["point_man", 4], ["breacher", 3], ["marksman", 2], ["combat_medic", 2],
			["gunner", 1], ["shieldman", 1], ["ammo_resupply", 2], ["hold_the_line", 2]]:
		var card: CardData = load("res://data/cards/%s.tres" % pair[0]) as CardData
		for k: int in int(pair[1]):
			deck.append(card)
	c.starter_deck = deck
	c.doctrine_after_matches = PackedInt32Array([1])
	c.doctrine_from_first_pick = false
	c.reward_rungs = PackedInt32Array()
	c.multi_pick_from_match = 0
	c.muster_out_from_match = 0
	c.salvage_after_loss = false
	return c
