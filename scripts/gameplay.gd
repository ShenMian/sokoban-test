extends Node3D

@onready var level_map: LevelMap = $LevelMap

@onready var hud: Control = $HudLayer/HUD
@onready var pause_menu: PauseMenu = $MenuLayer/PauseMenu
@onready var settings_menu: SettingsMenu = $MenuLayer/SettingsMenu
@onready var credits: Control = $MenuLayer/Credits
@onready var victory_menu: VictoryMenu = $MenuLayer/VictoryMenu

@onready var level_label: Label = %LevelValue
@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue

@onready var undo_button: ButtonFx = %UndoButton
@onready var redo_button: ButtonFx = %RedoButton
@onready var undo_all_button: ButtonFx = %UndoAllButton
@onready var solve_button: ButtonFx = %SolveButton
@onready var menu_button: ButtonFx = %MenuButton
@onready var transform_button: ButtonFx = %TransformButton
@onready var previous_button: ButtonFx = %PreviousButton
@onready var next_button: ButtonFx = %NextButton

var _transform_state: int = 0


func _ready() -> void:
	previous_button.disabled = not SceneTransition.has_previous_level()
	next_button.disabled = not SceneTransition.has_next_level()

	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.request_settings.connect(_on_pause_request_settings)
	pause_menu.request_credits.connect(_on_pause_request_credits)
	pause_menu.request_menu.connect(SceneTransition.load_main_menu)
	settings_menu.closed.connect(pause_menu.show)
	credits.closed.connect(pause_menu.show)

	level_map.solved.connect(_on_level_solved)
	victory_menu.request_next_level.connect(SceneTransition.load_next_level)
	victory_menu.request_menu.connect(SceneTransition.load_main_menu)

	undo_button.pressed.connect(level_map.do_undo)
	redo_button.pressed.connect(level_map.do_redo)
	undo_all_button.pressed.connect(level_map.do_undo_all)
	solve_button.pressed.connect(level_map.do_solve)
	menu_button.pressed.connect(_open_pause_menu)
	transform_button.pressed.connect(_transform_level)
	previous_button.pressed.connect(SceneTransition.load_previous_level)
	next_button.pressed.connect(SceneTransition.load_next_level)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _open_pause_menu():
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
	await level_map.wait_for_moves_finished()
	while _transform_state != 0:
		_transform_level()
	victory_menu.open(Actions.new(level_map.get_lurd()))


func _transform_level() -> void:
	if _transform_state % 4 == 3:
		level_map.rotate()
		level_map.flip_horizontal()
	else:
		level_map.rotate()

	_transform_state = (_transform_state + 1) % 8

	level_map.deselect_box()
	level_map._sync_entities_from_state()
	level_map._update_ui()
	level_map._reset_camera_position()
