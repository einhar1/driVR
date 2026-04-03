extends RefCounted
class_name QuestionDriveCoordinator

## Centralizes question-scene resolution and auto-drive startup for the quiz panel.

const OUTCOME_DRIVE_MAX_RETRIES: int = 20
const DEFAULT_SCENE_DRIVE_MAX_RETRIES: int = 20

var last_error_message: String = ""


## Starts auto-drive for the active question and retries startup while question-scene APIs initialize.
func start_drive_with_retry(
	p_question: QuestionData,
	p_auto_driver: Node,
	p_selected_index: int,
	p_scene_runner: Node,
) -> bool:
	last_error_message = ""

	if not is_instance_valid(p_question):
		last_error_message = "QuestionDriveCoordinator: Missing active question"
		return false
	if not is_instance_valid(p_auto_driver):
		last_error_message = "QuestionDriveCoordinator: AutoDriver node is invalid"
		return false

	if p_question.has_outcomes():
		return await _start_outcome_drive_with_retry(p_question, p_auto_driver, p_selected_index, p_scene_runner)

	return await _start_default_scene_drive_with_retry(p_question, p_auto_driver, p_scene_runner)


func _start_outcome_drive_with_retry(
	p_question: QuestionData,
	p_auto_driver: Node,
	p_selected_index: int,
	p_scene_runner: Node,
) -> bool:
	for _attempt: int in range(OUTCOME_DRIVE_MAX_RETRIES):
		if _try_start_outcome_drive(p_question, p_auto_driver, p_selected_index, p_scene_runner):
			return true
		await Engine.get_main_loop().process_frame

	last_error_message = (
		"test_panel_controller: Outcome drive setup failed after %d retries. Aborting movement instead of falling back to distance mode." % OUTCOME_DRIVE_MAX_RETRIES
	)
	return false


func _start_default_scene_drive_with_retry(
	p_question: QuestionData,
	p_auto_driver: Node,
	p_scene_runner: Node,
) -> bool:
	for _attempt: int in range(DEFAULT_SCENE_DRIVE_MAX_RETRIES):
		if _try_start_default_scene_drive(p_question, p_auto_driver, p_scene_runner):
			return true
		await Engine.get_main_loop().process_frame

	last_error_message = (
		"test_panel_controller: Default scene drive setup failed after %d retries. Scenario needs a waypoint target." % DEFAULT_SCENE_DRIVE_MAX_RETRIES
	)
	return false


func _try_start_outcome_drive(
	p_question: QuestionData,
	p_auto_driver: Node,
	p_selected_index: int,
	p_scene_runner: Node,
) -> bool:
	if not p_question.has_outcomes():
		return false
	if p_selected_index < 0 or p_selected_index >= p_question.answer_outcomes.size():
		return false

	var outcome: String = p_question.answer_outcomes[p_selected_index]
	var question_scene: Node = _find_active_question_scene(p_scene_runner)
	if not is_instance_valid(question_scene):
		return false
	if not question_scene.has_method("get_lane_for_outcome"):
		return false
	if not question_scene.has_method("get_stop_target_for_outcome"):
		return false

	var lane: RoadLane = question_scene.call("get_lane_for_outcome", outcome) as RoadLane
	var stop_target: Vector3 = question_scene.call("get_stop_target_for_outcome", outcome)
	if not is_instance_valid(lane):
		return false

	p_auto_driver.start_auto_drive_with_lane(lane, stop_target)
	return true


func _try_start_default_scene_drive(
	p_question: QuestionData,
	p_auto_driver: Node,
	p_scene_runner: Node,
) -> bool:
	if p_question.has_outcomes():
		return false

	var question_scene: Node = _find_active_question_scene(p_scene_runner)
	if not is_instance_valid(question_scene):
		return false

	var stop_target_variant: Variant = _get_default_scene_stop_target(question_scene)
	if not (stop_target_variant is Vector3):
		return false
	var stop_target: Vector3 = stop_target_variant

	if question_scene.has_method("get_default_drive_lane"):
		var lane: RoadLane = question_scene.call("get_default_drive_lane") as RoadLane
		if is_instance_valid(lane):
			p_auto_driver.start_auto_drive_on_lane(lane, stop_target)
			return true

	p_auto_driver.start_auto_drive_to_waypoint(stop_target)
	return true


func _get_default_scene_stop_target(p_question_scene: Node) -> Variant:
	if p_question_scene.has_method("get_default_stop_target"):
		return p_question_scene.call("get_default_stop_target")

	var waypoint: Node3D = p_question_scene.get_node_or_null("DriveWaypoint") as Node3D
	if is_instance_valid(waypoint):
		return waypoint.global_position

	return null


func _find_active_question_scene(p_scene_runner: Node) -> Node:
	if not is_instance_valid(p_scene_runner):
		return null
	return p_scene_runner.get_node_or_null("QuestionSceneRoot")
