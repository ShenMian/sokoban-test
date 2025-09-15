extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var settings_button: Button = $MenuBackground/VBox/SettingsButton
@onready var credits_button: Button = $MenuBackground/VBox/CreditsButton
@onready var close_button: Button = $CloseButton


func open():
	get_tree().paused = true
	show()
	animation_player.play("blur")


func close():
	hide()
	get_tree().paused = false


func _ready():
	close_button.pressed.connect(close)


func _input(_event: InputEvent):
	if Input.is_action_just_released("pause"):
		get_viewport().set_input_as_handled()
		close()
