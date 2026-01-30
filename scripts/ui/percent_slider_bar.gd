extends SliderBar
class_name PercentSliderBar


func _on_value_changed(value: float):
	progress_bar.value = value
	label.text = str(int(round(value * 100))) + "%"
