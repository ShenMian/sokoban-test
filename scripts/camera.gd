extends Camera3D

@export var drag_sensitivity = 1
@export var zoom_sensitivity = 0.5
@export var smooth_factor = 15.0

var is_dragging = false
var last_mouse_position = Vector2.ZERO
var target_position: Vector3 # 目标位置

func _ready():
	target_position = global_position

func _process(delta):
	if global_position.distance_to(target_position) > 0.001:
		global_position = global_position.lerp(target_position, smooth_factor * delta)
	else:
		global_position = target_position

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				last_mouse_position = event.position
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_position.y -= zoom_sensitivity
			target_position.y = max(target_position.y, 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_position.y += zoom_sensitivity
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_delta = event.position - last_mouse_position
		last_mouse_position = event.position

		target_position.x -= mouse_delta.x * drag_sensitivity * 0.01
		target_position.z -= mouse_delta.y * drag_sensitivity * 0.01
