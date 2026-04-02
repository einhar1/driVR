## Minimal scenario controller for `scenes/scenarios/new_scenario_template.tscn`
## Use this as a starting point for per-question scenarios.
extends Node3D

@onready var p_spawn_point: Node3D = $SpawnPoint

## Called when the scenario is activated by `question_scene_runner.gd`.
func activate_scenario() -> void:
    # Example: position the persistent car at the spawn point.
    if p_spawn_point:
        var transform: Transform3D = p_spawn_point.transform
        # Emit a signal or call into the scene runner to move the car.
        print("Scenario activated; spawn at:", transform.origin)

func deactivate_scenario() -> void:
    # Cleanup when the scenario is unloaded.
    pass
