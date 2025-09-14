extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func open():
	get_tree().paused = true
	show()
	animation_player.play("blur")


func close():
	hide()
	get_tree().paused = false


func _input(_event: InputEvent):
	if Input.is_action_just_released("pause"):
		get_viewport().set_input_as_handled()
		close()
