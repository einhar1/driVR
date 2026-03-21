extends CanvasLayer

func _on_button_1_pressed() -> void:
	var main_scene: Node = get_tree().current_scene
	if not is_instance_valid(main_scene):
		push_error("Current scene is invalid")
		return

	var car: Node = main_scene.get_node_or_null("car")
	if not is_instance_valid(car):
		push_error("Node not found: 'car' under current scene")
		return

	var auto_driver: Node = car.get_node_or_null("AutoDriver")
	if not is_instance_valid(auto_driver):
		push_error("Could not find auto-driver")
		return

	auto_driver.call("toggle_auto_drive")
