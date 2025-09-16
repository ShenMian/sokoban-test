extends Control

signal closed

@onready var background: TextureRect = $Background
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
	if tab_container.get_tab_title(index) == "Video":
		background.visible = false
	else:
		background.visible = true


func _on_close_pressed():
	close()
