extends LevelMap

@onready var camera: Camera3D = $"../Camera"


func _ready() -> void:
	# self.load_from_string("DuLLrUUdrR");
	self.load_from_string("rRRddrruULuullllDDldRuuurrrrddLLLrrruulllldDDurDurrrrruLdllllluurrrrDrdLLLLrrddrUruululllldDldRurrrdrruLLLLrrruulllldD");
	camera.global_position.x = self.dimensions().x / 2.0
	camera.global_position.z = self.dimensions().y / 2.0
