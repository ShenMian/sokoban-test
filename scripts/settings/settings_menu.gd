extends Control

signal closed

@onready var background: ColorRect = $Background
@onready var tab_container: TabContainer = $MarginContainer/VBox/TabContainer
@onready var close_button: Button = $CloseButton


func open():
	show()


func close():
	hide()
	closed.emit()


func _ready() -> void:
	tab_container.tab_changed.connect(_on_active_tab_changed)
	close_button.pressed.connect(_on_close_pressed)


func _input(_event: InputEvent):
	if not self.visible:
		return
	if Input.is_action_just_released("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_active_tab_changed(index: int):
	if index == 1:
		background.color.a = 0.0
	else:
		background.color.a = 1.0


func _on_close_pressed():
	close()
