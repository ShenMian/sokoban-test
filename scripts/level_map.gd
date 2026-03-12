extends LevelMap

signal undo_redo_state_changed

enum Direction {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3
}

const HEATMAP_CELL_SCENE = preload("res://scenes/heatmap_cell.tscn")

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints_container: Node3D = $Waypoints
@onready var heatmap_container: Node3D = $Heatmap
@onready var level_label: Label = $"../HudLayer/HUD/StatusPanel/HBox/LevelVBox/LevelValue"
@onready var moves_label: Label = $"../HudLayer/HUD/StatusPanel/HBox/MovesVBox/MovesValue"
@onready var pushes_label: Label = $"../HudLayer/HUD/StatusPanel/HBox/PushesVBox/PushesValue"

@export
var heatmap: bool:
	set(value):
		heatmap = value
		for child in heatmap_container.get_children():
			child.queue_free()
		if heatmap:
			_build_heatmap()

var has_redo: bool = false


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)

	assert(SceneTransition.collection != null and SceneTransition.level_index != null)
	var path := Settings.LEVEL_PATH + SceneTransition.collection + ".xsb"
	var level_id = SceneTransition.level_index + 1
	load_from_file(path, level_id)
	level_label.text = str(level_id)

	_reset_camera_position()

	await get_tree().process_frame
	_update_labels()
	update_pushable_hint()


func _process(_delta: float) -> void:
	if player.is_moving or _is_box_moving():
		return

	if Input.is_action_pressed("move_right"):
		move_by(Direction.RIGHT)
	elif Input.is_action_pressed("move_left"):
		move_by(Direction.LEFT)
	elif Input.is_action_pressed("move_up"):
		move_by(Direction.UP)
	elif Input.is_action_pressed("move_down"):
		move_by(Direction.DOWN)
	elif Input.is_action_just_pressed("undo_all"):
		var had_moves := get_move_count() > 0
		undo_all()
		if had_moves:
			has_redo = true
			undo_redo_state_changed.emit()
		_update_labels()
		update_pushable_hint()


func do_undo() -> void:
	undo()
	has_redo = true
	undo_redo_state_changed.emit()
	_update_labels()
	update_pushable_hint()


func do_redo() -> void:
	var prev_count := get_move_count()
	redo()
	if get_move_count() == prev_count:
		has_redo = false
		undo_redo_state_changed.emit()
	_update_labels()
	update_pushable_hint()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		load_from_string(DisplayServer.clipboard_get())
		has_redo = false
		undo_redo_state_changed.emit()
		_update_labels()
		update_pushable_hint()
		_reset_camera_position()
	elif Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(get_map())


func _build_heatmap() -> void:
	var lower_bounds: Dictionary = get_lower_bounds()
	var max_lower_bound: int = lower_bounds.values().max()
	for pos in lower_bounds:
		var heatmap_cell: HeatmapCell = HEATMAP_CELL_SCENE.instantiate()
		heatmap_cell.position = Vector3(pos.x, 0.01, pos.y)
		heatmap_container.add_child(heatmap_cell)
		heatmap_cell.setup(lower_bounds[pos], max_lower_bound)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player.is_moving:
			get_viewport().set_input_as_handled()
			return

		var space_state := get_world_3d().direct_space_state
		var ray_origin := camera.project_ray_origin(event.position)
		var ray_end := ray_origin + camera.project_ray_normal(event.position) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		query.collide_with_bodies = false

		# Checks if the click was on an empty space (without Area3D)
		if space_state.intersect_ray(query).is_empty():
			deselect_box()


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay":
		if key == "deadlock_hint":
			deadlock_hint = value
		elif key == "checkerboard":
			checkerboard_shading = value
		elif key == "pushable_hint":
			pushable_hint = value
		elif key == "heatmap":
			heatmap = value
		elif key == "pathfinding_strategy":
			pathfinding_strategy = value
		elif key == "algorithm":
			solver_algorithm = value
		elif key == "solver_strategy":
			solver_strategy = value


func _on_waypoint_clicked(from: Vector2i, to: Vector2i) -> void:
	deselect_box()
	await _execute_path(get_box_move_path(from, to))


func solve_level() -> void:
	deselect_box()

	if player.is_moving:
		return

	await _execute_path(solve(solver_algorithm, solver_strategy))


func _execute_path(directions: Array) -> void:
	for direction in directions:
		if is_solved():
			break
		move_by(direction)
		await wait_for_moves_finished()


func _is_box_moving() -> bool:
	for box in boxes_container.get_children():
		if box.is_moving:
			return true
	return false


func wait_for_moves_finished() -> void:
	if player.is_moving:
		await player.move_finished
	for box in boxes_container.get_children():
		if box.is_moving:
			await box.move_finished


func _on_player_moved(_to: Vector2, _pushed: bool) -> void:
	has_redo = false
	_update_labels()


func _update_labels() -> void:
	moves_label.text = str(get_move_count())
	pushes_label.text = str(get_push_count())


func _on_solved() -> void:
	print("Level solved!")
	Settings.set_level_solution(SceneTransition.collection, SceneTransition.level_index, get_actions())


func _reset_camera_position() -> void:
	var center := get_dimensions() / 2.0
	var max_dimension = max(get_dimensions().x, get_dimensions().y)
	camera._target_position = Vector3(center.x, max_dimension, center.y)
	camera.global_position = camera._target_position
	camera.zoom_factor = max_dimension + 1.0
