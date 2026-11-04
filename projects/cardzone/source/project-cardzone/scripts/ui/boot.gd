# boot.gd
# Adapted from CallingCard scripts/ui/boot.gd (unchanged logic).
# Purpose: Boot scene. Shows a loading label for one frame, then routes to the Title.
# Dependencies: SceneRouter.
# Author: Mechanics Developer Agent
extends Control

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_status.text = "Loading..."
	# Wait one frame so the label is drawn before the next scene loads.
	await get_tree().process_frame
	SceneRouter.goto_scene(first_scene())


## The scene Boot routes to. cz18 adds the playtest consent screen in front of the Title.
static func first_scene() -> String:
	return SceneRouter.SCENE_TITLE
