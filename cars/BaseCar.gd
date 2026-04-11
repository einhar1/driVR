extends VehicleBody3D


@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
@export_group("Engine Audio")
## AudioStreamPlayer3D that plays the one-shot engine start-up sound.
@export var startup_player_path: NodePath
## AudioStreamPlayer3D that plays the looping running engine sound.
@export var running_player_path: NodePath
## Forces the startup sound to be treated as this many seconds long. Set to 0 to use the clip's actual length.
@export_range(0.0, 3.0, 0.01) var startup_length_override: float = 0.0
## Minimum speed (km/h) before the engine audio is triggered for the first time.
@export_range(0.0, 50.0, 0.1) var idle_speed_threshold_kmph: float = 2.0
## Speed (km/h) at which the running loop reaches its minimum pitch/volume after the startup sound finishes.
@export_range(0.0, 60.0, 0.1) var fade_in_speed_kmph: float = 6.0
## Speed (km/h) mapped to maximum pitch and volume. Higher values make the engine sound more gradual.
@export_range(0.0, 200.0, 0.1) var max_speed_kmph_for_audio: float = 90.0
## Pitch of the running loop at low speed.
@export_range(0.1, 4.0, 0.01) var running_pitch_min: float = 0.85
## Pitch of the running loop at max speed.
@export_range(0.1, 4.0, 0.01) var running_pitch_max: float = 1.5
## Volume (dB) of the running loop at low speed. Raise toward 0 if the idle engine is too quiet.
@export_range(-80.0, 24.0, 0.1) var running_volume_db_min: float = -24.0
## Volume (dB) of the running loop at max speed. Raise toward 0 to increase overall engine loudness.
@export_range(-80.0, 24.0, 0.1) var running_volume_db_max: float = -4.0
var steer_target: float = 0.0
@onready var auto_driver: Node = get_node_or_null("AutoDriver")
@onready var _speed_label: Label = get_node_or_null("Hud/speed") as Label
@onready var _startup_player: AudioStreamPlayer3D = get_node_or_null(startup_player_path) as AudioStreamPlayer3D
@onready var _running_player: AudioStreamPlayer3D = get_node_or_null(running_player_path) as AudioStreamPlayer3D

var _engine_audio_started: bool = false
var _startup_end_time_msec: int = -1
var _engine_audio_enabled: bool = true


## Applies only the autonomous driving commands required by the quiz experience.
func _physics_process(p_delta: float) -> void:
	var speed: float = linear_velocity.length() * Engine.get_frames_per_second() * p_delta
	traction(speed)
	if _engine_audio_enabled:
		_update_engine_audio(speed)
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


func traction(p_speed: float) -> void:
	apply_central_force(Vector3.DOWN * p_speed)


## Enables or disables engine audio based on whether the player should hear it.
func set_engine_audio_enabled(p_enabled: bool) -> void:
	if _engine_audio_enabled == p_enabled:
		return

	_engine_audio_enabled = p_enabled
	if _engine_audio_enabled:
		return

	_engine_audio_started = false
	_startup_end_time_msec = -1
	if is_instance_valid(_startup_player) and _startup_player.playing:
		_startup_player.stop()
	if is_instance_valid(_running_player):
		if _running_player.playing:
			_running_player.stop()
		_set_running_mix(0.0)


## Updates startup and running engine audio based on vehicle speed.
func _update_engine_audio(p_speed_mps: float) -> void:
	if _running_player == null and _startup_player == null:
		return

	var speed_kmph: float = p_speed_mps * 3.6
	var is_moving: bool = speed_kmph > idle_speed_threshold_kmph

	if is_moving and not _engine_audio_started:
		_start_engine_audio()

	if not _engine_audio_started:
		_set_running_mix(0.0)
		return

	if _startup_end_time_msec > 0 and Time.get_ticks_msec() < _startup_end_time_msec:
		_set_running_mix(0.0)
		return

	var speed_ratio: float = inverse_lerp(fade_in_speed_kmph, max_speed_kmph_for_audio, speed_kmph)
	_set_running_mix(clamp(speed_ratio, 0.0, 1.0))


## Starts the one-shot startup sound and schedules running-loop handoff.
func _start_engine_audio() -> void:
	_engine_audio_started = true

	if is_instance_valid(_startup_player) and _startup_player.stream != null:
		_startup_player.play()
		if startup_length_override > 0.0:
			_startup_end_time_msec = Time.get_ticks_msec() + int(startup_length_override * 1000.0)
		else:
			_startup_end_time_msec = Time.get_ticks_msec() + int(_startup_player.stream.get_length() * 1000.0)
	else:
		_startup_end_time_msec = Time.get_ticks_msec()

	if is_instance_valid(_running_player) and not _running_player.playing:
		_running_player.play()


## Applies pitch and volume to running loop using a normalized ratio.
func _set_running_mix(p_ratio: float) -> void:
	if not is_instance_valid(_running_player):
		return

	var ratio: float = clamp(p_ratio, 0.0, 1.0)
	_running_player.pitch_scale = lerp(running_pitch_min, running_pitch_max, ratio)
	_running_player.volume_db = lerp(running_volume_db_min, running_volume_db_max, ratio)
