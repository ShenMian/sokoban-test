extends Node3D

signal selected
signal unselected
signal hovered
signal unhovered

@onready var level_map: LevelMap = $"../.."

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var area: Area3D = $Area

@onready var hover_indicator: MeshInstance3D = $HoverIndicator
@onready var select_indicator: MeshInstance3D = $SelectIndicator

@export_group("Move Animation")
@export var duration := 0.4
@export var ease_: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.8
@export var indicator_scale_max: float = 1.2

var _is_selected: bool = false
var _is_hovered: bool = false

var _indicator_tween: Tween


func move(direction: Vector3):
	# await get_tree().create_timer(0.35).timeout
	var tween = create_tween().set_ease(ease_).set_trans(transition)
	tween.tween_property(self, "global_position", global_position + direction, duration)
	await tween.finished


func _ready():
	level_map.box_move.connect(self._on_box_move)

	mesh_instance.mesh = mesh_instance.mesh.duplicate(true)
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_area_mouse_entered)
	area.mouse_exited.connect(_on_area_mouse_exited)

	_indicator_tween = create_tween()
	_indicator_tween.set_loops()
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_max, indicator_tween_duration / 2.0)
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_min, indicator_tween_duration / 2.0)
	_indicator_tween.pause()


func _on_box_move(from: Vector2i, to: Vector2i):
	var from_ = Vector3(from.x, 0.0, from.y)
	var to_ = Vector3(to.x, 0.0, to.y)
	if global_position != from_:
		return
	move(to_ - from_)


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
