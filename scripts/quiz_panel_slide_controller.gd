extends Node

## Slides the quiz panel sideways when the persistent car begins auto-driving.
## The panel itself remains in world space; [QuestionSceneRunner] is still free to
## reposition it between questions.

@export_group("Dependencies")
@export var panel_path: NodePath = ^".."
@export var car_path: NodePath = ^"../../car"
@export var auto_driver_path: NodePath = ^"../../car/AutoDriver"

@export_group("Slide")
@export_range(0.0, 5.0, 0.05) var slide_distance: float = 1.8
@export_range(0.05, 3.0, 0.05) var slide_duration: float = 0.35
@export var use_panel_left_direction: bool = true

var _panel: Node3D = null
var _car: Node3D = null
var _auto_driver: Node = null
var _slide_tween: Tween = null


func _ready() -> void:
	_panel = get_node_or_null(panel_path) as Node3D
	_car = get_node_or_null(car_path) as Node3D
	_auto_driver = get_node_or_null(auto_driver_path)

	if not is_instance_valid(_panel):
		push_warning("quiz_panel_slide_controller: Panel not found at '%s'" % String(panel_path))
		return

	if not is_instance_valid(_auto_driver):
		push_warning("quiz_panel_slide_controller: AutoDriver not found at '%s'" % String(auto_driver_path))
		return

	if not _auto_driver.auto_drive_started.is_connected(_on_auto_drive_started):
		_auto_driver.auto_drive_started.connect(_on_auto_drive_started)


## Slides the panel sideways from its current world position when auto-drive starts.
func _on_auto_drive_started() -> void:
	if _slide_tween != null:
		_slide_tween.kill()

	var slide_direction: Vector3 = _get_slide_direction()
	if slide_direction.length_squared() <= 0.0001:
		return

	var target_position: Vector3 = _panel.global_position + slide_direction * slide_distance
	_slide_tween = _panel.create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_panel, "global_position", target_position, slide_duration)


func _get_slide_direction() -> Vector3:
	if use_panel_left_direction:
		return -_panel.global_transform.basis.x.normalized()

	if is_instance_valid(_car):
		return -_car.global_transform.basis.x.normalized()

	return -_panel.global_transform.basis.x.normalized()
