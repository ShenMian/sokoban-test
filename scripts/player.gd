extends Node3D
class_name Player

signal selected
signal unselected
signal hovered
signal unhovered

@onready var meshes: Node3D = $Meshes
@onready var area: Area3D = $Meshes/Area
@onready var animation_tree: AnimationTree = $AnimationTree

@export_group("Move Animation")
@export var move_duration := 0.5
@export var move_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var move_transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Rotate Animation")
@export var rotate_duration := 0.1
@export var rotate_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var rotate_transition: Tween.TransitionType = Tween.TRANS_LINEAR

var _is_selected: bool = false
var _is_hovered: bool = false

var _is_walking: bool = false


func _ready():
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_area_mouse_entered)
	area.mouse_exited.connect(_on_area_mouse_exited)


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_selected = !_is_selected
		if _is_selected:
			selected.emit()
		else:
			unselected.emit()


func _on_area_mouse_entered():
	_is_hovered = true
	hovered.emit()


func _on_area_mouse_exited():
	_is_hovered = false
	unhovered.emit()


func _input(_event: InputEvent):
	if not _is_walking:
		if Input.is_action_just_pressed("move_right"):
			_move(Vector3.RIGHT)
		elif Input.is_action_just_pressed("move_left"):
			_move(Vector3.LEFT)
		elif Input.is_action_just_pressed("move_up"):
			_move(Vector3.MODEL_REAR)
		elif Input.is_action_just_pressed("move_down"):
			_move(Vector3.MODEL_FRONT)


func _move(direction: Vector3):
	_is_walking = true

	var target_rotation: float
	match direction:
		Vector3.RIGHT:
			target_rotation = 90.0
		Vector3.LEFT:
			target_rotation = -90.0
		Vector3.MODEL_REAR:
			target_rotation = 180.0
		Vector3.MODEL_FRONT:
			target_rotation = 0.0
		_:
			assert(false)
	# Constrain rotation angle to [-180°, 180°] to prevent long-way-around turns
	var delta := fposmod(target_rotation - meshes.rotation_degrees.y + 180.0, 360.0) - 180.0
	target_rotation = meshes.rotation_degrees.y + delta

	var rotate_tween = create_tween().set_ease(rotate_ease).set_trans(rotate_transition)
	rotate_tween.tween_property(meshes, "rotation_degrees:y", target_rotation, rotate_duration)
	await rotate_tween.finished

	animation_tree["parameters/playback"].travel("Walking")

	var target_position := global_position + direction
	var translate_tween = create_tween().set_ease(move_ease).set_trans(move_transition)
	translate_tween.tween_property(self, "global_position", target_position, move_duration)
	await translate_tween.finished

	animation_tree["parameters/playback"].travel("Static")

	_is_walking = false
