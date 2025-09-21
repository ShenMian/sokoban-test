extends CenterContainer

signal deadlock_changed(on: bool)

@onready var language: OptionButton = $VBox/LanguagePanel/Margin/HBox/OptionButton
@onready var deadlock: SwitchFx = $VBox/DeadlockPanel/Margin/HBox/CheckButton

const LOCALE_TO_NAME = {
	"en": "English",
	"zh": "中文"
}

const LOCALE_TO_INDEX = {
	"en": 0,
	"zh": 1
}


func _ready() -> void:
	var locales = TranslationServer.get_loaded_locales()
	for i in range(locales.size()):
		var locale = locales[i]
		language.add_item("%s (%s)" % [LOCALE_TO_NAME[locale], TranslationServer.get_locale_name(locale)])
		language.set_item_metadata(i, locale)

	language.item_selected.connect(_on_language_item_selected)
	deadlock.toggled.connect(deadlock_changed.emit)

	apply_settings()


func apply_settings() -> void:
	var index = LOCALE_TO_INDEX[Settings.get_value("gameplay", "language")];
	language.select(index)
	language.item_selected.emit(index)

	deadlock.button_pressed = Settings.get_value("gameplay", "deadlock")
	deadlock.toggled.emit(Settings.get_value("gameplay", "deadlock"))


func _on_language_item_selected(index: int):
	var locale := str(language.get_item_metadata(index))
	TranslationServer.set_locale(locale)
	Settings.set_value("gameplay", "language", locale)
