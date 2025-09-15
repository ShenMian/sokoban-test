extends Control

@onready var background: ColorRect = $Background
@onready var tab_container: TabContainer = $MarginContainer/VBox/TabContainer


func _ready() -> void:
	tab_container.tab_changed.connect(_on_active_tab_changed)


func _on_active_tab_changed(index: int):
	if index == 1:
		background.color.a = 0.0
	else:
		background.color.a = 1.0
