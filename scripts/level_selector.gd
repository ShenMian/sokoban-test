extends Control

@onready var collection_list: ItemList = $MarginContainer/HSplit/CollectionList
@onready var level_list: ItemList = $MarginContainer/HSplit/LevelList

@export var level_item_min_width: int = 100

var start_item_index: int
var end_item_index: int


func _ready():
	collection_list.item_clicked.connect(_on_collection_list_clicked)
	level_list.resized.connect(_on_level_list_resized)
	for i in range(1000):
		var placeholder = PlaceholderTexture2D.new()
		level_list.add_item(str(i + 1), placeholder, true)


func _process(_delta: float):
	var style_box = level_list.get_theme_stylebox("panel")
	var start = level_list.get_item_at_position(Vector2(style_box.get_margin(SIDE_LEFT), style_box.get_margin(SIDE_TOP)), true)
	var end = level_list.get_item_at_position(level_list.size - Vector2(style_box.get_margin(SIDE_RIGHT), style_box.get_margin(SIDE_BOTTOM) + 1.0), true)

	if start == start_item_index and end == -1:
		end = level_list.get_item_count() - 1
	if start == start_item_index and end == end_item_index:
		return
	start_item_index = start
	end_item_index = end

	for i in range(start, end + 1):
		var icon = load("res://assets/icon.svg")
		level_list.set_item_icon(i, icon)


func _on_collection_list_clicked(index: int, _at_position: Vector2, _mouse_button_index: int):
	print("Collection %d clicked" % index)
	# TODO


func _on_level_list_resized():
	var content_width = get_content_width(level_list)
	var h_separation = level_list.get_theme_constant("h_separation")

	var items_per_row = int(content_width / level_item_min_width)
	var item_width = content_width / items_per_row - h_separation

	level_list.max_columns = items_per_row
	level_list.set_fixed_column_width(item_width)
	level_list.set_fixed_icon_size(Vector2(item_width, item_width))


func get_content_width(item_list: ItemList) -> float:
	var width = item_list.size.x

	# Subtract left and right margins
	var style_box = item_list.get_theme_stylebox("panel")
	if style_box:
		width -= style_box.get_margin(SIDE_LEFT) + style_box.get_margin(SIDE_RIGHT)

	# Subtract scrollbar width
	var v_scroll_bar = item_list.get_v_scroll_bar()
	width -= v_scroll_bar.size.x

	return width
