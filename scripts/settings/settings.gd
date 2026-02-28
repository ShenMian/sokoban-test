extends Node

signal setting_changed(section: String, key: String, value: Variant)

var config := ConfigFile.new()
const CONFIG_PATH = "user://settings.ini"

const DEFAULT_CONFIG = {
	"gameplay": {
		"language": "en",
		"animation_speed": 1,
		"checkerboard": true,
		"deadlock": true,
		"pushable_hint": true,
		"pathfinding_strategy": 0,
		"heatmap": true,
		"algorithm": 0,
		"solver_strategy": 0,
	},
	"video": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"frame_rate_limit": 0,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"scaling_3d_scale": 1.0,
		"fsr_sharpness": 0.2,
		"fov": 60.0,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"msaa": Viewport.MSAA_DISABLED,
		"taa": false
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"mute_when_not_focused": true
	}
}

const DEFAULT_BINDINGS_PATH = "user://default_bindings.tres"
const BINDINGS_PATH := "user://bindings.tres"


func _ready():
	var error := config.load(CONFIG_PATH)
	if error:
		printerr("failed to load config file: ", error_string(error))

		# Creates default settings
		reset_gameplay_settings()
		reset_video_settings()
		reset_audio_settings()
	
	save_input_bindings(DEFAULT_BINDINGS_PATH)
	load_input_bindings()


func set_and_save_value(section: String, key: String, value: Variant):
	set_value(section, key, value)
	config.save(CONFIG_PATH)


func set_value(section: String, key: String, value: Variant):
	config.set_value(section, key, value)
	setting_changed.emit(section, key, value)


func get_value(section: String, key: String):
	return config.get_value(section, key)


func reset_gameplay_settings():
	config.erase_section("gameplay")
	for key in DEFAULT_CONFIG.gameplay:
		var value = DEFAULT_CONFIG.gameplay[key]
		set_value("gameplay", key, value)

	var locale = OS.get_locale()
	if locale in TranslationServer.get_loaded_locales():
		config.set_value("gameplay", "language", locale)

	config.save(CONFIG_PATH)


func reset_video_settings():
	config.erase_section("video")
	for key in DEFAULT_CONFIG.video:
		var value = DEFAULT_CONFIG.video[key]
		set_value("video", key, value)
	config.save(CONFIG_PATH)


func reset_audio_settings():
	config.erase_section("audio")
	for key in DEFAULT_CONFIG.audio:
		var value = DEFAULT_CONFIG.audio[key]
		set_value("audio", key, value)
	config.save(CONFIG_PATH)


func reset_input_settings():
	load_input_bindings(DEFAULT_BINDINGS_PATH)
	save_input_bindings()


func save_input_bindings(path: String = BINDINGS_PATH):
	var map = DictionaryResource.new()
	for action in InputMap.get_actions():
		if action.begins_with("editor_") or action.begins_with("ui_"):
			continue
		map.dict[action] = InputMap.action_get_events(action)
	var error := ResourceSaver.save(map, path)
	if error:
		printerr("failed to save bindings: ", error_string(error))


func load_input_bindings(path: String = BINDINGS_PATH):
	var map: DictionaryResource = ResourceLoader.load(path, "DictionaryResource")
	if not is_instance_valid(map):
		printerr("failed to load bindings")
		return
	for action in map.dict:
		InputMap.action_erase_events(action)
		for event in map.dict[action]:
			InputMap.action_add_event(action, event)
