extends ScrollContainer

@onready var binding_popup: BindingPopup = $"../../../../../BindingPopup"

@onready var action_buttons := {
	"move_up": $Margin/VBox/GridContainer/UpButton,
	"move_down": $Margin/VBox/GridContainer/DownButton,
	"move_left": $Margin/VBox/GridContainer/LeftButton,
	"move_right": $Margin/VBox/GridContainer/RightButton,
	"undo": $Margin/VBox/GridContainer/UndoButton,
	"redo": $Margin/VBox/GridContainer/RedoButton,
	"undo_all": $Margin/VBox/GridContainer/UndoAllButton,
}


func _ready() -> void:
	apply_settings()

	for action in action_buttons:
		action_buttons[action].pressed.connect(_on_button_pressed.bind(action))

	binding_popup.closed.connect(_on_binding_popup_closed)


func _on_binding_popup_closed() -> void:
	apply_settings()
	Settings.save_input_bindings()


func apply_settings() -> void:
	for action in action_buttons:
		var button: Button = action_buttons[action]
		var event := _get_event_by_action(action)
		_update_button_icons(button, _get_icons_by_event(event))


func _on_button_pressed(action: StringName) -> void:
	binding_popup.open(action)


func _get_event_by_action(action: StringName) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _get_icons_by_event(event: InputEventKey) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []

	if event.ctrl_pressed:
		icons.append(_get_icon_by_key_name("Control"))
	if event.shift_pressed:
		icons.append(_get_icon_by_key_name("Shift"))
	if event.alt_pressed:
		icons.append(_get_icon_by_key_name("Alt"))
	if event.meta_pressed:
		icons.append(_get_icon_by_key_name("Meta"))

	var key_name := OS.get_keycode_string(event.physical_keycode)
	icons.append(_get_icon_by_key_name(key_name))

	return icons


func _update_button_icons(button: Button, icons: Array[Texture2D]) -> void:
	var icon_container := button.get_node("HBox")
	for child in icon_container.get_children():
		child.queue_free()

	for icon in icons:
		var rect := TextureRect.new()
		rect.texture = icon
		icon_container.add_child(rect)


func _get_icon_by_key_name(key: String) -> Texture2D:
	const ICON_PATH := "res://assets/textures/input_prompts/Keyboard & Mouse/Vector/"

	if key.is_empty():
		return null

	match key:
		"Up":
			key = "arrow_up"
		"Down":
			key = "arrow_down"
		"Left":
			key = "arrow_left"
		"Right":
			key = "arrow_right"
		"Control":
			key = "ctrl"
		"Meta":
			key = "win"

	var path := ICON_PATH + "keyboard_%s.svg" % key.to_lower()
	return load(path) as Texture2D
