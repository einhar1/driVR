extends CanvasLayer

const DEFAULT_BUTTON_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const _GROUP_NAME_QUESTION_MANAGER: String = "question_manager"
const _GROUP_NAME_SCENE_RUNNER: String = "question_scene_runner"
const _DEPENDENCY_LOOKUP_MAX_FRAMES: int = 120

@onready var button_1: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_1") as Button
@onready var button_2: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_2") as Button
@onready var button_3: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_3") as Button
@onready var label: Label = get_node_or_null("Label") as Label
@onready var background_rect: ColorRect = get_node_or_null("ColorRect") as ColorRect
@onready var correct_sfx_player: AudioStreamPlayer = get_node_or_null("CorrectSfx") as AudioStreamPlayer
@onready var incorrect_sfx_player: AudioStreamPlayer = get_node_or_null("IncorrectSfx") as AudioStreamPlayer

@export_group("Question Label")
@export_range(14, 48, 1) var max_question_font_size: int = 26
@export_range(10, 32, 1) var min_question_font_size: int = 14
@export_range(20, 180, 1) var length_for_min_size: int = 120

@export_group("Answer Feedback")
@export_range(0.1, 3.0, 0.05) var feedback_hold_seconds: float = 0.9
@export_range(0.05, 1.0, 0.05) var feedback_flash_seconds: float = 0.2
@export var correct_panel_color: Color = Color(0.36, 0.78, 0.46, 0.92)
@export var incorrect_panel_color: Color = Color(0.82, 0.32, 0.32, 0.92)
@export var correct_button_color: Color = Color(0.42, 0.84, 0.48, 1.0)
@export var incorrect_button_color: Color = Color(0.92, 0.38, 0.38, 1.0)
@export var enable_button_flash_feedback: bool = false
@export var show_correct_button_on_incorrect: bool = true

@export_group("Quiz Flow")
@export_range(0.0, 3.0, 0.05) var post_feedback_advance_delay_seconds: float = 0.0
@export_range(0.0, 3.0, 0.05) var post_drive_advance_delay_seconds: float = 0.0

var question_manager: QuestionManager = null
var _last_selected_index: int = -1
var _feedback_locked: bool = false
var _feedback_tween: Tween = null
var _base_panel_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _drive_coordinator: QuestionDriveCoordinator = QuestionDriveCoordinator.new()
var _question_scene_runner: Node = null
var _flow_version: int = 0
var _panel_in_3d: Node3D = null


func _ready() -> void:
	if is_instance_valid(background_rect):
		_base_panel_color = background_rect.color

	# Walk up SubViewport → Viewport2Din3D to control whole-panel visibility.
	var sub_viewport: Node = get_parent()
	if sub_viewport is SubViewport:
		var parent: Node = sub_viewport.get_parent()
		if parent is Node3D:
			_panel_in_3d = parent as Node3D

	_set_panel_in_3d_visible(false)
	if not _drive_coordinator.drive_completed.is_connected(_on_drive_completed):
		_drive_coordinator.drive_completed.connect(_on_drive_completed)
	call_deferred("_initialize_dependencies")


func _initialize_dependencies() -> void:
	# Wait for QuestionManager to be fully initialized and broadcasting manager_initialized signal.
	var manager: QuestionManager = get_tree().get_first_node_in_group(_GROUP_NAME_QUESTION_MANAGER) as QuestionManager
	if is_instance_valid(manager):
		# Check if already initialized (signal may have already fired).
		if manager.question_bank != null:
			question_manager = manager
		else:
			# Wait for initialization if not yet ready.
			await manager.manager_initialized
			question_manager = manager
	else:
		push_error("QuestionManager not found in scene; retrying...")
		await get_tree().process_frame
		manager = get_tree().get_first_node_in_group(_GROUP_NAME_QUESTION_MANAGER) as QuestionManager
		if is_instance_valid(manager):
			if manager.question_bank != null:
				question_manager = manager
			else:
				await manager.manager_initialized
				question_manager = manager

	_question_scene_runner = await _resolve_scene_runner_with_retry()

	if is_instance_valid(question_manager):
		# Connect to question changes.
		if not question_manager.question_changed.is_connected(_on_question_changed):
			question_manager.question_changed.connect(_on_question_changed)
		if not question_manager.answer_validated.is_connected(_on_answer_validated):
			question_manager.answer_validated.connect(_on_answer_validated)
		if not question_manager.quiz_started.is_connected(_on_quiz_started_panel):
			question_manager.quiz_started.connect(_on_quiz_started_panel)
		if not question_manager.quiz_completed.is_connected(_on_quiz_completed_panel):
			question_manager.quiz_completed.connect(_on_quiz_completed_panel)

		# In debug single-question mode the quiz is already active — populate UI immediately.
		if question_manager.is_quiz_active():
			call_deferred(
				"_on_question_changed",
				question_manager.get_current_question(),
				question_manager.get_current_question_index()
			)
	else:
		push_error("QuestionManager not found in scene")

	# Hide the 3D panel until the quiz is active.
	_set_panel_in_3d_visible(question_manager != null and question_manager.is_quiz_active())


