extends Control
class_name SettingsMenu

signal closed

@onready var background: TextureRect = $Background
@onready var tabs: TabContainer = $MarginContainer/VBox/HSplit/Tabs
@onready var tooltip: RichTextLabel = $MarginContainer/VBox/HSplit/Margin/Tooltip
@onready var close_button: ButtonFx = $CloseButton
@onready var restore_button: ButtonFx = $RestoreButton

@onready var gameplay: ScrollContainer = $MarginContainer/VBox/HSplit/Tabs/GAMEPLAY
@onready var video: ScrollContainer = $MarginContainer/VBox/HSplit/Tabs/VIDEO
@onready var audio: ScrollContainer = $MarginContainer/VBox/HSplit/Tabs/AUDIO
@onready var input: ScrollContainer = $MarginContainer/VBox/HSplit/Tabs/INPUT

var _hovered_panel: Control = null
var _is_touch_scrolling: bool
var _scroll_touch_index: int = -1


func open() -> void:
	show()


func close() -> void:
	hide()
	closed.emit()


func _ready() -> void:
	tabs.tab_changed.connect(_on_active_tab_changed)
	tabs.gui_input.connect(_on_tabs_gui_input)
	close_button.pressed.connect(close)
	restore_button.pressed.connect(_on_restore_pressed)


func _on_active_tab_changed(index: int) -> void:
	Sounds.play_button_press()
	if tabs.get_tab_title(index) == "VIDEO":
		background.visible = false
	else:
		background.visible = true


func _on_restore_pressed() -> void:
	match tabs.get_tab_title(tabs.current_tab):
		"GAMEPLAY":
			Settings.reset_gameplay_settings()
			gameplay.apply_settings()
		"VIDEO":
			Settings.reset_video_settings()
			video.apply_settings()
		"AUDIO":
			Settings.reset_audio_settings()
			audio.apply_settings()
		"INPUT":
			Settings.reset_input_settings()
			input.apply_settings()


func _input(_event: InputEvent) -> void:
	if not visible:
		return
	_update_tooltip()


func _on_tabs_gui_input(input_event: InputEvent) -> void:
	if input_event is InputEventScreenTouch:
		var event := input_event as InputEventScreenTouch
		if event.pressed:
			_scroll_touch_index = event.index
			_is_touch_scrolling = false
		else:
			if event.index != _scroll_touch_index:
				return
			_scroll_touch_index = -1
	elif input_event is InputEventScreenDrag:
		var event := input_event as InputEventScreenDrag
		if event.index != _scroll_touch_index:
			return
		var scroll_container := tabs.get_current_tab_control()
		scroll_container.get_v_scroll_bar().value -= event.relative.y
		_is_touch_scrolling = true


func _update_tooltip() -> void:
	var active_tab := tabs.get_current_tab_control()

	var control_under_mouse := _find_control_at_point(active_tab, get_global_mouse_position())
	if control_under_mouse == _hovered_panel:
		return
	_hovered_panel = control_under_mouse

	var tooltip_control := _find_tooltip_control(_hovered_panel, active_tab)
	if tooltip_control:
		var title: String = tooltip_control.get_meta("title")
		var description: String = tooltip_control.get_meta("description")
		tooltip.text = (
			"[font_size=26][b][i]%s[/i][/b][/font_size]\n" +
			"[font_size=10]\n[/font_size]" +
			"%s"
		) % [tr(title), tr(description)]
	else:
		tooltip.text = ""


func _find_tooltip_control(control: Control, root: Control) -> Control:
	var current := control
	while current:
		if current.has_meta("title"):
			return current
		var parent := current.get_parent()
		if parent == root or not parent is Control:
			return null
		current = parent
	return null


func _find_control_at_point(parent: Control, point: Vector2) -> Control:
	var children := parent.get_children()
	# Reverse it in-place to check topmost nodes first
	children.reverse()

	for child in children:
		if not child is Control:
			continue
		var child_control := child as Control

		if child_control.get_global_rect().has_point(point):
			# This child is a candidate. Check if one of its children is a better candidate.
			var deeper_control := _find_control_at_point(child_control, point)
			# If we found a deeper child, that's our answer. Otherwise, this child is it.
			return deeper_control if deeper_control else child_control

	# No child at this level contains the point
	return null
