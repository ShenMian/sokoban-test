extends ScrollContainer

@onready var language: OptionButton = $VBox/LanguagePanel/HBox/OptionButton
@onready var animation_speed: OptionButton = $VBox/AnimationSpeedPanel/HBox/OptionButton
@onready var view_2d: SwitchFx = $"VBox/2dViewPanel/HBox/CheckButton"
@onready var checkerboard: SwitchFx = $VBox/CheckerboardPanel/HBox/CheckButton
@onready var deadlock: SwitchFx = $VBox/DeadlockPanel/HBox/CheckButton
@onready var pushable_hint: SwitchFx = $VBox/PushableHintPanel/HBox/CheckButton
@onready var pathfinding_strategy: OptionButton = $VBox/PathfindingStrategyPanel/HBox/OptionButton

@onready var algorithm: OptionButton = $VBox/AlgorithmPanel/HBox/OptionButton
@onready var solver_strategy: OptionButton = $VBox/StrategyPanel/HBox/OptionButton
@onready var heatmap: SwitchFx = $VBox/HeatmapPanel/HBox/CheckButton

const SECTION_NAME := "gameplay"


func _ready() -> void:
	language.item_selected.connect(_on_language_selected)
	animation_speed.item_selected.connect(_on_animation_speed_selected)
	view_2d.toggled.connect(_on_2d_view_toggled)
	checkerboard.toggled.connect(_on_checkerboard_toggled)
	deadlock.toggled.connect(_on_deadlock_toggled)
	pushable_hint.toggled.connect(_on_pushable_hint_toggled)
	pathfinding_strategy.item_selected.connect(_on_pathfinding_strategy_selected)
	algorithm.item_selected.connect(_on_algorithm_selected)
	solver_strategy.item_selected.connect(_on_strategy_selected)
	heatmap.toggled.connect(_on_heatmap_toggled)

	apply_settings()


func apply_settings() -> void:
	language.select(Settings.LOCALES.find(Settings.get_value(SECTION_NAME, "language")))
	language.item_selected.emit(language.selected)

	animation_speed.select(Settings.get_value(SECTION_NAME, "animation_speed"))
	animation_speed.item_selected.emit(animation_speed.selected)

	view_2d.button_pressed = Settings.get_value(SECTION_NAME, "2d_view")
	view_2d.toggled.emit(view_2d.button_pressed)

	checkerboard.button_pressed = Settings.get_value(SECTION_NAME, "checkerboard")
	checkerboard.toggled.emit(checkerboard.button_pressed)

	deadlock.button_pressed = Settings.get_value(SECTION_NAME, "deadlock_hint")
	deadlock.toggled.emit(deadlock.button_pressed)

	pushable_hint.button_pressed = Settings.get_value(SECTION_NAME, "pushable_hint")
	pushable_hint.toggled.emit(pushable_hint.button_pressed)

	pathfinding_strategy.select(Settings.get_value(SECTION_NAME, "pathfinding_strategy"))
	pathfinding_strategy.item_selected.emit(pathfinding_strategy.selected)

	algorithm.select(Settings.get_value(SECTION_NAME, "algorithm"))
	algorithm.item_selected.emit(algorithm.selected)

	solver_strategy.select(Settings.get_value(SECTION_NAME, "solver_strategy"))
	solver_strategy.item_selected.emit(solver_strategy.selected)

	heatmap.button_pressed = Settings.get_value(SECTION_NAME, "heatmap")
	heatmap.toggled.emit(heatmap.button_pressed)


func _on_language_selected(index: int) -> void:
	var locale := Settings.LOCALES[index]
	TranslationServer.set_locale(locale)
	Settings.set_and_save_value(SECTION_NAME, "language", locale)


func _on_animation_speed_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "animation_speed", index)


func _on_2d_view_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "2d_view", toggled_on)


func _on_checkerboard_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "checkerboard", toggled_on)


func _on_deadlock_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "deadlock_hint", toggled_on)


func _on_pushable_hint_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "pushable_hint", toggled_on)


func _on_pathfinding_strategy_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "pathfinding_strategy", index)


func _on_algorithm_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "algorithm", index)


func _on_strategy_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "solver_strategy", index)


func _on_heatmap_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "heatmap", toggled_on)
