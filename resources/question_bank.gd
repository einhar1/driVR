extends Resource
class_name QuestionBank

## Array of questions in this bank
@export var questions: Array[QuestionData] = []

## Get a question by index
func get_question(p_index: int) -> QuestionData:
	if p_index >= 0 and p_index < questions.size():
		return questions[p_index]
	push_error("Question index %d out of range (0-%d)" % [p_index, questions.size() - 1])
	return null

## Get total number of questions
func get_question_count() -> int:
	return questions.size()
