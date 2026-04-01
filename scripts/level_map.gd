extends LevelMap

const BOX_SCENE = preload("res://scenes/box.tscn")
const WAYPOINT_SCENE = preload("res://scenes/waypoint.tscn")
const HEATMAP_CELL_SCENE = preload("res://scenes/heatmap_cell.tscn")

@onready var gameplay: Node3D = $".."
@onready var camera: Camera3D = $"../Camera"

@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints_container: Node3D = $Waypoints
@onready var heatmap_container: Node3D = $Heatmap

@onready var enter_goal_player: AudioStreamPlayer3D = $Player/EnterGoalPlayer
@onready var leave_goal_player: AudioStreamPlayer3D = $Player/LeaveGoalPlayer

@export var solver_algorithm: E.Algorithm
@export var solver_strategy: E.Strategy

@export
var heatmap: bool:
	set(value):
		heatmap = value
		for child in heatmap_container.get_children():
			child.queue_free()
		if heatmap:
			_build_heatmap()

@export var pushable_hint: bool

@export var indicator_color: Color:
	set(value):
		indicator_color = value
		if player:
			player.get_node("Indicator/HoverIndicator").material_override.albedo_color = value

var _is_instant: bool
var _selected_box: Box
var _solving: bool = false
var _solve_tween: Tween


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)
	box_enter_goal.connect(enter_goal_player.play)
	box_leave_goal.connect(leave_goal_player.play)
	solve_completed.connect(_on_solve_completed)
	solve_failed.connect(_on_solve_failed)

	var indicator_material: StandardMaterial3D = player.get_node("Indicator/HoverIndicator").get_surface_override_material(0)
	indicator_material.albedo_color = indicator_color

	assert(SceneTransition.level_id != null)
	var level := Database.get_level(SceneTransition.level_id)
	load_from_string(level.get("map_xsb"))

	var snapshot := Database.get_snapshot(SceneTransition.level_id, true)
	fast_forward(snapshot)

	sync_entities_from_state()

	reset_camera_position()

	await get_tree().process_frame
	gameplay.level_label.text = str(SceneTransition.level_index)
	update_ui()


func _process(_delta: float) -> void:
	if _solving:
		poll_solve()
		return

	if Input.is_action_just_pressed("undo_all"):
		do_undo_all()
		return

	if player.is_moving or _is_box_moving():
		return

	if Input.is_action_pressed("move_right"):
		_execute_path([E.Direction.RIGHT])
	elif Input.is_action_pressed("move_left"):
		_execute_path([E.Direction.LEFT])
	elif Input.is_action_pressed("move_up"):
		_execute_path([E.Direction.UP])
	elif Input.is_action_pressed("move_down"):
		_execute_path([E.Direction.DOWN])
	else:
		return


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		load_from_string(DisplayServer.clipboard_get())
		sync_entities_from_state()
		update_ui()
		reset_camera_position()
	elif Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(get_map_xsb())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _solving or player.is_moving:
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


func do_undo() -> void:
	undo()
	deselect_box()
	sync_entities_from_state()
	update_ui()


func do_redo() -> void:
	redo()
	deselect_box()
	sync_entities_from_state()
	update_ui()


func do_undo_all() -> void:
	undo_all()
	deselect_box()
	sync_entities_from_state()
	update_ui()


func do_solve() -> void:
	if _solving:
		cancel_solve()
		_solving = false
		update_ui()
		gameplay.solve_button.modulate = Color.WHITE
		return

	deselect_box()
	_solving = true
	update_ui()
	start_solve(solver_algorithm, solver_strategy)


func _on_solve_completed(directions: Array) -> void:
	_solving = false
	update_ui()
	gameplay.solve_button.modulate = Color.WHITE
	await _execute_path(directions)


