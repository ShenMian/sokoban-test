extends CenterContainer

@onready var binding_popup: Control = $"../../../../BindingPopup"

@onready var up_button: Button = $VBox/GridContainer/UpButton
@onready var down_button: Button = $VBox/GridContainer/DownButton
@onready var left_button: Button = $VBox/GridContainer/LeftButton
@onready var right_button: Button = $VBox/GridContainer/RightButton


func _ready():
	apply_settings()

	up_button.pressed.connect(_on_button_pressed.bind("move_up"))
	down_button.pressed.connect(_on_button_pressed.bind("move_down"))
	left_button.pressed.connect(_on_button_pressed.bind("move_left"))
	right_button.pressed.connect(_on_button_pressed.bind("move_right"))

	binding_popup.closed.connect(apply_settings)


func apply_settings():
	up_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_up"))
	down_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_down"))
	left_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_left"))
	right_button.icon = _get_icon_by_key_name(_get_key_name_by_action("move_right"))


func _on_button_pressed(action: StringName):
	binding_popup.open(action)


func _get_key_name_by_action(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode != 0:
				return OS.get_keycode_string(key_event.physical_keycode)
			if key_event.keycode != 0:
				return OS.get_keycode_string(key_event.keycode)
			return key_event.as_text()
	return ""


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
