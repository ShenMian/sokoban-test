extends CenterContainer

@onready var window_mode: OptionButton = $VBox/WindowModePanel/Margin/HBox/OptionButton
@onready var vsync: CheckButton = $VBox/VsyncPanel/Margin/HBox/CheckButton
@onready var frame_rate_limit: SliderBar = $VBox/FrameRateLimitPanel/Margin/HBox/SliderBar

@onready var screen_space_aa: OptionButton = $VBox/ScreenSpaceAAPanel/Margin/HBox/OptionButton
@onready var msaa: OptionButton = $VBox/MsaaPanel/Margin/HBox/OptionButton
@onready var taa: CheckButton = $VBox/TaaPanel/Margin/HBox/CheckButton


func _ready():
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_WINDOWED:
			window_mode.selected = 0
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode.selected = 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode.selected = 2
		_:
			window_mode.selected = -1

	if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED:
		frame_rate_limit.disabled = true
		vsync.button_pressed = true
	else:
		frame_rate_limit.disabled = false
		vsync.button_pressed = false

	frame_rate_limit.value = Engine.max_fps
	_on_frame_rate_limit_value_changed(Engine.max_fps)

	window_mode.item_selected.connect(_on_window_mode_selected)
	vsync.toggled.connect(_on_vsync_toggled)
	frame_rate_limit.value_changed.connect(_on_frame_rate_limit_value_changed)

	match get_viewport().screen_space_aa:
		Viewport.SCREEN_SPACE_AA_DISABLED:
			screen_space_aa.selected = 0
		Viewport.SCREEN_SPACE_AA_SMAA:
			screen_space_aa.selected = 1
		Viewport.SCREEN_SPACE_AA_FXAA:
			screen_space_aa.selected = 2
	match get_viewport().msaa_3d:
		0:
			msaa.selected = 0
		2:
			msaa.selected = 1
		4:
			msaa.selected = 2
		8:
			msaa.selected = 3
	taa.button_pressed = get_viewport().use_taa

	screen_space_aa.item_selected.connect(_on_screen_space_aa_item_selected)
	msaa.item_selected.connect(_on_msaa_item_selected)
	taa.toggled.connect(_on_taa_toggled)


func _on_window_mode_selected(index: int):
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _on_vsync_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		frame_rate_limit.disabled = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		frame_rate_limit.disabled = false


func _on_frame_rate_limit_value_changed(value: float):
	if value == 0 || value == frame_rate_limit.max_value:
		frame_rate_limit.value = frame_rate_limit.max_value
		frame_rate_limit.label.text = "UNLIMITED"
		Engine.max_fps = 0
	else:
		Engine.max_fps = int(value)


func _on_screen_space_aa_item_selected(index: int):
	var value: Viewport.ScreenSpaceAA
	match index:
		0:
			value = Viewport.SCREEN_SPACE_AA_DISABLED
		1:
			value = Viewport.SCREEN_SPACE_AA_SMAA
		2:
			value = Viewport.SCREEN_SPACE_AA_FXAA
	get_viewport().screen_space_aa = value


func _on_msaa_item_selected(index: int):
	var value: Viewport.MSAA
	match index:
		0:
			value = Viewport.MSAA_DISABLED
		1:
			value = Viewport.MSAA_2X
		2:
			value = Viewport.MSAA_4X
		3:
			value = Viewport.MSAA_8X
	get_viewport().msaa_3d = value


func _on_taa_toggled(toggled_on: bool):
	get_viewport().use_taa = toggled_on
