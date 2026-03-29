extends Node3D

## Provides a default straight-through route for the `korsning` question scene.
## The prefab 4-way intersection ships with turn lanes, so this script creates
## a straight lane at runtime and exposes it to the quiz controller.

var _straight_lane: RoadLane = null

@onready var _intersection: Node3D = $"RoadManager/4way_1x1"
@onready var _drive_waypoint: Marker3D = $DriveWaypoint


func _ready() -> void:
	_create_straight_lane()


## Returns the default lane the player car should follow after answering.
func get_default_drive_lane() -> RoadLane:
	return _straight_lane


## Returns a stop target near the end of the straight lane.
func get_default_stop_target() -> Vector3:
	if is_instance_valid(_drive_waypoint):
		return _drive_waypoint.global_position

	if not is_instance_valid(_straight_lane):
		return global_position

	var lane_length: float = _straight_lane.curve.get_baked_length()
	var stop_offset: float = max(lane_length - 8.0, 0.0)
	var local_stop: Vector3 = _straight_lane.curve.sample_baked(stop_offset)
	return _straight_lane.to_global(local_stop)


func _create_straight_lane() -> void:
	if not is_instance_valid(_intersection):
		push_error("korsning.gd: 4way_1x1 intersection not found")
		return
	if is_instance_valid(_straight_lane):
		return

	var existing_lane: RoadLane = _intersection.get_node_or_null("S0N0") as RoadLane
	if is_instance_valid(existing_lane):
		_straight_lane = existing_lane
		return

	var lane_script: Script = load("res://addons/road-generator/nodes/road_lane.gd") as Script
	if lane_script == null:
		push_error("korsning.gd: Failed to load RoadLane script")
		return

	var path_node: Path3D = Path3D.new()
	path_node.name = "S0N0"
	path_node.set_script(lane_script)

	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3(2.0, 0.0, 16.0))
	curve.add_point(Vector3(2.0, 0.0, -50.0))
	path_node.curve = curve

	path_node.add_to_group("road_lanes")
	_intersection.add_child(path_node)
	_straight_lane = path_node as RoadLane
