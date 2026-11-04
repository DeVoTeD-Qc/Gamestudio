# title.gd
# Purpose: Placeholder Title screen (cc01): game name, "concept demo" line and the
#   unofficial-pitch disclaimer (plan header, IP rule). cc13: the two entry points, ENTER THE WALL
#   (the Banner Wall hub) and FIND A MATCH (the Lobby Duel's simulated matchmaking wait).
#   Prints "Title: ready", the marker the web load-time check waits for (cc17).
# Dependencies: EventBus, Settings, SceneRouter.
# Author: Mechanics Developer Agent
extends Control

const GAME_TITLE: String = "BANNER WALL"
const SUBTITLE: String = "Concept demo"
const DISCLAIMER: String = "Unofficial concept demo. Not affiliated with Activision or Call of Duty."

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _disclaimer: Label = %DisclaimerLabel
@onready var _status: Label = %StatusLabel
@onready var _start: Button = %StartButton
@onready var _lobby: Button = %LobbyButton


func _ready() -> void:
	_title.text = GAME_TITLE
	_subtitle.text = SUBTITLE
	_disclaimer.text = DISCLAIMER
	_status.text = ""
	_start.pressed.connect(_on_start_pressed)
	_lobby.pressed.connect(_on_lobby_pressed)
	EventBus.screen_shown.emit(&"title")
	print("Title: ready")


func _on_start_pressed() -> void:
	_status.text = "Opening the wall..."
	SceneRouter.goto_scene(SceneRouter.SCENE_HUB)


func _on_lobby_pressed() -> void:
	_status.text = "Looking for a match..."
	SceneRouter.goto_scene(SceneRouter.SCENE_LOBBY)
