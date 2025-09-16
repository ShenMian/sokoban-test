extends CenterContainer

@onready var language: OptionButton = $VBox/LanguagePanel/Margin/HBox/OptionButton

const LOCALE_TO_NAME = {
	"en": "English",
	"zh": "中文"
}


func _ready() -> void:
	var locales = TranslationServer.get_loaded_locales()
	for i in range(locales.size()):
		var locale = locales[i]
		language.add_item(LOCALE_TO_NAME[locale])
		language.set_item_metadata(i, locale)

	language.item_selected.connect(_on_language_item_selected)


func _on_language_item_selected(index: int):
	var selected := str(language.get_item_metadata(index))
	TranslationServer.set_locale(selected)
