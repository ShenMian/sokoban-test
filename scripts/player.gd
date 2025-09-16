extends Node3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var area: Area3D = $Mesh/Area

@export var outline_thickness: float = 0.1


func _ready():
	area.mouse_entered.connect(_on_area_mouse_entered)
	area.mouse_exited.connect(_on_area_mouse_exited)
	pass


func _on_area_mouse_entered():
	mesh_instance.mesh.material.next_pass["shader_parameter/thickness"] = outline_thickness


func _on_area_mouse_exited():
	mesh_instance.mesh.material.next_pass["shader_parameter/thickness"] = 0.0
