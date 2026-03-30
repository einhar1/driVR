extends Resource
class_name QuestionData

enum PostAnswerAction {
	AUTO_DRIVE,
	ADVANCE_IMMEDIATELY,
}

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

## Optional per-option outcome tags (e.g. "left", "right", "straight").
## When non-empty, every answer is treated as valid and the tag drives post-answer behaviour.
@export var answer_outcomes: PackedStringArray = PackedStringArray()

## Controls what happens after a correct answer is registered.
@export_enum("Auto Drive", "Advance Immediately") var post_answer_action: int = PostAnswerAction.AUTO_DRIVE


## Returns [code]true[/code] when the question uses outcome-based answers instead of a single correct index.
func has_outcomes() -> bool:
	return answer_outcomes.size() > 0


## Returns [code]true[/code] when the question should trigger post-answer auto-driving.
func should_auto_drive_after_answer() -> bool:
	return post_answer_action == PostAnswerAction.AUTO_DRIVE

func _to_string() -> String:
	return "QuestionData: %s" % question
