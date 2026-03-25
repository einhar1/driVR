extends Node

## Reference to the question bank resource
@export var question_bank: QuestionBank

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
	
	# Emit the first question
	emit_signal("question_change_requested", get_current_question(), current_question_index)
	emit_signal("question_changed", get_current_question(), current_question_index)

## Get the currently displayed question
func get_current_question() -> QuestionData:
	if not question_bank:
		return null
	return question_bank.get_question(current_question_index)

## Validate if the selected answer is correct
func validate_answer(p_selected_index: int) -> bool:
	var current_question: QuestionData = get_current_question()
	if not current_question:
		return false
	
	var is_correct: bool = (p_selected_index == current_question.correct_index)
	emit_signal("answer_validated", is_correct, p_selected_index, current_question.correct_index)
	
	return is_correct

## Move to the next question
func next_question() -> void:
	if not question_bank:
		return
	
	current_question_index += 1
	if current_question_index >= question_bank.get_question_count():
		current_question_index = 0
	
	emit_signal("question_change_requested", get_current_question(), current_question_index)
	emit_signal("question_changed", get_current_question(), current_question_index)

## Move to a specific question
func go_to_question(p_index: int) -> void:
	if not question_bank:
		return
	
	if p_index >= 0 and p_index < question_bank.get_question_count():
		current_question_index = p_index
		emit_signal("question_change_requested", get_current_question(), current_question_index)
		emit_signal("question_changed", get_current_question(), current_question_index)
	else:
		push_error("Question index out of range: %d" % p_index)
