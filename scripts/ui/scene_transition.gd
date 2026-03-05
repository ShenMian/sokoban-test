extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.visible = false


func change_scene_to_file(path: String):
	color_rect.visible = true
	animation_player.play("fade_in")
	await animation_player.animation_finished
	
	get_tree().change_scene_to_file(path)
	
	animation_player.play("fade_out")
	await animation_player.animation_finished
	color_rect.visible = false
	transition_finished.emit()
