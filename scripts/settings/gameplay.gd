extends CenterContainer

@onready var language: OptionButton = $VBox/LanguagePanel/Margin/HBox/OptionButton


func _ready() -> void:
	language.item_selected.connect(_on_language_item_selected)


func _on_language_item_selected(index: int):
	var selected = language.get_item_text(index)
	TranslationServer.set_locale(selected)
