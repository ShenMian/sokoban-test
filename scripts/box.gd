class_name Box
extends Node3D

signal selected
signal unselected
signal hovered
signal unhovered
signal move_finished

@export_group("Move Animation")
@export var duration: float = 0.4
@export var ease_: Tween.EaseType = Tween.EASE_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.8
@export var indicator_scale_max: float = 1.2

@export_group("", "")
@export var selectable: bool = true:
	set(value):
		selectable = value
		_apply_selectable()

@export var disabled: bool = false:
	set(value):
		if disabled == value:
			return
		disabled = value
		selectable = not value
		_apply_disabled()

var _is_selected: bool = false
var _is_hovered: bool = false
var _indicator_tween: Tween

@onready var level_map: LevelMap = $"../.."
@onready var player: Node3D = $"../../Player"
@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var mesh_area: Area3D = $Area
@onready var indicator_area: Area3D = $Indicator/Area
@onready var hover_indicator: MeshInstance3D = $Indicator/HoverIndicator
@onready var select_indicator: MeshInstance3D = $Indicator/SelectIndicator


func _ready() -> void:
	mesh_area.area_entered.connect(_on_area_entered)

	mesh_instance.mesh = mesh_instance.mesh.duplicate(true)
	mesh_area.input_event.connect(_on_area_input_event)
	mesh_area.mouse_entered.connect(_on_area_mouse_entered)
	mesh_area.mouse_exited.connect(_on_area_mouse_exited)
	indicator_area.input_event.connect(_on_area_input_event)
	indicator_area.mouse_entered.connect(_on_area_mouse_entered)
	indicator_area.mouse_exited.connect(_on_area_mouse_exited)

	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_max, indicator_tween_duration / 2.0)
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_min, indicator_tween_duration / 2.0)
	_indicator_tween.pause()

	if disabled:
		_apply_disabled()

	if not selectable:
		_apply_selectable()


func move(direction: Vector3) -> void:
	await create_tween() \
		.set_ease(ease_) \
		.set_trans(transition) \
		.tween_property(self , "global_position", global_position + direction, duration) \
		.finished
	move_finished.emit()


func deselect() -> void:
	_is_selected = false
	_apply_indicator()


func grid_position() -> Vector2i:
	return Vector2i(round(global_position.x), round(global_position.z))


func _on_area_entered(area: Area3D) -> void:
	# Move in the opposite direction when touched by a player
	if area != player.mesh_area:
		return
	move((global_position - player.global_position).normalized())


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_selected = not _is_selected
		_apply_indicator()
		if _is_selected:
			selected.emit()
		else:
			unselected.emit()
		get_viewport().set_input_as_handled()


func _on_area_mouse_entered() -> void:
	_is_hovered = true
	_apply_indicator()
	hovered.emit()


func _on_area_mouse_exited() -> void:
	_is_hovered = false
	_apply_indicator()
	unhovered.emit()


func _apply_indicator() -> void:
	select_indicator.visible = _is_selected
	hover_indicator.visible = _is_hovered and not _is_selected

	if _is_selected:
		_start_indicator_tween()
	else:
		_stop_indicator_tween()


func _start_indicator_tween() -> void:
	_indicator_tween.play()


func _stop_indicator_tween() -> void:
	_indicator_tween.pause()
	select_indicator.scale = Vector3.ONE


func _apply_disabled() -> void:
	var target_albedo := Color.WHITE.darkened(0.5) if disabled else Color.WHITE
	create_tween().tween_property(mesh_instance, "mesh:surface_0/material:albedo_color", target_albedo, 0.2)


func _apply_selectable() -> void:
	if not is_node_ready():
		return

	if not selectable:
		mesh_area.input_ray_pickable = false
		indicator_area.input_ray_pickable = false

		if _is_selected:
			deselect()
		if _is_hovered:
			_on_area_mouse_exited()
	else:
		mesh_area.input_ray_pickable = true
		indicator_area.input_ray_pickable = true
