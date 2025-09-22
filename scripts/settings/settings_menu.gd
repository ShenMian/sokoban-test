extends Control

signal fov_changed(fov: float)
signal deadlock_changed(on: bool)
signal closed

@onready var background: TextureRect = $Background
@onready var tabs: TabContainer = $MarginContainer/VBox/Tabs
@onready var close_button: ButtonFx = $CloseButton
@onready var restore_button: ButtonFx = $RestoreButton

@onready var gameplay: CenterContainer = $MarginContainer/VBox/Tabs/GAMEPLAY
@onready var video: ScrollContainer = $MarginContainer/VBox/Tabs/VIDEO
@onready var audio: CenterContainer = $MarginContainer/VBox/Tabs/AUDIO


func open():
	show()


func close():
	hide()
	closed.emit()


func _ready() -> void:
	tabs.tab_changed.connect(_on_active_tab_changed)
	close_button.pressed.connect(close)
	restore_button.pressed.connect(_on_restore_pressed)

	video.fov_changed.connect(fov_changed.emit)
	gameplay.deadlock_changed.connect(deadlock_changed.emit)


func _input(_event: InputEvent):
	if not self.visible:
		return


func _on_active_tab_changed(index: int):
	Sounds.play_button_press()
	if tabs.get_tab_title(index) == "VIDEO":
		background.visible = false
	else:
		background.visible = true


func _on_fov_changed(value: float):
	fov_changed.emit(value)
	Settings.set_and_save_value("video", "fov", value)


func _on_restore_pressed():
	match tabs.get_tab_title(tabs.current_tab):
		"GAMEPLAY":
			Settings.reset_gameplay_settings()
			gameplay.apply_settings()
		"VIDEO":
			Settings.reset_video_settings()
			video.apply_settings()
		"AUDIO":
			Settings.reset_audio_settings()
			audio.apply_settings()
