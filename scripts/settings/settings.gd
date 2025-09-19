extends Node

var config := ConfigFile.new()
const CONFIG_PATH = "user://settings.ini"


func set_value(section: String, key: String, value: Variant):
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)


func get_value(section: String, key: String):
	return config.get_value(section, key)


func _ready() -> void:
	var error := config.load(CONFIG_PATH)
	if error:
		print("failed to load config file: ", error)

		# Creates default settings
		reset_gameplay_settings()
		reset_video_settings()
		reset_audio_settings()


func reset_gameplay_settings():
	var locale = OS.get_locale()
	if locale in TranslationServer.get_loaded_locales():
		config.set_value("gameplay", "language", locale)
	else:
		config.set_value("gameplay", "language", "en")
	# config.set_value("gameplay", "checkerboard", false)
	# config.set_value("gameplay", "deadlock", true)
	# config.set_value("gameplay", "heatmap", true)
	config.save(CONFIG_PATH)


func reset_video_settings():
	config.set_value("video", "window_mode", DisplayServer.WINDOW_MODE_WINDOWED)
	config.set_value("video", "vsync", DisplayServer.VSYNC_ENABLED)
	config.set_value("video", "frame_rate_limit", 0)
	config.set_value("video", "fov", 60.0)
	config.set_value("video", "screen_space_aa", Viewport.SCREEN_SPACE_AA_SMAA)
	config.set_value("video", "msaa", Viewport.MSAA_DISABLED)
	config.set_value("video", "taa", false)
	config.save(CONFIG_PATH)


func reset_audio_settings():
	config.set_value("audio", "master_volume", 1.0)
	config.set_value("audio", "music_volume", 1.0)
	config.set_value("audio", "sfx_volume", 1.0)
	config.set_value("audio", "mute_when_not_focused", true)
	config.save(CONFIG_PATH)
