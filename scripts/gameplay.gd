extends Node3D

@onready var hud: Control = $HudLayer/HUD
@onready var pause_menu: Control = $MenuLayer/PauseMenu
@onready var settings_menu: Control = $MenuLayer/SettingsMenu


func _ready():
	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.request_settings.connect(_on_pause_request_settings)
	settings_menu.closed.connect(_on_settings_closed)


func _input(_event):
	if Input.is_action_just_released("pause"):
		hud.hide()
		pause_menu.open()


func _on_pause_closed():
	hud.show()


func _on_pause_request_settings():
	pause_menu.hide()
	settings_menu.open()


func _on_settings_closed():
	pause_menu.show()
