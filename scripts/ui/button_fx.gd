extends Button
class_name ButtonFx

@onready var press_audio: AudioStreamPlayer = Sounds.get_node("ButtonPressAudio")
@onready var hover_audio: AudioStreamPlayer = Sounds.get_node("ButtonHoverAudio")

@export var smooth_factor = 20.0

var _target_scale: Vector2 = Vector2.ONE


func _ready():
	self.pressed.connect(_on_pressed)
	self.mouse_entered.connect(_on_hovered)
	self.mouse_exited.connect(_on_unhovered)
	self.focus_entered.connect(_on_hovered)
	self.focus_exited.connect(_on_unhovered)


func _process(delta: float):
	self.pivot_offset = self.size / 2
	self.scale = lerp(self.scale, _target_scale, delta * smooth_factor)


func _on_pressed():
	press_audio.play()


func _on_hovered():
	_target_scale = Vector2.ONE * 1.1
	hover_audio.play()


func _on_unhovered():
	_target_scale = Vector2.ONE
