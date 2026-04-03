extends "res://scripts/scenarios/question_drive_scenario.gd"

## Provides outcome → lane mapping for the intersection quiz question.
## Creates a straight-through RoadLane at runtime since the 4way_1x1 intersection
## only ships with left-turn and right-turn lanes.

var _straight_lane: RoadLane

@onready var _intersection: Node3D = $"RoadManager/4way_1x1"


func _ready() -> void:
	_create_straight_lane()


func supports_outcome_drive() -> bool:
	return true


## Returns the intersection [RoadLane] that matches [param p_outcome].
func get_lane_for_outcome(p_outcome: String) -> RoadLane:
	match p_outcome:
		"left":
			return _intersection.get_node_or_null("S0W0") as RoadLane
		"right":
			return _intersection.get_node_or_null("S1E1") as RoadLane
		"straight":
			return _straight_lane
	push_warning("Unknown outcome: %s" % p_outcome)
	return null


## Returns the world-space stop target for [param p_outcome].
func get_stop_target_for_outcome(p_outcome: String) -> Vector3:
	match p_outcome:
		"left":
			return $WaypointLeft.global_position
		"right":
			return $WaypointRight.global_position
		"straight":
			return $WaypointStraight.global_position
	return Vector3.ZERO


func _create_straight_lane() -> void:
	var lane_script: Script = load("res://addons/road-generator/nodes/road_lane.gd")

	var path_node := Path3D.new()
	path_node.name = "S0N0"
	path_node.set_script(lane_script)

	var curve := Curve3D.new()
	curve.add_point(Vector3(2.0, 0.0, 16.0)) # South entry
	curve.add_point(Vector3(2.0, 0.0, -50.0)) # Well past WaypointStraight
	path_node.curve = curve

	path_node.add_to_group("road_lanes")
	_intersection.add_child(path_node)

	_straight_lane = path_node as RoadLane
