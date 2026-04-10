extends Node
class_name QuestionManager

## SYSTEMS CONTRACT:
## - Registers to group "question_manager" during _ready() for cross-viewport discovery.
## - Emits manager_initialized when setup is complete (question_bank loaded, startup index ready).
## - QuestionSceneRunner, test_panel_controller, and start_end_screen_controller await this signal.

const _LOCAL_DEV_CONFIG_PATH: String = "res://dev.local.cfg"

## Reference to the question bank resource
@export var question_bank: QuestionBank

@export_group("Debug")
## Starts the quiz on [member debug_question_index] and keeps reloading only that question.
@export var debug_run_single_question: bool = false
## Zero-based question index used when [member debug_run_single_question] is enabled.
@export_range(0, 999, 1) var debug_question_index: int = 0

## Currently displayed question index
var current_question_index: int = 0
var _quiz_active: bool = false

## Signal emitted when question changes
signal question_changed(p_question: QuestionData, p_index: int)

## Signal emitted when an answer is validated
signal answer_validated(p_is_correct: bool, p_selected_index: int, p_correct_index: int)

## Signal emitted before switching to a different question.
signal question_change_requested(p_question: QuestionData, p_index: int)

## Signal emitted when the player has answered the final question.
signal quiz_completed

## Signal emitted the moment the quiz becomes active (start or restart).
signal quiz_started

## Signal emitted when manager is fully initialized and ready for dependent systems.
signal manager_initialized

func _ready() -> void:
	add_to_group("question_manager")
	_apply_local_debug_overrides()

	if not question_bank:
		push_error("QuestionManager: No question_bank assigned")
		return
	
	if question_bank.get_question_count() == 0:
		push_error("QuestionManager: Question bank is empty")
		return

	current_question_index = _get_startup_question_index()

	# In debug single-question mode, jump straight into the quiz without the start screen.
	if debug_run_single_question:
		start_quiz()

	emit_signal("manager_initialized")


## Applies optional debug overrides from an untracked local config file.
func _apply_local_debug_overrides() -> void:
	if not FileAccess.file_exists(_LOCAL_DEV_CONFIG_PATH):
		return

	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(_LOCAL_DEV_CONFIG_PATH)
	if load_result != OK:
		push_warning(
			"QuestionManager: Failed to load %s (error %d)." % [
				_LOCAL_DEV_CONFIG_PATH,
				load_result
			]
		)
		return

	debug_run_single_question = bool(
		config.get_value("debug", "run_single_question", debug_run_single_question)
	)

	var local_question_index: int = int(
		config.get_value("debug", "question_index", debug_question_index)
	)
	debug_question_index = maxi(0, local_question_index)

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

	var is_correct: bool = (p_selected_index == current_question.correct_index)
	return validate_custom_answer(is_correct, p_selected_index, current_question.correct_index)


## Emits a custom validation result for scenarios that do not map cleanly to a single option index.
func validate_custom_answer(
	p_is_correct: bool,
	p_selected_index: int = -1,
	p_correct_index: int = -1,
) -> bool:
	emit_signal("answer_validated", p_is_correct, p_selected_index, p_correct_index)
	return p_is_correct

## Returns [code]true[/code] while the quiz is running.
func is_quiz_active() -> bool:
	return _quiz_active


## Begins the quiz from the startup question and emits [signal quiz_started].
func start_quiz() -> void:
	if not question_bank or question_bank.get_question_count() == 0:
		push_error("QuestionManager: Cannot start quiz — no questions available")
		return
	_quiz_active = true
	current_question_index = _get_startup_question_index()
	emit_signal("quiz_started")
	_emit_current_question()


## Move to the next question. Emits [signal quiz_completed] when the last question is passed.
func next_question() -> void:
	if not question_bank:
		return

	if debug_run_single_question:
		current_question_index = _get_startup_question_index()
		_emit_current_question()
		return

	current_question_index += 1
	if current_question_index >= question_bank.get_question_count():
		_quiz_active = false
		emit_signal("quiz_completed")
		return

	_emit_current_question()


## Reloads the currently active question by re-emitting its signals.
## Called when the player answers incorrectly so the question repeats after the drive.
func reload_current_question() -> void:
	_emit_current_question()


## Resets the quiz to the first question and emits [signal quiz_started].
func restart_quiz() -> void:
	if not question_bank:
		return
	_quiz_active = true
	current_question_index = _get_startup_question_index()
	emit_signal("quiz_started")
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


## Emits both signals for the currently active question. No-op when quiz is not active.
func _emit_current_question() -> void:
	if not _quiz_active:
		return
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
