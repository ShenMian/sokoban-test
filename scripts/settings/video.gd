extends ScrollContainer

@onready var window_mode: OptionButton = $Margin/VBox/WindowModePanel/Margin/HBox/OptionButton
@onready var vsync: CheckButton = $Margin/VBox/VsyncPanel/Margin/HBox/CheckButton
@onready var frame_rate_limit: SliderBar = $Margin/VBox/FrameRateLimitPanel/Margin/HSplit/SliderBar
@onready var scaling_method: OptionButton = $Margin/VBox/ScalingMethodPanel/Margin/HBox/OptionButton
@onready var upscaled_resolution: SliderBar = $Margin/VBox/UpscaledResolutionPanel/Margin/HSplit/SliderBar
@onready var fsr_sharpness: SliderBar = $Margin/VBox/FsrSharpnessPanel/Margin/HSplit/SliderBar

@onready var fov: SliderBar = $Margin/VBox/FieldOfViewPanel/Margin/HSplit/SliderBar

@onready var screen_space_aa: OptionButton = $Margin/VBox/ScreenSpaceAAPanel/Margin/HBox/OptionButton
@onready var msaa: OptionButton = $Margin/VBox/MsaaPanel/Margin/HBox/OptionButton
@onready var taa: CheckButton = $Margin/VBox/TaaPanel/Margin/HBox/CheckButton

const SECTION_NAME := "video"

const WINDOW_MODES: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
]

const SCREEN_SPACE_AA_MODES: Array[Viewport.ScreenSpaceAA] = [
	Viewport.SCREEN_SPACE_AA_DISABLED,
	Viewport.SCREEN_SPACE_AA_SMAA,
	Viewport.SCREEN_SPACE_AA_FXAA
]

const MSAA_MODES: Array[Viewport.MSAA] = [
	Viewport.MSAA_DISABLED,
	Viewport.MSAA_2X,
	Viewport.MSAA_4X,
	Viewport.MSAA_8X
]

const SCALING_3D_MODES: Array[Viewport.Scaling3DMode] = [
	Viewport.SCALING_3D_MODE_BILINEAR,
	Viewport.SCALING_3D_MODE_FSR,
	Viewport.SCALING_3D_MODE_FSR2
]


func _ready():
	window_mode.item_selected.connect(_on_window_mode_selected)
	vsync.toggled.connect(_on_vsync_toggled)
	frame_rate_limit.value_changed.connect(_on_frame_rate_limit_changed)
	scaling_method.item_selected.connect(_on_scaling_method_selected)
	upscaled_resolution.value_changed.connect(_on_upscaled_resolution_changed)
	fsr_sharpness.value_changed.connect(_on_fsr_sharpness_changed)
	fov.value_changed.connect(_on_fov_changed)
	screen_space_aa.item_selected.connect(_on_screen_space_aa_selected)
	msaa.item_selected.connect(_on_msaa_selected)
	taa.toggled.connect(_on_taa_toggled)

	apply_settings()


func apply_settings():
	window_mode.select(WINDOW_MODES.find(Settings.get_value(SECTION_NAME, "window_mode")))
	window_mode.item_selected.emit(window_mode.selected)

	vsync.button_pressed = Settings.get_value(SECTION_NAME, "vsync")
	vsync.toggled.emit(vsync.button_pressed)

	var max_fps = Settings.get_value(SECTION_NAME, "frame_rate_limit")
	frame_rate_limit.value = frame_rate_limit.max_value if max_fps == 0 else max_fps

	upscaled_resolution.value = Settings.get_value(SECTION_NAME, "scaling_3d_scale")
	upscaled_resolution.value_changed.emit(upscaled_resolution.value)

	fsr_sharpness.value = Settings.get_value(SECTION_NAME, "fsr_sharpness")
	fsr_sharpness.value_changed.emit(fsr_sharpness.value)

	fov.value = Settings.get_value(SECTION_NAME, "fov")

	screen_space_aa.select(SCREEN_SPACE_AA_MODES.find(Settings.get_value(SECTION_NAME, "screen_space_aa")))
	screen_space_aa.item_selected.emit(screen_space_aa.selected)

	msaa.select(MSAA_MODES.find(Settings.get_value(SECTION_NAME, "msaa")))
	msaa.item_selected.emit(msaa.selected)

	taa.button_pressed = Settings.get_value(SECTION_NAME, "taa")
	taa.toggled.emit(taa.button_pressed)

	scaling_method.select(SCALING_3D_MODES.find(Settings.get_value(SECTION_NAME, "scaling_3d_mode")))
	scaling_method.item_selected.emit(scaling_method.selected)


func _on_window_mode_selected(index: int):
	var mode := WINDOW_MODES[index]
	DisplayServer.window_set_mode(mode)
	Settings.set_and_save_value(SECTION_NAME, "window_mode", mode)


func _on_vsync_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		frame_rate_limit.disabled = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		frame_rate_limit.disabled = false
	Settings.set_and_save_value(SECTION_NAME, "vsync", DisplayServer.window_get_vsync_mode())


func _on_frame_rate_limit_changed(value: float):
	if value == 0 || value == frame_rate_limit.max_value:
		frame_rate_limit.value = frame_rate_limit.max_value
		frame_rate_limit.label.text = "UNLIMITED"
		Engine.max_fps = 0
	else:
		Engine.max_fps = int(value)
	Settings.set_and_save_value(SECTION_NAME, "frame_rate_limit", Engine.max_fps)


func _on_fov_changed(value: float):
	Settings.set_and_save_value(SECTION_NAME, "fov", value)


func _on_screen_space_aa_selected(index: int):
	var mode := SCREEN_SPACE_AA_MODES[index]
	get_viewport().screen_space_aa = mode
	Settings.set_and_save_value(SECTION_NAME, "screen_space_aa", mode)


func _on_msaa_selected(index: int):
	var mode := MSAA_MODES[index]
	get_viewport().msaa_3d = mode
	Settings.set_and_save_value(SECTION_NAME, "msaa", mode)


func _on_taa_toggled(toggled_on: bool):
	get_viewport().use_taa = toggled_on
	Settings.set_and_save_value(SECTION_NAME, "taa", toggled_on)


func _on_scaling_method_selected(index: int):
	var mode := SCALING_3D_MODES[index]
	var last_mode := get_viewport().scaling_3d_mode
	get_viewport().scaling_3d_mode = mode
	Settings.set_and_save_value(SECTION_NAME, "scaling_3d_mode", mode)

	fsr_sharpness.disabled = !(mode == Viewport.SCALING_3D_MODE_FSR || mode == Viewport.SCALING_3D_MODE_FSR2)
	# Disable AA when using FSR 2.2
	if mode == Viewport.SCALING_3D_MODE_FSR2:
		screen_space_aa.disabled = true
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		taa.disabled = true
		get_viewport().use_taa = false
		msaa.disabled = true
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	elif last_mode == Viewport.SCALING_3D_MODE_FSR2:
		screen_space_aa.disabled = false
		get_viewport().screen_space_aa = screen_space_aa.selected as Viewport.ScreenSpaceAA
		taa.disabled = false
		get_viewport().use_taa = taa.button_pressed
		msaa.disabled = false
		get_viewport().msaa_3d = msaa.selected as Viewport.MSAA


func _on_upscaled_resolution_changed(value: float):
	get_viewport().scaling_3d_scale = value
	Settings.set_and_save_value(SECTION_NAME, "scaling_3d_scale", value)


func _on_fsr_sharpness_changed(value: float):
	get_viewport().fsr_sharpness = value
	Settings.set_and_save_value(SECTION_NAME, "fsr_sharpness", value)