func _resolve_scene_runner_with_retry() -> Node:
	for _attempt: int in range(_DEPENDENCY_LOOKUP_MAX_FRAMES):
		var runner: Node = get_tree().get_first_node_in_group(_GROUP_NAME_SCENE_RUNNER)
		if is_instance_valid(runner):
			return runner
		await get_tree().process_frame

	var gameplay_root: Node = _get_gameplay_root()
	if is_instance_valid(gameplay_root):
		return gameplay_root.get_node_or_null("QuestionSceneRunner")

	return null


## Resolves the gameplay root node that owns car/question systems.
func _get_gameplay_root() -> Node:
	if is_instance_valid(_question_scene_runner):
		return _question_scene_runner.get_parent()

	if is_instance_valid(question_manager):
		return question_manager.get_parent()

	var manager: QuestionManager = get_tree().get_first_node_in_group(_GROUP_NAME_QUESTION_MANAGER) as QuestionManager
	if is_instance_valid(manager):
		return manager.get_parent()

	return null


func _on_quiz_started_panel() -> void:
	_set_panel_in_3d_visible(true)


func _on_quiz_completed_panel() -> void:
	_set_panel_in_3d_visible(false)


func _set_panel_in_3d_visible(p_visible: bool) -> void:
	if is_instance_valid(_panel_in_3d):
		_panel_in_3d.visible = p_visible


func _on_question_changed(p_question: QuestionData, _p_index: int) -> void:
	if not p_question:
		return
	_flow_version += 1

	_feedback_locked = false
	_last_selected_index = -1
	_reset_feedback_visuals()
	_set_answer_buttons_disabled(false)

	var display_question: String = _normalize_swedish_text(p_question.question)

	# Update label with question text
	if is_instance_valid(label):
		label.text = display_question
		_apply_question_label_style(display_question)

	# Update button texts with answer options
	var options_count: int = p_question.options.size()

	# Hide all buttons first
	button_1.visible = false
	button_2.visible = false
	button_3.visible = false

	# Show and update visible buttons
	if options_count >= 1:
		button_1.text = p_question.options[0]
		button_1.visible = true

	if options_count >= 2:
		button_2.text = p_question.options[1]
		button_2.visible = true

	if options_count >= 3:
		button_3.text = p_question.options[2]
		button_3.visible = true


func _on_answer_validated(p_is_correct: bool, p_selected_index: int, p_correct_index: int) -> void:
	if _feedback_locked:
		return

	_flow_version += 1
	var flow_version: int = _flow_version
	_feedback_locked = true
	_last_selected_index = p_selected_index
	_set_answer_buttons_disabled(true)
	_play_answer_feedback(p_is_correct, p_selected_index, p_correct_index)
	await get_tree().create_timer(feedback_hold_seconds).timeout
	if not _is_flow_active(flow_version):
		return
	_reset_feedback_visuals()

	if p_is_correct:
		var current_question: QuestionData = question_manager.get_current_question()
		if current_question and not current_question.should_auto_drive_after_answer():
			Callable(self , "_advance_without_car_movement").bind(flow_version).call_deferred()
			return
		Callable(self , "_start_question_drive_with_retry").bind(current_question, flow_version).call_deferred()
		return

	_feedback_locked = false
	_set_answer_buttons_disabled(false)
	if p_correct_index >= 0:
		print("Incorrect answer! Correct answer was index: %d" % p_correct_index)
	else:
		print("Incorrect answer!")


## Advances to the next question without moving the car.
func _advance_without_car_movement(p_flow_version: int) -> void:
	if post_feedback_advance_delay_seconds > 0.0:
		await get_tree().create_timer(post_feedback_advance_delay_seconds).timeout
	if not _is_flow_active(p_flow_version):
		return

	if is_instance_valid(question_manager):
		if question_manager.debug_run_single_question:
			print("test_panel_controller: Debug single-question mode is enabled, so the same question will reload")
		question_manager.next_question()
		return

	_feedback_locked = false
	_set_answer_buttons_disabled(false)


## Starts question-specific auto-drive and retries while scenario APIs initialize.
func _start_question_drive_with_retry(
	p_question: QuestionData,
	p_flow_version: int,
) -> void:
	var gameplay_root: Node = _get_gameplay_root()
	if not is_instance_valid(gameplay_root):
		push_error("test_panel_controller: Gameplay root not found")
		_feedback_locked = false
		_set_answer_buttons_disabled(false)
		return

	var did_start_drive: bool = await _drive_coordinator.start_drive_with_retry(
		p_question,
		_last_selected_index,
		_question_scene_runner,
		gameplay_root,
		NodePath("car")
	)
	if not _is_flow_active(p_flow_version):
		return
	if did_start_drive:
		return

	if not _drive_coordinator.last_error_message.is_empty():
		push_error(_drive_coordinator.last_error_message)
	else:
		push_error("test_panel_controller: Failed to start question auto-drive")

	_feedback_locked = false
	_set_answer_buttons_disabled(false)


func _on_drive_completed() -> void:
	Callable(self , "_advance_after_drive_completion").bind(_flow_version).call_deferred()


