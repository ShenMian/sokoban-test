extends Control

@onready var collection_list: ItemList = $MarginContainer/HSplit/CollectionList
@onready var level_list: ItemList = $MarginContainer/HSplit/LevelList

@export var level_item_min_width: int = 150

@export var preview_placeholder: GradientTexture2D

var _start_item_index: int
var _end_item_index: int

var _levels: Array[Dictionary] = []
var _generated_previews: Array[int] = []

var _preview_generator: LevelPreviewGenerator

var _selected_collection: String


func _ready():
	collection_list.item_clicked.connect(_on_collection_list_clicked)
	level_list.item_clicked.connect(_on_level_clicked)
	level_list.resized.connect(_on_level_list_resized)

	# Setup the level preview generator
	_preview_generator = LevelPreviewGenerator.new()
	_preview_generator.preview_generated.connect(_on_preview_generated)
	add_child(_preview_generator)

	_load_collections()
	assert(collection_list.item_count > 0)

	collection_list.select(0)
	_on_collection_list_clicked(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)


func _load_collections():
	collection_list.clear()
	var files = DirAccess.get_files_at(Settings.LEVEL_PATH)
	assert(files)
	for file in files:
		if file.ends_with(".xsb"):
			var collection_name = file.trim_suffix(".xsb")
			collection_list.add_item(collection_name)


func _process(_delta: float):
	var style_box = level_list.get_theme_stylebox("panel")
	var start = level_list.get_item_at_position(Vector2(style_box.get_margin(SIDE_LEFT), style_box.get_margin(SIDE_TOP)), true)
	var end = level_list.get_item_at_position(level_list.size - Vector2(style_box.get_margin(SIDE_RIGHT), style_box.get_margin(SIDE_BOTTOM) + 1.0), true)

	if start == -1:
		# No items are visible
		return
	if end == -1:
		end = level_list.get_item_count() - 1
	if start == _start_item_index and end == _end_item_index:
		return
	_start_item_index = start
	_end_item_index = end

	var cache_items = level_list.max_columns * 2

	# Submits preview rendering tasks
	var queue: Array[int] = []
	for i in range(start - cache_items, end + cache_items + 1):
		if i >= 0 and i < _levels.size():
			if not _generated_previews.has(i):
				queue.append(i)
	_preview_generator.submit_queue(queue)

	# Frees distant preview textures
	for i in range(_generated_previews.size() - 1, -1, -1):
		var idx: int = _generated_previews[i]
		if idx < start - cache_items or idx > end + cache_items:
			_generated_previews.remove_at(i)
			level_list.set_item_icon(idx, preview_placeholder)


func _on_preview_generated(index: int, texture: Texture2D):
	assert(not _generated_previews.has(index))
	_generated_previews.append(index)
	level_list.set_item_icon(index, texture)


func _on_collection_list_clicked(index: int, _at_position: Vector2, mouse_button_index: int):
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	_selected_collection = collection_list.get_item_text(index)
	_load_levels(Settings.LEVEL_PATH + _selected_collection + ".xsb")


func _load_levels(path: String):
	level_list.clear()
	_levels.clear()
	_generated_previews.clear()
	_start_item_index = -1
	_end_item_index = -1

	var full_path := ProjectSettings.globalize_path(path)
	_levels = Array(LevelMap.load_collection(full_path), TYPE_DICTIONARY, "", null)
	_preview_generator.set_levels(_levels)

	for idx in range(_levels.size()):
		var label = str(idx + 1)
		level_list.add_item(label, preview_placeholder, true)
		level_list.set_item_tooltip(idx, _make_tooltip(idx, _levels[idx]))


func _make_tooltip(index: int, data: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("#%d" % (index + 1))
	for key: String in data.keys():
		if key == "map" or key == "comments":
			continue
		lines.append("%s: %s" % [key.capitalize(), data[key]])
	if data.has("comments"):
		var comment: String = data["comments"]
		if comment.length() > 100:
			comment = comment.left(100 - 1) + "…"
		lines.append("")
		lines.append(comment)
	return "\n".join(lines)


func _on_level_clicked(index: int, _at_position: Vector2, mouse_button_index: int):
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	Settings.selected_collection = _selected_collection
	Settings.selected_level_index = index
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _on_level_list_resized():
	var content_width := _get_content_width(level_list)
	var h_separation := level_list.get_theme_constant("h_separation")

	var items_per_row := int(content_width / level_item_min_width)
	assert(items_per_row >= 0)
	var item_width := int(content_width / items_per_row - h_separation)

	level_list.max_columns = items_per_row
	level_list.set_fixed_column_width(item_width)
	level_list.set_fixed_icon_size(Vector2(item_width, item_width))
	preview_placeholder.width = item_width
	preview_placeholder.height = item_width


func _get_content_width(item_list: ItemList) -> float:
	var width = item_list.size.x

	# Subtract left and right margins
	var style_box = item_list.get_theme_stylebox("panel")
	if style_box:
		width -= style_box.get_margin(SIDE_LEFT) + style_box.get_margin(SIDE_RIGHT)

	# Subtract scrollbar width
	var v_scroll_bar = item_list.get_v_scroll_bar()
	width -= v_scroll_bar.size.x

	return width
