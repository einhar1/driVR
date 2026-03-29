extends Node

## Reference to the car (parent of this script)
@export var car: VehicleBody3D
## Reference to the RoadLaneAgent
@onready var lane_agent: RoadLaneAgent = get_parent().get_node("RoadLaneAgent") as RoadLaneAgent

## Emitted when the car reaches its distance target and comes to a full stop.
signal auto_drive_completed

## Auto-drive settings
@export var auto_drive_speed: float = 15.0
@export var auto_drive_enabled: bool = false
@export var total_distance_target: float = 5.0

@export_group("Lane Guidance")
@export_range(0.5, 30.0, 0.1) var lookahead_distance: float = 7.5
@export_range(0.0, 2.0, 0.05) var speed_lookahead_gain: float = 0.3
@export_range(0.1, 8.0, 0.05) var steering_gain: float = 0.7
@export_range(0.1, 6.0, 0.05) var steering_response_speed: float = 1.6
@export_range(0.05, 1.0, 0.01) var max_steering_command: float = 0.28
@export_range(0.0, 60.0, 0.1) var high_speed_reference: float = 18.0
@export_range(0.1, 1.0, 0.01) var high_speed_steering_scale: float = 0.5

@export_group("Speed Control")
@export_range(0.0, 500.0, 1.0) var max_engine_force_command: float = 40.0
@export_range(0.0, 3.0, 0.05) var max_brake_command: float = 3.0
@export_range(0.05, 50.0, 0.05) var engine_proportional_gain: float = 8.0
@export_range(0.05, 5.0, 0.05) var brake_proportional_gain: float = 0.45
@export_range(0.1, 12.0, 0.1) var comfortable_deceleration: float = 3.0
@export_range(0.0, 10.0, 0.1) var braking_begin_distance: float = 6.0
@export_range(0.0, 2.0, 0.05) var stop_hold_brake: float = 0.9
@export_range(0.05, 4.0, 0.05) var stop_complete_speed: float = 0.3
@export_range(0.0, 3.0, 0.05) var startup_ramp_seconds: float = 0.45
@export_range(0.1, 250.0, 0.1) var engine_ramp_rate: float = 80.0
@export_range(0.1, 20.0, 0.1) var brake_ramp_rate: float = 6.0

@export_group("Direction Calibration")
@export var invert_engine_direction: bool = true
@export var invert_steering_direction: bool = false

@export_group("Lane Selection")
@export var lock_lane_family: bool = true
@export_range(-1.0, 1.0, 0.01) var lane_alignment_dot_threshold: float = 0.1
@export_range(0.1, 3.0, 0.1) var lane_direction_sample_distance: float = 0.8
@export_range(0.0, 10.0, 0.1) var lane_offset_reacquire_distance: float = 2.0

var total_distance_traveled: float = 0.0
var steering_command: float = 0.0
var engine_force_command: float = 0.0
var brake_command: float = 0.0

var _is_ready_for_drive: bool = false
var _is_stopping: bool = false
var _startup_elapsed: float = 0.0
var _preferred_lane_family: String = ""
var _tracked_lane: RoadLane = null
var _tracked_lane_offset: float = 0.0
var _next_lane_override: RoadLane = null
var _outcome_lane_entered: bool = false
var _stop_target: Vector3 = Vector3.ZERO
var _use_stop_target: bool = false

const MAX_ASSIGN_RETRIES: int = 120
const NEAREST_LANE_SEARCH_DISTANCE: float = 250.0
const FAR_REMAINING_DISTANCE: float = 1000.0


func _refresh_road_manager_path() -> void:
	var main_scene: Node = get_tree().current_scene
	if not is_instance_valid(main_scene) or not is_instance_valid(lane_agent):
		return

	var road_manager: Node = main_scene.get_node_or_null("RoadManager")
	if not is_instance_valid(road_manager):
		road_manager = main_scene.get_node_or_null("DefaultEnvironment/RoadManager")

	if is_instance_valid(road_manager):
		lane_agent.road_manager_path = lane_agent.get_path_to(road_manager)


