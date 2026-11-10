# wip_run_check.gd
# Purpose: kc-wip-design campaign check for the head's Wip set (documentation/design/wip-set.md §4): the shipped
#   run_v2_check.gd with the Wip cards loadable by id (wip_cards.gd caches them at res://data/cards/<id>.tres),
#   so its own options take them: starter=private_1*3,private_2*3,... (the starter ladder) and the reward-pool
#   what-if below. Runs use the plain MatchState (RunProgress), so only the ENGINE_READY Wip cards behave as
#   designed here; the four new mechanics are measured in wip_duel_sim.gd.
#   Environment: WIP_POOL=1 adds one copy of each ENGINE_READY Wip card (the Privates and Premium Loadout
#   excepted: Standard Issue / a sim stand-in) to the reward pool; WIP_SET (wip_cards.gd what-ifs).
#   Run: WIP_POOL=1 godot --headless --path . -s res://tests/tools/wip_run_check.gd -- exps=runs runs=400
# Author: Sr Game Designer Agent (kc-wip-design)
extends "res://tests/tools/run_v2_check.gd"

const WC: GDScript = preload("res://tests/tools/wip_cards.gd")


func _main() -> void:
	var cards: Dictionary = WC.register(false)
	if OS.get_environment("WIP_POOL") == "1":
		# load() returns the cached RunConfig, and run_v2_check duplicates it shallowly: the pool is shared.
		var rc: RunConfig = load("res://data/run_config.tres") as RunConfig
		var pool: Array[CardData] = rc.reward_pool.duplicate()
		for id: StringName in WC.ENGINE_READY:
			if id != &"premium_loadout" and (cards[id] as CardData).collectible:
				pool.append(cards[id])
		print("wip_run_check: reward pool %d cards (+%d Wip)" % [pool.size(), pool.size() - rc.reward_pool.size()])
		rc.reward_pool = pool
	await super._main()
