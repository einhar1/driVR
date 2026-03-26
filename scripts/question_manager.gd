extends Node

## Reference to the question bank resource
@export var question_bank: QuestionBank

@export_group("Debug")
## Starts the quiz on [member debug_question_index] and keeps reloading only that question.
@export var debug_run_single_question: bool = false
## Zero-based question index used when [member debug_run_single_question] is enabled.
@export_range(0, 999, 1) var debug_question_index: int = 0

## Currently displayed question index
var current_question_index: int = 0

## Signal emitted when question changes
signal question_changed(p_question: QuestionData, p_index: int)

## Signal emitted when an answer is validated
signal answer_validated(p_is_correct: bool, p_selected_index: int, p_correct_index: int)

## Signal emitted before switching to a different question.
signal question_change_requested(p_question: QuestionData, p_index: int)

func _ready() -> void:
	if not question_bank:
		push_error("QuestionManager: No question_bank assigned")
		return
	
	if question_bank.get_question_count() == 0:
		push_error("QuestionManager: Question bank is empty")
		return

	current_question_index = _get_startup_question_index()
	
	# Emit the first question
	_emit_current_question()

## Get the currently displayed question
func get_current_question() -> QuestionData:
	if not question_bank:
		return null
	return question_bank.get_question(current_question_index)


## Returns the zero-based index of the currently active question.
func get_current_question_index() -> int:
	return current_question_index

## Validate if the selected answer is correct
func validate_answer(p_selected_index: int) -> bool:
	var current_question: QuestionData = get_current_question()
	if not current_question:
		return false
	
	var is_correct: bool
	if current_question.has_outcomes():
		is_correct = true
	else:
		is_correct = (p_selected_index == current_question.correct_index)
	emit_signal("answer_validated", is_correct, p_selected_index, current_question.correct_index)
	
	return is_correct

## Move to the next question
func next_question() -> void:
	if not question_bank:
		return

	if debug_run_single_question:
		current_question_index = _get_startup_question_index()
		_emit_current_question()
		return
	
	current_question_index += 1
	if current_question_index >= question_bank.get_question_count():
		current_question_index = 0
	
	_emit_current_question()

## Move to a specific question
func go_to_question(p_index: int) -> void:
	if not question_bank:
		return
	
	if p_index >= 0 and p_index < question_bank.get_question_count():
		current_question_index = p_index
		_emit_current_question()
	else:
		push_error("Question index out of range: %d" % p_index)


## Emits both signals for the currently active question.
func _emit_current_question() -> void:
	var current_question: QuestionData = get_current_question()
	emit_signal("question_change_requested", current_question, current_question_index)
	emit_signal("question_changed", current_question, current_question_index)


## Resolves the startup question index, clamping invalid debug values into range.
func _get_startup_question_index() -> int:
	if not debug_run_single_question:
		return 0

	var question_count: int = question_bank.get_question_count()
	var clamped_index: int = clampi(debug_question_index, 0, question_count - 1)
	if clamped_index != debug_question_index:
		push_warning(
			"QuestionManager: debug_question_index %d is out of range. Using %d instead." % [
				debug_question_index,
				clamped_index
			]
		)

	return clamped_index
