extends Control
class_name VictoryMenu

signal request_next_level
signal request_menu

@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue
@onready var optimal_move_label: Label = %OptimalMoveLabel
@onready var optimal_push_label: Label = %OptimalPushLabel

@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var next_button: Button = $Panel/VBox/VBox/NextButton
@onready var menu_button: Button = $Panel/VBox/VBox/MenuButton


func open(actions: Actions):
	get_tree().paused = true

	moves_label.text = str(actions.moves())
	pushes_label.text = str(actions.pushes())

	var previous_solution := Settings.get_active_level_solution()
	Settings.set_active_level_solution(actions)
	var best_solution := Settings.get_active_level_solution()

	if actions.moves() < previous_solution["optimal_move"].moves():
		moves_label.add_theme_color_override("font_color", Color.GREEN)
		optimal_move_label.text = "(%s %d→%d)" % [tr("BEST"), previous_solution["optimal_move"].moves(), best_solution["optimal_move"].moves()]
	else:
		optimal_move_label.text = "(%s %d)" % [tr("BEST"), best_solution["optimal_move"].moves()]
	if actions.pushes() < previous_solution["optimal_push"].pushes():
		pushes_label.add_theme_color_override("font_color", Color.GREEN)
		optimal_push_label.text = "(%s %d→%d)" % [tr("BEST"), previous_solution["optimal_push"].pushes(), best_solution["optimal_push"].pushes()]
	else:
		optimal_push_label.text = "(%s %d)" % [tr("BEST"), best_solution["optimal_push"].pushes()]

	next_button.visible = SceneTransition.has_next_level()
	show()
	audio_player.play()
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
