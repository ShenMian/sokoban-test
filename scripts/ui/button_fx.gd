extends Button
class_name ButtonFx

@onready var press_audio: AudioStreamPlayer = Sounds.get_node("ButtonPressAudio")
@onready var hover_audio: AudioStreamPlayer = Sounds.get_node("ButtonHoverAudio")


func _ready():
	self.pressed.connect(_on_pressed)
	self.mouse_entered.connect(_on_hovered)
	self.mouse_exited.connect(_on_unhovered)
	self.focus_entered.connect(_on_hovered)
	self.focus_exited.connect(_on_unhovered)


func _on_pressed():
	press_audio.play()


func _on_hovered():
	self.pivot_offset = self.size / 2
	self.scale = Vector2.ONE * 1.1
	hover_audio.play()


func _on_unhovered():
	self.scale = Vector2.ONE
