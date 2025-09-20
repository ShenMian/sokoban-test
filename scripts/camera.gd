extends Camera3D

@onready var settings_menu: Control = $"../MenuLayer/SettingsMenu"

@export var drag_sensitivity = 1
@export var zoom_sensitivity = 0.5
@export var smooth_factor = 15.0

var _is_dragging = false
var _target_position: Vector3
var _target_size: float = 10.0


func _ready():
	_target_position = global_position
	
	settings_menu.fov_changed.connect(self.set_fov)


func _process(delta):
	if abs(self.size - _target_size) > 0.001:
		self.size = lerp(self.size, _target_size, smooth_factor * delta)
	else:
		self.size = _target_size


func _physics_process(delta: float):
	if global_position.distance_to(_target_position) > 0.001:
		global_position = lerp(global_position, _target_position, smooth_factor * delta)
	else:
		global_position = _target_position


func _input(event):
	# FIXME: DEBUG
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if self.is_3d_view():
				switch_to_2d()
			else:
				switch_to_3d()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
		elif self.is_3d_view():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_position.y -= zoom_sensitivity
				_target_position.y = max(_target_position.y, 2.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_position.y += zoom_sensitivity
		else:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_size -= 1.0
				_target_size = max(_target_size, 1.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_size += 1.0
	elif event is InputEventMouseMotion and _is_dragging:
		_target_position.x -= event.relative.x * drag_sensitivity * 0.01
		_target_position.z -= event.relative.y * drag_sensitivity * 0.01


func is_3d_view() -> bool:
	return self.projection == PROJECTION_PERSPECTIVE


func switch_to_3d():
	self.projection = PROJECTION_PERSPECTIVE


func switch_to_2d():
	self.projection = PROJECTION_ORTHOGONAL
	self.size = 10.0
	_target_size = 10.0
