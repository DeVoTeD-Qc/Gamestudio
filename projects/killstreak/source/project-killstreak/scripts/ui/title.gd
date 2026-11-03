# title.gd
# Purpose: Placeholder title screen. Start does nothing until the run flow exists (p10).
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Control

@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	print("Title: Start pressed (run flow arrives in p10)")
