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

## XRTools Integration

- Extend `XRToolsMovementProvider`, `XRToolsFunctionPickup`, etc. for new VR interactions
- Register via `is_xr_class(name: String) -> bool`
- Respect physics layer assignments (see copilot-instructions.md)

## Don'ts

- Don't use untyped `var` declarations
- Don't modify files under `addons/` — those are managed externally
- Don't add OpenXR actions to the project input map — use `openxr_action_map.tres`
