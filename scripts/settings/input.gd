extends CenterContainer

@onready var up_button: Button = $VBox/GridContainer/UpButton
@onready var down_button: Button = $VBox/GridContainer/DownButton
@onready var left_button: Button = $VBox/GridContainer/LeftButton
@onready var right_button: Button = $VBox/GridContainer/RightButton

var _rebinding_action: StringName


func _ready():
	set_process_input(false)
	apply_settings()
	
	up_button.pressed.connect(_on_button_pressed.bind("move_up", up_button))
	down_button.pressed.connect(_on_button_pressed.bind("move_down", down_button))
	left_button.pressed.connect(_on_button_pressed.bind("move_left", left_button))
	right_button.pressed.connect(_on_button_pressed.bind("move_right", right_button))


func apply_settings():
	up_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_up"))
	down_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_down"))
	left_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_left"))
	right_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_right"))


func _on_button_pressed(action: StringName, button: Button):
	_rebinding_action = action
	button.icon = _get_icon_by_key_name(_get_key_name_by_action(_rebinding_action) + "_outline")
	set_process_input(true)


func _input(event):
	assert(_rebinding_action != "")

	if event.is_released():
		return
	set_process_input(false)

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		pass
	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		InputMap.action_erase_events(_rebinding_action)
		InputMap.action_add_event(_rebinding_action, key_event)

	_rebinding_action = ""
	apply_settings()
	get_viewport().set_input_as_handled()


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
