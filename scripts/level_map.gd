extends LevelMap

@onready var camera: Camera3D = $"../Camera"
@onready var settings_menu: Control = $"../MenuLayer/SettingsMenu"

const BOX = preload("uid://bslwjbitr74ja")


func _ready() -> void:
	settings_menu.deadlock_changed.connect(self.set_show_deadlocks)

	# self.load_from_string("DuLLrUUdrR");
	self.load_from_string("rRRddrruULuullllDDldRuuurrrrddLLLrrruulllldDDurDurrrrruLdllllluurrrrDrdLLLLrrddrUruululllldDldRurrrdrruLLLLrrruulllldD");

	camera.global_position.x = self.dimensions().x / 2.0
	camera.global_position.z = self.dimensions().y / 2.0
