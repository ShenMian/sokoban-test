extends CheckButton
class_name SwitchFx


func _ready():
	self.pressed.connect(Sounds.play_switch_press)
	self.mouse_entered.connect(Sounds.play_switch_hover)
