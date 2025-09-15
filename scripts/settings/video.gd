extends CenterContainer

@onready var window_mode: OptionButton = $VBox/WindowModePanel/Margin/HBox/OptionButton
@onready var vsync: CheckButton = $VBox/VsyncPanel/Margin/HBox/CheckButton

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

	vsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	
	window_mode.item_selected.connect(_on_window_mode_selected)
	vsync.toggled.connect(_on_vsync_toggled)
	
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
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_screen_space_aa_item_selected(index: int):
	var value: Viewport.ScreenSpaceAA
	match index:
		0:
			value = Viewport.SCREEN_SPACE_AA_DISABLED
		1:
			value = Viewport.SCREEN_SPACE_AA_SMAA
		2:
			value = Viewport.SCREEN_SPACE_AA_FXAA
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", value)


func _on_msaa_item_selected(index: int):
	var value: int
	match index:
		0:
			value = 0
		1:
			value = 2
		2:
			value = 4
		3:
			value = 8
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", value)


func _on_taa_toggled(toggled_on: bool):
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_taa", toggled_on)
