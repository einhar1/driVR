extends Node3D
class_name QuestionSceneRunner

## Keeps the car/player persistent while loading one environment scene per question.
## The default environment node (Floor, roads, etc.) is hidden while a question scene
## is active so that it does not render alongside the loaded content.

@export_group("Persistent Content")
@export var question_manager_path: NodePath = ^"../QuestionManager"
@export var persistent_car_path: NodePath = ^"../car"
## Quiz panel is positioned from the car's authored offset, but remains in world space.
@export var quiz_panel_path: NodePath = ^"../Viewport2Din3D"

@export_group("Default Environment")
## Node that contains the main-scene environment (Floor, RoadManager, etc.).
## It is hidden while a question scene is active and shown when none is loaded.
@export var default_environment_path: NodePath = ^"../DefaultEnvironment"

@export_group("Loaded Scene")
@export var loaded_scene_root_name: String = "QuestionSceneRoot"

const _GROUP_NAME_SCENE_RUNNER: String = "question_scene_runner"

var _question_manager: QuestionManager = null
var _persistent_car: Node3D = null
var _default_environment: Node3D = null
var _active_scene_root: Node3D = null
var _quiz_panel: Node3D = null
var _quiz_panel_offset_from_car: Transform3D = Transform3D.IDENTITY
var _initial_car_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	add_to_group(_GROUP_NAME_SCENE_RUNNER)
	_question_manager = get_node_or_null(question_manager_path) as QuestionManager
	_persistent_car = get_node_or_null(persistent_car_path) as Node3D
	_default_environment = get_node_or_null(default_environment_path) as Node3D
	_quiz_panel = get_node_or_null(quiz_panel_path) as Node3D
	if not is_instance_valid(_quiz_panel) and not quiz_panel_path.is_empty():
		push_warning("QuestionSceneRunner: Quiz panel not found at '%s'" % String(quiz_panel_path))

	if not is_instance_valid(_question_manager):
		push_error("QuestionSceneRunner: QuestionManager not found")
		return

	if not is_instance_valid(_persistent_car):
		push_error("QuestionSceneRunner: persistent car not found")
		return

	_cache_quiz_panel_offset_from_car()
	_initial_car_transform = _persistent_car.global_transform

	if _default_environment == null and not default_environment_path.is_empty():
		push_warning("QuestionSceneRunner: DefaultEnvironment node not found at '%s'" % String(default_environment_path))

	if not _question_manager.question_change_requested.is_connected(_on_question_change_requested):
		_question_manager.question_change_requested.connect(_on_question_change_requested)
	if not _question_manager.quiz_completed.is_connected(_on_quiz_completed_scene):
		_question_manager.quiz_completed.connect(_on_quiz_completed_scene)

	# Only catch up if quiz is already active (e.g. debug single-question mode).
	if _question_manager.is_quiz_active():
		Callable(self , "_apply_question_scene").bind(
				_question_manager.get_current_question()).call_deferred()


## Loads the scene mapped to the requested question and places the persistent car at its spawn point.
## Deferred to avoid modifying the physics world during a physics step (Jolt crash).
func _on_question_change_requested(p_question: QuestionData, _p_index: int) -> void:
	Callable(self , "_apply_question_scene").bind(p_question).call_deferred()


func _on_quiz_completed_scene() -> void:
	Callable(self , "_return_to_default_environment").call_deferred()


## Clears any active scenario scene and returns the player to the default environment.
func _return_to_default_environment() -> void:
	_clear_active_scene()
	_set_default_environment_visible(true)
	if is_instance_valid(_persistent_car):
		_stop_auto_driver()
		_apply_car_spawn_transform(_initial_car_transform)
		_set_player_in_car_state(true)
		_set_persistent_car_render_mode(true)
		_set_car_frozen(false)
		await get_tree().physics_frame
		if is_instance_valid(_persistent_car):
			_apply_car_spawn_transform(_initial_car_transform)


