# playtest_log.gd
# Purpose: PlaytestLog autoload. STUB from cc01 so the autoload order is fixed early.
#   Playtest logger adapted from Killstreak; listens to EventBus and writes user://playtest_log.jsonl.
#   Filled in by task cc16. Keep it registered in project.godot in this order:
#   EventBus, Settings, CardDB, Collection, PlaytestLog, SceneRouter.
# Dependencies: EventBus.
# Author: Mechanics Developer Agent
extends Node
