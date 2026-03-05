extends LevelMap

enum Direction {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3
}

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player
@onready var waypoints_container: Node3D = $Waypoints
@onready var moves: Label = $"../HudLayer/HUD/ScoreboardPanel/HBox/MovesVBox/MovesValue"
@onready var pushes: Label = $"../HudLayer/HUD/ScoreboardPanel/HBox/PushesVBox/PushesValue"


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)

	assert(SceneTransition.collection != null and SceneTransition.level_index != null)
	var full_path := ProjectSettings.globalize_path(Settings.LEVEL_PATH + SceneTransition.collection + ".xsb")
	load_from_file(full_path, SceneTransition.level_index + 1)

	_reset_camera_position()

	await get_tree().process_frame
	update_pushable_hint()


func _process(_delta: float) -> void:
	if not player.is_moving:
		if Input.is_action_pressed("move_right"):
			move_by(Direction.RIGHT)
		elif Input.is_action_pressed("move_left"):
			move_by(Direction.LEFT)
		elif Input.is_action_pressed("move_up"):
			move_by(Direction.UP)
		elif Input.is_action_pressed("move_down"):
			move_by(Direction.DOWN)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		load_from_string(DisplayServer.clipboard_get())
		update_pushable_hint()
		_reset_camera_position()
	if Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(get_map())


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


func on_waypoint_clicked(box_position: Vector2i, waypoint_position: Vector2i) -> void:
	deselect_box()

	var directions := box_move_path(box_position, waypoint_position)
	for direction in directions:
		if is_solved():
			break
		move_by(direction)
		await player.move_finished


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay" and key == "deadlock_hint":
		deadlock_hint = value
	if section == "gameplay" and key == "checkerboard":
		checkerboard_shading = value
	if section == "gameplay" and key == "pathfinding_strategy":
		pathfinding_strategy = value
	if section == "gameplay" and key == "pushable_hint":
		pushable_hint = value


func _on_player_moved(_to: Vector2, pushed: bool) -> void:
	moves.text = str(int(moves.text) + 1)
	if pushed:
		pushes.text = str(int(pushes.text) + 1)


func _on_solved() -> void:
	print("Level solved!")
	Settings.set_level_solution(SceneTransition.collection, SceneTransition.level_index, get_actions())


func _reset_camera_position() -> void:
	var center := dimensions() / 2.0
	camera._target_position.x = center.x
	camera._target_position.z = center.y
	camera.global_position.x = center.x
	camera.global_position.z = center.y
