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
	window_mode.item_selected.connect(_on_window_mode_selected)
	window_mode.select(Settings.get_value("video", "window_mode"))

	vsync.toggled.connect(_on_vsync_toggled)
	vsync.button_pressed = Settings.get_value("video", "vsync")
	vsync.toggled.emit(Settings.get_value("video", "vsync"))

	frame_rate_limit.value_changed.connect(_on_frame_rate_limit_value_changed)
	frame_rate_limit.value_changed.emit(Settings.get_value("video", "frame_rate_limit"))
	frame_rate_limit.value = frame_rate_limit.max_value if Engine.max_fps == 0 else Engine.max_fps

	screen_space_aa.item_selected.connect(_on_screen_space_aa_item_selected)
	screen_space_aa.select(SCREEN_SPACE_AA_TO_INDEX[Settings.get_value("video", "screen_space_aa")])

	msaa.item_selected.connect(_on_msaa_item_selected)
	msaa.select(MSAA_TO_INDEX[Settings.get_value("video", "msaa")])

	taa.toggled.connect(_on_taa_toggled)
	taa.button_pressed = Settings.get_value("video", "taa")
	taa.toggled.emit(Settings.get_value("video", "taa"))


func _on_window_mode_selected(index: int):
	DisplayServer.window_set_mode(INDEX_TO_WINDOW_MODE[index])
	Settings.set_value("video", "window_mode", INDEX_TO_WINDOW_MODE[index])


func _on_vsync_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		frame_rate_limit.disabled = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		frame_rate_limit.disabled = false
	Settings.set_value("video", "vsync", DisplayServer.window_get_vsync_mode())


func _on_frame_rate_limit_value_changed(value: float):
	if value == 0 || value == frame_rate_limit.max_value:
		frame_rate_limit.value = frame_rate_limit.max_value
		frame_rate_limit.label.text = "UNLIMITED"
		Engine.max_fps = 0
	else:
		Engine.max_fps = int(value)
	Settings.set_value("video", "frame_rate_limit", Engine.max_fps)


func _on_screen_space_aa_item_selected(index: int):
	get_viewport().screen_space_aa = INDEX_TO_SCREEN_SPACE_AA[index]
	Settings.set_value("video", "screen_space_aa", INDEX_TO_SCREEN_SPACE_AA[index])


func _on_msaa_item_selected(index: int):
	get_viewport().msaa_3d = INDEX_TO_MSAA[index]
	Settings.set_value("video", "msaa", INDEX_TO_MSAA[index])


func _on_taa_toggled(toggled_on: bool):
	get_viewport().use_taa = toggled_on
	Settings.set_value("video", "taa", toggled_on)
