extends CenterContainer

@onready var binding_popup: BindingPopup = $"../../../../BindingPopup"

@onready var action_buttons := {
	"move_up": $VBox/GridContainer/UpButton,
	"move_down": $VBox/GridContainer/DownButton,
	"move_left": $VBox/GridContainer/LeftButton,
	"move_right": $VBox/GridContainer/RightButton,
}


func _ready():
	apply_settings()

	for action in action_buttons:
		action_buttons[action].pressed.connect(_on_button_pressed.bind(action))

	binding_popup.closed.connect(apply_settings)


func apply_settings():
	for action in action_buttons:
		action_buttons[action].icon = _get_icon_by_key_name(_get_key_name_by_action(action))


func _on_button_pressed(action: StringName):
	binding_popup.open(action)


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
