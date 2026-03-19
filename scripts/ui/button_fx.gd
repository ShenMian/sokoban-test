extends Button
class_name ButtonFx

@export var smooth_factor: float = 20.0

var _target_scale := Vector2.ONE


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)
	focus_entered.connect(_on_hovered)
	focus_exited.connect(_on_unhovered)


func _process(delta: float) -> void:
	if disabled:
		_reset()
		return
	pivot_offset_ratio = Vector2.ONE / 2.0
	scale = lerp(scale, _target_scale, delta * smooth_factor)


func _on_pressed() -> void:
	Sounds.play_button_press()


func _on_hovered() -> void:
	if disabled:
		return
	_target_scale = Vector2.ONE * 1.1
	Sounds.play_button_hover()


func _on_unhovered() -> void:
	if disabled:
		return
	_target_scale = Vector2.ONE


func _reset() -> void:
	scale = Vector2.ONE
	_target_scale = Vector2.ONE
