extends CanvasLayer

@onready var button_1: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_1") as Button
@onready var button_2: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_2") as Button
@onready var button_3: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_3") as Button
@onready var label: Label = get_node_or_null("Label") as Label

@export_group("Question Label")
@export_range(14, 48, 1) var max_question_font_size: int = 26
@export_range(10, 32, 1) var min_question_font_size: int = 14
@export_range(20, 180, 1) var length_for_min_size: int = 120

var question_manager: Node
var car: Node

func _ready() -> void:
	# Find the QuestionManager in the scene
	question_manager = get_tree().current_scene.find_child("QuestionManager", true, false)
	
	# Find the car
	car = get_tree().current_scene.get_node_or_null("car")
	
	if question_manager:
		# Connect to question changes
		question_manager.question_changed.connect(_on_question_changed)
		question_manager.answer_validated.connect(_on_answer_validated)
		
		# Display the first question
		_on_question_changed(question_manager.get_current_question(), 0)
	else:
		push_error("QuestionManager not found in scene")

func _on_question_changed(p_question: QuestionData, _p_index: int) -> void:
	if not p_question:
		return
	
	# Update label with question text
	if is_instance_valid(label):
		label.text = p_question.question
		_apply_question_label_style(p_question.question)
	
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

func _on_answer_validated(p_is_correct: bool, _p_selected_index: int, p_correct_index: int) -> void:
	if p_is_correct:
		# Start auto-drive if answer is correct
		_start_car_movement()
		# Move to next question after a short delay
		get_tree().create_timer(3.0).timeout.connect(_on_movement_complete)
	else:
		# Show feedback (optional: change button color or play sound)
		print("Incorrect answer! Correct answer was index: %d" % p_correct_index)

func _start_car_movement() -> void:
	if not is_instance_valid(car):
		push_error("Car not found")
		return
	
	var auto_driver: Node = car.get_node_or_null("AutoDriver")
	if not is_instance_valid(auto_driver):
		push_error("Could not find auto-driver")
		return
	
	auto_driver.call("start_auto_drive")

func _on_movement_complete() -> void:
	if question_manager:
		question_manager.next_question()

func _on_button_1_pressed() -> void:
	if question_manager:
		question_manager.validate_answer(0)

func _on_button_2_pressed() -> void:
	if question_manager:
		question_manager.validate_answer(1)

func _on_button_3_pressed() -> void:
	if question_manager:
		question_manager.validate_answer(2)


## Adjusts question label typography to keep long text readable inside the panel.
func _apply_question_label_style(p_question_text: String) -> void:
	if not is_instance_valid(label):
		return

	if not is_instance_valid(label.label_settings):
		label.label_settings = LabelSettings.new()

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true

	var text_length: int = p_question_text.length()
	var clamped_threshold: int = maxi(1, length_for_min_size)
	var t: float = clampf(float(text_length) / float(clamped_threshold), 0.0, 1.0)
	var dynamic_size: int = int(round(lerpf(float(max_question_font_size), float(min_question_font_size), t)))
	label.label_settings.font_size = clampi(dynamic_size, min_question_font_size, max_question_font_size)
