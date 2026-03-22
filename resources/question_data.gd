extends Resource
class_name QuestionData

## The question text to display
@export var question: String = ""

## Array of answer options
@export var options: PackedStringArray = PackedStringArray()

## Index of the correct answer (0-based)
@export var correct_index: int = 0

func _to_string() -> String:
	return "QuestionData: %s" % question
