extends CheckButton
class_name SwitchFx


func _ready():
	pressed.connect(Sounds.play_switch_press)
	mouse_entered.connect(Sounds.play_switch_hover)
