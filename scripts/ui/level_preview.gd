extends SubViewport
class_name LevelPreview

signal preview_generated(index: int, texture: Texture2D)

const PREVIEW_SCENE := preload("res://scenes/ui/level_preview.tscn")

@onready var level_map: LevelMap = $LevelMap
@onready var camera: Camera3D = $Camera

var levels: Array[Dictionary] = []

var _queue: Array[int] = []
var _version: int = 0


func _ready():
	if Settings.get_value("gameplay", "2d_view"):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


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

		level_map.load_from_string(levels[index]["map"])

		var dimensions = Vector2(level_map.get_dimensions())
		var center = dimensions / 2.0
		var max_dimension = max(dimensions.x, dimensions.y)
		camera.global_position = Vector3(center.x, max_dimension, center.y)
		camera.global_position.y = max_dimension / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))

		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = max_dimension

		render_target_update_mode = SubViewport.UPDATE_ONCE

		await get_tree().process_frame

		var image := get_texture().get_image()
		var texture = ImageTexture.create_from_image(image)

		if version != _version:
			return
		preview_generated.emit(index, texture)
