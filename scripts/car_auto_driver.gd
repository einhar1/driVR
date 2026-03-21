extends Node

## Reference to the car (parent of this script)
@export var car: Node3D
## Reference to the RoadLaneAgent
@onready var lane_agent: RoadLaneAgent = get_parent().get_node("RoadLaneAgent") as RoadLaneAgent

## Auto-drive settings
@export var auto_drive_speed: float = 15.0 # meters per second
@export var auto_drive_enabled: bool = false
@export var total_distance_target: float = 5.0
var total_distance_traveled: float = 0.0
var _is_ready_for_drive: bool = false

const MAX_ASSIGN_RETRIES: int = 120
const NEAREST_LANE_SEARCH_DISTANCE: float = 250.0


## Try to assign the car to the nearest lane.
func _try_assign_lane() -> bool:
	if not is_instance_valid(car) or not is_instance_valid(lane_agent):
		return false

	if lane_agent.assign_nearest_lane() == OK:
		return true

	var nearest_lane: RoadLane = lane_agent.find_nearest_lane(car.global_position, NEAREST_LANE_SEARCH_DISTANCE)
	if is_instance_valid(nearest_lane):
		lane_agent.assign_lane(nearest_lane)
		return is_instance_valid(lane_agent.current_lane)

	return false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame

	if not car:
		car = get_parent() as Node3D

	if not is_instance_valid(lane_agent):
		push_error("RoadLaneAgent node missing under car")
		return

	var main_scene: Node = get_tree().current_scene
	if is_instance_valid(main_scene):
		var road_manager: Node = main_scene.get_node_or_null("RoadManager")
		if is_instance_valid(road_manager):
			lane_agent.road_manager_path = lane_agent.get_path_to(road_manager)

	var try_count: int = 0
	while try_count < MAX_ASSIGN_RETRIES:
		if _try_assign_lane():
			_is_ready_for_drive = true
			break
		try_count += 1
		await get_tree().physics_frame

	if not _is_ready_for_drive:
		push_warning("Failed to assign car to nearest lane during startup. Will retry on auto-drive start.")

func _physics_process(delta: float) -> void:
	if not _is_ready_for_drive:
		return

	if auto_drive_enabled and total_distance_traveled < total_distance_target:
		# Move the car along the lane
		if lane_agent.current_lane:
			var move_distance: float = auto_drive_speed * delta
			var next_pos: Vector3 = lane_agent.move_along_lane(move_distance)
			car.global_position = next_pos
			
			# Orient the car to face the direction it's moving
			var look_ahead_pos: Vector3 = lane_agent.test_move_along_lane(0.1)
			if not car.global_position.is_equal_approx(look_ahead_pos):
				car.look_at(look_ahead_pos, Vector3.UP)
			total_distance_traveled += move_distance
		else:
			# Try to find a lane if we lost it
			if not _try_assign_lane():
				push_warning("Car lost lane and couldn't find a new one")
				stop_auto_drive()
	elif total_distance_traveled >= total_distance_target:
		stop_auto_drive()

func start_auto_drive() -> void:
	if not _is_ready_for_drive:
		_is_ready_for_drive = _try_assign_lane()
		if not _is_ready_for_drive:
			push_warning("Auto-drive blocked: no lane found yet")
			return

	total_distance_traveled = 0.0
	auto_drive_enabled = true

func stop_auto_drive() -> void:
	auto_drive_enabled = false

func toggle_auto_drive() -> void:
	if auto_drive_enabled:
		stop_auto_drive()
	else:
		start_auto_drive()