## Try to assign the car to the nearest lane.
func _try_assign_lane() -> bool:
	if not is_instance_valid(car) or not is_instance_valid(lane_agent):
		return false

	var car_forward: Vector3 = _get_car_forward_flat()
	var best_lane: RoadLane = _find_best_lane_for_position(car.global_position, car_forward)
	if is_instance_valid(best_lane):
		lane_agent.assign_lane(best_lane)
		_set_tracked_lane(best_lane)
		if lock_lane_family and _preferred_lane_family.is_empty():
			_preferred_lane_family = _lane_family_of(best_lane)
		return is_instance_valid(lane_agent.current_lane)

	var nearest_lane: RoadLane = lane_agent.find_nearest_lane(car.global_position, NEAREST_LANE_SEARCH_DISTANCE)
	if is_instance_valid(nearest_lane):
		lane_agent.assign_lane(nearest_lane)
		_set_tracked_lane(nearest_lane)
		if lock_lane_family and _preferred_lane_family.is_empty():
			_preferred_lane_family = _lane_family_of(nearest_lane)
		return is_instance_valid(lane_agent.current_lane)

	return false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame

	if not car:
		car = get_parent() as VehicleBody3D

	if not is_instance_valid(lane_agent):
		push_error("RoadLaneAgent node missing under car")
		return

	_refresh_road_manager_path()

	var try_count: int = 0
	while try_count < MAX_ASSIGN_RETRIES:
		if _is_ready_for_drive:
			break
		if _try_assign_lane():
			_is_ready_for_drive = true
			break
		try_count += 1
		await get_tree().physics_frame

	if not _is_ready_for_drive:
		push_warning("Failed to assign car to nearest lane during startup. Will retry on auto-drive start.")


func _get_car_forward_flat() -> Vector3:
	var forward: Vector3 = - car.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _lane_family_of(p_lane: RoadLane) -> String:
	if not is_instance_valid(p_lane):
		return ""
	var lane_tag: String = p_lane.lane_next_tag if not p_lane.lane_next_tag.is_empty() else p_lane.lane_prior_tag
	if lane_tag.is_empty():
		return ""
	return lane_tag.substr(0, 1)


func _lane_forward_at_position(p_lane: RoadLane, p_world_position: Vector3) -> Vector3:
	if not is_instance_valid(p_lane):
		return Vector3.ZERO
	var lane_length: float = p_lane.curve.get_baked_length()
	if lane_length <= 0.01:
		return Vector3.ZERO

	var local_position: Vector3 = p_lane.to_local(p_world_position)
	var closest_offset: float = p_lane.curve.get_closest_offset(local_position)
	var sample_a: Vector3 = p_lane.curve.sample_baked(closest_offset)
	var sample_b_offset: float = min(closest_offset + lane_direction_sample_distance, lane_length)
	if is_equal_approx(sample_b_offset, closest_offset):
		sample_b_offset = max(closest_offset - lane_direction_sample_distance, 0.0)
	var sample_b: Vector3 = p_lane.curve.sample_baked(sample_b_offset)
	var lane_forward_world: Vector3 = p_lane.to_global(sample_b) - p_lane.to_global(sample_a)
	lane_forward_world.y = 0.0
	if lane_forward_world.length_squared() <= 0.0001:
		return Vector3.ZERO
	return lane_forward_world.normalized()


