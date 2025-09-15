extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $CenterContainer/VBoxContainer/CreditsButton
@onready var close_button: Button = $CloseButton

func open():
	get_tree().paused = true
	show()
	animation_player.play("blur")

	close_button.pressed.connect(close)


func close():
	hide()
	get_tree().paused = false


func _ready():
	pass


func _input(_event: InputEvent):
	if Input.is_action_just_released("pause"):
		get_viewport().set_input_as_handled()
		close()
