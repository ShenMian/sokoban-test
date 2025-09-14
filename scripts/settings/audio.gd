extends CenterContainer

@onready var master_volumn: HSlider = $VBox/VolumnGrid/MasterVolumn
@onready var music_volumn: HSlider = $VBox/VolumnGrid/MusicVolumn
@onready var sfx_volumn: HSlider = $VBox/VolumnGrid/SfxVolumn
@onready var mute_when_not_focused: CheckButton = $VBox/OutputGrid/MuteWhenNotFocused


func _ready() -> void:
	var master_bus_index := AudioServer.get_bus_index("Master")
	var music_bus_index := AudioServer.get_bus_index("Music")
	var sfx_bus_index := AudioServer.get_bus_index("Sfx")

	master_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	music_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus_index))
	sfx_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index))

	master_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(master_bus_index)))
	music_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(music_bus_index)))
	sfx_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(sfx_bus_index)))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_window_minimized()

		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_window_restored()


func _on_window_minimized() -> void:
	if not mute_when_not_focused.button_pressed:
		return
	
	var master_bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, true)


func _on_window_restored() -> void:
	if not mute_when_not_focused.button_pressed:
		return
	
	var master_bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, false)