func _find_best_lane_for_position(
	p_position: Vector3,
	p_forward: Vector3,
	p_exclude_lane: RoadLane = null,
) -> RoadLane:
	if not is_instance_valid(lane_agent.road_manager):
		return null

	var candidates: Array[RoadLane] = []
	var containers: Array = lane_agent.road_manager.get_containers()
	var groups_checked: Array[String] = []
	var manager_group: String = lane_agent.road_manager.ai_lane_group
	if not manager_group.is_empty():
		groups_checked.append(manager_group)

	for container in containers:
		if not is_instance_valid(container):
			continue
		var group_name: String = String(container.ai_lane_group)
		if group_name.is_empty() or group_name in groups_checked:
			continue
		groups_checked.append(group_name)

	for group_name in groups_checked:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is RoadLane and is_instance_valid(node):
				candidates.append(node as RoadLane)

	var best_lane: RoadLane = null
	var best_score: float = INF
	for lane in candidates:
		if is_instance_valid(p_exclude_lane) and lane == p_exclude_lane:
			continue

		var lane_point: Vector3 = lane_agent.get_closest_path_point(lane, p_position)
		var lane_distance: float = p_position.distance_to(lane_point)
		if lane_distance > NEAREST_LANE_SEARCH_DISTANCE:
			continue

		var lane_forward: Vector3 = _lane_forward_at_position(lane, p_position)
		if lane_forward == Vector3.ZERO:
			continue

		var alignment: float = lane_forward.dot(p_forward)
		if alignment < lane_alignment_dot_threshold:
			continue

		if lock_lane_family and not _preferred_lane_family.is_empty():
			var family: String = _lane_family_of(lane)
			if not family.is_empty() and family != _preferred_lane_family:
				continue

		var score: float = lane_distance + (1.0 - alignment) * 4.0
		if score < best_score:
			best_score = score
			best_lane = lane

	if is_instance_valid(best_lane):
		return best_lane

	return lane_agent.find_nearest_lane(p_position, NEAREST_LANE_SEARCH_DISTANCE)


func _set_tracked_lane(p_lane: RoadLane) -> void:
	if not is_instance_valid(p_lane):
		_tracked_lane = null
		_tracked_lane_offset = 0.0
		return

	_tracked_lane = p_lane
	var local_position: Vector3 = p_lane.to_local(car.global_position)
	_tracked_lane_offset = p_lane.curve.get_closest_offset(local_position)


func _update_lane_progress(p_forward_step: float) -> void:
	if not is_instance_valid(lane_agent.current_lane):
		return

	if _tracked_lane != lane_agent.current_lane or not is_instance_valid(_tracked_lane):
		_set_tracked_lane(lane_agent.current_lane)

	var lane_length: float = _tracked_lane.curve.get_baked_length()
	if lane_length <= 0.01:
		return

	var local_position: Vector3 = _tracked_lane.to_local(car.global_position)
	var closest_offset: float = _tracked_lane.curve.get_closest_offset(local_position)
	if absf(closest_offset - _tracked_lane_offset) > lane_offset_reacquire_distance:
		_tracked_lane_offset = closest_offset

	_tracked_lane_offset += p_forward_step
	while _tracked_lane_offset > lane_length:
		var next_lane: RoadLane = _get_next_lane(_tracked_lane)
		if not is_instance_valid(next_lane):
			_tracked_lane_offset = lane_length
			return
		var prev_name: String = str(_tracked_lane.name) if is_instance_valid(_tracked_lane) else "null"
		if _next_lane_override == next_lane:
			_outcome_lane_entered = true
			_next_lane_override = null
			print("[AutoDriver] Override consumed — entered lane '%s' (from '%s')" % [next_lane.name, prev_name])
		else:
			print("[AutoDriver] Lane transition: '%s' → '%s'" % [prev_name, next_lane.name])
		_tracked_lane_offset -= lane_length
		lane_agent.assign_lane(next_lane)
		_set_tracked_lane(next_lane)
		lane_length = _tracked_lane.curve.get_baked_length()
		if lane_length <= 0.01:
			return


