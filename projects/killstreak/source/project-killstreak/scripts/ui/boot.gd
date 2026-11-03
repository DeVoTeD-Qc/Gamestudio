# boot.gd
# Purpose: Boot scene. Shows a loading label for one frame, then routes to Title.
# Dependencies: SceneRouter.
# Author: Mechanics Developer Agent
extends Control

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_status.text = "Loading..."
	# Wait one frame so the label is drawn before the next scene loads.
	await get_tree().process_frame
	SceneRouter.goto_scene(SceneRouter.SCENE_TITLE)