func _advance_after_drive_completion(p_flow_version: int) -> void:
	if post_drive_advance_delay_seconds > 0.0:
		await get_tree().create_timer(post_drive_advance_delay_seconds).timeout
	if not _is_flow_active(p_flow_version):
		return

	if is_instance_valid(question_manager):
		question_manager.next_question()
		return

	_feedback_locked = false
	_set_answer_buttons_disabled(false)


func _is_flow_active(p_flow_version: int) -> bool:
	return p_flow_version == _flow_version


func _on_button_1_pressed() -> void:
	if is_instance_valid(question_manager) and not _feedback_locked:
		question_manager.validate_answer(0)


func _on_button_2_pressed() -> void:
	if is_instance_valid(question_manager) and not _feedback_locked:
		question_manager.validate_answer(1)


func _on_button_3_pressed() -> void:
	if is_instance_valid(question_manager) and not _feedback_locked:
		question_manager.validate_answer(2)


func _play_answer_feedback(
	p_is_correct: bool,
	p_selected_index: int,
	p_correct_index: int,
) -> void:
	var tween: Tween = _create_feedback_tween()
	var selected_button: Button = _get_button_for_index(p_selected_index)

	if p_is_correct:
		if is_instance_valid(background_rect):
			tween.tween_property(background_rect, "color", correct_panel_color, feedback_flash_seconds)
		if enable_button_flash_feedback and is_instance_valid(selected_button):
			tween.tween_property(selected_button, "modulate", correct_button_color, feedback_flash_seconds)
		_play_feedback_sound(correct_sfx_player)
		return

	if is_instance_valid(background_rect):
		tween.tween_property(background_rect, "color", incorrect_panel_color, feedback_flash_seconds)
	if enable_button_flash_feedback and is_instance_valid(selected_button):
		tween.tween_property(selected_button, "modulate", incorrect_button_color, feedback_flash_seconds)
	if enable_button_flash_feedback and show_correct_button_on_incorrect and p_correct_index >= 0 and p_correct_index != p_selected_index:
		var correct_button: Button = _get_button_for_index(p_correct_index)
		if is_instance_valid(correct_button):
			tween.tween_property(correct_button, "modulate", correct_button_color, feedback_flash_seconds)
	_play_feedback_sound(incorrect_sfx_player)


func _create_feedback_tween() -> Tween:
	if _feedback_tween != null:
		_feedback_tween.kill()

	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_SINE)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	return _feedback_tween


func _reset_feedback_visuals() -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
		_feedback_tween = null

	if is_instance_valid(background_rect):
		background_rect.color = _base_panel_color

	for button: Button in _get_answer_buttons():
		button.modulate = DEFAULT_BUTTON_MODULATE


func _set_answer_buttons_disabled(p_disabled: bool) -> void:
	for button: Button in _get_answer_buttons():
		button.disabled = p_disabled


func _get_answer_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if is_instance_valid(button_1):
		buttons.append(button_1)
	if is_instance_valid(button_2):
		buttons.append(button_2)
	if is_instance_valid(button_3):
		buttons.append(button_3)
	return buttons


func _get_button_for_index(p_index: int) -> Button:
	match p_index:
		0:
			return button_1
		1:
			return button_2
		2:
			return button_3
		_:
			return null


func _play_feedback_sound(p_player: AudioStreamPlayer) -> void:
	if is_instance_valid(p_player) and is_instance_valid(p_player.stream):
		p_player.play()


## Adjusts question label typography to keep long text readable inside the panel.
func _apply_question_label_style(p_question_text: String) -> void:
	if not is_instance_valid(label):
		return

	if not is_instance_valid(label.label_settings):
		label.label_settings = LabelSettings.new()

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var text_length: int = p_question_text.length()
	var clamped_threshold: int = maxi(1, length_for_min_size)
	var t: float = clampf(float(text_length) / float(clamped_threshold), 0.0, 1.0)
	var dynamic_size: int = int(round(lerpf(float(max_question_font_size), float(min_question_font_size), t)))
	label.label_settings.font_size = clampi(dynamic_size, min_question_font_size, max_question_font_size)


## Normalizes common malformed dead-key sequences for Swedish characters.
func _normalize_swedish_text(p_text: String) -> String:
	var normalized: String = p_text

	# Spacing diaeresis (U+00A8) dead-key patterns.
	normalized = normalized.replace("¨a", "ä")
	normalized = normalized.replace("¨A", "Ä")
	normalized = normalized.replace("¨o", "ö")
	normalized = normalized.replace("¨O", "Ö")
	normalized = normalized.replace("¨u", "ü")
	normalized = normalized.replace("¨U", "Ü")
	normalized = normalized.replace("¨å", "å")
	normalized = normalized.replace("¨Å", "Å")

	# Combining diaeresis (U+0308) patterns.
	normalized = normalized.replace("\u0308a", "ä")
	normalized = normalized.replace("\u0308A", "Ä")
	normalized = normalized.replace("\u0308o", "ö")
	normalized = normalized.replace("\u0308O", "Ö")
	normalized = normalized.replace("\u0308u", "ü")
	normalized = normalized.replace("\u0308U", "Ü")

	return normalized
