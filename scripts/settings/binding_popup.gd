extends Control
class_name BindingPopup

signal closed

@onready var title_label: Label = $VBox/TitleLabel
@onready var icon_container: HBoxContainer = $VBox/HBox

@onready var cancel_button: ButtonFx = $VBox/ColorRect/HBox/CancelButton
@onready var clear_button: ButtonFx = $VBox/ColorRect/HBox/ClearButton
@onready var confirm_button: ButtonFx = $VBox/ColorRect/HBox/ConfirmButton

@onready var cancel_hint_button: ButtonFx = $CancelButton

var _action: StringName
var _new_event: InputEvent = null


func open(action: StringName) -> void:
	_action = action
	_new_event = null
	title_label.text = action.to_upper()
	_update_icons(_get_icons_by_event(_get_event_by_action(action)))
	show()
	set_process_input(true)


func close() -> void:
	hide()
	closed.emit()


func _ready() -> void:
	set_process_input(false)

	cancel_button.pressed.connect(close)
	cancel_hint_button.pressed.connect(close)

	clear_button.pressed.connect(_on_clear_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


func _on_clear_pressed() -> void:
	_update_icons([])
	_new_event = null


func _on_confirm_pressed() -> void:
	InputMap.action_erase_events(_action)
	if _new_event != null:
		InputMap.action_add_event(_action, _new_event)
	close()


func _input(event: InputEvent) -> void:
	if event.is_released():
		return

	if event is InputEventKey and event.pressed:
		_new_event = event as InputEventKey
		_update_icons(_get_icons_by_event(_new_event))


func _get_event_by_action(action: StringName) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _update_icons(icons: Array[Texture2D]) -> void:
	for child in icon_container.get_children():
		child.queue_free()

	for icon in icons:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon_container.add_child(rect)


func _get_icons_by_event(event: InputEventKey) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []

	if event.ctrl_pressed:
		icons.append(_get_icon_by_key_name("control"))
	if event.shift_pressed:
		icons.append(_get_icon_by_key_name("shift"))
	if event.alt_pressed:
		icons.append(_get_icon_by_key_name("alt"))
	if event.meta_pressed:
		icons.append(_get_icon_by_key_name("meta"))

	var key_name := OS.get_keycode_string(event.physical_keycode)
	icons.append(_get_icon_by_key_name(key_name.to_lower()))

	return icons


func _get_icon_by_key_name(key: String) -> Texture2D:
	assert(key == key.to_lower())

	if key.is_empty():
		return null

	match key:
		"up":
			key = "arrow_up"
		"down":
			key = "arrow_down"
		"left":
			key = "arrow_left"
		"right":
			key = "arrow_right"
		"control":
			key = "ctrl"
		"meta":
			key = "win"

	const ICON_PATH := "res://assets/textures/input_prompts/keyboard_mouse/"
	var path := ICON_PATH + "keyboard_%s.svg" % key
	return load(path) as Texture2D
