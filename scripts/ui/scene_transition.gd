extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $ColorRect

var collection: String
var level_count: int
var level_index: int

func load_level(new_collection: String, new_count: int, new_index: int) -> void:
	collection = new_collection
	level_count = new_count
	level_index = new_index
	change_scene_to_file("res://scenes/gameplay.tscn")


func has_previous_level() -> bool:
	return level_index > 0


func load_previous_level() -> void:
	assert(has_previous_level())
	level_index -= 1
	change_scene_to_file("res://scenes/gameplay.tscn")


func has_next_level() -> bool:
	return level_index + 1 < level_count


func load_next_level() -> void:
	assert(has_next_level())
	level_index += 1
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
