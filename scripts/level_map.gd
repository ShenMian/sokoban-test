extends LevelMap

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player

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
	self.player_move.connect(_on_player_move)
	self.solved.connect(_on_solved)

	# self.load_from_string("DuLLrUUdrR")
	self.load_from_string("r2R2d2ruUL2u4l2DldR3u4r2d3L3r2u4ld2DurDu5ruLd5l2u4rDrd4L2r2drUr2ulu4ldDldRu3rd2ru4L3r2u4ldD")

	_reset_camera_position()


func _input(_event: InputEvent):
	if Input.is_action_just_pressed("import_from_clipboard"):
		self.load_from_string(DisplayServer.clipboard_get())
	if Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(self.export_to_string())


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "deadlock":
		self.set_deadlock_hint(value)
	if section == "gameplay" and key == "checkerboard":
		self.set_checkerboard_shading(value)


func _on_player_move(_to: Vector2, is_pushing: bool):
	moves.text = str(int(moves.text) + 1);
	if is_pushing:
		pushes.text = str(int(pushes.text) + 1);


func _on_solved():
	print("Level solved!")


func _reset_camera_position():
	camera.global_position.x = self.dimensions().x / 2.0
	camera.global_position.z = self.dimensions().y / 2.0
