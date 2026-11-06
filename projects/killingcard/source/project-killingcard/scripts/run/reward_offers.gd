# reward_offers.gd
# Purpose: Builds the between-match offers of a run (core-rules §3, Rulings 1-2,
#   content-log gap 7): Supply Drop (pick 1 of N different card designs, weighted by
#   the copies in RunConfig.reward_pool), weapon level (N attachments of the Primary's
#   pool the player doesn't own) and Perk offer (N Perks of perk_pool not owned).
#   Pure and deterministic: every pick draws from the RandomNumberGenerator passed in.
#   An offer is a plain Dictionary so it can go straight into the save file:
#     {kind: &"supply_drop" | &"attachment" | &"perk", match: int (1-based), options: Array[StringName]}
#   kc-syn (synergy-system.md §5) adds: &"doctrine" (options = trait ids), &"promotion" and
#   &"regroup" (options = card ids with a parallel `levels` array: each option is the first copy
#   of that design at that level). A Supply Drop may carry `on_trait` (slot 1's trait) and
#   `retire: true` (Retire is its 4th option). RunProgress builds and resolves them.
#   kc-art-traits: a Supply Drop also carries `traits` + `arts` (parallel to options: the trait and
#   art each card comes in) and `reissue: true` (Re-issue next to Retire); Promotion / Regroup carry
#   `traits` (each option's trait choice) and Regroup `reissue: true`.
# Dependencies: RunConfig, CardData, LoadoutItem.
# Author: Mechanics Developer Agent
class_name RewardOffers
extends RefCounted

const KIND_SUPPLY_DROP: StringName = &"supply_drop"
const KIND_ATTACHMENT: StringName = &"attachment"
const KIND_PERK: StringName = &"perk"
const KIND_DOCTRINE: StringName = &"doctrine"
const KIND_PROMOTION: StringName = &"promotion"
const KIND_REGROUP: StringName = &"regroup"
const KINDS: Array[StringName] = [KIND_SUPPLY_DROP, KIND_ATTACHMENT, KIND_PERK, KIND_DOCTRINE, KIND_PROMOTION, KIND_REGROUP]


## Supply Drop: `config.supply_drop_choices` different designs, each design's chance
## proportional to its copies in reward_pool (picked one after another without
## replacement). Fewer designs in the pool than choices -> all of them.
static func supply_drop(config: RunConfig, rng: RandomNumberGenerator) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardData in config.reward_pool:
		if card != null and card.collectible:
			ids.append(card.id)
	return weighted_distinct(ids, config.supply_drop_choices, rng)


## kc-syn §5.2 Supply Drop with an on-trait slot: slot 1 is a card that CAN carry `main_trait`
## (kc-art-traits: one of its trait options; RunProgress dresses it in that trait's art) (weighted by its
## copies in the pool), slots 2-3 are weighted random among the other designs. No on-trait card in
## the pool (or no main trait) -> a plain supply_drop().
static func supply_drop_on_trait(config: RunConfig, main_trait: StringName, rng: RandomNumberGenerator) -> Array[StringName]:
	if main_trait == &"":
		return supply_drop(config, rng)
	var on: Array[StringName] = []
	for card: CardData in config.reward_pool:
		if card != null and card.collectible and card.can_carry(main_trait):
			on.append(card.id)
	if on.is_empty():
		return supply_drop(config, rng)
	var first: Array[StringName] = weighted_distinct(on, 1, rng)
	var rest: Array[StringName] = []
	for card: CardData in config.reward_pool:
		if card != null and card.collectible and card.id != first[0]:
			rest.append(card.id)
	var picks: Array[StringName] = first
	picks.append_array(weighted_distinct(rest, config.supply_drop_choices - 1, rng))
	return picks


## kc-syn §5.2 Doctrine: `best` first (the deck's main trait), then random other traits, up to `count`.
static func doctrine(best: StringName, count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var picks: Array[StringName] = []
	if best != &"":
		picks.append(best)
	var others: Array[StringName] = []
	for t: StringName in SynergyRules.TRAITS:
		if t not in picks:
			others.append(t)
	picks.append_array(weighted_distinct(others, count - picks.size(), rng))
	return picks


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
