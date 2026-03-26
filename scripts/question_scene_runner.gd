extends Node3D
class_name QuestionSceneRunner

## Keeps the car/player persistent while loading one environment scene per question.
## The default environment node (Floor, roads, etc.) is hidden while a question scene
## is active so that it does not render alongside the loaded content.

@export_group("Persistent Content")
@export var question_manager_path: NodePath = ^"../QuestionManager"
@export var persistent_car_path: NodePath = ^"../car"

@export_group("Default Environment")
## Node that contains the main-scene environment (Floor, RoadManager, etc.).
## It is hidden while a question scene is active and shown when none is loaded.
@export var default_environment_path: NodePath = ^"../DefaultEnvironment"

@export_group("Loaded Scene")
@export var loaded_scene_root_name: String = "QuestionSceneRoot"

var _question_manager: Node = null
var _persistent_car: Node3D = null
var _default_environment: Node3D = null
var _active_scene_root: Node3D = null


func _ready() -> void:
	_question_manager = get_node_or_null(question_manager_path)
	_persistent_car = get_node_or_null(persistent_car_path) as Node3D
	_default_environment = get_node_or_null(default_environment_path) as Node3D

	if not is_instance_valid(_question_manager):
		push_error("QuestionSceneRunner: QuestionManager not found")
		return

	if not is_instance_valid(_persistent_car):
		push_error("QuestionSceneRunner: persistent car not found")
		return

	if _default_environment == null and not default_environment_path.is_empty():
		push_warning("QuestionSceneRunner: DefaultEnvironment node not found at '%s'" % String(default_environment_path))

	if not _question_manager.question_change_requested.is_connected(_on_question_change_requested):
		_question_manager.question_change_requested.connect(_on_question_change_requested)

	# QuestionManager._ready() fires question_change_requested before this node is ready to
	# connect (siblings run _ready() in scene-tree order, QuestionManager before this node).
	# Catch up by applying the current question immediately.
	Callable(self , "_apply_question_scene").bind(
			_question_manager.get_current_question()).call_deferred()


## Loads the scene mapped to the requested question and places the persistent car at its spawn point.
## Deferred to avoid modifying the physics world during a physics step (Jolt crash).
func _on_question_change_requested(p_question: QuestionData, _p_index: int) -> void:
	Callable(self , "_apply_question_scene").bind(p_question).call_deferred()


func _apply_question_scene(p_question: QuestionData) -> void:
	if not is_instance_valid(_persistent_car):
		return

	_clear_active_scene()

	if p_question == null or p_question.scene_path.is_empty():
		# No scene mapped — show the default environment again.
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

	_move_car_to_spawn(p_question)


## Frees the previously active question scene.
func _clear_active_scene() -> void:
	if is_instance_valid(_active_scene_root):
		_active_scene_root.queue_free()
		_active_scene_root = null


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
		spawn_node = _active_scene_root.find_child("SpawnPoint", true, false) as Node3D

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

	# Re-apply after one physics tick to avoid VehicleBody state snapping back.
	await get_tree().physics_frame
	if is_instance_valid(_persistent_car):
		_apply_car_spawn_transform(target_transform)


func _stop_auto_driver() -> void:
	var auto_driver: Node = _persistent_car.get_node_or_null("AutoDriver")
	if is_instance_valid(auto_driver) and auto_driver.has_method("stop_auto_drive"):
		auto_driver.call("stop_auto_drive")


func _apply_car_spawn_transform(p_target_transform: Transform3D) -> void:
	_persistent_car.global_transform = p_target_transform

	# Zero out physics-body velocities so the car does not drift from the spawn point.
	var rigid_body: RigidBody3D = _persistent_car as RigidBody3D
	if is_instance_valid(rigid_body):
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
	_persistent_car.reset_physics_interpolation()
