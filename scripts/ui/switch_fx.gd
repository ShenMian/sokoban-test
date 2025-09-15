extends CheckButton
class_name SwitchFx

@onready var press_audio: AudioStreamPlayer = Sounds.get_node("SwitchPressAudio")
@onready var hover_audio: AudioStreamPlayer = Sounds.get_node("SwitchHoverAudio")


func _ready():
	self.pressed.connect(press_audio.play)
	self.mouse_entered.connect(hover_audio.play)
