extends ScrollContainer

@onready var language: OptionButton = $Margin/VBox/LanguagePanel/Margin/HBox/OptionButton
@onready var animation_speed: OptionButton = $Margin/VBox/AnimationSpeedPanel/Margin/HBox/OptionButton
@onready var checkerboard: SwitchFx = $Margin/VBox/CheckerboardPanel/Margin/HBox/CheckButton
@onready var deadlock: SwitchFx = $Margin/VBox/DeadlockPanel/Margin/HBox/CheckButton
@onready var strategy: OptionButton = $Margin/VBox/StrategyPanel/Margin/HBox/OptionButton
@onready var algorithm: OptionButton = $Margin/VBox/AlgorithmPanel/Margin/HBox/OptionButton

const SECTION_NAME := "gameplay"

const LOCALES: Array[String] = ["en", "zh"]
const ALGORITHMS: Array[String] = ["A*", "IDA*"]


func _ready():
	language.item_selected.connect(_on_language_selected)
	animation_speed.item_selected.connect(_on_animation_speed_selected)
	checkerboard.toggled.connect(_on_checkerboard_toggled)
	deadlock.toggled.connect(_on_deadlock_toggled)
	strategy.item_selected.connect(_on_strategy_selected)
	algorithm.item_selected.connect(_on_algorithm_selected)

	apply_settings()


func apply_settings():
	language.select(LOCALES.find(Settings.get_value(SECTION_NAME, "language")))
	language.item_selected.emit(language.selected)

	animation_speed.select(Settings.get_value(SECTION_NAME, "animation_speed"))
	animation_speed.item_selected.emit(animation_speed.selected)

	checkerboard.button_pressed = Settings.get_value(SECTION_NAME, "checkerboard")
	checkerboard.toggled.emit(checkerboard.button_pressed)

	deadlock.button_pressed = Settings.get_value(SECTION_NAME, "deadlock")
	deadlock.toggled.emit(deadlock.button_pressed)

	strategy.select(Settings.get_value(SECTION_NAME, "strategy"))
	strategy.item_selected.emit(strategy.selected)
	
	algorithm.select(ALGORITHMS.find(Settings.get_value(SECTION_NAME, "algorithm")))
	algorithm.item_selected.emit(algorithm.selected)


func _on_language_selected(index: int):
	var locale := LOCALES[index]
	TranslationServer.set_locale(locale)
	Settings.set_and_save_value(SECTION_NAME, "language", locale)


func _on_animation_speed_selected(index: int):
	Settings.set_and_save_value(SECTION_NAME, "animation_speed", index)


func _on_checkerboard_toggled(toggled_on: bool):
	Settings.set_and_save_value(SECTION_NAME, "checkerboard", toggled_on)


func _on_deadlock_toggled(toggled_on: bool):
	Settings.set_and_save_value(SECTION_NAME, "deadlock", toggled_on)


func _on_strategy_selected(index: int):
	Settings.set_and_save_value(SECTION_NAME, "strategy", index)


func _on_algorithm_selected(index: int):
	Settings.set_and_save_value(SECTION_NAME, "algorithm", ALGORITHMS[index])
