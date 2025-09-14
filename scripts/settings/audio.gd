extends CenterContainer

@onready var master_volumn: HSlider = $VBox/GridContainer/MasterVolumn
@onready var music_volumn: HSlider = $VBox/GridContainer/MusicVolumn
@onready var sfx_volumn: HSlider = $VBox/GridContainer/SfxVolumn


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
