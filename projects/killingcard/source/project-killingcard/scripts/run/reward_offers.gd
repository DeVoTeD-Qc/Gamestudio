# reward_offers.gd
# Purpose: Builds the between-match offers of a run (core-rules §3, Rulings 1-2,
#   content-log gap 7): Supply Drop (pick 1 of N different card designs, weighted by
#   the copies in RunConfig.reward_pool), weapon level (N attachments of the Primary's
#   pool the player doesn't own) and Perk offer (N Perks of perk_pool not owned).
#   Pure and deterministic: every pick draws from the RandomNumberGenerator passed in.
#   An offer is a plain Dictionary so it can go straight into the save file:
#     {kind: &"supply_drop" | &"attachment" | &"perk", match: int (1-based), options: Array[StringName]}
# Dependencies: RunConfig, CardData, LoadoutItem.
# Author: Mechanics Developer Agent
class_name RewardOffers
extends RefCounted

const KIND_SUPPLY_DROP: StringName = &"supply_drop"
const KIND_ATTACHMENT: StringName = &"attachment"
const KIND_PERK: StringName = &"perk"
const KINDS: Array[StringName] = [KIND_SUPPLY_DROP, KIND_ATTACHMENT, KIND_PERK]


## Supply Drop: `config.supply_drop_choices` different designs, each design's chance
## proportional to its copies in reward_pool (picked one after another without
## replacement). Fewer designs in the pool than choices -> all of them.
static func supply_drop(config: RunConfig, rng: RandomNumberGenerator) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardData in config.reward_pool:
		if card != null and card.collectible:
			ids.append(card.id)
	return weighted_distinct(ids, config.supply_drop_choices, rng)


## Weapon level: up to `config.attachment_choices` attachments from the Primary's
## pool that aren't in `owned`. Empty when the pool is used up.
static func attachments(config: RunConfig, primary: LoadoutItem, owned: Array[StringName],
		rng: RandomNumberGenerator) -> Array[StringName]:
	var ids: Array[StringName] = []
	if primary != null:
		for att: LoadoutItem in primary.attachments:
			if att != null and att.id not in owned:
				ids.append(att.id)
	return weighted_distinct(ids, config.attachment_choices, rng)


## Perk offer: up to `config.perk_choices` Perks from perk_pool not in `owned`.
## Empty when every Perk slot is full or the pool is used up.
static func perks(config: RunConfig, owned: Array[StringName], rng: RandomNumberGenerator) -> Array[StringName]:
	if owned.size() >= config.perk_slots:
		return []
	var ids: Array[StringName] = []
	for perk: LoadoutItem in config.perk_pool:
		if perk != null and perk.id not in owned:
			ids.append(perk.id)
	return weighted_distinct(ids, config.perk_choices, rng)


## Picks up to `count` different ids from `entries`; repeated entries are weights.
## The result keeps the order of the picks.
static func weighted_distinct(entries: Array[StringName], count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	# Collapse to (id, weight) in first-seen order so the draw is independent of
	# dictionary ordering.
	var order: Array[StringName] = []
	var weight: Dictionary = {}
	for id: StringName in entries:
		if not weight.has(id):
			order.append(id)
			weight[id] = 0
		weight[id] = int(weight[id]) + 1
	var picks: Array[StringName] = []
	while picks.size() < count and not order.is_empty():
		var total: int = 0
		for id: StringName in order:
			total += int(weight[id])
		var roll: int = rng.randi_range(0, total - 1)
		for i: int in order.size():
			roll -= int(weight[order[i]])
			if roll < 0:
				picks.append(order[i])
				order.remove_at(i)
				break
	return picks
