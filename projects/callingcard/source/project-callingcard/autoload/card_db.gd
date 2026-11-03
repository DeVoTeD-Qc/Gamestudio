# card_db.gd
# Purpose: CardDB autoload. STUB from cc01 so the autoload order is fixed early.
#   Loads data/**/*.tres and validates it loudly (CardData, SetData, RivalData, ...).
#   Filled in by task cc02. Keep it registered in project.godot in this order:
#   EventBus, Settings, CardDB, Collection, PlaytestLog, SceneRouter.
# Dependencies: EventBus.
# Author: Mechanics Developer Agent
extends Node
