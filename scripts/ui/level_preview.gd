extends SubViewport
class_name LevelPreview

signal preview_generated(index: int, texture: Texture2D)

const BOX_SCENE := preload("res://scenes/box.tscn")

@onready var level_map: LevelMap = $LevelMap
@onready var boxes_container: Node3D = $LevelMap/Boxes
@onready var player: Node3D = $LevelMap/Player
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

		level_map.load_from_string(levels[index]["map_xsb"])
		_sync_entities_from_state()

		var dimensions = Vector2(level_map.get_dimensions())
		var center = dimensions / 2.0
		var max_dimension = max(dimensions.x, dimensions.y)
		camera.global_position = Vector3(center.x, max_dimension, center.y)
		camera.global_position.y = max_dimension / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))

		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = max_dimension

		render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw

		var image := get_texture().get_image()
		var texture = ImageTexture.create_from_image(image)

		if version != _version:
			return
		preview_generated.emit(index, texture)


func _sync_entities_from_state() -> void:
	for child in boxes_container.get_children():
		child.queue_free()

	for box_position in level_map.get_box_positions():
		var box: Box = BOX_SCENE.instantiate()
		box.position = Vector3(box_position.x, 0.0, box_position.y)
		boxes_container.add_child(box)

	var player_position := level_map.get_player_position()
	player.position = Vector3(player_position.x, 0.0, player_position.y)
