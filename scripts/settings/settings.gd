extends Node

signal setting_changed(section: String, key: String, value: Variant)

var config := ConfigFile.new()
const CONFIG_PATH = "user://settings.ini"

const DEFAULT_CONFIG = {
	"gameplay": {
		"language": "en",
		"checkerboard": false,
		"deadlock": true,
		"heatmap": true
	},
	"video": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"frame_rate_limit": 0,
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


func _ready() -> void:
	var error := config.load(CONFIG_PATH)
	if error:
		print("failed to load config file: ", error)

		# Creates default settings
		reset_gameplay_settings()
		reset_video_settings()
		reset_audio_settings()
