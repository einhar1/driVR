extends Node3D

## Intersection scenario controller.
## Maps per-answer outcome tags to directional waypoint markers and forces
## the auto-driver onto the lane heading toward the chosen waypoint.
##
## Usage: attach to the root Node3D of an intersection scenario scene. Add
## Marker3D children on each exit road, then fill in [member outcome_names]
## and [member outcome_waypoints] so each tag points to the matching marker.

@export_group("Outcome Mapping")

## Outcome tag strings — must match the values in QuestionData.answer_outcomes.
@export var outcome_names: PackedStringArray = PackedStringArray()

## Waypoint Marker3D nodes for each outcome (same index order as outcome_names).
@export var outcome_waypoints: Array[NodePath] = []


## Called by QuestionSceneRunner when the player selects an answer.
func apply_outcome(p_outcome: String, p_auto_driver: Node) -> void:
	var waypoint_index: int = _find_outcome_index(p_outcome)
	if waypoint_index < 0:
		push_warning("IntersectionScenario: Unknown outcome '%s'" % p_outcome)
		return

	if waypoint_index >= outcome_waypoints.size():
		push_warning("IntersectionScenario: No waypoint configured for outcome '%s'" % p_outcome)
		return

	var waypoint: Node3D = get_node_or_null(outcome_waypoints[waypoint_index]) as Node3D
	if not is_instance_valid(waypoint):
		push_warning("IntersectionScenario: Waypoint node not found for outcome '%s'" % p_outcome)
		return

	if not p_auto_driver.has_method("force_lane_toward"):
		push_error("IntersectionScenario: AutoDriver missing force_lane_toward method")
		return

	var success: bool = p_auto_driver.force_lane_toward(waypoint.global_position)
	if not success:
		push_warning("IntersectionScenario: No lane found toward '%s' waypoint" % p_outcome)


func _find_outcome_index(p_outcome: String) -> int:
	for i: int in outcome_names.size():
		if outcome_names[i] == p_outcome:
			return i
	return -1