func _on_solve_failed(error: String) -> void:
	_solving = false
	update_ui()
	gameplay.solve_button.modulate = Color.RED
	create_tween().tween_property(gameplay.solve_button, "modulate", Color.WHITE, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	push_warning("Solver failed: " + error)


func wait_for_moves_finished() -> void:
	if player.is_moving:
		await player.move_finished
	for box in boxes_container.get_children():
		if box.is_moving:
			await box.move_finished


func _build_heatmap() -> void:
	var lower_bounds: Dictionary = get_lower_bounds(solver_strategy)
	var max_lower_bound: int = lower_bounds.values().max()
	for pos in lower_bounds:
		var heatmap_cell: HeatmapCell = HEATMAP_CELL_SCENE.instantiate()
		heatmap_cell.position = Vector3(pos.x, 0.01, pos.y)
		heatmap_container.add_child(heatmap_cell)
		heatmap_cell.setup(lower_bounds[pos], max_lower_bound)


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay":
		if key == "animation_speed":
			_is_instant = value == E.AnimationSpeed.INSTANT
		elif key == "deadlock_hint":
			deadlock_hint = value
			build()
		elif key == "checkerboard":
			checkerboard_shading = value
			build()
		elif key == "pushable_hint":
			pushable_hint = value
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
		# Wait for animations to finish if not instant
		if not _is_instant:
			await wait_for_moves_finished()
	if _is_instant:
		sync_entities_from_state()
	update_ui()


func _is_box_moving() -> bool:
	for box in boxes_container.get_children():
		if box.is_moving:
			return true
	return false


func sync_entities_from_state() -> void:
	for child in boxes_container.get_children():
		child.queue_free()

	for box_position in get_box_positions():
		var box: Box = BOX_SCENE.instantiate()
		box.position = Vector3(box_position.x, 0.0, box_position.y)
		box.selected.connect(on_box_selected.bind(box))
		box.unselected.connect(on_box_unselected)
		box.move_finished.connect(_update_pushable_hint)
		boxes_container.add_child(box)

	var player_position := get_player_position()
	player.position = Vector3(player_position.x, 0.0, player_position.y)
	player.set_facing(get_player_direction())

	_update_pushable_hint()


func _update_pushable_hint() -> void:
	if not pushable_hint:
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
	_build_waypoints(box.grid_position())


func on_box_unselected() -> void:
	_selected_box = null
	_clear_waypoints()


func deselect_box() -> void:
	if _selected_box != null:
		var selected_box := _selected_box
		_selected_box = null
		selected_box.deselect()
	_clear_waypoints()


func _build_waypoints(from: Vector2i) -> void:
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


func _on_player_moved(to: Vector2i, pushed: bool) -> void:
	# Skip animation if instant is enabled
	if _is_instant:
		return

	var from := Vector2i(round(player.global_position.x), round(player.global_position.z))
	player.move(to - from, pushed)
	update_ui()


func update_ui() -> void:
	var status: Dictionary = get_status()

	# Update HUD labels
	gameplay.moves_label.text = str(status["move_count"])
	gameplay.pushes_label.text = str(status["push_count"])

	_update_pushable_hint()

	if _solving:
		gameplay.undo_button.disabled = true
		gameplay.redo_button.disabled = true
		gameplay.undo_all_button.disabled = true
		gameplay.solve_button.disabled = false
		gameplay.transform_button.disabled = true

		if _solve_tween == null:
			_solve_tween = create_tween().set_loops()
			_solve_tween.tween_property(gameplay.solve_button, "modulate", Color(0.5, 0.8, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			_solve_tween.tween_property(gameplay.solve_button, "modulate", Color(0.0, 0.567, 0.823, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	else:
		if _solve_tween:
			_solve_tween.kill()
			_solve_tween = null

		if player.is_moving or _is_box_moving():
			gameplay.undo_button.disabled = true
			gameplay.redo_button.disabled = true
			gameplay.undo_all_button.disabled = true
			gameplay.solve_button.disabled = true
			gameplay.transform_button.disabled = true
		else:
			gameplay.undo_button.disabled = !status["can_undo"]
			gameplay.redo_button.disabled = !status["can_redo"]
			gameplay.undo_all_button.disabled = !status["can_undo"]
			gameplay.solve_button.disabled = false
			gameplay.transform_button.disabled = false


func _on_solved() -> void:
	enter_goal_player.stop()


func reset_camera_position() -> void:
	var center := get_dimensions() / 2.0
	var max_dimension = max(get_dimensions().x, get_dimensions().y)
	camera._target_position = Vector3(center.x, max_dimension, center.y)
	camera.global_position = camera._target_position
	camera.zoom_factor = max_dimension + 1.0
