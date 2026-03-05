extends Node3D

@onready var hud: Control = $HudLayer/HUD
@onready var pause_menu: PauseMenu = $MenuLayer/PauseMenu
@onready var settings_menu: SettingsMenu = $MenuLayer/SettingsMenu
@onready var credits: Control = $MenuLayer/Credits
@onready var victory_menu: VictoryMenu = $MenuLayer/VictoryMenu
@onready var level_map: LevelMap = $LevelMap
@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue


func _ready() -> void:
	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.request_settings.connect(_on_pause_request_settings)
	pause_menu.request_credits.connect(_on_pause_request_credits)
	pause_menu.request_menu.connect(_on_request_menu)
	settings_menu.closed.connect(pause_menu.show)
	credits.closed.connect(pause_menu.show)

	level_map.solved.connect(_on_level_solved)
	victory_menu.request_next_level.connect(_on_request_next_level)
	victory_menu.request_menu.connect(_on_request_menu)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		get_viewport().set_input_as_handled()
		hud.hide()
		pause_menu.open()


func _on_pause_closed() -> void:
	hud.show()


func _on_pause_request_settings() -> void:
	pause_menu.hide()
	settings_menu.open()


func _on_pause_request_credits() -> void:
	pause_menu.hide()
	credits.open()


func _on_level_solved() -> void:
	victory_menu.open(int(moves_label.text), int(pushes_label.text))


func _on_request_next_level() -> void:
	# TODO: Add bounds checking
	Settings.current_level_index += 1
	SceneTransition.change_scene_to_file("res://scenes/gameplay.tscn")


func _on_request_menu() -> void:
	SceneTransition.change_scene_to_file("res://scenes/ui/level_selector.tscn")
