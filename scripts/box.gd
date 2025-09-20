extends Node3D

signal selected
signal unselected
signal hovered
signal unhovered

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var area: Area3D = $Area

@onready var hover_indicator: MeshInstance3D = $HoverIndicator
@onready var select_indicator: MeshInstance3D = $SelectIndicator

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.8
@export var indicator_scale_max: float = 1.2

var _is_selected: bool = false
var _is_hovered: bool = false

var _indicator_tween: Tween


func _ready():
	mesh_instance.mesh = mesh_instance.mesh.duplicate(true)
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_area_mouse_entered)
	area.mouse_exited.connect(_on_area_mouse_exited)

	_indicator_tween = create_tween()
	_indicator_tween.set_loops()
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_max, indicator_tween_duration / 2.0)
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_min, indicator_tween_duration / 2.0)
	_indicator_tween.pause()


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_selected = !_is_selected
		_apply_indicator()
		if _is_selected:
			selected.emit()
		else:
			unselected.emit()


func _on_area_mouse_entered():
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
