extends Node3D

signal selected
signal unselected
signal hovered
signal unhovered

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var area: Area3D = $Mesh/Area

@export var selected_outline_color: Color = Color.GREEN
@export var hovered_outline_color: Color = Color.WHITE
@export var outline_thickness: float = 0.1

var is_selected: bool = false
var is_hovered: bool = false


func _ready():
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_area_mouse_entered)
	area.mouse_exited.connect(_on_area_mouse_exited)


func _input(_event: InputEvent):
	if is_selected:
		_hightlight(selected_outline_color)
	elif is_hovered:
		_hightlight(hovered_outline_color)
	else:
		_unhighlight()


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_selected = !is_selected
		if is_selected:
			selected.emit()
		else:
			unselected.emit()


func _on_area_mouse_entered():
	is_hovered = true
	hovered.emit()


func _on_area_mouse_exited():
	is_hovered = false
	unhovered.emit()


func _hightlight(color: Color):
	mesh_instance.mesh.material.next_pass["shader_parameter/thickness"] = outline_thickness
	mesh_instance.mesh.material.next_pass["shader_parameter/color"] = color


func _unhighlight():
	mesh_instance.mesh.material.next_pass["shader_parameter/thickness"] = 0.0
