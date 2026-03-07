extends SubViewport
class_name LevelPreviewGenerator

signal preview_generated(index: int, texture: Texture2D)

const PREVIEW_SCENE := preload("res://scenes/ui/preview.tscn")

var levels: Array[Dictionary] = []

var _viewport: SubViewport
var _level_map: LevelMap
var _camera: Camera3D

var _queue: Array[int] = []
var _version: int = 0


func _init():
	_viewport = PREVIEW_SCENE.instantiate()
	add_child(_viewport)

	_level_map = _viewport.get_node("LevelMap")
	_camera = _viewport.get_node("Camera")


func set_levels(new_levels: Array[Dictionary]):
	_version += 1
	levels = new_levels
	_queue.clear()


func submit_queue(new_queue: Array[int]):
	_queue = new_queue


func set_preview_size(new_size: Vector2):
	size = new_size


func _process(_delta: float):
	if _queue.size() > 0:
		var version := _version

		var index: int = _queue.pop_front()

		_level_map.load_from_string(levels[index]["map"])

		var dimensions = Vector2(_level_map.dimensions())
		var center = dimensions / 2.0
		var max_dimension = max(dimensions.x, dimensions.y)
		_camera.global_position = Vector3(center.x, max_dimension, center.y)

		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

		await get_tree().process_frame

		var image := _viewport.get_texture().get_image()
		var texture = ImageTexture.create_from_image(image)

		if version != _version:
			return
		preview_generated.emit(index, texture)
