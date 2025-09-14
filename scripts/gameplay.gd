extends Node3D

@onready var pause_menu: Control = $MenuLayer/PauseMenu


func _input(_event):
	if Input.is_action_just_released("pause"):
		pause_menu.open()
