extends VehicleBody3D


@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
var steer_target: float = 0.0
@export var engine_force_value: float = 40.0
@onready var auto_driver: Node = get_node_or_null("AutoDriver")


func _physics_process(delta: float) -> void:
	var speed: float = linear_velocity.length() * Engine.get_frames_per_second() * delta
	traction(speed)
	$Hud/speed.text = str(round(speed * 3.8)) + "  KMPH"

	if auto_driver and auto_driver.auto_drive_enabled:
		_apply_auto_drive(delta)
		return

	var fwd_mps: float = transform.basis.x.x
	steer_target = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	steer_target *= STEER_LIMIT
	if Input.is_action_pressed("ui_down"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		if speed < 20 and speed != 0:
			engine_force = clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = engine_force_value
	else:
		engine_force = 0
	if Input.is_action_pressed("ui_up"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		if fwd_mps >= -1:
			if speed < 30 and speed != 0:
				engine_force = - clamp(engine_force_value * 10 / speed, 0, 300)
			else:
				engine_force = - engine_force_value
		else:
			brake = 1
	else:
		brake = 0.0
		
	if Input.is_action_pressed("ui_select"):
		brake = 3
		$wheal2.wheel_friction_slip = 0.8
		$wheal3.wheel_friction_slip = 0.8
	else:
		$wheal2.wheel_friction_slip = 3
		$wheal3.wheel_friction_slip = 3
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


func _apply_auto_drive(delta: float) -> void:
	var auto_steer_target: float = clamp(float(auto_driver.steering_command), -STEER_LIMIT, STEER_LIMIT)
	steering = move_toward(steering, auto_steer_target, STEER_SPEED * delta)
	engine_force = float(auto_driver.engine_force_command)
	brake = clamp(float(auto_driver.brake_command), 0.0, 3.0)
	$wheal2.wheel_friction_slip = 3
	$wheal3.wheel_friction_slip = 3


func traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * speed)
