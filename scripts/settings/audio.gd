extends CenterContainer

@onready var master_volumn: SliderBar = $VBox/MasterVolumePanel/Margin/HBox/SliderBar
@onready var music_volumn: SliderBar = $VBox/MusicVolumePanel/Margin/HBox/SliderBar
@onready var sfx_volumn: SliderBar = $VBox/SfxVolumePanel/Margin/HBox/SliderBar
@onready var mute_when_not_focused: CheckButton = $VBox/MuteWhenNotFocusedPanel/Margin/HBox/CheckButton


func _ready():
	var master_bus_index := AudioServer.get_bus_index("Master")
	var music_bus_index := AudioServer.get_bus_index("Music")
	var sfx_bus_index := AudioServer.get_bus_index("Sfx")

	master_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	music_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus_index))
	sfx_volumn.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_index))

	master_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(master_bus_index)))
	music_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(music_bus_index)))
	sfx_volumn.value_changed.connect(linear_to_db.bind(AudioServer.set_bus_volume_db.bind(sfx_bus_index)))


func _notification(what: int):
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_window_minimized()

		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_window_restored()


func _on_window_minimized():
	if not mute_when_not_focused.button_pressed:
		return
	
	var master_bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, true)


func _on_window_restored():
	if not mute_when_not_focused.button_pressed:
		return
	
	var master_bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, false)
