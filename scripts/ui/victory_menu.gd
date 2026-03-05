extends Control
class_name VictoryMenu

signal request_next_level
signal request_menu

@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var next_button: Button = $Panel/Margin/VBox/VBox/NextButton
@onready var menu_button: Button = $Panel/Margin/VBox/VBox/MenuButton


func open(moves: int, pushes: int):
	get_tree().paused = true
	moves_label.text = str(moves)
	pushes_label.text = str(pushes)
	show()
	animation_player.play("show")


func close():
	hide()
	get_tree().paused = false


func _ready():
	next_button.pressed.connect(_on_next_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)


func _on_next_button_pressed():
	close()
	request_next_level.emit()


func _on_menu_button_pressed():
	close()
	request_menu.emit()