func _sample_target_point(p_lookahead: float) -> Vector3:
	if not is_instance_valid(_tracked_lane):
		return car.global_position

	var sample_lane: RoadLane = _tracked_lane
	var sample_offset: float = _tracked_lane_offset + p_lookahead
	var lane_length: float = sample_lane.curve.get_baked_length()
	if lane_length <= 0.01:
		return car.global_position

	while sample_offset > lane_length:
		var next_lane: RoadLane
		if sample_lane == _tracked_lane and is_instance_valid(_next_lane_override):
			next_lane = _next_lane_override
		else:
			next_lane = sample_lane.get_node_or_null(sample_lane.lane_next) as RoadLane
		if not is_instance_valid(next_lane):
			# Extrapolate past the lane end in the lane's exit direction
			var overshoot: float = sample_offset - lane_length
			var end_pt: Vector3 = sample_lane.to_global(
				sample_lane.curve.sample_baked(lane_length)
			)
			var near_end_pt: Vector3 = sample_lane.to_global(
				sample_lane.curve.sample_baked(max(lane_length - 1.0, 0.0))
			)
			var exit_dir: Vector3 = (end_pt - near_end_pt).normalized()
			if exit_dir.length_squared() < 0.001:
				return end_pt
			return end_pt + exit_dir * overshoot
		sample_offset -= lane_length
		sample_lane = next_lane
		lane_length = sample_lane.curve.get_baked_length()
		if lane_length <= 0.01:
			return car.global_position

	var local_sample: Vector3 = sample_lane.curve.sample_baked(clamp(sample_offset, 0.0, lane_length))
	return sample_lane.to_global(local_sample)

func _physics_process(delta: float) -> void:
	if not auto_drive_enabled:
		return

	if not is_instance_valid(car) or not is_instance_valid(lane_agent):
		stop_auto_drive()
		return

	if not _is_ready_for_drive:
		_is_ready_for_drive = _try_assign_lane()
		if not _is_ready_for_drive:
			_begin_stop()

	if not is_instance_valid(lane_agent.current_lane) and not _try_assign_lane():
		push_warning("Car lost lane and couldn't find a new one")
		_begin_stop()

	var speed_mps: float = car.linear_velocity.length()
	var forward_speed_mps: float = max(car.linear_velocity.dot(_get_car_forward_flat()), 0.0)
	total_distance_traveled += speed_mps * delta

	var remaining_distance: float
	if _use_stop_target:
		if not _outcome_lane_entered:
			remaining_distance = FAR_REMAINING_DISTANCE
		else:
			var distance_to_target: float = car.global_position.distance_to(_stop_target)
			remaining_distance = distance_to_target
			if distance_to_target <= stop_complete_speed:
				_begin_stop()
	else:
		remaining_distance = max(total_distance_target - total_distance_traveled, 0.0)
		if remaining_distance <= 0.0:
			_begin_stop()

	var steering_target: float = 0.0
	if not _is_stopping and is_instance_valid(lane_agent.current_lane):
		_update_lane_progress(forward_speed_mps * delta)
		var effective_lookahead: float = lookahead_distance + (speed_mps * speed_lookahead_gain)
		var look_ahead_pos: Vector3 = _sample_target_point(effective_lookahead)
		steering_target = _compute_steering_target(look_ahead_pos, speed_mps)

	var target_speed_mps: float = _compute_target_speed(remaining_distance)
	var speed_error: float = target_speed_mps - speed_mps

	var engine_target: float = 0.0
	var brake_target: float = 0.0

	if speed_error >= 0.0:
		engine_target = min(speed_error * engine_proportional_gain, max_engine_force_command)
		if startup_ramp_seconds > 0.0 and not _is_stopping:
			_startup_elapsed += delta
			var startup_factor: float = clamp(_startup_elapsed / startup_ramp_seconds, 0.0, 1.0)
			engine_target *= startup_factor
	else:
		brake_target = min(-speed_error * brake_proportional_gain, max_brake_command)

	if _is_stopping:
		engine_target = 0.0
		brake_target = max(brake_target, stop_hold_brake)
	else:
		var engine_sign: float = -1.0 if invert_engine_direction else 1.0
		engine_target *= engine_sign

	steering_command = move_toward(steering_command, steering_target, steering_response_speed * delta)
	engine_force_command = move_toward(engine_force_command, engine_target, engine_ramp_rate * delta)
	brake_command = move_toward(brake_command, brake_target, brake_ramp_rate * delta)

	if _is_stopping and speed_mps <= stop_complete_speed:
		stop_auto_drive()
		auto_drive_completed.emit()


