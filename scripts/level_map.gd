extends LevelMap

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player
@onready var waypoints_container: Node3D = $Waypoints

@onready var moves: Label = $"../HudLayer/HUD/ScoreboardPanel/HBoxContainer/MovesVBox/Value"
@onready var pushes: Label = $"../HudLayer/HUD/ScoreboardPanel/HBoxContainer/PushesVBox/Value"

enum Direction {
	Up = 0,
	Down = 1,
	Left = 2,
	Right = 3
}


func _ready():
	Settings.setting_changed.connect(_on_setting_changed)
	self.player_moved.connect(_on_player_moved)
	self.solved.connect(_on_solved)

	if Settings.current_collection != null && Settings.current_level_index != null:
		var full_path := ProjectSettings.globalize_path(Settings.LEVEL_PATH + Settings.current_collection + ".xsb")
		self.load_from_file(full_path, Settings.current_level_index + 1)
	else:
		self.load_from_string("r2R2d2ruUL2u4l2DldR3u4r2d3L3r2u4ld2DurDu5ruLd5l2u4rDrd4L2r2drUr2ulu4ldDldRu3rd2ru4L3r2u4ldD")

	_reset_camera_position()

	await get_tree().process_frame
	self.update_pushable_hint()


func _process(_delta: float):
	if not player.is_moving:
		if Input.is_action_pressed("move_right"):
			self.move_by(Direction.Right)
		elif Input.is_action_pressed("move_left"):
			self.move_by(Direction.Left)
		elif Input.is_action_pressed("move_up"):
			self.move_by(Direction.Up)
		elif Input.is_action_pressed("move_down"):
			self.move_by(Direction.Down)


func _input(_event: InputEvent):
	if Input.is_action_just_pressed("import_from_clipboard"):
		self.load_from_string(DisplayServer.clipboard_get())
		self.update_pushable_hint()
		_reset_camera_position()
	if Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(self.get_map())


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player.is_moving:
			get_viewport().set_input_as_handled()
			return

		var space_state = get_world_3d().direct_space_state
		var ray_origin = camera.project_ray_origin(event.position)
		var ray_end = ray_origin + camera.project_ray_normal(event.position) * 1000.0
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		query.collide_with_bodies = false

		# Checks if the click was on an empty space (without Area3D)
		if space_state.intersect_ray(query).is_empty():
			self.deselect_box()


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "deadlock_hint":
		self.deadlock_hint = value
	if section == "gameplay" and key == "checkerboard":
		self.checkerboard_shading = value
	if section == "gameplay" and key == "pathfinding_strategy":
		self.pathfinding_strategy = value
	if section == "gameplay" and key == "pushable_hint":
		self.pushable_hint = value


func _on_player_moved(_to: Vector2, pushed: bool):
	moves.text = str(int(moves.text) + 1);
	if pushed:
		pushes.text = str(int(pushes.text) + 1);


func _on_solved():
	print("Level solved!")
	Settings.set_level_solution(Settings.current_collection, Settings.current_level_index, self.get_actions())


func _reset_camera_position():
	var center = self.dimensions() / 2.0
	camera.global_position.x = center.x
	camera.global_position.z = center.y


func on_waypoint_clicked(box_position: Vector2i, waypoint_position: Vector2i):
	self.deselect_box()

	var directions = self.box_move_path(box_position, waypoint_position)
	for direction in directions:
		if self.is_solved():
			break
		self.move_by(direction)
		await player.move_finished
