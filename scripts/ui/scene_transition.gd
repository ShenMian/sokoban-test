extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $ColorRect

var level_id: int

var collection_name: String
var collection_count: int
var level_index: int

func load_level(new_level_id: int, new_collection_name: String) -> void:
	level_id = new_level_id

	collection_name = new_collection_name
	collection_count = Database.get_collection_size(collection_name)
	level_index = Database.get_level_index(level_id, collection_name)

	change_scene_to_file("res://scenes/gameplay.tscn")


func has_previous_level() -> bool:
	return level_index > 0


func has_next_level() -> bool:
	return level_index + 1 < collection_count


func load_previous_level() -> void:
	assert(has_previous_level())
	level_id -= 1
	level_index -= 1
	change_scene_to_file("res://scenes/gameplay.tscn")


func load_next_level() -> void:
	assert(has_next_level())
	level_id += 1
	level_index += 1
	change_scene_to_file("res://scenes/gameplay.tscn")


func load_main_menu() -> void:
	change_scene_to_file("res://scenes/ui/level_list.tscn")


func change_scene_to_file(path: String) -> void:
	overlay.visible = true
	animation_player.play("fade_in")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(path)

	animation_player.play("fade_out")
	await animation_player.animation_finished
	overlay.visible = false
	transition_finished.emit()
