# title.gd
# Purpose: Placeholder Title screen (cz03): the game name and the "Prototype build" line.
#   cz13 replaces it with the real Title (version, Continue, New match).
#   Prints "Title: ready", the marker web load checks wait for.
# Dependencies: EventBus.
# Author: Mechanics Developer Agent
extends Control

const GAME_TITLE: String = "CardZone"
const SUBTITLE: String = "Prototype build"

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel


func _ready() -> void:
	_title.text = GAME_TITLE
	_subtitle.text = SUBTITLE
	EventBus.screen_shown.emit(&"title")
	print("Title: ready")
