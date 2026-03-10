extends Camera3D

@export var drag_sensitivity: float = 1.5
@export var zoom_sensitivity: float = 1.0
@export var smooth_factor: float = 15.0

var zoom_factor: float:
	set(value):
		zoom_factor = value
		if self.is_3d_view():
			_target_position.y = zoom_factor / (2.0 * tan(deg_to_rad(fov) / 2.0))
		else:
			_target_size = zoom_factor

var _is_dragging = false
var _target_position: Vector3
var _target_size: float = 10.0


func _ready():
	Settings.setting_changed.connect(_on_setting_changed)
	_target_position = global_position

	_on_setting_changed("gameplay", "2d_view", Settings.get_value("gameplay", "2d_view"))


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "video" and key == "fov":
		set_fov(value)
	elif section == "gameplay" and key == "2d_view":
		if value:
			projection = PROJECTION_ORTHOGONAL
			self.zoom_factor = zoom_factor
			size = _target_size
		else:
			projection = PROJECTION_PERSPECTIVE
			self.zoom_factor = zoom_factor
			global_position = _target_position


func _process(delta: float):
	if abs(self.size - _target_size) > 0.001:
		size = lerp(size, _target_size, smooth_factor * delta)
	else:
		size = _target_size

	if global_position.distance_to(_target_position) > 0.001:
		global_position = lerp(global_position, _target_position, smooth_factor * delta)
	else:
		global_position = _target_position


func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
	elif event is InputEventMouseMotion and _is_dragging:
		_target_position.x -= event.relative.x * drag_sensitivity * zoom_factor * 0.001
		_target_position.z -= event.relative.y * drag_sensitivity * zoom_factor * 0.001


func zoom_in():
	zoom_factor -= zoom_sensitivity
	zoom_factor = max(zoom_factor, 2.0)


func zoom_out():
	zoom_factor += zoom_sensitivity


func is_3d_view() -> bool:
	return projection == PROJECTION_PERSPECTIVE
