extends ScrollContainer

@onready var language: OptionButton = $VBox/LanguagePanel/Margin/HBox/OptionButton
@onready var deadlock: SwitchFx = $VBox/DeadlockPanel/Margin/HBox/CheckButton

const SECTION_NAME := "gameplay"

const LOCALES: Array[String] = ["en", "zh"]


func _ready():
	language.item_selected.connect(_on_language_selected)
	deadlock.toggled.connect(_on_deadlock_toggled)

	apply_settings()


func apply_settings():
	language.select(LOCALES.find(Settings.get_value(SECTION_NAME, "language")))
	language.item_selected.emit(language.selected)

	deadlock.button_pressed = Settings.get_value(SECTION_NAME, "deadlock")
	deadlock.toggled.emit(deadlock.button_pressed)


func _on_language_selected(index: int):
	var locale := LOCALES[index]
	TranslationServer.set_locale(locale)
	Settings.set_and_save_value(SECTION_NAME, "language", locale)


func _on_deadlock_toggled(toggled_on: bool):
	Settings.set_and_save_value(SECTION_NAME, "deadlock", toggled_on)
