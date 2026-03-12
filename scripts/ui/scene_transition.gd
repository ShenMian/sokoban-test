extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $ColorRect

var collection: String
var level_index: int
var level_count: int

func load_level(new_collection: String, new_index: int, new_level_count: int = 0) -> void:
	collection = new_collection
	level_index = new_index
	level_count = new_level_count
	change_scene_to_file("res://scenes/gameplay.tscn")


func load_next_level() -> void:
	level_index += 1
	if level_count > 0 and level_index >= level_count:
		load_main_menu()
		return
	change_scene_to_file("res://scenes/gameplay.tscn")


func load_main_menu() -> void:
	change_scene_to_file("res://scenes/ui/level_selector.tscn")


func change_scene_to_file(path: String) -> void:
	overlay.visible = true
	animation_player.play("fade_in")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(path)

	animation_player.play("fade_out")
	await animation_player.animation_finished
	overlay.visible = false
	transition_finished.emit()
