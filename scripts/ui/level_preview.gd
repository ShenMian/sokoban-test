extends SubViewport
class_name LevelPreview

signal preview_generated(index: int, texture: Texture2D)

const BOX_SCENE := preload("res://scenes/box.tscn")

@onready var level_map: LevelMap = $LevelMap
@onready var boxes: MultiMeshInstance3D = $LevelMap/Boxes
@onready var player: Node3D = $LevelMap/Player
@onready var camera: Camera3D = $Camera

var levels: Array[Dictionary] = []
var _queue: Array[int] = []
var _version: int = 0

var _is_processing: bool = false


func _ready() -> void:
	if Settings.get_value("gameplay", "2d_view"):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func set_levels(new_levels: Array[Dictionary]) -> void:
	_version += 1
	levels = new_levels
	_queue.clear()


func submit_queue(new_queue: Array[int]) -> void:
	_queue = new_queue


func set_preview_size(new_size: Vector2) -> void:
	size = new_size


func _process(_delta: float) -> void:
	if _queue.is_empty() or _is_processing:
		return

	_is_processing = true
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

	if version != _version:
		_is_processing = false
		return

	var image := get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)

	preview_generated.emit(index, texture)
	_is_processing = false


func _sync_entities_from_state() -> void:
	var box_positions := level_map.get_box_positions()

	var multi_mesh := boxes.multimesh
	multi_mesh.instance_count = box_positions.size()
	for i in range(box_positions.size()):
		var pos = box_positions[i]
		multi_mesh.set_instance_transform(i, Transform3D().translated(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5)))

	var player_position := level_map.get_player_position()
	player.position = Vector3(player_position.x, 0.0, player_position.y)
