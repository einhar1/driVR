extends CanvasLayer

signal advance_requested()

@onready var button_1: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_1") as Button
@onready var button_2: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_2") as Button
@onready var button_3: Button = get_node_or_null("MarginContainer/VBoxContainer/Button_3") as Button
@onready var label: Label = get_node_or_null("Label") as Label

@export_group("Question Label")
@export_range(14, 48, 1) var max_question_font_size: int = 26
@export_range(10, 32, 1) var min_question_font_size: int = 14
@export_range(20, 180, 1) var length_for_min_size: int = 120

@export_group("Viewport Auto Size")
@export var auto_size_viewport_to_content: bool = true
@export_range(0, 128, 1) var viewport_padding_px: int = 8

var question_manager: Node
var car: Node

func _ready() -> void:
	# Find the QuestionManager in the active scene tree.
	question_manager = get_tree().current_scene.find_child("QuestionManager", true, false)
	
	# Find the persistent car.
	car = get_tree().current_scene.get_node_or_null("car")
	
	if question_manager:
		# Connect to question changes.
		if not question_manager.question_changed.is_connected(_on_question_changed):
			question_manager.question_changed.connect(_on_question_changed)
		if not question_manager.answer_validated.is_connected(_on_answer_validated):
			question_manager.answer_validated.connect(_on_answer_validated)
		
		# Display the first question.
		var current_question_index: int = 0
		if question_manager.has_method("get_current_question_index"):
			current_question_index = question_manager.get_current_question_index()
		_on_question_changed(question_manager.get_current_question(), current_question_index)
	else:
		push_error("QuestionManager not found in scene")

	if auto_size_viewport_to_content:
		call_deferred("_sync_viewport_to_content")

func _on_question_changed(p_question: QuestionData, _p_index: int) -> void:
	if not p_question:
		return

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

	if auto_size_viewport_to_content:
		call_deferred("_sync_viewport_to_content")

func _on_answer_validated(p_is_correct: bool, _p_selected_index: int, p_correct_index: int) -> void:
	if p_is_correct:
		_start_car_movement()
	else:
		# Show feedback (optional: change button color or play sound).
		print("Incorrect answer! Correct answer was index: %d" % p_correct_index)

func _start_car_movement() -> void:
	if not is_instance_valid(car):
		push_error("Car not found")
		return

	var auto_driver: Node = car.get_node_or_null("AutoDriver")
	if not is_instance_valid(auto_driver):
		push_error("Could not find auto-driver")
		return

	# Advance to the next question only when the car has fully stopped.
	if not auto_driver.is_connected("auto_drive_completed", _on_movement_complete):
		auto_driver.connect("auto_drive_completed", _on_movement_complete, CONNECT_ONE_SHOT)
	auto_driver.call("start_auto_drive")

func _on_movement_complete() -> void:
	await get_tree().create_timer(1.5).timeout
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


## Resizes the parent Viewport2Din3D to fit visible 2D content bounds.
func _sync_viewport_to_content() -> void:
	var content_rect: Rect2 = _get_visible_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return

	var padded_size: Vector2 = Vector2(
		ceil(content_rect.size.x) + float(viewport_padding_px),
		ceil(content_rect.size.y) + float(viewport_padding_px)
	)

	var sub_viewport_node: Node = get_parent()
	if not (sub_viewport_node is SubViewport):
		return

	var viewport_2d_in_3d: Node = sub_viewport_node.get_parent()
	if not is_instance_valid(viewport_2d_in_3d):
		return

	var current_viewport_size: Variant = viewport_2d_in_3d.get("viewport_size")
	var current_screen_size: Variant = viewport_2d_in_3d.get("screen_size")
	if not (current_viewport_size is Vector2) or not (current_screen_size is Vector2):
		return

	var current_viewport_size_v2: Vector2 = current_viewport_size
	var current_screen_size_v2: Vector2 = current_screen_size
	var pixels_per_meter: float = current_viewport_size_v2.x / maxf(current_screen_size_v2.x, 0.001)
	var new_screen_size: Vector2 = padded_size / maxf(pixels_per_meter, 0.001)

	viewport_2d_in_3d.set("viewport_size", padded_size)
	viewport_2d_in_3d.set("screen_size", new_screen_size)


## Calculates a bounding rect for visible direct child controls.
func _get_visible_content_rect() -> Rect2:
	var has_any_control: bool = false
	var min_pos: Vector2 = Vector2.ZERO
	var max_pos: Vector2 = Vector2.ZERO

	for child: Node in get_children():
		if not (child is Control):
			continue

		var control: Control = child as Control
		if not control.visible:
			continue

		var rect: Rect2 = Rect2(control.position, control.size)
		if not has_any_control:
			min_pos = rect.position
			max_pos = rect.position + rect.size
			has_any_control = true
		else:
			min_pos = Vector2(minf(min_pos.x, rect.position.x), minf(min_pos.y, rect.position.y))
			max_pos = Vector2(
				maxf(max_pos.x, rect.position.x + rect.size.x),
				maxf(max_pos.y, rect.position.y + rect.size.y)
			)

	if not has_any_control:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	return Rect2(min_pos, max_pos - min_pos)
