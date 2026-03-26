extends VehicleBody3D


@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
var steer_target: float = 0.0
@onready var auto_driver: Node = get_node_or_null("AutoDriver")
@onready var _speed_label: Label = get_node_or_null("Hud/speed") as Label


## Applies only the autonomous driving commands required by the quiz experience.
func _physics_process(p_delta: float) -> void:
	var speed: float = linear_velocity.length() * Engine.get_frames_per_second() * p_delta
	traction(speed)
	if is_instance_valid(_speed_label):
		_speed_label.text = str(round(speed * 3.6)) + " KMPH"

	if auto_driver and auto_driver.auto_drive_enabled:
		_apply_auto_drive(p_delta)
		return

	engine_force = 0.0
	brake = 0.0
	steering = move_toward(steering, 0.0, STEER_SPEED * p_delta)


## Applies steering, throttle, and braking from the AutoDriver child node.
func _apply_auto_drive(p_delta: float) -> void:
	var auto_steer_target: float = clamp(float(auto_driver.steering_command), -STEER_LIMIT, STEER_LIMIT)
	steering = move_toward(steering, auto_steer_target, STEER_SPEED * p_delta)
	engine_force = float(auto_driver.engine_force_command)
	brake = clamp(float(auto_driver.brake_command), 0.0, 3.0)
	$wheal2.wheel_friction_slip = 3
	$wheal3.wheel_friction_slip = 3


func traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * speed)
