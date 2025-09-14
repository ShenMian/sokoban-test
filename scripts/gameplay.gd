extends Node3D

@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var hud: Control = $CanvasLayer/HUD


func _input(_event):
	if Input.is_action_just_released("pause"):
		hud.hide()
		pause_menu.open()
		# TODO: 重新显示 HUD
