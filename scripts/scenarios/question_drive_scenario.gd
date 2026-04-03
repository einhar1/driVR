extends Node3D
class_name QuestionDriveScenario

## Typed contract for scenario-specific auto-drive behavior used by quiz flow.
## Override support flags and corresponding getters in scenario scripts as needed.


## Returns [code]true[/code] when this scenario supports outcome-based lane/target mapping.
func supports_outcome_drive() -> bool:
	return false


## Returns [code]true[/code] when this scenario provides a default lane for non-outcome questions.
func supports_default_drive_lane() -> bool:
	return false


## Returns a lane for the given answer outcome, or [code]null[/code] if unavailable.
func get_lane_for_outcome(p_outcome: String) -> RoadLane:
	return null


## Returns a world-space stop target for the given answer outcome.
func get_stop_target_for_outcome(_p_outcome: String) -> Vector3:
	return Vector3.ZERO


## Returns a default lane for non-outcome scenarios, or [code]null[/code] if unavailable.
func get_default_drive_lane() -> RoadLane:
	return null


## Returns a default world-space stop target for non-outcome scenarios.
func get_default_stop_target() -> Vector3:
	return Vector3.INF