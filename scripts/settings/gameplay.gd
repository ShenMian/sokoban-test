extends CenterContainer

@onready var language: OptionButton = $VBox/LanguagePanel/Margin/HBox/OptionButton
@onready var deadlock: SwitchFx = $VBox/DeadlockPanel/Margin/HBox/CheckButton

const SECTION_NAME := "gameplay"

const LOCALE_TO_NAME := {
	"en": "English",
	"zh": "中文"
}

const LOCALE_TO_INDEX := {
	"en": 0,
	"zh": 1
}
var INDEX_TO_LOCALE := LOCALE_TO_INDEX.keys()


func _ready() -> void:
	var locales = TranslationServer.get_loaded_locales()
	for i in range(locales.size()):
		var locale = locales[i]
		language.add_item("%s (%s)" % [LOCALE_TO_NAME[locale], TranslationServer.get_locale_name(locale)])
		language.set_item_metadata(i, locale)

	language.item_selected.connect(_on_language_item_selected)
	deadlock.toggled.connect(_on_deadlock_toggled)

	apply_settings()


func apply_settings() -> void:
	language.select(LOCALE_TO_INDEX[Settings.get_value(SECTION_NAME, "language")])
	language.item_selected.emit(language.selected)

	deadlock.button_pressed = Settings.get_value(SECTION_NAME, "deadlock")
	deadlock.toggled.emit(deadlock.button_pressed)


func _on_language_item_selected(index: int):
	var locale: String = INDEX_TO_LOCALE[index]
	TranslationServer.set_locale(locale)
	Settings.set_and_save_value(SECTION_NAME, "language", locale)


func _on_deadlock_toggled(toggled_on: bool):
	Settings.set_and_save_value(SECTION_NAME, "deadlock", toggled_on)
