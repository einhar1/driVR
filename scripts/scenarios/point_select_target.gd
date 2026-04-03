extends StaticBody3D
class_name PointSelectTarget

signal pointer_event(p_event: XRToolsPointerEvent)

## Receives XR/Desktop pointer presses and forwards them to the active point-select scenario.

@export_group("Point Select")
## Stable ID used by the scenario root to decide whether this object is correct.
@export var selection_id: String = ""
## Optional explicit path to the scenario root if auto-discovery is not enough.
@export var scenario_root_path: NodePath = NodePath()
## Prevents the same target from being accepted multiple times.
@export var lock_after_successful_selection: bool = true

var _scenario_root: PointSelectScenario = null
var _selection_locked: bool = false


func _ready() -> void:
	if not pointer_event.is_connected(_on_pointer_event):
		pointer_event.connect(_on_pointer_event)

	_scenario_root = _resolve_scenario_root()
	if selection_id.is_empty():
		push_warning("PointSelectTarget: selection_id is empty on %s" % name)


## Handles presses from the XR pointer / desktop crosshair.
func _on_pointer_event(p_event: XRToolsPointerEvent) -> void:
	if p_event == null or p_event.event_type != XRToolsPointerEvent.Type.PRESSED:
		return
	if _selection_locked:
		return

	if not is_instance_valid(_scenario_root):
		_scenario_root = _resolve_scenario_root()
	if not is_instance_valid(_scenario_root):
		push_error("PointSelectTarget: Scenario root not found for %s" % name)
		return

	var was_accepted: bool = _scenario_root.submit_selection(selection_id)
	print("PointSelectTarget: Pressed '%s'" % selection_id)
	if lock_after_successful_selection and was_accepted:
		_selection_locked = true


## Resolves the nearest ancestor (or explicit node path) that owns point-select validation.
func _resolve_scenario_root() -> PointSelectScenario:
	if not scenario_root_path.is_empty():
		return get_node_or_null(scenario_root_path) as PointSelectScenario

	var current_node: Node = get_parent()
	while is_instance_valid(current_node):
		if current_node is PointSelectScenario:
			return current_node as PointSelectScenario
		current_node = current_node.get_parent()

	var scene_runner: Node = get_tree().current_scene.get_node_or_null("QuestionSceneRunner")
	if not is_instance_valid(scene_runner):
		return null

	return scene_runner.get_node_or_null("QuestionSceneRoot") as PointSelectScenario
