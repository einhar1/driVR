extends Resource
class_name QuestionData

## The question text to display
@export var question: String = ""

## Array of answer options
@export var options: PackedStringArray = PackedStringArray()

## Index of the correct answer (0-based)
@export var correct_index: int = 0

## Optional scene shown while this question is active.
@export_file("*.tscn") var scene_path: String = ""

## Optional node path inside the question scene used as the car spawn anchor.
@export var spawn_point_path: NodePath = NodePath("SpawnPoint")

## Per-answer driving outcome tags (same index order as options).
## When set, the scenario scene decides which lane to drive based on the selected answer.
## Leave empty for questions that use the default drive-on-correct behaviour.
@export var answer_outcomes: PackedStringArray = PackedStringArray()

func _to_string() -> String:
	return "QuestionData: %s" % question
