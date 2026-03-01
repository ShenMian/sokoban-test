extends Node3D
class_name Box

signal selected
signal unselected
signal hovered
signal unhovered
signal move_finished

@onready var level_map: LevelMap = $"../.."
@onready var player: Node3D = $"../../Player"

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var mesh_area: Area3D = $Area
@onready var indicator_area: Area3D = $Indicator/Area

@onready var hover_indicator: MeshInstance3D = $Indicator/HoverIndicator
@onready var select_indicator: MeshInstance3D = $Indicator/SelectIndicator

@export_group("Move Animation")
@export var duration := 0.4
@export var ease_: Tween.EaseType = Tween.EASE_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.8
@export var indicator_scale_max: float = 1.2

var disabled: bool = false:
	set(value):
		if disabled == value:
			return
		disabled = value

		if disabled and _is_selected:
			deselect()
			if _is_hovered:
				_on_area_mouse_exited()

		_apply_disabled()

var _is_selected: bool = false
var _is_hovered: bool = false

var _indicator_tween: Tween


func move(direction: Vector3):
	await create_tween() \
		.set_ease(ease_) \
		.set_trans(transition) \
		.tween_property(self , "global_position", global_position + direction, duration) \
		.finished
	move_finished.emit()


func deselect():
	_is_selected = false
	_apply_indicator()


func grid_position() -> Vector2i:
	return Vector2i(round(global_position.x), round(global_position.z))


func _ready():
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


func _on_area_entered(area: Area3D):
	# Move in the opposite direction when touched by a player
	if area != player.mesh_area:
		return
	move((global_position - player.global_position).normalized())


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_selected = !_is_selected
		_apply_indicator()
		if _is_selected:
			selected.emit()
		else:
			unselected.emit()
		get_viewport().set_input_as_handled()


func _on_area_mouse_entered():
	if disabled:
		return
	_is_hovered = true
	_apply_indicator()
	hovered.emit()


func _on_area_mouse_exited():
	_is_hovered = false
	_apply_indicator()
	unhovered.emit()


func _apply_indicator():
	select_indicator.visible = _is_selected
	hover_indicator.visible = _is_hovered and not _is_selected

	if _is_selected:
		_start_indicator_tween()
	else:
		_stop_indicator_tween()


func _start_indicator_tween():
	_indicator_tween.play()


func _stop_indicator_tween():
	_indicator_tween.pause()
	select_indicator.scale = Vector3.ONE


func _apply_disabled():
	var target_albedo = Color.WHITE.darkened(0.5) if disabled else Color.WHITE
	create_tween().tween_property(mesh_instance, "mesh:surface_0/material:albedo_color", target_albedo, 0.2)
