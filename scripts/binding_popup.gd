extends Control

signal closed

@onready var title_label: Label = $VBox/TitleLabel
@onready var texture_rect: TextureRect = $VBox/TextureRect

@onready var cancel_button: ButtonFx = $VBox/ColorRect/HBox/CancelButton
@onready var clear_button: ButtonFx = $VBox/ColorRect/HBox/ClearButton
@onready var confirm_button: ButtonFx = $VBox/ColorRect/HBox/ConfirmButton

@onready var cancel_hint_button: ButtonFx = $CancelButton

var _action: StringName
var _new_event: InputEvent
var _clear_event := false


func open(action: StringName):
	_action = action
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
	_clear_event = true


func _on_confirm_pressed():
	if _clear_event:
		InputMap.action_erase_events(_action)
	else:
		InputMap.action_erase_events(_action)
		InputMap.action_add_event(_action, _new_event)
	close()


func _input(event):
	assert(_action != "")

	if event.is_released():
		return

	if event is InputEventKey and event.pressed:
		_new_event = event as InputEventKey
		_clear_event = false
		texture_rect.texture = _get_icon_by_key_name(OS.get_keycode_string(_new_event.physical_keycode))


func _get_icon_by_key_name(key: String) -> Texture2D:
	if key == "":
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
	var path := "res://assets/textures/input_prompts/Keyboard & Mouse/Vector/keyboard_%s.svg" % key.to_lower()
	return load(path) as Texture2D


func _get_key_name_by_action(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey

			var label := ""
			if key_event.physical_keycode != 0:
				label = OS.get_keycode_string(key_event.physical_keycode)
			elif key_event.keycode != 0:
				label = OS.get_keycode_string(key_event.keycode)
			else:
				label = key_event.as_text()
			assert(label != "")

			return label
	return ""
