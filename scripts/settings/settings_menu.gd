extends Control

signal fov_changed(fov: float)
signal closed

@onready var background: TextureRect = $Background
@onready var tab_container: TabContainer = $MarginContainer/VBox/TabContainer
@onready var close_button: ButtonFx = $CloseButton

@onready var field_of_view: SliderBar = $MarginContainer/VBox/Tabs/VIDEO/VBox/FieldOfViewPanel/Margin/HBox/SliderBar


func open():
	show()


func close():
	hide()
	closed.emit()


func _ready() -> void:
	tab_container.tab_changed.connect(_on_active_tab_changed)
	close_button.pressed.connect(_on_close_pressed)

	field_of_view.value_changed.connect(_on_field_of_view_changed)
	field_of_view.value = Settings.get_value("video", "fov")


func _input(_event: InputEvent):
	if not self.visible:
		return
	if Input.is_action_just_released("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_active_tab_changed(index: int):
	if tab_container.get_tab_title(index) == "VIDEO":
		background.visible = false
	else:
		background.visible = true


func _on_field_of_view_changed(fov: float):
	fov_changed.emit(fov)
	Settings.set_value("video", "fov", fov)


func _on_close_pressed():
	close()
