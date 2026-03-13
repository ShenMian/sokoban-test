extends LevelMap

enum Direction {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3
}

const HEATMAP_CELL_SCENE = preload("res://scenes/heatmap_cell.tscn")
const BOX_SCENE = preload("res://scenes/box.tscn")
const WAYPOINT_SCENE = preload("res://scenes/waypoint.tscn")

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints_container: Node3D = $Waypoints
@onready var heatmap_container: Node3D = $Heatmap
@onready var gameplay: Node3D = $".."

@export
var heatmap: bool:
	set(value):
		heatmap = value
		for child in heatmap_container.get_children():
			child.queue_free()
		if heatmap:
			_build_heatmap()

var _pushable_hint: bool
var _selected_box: Box


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)

	assert(SceneTransition.collection != null and SceneTransition.level_index != null)
	var path := Settings.LEVEL_PATH + SceneTransition.collection + ".xsb"
	var level_id = SceneTransition.level_index + 1
	load_from_file(path, level_id)
	_sync_entities_from_state()

	_reset_camera_position()

	await get_tree().process_frame
	gameplay.level_label.text = str(level_id)
	_update_ui()


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
		do_undo_all()


func do_undo() -> void:
	undo()
	_sync_entities_from_state()
	_update_ui()


func do_redo() -> void:
	redo()
	_sync_entities_from_state()
	_update_ui()


func do_undo_all() -> void:
	undo_all()
	_sync_entities_from_state()
	_update_ui()


func do_solve() -> void:
	deselect_box()
	await _execute_path(solve(solver_algorithm, solver_strategy))


func wait_for_moves_finished() -> void:
	if player.is_moving:
		await player.move_finished
	for box in boxes_container.get_children():
		if box.is_moving:
			await box.move_finished


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		load_from_string(DisplayServer.clipboard_get())
		_sync_entities_from_state()
		_update_ui()
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
			build()
		elif key == "checkerboard":
			checkerboard_shading = value
			build()
		elif key == "pushable_hint":
			_pushable_hint = value
			_update_pushable_hint()
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


func _execute_path(directions: Array) -> void:
	for direction in directions:
		if is_solved():
			break
		move_by(direction)
		await wait_for_moves_finished()
	_update_ui()


func _is_box_moving() -> bool:
	for box in boxes_container.get_children():
		if box.is_moving:
			return true
	return false


func _sync_entities_from_state() -> void:
	var snapshot: Dictionary = get_state_snapshot()
	var box_positions: Array = snapshot["box_positions"]
	var player_pos: Vector2i = snapshot["player_position"]

	for child in boxes_container.get_children():
		child.queue_free()

	for box_pos in box_positions:
		var box: Box = BOX_SCENE.instantiate()
		box.position = Vector3(box_pos.x, 0.0, box_pos.y)
		box.selected.connect(func() -> void:
			on_box_selected(box)
		)
		box.unselected.connect(on_box_unselected)
		box.move_finished.connect(_update_pushable_hint)
		boxes_container.add_child(box)

	player.position = Vector3(player_pos.x, 0.0, player_pos.y)
	_update_pushable_hint()


func _update_pushable_hint() -> void:
	if not _pushable_hint:
		for box in boxes_container.get_children():
			box.disabled = false
		return

	var pushable_positions: Array = get_pushable_box_positions()
	for box in boxes_container.get_children():
		var grid_pos: Vector2i = box.grid_position()
		var is_pushable := pushable_positions.any(func(pos: Vector2i) -> bool:
			return pos == grid_pos
		)
		box.disabled = not is_pushable


func on_box_selected(box: Box) -> void:
	if _selected_box != null and _selected_box != box:
		_selected_box.deselect()

	_selected_box = box
	_rebuild_waypoints(box.grid_position())


func on_box_unselected() -> void:
	_selected_box = null
	_clear_waypoints()


func deselect_box() -> void:
	if _selected_box != null:
		var selected_box := _selected_box
		_selected_box = null
		selected_box.deselect()
	_clear_waypoints()


func _rebuild_waypoints(from: Vector2i) -> void:
	_clear_waypoints()
	for to in get_waypoint_positions(from):
		var waypoint = WAYPOINT_SCENE.instantiate()
		waypoint.position = Vector3(to.x, 0.01, to.y)
		waypoint.clicked.connect(func() -> void:
			_on_waypoint_clicked(from, to)
		)
		waypoints_container.add_child(waypoint)


func _clear_waypoints() -> void:
	for child in waypoints_container.get_children():
		child.queue_free()


func _on_player_moved(_to: Vector2, _pushed: bool) -> void:
	_update_ui()


func _update_ui() -> void:
	var snapshot: Dictionary = get_state_snapshot()
	_update_labels(snapshot)
	_update_pushable_hint()
	if player.is_moving or _is_box_moving():
		gameplay.undo_button.disabled = true
		gameplay.redo_button.disabled = true
		gameplay.undo_all_button.disabled = true
		gameplay.solve_button.disabled = true
	else:
		gameplay.undo_button.disabled = !snapshot["can_undo"]
		gameplay.redo_button.disabled = !snapshot["can_redo"]
		gameplay.undo_all_button.disabled = !snapshot["can_undo"]
		gameplay.solve_button.disabled = false


func _update_labels(snapshot: Dictionary) -> void:
	gameplay.moves_label.text = str(snapshot["move_count"])
	gameplay.pushes_label.text = str(snapshot["push_count"])


func _on_solved() -> void:
	print("Level solved!")
	Settings.set_level_solution(SceneTransition.collection, SceneTransition.level_index, get_actions())


func _reset_camera_position() -> void:
	var center := get_dimensions() / 2.0
	var max_dimension = max(get_dimensions().x, get_dimensions().y)
	camera._target_position = Vector3(center.x, max_dimension, center.y)
	camera.global_position = camera._target_position
	camera.zoom_factor = max_dimension + 1.0