func _apply_question_scene(p_question: QuestionData) -> void:
	if not is_instance_valid(_persistent_car):
		return

	_clear_active_scene()

	if p_question == null or p_question.scene_path.is_empty():
		# No scene mapped — show the default environment and ensure car is visible.
		_set_player_in_car_state(true)
		_set_persistent_car_render_mode(true)
		_set_car_frozen(false)
		_move_quiz_panel(p_question, _persistent_car.global_transform)
		_set_default_environment_visible(true)
		return

	var packed_scene: PackedScene = load(p_question.scene_path) as PackedScene
	if packed_scene == null:
		push_error("QuestionSceneRunner: Failed to load scene at %s" % p_question.scene_path)
		_set_default_environment_visible(true)
		return

	var instantiated_scene: Node = packed_scene.instantiate()
	if not (instantiated_scene is Node3D):
		push_error("QuestionSceneRunner: Scene must inherit Node3D: %s" % p_question.scene_path)
		if is_instance_valid(instantiated_scene):
			instantiated_scene.queue_free()
		_set_default_environment_visible(true)
		return

	# Hide default environment before adding question scene so they never overlap.
	_set_default_environment_visible(false)

	_active_scene_root = instantiated_scene as Node3D
	_active_scene_root.name = loaded_scene_root_name
	add_child(_active_scene_root)

	# Move the car to the scenario's SpawnPoint and place the quiz panel at the
	# same authored offset it has in front of the car, but keep it detached so it
	# stays still even if the car later moves.
	_set_player_in_car_state(p_question.player_in_car)
	_set_persistent_car_render_mode(p_question.player_in_car)
	_set_car_frozen(not p_question.player_in_car)
	await _move_car_to_spawn(p_question)


## Frees the previously active question scene.
func _clear_active_scene() -> void:
	if is_instance_valid(_active_scene_root):
		remove_child(_active_scene_root)
		_active_scene_root.queue_free()
		_active_scene_root = null


## Returns the currently loaded question scene root, or null when no question scene is active.
func get_active_scene_root() -> Node3D:
	return _active_scene_root


## Shows or hides the default environment node.
func _set_default_environment_visible(p_visible: bool) -> void:
	if is_instance_valid(_default_environment):
		_default_environment.visible = p_visible


## Aligns the persistent car with the loaded scene's configured spawn anchor.
func _move_car_to_spawn(p_question: QuestionData) -> void:
	if not is_instance_valid(_active_scene_root):
		return

	var spawn_path: NodePath = p_question.spawn_point_path
	if spawn_path.is_empty():
		spawn_path = NodePath("SpawnPoint")

	var spawn_node: Node3D = _active_scene_root.get_node_or_null(spawn_path) as Node3D
	if spawn_node == null:
		# Fallback for scenes where SpawnPoint exists but the question resource path is unset.
		spawn_node = _find_named_node3d_recursive(_active_scene_root, "SpawnPoint")

	if spawn_node == null:
		push_warning(
			"QuestionSceneRunner: Spawn point '%s' not found in %s. Car position unchanged." % [
				String(spawn_path),
				p_question.scene_path
			]
		)
		return

	var target_transform: Transform3D = spawn_node.global_transform
	_stop_auto_driver()
	_apply_car_spawn_transform(target_transform)
	_move_quiz_panel(p_question, target_transform)

	# Re-apply after one physics tick to avoid VehicleBody state snapping back.
	await get_tree().physics_frame
	if is_instance_valid(_persistent_car):
		_apply_car_spawn_transform(target_transform)
		_move_quiz_panel(p_question, target_transform)


func _stop_auto_driver() -> void:
	var auto_driver: CarAutoDriver = _persistent_car.get_node_or_null("AutoDriver") as CarAutoDriver
	if is_instance_valid(auto_driver):
		auto_driver.stop_auto_drive()


## Updates persistent car systems that depend on whether the player is seated inside the car.
func _set_player_in_car_state(p_player_in_car: bool) -> void:
	if not is_instance_valid(_persistent_car):
		return

	if _persistent_car.has_method("set_engine_audio_enabled"):
		_persistent_car.call("set_engine_audio_enabled", p_player_in_car)


func _apply_car_spawn_transform(p_target_transform: Transform3D) -> void:
	_persistent_car.global_transform = p_target_transform

	# Zero out physics-body velocities so the car does not drift from the spawn point.
	var rigid_body: RigidBody3D = _persistent_car as RigidBody3D
	if is_instance_valid(rigid_body):
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
	_persistent_car.reset_physics_interpolation()


