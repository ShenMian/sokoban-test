extends Node

signal setting_changed(section: String, key: String, value: Variant)

const INT_MAX := Vector3i.MAX.x

var config := ConfigFile.new()
const CONFIG_PATH = "user://settings.ini"

var solutions := ConfigFile.new()
const SOLUTIONS_PATH = "user://solutions.ini"

const DEFAULT_CONFIG = {
	"gameplay": {
		"language": "en",
		"animation_speed": 1,
		"checkerboard": true,
		"deadlock_hint": true,
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
const LEVEL_PATH := "res://assets/levels/"

var current_collection
var current_level_index


func _ready():
	var error := config.load(CONFIG_PATH)
	if error:
		printerr("failed to load config file: ", error_string(error))

		# Creates default settings
		reset_gameplay_settings()
		reset_video_settings()
		reset_audio_settings()
	
	var solutions_error := solutions.load(SOLUTIONS_PATH)
	if solutions_error:
		printerr("failed to load solutions file: ", error_string(solutions_error))

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


func _count_uppercase(text: String) -> int:
	var count = 0
	for i in range(text.length()):
		var ascii := text.unicode_at(i)
		if ascii >= int('A') and ascii <= int('Z'):
			count += 1
	return count


func set_level_solution(collection: String, level: int, actions: String):
	var solution := get_level_solution(collection, level)
	var best_pushes: int = _count_uppercase(solution["pushes_optimal"])
	var best_moves: int = solution["moves_optimal"].length()

	var new_pushes: int = _count_uppercase(actions)
	var new_moves: int = actions.length()
	var new_solution := solution.duplicate()

	if solution["pushes_optimal"].is_empty() or new_pushes < best_pushes:
		new_solution["pushes_optimal"] = actions
	if solution["moves_optimal"].is_empty() or new_moves < best_moves:
		new_solution["moves_optimal"] = actions

	solutions.set_value(collection, str(level), new_solution)
	solutions.save(SOLUTIONS_PATH)


const DEFAULT_SOLUTION := {
	"pushes_optimal": "",
	"moves_optimal": "",
}


func get_level_solution(collection: String, level: int) -> Dictionary:
	var solution: Dictionary = solutions.get_value(collection, str(level), DEFAULT_SOLUTION)
	return solution
