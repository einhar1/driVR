extends Node3D
class_name PointSelectScenario

## Handles point-and-click scenario answers by collecting clicks on tagged targets.

@export_group("Point Select")
## IDs that must be clicked before the answer is marked correct.
@export var correct_selection_ids: PackedStringArray = PackedStringArray()
## When disabled, the first incorrect click locks the scenario.
@export var allow_retry_after_incorrect: bool = true

var _question_manager: Node = null
var _selected_ids: PackedStringArray = PackedStringArray()
var _selection_completed: bool = false


func _ready() -> void:
	_question_manager = get_tree().current_scene.find_child("QuestionManager", true, false)
	if not is_instance_valid(_question_manager):
		push_error("PointSelectScenario: QuestionManager not found")
		return

	if correct_selection_ids.is_empty():
		push_warning("PointSelectScenario: No correct_selection_ids configured")


## Registers a target click and returns [code]true[/code] when the click was accepted.
func submit_selection(p_selection_id: String) -> bool:
	if _selection_completed:
		print("PointSelectScenario: Selection ignored because the scenario is already complete")
		return false

	if p_selection_id.is_empty():
		push_warning("PointSelectScenario: Ignored empty selection ID")
		return false

	if correct_selection_ids.has(p_selection_id):
		if _selected_ids.has(p_selection_id):
			print("PointSelectScenario: Selection '%s' was already registered" % p_selection_id)
			return false

		_selected_ids.append(p_selection_id)
		print(
			"PointSelectScenario: Registered correct selection '%s' (%d/%d)" % [
				p_selection_id,
				_selected_ids.size(),
				correct_selection_ids.size()
			]
		)
		if _selected_ids.size() >= correct_selection_ids.size():
			_selection_completed = true
			print("PointSelectScenario: All correct selections found")
			var scene_instance_id_before_validation: int = _get_active_question_scene_instance_id()
			_validate_custom_answer(true)
			Callable(self , "_ensure_progress_after_success").bind(scene_instance_id_before_validation).call_deferred()
		return true

	print("PointSelectScenario: Incorrect selection '%s'" % p_selection_id)
	_validate_custom_answer(false)
	if not allow_retry_after_incorrect:
		_selection_completed = true
	return false


## Emits the validation result through the shared quiz manager.
func _validate_custom_answer(p_is_correct: bool) -> void:
	if not is_instance_valid(_question_manager):
		push_error("PointSelectScenario: Cannot validate answer without QuestionManager")
		return

	if not _question_manager.has_method("validate_custom_answer"):
		push_error("PointSelectScenario: QuestionManager is missing validate_custom_answer")
		return

	_question_manager.call("validate_custom_answer", p_is_correct, -1, -1)


## Falls back to progressing the quiz if the standard UI callback path did not reload/switch scenes.
func _ensure_progress_after_success(p_scene_instance_id_before_validation: int) -> void:
	await get_tree().create_timer(2.0).timeout

	if not is_instance_valid(_question_manager):
		return

	var current_question: QuestionData = _question_manager.call("get_current_question") as QuestionData
	if current_question == null or current_question.should_auto_drive_after_answer():
		return

	var current_scene_instance_id: int = _get_active_question_scene_instance_id()
	if current_scene_instance_id != p_scene_instance_id_before_validation:
		return

	print("PointSelectScenario: Fallback advancing quiz because the scene did not change after success")
	if bool(_question_manager.get("debug_run_single_question")):
		var current_question_index: int = int(_question_manager.call("get_current_question_index"))
		_question_manager.call("go_to_question", current_question_index)
		return

	_question_manager.call("next_question")


## Returns the active question-scene instance ID, or -1 if none is loaded.
func _get_active_question_scene_instance_id() -> int:
	var scene_runner: Node = get_tree().current_scene.find_child("QuestionSceneRunner", true, false)
	if not is_instance_valid(scene_runner):
		return -1

	var question_scene: Node = scene_runner.get_node_or_null("QuestionSceneRoot")
	if not is_instance_valid(question_scene):
		return -1

	return question_scene.get_instance_id()
