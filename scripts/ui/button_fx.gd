extends Button
class_name ButtonFx

@export var smooth_factor = 20.0

var _target_scale: Vector2 = Vector2.ONE


func _ready():
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)
	focus_entered.connect(_on_hovered)
	focus_exited.connect(_on_unhovered)


func _process(delta: float):
	pivot_offset_ratio = Vector2.ONE / 2
	scale = lerp(scale, _target_scale, delta * smooth_factor)


func _on_pressed():
	Sounds.play_button_press()


func _on_hovered():
	_target_scale = Vector2.ONE * 1.1
	Sounds.play_button_hover()


func _on_unhovered():
	_target_scale = Vector2.ONE
