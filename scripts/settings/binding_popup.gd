extends Control
class_name BindingPopup

signal closed

@onready var title_label: Label = $VBox/TitleLabel
@onready var texture_rect: TextureRect = $VBox/TextureRect

@onready var cancel_button: ButtonFx = $VBox/ColorRect/HBox/CancelButton
@onready var clear_button: ButtonFx = $VBox/ColorRect/HBox/ClearButton
@onready var confirm_button: ButtonFx = $VBox/ColorRect/HBox/ConfirmButton

@onready var cancel_hint_button: ButtonFx = $CancelButton

var _action: StringName
var _new_event: InputEvent = null


func open(action: StringName):
	_action = action
	_new_event = null
	title_label.text = action.to_upper()
	texture_rect.texture = _get_icon_by_key_name(_get_key_name_by_action(action))
	show()
	set_process_input(true)


func close():
	self.hide()
	closed.emit()


func _ready():
	set_process_input(false)

	cancel_button.pressed.connect(close)
	cancel_hint_button.pressed.connect(close)

	clear_button.pressed.connect(_on_clear_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


func _on_clear_pressed():
	texture_rect.texture = null
	_new_event = null


func _on_confirm_pressed():
	InputMap.action_erase_events(_action)
	if _new_event != null:
		InputMap.action_add_event(_action, _new_event)
	close()


func _input(event):
	if event.is_released():
		return

	if event is InputEventKey and event.pressed:
		_new_event = event as InputEventKey
		texture_rect.texture = _get_icon_by_key_name(_get_key_name_by_event(_new_event))


func _get_key_name_by_action(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return _get_key_name_by_event(event as InputEventKey)
	return ""


func _get_key_name_by_event(event: InputEventKey) -> String:
	if event.physical_keycode != 0:
		return OS.get_keycode_string(event.physical_keycode)
	if event.keycode != 0:
		return OS.get_keycode_string(event.keycode)
	return event.as_text()


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
	var path := ICON_PATH + "keyboard_%s.svg" % key.to_lower()
	return load(path) as Texture2D
