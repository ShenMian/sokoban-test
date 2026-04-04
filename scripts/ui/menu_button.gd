extends MenuButton

signal undo_all
signal redo_all

@export var shortcuts: Array[Shortcut] = []


func _ready() -> void:
	var popup = get_popup()
	for idx in range(shortcuts.size()):
		popup.set_item_shortcut(idx, shortcuts[idx])
		popup.id_pressed.connect(_on_item_pressed)


func _on_item_pressed(id: int) -> void:
	Sounds.play_button_press()
	match id:
		0:
			undo_all.emit()
		1:
			redo_all.emit()
