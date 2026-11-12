# test_econ.gd
# Purpose: kc-econ (the head: "start at 1 supply and also draw only one card per turn. Maybe the
#   starting deck should be 10 cards so we see our newly earned cards faster. Shuffle discard if we
#   run out of cards, like classic deckbuilder."). Checks the shipped numbers (round N gives N Supply,
#   1 draw per round, a 10-card starter and crews, floor 8, the Operator free in round 1 only), the
#   classic reshuffle (an empty deck takes the shuffled discard pile, nothing else) and that the
#   match log says so in words.
# Author: Mechanics Developer Agent (kc-econ)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


func _shipped() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func test_shipped_economy_numbers() -> void:
	var cfg: RunConfig = _shipped()
	var supply: Array = []
	for r: int in range(1, 10):
		supply.append(cfg.supply_for_round(r))
	assert_eq(supply, [1, 2, 3, 4, 5, 6, 7, 7, 7], "round N gives N Supply, capped at 7")
	assert_eq([cfg.draws_per_round, cfg.opening_hand, cfg.round1_extra_draw, cfg.free_mulligans, cfg.hand_cap], [1, 4, 1, 1, 7],
			"1 draw per round; round 1 still draws the opening hand of 4 + 1 and keeps the free mulligan")
	assert_eq([cfg.deck_size, cfg.starter_deck.size(), cfg.deck_floor], [10, 10, 8], "10-card starter, floor 8")
	assert_eq([cfg.operator_cost, cfg.operator_free_round1], [1, true], "the Operator: free in round 1, 1 Supply per respawn")
	assert_eq([cfg.operator_cost_in_round(1), cfg.operator_cost_in_round(2), cfg.operator_cost_in_round(6)], [0, 1, 1], "cost by round")
	var plain: RunConfig = RunConfig.new()
	plain.operator_cost = 1
	assert_eq(plain.operator_cost_in_round(1), 1, "without operator_free_round1 round 1 costs the same")
	for md: RunMatchData in cfg.matches + cfg.bosses:
		assert_eq(md.deck_for_squad().size(), 10, "%s plays a 10-card deck" % md.crew_label)
	for f: String in ["squad_rusher", "squad_anchor", "squad_black_meridian", "squad_hollow_choir"]:
		assert_eq((load("res://data/squads/%s.tres" % f) as SquadData).deck.size(), 10, "%s: 10 cards" % f)


func test_round_one_supply_operator_and_draws_on_the_engine() -> void:
	var cfg: RunConfig = _shipped()
	var deck: Array[CardData] = cfg.starter_deck.duplicate()
	var p: SideSetup = F.setup(deck, cfg.starter_primary)
	var e: SideSetup = F.setup(deck.duplicate(), cfg.starter_primary)
	var m: MatchState = MatchState.new(cfg, F.flat_map(), p, e, 7, null)
	m.start_match()
	var me: RulesSide = m.sides[P]
	assert_eq([me.supply, m.sides[E].supply], [1, 1], "round 1: 1 Supply each (symmetric)")
	assert_eq([me.hand.size(), me.deck.size()], [5, 5], "opening hand 4 + 1 from 10 cards")
	assert_eq(m.operator_cost(), 0, "the round-1 placement is free")
	assert_true(m.submit(P, RulesIntent.place_operator(0))["ok"], "Operator placed for free")
	assert_eq(me.supply, 1, "the Supply is still there for a card")
	m.set_ready(P)
	m.set_ready(E)
	m.resolve_round()
	m.begin_round()
	assert_eq([m.round_number, me.supply, me.hand.size(), me.deck.size()], [2, 2, 6, 4], "round 2: 2 Supply, 1 card drawn")
	assert_eq(m.operator_cost(), 1, "from round 2 a (re)placement costs 1")


func test_empty_deck_reshuffles_the_discard_like_a_deckbuilder() -> void:
	var cards: Array[CardData] = []
	for i: int in 4:
		cards.append(F.unit("u%d" % i, 1, 1))
	var m: MatchState = F.new_match(F.setup(cards), F.setup(cards.duplicate()))
	var me: RulesSide = m.sides[P]
	# Draw the deck dry, then "play" two cards to the discard pile.
	m.draw_cards(P, me.deck.size())
	assert_true(me.deck.is_empty(), "deck empty")
	var hand0: int = me.hand.size()
	var gone: Array[RulesCard] = [me.hand[0], me.hand[1]]
	for c: RulesCard in gone:
		me.hand.erase(c)
		me.discard.append(c)
	var ev0: int = m.events.size()
	m.draw_cards(P, 1)
	var shuffled: Array = m.events.slice(ev0).filter(func(ev: Dictionary) -> bool: return ev["type"] == RulesEvent.DECK_RESHUFFLED)
	assert_eq(shuffled.size(), 1, "one reshuffle event")
	assert_eq(int(shuffled[0].get("count", 0)), 2, "the reshuffle took exactly the 2 discarded cards")
	assert_true(me.discard.is_empty(), "the discard pile became the new deck")
	assert_eq([me.hand.size(), me.deck.size()], [hand0 - 1, 1], "drew 1 of the 2, 1 left to draw")
	assert_true(gone.any(func(c: RulesCard) -> bool: return c in me.hand), "the drawn card came from the old discard")
	# Nothing in deck or discard: drawing stops quietly (no reshuffle of an empty pile).
	m.draw_cards(P, 1)
	var ev1: int = m.events.size()
	m.draw_cards(P, 1)
	assert_eq(m.events.slice(ev1).filter(func(ev: Dictionary) -> bool: return ev["type"] == RulesEvent.DECK_RESHUFFLED).size(), 0, "empty piles: no reshuffle")


func test_reshuffle_is_said_in_the_match_log() -> void:
	var c: Node = (load("res://scripts/ui/match_controller.gd") as GDScript).new()
	c.call(&"_add_v2_line", {"type": RulesEvent.DECK_RESHUFFLED, "side": &"player", "count": 6})
	c.call(&"_add_v2_line", {"type": RulesEvent.DECK_RESHUFFLED, "side": &"enemy", "count": 4})
	var feed: Array = c.get(&"killfeed")
	assert_eq(feed.size(), 2, "two log lines")
	assert_eq(String(feed[1]["text"]), "DISCARD RESHUFFLED: NEW DECK OF 6", "your reshuffle, in words")
	assert_eq(String(feed[0]["text"]), "RIVAL RESHUFFLED: NEW DECK OF 4", "the rival's too")
	c.free()
