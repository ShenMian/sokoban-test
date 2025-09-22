extends Node3D
class_name Player

signal selected
signal unselected
signal hovered
signal unhovered

@onready var level_map: LevelMap = $".."

@onready var meshes: Node3D = $Meshes
@onready var mesh_area: Area3D = $Meshes/Area
@onready var indicator_area: Area3D = $Indicator/Area
@onready var idle_timer: Timer = $IdleTimer
@onready var state_machine = $AnimationTree["parameters/playback"]

@onready var hover_indicator: MeshInstance3D = $Indicator/HoverIndicator
@onready var select_indicator: MeshInstance3D = $Indicator/SelectIndicator

@export_group("Move Animation")
@export var move_duration := 0.4
@export var move_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var move_transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Rotate Animation")
@export var rotate_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var rotate_transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.8
@export var indicator_scale_max: float = 1.2

var _is_selected: bool = false
var _is_hovered: bool = false

var _is_moving: bool = false

var _indicator_tween: Tween


func move(direction: Vector3, is_pushing: bool):
	if direction == Vector3.ZERO:
		state_machine.travel("EmoteNo")
		return

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
			assert(false, "unreachable")
	# Constrain rotation angle to [-180°, 180°] to prevent long-way-around turns
	var delta := fposmod(target_rotation - meshes.rotation_degrees.y + 180.0, 360.0) - 180.0
	target_rotation = meshes.rotation_degrees.y + delta

	_is_moving = true
	if meshes.rotation_degrees.y != target_rotation:
		var duration = abs(meshes.rotation_degrees.y - target_rotation) / 90.0 * 0.1
		await create_tween() \
			.set_ease(rotate_ease) \
			.set_trans(rotate_transition) \
			.tween_property(meshes, "rotation_degrees:y", target_rotation, duration) \
			.finished

	if is_pushing:
		state_machine.travel("Pushing")
	else:
		state_machine.travel("Walking")

	await create_tween() \
		.set_ease(move_ease) \
		.set_trans(move_transition) \
		.tween_property(self, "global_position", global_position + direction, move_duration) \
		.finished

	state_machine.travel("Static")
	_is_moving = false


func _ready():
	level_map.player_move.connect(_on_player_move)
	idle_timer.timeout.connect(_idle_timer_timeout)

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


func _process(_delta: float):
	if not _is_moving:
		if Input.is_action_pressed("move_right"):
			level_map.move_by(level_map.Direction.Right)
		elif Input.is_action_pressed("move_left"):
			level_map.move_by(level_map.Direction.Left)
		elif Input.is_action_pressed("move_up"):
			level_map.move_by(level_map.Direction.Up)
		elif Input.is_action_pressed("move_down"):
			level_map.move_by(level_map.Direction.Down)


func _on_player_move(to: Vector2i, is_pushing: bool):
	var to_ = Vector3(to.x, 0.0, to.y)
	move(to_ - global_position, is_pushing)


func _idle_timer_timeout():
	if state_machine.get_current_node() == "Static":
		state_machine.travel("Idle")
	idle_timer.start()


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