## Freezes or unfreezes the car's physics body.
## While frozen the VehicleBody3D behaves like a static body — no suspension,
## gravity, or drift — giving a stable player view for out-of-car scenarios.
func _set_car_frozen(p_frozen: bool) -> void:
	var rigid_body: RigidBody3D = _persistent_car as RigidBody3D
	if is_instance_valid(rigid_body):
		rigid_body.freeze = p_frozen


## Keeps XR rig active while toggling only visible car body parts.
func _set_persistent_car_render_mode(p_player_in_car: bool) -> void:
	if not is_instance_valid(_persistent_car):
		return

	# Never hide the root car node, because XR hands/pointer live under DriversSeatAnchor.
	_persistent_car.visible = true
	_set_car_visuals_visible(p_player_in_car)


## Shows/hides visual instances under the car, excluding the DriversSeatAnchor XR subtree.
func _set_car_visuals_visible(p_visible: bool) -> void:
	if not is_instance_valid(_persistent_car):
		return

	var xr_anchor: Node = _persistent_car.get_node_or_null("DriversSeatAnchor")
	var stack: Array[Node] = []
	for child_variant: Variant in _persistent_car.get_children():
		if child_variant is Node:
			stack.append(child_variant as Node)

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == xr_anchor:
			continue

		if node is VisualInstance3D:
			(node as VisualInstance3D).visible = p_visible

		for child_variant: Variant in node.get_children():
			if child_variant is Node:
				stack.append(child_variant as Node)


## Caches the panel transform relative to the car using the authored scene state.
## This keeps the panel placement consistent even though it now lives in world space.
func _cache_quiz_panel_offset_from_car() -> void:
	if not is_instance_valid(_quiz_panel) or not is_instance_valid(_persistent_car):
		return
	_quiz_panel_offset_from_car = _persistent_car.global_transform.affine_inverse() * _quiz_panel.global_transform


## Places the quiz panel using the same offset/rotation it has relative to the car
## in the authored scene, while keeping the panel independent from future car motion.
func _move_quiz_panel_to_car_transform(p_car_transform: Transform3D) -> void:
	if not is_instance_valid(_quiz_panel):
		return
	_quiz_panel.global_transform = p_car_transform * _quiz_panel_offset_from_car
	_quiz_panel.reset_physics_interpolation()


## Places the quiz panel either at a scenario-specific anchor or at its default
## authored offset relative to the car spawn transform.
func _move_quiz_panel(p_question: QuestionData, p_car_transform: Transform3D) -> void:
	var panel_spawn_node: Node3D = _find_panel_spawn_node(p_question)
	if is_instance_valid(panel_spawn_node):
		_quiz_panel.global_transform = panel_spawn_node.global_transform
		_quiz_panel.reset_physics_interpolation()
		return

	_move_quiz_panel_to_car_transform(p_car_transform)


## Resolves an optional scenario-specific panel anchor.
func _find_panel_spawn_node(p_question: QuestionData) -> Node3D:
	if not is_instance_valid(_active_scene_root) or p_question == null:
		return null

	var panel_spawn_path: NodePath = p_question.panel_spawn_point_path
	if panel_spawn_path.is_empty():
		return _find_named_node3d_recursive(_active_scene_root, "PanelSpawnPoint")

	var panel_spawn_node: Node3D = _active_scene_root.get_node_or_null(panel_spawn_path) as Node3D
	if is_instance_valid(panel_spawn_node):
		return panel_spawn_node

	return _find_named_node3d_recursive(_active_scene_root, "PanelSpawnPoint")


## Recursively finds the first [Node3D] with an exact node name match.
func _find_named_node3d_recursive(p_root: Node, p_node_name: String) -> Node3D:
	if not is_instance_valid(p_root):
		return null

	var stack: Array[Node] = [p_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == p_node_name and node is Node3D:
			return node as Node3D

		for child_variant: Variant in node.get_children():
			if child_variant is Node:
				stack.append(child_variant as Node)

	return null