func _compute_steering_target(p_target_position: Vector3, p_speed_mps: float) -> float:
	var to_target: Vector3 = p_target_position - car.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return 0.0
	to_target = to_target.normalized()

	var forward: Vector3 = _get_car_forward_flat()

	var yaw_error: float = forward.signed_angle_to(to_target, Vector3.UP)
	var speed_ratio: float = clamp(p_speed_mps / max(high_speed_reference, 0.01), 0.0, 1.0)
	var speed_steering_scale: float = lerp(1.0, high_speed_steering_scale, speed_ratio)
	var steer_sign: float = -1.0 if invert_steering_direction else 1.0
	var steering_unclamped: float = yaw_error * steering_gain * speed_steering_scale * steer_sign
	return clamp(steering_unclamped, -max_steering_command, max_steering_command)


func _compute_target_speed(p_remaining_distance: float) -> float:
	if _is_stopping:
		return 0.0

	var target_speed: float = auto_drive_speed
	if p_remaining_distance <= braking_begin_distance:
		var braking_speed: float = sqrt(max(0.0, 2.0 * comfortable_deceleration * p_remaining_distance))
		target_speed = min(target_speed, braking_speed)

	return target_speed


func _begin_stop() -> void:
	_is_stopping = true

func start_auto_drive() -> void:
	_refresh_road_manager_path()

	if not _is_ready_for_drive:
		_is_ready_for_drive = _try_assign_lane()
		if not _is_ready_for_drive:
			push_warning("Auto-drive blocked: no lane found yet")
			return
	elif is_instance_valid(lane_agent.current_lane):
		_set_tracked_lane(lane_agent.current_lane)

	_is_stopping = false
	_startup_elapsed = 0.0
	total_distance_traveled = 0.0
	steering_command = 0.0
	engine_force_command = 0.0
	brake_command = 0.0
	auto_drive_enabled = true

func stop_auto_drive() -> void:
	_is_stopping = false
	auto_drive_enabled = false
	steering_command = 0.0
	engine_force_command = 0.0
	brake_command = 0.0
	_tracked_lane = null
	_tracked_lane_offset = 0.0
	_next_lane_override = null
	_outcome_lane_entered = false
	_stop_target = Vector3.ZERO
	_use_stop_target = false


## Starts lane-following auto-drive, overriding the next lane transition to [param p_lane].
## The car brakes to a stop near [param p_stop_target] instead of using [member total_distance_target].
func start_auto_drive_with_lane(p_lane: RoadLane, p_stop_target: Vector3) -> void:
	_next_lane_override = p_lane
	_outcome_lane_entered = false
	_stop_target = p_stop_target
	_use_stop_target = true
	print("[AutoDriver] start_auto_drive_with_lane — override='%s', stop_target=%s" % [
		str(p_lane.name) if is_instance_valid(p_lane) else "null", p_stop_target])
	start_auto_drive()


## Returns the next lane to transition to from [param p_from_lane],
## preferring [member _next_lane_override] when set.
func _get_next_lane(p_from_lane: RoadLane) -> RoadLane:
	if is_instance_valid(_next_lane_override):
		return _next_lane_override
	return p_from_lane.get_node_or_null(p_from_lane.lane_next) as RoadLane


func toggle_auto_drive() -> void:
	if auto_drive_enabled:
		stop_auto_drive()
	else:
		start_auto_drive()
