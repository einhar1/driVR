---
description: "Use when writing or editing GDScript files. Enforces driVR type hints, naming, exports, signals, and Godot docstring conventions."
applyTo: "**/*.gd"
---

# GDScript Conventions

## Type Hints

Always annotate variables, parameters, and return types:

```gdscript
var speed: float = 5.0
func move(p_direction: Vector3, p_delta: float) -> void:
```

## Naming

- `snake_case` for functions and variables
- `_private_prefix` for private members
- `p_param` prefix for function parameters
- `PascalCase` for classes and enums
- `UPPER_SNAKE` for constants

## Node References

Use `@onready` with `%` unique name notation:

```gdscript
@onready var _hand: XRController3D = %LeftHand
```

## Exports

Use `@export` with groups and range hints where applicable:

```gdscript
@export_group("Movement")
@export_range(0.0, 20.0, 0.1) var max_speed: float = 10.0
```

## Signals

Define at the top of the class with typed parameters:

```gdscript
signal health_changed(new_health: int)
```

## Documentation

Use `##` doc comments (Godot docstring format) for public API:

```gdscript
## Applies impulse to the vehicle in the given direction.
func apply_impulse(p_direction: Vector3) -> void:
```

## Editor Scripts

Use `@tool` and `@icon()` for scripts that need editor visibility.

## Godot Addon and Base Class Integration

### XRTools Base Classes

Extend `XRToolsMovementProvider`, `XRToolsFunctionPickup`, etc. for new VR interactions:

- Register via `is_xr_class(name: String) -> bool`
- Respect physics layer assignments (see copilot-instructions.md)

### QuestionDriveScenario Base Class

For question scenario scripts, extend `QuestionDriveScenario` (defined in `scripts/scenarios/question_drive_scenario.gd`):

```gdscript
extends "res://scripts/scenarios/question_drive_scenario.gd"

## Provide auto-drive lane and stop target for this scenario.

func supports_default_drive_lane() -> bool:
	return true

func get_default_drive_lane() -> RoadLane:
	# Return a RoadLane that the car should follow
	return _my_road_lane

func get_default_stop_target() -> Vector3:
	# Return a world-space position where the car should stop
	return _my_waypoint.global_position
```

For outcome-based questions (multiple routes), implement outcome methods instead:

```gdscript
func supports_outcome_drive() -> bool:
	return true

func get_lane_for_outcome(p_outcome: String) -> RoadLane:
	# Return a RoadLane based on the outcome tag (e.g., "left", "right")
	match p_outcome:
		"left": return _left_lane
		"right": return _right_lane
		_: return null

func get_stop_target_for_outcome(p_outcome: String) -> Vector3:
	# Return a stop position for this outcome
	match p_outcome:
		"left": return _left_stop.global_position
		"right": return _right_stop.global_position
		_: return Vector3.ZERO
```

If these methods are unavailable or return `null`, the quiz flow skips auto-drive and advances to the next question.

### Manager Initialize Pattern

Controllers that interact with `QuestionManager` (including cross-viewport) must follow this pattern for safe initialization:

```gdscript
extends CanvasLayer

var _question_manager: QuestionManager = null

func _ready() -> void:
	call_deferred("_initialize_dependencies")

func _initialize_dependencies() -> void:
	# Resolve QuestionManager via group (works cross-viewport)
	_question_manager = get_tree().get_first_node_in_group("question_manager")

	if _question_manager == null:
		push_error("QuestionManager not found")
		return

	# Check if already initialized
	if _question_manager.question_bank != null:
		_on_manager_ready()
	else:
		# Wait for manager_initialized signal
		await _question_manager.manager_initialized
		_on_manager_ready()

func _on_manager_ready() -> void:
	# Safe to subscribe to quiz signals here
	_question_manager.quiz_started.connect(_on_quiz_started)
	_question_manager.quiz_completed.connect(_on_quiz_completed)
```

**Why this matters:** In debug single-question mode, the quiz is already active during most nodes' `_ready()`. Deferred initialization and signal waiting ensure you connect at the correct time regardless.

## Don'ts

- Don't use untyped `var` declarations
- Don't modify files under `addons/` — those are managed externally
- Don't add OpenXR actions to the project input map — use `openxr_action_map.tres`
