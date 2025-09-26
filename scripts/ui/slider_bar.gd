extends Control
class_name SliderBar

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $ProgressBar/Label

@export var disabled: bool = false:
	set(disabled):
		if disabled:
			self.editable = false
			self.modulate = Color.GRAY * 0.8
		else:
			self.editable = true
			self.modulate = Color.WHITE


func _ready():
	self.value_changed.connect(_on_value_changed)
	progress_bar.min_value = self.min_value
	progress_bar.max_value = self.max_value
	progress_bar.step = self.step
	progress_bar.value = self.value
	label.text = str(int(round(progress_bar.value)))


func _on_value_changed(value: float):
	progress_bar.value = value
	if self.min_value == 0.0 and self.max_value == 1.0:
		label.text = str(int(round(value * 100))) + "%"
	else:
		label.text = str(int(round(value)))
