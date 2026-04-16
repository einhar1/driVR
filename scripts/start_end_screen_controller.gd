extends CanvasLayer
class_name StartEndScreenController

## SYSTEMS CONTRACT:
## - Waits for QuestionManager to emit manager_initialized on startup.
## - Observes quiz_started and quiz_completed signals to manage screen visibility.
## - Lives inside the dedicated start/end Viewport2Din3D panel.

## Controller for the start and end screens shown outside the quiz flow.
## Lives inside the dedicated start/end Viewport2Din3D panel.
## Resolves [QuestionManager] through [method SceneTree.current_scene] to bridge viewport isolation.

const _GROUP_NAME_QUESTION_MANAGER: String = "question_manager"
const _DEPENDENCY_LOOKUP_MAX_FRAMES: int = 120

@onready var _start_screen: Control = %StartScreen
@onready var _end_screen: Control = %EndScreen
@onready var _score_label: Label = %ScoreLabel

var _question_manager: QuestionManager = null


func _ready() -> void:
	# Hide both screens immediately; _initialize_dependencies will show the correct one.
	_hide_all()
	call_deferred("_initialize_dependencies")


func _initialize_dependencies() -> void:
	# Wait for QuestionManager to broadcast manager_initialized.
	var manager: QuestionManager = get_tree().get_first_node_in_group(_GROUP_NAME_QUESTION_MANAGER) as QuestionManager
	if is_instance_valid(manager):
		# Check if already initialized (signal may have already fired).
		if manager.question_bank != null:
			_question_manager = manager
		else:
			# Wait for initialization if not yet ready.
			await manager.manager_initialized
			_question_manager = manager
	else:
		push_error("StartEndScreenController: QuestionManager not found (group 'question_manager' is empty)")
		_show_start_screen()
		return

	if not _question_manager.quiz_completed.is_connected(_on_quiz_completed):
		_question_manager.quiz_completed.connect(_on_quiz_completed)
	if not _question_manager.quiz_started.is_connected(_on_quiz_started):
		_question_manager.quiz_started.connect(_on_quiz_started)

	# In debug single-question mode the quiz is already active — hide ourselves immediately.
	if _question_manager.is_quiz_active():
		_hide_all()
	else:
		_show_start_screen()


## Called by the Starta button.
func _on_start_button_pressed() -> void:
	if is_instance_valid(_question_manager):
		_question_manager.start_quiz()
	# _on_quiz_started handles the rest.


## Called by the Starta ny omgång button.
func _on_restart_button_pressed() -> void:
	if is_instance_valid(_question_manager):
		_question_manager.restart_quiz()
	# _on_quiz_started handles the rest.


func _on_quiz_started() -> void:
	_hide_all()


func _on_quiz_completed() -> void:
	var total_questions: int = _question_manager.get_total_questions()
	var wrong_answers: int = _question_manager.get_wrong_answer_count()
	var correct_answers: int = total_questions - wrong_answers
	_score_label.text = "Du svarade rätt på %d av %d frågor." % [correct_answers, total_questions]
	_show_end_screen()


func _show_start_screen() -> void:
	if is_instance_valid(_start_screen):
		_start_screen.visible = true
	if is_instance_valid(_end_screen):
		_end_screen.visible = false


func _show_end_screen() -> void:
	if is_instance_valid(_start_screen):
		_start_screen.visible = false
	if is_instance_valid(_end_screen):
		_end_screen.visible = true


func _hide_all() -> void:
	if is_instance_valid(_start_screen):
		_start_screen.visible = false
	if is_instance_valid(_end_screen):
		_end_screen.visible = false
