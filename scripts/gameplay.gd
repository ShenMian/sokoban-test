extends Node3D


func _input(_event):
	if Input.is_action_just_released("pause"):
		$HUD.hide()
		$PauseMenu.open()
