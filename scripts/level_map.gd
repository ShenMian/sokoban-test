extends LevelMap

@onready var camera: Camera3D = $"../Camera"
@onready var player: Player = $Player

const BOX = preload("uid://bslwjbitr74ja")

enum Direction {
	Up = 0,
	Down = 1,
	Left = 2,
	Right = 3
}


func _ready():
	Settings.setting_changed.connect(_on_setting_changed)
	self.solved.connect(_on_solved)

	# self.load_from_string("DuLLrUUdrR");
	self.load_from_string("rRRddrruULuullllDDldRuuurrrrddLLLrrruulllldDDurDurrrrruLdllllluurrrrDrdLLLLrrddrUruululllldDldRurrrdrruLLLLrrruulllldD");

	camera.global_position.x = self.dimensions().x / 2.0
	camera.global_position.z = self.dimensions().y / 2.0


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "deadlock":
		self.set_show_deadlocks(value)


func _on_solved():
	print("Level Solved!")
