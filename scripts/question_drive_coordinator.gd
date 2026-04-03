extends RefCounted
class_name QuestionDriveCoordinator

## Centralizes question-scene resolution and auto-drive startup for the quiz panel.

const OUTCOME_DRIVE_MAX_RETRIES: int = 20
const DEFAULT_SCENE_DRIVE_MAX_RETRIES: int = 20
const QuestionDriveScenarioScript = preload("res://scripts/scenarios/question_drive_scenario.gd")

var last_error_message: String = ""
var _active_auto_driver: CarAutoDriver = null

signal drive_completed


## Starts auto-drive for the active question and retries startup while question-scene APIs initialize.
func start_drive_with_retry(
	p_question: QuestionData,
	p_selected_index: int,
	p_scene_runner: Node,
	p_scene_root: Node,
	p_car_path: NodePath,
) -> bool:
	last_error_message = ""

	if not is_instance_valid(p_question):
		last_error_message = "QuestionDriveCoordinator: Missing active question"
		return false

	var auto_driver: CarAutoDriver = _resolve_auto_driver(p_scene_root, p_car_path)
	if not is_instance_valid(auto_driver):
		return false
	_bind_auto_drive_completion(auto_driver)

	if p_question.has_outcomes():
		return await _start_outcome_drive_with_retry(p_question, auto_driver, p_selected_index, p_scene_runner)

	return await _start_default_scene_drive_with_retry(p_question, auto_driver, p_scene_runner)


func _resolve_auto_driver(p_scene_root: Node, p_car_path: NodePath) -> CarAutoDriver:
	if not is_instance_valid(p_scene_root):
		last_error_message = "QuestionDriveCoordinator: Scene root is invalid"
		return null

	var car: Node3D = p_scene_root.get_node_or_null(p_car_path) as Node3D
	if not is_instance_valid(car):
		# Fallback: tolerate stale viewport-proxy NodePaths like "../car".
		var fallback_path: String = String(p_car_path).trim_prefix("../")
		if not fallback_path.is_empty():
			car = p_scene_root.get_node_or_null(NodePath(fallback_path)) as Node3D

	if not is_instance_valid(car):
		car = p_scene_root.get_node_or_null("car") as Node3D

	if not is_instance_valid(car):
		last_error_message = "QuestionDriveCoordinator: Car not found"
		return null

	var auto_driver: CarAutoDriver = car.get_node_or_null("AutoDriver") as CarAutoDriver
	if not is_instance_valid(auto_driver):
		last_error_message = "QuestionDriveCoordinator: Could not find auto-driver"
		return null

	return auto_driver


func _bind_auto_drive_completion(p_auto_driver: CarAutoDriver) -> void:
	if is_instance_valid(_active_auto_driver):
		if _active_auto_driver.auto_drive_completed.is_connected(_on_auto_drive_completed):
			_active_auto_driver.auto_drive_completed.disconnect(_on_auto_drive_completed)

	_active_auto_driver = p_auto_driver
	if not _active_auto_driver.auto_drive_completed.is_connected(_on_auto_drive_completed):
		_active_auto_driver.auto_drive_completed.connect(_on_auto_drive_completed, CONNECT_ONE_SHOT)


func _on_auto_drive_completed() -> void:
	_active_auto_driver = null
	drive_completed.emit()


func _start_outcome_drive_with_retry(
	p_question: QuestionData,
	p_auto_driver: CarAutoDriver,
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
	p_auto_driver: CarAutoDriver,
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
	p_auto_driver: CarAutoDriver,
	p_selected_index: int,
	p_scene_runner: Node,
) -> bool:
	if not p_question.has_outcomes():
		return false
	if p_selected_index < 0 or p_selected_index >= p_question.answer_outcomes.size():
		return false

	var outcome: String = p_question.answer_outcomes[p_selected_index]
	var question_scene: Node = _find_active_question_scene(p_scene_runner)
	var drive_scenario: QuestionDriveScenarioScript = question_scene as QuestionDriveScenarioScript
	if not is_instance_valid(drive_scenario):
		return false
	if not drive_scenario.supports_outcome_drive():
		return false

	var lane: RoadLane = drive_scenario.get_lane_for_outcome(outcome)
	var stop_target: Vector3 = drive_scenario.get_stop_target_for_outcome(outcome)
	if not is_instance_valid(lane):
		return false

	p_auto_driver.start_auto_drive_with_lane(lane, stop_target)
	return true


func _try_start_default_scene_drive(
	p_question: QuestionData,
	p_auto_driver: CarAutoDriver,
	p_scene_runner: Node,
) -> bool:
	if p_question.has_outcomes():
		return false

	var question_scene: Node = _find_active_question_scene(p_scene_runner)
	if not is_instance_valid(question_scene):
		return false

	var drive_scenario: QuestionDriveScenarioScript = question_scene as QuestionDriveScenarioScript
	var stop_target: Vector3 = _get_default_scene_stop_target(question_scene, drive_scenario)
	if stop_target == Vector3.INF:
		return false

	if is_instance_valid(drive_scenario) and drive_scenario.supports_default_drive_lane():
		var lane: RoadLane = drive_scenario.get_default_drive_lane()
		if is_instance_valid(lane):
			p_auto_driver.start_auto_drive_on_lane(lane, stop_target)
			return true

	p_auto_driver.start_auto_drive_to_waypoint(stop_target)
	return true


func _get_default_scene_stop_target(
	p_question_scene: Node,
	p_drive_scenario: QuestionDriveScenarioScript,
) -> Vector3:
	if is_instance_valid(p_drive_scenario):
		var stop_target: Vector3 = p_drive_scenario.get_default_stop_target()
		if stop_target != Vector3.INF:
			return stop_target

	var waypoint: Node3D = p_question_scene.get_node_or_null("DriveWaypoint") as Node3D
	if is_instance_valid(waypoint):
		return waypoint.global_position

	return Vector3.INF


func _find_active_question_scene(p_scene_runner: Node) -> Node:
	if not is_instance_valid(p_scene_runner):
		return null
	# Prefer the direct accessor on QuestionSceneRunner; fall back to name lookup.
	if p_scene_runner.has_method("get_active_scene_root"):
		var root: Node3D = p_scene_runner.get_active_scene_root()
		if is_instance_valid(root):
			return root
	return p_scene_runner.get_node_or_null("QuestionSceneRoot")
