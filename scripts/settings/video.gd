extends ScrollContainer

@onready var window_mode: OptionButton = $VBox/WindowModePanel/Margin/HBox/OptionButton
@onready var vsync: CheckButton = $VBox/VsyncPanel/Margin/HBox/CheckButton
@onready var frame_rate_limit: SliderBar = $VBox/FrameRateLimitPanel/Margin/HBox/SliderBar

@onready var screen_space_aa: OptionButton = $VBox/ScreenSpaceAAPanel/Margin/HBox/OptionButton
@onready var msaa: OptionButton = $VBox/MsaaPanel/Margin/HBox/OptionButton
@onready var taa: CheckButton = $VBox/TaaPanel/Margin/HBox/CheckButton

const WINDOW_MODE_TO_INDEX = {
	DisplayServer.WINDOW_MODE_WINDOWED: 0,
	DisplayServer.WINDOW_MODE_FULLSCREEN: 1,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: 2
}
var INDEX_TO_WINDOW_MODE = WINDOW_MODE_TO_INDEX.keys()

const SCREEN_SPACE_AA_TO_INDEX = {
	Viewport.SCREEN_SPACE_AA_DISABLED: 0,
	Viewport.SCREEN_SPACE_AA_SMAA: 1,
	Viewport.SCREEN_SPACE_AA_FXAA: 2
}
var INDEX_TO_SCREEN_SPACE_AA = SCREEN_SPACE_AA_TO_INDEX.keys()

const MSAA_TO_INDEX = {
	Viewport.MSAA_DISABLED: 0,
	Viewport.MSAA_2X: 1,
	Viewport.MSAA_4X: 2,
	Viewport.MSAA_8X: 3
}
var INDEX_TO_MSAA = MSAA_TO_INDEX.keys()


func _ready():
	window_mode.selected = WINDOW_MODE_TO_INDEX[DisplayServer.window_get_mode()]

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

	screen_space_aa.selected = SCREEN_SPACE_AA_TO_INDEX[get_viewport().screen_space_aa]
	msaa.selected = MSAA_TO_INDEX[get_viewport().msaa_3d]
	taa.button_pressed = get_viewport().use_taa

	screen_space_aa.item_selected.connect(_on_screen_space_aa_item_selected)
	msaa.item_selected.connect(_on_msaa_item_selected)
	taa.toggled.connect(_on_taa_toggled)


func _on_window_mode_selected(index: int):
	DisplayServer.window_set_mode(INDEX_TO_WINDOW_MODE[index])


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
	get_viewport().screen_space_aa = INDEX_TO_SCREEN_SPACE_AA[index]


func _on_msaa_item_selected(index: int):
	get_viewport().msaa_3d = INDEX_TO_MSAA[index]


func _on_taa_toggled(toggled_on: bool):
	get_viewport().use_taa = toggled_on
