extends Control

signal closed
signal request_settings

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var settings_button: ButtonFx = $MenuBackground/VBox/SettingsButton
@onready var credits_button: ButtonFx = $MenuBackground/VBox/CreditsButton
@onready var close_button: ButtonFx = $CloseButton


func open():
	get_tree().paused = true
	show()
	animation_player.play("blur")


func close():
	hide()
	closed.emit()
	get_tree().paused = false


func _ready():
	close_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)


func _input(_event: InputEvent):
	if not self.visible:
		return


func _on_settings_pressed():
	request_settings.emit()
