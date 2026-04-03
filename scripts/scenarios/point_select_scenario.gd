extends Node3D
class_name PointSelectScenario

## Handles point-and-click scenario answers by collecting clicks on tagged targets.

@export_group("Point Select")
## IDs that must be clicked before the answer is marked correct.
@export var correct_selection_ids: PackedStringArray = PackedStringArray()
## When disabled, the first incorrect click locks the scenario.
@export var allow_retry_after_incorrect: bool = true

var _question_manager: QuestionManager = null
var _selected_ids: PackedStringArray = PackedStringArray()
var _selection_completed: bool = false


func _ready() -> void:
	var current_scene: Node = get_tree().current_scene
	_question_manager = current_scene.get_node_or_null("QuestionManager") as QuestionManager
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
			_validate_custom_answer(true)
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

	_question_manager.validate_custom_answer(p_is_correct, -1, -1)
